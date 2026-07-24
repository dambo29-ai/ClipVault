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
    
    @EnvironmentObject
    private var screenshotFolderAccessService:
        ScreenshotFolderAccessService
    
    @EnvironmentObject
    private var screenshotAutomationController:
        ScreenshotAutomationController

    @State private var hasAccessibilityPermission =
        AccessibilityPermissionService
            .isGranted
    
    @State private var isShowingSensitiveClipConfirmation =
        false
    
    @State private var screenshotAccessAlertMessage =
        ""

    @State private var isShowingScreenshotAccessAlert =
        false
    
    @State private var screenshotAutomationAlertMessage =
        ""

    @State private var isShowingScreenshotAutomationAlert =
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

            screenshotFolderAccessSetting

            Divider()

            screenshotAutomationSetting

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
        .alert(
            "Screenshot Folder Access",
            isPresented:
                $isShowingScreenshotAccessAlert
        ) {
            Button(
                "OK"
            ) {
            }
        } message: {
            Text(
                screenshotAccessAlertMessage
            )
        }
        
        .alert(
            "Screenshot Automation",
            isPresented:
                $isShowingScreenshotAutomationAlert
        ) {
            Button(
                "OK"
            ) {
            }
        } message: {
            Text(
                screenshotAutomationAlertMessage
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
    
    private var screenshotFolderAccessSetting:
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
                    "Screenshot Folder Access"
                )
                .font(
                    .body
                )
                .fontWeight(
                    .medium
                )

                Text(
                    "ClipVault detected the current macOS screenshot destination as \(screenshotFolderAccessService.destinationDescription). Grant read-only access before automatic screenshot copying can be enabled."
                )
                .font(
                    .body
                )
                .foregroundStyle(
                    .secondary
                )
                .textSelection(
                    .enabled
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
                    screenshotFolderAccessService
                        .hasAccessToCurrentDestination
                        ? "Access Granted"
                        : "Access Required",
                    systemImage:
                        screenshotFolderAccessService
                            .hasAccessToCurrentDestination
                            ? "checkmark.circle.fill"
                            : "folder.badge.questionmark"
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    screenshotFolderAccessService
                        .hasAccessToCurrentDestination
                        ? .green
                        : .secondary
                )

                Button(
                    screenshotFolderAccessService
                        .hasAccessToCurrentDestination
                        ? "Refresh Access"
                        : "Grant Access"
                ) {
                    requestScreenshotFolderAccess()
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
    
    private var screenshotAutomationSetting:
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
                    "Automatically Copy New Screenshots"
                )
                .font(
                    .body
                )
                .fontWeight(
                    .medium
                )

                Text(
                    "When enabled, ClipVault monitors the current macOS screenshot folder. New screenshots may take a few seconds to appear in ClipVault and become available for pasting. Only screenshots created after monitoring begins are considered. Screen recordings are excluded."
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
                Text(
                    screenshotAutomationController
                        .isMonitoring
                        ? "Monitoring"
                        : "Not Monitoring"
                )
                .font(
                    .body
                )
                .foregroundStyle(
                    screenshotAutomationController
                        .isMonitoring
                        ? Color.green
                        : Color.secondary
                )

                Toggle(
                    "",
                    isOn:
                        Binding(
                            get: {
                                screenshotAutomationController
                                    .isEnabled
                            },
                            set: {
                                isEnabled in

                                setScreenshotAutomationEnabled(
                                    isEnabled
                                )
                            }
                        )
                )
                .labelsHidden()
                .toggleStyle(
                    .switch
                )
                .disabled(
                    !screenshotFolderAccessService
                        .hasAccessToCurrentDestination
                )
            }
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
    
    private func setScreenshotAutomationEnabled(
        _ isEnabled:
            Bool
    ) {
        let result =
            screenshotAutomationController
                .setEnabled(
                    isEnabled
                )

        switch result {
        case .enabled,
             .disabled:
            return

        case .accessRequired:
            screenshotAutomationAlertMessage =
                "Grant read-only access to the current macOS screenshot folder before enabling automatic screenshot copying."

        case .clipboardDestination:
            screenshotAutomationAlertMessage =
                "macOS is already configured to place screenshots directly on the clipboard. Folder monitoring is not needed."

        case let .unsupportedDestination(
            destinationName
        ):
            screenshotAutomationAlertMessage =
                "The current macOS screenshot destination, \(destinationName), cannot be monitored by ClipVault."

        case let .monitorStartFailed(
            startResult
        ):
            switch startResult {
            case .securityScopedAccessFailed:
                screenshotAutomationAlertMessage =
                    "ClipVault could not begin security-scoped access to the screenshot folder. Refresh folder access and try again."

            case .folderOpenFailed:
                screenshotAutomationAlertMessage =
                    "ClipVault could not open the screenshot folder for monitoring. Refresh folder access and try again."

            case .started,
                 .alreadyMonitoring:
                screenshotAutomationAlertMessage =
                    "ClipVault could not start screenshot monitoring."
            }
        }

        isShowingScreenshotAutomationAlert =
            true
    }
    
    private func requestScreenshotFolderAccess()
    {
        let result =
            screenshotFolderAccessService
                .requestAccess()

        switch result {
        case .granted:
            screenshotAccessAlertMessage =
                "ClipVault now has read-only access to the current macOS screenshot folder."

            _ =
                screenshotAutomationController
                    .refreshAfterFolderAccessChange()

        case .cancelled:
            return

        case .clipboardDestination:
            screenshotAccessAlertMessage =
                "macOS is currently configured to place screenshots directly on the clipboard. Folder monitoring is not needed for this destination."

        case let .unsupportedDestination(
            destinationName
        ):
            screenshotAccessAlertMessage =
                "The current macOS screenshot destination, \(destinationName), cannot be monitored by ClipVault."

        case let .incorrectFolder(
            expected,
            selected
        ):
            screenshotAccessAlertMessage =
                """
                ClipVault expected access to:

                \(expected.path)

                You selected:

                \(selected.path)

                ClipVault did not change the macOS screenshot destination or save access to the selected folder.
                """

        case .bookmarkCreationFailed:
            screenshotAccessAlertMessage =
                "ClipVault could not save persistent read-only access to the screenshot folder."
        }

        isShowingScreenshotAccessAlert =
            true
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
