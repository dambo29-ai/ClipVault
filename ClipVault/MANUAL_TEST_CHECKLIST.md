# ClipVault Manual Test Checklist

Use this checklist after structural changes, persistence changes, UI refactors, or before creating a checkpoint.

Record the macOS and ClipVault build versions when performing a full regression test.

## Automated Test Baseline

Current automated baseline:

* 66 total tests.
* 12 `SelectionClipboardTransactionService` tests.
* Accepted Option-select capture keeps the newly selected text active.
* Blocked, sensitive, paused, and empty capture outcomes restore the previous clipboard.
* Copy-event failure, clipboard timeout, and unreadable clipboard content restore the previous clipboard.
* Restoration failure returns `clipboardRestoreFailed`.
* Reentrant capture returns `transactionAlreadyRunning`.
* Clipboard-monitoring suppression begins and ends exactly once.
* Accepted capture does not invoke clipboard restoration.

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
* [ ] The Settings window opens at an appropriate default size.
* [ ] The Settings sidebar does not change width when switching sections.
* [ ] Settings opens on **General**.

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
* [ ] **Selection Capture Access** accurately reports whether Accessibility access is granted.
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

## 7. Sensitive-Clip Detection

* [ ] A likely password or secret is skipped when appropriate.
* [ ] A skipped clip remains available in the system clipboard.
* [ ] A likely-sensitive Option-selected value is not saved to normal history.
* [ ] A likely-sensitive Option-selection restores the previous clipboard and does not make the sensitive value pasteable.
* [ ] A likely-sensitive Option-selection produces one skipped-warning row when warnings are enabled.
* [ ] Disabling **Show Skipped Clip Warnings** prevents Option-select warning rows while still restoring the previous clipboard.
* [ ] The skipped-warning row is red.
* [ ] The warning text is bold.
* [ ] The warning row is non-clickable.
* [ ] The warning row can be deleted.
* [ ] Skipped-warning rows are not restored after relaunch.
* [ ] Disabling **Show Skipped Clip Warnings** hides future warning rows.
* [ ] Re-enabling the setting restores future warning rows.
* [ ] The skipped-warning preference persists after relaunch.

Expected likely-sensitive warning:

```text
(Likely sensitive clip skipped in ClipVault. Clip still available in system clipboard for use.)
```

---

## 8. General Settings

* [ ] **General Settings** aligns with the **App Rules** section title.
* [ ] History Limit works.
* [ ] History Limit persists after relaunch.
* [ ] Keep History For works.
* [ ] Keep History For remains responsive.
* [ ] Changing retention removes only clips outside the selected period.
* [ ] Keep History For persists after relaunch.
* [ ] Backups to Keep accepts valid values.
* [ ] Backups to Keep persists after relaunch.
* [ ] Show Skipped Clip Warnings works.
* [ ] All standard controls share a consistent right-hand alignment.
* [ ] Keyboard-shortcut rows remain aligned.
* [ ] General Settings does not contain App Rules controls.

---

## 9. App Rules Layout

* [ ] App Rules opens without a beach ball.
* [ ] The first transition from General to App Rules is acceptably fast.
* [ ] Later transitions remain fast.
* [ ] The App Rules title remains aligned with General Settings.
* [ ] The search field aligns with the App Rules title.
* [ ] The filter dropdown aligns with the App Rules title.
* [ ] Application icons align with the App Rules title.
* [ ] Mode pickers align with the right edge of the search field.
* [ ] The count summary remains centered.
* [ ] The App Rules controls remain fixed while only the app list scrolls.
* [ ] The sidebar remains visible while viewing App Rules.
* [ ] Application icons load correctly.
* [ ] Scrolling remains smooth.
* [ ] Icons remain correct after searching and changing filters.

---

## 10. App Rules Search and Filters

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

## 11. App Rules Counts

* [ ] Allowed count is correct.
* [ ] Smart count is correct.
* [ ] Blocked count is correct.
* [ ] Allowed + Smart + Blocked equals the denominator.
* [ ] **Showing X of Y** reflects the active mode filter.
* [ ] Search updates the counts consistently.
* [ ] Show Hidden Utility Apps updates the counts consistently.
* [ ] The centered count summary does not shift unexpectedly.

---

## 12. App Rule Modes

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

## 13. Custom App Rules

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

## 14. App Discovery

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

## 15. Default Blocked Applications

Confirm the intended defaults where installed:

* [ ] 1Password is Blocked by default.
* [ ] Bitwarden is Blocked by default.
* [ ] NordPass is Blocked by default.
* [ ] Keychain Access is Blocked by default.
* [ ] Applications with “password” in the visible name are Blocked by default where appropriate.
* [ ] Resetting these applications restores the computed default rather than Allowed.

---

## 16. Clipboard Persistence

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

## 17. History Limits and Retention

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

## 18. History Export

* [ ] Export History creates a readable `.txt` file.
* [ ] The exported text contains normal clipboard items.
* [ ] The export preserves useful ordering.
* [ ] Skipped-warning rows are excluded.
* [ ] Exporting an empty history behaves appropriately.
* [ ] Export completes without freezing or crashing.

---

## 19. JSON Backups

* [ ] Export Backup creates a JSON file.
* [ ] The filename follows the expected timestamp format.
* [ ] The backup format version is `1`.
* [ ] The backup contains normal clipboard items.
* [ ] Skipped-warning rows are excluded.
* [ ] Captured clips include `"origin" : "captured"`.
* [ ] Restored clips include `"origin" : "restored"`.
* [ ] Restored clips preserve their original `createdAt` timestamps.
* [ ] Backups to Keep is respected.
* [ ] Backups to Keep values below 1 are corrected to 1 after loading.
* [ ] Backups to Keep values above 50 are corrected to 50 after loading.
* [ ] The Backups to Keep Stepper stops at 1 and 50.
* [ ] Automatic cleanup removes only backups beyond the configured limit.
* [ ] Manual Delete Old Backups works.
* [ ] Backup creation does not crash.

Expected filename format:

```text
ClipVault Backup yyyy-MM-dd HH-mm-ss.clipvaultbackup

---

## 20. Backup Import

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

### Compatibility and Failure Handling

* [ ] A version-1 backup created before the `origin` property existed still imports.
* [ ] Older backup items without an `origin` property are treated as restored during import.
* [ ] Invalid JSON is rejected safely.
* [ ] Malformed JSON displays **This JSON file is not a valid ClipVault backup.**
* [ ] A non-ClipVault JSON file is rejected safely.
* [ ] A backup with an invalid application name is rejected safely.
* [ ] An unsupported backup format version is rejected safely.
* [ ] Dragging a non-JSON file does not crash the app.
* [ ] Import failure alerts do not expose low-level JSON decoder messages.

---

## 21. Visual Alignment Review

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

## 22. Final Smoke Test

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
