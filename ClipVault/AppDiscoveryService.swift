//
//  AppDiscoveryService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/11/26.
//

import Foundation
import AppKit

struct DiscoveredApp: Sendable {
    let displayName: String
    let bundleIdentifier: String
    let appPath: String?
}

struct AppDiscoveryService: Sendable {
    nonisolated func discoverInstalledApplications() -> [DiscoveredApp] {
        let fileManager = FileManager.default

        var foldersToScan: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications")
        ]

        if let userApplicationsFolder = fileManager.urls(
            for: .applicationDirectory,
            in: .userDomainMask
        ).first {
            foldersToScan.append(userApplicationsFolder)
        }

        return foldersToScan.flatMap { folderURL in
            discoverApplications(in: folderURL)
        }
    }

    func discoverRunningApplications() -> [DiscoveredApp] {
        NSWorkspace.shared.runningApplications.compactMap { runningApp in
            guard runningApp.activationPolicy == .regular else {
                return nil
            }

            guard let bundleIdentifier = runningApp.bundleIdentifier else {
                return nil
            }

            return DiscoveredApp(
                displayName: runningApp.localizedName ?? bundleIdentifier,
                bundleIdentifier: bundleIdentifier,
                appPath: runningApp.bundleURL?.path
            )
        }
    }

    private nonisolated func discoverApplications(
        in folderURL: URL
    ) -> [DiscoveredApp] {
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var discoveredApps: [DiscoveredApp] = []

        for case let appURL as URL in enumerator {
            guard appURL.pathExtension.lowercased() == "app" else {
                continue
            }

            enumerator.skipDescendants()

            guard let bundle = Bundle(url: appURL),
                  let bundleIdentifier = bundle.bundleIdentifier else {
                continue
            }

            let displayName =
                bundle.object(
                    forInfoDictionaryKey: "CFBundleDisplayName"
                ) as? String ??
                bundle.object(
                    forInfoDictionaryKey: "CFBundleName"
                ) as? String ??
                appURL.deletingPathExtension().lastPathComponent

            discoveredApps.append(
                DiscoveredApp(
                    displayName: displayName,
                    bundleIdentifier: bundleIdentifier,
                    appPath: appURL.path
                )
            )
        }

        return discoveredApps
    }
}
