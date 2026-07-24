//
//  AutomatedScreenshotCapturePolicyService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/23/26.
//

import Foundation

@MainActor
final class AutomatedScreenshotCapturePolicyService
{
    static let itemTitle =
        "Screenshot Created"

    static let sourceAppName =
        "macOS Screenshot"

    private var imageDataInProgress:
        Set<Data> =
            []

    func beginCapture(
        imageData:
            Data,
        isMonitoringPaused:
            Bool
    ) -> Bool {
        guard
            !isMonitoringPaused,
            !imageData.isEmpty,
            !imageDataInProgress
                .contains(
                    imageData
                )
        else {
            return false
        }

        imageDataInProgress
            .insert(
                imageData
            )

        return true
    }

    func finishCapture(
        imageData:
            Data
    ) {
        imageDataInProgress
            .remove(
                imageData
            )
    }

    func isCaptureInProgress(
        imageData:
            Data
    ) -> Bool {
        imageDataInProgress
            .contains(
                imageData
            )
    }
}
