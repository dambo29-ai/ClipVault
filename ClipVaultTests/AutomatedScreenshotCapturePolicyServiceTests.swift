//
//  AutomatedScreenshotCapturePolicyServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/23/26.
//

import Foundation
import Testing
@testable import ClipVault

@MainActor
struct AutomatedScreenshotCapturePolicyServiceTests
{
    @Test
    func usesExpectedScreenshotMetadata()
    {
        #expect(
            AutomatedScreenshotCapturePolicyService
                .itemTitle ==
                "Screenshot Created"
        )

        #expect(
            AutomatedScreenshotCapturePolicyService
                .sourceAppName ==
                "macOS Screenshot"
        )
    }

    @Test
    func beginsCaptureWhenMonitoringIsActive()
    {
        let service =
            AutomatedScreenshotCapturePolicyService()

        let imageData =
            Data(
                [1, 2, 3, 4]
            )

        #expect(
            service
                .beginCapture(
                    imageData:
                        imageData,
                    isMonitoringPaused:
                        false
                )
        )

        #expect(
            service
                .isCaptureInProgress(
                    imageData:
                        imageData
                )
        )
    }

    @Test
    func rejectsCaptureWhileMonitoringIsPaused()
    {
        let service =
            AutomatedScreenshotCapturePolicyService()

        let imageData =
            Data(
                [5, 6, 7, 8]
            )

        #expect(
            !service
                .beginCapture(
                    imageData:
                        imageData,
                    isMonitoringPaused:
                        true
                )
        )

        #expect(
            !service
                .isCaptureInProgress(
                    imageData:
                        imageData
                )
        )
    }

    @Test
    func rejectsDuplicateCallbackWhileCaptureIsInProgress()
    {
        let service =
            AutomatedScreenshotCapturePolicyService()

        let imageData =
            Data(
                [9, 10, 11, 12]
            )

        #expect(
            service
                .beginCapture(
                    imageData:
                        imageData,
                    isMonitoringPaused:
                        false
                )
        )

        #expect(
            !service
                .beginCapture(
                    imageData:
                        imageData,
                    isMonitoringPaused:
                        false
                )
        )
    }

    @Test
    func permitsSameImageAfterPriorCaptureFinishes()
    {
        let service =
            AutomatedScreenshotCapturePolicyService()

        let imageData =
            Data(
                [13, 14, 15, 16]
            )

        #expect(
            service
                .beginCapture(
                    imageData:
                        imageData,
                    isMonitoringPaused:
                        false
                )
        )

        service
            .finishCapture(
                imageData:
                    imageData
            )

        #expect(
            !service
                .isCaptureInProgress(
                    imageData:
                        imageData
                )
        )

        #expect(
            service
                .beginCapture(
                    imageData:
                        imageData,
                    isMonitoringPaused:
                        false
                )
        )
    }
}
