//
//  ClipboardImagePasteboardService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/16/26.
//

import AppKit
import Foundation

@MainActor
struct ClipboardImagePasteboardService {
    private let imageStorageService:
        ClipboardImageStorageService

    init(
        imageStorageService:
            ClipboardImageStorageService =
                .shared
    ) {
        self.imageStorageService =
            imageStorageService
    }

    func writeImage(
        _ payload: ClipboardImagePayload,
        to pasteboard: NSPasteboard
    ) async throws -> Bool {
        let imageData =
            try await imageStorageService
                .loadImageData(
                    for: payload
                )

        let pasteboardType =
            NSPasteboard.PasteboardType(
                payload
                    .format
                    .uniformTypeIdentifier
            )

        let pasteboardItem =
            NSPasteboardItem()

        guard
            pasteboardItem.setData(
                imageData,
                forType: pasteboardType
            )
        else {
            return false
        }

        pasteboard.clearContents()

        return pasteboard.writeObjects([
            pasteboardItem
        ])
    }
}
