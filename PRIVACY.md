# Privacy

The Tidymint app runs entirely on your Mac. It does not track you, show ads, or send your files anywhere. The website tidymint.app is covered separately below.

## What leaves your Mac

Only what you choose to send from **Contact**, the newsletter invitation, or the one-time "Is Tidymint helping you?" card on Clean Now:

| Data | Why |
|---|---|
| Email address | To reply to you |
| Your message and its type (feedback, bug, question) | To read and act on it |
| App version, macOS version, Mac model, language (optional, on by default, can be unticked) | To reproduce bugs |
| Newsletter choice, the exact consent text and its version | To keep proof that you asked for the newsletter |
| Your answer to "Is Tidymint helping you?" (helpful, okay, not yet), the reasons you tick and the optional line you type, app version, language. No email, no Mac model, no identifier | To learn what to improve. The card shows at most twice, from 14 days after the first launch |

Submissions are stored in a private Google Sheet owned by the developer. If you answer the "Is Tidymint helping you?" card while offline, the answer is kept on your Mac and sent the next time the app opens (at most 5 tries).

## Update check

When the Tidymint window opens, at most once a day, it asks update.tidymint.app for the latest version number (if that fails, the copy on tidymint.app, then GitHub's public releases page). The request is the same plain request as before and carries nothing extra. update.tidymint.app adds one to a daily count, split by app version and macOS version, read from the standard User-Agent line every Mac app request includes (for example "Tidymint/0.3.8 ... Darwin/27.2.0"). It does not store your IP address, any identifier, or anything else, and request logs are off. This is how we know roughly how many Macs open Tidymint each day. The code is public in `backend/update-worker.js`. Nothing is installed automatically; the app only shows a line with a download link.

You can turn the daily check off in Settings > **Check for new versions automatically** (from 0.4.0). With it off, the app only asks when you press **Check Now**.

## Newsletter

You only join the newsletter by clicking **Send & get the newsletter** or **Subscribe**. Nothing is pre-ticked. The newsletter covers Mac tips, AI tools and drinks (concao.org). Every issue has an unsubscribe link, and you can ask for your data to be deleted at any time through **Contact**.

## Website (tidymint.app)

The website uses Google Analytics 4 to count visits, see which pages are read, where visitors come from, and how often the download button is clicked. Analytics cookies are only set if you click **Accept** in the cookie banner. If you decline, Google Analytics runs in consent mode without cookies and sends only cookieless pings. You can change your choice at any time with **Cookie settings** in the footer. Ads features are off. The newsletter form on the website sends the same data as the newsletter invitation in the app.

## Data stored on your Mac

- Settings: `~/Library/Preferences/com.haitrung.diskcleanup.plist`
- Activity log: `~/Library/Application Support/Tidymint/activity.log`

## Contact

Use **Contact** inside the app, email hello@tidymint.app, or open an issue on GitHub.
