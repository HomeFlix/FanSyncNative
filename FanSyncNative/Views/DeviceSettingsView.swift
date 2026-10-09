import SwiftUI

struct DeviceSettingsView: View {
    @EnvironmentObject var store: FanSyncStore
    @Environment(\.dismiss) private var dismiss
    let deviceId: String

    @State private var nameDraft: String = ""
    @State private var hideLightDimmer = false
    @State private var showingDeleteConfirm = false

    private var device: FanDevice? {
        store.devices.first(where: { $0.id == deviceId })
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            if let device {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Label("DEVICE NAME")

                        TextField("Device name", text: $nameDraft)
                            .font(.title3)
                            .padding(.bottom, 8)
                            .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.black.opacity(0.15)), alignment: .bottom)

                        Button {
                            // Device rename isn't exposed by the reverse-engineered `set`
                            // protocol (only status fields H00-H0E are known); this is a
                            // placeholder until that call is confirmed.
                        } label: {
                            FilledPill(title: "Save", background: FanSyncTheme.accent.opacity(0.5))
                        }

                        HStack(spacing: 6) {
                            Label("EXTRA DEVICE CONTROLS")
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(FanSyncTheme.onLabel)
                        }
                        .padding(.top, 8)

                        HStack {
                            Text("HIDE LIGHT DIMMER")
                                .font(.subheadline)
                                .foregroundStyle(FanSyncTheme.onLabel)
                            Spacer()
                            Toggle("", isOn: $hideLightDimmer)
                                .labelsHidden()
                                .toggleStyle(FanSyncToggleStyle())
                        }

                        Label("BLADE CALIBRATION")
                            .padding(.top, 8)
                        Button {} label: {
                            FilledPill(title: "BLADE CALIBRATION")
                        }

                        Label("FAMILY SHARING")
                            .padding(.top, 8)
                        Button {} label: {
                            FilledPill(title: "SHARE DEVICE")
                        }

                        Label("SOFTWARE VERSION")
                            .padding(.top, 8)
                        if let fw = device.status["firmware"] {
                            Text("\(fw)")
                        } else {
                            Text("—")
                                .foregroundStyle(FanSyncTheme.secondaryLabel)
                        }
                        Button {
                            Task { try? await store.refreshDevices() }
                        } label: {
                            FilledPill(title: "Check for Updates")
                        }

                        Label("MODEL #")
                            .padding(.top, 8)
                        Text(device.id)
                            .foregroundStyle(FanSyncTheme.secondaryLabel)

                        Color.clear.frame(height: 16)

                        VStack(spacing: 12) {
                            Text("Delete Device")
                                .font(.title2.weight(.medium))
                            Text("Note, as the device owner, removing this device will also remove access for anyone you have invited as a guest. Guests will need to be invited again.")
                                .font(.subheadline)
                                .foregroundStyle(FanSyncTheme.secondaryLabel)
                                .multilineTextAlignment(.center)

                            Button {
                                showingDeleteConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "xmark")
                                    Text("Delete Device")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .foregroundStyle(.white)
                                .background(Color.red)
                                .clipShape(Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .background(FanSyncTheme.screenBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(20)
                }
                .onAppear { nameDraft = device.displayName }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(FanSyncTheme.eggplant, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .confirmationDialog(
            "Deleting a device isn't supported by this client yet.",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("OK", role: .cancel) {}
        }
    }
}

private struct Label: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .tracking(0.5)
            .foregroundStyle(FanSyncTheme.onLabel)
    }
}

private struct FilledPill: View {
    let title: String
    var background: Color = FanSyncTheme.eggplant

    var body: some View {
        HStack {
            Spacer()
            Text(title.uppercased())
            Spacer()
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.white)
        .padding(.vertical, 16)
        .background(background)
        .clipShape(Capsule())
    }
}
