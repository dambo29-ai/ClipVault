# ClipVault

ClipVault is a native macOS clipboard-history app built with SwiftUI and AppKit. It stores a unified history of text, links, images, files, and folders while keeping App Sandbox enabled.

## Current capabilities

- Menu-bar operation with a separately reopenable main window.
- Unified history with All, Text, Links, Images, and Files filters.
- Search, pinning, custom clip titles, scoped clearing, retention limits, and persistence.
- Optional Option-select capture using Accessibility permission.
- Default-on sensitive-content protection with optional skipped-item warnings and an explicit opt-out confirmation.
- Native list and grid views for Links, Images, and Files, remembered independently.
- Rich Link Presentation previews with local caching and offline fallbacks.
- Managed image storage, thumbnails, Quick Look, and image-aware backups.
- Sandboxed file and folder references using security-scoped bookmarks.
- Finder-style file icons and Quick Look thumbnails.
- Native Quick Look previews for files, folders, archives, disk images, audio, video, aliases, and symbolic links.
- `.clipvaultbackup` export, validation, merge, replacement, and restored-asset cleanup.
- Per-app capture rules with Allowed, Smart, and Blocked modes.
- Native macOS Settings tabs for General, Appearance, Privacy, and App Rules.
- ClipVault-specific System, Light, and Dark appearance modes.

## Clipboard behavior

Clicking a normal row or grid card copies that one clip back to the system clipboard. There is no multi-selection mode.

A File clip keeps file-paste semantics. Renaming a clip changes the name of the exported copy; it does not rename or modify the original file, folder, alias, or symbolic link.

## File references and portability

ClipVault references ordinary files and folders rather than embedding their contents. Their continued availability depends on the original item and storage location remaining accessible.

Finder aliases remain aliases. Symbolic links are preserved as symbolic links, including their stored destination string. File, folder, archive, disk-image, audio, video, alias, and symbolic-link previews use Apple’s native Quick Look panel.

## Backups

A `.clipvaultbackup` package contains:

- `manifest.json` with clipboard-history metadata;
- managed image assets required by Image clips.

It does **not** contain the contents of ordinary referenced files or folders. On another Mac, restored File rows can remain searchable historical references but may be unavailable when their original locations or security-scoped access cannot be resolved.

Symbolic-link destination metadata is preserved. Link-preview metadata is treated as replaceable cache data and is fetched again when necessary.

## Link-preview network use

For Link clips, ClipVault uses Apple’s Link Presentation framework to request titles, representative images, and site icons. The resulting preview data is cached locally. Preview failure never prevents the URL itself from being copied or pasted.

## Privacy

- Clipboard history and managed assets are stored locally.
- App Sandbox remains enabled.
- Network access is used only to retrieve Link Presentation metadata for copied URLs.
- Option-select capture is off by default and requires Accessibility permission only when enabled.
- **Block Likely Sensitive Clips** is enabled by default.
- With protection enabled, likely passwords and other sensitive-looking text remain available in the system clipboard but are not stored in ClipVault history.
- Disabling sensitive-clip protection requires explicit confirmation.
- Smart app rules continue applying sensitive-content filtering even when the global protection setting is disabled.
- Blocked app rules always prevent ClipVault history capture.

## Settings

ClipVault uses a native macOS Settings window with four tabs:

- **General** — history limits, retention, backup count, skipped-warning visibility, and keyboard shortcuts.
- **Appearance** — System, Light, and Dark appearance modes.
- **Privacy** — sensitive-clip protection, Option-select capture, Accessibility permission status, and Link Preview privacy information.
- **App Rules** — per-application Allowed, Smart, and Blocked capture policies.

General, Appearance, and Privacy resize to fit their content. App Rules uses a fixed-height, internally scrollable application list.

## Appearance

Settings → Appearance provides:

- **System** — follows the current macOS appearance.
- **Light** — forces ClipVault to use Light appearance.
- **Dark** — forces ClipVault to use Dark appearance.

This changes ClipVault only, not macOS or other applications.

## Development status

The current automated baseline is **277 passing tests**. See `ClipVault/MANUAL_TEST_CHECKLIST.md` for manual regression coverage and `ClipVault/PRODUCT_DIRECTION.md` for approved product decisions.

## Known limitations

- Ordinary file and folder backups are references, not embedded copies.
- Finder aliases and symbolic links currently preview their reference identity rather than automatically previewing the resolved target.
- Link preview quality depends on metadata supplied by the destination website and current network availability.
- Multi-selection and batch actions across independent ClipVault rows are intentionally out of scope.
