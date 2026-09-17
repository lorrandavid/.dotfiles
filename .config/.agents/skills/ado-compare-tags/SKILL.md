---
name: ado-compare-tags
description: Compare two Azure Repos Git tags, trace tag-only commits to completed pull requests and Azure Boards hierarchy, and present a visual EN or PT-BR deployment-readiness report. Use when deciding what changed between releases and whether the evidence is sufficient to judge a deployment safe.
---

# Compare Azure DevOps Tags

Compare Git reachability in both directions, join the differences to Azure DevOps pull requests and work items, and turn the evidence into a visual deployment review. Treat the operation as read-only.

Use the bundled script for collection. Use the `show-me` skill for presentation. Keep those responsibilities separate:

```text
repository URL + base tag + target tag
  compare_ado_tags.py
    Git reachability in both directions
    stable patch equivalence against the opposite tag
    completed PRs matched by lastMergeCommit
    directly linked work items + parent hierarchy
  structured JSON evidence
    localized visual report
      scope of change
      traceability gaps
      deployment decision checklist
```

The report supports judgment; it does not prove that a release is safe. Tag and Boards metadata do not establish test, pipeline, security, migration, observability, or rollback readiness unless the user supplies separate evidence.

## Inputs

Require:

1. Azure DevOps repository URL
2. Base tag
3. Target tag

Optionally accept a report language:

- `en` — English
- `pt-BR` — Brazilian Portuguese

Accept the language in natural language or as `--language en|pt-BR`; it is a reporting option, not an argument to the collection script. If omitted, use the language of the user's request. If that is ambiguous, use `en`. Ask only for missing required inputs or an unsupported/ambiguous language value.

Interpret the target side as “present in the target tag but absent from the base tag.” Always inspect and display the reverse side too. This makes rollback, backport, and diverged-history differences visible.

Accept HTTPS or SSH Azure Repos URLs. Do not ask for organization, project, or repository names that can be parsed from the URL and verified through Azure DevOps.

## Collect evidence

1. Verify Python 3.10 or newer, `git`, Azure CLI, and the `azure-devops` CLI extension are available. Use the current authenticated session. Never request or expose a PAT.
2. Select the platform's Python launcher without editing the script:
   - Windows: prefer `py -3`; fall back to `python`.
   - macOS/Linux: prefer `python3`; fall back to `python` only when it is Python 3.10 or newer.
3. Run:

   ```text
   <python-launcher> <skill-directory>/scripts/compare_ado_tags.py <repository-url> <base-tag> <target-tag>
   ```

4. Pass arguments through the execution tool's native argument handling. Do not interpolate untrusted values into shell source. Capture stdout as JSON and leave stderr available for progress and diagnostics.
5. If authentication is missing, tell the user how to authenticate securely and stop. Ask before installing the Azure DevOps extension because installation changes their environment.

The script fetches only the requested tags, calculates both commit-set differences, compares non-merge commits by stable Git patch ID, queries Azure DevOps by `lastMergeCommit`, retains completed PRs, gets directly linked work items, follows parent hierarchy links, and deduplicates entities. Do not replace this with PR-title, commit-message, date, or branch-name heuristics.

## Interpret the evidence

Read these fields as authoritative within their stated limits:

- `comparison.relationship`: `baseAncestorOfTarget`, `targetAncestorOfBase`, `diverged`, or `sameCommit`.
- `sides.targetOnly`: evidence present only in the target.
- `sides.baseOnly`: evidence present only in the base.
- `pullRequests[].directWorkItemIds`: work items directly attached to a PR.
- `pullRequests[].workItemPaths`: each direct item followed by its discovered parent chain.
- `workItems[].category`: normalized to `feature`, `story`, `task`, or `other`. User Story, Product Backlog Item, and Requirement are categorized as `story`; preserve the original `type`.
- `commits[].patchStatus`: `new`, `equivalent`, `notApplicable` for merge commits, or `unavailable` when Git cannot derive a patch ID.
- `commits[].equivalentCommitIds`: opposite-tag commits with the same stable patch ID.
- `pullRequests[].changeClassification.status`: `new`, `partiallyAlreadyPresent`, `alreadyPresent`, or `indeterminate`. Traditional merges are classified from the commits introduced by their second parent; squash/rebase merges are classified from the merge commit itself.
- `effectiveCommitCount`, `effectivePullRequestCount`, and `effectiveWorkItemCount`: history-only duplicates excluded from the deployment-oriented counts.
- `unmatchedCommits`: every commit with no PR returned for the exact `lastMergeCommit` query.
- `effectiveUnmatchedCommits`: unmatched commits excluding confirmed patch-equivalent duplicates. Use this field—not all `unmatchedCommits`—when assessing deployment evidence.
- `patchEquivalence.equivalentCommits`: history-only commits whose patch is already reachable from the opposite tag.
- `workItems[].effectivePullRequestIds` and `alreadyPresentPullRequestIds`: whether an item's contributing PRs carry effective changes or only already-present patches.
- `completeness`: collection status and warnings.

