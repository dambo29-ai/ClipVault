//
//  ScreenshotAutomationPreferenceService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/24/26.
//

import Combine
import Foundation

@MainActor
final class ScreenshotAutomationPreferenceService:
    ObservableObject
{
    static let defaultsKey =
        "automaticallyCopiesNewScreenshots"

    @Published
    private(set)
    var automaticallyCopiesNewScreenshots:
        Bool

    private let userDefaults:
        UserDefaults

    init(
        userDefaults:
            UserDefaults =
                .standard
    ) {
        self.userDefaults =
            userDefaults

        automaticallyCopiesNewScreenshots =
            userDefaults
                .bool(
                    forKey:
                        Self
                            .defaultsKey
                )
    }

    func setAutomaticallyCopiesNewScreenshots(
        _ isEnabled:
            Bool
    ) {
        automaticallyCopiesNewScreenshots =
            isEnabled

        userDefaults
            .set(
                isEnabled,
                forKey:
                    Self
                        .defaultsKey
            )
    }
}
