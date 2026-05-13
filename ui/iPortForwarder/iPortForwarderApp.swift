import AppKit
import SwiftUI

import Libipf

@main
struct iPortForwarderApp: App {
    @StateObject private var state = globalState

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
                .environmentObject(state)
        }
        .commands {
            iPortForwarderCommands()
        }

        MenuBarExtra("iPortForwarder", systemImage: "arrow.left.arrow.right.circle") {
            if state.rules.isEmpty {
                Text("No forwarding rules")
            } else {
                ForEach(state.rules) { rule in
                    Toggle(isOn: Binding(
                        get: { rule.isEnabled },
                        set: { state.setRule(rule, enabled: $0) }
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
                    state.isAddingNewItem = true
                }
            }

            Button("Settings...") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                if !NSApplication.shared.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil) {
                    NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            }

            Divider()

            Button("Quit iPortForwarder") {
                state.shutdown()
                NSApplication.shared.terminate(nil)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(state)
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
