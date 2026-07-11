# Optional MCP setup

The official SonarQube MCP server is a good enhancement path for richer agent workflows, but it should stay optional for this repo.

## Why optional

- per-skill MCP is not supported here
- MCP config is global or user-local
- the REST helper scripts already cover the core read and verify workflow

## When MCP helps

- interactive agent sessions that query Sonar repeatedly
- tool-native issue browsing without custom script flags
- future autonomous flows that benefit from richer tool contracts

## Repo-specific guidance

- keep MCP config outside shared skill files
- use env vars for tokens and server URL
- do not hardcode credentials into `.config/opencode/opencode.json`
- keep PowerShell-specific local setup in user docs or profile snippets, not in shared repo config

## Recommended order

1. Get the REST workflow working first.
2. Validate project access and remediation loop.
3. Add MCP locally if you want a richer developer experience.

## Official tooling notes

- SonarSource provides an official SonarQube MCP server.
- It supports SonarQube Server and SonarCloud.
- It adds runtime prerequisites that this shared skill intentionally avoids.
