# Keep components stateless

**Source:** project rule. Not part of the Angular style guide.

State is complexity. Every field that a component owns is one more value that a reader must track and that can become out of sync. Keep internal state to the minimum that the template needs.

Accept internal state when it is crucial:

- a loading or error flag for the component's own request,
- a value that only the template uses and that no parent can own (for example, an open/closed toggle).

Judgment rule. Show the code and explain why the state is not needed. Mark the finding "Judgment".

## Look for

| Situation | Fix |
|---|---|
| A field or writable signal that can be computed from other fields, inputs, or services | `computed()`, or a getter if the project does not use signals. |
| A field copied from an input and kept in sync (`ngOnChanges`, `effect`, setter) | Read the input directly, or use `computed()` over the input. |
| State that a parent or sibling also needs | Lift it to the parent, a store, or a service, and pass it down with an input. |
| Several unrelated fields that change together | Group them in the smart container, or move the part of the template that uses them to a child component. |
| Many mutable fields in a presentation component | Make it a dumb component: inputs and outputs only. |
| A field that is assigned once and never changes | `readonly`, or a plain constant outside the class. |

## Related principles

- [prefer-declarative-streams](prefer-declarative-streams.md) covers state that `subscribe()` stores.
- [split-large-components](split-large-components.md) covers the smart/dumb split, which is the main way to remove state from a component.

## Not a violation

- A loading, error, or pending flag for the component's own request.
- A form model or a control that the component owns.
- A view-only toggle (menu open, tab selected) that no other component reads.

## Severity

Medium.
