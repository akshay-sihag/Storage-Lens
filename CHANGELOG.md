# Changelog — Storage Lens by Eridyn

## 1.1.3 (build 5) — 17 October 2026

- Profile labels include Chrome’s locally saved account display name and email when available.
- Added access guidance for unavailable account metadata; no invented identities or sign-in claims.
- Account details remain local and are excluded from research queries.

## 1.1.2 (build 4) — 17 October 2026

- Chrome cache rows, inspector and cleanup review identify profile display names and stable folder IDs.
- Profile names are searchable; absent or invalid profile metadata falls back gracefully.
- Nested rows clarify that their sizes are included in the parent total.
- 87 assertions pass, including profile mapping and cookie exclusion.

## 1.1.1 (build 3) — 17 October 2026

- npm cache cleanup no longer blocks unrelated Node, npm or npx processes.
- Open-file checks identify the actual process name and PID in preview and final cleanup failures.
- Added real file-holder tests; 79 assertions pass. No user cache data was deleted during validation.

## 1.1.0 (build 2) — 17 October 2026

- Inline folder expansion down to files, with background sizing and cached display data.
- Installer discovery, browser-specific cleanup safeguards and clearer removal consequences.
- Research on Web with optional Google search and compact inspector controls.
- Updated app metadata, About panel, exports and distribution filenames consistently.

## 1.0.0

- Native macOS dashboard with disk-usage donut and measured category breakdown.
- Installed apps and associated storage grouped by likely owner, using installed app icons when available.
- Search, size and cleanup filters, size/name sorting, and folder/file drill-down.
- Plain-language explanations, eligibility labels, and consequences for each supported cleanup type.
- Conservative exact-path rules for selected app caches and package-manager caches.
- Individual diagnostic log cleanup only for recognized files older than 30 days.
- Cleanup preview, process/open-file checks, identity revalidation, and explicit confirmation.
- Trash-only cleanup with local history and guarded restore that never overwrites existing folders.
- JSON and CSV report exports and visible scan-access limitations.
- Eridyn authorship and publisher branding, original programmatically drawn app icon, and DMG packaging.

Preview limitations: Apple Silicon build, macOS 14 deployment target with runtime verification on the development Mac only, ad-hoc signature, no Apple notarization, heuristic app grouping, selected-location scanning, and no claim to reproduce Apple's System Data categorization exactly.

### Explorer update
- Inline, lazy folder expansion to individual files, with sibling sorting and measured-tree search.
- Installer discovery, local purpose/risk explanations, and opt-in in-app web research.
- Explicit manual Move to Bin review in supported user locations, cache-child cleanup, mounted-image checks, and guarded restore.
- 49 safety and scanning assertions pass. Automatic web-result summarization remains unimplemented.

### Browser safety revision
- Replaced broad Chrome cache-root removal with specific per-profile page-cache rules.
- Protected browser profiles and mixed parent folders in manual mode.
- Added distinct cookie, site-storage and personal-browser-data explanations, consequences, evidence and source links.
- 65 safety and scanning assertions pass; no real browser data was deleted.

### Responsiveness and research controls
- Cached display metadata, icons and visible rows; retained fresh destructive-action checks.
- Folder names shown before asynchronous size measurement; two concurrent folder jobs maximum.
- Renamed Research on Web, switched optional search to Google, and removed the embedded browser window.
- 71 automated assertions passed, with live tree and inspector verification.
