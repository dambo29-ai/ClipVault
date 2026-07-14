//
//  SelectionClipboardTransactionService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/14/26.
//

import AppKit
import CoreGraphics
import Foundation

enum SelectionClipboardTransactionResult {
    case processed(ClipboardCaptureOutcome)
    case accessibilityNotGranted
    case sourceApplicationUnavailable
    case transactionAlreadyRunning
    case copyEventCouldNotBeCreated
    case clipboardDidNotChange
    case noTextCopied
    case clipboardRestoreFailed
}

@MainActor
final class SelectionClipboardTransactionService {
    private let pasteboard: NSPasteboard
    private var isRunning = false

    init(
        pasteboard: NSPasteboard = .general
    ) {
        self.pasteboard = pasteboard
    }

    func captureSelectedText(
        from processIdentifier: pid_t,
        beginIgnoringClipboardChanges: () -> Void,
        endIgnoringClipboardChanges: () -> Void,
        processSelectedText: (String) -> ClipboardCaptureOutcome
    ) async -> SelectionClipboardTransactionResult {
        guard !isRunning else {
            return .transactionAlreadyRunning
        }

        guard AXIsProcessTrusted() else {
            return .accessibilityNotGranted
        }

        guard processIdentifier > 0 else {
            return .sourceApplicationUnavailable
        }

        isRunning = true
        beginIgnoringClipboardChanges()

        defer {
            endIgnoringClipboardChanges()
            isRunning = false
        }

        let originalSnapshot =
            ClipboardSnapshotService.capture(
                from: pasteboard
            )

        let changeCountBeforeCopy =
            pasteboard.changeCount

        guard postCommandC(
            to: processIdentifier
        ) else {
            let restorationSucceeded =
                ClipboardSnapshotService.restore(
                    originalSnapshot,
                    to: pasteboard
                )

            return restorationSucceeded
                ? .copyEventCouldNotBeCreated
                : .clipboardRestoreFailed
        }

        let clipboardChanged =
            await waitForClipboardChange(
                after: changeCountBeforeCopy
            )

        guard clipboardChanged else {
            let restorationSucceeded =
                ClipboardSnapshotService.restore(
                    originalSnapshot,
                    to: pasteboard
                )

            return restorationSucceeded
                ? .clipboardDidNotChange
                : .clipboardRestoreFailed
        }

        guard
            let copiedText =
                pasteboard.string(
                    forType: .string
                ),
            !copiedText.isEmpty
        else {
            let restorationSucceeded =
                ClipboardSnapshotService.restore(
                    originalSnapshot,
                    to: pasteboard
                )

            return restorationSucceeded
                ? .noTextCopied
                : .clipboardRestoreFailed
        }

        let captureOutcome =
            processSelectedText(copiedText)

        guard captureOutcome == .captured else {
            let restorationSucceeded =
                ClipboardSnapshotService.restore(
                    originalSnapshot,
                    to: pasteboard
                )

            return restorationSucceeded
                ? .processed(captureOutcome)
                : .clipboardRestoreFailed
        }

        return .processed(captureOutcome)
    }

    private func postCommandC(
        to processIdentifier: pid_t
    ) -> Bool {
        let keyboardSource =
            CGEventSource(
                stateID: .hidSystemState
            )

        guard
            let keyDownEvent = CGEvent(
                keyboardEventSource: keyboardSource,
                virtualKey: 8,
                keyDown: true
            ),
            let keyUpEvent = CGEvent(
                keyboardEventSource: keyboardSource,
                virtualKey: 8,
                keyDown: false
            )
        else {
            return false
        }

        keyDownEvent.flags = .maskCommand
        keyUpEvent.flags = .maskCommand

        keyDownEvent.postToPid(
            processIdentifier
        )

        keyUpEvent.postToPid(
            processIdentifier
        )

        return true
    }

    private func waitForClipboardChange(
        after originalChangeCount: Int
    ) async -> Bool {
        let maximumAttempts = 20
        let delayBetweenAttempts =
            Duration.milliseconds(50)

        for _ in 0..<maximumAttempts {
            if pasteboard.changeCount !=
                originalChangeCount {
                return true
            }

            try? await Task.sleep(
                for: delayBetweenAttempts
            )
        }

        return false
    }
}

