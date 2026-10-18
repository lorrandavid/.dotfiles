# Prefer composition over inheritance

**Source:** project rule. Not part of the Angular style guide.

Inheritance couples a class to the hidden behavior of its base class. A change in the base class can break every subclass. Compose behavior instead: inject a service, apply a host directive, or put a child component in the template.

Search starting point: `rg "extends " --glob "*.ts"`. Read each hit. Ignore `interface X extends Y` and generic constraints (`T extends Y`).

## Look for

| Situation | Fix |
|---|---|
| A component or directive that extends a custom base component or directive | Move the shared logic to an `inject()` service or a function, or apply a host directive (`hostDirectives`). Move shared markup to a child component. |
| A custom abstract base class that several components extend to share fields and methods | Same fix. Each component keeps only what it uses. |
| A service that extends another service to reuse methods | Inject the other service, or extract the shared code to a function. |
| A subclass that overrides base methods to change behavior | Pass the varying part as an input, a function, or an injection token. |

## Not a violation

- Extending a framework or library class that the API requires (for example `Error`, or an abstract class that a library defines for you to implement).
- `implements` of an interface, including lifecycle interfaces.
- A base class that holds no state and no behavior, kept only as a type.

## Severity

Medium.
