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
    init()
    {
        let clipboardStore =
            ClipboardStore()

        let folderAccessService =
            ScreenshotFolderAccessService()

        let preferenceService =
            ScreenshotAutomationPreferenceService()

        let folderMonitorService =
            ScreenshotFolderMonitorService()
        
        let processingService =
            ScreenshotProcessingService(
                stableImageHandler: {
                    [weak clipboardStore]
                    _,
                    imageData in

                    clipboardStore?
                        .captureAutomatedScreenshot(
                            imageData
                        )
                }
            )
        
        _clipboardStore =
            StateObject(
                wrappedValue:
                    clipboardStore
            )

        _screenshotFolderAccessService =
            StateObject(
                wrappedValue:
                    folderAccessService
            )

        _screenshotAutomationPreferenceService =
            StateObject(
                wrappedValue:
                    preferenceService
            )

        _screenshotFolderMonitorService =
            StateObject(
                wrappedValue:
                    folderMonitorService
            )

        _screenshotAutomationController =
            StateObject(
                wrappedValue:
                    ScreenshotAutomationController(
                        preferenceService:
                            preferenceService,
                        folderAccessService:
                            folderAccessService,
                        folderMonitorService:
                            folderMonitorService,
                        processingService:
                            processingService
                    )
            )
    }
    @StateObject private var clipboardStore:
        ClipboardStore

    @StateObject private var optionSelectionGestureMonitor =
        OptionSelectionGestureMonitor()

    @StateObject private var screenshotFolderAccessService:
        ScreenshotFolderAccessService
    
    @StateObject private var screenshotAutomationPreferenceService:
        ScreenshotAutomationPreferenceService

    @StateObject private var screenshotFolderMonitorService:
        ScreenshotFolderMonitorService

    @StateObject private var screenshotAutomationController:
        ScreenshotAutomationController

    @Environment(\.openWindow)
    private var openWindow

    @Environment(\.openSettings)
    private var openSettings

    @State private var hasRegisteredKeyboardShortcuts =
        false

    @AppStorage(
        ClipVaultAppearanceMode
            .defaultsKey
    )
    private var appearanceModeRawValue =
        ClipVaultAppearanceMode
            .system
            .rawValue

    private var appearanceMode:
        ClipVaultAppearanceMode
    {
        ClipVaultAppearanceMode
            .resolved(
                from:
                    appearanceModeRawValue
            )
    }

    var body: some Scene {
        MenuBarExtra {
            Button("Show ClipVault") {
                openWindow(id: "main-window")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            
            Button(
                "Settings"
            ) {
                openSettings()

                NSApplication.shared
                    .activate(
                        ignoringOtherApps:
                            true
                    )
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
                    Task { @MainActor in
                        do {
                            let exportURL =
                                try await ClipboardBackupPackageService
                                    .shared
                                    .exportBackup(
                                        items:
                                            clipboardStore
                                                .items
                                    )

                            let cleanupResult =
                                try? ClipboardBackupPackageService
                                    .shared
                                    .deleteOldBackups(
                                        keepingMostRecent:
                                            clipboardStore
                                                .backupKeepCount
                                    )

                            NSWorkspace.shared
                                .activateFileViewerSelecting([
                                    exportURL
                                ])

                            showBackupExportSucceededAlert(
                                cleanupResult:
                                    cleanupResult
                            )
                        } catch {
                            OperationFailureAlert.show(
                                title:
                                    "Backup Export Failed",
                                message:
                                    "ClipVault could not export a backup.",
                                error:
                                    error
                            )
                        }
                    }
                }
                .disabled(
                    clipboardStore.items
                        .filter {
                            $0.kind == .normal
                        }
                        .isEmpty
                )
                
                Button("Import Latest Backup") {
                    Task { @MainActor in
                        do {
                            let packageContents =
                                try ClipboardBackupPackageImportService
                                    .shared
                                    .readLatestPackage()

                            let restoration =
                                try await ClipboardBackupPackageImportService
                                    .shared
                                    .restorePackage(
                                        packageContents
                                    )

                            await BackupImportWorkflow
                                .handlePackageRestoration(
                                    restoration,
                                    clipboardStore:
                                        clipboardStore
                                )
                        } catch {
                            OperationFailureAlert.show(
                                title:
                                    "Backup Import Failed",
                                message:
                                    "ClipVault could not import the latest backup package.",
                                error:
                                    error
                            )
                        }
                    }
                }
                
                Divider()
                
                Button("Reveal Latest Backup") {
                    Task { @MainActor in
                        do {
                            try ClipboardBackupPackageService
                                .shared
                                .revealLatestBackup()
                        } catch {
                            OperationFailureAlert.show(
                                title:
                                    "Reveal Backup Failed",
                                message:
                                    "ClipVault could not reveal the latest backup.",
                                error:
                                    error
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
                            let result =
                                try ClipboardBackupPackageService
                                    .shared
                                    .deleteOldBackups(
                                        keepingMostRecent:
                                            keepCount
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

            Button(
                "ClipVault Help"
            ) {
                openWindow(
                    id:
                        "help-window"
                )

                NSApplication.shared
                    .activate(
                        ignoringOtherApps:
                            true
                    )
            }

            Button("Quit ClipVault") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: "doc.on.clipboard")
                .onAppear {
                    appearanceMode
                        .applyToApplication()

                    registerKeyboardShortcutsIfNeeded()

                    optionSelectionGestureMonitor
                        .configure(
                            clipboardStore: clipboardStore
                        )

                    optionSelectionGestureMonitor
                        .applySavedCapturePreference()
                    
                    _ =
                        screenshotAutomationController
                            .applySavedPreference()
                }
                .onChange(
                    of:
                        appearanceModeRawValue
                ) {
                    _,
                    _ in

                    appearanceMode
                        .applyToApplication()
                }
        }
        .menuBarExtraStyle(.menu)
        .commands {

            CommandGroup(
                replacing:
                    .help
            ) {
                Button(
                    "ClipVault Help"
                ) {
                    openWindow(
                        id:
                            "help-window"
                    )

                    NSApplication.shared
                        .activate(
                            ignoringOtherApps:
                                true
                        )
                }
                .keyboardShortcut(
                    "?",
                    modifiers:
                        .command
                )
            }
        }

        Window("ClipVault", id: "main-window") {
            ContentView()
                .environmentObject(
                    clipboardStore
                )
                .onAppear {
                    appearanceMode
                        .applyToApplication()
                }
                .onChange(
                    of:
                        appearanceModeRawValue
                ) {
                    _,
                    _ in

                    appearanceMode
                        .applyToApplication()
                }
        }
        .defaultSize(width: 600, height: 500)
        .defaultLaunchBehavior(.suppressed)
        
    Window(
        "ClipVault Help",
        id:
            "help-window"
    ) {
        HelpWindowView()
            .environmentObject(
                clipboardStore
            )
            .onAppear {
                appearanceMode
                    .applyToApplication()
            }
            .onChange(
                of:
                    appearanceModeRawValue
            ) {
                _,
                _ in

                appearanceMode
                    .applyToApplication()
            }
    }
    .defaultSize(
        width:
            900,
        height:
            650
    )
    .defaultLaunchBehavior(
        .suppressed
    )

    
        Settings {
            SettingsContainerView()
                .environmentObject(
                    clipboardStore
                )
                .environmentObject(
                    optionSelectionGestureMonitor
                )
                .environmentObject(
                    screenshotFolderAccessService
                )
                .environmentObject(
                    screenshotAutomationController
                )
                .onAppear {
                    appearanceMode
                        .applyToApplication()
                }
                .onChange(
                    of:
                        appearanceModeRawValue
                ) {
                    _,
                    _ in

                    appearanceMode
                        .applyToApplication()
                }
        }
        .defaultSize(
            width:
                700,
            height:
                585
        )
        .windowResizability(
            .contentSize
        )
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
private func showExportSucceededAlert() {
    let alert = NSAlert()
    alert.messageText = "History Exported"
    alert.informativeText = "ClipVault exported your history and opened it in Finder."
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

@MainActor
private func showBackupExportSucceededAlert(
    cleanupResult:
        BackupCleanupResult?
) {
    let alert =
        NSAlert()

    alert.messageText =
        "Backup Exported"

    if let cleanupResult {
        if cleanupResult.deletedCount == 0 {
            alert.informativeText =
                "ClipVault exported a .clipvaultbackup package and opened it in Finder.\n\nNo old backup packages needed to be deleted."
        } else {
            alert.informativeText =
                "ClipVault exported a .clipvaultbackup package and opened it in Finder.\n\nDeleted \(cleanupResult.deletedCount) old backup package(s). Kept \(cleanupResult.keptCount) newest backup package(s)."
        }
    } else {
        alert.informativeText =
            "ClipVault exported a .clipvaultbackup package and opened it in Finder."
    }

    alert.alertStyle =
        .informational

    alert.addButton(
        withTitle:
            "OK"
    )

    alert.runModal()
}

@MainActor
private func shouldDeleteOldBackups(
    keepingMostRecent keepCount: Int
) -> Bool {
    let alert =
        NSAlert()

    alert.messageText =
        "Delete Old Backups?"

    alert.informativeText =
        "ClipVault will keep the newest \(keepCount) .clipvaultbackup package(s) and delete older backup packages from its Exports folder.\n\nThis will not delete your current clipboard history."

    alert.alertStyle =
        .warning

    let deleteButton =
        alert.addButton(
            withTitle:
                "Delete Old Backups"
        )

    deleteButton.keyEquivalent =
        "\r"

    let cancelButton =
        alert.addButton(
            withTitle:
                "Cancel"
        )

    cancelButton.keyEquivalent =
        "\u{1b}"

    let response =
        alert.runModal()

    return
        response ==
        .alertFirstButtonReturn
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

