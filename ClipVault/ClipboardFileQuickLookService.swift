//
//  ClipboardFileQuickLookService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/20/26.
//

import AppKit
import Foundation
import QuickLookUI

enum ClipboardFileQuickLookError:
    LocalizedError,
    Equatable
{
    case emptyPayload
    case previewPanelUnavailable

    var errorDescription: String? {
        switch self {
        case .emptyPayload:
            return
                "The File clip does not contain anything that can be previewed."

        case .previewPanelUnavailable:
            return
                "The Quick Look preview panel could not be opened."
        }
    }
}

@MainActor
final class ClipboardFileQuickLookService:
    NSObject,
    QLPreviewPanelDataSource,
    QLPreviewPanelDelegate
{
    static let shared =
        ClipboardFileQuickLookService()

    private let fileReferenceService:
        ClipboardFileReferenceService

    private var resolvedReferences:
        [ResolvedClipboardFileReference] = []

    private var previewURLs:
        [URL] = []

    private var keyboardEventMonitor:
        Any?

    private override convenience init() {
        self.init(
            fileReferenceService:
                .shared
        )
    }

    init(
        fileReferenceService:
            ClipboardFileReferenceService
    ) {
        self.fileReferenceService =
            fileReferenceService

        super.init()
    }
    
    func preparePreview(
        for payload:
            ClipboardFilesPayload
    ) throws -> [URL] {
        stopAccessingCurrentReferences()

        guard
            !payload.files.isEmpty
        else {
            throw ClipboardFileQuickLookError
                .emptyPayload
        }

        var preparedReferences:
            [ResolvedClipboardFileReference] = []

        var preparedURLs:
            [URL] = []

        do {
            for reference in payload.files {
                let resolvedReference =
                    try fileReferenceService
                        .resolve(
                            reference
                        )

                preparedReferences.append(
                    resolvedReference
                )

                preparedURLs.append(
                    resolvedReference.url
                )
            }
        } catch {
            for resolvedReference in
                preparedReferences
            {
                resolvedReference
                    .stopAccessing()
            }

            throw error
        }

        resolvedReferences =
            preparedReferences

        previewURLs =
            preparedURLs

        return preparedURLs
    }

    func showPreview(
        for payload:
            ClipboardFilesPayload
    ) throws {
        if ClipboardFileInformationPreviewService
            .shared
            .canPreview(
                payload
            )
        {
            dismissPreview()

            try ClipboardFileInformationPreviewService
                .shared
                .showPreview(
                    for:
                        payload
                )

            return
        }

        ClipboardFileInformationPreviewService
            .shared
            .dismissPreview()

        _ =
            try preparePreview(
                for:
                    payload
            )

        guard
            let previewPanel =
                QLPreviewPanel.shared()
        else {
            stopAccessingCurrentReferences()

            throw ClipboardFileQuickLookError
                .previewPanelUnavailable
        }

        previewPanel.dataSource =
            self

        previewPanel.delegate =
            self

        previewPanel.currentPreviewItemIndex =
            0

        previewPanel.reloadData()

        installKeyboardEventMonitor(
            for:
                previewPanel
        )

        NSApp.activate(
            ignoringOtherApps:
                true
        )

        previewPanel.orderFrontRegardless()

        previewPanel.makeKeyAndOrderFront(
            nil
        )
    }

    func dismissPreview() {
        ClipboardFileInformationPreviewService
            .shared
            .dismissPreview()
        if let previewPanel =
            QLPreviewPanel.shared(),
            previewPanel.dataSource ===
                self
        {
            previewPanel.orderOut(
                nil
            )
        }

        finishPreview()
    }

    func numberOfPreviewItems(
        in panel:
            QLPreviewPanel!
    ) -> Int {
        previewURLs.count
    }

    func previewPanel(
        _ panel:
            QLPreviewPanel!,
        previewItemAt index:
            Int
    ) -> QLPreviewItem! {
        guard
            previewURLs.indices
                .contains(
                    index
                )
        else {
            return nil
        }

        return previewURLs[index]
            as NSURL
    }

    func previewPanelWillClose(
        _ panel:
            QLPreviewPanel!
    ) {
        finishPreview()
    }
    
    private func installKeyboardEventMonitor(
        for previewPanel:
            QLPreviewPanel
    ) {
        removeKeyboardEventMonitor()

        keyboardEventMonitor =
            NSEvent.addLocalMonitorForEvents(
                matching:
                    .keyDown
            ) {
                [weak self, weak previewPanel]
                event in

                guard
                    let self,
                    let previewPanel,
                    previewPanel.isVisible,
                    previewPanel.dataSource ===
                        self
                else {
                    return event
                }

                switch event.keyCode {
                case 49:
                    /*
                     Space
                     */
                    self.closePreviewPanel(
                        previewPanel
                    )

                    return nil

                case 53:
                    /*
                     Escape
                     */
                    self.closePreviewPanel(
                        previewPanel
                    )

                    return nil

                default:
                    return event
                }
            }
    }

    private func closePreviewPanel(
        _ previewPanel:
            QLPreviewPanel
    ) {
        previewPanel.orderOut(
            nil
        )

        finishPreview()
    }

    private func finishPreview() {
        stopAccessingCurrentReferences()

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

    private func stopAccessingCurrentReferences() {
        for resolvedReference in
            resolvedReferences
        {
            resolvedReference
                .stopAccessing()
        }

        resolvedReferences = []
        previewURLs = []
    }
}
