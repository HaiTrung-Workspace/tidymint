# Security policy

Tidymint is a free, open-source Mac cleaner maintained by one person. Security reports are welcome and taken seriously.

## Reporting a vulnerability

Please report privately by email: **hello@tidymint.app** (subject line "Security").

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

- Tidymint moves files to the Trash only and never deletes permanently.
- The app makes one outbound request: a once-a-day check of a version text file on tidymint.app (see [PRIVACY.md](../PRIVACY.md)). It sends no account, usage or tracking data.
- Current builds are not yet signed or notarized by Apple, so macOS asks for confirmation on first launch. Verify downloads against the SHA-256 listed on each GitHub release.

## Verify your download

- Download Tidymint only from [tidymint.app](https://tidymint.app) or this repository's [Releases](https://github.com/HaiTrung-Workspace/tidymint/releases). Any other site offering "Tidymint" is not official.
- Check the file: `shasum -a 256 Tidymint.zip` in Terminal must print the SHA-256 shown on the release page.
- Each release links a VirusTotal scan of `Tidymint.zip`.
