import SwiftUI

enum AppAccent: String, CaseIterable, Identifiable, Sendable {
    case orange = "Orange"
    case yellow = "Yellow"
    case purple = "Purple"
    case green = "Green"
    case terracotta = "Clay"
    case moss = "Moss"
    case blue = "Ink"
    case plum = "Plum"

    var id: String { rawValue }

    private var values: (ink: UInt32, darkInk: UInt32, surface: UInt32, darkSurface: UInt32, fill: UInt32, onFill: UInt32) {
        switch self {
        case .orange: (0xA03B00, 0xFFB07C, 0xFFF3E9, 0x28201B, 0xF47B35, 0x191B18)
        case .yellow: (0x735800, 0xF2D466, 0xFBF5DD, 0x282519, 0xF0CE4E, 0x191B18)
        case .purple: (0x7042A8, 0xC6A7EE, 0xF4EFFA, 0x231E2B, 0x7950B8, 0xFFFFFF)
        case .green: (0x2F6545, 0x9CCFAF, 0xEDF4EE, 0x1B2720, 0x32734D, 0xFFFFFF)
        case .terracotta: (0xA13F2C, 0xE6A58D, 0xFAEFEB, 0x291F1C, 0xA13F2C, 0xFFFFFF)
        case .moss: (0x426246, 0xA3C5A3, 0xEFF3EC, 0x20271E, 0x426246, 0xFFFFFF)
        case .blue: (0x335D87, 0xA7C6EB, 0xEDF2F8, 0x1C232D, 0x335D87, 0xFFFFFF)
        case .plum: (0x7B456F, 0xD8AED0, 0xF8EFF5, 0x281E26, 0x7B456F, 0xFFFFFF)
        }
    }

    var color: Color { .adaptive(light: values.ink, dark: values.darkInk) }
    var surfaceColor: Color { .adaptive(light: values.surface, dark: values.darkSurface) }
    var solidColor: Color { Color(hex: values.fill) }
    var onSolidColor: Color { Color(hex: values.onFill) }
    var washColor: Color { Color.paper.mix(with: solidColor, by: 0.14) }
}

private struct AppAccentKey: EnvironmentKey {
    static let defaultValue = AppAccent.orange
}

extension EnvironmentValues {
    @Entry var simulatingReducedMotion = false

    var reduceCardMotion: Bool { accessibilityReduceMotion || simulatingReducedMotion }

    var appAccent: AppAccent {
        get { self[AppAccentKey.self] }
        set { self[AppAccentKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }

    static let paper = Color.adaptive(light: 0xF5F5F1, dark: 0x131515)
    static let surface = Color.adaptive(light: 0xFFFFFF, dark: 0x1C1F1E)
    static let muted = Color.adaptive(light: 0x585B55, dark: 0xB8BDB8)
    static let rule = Color.adaptive(light: 0xD8DBD3, dark: 0x3A403B)
}

struct PageTitle: View {
    let text: String
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 36

    init(text: String, size: CGFloat = 36) {
        self.text = text
        _size = ScaledMetric(wrappedValue: size, relativeTo: .largeTitle)
    }

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .medium))
            .tracking(-1.1)
            .foregroundStyle(.tint)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.medium))
            .tracking(0.7)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct BrandMark: View {
    var body: some View {
        Text("JOEYY")
            .font(.headline.weight(.semibold))
            .tracking(-0.5)
            .foregroundStyle(.tint)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Joeyy")
    }
}

struct PrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.appAccent) private var accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 16)
            .foregroundStyle(accent.onSolidColor)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(accent.solidColor)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.5)
    }
}

struct SectionHeading: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.headline.weight(.medium)).foregroundStyle(.tint)
            Spacer()
            if let detail {
                Text(detail).font(.caption).foregroundStyle(Color.muted)
            }
        }
    }
}

private struct NavigationHeading: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title).font(.headline.weight(.medium)).foregroundStyle(.tint)
                }
            }
    }
}

extension View {
    func appNavigationTitle(_ title: String) -> some View {
        modifier(NavigationHeading(title: title))
    }
}

