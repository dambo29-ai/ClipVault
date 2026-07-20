//
//  ClipboardFileURLRoutingServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/17/26.
//

import AppKit
import Foundation
import Testing
@testable import ClipVault

struct ClipboardFileURLRoutingServiceTests {
    @Test
    func rasterImageIsRoutedToImages()
        throws
    {
        let rootURL =
            try makeTestDirectory()

        defer {
            removeTestDirectory(
                rootURL
            )
        }

        let imageURL =
            rootURL
                .appendingPathComponent(
                    "Photo.png"
                )

        try makePNGData()
            .write(
                to:
                    imageURL
            )

        let result =
            ClipboardFileURLRoutingService
                .route([
                    imageURL
                ])

        #expect(
            result.imageFileURLs ==
                [
                    imageURL
                        .standardizedFileURL
                ]
        )

        #expect(
            result.fileAndFolderURLs
                .isEmpty
        )

        #expect(
            result.failedURLs.isEmpty
        )
    }

    @Test
    func ordinaryFileIsRoutedToFiles()
        throws
    {
        let rootURL =
            try makeTestDirectory()

        defer {
            removeTestDirectory(
                rootURL
            )
        }

        let fileURL =
            rootURL
                .appendingPathComponent(
                    "Notes.txt"
                )

        try Data(
            "Notes"
                .utf8
        )
        .write(
            to:
                fileURL
        )

        let result =
            ClipboardFileURLRoutingService
                .route([
                    fileURL
                ])

        #expect(
            result.imageFileURLs.isEmpty
        )

        #expect(
            result.fileAndFolderURLs ==
                [
                    fileURL
                        .standardizedFileURL
                ]
        )
    }

    @Test
    func folderIsRoutedToFiles()
        throws
    {
        let rootURL =
            try makeTestDirectory()

        defer {
            removeTestDirectory(
                rootURL
            )
        }

        let folderURL =
            rootURL
                .appendingPathComponent(
                    "Project",
                    isDirectory:
                        true
                )

        try FileManager.default
            .createDirectory(
                at:
                    folderURL,
                withIntermediateDirectories:
                    true
            )

        let result =
            ClipboardFileURLRoutingService
                .route([
                    folderURL
                ])

        #expect(
            result.imageFileURLs.isEmpty
        )

        #expect(
            result.fileAndFolderURLs ==
                [
                    folderURL
                        .standardizedFileURL
                ]
        )
    }

    @Test
    func mixedSelectionIsSeparated()
        throws
    {
        let rootURL =
            try makeTestDirectory()

        defer {
            removeTestDirectory(
                rootURL
            )
        }

        let imageURL =
            rootURL
                .appendingPathComponent(
                    "Photo.png"
                )

        try makePNGData()
            .write(
                to:
                    imageURL
            )

        let documentURL =
            rootURL
                .appendingPathComponent(
                    "Document.txt"
                )

        try Data(
            "Document"
                .utf8
        )
        .write(
            to:
                documentURL
        )

        let folderURL =
            rootURL
                .appendingPathComponent(
                    "Folder",
                    isDirectory:
                        true
                )

        try FileManager.default
            .createDirectory(
                at:
                    folderURL,
                withIntermediateDirectories:
                    true
            )

        let result =
            ClipboardFileURLRoutingService
                .route([
                    imageURL,
                    documentURL,
                    folderURL
                ])

        #expect(
            result.imageFileURLs ==
                [
                    imageURL
                        .standardizedFileURL
                ]
        )

        #expect(
            result.fileAndFolderURLs ==
                [
                    documentURL
                        .standardizedFileURL,
                    folderURL
                        .standardizedFileURL
                ]
        )
    }
    
    @Test
    func symbolicLinkToImageIsRoutedAsFile()
        throws
    {
        let rootURL =
            try makeTestDirectory()

        defer {
            removeTestDirectory(
                rootURL
            )
        }

        let imageURL =
            rootURL
                .appendingPathComponent(
                    "Photo.png"
                )

        try makePNGData()
            .write(
                to:
                    imageURL
            )

        let symbolicLinkURL =
            rootURL
                .appendingPathComponent(
                    "Photo Link"
                )

        try FileManager.default
            .createSymbolicLink(
                at:
                    symbolicLinkURL,
                withDestinationURL:
                    imageURL
            )

        let result =
            ClipboardFileURLRoutingService
                .route([
                    symbolicLinkURL
                ])

        #expect(
            result.imageFileURLs
                .isEmpty
        )

        #expect(
            result.fileAndFolderURLs ==
                [
                    symbolicLinkURL
                        .standardizedFileURL
                ]
        )

        #expect(
            result.failedURLs
                .isEmpty
        )
    }

    @Test
    func missingResourceIsReportedAsFailure()
        throws
    {
        let rootURL =
            try makeTestDirectory()

        defer {
            removeTestDirectory(
                rootURL
            )
        }

        let missingURL =
            rootURL
                .appendingPathComponent(
                    "Missing.txt"
                )

        let result =
            ClipboardFileURLRoutingService
                .route([
                    missingURL
                ])

        #expect(
            result.imageFileURLs.isEmpty
        )

        #expect(
            result.fileAndFolderURLs
                .isEmpty
        )

        #expect(
            result.failedURLs ==
                [
                    missingURL
                ]
        )
    }

    private func makeTestDirectory()
        throws -> URL
    {
        let directoryURL =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "ClipboardFileURLRoutingServiceTests-" +
                    UUID().uuidString,
                    isDirectory:
                        true
                )

        try FileManager.default
            .createDirectory(
                at:
                    directoryURL,
                withIntermediateDirectories:
                    true
            )

        return directoryURL
    }

    private func removeTestDirectory(
        _ directoryURL: URL
    ) {
        try? FileManager.default
            .removeItem(
                at:
                    directoryURL
            )
    }

    private func makePNGData()
        throws -> Data
    {
        let image =
            NSImage(
                size:
                    NSSize(
                        width: 8,
                        height: 8
                    )
            )

        image.lockFocus()

        NSColor.white.setFill()

        NSRect(
            x: 0,
            y: 0,
            width: 8,
            height: 8
        )
        .fill()

        image.unlockFocus()

        guard
            let tiffData =
                image.tiffRepresentation,
            let bitmap =
                NSBitmapImageRep(
                    data:
                        tiffData
                ),
            let pngData =
                bitmap.representation(
                    using:
                        .png,
                    properties:
                        [:]
                )
        else {
            throw TestImageError
                .couldNotCreatePNG
        }

        return pngData
    }

    private enum TestImageError:
        Error
    {
        case couldNotCreatePNG
    }
}
