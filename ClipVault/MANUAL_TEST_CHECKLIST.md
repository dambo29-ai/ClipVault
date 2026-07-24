# ClipVault Manual Test Checklist

Use this checklist after structural changes, persistence changes, UI refactors, or before creating a checkpoint.

Record the macOS and ClipVault build versions when performing a full regression test.

## Automated Test Baseline

Current automated baseline:

* **277 total tests passing.**
* Coverage includes typed payloads, persistence, retention, search classification, file references, aliases, symbolic links, image storage, backups, import rollback, asset cleanup, Link Presentation caching, List/Grid persistence, appearance mapping, file visuals, native Quick Look preparation, regular-file metadata reading, and sensitive-content capture-policy precedence.

These automated tests supplement this checklist; they do not replace manual cross-application and user-interface testing.

---

## 1. Launch and Window Behavior

* [ ] ClipVault launches without displaying the main window automatically.
* [ ] The ClipVault menu-bar icon appears.
* [ ] Clipboard monitoring begins after launch.
* [ ] **Show ClipVault** opens the main window.
* [ ] Closing the main window does not quit ClipVault.
* [ ] Reopening the main window works.
* [ ] The main window can be resized down to approximately 480 × 400.
* [ ] The header controls remain horizontal at the minimum window size.
* [ ] The search field, clipboard rows, row numbers, and trash icons remain visible at the minimum size.
* [ ] The Settings window opens at approximately 700 points wide.
* [ ] Settings opens on **General**.
* [ ] General, Appearance, and Privacy resize vertically to fit their content.
* [ ] App Rules remains at a stable taller height.
* [ ] Switching tabs produces a smooth resize without bouncing or clipping.
* [ ] Settings content begins with consistent spacing beneath the toolbar.
* [ ] The bottom spacing in General, Appearance, and Privacy is visually balanced.
* [ ] The native toolbar tabs display General, Appearance, Privacy, and App Rules.
* [ ] No sidebar-toggle control appears.
* [ ] The Settings traffic-light controls display normally.

---

## 2. Menu-Bar Commands

* [ ] **Show ClipVault** opens and activates the main window.
* [ ] **Settings** opens and activates the Settings window.
* [ ] **Pause Monitoring** pauses clipboard capture.
* [ ] **Resume Monitoring** resumes clipboard capture.
* [ ] History commands work.
* [ ] Backup commands work.
* [ ] Help opens correctly.
* [ ] Quit closes ClipVault completely.

---

## 3. Keyboard Shortcuts

* [ ] The default **Show ClipVault** shortcut works.
* [ ] The default **Pause/Resume Monitoring** shortcut works.
* [ ] Custom shortcut changes take effect.
* [ ] Shortcut changes persist after relaunch.
* [ ] Clearing a shortcut works.
* [ ] `Command–Comma` opens Settings when ClipVault is active.
* [ ] Escape clears an active clipboard search.
* [ ] Shortcut recorder fields remain aligned in General Settings.

---

## 4. Clipboard Capture

* [ ] Copying normal text creates a new clipboard-history row.
* [ ] The copied text appears correctly.
* [ ] The source application name appears correctly.
* [ ] The source bundle identifier appears correctly.
* [ ] The timestamp appears correctly.
* [ ] Row numbering appears correctly.
* [ ] Copying several clips rapidly captures them without freezing.
* [ ] Copying the same text again moves or replaces the existing clip rather than creating an unwanted duplicate.
* [ ] Clipboard monitoring continues while the main window is closed.
* [ ] Pausing monitoring prevents new clips from being saved.
* [ ] Resuming monitoring restores clipboard capture.

### Option-Select Capture

