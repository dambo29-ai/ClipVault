//
//  ClipboardImportService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/11/26.
//

import Foundation

enum ClipboardImportService {
    static func itemsFromLatestJSONBackup() throws -> [ClipboardItem] {
        let backupURL = try ClipboardHistoryExportService.latestJSONBackupURL()

        return try itemsFromJSONBackup(
            at: backupURL
        )
    }

    static func itemsFromJSONBackup(
        at backupURL: URL
    ) throws -> [ClipboardItem] {
        guard backupURL.pathExtension.lowercased() == "json" else {
            throw ClipboardImportError.invalidFileType
        }

        let didStartAccessing =
            backupURL.startAccessingSecurityScopedResource()

        defer {
            if didStartAccessing {
                backupURL.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(
            contentsOf: backupURL
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backup: ClipboardHistoryBackup

        do {
            backup = try decoder.decode(
                ClipboardHistoryBackup.self,
                from: data
            )
        } catch {
            throw ClipboardImportError.invalidClipVaultBackup
        }

        guard backup.appName == "ClipVault" else {
            throw ClipboardHistoryExportError.invalidBackupAppName
        }

        guard backup.formatVersion == 1 else {
            throw ClipboardHistoryExportError.unsupportedBackupFormat
        }

        return backup.items.filter {
            $0.kind == .normal
        }
    }

    static func prepareImport(
        existingItems: [ClipboardItem],
        backupItems: [ClipboardItem],
        maximumItemCount: Int
    ) -> ClipboardImportPreparation {
        let existingKeys = Set(
            existingItems
                .filter { $0.kind == .normal }
                .map { duplicateKey(for: $0.text) }
        )

        var importedItems: [ClipboardItem] = []
        var duplicateCount = 0
        var seenBackupKeys = Set<String>()

        for item in backupItems where item.kind == .normal {
            let key = duplicateKey(for: item.text)

            if existingKeys.contains(key) ||
                seenBackupKeys.contains(key) {
                duplicateCount += 1
            } else {
                importedItems.append(
                    item.restoredCopy()
                )

                seenBackupKeys.insert(key)
            }
        }

        guard !importedItems.isEmpty else {
            return ClipboardImportPreparation(
                mergedItems: existingItems,
                importedCount: 0,
                duplicateCount: duplicateCount,
                skippedDueToLimitCount: 0
            )
        }

        var mergedItems = existingItems
        mergedItems.append(contentsOf: importedItems)

        mergedItems.sort {
            $0.createdAt > $1.createdAt
        }

        let mergedNormalItemCount = mergedItems.filter {
            $0.kind == .normal
        }.count

        let itemsOverLimit = max(
            0,
            mergedNormalItemCount - maximumItemCount
        )

        if itemsOverLimit > 0 {
            return ClipboardImportPreparation(
                mergedItems: existingItems,
                importedCount: 0,
                duplicateCount: duplicateCount,
                skippedDueToLimitCount: itemsOverLimit
            )
        }

        return ClipboardImportPreparation(
            mergedItems: mergedItems,
            importedCount: importedItems.count,
            duplicateCount: duplicateCount,
            skippedDueToLimitCount: 0
        )
    }

    static func prepareReplacement(
        backupItems: [ClipboardItem],
        maximumItemCount: Int
    ) -> ClipboardReplacementPreparation {
        var replacementItems: [ClipboardItem] = []
        var seenKeys = Set<String>()
        var duplicateCount = 0

        for item in backupItems where item.kind == .normal {
            let key = duplicateKey(for: item.text)

            if seenKeys.contains(key) {
                duplicateCount += 1
            } else {
                replacementItems.append(
                    item.restoredCopy()
                )

                seenKeys.insert(key)
            }
        }

        replacementItems.sort {
            $0.createdAt > $1.createdAt
        }

        let skippedDueToLimitCount = max(
            0,
            replacementItems.count - maximumItemCount
        )

        if skippedDueToLimitCount > 0 {
            replacementItems = Array(
                replacementItems.prefix(maximumItemCount)
            )
        }

        return ClipboardReplacementPreparation(
            replacementItems: replacementItems,
            duplicateCount: duplicateCount,
            skippedDueToLimitCount: skippedDueToLimitCount
        )
    }

    private static func duplicateKey(
        for text: String
    ) -> String {
        text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }
}

enum ClipboardImportError: LocalizedError, Equatable {
    case invalidFileType
    case invalidClipVaultBackup

    var errorDescription: String? {
        switch self {
        case .invalidFileType:
            return "Please select a ClipVault JSON backup file."

        case .invalidClipVaultBackup:
            return "This JSON file is not a valid ClipVault backup."
        }
    }
}

struct ClipboardImportPreparation {
    let mergedItems: [ClipboardItem]
    let importedCount: Int
    let duplicateCount: Int
    let skippedDueToLimitCount: Int
}

struct ClipboardReplacementPreparation {
    let replacementItems: [ClipboardItem]
    let duplicateCount: Int
    let skippedDueToLimitCount: Int
}
