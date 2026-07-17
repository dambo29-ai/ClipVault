//
//  BackupImportWorkflow.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/11/26.
//

import AppKit

enum BackupImportWorkflow {
    @MainActor
    static func handlePackageRestoration(
        _ restoration:
            ClipboardBackupPackageRestoration,
        clipboardStore:
            ClipboardStore,
        packageImportService:
            ClipboardBackupPackageImportService =
                .shared
    ) async {
        let plan =
            clipboardStore
                .prepareBackupMerge(
                    restoration.items
                )

        let currentHistoryLimit =
            clipboardStore.maxItemCount

        let requiredHistoryLimit =
            plan.requiredUnpinnedItemCount

        let decision:
            ClipboardImportLimitDecision

        if requiredHistoryLimit <=
            currentHistoryLimit
        {
            decision =
                .keepLimit
        } else {
            let expandedHistoryLimit =
                min(
                    ClipboardImportService
                        .roundedHistoryLimit(
                            requiredItemCount:
                                requiredHistoryLimit
                        ),
                    ClipboardStore
                        .maximumHistoryLimit
                )

            let choice =
                BackupImportLimitConfirmation
                    .show(
                        currentHistoryLimit:
                            currentHistoryLimit,
                        requiredHistoryLimit:
                            requiredHistoryLimit,
                        expandedHistoryLimit:
                            expandedHistoryLimit,
                        maximumAllowedHistoryLimit:
                            ClipboardStore
                                .maximumHistoryLimit
                    )

            switch choice {
            case .expandLimit:
                decision =
                    .expandLimit

            case .keepLimit:
                decision =
                    .keepLimit

            case .cancel:
                await packageImportService
                    .deleteUnretainedRestoredImageAssets(
                        from:
                            restoration,
                        retainedItems:
                            clipboardStore.items
                    )

                return
            }
        }

        let result =
            clipboardStore
                .applyBackupImport(
                    plan:
                        plan,
                    decision:
                        decision
                )

        await packageImportService
            .deleteUnretainedRestoredImageAssets(
                from:
                    restoration,
                retainedItems:
                    clipboardStore.items
            )

        BackupImportSuccessAlert.show(
            importedCount:
                result.importedCount,
            duplicateCount:
                result.duplicateCount,
            skippedDueToLimitCount:
                result.skippedDueToLimitCount,
            replacedHistory:
                result.mode == .replace,
            resultingHistoryLimit:
                result.resultingHistoryLimit,
            didExpandHistoryLimit:
                result.didExpandHistoryLimit
        )
    }
    
    @MainActor
    static func handle(
        backupItems: [ClipboardItem],
        clipboardStore: ClipboardStore
    ) {
        let plan =
            clipboardStore.prepareBackupMerge(
                backupItems
            )

        let currentHistoryLimit =
            clipboardStore.maxItemCount

        let requiredHistoryLimit =
            plan.requiredUnpinnedItemCount

        let decision:
            ClipboardImportLimitDecision

        if requiredHistoryLimit <=
            currentHistoryLimit
        {
            decision = .keepLimit
        } else {
            let expandedHistoryLimit =
                min(
                    ClipboardImportService
                        .roundedHistoryLimit(
                            requiredItemCount:
                                requiredHistoryLimit
                        ),
                    ClipboardStore
                        .maximumHistoryLimit
                )

            let choice =
                BackupImportLimitConfirmation.show(
                    currentHistoryLimit:
                        currentHistoryLimit,
                    requiredHistoryLimit:
                        requiredHistoryLimit,
                    expandedHistoryLimit:
                        expandedHistoryLimit,
                    maximumAllowedHistoryLimit:
                        ClipboardStore
                            .maximumHistoryLimit
                )

            switch choice {
            case .expandLimit:
                decision = .expandLimit

            case .keepLimit:
                decision = .keepLimit

            case .cancel:
                return
            }
        }

        let result =
            clipboardStore.applyBackupImport(
                plan: plan,
                decision: decision
            )

        BackupImportSuccessAlert.show(
            importedCount:
                result.importedCount,
            duplicateCount:
                result.duplicateCount,
            skippedDueToLimitCount:
                result.skippedDueToLimitCount,
            replacedHistory: false,
            resultingHistoryLimit:
                result.resultingHistoryLimit,
            didExpandHistoryLimit:
                result.didExpandHistoryLimit
        )
    }
}
