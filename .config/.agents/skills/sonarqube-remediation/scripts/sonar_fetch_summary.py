#!/usr/bin/env python3

from __future__ import annotations

import argparse
from typing import Final

from sonar_common import (
    api_get,
    expect_dict,
    expect_list,
    json_dump,
    main_guard,
    optional_str,
    parse_csv,
    read_config,
    required_str,
)


DEFAULT_METRICS: Final[list[str]] = [
    "bugs",
    "code_smells",
    "vulnerabilities",
    "duplicated_lines",
    "duplicated_lines_density",
    "duplicated_blocks",
    "ncloc",
    "reliability_rating",
    "security_rating",
    "sqale_rating",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Fetch SonarQube summary measures and quality gate state")
    parser.add_argument("--project-key", required=True, help="SonarQube project key")
    parser.add_argument("--branch", help="Branch name")
    parser.add_argument("--pull-request", help="Pull request identifier")
    parser.add_argument("--metrics", help="Comma-separated metric keys")
    return parser.parse_args()


def metric_value_map(measures_payload: dict[str, object]) -> dict[str, object]:
    component = expect_dict(measures_payload.get("component"), "component")
    measures = expect_list(component.get("measures"), "component.measures")
    result: dict[str, object] = {}
    for raw_measure in measures:
        measure = expect_dict(raw_measure, "measure")
        metric = required_str(measure.get("metric"), "measure.metric")
        value = optional_str(measure.get("value"))
        if value is None:
            continue
        result[metric] = value
    result["project_key"] = required_str(component.get("key"), "component.key")
    result["project_name"] = required_str(component.get("name"), "component.name")
    return result


def quality_gate_summary(gate_payload: dict[str, object]) -> dict[str, object]:
    project_status = expect_dict(gate_payload.get("projectStatus"), "projectStatus")
    conditions = expect_list(project_status.get("conditions") or [], "projectStatus.conditions")
    summarized_conditions: list[dict[str, object]] = []
    for raw_condition in conditions:
        condition = expect_dict(raw_condition, "condition")
        summarized_conditions.append(
            {
                "metric": optional_str(condition.get("metricKey")),
                "status": optional_str(condition.get("status")),
                "actual": optional_str(condition.get("actualValue")),
                "comparator": optional_str(condition.get("comparator")),
                "error_threshold": optional_str(condition.get("errorThreshold")),
            }
        )
    periods = project_status.get("periods")
    return {
        "status": optional_str(project_status.get("status")),
        "cayc_status": optional_str(project_status.get("caycStatus")),
        "ignored_conditions": project_status.get("ignoredConditions"),
        "periods": periods if isinstance(periods, list) else [],
        "conditions": summarized_conditions,
    }


def main() -> None:
    args = parse_args()
    config = read_config()
    metrics = parse_csv(args.metrics) if args.metrics else DEFAULT_METRICS
    metric_keys = ",".join(metrics)

    measures_payload, measure_headers = api_get(
        config,
        "/api/measures/component",
        [
            ("component", args.project_key),
            ("metricKeys", metric_keys),
            ("branch", args.branch),
            ("pullRequest", args.pull_request),
        ],
    )
    gate_payload, gate_headers = api_get(
        config,
        "/api/qualitygates/project_status",
        [
            ("projectKey", args.project_key),
            ("branch", args.branch),
            ("pullRequest", args.pull_request),
        ],
    )

    payload = {
        "project": {
            "key": args.project_key,
            "branch": args.branch,
            "pull_request": args.pull_request,
        },
        "measures": metric_value_map(measures_payload),
        "quality_gate": quality_gate_summary(gate_payload),
        "token_expiration": measure_headers.get("sonarqube-authentication-token-expiration")
        or gate_headers.get("sonarqube-authentication-token-expiration"),
    }
    json_dump(payload)


if __name__ == "__main__":
    main_guard(main)
