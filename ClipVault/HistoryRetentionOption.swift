//
//  HistoryRetentionOption.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/10/26.
//

import Foundation

enum HistoryRetentionOption: String, CaseIterable, Identifiable, Codable {
    case forever
    case oneDay
    case sevenDays
    case thirtyDays
    case ninetyDays

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .forever:
            return "Forever"

        case .oneDay:
            return "1 Day"

        case .sevenDays:
            return "7 Days"

        case .thirtyDays:
            return "30 Days"

        case .ninetyDays:
            return "90 Days"
        }
    }

    var retentionInterval: TimeInterval? {
        switch self {
        case .forever:
            return nil

        case .oneDay:
            return 1 * 24 * 60 * 60

        case .sevenDays:
            return 7 * 24 * 60 * 60

        case .thirtyDays:
            return 30 * 24 * 60 * 60

        case .ninetyDays:
            return 90 * 24 * 60 * 60
        }
    }
}
