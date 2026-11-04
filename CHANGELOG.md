# Changelog

All notable changes to Tidymint. Dates are release dates.

## 0.4.0 (2026-11-05)

- New look: Settings and the rest of the app follow the macOS style, with sections that fold, standard text and control sizes, and warnings lined up in their own column. The window keeps its proportions when you change the text size
- New: open files from the lists. Click or press Space for Quick Look, double-click to open in its app, right-click for Open With, Show in Finder and Copy Path
- New: the Uninstaller has a search box, remembers how you sorted it, and also finds the app's own cache and temp folders in /private/var/folders
- New: switches in Settings to hide the menu bar icon and to turn off the daily check for a new version (Check Now still works). Add files or folders to the Ignore List yourself
- Fixed: the Trash page could count a folder on an external drive that Finder does not treat as Trash, so the number stayed the same after emptying. It now shows what is left on each drive

## 0.3.8 (2026-11-04)

- New: Duplicates and Large & Old Files can also scan external drives and extra folders you add in Settings. When the same file is on your Mac and on a drive, you choose which copy to keep
- New: a one-line question on Clean Now after two weeks of use, "Is Tidymint helping you?". One click, no email, asked at most twice
- New look for the Scan button: the mint leaf, with the word showing when you hover
- Fixed: Ignore in the Uninstaller and in Duplicates did not take effect, so an ignored file could still go to the Trash
- Fixed: the Trash page counts drives too, Undo goes away once you empty the Trash, Uninstall waits until related files are listed, and the month viewer frees space right after the Trash is emptied
- The daily update check now goes through update.tidymint.app and is counted by app and macOS version only; nothing else about your Mac is sent (see Privacy)

## 0.3.7 (2026-11-03)

- New: Clean by App opens each month as a grid of photos and videos, split by week. Tick single files, a whole week or the whole month, drag a box over many, or Shift-click a range
- Photos and videos saved without a file extension (Zalo, Telegram, WhatsApp) now show real thumbnails and open large
- App index files (Zalo, Telegram) are kept out of the photo grid and the month counts; Telegram stickers and unfinished downloads are labelled
- Uses much less memory: less at launch, no more spikes when Duplicates reads large files, and memory goes back to macOS when the window closes
- Safer: Clean by App never offers Telegram's own database files, which have no file extension and could be listed with the media before
- The Trash page names the app of the last Clean by App session

## 0.3.6 (2026-10-30)

- New: "What is in System Data" in Space Lens shows iPhone backups, iOS update files and Xcode leftovers you can clean, leftover browser copies, and where to handle the rest
- New: Statistics shows a chart of free space per day (7, 30 or 90 days)
- Clean Now lists Xcode build data per project, never pre-selected
- Clean by App: CapCut rendering cache and proxies, now checked on a real Mac
- Space Lens explains more folders: CapCut, Docker, Homebrew, Xcode archives
- New app icon; Advanced in the sidebar starts folded
- New menu bar icon: a mint leaf that fills as your disk fills, turns amber when free space gets close to your warning level and red below it
- Safer Uninstaller: Undo puts the app back too, not only its files; browser web apps are marked and explained
- Safer cleaning: a file the Trash refuses on an external or network drive is reported, never moved
- Uninstaller now removes apps installed for every user, such as App Store apps: Finder moves them to the Trash and macOS asks for your password, which Tidymint never sees; error messages say what to do next
- Xcode archives are never offered for removal; simulator caches and CapCut caption and voice-over files are no longer pre-selected
- New Contact page, and tooltips on small buttons

## 0.3.5 (2026-10-28)

- Clean Now shows results as cards, and the scan shows which step it is on
- Done screen after a clean: space recovered, with Undo and Open Trash
- Every page shows how many items are selected and their total size
- Photo and video thumbnails in Large Files, Duplicates and Space Lens
- Space Lens: select items and move them to the Trash, with back and forward
- Uninstaller: filter and sort the app list
- Clean by App now covers Telegram, WhatsApp, Slack, VS Code and Outlook
- Settings shows whether Full Disk Access is on, with a button to turn it on
- Sidebar: clearer icons, a number only on Settings, labels never cut off at any text size
- Support the project in the menu bar menu
- Sizes use one decimal, with a decimal comma in Vietnamese

## 0.3.4 (2026-10-27)

- New: text size (Small, Default, Large) in Settings
- Sidebar shows a spinner while a page scans and a dot when a result is waiting
- Trash in the sidebar shows when it has something in it
- Support the project button in Settings
- Low disk space alert takes any number of GB; 0 turns it off
- Space Lens moved to the top of Advanced; Cleanup details now opens from Clean Now

## 0.3.3 (2026-10-27)

- Reminder on the home page when Full Disk Access is off, with a button to the right setting
- Fewer permission pop-ups when Full Disk Access is off
- Duplicate finder says when the link check is running
- Only one copy of Tidymint runs at a time: launching a new build quits the old one
- Install guide with a screenshot for every step

## 0.3.2 (2026-10-27)

- New: Star White, a light theme
- New app icon and favicon
- Better readability on every theme
- Vietnamese: remaining text translated, dates in Vietnamese

## 0.3.1 (2026-10-27)

- New: Clean by App for Zalo, Chrome, Edge, Cốc Cốc and CapCut
- New: Undo the last clean from the Trash page
- Safety level on every cleanup group
- Uninstaller and Startup Items are more careful about what they pre-select and flag
- Update check in Settings
- Darker mint theme

## 0.3.0 (2026-10-26)

- Universal build for Apple silicon and Intel, macOS 14 or later
- Download and install guide in English and Vietnamese
- Contact address hello@tidymint.app in the app, website and privacy policy

## 0.2.0 (2026-10-26)

- Renamed from Disk Cleanup to Tidymint, mint theme and mint-leaf icon
- New screenshots and the tidymint.app website

## 0.1.0 (2026-10-25)

- First public build: Smart Scan, Cleanup, Uninstaller, Large and old files, Duplicates, Space Lens, Cloud Cleanup, Startup Items, Statistics
- Everything always goes to the Trash, nothing is deleted outright
- English and Vietnamese
