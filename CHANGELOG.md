# Changelog

## Unreleased

### Added

- Unified typed clipboard history for text, links, images, files, and folders.
- Persistent pinning, custom clip titles, filtering, search, retention, and scoped clearing.
- Native Link Presentation previews in List and Grid views.
- Persistent List/Grid modes for Links, Images, and Files.
- Finder-style file icons and Quick Look thumbnails.
- Native Quick Look previews for ordinary files, images, folders, archives, disk images, audio, video, Finder aliases, and symbolic links.
- Regular-file metadata reader coverage.
- Symbolic-link preservation and reconstruction.
- App-specific System, Light, and Dark appearance modes.
- Hardened backup import validation and restored-image cleanup.
- Native macOS Settings tabs for General, Appearance, Privacy, and App Rules.
- Adaptive Settings-window sizing for General, Appearance, and Privacy.
- A dedicated Privacy tab for sensitive-content protection, Option-select capture, Accessibility permission status, and Link Preview disclosure.
- Default-on **Block Likely Sensitive Clips** protection with explicit confirmation before disabling it.
- Persisted sensitive-clip protection preferences.
- Capture-policy tests covering Allowed, Smart, and Blocked behavior when global sensitive-content protection is disabled.
- Optional automatic capture of newly created macOS screenshots.
- Sandboxed screenshot-folder access using persistent read-only security-scoped bookmarks.
- Screenshot-folder monitoring, candidate discovery, stable-file verification, and clipboard integration.
- Automated screenshot identity using **Screenshot Created** and **macOS Screenshot** metadata.
- Regression coverage for screenshot preference, destination detection, folder access, monitoring, discovery, processing, stability, and duplicate-event protection.

### Changed

- File pasteboard access remains active while the file clip is on the clipboard.
- Tap-to-copy now provides the same visual feedback as a physical click.
- Grid cards use consistent dimensions.
- Link previews are cached locally and remain independent of URL copying.
- Increased Settings typography to better match native macOS applications.
- Moved Option-select capture controls and Accessibility status from General to Privacy.
- Reworked App Rules into a fixed-height layout with an internally scrollable application list.
- Tightened App Rules alignment, spacing, and app-name-to-mode-menu layout.
- Settings can now be opened consistently through Command–Comma, the menu-bar command, and the main-window gear button.
- Allowed apps now follow the global sensitive-clip protection preference, while Smart and Blocked apps retain their own protection policies.
- Routed all supported file previews through the native `QLPreviewPanel`.
- Corrected Quick Look reload and selection order.
- Refresh the selected Quick Look item after presentation so media metadata, native controls, autoplay, sharing, and Open With actions load correctly.
- Spreadsheet clipboard data now takes priority over rendered image representations when Excel and similar applications provide both.
- Automated screenshots replace the system clipboard only after the screenshot file is complete and readable.

### Fixed

- File clips failing to paste after security-scoped access ended too early.
- Light/Dark/System appearance transitions and Settings-tab resets.
- Intermittent Space/Escape failure when closing Quick Look.
- Alias and symbolic-link routing being mistaken for image targets.
- The main-window gear button failing to open the native Settings scene.
- Excess Settings-window width and inconsistent tab spacing.
- Settings content being vertically centered instead of aligned beneath the toolbar.
- Uneven App Rules padding and excessive spacing between application names and mode menus.
- Settings selection and keyboard-focus problems caused by the earlier sidebar implementation.
- MP3 previews showing incomplete controls and missing embedded metadata.
- Audio and video previews failing to autoplay.
- ZIP, DMG, folder, alias, and symbolic-link previews showing only generic icons.
- Custom preview windows replacing native Quick Look controls and actions.
- Excel cell ranges being captured and pasted back as images instead of editable cell data.
- Screenshot destination detection resolving to the app sandbox’s container Desktop rather than the logged-in user’s actual Desktop.
- Repeated screenshot-folder callbacks creating duplicate automated capture requests.
- Redundant **Copied Image** text appearing below **Screenshot Created**.
