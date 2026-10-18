# Name handlers for what they do

**Guide section:** Name event handlers for what they _do_, not for the triggering event

`saveUser` tells the reader the effect. `handleClick` forces the reader to open the method.

## Look for

Handlers such as `handleClick`, `onClick`, `onSubmit`, `onChange`, `clicked`.

## Not a violation

- `handleKeydown` is correct when the handler is long and delegates to methods with specific names. Accept a generic name when the handler delegates by event type.

## Severity

Low.
