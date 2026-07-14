//
//  ClipVaultApp.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/8/26.
//

import SwiftUI
import AppKit
import KeyboardShortcuts

@main
struct ClipVaultApp: App {
    @StateObject private var clipboardStore = ClipboardStore()

    @StateObject private var optionSelectionGestureMonitor =
        OptionSelectionGestureMonitor()

    @Environment(\.openWindow) private var openWindow
    @State private var hasRegisteredKeyboardShortcuts = false

    var body: some Scene {
        MenuBarExtra {
            Button("Show ClipVault") {
                openWindow(id: "main-window")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            
            Button("Settings") {
                openWindow(id: "settings-window")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }

            Divider()
            
            Button(
                clipboardStore.isMonitoringPaused
                    ? "Resume Monitoring"
                    : "Pause Monitoring"
            ) {
                clipboardStore.isMonitoringPaused.toggle()
            }
            
            Divider()
            
            Menu("History") {
                Button("Export History") {
                    DispatchQueue.main.async {
                        do {
                            let exportURL = try ClipboardHistoryExportService.exportTextHistory(clipboardStore.items)
                            NSWorkspace.shared.activateFileViewerSelecting([exportURL])
                            showExportSucceededAlert()
                        } catch {
                            OperationFailureAlert.show(
                                title: "Export Failed",
                                message: "ClipVault could not export your history.",
                                error: error
                            )
                        }
                    }
                }
                .disabled(clipboardStore.items.filter { $0.kind == .normal }.isEmpty)
                
                Button("Clear History") {
                    if ClearHistoryConfirmation.shouldClearHistory() {
                        clipboardStore.clearHistory()
                    }
                }
                .disabled(clipboardStore.items.isEmpty)
            }

            Menu("Backups") {
                Button("Export Backup") {
                    DispatchQueue.main.async {
                        do {
                            let exportURL = try ClipboardHistoryExportService.exportJSONBackup(clipboardStore.items)
                            
                            let cleanupResult = try? ClipboardHistoryExportService.deleteOldJSONBackups(
                                keepingMostRecent: clipboardStore.backupKeepCount
                            )
                            
                            NSWorkspace.shared.activateFileViewerSelecting([exportURL])
                            showBackupExportSucceededAlert(cleanupResult: cleanupResult)
                        } catch {
                            OperationFailureAlert.show(
                                title: "Backup Export Failed",
                                message: "ClipVault could not export a backup.",
                                error: error
                            )
                        }
                    }
                }
                .disabled(clipboardStore.items.filter { $0.kind == .normal }.isEmpty)
                
                Button("Import Latest Backup") {
                    DispatchQueue.main.async {
                        do {
                            let backupItems =
                                try ClipboardImportService.itemsFromLatestJSONBackup()
                            
                            BackupImportWorkflow.handle(
                                backupItems: backupItems,
                                clipboardStore: clipboardStore,
                                openSettings: {
                                    openWindow(id: "settings-window")
                                }
                            )
                        } catch {
                            OperationFailureAlert.show(
                                title: "Backup Import Failed",
                                message: "ClipVault could not import the latest backup.",
                                error: error
                            )
                        }
                    }
                }
                
                Divider()
                
                Button("Reveal Latest Backup") {
                    DispatchQueue.main.async {
                        do {
                            try ClipboardHistoryExportService.revealLatestJSONBackup()
                        } catch {
                            OperationFailureAlert.show(
                                title: "Reveal Backup Failed",
                                message: "ClipVault could not reveal the latest backup.",
                                error: error
                            )
                        }
                    }
                }

                Button("Delete Old Backups") {
                    DispatchQueue.main.async {
                        let keepCount = clipboardStore.backupKeepCount
                        
                        guard shouldDeleteOldBackups(keepingMostRecent: keepCount) else {
                            return
                        }
                        
                        do {
                            let result = try ClipboardHistoryExportService.deleteOldJSONBackups(
                                keepingMostRecent: keepCount
                            )
                            
                            showOldBackupsDeletedAlert(result: result)
                        } catch {
                            OperationFailureAlert.show(
                                title: "Delete Backups Failed",
                                message: "ClipVault could not delete old backups.",
                                error: error
                            )
                        }
                    }
                }
            }
            
            Divider()

            Button("ClipVault Help") {
                showClipVaultHelpAlert(backupKeepCount: clipboardStore.backupKeepCount)
            }

            Button("Quit ClipVault") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: "doc.on.clipboard")
                .onAppear {
                    registerKeyboardShortcutsIfNeeded()

                    optionSelectionGestureMonitor
                        .configure(
                            clipboardStore: clipboardStore
                        )

                    optionSelectionGestureMonitor
                        .applySavedCapturePreference()
                }
        }
        .menuBarExtraStyle(.menu)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    openWindow(id: "settings-window")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            CommandGroup(replacing: .help) {
                Button("ClipVault Help") {
                    showClipVaultHelpAlert(
                        backupKeepCount: clipboardStore.backupKeepCount
                    )
                }
            }
        }

