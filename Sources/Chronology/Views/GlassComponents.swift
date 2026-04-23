import SwiftUI

// MARK: - Capsule pill button

struct GlassPill: View {
    let title: String
    var icon: String? = nil
    var isOn: Bool = false
    var accent: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon).font(.system(size: 11, weight: .medium))
                }
                Text(title).font(.system(size: 12.5, weight: .medium))
            }
            .padding(.horizontal, 12).frame(height: 28)
            .foregroundStyle(isOn ? .white : Color.primary)
            .background(
                Capsule().fill(isOn ? AnyShapeStyle(accent) : AnyShapeStyle(.ultraThinMaterial))
            )
            .overlay(
                Capsule().strokeBorder(
                    isOn ? accent.opacity(0.6) : Color.primary.opacity(0.08),
                    lineWidth: 0.5)
            )
            .shadow(color: isOn ? accent.opacity(0.3) : .black.opacity(0.05),
                    radius: isOn ? 8 : 3, y: isOn ? 4 : 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Icon-only circular button

struct IconCircleButton: View {
    let systemName: String
    var help: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Capsule segmented control

struct GlassSegmented<T: Hashable>: View {
    @Binding var selection: T
    let options: [(T, String, String?)] // value, label, optional SF symbol

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { (value, label, icon) in
                Button {
                    withAnimation(.spring(duration: 0.25)) { selection = value }
                } label: {
                    HStack(spacing: 5) {
                        if let icon = icon {
                            Image(systemName: icon).font(.system(size: 10.5))
                        }
                        Text(label).font(.system(size: 12.5, weight: .medium))
                    }
                    .padding(.horizontal, 14).frame(height: 26)
                    .foregroundStyle(selection == value ? Color.primary : Color.secondary)
                    .background(
                        ZStack {
                            if selection == value {
                                Capsule().fill(.background)
                                    .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
    }
}

// MARK: - Modern toggle

struct GlassToggle: View {
    @Binding var isOn: Bool
    var accent: Color = .accentColor

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? accent : Color.primary.opacity(0.14))
                    .frame(width: 34, height: 20)
                Circle().fill(Color.white)
                    .frame(width: 16, height: 16)
                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                    .padding(2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Colored dot

struct ColorDot: View {
    let hue: Double
    var size: CGFloat = 10
    var glow: Bool = true

    var body: some View {
        Circle().fill(Color.eventBar(hue: hue))
            .frame(width: size, height: size)
            .shadow(color: glow ? Color.eventBar(hue: hue).opacity(0.8) : .clear,
                    radius: glow ? 4 : 0)
    }
}

// MARK: - Section caption

struct SectionCaption: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(.tertiary)
    }
}

// MARK: - Now indicator

struct NowIndicator: View {
    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(Color(red: 1.0, green: 0.23, blue: 0.19))
                .frame(height: 1)
                .shadow(color: .red.opacity(0.6), radius: 4)
            Circle().fill(Color(red: 1.0, green: 0.23, blue: 0.19))
                .frame(width: 9, height: 9)
                .overlay(Circle().strokeBorder(.red.opacity(0.18), lineWidth: 3).blur(radius: 0.5))
                .offset(x: -4)
                .shadow(color: .red.opacity(0.7), radius: 5)
        }
    }
}
