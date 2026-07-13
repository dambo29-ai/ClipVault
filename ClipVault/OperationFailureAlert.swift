//
//  OperationFailureAlert.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/11/26.
//

import AppKit

enum OperationFailureAlert {
    @MainActor
    static func show(
        title: String,
        message: String,
        error: Error? = nil
    ) {
        let alert = NSAlert()
        alert.messageText = title

        if let error {
            alert.informativeText =
                "\(message)\n\n\(error.localizedDescription)"
        } else {
            alert.informativeText = message
        }

        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
