import SwiftUI

struct MyGroupsView: View {
    @EnvironmentObject var store: FanSyncStore
    @EnvironmentObject var groupStore: DeviceGroupStore

    @State private var actionSheetGroup: DeviceGroup?
    @State private var renamingGroup: DeviceGroup?
    @State private var renameText = ""
    @State private var showingNewGroupPrompt = false
    @State private var newGroupName = ""

    var body: some View {
        ZStack {
            FanSyncTheme.screenBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(groupStore.groups) { group in
                        groupSection(group)
                    }

                    ungroupedSection
                }
            }
        }
        .navigationTitle("My Groups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(FanSyncTheme.eggplant, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingNewGroupPrompt = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .confirmationDialog("Group", isPresented: Binding(get: { actionSheetGroup != nil }, set: { if !$0 { actionSheetGroup = nil } }), presenting: actionSheetGroup) { group in
            Button("Rename group") {
                renameText = group.name
                renamingGroup = group
            }
            Button("Move group down one") { groupStore.moveDown(group) }
            Button("Delete group", role: .destructive) { groupStore.delete(group) }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename Group", isPresented: Binding(get: { renamingGroup != nil }, set: { if !$0 { renamingGroup = nil } })) {
            TextField("Group name", text: $renameText)
            Button("Save") {
                if let group = renamingGroup { groupStore.rename(group, to: renameText) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("New Group", isPresented: $showingNewGroupPrompt) {
            TextField("Group name", text: $newGroupName)
            Button("Add") {
                if !newGroupName.isEmpty { groupStore.addGroup(name: newGroupName) }
                newGroupName = ""
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func groupSection(_ group: DeviceGroup) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text(group.name)
                    .font(.subheadline)
                    .foregroundStyle(FanSyncTheme.secondaryLabel)
                Spacer()
            }
            .overlay(alignment: .trailing) {
                Button { actionSheetGroup = group } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(FanSyncTheme.eggplant)
                        .clipShape(Circle())
                }
                .padding(.trailing, 16)
            }
            .padding(.vertical, 14)
            .background(FanSyncTheme.screenBackground)

            ForEach(group.deviceIds, id: \.self) { deviceId in
                if let device = store.devices.first(where: { $0.id == deviceId }) {
                    GroupDeviceRow(name: device.displayName)
                }
            }
        }
    }

    private var ungroupedSection: some View {
        let ungrouped = groupStore.ungroupedDeviceIds(allDeviceIds: store.devices.map(\.id))
        return VStack(spacing: 0) {
            Text("Device Not in Group")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FanSyncTheme.onLabel)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(FanSyncTheme.screenBackground)

            ForEach(ungrouped, id: \.self) { deviceId in
                if let device = store.devices.first(where: { $0.id == deviceId }) {
                    GroupDeviceRow(name: device.displayName)
                }
            }

            Text("DRAG HERE TO ADD")
                .font(.caption)
                .tracking(0.5)
                .foregroundStyle(FanSyncTheme.secondaryLabel.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        }
    }
}

private struct GroupDeviceRow: View {
    let name: String

    var body: some View {
        HStack {
            Text(name)
                .font(.title3)
                .foregroundStyle(FanSyncTheme.onLabel)
            Spacer()
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(FanSyncTheme.onLabel)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color.white)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.black.opacity(0.08)), alignment: .bottom)
    }
}
