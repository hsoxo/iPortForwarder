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
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(state)
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
        }
        .menuBarExtraStyle(.window)
        .commands {
            iPortForwarderCommands()
        }

        WindowGroup("Settings", id: "settings") {
            SettingsView()
                .environmentObject(state)
        }
    }
}

struct MenuBarContentView: View {
    @EnvironmentObject var state: GlobalState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
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
            withAnimation {
                state.selectedSettingsTab = .rules
                state.isAddingNewItem = true
            }
            openWindow(id: "settings")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        Button("Settings...") {
            state.selectedSettingsTab = .general
            openWindow(id: "settings")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        Divider()

        Button("Quit iPortForwarder") {
            state.shutdown()
            NSApplication.shared.terminate(nil)
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
