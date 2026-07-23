//
//  ScreenshotAutomationController.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/23/26.
//

import Combine
import Foundation

enum ScreenshotAutomationActivationResult:
    Equatable
{
    case enabled

    case disabled

    case accessRequired

    case unsupportedDestination(
        String
    )

    case clipboardDestination

    case monitorStartFailed(
        ScreenshotFolderMonitorStartResult
    )
}

@MainActor
final class ScreenshotAutomationController:
    ObservableObject
{
    @Published
    private(set)
    var isMonitoring:
        Bool =
            false

    private let preferenceService:
        ScreenshotAutomationPreferenceService

    private let folderAccessService:
        ScreenshotFolderAccessService

    private let folderMonitorService:
        ScreenshotFolderMonitorService
    
    private let processingService:
        ScreenshotProcessingService

    init(
        preferenceService:
            ScreenshotAutomationPreferenceService,
        folderAccessService:
            ScreenshotFolderAccessService,
        folderMonitorService:
            ScreenshotFolderMonitorService,
        processingService:
            ScreenshotProcessingService? =
                nil
    ) {
        self.preferenceService =
            preferenceService

        self.folderAccessService =
            folderAccessService

        self.folderMonitorService =
            folderMonitorService
        
        self.processingService =
            processingService ??
            ScreenshotProcessingService()

        isMonitoring =
            folderMonitorService
                .isMonitoring
    }

    var isEnabled:
        Bool
    {
        preferenceService
            .automaticallyCopiesNewScreenshots
    }

    func applySavedPreference()
        -> ScreenshotAutomationActivationResult
    {
        guard
            preferenceService
                .automaticallyCopiesNewScreenshots
        else {
            stopMonitoring()

            return .disabled
        }

        return startMonitoring()
    }

    func setEnabled(
        _ isEnabled:
            Bool
    ) -> ScreenshotAutomationActivationResult {
        guard
            isEnabled
        else {
            preferenceService
                .setAutomaticallyCopiesNewScreenshots(
                    false
                )

            stopMonitoring()

            return .disabled
        }

        let result =
            startMonitoring()

        guard
            result ==
                .enabled
        else {
            preferenceService
                .setAutomaticallyCopiesNewScreenshots(
                    false
                )

            return result
        }

        preferenceService
            .setAutomaticallyCopiesNewScreenshots(
                true
            )

        return .enabled
    }

    func refreshAfterFolderAccessChange()
        -> ScreenshotAutomationActivationResult
    {
        stopMonitoring()

        guard
            preferenceService
                .automaticallyCopiesNewScreenshots
        else {
            return .disabled
        }

        let result =
            startMonitoring()

        if result !=
            .enabled
        {
            preferenceService
                .setAutomaticallyCopiesNewScreenshots(
                    false
                )
        }

        return result
    }

    func stopMonitoring()
    {
        folderMonitorService
            .stopMonitoring()

        processingService
            .stopMonitoring()

        isMonitoring =
            false
    }

    private func startMonitoring()
        -> ScreenshotAutomationActivationResult
    {
        folderAccessService
            .refreshDestination()

        switch folderAccessService
            .destination
        {
        case .clipboard:
            stopMonitoring()

            return .clipboardDestination

        case let .unsupportedDestination(
            destinationName
        ):
            stopMonitoring()

            return .unsupportedDestination(
                destinationName
            )

        case .folder:
            break
        }

        guard
            folderAccessService
                .hasAccessToCurrentDestination,
            let grantedFolderURL =
                folderAccessService
                    .resolvedGrantedFolderURL()
        else {
            stopMonitoring()

            return .accessRequired
        }

        processingService
            .beginMonitoring(
                folderURL:
                    grantedFolderURL
            )

        let startResult =
            folderMonitorService
                .startMonitoring(
                    folderURL:
                        grantedFolderURL,
                    onFolderChanged: {
                        [weak self]
                        in

                        guard
                            let self
                        else {
                            return
                        }

                        Task {
                            @MainActor
                            [weak self]
                            in

                            guard
                                let self
                            else {
                                return
                            }

                            await self
                                .processingService
                                .processFolderChange()
                        }
                    }
                )

        switch startResult {
        case .started,
             .alreadyMonitoring:
            isMonitoring =
                true

            return .enabled

        case .securityScopedAccessFailed,
             .folderOpenFailed:
            processingService
                .stopMonitoring()

            isMonitoring =
                false

            return .monitorStartFailed(
                startResult
            )
        }
    }
}
