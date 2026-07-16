//
//  ClipboardHistoryExportService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/9/26.
//

import AppKit
import Foundation

enum ClipboardHistoryExportError: LocalizedError, Equatable {
    case noHistory
    case noBackupsFound
    case unsupportedBackupFormat
    case invalidBackupAppName
    
    var errorDescription: String? {
        switch self {
        case .noHistory:
            return "ClipVault does not have any saved clipboard history yet."
        case .noBackupsFound:
            return "ClipVault could not find any JSON backup files in the Exports folder."
        case .unsupportedBackupFormat:
            return "This backup file uses an unsupported format version."
        case .invalidBackupAppName:
            return "This file does not appear to be a ClipVault backup."
        }
    }
}

struct ClipboardHistoryBackup: Codable {
    let appName: String
    let formatVersion: Int
    let exportedAt: Date
    let items: [ClipboardItem]
}

struct BackupCleanupResult {
    let deletedCount: Int
    let keptCount: Int
}

enum ClipboardHistoryExportService {
    static func exportTextHistory(_ items: [ClipboardItem]) throws -> URL {
        let normalItems = items.filter { $0.kind == .normal }
        
        guard !normalItems.isEmpty else {
            throw ClipboardHistoryExportError.noHistory
        }
        
        let exportText = makeExportText(from: normalItems)
        let exportURL = try makeExportURL(
            prefix: "ClipVault History",
            fileExtension: "txt"
        )
        
        try exportText.write(to: exportURL, atomically: true, encoding: .utf8)
        
        return exportURL
    }
    
    static func exportJSONBackup(_ items: [ClipboardItem]) throws -> URL {
        let normalItems = items.filter { $0.kind == .normal }
        
        guard !normalItems.isEmpty else {
            throw ClipboardHistoryExportError.noHistory
        }
        
        let backup = ClipboardHistoryBackup(
            appName: "ClipVault",
            formatVersion: 1,
            exportedAt: Date(),
            items: normalItems
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(backup)
        
        let exportURL = try makeExportURL(
            prefix: "ClipVault Backup",
            fileExtension: "json"
        )
        
        try data.write(to: exportURL, options: .atomic)
        
        return exportURL
    }
    
    static func latestJSONBackupURL() throws -> URL {
        let backupURLs = try sortedJSONBackupURLsNewestFirst()
        
        guard let latestBackupURL = backupURLs.first else {
            throw ClipboardHistoryExportError.noBackupsFound
        }
        
        return latestBackupURL
    }
    
    static func revealLatestJSONBackup() throws {
        let latestBackupURL = try latestJSONBackupURL()
        NSWorkspace.shared.activateFileViewerSelecting([latestBackupURL])
    }
    
    static func revealExportsFolder() throws {
        let exportsFolderURL = try makeExportsFolderURL()
        NSWorkspace.shared.open(exportsFolderURL)
    }
    
    static func deleteOldJSONBackups(keepingMostRecent keepCount: Int) throws -> BackupCleanupResult {
        let safeKeepCount = max(keepCount, 1)
        let backupURLs = try sortedJSONBackupURLsNewestFirst()
        
        guard !backupURLs.isEmpty else {
            throw ClipboardHistoryExportError.noBackupsFound
        }
        
        let backupURLsToKeep = Array(backupURLs.prefix(safeKeepCount))
        let backupURLsToDelete = Array(backupURLs.dropFirst(safeKeepCount))
        
        for backupURL in backupURLsToDelete {
            try FileManager.default.removeItem(at: backupURL)
        }
        
        return BackupCleanupResult(
            deletedCount: backupURLsToDelete.count,
            keptCount: backupURLsToKeep.count
        )
    }
    
    private static func sortedJSONBackupURLsNewestFirst() throws -> [URL] {
        let exportsFolderURL =
            try makeExportsFolderURL()

        let fileURLs =
            try FileManager.default.contentsOfDirectory(
                at: exportsFolderURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let validBackups:
            [(url: URL, exportedAt: Date)] =
                fileURLs.compactMap {
                    url in

                    guard
                        url.pathExtension
                            .lowercased() == "json"
                    else {
                        return nil
                    }

                    guard
                        let data = try? Data(
                            contentsOf: url
                        ),
                        let backup =
                            try? decoder.decode(
                                ClipboardHistoryBackup.self,
                                from: data
                            ),
                        backup.appName == "ClipVault",
                        backup.formatVersion == 1
                    else {
                        return nil
                    }

                    return (
                        url: url,
                        exportedAt: backup.exportedAt
                    )
                }

        return validBackups
            .sorted {
                firstBackup,
                secondBackup in

                if firstBackup.exportedAt !=
                    secondBackup.exportedAt
                {
                    return
                        firstBackup.exportedAt >
                        secondBackup.exportedAt
                }

                return
                    firstBackup.url.lastPathComponent
                        .localizedStandardCompare(
                            secondBackup
                                .url
                                .lastPathComponent
                        ) ==
                        .orderedDescending
            }
            .map(\.url)
    }
    
    private static func makeExportURL(
        prefix: String,
        fileExtension: String
    ) throws -> URL {
        let exportsFolderURL = try makeExportsFolderURL()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        
        let timestamp = dateFormatter.string(from: Date())
        let filename = "\(prefix) \(timestamp).\(fileExtension)"
        
        return exportsFolderURL.appendingPathComponent(filename)
    }
    
    private static func makeExportsFolderURL() throws -> URL {
        let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        
        let clipVaultFolderURL = applicationSupportURL
            .appendingPathComponent("ClipVault", isDirectory: true)
        
        let exportsFolderURL = clipVaultFolderURL
            .appendingPathComponent("Exports", isDirectory: true)
        
        try FileManager.default.createDirectory(
            at: exportsFolderURL,
            withIntermediateDirectories: true
        )
        
        return exportsFolderURL
    }
    
    private static func makeExportText(from items: [ClipboardItem]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        let exportedAt = dateFormatter.string(from: Date())
        
        var sections: [String] = []
        
        sections.append("""
        ClipVault History Export
        Exported: \(exportedAt)
        Items: \(items.count)
        """)
        
        for item in items.reversed() {
            let copiedAt = dateFormatter.string(from: item.createdAt)
            let source = item.sourceAppName ?? "Unknown"
            
            sections.append("""
            
            ----------------------------------------
            #\(displayNumber(for: item, in: items))
            Copied: \(copiedAt)
            Source: \(source)
            
            \(item.displayText)
            """)
        }
        
        return sections.joined(separator: "\n")
    }
    
    private static func displayNumber(for item: ClipboardItem, in items: [ClipboardItem]) -> Int {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return 0
        }
        
        return items.count - index
    }
}
