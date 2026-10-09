import SwiftUI

/// The "More Controls" bottom sheet, matching the reference app's modal presentation
/// (header card + CLOSE bar pinned to the bottom), not a pushed screen.
struct DeviceDetailSheet: View {
    @EnvironmentObject var store: FanSyncStore
    @Environment(\.dismiss) private var dismiss
    let deviceId: String

    @State private var showingSettings = false
    @State private var showingSchedules = false

    private var device: FanDevice? {
        store.devices.first(where: { $0.id == deviceId })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FanSyncTheme.screenBackground.ignoresSafeArea()

                if let device {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 14) {
                                    FanSyncPinwheel(size: 40)
                                    Text(device.displayName)
                                        .font(.title.weight(.regular))
                                        .foregroundStyle(FanSyncTheme.onLabel)
                                }
                                .padding(.top, 24)
                                .padding(.bottom, 20)

                                HStack {
                                    Toggle("", isOn: Binding(
                                        get: { device.fanPower },
                                        set: { store.setFanPower(device, on: $0) }
                                    ))
                                    .labelsHidden()
                                    .toggleStyle(FanSyncToggleStyle())

                                    Text(device.fanPower ? "ON" : "OFF")
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(FanSyncTheme.onLabel)
                                        .padding(.leading, 6)

                                    Spacer()

                                    Text("\(device.fanPercent)%")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(FanSyncTheme.onLabel)
                                    FanSyncPinwheel(color: FanSyncTheme.secondaryLabel, size: 18)
                                }
                                Slider(
                                    value: Binding(
                                        get: { Double(device.fanPercent) },
                                        set: { store.setFanPercent(device, percent: Int($0)) }
                                    ),
                                    in: 0...100, step: 1
                                )
                                .tint(FanSyncTheme.eggplant)
                                .padding(.top, 8)
                                .padding(.bottom, 20)

                                Divider()

                                DetailSection(title: "Breeze Mode") {
                                    FanSyncSegmentedControl(
                                        options: ["Normal", "Fresh Air"],
                                        selection: Binding(
                                            get: { device.fanMode == .freshAir ? 1 : 0 },
                                            set: { store.setFanMode(device, mode: $0 == 1 ? .freshAir : .normal) }
                                        )
                                    )
                                }

                                Divider()

                                DetailSection(title: "Fan Direction") {
                                    FanSyncSegmentedControl(
                                        options: ["Forward", "Reverse"],
                                        selection: Binding(
                                            get: { device.fanDirection == .reverse ? 1 : 0 },
                                            set: { store.setFanDirection(device, direction: $0 == 1 ? .reverse : .forward) }
                                        )
                                    )
                                }

                                Divider()

                                ToggleRow(
                                    title: "Light",
                                    isOn: Binding(
                                        get: { device.lightPower },
                                        set: { store.setLightPower(device, on: $0) }
                                    )
                                )

                                Divider()

                                ToggleRow(
                                    title: "Home Away",
                                    isOn: Binding(
                                        get: { device.homeAway },
                                        set: { store.setHomeAway(device, on: $0) }
                                    )
                                )

                                Divider()

                                HStack(spacing: 16) {
                                    Button {
                                        showingSettings = true
                                    } label: {
                                        Text("Settings")
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .foregroundStyle(.white)
                                            .background(Color.gray.opacity(0.6))
                                            .clipShape(Capsule())
                                    }
                                    Button {
                                        showingSchedules = true
                                    } label: {
                                        Text("Schedules")
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .foregroundStyle(.white)
                                            .background(Color.gray.opacity(0.6))
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.top, 20)
                                .padding(.bottom, 12)
                            }
                            .padding(.horizontal, 20)
                        }

                        Button {
                            dismiss()
                        } label: {
                            Text("CLOSE")
                                .font(.subheadline.weight(.semibold))
                                .tracking(0.5)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(FanSyncTheme.eggplant)
                        }
                    }
                } else {
                    ContentUnavailableView("Device Unavailable", systemImage: "exclamationmark.triangle")
                }
            }
            .navigationDestination(isPresented: $showingSettings) {
                if device != nil { DeviceSettingsView(deviceId: deviceId) }
            }
            .navigationDestination(isPresented: $showingSchedules) {
                if let device { ScheduleListView(deviceName: device.displayName) }
            }
        }
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    let content: Content
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(FanSyncTheme.onLabel)
            content
        }
        .padding(.vertical, 16)
    }
}

private struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(FanSyncTheme.onLabel)
            Spacer()
            Text(isOn ? "ON" : "OFF")
                .font(.title3.weight(.bold))
                .foregroundStyle(FanSyncTheme.onLabel)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(FanSyncToggleStyle())
        }
        .padding(.vertical, 16)
    }
}