Build each side from its own data. Use the effective classification for the primary deployment view while preserving raw reachability counts for audit. Group work items under a Feature only when a returned hierarchy path reaches that Feature. Put items without a discovered Feature ancestor under “Unparented work items” / “Itens sem Feature associada.” Put custom types under `other`; never discard them. A work item appearing through multiple PRs is shown once with every contributing PR.

Preserve source-controlled and Azure DevOps content exactly: tag names, commit hashes, branch names, work-item types, states, titles, PR titles, descriptions, acceptance criteria, and URLs. Localize only report-authored prose, headings, labels, explanations, and checklist text. Do not translate code or source data.

Apply the `bro` skill's writing rule to all report-authored prose and the chat summary: use short, plain sentences; prefer familiar words; remove jargon when it is not needed for accuracy. The renderer's fixed copy already follows this rule. When changing that copy, update the renderer and its tests—never ask the model to rewrite a generated page.

## Assess deployment evidence

Show a prominent decision-support status. Derive it mechanically; do not improvise a safety verdict.

1. **Insufficient evidence / Evidência insuficiente** when either side is incomplete, any warning exists, any effective commit is unmatched, or any effective/indeterminate PR has no directly linked work item. A confirmed patch-equivalent commit without a PR is historical evidence, not an effective traceability gap.
2. **Review divergence / Revisar divergência** when the collection is complete but the tags diverged or the target is an ancestor of the base.
3. **No tag difference / Sem diferença entre tags** when both tags resolve to the same commit.
4. **Review change set / Revisar conjunto de mudanças** for a complete forward comparison, including an empty target-only side.

Never label a release “safe,” “approved,” “go,” or “no-go” from this comparison alone. State what prevents stronger confidence. Clearly separate:

- **Observed:** command-backed Git and Azure DevOps facts.
- **Not evaluated:** tests, pipeline status, security scanning, database/configuration compatibility, monitoring, rollback, approvals, and runtime health unless separate evidence was explicitly collected.
- **Human decision:** whether the observed scope is expected and the unevaluated checks are satisfied.

Surface these risk signals without inventing severity:

- unexpected `baseOnly` content;
- diverged or reversed ancestry;
- effective unmatched commits;
- effective or indeterminate completed PRs without linked work items;
- partially equivalent or indeterminate PR classifications;
- warnings or partial collection;
- requirements with missing descriptions or acceptance criteria;
- custom/unparented work items;
- unusually broad change counts (report the count, but do not define an arbitrary threshold).

## Produce the visual report

Do not ask the model to design or write the report HTML. The versioned template at `assets/report-template.html` is the visual authority for colors, typography, spacing, components, section order, responsive behavior, and localized labels. The deterministic renderer at `scripts/render_ado_report.py` owns the EN/PT-BR copy, escapes dynamic values, and writes strict UTF-8. Never modify the generated HTML per run. Change the checked-in template, renderer copy, and tests when the design or wording must evolve.

After collection:

1. Save the script's exact JSON stdout as a UTF-8 file in the OS temporary directory.
2. Run the renderer with native argument handling:

   ```text
   <python-launcher> <skill-directory>/scripts/render_ado_report.py <evidence-json> --language <en|pt-BR>
   ```

   Omit `--output` to let the renderer create a unique `ado-tag-comparison-*.html` file in the OS temporary directory. Its stdout is the absolute report path.
3. Read the generated file back as strict UTF-8. For PT-BR, verify representative localized text such as `Decisão`, `Evidência` and `Não avaliado` appears unchanged.
4. Apply `show-me` only to present/open the generated artifact; do not let it regenerate or restyle the page.
5. Open the report with the platform-appropriate command. If opening is unavailable, provide the absolute path.

