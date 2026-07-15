//
//  SelectionClipboardTransactionServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/14/26.
//

import AppKit
import Testing
@testable import ClipVault

@MainActor
struct SelectionClipboardTransactionServiceTests {
    @Test
    func acceptedCaptureKeepsNewlyCopiedTextActive() async {
        let pasteboard = makePasteboard()

        pasteboard.clearContents()
        pasteboard.setString(
            "Original clipboard text",
            forType: .string
        )

        var beginIgnoringCallCount = 0
        var endIgnoringCallCount = 0

        let service =
            makeService(
                pasteboard: pasteboard,
                copiedText: "Selected text"
            )

        let result =
            await service.captureSelectedText(
                from: 123,
                beginIgnoringClipboardChanges: {
                    beginIgnoringCallCount += 1
                },
                endIgnoringClipboardChanges: {
                    endIgnoringCallCount += 1
                },
                processSelectedText: {
                    copiedText in

                    #expect(copiedText == "Selected text")
                    return .captured
                }
            )

        guard case .processed(.captured) = result else {
            Issue.record(
                "Expected a processed captured result."
            )
            return
        }

        #expect(
            pasteboard.string(forType: .string) ==
                "Selected text"
        )

        #expect(beginIgnoringCallCount == 1)
        #expect(endIgnoringCallCount == 1)
    }

    @Test
    func blockedCaptureRestoresPreviousClipboard() async {
        let pasteboard = makePasteboard()

        pasteboard.clearContents()
        pasteboard.setString(
            "Original clipboard text",
            forType: .string
        )

        let service =
            makeService(
                pasteboard: pasteboard,
                copiedText: "Blocked selected text"
            )

        let result =
            await service.captureSelectedText(
                from: 123,
                beginIgnoringClipboardChanges: {},
                endIgnoringClipboardChanges: {},
                processSelectedText: {
                    _ in

                    .skippedBlocked
                }
            )

        guard case .processed(.skippedBlocked) = result else {
            Issue.record(
                "Expected a processed skippedBlocked result."
            )
            return
        }

        #expect(
            pasteboard.string(forType: .string) ==
                "Original clipboard text"
        )
    }

    @Test
    func sensitiveCaptureRestoresPreviousClipboard() async {
        let pasteboard = makePasteboard()

        pasteboard.clearContents()
        pasteboard.setString(
            "Original clipboard text",
            forType: .string
        )

        let service =
            makeService(
                pasteboard: pasteboard,
                copiedText: "Sensitive selected text"
            )

        let result =
            await service.captureSelectedText(
                from: 123,
                beginIgnoringClipboardChanges: {},
                endIgnoringClipboardChanges: {},
                processSelectedText: {
                    _ in

                    .skippedSensitive
                }
            )

        guard case .processed(.skippedSensitive) = result else {
            Issue.record(
                "Expected a processed skippedSensitive result."
            )
            return
        }

        #expect(
            pasteboard.string(forType: .string) ==
                "Original clipboard text"
        )
    }

    @Test
    func pausedCaptureRestoresPreviousClipboard() async {
        let pasteboard = makePasteboard()

        pasteboard.clearContents()
        pasteboard.setString(
            "Original clipboard text",
            forType: .string
        )

        let service =
            makeService(
                pasteboard: pasteboard,
                copiedText: "Selected while paused"
            )

        let result =
            await service.captureSelectedText(
                from: 123,
                beginIgnoringClipboardChanges: {},
                endIgnoringClipboardChanges: {},
                processSelectedText: {
                    _ in

                    .skippedMonitoringPaused
                }
            )

        guard
            case .processed(
                .skippedMonitoringPaused
            ) = result
        else {
            Issue.record(
                """
                Expected a processed \
                skippedMonitoringPaused result.
                """
            )
            return
        }

        #expect(
            pasteboard.string(forType: .string) ==
                "Original clipboard text"
        )
    }

    @Test
    func monitoringSuppressionIsBalancedExactlyOnce() async {
        let pasteboard = makePasteboard()

        pasteboard.clearContents()
        pasteboard.setString(
            "Original clipboard text",
            forType: .string
        )

        var beginIgnoringCallCount = 0
        var endIgnoringCallCount = 0

        let service =
            makeService(
                pasteboard: pasteboard,
                copiedText: "Selected text"
            )

        _ =
            await service.captureSelectedText(
                from: 123,
                beginIgnoringClipboardChanges: {
                    beginIgnoringCallCount += 1
                },
                endIgnoringClipboardChanges: {
                    endIgnoringCallCount += 1
                },
                processSelectedText: {
                    _ in

                    .skippedBlocked
                }
            )

        #expect(beginIgnoringCallCount == 1)
        #expect(endIgnoringCallCount == 1)
    }

    private func makeService(
        pasteboard: NSPasteboard,
        copiedText: String
    ) -> SelectionClipboardTransactionService {
        SelectionClipboardTransactionService(
            pasteboard: pasteboard,
            isAccessibilityGranted: {
                true
            },
            postCopyCommand: { @MainActor
                _ in

                pasteboard.clearContents()

                return pasteboard.setString(
                    copiedText,
                    forType: .string
                )
            },
            waitForClipboardChange: {
                _,
                _ in

                true
            }
        )
    }

    private func makePasteboard() -> NSPasteboard {
        NSPasteboard(
            name: NSPasteboard.Name(
                """
                SelectionClipboardTransactionServiceTests-\
                \(UUID().uuidString)
                """
            )
        )
    }
}
