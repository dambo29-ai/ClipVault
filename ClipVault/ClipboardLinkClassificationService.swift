//
//  ClipboardLinkClassificationService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/15/26.
//

import Foundation

enum ClipboardLinkClassificationService {
    static func isLink(_ text: String) -> Bool {
        let trimmedText =
            text.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !trimmedText.isEmpty else {
            return false
        }

        guard
            trimmedText.rangeOfCharacter(
                from: .whitespacesAndNewlines
            ) == nil
        else {
            return false
        }

        guard
            let components =
                URLComponents(string: trimmedText),
            let scheme =
                components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = components.host,
            !host.isEmpty
        else {
            return false
        }

        return true
    }
}
