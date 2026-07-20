//
//  ClipboardViewModeTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/20/26.
//

import Testing
@testable import ClipVault

struct ClipboardViewModeTests {
    @Test
    func rawValuesRemainStableForPersistence()
    {
        #expect(
            ClipboardViewMode
                .list
                .rawValue ==
                "list"
        )

        #expect(
            ClipboardViewMode
                .grid
                .rawValue ==
                "grid"
        )
    }

    @Test
    func persistedRawValuesRestoreViewModes()
        throws
    {
        let listMode =
            try #require(
                ClipboardViewMode(
                    rawValue:
                        "list"
                )
            )

        let gridMode =
            try #require(
                ClipboardViewMode(
                    rawValue:
                        "grid"
                )
            )

        #expect(
            listMode ==
                .list
        )

        #expect(
            gridMode ==
                .grid
        )
    }
}
