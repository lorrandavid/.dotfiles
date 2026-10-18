# Bind `class` and `style` directly

**Guide section:** Prefer `class` and `style` over `ngClass` and `ngStyle`

Native `[class]` and `[style]` bindings are simpler, need no import, and are the platform way.

## Look for

`[ngClass]`, `[ngStyle]`, `NgClass`, or `NgStyle` in `imports`.

## Fix

Replace with `[class.name]="cond"`, `[class]="expr"`, `[style.prop]="value"`, or `[style]="expr"`. Remove the unused import.

## Severity

Low.
