# Sources

How the app code is organised. Read this before adding a file or a feature.

## Rules

1. **One feature per file.** Logic and its page live together (for example `Apps/Apps.swift` holds the Uninstaller model and its page). Shared building blocks go in `UI/Components.swift`.
2. **Seven folders, one level deep.** `build.sh` compiles every `.swift` file under `Sources/`. File names stay unique across folders (tools look files up by name). A new file goes in the folder of its feature area; do not add a folder for a single file.
3. **Everything that moves user files goes through `Trash.swift`.** Call `VM.trash(...)`; never call `trashItem` or `removeItem` on a user's file from another file. `removeItem` is only for files the app created itself (its own history, temporary preview links, `.DS_Store`), with a comment saying why.
4. **Network only in `Network.swift` and `Contact.swift`.** Two paths exist: the update check (can be turned off) and the form the user sends. See `PRIVACY.md`.
5. **Unreleased features** sit behind a `dev-...` flag and in their own file. A hidden flag still publishes the code, so a feature that must stay secret is not in the release branch at all.
6. **Size.** When a file passes about 800 lines, split it by sub-feature. State of the shared view model (`@Published` properties) stays in `App/ViewModel.swift`; the actions of a feature go in an `extension VM` file next to that feature (`AppsVM.swift`, `DuplicatesVM.swift`...). A `private` member is only visible inside its own file, so keep it in the file that uses it.
7. **Text.** Every user-facing string goes through `t("English", "Tiếng Việt")`. No em dashes.
8. **No `@State`** (the macro needs an Xcode-only plugin). Use `Flag` or an `ObservableObject`.
9. A new file is added to the map below in the same commit.

## Map

### `App/` Start-up, window, shared state, developer helpers

| File | What it holds |
|---|---|
| `App.swift` | Entry point (`@main`), app icon drawn in code, feature flags, shared view model instance |
| `MenuBar.swift` | Menu bar item and `AppDelegate` |
| `Root.swift` | Window layout and sidebar |
| `ViewModel.swift` | `Page` list and the shared view model: state for every page, window, settings, disk and memory checks, Undo banner, updates, Ignore list |
| `Demo.swift` | Sample data for screenshots (`--demo`), never touches real files |
| `SelfTest.swift` | Dev build only: `--selftest` runs clean and Undo on test files without clicking (results to a text file) |

### `Core/` Data model, settings, scanning, the Trash and Undo, network

| File | What it holds |
|---|---|
| `Model.swift` | `CleanItem`, `Category`, `Safety`, Space Lens nodes |
| `Prefs.swift` | Settings stored in `UserDefaults`, Ignore list |
| `Scanner.swift` | Folder scanning, sizes, what is ticked by default and why |
| `Trash.swift` | Move to Trash, Undo journal, safe-area check, iCloud handling, Trash size and Empty Trash |
| `Network.swift` | Update check (`Updates`) and feedback sending (`Backend`) |

### `UI/` Look and reusable views

| File | What it holds |
|---|---|
| `Theme.swift` | Colours, text sizes, language switch, hover and tooltip helpers |
| `Components.swift` | Reusable views: buttons, rows, check boxes, banners, thumbnails |

### `Clean/` Finding and cleaning files

| File | What it holds |
|---|---|
| `CleanVM.swift` | View model actions for Clean Now, Large Files and Cloud |
| `ByAppVM.swift` | View model actions for Clean by App and its month viewer |
| `DuplicatesVM.swift` | View model actions for Duplicates |
| `LensVM.swift` | View model actions for Space Lens and System Data |
| `Pages.swift` | Clean Now, review, Clean by App, Large Files and Ignore pages |
| `AppRules.swift` | Clean by App rules (Zalo, Telegram, Chrome...) |
| `AIModels.swift` | Local AI models for Clean by App (Ollama, Hugging Face, LM Studio): one row per model |
| `MonthViewer.swift` | Month-by-month viewer for Clean by App |
| `DevDeps.swift` | Dependency and build folders of projects left alone (node_modules, venv, target...) for Cleanup |
| `SpaceLens.swift` | Space Lens page, bubble layout, folder explanations |
| `SystemData.swift` | System Data explainer |
| `Duplicates.swift` | Duplicate finder and its page |
| `Cloud.swift` | Cloud folders (remove downloaded copies) and its page |
| `TrashPage.swift` | Trash page |

### `Apps/` Installed apps and what starts with the Mac

| File | What it holds |
|---|---|
| `AppsVM.swift` | View model actions for the Uninstaller, leftovers, the Trash hint and Startup items |
| `Apps.swift` | Uninstaller, leftovers, installers, and their page |
| `TrashHint.swift` | Optional hint when an app is dragged to the Trash: lists what it left in Library (off by default) |
| `Startup.swift` | Login items and launch agents, and their page |

### `Tools/` Tools beyond cleaning

| File | What it holds |
|---|---|
| `Mintangle.swift` | Window tiling (Mintangle): actions, shortcuts, moving and resizing windows |
| `MintangleSnap.swift` | Mintangle: drag to snap, footprint, where each action puts a window |
| `MintanglePage.swift` | Mintangle: sidebar page, shortcut grid, Settings switch |
| `Shelf.swift` | Drop shelf (Mintdrop): items, panel, shake and shortcut |
| `ShelfPage.swift` | Mintdrop: dragging files out, panel content, sidebar page, Settings switch |

### `More/` Settings, Stats and Contact pages

| File | What it holds |
|---|---|
| `Settings.swift` | Settings page |
| `Stats.swift` | Activity log, free-space history, Stats page |
| `Contact.swift` | Contact page, check-in card, invite, footer links |
