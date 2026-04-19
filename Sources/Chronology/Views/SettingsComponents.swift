import SwiftUI

// MARK: - Section wrapper

struct SettingsSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .foregroundColor(.primary)

                Divider()

                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Labeled row with description

struct SettingsRow<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            Spacer(minLength: 12)
            trailing()
        }
    }
}

// MARK: - Inline callout

struct InlineCallout: View {
    let text: String
    var systemImage: String = "info.circle.fill"
    var tint: Color = .blue

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundColor(tint)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Live preview event card (mirrors EventItemView styling)

struct LiveEventPreview: View {
    @ObservedObject var appViewModel: AppViewModel
    let title: String
    let location: String
    let tint: Color

    private var backgroundFill: some View {
        Group {
            switch appViewModel.eventCardStyle {
            case "filled":
                tint.opacity(0.9)
            case "bordered":
                Color.clear
            case "minimal":
                tint.opacity(0.15)
            default:
                tint.opacity(0.9)
            }
        }
    }

    private var textColor: Color {
        switch appViewModel.eventCardStyle {
        case "filled": return .white
        default: return .primary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(textColor)
                .lineLimit(1)
            Text(location)
                .font(.caption2)
                .foregroundColor(textColor.opacity(0.85))
                .lineLimit(1)
        }
        .padding(8)
        .frame(width: 140, height: 56, alignment: .topLeading)
        .background(backgroundFill)
        .cornerRadius(appViewModel.eventCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: appViewModel.eventCornerRadius)
                .stroke(tint, lineWidth: appViewModel.eventBorderWidth)
        )
        .shadow(color: .black.opacity(appViewModel.eventShadowEnabled ? 0.18 : 0), radius: 3, y: 1)
    }
}

// MARK: - Grid preview swatch

struct GridPreviewSwatch: View {
    @ObservedObject var appViewModel: AppViewModel

    var body: some View {
        Canvas { ctx, size in
            let cols = 4
            let rows = 3
            let cellW = size.width / CGFloat(cols)
            let cellH = size.height / CGFloat(rows)
            let opacity = appViewModel.gridLineOpacity
            let thickness = appViewModel.gridLineThickness

            for c in 1..<cols {
                var p = Path()
                p.move(to: CGPoint(x: CGFloat(c) * cellW, y: 0))
                p.addLine(to: CGPoint(x: CGFloat(c) * cellW, y: size.height))
                ctx.stroke(p, with: .color(.primary.opacity(opacity)), lineWidth: thickness)
            }
            for r in 1..<rows {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: CGFloat(r) * cellH))
                p.addLine(to: CGPoint(x: size.width, y: CGFloat(r) * cellH))
                ctx.stroke(p, with: .color(.primary.opacity(opacity)), lineWidth: thickness)
            }
        }
        .frame(height: 70)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(appViewModel.gridBackgroundOpacity))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}
