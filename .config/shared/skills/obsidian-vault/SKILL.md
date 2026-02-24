---
name: obsidian-vault
description: Guidelines for organizing and using the Obsidian Vault for AI research notes.
---

# Obsidian Vault

## Vault location

Use a user-provided vault path/link per session (`<VAULT_PATH>`), since it can differ between machines.
If the user has not provided it yet, ask for it before running any vault operation.

Examples:
- Personal PC: `D:\Obsidian Vault\AI Research\`
- Work PC: `E:\Work Obsidian\AI Research\`

## Naming conventions

- **Index notes**: aggregate related topics (e.g., `Ralph Wiggum Index.md`, `Skills Index.md`, `RAG Index.md`)
- **Title case** for all note names
- No folders for organization - use links and index notes instead

## Linking

- Use Obsidian `[[wikilinks]]` syntax: `[[Note Title]]`
- Notes link to dependencies/related notes at the bottom
- Index notes are just lists of `[[wikilinks]]`

## Workflows

### Search for notes

```bash
# Search by filename
find "<VAULT_PATH>" -name "*.md" | grep -i "keyword"

# Search by content
grep -rl "keyword" "<VAULT_PATH>" --include="*.md"
```

Or use Grep/Glob tools directly on the vault path.

### Create a new note

1. Use **Title Case** for filename
2. Write content as a unit of learning (per vault rules)
3. Add `[[wikilinks]]` to related notes at the bottom
4. If part of a numbered sequence, use the hierarchical numbering scheme

### Find related notes

Search for `[[Note Title]]` across the vault to find backlinks:

```bash
grep -rl "\\[\\[Note Title\\]\\]" "<VAULT_PATH>"
```

### Find index notes

```bash
find "<VAULT_PATH>" -name "*Index*"
```
