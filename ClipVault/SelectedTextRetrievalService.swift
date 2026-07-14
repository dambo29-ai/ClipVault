//
//  SelectedTextRetrievalService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/13/26.
//

import ApplicationServices
import Foundation

enum SelectedTextRetrievalResult {
    case selectedText(String)
    case accessibilityNotGranted
    case applicationUnavailable
    case focusedElementUnavailable
    case noSelectedText
    case retrievalFailed
}

enum SelectedTextRetrievalService {
    static func retrieveSelectedText(
        from processIdentifier: pid_t
    ) -> SelectedTextRetrievalResult {
        guard AXIsProcessTrusted() else {
            return .accessibilityNotGranted
        }

        guard processIdentifier > 0 else {
            return .applicationUnavailable
        }

        let applicationElement =
            AXUIElementCreateApplication(
                processIdentifier
            )

        var focusedElementValue: CFTypeRef?

        let focusedElementError =
            AXUIElementCopyAttributeValue(
                applicationElement,
                kAXFocusedUIElementAttribute as CFString,
                &focusedElementValue
            )

        guard focusedElementError == .success,
              let focusedElementValue else {
            return .focusedElementUnavailable
        }

        let focusedElement =
            unsafeBitCast(
                focusedElementValue,
                to: AXUIElement.self
            )

        var selectedTextValue: CFTypeRef?

        let selectedTextError =
            AXUIElementCopyAttributeValue(
                focusedElement,
                kAXSelectedTextAttribute as CFString,
                &selectedTextValue
            )

        if selectedTextError == .noValue ||
            selectedTextError == .attributeUnsupported {
            return .noSelectedText
        }

        guard selectedTextError == .success else {
            return .retrievalFailed
        }

        guard let selectedText =
            selectedTextValue as? String else {
            return .noSelectedText
        }

        guard !selectedText.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            return .noSelectedText
        }

        return .selectedText(selectedText)
    }
}
