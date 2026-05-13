import AppKit
import ServiceManagement
import SwiftUI

class LaunchingAtLogin: ObservableObject {
    var enabled: Bool {
        get {
            return SMAppService.mainApp.status == .enabled
        }

        set {
            if newValue {
                if SMAppService.mainApp.status == .enabled {
                    try? SMAppService.mainApp.unregister()
                }

                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
            objectWillChange.send()
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var globalState: GlobalState
    @StateObject private var launchingAtLogin = LaunchingAtLogin()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Launch at login", isOn: $launchingAtLogin.enabled)

            Text("Forwarding rules are saved automatically and enabled rules are restored at launch.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(globalState.rules) { rule in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { rule.isEnabled },
                                set: { globalState.setRule(rule, enabled: $0) }
                            ))
                            .toggleStyle(.switch)

                            ForwardedItemRow(
                                item: rule,
                                errors: globalState.errors[rule.id],
                                onChange: { address, remotePort, localPort, allowLan in
                                    var updatedRule = rule
                                    updatedRule.address = address
                                    updatedRule.remotePort = remotePort
                                    updatedRule.localPort = localPort
                                    updatedRule.allowLan = allowLan
                                    globalState.updateRule(updatedRule)
                                },
                                onDelete: {
                                    withAnimation {
                                        globalState.deleteRule(rule)
                                    }
                                }
                            )
                        }
                    }

                    if globalState.isAddingNewItem {
                        ForwardedItemRow(onNewItemAdded: { newItem in
                            globalState.addRule(newItem)
                            globalState.isAddingNewItem = false
                        }, onCancel: {
                            withAnimation {
                                globalState.isAddingNewItem = false
                            }
                        })
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            .frame(minWidth: 520, minHeight: 180)

            HStack {
                Spacer()
                Button {
                    withAnimation {
                        globalState.isAddingNewItem = true
                    }
                } label: {
                    Label("Add Rule", systemImage: "plus")
                }
                .disabled(globalState.isAddingNewItem)
            }
        }
        .padding()
    }
}

#Preview {
    SettingsView()
        .environmentObject(globalState)
}
