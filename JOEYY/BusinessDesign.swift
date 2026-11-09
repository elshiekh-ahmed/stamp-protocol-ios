import SwiftUI
import UIKit

// Business-side building blocks. They reuse the customer app's tokens (PageTitle, Color.surface,
// Color.rule, CardPressStyle) and its card views (MerchantArtwork, PunchCard) so a business sees
// its card exactly as customers will.

/// Page title row used at the top of every business tab, with the bug-report button on the trailing edge.
struct PageHeader<Trailing: View>: View {
    let title: String
    let identifier: String
    let trailing: Trailing

    init(_ title: String, identifier: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.identifier = identifier
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            PageTitle(text: title)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(identifier)
            Spacer(minLength: 8)
            trailing
            BugReportButton()
        }
    }
}

extension PageHeader where Trailing == EmptyView {
    init(_ title: String, identifier: String) {
        self.init(title, identifier: identifier) { EmptyView() }
    }
}

/// A business logo, or the business's initials when none has been uploaded.
struct LogoView: View {
    let data: Data?
    var name = ""
    var size: CGFloat = 44
    @Environment(\.appAccent) private var accent

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if !initials.isEmpty {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold, design: .serif))
                    .foregroundStyle(accent.color)
            } else {
                Image(systemName: "storefront")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.26)
                    .foregroundStyle(accent.color)
            }
        }
        .frame(width: size, height: size)
        .background(accent.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityHidden(true)
    }
}

/// The card's cover: the business's photo, or the customer app's generated artwork for the theme.
struct BusinessCover: View {
    let theme: MerchantTheme
    let coverJPEG: Data?

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let coverJPEG, let image = UIImage(data: coverJPEG) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    MerchantArtwork(theme: theme)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }
}

/// The business's card as it appears in a customer's Home collection (mirrors PlaceGalleryTile).
struct BusinessCardTile: View {
    let name: String
    let location: String
    let reward: String
    let requiredPunches: Int
    let design: CardDesign
    var detail: String? = nil

    var body: some View {
        let theme = design.theme
        VStack(alignment: .leading, spacing: 0) {
            BusinessCover(theme: theme, coverJPEG: design.coverJPEG)
                .frame(height: theme.galleryHeight)
            VStack(alignment: .leading, spacing: 10) {
                Text(name)
                    .font(.system(.title2, design: theme.fontDesign).weight(.medium))
                if !location.isEmpty {
                    Text(location).font(.caption).fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(reward.isEmpty ? "Describe the reward" : reward).font(.subheadline)
                    Text(detail ?? "\(requiredPunches) stamps")
                        .font(.caption.monospacedDigit())
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(theme.ink)
            .background(theme.paper)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.ink.opacity(0.18)))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(reward.isEmpty ? "no reward yet" : reward)")
        .accessibilityValue(detail ?? "\(requiredPunches) stamps")
    }
}

/// A large tappable choice, styled like the setup landing's Customer and Business destinations.
struct BusinessDestination: View {
    let title: String
    let subtitle: String
    let symbol: String
    let identifier: String
    let action: () -> Void
    @Environment(\.appAccent) private var accent
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                if !typeSize.isAccessibilitySize {
                    Image(systemName: symbol)
                        .font(.title)
                        .foregroundStyle(accent.color)
                        .frame(width: 64, height: 64)
                        .background(accent.surfaceColor, in: RoundedRectangle(cornerRadius: 12))
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
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
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
