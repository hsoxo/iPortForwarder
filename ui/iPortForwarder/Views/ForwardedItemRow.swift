import AppKit
import SwiftUI

import Libipf

struct ForwardedItemRow: View {
    var item: DisplayableForwardedItem?
    var errors: [IpfError]?

    var onNewItemAdded: ((_ newItem: ForwardRuleConfig) -> Void)?
    var onChange: ((_ ipAddress: String, _ remotePort: Port, _ localPort: UInt16?, _ allowLan: Bool) -> Void)?
    var onCancel: (() -> Void)?
    var onDelete: (() -> Void)?

    @State private var address: String
    @State private var remotePort: Port
    @State private var localPort: UInt16?
    @State private var allowLan: Bool

    @State private var showSettings: Bool = false
    @State private var errorsHovered: Bool = false

    @FocusState private var addrInFocus: Bool
    @FocusState private var remotePortInFocus: Bool
    @FocusState private var localPortInFocus: Bool

    init(
        item: DisplayableForwardedItem? = nil,
        errors: [IpfError]? = nil,
        onNewItemAdded: ((_ newItem: ForwardRuleConfig) -> Void)? = nil,
        onChange: (
            (_ ipAddress: String, _ remotePort: Port, _ localPort: UInt16?, _ allowLan: Bool) -> Void
        )? = nil,
        onCancel: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.item = item
        self.errors = errors
        self.onNewItemAdded = onNewItemAdded
        self.onChange = onChange
        self.onCancel = onCancel
        self.onDelete = onDelete
        self._address = State(initialValue: item?.address ?? "")
        self._remotePort = State(initialValue: item?.remotePort ?? .single(port: 0))
        self._localPort = State(initialValue: item?.localPort)
        self._allowLan = State(initialValue: item?.allowLan ?? false)
    }

