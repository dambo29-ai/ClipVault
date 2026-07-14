//
//  SettingsView.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/10/26.
//

import SwiftUI
import AppKit
import KeyboardShortcuts

struct GeneralSettingsView: View {
    @EnvironmentObject var clipboardStore: ClipboardStore

    @EnvironmentObject
    var optionSelectionGestureMonitor:
        OptionSelectionGestureMonitor
    @State private var historyLimitText = ""
    @State private var backupKeepCountText = ""
    @State private var hasAccessibilityPermission =
        AccessibilityPermissionService.isGranted
    @State private var clipboardRestoreDiagnosticMessage =
        "Not tested yet"
    
    private let settingsControlColumnWidth: CGFloat = 150
    
    var body: some View {
        VStack(spacing: 0) {
            settingsHeader
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    historyLimitSetting
                    
                    Divider()
                    
                    historyRetentionSetting

                    Divider()

                    backupKeepCountSetting

                    Divider()

                    skippedWarningsSetting

                    Divider()

                    selectionCapturePermissionSetting

                    Divider()

                    selectionCaptureDiagnosticSetting

                    Divider()

                    clipboardRestoreDiagnosticSetting

                    Divider()

                    keyboardShortcutsSetting

                }
                .padding(24)
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .onAppear {
            historyLimitText =
                "\(clipboardStore.maxItemCount)"

            backupKeepCountText =
                "\(clipboardStore.backupKeepCount)"

            refreshAccessibilityPermission()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            refreshAccessibilityPermission()
        }
    }
    
