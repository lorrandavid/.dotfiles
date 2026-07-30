# Angular 18 migration playbook

Load only the sections matching dependencies or failures discovered during the upgrade.

## Angular Material legacy to MDC

Angular Material 17 removes legacy components. While Material 16 is still installed, run the official migration schematic:

```bash
npx ng generate @angular/material:mdc-migration
```

Resolve every schematic finding, then search exhaustively before installing Material 17:

```bash
rg "@angular/material/legacy-|MatLegacy|MAT_LEGACY|all-legacy-component|legacy-core" .
```

Use the official MDC migration guide and migrate all reported components. Typical TypeScript replacements include:

```typescript
// Legacy
import { MatLegacyDialogModule as MatDialogModule } from '@angular/material/legacy-dialog';
import { MatLegacyButtonModule as MatButtonModule } from '@angular/material/legacy-button';
import { MatLegacyCardModule as MatCardModule } from '@angular/material/legacy-card';
import { MatLegacyInputModule as MatInputModule } from '@angular/material/legacy-input';

// MDC
import { MatDialogModule } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatInputModule } from '@angular/material/input';
```

Dialogs change from:

```typescript
import {
  MatLegacyDialog as MatDialog,
  MatLegacyDialogRef as MatDialogRef,
  MAT_LEGACY_DIALOG_DATA as MAT_DIALOG_DATA,
} from '@angular/material/legacy-dialog';
```

to:

```typescript
import { MAT_DIALOG_DATA, MatDialog, MatDialogRef } from '@angular/material/dialog';
```

Ensure `MatDialogModule` is imported wherever the dialog API is used. Replace legacy typography/core mixins:

```scss
// Remove:
@include mat.all-legacy-component-typographies();
@include mat.legacy-core();

// Use the supported core setup once:
@include mat.core();
```

MDC changes internal DOM and CSS classes from many `mat-*` selectors to `mat-mdc-*`. Prefer supported theme tokens and component APIs. Treat hard-coded global overrides and `!important` rules as project-specific last resorts, not automatic migration steps. Compare radio buttons, buttons, dialogs, and form fields against the pre-upgrade application and document every intentional visual difference.

References:

- <https://material.angular.io/guide/mdc-migration>
- <https://angular.dev/update-guide>

## ng-bootstrap accordion v17

Symptom:

```text
Cannot destructure property 'ngbCollapse' of 'this._collapse' as it is undefined
```

The accordion API changed in ng-bootstrap 17. Update API assertions:

```typescript
// <=16
expect(spy.collapseAll).toHaveBeenCalled();
expect(spy.expandAll).toHaveBeenCalled();

// 17+
expect(spy.closeAll).toHaveBeenCalled();
expect(spy.openAll).toHaveBeenCalled();
```

A test failing during `fixture.detectChanges()` may have an incomplete accordion test bed. Prefer completing the test fixture with required declarations/providers or testing component logic at a shallower seam when rendering is outside the test's purpose; do not remove change detection merely to hide a production rendering defect.

Reference: <https://ng-bootstrap.github.io/#/components/accordion/overview>

## Apollo testing collision

Symptom: `Apollo has been already created`.

`SharedModule` may register the production Apollo instance while `ApolloTestingModule` registers another. In Apollo unit tests, import `ApolloTestingModule`, remove the broad `SharedModule`, and add only the specific modules the fixture needs.

Removing `SharedModule` can expose missing imports. For a missing translate pipe, add the translation module explicitly:

```typescript
imports: [
  TranslateModule.forRoot({
    loader: { provide: TranslateLoader, useClass: TranslateFakeLoader },
  }),
]
```

## Network error assertions

If an upgraded client now exposes the message, update the assertion only after confirming runtime behavior is intended:

```typescript
expect(error.message).toBe('Network Error');
```

Do not mechanically replace an expectation of `undefined`; verify that the public error contract changed.

## ngx-mask

Symptom: `No pipe found with name 'mask'`.

For ngx-mask 18's standalone exports, import the used directive and pipe and provide its configuration at the correct injector:

```typescript
import { NgxMaskDirective, NgxMaskPipe, provideNgxMask } from 'ngx-mask';

@NgModule({
  imports: [NgxMaskDirective, NgxMaskPipe],
  providers: [provideNgxMask()],
})
export class FeatureModule {}
```

Avoid duplicate providers when configuration already exists at bootstrap/root.

## TSLint to ESLint

Detect first:

```bash
rg '"(tslint|codelyzer)"' package.json
```

When present:

```bash
npx ng add @angular-eslint/schematics
npm uninstall tslint codelyzer tslint-config-prettier
```

Remove `tslint.json` after confirming all needed rules are represented and the lint command passes. If Angular ESLint peer resolution requires the versions validated in the source playbook, its known combination was:

```bash
npm install --save-dev eslint@8.57.0 \
  @typescript-eslint/eslint-plugin@7.18.0 \
  @typescript-eslint/parser@7.18.0
```

Use that combination only when it agrees with the installed `@angular-eslint` peer ranges; the omitted internal compatibility JSON may supersede it.

## Lockfile and dependency resolution

For an out-of-sync lockfile, first run `npm install` and inspect the diff. If the lockfile remains irreparable:

```bash
rm package-lock.json
npm install
npm ci
```

Deleting the lockfile is a recovery action because it can cause broad transitive churn. Review the regenerated diff.

For peer conflicts, identify the conflicting package and install a compatible release. `--legacy-peer-deps` is a temporary diagnostic/recovery option, not final proof of compatibility.

## Private npm registries

Inspect `.npmrc` by querying registry keys or reading a redacted copy; never print the file wholesale because it may contain live credentials. Redact `_auth`, `_authToken`, passwords, and embedded URL credentials from command output. Preserve required scopes and use environment-variable token references. A minimal shape may be:

```ini
@fortawesome:registry=https://npm.fontawesome.com/
//npm.fontawesome.com/:_authToken=${FONTAWESOME_TOKEN}
registry=https://registry.npmjs.org/
```

Never replace a valid Azure Artifacts configuration merely because it differs from this example, and never commit literal tokens.

## Other project-specific checks

- `CommonModule` must be imported by NgModules that use its directives and pipes.
- Verify polyfills against actual browser support and application needs.
- Install `@types/node` only where Node APIs/types are actually consumed.
- The source playbook associates a `PdfViewerModule` dependency with version `9.1.5` but does not identify the package. Find the module's import source, then verify that exact package's Angular 18 peer support before selecting a version.
- Ensure application dependency versions are exact when organizational policy requires reproducible pins; distinguish npm semver prefixes from URLs, aliases, and non-version strings rather than applying a blind text replacement.
