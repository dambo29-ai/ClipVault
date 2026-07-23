//
//  ScreenshotAutomationPreferenceServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/24/26.
//

import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ScreenshotAutomationPreferenceServiceTests
{
    @Test
    func defaultsToDisabled()
    {
        let fixture =
            makeFixture()

        defer {
            removeFixture(
                fixture
            )
        }

        let service =
            ScreenshotAutomationPreferenceService(
                userDefaults:
                    fixture
                        .userDefaults
            )

        #expect(
            !service
                .automaticallyCopiesNewScreenshots
        )
    }

    @Test
    func enablingPreferencePersists()
    {
        let fixture =
            makeFixture()

        defer {
            removeFixture(
                fixture
            )
        }

        let service =
            ScreenshotAutomationPreferenceService(
                userDefaults:
                    fixture
                        .userDefaults
            )

        service
            .setAutomaticallyCopiesNewScreenshots(
                true
            )

        #expect(
            service
                .automaticallyCopiesNewScreenshots
        )

        let restoredService =
            ScreenshotAutomationPreferenceService(
                userDefaults:
                    fixture
                        .userDefaults
            )

        #expect(
            restoredService
                .automaticallyCopiesNewScreenshots
        )
    }

    @Test
    func disablingPreferencePersists()
    {
        let fixture =
            makeFixture()

        defer {
            removeFixture(
                fixture
            )
        }

        fixture
            .userDefaults
            .set(
                true,
                forKey:
                    ScreenshotAutomationPreferenceService
                        .defaultsKey
            )

        let service =
            ScreenshotAutomationPreferenceService(
                userDefaults:
                    fixture
                        .userDefaults
            )

        #expect(
            service
                .automaticallyCopiesNewScreenshots
        )

        service
            .setAutomaticallyCopiesNewScreenshots(
                false
            )

        #expect(
            !service
                .automaticallyCopiesNewScreenshots
        )

        let restoredService =
            ScreenshotAutomationPreferenceService(
                userDefaults:
                    fixture
                        .userDefaults
            )

        #expect(
            !restoredService
                .automaticallyCopiesNewScreenshots
        )
    }

    private func makeFixture()
        -> PreferenceFixture
    {
        let suiteName =
            "ScreenshotAutomationPreferenceServiceTests-" +
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

        return PreferenceFixture(
            suiteName:
                suiteName,
            userDefaults:
                userDefaults
        )
    }

    private func removeFixture(
        _ fixture:
            PreferenceFixture
    ) {
        fixture
            .userDefaults
            .removePersistentDomain(
                forName:
                    fixture
                        .suiteName
            )
    }

    private struct PreferenceFixture
    {
        let suiteName:
            String

        let userDefaults:
            UserDefaults
    }
}
