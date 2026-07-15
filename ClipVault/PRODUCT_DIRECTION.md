# ClipVault Product Direction

This document records approved product decisions and architectural direction for ClipVault. It exists to preserve product intent across development sessions and handoffs.

Implementation details may evolve, but changes that conflict with these decisions should be discussed before code is written.

---

## Product identity

ClipVault is a native macOS clipboard-history application.

The application should feel as though it belongs on macOS. Favor:

- Native macOS controls and interaction patterns.
- AppKit where SwiftUI does not provide reliable native behavior.
- Standard title bars, toolbars, menus, alerts, spacing, keyboard behavior, accessibility, and window management.
- Restrained styling and clear visual hierarchy.
- Local-first operation and privacy-conscious defaults.
- A lean main window, with complex functionality placed in Settings, menus, services, or focused workflows.

Avoid:

- Mobile-style layouts.
- Oversized cards.
- Decorative interface elements without a functional purpose.
- Custom imitation title bars when native macOS behavior is available.
- Redundant application names or headings inside window content.
- Network activity that is not clearly necessary or disclosed.

App Sandbox remains mandatory.

---

## Main-window direction

The existing Pause, Clear, and Settings controls remain in their current upper-right area and retain their current relationship to the top portion of the main window.

The former visible in-content headings `ClipVault` and `Text clipboard history` have been removed.

The main window retains an internal title for macOS window management, Accessibility, Mission Control, and the Window menu.

The intended hierarchy is:

```text
[Existing Pause] [Existing Clear] [Existing Settings]

[ All Spaces ▾ ]

[ All ] [ Text ] [ Links ] [ Images ] [ Files ]

[ Search clipboard history… ]

PINNED
...

RECENT
...
```

Exact spacing and placement should be evaluated in the running application.

The Space selector and content filters are separate dimensions:

- A Space describes where an item belongs.
- A content filter describes what kind of item it is.

Search should operate within the currently selected Space and content filter.

---

## Unified clipboard history

ClipVault uses one unified chronological clipboard history rather than separate storage histories for each content type.

The content filters are:

```text
All | Text | Links | Images | Files
```

These are non-destructive views over the same underlying history.

- **All** displays every supported type.
- **Text** displays ordinary text that is not primarily classified as a Link.
- **Links** displays copied URLs.
- **Images** displays copied image data, including clipboard screenshots.
- **Files** displays files and folders copied from Finder or another file-oriented source.

Empty filters remain visible and provide contextual empty states.

---

## Content classification

Each clipboard event has one primary classification.

Initial precedence:

```text
Files → Images → Links → Text
```

Examples:

- A file copied from Finder is a File.
- Image pixels copied from Preview, Photos, Safari, an image editor, or a screenshot are an Image.
- A copied URL is a Link even though it is represented as text on the pasteboard.
- Ordinary writing is Text.

### Image files copied from Finder

An image file copied from Finder initially retains:

```text
Primary kind: File
File subtype: Image
```

This preserves file-paste behavior.

A later Images-filter option may include image-bearing files without duplicating the underlying clipboard item. That decision will be evaluated through actual use.

---

## History Limit and retention

There is one global History Limit across all unpinned normal clipboard items.

```text
History Limit = maximum number of unpinned normal items
```

Rules:

- Unpinned normal items count toward History Limit.
- Warning rows do not count.
- Pinned items do not count.
- Warning rows do not displace normal history.
- Pinned items do not displace unpinned normal history.
- Age-based retention does not remove pinned items.
- Restored backup items retain their existing special retention behavior unless deliberately redesigned later.

Independent category quotas are deferred unless real use demonstrates that one content type consistently starves another.

---

## Visible history numbering

Visible numbers represent positions in the currently displayed unpinned history rather than permanent item identifiers.

Rules:

- Unpinned normal items receive sequential visible numbers.
- Warning rows receive no number.
- Pinned items receive no number.
- Filtering recalculates visible numbering.
- Search results use consecutive visible numbering.
- Warning rows must not make the interface appear to exceed History Limit.

Example:

```text
2  Newer normal item
   Red warning
1  Older normal item
```

When pinning exists:

```text
PINNED
   Frequently used item

RECENT
2  Newer unpinned item
1  Older unpinned item
```

---

## Pinning

Normal clipboard items may be pinned for protection and repeated use.

Warning rows can never be pinned.

A pinned item:

