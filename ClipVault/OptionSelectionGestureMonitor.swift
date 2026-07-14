//
//  OptionSelectionGestureMonitor.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/13/26.
//

import AppKit
import Combine
import Foundation

@MainActor
final class OptionSelectionGestureMonitor: ObservableObject {
    @Published private(set) var isCaptureEnabled: Bool
    @Published private(set) var isMonitoring = false
    @Published private(set) var lastDetectedAt: Date?
    @Published private(set) var lastDetectedAppName: String?
    @Published private(set) var lastRetrievalMessage =
        "No selection captured yet"

    private static let captureEnabledPreferenceKey =
        "optionSelectCaptureEnabled"

    private let userDefaults: UserDefaults
    private var globalEventMonitor: Any?

    private var optionWasHeldAtMouseDown = false
    private var didDragWhileSelecting = false
    private var sourceAppNameAtMouseDown: String?
    private var sourceBundleIdentifierAtMouseDown: String?
    private var sourceAppPathAtMouseDown: String?
    private var sourceProcessIdentifierAtMouseDown: pid_t?
    
    private let transactionService =
        SelectionClipboardTransactionService()

    private weak var clipboardStore: ClipboardStore?

    init(
        userDefaults: UserDefaults = .standard
    ) {
        self.userDefaults = userDefaults

        isCaptureEnabled =
            userDefaults.bool(
                forKey:
                    Self.captureEnabledPreferenceKey
            )
    }

    deinit {
        if let globalEventMonitor {
            NSEvent.removeMonitor(
                globalEventMonitor
            )
        }
    }

    func configure(
        clipboardStore: ClipboardStore
    ) {
        self.clipboardStore =
            clipboardStore
    }

