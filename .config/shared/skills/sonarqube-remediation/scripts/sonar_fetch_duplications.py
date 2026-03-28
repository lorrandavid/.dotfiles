#!/usr/bin/env python3

from __future__ import annotations

import argparse
import math
from typing import Final

from sonar_common import (
    SonarConfig,
    api_get,
    die,
    expect_dict,
    expect_list,
    json_dump,
    main_guard,
    optional_str,
    read_config,
    required_str,
)


DEFAULT_BUFFER_PERCENT: Final[int] = 20
DEFAULT_MAX_FILES: Final[int] = 10
DEFAULT_PAGE_SIZE: Final[int] = 50

DUPLICATION_METRICS: Final[list[str]] = [
    "duplicated_lines",
    "ncloc",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fetch SonarQube duplication details: project overview, per-file duplication blocks, and removal target"
    )
    parser.add_argument("--project-key", required=True, help="SonarQube project key")
    parser.add_argument("--branch", help="Branch name")
    parser.add_argument("--pull-request", help="Pull request identifier")
    parser.add_argument(
        "--buffer-percent",
        type=int,
        default=DEFAULT_BUFFER_PERCENT,
        help="Buffer percentage for removal target (default: 20). "
        "Accounts for refactoring that may introduce some new duplication while removing more.",
    )
    parser.add_argument(
        "--max-files",
        type=int,
        default=DEFAULT_MAX_FILES,
        help="Maximum number of files to fetch duplication details for (default: 10)",
    )
    parser.add_argument(
        "--page-size",
        type=int,
        default=DEFAULT_PAGE_SIZE,
        help="Page size for component tree queries (default: 50, max: 500)",
    )
    return parser.parse_args()


def clamp_page_size(page_size: int) -> int:
    if page_size < 1:
        return 1
    if page_size > 500:
        return 500
    return page_size


def clamp_buffer_percent(buffer_percent: int) -> int:
    if buffer_percent < 0:
        return 0
    if buffer_percent > 100:
        return 100
    return buffer_percent


def calculate_removal_target(
    total_duplicated_lines: int,
    target_density: float,
    total_loc: int,
    buffer_percent: int,
) -> dict[str, object]:
    """Calculate how many duplicated lines to remove, with buffer.

    The buffer accounts for refactoring that may introduce some new
    duplication while removing more. For example, extracting a shared
    utility might remove 100 lines of duplication but the utility itself
    could appear as a new small duplication block.
    """
    buffer = clamp_buffer_percent(buffer_percent)

    # Raw lines to remove to reach the target density
    if total_loc > 0:
        target_dup_lines = math.floor(target_density / 100.0 * total_loc)
    else:
        target_dup_lines = 0

    raw_lines_to_remove = max(0, total_duplicated_lines - target_dup_lines)

    # Apply buffer: we need to remove MORE than the raw target because
    # our refactoring may add back some duplication
    buffer_multiplier = 1.0 + (buffer / 100.0)
    effective_lines_to_remove = math.ceil(raw_lines_to_remove * buffer_multiplier)

    # Cap at the total duplicated lines
    effective_lines_to_remove = min(effective_lines_to_remove, total_duplicated_lines)

    return {
        "total_duplicated_lines": total_duplicated_lines,
        "total_loc": total_loc,
        "current_density_percent": round(total_duplicated_lines / total_loc * 100, 2) if total_loc > 0 else 0,
        "target_density_percent": target_density,
        "target_duplicated_lines": target_dup_lines,
        "raw_lines_to_remove": raw_lines_to_remove,
        "buffer_percent": buffer,
        "effective_lines_to_remove": effective_lines_to_remove,
    }


def fetch_project_measures(
    config: SonarConfig,
    project_key: str,
    branch: str | None,
    pull_request: str | None,
) -> tuple[int, int, float]:
    """Fetch ncloc, duplicated_lines, and duplicated_lines_density."""
    payload, _headers = api_get(
        config,
        "/api/measures/component",
        [
            ("component", project_key),
            ("metricKeys", "ncloc,duplicated_lines,duplicated_lines_density"),
            ("branch", branch),
            ("pullRequest", pull_request),
        ],
    )
    component = expect_dict(payload.get("component"), "component")
    measures = expect_list(component.get("measures"), "component.measures")

    values: dict[str, str] = {}
    for raw_measure in measures:
        measure = expect_dict(raw_measure, "measure")
        metric = required_str(measure.get("metric"), "measure.metric")
        value = optional_str(measure.get("value"))
        if value is not None:
            values[metric] = value

    total_loc = int(values.get("ncloc", "0"))
    duplicated_lines = int(values.get("duplicated_lines", "0"))
    density = float(values.get("duplicated_lines_density", "0.0"))

    return total_loc, duplicated_lines, density


def component_tree_params(
    project_key: str,
    branch: str | None,
    pull_request: str | None,
    page_index: int,
    page_size: int,
) -> list[tuple[str, str | None]]:
    return [
        ("component", project_key),
        ("metricKeys", ",".join(DUPLICATION_METRICS)),
        ("s", "metric"),
        ("metricSort", "duplicated_lines"),
        ("metricSortFilter", "withMeasuresOnly"),
        ("asc", "false"),
        ("qualifiers", "FIL"),
        ("branch", branch),
        ("pullRequest", pull_request),
        ("p", str(page_index)),
        ("ps", str(page_size)),
    ]


