# Gruvbuddy Earthy

A dark VS Code color theme port of [TJ DeVries' custom Gruvbuddy palette](https://gist.github.com/tjdevries/165da30ee91824773842653660ce2368).

It keeps Gruvbox's earthy accents while lifting the foreground and UI contrast so the editor does not feel overly dim.

## Install from this dotfiles repository

Run the normal dotfiles linker on Windows:

```powershell
.\dot.ps1 link
```

Then select **Gruvbuddy Earthy** with **Preferences: Color Theme**.

## Package for sharing

From this directory, run:

```sh
npx @vscode/vsce package
```

Install the resulting `.vsix` through **Extensions: Install from VSIX...** or with:

```sh
code --install-extension gruvbuddy-earthy-theme-1.0.0.vsix
```