The fixed template works on desktop and mobile and contains, in this order:

1. **Header** — repository, `<base> → <target>`, localized generation context, and links back to Azure DevOps.
2. **Decision-support banner** — one of the four statuses above, a one-sentence reason, and an explicit “human decision required” note.
3. **Relationship visual** — a compact two-lane or branching diagram showing ancestry and both directional differences. Prefer HTML/CSS or inline SVG in the artifact; do not require Mermaid at runtime.
4. **Evidence summary** — show historical and effective counts side by side for target-only/base-only commits and PRs, plus work items, effective unmatched commits, and collection completeness.
5. **Target only** — Feature-first hierarchy for effective and indeterminate PRs with linked IDs, type, title, state, contributing PRs, description, and acceptance criteria when available. Mark partially already-present PRs without hiding them.
6. **Base only** — the same structure, always visible; say “None” / “Nenhum” when empty.
7. **Already present by equivalent patch / Já presente por patch equivalente** — confirmed equivalent commit pairs and fully already-present PRs. Keep links and work items for audit, but do not present them as new deployment scope.
8. **Traceability gaps** — effective unmatched commits, effective/indeterminate PRs without linked work items, warnings, unparented/custom effective items, and missing requirement detail. Keep historical-only unmatched commits visible in the equivalence section rather than treating them as deployment gaps. State “None found” / “Nenhuma encontrada” only when supported by the result.
9. **Deployment checklist** — separate observed facts from items not evaluated. Render unevaluated checks as neutral unchecked items, never as failures.
10. **Method and limitations** — Git reachability, stable patch equivalence, exact merge-commit association, hierarchy derivation, collection timestamp, and the report's safety limitation.

The template keeps the first screen scannable, uses color only as reinforcement, keeps both directional sides visible, and makes detailed descriptions collapsible. Do not override these choices in a generated report.

Also return a concise localized chat summary containing:

- the decision-support status;
- relationship and directional counts;
- the most important traceability gaps;
- the absolute HTML report path.

Do not duplicate the full report in chat unless the HTML artifact cannot be created.

## Language labels

Use consistent terminology.

| Meaning | `en` | `pt-BR` |
|---|---|---|
| Target only | In target only | Somente no destino |
| Base only | In base only | Somente na base |
| Traceability gaps | Traceability gaps | Lacunas de rastreabilidade |
| Already present by equivalent patch | Already present by equivalent patch | Já presente por patch equivalente |
| Historical count | Historical count | Contagem histórica |
| Effective count | Effective count | Contagem efetiva |
| Unparented work items | Unparented work items | Itens sem Feature associada |
| Directly linked | Directly linked | Vinculado diretamente |
| Hierarchy-derived | Hierarchy-derived | Derivado da hierarquia |
| Not evaluated | Not evaluated | Não avaliado |
| Human decision required | Human decision required | Decisão humana necessária |

Write natural Brazilian Portuguese rather than translating English word-for-word. Preserve standard technical names such as Git, tag, commit, pull request, pipeline, Feature, User Story, Product Backlog Item, and Task where translation would make Azure DevOps terminology less recognizable.

## Accuracy rules

- Report only command-backed Azure DevOps and Git facts as observed.
- Treat tag membership as reachability, not chronology or deployment order.
- Call a work item “directly linked” only when returned by the PR work-item endpoint. Label ancestors as hierarchy-derived.
- Do not infer business behavior from titles alone. Summarize descriptions and acceptance criteria when present; otherwise say the detail is unavailable.
- Mention every unmatched commit, but distinguish confirmed patch-equivalent historical commits from effective unmatched commits. Only the latter limits release confidence for new scope.
- If tags diverged, describe two independent histories; never imply that the target is simply newer.
- Treat patch equivalence as strong evidence of a repeated textual change, not proof of identical runtime behavior. Manual rewrites, conflict resolution, combined commits, and surrounding code can prevent or complicate equivalence.
- Never hide partially equivalent or indeterminate PRs from effective scope.
- Keep uncertainty visible. An incomplete report must never sound exhaustive.
- Never mutate repositories, pull requests, work items, tags, branches, or pipelines.
