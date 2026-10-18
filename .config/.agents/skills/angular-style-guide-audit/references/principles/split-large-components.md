# Split large components

**Source:** project rule. Not part of the Angular style guide.

A component that loads data and also renders a long template carries two jobs. Split it into a smart container and dumb presentation components.

The script flags components whose class or template exceeds the `componentLimits` values (default: 200 class lines, 150 template lines). See [complexity-budget](complexity-budget.md) for how to run it. Also consider a component large when it exceeds the CDD limit.

- **Smart (container):** injects services or stores, loads data, handles routes, and holds the state. Has a short template that composes child components.
- **Dumb (presentation):** receives data through inputs, reports actions through outputs, does not inject data services, and can be reused or tested without mocks.

## Signs of an opportunity

- The component injects data services and also has a long template.
- Template blocks repeat, or sit inside `@for`/`*ngFor` with a large body.
- Independent visual sections (header, filters, list, detail, form).
- Methods used by only one part of the template.

## Report

The suggestion must be concrete:

- the name of each new component,
- the template block (with line numbers) that moves to it,
- its inputs and outputs,
- what stays in the container.

If the component is large but already presentation-only, with no natural split, record it as an observation, not as a finding.

## Severity

Medium.
