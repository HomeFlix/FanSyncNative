import SwiftUI

struct MyAccountView: View {
    @EnvironmentObject var store: FanSyncStore
    @AppStorage("timeFormat24h") private var is24h = true
    @State private var showingDeleteConfirm = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("TIME FORMAT: \(is24h ? "24H" : "12H")")
                        .font(.caption.weight(.semibold))
                        .tracking(0.5)
                        .foregroundStyle(FanSyncTheme.onLabel)

                    Button {
                        is24h.toggle()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Set Time Format")
                            Spacer()
                        }
                        .font(.body)
                        .foregroundStyle(.white)
                        .padding(.vertical, 16)
                        .background(FanSyncTheme.eggplant)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    }

                    Text("MY DATA")
                        .font(.caption.weight(.semibold))
                        .tracking(0.5)
                        .foregroundStyle(FanSyncTheme.onLabel)
                        .padding(.top, 16)

                    Button {
                        showingDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete My Account")
                            Spacer()
                        }
                        .font(.body)
                        .foregroundStyle(.white)
                        .padding(.vertical, 16)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("My Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(FanSyncTheme.eggplant, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .confirmationDialog(
            "Deleting your account is irreversible and must be done through Fanimation's account portal, not from this unofficial client.",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("OK", role: .cancel) {}
        }
    }
}