- Moves from Recent into a Pinned section above Recent.
- Receives no visible history number.
- Survives History Limit trimming.
- Survives age-based retention.
- Survives the standard Clear action.
- Remains searchable.
- Appears only in applicable content filters.
- Retains its original capture timestamp and source metadata.
- Preserves its pin state through relaunch.

The Pinned section appears only when the active filter contains matching pinned items.

Examples:

- A pinned Link appears in All and Links.
- A pinned ordinary text item appears in All and Text.
- A pinned Link does not appear in Text.

Unpinning returns an item to Recent according to its original capture timestamp, not the time it was unpinned.

### Pin ordering

Initial pin ordering is based on `pinnedAt`, with the most recently pinned item first.

Copying or using a pin does not reorder it.

Custom drag-and-drop pin ordering is deferred.

### Pin controls

Normal rows use a trailing pin action grouped with the existing row controls.

Conceptually:

```text
Ordinary text: [Pin] [Delete]
Link:          [Open Link] [Pin] [Delete]
```

Use native SF Symbols:

```text
pin
pin.fill
```

Behavior:

- Unpinned-row pin controls may appear on hover to reduce clutter.
- The filled pin remains visible for pinned rows because it communicates persistent state.
- Clicking Pin or Unpin does not copy the item.
- Clicking the main row continues to copy.
- Context menus include Pin or Unpin.
- Warning rows expose no pin control or Pin context-menu command.
- Pin controls include native tooltips and Accessibility labels.

---

## Pinned duplicate behavior

When newly copied content matches an existing pinned item:

- Do not create another item.
- Keep the existing item pinned.
- Keep its position within the Pinned section.
- Do not change `pinnedAt`.
- Do not move the item into Recent.
- Briefly highlight the existing pinned row.
- Scroll it into view when appropriate and when it is visible in the active filter.

The highlight should be restrained:

- Use a native accent or selection-style background.
- Fade in and out once.
- Avoid pulsing, bouncing, or decorative animation.
- Respect Reduce Motion.
- Suppress repeated flashes during rapid duplicate captures.

If the existing pin is hidden by the active content filter, ClipVault should not switch filters automatically.

Duplicate behavior for unpinned items remains unchanged: the existing item moves or replaces according to the current text-based duplicate policy rather than creating another copy event.

---

## Clear behavior

Clear operates within the currently active content filter.

Examples:

- Clear from Links affects Links only.
- Clear from Text affects Text only.
- Clear from All affects all supported content types.
- Images and Files follow the same rule when implemented.

When Spaces exist, the active Space will also constrain Clear.

For example:

```text
Work + Links
```

means that Clear affects only items assigned to Work that are classified as Links.

### Native Clear menu

The existing Clear control will become a native menu button.

Its commands depend on the active filter.

Example in Links:

```text
Clear Unpinned Links…
Clear All Links, Including Pinned…
```

Example in All:

```text
Clear All Unpinned History…
Clear All History, Including Pinned…
```

The normal and preferred action removes only unpinned items in the current scope.

The stronger action that includes pinned items is secondary and explicitly labeled.

### Confirmations

Clearing unpinned items uses a contextual confirmation.

Example in Links:

```text
Title: Clear Link History?

This will remove all unpinned links currently shown in the Links view.
Pinned links will remain.

[Cancel] [Clear Unpinned]
```

Example in All:

```text
Title: Clear All Clipboard History?

This will remove all unpinned clipboard items.
Pinned items will remain.

[Cancel] [Clear Unpinned]
```

Clearing pinned and unpinned items requires stronger confirmation.

Example in Links:

```text
Title: Clear Pinned and Unpinned Links?

This will permanently remove all links in the current view, including
items that were pinned for protection.

[Cancel] [Clear Everything]
```

Example in All:

```text
Title: Clear All Pinned and Unpinned History?

This will permanently remove all clipboard history, including pinned items.

[Cancel] [Clear Everything]
```

---

## Spaces

The organizational feature will be called Spaces rather than Profiles or Collections.

Examples:

```text
Home
Work
Family
Travel
```

The aggregate selection is:

```text
All Spaces
```

This avoids a naming collision with the All content filter.

Initial behavior:

- An item belongs to one Space at a time.
- Assignment is manual.
- Spaces are user-named.
- Space and content type remain independent dimensions.
- `All Spaces + Images` displays Images from every Space.
- `Work + All` displays every type assigned to Work.

Automatic assignment, multi-Space membership, and tag-like behavior are deferred until the basic workflow has been tested.

