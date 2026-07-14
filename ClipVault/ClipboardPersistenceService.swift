//
//  ClipboardPersistenceService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/10/26.
//

import Foundation

actor ClipboardPersistenceService {
    static let shared = ClipboardPersistenceService()

    private let customStorageURL: URL?

    private init() {
        customStorageURL = nil
    }

    init(storageURL: URL) {
        customStorageURL = storageURL
    }

    func saveItems(_ items: [ClipboardItem]) throws {
        let savableItems = items.filter {
            $0.kind == .normal
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]

        let data = try encoder.encode(savableItems)
        let fileURL = try resolvedStorageURL()

        try data.write(
            to: fileURL,
            options: [.atomic]
        )
    }

    func loadItems() throws -> [ClipboardItem] {
        try Self.loadItems(
            from: resolvedStorageURL()
        )
    }

    nonisolated static func loadItems() throws -> [ClipboardItem] {
        try loadItems(
            from: defaultStorageURL()
        )
    }

    nonisolated static func loadItems(
        from fileURL: URL
    ) throws -> [ClipboardItem] {
        guard FileManager.default.fileExists(
            atPath: fileURL.path
        ) else {
            return []
        }

        let data = try Data(
            contentsOf: fileURL
        )

        let decoder = JSONDecoder()

        let loadedItems = try decoder.decode(
            [ClipboardItem].self,
            from: data
        )

        return loadedItems.filter {
            $0.kind == .normal
        }
    }

    private func resolvedStorageURL() throws -> URL {
        if let customStorageURL {
            try Self.createParentDirectory(
                for: customStorageURL
            )

            return customStorageURL
        }

        return try Self.defaultStorageURL()
    }

    private nonisolated static func defaultStorageURL() throws -> URL {
        guard let applicationSupportURL =
            FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
            throw ClipboardPersistenceError
                .applicationSupportUnavailable
        }

        let folderURL =
            applicationSupportURL.appendingPathComponent(
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

    private nonisolated static func createParentDirectory(
        for fileURL: URL
    ) throws {
        let parentDirectoryURL =
            fileURL.deletingLastPathComponent()

        try FileManager.default.createDirectory(
            at: parentDirectoryURL,
            withIntermediateDirectories: true
        )
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
