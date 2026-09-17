# Security policy

## Reporting a vulnerability

Please do not open a public issue for security problems. Report them privately through
[GitHub's private vulnerability reporting](https://github.com/Cookiezisg/Anselm/security/advisories/new)
for this repository. You will get an acknowledgement within a few days, and a fix or a mitigation
plan before any public disclosure.

Include what you found, how to reproduce it, and which version or commit you tested.

## Scope

- The desktop app (`frontend/`) and the local Go sidecar (`backend/`), including the install and
  update chain: signed macOS builds, Sparkle updates, the Windows installer and its checksum
  verification.
- The way the app stores secrets: the master key in the system keychain, provider API keys and the
  device-proof key encrypted on disk.
- The boundary between the local sidecar and the managed Anselm API (device-bound proofs, quota).

The managed API gateway itself lives in a separate repository; reports about it are welcome through
the same channel and will be routed.

## Supported versions

Only the latest release receives fixes. The app updates itself on macOS and Windows, and Linux
users are pointed at the latest release.

## Code signing policy

Every release artifact is built by the `release` workflow in this repository from a tagged commit
on `main`; nothing is built or signed on a developer machine.

- **macOS**: the app, its sidecar and the DMG are signed with the maintainer's Apple Developer ID
  (team `YCYFFXR57C`) with the hardened runtime, notarized by Apple and stapled. In-app updates
  are additionally signed with an EdDSA key whose public half is embedded in the app.
- **Windows**: the installer and portable build are currently unsigned, so SmartScreen warns on
  first run. Verify downloads against `SHA256SUMS.txt` on the release. Signing will come with a
  commercial certificate once the project justifies the cost; this section will say so.
- **Linux**: artifacts are unsigned; verify them against `SHA256SUMS.txt` on the release.

Team roles for signing decisions:

| Role | Who |
|---|---|
| Committers (may change code without review) | [@Cookiezisg](https://github.com/Cookiezisg) |
| Reviewers (review outside contributions) | [@Cookiezisg](https://github.com/Cookiezisg) |
| Approvers (decide whether a release is signed) | [@Cookiezisg](https://github.com/Cookiezisg) |

## Privacy

The desktop app transfers no data to the project or to third parties without the user asking for
it. The only network traffic on a fresh install is the managed Anselm API route (device
registration and the requests the user makes through it), the update check against GitHub
Releases, and whatever providers or MCP servers the user configures.