* [ ] **Enable Option-Select Capture** defaults to off when no preference has previously been saved.
* [ ] Enabling Option-select starts capture immediately without requiring a relaunch.
* [ ] Disabling Option-select stops capture immediately without requiring a relaunch.
* [ ] The Option-select preference persists after relaunch.
* [ ] Enabling Option-select requests Accessibility access only when access has not already been granted.
* [ ] **Selection Capture Permission** accurately reports whether Accessibility access is granted.
* [ ] Option-select controls appear in Privacy rather than General.
* [ ] Normal Command-C monitoring works without Accessibility permission.
* [ ] Holding Option while dragging across text copies the completed selection.
* [ ] Option-click without dragging does not trigger capture.
* [ ] Dragging without Option does not trigger capture.
* [ ] The Option-selected text becomes the active system clipboard item.
* [ ] Immediately pressing `Command–V` pastes the Option-selected text.
* [ ] Accepted Option-selected text appears once at the top of ClipVault history.
* [ ] The source application name is correct.
* [ ] The source bundle identifier is correct.
* [ ] Option-selecting the same text again moves or replaces the existing item instead of creating a duplicate.
* [ ] Option-select capture works while the main ClipVault window is closed.
* [ ] Pausing clipboard monitoring prevents Option-selected text from being saved to history.
* [ ] While monitoring is paused, Option-select restores the previous clipboard and does not make the selected text pasteable.
* [ ] Resuming monitoring allows subsequent Option-selected text to be saved again.
* [ ] Option-select works in TextEdit.
* [ ] Option-select works in Notes.
* [ ] Option-select works in Safari.
* [ ] Option-select works in Apple Mail.
* [ ] Option-select works in Microsoft Word.
* [ ] Rapid repeated Option-select gestures do not crash ClipVault or corrupt clipboard history.
* [ ] A gesture that produces no readable text does not replace the last valid clipboard item.

### Option-Select Transaction Regression

Run these checks after changing `SelectionClipboardTransactionService`, clipboard snapshot behavior, capture policy routing, or clipboard-monitoring suppression.

* [ ] Accepted Option-selected text remains the active system clipboard item and appears once in ClipVault history.
* [ ] Option-selecting text from a Blocked app restores the previous clipboard and does not save the blocked text.
* [ ] A likely-sensitive Option-selection restores the previous clipboard and does not save the sensitive text.
* [ ] Option-selecting while clipboard monitoring is paused restores the previous clipboard and does not save the selected text.
* [ ] After each rejected Option-selection, normal clipboard monitoring resumes and the next ordinary `Command–C` is captured correctly.

---

## 5. Clipboard Row Actions

* [ ] Clicking a normal clipboard row copies it back to the system clipboard.
* [ ] The copied clip can be pasted into another application.
* [ ] Clicking a skipped-warning row does nothing.
* [ ] Deleting a normal row works.
* [ ] Deleting a skipped-warning row works.
* [ ] Trash icons align consistently across all row types.
* [ ] Row numbers and trash icons visually balance the list.
* [ ] Dividers extend across the full row width.
* [ ] The final row does not display an unnecessary divider.

---

## 6. Clipboard Search

* [ ] The main search field is visually distinct from its surrounding background.
* [ ] Typing filters clipboard results immediately.
* [ ] Search is case-insensitive.
* [ ] The clear-search button appears after entering text.
* [ ] The clear-search button restores the full list.
* [ ] Escape clears the search.
* [ ] A search with no matches displays **No matching clips found**.
* [ ] An empty history displays **No copied text yet**.
* [ ] The two empty states are visually centered and distinct.

---

## 7. Sensitive-Clip Protection

### Default Protection

* [ ] **Block Likely Sensitive Clips** appears in Privacy.
* [ ] Protection defaults to on when no preference has previously been saved.
* [ ] The protection preference persists after relaunch.
* [ ] A likely password copied from an Allowed app is skipped while protection is on.
* [ ] A skipped sensitive clip remains available in the system clipboard.
* [ ] A likely-sensitive Option-selection restores the previous clipboard and is not saved.
* [ ] A likely-sensitive Option-selection produces one skipped-warning row when warnings are enabled.
* [ ] The skipped-warning row is red.
* [ ] The warning text is bold.
* [ ] The warning row is non-clickable.
* [ ] The warning row can be deleted.
* [ ] Skipped-warning rows are not restored after relaunch.

### Disabling Protection

