//
//  ScreenshotAutomationControllerTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/23/26.
//

import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ScreenshotAutomationControllerTests
{
    @Test
    func defaultsToDisabledAndDoesNotMonitor()
    {
        let fixture =
            makeFixture()

        defer {
            fixture
                .cleanup()
        }

        let result =
            fixture
                .controller
                .applySavedPreference()

        #expect(
            result ==
                .disabled
        )

        #expect(
            !fixture
                .controller
                .isEnabled
        )

        #expect(
            !fixture
                .controller
                .isMonitoring
        )
    }

    @Test
    func enablingWithoutFolderAccessFailsAndRemainsDisabled()
    {
        let fixture =
            makeFixture(
                grantFolderAccess:
                    false
            )

        defer {
            fixture
                .cleanup()
        }

        let result =
            fixture
                .controller
                .setEnabled(
                    true
                )

        #expect(
            result ==
                .accessRequired
        )

        #expect(
            !fixture
                .controller
                .isEnabled
        )

        #expect(
            !fixture
                .controller
                .isMonitoring
        )
    }

    @Test
    func enablingWithFolderAccessStartsMonitoring()
    {
        let fixture =
            makeFixture(
                grantFolderAccess:
                    true
            )

        defer {
            fixture
                .cleanup()
        }

        let result =
            fixture
                .controller
                .setEnabled(
                    true
                )

        #expect(
            result ==
                .enabled
        )

        #expect(
            fixture
                .controller
                .isEnabled
        )

        #expect(
            fixture
                .controller
                .isMonitoring
        )
    }

    @Test
    func disablingStopsMonitoringAndPersistsDisabledState()
    {
        let fixture =
            makeFixture(
                grantFolderAccess:
                    true
            )

        defer {
            fixture
                .cleanup()
        }

        #expect(
            fixture
                .controller
                .setEnabled(
                    true
                ) ==
                .enabled
        )

        let result =
            fixture
                .controller
                .setEnabled(
                    false
                )

        #expect(
            result ==
                .disabled
        )

        #expect(
            !fixture
                .controller
                .isEnabled
        )

        #expect(
            !fixture
                .controller
                .isMonitoring
        )
    }

    @Test
    func savedEnabledPreferenceStartsMonitoringOnLaunch()
    {
        let fixture =
            makeFixture(
                grantFolderAccess:
                    true,
                initiallyEnabled:
                    true
            )

        defer {
            fixture
                .cleanup()
        }

        let result =
            fixture
                .controller
                .applySavedPreference()

        #expect(
            result ==
                .enabled
        )

        #expect(
            fixture
                .controller
                .isEnabled
        )

        #expect(
            fixture
                .controller
                .isMonitoring
        )
    }

    private func makeFixture(
        grantFolderAccess:
            Bool =
                false,
        initiallyEnabled:
            Bool =
                false
    ) -> ControllerFixture {
        let suiteName =
            "ScreenshotAutomationControllerTests-" +
            UUID()
                .uuidString

        let userDefaults =
            UserDefaults(
                suiteName:
                    suiteName
            )!

        userDefaults
            .removePersistentDomain(
                forName:
                    suiteName
            )

        if initiallyEnabled {
            userDefaults
                .set(
                    true,
                    forKey:
                        ScreenshotAutomationPreferenceService
                            .defaultsKey
                )
        }

        let folderURL =
            FileManager
                .default
                .temporaryDirectory
                .appendingPathComponent(
                    "ScreenshotAutomationControllerTests-" +
                    UUID()
                        .uuidString,
                    isDirectory:
                        true
                )

        try! FileManager
            .default
            .createDirectory(
                at:
                    folderURL,
                withIntermediateDirectories:
                    true
            )

        let destinationService =
            ScreenshotDestinationService(
                homeDirectory:
                    folderURL
                        .deletingLastPathComponent(),
                configuredLocationProvider: {
                    folderURL
                        .path
                }
            )

        let folderAccessService =
            ScreenshotFolderAccessService(
                destinationService:
                    destinationService,
                userDefaults:
                    userDefaults,
                bookmarkCreator: {
                    selectedURL in

                    Data(
                        selectedURL
                            .path
                            .utf8
                    )
                },
                bookmarkResolver: {
                    bookmarkData in

                    let path =
                        String(
                            decoding:
                                bookmarkData,
                            as:
                                UTF8.self
                        )

                    return (
                        url:
                            URL(
                                fileURLWithPath:
                                    path,
                                isDirectory:
                                    true
                            ),
                        isStale:
                            false
                    )
                }
            )

        if grantFolderAccess {
            #expect(
                folderAccessService
                    .grantAccess(
                        to:
                            folderURL
                    ) ==
                    .granted
            )
        }

        let preferenceService =
            ScreenshotAutomationPreferenceService(
                userDefaults:
                    userDefaults
            )

        let folderMonitorService =
            ScreenshotFolderMonitorService(
                securityScopeStarter: {
                    _ in

                    true
                },
                securityScopeStopper: {
                    _ in
                }
            )

        let controller =
            ScreenshotAutomationController(
                preferenceService:
                    preferenceService,
                folderAccessService:
                    folderAccessService,
                folderMonitorService:
                    folderMonitorService
            )

        return ControllerFixture(
            suiteName:
                suiteName,
            userDefaults:
                userDefaults,
            folderURL:
                folderURL,
            controller:
                controller
        )
    }

    @MainActor
    private struct ControllerFixture
    {
        let suiteName:
            String

        let userDefaults:
            UserDefaults

        let folderURL:
            URL

        let controller:
            ScreenshotAutomationController

        func cleanup()
        {
            controller
                .stopMonitoring()

            userDefaults
                .removePersistentDomain(
                    forName:
                        suiteName
                )

            try? FileManager
                .default
                .removeItem(
                    at:
                        folderURL
                )
        }
    }
}
