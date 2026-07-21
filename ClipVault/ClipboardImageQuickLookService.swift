//
//  ClipboardImageQuickLookService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/16/26.
//

import AppKit
import Foundation
import QuickLookUI

@MainActor
final class ClipboardImageQuickLookService:
    NSObject,
    QLPreviewPanelDataSource,
    QLPreviewPanelDelegate
{
    static let shared =
        ClipboardImageQuickLookService()

    private let imageStorageService:
        ClipboardImageStorageService

    private var previewURL:
        URL?

    private var keyboardEventMonitor:
        Any?

    private override convenience init() {
        self.init(
            imageStorageService:
                .shared
        )
    }

    init(
        imageStorageService:
            ClipboardImageStorageService
    ) {
        self.imageStorageService =
            imageStorageService

        super.init()
    }

    func showPreview(
        for payload:
            ClipboardImagePayload
    ) async throws {
        _ =
            try await imageStorageService
                .loadImageData(
                    for:
                        payload
                )

        let fileURL =
            try await imageStorageService
                .imageFileURL(
                    for:
                        payload
                )

        previewURL =
            fileURL

        guard
            let previewPanel =
                QLPreviewPanel.shared()
        else {
            finishPreview()

            throw ClipboardImageQuickLookError
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

    func numberOfPreviewItems(
        in panel:
            QLPreviewPanel!
    ) -> Int {
        previewURL == nil
            ? 0
            : 1
    }

    func previewPanel(
        _ panel:
            QLPreviewPanel!,
        previewItemAt index:
            Int
    ) -> QLPreviewItem! {
        guard
            index == 0,
            let previewURL
        else {
            return nil
        }

        return previewURL
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
                    self.closePreviewPanel(
                        previewPanel
                    )

                    return nil

                case 53:
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
        previewURL =
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

enum ClipboardImageQuickLookError:
    LocalizedError,
    Equatable
{
    case previewPanelUnavailable

    var errorDescription:
        String?
    {
        switch self {
        case .previewPanelUnavailable:
            return
                "The Quick Look preview panel could not be opened."
        }
    }
}