* [ ] Turning protection off displays the confirmation dialog.
* [ ] Selecting **Cancel** leaves protection enabled.
* [ ] Selecting **Allow Sensitive Clips** disables protection.
* [ ] The confirmation explains that sensitive clips may be retained across launches and included in backups.
* [ ] With protection off, a likely password copied from an Allowed app is stored in ClipVault.
* [ ] Disabling protection affects future clips only.
* [ ] Previously skipped clips are not recovered.
* [ ] Turning protection back on does not delete previously stored clips.

### Rule Precedence

* [ ] Smart mode continues skipping likely passwords, tokens, API keys, and secret-looking text while global protection is off.
* [ ] Blocked mode continues rejecting all capture while global protection is off.
* [ ] Blocked copied text remains available in the system clipboard.
* [ ] Allowed mode follows the global sensitive-clip protection preference.
* [ ] Normal non-sensitive text is unaffected by the global protection preference.
* [ ] Option-select capture follows the same Allowed, Smart, and Blocked policy precedence.

### Warning Preference

* [ ] Disabling **Show Skipped Clip Warnings** prevents future warning rows without disabling protection.
* [ ] Re-enabling the warning setting restores future warning rows.
* [ ] The skipped-warning preference persists after relaunch.

Expected likely-sensitive warning:

```text
(Likely sensitive clip skipped in ClipVault. Clip still available in system clipboard for use.)
```

---

## 8. General Settings

* [ ] History Limit works.
* [ ] History Limit persists after relaunch.
* [ ] Keep History For works.
* [ ] Keep History For remains responsive.
* [ ] Changing retention removes only clips outside the selected period.
* [ ] Keep History For persists after relaunch.
* [ ] Backups to Keep accepts valid values.
* [ ] Backups to Keep persists after relaunch.
* [ ] Show Skipped Clip Warnings works.
* [ ] Keyboard-shortcut rows remain aligned.
* [ ] General does not contain Option-select or Accessibility controls.
* [ ] General typography is consistent with the other Settings tabs.
* [ ] General content begins and ends with balanced spacing.

---

## 9. Appearance Settings

* [ ] System follows the current macOS appearance.
* [ ] Light forces ClipVault into Light appearance.
* [ ] Dark forces ClipVault into Dark appearance.
* [ ] Appearance changes affect ClipVault only.
* [ ] The selected appearance mode persists after relaunch.
* [ ] Switching appearance modes does not change the selected Settings tab.
* [ ] The three appearance options are centered.
* [ ] Appearance content begins and ends with balanced spacing.
* [ ] Appearance typography matches the General and Privacy tabs.

---

## 10. Privacy Settings

* [ ] Privacy contains Block Likely Sensitive Clips.
* [ ] Privacy contains Screenshot Folder Access.
* [ ] Privacy shows the actual macOS screenshot destination rather than the sandbox container path.
* [ ] Screenshot Folder Access reports Access Granted after the user approves the correct folder.
* [ ] Screenshot folder access persists after quitting and reopening ClipVault.
* [ ] Selecting the wrong folder is rejected without removing valid existing access.
* [ ] Privacy contains Automatically Copy New Screenshots.
* [ ] Automatic screenshot copying is Off by default for a new installation.
* [ ] Monitoring status appears above the toggle.
* [ ] Monitoring is green and visually matches the Access Granted status.
* [ ] The setting explains that screenshots may take a few seconds to appear and become available for pasting.
* [ ] Privacy contains Enable Option-Select Capture.
* [ ] Privacy contains Selection Capture Permission.
* [ ] Privacy contains the Link Preview Privacy disclosure.
* [ ] Accessibility status refreshes after returning from System Settings.
* [ ] The Link Preview disclosure accurately explains network retrieval and local caching.
* [ ] Privacy grows automatically when content is added.
* [ ] Privacy content begins and ends with balanced spacing.
* [ ] Privacy typography matches the General and Appearance tabs.

---

## 11. Automatic Screenshot Capture

### Enabled

