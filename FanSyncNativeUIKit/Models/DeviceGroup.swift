import Foundation

/// A user-defined grouping of fans (e.g. "First Floor"). Server-backed via the FanSync
/// WebSocket's lst_group/get_group/set_group/del_group requests (confirmed via packet
/// capture of the real app) — NOT purely local; groups sync across devices/sessions
/// against the real account, matching the real app's behavior.
struct DeviceGroup: Equatable {
    /// The server's opaque group identifier (e.g. "group-1665936580747"), used in every
    /// get_group/set_group/del_group call. Distinct from `name`, the user-facing display
    /// name, which the real app calls `properties.displayName`.
    var serverName: String
    var name: String
    var deviceIds: [String]
}

final class DeviceGroupStore {
    private(set) var groups: [DeviceGroup] = []
    let didChange = ObserverList<[DeviceGroup]>()

    private weak var ws: FanSyncWebSocket?

    init() {}

    /// Must be called once the WebSocket is connected and logged in (mirrors
    /// FanSyncStore.refreshDevices's lifecycle) — groups can't load before then.
    func attach(ws: FanSyncWebSocket) {
        self.ws = ws
        ws.onGroupChange = { [weak self] groupData in
            self?.applyRemoteChange(groupData)
        }
    }

    func reload(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let ws else { completion(.failure(FanSyncError.notConnected)); return }
        ws.listGroups { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let names):
                self.loadGroupDetails(names: names, index: 0, accumulated: [], completion: completion)
            }
        }
    }

    private func loadGroupDetails(
        names: [String],
        index: Int,
        accumulated: [DeviceGroup],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard index < names.count else {
            groups = accumulated
            didChange.notify(groups)
            completion(.success(()))
            return
        }
        guard let ws else { completion(.failure(FanSyncError.notConnected)); return }

        ws.getGroup(name: names[index]) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let data):
                var next = accumulated
                next.append(DeviceGroup(serverName: data.name, name: data.properties.displayName, deviceIds: data.devices))
                self.loadGroupDetails(names: names, index: index + 1, accumulated: next, completion: completion)
            }
        }
    }

    private func applyRemoteChange(_ data: GetGroupResponse.GroupData) {
        if let idx = groups.firstIndex(where: { $0.serverName == data.name }) {
            groups[idx].name = data.properties.displayName
            groups[idx].deviceIds = data.devices
        } else {
            groups.append(DeviceGroup(serverName: data.name, name: data.properties.displayName, deviceIds: data.devices))
        }
        didChange.notify(groups)
    }

    /// The server has no dedicated create endpoint (confirmed: the reference client's
    /// protocol notes list only lst_group/get_group/set_group/del_group) — naming a
    /// group that doesn't exist yet in a set_group call creates it, same call used for
    /// updates. The server-generated-looking name pattern ("group-<timestamp>") seen in
    /// every real group is mirrored here for consistency, though any unique string works.
    func addGroup(name: String) {
        guard let ws else { return }
        let serverName = "group-\(Int(Date().timeIntervalSince1970 * 1000))"
        ws.setGroup(name: serverName, devices: [], displayName: name) { [weak self] result in
            guard let self, case .success = result else { return }
            self.groups.append(DeviceGroup(serverName: serverName, name: name, deviceIds: []))
            self.didChange.notify(self.groups)
        }
    }

    func rename(_ group: DeviceGroup, to newName: String) {
        guard let ws, let idx = groups.firstIndex(where: { $0.serverName == group.serverName }) else { return }
        ws.setGroup(name: group.serverName, devices: group.deviceIds, displayName: newName) { [weak self] result in
            guard let self, case .success = result else { return }
            self.groups[idx].name = newName
            self.didChange.notify(self.groups)
        }
    }

    func delete(_ group: DeviceGroup) {
        guard let ws else { return }
        ws.deleteGroup(name: group.serverName) { [weak self] result in
            guard let self, case .success = result else { return }
            self.groups.removeAll { $0.serverName == group.serverName }
            self.didChange.notify(self.groups)
        }
    }

    /// The real app's group list order is driven by a separate get_user_data response
    /// (`groupDisplayOrder`) we don't currently sync (no reordering UI exists yet), so
    /// this still only reorders the local array — swapping on-device display order
    /// without a corresponding server call. Revisit if reordering needs to persist.
    func moveDown(_ group: DeviceGroup) {
        guard let idx = groups.firstIndex(where: { $0.serverName == group.serverName }), idx < groups.count - 1 else { return }
        groups.swapAt(idx, idx + 1)
        didChange.notify(groups)
    }

    func addDevice(_ deviceId: String, to group: DeviceGroup) {
        guard let ws, let idx = groups.firstIndex(where: { $0.serverName == group.serverName }) else { return }
        guard !groups[idx].deviceIds.contains(deviceId) else { return }
        let updatedDevices = groups[idx].deviceIds + [deviceId]
        ws.setGroup(name: group.serverName, devices: updatedDevices, displayName: group.name) { [weak self] result in
            guard let self, case .success = result else { return }
            self.groups[idx].deviceIds = updatedDevices
            self.didChange.notify(self.groups)
        }
    }

    func removeDevice(_ deviceId: String, from group: DeviceGroup) {
        guard let ws, let idx = groups.firstIndex(where: { $0.serverName == group.serverName }) else { return }
        let updatedDevices = groups[idx].deviceIds.filter { $0 != deviceId }
        ws.setGroup(name: group.serverName, devices: updatedDevices, displayName: group.name) { [weak self] result in
            guard let self, case .success = result else { return }
            self.groups[idx].deviceIds = updatedDevices
            self.didChange.notify(self.groups)
        }
    }

    /// Device ids not currently assigned to any group.
    func ungroupedDeviceIds(allDeviceIds: [String]) -> [String] {
        let grouped = Set(groups.flatMap(\.deviceIds))
        return allDeviceIds.filter { !grouped.contains($0) }
    }
}
