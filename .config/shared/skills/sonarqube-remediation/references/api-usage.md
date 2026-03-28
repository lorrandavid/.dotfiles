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

## Duplication endpoint usage

`sonar_fetch_duplications.py` combines three SonarQube APIs into a single structured output:

1. `/api/measures/component` — project-level `ncloc`, `duplicated_lines`, `duplicated_lines_density`
2. `/api/measures/component_tree` — per-file metrics sorted by `duplicated_lines` descending
3. `/api/duplications/show` — block-level detail for each file (which lines, which peer component)

### Parameters

- `--project-key` (required): SonarQube project key
- `--branch`: branch name
- `--pull-request`: PR identifier
- `--buffer-percent` (default: 20): buffer for removal target calculation
- `--max-files` (default: 10): how many top files to fetch duplication details for
- `--page-size` (default: 50): page size for component tree queries

### Example

```bash
python3 .config/shared/skills/sonarqube-remediation/scripts/sonar_fetch_duplications.py \
  --project-key my-project \
  --branch main \
  --max-files 15 \
  --buffer-percent 25
```

```powershell
py -3 .config/shared/skills/sonarqube-remediation/scripts/sonar_fetch_duplications.py `
  --project-key my-project `
  --branch main `
  --max-files 15 `
  --buffer-percent 25
```

### Output shape

```json
{
  "project": { "key": "...", "branch": "..." },
  "overview": {
    "total_duplicated_lines": 678,
    "total_loc": 12345,
    "current_density_percent": 5.49,
    "target_density_percent": 2.49,
    "target_duplicated_lines": 307,
    "raw_lines_to_remove": 371,
    "buffer_percent": 20,
    "effective_lines_to_remove": 446
  },
  "files": [
    {
      "key": "project:src/foo.ts",
      "path": "src/foo.ts",
      "duplicated_lines": 120,
      "ncloc": 500,
      "duplications": [
        {
          "blocks": [
            { "component_key": "project:src/foo.ts", "component_name": "foo.ts", "from_line": 10, "size": 30 },
            { "component_key": "project:src/bar.ts", "component_name": "bar.ts", "from_line": 45, "size": 30 }
          ]
        }
      ]
    }
  ]
}
```

### Removal target calculation

The `overview.effective_lines_to_remove` includes a buffer that accounts for refactoring
side effects. When you extract shared code, the new shared module may itself register as
a small duplication block. The buffer (default 20%) ensures you aim to remove enough
lines that the net result still meets the target even after new minor duplications appear.

### Raw API parity

Component tree (files sorted by duplicated lines):

```bash
curl -s -u "$SONARQUBE_TOKEN:" \
  "$SONARQUBE_URL/api/measures/component_tree?component=my-project&metricKeys=duplicated_lines,ncloc&s=metric&metricSort=duplicated_lines&metricSortFilter=withMeasuresOnly&asc=false&qualifiers=FIL&ps=50"
```

File duplication blocks:

```bash
curl -s -u "$SONARQUBE_TOKEN:" \
  "$SONARQUBE_URL/api/duplications/show?key=project:src/foo.ts"
```
