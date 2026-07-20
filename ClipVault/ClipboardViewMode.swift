//
//  ClipboardViewMode.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/20/26.
//

import Foundation

enum ClipboardViewMode:
    String,
    CaseIterable,
    Identifiable
{
    case list
    case grid

    var id: Self {
        self
    }

    var systemImageName: String {
        switch self {
        case .list:
            return "list.bullet"

        case .grid:
            return "square.grid.2x2"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .list:
            return "List view"

        case .grid:
            return "Grid view"
        }
    }
}
