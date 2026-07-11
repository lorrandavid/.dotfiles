#!/usr/bin/env python3

from __future__ import annotations

import argparse
import time

from sonar_common import (
    SonarConfig,
    api_get,
    expect_dict,
    expect_list,
    iso_now,
    json_dump,
    main_guard,
    optional_str,
    read_config,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Wait for a newer SonarQube analysis to appear")
    parser.add_argument("--project-key", required=True, help="SonarQube project key")
    parser.add_argument("--branch", help="Branch name")
    parser.add_argument("--pull-request", help="Pull request identifier")
    parser.add_argument("--timeout-seconds", type=int, default=600, help="Maximum wait time")
    parser.add_argument("--poll-interval-seconds", type=int, default=10, help="Polling interval")
    parser.add_argument("--baseline-analysis-key", help="Known previous analysis key")
    return parser.parse_args()


def latest_analysis(payload: dict[str, object]) -> dict[str, object] | None:
    analyses = expect_list(payload.get("analyses") or [], "analyses")
    if not analyses:
        return None
    return expect_dict(analyses[0], "analysis")


def analysis_snapshot(analysis: dict[str, object] | None) -> dict[str, object] | None:
    if analysis is None:
        return None
    return {
        "key": optional_str(analysis.get("key")),
        "date": optional_str(analysis.get("date")),
        "events": expect_list(analysis.get("events") or [], "analysis.events"),
    }


def fetch_latest_analysis(config: SonarConfig, args: argparse.Namespace) -> dict[str, object] | None:
    payload, _headers = api_get(
        config,
        "/api/project_analyses/search",
        [
            ("project", args.project_key),
            ("branch", args.branch),
            ("pullRequest", args.pull_request),
            ("ps", "1"),
        ],
    )
    return latest_analysis(payload)


def main() -> None:
    args = parse_args()
    config = read_config()
    started_at = time.monotonic()
    baseline = args.baseline_analysis_key
    if baseline is None:
        current = fetch_latest_analysis(config, args)
        snapshot = analysis_snapshot(current)
        baseline = snapshot["key"] if snapshot is not None else None

    while True:
        current = fetch_latest_analysis(config, args)
        snapshot = analysis_snapshot(current)
        current_key = snapshot["key"] if snapshot is not None else None
        if snapshot is not None and current_key != baseline:
            json_dump(
                {
                    "project": {
                        "key": args.project_key,
                        "branch": args.branch,
                        "pull_request": args.pull_request,
                    },
                    "status": "completed",
                    "baseline_analysis_key": baseline,
                    "latest_analysis": snapshot,
                    "observed_at": iso_now(),
                }
            )
            return

        elapsed = time.monotonic() - started_at
        if elapsed >= args.timeout_seconds:
            json_dump(
                {
                    "project": {
                        "key": args.project_key,
                        "branch": args.branch,
                        "pull_request": args.pull_request,
                    },
                    "status": "timeout",
                    "baseline_analysis_key": baseline,
                    "latest_analysis": snapshot,
                    "observed_at": iso_now(),
                }
            )
            return

        time.sleep(args.poll_interval_seconds)
