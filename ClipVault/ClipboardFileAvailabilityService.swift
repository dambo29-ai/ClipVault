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
    case unavailable
}

@MainActor
final class ClipboardFileAvailabilityService {
    static let shared =
        ClipboardFileAvailabilityService()

    private let fileReferenceService:
        ClipboardFileReferenceService

    private init() {
        fileReferenceService =
            .shared
    }

    init(
        fileReferenceService:
            ClipboardFileReferenceService
    ) {
        self.fileReferenceService =
            fileReferenceService
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
            }

            return .available
        } catch {
            return .unavailable
        }
    }
}
