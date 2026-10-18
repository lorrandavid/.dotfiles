# Declare in reading order

**Guide sections:**

- Group Angular-specific properties before methods
- Use lifecycle hook interfaces

A reader learns the contract of a component (what it injects, takes in, emits, and queries) before the behavior. A lifecycle interface states the contract of a hook in the class signature.

## Look for

| Guide section | What to look for |
|---|---|
| Group Angular-specific properties before methods | Injections, inputs, outputs, or queries declared after methods or mixed in among them. |
| Use lifecycle hook interfaces | Class with `ngOnInit`, `ngOnDestroy`, `ngOnChanges`, and so on, without the matching `implements`. |

## Severity

Low.
