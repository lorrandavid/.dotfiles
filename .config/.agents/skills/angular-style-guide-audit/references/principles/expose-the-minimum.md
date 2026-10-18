# Expose the minimum

**Guide sections:**

- Use `protected` on class members that are only used by a component's template
- Use `readonly` for properties that shouldn't change

Public members are API. Only inputs, outputs, and models are meant to be public on a component. Everything else is narrower, and Angular-initialized properties are fixed.

## Look for

| Guide section | What to look for |
|---|---|
| Use `protected` on class members that are only used by a component's template | Members without a modifier or with `public` that the template uses and no other file uses. Search for the name in other files before you report. |
| Use `readonly` for properties that shouldn't change | `input()`, `input.required()`, `model()`, `output()`, `viewChild()`, `viewChildren()`, `contentChild()`, `contentChildren()`, `@Output()`, `@ViewChild(ren)`, `@ContentChild(ren)` without `readonly`. |

## Not a violation

- `protected` does not apply to inputs, outputs, and models. They are the public API.
- `@Input()` without `readonly` is correct. In the decorator API, `readonly` applies only to `@Output` and queries.

## Severity

- High: a property that Angular initializes and the code overwrites, without `readonly`.
- Medium: public members used only by the template.
- Low: missing `readonly` without reassignment.
