# Preview validation — Eridyn

Version: 1.0.0. Validation date: 17 October 2026.

- Built on Apple Silicon with the macOS 27.0.1 host and a macOS 14 deployment target.
- 27 automated assertions passed: exact cleanup allowlist, unsafe parents, partial scans, path traversal, symlinks, changed identities, persistent app data exclusion, running app helpers, log age/type rules, restore-path restrictions, no-overwrite restore policy, immediate-child scanning, cancellation, and a real synthetic-file Trash/restore round-trip.
- Live UI checked: first launch, scan, charts, installed-app measurements, app grouping/icons, app search, app details, folder drill-down, and cleanup preview blocking a running app.
- JSON export saved successfully and parsed with expected Eridyn/version metadata. CSV export is implemented; interactive CSV export was not exercised in this pass.
- DMG checksum verified; image mounted read-only, app code signature verified, bundled executable and final icon compared against the build, then image ejected.
- No actual user caches, app data, or logs were removed. The only Trash operation during validation used a generated synthetic test file, which was restored.

Not yet validated: other physical Macs, older supported macOS versions, Intel builds, each third-party app's post-cleanup behavior, full user-data cleanup/restore integration, notarization/Gatekeeper distribution, automated updates, or accessibility audit. This is a preview, not a public-release certification.

- Installer DMG verified in Finder with two large icons, a centered drag arrow, and no publisher/version or post-copy footer text. Disk-image checksum verified.

- Expandable explorer verified live through Claude → vm_bundles → claudevm.bundle → rootfs.img; actual files appeared inline in descending size order.
- 49 synthetic safety/scanning assertions pass, including cache descendants, manual-removal exclusions, installer discovery and symlink handling.
- Online research is a live search view, not automatic web summarization.

- In-app web search loaded live results; installed final app passed code-signature verification and launched successfully.

- Browser safety revision: 65 assertions passed. Whole Chrome roots, profile ancestors, cookies, bookmarks, credentials and offline Storage are blocked; only identified page-cache paths qualify. No real browser data was removed; login preservation has not been validated with a destructive browser regression test.

- Responsiveness update: 71 assertions passed. 10,000 cached eligibility display lookups took 3.21 ms in a local synthetic run (not an end-to-end UI latency benchmark). Cached display metadata cannot bypass fresh deletion checks.
- Live UI verified selection, inline nested expansion and compact Research on Web card with Google query. Browser sheet removed; automated summaries remain unconnected.

- 1.1.1: 79 assertions pass, including a child process holding a nested fixture file, unrelated open-file exclusion, releasing the holder, parser handling and fail-closed timeout/permission checks.
