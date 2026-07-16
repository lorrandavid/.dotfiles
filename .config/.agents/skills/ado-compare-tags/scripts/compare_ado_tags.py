#!/usr/bin/env python3
"""Compare Azure Repos tags and join tag-only PRs to their work-item hierarchy."""

from __future__ import annotations

import argparse
from functools import lru_cache
import html
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from typing import Any, Iterable
from urllib.parse import quote, unquote, urlparse, urlunparse


PR_QUERY_BATCH_SIZE = 100
MAX_PARENT_DEPTH = 20


class ComparisonError(RuntimeError):
    """A safe, user-facing comparison failure."""


class _TextExtractor(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.parts: list[str] = []

    def handle_data(self, data: str) -> None:
        value = data.strip()
        if value:
            self.parts.append(value)


def plain_text(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value)
    parser = _TextExtractor()
    try:
        parser.feed(text)
        normalized = " ".join(parser.parts)
    except Exception:
        normalized = re.sub(r"<[^>]+>", " ", text)
    normalized = re.sub(r"\s+", " ", html.unescape(normalized)).strip()
    return normalized or None


def redact_secrets(value: str) -> str:
    return re.sub(r"(?i)(https?://)[^/@\s]+(?::[^/@\s]*)?@", r"\1", value)


def safe_repository_url(repository_url: str) -> str:
    parsed = urlparse(repository_url)
    if parsed.scheme.lower() not in {"http", "https"} or not parsed.hostname:
        return repository_url
    host = parsed.hostname
    if parsed.port:
        host = f"{host}:{parsed.port}"
    return urlunparse((parsed.scheme, host, parsed.path, "", "", ""))


def run(command: list[str], cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=str(cwd) if cwd else None,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if check and result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or f"exit code {result.returncode}"
        raise ComparisonError(redact_secrets(detail))
    return result


def run_json(command: list[str]) -> Any:
    result = run(command)
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise ComparisonError(f"Expected JSON but received invalid output: {exc}") from exc


@lru_cache(maxsize=None)
def executable(name: str) -> str:
    candidates = [name]
    if os.name == "nt":
        candidates = [f"{name}.exe", f"{name}.cmd", f"{name}.bat", name]
    for candidate in candidates:
        resolved = shutil.which(candidate)
        if resolved:
            return resolved
    raise ComparisonError(f"Missing required executable: {name}")


def parse_repository_url(repository_url: str) -> dict[str, str]:
    scp_match = re.fullmatch(
        r"git@ssh\.dev\.azure\.com:v3/([^/]+)/([^/]+)/(.+?)(?:\.git)?/?",
        repository_url,
        re.IGNORECASE,
    )
    if scp_match:
        organization, project, repository = map(unquote, scp_match.groups())
        return {
            "organization": organization,
            "organizationUrl": f"https://dev.azure.com/{quote(organization, safe='')}",
            "project": project,
            "repository": repository,
        }

    parsed = urlparse(repository_url)
    host = (parsed.hostname or "").lower()
    segments = [unquote(segment) for segment in parsed.path.split("/") if segment]

    if host == "dev.azure.com" and len(segments) >= 4 and segments[2].lower() == "_git":
        organization, project, repository = segments[0], segments[1], "/".join(segments[3:])
        organization_url = f"https://dev.azure.com/{quote(organization, safe='')}"
    elif host.endswith(".visualstudio.com") and len(segments) >= 3 and segments[1].lower() == "_git":
        organization = host[: -len(".visualstudio.com")]
        project, repository = segments[0], "/".join(segments[2:])
        organization_url = f"https://{host}"
    elif host == "ssh.dev.azure.com" and len(segments) >= 4 and segments[0].lower() == "v3":
        organization, project, repository = segments[1], segments[2], "/".join(segments[3:])
        organization_url = f"https://dev.azure.com/{quote(organization, safe='')}"
    else:
        raise ComparisonError(
            "Repository URL must be an Azure Repos HTTPS or SSH URL containing organization, project, and repository."
        )

    if repository.lower().endswith(".git"):
        repository = repository[:-4]
    if not organization or not project or not repository:
        raise ComparisonError("Could not resolve organization, project, and repository from the repository URL.")
    return {
        "organization": organization,
        "organizationUrl": organization_url,
        "project": project,
        "repository": repository,
    }


def verify_prerequisites() -> None:
    executable("git")
    az = executable("az")
    run_json([az, "extension", "show", "--name", "azure-devops", "--only-show-errors", "--output", "json"])


def validate_tag(tag: str) -> None:
    if not tag:
        raise ComparisonError("Tag names cannot be empty.")
    result = run([executable("git"), "check-ref-format", f"refs/tags/{tag}"], check=False)
    if result.returncode != 0:
        raise ComparisonError(f"Invalid Git tag name: {tag}")


def resolve_repository(scope: dict[str, str]) -> dict[str, str]:
    raw = run_json(
        [
            executable("az"),
            "repos",
            "show",
            "--repository",
            scope["repository"],
            "--project",
            scope["project"],
            "--org",
            scope["organizationUrl"],
            "--only-show-errors",
            "--output",
            "json",
        ]
    )
    project = raw.get("project") or {}
    return {
        **scope,
        "id": str(raw.get("id") or ""),
        "name": str(raw.get("name") or scope["repository"]),
        "projectId": str(project.get("id") or ""),
        "projectName": str(project.get("name") or scope["project"]),
        "webUrl": str(raw.get("webUrl") or ""),
    }


def git_output(repo: Path, *arguments: str, check: bool = True) -> str:
    return run([executable("git"), "-C", str(repo), *arguments], check=check).stdout.strip()


def fetch_tag(repo: Path, tag: str) -> str:
    ref = f"refs/tags/{tag}"
    run(
        [
            executable("git"),
            "-C",
            str(repo),
            "fetch",
            "--quiet",
            "--no-tags",
            "origin",
            f"+{ref}:{ref}",
        ]
    )
    return git_output(repo, "rev-parse", "--verify", f"{ref}^{{commit}}")


def rev_list(repo: Path, include: str, exclude: str) -> list[str]:
    output = git_output(repo, "rev-list", include, f"^{exclude}")
    return output.splitlines() if output else []


def is_ancestor(repo: Path, ancestor: str, descendant: str) -> bool:
    result = run(
        [
            executable("git"),
            "-C",
            str(repo),
            "merge-base",
            "--is-ancestor",
            ancestor,
            descendant,
        ],
        check=False,
    )
    if result.returncode not in (0, 1):
        raise ComparisonError(result.stderr.strip() or "Could not determine tag ancestry.")
    return result.returncode == 0


def relationship(repo: Path, base_commit: str, target_commit: str) -> str:
    if base_commit == target_commit:
        return "sameCommit"
    if is_ancestor(repo, base_commit, target_commit):
        return "baseAncestorOfTarget"
    if is_ancestor(repo, target_commit, base_commit):
        return "targetAncestorOfBase"
    return "diverged"


def chunks(values: list[str], size: int) -> Iterable[list[str]]:
    for index in range(0, len(values), size):
        yield values[index : index + size]


def collection(raw: Any) -> list[Any]:
    if isinstance(raw, list):
        return raw
    if isinstance(raw, dict):
        value = raw.get("value")
        if isinstance(value, list):
            return value
    return []


def query_pull_requests(commits: list[str], repository: dict[str, str]) -> tuple[dict[str, dict[str, Any]], set[str]]:
    pull_requests: dict[str, dict[str, Any]] = {}
    matched_commits: set[str] = set()
    for batch in chunks(commits, PR_QUERY_BATCH_SIZE):
        body = {"queries": [{"type": "lastMergeCommit", "items": batch}]}
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", suffix=".json", delete=False) as handle:
            json.dump(body, handle)
            request_path = handle.name
        try:
            raw = run_json(
                [
                    executable("az"),
                    "devops",
                    "invoke",
                    "--area",
                    "git",
                    "--resource",
                    "pullRequestQuery",
                    "--route-parameters",
                    f"project={repository['projectId'] or repository['projectName']}",
                    f"repositoryId={repository['id']}",
                    "--org",
                    repository["organizationUrl"],
                    "--api-version",
                    "7.1",
                    "--http-method",
                    "POST",
                    "--in-file",
                    request_path,
                    "--only-show-errors",
                    "--output",
                    "json",
                ]
            )
        finally:
            Path(request_path).unlink(missing_ok=True)

        results = raw.get("results", []) if isinstance(raw, dict) else []
        for result_map in results:
            if not isinstance(result_map, dict):
                continue
            for commit_id, prs in result_map.items():
                if not isinstance(prs, list) or not prs:
                    continue
                matched_commits.add(commit_id.lower())
                for pr in prs:
                    if isinstance(pr, dict) and pr.get("pullRequestId") is not None:
                        pull_requests[str(pr["pullRequestId"])] = pr
    return pull_requests, matched_commits


def portal_url(
    repository: dict[str, str], kind: str, resource_id: int, project_name: str | None = None
) -> str:
    org = repository["organizationUrl"].rstrip("/")
    project = quote(project_name or repository["projectName"], safe="")
    if kind == "pr":
        repo = quote(repository["name"], safe="")
        return f"{org}/{project}/_git/{repo}/pullrequest/{resource_id}"
    return f"{org}/{project}/_workitems/edit/{resource_id}"


def normalize_identity(value: Any) -> str | None:
    if isinstance(value, dict):
        return value.get("displayName") or value.get("uniqueName")
    return str(value) if value else None


def work_item_category(item_type: str) -> str:
    normalized = item_type.casefold().strip()
    if normalized == "feature":
        return "feature"
    if normalized in {"user story", "product backlog item", "requirement"}:
        return "story"
    if normalized == "task":
        return "task"
    return "other"


def parent_id(relations: Any) -> int | None:
    if not isinstance(relations, list):
        return None
    for relation in relations:
        if not isinstance(relation, dict) or relation.get("rel") != "System.LinkTypes.Hierarchy-Reverse":
            continue
        match = re.search(r"/(\d+)(?:\?.*)?$", str(relation.get("url") or ""))
        if match:
            return int(match.group(1))
    return None


def fetch_work_item(work_item_id: int, repository: dict[str, str]) -> tuple[dict[str, Any], int | None]:
    raw = run_json(
        [
            executable("az"),
            "boards",
            "work-item",
            "show",
            "--id",
            str(work_item_id),
            "--expand",
            "relations",
            "--org",
            repository["organizationUrl"],
            "--only-show-errors",
            "--output",
            "json",
        ]
    )
    fields = raw.get("fields") or {}
    item_type = str(fields.get("System.WorkItemType") or "Unknown")
    project_name = str(fields.get("System.TeamProject") or repository["projectName"])
    normalized = {
        "id": int(raw.get("id") or work_item_id),
        "type": item_type,
        "category": work_item_category(item_type),
        "title": str(fields.get("System.Title") or ""),
        "state": str(fields.get("System.State") or ""),
        "description": plain_text(fields.get("System.Description")),
        "acceptanceCriteria": plain_text(fields.get("Microsoft.VSTS.Common.AcceptanceCriteria")),
        "assignedTo": normalize_identity(fields.get("System.AssignedTo")),
        "areaPath": fields.get("System.AreaPath"),
        "iterationPath": fields.get("System.IterationPath"),
        "project": project_name,
        "url": portal_url(
            repository, "work-item", int(raw.get("id") or work_item_id), project_name
        ),
        "parentId": parent_id(raw.get("relations")),
        "directPullRequestIds": [],
        "viaPullRequestIds": [],
    }
    return normalized, normalized["parentId"]


def hydrate_pull_request(pr_id: int, shallow: dict[str, Any], repository: dict[str, str]) -> dict[str, Any]:
    raw = run_json(
        [
            executable("az"),
            "repos",
            "pr",
            "show",
            "--id",
            str(pr_id),
            "--org",
            repository["organizationUrl"],
            "--only-show-errors",
            "--output",
            "json",
        ]
    )
    source = raw or shallow
    merge_commit = source.get("lastMergeCommit") or shallow.get("lastMergeCommit") or {}
    return {
        "id": pr_id,
        "title": str(source.get("title") or shallow.get("title") or ""),
        "description": plain_text(source.get("description")),
        "status": str(source.get("status") or shallow.get("status") or ""),
        "sourceRefName": source.get("sourceRefName"),
        "targetRefName": source.get("targetRefName"),
        "closedDate": source.get("closedDate"),
        "createdBy": normalize_identity(source.get("createdBy")),
        "lastMergeCommit": merge_commit.get("commitId"),
        "url": portal_url(repository, "pr", pr_id),
        "directWorkItemIds": [],
        "workItemPaths": [],
    }


def linked_work_item_ids(pr_id: int, repository: dict[str, str]) -> list[int]:
    raw = run_json(
        [
            executable("az"),
            "repos",
            "pr",
            "work-item",
            "list",
            "--id",
            str(pr_id),
            "--org",
            repository["organizationUrl"],
            "--only-show-errors",
            "--output",
            "json",
        ]
    )
    ids: list[int] = []
    for item in collection(raw):
        if isinstance(item, dict) and item.get("id") is not None:
            ids.append(int(item["id"]))
    return sorted(set(ids))


def collect_side(
    commits: list[str],
    git_repo: Path,
    repository: dict[str, str],
    work_item_cache: dict[int, tuple[dict[str, Any], int | None]],
) -> dict[str, Any]:
    shallow_prs, matched_commits = query_pull_requests(commits, repository)
    pull_requests: list[dict[str, Any]] = []
    side_items: dict[int, dict[str, Any]] = {}
    warnings: list[str] = []

    for pr_key in sorted(shallow_prs, key=int):
        pr_id = int(pr_key)
        try:
            pr = hydrate_pull_request(pr_id, shallow_prs[pr_key], repository)
            if pr["status"].casefold() != "completed":
                warnings.append(
                    f"PR #{pr_id} was returned for a merge commit but has status {pr['status']!r}; it was excluded."
                )
                continue
            direct_ids = linked_work_item_ids(pr_id, repository)
            pr["directWorkItemIds"] = direct_ids
        except ComparisonError as exc:
            warnings.append(f"PR #{pr_id}: {exc}")
            continue

        for direct_id in direct_ids:
            path: list[int] = []
            current_id: int | None = direct_id
            seen: set[int] = set()
            depth = 0
            while current_id is not None and current_id not in seen and depth < MAX_PARENT_DEPTH:
                seen.add(current_id)
                try:
                    if current_id not in work_item_cache:
                        work_item_cache[current_id] = fetch_work_item(current_id, repository)
                    cached_item, next_parent_id = work_item_cache[current_id]
                except ComparisonError as exc:
                    warnings.append(f"Work item #{current_id} from PR #{pr_id}: {exc}")
                    break

                item = side_items.setdefault(current_id, {**cached_item})
                direct_prs = set(item.get("directPullRequestIds", []))
                via_prs = set(item.get("viaPullRequestIds", []))
                via_prs.add(pr_id)
                if current_id == direct_id:
                    direct_prs.add(pr_id)
                item["directPullRequestIds"] = sorted(direct_prs)
                item["viaPullRequestIds"] = sorted(via_prs)
                path.append(current_id)
                if item["category"] == "feature":
                    break
                current_id = next_parent_id
                depth += 1

            if current_id in seen and current_id != direct_id:
                warnings.append(f"Hierarchy cycle detected while following work item #{direct_id} from PR #{pr_id}.")
            elif depth >= MAX_PARENT_DEPTH:
                warnings.append(f"Hierarchy depth exceeded {MAX_PARENT_DEPTH} for work item #{direct_id} from PR #{pr_id}.")
            pr["workItemPaths"].append(path)
        pull_requests.append(pr)

    unmatched_ids = [commit for commit in commits if commit.lower() not in matched_commits]
    unmatched = []
    for commit_id in unmatched_ids:
        subject = git_output(git_repo, "show", "-s", "--format=%s", commit_id)
        unmatched.append({"commitId": commit_id, "subject": subject})

    return {
        "commitCount": len(commits),
        "pullRequestCount": len(pull_requests),
        "workItemCount": len(side_items),
        "pullRequests": pull_requests,
        "workItems": sorted(side_items.values(), key=lambda item: (item["category"], item["id"])),
        "unmatchedCommits": unmatched,
        "warnings": warnings,
        "complete": not warnings,
    }


def compare(repository_url: str, base_tag: str, target_tag: str) -> dict[str, Any]:
    validate_tag(base_tag)
    validate_tag(target_tag)
    verify_prerequisites()
    repository = resolve_repository(parse_repository_url(repository_url))
    if not repository["id"]:
        raise ComparisonError("Azure DevOps returned repository metadata without a repository ID.")

    print(f"Fetching tags {base_tag!r} and {target_tag!r}...", file=sys.stderr)
    with tempfile.TemporaryDirectory(prefix="ado-compare-tags-") as temp_dir:
        git_repo = Path(temp_dir) / "repo"
        git = executable("git")
        run([git, "init", "--quiet", str(git_repo)])
        run([git, "-C", str(git_repo), "remote", "add", "origin", repository_url])
        base_commit = fetch_tag(git_repo, base_tag)
        target_commit = fetch_tag(git_repo, target_tag)
        target_only_commits = rev_list(git_repo, target_commit, base_commit)
        base_only_commits = rev_list(git_repo, base_commit, target_commit)

        print(
            f"Resolving PRs for {len(target_only_commits)} target-only and {len(base_only_commits)} base-only commits...",
            file=sys.stderr,
        )
        work_item_cache: dict[int, tuple[dict[str, Any], int | None]] = {}
        target_side = collect_side(target_only_commits, git_repo, repository, work_item_cache)
        base_side = collect_side(base_only_commits, git_repo, repository, work_item_cache)
        relation = relationship(git_repo, base_commit, target_commit)

    warnings = [*target_side["warnings"], *base_side["warnings"]]
    return {
        "operation": "tag-comparison",
        "classification": "read-only",
        "repository": {
            "inputUrl": safe_repository_url(repository_url),
            "organization": repository["organization"],
            "organizationUrl": repository["organizationUrl"],
            "projectId": repository["projectId"],
            "project": repository["projectName"],
            "id": repository["id"],
            "name": repository["name"],
            "webUrl": repository["webUrl"],
        },
        "comparison": {
            "baseTag": base_tag,
            "baseCommit": base_commit,
            "targetTag": target_tag,
            "targetCommit": target_commit,
            "relationship": relation,
        },
        "sides": {
            "targetOnly": target_side,
            "baseOnly": base_side,
        },
        "completeness": {
            "complete": not warnings,
            "warnings": warnings,
            "method": "Git reachability plus Azure DevOps pullRequestQuery(type=lastMergeCommit)",
        },
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compare two Azure Repos tags and return merged PR/work-item differences as JSON."
    )
    parser.add_argument("repository_url", help="Azure DevOps repository HTTPS or SSH URL")
    parser.add_argument("base_tag", help="Base tag")
    parser.add_argument("target_tag", help="Target tag")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        result = compare(args.repository_url, args.base_tag, args.target_tag)
    except ComparisonError as exc:
        print(f"ado-compare-tags: {exc}", file=sys.stderr)
        return 1
    json.dump(result, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write(os.linesep)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
