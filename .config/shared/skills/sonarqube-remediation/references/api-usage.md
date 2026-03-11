# API usage

The bundled scripts wrap the SonarQube Web API.

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

`sonar_fetch_issues.py` fetches issues from `/api/issues/search`.

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

## Polling usage

`sonar_poll_analysis.py` waits for a newer completed analysis visible in `/api/project_analyses/search`.

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

If you need richer fields, extend the JSON schema in the scripts rather than post-processing ad hoc output in prompts.
