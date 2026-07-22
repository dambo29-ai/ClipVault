//
//  PrivacySettingsView.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/22/26.
//

import SwiftUI
import AppKit

struct PrivacySettingsView:
    View
{
    @EnvironmentObject
    private var optionSelectionGestureMonitor:
        OptionSelectionGestureMonitor
    
    @EnvironmentObject
    private var clipboardStore:
        ClipboardStore

    @State private var hasAccessibilityPermission =
        AccessibilityPermissionService
            .isGranted
    
    @State private var isShowingSensitiveClipConfirmation =
        false

    private let controlColumnWidth:
        CGFloat =
            170

    var body:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                22
        ) {
            sensitiveClipProtectionSetting

            Divider()

            selectionCaptureEnabledSetting

            Divider()

            selectionCapturePermissionSetting

            Divider()

            linkPreviewPrivacySetting
        }
        .padding(
            .horizontal,
            28
        )
        .padding(
            .vertical,
            24
        )
        .frame(
            maxWidth:
                .infinity,
            alignment:
                .topLeading
        )
        .onAppear {
            refreshAccessibilityPermission()
        }
        .onReceive(
            NotificationCenter
                .default
                .publisher(
                    for:
                        NSApplication
                            .didBecomeActiveNotification
                )
        ) {
            _ in

            refreshAccessibilityPermission()
        }
        .alert(
            "Allow Likely Sensitive Clips?",
            isPresented:
                $isShowingSensitiveClipConfirmation
        ) {
            Button(
                "Cancel",
                role:
                    .cancel
            ) {
            }

            Button(
                "Allow Sensitive Clips"
            ) {
                clipboardStore
                    .setBlocksLikelySensitiveClips(
                        false
                    )
            }
        } message: {
            Text(
                "Likely passwords and other sensitive-looking text may be stored in ClipVault history, retained across launches, and included in ClipVault backups. Smart and Blocked app rules will remain protective."
            )
        }
    }
    
    private var sensitiveClipProtectionSetting:
        some View
    {
        HStack(
            alignment:
                .top,
            spacing:
                18
        ) {
            VStack(
                alignment:
                    .leading,
                spacing:
                    5
            ) {
                Text(
                    "Block Likely Sensitive Clips"
                )
                .font(
                    .body
                )
                .fontWeight(
                    .medium
                )

                Text(
                    "Likely passwords and other sensitive-looking text remain available in the system clipboard but are not saved to ClipVault history. Smart and Blocked app rules always retain their own protection."
                )
                .font(
                    .body
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            Toggle(
                "",
                isOn:
                    Binding(
                        get: {
                            clipboardStore
                                .blocksLikelySensitiveClips
                        },
                        set: {
                            newValue in

                            setSensitiveClipProtectionEnabled(
                                newValue
                            )
                        }
                    )
            )
            .labelsHidden()
            .toggleStyle(
                .switch
            )
            .frame(
                width:
                    controlColumnWidth,
                alignment:
                    .trailing
            )
        }
    }

    private var selectionCaptureEnabledSetting:
        some View
    {
        HStack(
            alignment:
                .top
        ) {
            VStack(
                alignment:
                    .leading,
                spacing:
                    5
            ) {
                Text(
                    "Enable Option-Select Capture"
                )
                .font(
                    .body
                )
                .fontWeight(
                    .medium
                )

                Text(
                    "Hold Option while selecting text to copy it, make it ready to paste, and save accepted text to ClipVault history."
                )
                .font(
                    .body
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            Toggle(
                "",
                isOn:
                    Binding(
                        get: {
                            optionSelectionGestureMonitor
                                .isCaptureEnabled
                        },
                        set: {
                            isEnabled in

                            setOptionSelectCaptureEnabled(
                                isEnabled
                            )
                        }
                    )
            )
            .labelsHidden()
            .toggleStyle(
                .switch
            )
            .frame(
                width:
                    controlColumnWidth,
                alignment:
                    .trailing
            )
        }
    }

    private var selectionCapturePermissionSetting:
        some View
    {
        HStack(
            alignment:
                .top
        ) {
            VStack(
                alignment:
                    .leading,
                spacing:
                    5
            ) {
                Text(
                    "Selection Capture Permission"
                )
                .font(
                    .body
                )
                .fontWeight(
                    .medium
                )

                Text(
                    "Accessibility permission is required only for Option-selection capture. Normal Command-C clipboard monitoring does not require it."
                )
                .font(
                    .body
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            VStack(
                alignment:
                    .trailing,
                spacing:
                    9
            ) {
                Label(
                    hasAccessibilityPermission
                        ? "Access Granted"
                        : "Access Not Granted",
                    systemImage:
                        hasAccessibilityPermission
                            ? "checkmark.circle.fill"
                            : "exclamationmark.triangle.fill"
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    hasAccessibilityPermission
                        ? .green
                        : .secondary
                )

                Button(
                    hasAccessibilityPermission
                        ? "Refresh Status"
                        : "Request Access"
                ) {
                    if hasAccessibilityPermission {
                        refreshAccessibilityPermission()
                    } else {
                        AccessibilityPermissionService
                            .requestAccessAndOpenSettings()

                        DispatchQueue
                            .main
                            .asyncAfter(
                                deadline:
                                    .now() +
                                    1.0
                            ) {
                                refreshAccessibilityPermission()
                            }
                    }
                }
            }
            .frame(
                width:
                    controlColumnWidth,
                alignment:
                    .trailing
            )
        }
    }

    private var linkPreviewPrivacySetting:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                5
        ) {
            Text(
                "Link Preview Privacy"
            )
            .font(
                .body
            )
            .fontWeight(
                .medium
            )

            Text(
                "ClipVault may contact a copied link’s website to retrieve native preview information. Preview data is cached locally."
            )
            .font(
                .body
            )
            .foregroundStyle(
                .secondary
            )
        }
    }
    
    private func setSensitiveClipProtectionEnabled(
        _ isEnabled:
            Bool
    ) {
        if isEnabled {
            clipboardStore
                .setBlocksLikelySensitiveClips(
                    true
                )

            return
        }

        /*
         Keep the persisted preference enabled until the
         user explicitly confirms the reduced protection.
         Because the binding still reads true, cancelling
         leaves the switch in its original state.
         */
        isShowingSensitiveClipConfirmation =
            true
    }

    private func setOptionSelectCaptureEnabled(
        _ isEnabled:
            Bool
    ) {
        optionSelectionGestureMonitor
            .setCaptureEnabled(
                isEnabled
            )

        guard
            isEnabled,
            !AccessibilityPermissionService
                .isGranted
        else {
            refreshAccessibilityPermission()
            return
        }

        AccessibilityPermissionService
            .requestAccessAndOpenSettings()

        DispatchQueue
            .main
            .asyncAfter(
                deadline:
                    .now() +
                    1.0
            ) {
                refreshAccessibilityPermission()
            }
    }

    private func refreshAccessibilityPermission()
    {
        hasAccessibilityPermission =
            AccessibilityPermissionService
                .isGranted
    }
}
