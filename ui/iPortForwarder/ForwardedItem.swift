import Foundation

import Libipf

enum Port: Codable, Equatable {
    case single(port: UInt16)

    var value: UInt16 {
        switch self {
        case .single(let port):
            return port
        }
    }

    private enum CodingKeys: String, CodingKey {
        case single
        case range
    }

    private enum SingleCodingKeys: String, CodingKey {
        case port
    }

    private enum RangeCodingKeys: String, CodingKey {
        case start
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.single) {
            let single = try container.nestedContainer(keyedBy: SingleCodingKeys.self, forKey: .single)
            self = .single(port: try single.decode(UInt16.self, forKey: .port))
            return
        }

        if container.contains(.range) {
            let range = try container.nestedContainer(keyedBy: RangeCodingKeys.self, forKey: .range)
            self = .single(port: try range.decode(UInt16.self, forKey: .start))
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath, debugDescription: "Expected a single port.")
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var single = container.nestedContainer(keyedBy: SingleCodingKeys.self, forKey: .single)
        try single.encode(value, forKey: .port)
    }
}

protocol DisplayableForwardedItem {
    var address: String { get }
    var remotePort: Port { get }
    var localPort: UInt16? { get }
    var allowLan: Bool { get }
}

struct ForwardRuleConfig: Codable, DisplayableForwardedItem, Identifiable, Equatable {
    var id: UUID
    var address: String
    var remotePort: Port
    var localPort: UInt16?
    var allowLan: Bool
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        address: String,
        remotePort: Port,
        localPort: UInt16? = nil,
        allowLan: Bool = false,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.address = address
        self.remotePort = remotePort
        self.localPort = localPort
        self.allowLan = allowLan
        self.isEnabled = isEnabled
    }

    init(item: DisplayableForwardedItem, isEnabled: Bool = true) {
        self.id = UUID()
        self.address = item.address
        self.remotePort = item.remotePort
        self.localPort = item.localPort
        self.allowLan = item.allowLan
        self.isEnabled = isEnabled
    }
}

@MainActor
class ForwardedItem: DisplayableForwardedItem, Identifiable {
    let address: String
    let remotePort: Port
    let localPort: UInt16?
    let allowLan: Bool
    private let forwardRuleId: Int8
    private var hasDeinit = false

    nonisolated var id: Int8 {
        return self.forwardRuleId
    }

    init(
        address: String,
        remotePort: UInt16,
        localPort: UInt16? = nil,
        allowLan: Bool = false
    ) throws {
        self.address = address
        self.remotePort = .single(port: remotePort)
        if let localPort {
            self.localPort = localPort
        } else {
            self.localPort = nil
        }
        self.allowLan = allowLan

        self.forwardRuleId = try forward(
            address: address,
            remotePort: remotePort,
            localPort: localPort ?? remotePort,
            allowLan: allowLan
        )
    }

    init(
        address: String,
        remotePort: Port,
        localPort: UInt16? = nil,
        allowLan: Bool = false
    ) throws {
        self.address = address
        self.remotePort = remotePort
        self.localPort = localPort
        self.allowLan = allowLan

        self.forwardRuleId = try forward(
            address: address,
            remotePort: remotePort.value,
            localPort: localPort ?? remotePort.value,
            allowLan: allowLan
        )
    }

    init(item: DisplayableForwardedItem) throws {
        self.address = item.address
        self.remotePort = item.remotePort
        self.localPort = item.localPort
        self.allowLan = item.allowLan

        self.forwardRuleId = try forward(
            address: address,
            remotePort: remotePort.value,
            localPort: localPort ?? remotePort.value,
            allowLan: allowLan
        )
    }

    deinit {
        if !hasDeinit {
            cancelForward(forwardRuleId: self.forwardRuleId)
        }
    }

    public func destroy() {
        guard !hasDeinit else { return }
        hasDeinit = true
        cancelForward(forwardRuleId: self.forwardRuleId)
    }
}

struct ForwardedItemInfo: Codable, DisplayableForwardedItem {
    let address: String

    let remotePort: Port

    let localPort: UInt16?

    let allowLan: Bool

    init(
        address: String,
        remotePort: Port,
        localPort: UInt16? = nil,
        allowLan: Bool = false
    ) {
        self.address = address
        self.remotePort = remotePort
        self.localPort = localPort
        self.allowLan = allowLan
    }

    init(item: DisplayableForwardedItem) {
        self.address = item.address
        self.remotePort = item.remotePort
        self.localPort = item.localPort
        self.allowLan = item.allowLan
    }
}
