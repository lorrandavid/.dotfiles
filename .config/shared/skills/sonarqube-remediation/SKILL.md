---
name: sonarqube-remediation
description: Fetch and triage SonarQube issues and measures for conservative remediation work. Use when you need SonarQube Server data such as bugs, code smells, duplicated lines, or quality gate status.
references:
  - references/auth-and-setup.md
  - references/api-usage.md
  - references/remediation-policy.md
  - references/mcp-optional-setup.md
---

# SonarQube Remediation

Use this skill when SonarQube should be the source of findings for conservative code cleanup.

## Scope

- Use the bundled REST helper scripts to retrieve SonarQube data.
- Treat SonarQube Server as the source of findings.
- Keep tokens, `.env` files, and machine-local MCP config out of commits.
- Use this skill for data gathering, issue triage inputs, helper commands, and SonarQube-specific reference material.
- Leave remediation orchestration, local verification, commit creation, PR creation, and cleanup decisions to the calling agent.

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

### 3. Interpret the results conservatively

- Prefer explicitly requested issue keys when provided by the caller.
- Otherwise favor small, local, low-risk fixes over broad cleanup.
- Be cautious with auth, crypto, access control, data migrations, and large cross-package duplication work.
- If helper output disagrees with the UI or raw API data, stop and reconcile the mismatch before changing code.

## Optional tooling

- `SonarQube MCP server`: useful for richer agent workflows, but optional here because MCP is global, not per skill.
- `sonar` CLI: useful if installed locally, but not the required contract for this skill.
- `sonar-scanner`: optional for CI-managed analysis, not required for this skill's local workflow.

## Read next

- `.config/shared/skills/sonarqube-remediation/references/auth-and-setup.md`
- `.config/shared/skills/sonarqube-remediation/references/api-usage.md`
- `.config/shared/skills/sonarqube-remediation/references/remediation-policy.md`
- `.config/shared/skills/sonarqube-remediation/references/mcp-optional-setup.md`
