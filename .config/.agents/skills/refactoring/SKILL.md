---
name: refactoring
description: Refactor code with a pinned behavior contract. The structure changes, the behavior does not. Use when the user asks to refactor, restructure, reshape, simplify, or clean up code without changing what it does.
---

# Refactoring

Adapted from the pstack refactoring playbook by Lauren Tan (MIT, see [references/LICENSE-pstack](references/LICENSE-pstack)). Subagent delegation and forced model settings were removed. Do the work in this session, with the model the user chose.

**You own the contract. The structure changes. The behavior does not.** Refactoring is distinct from a feature, which adds behavior, and from a bug fix, which corrects it.

If the cleanup reveals a missing feature or a real bug, split it out and ship the structural change first against the pinned contract. A redesign is allowed, but name it and tell the user it is a feature, not a refactor.

## Principles

Read the principle file when its step applies. Each file is short.

| Principle | Read it at step |
| --- | --- |
| [model-the-domain](references/model-the-domain.md) | 2 |
| [foundational-thinking](references/foundational-thinking.md) | 3 |
| [redesign-from-first-principles](references/redesign-from-first-principles.md) | 3 |
| [subtract-before-you-add](references/subtract-before-you-add.md) | 4 |
| [laziness-protocol](references/laziness-protocol.md) | 4 |
| [migrate-callers-then-delete-legacy-apis](references/migrate-callers-then-delete-legacy-apis.md) | 5 |
| [prove-it-works](references/prove-it-works.md) | 6 |
| [minimize-reader-load](references/minimize-reader-load.md) | 7 |
| [build-the-lever](references/build-the-lever.md) | 5, 6 |
| [sequence-verifiable-units](references/sequence-verifiable-units.md) | 8 |

Optional: for a large reshape that needs an auditable trail, keep a decision log per [show-me-your-work](references/show-me-your-work/show-me-your-work.md).

## Steps

1. **Pin the behavior contract first.** Read the affected subsystem to learn the contract: callers, inputs, outputs, side effects. Then write a characterization test, snapshot, or equivalence harness that captures current behavior before any structure moves. If the area has no coverage, write the pin before you touch structure. Type check and lint are not a pin.
2. **Name the structure the code is missing**, per model-the-domain. Boring code stays when the shape is already clear and local. The reshape must delete branches or invalid states, not add indirection.
3. **Name the target shape.** State what the module layout, types, and call graph should be if built today (foundational-thinking, redesign-from-first-principles). If the target crosses a function boundary and more than one shape is plausible, compare the options and recommend one before you move code.
4. **Subtract before you add.** Delete dead code, collapse one-caller wrappers, drop redundant validators, and remove orphan references before you introduce the new shape. The smallest change that reaches the target shape ships (laziness-protocol). A speculative cleanup that "might help" gets reverted.
5. **Move in small behavior-preserving steps, each keeping the pin green.** For API reshapes, migrate every caller and delete the old API in the same wave. No compatibility shims, no parallel old-and-new paths. Spot-check every rename against the actual files. Renames silently miss usages in strings, prose, and back-references.
6. **Prove behavior is unchanged on the real artifact**, not "it compiles" (prove-it-works). For larger reshapes, run an equivalence check: a script that diffs old-vs-new outputs, a recorded baseline replayed against the new code, or a smoke run of the real app. Then run typecheck, lint, and the relevant tests.
7. **Confirm the change is worth keeping.** The success measure is reduced reader load (minimize-reader-load). If the diff does not lower reader load somewhere, revert it.
8. **Propose small ordered commits.** A subtraction commit, then the reshape, then any follow-on cleanup. Each slice stays green before the next (sequence-verifiable-units). Do not commit, push, or open a PR unless the user asks.

## Reply

Report these items. Add no new behavior.

- The structure that changed
- The pin you held it against
- The equivalence proof
- The reader-load delta
- What shipped and what you reverted
