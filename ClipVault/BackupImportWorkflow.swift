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
            ClipboardBackupPackageImportService? =
                nil
    ) async {
        let packageImportService =
            packageImportService ??
            ClipboardBackupPackageImportService
                .shared
        
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
}
