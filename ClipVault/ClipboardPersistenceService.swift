//
//  ClipboardPersistenceService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/10/26.
//

import Foundation

actor ClipboardPersistenceService {
    static let shared = ClipboardPersistenceService()

    private init() {}

    func saveItems(_ items: [ClipboardItem]) throws {
        let savableItems = items.filter { $0.kind == .normal }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(savableItems)
        try data.write(to: storageURL(), options: [.atomic])
    }

    nonisolated static func loadItems() throws -> [ClipboardItem] {
        let fileURL = try storageURL()

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)

        let decoder = JSONDecoder()
        let loadedItems = try decoder.decode(
            [ClipboardItem].self,
            from: data
        )

        return loadedItems.filter { $0.kind == .normal }
    }

    private nonisolated static func storageURL() throws -> URL {
        guard let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw ClipboardPersistenceError.applicationSupportUnavailable
        }

        let folderURL = applicationSupportURL.appendingPathComponent(
            "ClipVault",
            isDirectory: true
        )

        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )

        return folderURL.appendingPathComponent(
            "clipboard-history.json"
        )
    }

    private func storageURL() throws -> URL {
        try Self.storageURL()
    }
}

private enum ClipboardPersistenceError: LocalizedError {
    case applicationSupportUnavailable

    var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable:
            return "The Application Support folder could not be located."
        }
    }
}
