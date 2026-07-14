//
//  ClipboardStore.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/8/26.
//

import Foundation
import AppKit
import Combine

private struct DefaultAppGroup {
    let groupID: String
    let displayName: String
    let bundleIdentifiers: [String]
}

enum ClipboardCaptureOutcome {
    case captured
    case skippedMonitoringPaused
    case skippedEmpty
    case skippedBlocked
    case skippedSensitive
}

enum ClipboardBackupImportOutcome {
    case imported(
        importedCount: Int,
        duplicateCount: Int
    )

    case exceedsHistoryLimit(
        itemsOverLimit: Int
    )
}

struct ClipboardBackupReplacementResult {
    let imported: Int
    let duplicates: Int
    let skippedDueToLimit: Int
}

@MainActor
final class ClipboardStore: ObservableObject {
    static let minimumHistoryLimit = 10
    static let maximumHistoryLimit = 500

    static let minimumBackupKeepCount = 1
    static let maximumBackupKeepCount = 50
    
    @Published var items: [ClipboardItem] = []
    @Published var isMonitoringPaused: Bool = false
    @Published private(set) var maxItemCount: Int = 100
    @Published private(set) var historyRetentionOption: HistoryRetentionOption = .forever
    @Published private(set) var showsSkippedClipWarnings: Bool = true
    @Published private(set) var backupKeepCount: Int = 5
    @Published private(set) var knownAppRecords: [String: KnownAppRecord] = [:]
    @Published private(set) var appRuleModes: [String: AppRuleMode] = [:]
    @Published private(set) var isRefreshingAvailableApps = false
    
    private let maxItemCountKey = "maxItemCount"
    private let historyRetentionOptionKey = "historyRetentionOption"
    private let showsSkippedClipWarningsKey = "showsSkippedClipWarnings"
    private let backupKeepCountKey = "backupKeepCount"
    private let knownAppRecordsKey = "knownAppRecords"
    private let appRuleModesKey = "appRuleModes"
    
    private let appDiscoveryService = AppDiscoveryService()
    private let clipboardMonitoringService = ClipboardMonitoringService()

    private var appDiscoveryTask: Task<Void, Never>?
    
    // Old key retained only so we can migrate existing Allowed/Blocked choices.
    private let legacyBlockedAppGroupIDsKey = "blockedAppGroupIDs"
    
    private let defaultAppGroups: [DefaultAppGroup] = [
        DefaultAppGroup(
            groupID: "1password",
            displayName: "1Password",
            bundleIdentifiers: [
                "com.1password.1password",
                "com.1password.1password-safari",
                "com.1password.1password.safari",
                "com.agilebits.onepassword",
                "com.agilebits.onepassword7"
            ]
        ),
        DefaultAppGroup(
            groupID: "bitwarden",
            displayName: "Bitwarden",
            bundleIdentifiers: [
                "com.8bit.bitwarden",
                "com.bitwarden.desktop",
                "com.bitwarden.safari"
            ]
        ),
        DefaultAppGroup(
            groupID: "nordpass",
            displayName: "NordPass",
            bundleIdentifiers: [
                "com.nordpass.NordPass",
                "com.nordpass.desktop",
                "com.nordpass.macos",
                "com.nordsec.nordpass"
            ]
        ),
        DefaultAppGroup(
            groupID: "keychain-access",
            displayName: "Keychain Access",
            bundleIdentifiers: [
                "com.apple.keychainaccess"
            ]
        )
    ]
    
    var appRuleOptions: [AppRuleOption] {
        let groupedRecords = Dictionary(grouping: knownAppRecords.values) { record in
            record.groupID
        }
        
        return groupedRecords.map { groupID, records in
            let displayName = displayNameForGroupID(groupID) ?? records
                .map { $0.displayName }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .first ?? groupID
            
            let bundleIdentifiers = records
                .map { $0.bundleIdentifier }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            
            let iconFilePath = records
                .compactMap { $0.appPath }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .first
            
            return AppRuleOption(
                id: groupID,
                displayName: displayName,
                bundleIdentifiers: bundleIdentifiers,
                iconFilePath: iconFilePath
            )
        }
        .sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }
    