* [ ] Grant access to the current macOS screenshot folder.
* [ ] Turn Automatically Copy New Screenshots On.
* [ ] The status changes to Monitoring.
* [ ] Quit and reopen ClipVault.
* [ ] The toggle remains On and monitoring resumes.
* [ ] Take one screenshot using Shift–Command–3 or Shift–Command–4.
* [ ] After a short processing delay, exactly one new Image item appears.
* [ ] The item title is Screenshot Created.
* [ ] The source is macOS Screenshot.
* [ ] The redundant Copied Image subtitle is not shown.
* [ ] The screenshot can be pasted immediately without first clicking its ClipVault row.
* [ ] The screenshot pastes as image data rather than a filename or file reference.
* [ ] Waiting or switching applications does not create another row for the same capture event.
* [ ] Taking the same visible screenshot a second time creates a second history item because it is a separate capture action.
* [ ] A normal image copied from another application still displays Copied Image.
* [ ] An image file copied from Finder retains normal Finder file-copy behavior until its ClipVault Image row is clicked.

### Disabled

* [ ] Turn Automatically Copy New Screenshots Off.
* [ ] The status changes to Not Monitoring.
* [ ] Copy recognizable text.
* [ ] Take a screenshot.
* [ ] The screenshot file is still saved by macOS.
* [ ] No screenshot item is added automatically.
* [ ] The recognizable text remains on the system clipboard.

### Paused

* [ ] Turn screenshot automation On.
* [ ] Pause ClipVault monitoring from the menu bar.
* [ ] Copy recognizable text.
* [ ] Take a screenshot.
* [ ] No screenshot item is stored.
* [ ] The screenshot does not replace the recognizable clipboard text.
* [ ] Resume monitoring afterward.

### Exclusions

* [ ] Create a short macOS screen recording.
* [ ] The recording file is not added to ClipVault.
* [ ] The recording does not change the system clipboard.
* [ ] An unrelated image added to the screenshot folder is not automatically captured.

---

## 12. App Rules Layout

* [ ] App Rules opens without a beach ball.
* [ ] The first transition from General to App Rules is acceptably fast.
* [ ] Later transitions remain fast.
* [ ] App Rules begins with spacing consistent with the other Settings tabs.
* [ ] The search field, filter controls, information button, and Actions menu align correctly.
* [ ] The filter panel has balanced left and right padding.
* [ ] Application names and mode menus have an appropriate horizontal gap.
* [ ] Mode menus remain vertically aligned across rows.
* [ ] The application list scrolls independently while the upper controls remain fixed.
* [ ] The information popover opens and explains App Rule modes.
* [ ] Mode pickers align with the right edge of the search field.
* [ ] The count summary remains centered.
* [ ] The App Rules controls remain fixed while only the app list scrolls.
* [ ] Application icons load correctly.
* [ ] Scrolling remains smooth.
* [ ] Icons remain correct after searching and changing filters.

---

## 13. App Rules Search and Filters

* [ ] The App Rules search field is visually distinct from its surrounding background.
* [ ] Search matches application display names.
* [ ] Search matches bundle identifiers.
* [ ] The clear-search button works.
* [ ] **All Apps** works.
* [ ] **Smart + Blocked** works.
* [ ] **Blocked Only** works.
* [ ] **Custom Rules Only** works.
* [ ] **Show Hidden Utility Apps** works.
* [ ] A search with no matches displays a centered empty state.
* [ ] An empty application list displays a centered empty state.

---

## 14. App Rules Counts

* [ ] Allowed count is correct.
* [ ] Smart count is correct.
* [ ] Blocked count is correct.
* [ ] Allowed + Smart + Blocked equals the denominator.
* [ ] **Showing X of Y** reflects the active mode filter.
* [ ] Search updates the counts consistently.
* [ ] Show Hidden Utility Apps updates the counts consistently.
* [ ] The centered count summary does not shift unexpectedly.

---

## 15. App Rule Modes

