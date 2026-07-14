//
//  ClipboardCapturePolicyServiceTests.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/14/26.
//

import XCTest
@testable import ClipVault

@MainActor
final class ClipboardCapturePolicyServiceTests:
    XCTestCase {
    func testAllowedModeCapturesNormalText() {
        let decision =
            ClipboardCapturePolicyService
                .decision(
                    for:
                        "Ordinary clipboard text",
                    ruleMode: .allowed
                )

        XCTAssertEqual(
            decision,
            .capture
        )
    }

    func testAllowedModeSkipsLikelyPassword() {
        let decision =
            ClipboardCapturePolicyService
                .decision(
                    for:
                        "Q7!mP2#zL9@vR4$x",
                    ruleMode: .allowed
                )

        XCTAssertEqual(
            decision,
            .skipSensitive
        )
    }

    func testAllowedModeDoesNotApplySmartTokenDetection() {
        let decision =
            ClipboardCapturePolicyService
                .decision(
                    for:
                        "ghp_abcdefghijklmnop",
                    ruleMode: .allowed
                )

        XCTAssertEqual(
            decision,
            .capture
        )
    }

    func testSmartModeCapturesNormalText() {
        let decision =
            ClipboardCapturePolicyService
                .decision(
                    for:
                        "Ordinary clipboard text",
                    ruleMode: .smart
                )

        XCTAssertEqual(
            decision,
            .capture
        )
    }

    func testSmartModeAllowsEmailAddress() {
        let decision =
            ClipboardCapturePolicyService
                .decision(
                    for:
                        "person@example.com",
                    ruleMode: .smart
                )

        XCTAssertEqual(
            decision,
            .capture
        )
    }

    func testSmartModeAllowsURL() {
        let decision =
            ClipboardCapturePolicyService
                .decision(
                    for:
                        "https://example.com/account",
                    ruleMode: .smart
                )

        XCTAssertEqual(
            decision,
            .capture
        )
    }

    func testSmartModeSkipsLikelyPassword() {
        let decision =
            ClipboardCapturePolicyService
                .decision(
                    for:
                        "Q7!mP2#zL9@vR4$x",
                    ruleMode: .smart
                )

        XCTAssertEqual(
            decision,
            .skipSensitive
        )
    }

    func testSmartModeSkipsPrefixedSecretToken() {
        let decision =
            ClipboardCapturePolicyService
                .decision(
                    for:
                        "ghp_abcdefghijklmnop",
                    ruleMode: .smart
                )

        XCTAssertEqual(
            decision,
            .skipSensitive
        )
    }

    func testBlockedModeSkipsNormalText() {
        let decision =
            ClipboardCapturePolicyService
                .decision(
                    for:
                        "Ordinary clipboard text",
                    ruleMode: .blocked
                )

        XCTAssertEqual(
            decision,
            .skipBlocked
        )
    }

    func testBlockedModeTakesPriorityOverSensitiveDetection() {
        let decision =
            ClipboardCapturePolicyService
                .decision(
                    for:
                        "Q7!mP2#zL9@vR4$x",
                    ruleMode: .blocked
                )

        XCTAssertEqual(
            decision,
            .skipBlocked
        )
    }
}

