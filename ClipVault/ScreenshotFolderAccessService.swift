//
//  ScreenshotFolderAccessService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/23/26.
//

import AppKit
import Combine
import Foundation

enum ScreenshotFolderAccessResult:
    Equatable
{
    case granted

    case cancelled

    case clipboardDestination

    case unsupportedDestination(
        String
    )

    case incorrectFolder(
        expected:
            URL,
        selected:
            URL
    )

    case bookmarkCreationFailed
}

@MainActor
final class ScreenshotFolderAccessService:
    ObservableObject
{
    @Published
    private(set)
    var destination:
        ScreenshotDestinationResolution

    @Published
    private(set)
    var grantedFolderURL:
        URL?

    private let destinationService:
        ScreenshotDestinationService

    private let userDefaults:
        UserDefaults

    private let bookmarkCreator:
        (URL) throws -> Data

    private let bookmarkResolver:
        (Data) throws -> (
            url:
                URL,
            isStale:
                Bool
        )

    private let bookmarkDefaultsKey =
        "screenshotFolderSecurityScopedBookmark"

    init(
        destinationService:
            ScreenshotDestinationService? =
                nil,
        userDefaults:
            UserDefaults =
                .standard,
        bookmarkCreator:
            @escaping (URL) throws -> Data =
                ScreenshotFolderAccessService
                    .createSecurityScopedBookmark,
        bookmarkResolver:
            @escaping (Data) throws -> (
                url:
                    URL,
                isStale:
                    Bool
            ) =
                ScreenshotFolderAccessService
                    .resolveSecurityScopedBookmark
    ) {
        self.destinationService =
            destinationService ??
            ScreenshotDestinationService()

        self.userDefaults =
            userDefaults

        self.bookmarkCreator =
            bookmarkCreator

        self.bookmarkResolver =
            bookmarkResolver

        destination =
            self.destinationService
                .currentDestination()

        grantedFolderURL =
            nil

        restoreSavedAccess()
    }

    var detectedFolderURL:
        URL?
    {
        guard
            case let .folder(
                folderURL
            ) =
                destination
        else {
            return nil
        }

        return folderURL
            .standardizedFileURL
    }

    var hasAccessToCurrentDestination:
        Bool
    {
        guard
            let detectedFolderURL,
            let grantedFolderURL
        else {
            return false
        }

        return foldersMatch(
            detectedFolderURL,
            grantedFolderURL
        )
    }

    var destinationDescription:
        String
    {
        switch destination {
        case let .folder(
            folderURL
        ):
            return folderURL
                .path

        case .clipboard:
            return "Clipboard"

        case let .unsupportedDestination(
            destinationName
        ):
            return destinationName
        }
    }

    func refreshDestination()
    {
        destination =
            destinationService
                .currentDestination()

        guard
            hasAccessToCurrentDestination
        else {
            return
        }

        /*
         The saved bookmark still matches the detected
         macOS screenshot destination.
         */
    }

    func requestAccess()
        -> ScreenshotFolderAccessResult
    {
        refreshDestination()

        switch destination {
        case .clipboard:
            return .clipboardDestination

        case let .unsupportedDestination(
            destinationName
        ):
            return .unsupportedDestination(
                destinationName
            )

        case let .folder(
            expectedFolderURL
        ):
            return presentAccessPanel(
                expectedFolderURL:
                    expectedFolderURL
            )
        }
    }

    func grantAccess(
        to selectedFolderURL:
            URL
    ) -> ScreenshotFolderAccessResult
    {
        guard
            let expectedFolderURL =
                detectedFolderURL
        else {
            switch destination {
            case .clipboard:
                return .clipboardDestination

            case let .unsupportedDestination(
                destinationName
            ):
                return .unsupportedDestination(
                    destinationName
                )

            case .folder:
                return .bookmarkCreationFailed
            }
        }

        let standardizedSelectedURL =
            selectedFolderURL
                .standardizedFileURL

        guard
            foldersMatch(
                expectedFolderURL,
                standardizedSelectedURL
            )
        else {
            return .incorrectFolder(
                expected:
                    expectedFolderURL,
                selected:
                    standardizedSelectedURL
            )
        }

        do {
            let bookmarkData =
                try bookmarkCreator(
                    standardizedSelectedURL
                )

            userDefaults
                .set(
                    bookmarkData,
                    forKey:
                        bookmarkDefaultsKey
                )

            grantedFolderURL =
                standardizedSelectedURL

            return .granted
        } catch {
            return .bookmarkCreationFailed
        }
    }

    func resolvedGrantedFolderURL()
        -> URL?
    {
        guard
            let bookmarkData =
                userDefaults
                    .data(
                        forKey:
                            bookmarkDefaultsKey
                    )
        else {
            return nil
        }

        do {
            let resolution =
                try bookmarkResolver(
                    bookmarkData
                )

            let resolvedURL =
                resolution
                    .url
                    .standardizedFileURL

            if resolution.isStale {
                let replacementBookmark =
                    try bookmarkCreator(
                        resolvedURL
                    )

                userDefaults
                    .set(
                        replacementBookmark,
                        forKey:
                            bookmarkDefaultsKey
                    )
            }

            grantedFolderURL =
                resolvedURL

            return resolvedURL
        } catch {
            grantedFolderURL =
                nil

            return nil
        }
    }

    func clearAccess()
    {
        userDefaults
            .removeObject(
                forKey:
                    bookmarkDefaultsKey
            )

        grantedFolderURL =
            nil
    }

    private func presentAccessPanel(
        expectedFolderURL:
            URL
    ) -> ScreenshotFolderAccessResult
    {
        let openPanel =
            NSOpenPanel()

        openPanel.title =
            "Grant Screenshot Folder Access"

        openPanel.message =
            "Grant ClipVault read-only access to the folder macOS currently uses for screenshots."

        openPanel.prompt =
            "Grant Access"

        openPanel.directoryURL =
            expectedFolderURL

        openPanel.canChooseFiles =
            false

        openPanel.canChooseDirectories =
            true

        openPanel.allowsMultipleSelection =
            false

        openPanel.canCreateDirectories =
            false

        guard
            openPanel.runModal() ==
                .OK,
            let selectedFolderURL =
                openPanel.url
        else {
            return .cancelled
        }

        return grantAccess(
            to:
                selectedFolderURL
        )
    }

    private func restoreSavedAccess()
    {
        _ =
            resolvedGrantedFolderURL()
    }

    private func foldersMatch(
        _ firstURL:
            URL,
        _ secondURL:
            URL
    ) -> Bool {
        firstURL
            .standardizedFileURL
            .path ==
        secondURL
            .standardizedFileURL
            .path
    }

    nonisolated
    private static func createSecurityScopedBookmark(
        for folderURL:
            URL
    ) throws -> Data {
        try folderURL
            .bookmarkData(
                options: [
                    .withSecurityScope,
                    .securityScopeAllowOnlyReadAccess
                ],
                includingResourceValuesForKeys: [
                    .nameKey,
                    .isDirectoryKey
                ],
                relativeTo:
                    nil
            )
    }

    nonisolated
    private static func resolveSecurityScopedBookmark(
        _ bookmarkData:
            Data
    ) throws -> (
        url:
            URL,
        isStale:
            Bool
    ) {
        var isStale =
            false

        let resolvedURL =
            try URL(
                resolvingBookmarkData:
                    bookmarkData,
                options: [
                    .withSecurityScope,
                    .withoutUI
                ],
                relativeTo:
                    nil,
                bookmarkDataIsStale:
                    &isStale
            )

        return (
            url:
                resolvedURL,
            isStale:
                isStale
        )
    }
}
