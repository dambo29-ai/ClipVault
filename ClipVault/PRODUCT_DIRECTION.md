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

Clear operates on the items currently represented by the active view scope.

Before Spaces exist, the scope is:

```text
Active content filter
+ Active search
```

After Spaces exist, the scope becomes:

```text
Active Space
+ Active content filter
+ Active search
```

Examples:

- Links with no search clears Links in the current view.
- Links with a search matching two items clears only those two matching Links.
- Text with a search matching five items clears only those five matching Text items.
- All with a search matching items across multiple content types clears only those matching items.
- Images or Files with no matching results leaves Clear disabled.

Search therefore participates in destructive scope. Items hidden by the active search remain untouched.

### Pinned behavior

The preferred Clear action removes only unpinned items in the active scope.

A separate stronger action removes pinned and unpinned items in the same scope.

Examples:

- `Clear Unpinned Links…`
- `Clear All Links, Including Pinned…`
- `Clear Matching Unpinned Links…`
- `Clear All Matching Links, Including Pinned…`
- `Clear Matching Unpinned Items…`
- `Clear All Matching Items, Including Pinned…`

Pinned items outside the active filter or search remain untouched.

### Native Clear menu

The existing Clear control will become a native menu button.

Its commands depend on the active filter, search state, and visible results.

Example in Links with no search:

```text
Clear Unpinned Links…
Clear All Links, Including Pinned…
```

Example in Links with an active search:

```text
Clear Matching Unpinned Links…
Clear All Matching Links, Including Pinned…
```

Example in All with an active search:

```text
Clear Matching Unpinned Items…
Clear All Matching Items, Including Pinned…
```

The stronger action that includes pinned items is secondary and explicitly labeled.

The Clear menu is disabled when the active view scope contains nothing removable.

### Confirmation counts

Confirmation titles and action labels should include the number of affected normal clipboard items where practical.

Example:

```text
Title: Clear 2 Matching Links?

This will remove 2 unpinned links matching the current search.
Pinned links will remain.

[Cancel] [Clear 2 Links]
```

Stronger example:

```text
Title: Clear 3 Matching Items, Including Pinned?

This will permanently remove 3 matching clipboard items,
including any pinned items in the current results.

[Cancel] [Clear 3 Items]
```

Counts refer to normal clipboard items rather than warning rows.

### Warning rows

Matching warning rows are also removed when their current view scope is cleared.

Warning rows:

- do not count as clipboard items in confirmation counts,
- do not count toward History Limit,
- remain unpinned and temporary.

If the active scope contains only warnings, the Clear menu should use warning-specific language such as:

```text
Clear Matching Warnings…
```

rather than describing them as clips or clipboard items.

### Clear scope examples

```text
All + no search
```

affects every item represented by All.

```text
Links + "apple"
```

affects only Links matching `apple`.

```text
Text + "invoice"
```

affects only ordinary Text items matching `invoice`, plus matching warning rows if applicable.

A future scope such as:

```text
Work + Links + "vendor"
```

will affect only matching Work Links.

Clear must never silently affect items outside the active Space, content filter, or search.

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

Image support is implemented for copied image data from Preview, Photos, Safari, image editors, Finder image files, and other applications exposing readable image pasteboard representations.

ClipVault also supports optional automatic capture of newly created macOS screenshots.

Implemented behavior:

- Managed image storage outside the lightweight history metadata.
- List and Grid thumbnails.
- Pixel dimensions, byte count, source, timestamp, pin state, and custom titles.
- Native Quick Look.
- Copy-back using useful image representations rather than the display thumbnail alone.
- Coordinated asset deletion.
- Backup packages containing required managed image assets.

Automatic screenshot behavior:

- Disabled by default.
- Detects the current macOS screenshot destination without weakening App Sandbox.
- Requires explicit read-only folder access through a security-scoped bookmark.
- Monitors only screenshots created after monitoring begins.
- Excludes screen recordings and unrelated images.
- Waits until a screenshot file is stable and readable before processing it.
- Adds the screenshot to history as an Image titled **Screenshot Created**.
- Identifies the source as **macOS Screenshot**.
- Writes the screenshot to the system clipboard so it can be pasted immediately.
- Prevents repeated filesystem callbacks from creating duplicate history items.
- Respects ClipVault’s global Pause Monitoring state.
- May require a few seconds between capture and clipboard availability.

---

## Files

ClipVault references ordinary files and folders rather than privately embedding their contents. Files copied together from Finder are currently presented as individual File clips, which is the approved user-facing behavior.

Implemented behavior:

- Sandboxed security-scoped bookmarks for ordinary files and folders.
- Native Finder-style icons and Quick Look thumbnails.
- List and Grid views.
- Automatic availability checks, iCloud-placeholder download handling, and unavailable-state warnings.
- Native Quick Look for ordinary supported files.
- Native information previews for folders, Finder aliases, and symbolic links.
- Finder aliases remain aliases when copied back.
- Symbolic links preserve their stored destination string and paste back as symbolic links.
- Custom clip titles rename exported copies only; originals are never renamed.

A reference may become unavailable if the original item is moved, renamed, deleted, disconnected, or no longer accessible. Backup packages preserve File-reference metadata but do not embed ordinary file or folder contents.

---

## Links

Links use Apple’s Link Presentation framework for native rich metadata previews.

Implemented behavior:

- Recognize valid HTTP and HTTPS URLs.
- Click the main row or grid card to copy the URL.
- Open the destination through the dedicated Open Link action or context menu.
- Independent persistent List and Grid modes.
- Representative webpage image, site icon, title, and domain when supplied.
- Local preview caching and offline fallback states.
- Preview loading never blocks or changes URL copying.
- Link preview cache is replaceable presentation data and is not required in backups.

Network access is limited to retrieving Link Presentation metadata and should remain disclosed in user documentation.

---

## Appearance

Settings provides System, Light, and Dark modes for ClipVault only.

- System follows the active macOS appearance.
- Light and Dark force ClipVault’s native AppKit appearance.
- Switching modes applies immediately without rebuilding the Settings hierarchy or resetting the active Settings section.

---

## Selection model

Each row or grid card represents one independently actionable clipboard clip. Clicking it copies that clip.

Multi-selection, checkboxes, batch paste, and batch actions across independent clips are intentionally excluded unless explicitly reconsidered later.

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
