import SwiftUI

struct CreateScheduleView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    @State private var repeatOn = false
    @State private var selectedDays: Set<Int> = []
    @State private var fanOn = false
    @State private var fanPercent: Double = 0
    @State private var lightOn = false

    private let days = ["M", "T", "W", "TH", "F", "SA", "SU"]

    var body: some View {
        ZStack {
            FanSyncTheme.screenBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label("Schedule Name")
                    TextField("My Schedule", text: $name)
                        .font(.title3)
                        .padding(.bottom, 8)
                        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.black.opacity(0.15)), alignment: .bottom)

                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Start Time")
                            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 8) {
                            Label("End Time")
                            DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }
                    Divider()

                    HStack {
                        Label("Repeat")
                        Spacer()
                        Text(repeatOn ? "ON" : "OFF")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(FanSyncTheme.onLabel)
                        Toggle("", isOn: $repeatOn)
                            .labelsHidden()
                            .toggleStyle(FanSyncToggleStyle())
                    }

                    HStack(spacing: 0) {
                        ForEach(days.indices, id: \.self) { i in
                            Button {
                                if selectedDays.contains(i) { selectedDays.remove(i) } else { selectedDays.insert(i) }
                            } label: {
                                Text(days[i])
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FanSyncTheme.onLabel)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle().stroke(selectedDays.contains(i) ? FanSyncTheme.eggplant : .clear, lineWidth: 1.5)
                                    )
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    Divider()

                    Text("Settings")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    HStack {
                        Toggle("", isOn: $fanOn)
                            .labelsHidden()
                            .toggleStyle(FanSyncToggleStyle())
                        Text(fanOn ? "ON" : "OFF")
                            .font(.title3.weight(.bold))
                        Spacer()
                        Text(fanOn ? "\(Int(fanPercent))%" : "--")
                            .font(.title3.weight(.semibold))
                    }
                    Slider(value: $fanPercent, in: 0...100, step: 1)
                        .tint(FanSyncTheme.eggplant)
                        .disabled(!fanOn)
                    Divider()

                    HStack {
                        Label("Light")
                        Spacer()
                        Text(lightOn ? "ON" : "OFF")
                            .font(.title3.weight(.bold))
                        Toggle("", isOn: $lightOn)
                            .labelsHidden()
                            .toggleStyle(FanSyncToggleStyle())
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Create Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}

private struct Label: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.5)
            .foregroundStyle(FanSyncTheme.onLabel)
    }
}
