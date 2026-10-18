# Organize by feature

**Guide sections:**

- All the application's code goes in a directory named `src`
- Bootstrap your application in a file named `main.ts` directly inside `src`
- Group closely related files together in the same directory
- Organize your project by feature areas
- One concept per file

Code that changes together lives together. A reader opens one folder to see one feature, and one file to see one concept.

## Look for

| Guide section | What to look for |
|---|---|
| All the application's code goes in a directory named `src` | UI code outside `src/`. |
| Bootstrap your application in a file named `main.ts` directly inside `src` | `bootstrapApplication`/`bootstrapModule` outside `src/main.ts`. |
| Group closely related files together in the same directory | Template or style in a different folder from the `.ts` file. A `tests/` or `__tests__/` folder with tests for code in other folders. |
| Organize your project by feature areas | Folders by type: `components/`, `directives/`, `services/`, `pipes/`, `models/`, `guards/`, `interceptors/`. Folders with so many files that they are hard to navigate (count the files and cite the number). |
| One concept per file | Files with more than one `@Component`/`@Directive`/`@Injectable`/`@Pipe`. |

## Not a violation

- Several small classes in one file that form a single concept (for example, `Seat` and `SeatMap`). Report only when the classes are unrelated or the file is large. When in doubt, the guide prefers smaller files: report it as low and explain.

## Severity

Medium. Folder moves change import paths, so list them before the smaller fixes in "Next steps".
