import Foundation

// MARK: - Field codes (from Fanimation's dynamic info-model; treated as defaults)

enum FanField: String {
    case fanPower = "H00"
    case fanMode = "H01"
    case fanPercent = "H02"
    case fanDirection = "H06"
    case lightPower = "H0B"
    case lightPercent = "H0C"
    case homeAway = "H0D"
    case unknown1 = "H05"
    case errorCode = "H0E"
}

enum FanMode: Int {
    case normal = 0
    case freshAir = 1
}

enum FanDirection: Int {
    case forward = 0
    case reverse = 1
}

// MARK: - HTTP session (REST login)

struct SessionLoginRequest: Encodable {
    let email: String
    let password: String
}

struct SessionLoginResponse: Decodable {
    let id: Int
    let token: String
}

struct SessionStatusResponse: Decodable {
    let id: Int?
    let status: String
}

// MARK: - WebSocket request envelopes

protocol WSRequest: Encodable {
    var id: Int { get }
    var request: String { get }
}

struct LoginWSRequest: WSRequest {
    struct Data: Encodable { let token: String }
    let id: Int
    let request = "login"
    let data: Data
}

struct ListDevicesWSRequest: WSRequest {
    let id: Int
    let request = "lst_device"
}

struct GetDeviceWSRequest: WSRequest {
    let id: Int
    let request = "get"
    let device: String
}

struct SetDeviceWSRequest: WSRequest {
    let id: Int
    let request = "set"
    let device: String
    let data: [String: String]
}

// MARK: - WebSocket response envelopes

struct WSEnvelope: Decodable {
    let id: Int?
    let status: String?
    let response: String?
    let event: String?
}

struct WSLoginResponse: Decodable {
    let id: Int
    let status: String
    let response: String
}

struct ListDevicesResponse: Decodable {
    struct Properties: Decodable {
        let displayName: String
        let deviceHasBeenConfigured: Bool?
        let ignoreUpdateVersion: String?
    }
    struct Device: Decodable, Identifiable {
        let owner: String?
        let device: String
        let role: String?
        let properties: Properties
        var id: String { device }
    }
    let id: Int
    let status: String
    let data: [Device]
}

struct GetDeviceResponse: Decodable {
    struct Module: Decodable {
        let firmware_version: String?
        let local_ip: String?
        let ssid: String?
        let mac_address: String?
    }
    struct Esh: Decodable {
        let brand: String?
        let esh_version: String?
        let device_id: String?
        let model: String?
    }
    struct Profile: Decodable {
        let module: Module?
        let esh: Esh?
    }
    struct DeviceData: Decodable {
        let status: [String: Int]
        let fields: [String]?
        let profile: Profile?
        let device: String
        let connected: Int?
        let device_state: String?
    }
    let id: Int
    let status: String
    let data: DeviceData
}

struct DeviceChangeEvent: Decodable {
    struct Changes: Decodable { let status: [String: Int] }
    struct EventData: Decodable { let changes: Changes; let device: String }
    let event: String
    let data: EventData
}

// MARK: - Domain model used by the UI

struct FanDevice: Identifiable, Equatable {
    let id: String // device id
    var displayName: String
    var status: [String: Int]

    var fanPower: Bool { status[FanField.fanPower.rawValue] == 1 }
    var fanPercent: Int { status[FanField.fanPercent.rawValue] ?? 0 }
    var fanMode: FanMode { FanMode(rawValue: status[FanField.fanMode.rawValue] ?? 0) ?? .normal }
    var fanDirection: FanDirection { FanDirection(rawValue: status[FanField.fanDirection.rawValue] ?? 0) ?? .forward }
    var lightPower: Bool { status[FanField.lightPower.rawValue] == 1 }
    var lightPercent: Int { status[FanField.lightPercent.rawValue] ?? 0 }
    var homeAway: Bool { status[FanField.homeAway.rawValue] == 1 }

    mutating func apply(changes: [String: Int]) {
        for (k, v) in changes { status[k] = v }
    }
}
