//
//  ClipboardLinkPreviewServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/20/26.
//

import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ClipboardLinkPreviewServiceTests {
    @Test
    func domainRemovesCommonWWWPrefix()
        throws
    {
        let url =
            try #require(
                URL(
                    string:
                        "https://www.apple.com/mac/"
                )
            )

        #expect(
            ClipboardLinkPreviewService
                .domain(
                    for:
                        url
                ) ==
                "apple.com"
        )
    }

    @Test
    func cacheFilenameIsStableAndIgnoresFragment()
        throws
    {
        let firstURL =
            try #require(
                URL(
                    string:
                        "https://example.com/article#first"
                )
            )

        let secondURL =
            try #require(
                URL(
                    string:
                        "https://example.com/article#second"
                )
            )

        #expect(
            ClipboardLinkPreviewService
                .cacheFilename(
                    for:
                        firstURL
                ) ==
            ClipboardLinkPreviewService
                .cacheFilename(
                    for:
                        secondURL
                )
        )
    }

    @Test
    func cachedPreviewIsReusedWithoutRefetching()
        async throws
    {
        let cacheRootURL =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "ClipboardLinkPreviewServiceTests-" +
                    UUID().uuidString,
                    isDirectory:
                        true
                )

        defer {
            try? FileManager.default
                .removeItem(
                    at:
                        cacheRootURL
                )
        }

        let url =
            try #require(
                URL(
                    string:
                        "https://example.com/article"
                )
            )

        var fetchCount =
            0

        let fetcher:
            ClipboardLinkPreviewService
                .PreviewFetcher =
        {
            requestedURL in

            fetchCount += 1

            return ClipboardLinkPreview(
                requestedURLString:
                    requestedURL
                        .absoluteString,
                resolvedURLString:
                    requestedURL
                        .absoluteString,
                title:
                    "Example Article",
                domain:
                    "example.com",
                imageData:
                    Data([
                        1,
                        2,
                        3
                    ]),
                iconData:
                    nil,
                fetchedAt:
                    Date(),
                didFetchSuccessfully:
                    true
            )
        }

        let firstService =
            ClipboardLinkPreviewService(
                cacheRootURL:
                    cacheRootURL,
                previewFetcher:
                    fetcher
            )

        let firstPreview =
            await firstService
                .preview(
                    for:
                        url
                )

        #expect(
            firstPreview.title ==
                "Example Article"
        )

        #expect(
            fetchCount ==
                1
        )

        let secondService =
            ClipboardLinkPreviewService(
                cacheRootURL:
                    cacheRootURL,
                previewFetcher:
                    fetcher
            )

        let secondPreview =
            await secondService
                .preview(
                    for:
                        url
                )

        #expect(
            secondPreview ==
                firstPreview
        )

        #expect(
            fetchCount ==
                1
        )
    }
}