    private var defaultBundleIdentifierToGroupID: [String: String] {
        var result: [String: String] = [:]
        
        for group in defaultAppGroups {
            for bundleIdentifier in group.bundleIdentifiers {
                result[bundleIdentifier.lowercased()] = group.groupID
            }
        }
        
        return result
    }
    
    private var defaultGroupIDToDisplayName: [String: String] {
        var result: [String: String] = [:]
        
        for group in defaultAppGroups {
            result[group.groupID] = group.displayName
        }
        
        return result
    }
    
    init() {
        loadMaxItemCount()
        loadHistoryRetentionOption()
        loadSkippedClipWarningPreference()
        loadBackupKeepCount()
        loadKnownAppRecords()
        loadAppRuleModes()
        loadItems()
        applyRetentionRules()

        clipboardMonitoringService.start { [weak self] payload in
            self?.handleClipboardChange(payload)
        }
    }
    
    func copyToClipboard(_ item: ClipboardItem) {
        guard item.kind == .normal else {
            return
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        
        clipboardMonitoringService.synchronizeChangeCount()
    }
    
    func synchronizeClipboardMonitoringChangeCount() {
        clipboardMonitoringService.synchronizeChangeCount()
    }

    func beginIgnoringClipboardMonitoringChanges() {
        clipboardMonitoringService
            .beginIgnoringClipboardChanges()
    }

    func captureSelectedText(
        _ text: String,
        sourceAppName: String?,
        sourceBundleIdentifier: String?,
        sourceAppPath: String?
    ) -> ClipboardCaptureOutcome {
        processClipboardCapture(
            ClipboardChangePayload(
                text: text,
                sourceAppName: sourceAppName,
                sourceBundleIdentifier:
                    sourceBundleIdentifier,
                sourceAppPath: sourceAppPath
            )
        )
    }
    
    func endIgnoringClipboardMonitoringChanges() {
        clipboardMonitoringService
            .endIgnoringClipboardChanges()
    }
    
    func deleteItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }
    
    func clearHistory() {
        items.removeAll()
        saveItems()
    }
    
    func importNormalItemsFromBackup(
        _ backupItems: [ClipboardItem]
    ) -> ClipboardBackupImportOutcome {
        let preparation =
            ClipboardImportService.prepareImport(
                existingItems: items,
                backupItems: backupItems,
                maximumItemCount: maxItemCount
            )

        if preparation.skippedDueToLimitCount > 0 {
            return .exceedsHistoryLimit(
                itemsOverLimit:
                    preparation.skippedDueToLimitCount
            )
        }

        if preparation.importedCount > 0 {
            items = preparation.mergedItems
            saveItems()
        }

        return .imported(
            importedCount: preparation.importedCount,
            duplicateCount: preparation.duplicateCount
        )
    }
    
    func replaceHistoryWithBackupItems(
        _ backupItems: [ClipboardItem]
    ) -> ClipboardBackupReplacementResult {
        let preparation =
            ClipboardImportService.prepareReplacement(
                backupItems: backupItems,
                maximumItemCount: maxItemCount
            )

        items = preparation.replacementItems
        saveItems()

        return ClipboardBackupReplacementResult(
            imported: preparation.replacementItems.count,
            duplicates: preparation.duplicateCount,
            skippedDueToLimit:
                preparation.skippedDueToLimitCount
        )
    }
    
    func setMaxItemCount(_ newValue: Int) {
        let clampedValue = min(
            max(
                newValue,
                Self.minimumHistoryLimit
            ),
            Self.maximumHistoryLimit
        )

        maxItemCount = clampedValue
        UserDefaults.standard.set(
            clampedValue,
            forKey: maxItemCountKey
        )

        applyRetentionRules()
        saveItems()
    }
    
    func setHistoryRetentionOption(_ newValue: HistoryRetentionOption) {
        historyRetentionOption = newValue
        UserDefaults.standard.set(newValue.rawValue, forKey: historyRetentionOptionKey)
        
        applyRetentionRules()
        saveItems()
    }

    func setShowsSkippedClipWarnings(_ newValue: Bool) {
        showsSkippedClipWarnings = newValue
        UserDefaults.standard.set(newValue, forKey: showsSkippedClipWarningsKey)
    }

    func setBackupKeepCount(_ newValue: Int) {
        let clampedValue = min(
            max(
                newValue,
                Self.minimumBackupKeepCount
            ),
            Self.maximumBackupKeepCount
        )

        backupKeepCount = clampedValue
        UserDefaults.standard.set(
            clampedValue,
            forKey: backupKeepCountKey
        )
    }
    
