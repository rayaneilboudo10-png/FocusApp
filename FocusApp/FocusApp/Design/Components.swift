import SwiftUI

// MARK: - Containers

struct Card<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    init(padding: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Palette.card, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.Palette.stroke, lineWidth: 1)
            )
    }
}

struct ScreenHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let trailing: Trailing

    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DS.Typography.largeTitle)
                    .foregroundStyle(DS.Palette.text)
                if let subtitle {
                    Text(subtitle)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(DS.Palette.secondary)
                }
            }
            Spacer()
            trailing
        }
        .padding(.top, DS.Space.m)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(DS.Typography.caption)
            .tracking(1.3)
            .foregroundStyle(DS.Palette.tertiary)
            .padding(.leading, 4)
    }
}

struct RowDivider: View {
    var inset: CGFloat = 64
    var body: some View {
        Rectangle()
            .fill(DS.Palette.stroke)
            .frame(height: 1)
            .padding(.leading, inset)
    }
}

// MARK: - Rows

struct IconBadge: View {
    let systemImage: String
    var tint: Color = DS.Palette.text

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(DS.Palette.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct ToggleRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @Binding var isOn: Bool
    var disabled: Bool = false

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 14) {
                IconBadge(systemImage: systemImage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DS.Typography.body.weight(.medium))
                        .foregroundStyle(DS.Palette.text)
                    Text(subtitle)
                        .font(DS.Typography.footnote)
                        .foregroundStyle(DS.Palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(DS.Palette.accent)
        .disabled(disabled)
        .padding(.horizontal, 16)
        .frame(minHeight: 70)
    }
}

struct NavRow: View {
    let title: String
    let value: String
    let systemImage: String
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                IconBadge(systemImage: systemImage)
                Text(title)
                    .font(DS.Typography.body.weight(.medium))
                    .foregroundStyle(DS.Palette.text)
                Spacer(minLength: 8)
                Text(value)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(DS.Palette.secondary)
                    .lineLimit(1)
                Image(systemName: disabled ? "lock.fill" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Palette.tertiary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// MARK: - Controls

struct ChipPicker<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> String
    var disabled: Bool = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isSelected = option == selection
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { selection = option }
                    } label: {
                        Text(label(option))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(isSelected ? Color.black : DS.Palette.text)
                            .padding(.horizontal, 18)
                            .frame(minWidth: 56, minHeight: 44)
                            .background(isSelected ? DS.Palette.text : DS.Palette.raised, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var fill: Color = DS.Palette.text
    var foreground: Color = .black

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: DS.Size.primaryButton)
            .background(fill, in: RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var foreground: Color = DS.Palette.text

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: DS.Size.touch)
            .background(DS.Palette.raised, in: RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous))
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct Badge: View {
    let text: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(DS.Palette.secondary)
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(DS.Palette.raised, in: Capsule())
    }
}
