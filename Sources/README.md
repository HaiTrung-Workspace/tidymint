# Sources

How the app code is organised. Read this before adding a file or a feature.

## Rules

1. **One feature per file.** Logic and its page live together (for example `Apps.swift` holds the Uninstaller model and its page). Shared building blocks go in `Components.swift`.
2. **Flat folder.** `build.sh` compiles `Sources/*.swift` only; subfolders are not built.
3. **Everything that moves user files goes through `Trash.swift`.** Call `VM.trash(...)`; never call `trashItem` or `removeItem` on a user's file from another file. `removeItem` is only for files the app created itself (its own history, temporary preview links, `.DS_Store`), with a comment saying why.
4. **Network only in `Network.swift` and `Contact.swift`.** Two paths exist: the update check (can be turned off) and the form the user sends. See `PRIVACY.md`.
5. **Unreleased features** sit behind a `dev-...` flag and in their own file. A hidden flag still publishes the code, so a feature that must stay secret is not in the release branch at all.
6. **Size.** When a file passes about 800 lines, split it by sub-feature. `ViewModel.swift` is known to be over this.
7. **Text.** Every user-facing string goes through `t("English", "Tiếng Việt")`. No em dashes.
8. **No `@State`** (the macro needs an Xcode-only plugin). Use `Flag` or an `ObservableObject`.
9. A new file is added to the map below in the same commit.

## Map

| File | What it holds |
|---|---|
| `App.swift` | Entry point (`@main`), app icon drawn in code, feature flags, shared view model instance |
| `MenuBar.swift` | Menu bar item and `AppDelegate` |
| `ViewModel.swift` | `Page` list and the shared view model (state for every page) |
| `Root.swift` | Window layout and sidebar |
| `Theme.swift` | Colours, text sizes, language switch, hover and tooltip helpers |
| `Components.swift` | Reusable views: buttons, rows, check boxes, banners, thumbnails |
| `Model.swift` | `CleanItem`, `Category`, `Safety`, Space Lens nodes |
| `Prefs.swift` | Settings stored in `UserDefaults`, Ignore list |
| `Scanner.swift` | Folder scanning, sizes, what is ticked by default and why |
| `AppRules.swift` | Clean by App rules (Zalo, Telegram, Chrome...) |
| `Trash.swift` | Move to Trash, Undo journal, safe-area check, iCloud handling, Trash size and Empty Trash |
| `TrashPage.swift` | Trash page |
| `Pages.swift` | Clean Now, review, Clean by App, Large Files and Ignore pages |
| `MonthViewer.swift` | Month-by-month viewer for Clean by App |
| `SpaceLens.swift` | Space Lens page, bubble layout, folder explanations |
| `SystemData.swift` | System Data explainer |
| `Apps.swift` | Uninstaller, leftovers, installers, and their page |
| `Duplicates.swift` | Duplicate finder and its page |
| `Cloud.swift` | Cloud folders (remove downloaded copies) and its page |
| `Startup.swift` | Login items and launch agents, and their page |
| `Stats.swift` | Activity log, free-space history, Stats page |
| `Settings.swift` | Settings page |
| `Network.swift` | Update check (`Updates`) and feedback sending (`Backend`) |
| `Contact.swift` | Contact page, check-in card, invite, footer links |
| `Mintangle.swift` | Window tiling (Mintangle) |
| `Shelf.swift` | Drop shelf (Mintdrop) |
| `Demo.swift` | Sample data for screenshots (`--demo`), never touches real files |
