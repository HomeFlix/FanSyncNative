import SwiftUI

/// Scheduling isn't covered by the reverse-engineered FanSync protocol (no schedule-related
/// request type was observed in the reference client), so this is a local-only UI stub that
/// matches the reference app's look. It does not currently read or write anything server-side.
struct ScheduleListView: View {
    let deviceName: String
    @State private var showingCreate = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("\(deviceName)'s Schedules")
                    .font(.title2.weight(.medium))
                    .padding(.top, 32)

                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "calendar")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                        .frame(width: 100, height: 100)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Circle())

                    Text("No Schedules")
                        .font(.title3.weight(.semibold))
                }

                Button {
                    showingCreate = true
                } label: {
                    Text("Create a Schedule")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .background(FanSyncTheme.eggplant)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 20)

                Spacer()
                Spacer()
            }
        }
        .navigationTitle("Schedule List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(FanSyncTheme.eggplant, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingCreate = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(isPresented: $showingCreate) {
            CreateScheduleView()
        }
    }
}
