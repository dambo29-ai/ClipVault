# Changelog

## Unreleased

### Added

- Unified typed clipboard history for text, links, images, files, and folders.
- Persistent pinning, custom clip titles, filtering, search, retention, and scoped clearing.
- Native Link Presentation previews in List and Grid views.
- Persistent List/Grid modes for Links, Images, and Files.
- Finder-style file icons and Quick Look thumbnails.
- Quick Look previews for ordinary files and images.
- Native information previews for folders, Finder aliases, and symbolic links.
- Symbolic-link preservation and reconstruction.
- App-specific System, Light, and Dark appearance modes.
- Hardened backup import validation and restored-image cleanup.

### Changed

- File pasteboard access remains active while the file clip is on the clipboard.
- Tap-to-copy now provides the same visual feedback as a physical click.
- Grid cards use consistent dimensions.
- Link previews are cached locally and remain independent of URL copying.

### Fixed

- File clips failing to paste after security-scoped access ended too early.
- Light/Dark/System appearance transitions and Settings-tab resets.
- Intermittent Space/Escape failure when closing Quick Look.
- Alias and symbolic-link routing being mistaken for image targets.
