//
//  KeyboardShortcutNames.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/9/26.
//

import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let showClipVault = Self(
        "showClipVault",
        initial: .init(.v, modifiers: [.control, .option])
    )
    
    static let pauseResumeMonitoring = Self(
        "pauseResumeMonitoring",
        initial: .init(.p, modifiers: [.control, .option])
    )
}
