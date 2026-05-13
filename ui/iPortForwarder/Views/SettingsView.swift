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
        TabView(selection: $globalState.selectedSettingsTab) {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(SettingsTab.general)

            rulesTab
                .tabItem {
                    Label("Rules", systemImage: "arrow.left.arrow.right")
                }
                .tag(SettingsTab.rules)
        }
        .frame(minWidth: 620, minHeight: 320)
        .padding()
    }

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Launch at login", isOn: $launchingAtLogin.enabled)
            Spacer()
        }
        .padding()
    }

    private var rulesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
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
