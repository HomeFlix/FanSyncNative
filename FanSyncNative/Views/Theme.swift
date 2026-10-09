import SwiftUI

/// Visual theme matched to the official FanSync app's look: a deep eggplant/purple
/// header and action bar, light gray device cards, and purple accents throughout.
enum FanSyncTheme {
    static let eggplant = Color(red: 0.26, green: 0.09, blue: 0.27)      // header / bottom bar
    static let eggplantDark = Color(red: 0.20, green: 0.06, blue: 0.21)  // pressed/shadow state
    static let accent = Color(red: 0.42, green: 0.14, blue: 0.44)        // slider fill / toggle on
    static let cardBackground = Color(red: 0.95, green: 0.95, blue: 0.96)
    static let screenBackground = Color(red: 0.90, green: 0.90, blue: 0.92)
    static let onLabel = Color.black.opacity(0.85)
    static let secondaryLabel = Color.black.opacity(0.45)
}

struct FanSyncCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(FanSyncTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct FanSyncBarButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.subheadline.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(FanSyncTheme.eggplant)
        }
        .buttonStyle(.plain)
    }
}

struct FanSyncToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack {
                Capsule()
                    .fill(configuration.isOn ? FanSyncTheme.accent.opacity(0.35) : Color.black.opacity(0.15))
                    .frame(width: 50, height: 30)
                Circle()
                    .fill(configuration.isOn ? FanSyncTheme.accent : Color.white)
                    .shadow(radius: 1)
                    .frame(width: 26, height: 26)
                    .offset(x: configuration.isOn ? 10 : -10)
            }
        }
        .buttonStyle(.plain)
    }
}

struct FanSyncSliderStyle {
    static func tint() -> Color { FanSyncTheme.eggplant }
}

/// The 4-blade pinwheel glyph used in place of a literal fan icon, matching the
/// app's device icon and header logo.
struct FanSyncPinwheel: View {
    var color: Color = FanSyncTheme.eggplant
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            ForEach(0..<4) { i in
                Capsule()
                    .fill(color)
                    .frame(width: size * 0.42, height: size * 0.9)
                    .offset(y: -size * 0.23)
                    .rotationEffect(.degrees(Double(i) * 90))
            }
        }
        .frame(width: size, height: size)
    }
}

/// Two-option pill segmented control matching the "NORMAL / FRESH AIR" breeze mode selector.
struct FanSyncSegmentedControl: View {
    let options: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { i in
                Button {
                    selection = i
                } label: {
                    Text(options[i].uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(0.3)
                        .foregroundStyle(selection == i ? .white : FanSyncTheme.secondaryLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selection == i ? FanSyncTheme.eggplant : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.black.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}
