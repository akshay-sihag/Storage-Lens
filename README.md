# Storage Lens — By Eridyn

**Author and publisher: Eridyn · Version 1.1.3**

A native macOS storage explorer with explanations, app-related storage views, charts, and deliberately restricted, reversible cleanup. Built with Swift, SwiftUI, AppKit, and Swift Charts. No analytics, account, administrator helper, or automatic deletion. Scanning is local; online research is opt-in.

## Requirements

- Apple Silicon Mac, macOS 14 or newer (deployment target; testing currently limited to the development Mac).
- Build: Apple Command Line Tools providing Swift and the macOS SDK.
- This preview uses a local ad-hoc signature. It is **not notarized**. Public distribution needs Eridyn's Apple Developer ID signing and Apple notarization. A custom publisher metadata field is branding, not a verified signing identity.

## Build and test

```sh
./scripts/test.sh
./scripts/build.sh
open "build/Storage Lens.app"
./scripts/package-dmg.sh
```

Open `Package.swift` in Xcode to browse and edit the Swift project. Use the scripts above to produce the branded app bundle and DMG.

The DMG opens in a custom Finder window with two large icons, an Applications shortcut, a centered arrow, and drag-to-install instructions. The build script targets Apple Silicon. The app has no third-party runtime dependencies. DMG packaging installs dmgbuild 1.6.5 in an isolated build-only Python environment. The SwiftUI State wrapper alias avoids a macro-name collision in newer SDKs while retaining the macOS 14 deployment target.

## Using the app

1. Start a read-only scan. Review scan coverage if protected folders could not be read.
2. Use Overview for disk usage and the measured-category breakdown. These are not Apple's exact System Data classification.
3. Use Applications for likely-owner grouping and installed app icons. This groups installed apps and associated data; unknown apps use a fallback icon.
4. Search and filter All locations, or explore a folder to see its immediate children and files.
5. Cleanup lists only recognized cache paths and diagnostic logs older than 30 days. Select deliberately; nothing is preselected.
6. Preview cleanup. Running related processes, open files, incomplete scans, changed folders, and unsupported paths are blocked.
7. After confirmation, eligible items move to Trash. History can restore them while they remain in Trash and the destination has not been recreated.
8. Try your applications before manually emptying Trash in Finder. The app never empties Trash, and moving to Trash does not immediately free disk space.

## Safety boundaries

Cleanup is restricted by exact paths, ownership, canonical paths, file identity, full measurement, process checks, open-file checks, and confirmation. It rejects symlinks and incomplete scans. Caches can require re-downloads or a slower first launch. No cleaner can promise identical behavior across every third-party app version.

Automatic cleanup excludes whole application-support folders, databases, preferences, credentials, projects, cloud documents, backups, AI models, virtual machines and system data. Explicit manual review is available for selected user-owned locations as described below; it is never labeled safe by default. Adobe staging and developer runtimes are explained but must be managed through their owning tools. Restore never merges or overwrites folders. npm cache cleanup checks actual open handles in the selected subtree instead of blocking unrelated Node processes. Other app-specific process guards remain in place.

Filesystem state can change between checks; this is a personal desktop utility, not a security boundary against another process deliberately racing it. No privileged helper is installed.

## Privacy and reports

Scan results remain in memory. JSON/CSV exports happen only on request and contain local paths; review before sharing. Cleanup history is saved locally at `~/Library/Application Support/Storage Lens/history.json` with restricted file permissions. Optional Full Disk Access broadens read visibility but does not expand the cleanup allowlist. The app does not grant itself permissions.

## Project layout

- `Sources/StorageCore.swift`: scanner, path rules, process-block policy, history data.
- `Sources/StorageModel.swift`: scan lifecycle, preview, Trash/restore workflow, exports.
- `Sources/StorageLensApp.swift`: native interface and Eridyn branding.
- `Tests/main.swift`: synthetic safety cases and reversible Trash round-trip.
- `Resources`: metadata and app icon.
- `scripts`: build, tests, icon generation, and DMG packaging.

