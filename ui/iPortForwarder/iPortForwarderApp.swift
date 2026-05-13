import AppKit
import SwiftUI

import Libipf

@main
struct iPortForwarderApp: App {
    init() {
        initLibipfErrorHandler()
        globalState.restoreSavedRules()

        Task.detached {
            await AppUpdater.checkForUpdates()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(globalState)
        }
        .commands {
            iPortForwarderCommands()
        }

        MenuBarExtra("iPortForwarder", systemImage: "arrow.left.arrow.right.circle") {
            if globalState.rules.isEmpty {
                Text("No forwarding rules")
            } else {
                ForEach(globalState.rules) { rule in
                    Toggle(isOn: Binding(
                        get: { rule.isEnabled },
                        set: { globalState.setRule(rule, enabled: $0) }
                    )) {
                        Text(rule.menuTitle)
                    }
                }
            }

            Divider()

            Button("Add New Rule") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
                withAnimation {
                    globalState.isAddingNewItem = true
                }
            }

            SettingsLink {
                Text("Settings...")
            }

            Divider()

            Button("Quit iPortForwarder") {
                globalState.shutdown()
                NSApplication.shared.terminate(nil)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(globalState)
        }
    }
}

extension ForwardRuleConfig {
    var menuTitle: String {
        let localPortDescription: String
        switch remotePort {
        case let .single(port):
            localPortDescription = String(localPort ?? port)
            return "\(localPortDescription) -> \(address):\(port)"
        case let .range(start, end):
            let localStart = localPort ?? start
            let localEnd = Int(localStart) + Int(end - start)
            localPortDescription = "\(localStart)-\(localEnd)"
            return "\(localPortDescription) -> \(address):\(start)-\(end)"
        }
    }
}
