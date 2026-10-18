# Choose names that cannot clash

**Guide sections:**

- Choosing component selectors
- Choosing directive selectors
- Naming component and directive members

Selectors, inputs, and outputs are public API in the template. A name that collides with the platform or with another library causes bugs that are hard to see.

## Look for

| Guide section | What to look for |
|---|---|
| Choosing component selectors | Element selector without a hyphen. Prefix different from the project prefix. The `ng` prefix (the guide says "Never"). |
| Choosing directive selectors | Directive without the project prefix. Attribute selector not in camelCase (`[mr-tooltip]` instead of `[mrTooltip]`). |
| Naming component and directive members | Inputs or outputs named like a DOM property or event (`click`, `change`, `focus`, `blur`, `submit`, `input`, `title`, `hidden`, `id`, `style`, `value` on elements that already have them). Inputs/outputs with a prefix (`appValue`). Outputs with an `on` prefix (`onSave`) or not in camelCase. |

Learn the project prefix from `angular.json` and the most frequent selector prefix before you report.

## Severity

- High: `ng` prefix, and input or output that clashes with a DOM property or event. The native event also fires the handler.
- Medium: selector without the project prefix, selector without a hyphen.
- Low: `on` prefix, input or output prefix, attribute selector casing.
