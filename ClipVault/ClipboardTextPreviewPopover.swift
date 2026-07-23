//
//  ClipboardTextPreviewPopover.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/23/26.
//

import AppKit
import SwiftUI

struct ClipboardTextPreviewPopover:
    View
{
    let title:
        String

    let text:
        String

    let onCopy:
        () -> Void

    @State private var isCopyFeedbackVisible =
        false

    private let popoverWidth:
        CGFloat =
            560

    private let horizontalPadding:
        CGFloat =
            20

    private let verticalTextPadding:
        CGFloat =
            18

    private let headerHeight:
        CGFloat =
            40

    private let minimumTextViewportHeight:
        CGFloat =
            28

    private let maximumTextViewportHeight:
        CGFloat =
            430

    private var availableTextWidth:
        CGFloat
    {
        popoverWidth -
            (
                horizontalPadding *
                    2
            )
    }

    private var measuredTextHeight:
        CGFloat
    {
        let font =
            NSFont
                .systemFont(
                    ofSize:
                        NSFont
                            .systemFontSize
                )

        let boundingRectangle =
            (
                text as NSString
            )
            .boundingRect(
                with:
                    NSSize(
                        width:
                            availableTextWidth,
                        height:
                            .greatestFiniteMagnitude
                    ),
                options: [
                    .usesLineFragmentOrigin,
                    .usesFontLeading
                ],
                attributes: [
                    .font:
                        font
                ]
            )

        return ceil(
            boundingRectangle
                .height
        )
    }

    private var textViewportHeight:
        CGFloat
    {
        min(
            max(
                measuredTextHeight,
                minimumTextViewportHeight
            ),
            maximumTextViewportHeight
        )
    }

    private var totalPopoverHeight:
        CGFloat
    {
        headerHeight +
            1 +
            (
                verticalTextPadding *
                    2
            ) +
            textViewportHeight
    }

    var body:
        some View
    {
        VStack(
            spacing:
                0
        ) {
            header

            Divider()

            textPreview
        }
        .frame(
            width:
                popoverWidth,
            height:
                totalPopoverHeight
        )
    }

    private var header:
        some View
    {
        HStack(
            spacing:
                12
        ) {
            Text(
                title
            )
            .font(
                .headline
            )
            .lineLimit(
                1
            )
            .truncationMode(
                .middle
            )

            Spacer()

            copyButton
        }
        .frame(
            height:
                headerHeight
        )
        .padding(
            .horizontal,
            14
        )
    }

    private var textPreview:
        some View
    {
        ScrollView {
            Text(
                text
            )
            .font(
                .body
            )
            .textSelection(
                .enabled
            )
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    .topLeading
            )
        }
        .frame(
            height:
                textViewportHeight
        )
        .padding(
            .horizontal,
            horizontalPadding
        )
        .padding(
            .vertical,
            verticalTextPadding
        )
    }

    private var copyButton:
        some View
    {
        Button {
            copyText()
        } label: {
            Image(
                systemName:
                    isCopyFeedbackVisible
                        ? "checkmark"
                        : "doc.on.doc"
            )
            .foregroundStyle(
                isCopyFeedbackVisible
                    ? Color.accentColor
                    : Color.secondary
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
        .help(
            isCopyFeedbackVisible
                ? "Copied"
                : "Copy Text"
        )
        .accessibilityLabel(
            isCopyFeedbackVisible
                ? "Text copied"
                : "Copy text"
        )
    }

    private func copyText()
    {
        onCopy()

        isCopyFeedbackVisible =
            true

        Task { @MainActor in
            try? await Task.sleep(
                for:
                    .milliseconds(
                        700
                    )
            )

            isCopyFeedbackVisible =
                false
        }
    }
}
