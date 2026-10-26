# Disk Cleanup

A free, open-source disk cleaner for macOS, built for people who work with AI tools.

AI work leaves a lot behind: model files, drafts, exported images, duplicate assets, caches from browsers and editors. Disk Cleanup finds that clutter, shows exactly what it is, and moves only what you select to the Trash.

> **Safety first.** Nothing is deleted permanently. Every action moves files to the Trash, and the Trash is only emptied when you click **Empty Trash** and confirm.

![Disk Cleanup, Smart Scan](docs/smart.jpg)

## Features

| Area | What it does |
|---|---|
| **Smart Scan** | One click to find safe junk, large files and the Trash size |
| **Cleanup** | User caches, app caches (Chrome, Slack, Notion, VS Code...), logs, npm cache, downloaded aerial wallpapers, old Downloads, `_tmp` / `_to_delete` drafts in your project folders |
| **Uninstaller** | Removes an app together with its leftovers; finds leftovers of apps already removed and old installers |
| **Large & Old Files** | Files over 100 MB in your personal folders, never pre-selected |
| **Duplicates** | Finds identical files (SHA-256), keeps one copy, and before deleting can check whether a script or skill in your project folders still uses them |
| **Space Lens** | Bubble map of what takes up space, with plain-language notes for common folders (AI model folders included) |
| **Cloud Cleanup** | Shows how much of iCloud Drive, Google Drive, Dropbox... is stored locally |
| **Startup Items** | Lists background helpers that start with your Mac; flags ones left by removed apps |
| **Statistics** | Space freed over time and a full activity log |
| **Menu bar** | A hard-drive indicator with free space inside, plus disk, RAM and Trash at a glance |
| **Contact** | Send feedback or bug reports from inside the app |

| Space Lens (Golden Gate theme) | Settings (Burgundy theme) |
|---|---|
| ![Space Lens](docs/lens.jpg) | ![Settings](docs/settings.jpg) |
| **Contact (Pride theme)** | **App icon follows the theme** |
| ![Contact](docs/contact.jpg) | ![Icons](docs/icons.png) |

Menu bar indicator at different free-space levels:

![Menu bar](docs/menubar.png)

Also: English and Vietnamese, four colour themes (Night Sky, Burgundy, Golden Gate, Pride) with a matching app icon, an Ignore list, and alerts when disk space or memory runs low.

## Install

### Build from source (recommended)

Requirements: macOS 14 or later, Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/HaiTrung-Workspace/disk-cleanup.git
cd disk-cleanup
./build.sh --install
```

### First launch

1. Open **Disk Cleanup** from Applications.
2. Grant **Full Disk Access** in System Settings > Privacy & Security > Full Disk Access, so the app can measure every folder. Without it, some folders show as empty.
3. Optional: in **Settings**, add your **project folders** (code, AI workspaces). Drafts are found there, duplicates there are never pre-selected, and links are checked there before deleting.

## What it never touches

Photos libraries, Mail, keychains and passwords, cloud storage roots, iCloud Drive internals, Apple system caches, browser profiles for antidetect tools, and anything on your Ignore list. You can add more protected keywords:

```bash
defaults write com.haitrung.diskcleanup protectedKeywords -array "my-profile-folder"
```

## Where data is stored

- Settings: `~/Library/Preferences/com.haitrung.diskcleanup.plist`
- Activity log: `~/Library/Application Support/Disk Cleanup/activity.log`

The app works offline. It sends nothing anywhere unless you choose to send feedback or join the newsletter. See [PRIVACY.md](PRIVACY.md).

## Feedback

Use **Contact** inside the app (an email address is required so you can get a reply), or open an issue on GitHub.

Self-hosting the collector: `backend/Code.gs` is a Google Apps Script that appends submissions to a Google Sheet. Deploy it as a web app and put its URL in `Backend.endpoint`.

## License

MIT. See [LICENSE](LICENSE). The software is provided "as is", without warranty of any kind. Review what you select before cleaning.

---

## Tiếng Việt

**Disk Cleanup** là app dọn ổ đĩa miễn phí, mã nguồn mở cho macOS, dành cho người làm việc với AI. App chỉ chuyển file vào Thùng rác, không xoá vĩnh viễn. Cài đặt: chạy `./build.sh --install`, cấp quyền **Truy cập toàn bộ ổ đĩa**, rồi thêm **thư mục dự án** trong phần Cài đặt. Giao diện có tiếng Việt, tự chọn theo ngôn ngữ của máy.