* [ ] Allowed mode saves normal copied text.
* [ ] Smart mode permits obvious URLs.
* [ ] Smart mode permits obvious email addresses.
* [ ] Smart mode skips likely passwords, tokens, API keys, and secret-looking text.
* [ ] Blocked mode never saves copied text from the selected app.
* [ ] Blocked copied text remains available in the system clipboard.
* [ ] A blocked warning row appears when skipped warnings are enabled.
* [ ] Allowed mode saves accepted Option-selected text.
* [ ] Smart mode applies the same sensitive-content policy to Option-selected text as to normal copied text.
* [ ] Blocked mode does not save Option-selected text from the blocked app.
* [ ] Option-selecting text in a blocked app restores the previous clipboard and does not make the blocked text pasteable.
* [ ] A blocked-app Option-selection produces one warning row when warnings are enabled.
* [ ] The blocked-app warning identifies the correct source application.
* [ ] The Blocked picker label displays normally without literal asterisks.
* [ ] A lock icon appears only when the app is Blocked.
* [ ] The lock icon does not leave an empty gap in Allowed or Smart modes.

---

## 16. Custom App Rules

* [ ] Changing an app rule creates a custom override.
* [ ] A blue dot appears for a custom rule.
* [ ] A reset icon appears beside the blue dot.
* [ ] The blue dot tooltip identifies it as a custom rule.
* [ ] The information popover explains the blue dot.
* [ ] Resetting one app removes its custom override.
* [ ] The blue dot and reset icon disappear after reset.
* [ ] The mode picker does not shift when indicators appear or disappear.
* [ ] Reset to Defaults clears all custom overrides.
* [ ] Default-blocked apps do not incorrectly display custom-rule indicators after a global reset.
* [ ] Custom rules persist after relaunch.

---

## 17. App Discovery

* [ ] Existing known applications load when App Rules opens.
* [ ] **Refresh App List** starts an asynchronous refresh.
* [ ] A small progress indicator appears during refresh.
* [ ] The refresh command is disabled while refreshing.
* [ ] Search remains responsive during refresh.
* [ ] Filters remain responsive during refresh.
* [ ] Scrolling remains responsive during refresh.
* [ ] The progress indicator disappears after refresh.
* [ ] Newly discovered apps appear.
* [ ] Discovered apps persist after relaunch.
* [ ] Clicking refresh repeatedly does not crash ClipVault.
* [ ] Repeated refreshes do not create duplicate visible applications.
* [ ] Copying from a previously unknown application adds it to App Rules.

---

## 18. Default Blocked Applications

Confirm the intended defaults where installed:

* [ ] 1Password is Blocked by default.
* [ ] Bitwarden is Blocked by default.
* [ ] NordPass is Blocked by default.
* [ ] Keychain Access is Blocked by default.
* [ ] Applications with “password” in the visible name are Blocked by default where appropriate.
* [ ] Resetting these applications restores the computed default rather than Allowed.

---

## 19. Clipboard Persistence

* [ ] Normal clipboard history survives relaunch.
* [ ] Deleted clips remain deleted after relaunch.
* [ ] Clearing history remains cleared after relaunch.
* [ ] Rapidly copied clips persist correctly.
* [ ] Rapidly deleted clips remain deleted.
* [ ] Quitting immediately after copying does not lose recent changes.
* [ ] Quitting immediately after deleting does not restore deleted items.
* [ ] Clearing history and immediately quitting remains cleared.
* [ ] Saving resumes normally after clearing history and copying again.
* [ ] Skipped-warning rows are not persisted.

---

## 20. History Limits and Retention

### History Limit

* [ ] History does not exceed the selected normal-clip limit.
* [ ] Lowering the History Limit removes only the oldest excess normal clips.
* [ ] Increasing the History Limit allows additional normal clips.
* [ ] Skipped-warning rows do not count toward the History Limit.
* [ ] Adding a skipped-warning row does not remove a normal clip that is within the History Limit.
* [ ] Visible warning rows do not cause a valid backup import to exceed the History Limit.
* [ ] History Limit values below 10 are corrected to 10 after loading.
* [ ] History Limit values above 500 are corrected to 500 after loading.
* [ ] The History Limit Stepper stops at 10 and 500.
* [ ] The History Limit persists after relaunch.

### Time-Based Retention

