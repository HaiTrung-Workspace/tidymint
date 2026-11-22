# Security policy

Tidymint is a free, open-source Mac cleaner maintained by one person. Security reports are welcome and taken seriously.

## Reporting a vulnerability

Please report privately, either:
- through GitHub: **Security** tab › **Report a vulnerability** ([open a private report](https://github.com/HaiTrung-Workspace/tidymint/security/advisories/new)), or
- by email: **hello@tidymint.app** (subject line "Security").

Include, if you can:
- the Tidymint version and macOS version,
- what you found and the steps to reproduce it,
- what you think the impact is.

Please do not open a public issue for a vulnerability before it is fixed. Public issues are fine for anything that is not a security risk.

## What to expect

- You will get a reply within 24 hours.
- A fix in the next release when the report is confirmed, with credit in the changelog if you want it.

## Supported versions

Only the latest release receives security fixes.

## Scope notes

- Tidymint moves files to the Trash and does not delete them itself. One exception, off by default: Auto-empty Trash in the Plus bundle permanently deletes items that are already in the Trash.
- The app checks for a new version by itself and, once a day, sends usage statistics with that check. A Plus trial or key is checked with the key service. Both are described in [PRIVACY.md](../PRIVACY.md). Your files, their names and their contents are never sent.
- From 1.0.0, builds are signed with a Developer ID and notarized by Apple. You can still verify a download against the SHA-256 listed on each GitHub release.

## Verify your download

- Download Tidymint only from [tidymint.app](https://tidymint.app) or this repository's [Releases](https://github.com/HaiTrung-Workspace/tidymint/releases). Any other site offering "Tidymint" is not official.
- Check the file: `shasum -a 256 Tidymint.zip` in Terminal must print the SHA-256 shown on the release page.
- Each release links a VirusTotal scan of `Tidymint.zip`.
