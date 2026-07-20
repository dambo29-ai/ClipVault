//
//  ClipboardFileAvailabilityService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/19/26.
//

import Foundation

enum ClipboardFileAvailabilityStatus:
    Equatable,
    Sendable
{
    case available
    case downloading
    case unavailable
}

@MainActor
final class ClipboardFileAvailabilityService {
    static let shared =
        ClipboardFileAvailabilityService()

    private let fileReferenceService:
        ClipboardFileReferenceService

    private let isUbiquitousItem:
        (URL) -> Bool

    private let downloadingStatus:
        (URL) throws -> URLUbiquitousItemDownloadingStatus?

    private let startDownloading:
        (URL) throws -> Void

    private init() {
        fileReferenceService =
            .shared

        isUbiquitousItem = {
            fileURL in

            FileManager.default
                .isUbiquitousItem(
                    at:
                        fileURL
                )
        }

        downloadingStatus = {
            fileURL in

            try fileURL
                .resourceValues(
                    forKeys: [
                        .ubiquitousItemDownloadingStatusKey
                    ]
                )
                .ubiquitousItemDownloadingStatus
        }

        startDownloading = {
            fileURL in

            try FileManager.default
                .startDownloadingUbiquitousItem(
                    at:
                        fileURL
                )
        }
    }

    init(
        fileReferenceService:
            ClipboardFileReferenceService,
        isUbiquitousItem:
            @escaping (URL) -> Bool = {
                fileURL in

                FileManager.default
                    .isUbiquitousItem(
                        at:
                            fileURL
                    )
            },
        downloadingStatus:
            @escaping (URL) throws
                -> URLUbiquitousItemDownloadingStatus? = {
                    fileURL in

                    try fileURL
                        .resourceValues(
                            forKeys: [
                                .ubiquitousItemDownloadingStatusKey
                            ]
                        )
                        .ubiquitousItemDownloadingStatus
                },
        startDownloading:
            @escaping (URL) throws -> Void = {
                fileURL in

                try FileManager.default
                    .startDownloadingUbiquitousItem(
                        at:
                            fileURL
                    )
            }
    ) {
        self.fileReferenceService =
            fileReferenceService

        self.isUbiquitousItem =
            isUbiquitousItem

        self.downloadingStatus =
            downloadingStatus

        self.startDownloading =
            startDownloading
    }

    func status(
        for payload:
            ClipboardFilesPayload
    ) -> ClipboardFileAvailabilityStatus {
        guard !payload.files.isEmpty else {
            return .unavailable
        }

        var resolvedReferences:
            [ResolvedClipboardFileReference] =
                []

        defer {
            for resolvedReference in
                resolvedReferences
            {
                resolvedReference
                    .stopAccessing()
            }
        }

        var containsDownloadingItem =
            false

        do {
            for fileReference in
                payload.files
            {
                let resolvedReference =
                    try fileReferenceService
                        .resolve(
                            fileReference
                        )

                resolvedReferences.append(
                    resolvedReference
                )

                let fileURL =
                    resolvedReference.url

                guard
                    isUbiquitousItem(
                        fileURL
                    )
                else {
                    continue
                }

                let status =
                    try downloadingStatus(
                        fileURL
                    )

                switch status {
                case .current:
                    break

                case .downloaded:
                    break

                case .notDownloaded:
                    try? startDownloading(
                        fileURL
                    )

                    containsDownloadingItem =
                        true

                default:
                    containsDownloadingItem =
                        true
                }
            }

            return containsDownloadingItem
                ? .downloading
                : .available
        } catch {
            return .unavailable
        }
    }
}
