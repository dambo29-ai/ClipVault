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
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.text)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    metadataView
                }
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
                Button("Copy") {
                    onCopy()
                }

                if isLink {
                    Button("Open Link") {
                        openLink()
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

                Button("Delete", role: .destructive) {
                    onDelete()
                }
            }

            if isLink {
                openLinkButton
            }

            pinButton

            deleteButton
                .help("Delete this clipboard item")
                .accessibilityLabel("Delete clipboard item")
        }
    }
    
    private var isLink: Bool {
        item.kind == .normal &&
        item.contentKind == .link
    }

    private var linkURL: URL? {
        guard isLink else {
            return nil
        }

        let trimmedText =
            item.text.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return URL(string: trimmedText)
    }

    private func openLink() {
        guard let linkURL else {
            return
        }

        NSWorkspace.shared.open(linkURL)
    }

    private var sensitiveSkippedRow: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.text)
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