def fetch_top_duplicated_files(
    config: SonarConfig,
    project_key: str,
    branch: str | None,
    pull_request: str | None,
    max_files: int,
    page_size: int,
) -> list[dict[str, object]]:
    """Fetch files with most duplicated lines via component_tree API."""
    files: list[dict[str, object]] = []
    page_index = 1

    while len(files) < max_files:
        payload, _headers = api_get(
            config,
            "/api/measures/component_tree",
            component_tree_params(project_key, branch, pull_request, page_index, page_size),
        )
        components = expect_list(payload.get("components"), "components")

        if not components:
            break

        for raw_component in components:
            if len(files) >= max_files:
                break

            component = expect_dict(raw_component, "component")
            component_key = required_str(component.get("key"), "component.key")
            component_path = optional_str(component.get("path"))
            measures = expect_list(component.get("measures") or [], "component.measures")

            metric_values: dict[str, str] = {}
            for raw_measure in measures:
                measure = expect_dict(raw_measure, "measure")
                metric = required_str(measure.get("metric"), "measure.metric")
                value = optional_str(measure.get("value"))
                if value is not None:
                    metric_values[metric] = value

            dup_lines = int(metric_values.get("duplicated_lines", "0"))
            if dup_lines == 0:
                break

            files.append({
                "key": component_key,
                "path": component_path or component_key,
                "duplicated_lines": dup_lines,
                "ncloc": int(metric_values.get("ncloc", "0")),
            })

        paging = expect_dict(payload.get("paging"), "paging")
        total = paging.get("total")
        if not isinstance(total, int) or page_index * page_size >= total:
            break
        page_index += 1

    return files


def resolve_duplication_files(
    raw_files: dict[str, object],
) -> dict[str, dict[str, object]]:
    """Resolve the _ref map from /api/duplications/show into file metadata."""
    resolved: dict[str, dict[str, object]] = {}
    for ref_id, raw_file in raw_files.items():
        file_info = expect_dict(raw_file, f"files.{ref_id}")
        resolved[ref_id] = {
            "key": optional_str(file_info.get("key")),
            "name": optional_str(file_info.get("name")),
            "project_name": optional_str(file_info.get("projectName")),
        }
    return resolved


def summarize_duplication_block(
    raw_block: object,
    ref_map: dict[str, dict[str, object]],
) -> dict[str, object]:
    block = expect_dict(raw_block, "block")
    return {
        "component_key": ref_map.get(
            required_str(block.get("_ref"), "block._ref"), {}
        ).get("key"),
        "component_name": ref_map.get(
            required_str(block.get("_ref"), "block._ref"), {}
        ).get("name"),
        "from_line": block.get("from"),
        "size": block.get("size"),
    }


def fetch_file_duplications(
    config: SonarConfig,
    component_key: str,
    branch: str | None,
    pull_request: str | None,
) -> list[dict[str, object]]:
    """Fetch duplication blocks for a single file via /api/duplications/show."""
    payload, _headers = api_get(
        config,
        "/api/duplications/show",
        [
            ("key", component_key),
            ("branch", branch),
            ("pullRequest", pull_request),
        ],
    )

    raw_files = payload.get("files")
    if raw_files is None or not isinstance(raw_files, dict):
        return []

    ref_map = resolve_duplication_files(raw_files)
    raw_duplications = expect_list(payload.get("duplications") or [], "duplications")

    duplications: list[dict[str, object]] = []
    for raw_dup in raw_duplications:
        dup = expect_dict(raw_dup, "duplication")
        raw_blocks = expect_list(dup.get("blocks") or [], "duplication.blocks")
        blocks = [summarize_duplication_block(b, ref_map) for b in raw_blocks]
        duplications.append({"blocks": blocks})

    return duplications


def main() -> None:
    args = parse_args()
    config = read_config()
    page_size = clamp_page_size(args.page_size)
    buffer_percent = clamp_buffer_percent(args.buffer_percent)

    total_loc, duplicated_lines, density = fetch_project_measures(
        config, args.project_key, args.branch, args.pull_request
    )

    removal_target = calculate_removal_target(
        total_duplicated_lines=duplicated_lines,
        target_density=max(0, density - 3.0) if density > 3.0 else 0.0,
        total_loc=total_loc,
        buffer_percent=buffer_percent,
    )

    top_files = fetch_top_duplicated_files(
        config,
        args.project_key,
        args.branch,
        args.pull_request,
        max_files=args.max_files,
        page_size=page_size,
    )

    files_with_details: list[dict[str, object]] = []
    for file_entry in top_files:
        component_key = required_str(file_entry.get("key"), "file.key")
        duplications = fetch_file_duplications(
            config, component_key, args.branch, args.pull_request
        )
        files_with_details.append({
            **file_entry,
            "duplications": duplications,
        })

    payload: dict[str, object] = {
        "project": {
            "key": args.project_key,
            "branch": args.branch,
            "pull_request": args.pull_request,
        },
        "overview": removal_target,
        "files": files_with_details,
    }
    json_dump(payload)


if __name__ == "__main__":
    main_guard(main)
