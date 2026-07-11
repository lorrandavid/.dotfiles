---
name: intelligent-diff
description: Performs an intelligent, structured analysis of git diffs and commit logs between two versions, focusing on release impact, architecture, and risk.
---

Analyze git diffs and commit logs to produce actionable release insights.
Your goal is to help teams decide whether a release is safe to deploy.

## Prerequisites

- You have access to:
  - base_version: current production version (tag, branch, or commit SHA)
  - target_version: version that will be deployed
  - diff: raw git diff between the two versions
  - commit_log: commit history between the two versions

- **Important**:
  - Diffs alone are not enough. Use context and intent from commit messages.
  - Do not repeat raw diffs unless strictly necessary.
  - Do not invent hypothetical risks without evidence.

## Output Format

TL;DR
- High-level summary of what changed
- Who should care (backend, frontend, infra, product)
- Overall release risk: Low / Medium / High

----------------------------------------

Walkthrough of Changes

Group changes into logical sections such as:
- API / Contracts
- Business Logic
- Data / Migrations
- Frontend / UX
- Infrastructure / Configuration
- Dependencies / Tooling

For each section:
- Explain what changed
- Explain why it matters

----------------------------------------

Architectural Impact

- Describe any system-level or architectural impact
- Include an ASCII diagram if relevant
- If there is no architectural impact, explicitly state that

Example (only if applicable):

[Client]
   |
[API]
   |
[Service]
   |
[Queue] ---> [Worker]

----------------------------------------

Risk & Bug Analysis

- Highlight potential bugs or regressions
- Flag areas that require extra careful review
- Reference specific commits and files
- Explain realistic failure scenarios

Use the following format:

⚠️ Commit <commit_sha>
- File(s):
- Risk:
- Why this matters in production:

----------------------------------------

Review Checklist

Provide a concise checklist of things that must be verified before release.
Checklist items must be concrete and actionable.

----------------------------------------

## Final Constraints

- Be precise and pragmatic
- Prefer clarity over verbosity
- Treat this as a production readiness assessment

## References

| File | When to Read |
|------|--------------|
| [templates.md](./references/templates.md) | Output formats |
