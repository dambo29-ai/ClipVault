//
//  ClipboardFileInformationView.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/21/26.
//

import AppKit
import SwiftUI

struct ClipboardFileInformationView:
    View
{
    let information:
        ClipboardFileInformation

    private var nativeIcon:
        NSImage
    {
        NSWorkspace.shared
            .icon(
                forFile:
                    information
                        .originalURL
                        .path
            )
    }

    var body:
        some View
    {
        HStack(
            alignment:
                .center,
            spacing:
                42
        ) {
            Image(
                nsImage:
                    nativeIcon
            )
            .resizable()
            .scaledToFit()
            .frame(
                width:
                    300,
                height:
                    300
            )
            .accessibilityHidden(
                true
            )

            VStack(
                alignment:
                    .leading,
                spacing:
                    24
            ) {
                VStack(
                    alignment:
                        .leading,
                    spacing:
                        8
                ) {
                    Text(
                        information
                            .displayName
                    )
                    .font(
                        .system(
                            size:
                                32,
                            weight:
                                .semibold
                        )
                    )
                    .lineLimit(2)
                    .truncationMode(
                        .middle
                    )
                    .textSelection(
                        .enabled
                    )

                    Text(
                        summaryText
                    )
                    .font(
                        .title3
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        13
                ) {
                    if let itemCountText =
                        information.itemCountText
                    {
                        detailRow(
                            title:
                                "Contents",
                            value:
                                itemCountText
                        )
                    }

                    if let modifiedDate =
                        information.modifiedDate
                    {
                        detailRow(
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

                    detailRow(
                        title:
                            "Location",
                        value:
                            information
                                .originalURL
                                .deletingLastPathComponent()
                                .path
                    )

                    if let destination =
                        information.destination
                    {
                        detailRow(
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
                        detailRow(
                            title:
                                "Destination Status",
                            value:
                                destinationStatusText
                        )
                    }
                }

                Spacer()

                HStack {
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
            }
            .frame(
                maxWidth:
                    .infinity,
                maxHeight:
                    .infinity,
                alignment:
                    .topLeading
            )
        }
        .padding(
            44
        )
        .frame(
            width:
                860,
            height:
                520
        )
        .background(
            Color(
                nsColor:
                    .windowBackgroundColor
            )
        )
    }

    private var summaryText:
        String
    {
        let components =
            [
                information
                    .kind
                    .displayName,
                information
                    .itemCountText
            ]
            .compactMap {
                $0
            }

        return components
            .joined(
                separator:
                    " • "
            )
    }

    private func detailRow(
        title:
            String,
        value:
            String
    ) -> some View {
        HStack(
            alignment:
                .firstTextBaseline,
            spacing:
                14
        ) {
            Text(
                title
            )
            .fontWeight(
                .medium
            )
            .foregroundStyle(
                .secondary
            )
            .frame(
                width:
                    132,
                alignment:
                    .trailing
            )

            Text(
                value
            )
            .lineLimit(2)
            .truncationMode(
                .middle
            )
            .textSelection(
                .enabled
            )
            .help(
                value
            )
        }
    }
}
