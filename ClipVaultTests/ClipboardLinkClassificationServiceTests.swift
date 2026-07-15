//
//  ClipboardLinkClassificationServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/15/26.
//

import Testing
@testable import ClipVault

struct ClipboardLinkClassificationServiceTests {
    @Test
    func recognizesHTTPSURL() {
        #expect(
            ClipboardLinkClassificationService.isLink(
                "https://www.apple.com"
            )
        )
    }

    @Test
    func recognizesHTTPURL() {
        #expect(
            ClipboardLinkClassificationService.isLink(
                "http://example.com"
            )
        )
    }

    @Test
    func recognizesURLWithPathQueryAndFragment() {
        #expect(
            ClipboardLinkClassificationService.isLink(
                """
                https://example.com/products/item\
                ?name=clipvault#details
                """
            )
        )
    }

    @Test
    func recognizesURLSurroundedByWhitespace() {
        #expect(
            ClipboardLinkClassificationService.isLink(
                "  \nhttps://example.com/path\t "
            )
        )
    }

    @Test
    func recognizesLocalhostURL() {
        #expect(
            ClipboardLinkClassificationService.isLink(
                "http://localhost:8080/settings"
            )
        )
    }

    @Test
    func rejectsEmptyText() {
        #expect(
            !ClipboardLinkClassificationService.isLink("")
        )
    }

    @Test
    func rejectsOrdinaryText() {
        #expect(
            !ClipboardLinkClassificationService.isLink(
                "This is ordinary clipboard text."
            )
        )
    }

    @Test
    func rejectsSentenceContainingURL() {
        #expect(
            !ClipboardLinkClassificationService.isLink(
                """
                Visit https://www.apple.com for details.
                """
            )
        )
    }

    @Test
    func rejectsEmailAddress() {
        #expect(
            !ClipboardLinkClassificationService.isLink(
                "hello@example.com"
            )
        )
    }

    @Test
    func rejectsDomainWithoutScheme() {
        #expect(
            !ClipboardLinkClassificationService.isLink(
                "www.apple.com"
            )
        )
    }

    @Test
    func rejectsFileURL() {
        #expect(
            !ClipboardLinkClassificationService.isLink(
                "file:///Users/example/Desktop/file.txt"
            )
        )
    }

    @Test
    func rejectsMailtoURL() {
        #expect(
            !ClipboardLinkClassificationService.isLink(
                "mailto:hello@example.com"
            )
        )
    }

    @Test
    func rejectsURLContainingUnescapedSpaces() {
        #expect(
            !ClipboardLinkClassificationService.isLink(
                "https://example.com/a path"
            )
        )
    }
}
