//
//  ClipboardLinkPreviewService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/20/26.
//

private let clipboardLinkFailedPreviewLifetime:
    TimeInterval =
        6 * 60 * 60

private let clipboardLinkMaximumVisualByteCount =
    8 * 1_024 * 1_024

import CryptoKit
import Foundation
import LinkPresentation
import UniformTypeIdentifiers

struct ClipboardLinkPreview:
    Codable,
    Equatable,
    Sendable
{
    let requestedURLString:
        String

    let resolvedURLString:
        String

    let title:
        String?

    let domain:
        String

    let imageData:
        Data?

    let iconData:
        Data?

    let fetchedAt:
        Date

    let didFetchSuccessfully:
        Bool

    var preferredVisualData:
        Data?
    {
        imageData ??
        iconData
    }
}

enum ClipboardLinkPreviewServiceError:
    LocalizedError
{
    case invalidURL
    case metadataUnavailable

    var errorDescription:
        String?
    {
        switch self {
        case .invalidURL:
            return
                "The saved link is not a valid URL."

        case .metadataUnavailable:
            return
                "No rich preview metadata was available for this link."
        }
    }
}

@MainActor
final class ClipboardLinkPreviewService {
    typealias PreviewFetcher =
        @MainActor (URL) async throws
            -> ClipboardLinkPreview

    static let shared =
        ClipboardLinkPreviewService()

    private let cacheRootURL:
        URL

    private let previewFetcher:
        PreviewFetcher

    private var memoryCache:
        [String: ClipboardLinkPreview] =
            [:]

    convenience init() {
        self.init(
            cacheRootURL:
                nil,
            previewFetcher:
                nil
        )
    }

    init(
        cacheRootURL:
            URL? = nil,
        previewFetcher:
            PreviewFetcher? = nil
    ) {
        if let cacheRootURL {
            self.cacheRootURL =
                cacheRootURL
        } else {
            self.cacheRootURL =
                FileManager.default
                    .urls(
                        for:
                            .cachesDirectory,
                        in:
                            .userDomainMask
                    )
                    .first?
                    .appendingPathComponent(
                        "ClipVault",
                        isDirectory:
                            true
                    )
                    .appendingPathComponent(
                        "Link Previews",
                        isDirectory:
                            true
                    ) ??
                FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent(
                        "ClipVault Link Previews",
                        isDirectory:
                            true
                    )
        }

        self.previewFetcher =
            previewFetcher ??
            Self.fetchNativePreview
    }

    func preview(
        for url:
            URL
    ) async -> ClipboardLinkPreview {
        let normalizedURL =
            Self.normalizedURL(
                url
            )

        let cacheKey =
            normalizedURL
                .absoluteString

        if let memoryPreview =
            memoryCache[
                cacheKey
            ],
           !Self.shouldRetry(
                memoryPreview
           )
        {
            return memoryPreview
        }

        if let diskPreview =
            loadCachedPreview(
                for:
                    normalizedURL
            ),
           !Self.shouldRetry(
                diskPreview
           )
        {
            memoryCache[
                cacheKey
            ] =
                diskPreview

            return diskPreview
        }

        let fetchedPreview:
            ClipboardLinkPreview

        do {
            fetchedPreview =
                try await previewFetcher(
                    normalizedURL
                )
        } catch {
            fetchedPreview =
                Self.fallbackPreview(
                    for:
                        normalizedURL
                )
        }

        memoryCache[
            cacheKey
        ] =
            fetchedPreview

        saveCachedPreview(
            fetchedPreview,
            for:
                normalizedURL
        )

        return fetchedPreview
    }

    func removeAllCachedPreviews()
        throws
    {
        memoryCache = [:]

        guard
            FileManager.default
                .fileExists(
                    atPath:
                        cacheRootURL.path
                )
        else {
            return
        }

        try FileManager.default
            .removeItem(
                at:
                    cacheRootURL
            )
    }

    nonisolated static func normalizedURL(
        _ url:
            URL
    ) -> URL {
        guard
            var components =
                URLComponents(
                    url:
                        url,
                    resolvingAgainstBaseURL:
                        false
                )
        else {
            return url
        }

        components.fragment =
            nil

        return components.url ??
            url
    }

    nonisolated static func domain(
        for url:
            URL
    ) -> String {
        let host =
            url.host?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                ) ??
            ""

        guard !host.isEmpty else {
            return url
                .absoluteString
        }

        if host
            .lowercased()
            .hasPrefix(
                "www."
            )
        {
            return String(
                host.dropFirst(4)
            )
        }

