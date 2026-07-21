//
//  ClipboardFileInformationPreviewService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/21/26.
//

import AppKit
import SwiftUI

@MainActor
final class ClipboardFileInformationPreviewService:
    NSObject,
    NSWindowDelegate
{
    static let shared =
        ClipboardFileInformationPreviewService()

    private let fileReferenceService:
        ClipboardFileReferenceService

    private let informationReader:
        ClipboardFileInformationReader

    private var panel:
        NSPanel?

    private var resolvedReference:
        ResolvedClipboardFileReference?

    private var keyboardEventMonitor:
        Any?

    private override convenience init() {
        self.init(
            fileReferenceService:
                .shared,
            informationReader:
                ClipboardFileInformationReader()
        )
    }

    init(
        fileReferenceService:
            ClipboardFileReferenceService,
        informationReader:
            ClipboardFileInformationReader
    ) {
        self.fileReferenceService =
            fileReferenceService

        self.informationReader =
            informationReader

        super.init()
    }

    func canPreview(
        _ payload:
            ClipboardFilesPayload
    ) -> Bool {
        guard
            payload.files.count == 1,
            let reference =
                payload.files.first
        else {
            return false
        }

        if reference.isDirectory ||
            reference.isSymbolicLink
        {
            return true
        }

        guard
            let resolvedReference =
                try? fileReferenceService
                    .resolve(
                        reference
                    )
        else {
            return false
        }

        defer {
            resolvedReference
                .stopAccessing()
        }

        let resourceValues =
            try? resolvedReference
                .url
                .resourceValues(
                    forKeys: [
                        .isAliasFileKey
                    ]
                )

        return resourceValues?
            .isAliasFile ??
            false
    }

    func showPreview(
        for payload:
            ClipboardFilesPayload
    ) throws {
        dismissPreview()

        guard
            payload.files.count == 1,
            let reference =
                payload.files.first
        else {
            throw ClipboardFileInformationReaderError
                .unsupportedItem
        }

        let resolvedReference =
            try fileReferenceService
                .resolve(
                    reference
                )

        let information:
            ClipboardFileInformation

        do {
            information =
                try informationReader
                    .information(
                        for:
                            reference,
                        resolvedURL:
                            resolvedReference.url
                    )
        } catch {
            resolvedReference
                .stopAccessing()

            throw error
        }

        self.resolvedReference =
            resolvedReference

        let hostingController =
            NSHostingController(
                rootView:
                    ClipboardFileInformationView(
                        information:
                            information
                    )
            )

        let panel =
            NSPanel(
                contentRect:
                    NSRect(
                        x:
                            0,
                        y:
                            0,
                        width:
                            860,
                        height:
                            520
                    ),
                styleMask: [
                    .titled,
                    .closable,
                    .resizable,
                    .fullSizeContentView
                ],
                backing:
                    .buffered,
                defer:
                    false
            )

        panel.title =
            information.displayName

        panel.titleVisibility =
            .hidden

        panel.titlebarAppearsTransparent =
            true

        panel.isReleasedWhenClosed =
            false

        panel.delegate =
            self

        panel.contentViewController =
            hostingController

        panel.minSize =
            NSSize(
                width:
                    720,
                height:
                    440
            )

        panel.center()

        installKeyboardEventMonitor(
            for:
                panel
        )

        NSApp.activate(
            ignoringOtherApps:
                true
        )

        panel.makeKeyAndOrderFront(
            nil
        )

        self.panel =
            panel
    }

    func dismissPreview() {
        panel?
            .orderOut(
                nil
            )

        finishPreview()
    }

    func windowWillClose(
        _ notification:
            Notification
    ) {
        finishPreview()
    }

    private func installKeyboardEventMonitor(
        for panel:
            NSPanel
    ) {
        removeKeyboardEventMonitor()

        keyboardEventMonitor =
            NSEvent.addLocalMonitorForEvents(
                matching:
                    .keyDown
            ) {
                [weak self, weak panel]
                event in

                guard
                    let self,
                    let panel,
                    panel.isVisible,
                    self.panel ===
                        panel
                else {
                    return event
                }

                switch event.keyCode {
                case 49,
                     53:
                    self.dismissPreview()

                    return nil

                default:
                    return event
                }
            }
    }

    private func finishPreview() {
        resolvedReference?
            .stopAccessing()

        resolvedReference =
            nil

        panel =
            nil

        removeKeyboardEventMonitor()
    }

    private func removeKeyboardEventMonitor() {
        guard
            let keyboardEventMonitor
        else {
            return
        }

        NSEvent.removeMonitor(
            keyboardEventMonitor
        )

        self.keyboardEventMonitor =
            nil
    }
}