struct SecondaryButton: ButtonStyle {
    @Environment(\.appAccent) private var accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundStyle(accent.color)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.rule))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct TextButton: ButtonStyle {
    @Environment(\.appAccent) private var accent
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? accent.color : Color.muted)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct AppBackground: View {
    @Environment(\.appAccent) private var accent

    var body: some View {
        RadialGradient(
            colors: [accent.washColor, .paper],
            center: .topTrailing, startRadius: 0, endRadius: 640
        )
        .ignoresSafeArea()
    }
}

struct ClientRow: View {
    let place: Place
    @Environment(\.appAccent) private var accent

    var body: some View {
        HStack(spacing: 16) {
            MerchantCover(place: place, canRetry: false)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 6) {
                Text(place.name)
                    .font(.headline.weight(.medium))
                    .foregroundStyle(accent.color)
                    .fixedSize(horizontal: false, vertical: true)
                Text(place.neighborhood).font(.caption).foregroundStyle(Color.muted)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Color.muted)
        }
        .padding(18)
        .frame(minHeight: 88)
        .contentShape(Rectangle())
    }
}

extension CardStyle {
    var paper: Color { MerchantTheme.sample(for: self).paper }
    var ink: Color { MerchantTheme.sample(for: self).ink }
}

struct PunchCard: View {
    let place: Place
    let stamps: Int
    var compact = false
    var title: String? = nil
    var reward: String? = nil
    /// Renders an unpublished theme, such as the business side's card preview.
    var themeOverride: MerchantTheme? = nil
    @Environment(\.reduceCardMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(MerchantBrandingStore.self) private var branding
    @ScaledMetric(relativeTo: .body) private var diameter: CGFloat = 44

    private var theme: MerchantTheme { themeOverride ?? branding.theme(for: place) }
    private var allowsMotion: Bool { !reduceMotion && theme.allowsMotion }
    private var stock: PunchCardStock { PunchCardStock(artwork: theme.artwork) }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 16 : 24) {
            if compact {
                Text(title ?? place.name).font(.system(.headline, design: theme.fontDesign))
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    rewardTitle
                    Spacer(minLength: 0)
                    rewardTarget
                }
                VStack(alignment: .leading, spacing: 8) { rewardTitle; rewardTarget }
            }
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns),
                spacing: compact ? 12 : 22
            ) {
                ForEach(0..<place.requiredPunches, id: \.self) { index in
                    ZStack {
                        if index < stamps {
                            PunchHole(seed: index)
                                .stroke(.white.opacity(0.7), lineWidth: 3)
                                .offset(y: 0.8)
                            PunchHole(seed: index)
                                .stroke(theme.ink.opacity(0.55), lineWidth: 1.5)
                            PunchHole(seed: index)
                                .fill(.black)
                                .blendMode(.destinationOut)
                                .transition(
                                    allowsMotion
                                        ? .scale(scale: 0.02).combined(with: .opacity) : .opacity
                                )
                        } else {
                            Circle()
                                .strokeBorder(theme.ink, lineWidth: 1)
                            if index == place.requiredPunches - 1 {
                                Circle().strokeBorder(theme.ink, lineWidth: 1)
                                    .padding(compact ? 3 : 4)
                            }
                            Text("\(index + 1)")
                                .font(.system(size: compact ? 10 : 16, weight: .semibold, design: .monospaced))
                                .foregroundStyle(theme.ink)
                                .background(theme.paper)
                        }
                    }
                    .frame(width: compact ? 24 : min(diameter, 54), height: compact ? 24 : min(diameter, 54))
                    .rotationEffect(.degrees(index < stamps ? Double((index * 7) % 5) - 2 : 0))
                    .offset(y: index < stamps ? CGFloat(index % 3 - 1) * 1.5 : 0)
                    .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(stamps) of \(place.requiredPunches) stamps")
            .accessibilityValue(stamps == place.requiredPunches ? "Complete" : "Collecting")
            .accessibilityIdentifier("card.progress")
        }
        .foregroundStyle(theme.ink)
        .padding(compact ? 16 : 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            stock
                .fill(theme.paper)
                .overlay {
                    CardStockTexture()
                        .clipShape(stock)
                }
                .overlay {
                    stock.stroke(.white.opacity(0.35), lineWidth: 0.5).padding(2)
                }
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.24), radius: 1, x: 0, y: 2)
        .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 8)
        .overlay {
            stock.stroke(theme.ink.opacity(0.22), lineWidth: 0.75)
        }
        .phaseAnimator([0, 1, 2], trigger: stamps) { card, phase in
            card
                .scaleEffect(allowsMotion && phase == 1 ? 0.985 : 1)
                .rotation3DEffect(
                    .degrees(allowsMotion && phase == 1 ? -3 : 0),
                    axis: (x: 1, y: 0.2, z: 0), perspective: 0.35
                )
        } animation: { phase in
            allowsMotion
                ? (phase == 1 ? .easeIn(duration: 0.08) : .spring(response: 0.32, dampingFraction: 0.65))
                : nil
        }
    }

    private var rewardTitle: some View {
        Text(reward ?? place.rewardDescription)
            .font(.system(compact ? .subheadline : .title2, design: theme.fontDesign).weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var rewardTarget: some View {
        Text("\(place.requiredPunches) stamps").font(.caption.monospacedDigit()).fixedSize()
    }

    private var columns: Int {
        if compact && !typeSize.isAccessibilitySize { return place.requiredPunches }
        return typeSize.isAccessibilitySize ? 3 : (place.requiredPunches + 1) / 2
    }
}

private struct PunchCardStock: Shape {
    let artwork: MerchantTheme.Artwork

    func path(in rect: CGRect) -> Path {
        switch artwork {
        case .cloud:
            Path(roundedRect: rect, cornerRadius: 24)
        case .stone:
            Path(roundedRect: rect, cornerRadius: 3)
        case .rail:
            Path { path in
                let cut: CGFloat = min(16, rect.width / 8, rect.height / 8)
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
                path.closeSubpath()
            }
        }
    }
}

private struct CardStockTexture: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<180 {
                let x = CGFloat((index * 73 + 19) % 997) / 997 * size.width
                let y = CGFloat((index * 137 + 41) % 991) / 991 * size.height
                var fiber = Path()
                fiber.move(to: CGPoint(x: x, y: y))
                fiber.addLine(to: CGPoint(x: x + CGFloat(index % 3 + 1), y: y + 0.5))
                context.stroke(fiber, with: .color(.white.opacity(0.14)), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct PunchHole: Shape {
    let seed: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for point in 0..<96 {
            let angle = Double(point) / 96 * .pi * 2
            let variation = 1 - Double((point * 13 + seed * 17) % 11) * 0.0025
            let position = CGPoint(
                x: rect.midX + cos(angle) * rect.width * 0.46 * variation,
                y: rect.midY + sin(angle) * rect.height * 0.46 * variation
            )
            if point == 0 { path.move(to: position) } else { path.addLine(to: position) }
        }
        path.closeSubpath()
        return path
    }
}

struct CardPressStyle: ButtonStyle {
    var allowsMotion = true
    @Environment(\.reduceCardMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !allowsMotion || !configuration.isPressed ? 1 : 0.98)
            .rotation3DEffect(
                .degrees(reduceMotion || !allowsMotion || !configuration.isPressed ? 0 : 3),
                axis: (x: 1, y: -0.3, z: 0), perspective: 0.4
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(reduceMotion || !allowsMotion ? nil : .spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct TicketShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 14
        let notch = min(rect.height / 5, 12)
        var path = Path()
        path.move(to: CGPoint(x: r, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: r), control: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - notch))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY + notch),
            control1: CGPoint(x: rect.maxX - notch * 1.4, y: rect.midY - notch),
            control2: CGPoint(x: rect.maxX - notch * 1.4, y: rect.midY + notch)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: 0, y: rect.maxY - r), control: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.midY + notch))
        path.addCurve(
            to: CGPoint(x: 0, y: rect.midY - notch),
            control1: CGPoint(x: notch * 1.4, y: rect.midY + notch),
            control2: CGPoint(x: notch * 1.4, y: rect.midY - notch)
        )
        path.addLine(to: CGPoint(x: 0, y: r))
        path.addQuadCurve(to: CGPoint(x: r, y: 0), control: .zero)
        path.closeSubpath()
        return path
    }
}

struct Notice: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(.tint).frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.tint)
                Text(message).font(.footnote).foregroundStyle(Color.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct PlaceMark: View {
    let place: Place
    var size: CGFloat = 24

    var body: some View {
        Text(place.initials)
        .font(.system(size: size * 0.55, weight: .semibold, design: .serif))
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