* [ ] Time-based retention removes expired clips captured normally by ClipVault.
* [ ] Forever retention preserves all normal clips within the History Limit.
* [ ] Changing retention does not freeze the interface.
* [ ] Retention rules apply correctly after relaunch.
* [ ] Clips restored from a backup are retained regardless of their original age.
* [ ] Restored historical clips survive relaunch.
* [ ] Changing Keep History For does not remove restored historical clips.
* [ ] Capturing a new clip does not remove restored historical clips because of their age.
* [ ] Newly captured clips remain subject to the active retention setting.

---

## 21. History Export

* [ ] Export History creates a readable `.txt` file.
* [ ] The exported text contains normal clipboard items.
* [ ] The export preserves useful ordering.
* [ ] Skipped-warning rows are excluded.
* [ ] Exporting an empty history behaves appropriately.
* [ ] Export completes without freezing or crashing.

---

## 22. Backup Packages

* [ ] Export Backup creates a `.clipvaultbackup` package.
* [ ] The filename follows the expected timestamp format.
* [ ] The package contains `manifest.json`.
* [ ] The package contains an `Images` directory.
* [ ] The backup manifest uses the current supported format version.
* [ ] The backup contains normal clipboard items.
* [ ] Skipped-warning rows are excluded.
* [ ] Image items include their managed image assets.
* [ ] Shared image assets are written only once.
* [ ] Missing managed image assets cause export to fail safely.
* [ ] Restored clips preserve their original `createdAt` timestamps.
* [ ] Backups to Keep is respected.
* [ ] Backups to Keep values below 1 are corrected to 1 after loading.
* [ ] Backups to Keep values above 50 are corrected to 50 after loading.
* [ ] The Backups to Keep Stepper stops at 1 and 50.
* [ ] Automatic cleanup removes only packages beyond the configured limit.
* [ ] Automatic cleanup uses the manifest export date rather than only the filename.
* [ ] Malformed packages are ignored when finding the latest valid backup.
* [ ] Manual Delete Old Backups works.
* [ ] Reveal Latest Backup selects the newest valid package.
* [ ] Backup creation does not freeze or crash.

Expected filename format:

```text
ClipVault Backup yyyy-MM-dd HH-mm-ss.clipvaultbackup
```

---

## 23. Backup Import

### Import Entry Points

* [ ] Import Latest Backup works.
* [ ] Dragging a valid .clipvaultbackup package into the main window works.
* [ ] Both import entry points produce consistent results and alerts.
* [ ] Both import entry points use the same duplicate, limit, and replacement behavior.

### Normal Merge

* [ ] Imported items merge with existing history.
* [ ] Import does not replace unrelated existing clips.
* [ ] Imported clips preserve their original text.
* [ ] Imported clips preserve their original timestamps.
* [ ] Imported clips are marked as restored.
* [ ] Imported historical clips are restored regardless of age.
* [ ] Imported historical clips remain after relaunch.
* [ ] Importing into empty history works.
* [ ] An import that exactly reaches the History Limit succeeds.
* [ ] Warning rows do not count toward import capacity.

### Duplicate Handling

* [ ] Items already present in current history are skipped.
* [ ] Duplicate text within one backup is skipped.
* [ ] Duplicate comparison remains based on trimmed text.
* [ ] A mixed backup imports new clips and skips duplicates.
* [ ] The imported count is correct.
* [ ] The duplicate count is correct.
* [ ] A duplicate-only backup displays **No New Clips Imported**.
* [ ] Duplicate-only import does not display a zero-count imported line.
* [ ] Import does not create identical normal clipboard rows.

### History-Limit Handling

* [ ] An over-limit backup containing older clips displays the limit confirmation.
* [ ] An over-limit backup containing newer clips displays the limit confirmation.
* [ ] Over-limit detection does not mutate existing history.
* [ ] The required minimum History Limit is calculated using normal clips only.
* [ ] Warning rows do not cause a false over-limit result.
* [ ] Open Settings is offered when the required limit is 500 or less.
* [ ] Open Settings is not offered when the required limit is greater than 500.
* [ ] Replace is offered for an over-limit import.
* [ ] Cancel leaves history unchanged.
* [ ] Cancel works when the required limit is greater than 500.

