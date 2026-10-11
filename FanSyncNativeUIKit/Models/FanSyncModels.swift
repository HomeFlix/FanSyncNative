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

/// Decodes an id field that the server sends inconsistently as either a JSON number
/// or a JSON string (confirmed: POST /api:1/session returns `"id":"28549"`, a string,
/// despite looking numeric) — JSONDecoder does not coerce between the two by default.
struct StringOrIntID: Decodable {
    let value: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else {
            let stringValue = try container.decode(String.self)
            guard let intValue = Int(stringValue) else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Expected a numeric string, got \(stringValue)"
                )
            }
            value = intValue
        }
    }
}

struct SessionLoginResponse: Decodable {
    let id: StringOrIntID
    let token: String
}

struct SessionStatusResponse: Decodable {
    let id: StringOrIntID?
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
    // Values must be encoded as JSON numbers, not strings — confirmed via packet
    // capture of the real app ("data":{"H06":0}, not "data":{"H06":"0"}). Sending
    // strings here was a real bug: the server silently accepted the request (we got
    // a status:"ok" response) but never actually applied the change, which is why
    // fan power/speed/direction toggles appeared to do nothing.
    let data: [String: Int]
}

struct ListGroupsWSRequest: WSRequest {
    let id: Int
    let request = "lst_group"
}

struct GetGroupWSRequest: WSRequest {
    struct Data: Encodable { let name: String }
    let id: Int
    let request = "get_group"
    let data: Data
}

/// Mirrors the real app's exact update pattern (confirmed via packet capture): the
/// client reads a group's current member list, applies the local add/remove, and sends
/// the FULL resulting device list back — there is no separate add-one/remove-one
/// request. `properties.displayName` is always included too, even when unchanged.
struct SetGroupWSRequest: WSRequest {
    struct Properties: Encodable { let displayName: String }
    struct Data: Encodable {
        let name: String
        let devices: [String]
        let properties: Properties
    }
    let id: Int
    let request = "set_group"
    let data: Data
}

/// `del_group`'s shape isn't confirmed by packet capture (we never captured a delete),
/// but it's named/confirmed to exist in the reference Python client's protocol notes.
/// Shape is inferred by direct analogy to get_group's {name} data payload, which is the
/// consistent pattern across every other named-resource request in this protocol.
struct DeleteGroupWSRequest: WSRequest {
    struct Data: Encodable { let name: String }
    let id: Int
    let request = "del_group"
    let data: Data
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
        // Confirmed via packet capture: devices with a non-dimmable light fixture
        // report "hideLightDimmer":true (e.g. Great Room, Porch); devices with a
        // dimmable fixture omit the key entirely (e.g. Guest Room, Jack and Jill) —
        // absence means "don't hide it", i.e. the dimmer IS supported.
        let hideLightDimmer: Bool?
        let hideFanDirection: Bool?
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

/// `lst_group` just returns an array of group name strings — their display names and
/// membership require a follow-up `get_group` per name (confirmed via packet capture).
struct ListGroupsResponse: Decodable {
    let id: Int
    let status: String
    let data: [String]
}

struct GetGroupResponse: Decodable {
    struct Properties: Decodable { let displayName: String }
    struct GroupData: Decodable {
        let properties: Properties
        let name: String
        let devices: [String]
    }
    let id: Int
    let status: String
    let data: GroupData
}

struct SetGroupResponse: Decodable {
    let id: Int
    let status: String
}

/// Unsolicited push the server sends to all connected sessions after a successful
/// set_group, so other devices/tabs stay in sync (confirmed via packet capture:
/// {"data":{...same shape as GetGroupResponse.data...},"event":"set_group"}).
struct GroupChangeEvent: Decodable {
    let event: String
    let data: GetGroupResponse.GroupData
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
    // Both fields are optional: confirmed via packet capture that `changes` can be
    // JUST {"connected":1} (no status key at all, e.g. when a physical device comes
    // back online) or JUST {"status":{...}} (a field value changed) — never assume
    // both are always present in the same push.
    struct Changes: Decodable { let status: [String: Int]?; let connected: Int? }
    struct EventData: Decodable { let changes: Changes; let device: String }
    let event: String
    let data: EventData
}

// MARK: - Domain model used by the UI

struct FanDevice: Identifiable, Equatable {
    let id: String // device id
    var displayName: String
    var status: [String: Int]
    // Whether the physical device is currently reachable (confirmed via packet
    // capture: top-level `connected` field in get responses and device_change pushes,
    // e.g. {"data":{"changes":{"connected":1},"device":"..."},"event":"device_change"}
    // — separate from `status`, not one of the H-prefixed fields). Powering the
    // device off at the physical switch flips this to false; the real app grays out
    // the power toggle and speed slider while it's false.
    var isConnected: Bool = true
    // From ListDevicesResponse.Properties — per-device capability flags, not part of
    // `status`. Absence (nil) means the capability IS supported (see the field's own
    // doc comment on ListDevicesResponse.Properties).
    var hidesLightDimmer: Bool = false
    var hidesFanDirection: Bool = false

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
