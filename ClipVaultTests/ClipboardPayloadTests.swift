//
//  ClipboardPayloadTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/16/26.
//

import AppKit
import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ClipboardPayloadTests {
    @Test
    func textPayloadProvidesTextClassificationAndSearchText() {
        let payload =
            ClipboardPayload.text(
                ClipboardTextPayload(
                    text: "Ordinary clipboard text"
                )
            )

        #expect(payload.contentKind == .text)

        #expect(
            payload.searchableText ==
                "Ordinary clipboard text"
        )
        
        #expect(
            payload.displayText ==
                "Ordinary clipboard text"
        )

        #expect(payload.linkURL == nil)

        #expect(
            payload.duplicateKey ==
                "Ordinary clipboard text"
        )
    }

    @Test
    func duplicateKeyTrimsOnlySurroundingWhitespace() {
        let payload =
            ClipboardPayload.text(
                ClipboardTextPayload(
                    text:
                        "  Multi word clipboard text \n"
                )
            )

        #expect(
            payload.duplicateKey ==
                "Multi word clipboard text"
        )
    }
    
    @Test
    func linkPayloadProvidesLinkClassificationAndSearchText() {
        let payload =
            ClipboardPayload.link(
                ClipboardLinkPayload(
                    urlString:
                        "https://example.com/path"
                )
            )

        #expect(payload.contentKind == .link)

        #expect(
            payload.searchableText ==
                "https://example.com/path"
        )
        
        #expect(
            payload.displayText ==
                "https://example.com/path"
        )

        #expect(
            payload.linkURL ==
                URL(
                    string:
                        "https://example.com/path"
                )
        )

        #expect(
            payload.compatibilityText ==
                "https://example.com/path"
        )
    }

    @Test
    func inferenceCreatesLinkPayloadForValidURL() {
        let payload =
            ClipboardPayload.inferred(
                from: "https://example.com",
                itemKind: .normal
            )

        #expect(
            payload ==
                .link(
                    ClipboardLinkPayload(
                        urlString:
                            "https://example.com"
                    )
                )
        )
    }

    @Test
    func inferenceCreatesTextPayloadForOrdinaryText() {
        let payload =
            ClipboardPayload.inferred(
                from: "Ordinary clipboard text",
                itemKind: .normal
            )

        #expect(
            payload ==
                .text(
                    ClipboardTextPayload(
                        text:
                            "Ordinary clipboard text"
                    )
                )
        )
    }

    @Test
    func warningInferenceAlwaysCreatesTextPayload() {
        let warningText =
            "https://example.com"

        let payload =
            ClipboardPayload.inferred(
                from: warningText,
                itemKind: .sensitiveSkipped
            )

        #expect(
            payload ==
                .text(
                    ClipboardTextPayload(
                        text: warningText
                    )
                )
        )

        #expect(payload.contentKind == .text)
    }
    
    @Test
    func textPayloadWritesTextToPasteboard() {
        let pasteboard =
            makePasteboard()

        let payload =
            ClipboardPayload.text(
                ClipboardTextPayload(
                    text:
                        "Text pasteboard value"
                )
            )

        let didWrite =
            payload.write(
                to: pasteboard
            )

        #expect(didWrite)

        #expect(
            pasteboard.string(
                forType: .string
            ) ==
                "Text pasteboard value"
        )
    }

    @Test
    func linkPayloadWritesURLStringToPasteboard() {
        let pasteboard =
            makePasteboard()

        let payload =
            ClipboardPayload.link(
                ClipboardLinkPayload(
                    urlString:
                        "https://example.com/copied"
                )
            )

        let didWrite =
            payload.write(
                to: pasteboard
            )

        #expect(didWrite)

        #expect(
            pasteboard.string(
                forType: .string
            ) ==
                "https://example.com/copied"
        )
    }

    @Test
    func payloadRoundTripPreservesAssociatedValue() throws {
        let originalPayload =
            ClipboardPayload.link(
                ClipboardLinkPayload(
                    urlString:
                        "https://example.com/products"
                )
            )

        let encodedData =
            try JSONEncoder().encode(
                originalPayload
            )

        let decodedPayload =
            try JSONDecoder().decode(
                ClipboardPayload.self,
                from: encodedData
            )

        #expect(
            decodedPayload ==
                originalPayload
        )
    }
    private func makePasteboard() -> NSPasteboard {
        NSPasteboard(
            name:
                NSPasteboard.Name(
                    "ClipboardPayloadTests-\(UUID().uuidString)"
                )
        )
    }
}
