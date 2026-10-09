import SwiftUI

struct DeviceListView: View {
    var body: some View {
        WithSideMenu { openMenu in
            DeviceListContent(openMenu: openMenu)
        }
    }
}

private struct DeviceListContent: View {
    @EnvironmentObject var store: FanSyncStore
    @EnvironmentObject var groupStore: DeviceGroupStore
    let openMenu: () -> Void

    @State private var selectedTab: String = "All" // "All" or a DeviceGroup.id.uuidString
    @State private var presentedDevice: FanDevice?

    private var visibleDevices: [FanDevice] {
        guard selectedTab != "All",
              let group = groupStore.groups.first(where: { $0.id.uuidString == selectedTab })
        else { return store.devices }
        return store.devices.filter { group.deviceIds.contains($0.id) }
    }

    var body: some View {
        ZStack {
            FanSyncTheme.screenBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                tabs

                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(visibleDevices) { device in
                            DeviceCard(device: device, onMoreControls: { presentedDevice = device })
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                    .padding(.bottom, 24)
                }
                .refreshable { try? await store.refreshDevices() }
            }
        }
        .overlay {
            if store.devices.isEmpty {
                ContentUnavailableView("No Devices", systemImage: "fan", description: Text("Pull to refresh."))
            }
        }
        .sheet(item: $presentedDevice) { device in
            DeviceDetailSheet(deviceId: device.id)
        }
    }

    private var header: some View {
        ZStack {
            FanSyncTheme.eggplant
            HStack {
                Button(action: openMenu) {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.white)
                        .font(.title3)
                }
                Spacer()
                FanSyncPinwheel(color: .white, size: 22)
                    .padding(6)
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                Spacer()
                Menu {
                    Button("Refresh") { Task { try? await store.refreshDevices() } }
                    Button("Log Out", role: .destructive) { store.logout() }
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.white)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 56)
    }

    private var tabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 28) {
                TabButton(title: "All", isSelected: selectedTab == "All") { selectedTab = "All" }
                ForEach(groupStore.groups) { group in
                    TabButton(title: group.name, isSelected: selectedTab == group.id.uuidString) {
                        selectedTab = group.id.uuidString
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 48)
        .background(FanSyncTheme.eggplant)
    }
}

private struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(.white.opacity(isSelected ? 1 : 0.7))
                Rectangle()
                    .fill(isSelected ? Color.white : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct DeviceCard: View {
    @EnvironmentObject var store: FanSyncStore
    let device: FanDevice
    let onMoreControls: () -> Void

    var body: some View {
        FanSyncCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.75, green: 0.8, blue: 0.95).opacity(0.5))
                        .frame(width: 48, height: 48)
                    FanSyncPinwheel(size: 26)
                }

                Text(device.displayName)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(FanSyncTheme.onLabel)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            HStack {
                Text(device.fanPower ? "ON" : "OFF")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(FanSyncTheme.onLabel)

                Spacer()

                Text("\(device.fanPercent)%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FanSyncTheme.onLabel)

                FanSyncPinwheel(color: FanSyncTheme.secondaryLabel, size: 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            HStack(spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { device.fanPower },
                    set: { store.setFanPower(device, on: $0) }
                ))
                .labelsHidden()
                .toggleStyle(FanSyncToggleStyle())

                Slider(
                    value: Binding(
                        get: { Double(device.fanPercent) },
                        set: { store.setFanPercent(device, percent: Int($0)) }
                    ),
                    in: 0...100
                )
                .tint(FanSyncSliderStyle.tint())
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)

            FanSyncBarButton(title: "More Controls", action: onMoreControls)
        }
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}
