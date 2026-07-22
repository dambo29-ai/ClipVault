//
//  ClipboardCapturePolicyService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/14/26.
//

import Foundation

enum ClipboardCapturePolicyDecision:
    Equatable {
    case capture
    case skipBlocked
    case skipSensitive
}

enum ClipboardCapturePolicyService {
    static func decision(
        for text:
            String,
        ruleMode:
            AppRuleMode,
        blocksLikelySensitiveClips:
            Bool =
                true
    ) -> ClipboardCapturePolicyDecision {
        switch ruleMode {
        case .blocked:
            /*
             An explicit Blocked app rule always takes
             priority over the global privacy preference.
             */
            return .skipBlocked

        case .smart:
            /*
             Smart apps retain their additional sensitive
             text and token filtering even when the global
             protection preference is disabled.
             */
            if shouldSkipInSmartMode(
                text
            ) {
                return .skipSensitive
            }

            return .capture

        case .allowed:
            /*
             Allowed apps use the global sensitive-clip
             preference. Disabling it permits likely
             passwords to enter ClipVault history.
             */
            if
                blocksLikelySensitiveClips,
                PasswordDetector
                    .isLikelyPassword(
                        text
                    )
            {
                return .skipSensitive
            }

            return .capture
        }
    }

    private static func shouldSkipInSmartMode(
        _ text: String
    ) -> Bool {
        let trimmed =
            text.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !trimmed.isEmpty else {
            return false
        }

        if isObviousEmail(trimmed) {
            return false
        }

        if isLikelyURL(trimmed) {
            return false
        }

        if PasswordDetector
            .isLikelyPassword(trimmed) {
            return true
        }

        if isLikelySecretToken(trimmed) {
            return true
        }

        return false
    }

    private static func isObviousEmail(
        _ text: String
    ) -> Bool {
        guard !text.contains(" ") else {
            return false
        }

        let parts =
            text.split(separator: "@")

        guard
            parts.count == 2,
            let domain = parts.last,
            domain.contains(".")
        else {
            return false
        }

        return true
    }

    private static func isLikelyURL(
        _ text: String
    ) -> Bool {
        let lowercased =
            text.lowercased()

        if lowercased.hasPrefix("http://") ||
            lowercased.hasPrefix("https://") {
            return true
        }

        if lowercased.hasPrefix("www.") {
            return true
        }

        guard
            let url = URL(string: text),
            let scheme =
                url.scheme?.lowercased()
        else {
            return false
        }

        return [
            "http",
            "https",
            "mailto",
            "ftp"
        ]
        .contains(scheme)
    }

    private static func isLikelySecretToken(
        _ text: String
    ) -> Bool {
        let trimmed =
            text.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !trimmed.contains(" ") else {
            return false
        }

        guard trimmed.count >= 16 else {
            return false
        }

        let lowercased =
            trimmed.lowercased()

        let secretPrefixes = [
            "sk-",
            "pk_",
            "rk_",
            "ghp_",
            "gho_",
            "github_pat_",
            "xoxb-",
            "xoxp-"
        ]

        if secretPrefixes.contains(
            where: {
                lowercased.hasPrefix($0)
            }
        ) {
            return true
        }

        let hasLowercase =
            trimmed.rangeOfCharacter(
                from: .lowercaseLetters
            ) != nil

        let hasUppercase =
            trimmed.rangeOfCharacter(
                from: .uppercaseLetters
            ) != nil

        let hasNumber =
            trimmed.rangeOfCharacter(
                from: .decimalDigits
            ) != nil

        let hasSymbol =
            trimmed.rangeOfCharacter(
                from:
                    CharacterSet
                        .alphanumerics
                        .inverted
            ) != nil

        let categoryCount = [
            hasLowercase,
            hasUppercase,
            hasNumber,
            hasSymbol
        ]
        .filter { $0 }
        .count

        if trimmed.count >= 24 &&
            categoryCount >= 3 {
            return true
        }

        if trimmed.count >= 32 &&
            categoryCount >= 2 {
            return true
        }

        return false
    }
}

