# Consistency over convention

**Guide section:** When in doubt, prefer consistency.

A file must not mix conventions. When the guide contradicts the style of a file, keep the style of the file. Mixed styles confuse readers more than a deviation from the guide.

This principle is a filter on every other principle. Apply it before you report a finding.

## Rules

- Do not recommend that one member of a file follow the guide if the rest of the file follows another style. Recommend the whole file, or nothing.
- If the project mixes two conventions across files (for example, with and without the `.component` suffix), report the mix once as an inconsistency. Do not report each file.
- A project-wide convention that differs from the guide is a low-severity note, not a violation in each file.

## Severity

Low.
