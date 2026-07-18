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
    let onRename: (String?) -> Void
    let onPin: () -> Void
    let onUnpin: () -> Void
    let onDelete: () -> Void

    @State private var isRenaming = false
    @State private var renameDraft = ""

    @FocusState
    private var isRenameFieldFocused:
        Bool

    var body: some View {
        HStack(
            alignment: .top,
            spacing: 10
        ) {
            numberView

            if item.kind ==
                .sensitiveSkipped
            {
                sensitiveSkippedRow
            } else {
                normalRow
            }
        }
        .background {
            RoundedRectangle(
                cornerRadius: 6
            )
            .fill(
                isHighlighted
                    ? Color.accentColor
                        .opacity(0.16)
                    : Color.clear
            )
        }
        .animation(
            .easeInOut(
                duration: 0.22
            ),
            value:
                isHighlighted
        )
        .onExitCommand {
            guard isRenaming else {
                return
            }

            cancelRenaming()
        }
        .onChange(
            of:
                isRenameFieldFocused
        ) {
            _,
            isFocused in

            if isRenaming &&
                !isFocused
            {
                saveRename()
            }
        }
    }

    @ViewBuilder
    private var numberView:
        some View
    {
        if let displayNumber {
            Text(
                "\(displayNumber)"
            )
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(
                .secondary
            )
            .monospacedDigit()
            .frame(
                width: 28,
                alignment: .center
            )
            .padding(.top, 10)
        } else {
            Color.clear
                .frame(width: 28)
        }
    }

    private var normalRow:
        some View
    {
        HStack(spacing: 8) {
            if isRenaming {
                renameEditor
            } else {
                Button(
                    action:
                        onCopy
                ) {
                    normalRowContent
                        .frame(
                            maxWidth:
                                .infinity,
                            alignment:
                                .leading
                        )
                        .padding(
                            .vertical,
                            8
                        )
                        .frame(
                            maxWidth:
                                .infinity,
                            alignment:
                                .leading
                        )
                        .contentShape(
                            Rectangle()
                        )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    copyContextMenuButton

                    Button(
                        "Rename Clip"
                    ) {
                        beginRenaming()
                    }

                    if isLink {
                        Button(
                            "Open Link"
                        ) {
                            openLink()
                        }
                    }

                    if item.imagePayload !=
                        nil
                    {
                        Button(
                            "Preview"
                        ) {
                            previewImage()
                        }
                    }

                    if item.isPinned {
                        Button(
                            "Unpin"
                        ) {
                            onUnpin()
                        }
                    } else {
                        Button(
                            "Pin"
                        ) {
                            onPin()
                        }
                    }

                    Divider()

                    Button(
                        "Delete",
                        role:
                            .destructive
                    ) {
                        onDelete()
                    }
                }
            }

            if !isRenaming {
                if isLink {
                    openLinkButton
                }

                if item.imagePayload != nil {
                    previewImageButton
                }

                renameButton

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
    }

    private var renameEditor:
        some View
    {
        HStack(spacing: 8) {
            TextField(
                "Clip title",
                text:
                    $renameDraft
            )
            .textFieldStyle(
                .roundedBorder
            )
            .focused(
                $isRenameFieldFocused
            )
            .onSubmit {
                saveRename()
            }

            Button {
                saveRename()
            } label: {
                Image(
                    systemName:
                        "checkmark"
                )
                .frame(
                    width: 24,
                    height: 24
                )
            }
            .buttonStyle(
                .borderless
            )
            .help("Save title")

            Button {
                cancelRenaming()
            } label: {
                Image(
                    systemName:
                        "xmark"
                )
                .frame(
                    width: 24,
                    height: 24
                )
            }
            .buttonStyle(
                .borderless
            )
            .help("Cancel renaming")
        }
        .padding(.vertical, 8)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    private var copyContextMenuButton:
        some View
    {
        Button(
            item.imagePayload == nil
                ? "Copy"
                : "Copy Image"
        ) {
            onCopy()
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
        } else if let filesPayload =
            item.filesPayload
        {
            filesRowContent(
                filesPayload
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
            Text(
                item.displayText
            )
            .fontWeight(
                item.hasCustomTitle
                    ? .medium
                    : .regular
            )
            .lineLimit(
                item.hasCustomTitle
                    ? 1
                    : 3
            )
            .multilineTextAlignment(
                .leading
            )

            if item.hasCustomTitle {
                Text(
                    item.automaticDisplayText
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                .lineLimit(2)
                .multilineTextAlignment(
                    .leading
                )
            }

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
                payload:
                    imagePayload
            )

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(
                    item.displayText
                )
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(
                    .middle
                )
                .help(
                    item.displayText
                )

                if item.hasCustomTitle {
                    Text(
                        imagePayload
                            .displayTitle
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(1)
                    .truncationMode(
                        .middle
                    )
                }

                Text(
                    imagePayload
                        .rowMetadataText
                )
                .lineLimit(1)

                imageSourceMetadataView
            }
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    .leading
            )
        }
    }

    private func filesRowContent(
        _ filesPayload:
            ClipboardFilesPayload
    ) -> some View {
        HStack(
            alignment: .center,
            spacing: 12
        ) {
            fileIconView(
                for:
                    filesPayload
            )

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(
                    item.displayText
                )
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(
                    .middle
                )
                .help(
                    item.displayText
                )

                if item.hasCustomTitle {
                    Text(
                        filesPayload
                            .displayTitle
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(1)
                    .truncationMode(
                        .middle
                    )
                }

                Text(
                    filesPayload
                        .rowMetadataText
                )
                .lineLimit(1)
                .foregroundStyle(
                    .secondary
                )

                fileSourceMetadataView
            }
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    .leading
            )
        }
    }

    @ViewBuilder
    private func fileIconView(
        for filesPayload:
            ClipboardFilesPayload
    ) -> some View {
        if let fileReference =
            filesPayload.files.first
        {
            Image(
                systemName:
                    fileReference
                        .isDirectory
                        ? "folder.fill"
                        : "doc.fill"
            )
            .font(
                .system(
                    size: 32
                )
            )
            .foregroundStyle(
                .secondary
            )
            .frame(
                width: 56,
                height: 56
            )
            .background {
                RoundedRectangle(
                    cornerRadius: 7
                )
                .fill(
                    Color.secondary
                        .opacity(0.08)
                )
            }
            .accessibilityHidden(
                true
            )
        }
    }

    private var isLink: Bool {
        item.kind == .normal &&
        item.linkURL != nil
    }

    private var linkURL: URL? {
        guard
            item.kind ==
                .normal
        else {
            return nil
        }

        return item.linkURL
    }

    private func beginRenaming() {
        renameDraft =
            item.customTitle ??
            item.automaticDisplayText

        isRenaming = true

        Task { @MainActor in
            isRenameFieldFocused =
                true
        }
    }

    private func saveRename() {
        guard isRenaming else {
            return
        }

        isRenaming = false
        isRenameFieldFocused =
            false

        onRename(
            renameDraft
        )
    }

    private func cancelRenaming() {
        isRenaming = false
        isRenameFieldFocused =
            false
        renameDraft = ""
    }

    private func openLink() {
        guard let linkURL else {
            return
        }

        NSWorkspace.shared.open(
            linkURL
        )
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
                    error:
                        error
                )
            }
        }
    }

    private var sensitiveSkippedRow:
        some View
    {
        HStack(spacing: 8) {
            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                Text(
                    item.displayText
                )
                .fontWeight(.bold)
                .foregroundStyle(.red)
                .lineLimit(3)
                .multilineTextAlignment(
                    .leading
                )

                Text(
                    ClipboardTimestampFormatter
                        .string(
                            for:
                                item.createdAt
                        )
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }
            .padding(.vertical, 8)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )

            deleteButton
                .help(
                    "Delete this warning row"
                )
                .accessibilityLabel(
                    "Delete warning row"
                )
        }
    }
    
    private var renameButton:
        some View
    {
        Button {
            beginRenaming()
        } label: {
            Image(
                systemName:
                    "square.and.pencil"
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
        .help("Rename clip")
        .accessibilityLabel(
            "Rename clipboard item"
        )
    }

    private var pinButton:
        some View
    {
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
            .frame(
                width: 28,
                height: 28
            )
            .contentShape(
                Rectangle()
            )
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

    private var deleteButton:
        some View
    {
        Button(
            role: .destructive,
            action:
                onDelete
        ) {
            Image(
                systemName:
                    "trash"
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
    }

    private var openLinkButton:
        some View
    {
        Button {
            openLink()
        } label: {
            Image(
                systemName:
                    "link"
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
        .help("Open link in browser")
        .accessibilityLabel(
            "Open link"
        )
    }

    private var previewImageButton:
        some View
    {
        Button {
            previewImage()
        } label: {
            Image(
                systemName:
                    "eye"
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

    @ViewBuilder
    private var metadataView:
        some View
    {
        HStack(spacing: 4) {
            Text(
                item.sourceAppName ??
                "Unknown App"
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )

            Text("•")
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

            Text(
                ClipboardTimestampFormatter
                    .string(
                        for:
                            item.createdAt
                    )
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )
        }
    }

    private var imageSourceMetadataView:
        some View
    {
        metadataView
    }

    private var fileSourceMetadataView:
        some View
    {
        metadataView
    }
}
