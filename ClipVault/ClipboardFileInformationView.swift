//
//  ClipboardFileInformationView.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/21/26.
//

import AppKit
import SwiftUI
import QuickLookUI

private struct EmbeddedQuickLookView:
    NSViewRepresentable
{
    let previewURL:
        URL

    func makeNSView(
        context:
            Context
    ) -> QLPreviewView {
        let previewView =
            QLPreviewView(
                frame:
                    .zero,
                style:
                    .normal
            )!

        previewView.autostarts =
            true

        previewView.previewItem =
            previewURL
                as NSURL

        return previewView
    }

    func updateNSView(
        _ previewView:
            QLPreviewView,
        context:
            Context
    ) {
        let currentURL =
            (
                previewView
                    .previewItem
                    as? NSURL
            ) as URL?

        guard
            currentURL !=
                previewURL
        else {
            return
        }

        previewView.previewItem =
            previewURL
                as NSURL
    }
}

struct ClipboardFileInformationView:
    View
{
    let information:
        ClipboardFileInformation

    var body:
        some View
    {
        VStack(
            spacing:
                0
        ) {
            EmbeddedQuickLookView(
                previewURL:
                    information
                        .originalURL
            )
            .frame(
                minWidth:
                    640,
                maxWidth:
                    .infinity,
                minHeight:
                    360,
                maxHeight:
                    .infinity
            )

            Divider()

            metadataSection
        }
        .frame(
            width:
                860,
            height:
                650
        )
        .background(
            Color(
                nsColor:
                    .windowBackgroundColor
            )
        )
    }
    
    private var metadataSection:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                14
        ) {
            HStack(
                alignment:
                    .firstTextBaseline,
                spacing:
                    16
            ) {
                Text(
                    information
                        .displayName
                )
                .font(
                    .title2
                )
                .fontWeight(
                    .semibold
                )
                .lineLimit(
                    1
                )
                .truncationMode(
                    .middle
                )
                .textSelection(
                    .enabled
                )

                Spacer()

                Button(
                    "Close"
                ) {
                    NSApp.keyWindow?
                        .performClose(
                            nil
                        )
                }
                .keyboardShortcut(
                    .cancelAction
                )
            }

            Grid(
                alignment:
                    .leading,
                horizontalSpacing:
                    16,
                verticalSpacing:
                    8
            ) {
                metadataRow(
                    title:
                        "Kind",
                    value:
                        information
                            .kindDescription
                )

                if let byteCountText =
                    information
                        .byteCountText
                {
                    metadataRow(
                        title:
                            "Size",
                        value:
                            byteCountText
                    )
                }

                if let itemCountText =
                    information
                        .itemCountText
                {
                    metadataRow(
                        title:
                            "Contents",
                        value:
                            itemCountText
                    )
                }

                if let modifiedDate =
                    information
                        .modifiedDate
                {
                    metadataRow(
                        title:
                            "Modified",
                        value:
                            modifiedDate
                                .formatted(
                                    date:
                                        .abbreviated,
                                    time:
                                        .shortened
                                )
                    )
                }

                metadataRow(
                    title:
                        "Location",
                    value:
                        information
                            .originalURL
                            .deletingLastPathComponent()
                            .path
                )

                if let destination =
                    information
                        .destination
                {
                    metadataRow(
                        title:
                            "Destination",
                        value:
                            destination
                    )
                }

                if let destinationStatusText =
                    information
                        .destinationStatusText
                {
                    metadataRow(
                        title:
                            "Destination Status",
                        value:
                            destinationStatusText
                    )
                }
            }
        }
        .padding(
            .horizontal,
            24
        )
        .padding(
            .vertical,
            18
        )
    }

    private func metadataRow(
        title:
            String,
        value:
            String
    ) -> some View {
        GridRow {
            Text(
                title
            )
            .fontWeight(
                .medium
            )
            .foregroundStyle(
                .secondary
            )
            .gridColumnAlignment(
                .trailing
            )

            Text(
                value
            )
            .lineLimit(
                1
            )
            .truncationMode(
                .middle
            )
            .textSelection(
                .enabled
            )
            .help(
                value
            )
            .gridColumnAlignment(
                .leading
            )
        }
    }
}
