# API usage

The bundled scripts wrap the SonarQube Web API.

## Preferred execution model

Unless you are already inside a dedicated fetch subagent, do not run these commands in the main agent. Pass the exact helper command to a narrow execution-oriented subagent so raw JSON, pagination detail, and mismatch checks stay out of the main context window.

## Summary endpoint usage

`sonar_fetch_summary.py` fetches measures from `/api/measures/component` and quality gate state from `/api/qualitygates/project_status`.

Default metric keys:

- `bugs`
- `code_smells`
- `vulnerabilities`
- `duplicated_lines`
- `duplicated_lines_density`
- `duplicated_blocks`
- `ncloc`
- `reliability_rating`
- `security_rating`
- `sqale_rating`

Example:

```bash
python3 .config/shared/skills/sonarqube-remediation/scripts/sonar_fetch_summary.py \
  --project-key my-project \
  --branch main
```

```powershell
py -3 .config/shared/skills/sonarqube-remediation/scripts/sonar_fetch_summary.py `
  --project-key my-project `
  --branch main
```

## Issues endpoint usage

`sonar_fetch_issues.py` fetches issues from `/api/issues/search` and scopes project results with `componentKeys`.

Useful filters:

- `--types BUG,CODE_SMELL,VULNERABILITY`
- `--severities BLOCKER,CRITICAL,MAJOR`
- `--statuses OPEN,CONFIRMED,REOPENED`
- `--assignees <login1,login2>`
- `--created-after YYYY-MM-DD`
- `--max-pages N`

Example:

```bash
python3 .config/shared/skills/sonarqube-remediation/scripts/sonar_fetch_issues.py \
  --project-key my-project \
  --types BUG,CODE_SMELL \
  --statuses OPEN,CONFIRMED \
  --max-pages 3
```

```powershell
py -3 .config/shared/skills/sonarqube-remediation/scripts/sonar_fetch_issues.py `
  --project-key my-project `
  --types BUG,CODE_SMELL `
  --statuses OPEN,CONFIRMED `
  --max-pages 3
```

Equivalent raw API request:

```bash
curl -s -u "$SONARQUBE_TOKEN:" \
  "$SONARQUBE_URL/api/issues/search?componentKeys=my-project&types=BUG,CODE_SMELL&statuses=OPEN,CONFIRMED&ps=100"
```

## Polling usage

`sonar_poll_analysis.py` waits for a newer completed analysis visible in `/api/project_analyses/search`.

Run polling in a narrow execution-oriented subagent as well, because it can emit repeated status output while it waits.

Use it after:

- CI finishes a Sonar analysis
- local `sonar-scanner` run starts a new analysis

Example:

```bash
python3 .config/shared/skills/sonarqube-remediation/scripts/sonar_poll_analysis.py \
  --project-key my-project \
  --branch main \
  --timeout-seconds 900
```

```powershell
py -3 .config/shared/skills/sonarqube-remediation/scripts/sonar_poll_analysis.py `
  --project-key my-project `
  --branch main `
  --timeout-seconds 900
```

## Output contract

The scripts return compact JSON so an agent can:

- rank findings deterministically
- avoid scraping HTML or UI text
- compare before/after metrics

When using the preferred subagent flow, have the fetch subagent return the raw compact JSON plus only the smallest useful summary for the main agent.

If you need richer fields, extend the JSON schema in the scripts rather than post-processing ad hoc output in prompts.
