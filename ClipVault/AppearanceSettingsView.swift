//
//  AppearanceSettingsView.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/20/26.
//

import SwiftUI

struct AppearanceSettingsView:
    View
{
    @AppStorage(
        ClipVaultAppearanceMode
            .defaultsKey
    )
    private var appearanceModeRawValue =
        ClipVaultAppearanceMode
            .system
            .rawValue

    private var appearanceMode:
        ClipVaultAppearanceMode
    {
        get {
            ClipVaultAppearanceMode
                .resolved(
                    from:
                        appearanceModeRawValue
                )
        }

        nonmutating set {
            appearanceModeRawValue =
                newValue.rawValue

            newValue
                .applyToApplication()
        }
    }

    var body:
        some View
    {
            VStack(
                alignment:
                    .center,
                spacing:
                    24
            ) {
                Text(
                    "Choose how ClipVault appears. This setting changes ClipVault only and does not alter the appearance of macOS or other applications."
                )
                .font(
                    .body
                )
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )
                .frame(
                    maxWidth:
                        520
                )

                appearanceOptions
            }
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    .top
            )
            .padding(
                .horizontal,
                24
            )
            .padding(
                .top,
                30
            )
            .padding(
                .bottom,
                24
            )
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    .top
            )
    }

    private var appearanceOptions:
        some View
    {
        HStack(
            alignment:
                .top,
            spacing:
                14
        ) {
            ForEach(
                ClipVaultAppearanceMode
                    .allCases
            ) {
                mode in

                appearanceOption(
                    mode
                )
            }
        }
    }

    private func appearanceOption(
        _ mode:
            ClipVaultAppearanceMode
    ) -> some View {
        Button {
            appearanceMode =
                mode
        } label: {
            VStack(
                spacing:
                    12
            ) {
                ZStack {
                    RoundedRectangle(
                        cornerRadius:
                            12
                    )
                    .fill(
                        previewBackground(
                            for:
                                mode
                        )
                    )

                    VStack(
                        spacing:
                            9
                    ) {
                        HStack(
                            spacing:
                                6
                        ) {
                            Circle()
                                .fill(
                                    previewSecondary(
                                        for:
                                            mode
                                    )
                                )
                                .frame(
                                    width:
                                        8,
                                    height:
                                        8
                                )

                            RoundedRectangle(
                                cornerRadius:
                                    3
                            )
                            .fill(
                                previewSecondary(
                                    for:
                                        mode
                                )
                            )
                            .frame(
                                width:
                                    58,
                                height:
                                    7
                            )

                            Spacer()
                        }

                        RoundedRectangle(
                            cornerRadius:
                                6
                        )
                        .fill(
                            previewSurface(
                                for:
                                    mode
                            )
                        )
                        .frame(
                            height:
                                42
                        )

                        HStack(
                            spacing:
                                6
                        ) {
                            RoundedRectangle(
                                cornerRadius:
                                    3
                            )
                            .fill(
                                previewSecondary(
                                    for:
                                        mode
                                )
                            )
                            .frame(
                                height:
                                    7
                            )

                            RoundedRectangle(
                                cornerRadius:
                                    3
                            )
                            .fill(
                                Color.accentColor
                            )
                            .frame(
                                width:
                                    24,
                                height:
                                    7
                            )
                        }
                    }
                    .padding(14)
                }
                .frame(
                    width:
                        150,
                    height:
                        104
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius:
                            12
                    )
                    .stroke(
                        appearanceMode ==
                            mode
                            ? Color.accentColor
                            : Color.secondary
                                .opacity(0.25),
                        lineWidth:
                            appearanceMode ==
                                mode
                                ? 2
                                : 1
                    )
                }

                HStack(
                    spacing:
                        6
                ) {
                    Image(
                        systemName:
                            mode
                                .systemImageName
                    )

                    Text(
                        mode
                            .displayName
                    )
                    .font(
                        .body
                    )
                    .fontWeight(
                        appearanceMode ==
                            mode
                            ? .semibold
                            : .regular
                    )
                }

                Text(
                    mode.description
                )
                .font(
                    .body
                )
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )
                .frame(
                    width:
                        150
                )
            }
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            mode.displayName
        )
        .accessibilityValue(
            appearanceMode ==
                mode
                ? "Selected"
                : "Not selected"
        )
    }

    private func previewBackground(
        for mode:
            ClipVaultAppearanceMode
    ) -> Color {
        switch mode {
        case .system:
            return Color(
                nsColor:
                    .windowBackgroundColor
            )

        case .light:
            return Color(
                white:
                    0.93
            )

        case .dark:
            return Color(
                white:
                    0.12
            )
        }
    }

    private func previewSurface(
        for mode:
            ClipVaultAppearanceMode
    ) -> Color {
        switch mode {
        case .system:
            return Color(
                nsColor:
                    .controlBackgroundColor
            )

        case .light:
            return .white

        case .dark:
            return Color(
                white:
                    0.22
            )
        }
    }

    private func previewSecondary(
        for mode:
            ClipVaultAppearanceMode
    ) -> Color {
        switch mode {
        case .system:
            return Color(
                nsColor:
                    .secondaryLabelColor
            )
            .opacity(0.7)

        case .light:
            return Color.black
                .opacity(0.45)

        case .dark:
            return Color.white
                .opacity(0.55)
        }
    }
}
