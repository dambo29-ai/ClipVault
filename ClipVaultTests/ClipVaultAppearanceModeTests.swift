//
//  ClipVaultAppearanceModeTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/20/26.
//

import AppKit
import SwiftUI
import Testing
@testable import ClipVault

@MainActor
struct ClipVaultAppearanceModeTests {
    @Test
    func rawValuesRemainStableForPersistence()
    {
        #expect(
            ClipVaultAppearanceMode
                .system
                .rawValue ==
                "system"
        )

        #expect(
            ClipVaultAppearanceMode
                .light
                .rawValue ==
                "light"
        )

        #expect(
            ClipVaultAppearanceMode
                .dark
                .rawValue ==
                "dark"
        )
    }

    @Test
    func invalidPersistedValueFallsBackToSystem()
    {
        #expect(
            ClipVaultAppearanceMode
                .resolved(
                    from:
                        "invalid-value"
                ) ==
                .system
        )
    }

    @Test
    func modesMapToNativeAppearances()
    {
        #expect(
            ClipVaultAppearanceMode
                .system
                .preferredColorScheme ==
                nil
        )

        #expect(
            ClipVaultAppearanceMode
                .light
                .preferredColorScheme ==
                .light
        )

        #expect(
            ClipVaultAppearanceMode
                .dark
                .preferredColorScheme ==
                .dark
        )

        #expect(
            ClipVaultAppearanceMode
                .system
                .appKitAppearance ==
                nil
        )

        #expect(
            ClipVaultAppearanceMode
                .light
                .appKitAppearance?
                .name ==
                .aqua
        )

        #expect(
            ClipVaultAppearanceMode
                .dark
                .appKitAppearance?
                .name ==
                .darkAqua
        )
    }
}
