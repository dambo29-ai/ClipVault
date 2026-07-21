//
//  ClipVaultAppearanceMode.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/20/26.
//

import AppKit
import SwiftUI

enum ClipVaultAppearanceMode:
    String,
    CaseIterable,
    Identifiable
{
    case system
    case light
    case dark

    static let defaultsKey =
        "clipVaultAppearanceMode"

    var id: Self {
        self
    }

    var displayName: String {
        switch self {
        case .system:
            return "System"

        case .light:
            return "Light"

        case .dark:
            return "Dark"
        }
    }

    var description: String {
        switch self {
        case .system:
            return
                "Match the current macOS appearance."

        case .light:
            return
                "Always display ClipVault in Light appearance."

        case .dark:
            return
                "Always display ClipVault in Dark appearance."
        }
    }

    var systemImageName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"

        case .light:
            return "sun.max.fill"

        case .dark:
            return "moon.fill"
        }
    }

    var preferredColorScheme:
        ColorScheme?
    {
        switch self {
        case .system:
            return nil

        case .light:
            return .light

        case .dark:
            return .dark
        }
    }

    var appKitAppearance:
        NSAppearance?
    {
        switch self {
        case .system:
            return nil

        case .light:
            return NSAppearance(
                named:
                    .aqua
            )

        case .dark:
            return NSAppearance(
                named:
                    .darkAqua
            )
        }
    }

    static func resolved(
        from rawValue:
            String
    ) -> ClipVaultAppearanceMode {
        ClipVaultAppearanceMode(
            rawValue:
                rawValue
        ) ?? .system
    }

    @MainActor
    func applyToApplication() {
        let application =
            NSApplication.shared

        application.appearance =
            appKitAppearance

        for window in application.windows {
            window.appearance =
                appKitAppearance

            window.contentView?
                .appearance =
                    appKitAppearance

            window.contentView?
                .needsLayout =
                    true

            window.contentView?
                .needsDisplay =
                    true

            window.contentView?
                .layoutSubtreeIfNeeded()

            window.contentView?
                .displayIfNeeded()

            window.invalidateShadow()
        }
    }
}