    private var settingsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("General Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    private var historyLimitSetting: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    "History Limit (\(ClipboardStore.minimumHistoryLimit)-\(ClipboardStore.maximumHistoryLimit))"
                )
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("ClipVault will keep up to \(clipboardStore.maxItemCount) copied text items.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                TextField("100", text: $historyLimitText)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 48)
                    .onSubmit {
                        applyHistoryLimitText()
                    }
                    .onChange(of: historyLimitText) { _, newValue in
                        let digitsOnly = newValue.filter { $0.isNumber }
                        
                        if digitsOnly != newValue {
                            historyLimitText = digitsOnly
                        }
                    }
                
                Stepper(
                    "",
                    value: Binding(
                        get: {
                            clipboardStore.maxItemCount
                        },
                        set: { newValue in
                            clipboardStore.setMaxItemCount(newValue)
                            historyLimitText = "\(clipboardStore.maxItemCount)"
                        }
                    ),
                    in: ClipboardStore.minimumHistoryLimit...ClipboardStore.maximumHistoryLimit,
                    step: 10
                )
                .labelsHidden()
            }
            .frame(width: settingsControlColumnWidth, alignment: .trailing)
        }
    }
    
    private var historyRetentionSetting: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Keep History For")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Automatically remove copied text older than the selected time period.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Picker(
                "",
                selection: Binding(
                    get: {
                        clipboardStore.historyRetentionOption
                    },
                    set: { newValue in
                        clipboardStore.setHistoryRetentionOption(newValue)
                    }
                )
            ) {
                ForEach(HistoryRetentionOption.allCases) { option in
                    Text(option.displayName)
                        .tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: settingsControlColumnWidth, alignment: .trailing)
            .labelsHidden()
        }
    }
    
    private var backupKeepCountSetting: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    "Backups to Keep (\(ClipboardStore.minimumBackupKeepCount)-\(ClipboardStore.maximumBackupKeepCount))"
                )
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Delete Old Backups will keep the newest \(clipboardStore.backupKeepCount) JSON backup file(s).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                TextField("5", text: $backupKeepCountText)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 48)
                    .onSubmit {
                        applyBackupKeepCountText()
                    }
                    .onChange(of: backupKeepCountText) { _, newValue in
                        let digitsOnly = newValue.filter { $0.isNumber }
                        
                        if digitsOnly != newValue {
                            backupKeepCountText = digitsOnly
                        }
                    }
                
                Stepper(
                    "",
                    value: Binding(
                        get: {
                            clipboardStore.backupKeepCount
                        },
                        set: { newValue in
                            clipboardStore.setBackupKeepCount(newValue)
                            backupKeepCountText = "\(clipboardStore.backupKeepCount)"
                        }
                    ),
                    in: ClipboardStore.minimumBackupKeepCount...ClipboardStore.maximumBackupKeepCount,
                    step: 1
                )
                .labelsHidden()
            }
            .frame(width: settingsControlColumnWidth, alignment: .trailing)
        }
    }
    
    private var skippedWarningsSetting: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Show Skipped Clip Warnings")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Show a temporary warning row when ClipVault skips likely sensitive clips or clips from blocked apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle(
                "",
                isOn: Binding(
                    get: {
                        clipboardStore.showsSkippedClipWarnings
                    },
                    set: { newValue in
                        clipboardStore.setShowsSkippedClipWarnings(newValue)
                    }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .frame(width: settingsControlColumnWidth, alignment: .trailing)
        }
    }
    
    private var selectionCapturePermissionSetting: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Selection Capture Access")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(
                    "Accessibility access will allow ClipVault to detect Option-select gestures in other applications."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Label(
                    hasAccessibilityPermission
                        ? "Access Granted"
                        : "Access Not Granted",
                    systemImage:
                        hasAccessibilityPermission
                            ? "checkmark.circle.fill"
                            : "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(
                    hasAccessibilityPermission
                        ? .green
                        : .secondary
                )

                Button(
                    hasAccessibilityPermission
                        ? "Refresh Status"
                        : "Request Access"
                ) {
                    if hasAccessibilityPermission {
                        refreshAccessibilityPermission()
                    } else {
                        AccessibilityPermissionService
                            .requestAccessAndOpenSettings()

                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + 1.0
                        ) {
                            refreshAccessibilityPermission()
                        }
                    }
                }
            }
            .frame(
                width: settingsControlColumnWidth,
                alignment: .trailing
            )
        }
    }
    
    private var selectionCaptureDiagnosticSetting: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Option-Select Diagnostic")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(
                    "Hold Option while dragging to select text in another application. The selection becomes the active clipboard item and accepted text is also saved to ClipVault history."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Label(
                    optionSelectionGestureMonitor.isMonitoring
                        ? "Monitor Active"
                        : "Monitor Inactive",
                    systemImage:
                        optionSelectionGestureMonitor.isMonitoring
                            ? "wave.3.right.circle.fill"
                            : "wave.3.right.circle"
                )
                .font(.caption)
                .foregroundStyle(
                    optionSelectionGestureMonitor.isMonitoring
                        ? .green
                        : .secondary
                )

                if let lastDetectedAt =
                    optionSelectionGestureMonitor.lastDetectedAt {
                    Text(
                        "Last detected: \(ClipboardTimestampFormatter.string(for: lastDetectedAt))"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if let appName =
                        optionSelectionGestureMonitor
                            .lastDetectedAppName {
                        Text(appName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(
                        optionSelectionGestureMonitor
                            .lastRetrievalMessage
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if let selectedText =
                        optionSelectionGestureMonitor
                            .lastSelectedText {
                        Text(selectedText)
                            .font(.caption)
                            .lineLimit(4)
                            .multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                            .frame(
                                maxWidth: settingsControlColumnWidth,
                                alignment: .trailing
                            )
                    }
                } else {
                    Text("No gesture detected yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(
                width: settingsControlColumnWidth,
                alignment: .trailing
            )
        }
    }
    
    private var clipboardRestoreDiagnosticSetting: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Clipboard Restore Diagnostic")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(
                    "Temporarily replaces the system clipboard, restores its previous contents, and verifies the result. Clipboard history should not change."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Button("Test Restore") {
                    runClipboardRestoreDiagnostic()
                }

                Text(clipboardRestoreDiagnosticMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .frame(
                        maxWidth: settingsControlColumnWidth,
                        alignment: .trailing
                    )
            }
            .frame(
                width: settingsControlColumnWidth,
                alignment: .trailing
            )
        }
    }
    
    private var keyboardShortcutsSetting: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Keyboard Shortcuts")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Set global shortcuts for ClipVault.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 10) {
                shortcutRecorderRow(
                    label: "Show ClipVault:",
                    name: .showClipVault
                )

                shortcutRecorderRow(
                    label: "Pause/Resume:",
                    name: .pauseResumeMonitoring
                )
            }
        }
    }
    
    private func shortcutRecorderRow(
        label: String,
        name: KeyboardShortcuts.Name
    ) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .trailing)

            KeyboardShortcuts.Recorder(
                "",
                name: name
            )
            .labelsHidden()
        }
    }
    
    private func refreshAccessibilityPermission() {
        hasAccessibilityPermission =
            AccessibilityPermissionService.isGranted
    }
    
    private func runClipboardRestoreDiagnostic() {
        let pasteboard = NSPasteboard.general

        let originalSnapshot =
            ClipboardSnapshotService.capture(
                from: pasteboard
            )

        pasteboard.clearContents()

        let temporaryWriteSucceeded =
            pasteboard.setString(
                "ClipVault temporary clipboard diagnostic",
                forType: .string
            )

        guard temporaryWriteSucceeded else {
            ClipboardSnapshotService.restore(
                originalSnapshot,
                to: pasteboard
            )

            clipboardStore
                .synchronizeClipboardMonitoringChangeCount()

            clipboardRestoreDiagnosticMessage =
                "Temporary clipboard write failed."

            return
        }

        let restorationSucceeded =
            ClipboardSnapshotService.restore(
                originalSnapshot,
                to: pasteboard
            )

        clipboardStore
            .synchronizeClipboardMonitoringChangeCount()

        guard restorationSucceeded else {
            clipboardRestoreDiagnosticMessage =
                "Clipboard restoration failed."

            return
        }

        let restoredSnapshot =
            ClipboardSnapshotService.capture(
                from: pasteboard
            )

        if clipboardSnapshotsMatch(
            originalSnapshot,
            restoredSnapshot
        ) {
            clipboardRestoreDiagnosticMessage =
                "Restore succeeded and was verified."
        } else {
            clipboardRestoreDiagnosticMessage =
                "Clipboard was restored, but verification failed."
        }
    }
    
    private func clipboardSnapshotsMatch(
        _ firstSnapshot: ClipboardSnapshot,
        _ secondSnapshot: ClipboardSnapshot
    ) -> Bool {
        guard
            firstSnapshot.items.count ==
                secondSnapshot.items.count
        else {
            return false
        }

        for (
            firstItem,
            secondItem
        ) in zip(
            firstSnapshot.items,
            secondSnapshot.items
        ) {
            guard
                firstItem.representations.count ==
                    secondItem.representations.count
            else {
                return false
            }

            for (
                type,
                firstData
            ) in firstItem.representations {
                guard
                    secondItem.representations[type] ==
                        firstData
                else {
                    return false
                }
            }
        }

        return true
    }
    
    private func applyHistoryLimitText() {
        guard let typedValue = Int(historyLimitText) else {
            historyLimitText = "\(clipboardStore.maxItemCount)"
            return
        }
        
        clipboardStore.setMaxItemCount(typedValue)
        historyLimitText = "\(clipboardStore.maxItemCount)"
    }
    
    private func applyBackupKeepCountText() {
        guard let typedValue = Int(backupKeepCountText) else {
            backupKeepCountText = "\(clipboardStore.backupKeepCount)"
            return
        }
        
        clipboardStore.setBackupKeepCount(typedValue)
        backupKeepCountText = "\(clipboardStore.backupKeepCount)"
    }
}