### Open Settings

* [ ] Choosing Open Settings leaves history unchanged.
* [ ] Choosing Open Settings opens General Settings.
* [ ] ClipVault becomes active after General Settings opens.
* [ ] The instructional alert states that the backup has not been imported.
* [ ] The instructional alert gives the exact minimum required History Limit.
* [ ] The instructional alert tells the user to run the import again.
* [ ] The pending backup is not imported automatically after changing the limit.

### Replace

* [ ] Replace removes the existing normal clipboard history.
* [ ] Replace imports normal items from the selected backup.
* [ ] Replace excludes warning rows and other non-normal items.
* [ ] Replace removes duplicate text within the backup.
* [ ] Replace sorts restored clips by their original timestamps.
* [ ] Replace marks accepted clips as restored.
* [ ] Replace trims the restored history to the current History Limit.
* [ ] Replace reports duplicate clips when duplicates were removed.
* [ ] Replace reports clips omitted because of the History Limit.
* [ ] Replace does not display zero-count result lines.
* [ ] Replacement results survive relaunch.

### Package Validation and Failure Handling

* [ ] A package with the wrong extension is rejected safely.
* [ ] A missing package is rejected safely.
* [ ] A `.clipvaultbackup` item that is not a directory is rejected safely.
* [ ] A package without `manifest.json` is rejected safely.
* [ ] An unreadable or malformed manifest is rejected safely.
* [ ] A package with an invalid application name is rejected safely.
* [ ] An unsupported package format version is rejected safely.
* [ ] A package with no importable normal items is rejected safely.
* [ ] A package with a missing image asset is rejected safely.
* [ ] A package with a damaged or hash-mismatched image asset is rejected safely.
* [ ] A package with conflicting image metadata is rejected safely.
* [ ] A failed image restoration removes assets already written during that attempt.
* [ ] Cancelling an import removes newly restored assets.
* [ ] Image assets omitted by duplicate or History Limit resolution are removed.
* [ ] Existing managed image assets are never deleted by failed package restoration.
* [ ] Import failure alerts do not expose low-level decoder or filesystem messages.
* [ ] Dropping a normal `.json` file does not import it as a backup.
* [ ] Dropping multiple packages together is rejected.
* [ ] Dropping a package together with an image is rejected.

---

## 24. Links, Images, and Files Views

* [ ] Links, Images, and Files each remember their List/Grid mode independently.
* [ ] The view toggle appears beside Search only for supported filters.
* [ ] All, Text, and other unsupported filters remain List-only.
* [ ] Grid cards remain uniform in height with long custom titles.
* [ ] Tap-to-click and physical click provide the same copy-feedback animation.
* [ ] No multi-selection or checkbox interface appears.

### Link Previews

* [ ] Cached previews appear immediately.
* [ ] New public links load native rich metadata without opening a browser.
* [ ] Missing metadata uses a site-icon or globe/domain fallback.
* [ ] Offline links remain copyable.
* [ ] Link copying is immediate while metadata is loading.
* [ ] List thumbnails and Grid previews remain visually consistent.

### Image and File Visuals

* [ ] Image thumbnails display correctly in List and Grid.
* [ ] PDFs and supported files receive native Quick Look thumbnails.
* [ ] Folders, archives, aliases, and symbolic links receive native macOS icons.
* [ ] File copy/paste works from both List and Grid.
* [ ] Renaming changes only the exported copy, never the original item.

---

## 25. Native Quick Look

