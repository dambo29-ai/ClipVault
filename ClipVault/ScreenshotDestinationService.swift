//
//  ScreenshotDestinationService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/23/26.
//

import CoreFoundation
import Foundation

enum ScreenshotDestinationResolution:
    Equatable,
    Sendable
{
    case folder(
        URL
    )

    case clipboard

    case unsupportedDestination(
        String
    )
}

struct ScreenshotDestinationService
{
    private let homeDirectory:
        URL

    private let configuredLocationProvider:
        () -> String?

    init(
        homeDirectory:
            URL =
                FileManager
                    .default
                    .homeDirectoryForCurrentUser,
        configuredLocationProvider:
            @escaping () -> String? =
                ScreenshotDestinationService
                    .readConfiguredLocation
    ) {
        self.homeDirectory =
            homeDirectory

        self.configuredLocationProvider =
            configuredLocationProvider
    }

    func currentDestination()
        -> ScreenshotDestinationResolution
    {
        resolveDestination(
            configuredLocation:
                configuredLocationProvider()
        )
    }

    func resolveDestination(
        configuredLocation:
            String?
    ) -> ScreenshotDestinationResolution {
        guard
            let configuredLocation
        else {
            return .folder(
                defaultDesktopURL
            )
        }

        let trimmedLocation =
            configuredLocation
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            !trimmedLocation.isEmpty
        else {
            return .folder(
                defaultDesktopURL
            )
        }

        switch trimmedLocation
            .lowercased()
        {
        case "clipboard":
            return .clipboard

        case "mail",
             "messages",
             "preview":
            return .unsupportedDestination(
                trimmedLocation
            )

        default:
            break
        }

        guard
            let resolvedFolderURL =
                resolvedFolderURL(
                    from:
                        trimmedLocation
                )
        else {
            return .folder(
                defaultDesktopURL
            )
        }

        return .folder(
            resolvedFolderURL
        )
    }

    private var defaultDesktopURL:
        URL
    {
        homeDirectory
            .appendingPathComponent(
                "Desktop",
                isDirectory:
                    true
            )
            .standardizedFileURL
    }

    private func resolvedFolderURL(
        from location:
            String
    ) -> URL? {
        if location ==
            "~"
        {
            return homeDirectory
                .standardizedFileURL
        }

        if location.hasPrefix(
            "~/"
        ) {
            let relativePath =
                String(
                    location
                        .dropFirst(
                            2
                        )
                )

            return homeDirectory
                .appendingPathComponent(
                    relativePath,
                    isDirectory:
                        true
                )
                .standardizedFileURL
        }

        let locationURL =
            URL(
                fileURLWithPath:
                    location,
                isDirectory:
                    true
            )

        guard
            locationURL
                .path
                .hasPrefix(
                    "/"
                )
        else {
            return nil
        }

        return locationURL
            .standardizedFileURL
    }

    nonisolated
    private static func readConfiguredLocation()
        -> String?
    {
        let value =
            CFPreferencesCopyAppValue(
                "location"
                    as CFString,
                "com.apple.screencapture"
                    as CFString
            )

        return value as? String
    }
}
