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

The existing Pause, Clear, and Settings controls will remain in their current upper-right area and retain their current relationship to the top portion of the main window.

The visible in-content headings:

- `ClipVault`
- `Text clipboard history`

will eventually be removed.

The main window may retain an internal title for macOS window management, Accessibility, Mission Control, and the Window menu, even when visible title text is suppressed.

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
