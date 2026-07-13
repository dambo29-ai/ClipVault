//
//  AppRuleModels.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/10/26.
//
//

import Foundation

enum AppRuleMode: String, CaseIterable, Identifiable, Codable {
    case allowed
    case smart
    case blocked

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .allowed:
            return "Allowed"

        case .smart:
            return "Smart"

        case .blocked:
            return "Blocked"
        }
    }
}

struct AppRuleOption: Identifiable, Hashable {
    let id: String
    let displayName: String
    let bundleIdentifiers: [String]
    let iconFilePath: String?
}

struct KnownAppRecord: Codable {
    let displayName: String
    let bundleIdentifier: String
    let appPath: String?
    let groupID: String
}
