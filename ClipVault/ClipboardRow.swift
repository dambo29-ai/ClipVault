//
//  ClipboardRow.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/10/26.
//

import SwiftUI

struct ClipboardRow: View {
    let item: ClipboardItem
    let displayNumber: Int?
    let onCopy: () -> Void
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
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            deleteButton
                .help("Delete this clipboard item")
                .accessibilityLabel("Delete clipboard item")
        }
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
