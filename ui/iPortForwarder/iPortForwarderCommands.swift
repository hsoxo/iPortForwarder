import Foundation
import SwiftUI

struct iPortForwarderCommands: Commands {
    var window: NSWindow? {
        get {
            return NSApplication.shared.windows.first
        }
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Forward Item") {
                withAnimation {
                    globalState.isAddingNewItem = true
                }
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save Current Forwarding List") {
                guard let window else { return }
                let listOfItemInfo = globalState.exportRules()
                let jsonData: Data
                do {
                    jsonData = try JSONEncoder().encode(listOfItemInfo)
                } catch {
                    showErrorDialog(error)
                    return
                }
                guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                    showErrorDialog("Failed to encode forwarding list as UTF-8.")
                    return
                }

                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.json]
                savePanel.canCreateDirectories = true
                savePanel.isExtensionHidden = false
                savePanel.title = "Save current forwarding list"
                savePanel.message = "Choose a folder and a name to store the list."
                savePanel.nameFieldLabel = "List name:"
                savePanel.beginSheetModal(for: window) {
                    if $0 == .OK {
                        if let saveUrl = savePanel.url {
                            do {
                                try jsonString.write(to: saveUrl, atomically: false, encoding: .utf8)
                            } catch {
                                showErrorDialog(error)
                            }
                        }
                    }
                }
            }
            .keyboardShortcut("s", modifiers: .command)
        }

        CommandGroup(after: .saveItem) {
            Button("Import Forwarding List") {
                if let window {
                    let openPanel = NSOpenPanel()
                    openPanel.allowsMultipleSelection = false
                    openPanel.allowedContentTypes = [.json]
                    openPanel.allowsOtherFileTypes = false
                    openPanel.canChooseFiles = true
                    openPanel.canChooseDirectories = false
                    openPanel.canCreateDirectories = false
                    openPanel.isExtensionHidden = false
                    openPanel.title = "Import a forwarding list"
                    openPanel.message = "Choose a forwarding list to import."
                    openPanel.beginSheetModal(for: window) {
                        if $0 == .OK {
                            if let openUrl = openPanel.url {
                                do {
                                    let data = try Data(contentsOf: openUrl)
                                    let decoder = JSONDecoder()

                                    let rules: [ForwardRuleConfig]
                                    if let decodedRules = try? decoder.decode([ForwardRuleConfig].self, from: data) {
                                        rules = decodedRules
                                    } else {
                                        let legacyItems = try decoder.decode([ForwardedItemInfo].self, from: data)
                                        rules = legacyItems.map { ForwardRuleConfig(item: $0) }
                                    }

                                    withAnimation {
                                        globalState.importRules(rules)
                                    }
                                } catch {
                                    showErrorDialog(error)
                                }
                            }
                        }
                    }
                }
            }
            .keyboardShortcut("o", modifiers: .command)
        }
    }
}
