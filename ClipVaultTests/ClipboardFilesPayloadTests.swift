//
//  ClipboardFilesPayloadTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/17/26.
//

import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ClipboardFilesPayloadTests {
    @Test
    func singleFileUsesFilenameAsTitle() {
        let payload =
            ClipboardFilesPayload(
                files: [
                    makeFile(
                        path:
                            "/Users/example/Documents/report.pdf",
                        displayName:
                            "report.pdf",
                        byteCount:
                            12_000
                    )
                ]
            )

        #expect(
            payload.displayTitle ==
                "report.pdf"
        )

        #expect(
            payload.itemCountText ==
                "1 Item"
        )

        #expect(
            payload.rowMetadataText.contains(
                "PDF"
            )
        )

        #expect(
            payload.rowMetadataText.contains(
                "KB"
            ) ||
            payload.rowMetadataText.contains(
                "kB"
            )
        )
    }

    @Test
    func singleFolderUsesFolderMetadata() {
        let payload =
            ClipboardFilesPayload(
                files: [
                    makeFile(
                        path:
                            "/Users/example/Documents/Project",
                        displayName:
                            "Project",
                        isDirectory:
                            true
                    )
                ]
            )

        #expect(
            payload.displayTitle ==
                "Project"
        )

        #expect(
            payload.rowMetadataText ==
                "Folder"
        )
    }

    @Test
    func multipleItemsUseCountTitleAndComposition() {
        let payload =
            ClipboardFilesPayload(
                files: [
                    makeFile(
                        path:
                            "/tmp/first.txt",
                        displayName:
                            "first.txt"
                    ),
                    makeFile(
                        path:
                            "/tmp/second.txt",
                        displayName:
                            "second.txt"
                    ),
                    makeFile(
                        path:
                            "/tmp/Folder",
                        displayName:
                            "Folder",
                        isDirectory:
                            true
                    )
                ]
            )

        #expect(
            payload.displayTitle ==
                "3 Items"
        )

        #expect(
            payload.compositionText ==
                "2 Files • 1 Folder"
        )

        #expect(
            payload.rowMetadataText ==
                "2 Files • 1 Folder"
        )
    }

    @Test
    func searchableTextContainsNamesPathsAndKinds() {
        let payload =
            ClipboardFilesPayload(
                files: [
                    makeFile(
                        path:
                            "/Users/example/Desktop/Contract.pdf",
                        displayName:
                            "Contract.pdf"
                    ),
                    makeFile(
                        path:
                            "/Users/example/Desktop/Photos",
                        displayName:
                            "Photos",
                        isDirectory:
                            true
                    )
                ]
            )

        #expect(
            payload.searchableText.contains(
                "Contract.pdf"
            )
        )

        #expect(
            payload.searchableText.contains(
                "/Users/example/Desktop/Photos"
            )
        )

        #expect(
            payload.searchableText.contains(
                "Folder"
            )
        )
    }

    @Test
    func blankDisplayNameFallsBackToPathComponent() {
        let file =
            makeFile(
                path:
                    "/Users/example/Desktop/archive.zip",
                displayName:
                    "   "
            )

        #expect(
            file.displayName ==
                "archive.zip"
        )
    }

    @Test
    func negativeByteCountIsClampedToZero() {
        let file =
            makeFile(
                path:
                    "/tmp/test.dat",
                displayName:
                    "test.dat",
                byteCount:
                    -500
            )

        #expect(
            file.byteCount ==
                0
        )
    }

    @Test
    func duplicateKeyIgnoresFileSelectionOrder() {
        let firstFile =
            makeFile(
                path:
                    "/tmp/First.txt",
                displayName:
                    "First.txt"
            )

        let secondFile =
            makeFile(
                path:
                    "/tmp/Second.txt",
                displayName:
                    "Second.txt"
            )

        let firstPayload =
            ClipboardFilesPayload(
                files: [
                    firstFile,
                    secondFile
                ]
            )

        let secondPayload =
            ClipboardFilesPayload(
                files: [
                    secondFile,
                    firstFile
                ]
            )

        #expect(
            firstPayload.duplicateKey ==
                secondPayload.duplicateKey
        )

        #expect(
            firstPayload.duplicateKey
                .hasPrefix(
                    "files:"
                )
        )
    }

    @Test
    func payloadRoundTripPreservesMetadata()
        throws
    {
        let originalPayload =
            ClipboardFilesPayload(
                files: [
                    ClipboardFileReference(
                        path:
                            "/tmp/example.mov",
                        displayName:
                            "example.mov",
                        isDirectory:
                            false,
                        byteCount:
                            84_000,
                        bookmarkData:
                            Data(
                                [1, 2, 3, 4]
                            )
                    )
                ]
            )

        let data =
            try JSONEncoder()
                .encode(
                    originalPayload
                )

        let decodedPayload =
            try JSONDecoder()
                .decode(
                    ClipboardFilesPayload.self,
                    from:
                        data
                )

        #expect(
            decodedPayload ==
                originalPayload
        )
    }

    private func makeFile(
        path: String,
        displayName: String,
        isDirectory: Bool = false,
        byteCount: Int? = nil
    ) -> ClipboardFileReference {
        ClipboardFileReference(
            path:
                path,
            displayName:
                displayName,
            isDirectory:
                isDirectory,
            byteCount:
                byteCount
        )
    }
}
