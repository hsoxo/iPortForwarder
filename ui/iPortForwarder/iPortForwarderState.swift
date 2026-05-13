import Foundation

import Libipf

private let savedRulesKey = "savedForwardRuleConfigs"

enum SettingsTab: Hashable {
    case general
    case rules
}

extension Array: @retroactive RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else { return nil }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}

@MainActor
class GlobalState: ObservableObject {
    @Published private(set) var rules: [ForwardRuleConfig] = []
    @Published var errors: [UUID: [IpfError]] = [:]
    @Published var isAddingNewItem: Bool = false
    @Published var selectedSettingsTab: SettingsTab = .general

    private var activeItems: [UUID: ForwardedItem] = [:]
    private var activeRuleIds: [Int8: UUID] = [:]
    private var isLoading = false

    init() {}

    public func restoreSavedRules() {
        loadSavedRules()
    }

    public func addRule(_ rule: ForwardRuleConfig) {
        rules.append(rule)
        if rule.isEnabled {
            startRule(rule)
        }
        saveRules()
    }

    public func updateRule(_ rule: ForwardRuleConfig) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else {
            return
        }

        stopRule(rules[index].id)
        rules[index] = rule

        if rule.isEnabled {
            startRule(rule)
        }

        saveRules()
    }

    public func deleteRule(_ rule: ForwardRuleConfig) {
        stopRule(rule.id)
        errors.removeValue(forKey: rule.id)
        rules.removeAll { $0.id == rule.id }
        saveRules()
    }

    public func setRule(_ rule: ForwardRuleConfig, enabled: Bool) {
        var updatedRule = rule
        updatedRule.isEnabled = enabled
        updateRule(updatedRule)
    }

    public func ruleIsRunning(_ rule: ForwardRuleConfig) -> Bool {
        activeItems[rule.id] != nil
    }

    public func recordError(forwardRuleId: Int8, error: IpfError) {
        guard let ruleId = activeRuleIds[forwardRuleId] else {
            return
        }

        if var currentErrors = errors[ruleId] {
            currentErrors.append(error)
            errors[ruleId] = currentErrors
        } else {
            errors[ruleId] = [error]
        }
    }

    public func clear() {
        for ruleId in Array(activeItems.keys) {
            stopRule(ruleId)
        }
        rules = []
        errors = [:]
        isAddingNewItem = false
        saveRules()
    }

    public func shutdown() {
        for ruleId in Array(activeItems.keys) {
            stopRule(ruleId)
        }
    }

    public func importRules(_ importedRules: [ForwardRuleConfig]) {
        for rule in importedRules {
            var importedRule = rule
            importedRule.id = UUID()
            addRule(importedRule)
        }
    }

    public func exportRules() -> [ForwardRuleConfig] {
        rules
    }

    private func loadSavedRules() {
        isLoading = true
        defer { isLoading = false }

        guard let savedRulesString = UserDefaults.standard.string(forKey: savedRulesKey),
              let savedRulesData = savedRulesString.data(using: .utf8)
        else {
            return
        }

        let decoder = JSONDecoder()
        if let savedRules = try? decoder.decode([ForwardRuleConfig].self, from: savedRulesData) {
            rules = savedRules
        } else if let savedInfos = try? decoder.decode([ForwardedItemInfo].self, from: savedRulesData) {
            rules = savedInfos.map { ForwardRuleConfig(item: $0) }
        }

        for rule in rules where rule.isEnabled {
            startRule(rule)
        }
    }

    private func saveRules() {
        if !isLoading {
            UserDefaults.standard.set(rules.rawValue, forKey: savedRulesKey)
        }
    }

    private func startRule(_ rule: ForwardRuleConfig) {
        do {
            let item = try ForwardedItem(item: rule)
            activeItems[rule.id] = item
            activeRuleIds[item.id] = rule.id
            errors.removeValue(forKey: rule.id)
        } catch {
            if let ipfError = error as? IpfError {
                errors[rule.id] = [ipfError]
            } else {
                showErrorDialog(error)
            }
        }
    }

    private func stopRule(_ ruleId: UUID) {
        if let item = activeItems.removeValue(forKey: ruleId) {
            activeRuleIds.removeValue(forKey: item.id)
            item.destroy()
        }
    }
}

@MainActor var globalState = GlobalState()

@MainActor
func initLibipfErrorHandler() {
    try! Libipf.registerErrorHandler { id, ipfError in
        DispatchQueue.main.async {
            globalState.recordError(forwardRuleId: id, error: ipfError)
        }
    }
}
