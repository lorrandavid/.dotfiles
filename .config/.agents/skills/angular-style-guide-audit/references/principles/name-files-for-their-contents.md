# Name files for their contents

**Guide sections:**

- Separate words in file names with hyphens
- Use the same name for a file's tests with `.spec` at the end
- Match file names to the TypeScript identifier within
- Use the same file name for a component's TypeScript, template, and styles

A reader must find a class from its file name, and find the template, styles, and test of a component from the name of its `.ts` file.

## Look for

| Guide section | What to look for |
|---|---|
| Separate words in file names with hyphens | `.ts`, `.html`, `.css`, and `.scss` files with camelCase, PascalCase, or `_` in the name. |
| Use the same name for a file's tests with `.spec` at the end | Tests with `.test.ts` or with a name different from the tested file. |
| Match file names to the TypeScript identifier within | Main class with a name different from the file. Generic files: `utils.ts`, `helpers.ts`, `common.ts` (with or without a folder prefix). |
| Use the same file name for a component's TypeScript, template, and styles | `templateUrl`/`styleUrl(s)` that point to names different from the `.ts` file. Extra style file without a word that describes its content. |

## Not a violation

- Type suffixes. `UserProfileComponent` in `user-profile.component.ts` complies, as does `UserProfile` in `user-profile.ts`. Report only when the name does not match the class (for example, `PaymentFormComponent` in `checkout.component.ts`).

## Severity

- Medium: file name that does not match its class, generic file name.
- Low: casing, `.spec` suffix, style file names.
