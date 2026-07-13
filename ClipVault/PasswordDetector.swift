//
//  PasswordDetector.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/8/26.
//

import Foundation

struct PasswordDetector {
    static func isLikelyPassword(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return false
        }

        // Do not treat URLs as passwords.
        if isLikelyURL(trimmed) {
            return false
        }

        // Do not treat likely code snippets as passwords.
        if isLikelyCodeSnippet(trimmed) {
            return false
        }

        // Passwords are usually single-line.
        guard !trimmed.contains("\n") else {
            return false
        }

        // Avoid treating normal phrases as passwords.
        guard !trimmed.contains(" ") else {
            return false
        }

        // Most passwords are at least 8 characters.
        guard trimmed.count >= 8 else {
            return false
        }

        // Avoid classifying huge copied blobs as passwords.
        guard trimmed.count <= 256 else {
            return false
        }

        let hasLowercase = trimmed.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasUppercase = trimmed.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasNumber = trimmed.rangeOfCharacter(from: .decimalDigits) != nil

        let symbolCharacterSet = CharacterSet.alphanumerics.inverted
        let hasSymbol = trimmed.rangeOfCharacter(from: symbolCharacterSet) != nil

        let categoryCount = [hasLowercase, hasUppercase, hasNumber, hasSymbol]
            .filter { $0 }
            .count

        // Strong signal: classic complex password.
        // Example: MyFakeP@ssw0rd123!
        if categoryCount == 4 {
            return true
        }

        // Strong signal: random-looking token/key.
        // Example: long mixed alphanumeric strings with little readable structure.
        if trimmed.count >= 32 && categoryCount >= 3 && !looksReadable(trimmed) {
            return true
        }

        return false
    }

    private static func isLikelyURL(_ text: String) -> Bool {
        let lowercased = text.lowercased()

        if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") {
            return true
        }

        if lowercased.hasPrefix("www.") {
            return true
        }

        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased() else {
            return false
        }

        return ["http", "https", "mailto", "ftp"].contains(scheme)
    }

    private static func isLikelyCodeSnippet(_ text: String) -> Bool {
        let codeKeywords = [
            "func ", "let ", "var ", "import ", "struct ", "class ",
            "enum ", "private ", "public ", "return ", "guard ",
            "if ", "else ", "for ", "while ", "switch ", "case ",
            "@State", "@Published", "@MainActor", "@EnvironmentObject"
        ]

        if codeKeywords.contains(where: { text.contains($0) }) {
            return true
        }

        let codePatterns = [
            "()", "->", "=>", "==", "!=", ">=", "<=", "&&", "||",
            "{", "}", "[", "]", ";", "."
        ]

        let patternCount = codePatterns.filter { text.contains($0) }.count

        if patternCount >= 2 {
            return true
        }

        // Common function/property call shape:
        // clipboardStore.clearHistory()
        if text.contains(".") && text.contains("(") && text.contains(")") {
            return true
        }

        return false
    }

    private static func looksReadable(_ text: String) -> Bool {
        let vowels = CharacterSet(charactersIn: "aeiouAEIOU")
        let vowelCount = text.unicodeScalars.filter { vowels.contains($0) }.count

        // Very rough heuristic:
        // readable words usually have some vowels.
        return vowelCount >= 3
    }
}
