//
//  ClipboardLinkThumbnailView.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/20/26.
//

import AppKit
import SwiftUI

struct ClipboardLinkThumbnailView:
    View
{
    let url:
        URL

    let width:
        CGFloat

    let height:
        CGFloat

    let showsIdentityOverlay:
        Bool

    private let previewService:
        ClipboardLinkPreviewService

    @State private var preview:
        ClipboardLinkPreview?

    @State private var isLoading =
        true

    @MainActor
    init(
        url: URL,
        width: CGFloat = 168,
        height: CGFloat = 126,
        showsIdentityOverlay:
            Bool = true,
        previewService:
            ClipboardLinkPreviewService? =
                nil
    ) {
        self.url =
            url

        self.width =
            width

        self.height =
            height

        self.showsIdentityOverlay =
            showsIdentityOverlay

        self.previewService =
            previewService ??
            ClipboardLinkPreviewService
                .shared
    }

    var body:
        some View
    {
        ZStack {
            RoundedRectangle(
                cornerRadius:
                    8
            )
            .fill(
                Color.secondary
                    .opacity(0.08)
            )

            if
                let visualData =
                    preview?
                        .preferredVisualData,
                let image =
                    NSImage(
                        data:
                            visualData
                    )
            {
                Image(
                    nsImage:
                        image
                )
                .resizable()
                .scaledToFill()
                .frame(
                    width:
                        width,
                    height:
                        height
                )
                .clipped()
            } else {
                fallbackView
            }

            if isLoading {
                ProgressView()
                    .controlSize(
                        .small
                    )
                    .padding(8)
                    .background(
                        .regularMaterial,
                        in:
                            Circle()
                    )
            }

            if showsIdentityOverlay {
                linkIdentityOverlay
            }
        }
        .frame(
            width:
                width,
            height:
                height
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    8
            )
        )
        .task(
            id:
                url.absoluteString
        ) {
            isLoading =
                true

            preview =
                await previewService
                    .preview(
                        for:
                            url
                    )

            isLoading =
                false
        }
        .accessibilityElement(
            children:
                .ignore
        )
        .accessibilityLabel(
            accessibilityText
        )
    }

    private var fallbackView:
        some View
    {
        VStack(
            spacing:
                9
        ) {
            Image(
                systemName:
                    "globe"
            )
            .font(
                .system(
                    size:
                        38,
                    weight:
                        .light
                )
            )
            .foregroundStyle(
                .secondary
            )

            Text(
                preview?
                    .domain ??
                ClipboardLinkPreviewService
                    .domain(
                        for:
                            url
                    )
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )
            .lineLimit(1)
            .truncationMode(
                .middle
            )
            .padding(
                .horizontal,
                10
            )
        }
    }

    private var linkIdentityOverlay:
        some View
    {
        VStack {
            Spacer()

            HStack(
                spacing:
                    6
            ) {
                Image(
                    systemName:
                        "link"
                )
                .font(.caption2)

                Text(
                    preview?
                        .domain ??
                    ClipboardLinkPreviewService
                        .domain(
                            for:
                                url
                        )
                )
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(
                    .middle
                )

                Spacer()
            }
            .foregroundStyle(
                .primary
            )
            .padding(
                .horizontal,
                8
            )
            .padding(
                .vertical,
                6
            )
            .background(
                .regularMaterial
            )
        }
    }

    private var accessibilityText:
        String
    {
        let title =
            preview?
                .title ??
            "Link preview"

        let domain =
            preview?
                .domain ??
            ClipboardLinkPreviewService
                .domain(
                    for:
                        url
                )

        return
            "\(title), \(domain)"
    }
}
