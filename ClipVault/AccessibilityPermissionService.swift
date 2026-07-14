//
//  AccessibilityPermissionService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/13/26.
//

import AppKit
import ApplicationServices

enum AccessibilityPermissionService {
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessAndOpenSettings() {
        let promptKey =
            kAXTrustedCheckOptionPrompt
                .takeUnretainedValue() as String

        let options = [
            promptKey: true
        ] as CFDictionary

        AXIsProcessTrustedWithOptions(options)

        openAccessibilitySettings()
    }

    static func openAccessibilitySettings() {
        guard let settingsURL = URL(
            string:
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }

        NSWorkspace.shared.open(settingsURL)
    }
}
