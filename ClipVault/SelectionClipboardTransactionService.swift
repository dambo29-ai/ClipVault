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
    typealias AccessibilityCheck = () -> Bool
    typealias CopyCommandPoster = @MainActor (
        pid_t
    ) -> Bool
    typealias ClipboardChangeWaiter = (
        NSPasteboard,
        Int
    ) async -> Bool
    typealias SnapshotCapturer = @MainActor (
        NSPasteboard
    ) -> ClipboardSnapshot
    typealias SnapshotRestorer = @MainActor (
        ClipboardSnapshot,
        NSPasteboard
    ) -> Bool

    private let pasteboard: NSPasteboard
    private let isAccessibilityGranted: AccessibilityCheck
    private let postCopyCommand: CopyCommandPoster
    private let waitForClipboardChange: ClipboardChangeWaiter
    private let captureSnapshot: SnapshotCapturer
    private let restoreSnapshot: SnapshotRestorer

    private var isRunning = false

    init(
        pasteboard: NSPasteboard = .general,
        isAccessibilityGranted: @escaping AccessibilityCheck = {
            AXIsProcessTrusted()
        },
        postCopyCommand: @escaping CopyCommandPoster = { @MainActor
            processIdentifier in

            SelectionClipboardTransactionService.postProductionCommandC(
                to: processIdentifier
            )
        },
        waitForClipboardChange: @escaping ClipboardChangeWaiter = {
            pasteboard,
            originalChangeCount in

            await SelectionClipboardTransactionService.waitForProductionClipboardChange(
                on: pasteboard,
                after: originalChangeCount
            )
        },
        captureSnapshot: @escaping SnapshotCapturer = { @MainActor
            pasteboard in

            ClipboardSnapshotService.capture(
                from: pasteboard
            )
        },
        restoreSnapshot: @escaping SnapshotRestorer = { @MainActor
            snapshot,
            pasteboard in

            ClipboardSnapshotService.restore(
                snapshot,
                to: pasteboard
            )
        }
    ) {
        self.pasteboard = pasteboard
        self.isAccessibilityGranted =
            isAccessibilityGranted
        self.postCopyCommand =
            postCopyCommand
        self.waitForClipboardChange =
            waitForClipboardChange
        self.captureSnapshot =
            captureSnapshot
        self.restoreSnapshot =
            restoreSnapshot
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

        guard isAccessibilityGranted() else {
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
            captureSnapshot(pasteboard)

        let changeCountBeforeCopy =
            pasteboard.changeCount

        guard postCopyCommand(
            processIdentifier
        ) else {
            let restorationSucceeded =
                restoreSnapshot(
                    originalSnapshot,
                    pasteboard
                )

            return restorationSucceeded
                ? .copyEventCouldNotBeCreated
                : .clipboardRestoreFailed
        }

        let clipboardChanged =
            await waitForClipboardChange(
                pasteboard,
                changeCountBeforeCopy
            )

        guard clipboardChanged else {
            let restorationSucceeded =
                restoreSnapshot(
                    originalSnapshot,
                    pasteboard
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
                restoreSnapshot(
                    originalSnapshot,
                    pasteboard
                )

            return restorationSucceeded
                ? .noTextCopied
                : .clipboardRestoreFailed
        }

        let captureOutcome =
            processSelectedText(copiedText)

        guard captureOutcome == .captured else {
            let restorationSucceeded =
                restoreSnapshot(
                    originalSnapshot,
                    pasteboard
                )

            return restorationSucceeded
                ? .processed(captureOutcome)
                : .clipboardRestoreFailed
        }

        return .processed(captureOutcome)
    }

    private static func postProductionCommandC(
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

    private static func waitForProductionClipboardChange(
        on pasteboard: NSPasteboard,
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
