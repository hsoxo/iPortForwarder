import SwiftUI

struct ContentView: View {
    @EnvironmentObject var globalState: GlobalState

    var body: some View {
        VStack {
            ScrollView {
                VStack {
                    ForEach(globalState.rules) { rule in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { rule.isEnabled },
                                set: { globalState.setRule(rule, enabled: $0) }
                            ))
                            .toggleStyle(.switch)
                            .help(rule.isEnabled ? "Disable forwarding" : "Enable forwarding")

                            ForwardedItemRow(
                                item: rule,
                                errors: globalState.errors[rule.id],
                                onChange: { address, remotePort, localPort, allowLan in
                                    var updatedRule = rule
                                    updatedRule.address = address
                                    updatedRule.remotePort = remotePort
                                    updatedRule.localPort = localPort
                                    updatedRule.allowLan = allowLan
                                    withAnimation {
                                        globalState.updateRule(updatedRule)
                                    }
                                },
                                onDelete: {
                                    withAnimation {
                                        globalState.deleteRule(rule)
                                    }
                                }
                            )
                        }
                        .contextMenu {
                            Button(action: {
                                withAnimation {
                                    globalState.deleteRule(rule)
                                }
                            }) {
                                Text("Delete")
                            }
                        }
                    }

                    if globalState.isAddingNewItem {
                        ForwardedItemRow(onNewItemAdded: { newItem in
                            globalState.addRule(newItem)
                            globalState.isAddingNewItem = false
                        }, onCancel: { withAnimation {
                            globalState.isAddingNewItem = false
                        } })
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }

                // A hack to make ScrollView stable
                if globalState.rules.isEmpty {
                    HStack {
                        Spacer()
                    }
                }
            }
            .frame(minWidth: 400, minHeight: 100)
            .padding(.all, 8)

            if !globalState.isAddingNewItem {
                Button("Add New") {
                    withAnimation {
                        globalState.isAddingNewItem = true
                    }
                }
                .padding()
                .transition(.move(edge: .bottom))
            }
        }
    }
}
