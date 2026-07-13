//
//  ResetAppRulesConfirmation.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/9/26.
//

import AppKit

enum ResetAppRulesConfirmation {
    @MainActor
    static func shouldResetAppRules() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Reset App Rules?"
        alert.informativeText = "This will restore ClipVault’s default app privacy rules. Custom app rule choices will be removed."
        alert.alertStyle = .warning

        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Reset Rules")

        let response = alert.runModal()

        return response == .alertSecondButtonReturn
    }
}
