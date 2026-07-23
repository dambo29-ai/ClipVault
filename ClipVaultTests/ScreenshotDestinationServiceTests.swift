//
//  ScreenshotDestinationServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/23/26.
//

import Foundation
import Testing
@testable import ClipVault

struct ScreenshotDestinationServiceTests
{
    private let testHomeDirectory =
        URL(
            fileURLWithPath:
                "/Users/TestUser",
            isDirectory:
                true
        )

    @Test
    func missingPreferenceDefaultsToDesktop()
    {
        let service =
            makeService(
                configuredLocation:
                    nil
            )

        let result =
            service
                .currentDestination()

        guard
            case let .folder(
                folderURL
            ) =
                result
        else {
            Issue.record(
                "Expected a folder destination."
            )

            return
        }

        #expect(
            folderURL ==
                testHomeDirectory
                    .appendingPathComponent(
                        "Desktop",
                        isDirectory:
                            true
                    )
        )
    }

    @Test
    func expandsTildeBasedFolder()
    {
        let service =
            makeService(
                configuredLocation:
                    "~/Pictures/Screenshots"
            )

        let result =
            service
                .currentDestination()

        guard
            case let .folder(
                folderURL
            ) =
                result
        else {
            Issue.record(
                "Expected a folder destination."
            )

            return
        }

        #expect(
            folderURL ==
                testHomeDirectory
                    .appendingPathComponent(
                        "Pictures/Screenshots",
                        isDirectory:
                            true
                    )
        )
    }

    @Test
    func preservesAbsoluteFolderPath()
    {
        let service =
            makeService(
                configuredLocation:
                    "/Volumes/Media/Screenshots"
            )

        let result =
            service
                .currentDestination()

        guard
            case let .folder(
                folderURL
            ) =
                result
        else {
            Issue.record(
                "Expected a folder destination."
            )

            return
        }

        #expect(
            folderURL ==
                URL(
                    fileURLWithPath:
                        "/Volumes/Media/Screenshots",
                    isDirectory:
                        true
                )
        )
    }

    @Test
    func recognizesClipboardDestination()
    {
        let service =
            makeService(
                configuredLocation:
                    "clipboard"
            )

        let result =
            service
                .currentDestination()

        guard
            case .clipboard =
                result
        else {
            Issue.record(
                "Expected the clipboard destination."
            )

            return
        }
    }

    private func makeService(
        configuredLocation:
            String?
    ) -> ScreenshotDestinationService {
        ScreenshotDestinationService(
            homeDirectory:
                testHomeDirectory,
            configuredLocationProvider: {
                configuredLocation
            }
        )
    }
}
