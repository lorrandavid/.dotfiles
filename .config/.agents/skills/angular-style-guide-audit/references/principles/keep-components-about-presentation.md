# Keep components about presentation

**Guide sections:**

- Keep components and directives focused on presentation
- Avoid overly complex logic in templates
- Keep lifecycle methods simple

A component connects data to the screen. Rules that do not depend on the UI belong where they can be tested without it.

All three sections are **judgment** rules. They have no exact threshold. Show the code, explain why it looks complex, and mark the finding "Judgment".

## Look for

| Guide section | What to look for | Fix |
|---|---|---|
| Keep components and directives focused on presentation | Form validation, data transformation, or business rules inside the component that do not depend on the UI. | Name the destination: pure function, validator, or service. |
| Avoid overly complex logic in templates | Expressions with several operators, nested ternaries, call chains, or calculations in the template. | `computed()`, or a getter if the project does not use signals. |
| Keep lifecycle methods simple | `ngOnInit`, `ngOnChanges`, `ngAfterViewInit`, and other hooks with long logic instead of calls to methods with clear names. | Extract methods with names that say what they do. |

## Related project principles

Size and cognitive load of a component are measured, not judged. See [complexity-budget](complexity-budget.md) and [split-large-components](split-large-components.md). For internal state, see [keep-components-stateless](keep-components-stateless.md).

## Severity

- Medium: logic outside the UI in a component.
- Low: template expressions, lifecycle methods.
