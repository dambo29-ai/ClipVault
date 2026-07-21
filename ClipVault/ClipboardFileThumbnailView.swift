//
//  ClipboardFileThumbnailView.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/20/26.
//

import AppKit
import SwiftUI

struct ClipboardFileThumbnailView:
    View
{
    let payload:
        ClipboardFilesPayload

    let width:
        CGFloat

    let height:
        CGFloat

    let availability:
        ClipboardFileAvailabilityStatus

    private let visualService:
        ClipboardFileVisualService

    @State private var visual:
        ClipboardFileVisual?

    @State private var isLoading =
        true

    @Environment(\.displayScale)
    private var displayScale

    @MainActor
    init(
        payload:
            ClipboardFilesPayload,
        width:
            CGFloat,
        height:
            CGFloat,
        availability:
            ClipboardFileAvailabilityStatus,
        visualService:
            ClipboardFileVisualService? =
                nil
    ) {
        self.payload =
            payload

        self.width =
            width

        self.height =
            height

        self.availability =
            availability

        self.visualService =
            visualService ??
            ClipboardFileVisualService
                .shared
    }

    var body:
        some View
    {
        ZStack(
            alignment:
                .bottomTrailing
        ) {
            RoundedRectangle(
                cornerRadius:
                    8
            )
            .fill(
                Color.secondary
                    .opacity(0.08)
            )

            if let visual {
                Image(
                    nsImage:
                        visual.image
                )
                .resizable()
                .aspectRatio(
                    contentMode:
                        visual.source ==
                            .quickLookThumbnail
                            ? .fill
                            : .fit
                )
                .frame(
                    width:
                        width,
                    height:
                        height
                )
                .padding(
                    visual.source ==
                        .workspaceIcon
                        ? 13
                        : 0
                )
                .clipped()
                .opacity(
                    availability ==
                        .unavailable
                        ? 0.48
                        : 1
                )
            } else {
                Image(
                    systemName:
                        "doc.fill"
                )
                .font(
                    .system(
                        size:
                            min(
                                width,
                                height
                            ) * 0.42
                    )
                )
                .foregroundStyle(
                    .secondary
                )
            }

            if isLoading {
                ProgressView()
                    .controlSize(
                        .small
                    )
                    .padding(7)
                    .background(
                        .regularMaterial,
                        in:
                            Circle()
                    )
                    .frame(
                        maxWidth:
                            .infinity,
                        maxHeight:
                            .infinity,
                        alignment:
                            .center
                    )
            }

            if payload.files.count > 1 {
                Text(
                    "\(payload.files.count)"
                )
                .font(.caption)
                .fontWeight(
                    .semibold
                )
                .monospacedDigit()
                .padding(
                    .horizontal,
                    7
                )
                .padding(
                    .vertical,
                    4
                )
                .background(
                    .regularMaterial,
                    in:
                        Capsule()
                )
                .padding(7)
            }

            availabilityOverlay
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
                payload
        ) {
            isLoading =
                true

            visual =
                await visualService
                    .visual(
                        for:
                            payload,
                        size:
                            CGSize(
                                width:
                                    width,
                                height:
                                    height
                            ),
                        scale:
                            displayScale
                    )

            isLoading =
                false
        }
        .accessibilityHidden(
            true
        )
    }

    @ViewBuilder
    private var availabilityOverlay:
        some View
    {
        switch availability {
        case .available:
            EmptyView()

        case .downloading:
            Image(
                systemName:
                    "icloud.and.arrow.down"
            )
            .font(.title3)
            .foregroundStyle(
                .secondary
            )
            .padding(8)
            .background(
                .regularMaterial,
                in:
                    Circle()
            )
            .padding(6)

        case .unavailable:
            Image(
                systemName:
                    "exclamationmark.triangle.fill"
            )
            .font(.title3)
            .foregroundStyle(
                .orange
            )
            .padding(8)
            .background(
                .regularMaterial,
                in:
                    Circle()
            )
            .padding(6)
        }
    }
}