        Window("ClipVault", id: "main-window") {
            ContentView()
                .environmentObject(clipboardStore)
        }
        .defaultSize(width: 600, height: 500)
        .defaultLaunchBehavior(.suppressed)
        
        Window("ClipVault Settings", id: "settings-window") {
            SettingsContainerView()
                .environmentObject(clipboardStore)
                .environmentObject(
                    optionSelectionGestureMonitor
                )
        }
        .defaultSize(width: 900, height: 700)
    }
    
    @ViewBuilder
    private func shortcutMenuLabel(
        title: String,
        shortcutName: KeyboardShortcuts.Name
    ) -> some View {
        HStack {
            Text(title)

            Spacer()

            if let shortcut = KeyboardShortcuts.getShortcut(for: shortcutName) {
                Text(shortcut.description)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func registerKeyboardShortcutsIfNeeded() {
        guard !hasRegisteredKeyboardShortcuts else {
            return
        }
        
        hasRegisteredKeyboardShortcuts = true
        
        KeyboardShortcuts.onKeyUp(for: .showClipVault) {
            Task { @MainActor in
                openWindow(id: "main-window")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
        
        KeyboardShortcuts.onKeyUp(for: .pauseResumeMonitoring) {
            Task { @MainActor in
                clipboardStore.isMonitoringPaused.toggle()
            }
        }
    }
}

@MainActor
private func showClipVaultHelpAlert(backupKeepCount: Int) {
    let alert = NSAlert()
    alert.messageText = "ClipVault Help"
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    
    let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 520, height: 520))
    textView.isEditable = false
    textView.isSelectable = true
    textView.drawsBackground = false
    textView.textContainerInset = NSSize(width: 0, height: 0)
    textView.textContainer?.lineFragmentPadding = 0
    
    let regularFont = NSFont.systemFont(ofSize: 13)
    let boldFont = NSFont.boldSystemFont(ofSize: 13)
    
    let regularAttributes: [NSAttributedString.Key: Any] = [
        .font: regularFont,
        .foregroundColor: NSColor.labelColor
    ]
    
    let boldAttributes: [NSAttributedString.Key: Any] = [
        .font: boldFont,
        .foregroundColor: NSColor.labelColor
    ]
    
    let helpText = NSMutableAttributedString()
    
    appendParagraph(
        to: helpText,
        text: "ClipVault saves a local history of normal copied text from your Mac clipboard.",
        attributes: regularAttributes
    )
    
    appendSection(
        to: helpText,
        heading: "Show ClipVault",
        body: "Use the menu bar icon or press Control-Option-V.",
        headingAttributes: boldAttributes,
        bodyAttributes: regularAttributes
    )
    
    appendSection(
        to: helpText,
        heading: "Pause Monitoring",
        body: "Use the menu bar icon or press Control-Option-P. When monitoring is paused, ClipVault will ignore new clipboard changes until monitoring resumes.",
        headingAttributes: boldAttributes,
        bodyAttributes: regularAttributes
    )
    
    appendSection(
        to: helpText,
        heading: "Search",
        body: "Use the search field in the ClipVault window to filter saved clips. Press Escape while searching to clear the search field.",
        headingAttributes: boldAttributes,
        bodyAttributes: regularAttributes
    )
    
    appendSection(
        to: helpText,
        heading: "Copy an Old Clip",
        body: "Click a normal clipboard row to copy that text back to the system clipboard.",
        headingAttributes: boldAttributes,
        bodyAttributes: regularAttributes
    )
    
    appendSection(
        to: helpText,
        heading: "Clear History",
        body: "Clear History permanently deletes saved ClipVault history. It does not change the current macOS system clipboard.",
        headingAttributes: boldAttributes,
        bodyAttributes: regularAttributes
    )
    
    appendSection(
        to: helpText,
        heading: "Export History",
        body: "Export History creates a readable text file containing your normal saved clips.",
        headingAttributes: boldAttributes,
        bodyAttributes: regularAttributes
    )
    
    appendSection(
        to: helpText,
        heading: "Backups",
        body: "Export Backup creates a JSON backup and automatically keeps only the newest \(backupKeepCount) backup file(s).\nImport Latest Backup imports the newest ClipVault backup from the Exports folder.\nYou can also drag a ClipVault JSON backup file onto the main ClipVault window to import that specific file.\nReveal Latest Backup opens the newest backup in Finder.\nDelete Old Backups manually applies the same backup cleanup rule.",
        headingAttributes: boldAttributes,
        bodyAttributes: regularAttributes
    )
    
    appendSection(
        to: helpText,
        heading: "App Rules",
        body: "Allowed saves normal clips unless they look sensitive.\nSmart is useful for password managers and skips likely passwords, tokens, API keys, and secret-looking text.\nBlocked never saves copied text from that app.",
        headingAttributes: boldAttributes,
        bodyAttributes: regularAttributes
    )
    
    appendSection(
        to: helpText,
        heading: "Skipped Warnings",
        body: "If enabled in Settings, ClipVault shows red placeholder rows when sensitive or blocked clips are skipped. The skipped text still remains available in the normal macOS system clipboard.",
        headingAttributes: boldAttributes,
        bodyAttributes: regularAttributes
    )
    
    textView.textStorage?.setAttributedString(helpText)
    
    let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 520, height: 360))
    scrollView.hasVerticalScroller = true
    scrollView.documentView = textView
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    
    alert.accessoryView = scrollView
    alert.runModal()
}

