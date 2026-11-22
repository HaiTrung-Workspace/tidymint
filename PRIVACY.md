# Privacy

The Tidymint app does its work on your Mac and shows no ads. It never sends your files, their names or what is in them anywhere, except Mintclip's iCloud sync if you turn it on. The website tidymint.app is covered separately below.

## What leaves your Mac

From **Contact**, the newsletter invitation, or the "Is Tidymint helping you?" card on Clean Now, only what you choose to send:

| Data | Why |
|---|---|
| Email address | To reply to you |
| Your message and its type (feedback, bug, question) | To read and act on it |
| App version, macOS version, Mac model, language (optional, on by default, can be unticked) | To reproduce bugs |
| Newsletter choice, the exact consent text and its version | To keep proof that you asked for the newsletter |
| Your answer to "Is Tidymint helping you?" (helpful, okay, not yet), the reasons you tick and the optional line you type, app version, language. No email, no Mac model | To learn what to improve. The card shows at most twice |

Submissions are stored in a private Google Sheet owned by the developer. If you answer the "Is Tidymint helping you?" card while offline, the answer is kept on your Mac and sent the next time the app opens (at most 5 tries).

## Update check and usage statistics

The app checks for updates by itself and adds a few usage numbers once a day: the app and macOS version, your language and country, which tools you use and how much, how long it has been installed, and whether this copy is free, on trial or paid. They travel under a random id for this install, never your name. Never files, file names, or anything you type or copy. Nothing is installed by itself, and requests are kept with their IP address for up to three months.

## Tidymint Plus: trial, keys and purchases

The trial and a key only need to recognise your Mac: no name, no account.

**Trial.** When you start the 14-day trial, the app sends a code worked out from your Mac's hardware ID, never the ID itself. The key service keeps a hash of that code and the start date with no time limit, so each Mac gets one trial.

**Key.** When you add a key, the app sends the key and the same code, and asks again about once a day. The key is passed to Polar to be checked. For each key the service keeps the list of Macs (the hashed code and the date added) and a hash of the key, until you remove the Mac in Settings > Key. Removing a Mac works even after a refund. The key and the last signed answer are kept in the Keychain of this Mac and are not synced to iCloud.

**Code by email.** To add a Mac, a 6-digit code is sent to the email you bought with, through Resend. Resend stores your email address and the message in the United States for 30 days. Opens and clicks are not tracked. The app only ever sees that address with most of it hidden.

**Request log.** Each trial or key request is logged for up to three months: its type, result, country, IP address, the key's ID and part of the Mac's hashed code.

**Purchase.** Payment is handled by Polar. Tidymint never sees your full card number. Polar shows Tidymint your email, what you bought, and your name, billing address and tax ID if you gave them. The order also notes which tool led you to the purchase page. This is used to help you when you write, and to count which tools are bought.

## Accessibility permission (Mintangle, from 0.5.0)

Mintangle is off by default. Only when you turn it on does Tidymint ask macOS for Accessibility permission. It uses it to read the position and size of windows and to move or resize them: the front window when you press a Mintangle shortcut, and the window under the pointer when you click and drag it (to know whether it reaches a screen edge). It does not read what is inside windows and does not record the keys you type: shortcuts are registered with macOS, which tells Tidymint only when one of its own shortcuts is pressed. When you set a shortcut, Tidymint reads the shortcut settings of your other apps to warn you if the keys are already taken, keeping only the key combinations, on your Mac. Nothing is sent anywhere. Apple notes that this permission is broad, so you can turn Mintangle off, or switch Tidymint off in System Settings > Privacy & Security > Accessibility, at any time. Mintdrop needs no extra permission: while the mouse button is held it checks whether files are being dragged, and only then follows the pointer, to notice a shake.

## Mintbar: Accessibility and Screen Recording (from 0.6.0)

Mintbar is off by default. On macOS 14 to 26 it needs no permission and reads nothing from the screen. On macOS 27, when you turn it on, Tidymint asks for two permissions:

- **Accessibility**: to see which apps have an icon in the menu bar and where each icon is, and to open the icon you pick from a group. To open it, Tidymint may click that icon for you and then puts the pointer back where it was. A click on the clock is passed on the same way while icons are hidden, because macOS would otherwise ignore it. Tidymint does not read what is inside windows and does not record the keys you type.
- **Screen Recording**: to take a picture of the menu bar icon of each app you put in a group. Only that icon's own slot in the menu bar is captured, and only while the icon is in view. The pictures are kept in `~/Library/Application Support/Tidymint/mintbar-icons/` and are deleted when the app leaves its last group or when you turn Mintbar off.

Tidymint also reads (and never changes) the macOS Menu Bar settings, to list the apps whose "Allow in the Menu Bar" switch is off. The names of the apps that have menu bar icons are kept in Tidymint's settings. Nothing is sent anywhere.

## Mintclip (clipboard history)

Mintclip is off by default. When you turn it on, it keeps what you copy on your Mac so you can paste it again. Its iCloud sync is a separate switch, also off by default; only then does your copy history travel through your own iCloud to your other Macs. None of it goes to Tidymint, and it is never part of the settings backup.

## Trash hint and project folders (from 0.5.2)

The hint shown when an app goes to the Trash is off by default. When you turn it on, Tidymint watches the Trash folder while it is running, and when an app lands there it looks in your Library for folders named after that app's identifier. It needs Full Disk Access to see the Trash. The notification shows the app's name and stays on your Mac. Nothing is ticked, moved or sent anywhere.

To find libraries of old projects and Git working copies left behind, Tidymint reads file names and dates inside the project folders you set in Settings, plus the working-copy folders of Codex and Cursor in your home folder, and asks macOS which folders running programs are working in. All of it stays on your Mac.

## Newsletter

You only join the newsletter by clicking **Send & get the newsletter** or **Subscribe**. Nothing is pre-ticked. The newsletter covers Mac tips, AI tools and drinks (concao.org). Every issue has an unsubscribe link, and you can ask for your data to be deleted at any time through **Contact**.

## Website (tidymint.app)

The website uses Google Analytics 4 to count visits, see which pages are read, where visitors come from, and how often the download button is clicked. Analytics cookies are only set if you click **Accept** in the cookie banner. If you decline, Google Analytics runs in consent mode without cookies and sends only cookieless pings. You can change your choice at any time with **Cookie settings** in the footer. Ads features are off. The newsletter form on the website sends the same data as the newsletter invitation in the app.

## Data stored on your Mac

- Settings: `~/Library/Preferences/com.haitrung.diskcleanup.plist`
- Activity log: `~/Library/Application Support/Tidymint/activity.log`
- Plus keys and their last check: the Keychain of this Mac (not synced)
- Mintbar icon pictures (only while Mintbar is on, macOS 27): `~/Library/Application Support/Tidymint/mintbar-icons/`

## Contact

Use **Contact** inside the app, email hello@tidymint.app, or open an issue on GitHub.
