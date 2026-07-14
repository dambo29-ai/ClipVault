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
        "No selection read yet"

    private var globalEventMonitor: Any?

    private var optionWasHeldAtMouseDown = false
    private var didDragWhileSelecting = false
    private var sourceAppNameAtMouseDown: String?
    private var sourceProcessIdentifierAtMouseDown: pid_t?

    deinit {
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
        }
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
                    event.modifierFlags.contains(.option)

                Task { @MainActor [weak self] in
                    self?.handle(
                        eventKind,
                        optionIsPressed: optionIsPressed
                    )
                }
            }

        isMonitoring = globalEventMonitor != nil
    }

    func stopMonitoring() {
        guard let globalEventMonitor else {
            return
        }

        NSEvent.removeMonitor(globalEventMonitor)
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
            optionWasHeldAtMouseDown = optionIsPressed
            didDragWhileSelecting = false

            let frontmostApplication =
                NSWorkspace.shared.frontmostApplication

            sourceAppNameAtMouseDown =
                frontmostApplication?.localizedName

            sourceProcessIdentifierAtMouseDown =
                frontmostApplication?.processIdentifier

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

            guard optionWasHeldAtMouseDown,
                  didDragWhileSelecting else {
                return
            }

            lastDetectedAt = Date()
            lastDetectedAppName = detectedAppName
            lastSelectedText = nil
            lastRetrievalMessage =
                "Reading selected text…"

            guard let detectedProcessIdentifier else {
                lastSelectedText = nil
                lastRetrievalMessage =
                    "The source application could not be identified"
                return
            }

            retrieveSelectedTextAfterSelectionSettles(
                processIdentifier: detectedProcessIdentifier
            )
        }
    }

    private func retrieveSelectedTextAfterSelectionSettles(
        processIdentifier: pid_t
    ) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(
                nanoseconds: 250_000_000
            )

            guard let self else {
                return
            }

            let result =
                SelectedTextRetrievalService
                    .retrieveSelectedText(
                        from: processIdentifier
                    )

            applyRetrievalResult(result)
        }
    }

    private func applyRetrievalResult(
        _ result: SelectedTextRetrievalResult
    ) {
        switch result {
        case .selectedText(let text):
            lastSelectedText = text
            lastRetrievalMessage =
                "Selected text read successfully."

        case .accessibilityNotGranted:
            lastSelectedText = nil
            lastRetrievalMessage =
                "Accessibility access is not granted."

        case .applicationUnavailable:
            lastSelectedText = nil
            lastRetrievalMessage =
                "The source application could not be identified."

        case .focusedElementUnavailable:
            lastSelectedText = nil
            lastRetrievalMessage =
                "The focused text element could not be found."

        case .noSelectedText:
            lastSelectedText = nil
            lastRetrievalMessage =
                "No readable selected text was found."

        case .retrievalFailed:
            lastSelectedText = nil
            lastRetrievalMessage =
                "Selected text could not be read."
        }
    }

    private func resetCurrentGesture() {
        optionWasHeldAtMouseDown = false
        didDragWhileSelecting = false
        sourceAppNameAtMouseDown = nil
        sourceProcessIdentifierAtMouseDown = nil
    }
}

private enum MonitoredEventKind: Sendable {
    case leftMouseDown
    case leftMouseDragged
    case leftMouseUp
}