    func applySavedCapturePreference() {
        if isCaptureEnabled {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    func setCaptureEnabled(
        _ isEnabled: Bool
    ) {
        guard isCaptureEnabled != isEnabled else {
            return
        }

        isCaptureEnabled = isEnabled

        userDefaults.set(
            isEnabled,
            forKey:
                Self.captureEnabledPreferenceKey
        )

        if isEnabled {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    func startMonitoring() {
        guard isCaptureEnabled else {
            return
        }

        guard globalEventMonitor == nil else {
            return
        }

        globalEventMonitor =
            NSEvent.addGlobalMonitorForEvents(
                matching: [
                    .leftMouseDown,
                    .leftMouseDragged,
                    .leftMouseUp
                ]
            ) { [weak self] event in
                let eventKind: MonitoredEventKind

                switch event.type {
                case .leftMouseDown:
                    eventKind = .leftMouseDown

                case .leftMouseDragged:
                    eventKind = .leftMouseDragged

                case .leftMouseUp:
                    eventKind = .leftMouseUp

                default:
                    return
                }

                let optionIsPressed =
                    event.modifierFlags
                        .contains(.option)

                Task { @MainActor [weak self] in
                    self?.handle(
                        eventKind,
                        optionIsPressed:
                            optionIsPressed
                    )
                }
            }

        isMonitoring =
            globalEventMonitor != nil
    }

    func stopMonitoring() {
        guard let globalEventMonitor else {
            return
        }

        NSEvent.removeMonitor(
            globalEventMonitor
        )

        self.globalEventMonitor = nil

        resetCurrentGesture()
        isMonitoring = false
    }

    private func handle(
        _ eventKind: MonitoredEventKind,
        optionIsPressed: Bool
    ) {
        switch eventKind {
        case .leftMouseDown:
            optionWasHeldAtMouseDown =
                optionIsPressed

            didDragWhileSelecting = false

            let frontmostApplication =
                NSWorkspace.shared
                    .frontmostApplication

            sourceAppNameAtMouseDown =
                frontmostApplication?
                    .localizedName

            sourceBundleIdentifierAtMouseDown =
                frontmostApplication?
                    .bundleIdentifier

            sourceAppPathAtMouseDown =
                frontmostApplication?
                    .bundleURL?
                    .path

            sourceProcessIdentifierAtMouseDown =
                frontmostApplication?
                    .processIdentifier

        case .leftMouseDragged:
            guard optionWasHeldAtMouseDown else {
                return
            }

            didDragWhileSelecting = true

        case .leftMouseUp:
            let detectedAppName =
                sourceAppNameAtMouseDown

            let detectedBundleIdentifier =
                sourceBundleIdentifierAtMouseDown

            let detectedAppPath =
                sourceAppPathAtMouseDown

            let detectedProcessIdentifier =
                sourceProcessIdentifierAtMouseDown

            defer {
                resetCurrentGesture()
            }

            guard
                optionWasHeldAtMouseDown,
                didDragWhileSelecting
            else {
                return
            }

            lastDetectedAt = Date()
            lastDetectedAppName =
                detectedAppName

            lastRetrievalMessage =
                "Running clipboard transaction…"

            guard
                let detectedProcessIdentifier
            else {
                lastRetrievalMessage =
                    "The source application could not be identified."

                return
            }

            captureSelectedTextAfterSelectionSettles(
                processIdentifier:
                    detectedProcessIdentifier,
                sourceAppName:
                    detectedAppName,
                sourceBundleIdentifier:
                    detectedBundleIdentifier,
                sourceAppPath:
                    detectedAppPath
            )
        }
    }

    private func captureSelectedTextAfterSelectionSettles(
        processIdentifier: pid_t,
        sourceAppName: String?,
        sourceBundleIdentifier: String?,
        sourceAppPath: String?
    ) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(
                for: .milliseconds(250)
            )

            guard
                let self,
                let clipboardStore
            else {
                self?.lastRetrievalMessage =
                    "Clipboard monitoring could not be accessed."

                return
            }

            let result =
                await transactionService
                    .captureSelectedText(
                        from: processIdentifier,
                        beginIgnoringClipboardChanges: {
                            clipboardStore
                                .beginIgnoringClipboardMonitoringChanges()
                        },
                        endIgnoringClipboardChanges: {
                            clipboardStore
                                .endIgnoringClipboardMonitoringChanges()
                        },
                        processSelectedText: {
                            selectedText in

                            clipboardStore.captureSelectedText(
                                selectedText,
                                sourceAppName: sourceAppName,
                                sourceBundleIdentifier:
                                    sourceBundleIdentifier,
                                sourceAppPath: sourceAppPath
                            )
                        }
                    )

            applyTransactionResult(result)
        }
    }

    private func applyTransactionResult(
        _ result: SelectionClipboardTransactionResult
    ) {
        switch result {
        case let .processed(captureOutcome):
            applyCaptureOutcome(
                captureOutcome
            )

        case .accessibilityNotGranted:
            lastRetrievalMessage =
                "Accessibility access is not granted."

        case .sourceApplicationUnavailable:
            lastRetrievalMessage =
                "The source application could not be identified."

        case .transactionAlreadyRunning:
            lastRetrievalMessage =
                "Another selection transaction is already running."

        case .copyEventCouldNotBeCreated:
            lastRetrievalMessage =
                "The Command–C event could not be created."

        case .clipboardDidNotChange:
            lastRetrievalMessage =
                "The source application did not update the clipboard."

        case .noTextCopied:
            lastRetrievalMessage =
                "The source application copied no readable text."

        case .clipboardRestoreFailed:
            lastRetrievalMessage =
                "The original clipboard could not be restored."
        }
    }
    
    private func applyCaptureOutcome(
        _ outcome: ClipboardCaptureOutcome
    ) {
        switch outcome {
        case .captured:
            lastRetrievalMessage =
                "Selected text was added to ClipVault and is ready to paste."

        case .skippedMonitoringPaused:
            lastRetrievalMessage =
                "Selection was ignored because clipboard monitoring is paused."

        case .skippedEmpty:
            lastRetrievalMessage =
                "The copied selection contained no readable text."

        case .skippedBlocked:
            lastRetrievalMessage =
                "Selection was ignored because the source application is blocked."

        case .skippedSensitive:
            lastRetrievalMessage =
                "Selection was ignored because it appears to contain sensitive information."
        }
    }

    private func resetCurrentGesture() {
        optionWasHeldAtMouseDown = false
        didDragWhileSelecting = false

        sourceAppNameAtMouseDown = nil
        sourceBundleIdentifierAtMouseDown = nil
        sourceAppPathAtMouseDown = nil

        sourceProcessIdentifierAtMouseDown =
            nil
    }
}

private enum MonitoredEventKind: Sendable {
    case leftMouseDown
    case leftMouseDragged
    case leftMouseUp
}
