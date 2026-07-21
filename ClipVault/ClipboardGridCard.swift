//
//  ClipboardGridCard.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/20/26.
//

import AppKit
import SwiftUI

struct ClipboardGridCard: View {
    let item: ClipboardItem
    let displayNumber: Int?
    let isHighlighted: Bool
    let onCopy: () -> Void
    let onRename: (String?) -> Void
    let onPin: () -> Void
    let onUnpin: () -> Void
    let onDelete: () -> Void

    @State private var isRenaming =
        false

    @State private var renameDraft =
        ""

    @State private var isCopyFeedbackActive =
        false

    @State private var copyFeedbackGeneration =
        0

    @State private var fileAvailability:
        ClipboardFileAvailabilityStatus =
            .available

    @FocusState
    private var isRenameFieldFocused:
        Bool

    var body: some View {
        VStack(
            alignment:
                .leading,
            spacing:
                8
        ) {
            ZStack(
                alignment:
                    .topLeading
            ) {
                Button(
                    action:
                        performCopy
                ) {
                    previewArea
                        .frame(
                            maxWidth:
                                .infinity
                        )
                        .contentShape(
                            Rectangle()
                        )
                }
                .buttonStyle(.plain)

                if let displayNumber {
                    Text(
                        "\(displayNumber)"
                    )
                    .font(.caption2)
                    .fontWeight(
                        .semibold
                    )
                    .monospacedDigit()
                    .padding(
                        .horizontal,
                        6
                    )
                    .padding(
                        .vertical,
                        3
                    )
                    .background(
                        .regularMaterial,
                        in:
                            Capsule()
                    )
                    .padding(6)
                }
            }

            Group {
                if isRenaming {
                    renameEditor
                } else {
                    titleArea
                }
            }
            .frame(
                height:
                    76,
                alignment:
                    .topLeading
            )

            cardActions
        }
        .padding(8)
        .frame(
            height:
                260,
            alignment:
                .top
        )
        .background {
            RoundedRectangle(
                cornerRadius:
                    10
            )
            .fill(
                isHighlighted ||
                isCopyFeedbackActive
                    ? Color.accentColor
                        .opacity(
                            isHighlighted
                                ? 0.16
                                : 0.12
                        )
                    : Color(
                        nsColor:
                            .controlBackgroundColor
                    )
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius:
                    10
            )
            .stroke(
                isHighlighted
                    ? Color.accentColor
                        .opacity(0.45)
                    : Color.secondary
                        .opacity(0.18),
                lineWidth:
                    1
            )
        }
        .animation(
            .easeOut(
                duration:
                    0.16
            ),
            value:
                isCopyFeedbackActive
        )
        .contextMenu {
            Button(
                item.imagePayload == nil
                    ? "Copy"
                    : "Copy Image"
            ) {
                performCopy()
            }

            Button(
                "Rename Clip"
            ) {
                beginRenaming()
            }

            if item.imagePayload != nil {
                Button(
                    "Preview"
                ) {
                    previewImage()
                }
            }

            if item.filesPayload != nil {
                Button(
                    "Preview"
                ) {
                    previewFiles()
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
    private var previewArea:
        some View
    {
        if let imagePayload =
            item.imagePayload
        {
            ClipboardImageThumbnailView(
                payload:
                    imagePayload,
                width:
                    168,
                height:
                    126
            )
            .frame(
                maxWidth:
                    .infinity
            )
        } else if let linkURL =
            item.linkURL
        {
            ClipboardLinkThumbnailView(
                url:
                    linkURL,
                width:
                    168,
                height:
                    126
            )
            .frame(
                maxWidth:
                    .infinity
            )
        } else if let filesPayload =
            item.filesPayload
        {
            filePreviewArea(
                filesPayload
            )
        }
    }

    private func filePreviewArea(
        _ filesPayload:
            ClipboardFilesPayload
    ) -> some View {
        ClipboardFileThumbnailView(
            payload:
                filesPayload,
            width:
                168,
            height:
                126,
            availability:
                fileAvailability
        )
        .frame(
            maxWidth:
                .infinity
        )
        .task(
            id:
                filesPayload
        ) {
            await monitorFileAvailability(
                filesPayload
            )
        }
    }

    private var titleArea:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                4
        ) {
            Text(
                item.displayText
            )
            .font(.callout)
            .fontWeight(.medium)
            .lineLimit(2)
            .truncationMode(
                .middle
            )
            .help(
                item.displayText
            )

            if item.hasCustomTitle {
                Text(
                    item.automaticDisplayText
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
                metadataText
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )
            .lineLimit(1)
        }
        .frame(
            maxWidth:
                .infinity,
            alignment:
                .leading
        )
    }

    private var metadataText:
        String
    {
        if let imagePayload =
            item.imagePayload
        {
            return imagePayload
                .rowMetadataText
        }

        if let filesPayload =
            item.filesPayload
        {
            return filesPayload
                .rowMetadataText
        }

        if let linkURL =
            item.linkURL
        {
            return ClipboardLinkPreviewService
                .domain(
                    for:
                        linkURL
                )
        }

        return ""
    }

    private var cardActions:
        some View
    {
        HStack(
            spacing:
                4
        ) {
            Spacer()

            previewButton

            renameButton

            pinButton

            deleteButton
        }
    }

    @ViewBuilder
    private var previewButton:
        some View
    {
        if item.imagePayload != nil {
            actionButton(
                systemName:
                    "eye",
                help:
                    "Preview image",
                action:
                    previewImage
            )
        } else if let filesPayload =
            item.filesPayload
        {
            actionButton(
                systemName:
                    "eye",
                help:
                    filesPayload.files.count == 1
                        ? "Preview file or folder"
                        : "Preview file group",
                action:
                    previewFiles
            )
        }
    }

    private var renameButton:
        some View
    {
        actionButton(
            systemName:
                "square.and.pencil",
            help:
                "Rename clip",
            action:
                beginRenaming
        )
    }

    private var pinButton:
        some View
    {
        actionButton(
            systemName:
                item.isPinned
                    ? "pin.slash"
                    : "pin",
            help:
                item.isPinned
                    ? "Unpin clipboard item"
                    : "Pin clipboard item",
            action:
                item.isPinned
                    ? onUnpin
                    : onPin
        )
    }

    private var deleteButton:
        some View
    {
        actionButton(
            systemName:
                "trash",
            help:
                "Delete clipboard item",
            action:
                onDelete
        )
    }

    private func actionButton(
        systemName:
            String,
        help:
            String,
        action:
            @escaping () -> Void
    ) -> some View {
        Button(
            action:
                action
        ) {
            Image(
                systemName:
                    systemName
            )
            .foregroundStyle(
                .secondary
            )
            .frame(
                width:
                    26,
                height:
                    26
            )
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(
            .borderless
        )
        .help(help)
    }

    private var renameEditor:
        some View
    {
        HStack(
            spacing:
                5
        ) {
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
            }
            .buttonStyle(
                .borderless
            )
            .help(
                "Save title"
            )

            Button {
                cancelRenaming()
            } label: {
                Image(
                    systemName:
                        "xmark"
                )
            }
            .buttonStyle(
                .borderless
            )
            .help(
                "Cancel renaming"
            )
        }
    }
    
    private func performCopy() {
        copyFeedbackGeneration += 1

        let generation =
            copyFeedbackGeneration

        isCopyFeedbackActive =
            true

        onCopy()

        Task { @MainActor in
            try? await Task.sleep(
                for:
                    .milliseconds(180)
            )

            guard
                copyFeedbackGeneration ==
                    generation
            else {
                return
            }

            isCopyFeedbackActive =
                false
        }
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

    private func previewFiles() {
        guard
            let filesPayload =
                item.filesPayload
        else {
            return
        }

        do {
            try ClipboardFileQuickLookService
                .shared
                .showPreview(
                    for:
                        filesPayload
                )
        } catch {
            OperationFailureAlert.show(
                title:
                    "File Could Not Be Previewed",
                message:
                    filesPayload.files.count == 1
                        ? "The original file or folder could not be opened in Quick Look."
                        : "One or more original files or folders could not be opened in Quick Look.",
                error:
                    error
            )
        }
    }

    private func monitorFileAvailability(
        _ filesPayload:
            ClipboardFilesPayload
    ) async {
        while !Task.isCancelled {
            let updatedAvailability =
                ClipboardFileAvailabilityService
                    .shared
                    .status(
                        for:
                            filesPayload
                    )

            if fileAvailability !=
                updatedAvailability
            {
                fileAvailability =
                    updatedAvailability
            }

            do {
                try await Task.sleep(
                    for:
                        .seconds(15)
                )
            } catch {
                return
            }
        }
    }
}