    var body: some View {
        VStack {
            HStack {
                HStack {
                    ZStack {
                        if let errors {
                            if !errors.isEmpty {
                                Spacer()
                                    .frame(width: 36)

                                Image(systemName: "x.circle.fill")
                                    .foregroundColor(.red)
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                        }
                    }
                    .onHover {
                        let hovered = $0
                        withAnimation {
                            errorsHovered = hovered
                        }
                    }
                    .animation(.spring(), value: errors)

                    TextField("IP Address or Domain Name", text: $address.animation()) {}
                        .textFieldStyle(.roundedBorder)
                        .overlay(
                            HStack {
                                Spacer()
                                if address != "" && checkIpIsValid(ip: address) {
                                    Text("IP")
                                        .frame(width: 16, height: 16)
                                        .font(.system(size: 8))
                                        .foregroundStyle(.gray)
                                        .border(.gray, width: 2)
                                        .cornerRadius(4)
                                        .padding(.trailing, 5)
                                }
                            }
                        )
                        .focused($addrInFocus)
                        .onAppear {
                            // auto focus when this show from `AddNew` button click
                            if item == nil {
                                self.addrInFocus = true
                            }
                        }

                    Text(":")

                    TextField(
                        "Port",
                        text: Binding(
                            get: {
                                remotePort.value == 0 ? "" : String(remotePort.value)
                            },
                            set: {
                                remotePort = .single(port: UInt16($0) ?? 0)
                            }
                        ).animation()
                    )
                    .frame(minWidth: 30, maxWidth: 60)
                    .textFieldStyle(.roundedBorder)
                    .focused($remotePortInFocus)
                }

                Spacer()

                HStack {
                    if item != nil {
                        Button {
                            withAnimation(.spring()) {
                                showSettings.toggle()
                            }
                        } label: {
                            Label(
                                showSettings ? "Hide advanced settings" : "Show advanced settings",
                                systemImage: "gear"
                            )
                            .labelStyle(.iconOnly)
                            .foregroundColor(showSettings ? .accentColor : .primary)
                        }
                        .help(showSettings ? "Hide advanced settings" : "Show advanced settings")
                    }

                    if hasChanged() {
                        HStack {
                            Button {
                                submit()
                            } label: {
                                Label("OK", systemImage: "checkmark")
                                    .labelStyle(.iconOnly)
                                    .foregroundColor(isValid() ? .green : .gray)
                            }
                            .help("OK")
                            .disabled(!isValid())

                            Button {
                                withAnimation {
                                    reset()
                                }
                            } label: {
                                Label("Reset", systemImage: "arrow.clockwise")
                                    .labelStyle(.iconOnly)
                                    .foregroundColor(.blue)
                            }
                            .help("Reset")

                            if item == nil {
                                Button {
                                    if let cancel = onCancel {
                                        cancel()
                                    }
                                } label: {
                                    Label("Cancel", systemImage: "xmark")
                                        .labelStyle(.iconOnly)
                                        .foregroundColor(.red)
                                }
                                .help("Cancel")
                            }
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            .frame(height: 32)

            if showSettings || item == nil {
                HStack {
                    Toggle(
                        "Use a different local port",
                        isOn: Binding(
                            get: { localPort != nil },
                            set: {
                                if $0 {
                                    withAnimation {
                                        localPort = 0
                                        localPortInFocus = true
                                    }
                                } else {
                                    // a hack to make it work
                                    if localPortInFocus {
                                        localPortInFocus = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                            withAnimation {
                                                localPort = nil
                                            }
                                        }
                                    } else {
                                        withAnimation {
                                            localPort = nil
                                        }
                                    }
                                }
                            }
                        )
                    )
                    .toggleStyle(.switch)

                    if let localPort {
                        HStack {
                            TextField(
                                "Port",
                                text: Binding(
                                    get: { localPort == 0 ? "" : String(localPort) },
                                    set: {
                                        self.localPort = UInt16($0) ?? 0
                                    }
                                )
                            )
                            .frame(minWidth: 30, maxWidth: 60)
                            .textFieldStyle(.roundedBorder)
                            .focused($localPortInFocus)
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }

                    Spacer()
                        .frame(width: 32)

                    Toggle("Allow LAN", isOn: $allowLan.animation())
                        .toggleStyle(.switch)
                        .help("Switch between binding to either 127.0.0.1 or 0.0.0.0")
                        .transition(.slide)

                    Spacer()

                    if item != nil {
                        Button {
                            if let delete = onDelete {
                                delete()
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .labelStyle(.iconOnly)
                                .foregroundColor(.red)
                        }
                        .help("Delete")
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            VStack {
                if let errors {
                    if errorsHovered {
                        HStack {
                            VStack {
                                Spacer()
                                    .frame(height: 8)
                                ForEach(Array(errors.enumerated()), id: \.offset) { _, error in
                                    HStack {
                                        Text(error.message())
                                            .foregroundColor(.white)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 1)
                                }
                                Spacer()
                                    .frame(height: 8)
                            }
                            .background(.red)
                            .cornerRadius(8)

                        }
                        .padding(.horizontal, 30)
                        .padding(.vertical, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            .animation(.spring(), value: errorsHovered)
        }
        .onSubmit {
            if isValid() {
                submit()
            }
        }
        .onExitCommand {
            if let cancel = onCancel {
                cancel()
            }
        }
    }

    func isValid() -> Bool {
        if address == "" {
            return false
        }

        if remotePort.value == 0 {
            return false
        }

        if let localPort = localPort {
            if localPort == 0 {
                return false
            }
        }

        return true
    }

    func hasChanged() -> Bool {
        if item == nil {
            return true
        }

        return item!.address != address || item!.remotePort != remotePort
            || item!.localPort != localPort || item!.allowLan != allowLan
    }

    func submit() {
        if item != nil {
            withAnimation {
                if let onChange {
                    onChange(address, remotePort, localPort, allowLan)
                }
            }
        } else if let onNewItemAdded {
            let newItem = ForwardRuleConfig(
                address: address,
                remotePort: remotePort,
                localPort: localPort,
                allowLan: allowLan
            )
            onNewItemAdded(newItem)
        }
    }

    func reset() {
        address = item?.address ?? ""
        remotePort = item?.remotePort ?? .single(port: 0)
        localPort = item?.localPort
        allowLan = item?.allowLan ?? false
    }
}

#Preview {
    Group {
        ForwardedItemRow()
        ForwardedItemRow(
            item: ForwardedItemInfo(address: "192.168.1.1", remotePort: .single(port: 1234)))
        ForwardedItemRow(
            item: ForwardedItemInfo(
                address: "192.168.1.1", remotePort: .single(port: 1234), localPort: 4321))
        ForwardedItemRow(
            item: ForwardedItemInfo(address: "192.168.1.1", remotePort: .single(port: 1234)),
            errors: [IpfError.addrInUse])
        ForwardedItemRow(
            item: ForwardedItemInfo(address: "192.168.1.1", remotePort: .single(port: 1234)),
            errors: [IpfError.addrInUse, IpfError.tooManyOpenFiles])
        ForwardedItemRow(
            item: ForwardedItemInfo(
                address: "www.google.com", remotePort: .single(port: 80), localPort: 8080))
    }
}
