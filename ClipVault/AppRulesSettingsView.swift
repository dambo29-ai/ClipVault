//
//  AppRulesSettingsView.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/10/26.
//

import SwiftUI

private enum AppRulesFilter: String, CaseIterable, Identifiable {
    case all
    case smartAndBlocked
    case blockedOnly
    case customOnly

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .all:
            return "All Apps"

        case .smartAndBlocked:
            return "Smart + Blocked"

        case .blockedOnly:
            return "Blocked Only"

        case .customOnly:
            return "Custom Rules Only"
        }
    }
}

struct AppRulesSettingsView: View {
    @EnvironmentObject private var clipboardStore: ClipboardStore

    @State private var searchText = ""
    @State private var selectedFilter: AppRulesFilter = .all
    @State private var showsHiddenUtilityApps = false
    @State private var isShowingHelp = false

    var body: some View {
        VStack(
            alignment:
                .leading,
            spacing:
                0
        ) {
            VStack(
                alignment:
                    .leading,
                spacing:
                    10
            ) {
                controls
                countSummary

                ScrollView {
                    appList
                        .frame(
                            maxWidth:
                                .infinity
                        )
                        .padding(
                            .bottom,
                            16
                        )
                }
                .frame(
                    minHeight:
                        390,
                    idealHeight:
                        470,
                    maxHeight:
                        .infinity
                )
            }
            .padding(
                .horizontal,
                24
            )
            .padding(
                .top,
                10
            )
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .onAppear {
            searchText = ""
        }
        .onDisappear {
            searchText = ""
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            searchField

            HStack(
                spacing:
                    10
            ) {
                Picker(
                    "Filter",
                    selection:
                        $selectedFilter
                ) {
                    ForEach(AppRulesFilter.allCases) { filter in
                        Text(filter.displayName)
                            .tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .frame(
                    width:
                        150
                )
                .labelsHidden()

                Toggle(
                    "Show Hidden Utility Apps",
                    isOn:
                        $showsHiddenUtilityApps
                )
                .font(
                    .callout
                )
                .toggleStyle(.checkbox)
                .help(
                    "Show helper apps, installers, updaters, daemons, agents, and other utility apps normally hidden from the default App Rules list."
                )
                
                Button {
                    isShowingHelp
                        .toggle()
                } label: {
                    Image(
                        systemName:
                            "info.circle"
                    )
                    .font(
                        .system(
                            size:
                                15
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
                .buttonStyle(
                    .borderless
                )
                .help(
                    "Learn about App Rule modes"
                )
                .accessibilityLabel(
                    "Learn about App Rule modes"
                )
                .popover(
                    isPresented:
                        $isShowingHelp,
                    arrowEdge:
                        .bottom
                ) {
                    helpPopover
                }

                Spacer()

                HStack(spacing: 8) {
                    if clipboardStore.isRefreshingAvailableApps {
                        ProgressView()
                            .controlSize(.small)
                            .help("Refreshing application list")
                            .accessibilityLabel("Refreshing application list")
                    }

                    Menu("Actions") {
                        Button {
                            clipboardStore.refreshAvailableApps()
                        } label: {
                            Label(
                                clipboardStore.isRefreshingAvailableApps
                                    ? "Refreshing App List…"
                                    : "Refresh App List",
                                systemImage: "arrow.clockwise"
                            )
                        }
                        .disabled(clipboardStore.isRefreshingAvailableApps)

                        Divider()

                        Button {
                            if ResetAppRulesConfirmation.shouldResetAppRules() {
                                clipboardStore.resetAppRuleModesToDefaults()
                            }
                        } label: {
                            Label(
                                "Reset App Rules to Defaults",
                                systemImage: "arrow.counterclockwise"
                            )
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .help("Refresh apps or reset App Rules")
                }
            }
        }
        .padding(
            14
        )
        .background(
            .background
                .opacity(
                    0.35
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var countSummary: some View {
        Text(
            "Allowed: \(allowedCount)  •  " +
            "Smart: \(smartCount)  •  " +
            "Blocked: \(blockedCount)  •  " +
            "Showing \(visibleCount) of \(countDenominator)"
        )
        .font(
            .footnote
        )
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var appList: some View {
        if clipboardStore.appRuleOptions.isEmpty {
            emptyState(
                icon: "app.dashed",
                message: "No apps found yet. Click Refresh or copy text from an app."
            )
        } else if filteredAppRules.isEmpty {
            emptyState(
                icon: "magnifyingglass",
                message: "No matching apps found."
            )
        } else {
            LazyVStack(spacing: 0) {
                ForEach(filteredAppRules) { appRule in
                    AppRuleRow(
                        appRule: appRule,
                        mode: clipboardStore.appRuleMode(for: appRule),
                        hasCustomMode: clipboardStore.hasCustomAppRuleMode(
                            for: appRule
                        ),
                        onChange: { newMode in
                            clipboardStore.setAppRuleMode(
                                appRule,
                                mode: newMode
                            )
                        },
                        onResetToDefault: {
                            clipboardStore.resetAppRuleModeToDefault(appRule)
                        }
                    )

                    if appRule.id != filteredAppRules.last?.id {
                        Divider()
                            .padding(.leading, 54)
                    }
                }
            }
            .background(.background.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func emptyState(
        icon: String,
        message: String
    ) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)

            Text(message)
                .font(
                    .callout
                )
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 180,
            alignment: .center
        )
        .padding(.horizontal, 24)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(
                    .body
                )
                .foregroundStyle(.secondary)

            TextField("Search apps", text: $searchText)
                .textFieldStyle(.plain)
                .font(
                    .system(
                        size:
                            15
                    )
                )

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Clear app search")
                .accessibilityLabel("Clear app search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(nsColor: .textBackgroundColor))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var helpPopover: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("App Rule Modes")
                .font(.headline)

            Text(
                "Choose how ClipVault handles copied text from each installed app."
            )
            .font(
                .callout
            )
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                helpRow(
                    title: "Allowed",
                    description:
                        "ClipVault saves copied text from this app unless the clip looks sensitive, such as a likely password or secret token."
                )

                helpRow(
                    title: "Smart",
                    description:
                        "Useful for password managers. ClipVault allows obvious emails and URLs, but skips likely passwords, tokens, API keys, and secret-looking text."
                )

                helpRow(
                    title: "Blocked",
                    description:
                        "ClipVault never saves copied text from this app. The copied text still remains available in the normal macOS system clipboard."
                )
            }
            
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(.tint)
                    .frame(width: 6, height: 6)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Custom Rule")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(
                        "A blue dot means the app’s rule has been changed from its default. Use the reset button beside it to restore the default rule."
                    )
                    .font(
                        .callout
                    )
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            Text(
                "Smart mode is helpful, but not perfect. Weak or human-readable passwords like “sunshine2026” or “mydogHarvey” may look like normal text and could still be saved."
            )
            .font(
                .callout
            )
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 360)
    }

    private func helpRow(
        title: String,
        description: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            Text(description)
                .font(
                    .callout
                )
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var allowedCount: Int {
        appRulesBeforeModeFilter.filter {
            clipboardStore.appRuleMode(for: $0) == .allowed
        }
        .count
    }

    private var smartCount: Int {
        appRulesBeforeModeFilter.filter {
            clipboardStore.appRuleMode(for: $0) == .smart
        }
        .count
    }

    private var blockedCount: Int {
        appRulesBeforeModeFilter.filter {
            clipboardStore.appRuleMode(for: $0) == .blocked
        }
        .count
    }

    private var visibleCount: Int {
        filteredAppRules.count
    }

    private var countDenominator: Int {
        appRulesBeforeModeFilter.count
    }

    private var appRulesBeforeModeFilter: [AppRuleOption] {
        let cleanedSearchText = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let matchingRules = clipboardStore.appRuleOptions.filter { appRule in
            guard !cleanedSearchText.isEmpty else {
                return true
            }

            let matchesDisplayName =
                appRule.displayName.localizedCaseInsensitiveContains(
                    cleanedSearchText
                )

            let matchesBundleIdentifier =
                appRule.bundleIdentifiers.contains { bundleIdentifier in
                    bundleIdentifier.localizedCaseInsensitiveContains(
                        cleanedSearchText
                    )
                }

            return matchesDisplayName || matchesBundleIdentifier
        }

        if cleanedSearchText.isEmpty && !showsHiddenUtilityApps {
            return matchingRules.filter { appRule in
                shouldShowByDefault(appRule)
            }
        }

        return matchingRules
    }

    private var filteredAppRules: [AppRuleOption] {
        appRulesBeforeModeFilter.filter { appRule in
            let mode = clipboardStore.appRuleMode(for: appRule)

            switch selectedFilter {
            case .all:
                return true

            case .smartAndBlocked:
                return mode == .smart || mode == .blocked

            case .blockedOnly:
                return mode == .blocked

            case .customOnly:
                return clipboardStore.hasCustomAppRuleMode(for: appRule)
            }
        }
    }

    private func shouldShowByDefault(
        _ appRule: AppRuleOption
    ) -> Bool {
        if clipboardStore.appRuleMode(for: appRule) != .allowed {
            return true
        }

        let alwaysShowGroupIDs = [
            "1password",
            "bitwarden",
            "nordpass",
            "keychain-access"
        ]

        if alwaysShowGroupIDs.contains(appRule.id) {
            return true
        }

        if appRule.id.hasPrefix("password-app-") {
            return true
        }

        let normalizedDisplayName = appRule.displayName.lowercased()

        if normalizedDisplayName.contains("password") {
            return true
        }

        let hiddenDisplayNameTerms = [
            "cleanup",
            "clean up",
            "uninstall",
            "uninstaller",
            "installer",
            "updater",
            "update helper",
            "helper",
            "daemon",
            "agent",
            "service",
            "crash reporter",
            "diagnostic",
            "diagnostics",
            "licensing",
            "quick menu",
            "background",
            "login item",
            "sync helper",
            "creative cloud helper"
        ]

        if hiddenDisplayNameTerms.contains(
            where: { normalizedDisplayName.contains($0) }
        ) {
            return false
        }

        let hiddenBundleIdentifierTerms = [
            "cleanup",
            "uninstall",
            "installer",
            "updater",
            "helper",
            "daemon",
            "agent",
            "crashreporter",
            "diagnostic",
            "licensing"
        ]

        let hasHiddenBundleIdentifier =
            appRule.bundleIdentifiers.contains { bundleIdentifier in
                let normalizedBundleIdentifier =
                    bundleIdentifier.lowercased()

                return hiddenBundleIdentifierTerms.contains { hiddenTerm in
                    normalizedBundleIdentifier.contains(hiddenTerm)
                }
            }

        if hasHiddenBundleIdentifier {
            return false
        }

        return true
    }
}
