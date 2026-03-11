---
name: sonarqube-remediation
description: Fetch and triage SonarQube issues and measures, then drive conservative remediation workflows. Use when you need SonarQube Server data such as bugs, code smells, duplicated lines, or quality gate status.
references:
  - references/auth-and-setup.md
  - references/api-usage.md
  - references/remediation-policy.md
  - references/mcp-optional-setup.md
---

# SonarQube Remediation

Use this skill when SonarQube should be the verification layer for code changes or autonomous cleanup.

## Rules

- Prefer the bundled REST helper scripts for retrieval.
- Treat SonarQube Server as the target.
- Never commit tokens, `.env` files, or machine-local MCP config.
- Keep autonomous fixes conservative and locally verifiable.
- Re-run the target repo's checks before claiming a Sonar issue is resolved.

## Shell compatibility

- Bash/zsh: use `python3`.
- Windows PowerShell: prefer `py -3`; use `python` only if `py` is unavailable.
- Keep script paths relative and with forward slashes so the same commands work across shells.

## Required environment

- `SONARQUBE_URL`
- `SONARQUBE_TOKEN`

## Quick start

Project summary:

```bash
python3 .config/shared/skills/sonarqube-remediation/scripts/sonar_fetch_summary.py --project-key <project-key>
```

```powershell
py -3 .config/shared/skills/sonarqube-remediation/scripts/sonar_fetch_summary.py --project-key <project-key>
```

Open issues:

```bash
python3 .config/shared/skills/sonarqube-remediation/scripts/sonar_fetch_issues.py --project-key <project-key> --types BUG,CODE_SMELL --statuses OPEN,CONFIRMED --max-pages 2
```

If the helper output disagrees with the UI or a manual request, compare against this raw API form:

```bash
curl -s -u "$SONARQUBE_TOKEN:" "$SONARQUBE_URL/api/issues/search?componentKeys=<project-key>&types=BUG,CODE_SMELL&statuses=OPEN,CONFIRMED&ps=100"
```

```powershell
py -3 .config/shared/skills/sonarqube-remediation/scripts/sonar_fetch_issues.py --project-key <project-key> --types BUG,CODE_SMELL --statuses OPEN,CONFIRMED --max-pages 2
```

Wait for fresh analysis after a scan:

```bash
python3 .config/shared/skills/sonarqube-remediation/scripts/sonar_poll_analysis.py --project-key <project-key> --timeout-seconds 600
```

```powershell
py -3 .config/shared/skills/sonarqube-remediation/scripts/sonar_poll_analysis.py --project-key <project-key> --timeout-seconds 600
```

## Workflow

1. Confirm auth and target project.
2. Fetch summary metrics and quality gate state.
3. Fetch a scoped issue list for actionable items.
4. Rank findings by risk and fixability.
5. Apply one conservative fix at a time.
6. Run the target repo's tests, lint, and type checks.
7. Trigger or wait for a new Sonar analysis, then re-fetch summary/issues.

## Recommended operations

### 1. Summary first

Use `sonar_fetch_summary.py` to get:

- `bugs`
- `code_smells`
- `vulnerabilities`
- `duplicated_lines`
- `duplicated_lines_density`
- `duplicated_blocks`
- quality gate status

PowerShell:

```powershell
py -3 .config/shared/skills/sonarqube-remediation/scripts/sonar_fetch_summary.py --project-key my-project --branch main
```

### 2. Narrow issue selection

Use `sonar_fetch_issues.py` with filters:

- project scope uses `componentKeys=<project-key>` under the hood
- `--types BUG,CODE_SMELL`
- `--severities BLOCKER,CRITICAL,MAJOR`
- `--statuses OPEN,CONFIRMED,REOPENED`
- `--branch <branch>` when validating branch-specific work

PowerShell:

```powershell
py -3 .config/shared/skills/sonarqube-remediation/scripts/sonar_fetch_issues.py --project-key my-project --types BUG,CODE_SMELL --statuses OPEN,CONFIRMED --max-pages 3
```

### 3. Poll after analysis

Use `sonar_poll_analysis.py` after CI or local scanner execution to wait for a newer analysis before trusting counts.

PowerShell:

```powershell
py -3 .config/shared/skills/sonarqube-remediation/scripts/sonar_poll_analysis.py --project-key my-project --branch main --timeout-seconds 900
```

## Optional tooling

- `SonarQube MCP server`: useful for richer agent workflows, but optional here because MCP is global, not per skill.
- `sonar` CLI: useful if installed locally, but not the required contract for this skill.
- `sonar-scanner`: use for re-analysis, not for primary retrieval.

## When to use the optional agent

Use `.config/shared/agents/sonarqube-remediator.md` when you want an explicit fetch -> fix -> verify loop with strict safety rules.

## Read next

- `.config/shared/skills/sonarqube-remediation/references/auth-and-setup.md`
- `.config/shared/skills/sonarqube-remediation/references/api-usage.md`
- `.config/shared/skills/sonarqube-remediation/references/remediation-policy.md`
- `.config/shared/skills/sonarqube-remediation/references/mcp-optional-setup.md`