    func appRuleMode(for appRule: AppRuleOption) -> AppRuleMode {
        appRuleModes[appRule.id] ?? defaultAppRuleMode(forGroupID: appRule.id)
    }
    
    func setAppRuleMode(_ appRule: AppRuleOption, mode: AppRuleMode) {
        let defaultMode = defaultAppRuleMode(forGroupID: appRule.id)
        
        if mode == defaultMode {
            appRuleModes.removeValue(forKey: appRule.id)
        } else {
            appRuleModes[appRule.id] = mode
        }
        
        saveAppRuleModes()
    }

    func hasCustomAppRuleMode(for appRule: AppRuleOption) -> Bool {
        appRuleModes[appRule.id] != nil
    }

    func resetAppRuleModeToDefault(_ appRule: AppRuleOption) {
        appRuleModes.removeValue(forKey: appRule.id)
        saveAppRuleModes()
    }
    
    func resetAppRuleModesToDefaults() {
        appRuleModes = [:]
        saveAppRuleModes()
    }
    
    func refreshAvailableApps() {
        appDiscoveryTask?.cancel()

        rememberDefaultAppGroups()
        rememberRunningApplications()

        isRefreshingAvailableApps = true

        let discoveryService = appDiscoveryService

        appDiscoveryTask = Task { [weak self] in
            let installedApps = await Task.detached(
                priority: .userInitiated
            ) {
                discoveryService.discoverInstalledApplications()
            }
            .value

            guard !Task.isCancelled else {
                return
            }

            guard let self else {
                return
            }

            self.rememberDiscoveredApps(installedApps)
            self.saveKnownAppRecords()
            self.isRefreshingAvailableApps = false
            self.appDiscoveryTask = nil
        }
    }
    
    private func handleClipboardChange(
        _ payload: ClipboardChangePayload
    ) {
        _ = processClipboardCapture(payload)
    }

    @discardableResult
    private func processClipboardCapture(
        _ payload: ClipboardChangePayload
    ) -> ClipboardCaptureOutcome {
        guard !isMonitoringPaused else {
            return .skippedMonitoringPaused
        }

        let cleanedText =
            payload.text.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanedText.isEmpty else {
            return .skippedEmpty
        }

        let sourceAppName =
            payload.sourceAppName

        let sourceBundleIdentifier =
            payload.sourceBundleIdentifier

        if let sourceAppName,
           let sourceBundleIdentifier {
            rememberApp(
                displayName: sourceAppName,
                bundleIdentifier:
                    sourceBundleIdentifier,
                appPath: payload.sourceAppPath,
                shouldSave: true
            )
        }

        let sourceRuleMode =
            ruleModeForSourceApp(
                sourceAppName: sourceAppName,
                bundleIdentifier:
                    sourceBundleIdentifier
            )

        switch sourceRuleMode {
        case .blocked:
            addBlockedAppSkippedPlaceholder(
                sourceAppName: sourceAppName
            )

            return .skippedBlocked

        case .smart:
            if shouldSkipInSmartMode(cleanedText) {
                addSensitiveSkippedPlaceholder()
                return .skippedSensitive
            }

        case .allowed:
            break
        }

        guard
            !PasswordDetector
                .isLikelyPassword(cleanedText)
        else {
            addSensitiveSkippedPlaceholder()
            return .skippedSensitive
        }

        let newItem = ClipboardItem(
            text: cleanedText,
            createdAt: Date(),
            sourceAppName: sourceAppName,
            sourceBundleIdentifier:
                sourceBundleIdentifier
        )

        items.removeAll {
            $0.kind == .normal &&
                $0.text == cleanedText
        }

        items.insert(
            newItem,
            at: 0
        )

        applyRetentionRules()
        saveItems()

        return .captured
    }
    
    private func ruleModeForSourceApp(
        sourceAppName: String?,
        bundleIdentifier: String?
    ) -> AppRuleMode {
        guard let bundleIdentifier else {
            return .allowed
        }
        
        let groupID = groupIDForApp(
            displayName: sourceAppName ?? bundleIdentifier,
            bundleIdentifier: bundleIdentifier
        )
        
        return appRuleModes[groupID] ?? defaultAppRuleMode(forGroupID: groupID)
    }
    
