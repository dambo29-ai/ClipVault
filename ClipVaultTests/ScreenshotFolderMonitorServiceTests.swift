//
//  ScreenshotFolderMonitorServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/23/26.
//

import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ScreenshotFolderMonitorServiceTests
{
    @Test
    func reportsSecurityScopedAccessFailure()
    {
        let folderURL =
            makeFolderURL()

        let service =
            ScreenshotFolderMonitorService(
                securityScopeStarter: {
                    receivedURL in

                    #expect(
                        receivedURL ==
                            folderURL
                    )

                    return false
                },
                folderOpener: {
                    _ in

                    Issue.record(
                        "The folder must not be opened after security-scoped access fails."
                    )

                    return -1
                }
            )

        let result =
            service
                .startMonitoring(
                    folderURL:
                        folderURL,
                    onFolderChanged: {
                    }
                )

        #expect(
            result ==
                .securityScopedAccessFailed
        )

        #expect(
            !service
                .isMonitoring
        )

        #expect(
            service
                .monitoredFolderURL ==
                nil
        )
    }

    @Test
    func stopsSecurityScopedAccessWhenFolderOpenFails()
    {
        let folderURL =
            makeFolderURL()

        var stoppedFolderURL:
            URL?

        let service =
            ScreenshotFolderMonitorService(
                securityScopeStarter: {
                    receivedURL in

                    #expect(
                        receivedURL ==
                            folderURL
                    )

                    return true
                },
                securityScopeStopper: {
                    receivedURL in

                    stoppedFolderURL =
                        receivedURL
                },
                folderOpener: {
                    receivedURL in

                    #expect(
                        receivedURL ==
                            folderURL
                    )

                    return -1
                }
            )

        let result =
            service
                .startMonitoring(
                    folderURL:
                        folderURL,
                    onFolderChanged: {
                    }
                )

        #expect(
            result ==
                .folderOpenFailed
        )

        #expect(
            stoppedFolderURL ==
                folderURL
        )

        #expect(
            !service
                .isMonitoring
        )
    }

    @Test
    func reportsAlreadyMonitoringWithoutStartingAgain()
        throws
    {
        let fixture =
            try makeFolderFixture()

        defer {
            removeFolderFixture(
                fixture
            )
        }

        var securityScopeStartCount =
            0

        let service =
            ScreenshotFolderMonitorService(
                securityScopeStarter: {
                    _ in

                    securityScopeStartCount +=
                        1

                    return true
                }
            )

        let firstResult =
            service
                .startMonitoring(
                    folderURL:
                        fixture
                            .folderURL,
                    onFolderChanged: {
                    }
                )

        #expect(
            firstResult ==
                .started
        )

        let secondResult =
            service
                .startMonitoring(
                    folderURL:
                        fixture
                            .folderURL,
                    onFolderChanged: {
                    }
                )

        #expect(
            secondResult ==
                .alreadyMonitoring
        )

        #expect(
            securityScopeStartCount ==
                1
        )

        service
            .stopMonitoring()
    }

    @Test
    func startsAndStopsMonitoring()
        throws
    {
        let fixture =
            try makeFolderFixture()

        defer {
            removeFolderFixture(
                fixture
            )
        }

        var startedFolderURL:
            URL?

        var stoppedFolderURL:
            URL?

        let service =
            ScreenshotFolderMonitorService(
                securityScopeStarter: {
                    receivedURL in

                    startedFolderURL =
                        receivedURL

                    return true
                },
                securityScopeStopper: {
                    receivedURL in

                    stoppedFolderURL =
                        receivedURL
                }
            )

        let result =
            service
                .startMonitoring(
                    folderURL:
                        fixture
                            .folderURL,
                    onFolderChanged: {
                    }
                )

        #expect(
            result ==
                .started
        )

        #expect(
            service
                .isMonitoring
        )

        #expect(
            service
                .monitoredFolderURL ==
                fixture
                    .folderURL
                    .standardizedFileURL
        )

        #expect(
            startedFolderURL ==
                fixture
                    .folderURL
                    .standardizedFileURL
        )

        service
            .stopMonitoring()

        #expect(
            !service
                .isMonitoring
        )

        #expect(
            service
                .monitoredFolderURL ==
                nil
        )

        #expect(
            stoppedFolderURL ==
                fixture
                    .folderURL
                    .standardizedFileURL
        )
    }

    @Test
    func stoppingInactiveMonitorDoesNothing()
    {
        var securityScopeStopCount =
            0

        let service =
            ScreenshotFolderMonitorService(
                securityScopeStopper: {
                    _ in

                    securityScopeStopCount +=
                        1
                }
            )

        service
            .stopMonitoring()

        #expect(
            securityScopeStopCount ==
                0
        )

        #expect(
            !service
                .isMonitoring
        )
    }

    private func makeFolderURL()
        -> URL
    {
        URL(
            fileURLWithPath:
                "/Users/TestUser/Desktop",
            isDirectory:
                true
        )
        .standardizedFileURL
    }

    private func makeFolderFixture()
        throws -> FolderFixture
    {
        let folderURL =
            FileManager
                .default
                .temporaryDirectory
                .appendingPathComponent(
                    "ScreenshotFolderMonitorServiceTests-" +
                    UUID()
                        .uuidString,
                    isDirectory:
                        true
                )

        try FileManager
            .default
            .createDirectory(
                at:
                    folderURL,
                withIntermediateDirectories:
                    true
            )

        return FolderFixture(
            folderURL:
                folderURL
        )
    }

    private func removeFolderFixture(
        _ fixture:
            FolderFixture
    ) {
        try? FileManager
            .default
            .removeItem(
                at:
                    fixture
                        .folderURL
            )
    }

    private struct FolderFixture
    {
        let folderURL:
            URL
    }
}
