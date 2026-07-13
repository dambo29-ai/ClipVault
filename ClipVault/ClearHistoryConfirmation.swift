//
//  ClearHistoryConfirmation.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/9/26.
//

import AppKit

enum ClearHistoryConfirmation {
    @MainActor
    static func shouldClearHistory() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Clear Clipboard History?"
        alert.informativeText = "This will permanently delete all saved ClipVault history. This cannot be undone."
        alert.alertStyle = .warning

        let clearButton = alert.addButton(withTitle: "Clear History")
        clearButton.keyEquivalent = "\r"

        let cancelButton = alert.addButton(withTitle: "Cancel")
        cancelButton.keyEquivalent = "\u{1b}"

        let response = alert.runModal()

        return response == .alertFirstButtonReturn
    }
}