    private func defaultAppRuleMode(forGroupID groupID: String) -> AppRuleMode {
        switch groupID {
        case "1password", "bitwarden", "nordpass", "keychain-access":
            return .blocked
        default:
            if groupID.hasPrefix("password-app-") {
                return .blocked
            }
            
            return .allowed
        }
    }
    
    private func shouldSkipInSmartMode(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return false
        }
        
        if isObviousEmail(trimmed) {
            return false
        }
        
        if isLikelyURL(trimmed) {
            return false
        }
        
        if PasswordDetector.isLikelyPassword(trimmed) {
            return true
        }
        
        if isLikelySecretToken(trimmed) {
            return true
        }
        
        return false
    }
    
    private func isObviousEmail(_ text: String) -> Bool {
        guard !text.contains(" ") else {
            return false
        }
        
        let parts = text.split(separator: "@")
        
        guard parts.count == 2,
              let domain = parts.last,
              domain.contains(".") else {
            return false
        }
        
        return true
    }
    
    private func isLikelyURL(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") {
            return true
        }
        
        if lowercased.hasPrefix("www.") {
            return true
        }
        
        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased() else {
            return false
        }
        
        return ["http", "https", "mailto", "ftp"].contains(scheme)
    }
    
    private func isLikelySecretToken(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.contains(" ") else {
            return false
        }
        
        guard trimmed.count >= 16 else {
            return false
        }
        
        let lowercased = trimmed.lowercased()
        
        let secretPrefixes = [
            "sk-",
            "pk_",
            "rk_",
            "ghp_",
            "gho_",
            "github_pat_",
            "xoxb-",
            "xoxp-"
        ]
        
        if secretPrefixes.contains(where: { lowercased.hasPrefix($0) }) {
            return true
        }
        
        let hasLowercase = trimmed.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasUppercase = trimmed.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasNumber = trimmed.rangeOfCharacter(from: .decimalDigits) != nil
        let hasSymbol = trimmed.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil
        
        let categoryCount = [hasLowercase, hasUppercase, hasNumber, hasSymbol]
            .filter { $0 }
            .count
        
        if trimmed.count >= 24 && categoryCount >= 3 {
            return true
        }
        
        if trimmed.count >= 32 && categoryCount >= 2 {
            return true
        }
        
        return false
    }
    
    private func applyRetentionRules() {
        items = ClipboardRetentionService.applyingRules(
            to: items,
            retentionOption: historyRetentionOption,
            maximumNormalItemCount: maxItemCount
        )
    }
    
    private func rememberDefaultAppGroups() {
        for group in defaultAppGroups {
            for bundleIdentifier in group.bundleIdentifiers {
                rememberApp(
                    displayName: group.displayName,
                    bundleIdentifier: bundleIdentifier,
                    appPath: findInstalledAppPath(bundleIdentifier: bundleIdentifier),
                    shouldSave: false
                )
            }
        }
    }
    
    private func rememberRunningApplications() {
        let discoveredApps =
            appDiscoveryService.discoverRunningApplications()

        rememberDiscoveredApps(discoveredApps)
    }
    
    private func findInstalledAppPath(bundleIdentifier: String) -> String? {
        let normalizedBundleIdentifier = bundleIdentifier.lowercased()
        
        if let existingRecord = knownAppRecords[normalizedBundleIdentifier],
           let appPath = existingRecord.appPath {
            return appPath
        }
        
        return nil
    }
    
    private func rememberDiscoveredApps(
        _ discoveredApps: [DiscoveredApp]
    ) {
        for discoveredApp in discoveredApps {
            rememberApp(
                displayName: discoveredApp.displayName,
                bundleIdentifier: discoveredApp.bundleIdentifier,
                appPath: discoveredApp.appPath,
                shouldSave: false
            )
        }
    }
    
    private func rememberApp(
        displayName: String,
        bundleIdentifier: String,
        appPath: String?,
        shouldSave: Bool
    ) {
        let normalizedBundleIdentifier = bundleIdentifier.lowercased()
        let cleanedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !normalizedBundleIdentifier.isEmpty else {
            return
        }
        
        let finalDisplayName = cleanedDisplayName.isEmpty ? bundleIdentifier : cleanedDisplayName
        
        let record = KnownAppRecord(
            displayName: finalDisplayName,
            bundleIdentifier: normalizedBundleIdentifier,
            appPath: appPath,
            groupID: groupIDForApp(
                displayName: finalDisplayName,
                bundleIdentifier: normalizedBundleIdentifier
            )
        )
        
        knownAppRecords[normalizedBundleIdentifier] = record
        
        if shouldSave {
            saveKnownAppRecords()
        }
    }
    
    private func groupIDForApp(
        displayName: String,
        bundleIdentifier: String
    ) -> String {
        let normalizedBundleIdentifier = bundleIdentifier.lowercased()
        let normalizedDisplayName = displayName.lowercased()
        
        if let defaultGroupID = defaultBundleIdentifierToGroupID[normalizedBundleIdentifier] {
            return defaultGroupID
        }
        
        if normalizedDisplayName.contains("1password") ||
            normalizedBundleIdentifier.contains("1password") ||
            normalizedBundleIdentifier.contains("onepassword") ||
            normalizedBundleIdentifier.contains("agilebits") {
            return "1password"
        }
        
        if normalizedDisplayName.contains("bitwarden") ||
            normalizedBundleIdentifier.contains("bitwarden") {
            return "bitwarden"
        }

        if normalizedDisplayName.contains("nordpass") ||
            normalizedBundleIdentifier.contains("nordpass") {
            return "nordpass"
        }

        if normalizedDisplayName.contains("keychain access") ||
            normalizedBundleIdentifier.contains("keychainaccess") {
            return "keychain-access"
        }

        if normalizedDisplayName.contains("password") {
            return "password-app-\(slugify(displayName))"
        }
        
        if let existingRecord = knownAppRecords[normalizedBundleIdentifier] {
            return existingRecord.groupID
        }
        
        return "app-\(slugify(displayName))"
    }
    
    private func displayNameForGroupID(_ groupID: String) -> String? {
        if let defaultDisplayName = defaultGroupIDToDisplayName[groupID] {
            return defaultDisplayName
        }
        
        return nil
    }
    
    private func slugify(_ value: String) -> String {
        let lowercased = value.lowercased()
        let allowedCharacters = CharacterSet.alphanumerics
        
        var result = ""
        var previousWasDash = false
        
        for scalar in lowercased.unicodeScalars {
            if allowedCharacters.contains(scalar) {
                result.append(String(scalar))
                previousWasDash = false
            } else if !previousWasDash {
                result.append("-")
                previousWasDash = true
            }
        }
        
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
    
    private func saveItems() {
        let itemsToSave = items

        Task {
            do {
                try await ClipboardPersistenceService.shared.saveItems(
                    itemsToSave
                )
            } catch {
                print("Failed to save clipboard history: \(error)")
            }
        }
    }
    
    private func loadItems() {
        do {
            items = try ClipboardPersistenceService.loadItems()

            for item in items {
                if let sourceAppName = item.sourceAppName,
                   let sourceBundleIdentifier = item.sourceBundleIdentifier {
                    rememberApp(
                        displayName: sourceAppName,
                        bundleIdentifier: sourceBundleIdentifier,
                        appPath: nil,
                        shouldSave: false
                    )
                }
            }

            saveKnownAppRecords()

            // Clean up any previously saved placeholder rows.
            saveItems()
        } catch {
            print("Failed to load clipboard history: \(error)")
            items = []
        }
    }
    
    private func loadMaxItemCount() {
        let savedValue = UserDefaults.standard.integer(forKey: maxItemCountKey)
        
        if savedValue == 0 {
            maxItemCount = 100
        } else {
            maxItemCount = min(
                max(
                    savedValue,
                    Self.minimumHistoryLimit
                ),
                Self.maximumHistoryLimit
            )
        }
    }
    
    private func loadHistoryRetentionOption() {
        guard let savedRawValue = UserDefaults.standard.string(forKey: historyRetentionOptionKey),
              let savedOption = HistoryRetentionOption(rawValue: savedRawValue) else {
            historyRetentionOption = .forever
            return
        }
        
        historyRetentionOption = savedOption
    }

    private func loadSkippedClipWarningPreference() {
        if UserDefaults.standard.object(forKey: showsSkippedClipWarningsKey) == nil {
            showsSkippedClipWarnings = true
        } else {
            showsSkippedClipWarnings = UserDefaults.standard.bool(forKey: showsSkippedClipWarningsKey)
        }
    }

    private func loadBackupKeepCount() {
        let savedValue =
            UserDefaults.standard.integer(
                forKey: backupKeepCountKey
            )

        if savedValue == 0 {
            backupKeepCount = 5
        } else {
            backupKeepCount = min(
                max(
                    savedValue,
                    Self.minimumBackupKeepCount
                ),
                Self.maximumBackupKeepCount
            )
        }
    }
    
    private func loadKnownAppRecords() {
        guard let data = UserDefaults.standard.data(forKey: knownAppRecordsKey) else {
            rememberDefaultAppGroups()
            saveKnownAppRecords()
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let savedRecords = try decoder.decode([KnownAppRecord].self, from: data)
            
            knownAppRecords = savedRecords.reduce(into: [:]) { result, record in
                result[record.bundleIdentifier.lowercased()] = record
            }
        } catch {
            print("Failed to load known app records: \(error)")
            knownAppRecords = [:]
        }
        
        rememberDefaultAppGroups()
        saveKnownAppRecords()
    }
    
    private func saveKnownAppRecords() {
        do {
            let encoder = JSONEncoder()
            let records = Array(knownAppRecords.values)
            let data = try encoder.encode(records)
            UserDefaults.standard.set(data, forKey: knownAppRecordsKey)
        } catch {
            print("Failed to save known app records: \(error)")
        }
    }
    
    private func loadAppRuleModes() {
        if let rawDictionary = UserDefaults.standard.dictionary(forKey: appRuleModesKey) as? [String: String] {
            var result: [String: AppRuleMode] = [:]
            
            for entry in rawDictionary {
                if let mode = AppRuleMode(rawValue: entry.value) {
                    let defaultMode = defaultAppRuleMode(forGroupID: entry.key)
                    
                    if mode != defaultMode {
                        result[entry.key] = mode
                    }
                }
            }
            
            appRuleModes = result
            saveAppRuleModes()
            return
        }
        
        appRuleModes = migrateLegacyBlockedAppsToModes().filter { entry in
            entry.value != defaultAppRuleMode(forGroupID: entry.key)
        }
        
        saveAppRuleModes()
    }
    
    private func migrateLegacyBlockedAppsToModes() -> [String: AppRuleMode] {
        var migratedModes: [String: AppRuleMode] = [:]
        
        if let legacyBlockedGroupIDs = UserDefaults.standard.array(forKey: legacyBlockedAppGroupIDsKey) as? [String] {
            for groupID in legacyBlockedGroupIDs {
                migratedModes[groupID] = .blocked
            }
        }
        
        return migratedModes
    }
    
    private func saveAppRuleModes() {
        let rawDictionary = appRuleModes.reduce(into: [String: String]()) { result, entry in
            result[entry.key] = entry.value.rawValue
        }
        
        UserDefaults.standard.set(rawDictionary, forKey: appRuleModesKey)
    }
    
    private func trimItemsToMaxCount() {
        items = ClipboardRetentionService.trimmingNormalItems(
            in: items,
            maximumNormalItemCount: maxItemCount
        )
    }
    
    private func addSensitiveSkippedPlaceholder() {
        let message = "(Likely sensitive clip skipped in ClipVault. Clip still available in system clipboard for use.)"
        addSkippedPlaceholder(message: message)
    }
    
    private func addBlockedAppSkippedPlaceholder(sourceAppName: String?) {
        let appName = sourceAppName?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let message: String
        
        if let appName, !appName.isEmpty {
            message = "(Clip skipped because it came from blocked app: \(appName). Clip still available in system clipboard for use.)"
        } else {
            message = "(Clip skipped because it came from a blocked app. Clip still available in system clipboard for use.)"
        }
        
        addSkippedPlaceholder(message: message)
    }
    
    private func addSkippedPlaceholder(message: String) {
        guard showsSkippedClipWarnings else {
            return
        }
        
        let placeholder = ClipboardItem(
            text: message,
            createdAt: Date(),
            kind: .sensitiveSkipped
        )

        items.insert(placeholder, at: 0)
        trimItemsToMaxCount()

        // Do not call saveItems().
        // This keeps warning rows visible during the current session
        // without storing placeholders permanently.
    }
}
