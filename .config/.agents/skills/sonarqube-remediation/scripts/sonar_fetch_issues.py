#!/usr/bin/env python3

from __future__ import annotations

import argparse

from sonar_common import (
    api_get,
    expect_dict,
    expect_list,
    json_dump,
    main_guard,
    optional_str,
    read_config,
    required_str,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Fetch SonarQube issues with stable JSON output")
    parser.add_argument("--project-key", required=True, help="SonarQube project key")
    parser.add_argument("--branch", help="Branch name")
    parser.add_argument("--pull-request", help="Pull request identifier")
    parser.add_argument("--types", help="Comma-separated issue types")
    parser.add_argument("--severities", help="Comma-separated severities")
    parser.add_argument("--statuses", help="Comma-separated statuses")
    parser.add_argument("--resolved", choices=["true", "false"], default="false", help="Include resolved issues")
    parser.add_argument("--assignees", help="Comma-separated assignee logins")
    parser.add_argument("--created-after", help="Filter by creation date, for example 2026-03-01")
    parser.add_argument("--languages", help="Comma-separated language keys")
    parser.add_argument("--page-size", type=int, default=100, help="Page size up to 500")
    parser.add_argument("--max-pages", type=int, default=1, help="How many pages to fetch")
    return parser.parse_args()


def issue_search_params(
    args: argparse.Namespace,
    page_index: int,
    page_size: int,
) -> list[tuple[str, str | None]]:
    return [
        ("componentKeys", args.project_key),
        ("branch", args.branch),
        ("pullRequest", args.pull_request),
        ("types", args.types),
        ("severities", args.severities),
        ("statuses", args.statuses),
        ("resolved", args.resolved),
        ("assignees", args.assignees),
        ("createdAfter", args.created_after),
        ("languages", args.languages),
        ("p", str(page_index)),
        ("ps", str(page_size)),
    ]


def clamp_page_size(page_size: int) -> int:
    if page_size < 1:
        return 1
    if page_size > 500:
        return 500
    return page_size


def issue_url(base_url: str, project_key: str | None, issue_key: str) -> str | None:
    if project_key is None:
        return None
    return f"{base_url}/project/issues?id={project_key}&open={issue_key}"


def summarize_issue(raw_issue: object, base_url: str) -> dict[str, object]:
    issue = expect_dict(raw_issue, "issue")
    issue_key = required_str(issue.get("key"), "issue.key")
    project_key = optional_str(issue.get("project"))
    text_range = issue.get("textRange")
    text_range_dict = expect_dict(text_range, "issue.textRange") if text_range is not None else None
    line = issue.get("line")
    return {
        "key": issue_key,
        "rule": optional_str(issue.get("rule")),
        "message": optional_str(issue.get("message")),
        "project": project_key,
        "component": optional_str(issue.get("component")),
        "type": optional_str(issue.get("type")),
        "severity": optional_str(issue.get("severity")),
        "status": optional_str(issue.get("status")),
        "resolution": optional_str(issue.get("resolution")),
        "assignee": optional_str(issue.get("assignee")),
        "author": optional_str(issue.get("author")),
        "effort": optional_str(issue.get("effort")),
        "debt": optional_str(issue.get("debt")),
        "creation_date": optional_str(issue.get("creationDate")),
        "update_date": optional_str(issue.get("updateDate")),
        "line": line if isinstance(line, int) else None,
        "text_range": {
            "start_line": text_range_dict.get("startLine"),
            "end_line": text_range_dict.get("endLine"),
            "start_offset": text_range_dict.get("startOffset"),
            "end_offset": text_range_dict.get("endOffset"),
        }
        if text_range_dict is not None
        else None,
        "tags": expect_list(issue.get("tags") or [], "issue.tags"),
        "clean_code_attribute": optional_str(issue.get("cleanCodeAttribute")),
        "url": issue_url(base_url, project_key, issue_key),
    }


def main() -> None:
    args = parse_args()
    config = read_config()
    page_size = clamp_page_size(args.page_size)

    issues: list[dict[str, object]] = []
    paging: dict[str, object] | None = None

    for page_index in range(1, args.max_pages + 1):
        payload, headers = api_get(
            config,
            "/api/issues/search",
            issue_search_params(args, page_index, page_size),
        )
        raw_issues = expect_list(payload.get("issues"), "issues")
        for raw_issue in raw_issues:
            issues.append(summarize_issue(raw_issue, config.base_url))

        raw_paging = expect_dict(payload.get("paging"), "paging")
        total = raw_paging.get("total")
        page_index_value = raw_paging.get("pageIndex")
        page_size_value = raw_paging.get("pageSize")
        paging = {
            "page_index": page_index_value,
            "page_size": page_size_value,
            "total": total,
            "fetched_pages": page_index,
            "token_expiration": headers.get("sonarqube-authentication-token-expiration"),
        }

        if not isinstance(total, int) or not isinstance(page_size_value, int) or not isinstance(page_index_value, int):
            break
        if page_index_value * page_size_value >= total:
            break

    payload = {
        "project": {
            "key": args.project_key,
            "branch": args.branch,
            "pull_request": args.pull_request,
        },
        "filters": {
            "types": args.types,
            "severities": args.severities,
            "statuses": args.statuses,
            "resolved": args.resolved,
            "assignees": args.assignees,
            "created_after": args.created_after,
            "languages": args.languages,
        },
        "paging": paging,
        "issues": issues,
    }
    json_dump(payload)


if __name__ == "__main__":
    main_guard(main)