* [ ] Images open with native Quick Look controls, Share, full screen, and Open with Preview.
* [ ] PDFs open with native document controls, page thumbnails, Share, and Open with Preview.
* [ ] MP3 and other supported audio files display embedded artwork and metadata when available.
* [ ] MP3 and other supported audio files use native playback controls.
* [ ] MP3 and other supported audio files autoplay.
* [ ] MP4 and other supported video files use native playback controls.
* [ ] MP4 and other supported video files autoplay.
* [ ] ZIP archives display filename, size, modified date, Share, and Uncompress.
* [ ] DMG files display filename, size, modified date, Share, and Mount.
* [ ] Folders display native folder information, item count, modified date, and Share.
* [ ] Finder aliases open in native Quick Look without crashing.
* [ ] Symbolic links open in native Quick Look without crashing.
* [ ] Finder aliases and symbolic links may display the reference rather than the resolved target.
* [ ] Multi-file previews remain functional.
* [ ] Space consistently closes the active preview.
* [ ] Escape consistently closes the active preview.
* [ ] The native close control consistently closes the active preview.
* [ ] Preview remains closable after clicking the main ClipVault window.
* [ ] Repeated open-and-close cycles remain responsive.
* [ ] Closing previews releases security-scoped access correctly.

---

## 26. Appearance

* [ ] Settings → Appearance offers System, Light, and Dark.
* [ ] System follows macOS.
* [ ] Light and Dark affect ClipVault only.
* [ ] Every transition works immediately, including Light → System and Dark → System.
* [ ] Switching appearance does not reset Settings to General.
* [ ] The main window, Settings, menus, alerts, rows, cards, and controls remain readable in all modes.
* [ ] The selected appearance persists after relaunch.

---

## 27. Documentation and Privacy

* [ ] README accurately describes current features.
* [ ] Backup documentation clearly states that ordinary file/folder contents are not embedded.
* [ ] Link-preview network use is disclosed.
* [ ] Option-select Accessibility requirements are documented.
* [ ] Renamed File clips are documented as exported-copy names only.
* [ ] Multi-selection is not described or implied.

---

## 28. Visual Alignment Review

Inspect the app at normal size and minimum size.

* [ ] General Settings and App Rules titles align.
* [ ] Future Settings titles would naturally follow the same title line.
* [ ] Search fields have clearly visible text-entry regions.
* [ ] Main-window header elements align cleanly.
* [ ] Pause remains horizontal.
* [ ] Clipboard row numbers form a consistent column.
* [ ] Clipboard text forms a consistent column.
* [ ] Trash icons form a consistent column.
* [ ] App Rules search, filter, app icons, and title share a left alignment line.
* [ ] App Rules pickers share a right alignment line with the search field.
* [ ] Sidebar icons occupy a consistent column.
* [ ] Sidebar labels occupy a consistent column.
* [ ] No control appears unintentionally crowded against a window edge.
* [ ] No element visibly shifts when switching Settings sections.
* [ ] Light Mode looks correct.
* [ ] Dark Mode looks correct.

---

## 29. Final Smoke Test

Perform these steps in order:

1. [ ] Quit ClipVault.
2. [ ] Relaunch ClipVault.
3. [ ] Copy normal text.
4. [ ] Copy a likely sensitive value.
5. [ ] Open the main window.
6. [ ] Search for a clip.
7. [ ] Clear the search.
8. [ ] Copy a clip back to the clipboard.
9. [ ] Delete one clip.
10. [ ] Open General Settings.
11. [ ] Enable Option-select capture.
12. [ ] Option-select text in TextEdit.
13. [ ] Immediately paste and confirm that the selected text is active.
14. [ ] Confirm the Option-selected text appears once in history.
15. [ ] Disable Option-select capture and confirm that a new Option-drag does not trigger.
16. [ ] Restore the preferred Option-select setting.
17. [ ] Change and restore one other harmless setting.
18. [ ] Open App Rules.
19. [ ] Search for an application.
20. [ ] Change one app rule.
21. [ ] Confirm the changed rule also applies to Option-selected text.
22. [ ] Reset the app rule.
23. [ ] Refresh the app list.
24. [ ] Export a backup.
25. [ ] Quit ClipVault.
26. [ ] Relaunch ClipVault.
27. [ ] Confirm history, settings, Option-select preference, and app rules remain correct.

---

## Test Notes

**Date:**

**macOS version:**

**Xcode version:**

**ClipVault checkpoint/build:**

**Issues found:**

*

**Result:**

* [ ] Pass
* [ ] Pass with minor issues
* [ ] Fail
