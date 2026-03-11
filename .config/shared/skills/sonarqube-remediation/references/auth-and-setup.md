# Auth and setup

Use environment variables only.

## Required variables

```bash
export SONARQUBE_URL="https://sonarqube.example.com"
export SONARQUBE_TOKEN="<token>"
```

```powershell
$env:SONARQUBE_URL = "https://sonarqube.example.com"
$env:SONARQUBE_TOKEN = "<token>"
```

## Auth model

- The helper scripts authenticate the same way as `curl -u "$SONARQUBE_TOKEN:"`
- They send `Authorization: Basic base64("<token>:")`
- Generate a user token with browse access to the target project
- Never place tokens in repo files or command history screenshots

Raw API parity check:

```bash
curl -s -u "$SONARQUBE_TOKEN:" \
  "$SONARQUBE_URL/api/issues/search?componentKeys=my-project&types=BUG&statuses=OPEN&ps=100"
```

## Prerequisites

- Python 3.10+ for the bundled scripts
- Access to the SonarQube project
- A known Sonar project key
- On Windows, PowerShell 5.1+ or PowerShell 7+ with `py -3` or `python` on `PATH`

## Optional local tools

Official Sonar tooling that may help:

- `sonar` CLI: newer unified Sonar CLI with auth, list, analyze, and integrate commands
- `sonar-scanner`: standard scanner for running analyses

Use them as local conveniences only. The bundled scripts remain the stable skill contract.

## Safe setup checklist

1. Export env vars in your shell profile or a local secret manager.
2. Verify access with a read-only request:

```bash
python3 .config/shared/skills/sonarqube-remediation/scripts/sonar_fetch_summary.py --project-key <project-key>
```

```powershell
py -3 .config/shared/skills/sonarqube-remediation/scripts/sonar_fetch_summary.py --project-key <project-key>
```

3. If the token expires, rotate it outside the repo and update only your local environment.

## Scope guidance

- Default to project-level reads.
- Add `--branch` or `--pull-request` only when you specifically need branch or PR analysis.
