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

    private var previewURL: URL?

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
        /*
         loadImageData validates:
         - file existence
         - byte count
         - content hash
         - image decodability
         */
        _ =
            try await imageStorageService
                .loadImageData(
                    for: payload
                )

        let fileURL =
            try await imageStorageService
                .imageFileURL(
                    for: payload
                )

        previewURL =
            fileURL

        guard
            let previewPanel =
                QLPreviewPanel.shared()
        else {
            throw ClipboardImageQuickLookError
                .previewPanelUnavailable
        }

        previewPanel.dataSource = self
        previewPanel.delegate = self
        previewPanel.currentPreviewItemIndex = 0
        previewPanel.reloadData()

        NSApp.activate(
            ignoringOtherApps: true
        )

        previewPanel.makeKeyAndOrderFront(
            nil
        )
    }

    func numberOfPreviewItems(
        in panel: QLPreviewPanel!
    ) -> Int {
        previewURL == nil
            ? 0
            : 1
    }

    func previewPanel(
        _ panel: QLPreviewPanel!,
        previewItemAt index: Int
    ) -> QLPreviewItem! {
        guard
            index == 0,
            let previewURL
        else {
            return nil
        }

        return previewURL as NSURL
    }

    func previewPanelWillClose(
        _ panel: QLPreviewPanel!
    ) {
        previewURL = nil
    }
}

enum ClipboardImageQuickLookError:
    LocalizedError,
    Equatable
{
    case previewPanelUnavailable

    var errorDescription: String? {
        switch self {
        case .previewPanelUnavailable:
            return
                "The Quick Look preview panel could not be opened."
        }
    }
}
