import Foundation

/// A user-defined, on-device grouping of fans (e.g. "First Floor"). Mirrors the My Groups
/// screen in the official app. Not backed by any Fanimation cloud API — purely local
/// organization, persisted to disk since this is a single-user personal app.
struct DeviceGroup: Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var deviceIds: [String]
}

final class DeviceGroupStore {
    private(set) var groups: [DeviceGroup] = []
    let didChange = ObserverList<[DeviceGroup]>()

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("groups.json")
    }()

    init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([DeviceGroup].self, from: data)
        else { return }
        groups = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        try? data.write(to: fileURL)
        didChange.notify(groups)
    }

    func addGroup(name: String) {
        groups.append(DeviceGroup(name: name, deviceIds: []))
        save()
    }

    func rename(_ group: DeviceGroup, to newName: String) {
        guard let idx = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[idx].name = newName
        save()
    }

    func delete(_ group: DeviceGroup) {
        groups.removeAll { $0.id == group.id }
        save()
    }

    func moveDown(_ group: DeviceGroup) {
        guard let idx = groups.firstIndex(where: { $0.id == group.id }), idx < groups.count - 1 else { return }
        groups.swapAt(idx, idx + 1)
        save()
    }

    func addDevice(_ deviceId: String, to group: DeviceGroup) {
        guard let idx = groups.firstIndex(where: { $0.id == group.id }) else { return }
        if !groups[idx].deviceIds.contains(deviceId) {
            groups[idx].deviceIds.append(deviceId)
            save()
        }
    }

    func removeDevice(_ deviceId: String, from group: DeviceGroup) {
        guard let idx = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[idx].deviceIds.removeAll { $0 == deviceId }
        save()
    }

    /// Device ids not currently assigned to any group.
    func ungroupedDeviceIds(allDeviceIds: [String]) -> [String] {
        let grouped = Set(groups.flatMap(\.deviceIds))
        return allDeviceIds.filter { !grouped.contains($0) }
    }
}
