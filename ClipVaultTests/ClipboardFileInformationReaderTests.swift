//
//  ClipboardFileInformationReaderTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/21/26.
//

import Foundation
import Testing
@testable import ClipVault

struct ClipboardFileInformationReaderTests {
    @Test
    func folderInformationIncludesItemCount()
        throws
    {
        let testDirectory =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "ClipboardFileInformationReaderTests-" +
                        UUID().uuidString,
                    isDirectory:
                        true
                )

        defer {
            try? FileManager.default
                .removeItem(
                    at:
                        testDirectory
                )
        }

        try FileManager.default
            .createDirectory(
                at:
                    testDirectory,
                withIntermediateDirectories:
                    true
            )

        var receivedDirectoryURL:
            URL?

        let reader =
            ClipboardFileInformationReader(
                directoryItemCounter: {
                    directoryURL in

                    receivedDirectoryURL =
                        directoryURL

                    return 9
                }
            )

        let information =
            try reader.information(
                for:
                    ClipboardFileReference(
                        path:
                            testDirectory.path,
                        displayName:
                            "Folder",
                        isDirectory:
                            true,
                        bookmarkData:
                            Data([1])
                    ),
                resolvedURL:
                    testDirectory
            )

        #expect(
            receivedDirectoryURL ==
                testDirectory
                    .standardizedFileURL
        )

        #expect(
            information.kind ==
                .folder
        )

        #expect(
            information.itemCount ==
                9
        )

        #expect(
            information.itemCountText ==
                "9 items"
        )
    }

    @Test
    func symbolicLinkInformationPreservesRelativeDestination()
        throws
    {
        let reference =
            ClipboardFileReference(
                path:
                    "/Users/Test/Desktop/Photo Link",
                displayName:
                    "Photo Link",
                isDirectory:
                    false,
                bookmarkData:
                    nil,
                symbolicLinkIdentifier:
                    UUID(),
                symbolicLinkDestination:
                    "../Pictures/Photo.png"
            )

        var requestedPath:
            String?

        let reader =
            ClipboardFileInformationReader(
                fileExists: {
                    path in

                    requestedPath =
                        path

                    return true
                }
            )

        let information =
            try reader.information(
                for:
                    reference,
                resolvedURL:
                    reference.fileURL
            )

        #expect(
            information.kind ==
                .symbolicLink
        )

        #expect(
            information.destination ==
                "../Pictures/Photo.png"
        )

        #expect(
            information.destinationExists ==
                true
        )

        #expect(
            requestedPath ==
                "/Users/Test/Pictures/Photo.png"
        )
    }

    @Test
    func aliasInformationIncludesResolvedDestination()
        throws
    {
        let aliasURL =
            URL(
                fileURLWithPath:
                    "/Users/Test/Desktop/Document Alias"
            )

        let targetURL =
            URL(
                fileURLWithPath:
                    "/Users/Test/Documents/Document.pdf"
            )

        let reader =
            ClipboardFileInformationReader(
                aliasResolver: {
                    receivedURL in

                    #expect(
                        receivedURL ==
                            aliasURL
                    )

                    return targetURL
                },
                fileExists: {
                    path in

                    path ==
                        targetURL.path
                }
            )

        let information =
            reader.aliasInformationForTesting(
                reference:
                    ClipboardFileReference(
                        path:
                            aliasURL.path,
                        displayName:
                            "Document Alias",
                        isDirectory:
                            false,
                        bookmarkData:
                            Data([1])
                    ),
                resolvedURL:
                    aliasURL
            )

        #expect(
            information.kind ==
                .finderAlias
        )

        #expect(
            information.destination ==
                targetURL.path
        )

        #expect(
            information.destinationExists ==
                true
        )
    }
}
