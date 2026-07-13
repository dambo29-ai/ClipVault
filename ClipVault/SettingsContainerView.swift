//
//  SettingsContainerView.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/10/26.
//

import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case appRules

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .general:
            return "General"

        case .appRules:
            return "App Rules"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "gearshape"

        case .appRules:
            return "shield.lefthalf.filled"
        }
    }
}

struct SettingsContainerView: View {
    @State private var selectedSection: SettingsSection = .general

    private let sidebarWidth: CGFloat = 170

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            selectedDetailView
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
        }
        .frame(
            minWidth: 820,
            idealWidth: 900,
            minHeight: 620,
            idealHeight: 700
        )
        .onAppear {
            selectedSection = .general
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: section.systemImage)
                            .frame(width: 16, alignment: .center)

                        Text(section.title)

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 30)
                    .padding(.horizontal, 10)
                    .contentShape(Rectangle())
                    .foregroundStyle(
                        selectedSection == section
                            ? Color.white
                            : Color.primary
                    )
                    .background {
                        if selectedSection == section {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .frame(width: sidebarWidth)
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxHeight: .infinity)
        .layoutPriority(1)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var selectedDetailView: some View {
        switch selectedSection {
        case .general:
            GeneralSettingsView()

        case .appRules:
            AppRulesSettingsView()
        }
    }
}
