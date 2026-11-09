import SwiftUI

struct SetupView: View {
    let onCustomer: () -> Void
    let onBusiness: () -> Void
    var onClose: (() -> Void)? = nil
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        BrandMark()
                        Spacer()
                        if let onClose {
                            Button("Close", action: onClose)
                                .frame(minWidth: 44, minHeight: 44)
                                .accessibilityIdentifier("setup.close")
                        }
                    }
                    SetupCardStack()
                    let layout = sizeClass == .regular && !typeSize.isAccessibilitySize
                        ? AnyLayout(HStackLayout(spacing: 16))
                        : AnyLayout(VStackLayout(spacing: 16))
                    layout {
                        customerDestination
                        businessDestination
                    }
                }
                .padding(24)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
            .background { AppBackground() }
            .toolbar(.hidden, for: .navigationBar)
        }
        .interactiveDismissDisabled(onClose == nil)
    }

    private var customerDestination: some View {
        SetupDestination(
            title: "Customer", subtitle: "Collect stamps", business: false,
            identifier: "setup.customer", action: onCustomer
        )
    }

    private var businessDestination: some View {
        SetupDestination(
            title: "Business", subtitle: "Create a program", business: true,
            identifier: "setup.business", action: onBusiness
        )
    }
}

private struct SetupDestination: View {
    let title: String
    let subtitle: String
    let business: Bool
    let identifier: String
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                if !typeSize.isAccessibilitySize {
                    SetupArtwork(business: business)
                        .frame(width: 92, height: 94)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(.title2.weight(.medium))
                    Text(subtitle).font(.subheadline).foregroundStyle(Color.muted)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.title3)
                    .accessibilityHidden(true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .foregroundStyle(Color.primary)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.rule))
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(CardPressStyle())
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
        .accessibilityIdentifier(identifier)
    }
}

private struct SetupArtwork: View {
    let business: Bool

    var body: some View {
        ZStack {
            ForEach(business ? [2, 1, 0] : [0], id: \.self) { index in
                MerchantCover(place: Place.samples[index], canRetry: false)
                    .frame(width: business ? 58 : 78, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(alignment: .bottom) {
                        if !business {
                            HStack(spacing: 5) {
                                ForEach(0..<3) { _ in
                                    Circle().fill(Color.surface).frame(width: 10, height: 10)
                                }
                            }
                            .padding(.bottom, 12)
                        }
                    }
                    .rotationEffect(.degrees(business ? Double(index - 1) * 13 : -8))
                    .offset(x: business ? CGFloat(index - 1) * 16 : 0)
                    .shadow(color: .black.opacity(0.12), radius: 3, y: 3)
            }
        }
    }
}

private struct SetupCardStack: View {
    @Environment(\.reduceCardMotion) private var reduceMotion
    @Environment(MerchantBrandingStore.self) private var branding
    @State private var appeared = false

    private var allowsMotion: Bool {
        !reduceMotion && Place.samples.allSatisfy { branding.theme(for: $0).allowsMotion }
    }

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width - 44, 350)
            ZStack {
                ForEach([2, 1], id: \.self) { index in
                    MerchantCover(place: Place.samples[index], canRetry: false)
                        .frame(width: width, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .rotationEffect(.degrees(index == 1 ? 8 : -8))
                        .offset(x: index == 1 ? 12 : -12, y: CGFloat(-index) * 22)
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 3)
                }
                PunchCard(
                    place: Place.samples[0], stamps: 5, compact: true,
                    title: "JOEYY Intl", reward: "Stamp protocol"
                )
                    .frame(width: width)
                    .offset(y: 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 230)
        .dynamicTypeSize(.medium)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .offset(y: appeared || !allowsMotion ? 0 : 14)
        .opacity(appeared || !allowsMotion ? 1 : 0)
        .onAppear {
            withAnimation(allowsMotion ? .spring(response: 0.5, dampingFraction: 0.8) : nil) {
                appeared = true
            }
        }
    }
}
