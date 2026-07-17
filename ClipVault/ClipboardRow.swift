//
//  ClipboardRow.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/10/26.
//

import AppKit
import SwiftUI

struct ClipboardRow: View {
    let item: ClipboardItem
    let displayNumber: Int?
    let isHighlighted: Bool
    let onCopy: () -> Void
    let onPin: () -> Void
    let onUnpin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            numberView

            if item.kind == .sensitiveSkipped {
                sensitiveSkippedRow
            } else {
                normalRow
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isHighlighted
                        ? Color.accentColor.opacity(0.16)
                        : Color.clear
                )
        }
        .animation(
            .easeInOut(duration: 0.22),
            value: isHighlighted
        )
    }
    
    @ViewBuilder
    private var numberView: some View {
        if let displayNumber {
            Text("\(displayNumber)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 28, alignment: .center)
                .padding(.top, 10)
        } else {
            Color.clear
                .frame(width: 28)
        }
    }

    private var normalRow: some View {
        HStack(spacing: 8) {
            Button(action: onCopy) {
                normalRowContent
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding(.vertical, 8)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(
                    item.imagePayload == nil
                        ? "Copy"
                        : "Copy Image"
                ) {
                    onCopy()
                }

                if isLink {
                    Button("Open Link") {
                        openLink()
                    }
                }

                if item.imagePayload != nil {
                    Button("Preview") {
                        previewImage()
                    }
                }

                if item.isPinned {
                    Button("Unpin") {
                        onUnpin()
                    }
                } else {
                    Button("Pin") {
                        onPin()
                    }
                }

                Divider()

                Button(
                    "Delete",
                    role: .destructive
                ) {
                    onDelete()
                }
            }

            if isLink {
                openLinkButton
            }

            if item.imagePayload != nil {
                previewImageButton
            }

            pinButton

            deleteButton
                .help(
                    "Delete this clipboard item"
                )
                .accessibilityLabel(
                    "Delete clipboard item"
                )
        }
    }

    @ViewBuilder
    private var normalRowContent:
        some View
    {
        if let imagePayload =
            item.imagePayload
        {
            imageRowContent(
                imagePayload
            )
        } else {
            textRowContent
        }
    }

    private var textRowContent:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 6
        ) {
            Text(item.displayText)
                .lineLimit(3)
                .multilineTextAlignment(
                    .leading
                )

            metadataView
        }
    }

    private func imageRowContent(
        _ imagePayload:
            ClipboardImagePayload
    ) -> some View {
        HStack(
            alignment: .center,
            spacing: 12
        ) {
            ClipboardImageThumbnailView(
                payload: imagePayload
            )

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(
                    imagePayload.displayTitle
                )
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(
                    imagePayload.displayTitle
                )

                Text(
                    imagePayload
                        .rowMetadataText
                )
                .lineLimit(1)

                imageSourceMetadataView
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        }
    }
    
    private var isLink: Bool {
        item.kind == .normal &&
        item.linkURL != nil
    }

    private var linkURL: URL? {
        guard item.kind == .normal else {
            return nil
        }

        return item.linkURL
    }

    private func openLink() {
        guard let linkURL else {
            return
        }

        NSWorkspace.shared.open(linkURL)
    }
    
    private func previewImage() {
        guard
            let imagePayload =
                item.imagePayload
        else {
            return
        }

        Task { @MainActor in
            do {
                try await
                    ClipboardImageQuickLookService
                        .shared
                        .showPreview(
                            for:
                                imagePayload
                        )
            } catch {
                OperationFailureAlert.show(
                    title:
                        "Image Could Not Be Previewed",
                    message:
                        "The stored image could not be opened in Quick Look.",
                    error: error
                )
            }
        }
    }

    private var sensitiveSkippedRow: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.displayText)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                Text(
                    ClipboardTimestampFormatter.string(
                        for: item.createdAt
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)

            deleteButton
                .help("Delete this warning row")
                .accessibilityLabel("Delete warning row")
        }
    }
    
    private var pinButton: some View {
        Button {
            if item.isPinned {
                onUnpin()
            } else {
                onPin()
            }
        } label: {
            Image(
                systemName:
                    item.isPinned
                        ? "pin.fill"
                        : "pin"
            )
            .foregroundStyle(
                item.isPinned
                    ? .primary
                    : .secondary
            )
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(
            item.isPinned
                ? "Unpin item"
                : "Pin item"
        )
        .accessibilityLabel(
            item.isPinned
                ? "Unpin clipboard item"
                : "Pin clipboard item"
        )
    }
    
    private var previewImageButton:
        some View
    {
        Button(
            action: previewImage
        ) {
            Image(
                systemName: "eye"
            )
            .foregroundStyle(
                .secondary
            )
            .frame(
                width: 28,
                height: 28
            )
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(.borderless)
        .help("Preview image")
        .accessibilityLabel(
            "Preview image"
        )
    }
    
    private var openLinkButton: some View {
        Button(action: openLink) {
            Image(systemName: "link")
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help("Open link")
        .accessibilityLabel("Open link")
    }
    
    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "trash")
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }
    
    private var imageSourceMetadataView:
        some View
    {
        HStack(spacing: 6) {
            if let sourceAppName =
                item.sourceAppName,
               !sourceAppName
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .isEmpty
            {
                Text(sourceAppName)
                    .lineLimit(1)

                Text("•")
            }

            Text(
                ClipboardTimestampFormatter
                    .string(
                        for:
                            item.createdAt
                    )
            )
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    
    private var metadataView: some View {
        HStack(spacing: 6) {
            Text(
                ClipboardTimestampFormatter.string(
                    for: item.createdAt
                )
            )
            
            if let sourceAppName = item.sourceAppName,
               !sourceAppName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("•")
                
                Text(sourceAppName)
                    .lineLimit(1)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