        return host
    }

    nonisolated static func cacheFilename(
        for url:
            URL
    ) -> String {
        let normalizedString =
            normalizedURL(
                url
            )
            .absoluteString

        let digest =
            SHA256.hash(
                data:
                    Data(
                        normalizedString
                            .utf8
                    )
            )

        return digest
            .map {
                String(
                    format:
                        "%02x",
                    $0
                )
            }
            .joined() +
            ".json"
    }

    private func cacheURL(
        for url:
            URL
    ) -> URL {
        cacheRootURL
            .appendingPathComponent(
                Self.cacheFilename(
                    for:
                        url
                ),
                isDirectory:
                    false
            )
    }

    private func loadCachedPreview(
        for url:
            URL
    ) -> ClipboardLinkPreview? {
        let fileURL =
            cacheURL(
                for:
                    url
            )

        guard
            let data =
                try? Data(
                    contentsOf:
                        fileURL
                )
        else {
            return nil
        }

        return try? JSONDecoder()
            .decode(
                ClipboardLinkPreview.self,
                from:
                    data
            )
    }

    private func saveCachedPreview(
        _ preview:
            ClipboardLinkPreview,
        for url:
            URL
    ) {
        do {
            try FileManager.default
                .createDirectory(
                    at:
                        cacheRootURL,
                    withIntermediateDirectories:
                        true
                )

            let data =
                try JSONEncoder()
                    .encode(
                        preview
                    )

            try data.write(
                to:
                    cacheURL(
                        for:
                            url
                    ),
                options:
                    .atomic
            )
        } catch {
            /*
             A failed cache write must never prevent
             the link itself from remaining usable.
             */
        }
    }

    private static func shouldRetry(
        _ preview:
            ClipboardLinkPreview
    ) -> Bool {
        guard
            !preview
                .didFetchSuccessfully
        else {
            return false
        }

        return Date()
            .timeIntervalSince(
                preview.fetchedAt
            ) >=
        clipboardLinkFailedPreviewLifetime
    }

    private nonisolated static func fallbackPreview(
        for url:
            URL
    ) -> ClipboardLinkPreview {
        ClipboardLinkPreview(
            requestedURLString:
                url.absoluteString,
            resolvedURLString:
                url.absoluteString,
            title:
                nil,
            domain:
                domain(
                    for:
                        url
                ),
            imageData:
                nil,
            iconData:
                nil,
            fetchedAt:
                Date(),
            didFetchSuccessfully:
                false
        )
    }

    private static func fetchNativePreview(
        for url:
            URL
    ) async throws -> ClipboardLinkPreview {
        let metadata =
            try await fetchMetadata(
                for:
                    url
            )

        let resolvedURL =
            metadata.url ??
            url

        async let representativeImageData =
            loadVisualData(
                from:
                    metadata
                        .imageProvider
            )

        async let representativeIconData =
            loadVisualData(
                from:
                    metadata
                        .iconProvider
            )

        let loadedImageData =
            await representativeImageData

        let loadedIconData =
            await representativeIconData

        return ClipboardLinkPreview(
            requestedURLString:
                url.absoluteString,
            resolvedURLString:
                resolvedURL
                    .absoluteString,
            title:
                normalizedText(
                    metadata.title
                ),
            domain:
                domain(
                    for:
                        resolvedURL
                ),
            imageData:
                acceptedVisualData(
                    loadedImageData
                ),
            iconData:
                acceptedVisualData(
                    loadedIconData
                ),
            fetchedAt:
                Date(),
            didFetchSuccessfully:
                true
        )
    }

    private static func fetchMetadata(
        for url:
            URL
    ) async throws -> LPLinkMetadata {
        try await withCheckedThrowingContinuation {
            continuation in

            let provider =
                LPMetadataProvider()

            provider.timeout =
                15

            provider
                .shouldFetchSubresources =
                    true

            provider
                .startFetchingMetadata(
                    for:
                        url
                ) {
                    metadata,
                    error in

                    if let metadata {
                        continuation
                            .resume(
                                returning:
                                    metadata
                            )

                        return
                    }

                    continuation
                        .resume(
                            throwing:
                                error ??
                                ClipboardLinkPreviewServiceError
                                    .metadataUnavailable
                        )
                }
        }
    }

    private static func loadVisualData(
        from provider:
            NSItemProvider?
    ) async -> Data? {
        guard let provider else {
            return nil
        }

        let imageTypeIdentifier =
            provider
                .registeredTypeIdentifiers
                .first {
                    identifier in

                    guard
                        let type =
                            UTType(
                                identifier
                            )
                    else {
                        return false
                    }

                    return type
                        .conforms(
                            to:
                                .image
                        )
                }

        guard
            let imageTypeIdentifier
        else {
            return nil
        }

        return await withCheckedContinuation {
            continuation in

            provider
                .loadDataRepresentation(
                    forTypeIdentifier:
                        imageTypeIdentifier
                ) {
                    data,
                    _ in

                    continuation
                        .resume(
                            returning:
                                data
                        )
                }
        }
    }

    private static func acceptedVisualData(
        _ data:
            Data?
    ) -> Data? {
        guard
            let data,
            !data.isEmpty,
            data.count <=
                clipboardLinkMaximumVisualByteCount
        else {
            return nil
        }

        return data
    }

    private nonisolated static func normalizedText(
        _ text:
            String?
    ) -> String? {
        let cleanedText =
            text?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            cleanedText?
                .isEmpty == false
        else {
            return nil
        }

        return cleanedText
    }
}
