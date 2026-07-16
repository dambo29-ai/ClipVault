//
//  ClipboardClearScopeService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/15/26.
//

import Foundation

enum ClipboardClearContentScope:
    Equatable,
    Sendable
{
    case all
    case text
    case links
    case images
    case files
}

struct ClipboardClearScopeResult:
    Equatable,
    Sendable
{
    let normalItems: [ClipboardItem]
    let warningItems: [ClipboardItem]

    var allItems: [ClipboardItem] {
        normalItems + warningItems
    }

    var unpinnedNormalItems: [ClipboardItem] {
        normalItems.filter {
            !$0.isPinned
        }
    }

    var pinnedNormalItems: [ClipboardItem] {
        normalItems.filter {
            $0.isPinned
        }
    }

    var allItemIDs: Set<UUID> {
        Set(
            allItems.map(\.id)
        )
    }

    var unpinnedItemIDsIncludingWarnings: Set<UUID> {
        Set(
            unpinnedNormalItems.map(\.id) +
            warningItems.map(\.id)
        )
    }

    var normalItemCount: Int {
        normalItems.count
    }

    var unpinnedNormalItemCount: Int {
        unpinnedNormalItems.count
    }

    var pinnedNormalItemCount: Int {
        pinnedNormalItems.count
    }

    var warningCount: Int {
        warningItems.count
    }

    var isEmpty: Bool {
        normalItems.isEmpty &&
        warningItems.isEmpty
    }
}

enum ClipboardClearScopeService {
    static func result(
        from items: [ClipboardItem],
        contentScope: ClipboardClearContentScope,
        searchText: String
    ) -> ClipboardClearScopeResult {
        let contentScopedItems =
            items.filter {
                itemMatchesContentScope(
                    $0,
                    contentScope: contentScope
                )
            }

        let trimmedSearchText =
            searchText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let searchScopedItems: [ClipboardItem]

        if trimmedSearchText.isEmpty {
            searchScopedItems =
                contentScopedItems
        } else {
            searchScopedItems =
                contentScopedItems.filter {
                    $0.text.localizedCaseInsensitiveContains(
                        trimmedSearchText
                    )
                }
        }

        return ClipboardClearScopeResult(
            normalItems:
                searchScopedItems.filter {
                    $0.kind == .normal
                },
            warningItems:
                searchScopedItems.filter {
                    $0.kind != .normal
                }
        )
    }

    private static func itemMatchesContentScope(
        _ item: ClipboardItem,
        contentScope: ClipboardClearContentScope
    ) -> Bool {
        switch contentScope {
        case .all:
            return true

        case .text:
            guard item.kind == .normal else {
                return true
            }

            return
                !ClipboardLinkClassificationService.isLink(
                    item.text
                )

        case .links:
            guard item.kind == .normal else {
                return false
            }

            return
                ClipboardLinkClassificationService.isLink(
                    item.text
                )

        case .images, .files:
            return false
        }
    }
}