---

## Images

Image support concerns copied image data rather than only image files.

Potential sources include:

- Preview.
- Photos.
- Safari.
- Image editors.
- Screenshots copied directly to the clipboard.
- Other apps exposing readable image pasteboard representations.

An image item should eventually display:

- A thumbnail.
- Pixel dimensions where available.
- Data size where useful.
- Source application.
- Timestamp.
- Pin state.

Copying an image item back to the clipboard should restore useful original representations where practical, not merely copy its display thumbnail.

Large image payloads should be stored separately from history metadata.

Recommended storage direction:

- Lightweight history metadata.
- Separate Application Support files for image payloads.
- Separate generated thumbnails.
- Coordinated asset deletion.
- Backups containing both metadata and required assets.

Large image data should not be embedded directly in the current JSON history file.

---

## Files

ClipVault will reference copied files rather than privately duplicating them.

A File item may represent:

- One file.
- Multiple files copied in one clipboard event.
- A folder.
- A mixed group of files and folders.

A File row should eventually support:

- File or folder name.
- Native icon or preview where appropriate.
- Original path.
- File or folder distinction.
- Multiple-item summaries.
- Missing or unavailable state.
- Source application.
- Timestamp.
- Pin state.

A reference may become unavailable if the original is moved, renamed, deleted, disconnected, or no longer accessible.

App Sandbox remains mandatory. File support must therefore use a sandbox-compatible access and restoration design.

---

## Links

Links initially remain local and restrained.

Behavior:

- Recognize valid `http://` and `https://` URLs.
- Display the URL.
- Indicate Link status through the trailing Open Link control.
- Click the main row to copy.
- Use the trailing Link icon or context menu to open in the default browser.

Automatic website previews are deferred because they introduce network requests, caching, privacy concerns, failure states, and additional storage.

ClipVault should not silently contact every copied domain.

---

## Warning rows

Skipped-capture warnings remain temporary interface feedback rather than normal clipboard content.

They are:

- Red.
- Bold.
- Non-copyable.
- Individually deletable.
- Excluded from persistence.
- Excluded from History Limit.
- Excluded from retention.
- Excluded from visible numbering.
- Ineligible for pinning.

Native `Command–C` warnings and Option-select warnings must continue to describe their different clipboard outcomes accurately.

---

## Architectural direction

The current text-oriented model will evolve toward a content-neutral item model.

Conceptually:

```swift
ClipboardItem {
    id
    contentKind
    payload
    searchableText
    timestamp
    source
    origin
    isPinned
    pinnedAt
    spaceID
}
```

Likely content kinds:

```swift
enum ClipboardContentKind {
    case text
    case link
    case image
    case files
    case warning
}
```

Prefer a typed payload design over many unrelated optional properties.

Conceptually:

```swift
enum ClipboardPayload {
    case text(TextPayload)
    case link(LinkPayload)
    case image(ImagePayload)
    case files(FilePayload)
    case warning(WarningPayload)
}
```

These sketches describe architectural intent rather than paste-ready implementation. The final design must account for the existing code, persistence, backward compatibility, Swift concurrency, backups, and App Sandbox.

---

## Development order

The current planned sequence is:

1. Add backward-compatible persisted pin metadata.
2. Protect pins from History Limit and age retention.
3. Divide filtered results into Pinned and Recent collections.
4. Add the Pinned and Recent interface sections.
5. Add trailing Pin and Unpin controls and context-menu commands.
6. Replace Clear with the filter-scoped native Clear menu.
7. Add pinned-duplicate highlighting.
8. Introduce backward-compatible content-neutral item classification.
9. Add image capture, storage, display, restoration, and backups.
10. Design and add sandbox-compatible File support.
11. Add Spaces after heterogeneous content and pinning are stable.

Each stage must preserve existing behavior, add focused automated coverage where practical, and receive manual regression testing before commit.

Do not combine persistence migration, retention changes, UI restructuring, Clear redesign, duplicate highlighting, image storage, File access, and Spaces into one refactor.

---

## Deferred features

The following remain deferred until their prerequisites are stable:

- Website previews.
- Multi-Space membership.
- Automatic Space assignment.
- Source-app routing into Spaces.
- User-authored snippets.
- Drag-and-drop pin ordering.
- Content-category quotas.
- iOS companion application.
- Cross-device sync.
- SwiftData migration.
- Image Files appearing in both Files and Images filters.
- Private File duplication or archival inside ClipVault.
