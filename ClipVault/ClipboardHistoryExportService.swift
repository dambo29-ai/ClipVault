//
//  ClipboardHistoryExportService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/9/26.
//

import AppKit
import Foundation

enum ClipboardHistoryExportError:
    LocalizedError,
    Equatable
{
    case noHistory

    var errorDescription: String? {
        switch self {
        case .noHistory:
            return
                "ClipVault does not have any saved clipboard history yet."
        }
    }
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
    
    static func revealExportsFolder() throws {
        let exportsFolderURL = try makeExportsFolderURL()
        NSWorkspace.shared.open(exportsFolderURL)
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
