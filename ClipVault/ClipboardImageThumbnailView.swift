//
//  ClipboardImageThumbnailView.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/16/26.
//

import AppKit
import SwiftUI

@MainActor
struct ClipboardImageThumbnailView: View {
    let payload: ClipboardImagePayload
    let width: CGFloat
    let height: CGFloat

    private let imageStorageService:
        ClipboardImageStorageService

    @State private var thumbnailImage:
        NSImage?

    @State private var isLoading = true
    @State private var didFail = false

    init(
        payload: ClipboardImagePayload,
        width: CGFloat = 96,
        height: CGFloat = 72,
        imageStorageService:
            ClipboardImageStorageService =
                .shared
    ) {
        self.payload = payload
        self.width = width
        self.height = height
        self.imageStorageService =
            imageStorageService
    }

    var body: some View {
        ZStack {
            checkerboardBackground

            if let thumbnailImage {
                Image(
                    nsImage:
                        thumbnailImage
                )
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .padding(3)
            } else if didFail {
                Image(
                    systemName:
                        "photo.badge.exclamationmark"
                )
                .font(.title2)
                .foregroundStyle(.secondary)
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(
            width: width,
            height: height
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 6
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 6
            )
            .stroke(
                Color.secondary.opacity(
                    0.25
                ),
                lineWidth: 1
            )
        }
        .task(
            id: payload.storageIdentifier
        ) {
            await loadThumbnail()
        }
        .accessibilityLabel(
            "Image thumbnail"
        )
    }

    private var checkerboardBackground:
        some View
    {
        Canvas {
            context,
            size in

            let tileSize = 8.0
            let columnCount =
                Int(
                    ceil(
                        size.width /
                        tileSize
                    )
                )

            let rowCount =
                Int(
                    ceil(
                        size.height /
                        tileSize
                    )
                )

            for row in 0..<rowCount {
                for column in
                    0..<columnCount
                {
                    let isAlternate =
                        (row + column)
                            .isMultiple(of: 2)

                    let rectangle =
                        CGRect(
                            x:
                                Double(column) *
                                tileSize,
                            y:
                                Double(row) *
                                tileSize,
                            width: tileSize,
                            height: tileSize
                        )

                    let fillColor =
                        isAlternate
                            ? Color(
                                nsColor:
                                    .controlBackgroundColor
                            )
                            : Color.secondary
                                .opacity(0.10)

                    context.fill(
                        Path(rectangle),
                        with:
                            .color(
                                fillColor
                            )
                    )
                }
            }
        }
    }

    private func loadThumbnail()
        async
    {
        isLoading = true
        didFail = false
        thumbnailImage = nil

        do {
            let imageData =
                try await
                    imageStorageService
                        .loadImageData(
                            for: payload
                        )

            guard
                let loadedImage =
                    NSImage(
                        data: imageData
                    )
            else {
                isLoading = false
                didFail = true
                return
            }

            thumbnailImage =
                loadedImage

            isLoading = false
        } catch {
            isLoading = false
            didFail = true
        }
    }
}
