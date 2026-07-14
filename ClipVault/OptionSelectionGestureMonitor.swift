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
    @Published private(set) var isMonitoring = false
    @Published private(set) var lastDetectedAt: Date?
    @Published private(set) var lastDetectedAppName: String?
    @Published private(set) var lastSelectedText: String?
    @Published private(set) var lastRetrievalMessage =
        "No selection captured yet"

    private var globalEventMonitor: Any?

    private var optionWasHeldAtMouseDown = false
    private var didDragWhileSelecting = false
    private var sourceAppNameAtMouseDown: String?
    private var sourceProcessIdentifierAtMouseDown: pid_t?

    private let transactionService =
        SelectionClipboardTransactionService()

    private weak var clipboardStore: ClipboardStore?

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

    func startMonitoring() {
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

            lastSelectedText = nil
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
                    detectedProcessIdentifier
            )
        }
    }

    private func captureSelectedTextAfterSelectionSettles(
        processIdentifier: pid_t
    ) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(
                for: .milliseconds(250)
            )

            guard
                let self,
                let clipboardStore
            else {
                self?.lastSelectedText = nil
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
                        }
                    )

            applyTransactionResult(
                result
            )
        }
    }

    private func applyTransactionResult(
        _ result:
            SelectionClipboardTransactionResult
    ) {
        switch result {
        case .selectedText:
            lastSelectedText = nil
            lastRetrievalMessage =
                "Selected text copied and the original clipboard was restored."

        case .accessibilityNotGranted:
            lastSelectedText = nil
            lastRetrievalMessage =
                "Accessibility access is not granted."

        case .sourceApplicationUnavailable:
            lastSelectedText = nil
            lastRetrievalMessage =
                "The source application could not be identified."

        case .transactionAlreadyRunning:
            lastSelectedText = nil
            lastRetrievalMessage =
                "Another selection transaction is already running."

        case .copyEventCouldNotBeCreated:
            lastSelectedText = nil
            lastRetrievalMessage =
                "The Command–C event could not be created."

        case .clipboardDidNotChange:
            lastSelectedText = nil
            lastRetrievalMessage =
                "The source application did not update the clipboard."

        case .noTextCopied:
            lastSelectedText = nil
            lastRetrievalMessage =
                "The source application copied no readable text."

        case .clipboardRestoreFailed:
            lastSelectedText = nil
            lastRetrievalMessage =
                "The original clipboard could not be restored."
        }
    }

    private func resetCurrentGesture() {
        optionWasHeldAtMouseDown = false
        didDragWhileSelecting = false

        sourceAppNameAtMouseDown = nil

        sourceProcessIdentifierAtMouseDown =
            nil
    }
}

private enum MonitoredEventKind: Sendable {
    case leftMouseDown
    case leftMouseDragged
    case leftMouseUp
}
