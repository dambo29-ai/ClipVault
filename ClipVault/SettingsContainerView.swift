//
//  SettingsContainerView.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/10/26.
//

import SwiftUI

private enum SettingsSection:
    String,
    Hashable
{
    case general
    case appearance
    case privacy
    case appRules

    var usesFixedHeight:
        Bool
    {
        self ==
            .appRules
    }
}

private struct SettingsContentHeightPreferenceKey:
    PreferenceKey
{
    static var defaultValue:
        [SettingsSection: CGFloat] =
            [:]

    static func reduce(
        value:
            inout [SettingsSection: CGFloat],
        nextValue:
            () -> [SettingsSection: CGFloat]
    ) {
        value
            .merge(
                nextValue(),
                uniquingKeysWith: {
                    _,
                    newValue in

                    newValue
                }
            )
    }
}

private extension View
{
    func reportSettingsContentHeight(
        for section:
            SettingsSection
    ) -> some View {
        background {
            GeometryReader {
                geometry in

                Color.clear
                    .preference(
                        key:
                            SettingsContentHeightPreferenceKey
                                .self,
                        value: [
                            section:
                                geometry
                                    .size
                                    .height
                        ]
                    )
            }
        }
    }
}

struct SettingsContainerView:
    View
{
    @State private var selectedSection:
        SettingsSection =
            .general

    @State private var measuredContentHeights:
        [SettingsSection: CGFloat] =
            [:]

    /*
     The TabView toolbar/titlebar region is outside the
     measured page content. This constant accounts for
     that native macOS Settings chrome.
     */
    private let settingsChromeHeight:
        CGFloat =
            10

    private let minimumWindowHeight:
        CGFloat =
            280

    private let maximumAutomaticWindowHeight:
        CGFloat =
            680

    private let appRulesWindowHeight:
        CGFloat =
            680

    private var selectedWindowHeight:
        CGFloat
    {
        if selectedSection
            .usesFixedHeight
        {
            return appRulesWindowHeight
        }

        let measuredContentHeight =
            measuredContentHeights[
                selectedSection
            ] ??
            defaultContentHeight(
                for:
                    selectedSection
            )

        return min(
            max(
                measuredContentHeight +
                    settingsChromeHeight,
                minimumWindowHeight
            ),
            maximumAutomaticWindowHeight
        )
    }

    var body:
        some View
    {
        TabView(
            selection:
                $selectedSection
        ) {
            Tab(
                "General",
                systemImage:
                    "gearshape",
                value:
                    SettingsSection.general
            ) {
                VStack(
                    spacing:
                        0
                ) {
                    GeneralSettingsView()
                        .fixedSize(
                            horizontal:
                                false,
                            vertical:
                                true
                        )
                        .reportSettingsContentHeight(
                            for:
                                .general
                        )

                    Spacer(
                        minLength:
                            0
                    )
                }
                .frame(
                    maxWidth:
                        .infinity,
                    maxHeight:
                        .infinity,
                    alignment:
                        .top
                )
            }

            Tab(
                "Appearance",
                systemImage:
                    "paintbrush",
                value:
                    SettingsSection.appearance
            ) {
                VStack(
                    spacing:
                        0
                ) {
                    AppearanceSettingsView()
                        .fixedSize(
                            horizontal:
                                false,
                            vertical:
                                true
                        )
                        .reportSettingsContentHeight(
                            for:
                                .appearance
                        )

                    Spacer(
                        minLength:
                            0
                    )
                }
                .frame(
                    maxWidth:
                        .infinity,
                    maxHeight:
                        .infinity,
                    alignment:
                        .top
                )
            }

            Tab(
                "Privacy",
                systemImage:
                    "hand.raised",
                value:
                    SettingsSection.privacy
            ) {
                VStack(
                    spacing:
                        0
                ) {
                    PrivacySettingsView()
                        .fixedSize(
                            horizontal:
                                false,
                            vertical:
                                true
                        )
                        .reportSettingsContentHeight(
                            for:
                                .privacy
                        )

                    Spacer(
                        minLength:
                            0
                    )
                }
                .frame(
                    maxWidth:
                        .infinity,
                    maxHeight:
                        .infinity,
                    alignment:
                        .top
                )
            }

            Tab(
                "App Rules",
                systemImage:
                    "shield.lefthalf.filled",
                value:
                    SettingsSection.appRules
            ) {
                AppRulesSettingsView()
            }
        }
        .frame(
            width:
                700,
            height:
                selectedWindowHeight
        )
        .onPreferenceChange(
            SettingsContentHeightPreferenceKey
                .self
        ) {
            newHeights in

            for (
                section,
                height
            ) in newHeights {
                guard
                    height >
                        0
                else {
                    continue
                }

                measuredContentHeights[
                    section
                ] =
                    height
            }
        }
        .animation(
            .easeInOut(
                duration:
                    0.18
            ),
            value:
                selectedWindowHeight
        )
    }

    private func defaultContentHeight(
        for section:
            SettingsSection
    ) -> CGFloat {
        switch section {
        case .general:
            return 420

        case .appearance:
            return 230

        case .privacy:
            return 320

        case .appRules:
            return appRulesWindowHeight
        }
    }
}
