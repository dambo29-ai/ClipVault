//
//  AppRuleRow.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/10/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AppRuleRow: View {
    let appRule: AppRuleOption
    let mode: AppRuleMode
    let hasCustomMode: Bool
    let onChange: (AppRuleMode) -> Void
    let onResetToDefault: () -> Void
    
    var body:
        some View
    {
        HStack(
            spacing:
                12
        ) {
            AppIconView(
                appPath:
                    appRule
                        .iconFilePath
            )

            VStack(
                alignment:
                    .leading,
                spacing:
                    3
            ) {
                Text(
                    appRule
                        .displayName
                )
                .font(
                    .body
                )
                .lineLimit(
                    1
                )

                Text(
                    bundleIdentifierSummary
                )
                .font(
                    .footnote
                )
                .foregroundStyle(
                    .secondary
                )
                .lineLimit(
                    1
                )
            }
            .frame(
                width:
                    350,
                alignment:
                    .leading
            )

            HStack(
                spacing:
                    6
            ) {
                if hasCustomMode {
                    Circle()
                        .fill(
                            .tint
                        )
                        .frame(
                            width:
                                6,
                            height:
                                6
                        )
                        .help(
                            "Custom rule"
                        )

                    Button {
                        onResetToDefault()
                    } label: {
                        Image(
                            systemName:
                                "arrow.counterclockwise"
                        )
                        .frame(
                            width:
                                18,
                            height:
                                18
                        )
                        .contentShape(
                            Rectangle()
                        )
                    }
                    .buttonStyle(
                        .borderless
                    )
                    .help(
                        "Reset this app rule to its default"
                    )
                    .accessibilityLabel(
                        "Reset this app rule to its default"
                    )
                }

                if mode ==
                    .blocked
                {
                    Image(
                        systemName:
                            "lock.fill"
                    )
                    .font(
                        .system(
                            size:
                                12
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .help(
                        "Clipboard capture is blocked for this app"
                    )
                    .accessibilityLabel(
                        "Blocked"
                    )
                }

                Picker(
                    "Mode",
                    selection:
                        Binding(
                            get: {
                                mode
                            },
                            set: {
                                newMode in

                                onChange(
                                    newMode
                                )
                            }
                        )
                ) {
                    ForEach(
                        AppRuleMode
                            .allCases
                    ) {
                        availableMode in

                        Text(
                            availableMode
                                .displayName
                        )
                        .tag(
                            availableMode
                        )
                    }
                }
                .pickerStyle(
                    .menu
                )
                .labelsHidden()
                .frame(
                    width:
                        120
                )
            }
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    .trailing
            )
        }
        .padding(
            .vertical,
            10
        )
        .padding(
            .horizontal,
            14
        )
    }
    
    private var bundleIdentifierSummary: String {
        if appRule.bundleIdentifiers.count == 1 {
            return appRule.bundleIdentifiers[0]
        } else {
            return "\(appRule.bundleIdentifiers.count) bundle identifiers"
        }
    }
}

private struct AppIconView: View {
    let appPath: String?

    var body: some View {
        Image(nsImage: AppIconCache.icon(for: appPath))
            .resizable()
            .frame(width: 32, height: 32)
    }
}

@MainActor
private enum AppIconCache {
    private static let cache = NSCache<NSString, NSImage>()
    private static let fallbackCacheKey = "__ClipVaultFallbackAppIcon__"

    static func icon(for appPath: String?) -> NSImage {
        let cacheKey = appPath ?? fallbackCacheKey

        if let cachedIcon = cache.object(
            forKey: cacheKey as NSString
        ) {
            return cachedIcon
        }

        let loadedIcon: NSImage

        if let appPath {
            loadedIcon = NSWorkspace.shared.icon(forFile: appPath)
        } else {
            loadedIcon = NSWorkspace.shared.icon(
                for: .applicationBundle
            )
        }

        cache.setObject(
            loadedIcon,
            forKey: cacheKey as NSString
        )

        return loadedIcon
    }
}
