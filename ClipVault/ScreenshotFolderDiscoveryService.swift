//
//  ScreenshotFolderDiscoveryService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/23/26.
//

import Foundation

@MainActor
final class ScreenshotFolderDiscoveryService
{
    private let candidateService:
        ScreenshotCandidateService

    private let directoryContentsProvider:
        (URL) throws -> [URL]

    private var monitoredFolderURL:
        URL?

    private var monitoringStartedAt:
        Date?

    private var discoveredFileURLs:
        Set<URL> =
            []

    init(
        candidateService:
            ScreenshotCandidateService? =
                nil,
        directoryContentsProvider:
            @escaping (URL) throws -> [URL] = {
                folderURL in

                try FileManager
                    .default
                    .contentsOfDirectory(
                        at:
                            folderURL,
                        includingPropertiesForKeys: [
                            .isRegularFileKey,
                            .creationDateKey,
                            .contentModificationDateKey,
                            .fileSizeKey,
                            .contentTypeKey
                        ],
                        options: [
                            .skipsHiddenFiles
                        ]
                    )
            }
    ) {
        self.candidateService =
            candidateService ??
            ScreenshotCandidateService()

        self.directoryContentsProvider =
            directoryContentsProvider
    }

    func beginMonitoring(
        folderURL:
            URL,
        startedAt:
            Date =
                Date()
    ) {
        monitoredFolderURL =
            folderURL
                .standardizedFileURL

        monitoringStartedAt =
            startedAt

        discoveredFileURLs =
            []
    }

    func stopMonitoring()
    {
        monitoredFolderURL =
            nil

        monitoringStartedAt =
            nil

        discoveredFileURLs =
            []
    }

    func discoverNewCandidates()
        -> [ScreenshotCandidate]
    {
        guard
            let monitoredFolderURL,
            let monitoringStartedAt
        else {
            return []
        }

        let fileURLs:
            [URL]

        do {
            fileURLs =
                try directoryContentsProvider(
                    monitoredFolderURL
                )
        } catch {
            return []
        }

        var newCandidates:
            [ScreenshotCandidate] =
                []

        for fileURL in fileURLs {
            let standardizedFileURL =
                fileURL
                    .standardizedFileURL

            guard
                !discoveredFileURLs
                    .contains(
                        standardizedFileURL
                    )
            else {
                continue
            }

            guard
                let candidate =
                    candidateService
                        .candidate(
                            for:
                                standardizedFileURL,
                            monitoringStartedAt:
                                monitoringStartedAt
                        )
            else {
                continue
            }

            discoveredFileURLs
                .insert(
                    standardizedFileURL
                )

            newCandidates
                .append(
                    candidate
                )
        }

        return newCandidates
            .sorted {
                leftCandidate,
                rightCandidate in

                if leftCandidate.creationDate ==
                    rightCandidate.creationDate
                {
                    return leftCandidate
                        .fileURL
                        .lastPathComponent <
                        rightCandidate
                            .fileURL
                            .lastPathComponent
                }

                return leftCandidate
                    .creationDate <
                    rightCandidate
                        .creationDate
            }
    }
}
