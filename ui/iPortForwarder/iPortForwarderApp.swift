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
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .padding(.top, 10)

            if state.rules.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(state.rules) { rule in
                            MenuBarRuleRow(rule: rule)
                                .environmentObject(state)
                        }
                    }
                    .padding(.vertical, 10)
                }
                .frame(maxHeight: 260)
            }

            Divider()

            HStack(spacing: 8) {
                Button {
                    withAnimation {
                        state.selectedSettingsTab = .rules
                        state.isAddingNewItem = true
                    }
                    openWindow(id: "settings")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                } label: {
                    Label("Add", systemImage: "plus")
                }

                Spacer()

                Button {
                    state.selectedSettingsTab = .general
                    openWindow(id: "settings")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .labelStyle(.iconOnly)
                }
                .help("Settings")

                Button {
                    state.shutdown()
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                        .labelStyle(.iconOnly)
                }
                .help("Quit iPortForwarder")
            }
            .buttonStyle(.borderless)
            .padding(.top, 10)
        }
        .padding(14)
        .frame(width: 340)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text("iPortForwarder")
                    .font(.headline)
                Text("\(state.rules.filter(\.isEnabled).count) active of \(state.rules.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 8) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
            Text("No forwarding rules")
                .font(.subheadline)
            Text("Add a rule in Settings to start forwarding ports.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

struct MenuBarRuleRow: View {
    @EnvironmentObject var state: GlobalState
    let rule: ForwardRuleConfig

    var body: some View {
        Button {
            state.setRule(rule, enabled: !rule.isEnabled)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    if rule.isEnabled {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                }
                .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.destinationTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(rule.localTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
        .help(rule.isEnabled ? "Disable forwarding" : "Enable forwarding")
    }
}

extension ForwardRuleConfig {
    var menuTitle: String {
        let port = remotePort.value
        return "\(localPort ?? port) -> \(address):\(port)"
    }

    var destinationTitle: String {
        "\(address):\(remotePort.value)"
    }

    var localTitle: String {
        "Local \(localPort ?? remotePort.value)"
    }
}
