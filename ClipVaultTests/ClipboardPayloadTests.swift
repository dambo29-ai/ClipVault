//
//  ClipboardPayloadTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/16/26.
//

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
            payload.compatibilityText ==
                "Ordinary clipboard text"
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
}
