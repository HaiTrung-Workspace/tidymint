# Contributing to Tidymint

Thanks for taking the time. Tidymint is a small project, so a clear report or a small, focused change helps the most.

## Report a bug or suggest something

Open an issue with the forms on the [Issues page](https://github.com/HaiTrung-Workspace/tidymint/issues/new/choose). For a bug, say what you clicked, what you expected and what happened, plus your macOS version and Tidymint version (Settings shows it).

For a security problem, do not open a public issue. See [SECURITY.md](.github/SECURITY.md).

## Build it

You need macOS 14 or later and the Xcode Command Line Tools (`xcode-select --install`). There is no Xcode project.

```sh
./build.sh            # builds build/Tidymint.app
./build.sh --install  # builds and copies it to /Applications
```

## Find your way around

[Sources/README.md](Sources/README.md) has the rules and a map of every file. In short:

| Folder | What lives there |
|---|---|
| `Sources/App` | Start-up, window, shared state |
| `Sources/Core` | Data model, settings, scanning, the Trash and Undo, network |
| `Sources/UI` | Colours, text sizes, reusable views |
| `Sources/Clean` | Finding and cleaning files |
| `Sources/Apps` | Uninstaller, Startup items |
| `Sources/Tools` | Mintangle, Mintdrop |
| `Sources/More` | Settings, Stats, Contact |
| `docs`, `tools` | The website and the scripts that build it |

## Rules a change must keep

1. Files a person owns only move through `VM.trash`, so everything lands in the Trash and Undo can bring it back. Nothing is deleted directly.
2. Nothing risky is ticked for the user: project folders, anything holding a database, anything in use.
3. No new network request. If one is truly needed, it is described in [PRIVACY.md](PRIVACY.md) in the same change.
4. Every user-facing string has English and Vietnamese: `t("English", "Tiếng Việt")`.
5. A new source file is added to the map in `Sources/README.md`.

## Send a pull request

Keep it to one thing. Say what changes for the user, and tick the checklist in the pull request form. Try the changed screen on a real Mac before you send it.

By contributing you agree that your work is released under the [MIT License](LICENSE).
