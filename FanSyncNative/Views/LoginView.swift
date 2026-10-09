import SwiftUI

struct LoginView: View {
    @EnvironmentObject var store: FanSyncStore
    @State private var email = ""
    @State private var password = ""
    @State private var remember = true

    var body: some View {
        ZStack {
            FanSyncTheme.eggplant.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "fan.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundStyle(.white)
                    .padding(18)
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))

                Text("FanSync")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                VStack(spacing: 14) {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(FanSyncTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding(14)
                        .background(FanSyncTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Toggle("Remember me", isOn: $remember)
                        .toggleStyle(FanSyncToggleStyle())
                        .tint(.white)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 32)

                if case .error(let message) = store.state {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    Task { await store.login(email: email, password: password, remember: remember) }
                } label: {
                    if store.state == .loggingIn || store.state == .connecting {
                        ProgressView()
                            .tint(FanSyncTheme.eggplant)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Text("LOG IN")
                            .font(.subheadline.weight(.semibold))
                            .tracking(0.5)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .foregroundStyle(FanSyncTheme.eggplant)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .disabled(email.isEmpty || password.isEmpty || store.state == .loggingIn || store.state == .connecting)
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
    }
}