## Before public release

This is a preview for iteration. Test on supported OS versions and additional Macs; validate each supported application's cache behavior; add signed/notarized release automation with Eridyn's own certificate; run accessibility and failure-recovery QA; decide Intel support, licensing, support contacts, update distribution, and the final privacy policy. Do not represent the local ad-hoc signature as verified Eridyn identity.

© 2026 Eridyn. All rights reserved. No open-source license has been selected yet.


### Expandable explorer and manual removal

Folders expand inline in the storage table, on demand, with largest children first by default. Expansion measures files and folders in the background; results are cached until the next scan or cleanup. Search filters the measured, expanded tree and preserves ancestor rows; it does not search unexpanded descendants. Folder totals include their children, so parent and child rows must not be added together.

The Installers view discovers DMG/PKG/MPKG files under Downloads, user Caches and Application Support without following symlinks or descending into packages. Recognized cache descendants use the existing cache guidance and process checks. Other installers require review; extension alone never makes them safe.

Move to Bin offers explicit manual review for owned, fully measured items within Downloads, Documents, Desktop, Application Support and user Caches. System locations, cloud-storage roots, app-bundle components, credentials and the app’s own history are excluded. Manual removal can break app features or lose unique data; it is not a safety recommendation. Both modes revalidate identity, size, modification time, running processes, open handles and mounted disk images, and record recoverable Trash destinations. Process detection cannot establish every third-party dependency. No cleanup is automatic and Trash is never emptied.

Research on Web opens a compact inspector card with editable, generic search terms. The optional Search Google button opens the default browser; the embedded browser sheet has been removed. Scans, full paths and file contents stay local. Automated inline web summaries are not connected yet, and web results cannot change cleanup eligibility.

### Browser cleanup evidence

Chrome’s whole cache root is not a cleanup target. Only `Default/Cache` and numeric `Profile N/Cache` locations beneath the standard user cache directory are recognized. Storage, Code Cache and unknown children remain excluded pending specific research. Chrome profiles and mixed ancestors cannot be removed through manual mode. Cookies, offline site storage, browser configuration and credentials have distinct consequence guidance. The inspector records source links, evidence limitations and review date. This is a location-based classification, not proof that a specific site will be unaffected.

Sources reviewed 17 October 2026:
- https://support.google.com/chrome/answer/2392709?hl=en
- https://support.google.com/chrome/answer/95647?hl=en
- https://chromium.googlesource.com/chromium/src/+/HEAD/docs/user_data_dir.md

The product standard is to explain purpose, benefit of keeping data, removal consequences, recovery limits and evidence. Unknown data remains unknown; disk size and filename alone never establish safety. Other app rules still require broader version-specific research and real application regression testing before public-release safety claims.

### Responsiveness

Display metadata and eligibility hints are cached, while cleanup still revalidates current filesystem state. Row selection no longer rebuilds and rechecks the entire visible tree. Visible rows and depth maps update only when scan/tree/filter inputs change; app/file icons are cached. Folder names appear before size calculation finishes, with explicit Calculating labels and no cleanup eligibility. Folder work runs off the main thread, limited to two concurrent operations; opening another folder or selecting rows does not wait for an existing size calculation. Initial measurements of large folders can still take time.

The usage check reports process names and PIDs using machine-readable lsof output. It runs both in preview and immediately before moving items. Errors and timeouts fail closed. It is a point-in-time check, not an atomic lock: do not start package installs during cleanup.

Chrome cache rows show local profile display names and folder identifiers. Only the profile name mapping is decoded from Local State during scanning; it is not sent to web research. Missing metadata falls back to Default/Profile N. Nested sizes are explicitly included in parent totals.

Chrome profile labels include the locally saved profile name, account display name and email when readable. These fields stay in memory, are not sent to research and do not prove a currently active sign-in. Missing metadata is not treated as a signed-out account; access help is shown instead.
