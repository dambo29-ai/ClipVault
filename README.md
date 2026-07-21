# ClipVault

ClipVault is a native macOS clipboard-history app built with SwiftUI and AppKit. It stores a unified history of text, links, images, files, and folders while keeping App Sandbox enabled.

## Current capabilities

- Menu-bar operation with a separately reopenable main window.
- Unified history with All, Text, Links, Images, and Files filters.
- Search, pinning, custom clip titles, scoped clearing, retention limits, and persistence.
- Optional Option-select capture using Accessibility permission.
- Sensitive-content detection with optional skipped-item warnings.
- Native list and grid views for Links, Images, and Files, remembered independently.
- Rich Link Presentation previews with local caching and offline fallbacks.
- Managed image storage, thumbnails, Quick Look, and image-aware backups.
- Sandboxed file and folder references using security-scoped bookmarks.
- Finder-style file icons and Quick Look thumbnails.
- Information previews for folders, Finder aliases, and symbolic links.
- `.clipvaultbackup` export, validation, merge, replacement, and restored-asset cleanup.
- Per-app capture rules.
- ClipVault-specific System, Light, and Dark appearance modes.

## Clipboard behavior

Clicking a normal row or grid card copies that one clip back to the system clipboard. There is no multi-selection mode.

A File clip keeps file-paste semantics. Renaming a clip changes the name of the exported copy; it does not rename or modify the original file, folder, alias, or symbolic link.

## File references and portability

ClipVault references ordinary files and folders rather than embedding their contents. Their continued availability depends on the original item and storage location remaining accessible.

Finder aliases remain aliases. Symbolic links are preserved as symbolic links, including their stored destination string. Special information previews show useful metadata when generic Quick Look would otherwise display only an icon.

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
- Network access is used for Link Presentation metadata.
- Option-select capture is off by default and requires Accessibility permission when enabled.
- Likely sensitive clips can be skipped from history while preserving the expected system-clipboard behavior.

## Appearance

Settings → Appearance provides:

- **System** — follows the current macOS appearance.
- **Light** — forces ClipVault to use Light appearance.
- **Dark** — forces ClipVault to use Dark appearance.

This changes ClipVault only, not macOS or other applications.

## Development status

The current automated baseline is **273 passing tests**. See `ClipVault/MANUAL_TEST_CHECKLIST.md` for manual regression coverage and `ClipVault/PRODUCT_DIRECTION.md` for approved product decisions.

## Known limitations

- Ordinary file and folder backups are references, not embedded copies.
- Finder-specific Quick Look presentations are not always exposed to third-party apps; ClipVault uses its own native information panel for folders, aliases, and symbolic links.
- Link preview quality depends on metadata supplied by the destination website and current network availability.
- Multi-selection and batch actions across independent ClipVault rows are intentionally out of scope.
