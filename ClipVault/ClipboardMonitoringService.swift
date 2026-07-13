//
//  ClipboardMonitoringService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/11/26.
//

import AppKit
import Foundation

struct ClipboardChangePayload {
    let text: String
    let sourceAppName: String?
    let sourceBundleIdentifier: String?
    let sourceAppPath: String?
}

@MainActor
final class ClipboardMonitoringService {
    private let pasteboard: NSPasteboard
    private let pollingInterval: Duration

    private var lastChangeCount: Int
    private var monitoringTask: Task<Void, Never>?

    init(
        pasteboard: NSPasteboard = .general,
        pollingInterval: Duration = .milliseconds(100)
    ) {
        self.pasteboard = pasteboard
        self.pollingInterval = pollingInterval
        self.lastChangeCount = pasteboard.changeCount
    }

    deinit {
        monitoringTask?.cancel()
    }

    func start(
        onClipboardChange: @escaping @MainActor (
            ClipboardChangePayload
        ) -> Void
    ) {
        guard monitoringTask == nil else {
            return
        }

        monitoringTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            while !Task.isCancelled {
                checkForClipboardChange(
                    onClipboardChange: onClipboardChange
                )

                try? await Task.sleep(for: pollingInterval)
            }
        }
    }

    func stop() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    func synchronizeChangeCount() {
        lastChangeCount = pasteboard.changeCount
    }

    private func checkForClipboardChange(
        onClipboardChange: @escaping @MainActor (
            ClipboardChangePayload
        ) -> Void
    ) {
        guard pasteboard.changeCount != lastChangeCount else {
            return
        }

        lastChangeCount = pasteboard.changeCount

        guard let copiedText = pasteboard.string(forType: .string) else {
            return
        }

        let sourceApp = NSWorkspace.shared.frontmostApplication

        let payload = ClipboardChangePayload(
            text: copiedText,
            sourceAppName: sourceApp?.localizedName,
            sourceBundleIdentifier: sourceApp?.bundleIdentifier,
            sourceAppPath: sourceApp?.bundleURL?.path
        )

        onClipboardChange(payload)
    }
}
