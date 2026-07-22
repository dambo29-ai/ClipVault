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

    @State private var historyLimitText = ""
    @State private var backupKeepCountText = ""
    
    private let settingsControlColumnWidth: CGFloat = 150
    
    var body: some View {
        VStack(
            alignment:
                .leading,
            spacing:
                22
        ) {
                    historyLimitSetting
                    
                    Divider()
                    
                    historyRetentionSetting

                    Divider()

                    backupKeepCountSetting

                    Divider()

                    skippedWarningsSetting

                    Divider()

                    keyboardShortcutsSetting
                    
        }
        .padding(
            .horizontal,
            28
        )
        .padding(
            .vertical,
            24
        )
        .frame(
            maxWidth:
                .infinity,
            alignment:
                .topLeading
        )
        .onAppear {
            historyLimitText =
                "\(clipboardStore.maxItemCount)"

            backupKeepCountText =
                "\(clipboardStore.backupKeepCount)"
        }
        .onChange(
            of: clipboardStore.maxItemCount
        ) { _, newValue in
            historyLimitText =
                "\(newValue)"
        }
    }
    
    private var historyLimitSetting: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    "History Limit (\(ClipboardStore.minimumHistoryLimit)-\(ClipboardStore.maximumHistoryLimit))"
                )
                .font(
                    .body
                )
                .fontWeight(
                    .medium
                )
                
                Text("ClipVault will keep up to \(clipboardStore.maxItemCount) copied text items.")
                    .font(
                        .body
                    )
                    .foregroundStyle(
                        .secondary
                    )
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
                    .font(
                        .body
                    )
                    .fontWeight(
                        .medium
                    )
                
                Text("Automatically remove copied text older than the selected time period.")
                    .font(
                        .body
                    )
                    .foregroundStyle(
                        .secondary
                    )
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
                .font(
                    .body
                )
                .fontWeight(
                    .medium
                )
                
                Text(
                    "Delete Old Backups will keep the newest \(clipboardStore.backupKeepCount) .clipvaultbackup package(s)."
                )
                .font(
                    .body
                )
                .foregroundStyle(
                    .secondary
                )
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
                    .font(
                        .body
                    )
                    .fontWeight(
                        .medium
                    )
                
                Text("Show a temporary warning row when ClipVault skips likely sensitive clips or clips from blocked apps.")
                    .font(
                        .body
                    )
                    .foregroundStyle(
                        .secondary
                    )
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
    
    private var keyboardShortcutsSetting: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Keyboard Shortcuts")
                    .font(
                        .body
                    )
                    .fontWeight(
                        .medium
                    )
                
                Text("Set global shortcuts for ClipVault.")
                    .font(
                        .body
                    )
                    .foregroundStyle(
                        .secondary
                    )
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
                .font(
                    .callout
                )
                .foregroundStyle(.secondary)
                .frame(
                    width:
                        110,
                    alignment:
                        .trailing
                )

            KeyboardShortcuts.Recorder(
                "",
                name: name
            )
            .labelsHidden()
        }
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