private func appendParagraph(
    to attributedString: NSMutableAttributedString,
    text: String,
    attributes: [NSAttributedString.Key: Any]
) {
    attributedString.append(
        NSAttributedString(
            string: "\(text)\n\n",
            attributes: attributes
        )
    )
}

private func appendSection(
    to attributedString: NSMutableAttributedString,
    heading: String,
    body: String,
    headingAttributes: [NSAttributedString.Key: Any],
    bodyAttributes: [NSAttributedString.Key: Any]
) {
    attributedString.append(
        NSAttributedString(
            string: "\(heading)\n",
            attributes: headingAttributes
        )
    )
    
    attributedString.append(
        NSAttributedString(
            string: "\(body)\n\n",
            attributes: bodyAttributes
        )
    )
}

@MainActor
private func showExportSucceededAlert() {
    let alert = NSAlert()
    alert.messageText = "History Exported"
    alert.informativeText = "ClipVault exported your history and opened it in Finder."
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

@MainActor
private func showBackupExportSucceededAlert(cleanupResult: BackupCleanupResult?) {
    let alert = NSAlert()
    alert.messageText = "Backup Exported"
    
    if let cleanupResult {
        if cleanupResult.deletedCount == 0 {
            alert.informativeText = "ClipVault exported a JSON backup and opened it in Finder.\n\nNo old backups needed to be deleted."
        } else {
            alert.informativeText = "ClipVault exported a JSON backup and opened it in Finder.\n\nDeleted \(cleanupResult.deletedCount) old backup file(s). Kept \(cleanupResult.keptCount) newest backup file(s)."
        }
    } else {
        alert.informativeText = "ClipVault exported a JSON backup and opened it in Finder."
    }
    
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

@MainActor
private func shouldDeleteOldBackups(keepingMostRecent keepCount: Int) -> Bool {
    let alert = NSAlert()
    alert.messageText = "Delete Old Backups?"
    alert.informativeText = "ClipVault will keep the newest \(keepCount) JSON backups and delete older backup files from its Exports folder.\n\nThis will not delete your current clipboard history."
    alert.alertStyle = .warning
    
    let deleteButton = alert.addButton(withTitle: "Delete Old Backups")
    deleteButton.keyEquivalent = "\r"
    
    let cancelButton = alert.addButton(withTitle: "Cancel")
    cancelButton.keyEquivalent = "\u{1b}"
    
    let response = alert.runModal()
    
    return response == .alertFirstButtonReturn
}

@MainActor
private func showOldBackupsDeletedAlert(result: BackupCleanupResult) {
    let alert = NSAlert()
    
    if result.deletedCount == 0 {
        alert.messageText = "No Old Backups Deleted"
        alert.informativeText = "ClipVault kept \(result.keptCount) backup file(s). There were no older backup files to delete."
    } else {
        alert.messageText = "Old Backups Deleted"
        alert.informativeText = "Deleted \(result.deletedCount) old backup file(s).\nKept \(result.keptCount) newest backup file(s)."
    }
    
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

