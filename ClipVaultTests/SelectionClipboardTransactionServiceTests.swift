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
    
    @Test
    func copyEventFailureRestoresPreviousClipboard() async {
        let pasteboard = makePasteboard()

        pasteboard.clearContents()
        pasteboard.setString(
            "Original clipboard text",
            forType: .string
        )

        let service =
            SelectionClipboardTransactionService(
                pasteboard: pasteboard,
                isAccessibilityGranted: {
                    true
                },
                postCopyCommand: { @MainActor
                    _ in

                    pasteboard.clearContents()
                    pasteboard.setString(
                        "Temporary changed text",
                        forType: .string
                    )

                    return false
                },
                waitForClipboardChange: {
                    _,
                    _ in

                    true
                }
            )

        let result =
            await service.captureSelectedText(
                from: 123,
                beginIgnoringClipboardChanges: {},
                endIgnoringClipboardChanges: {},
                processSelectedText: {
                    _ in

                    Issue.record(
                        """
                        processSelectedText should not run \
                        after copy-event failure.
                        """
                    )

                    return .captured
                }
            )

        guard case .copyEventCouldNotBeCreated = result else {
            Issue.record(
                """
                Expected copyEventCouldNotBeCreated.
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
    func clipboardTimeoutRestoresPreviousClipboard() async {
        let pasteboard = makePasteboard()

        pasteboard.clearContents()
        pasteboard.setString(
            "Original clipboard text",
            forType: .string
        )

        let service =
            SelectionClipboardTransactionService(
                pasteboard: pasteboard,
                isAccessibilityGranted: {
                    true
                },
                postCopyCommand: { @MainActor
                    _ in

                    pasteboard.clearContents()
                    pasteboard.setString(
                        "Temporary selected text",
                        forType: .string
                    )

                    return true
                },
                waitForClipboardChange: {
                    _,
                    _ in

                    false
                }
            )

        let result =
            await service.captureSelectedText(
                from: 123,
                beginIgnoringClipboardChanges: {},
                endIgnoringClipboardChanges: {},
                processSelectedText: {
                    _ in

                    Issue.record(
                        """
                        processSelectedText should not run \
                        after a clipboard timeout.
                        """
                    )

                    return .captured
                }
            )

        guard case .clipboardDidNotChange = result else {
            Issue.record(
                "Expected clipboardDidNotChange."
            )
            return
        }

        #expect(
            pasteboard.string(forType: .string) ==
                "Original clipboard text"
        )
    }

    @Test
    func noReadableTextRestoresPreviousClipboard() async {
        let pasteboard = makePasteboard()

        pasteboard.clearContents()
        pasteboard.setString(
            "Original clipboard text",
            forType: .string
        )

        let nonTextType =
            NSPasteboard.PasteboardType(
                "com.clipvault.tests.non-text"
            )

        let service =
            SelectionClipboardTransactionService(
                pasteboard: pasteboard,
                isAccessibilityGranted: {
                    true
                },
                postCopyCommand: { @MainActor
                    _ in

                    pasteboard.clearContents()

                    return pasteboard.setData(
                        Data([0x01, 0x02, 0x03]),
                        forType: nonTextType
                    )
                },
                waitForClipboardChange: {
                    _,
                    _ in

                    true
                }
            )

        let result =
            await service.captureSelectedText(
                from: 123,
                beginIgnoringClipboardChanges: {},
                endIgnoringClipboardChanges: {},
                processSelectedText: {
                    _ in

                    Issue.record(
                        """
                        processSelectedText should not run \
                        when no readable text was copied.
                        """
                    )

                    return .captured
                }
            )

        guard case .noTextCopied = result else {
            Issue.record(
                "Expected noTextCopied."
            )
            return
        }

        #expect(
            pasteboard.string(forType: .string) ==
                "Original clipboard text"
        )
    }

    @Test
    func restorationFailureReturnsClipboardRestoreFailed() async {
        let pasteboard = makePasteboard()

        pasteboard.clearContents()
        pasteboard.setString(
            "Original clipboard text",
            forType: .string
        )

        var restorationCallCount = 0

        let service =
            SelectionClipboardTransactionService(
                pasteboard: pasteboard,
                isAccessibilityGranted: {
                    true
                },
                postCopyCommand: { @MainActor
                    _ in

                    pasteboard.clearContents()
                    pasteboard.setString(
                        "Temporary changed text",
                        forType: .string
                    )

                    return false
                },
                waitForClipboardChange: {
                    _,
                    _ in

                    true
                },
                restoreSnapshot: { @MainActor
                    _,
                    _ in

                    restorationCallCount += 1
                    return false
                }
            )

        let result =
            await service.captureSelectedText(
                from: 123,
                beginIgnoringClipboardChanges: {},
                endIgnoringClipboardChanges: {},
                processSelectedText: {
                    _ in

                    .captured
                }
            )

        guard case .clipboardRestoreFailed = result else {
            Issue.record(
                "Expected clipboardRestoreFailed."
            )
            return
        }

        #expect(restorationCallCount == 1)
    }

    @Test
    func reentrantTransactionReturnsTransactionAlreadyRunning() async {
        let pasteboard = makePasteboard()

        pasteboard.clearContents()
        pasteboard.setString(
            "Original clipboard text",
            forType: .string
        )

        var copyCommandWasPosted = false

        let service =
            SelectionClipboardTransactionService(
                pasteboard: pasteboard,
                isAccessibilityGranted: {
                    true
                },
                postCopyCommand: { @MainActor
                    _ in

                    copyCommandWasPosted = true

                    pasteboard.clearContents()

                    return pasteboard.setString(
                        "First selected text",
                        forType: .string
                    )
                },
                waitForClipboardChange: {
                    _,
                    _ in

                    try? await Task.sleep(
                        for: .milliseconds(200)
                    )

                    return true
                }
            )

        let firstTransaction =
            Task { @MainActor in
                await service.captureSelectedText(
                    from: 123,
                    beginIgnoringClipboardChanges: {},
                    endIgnoringClipboardChanges: {},
                    processSelectedText: {
                        _ in

                        .captured
                    }
                )
            }

        while !copyCommandWasPosted {
            await Task.yield()
        }

        let secondResult =
            await service.captureSelectedText(
                from: 456,
                beginIgnoringClipboardChanges: {},
                endIgnoringClipboardChanges: {},
                processSelectedText: {
                    _ in

                    .captured
                }
            )

        guard
            case .transactionAlreadyRunning =
                secondResult
        else {
            Issue.record(
                """
                Expected transactionAlreadyRunning \
                for the second transaction.
                """
            )

            _ = await firstTransaction.value
            return
        }

        let firstResult =
            await firstTransaction.value

        guard case .processed(.captured) = firstResult else {
            Issue.record(
                """
                Expected the first transaction \
                to finish as captured.
                """
            )
            return
        }
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
