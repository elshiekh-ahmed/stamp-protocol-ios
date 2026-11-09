import SwiftUI
import UIKit

struct PlaceDetailView: View {
    let place: Place
    @Environment(LoyaltyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.reduceCardMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(MerchantBrandingStore.self) private var branding
    @State private var sheet: DetailSheet?
    @State private var confirmingRedemption = false
    @State private var stampFeedback = false
    @State private var confirmingArchive = false
    @State private var feedback: String?
    @State private var failure: String?

    private var membership: Membership? { store.membership(for: place) }
    private var stamps: Int { membership?.stamps ?? 0 }
    private var active: Bool { membership?.archived == false }
    private var complete: Bool { stamps == place.requiredPunches }
    private var theme: MerchantTheme { branding.theme(for: place) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                ViewThatFits(in: .horizontal) {
                    if !typeSize.isAccessibilitySize {
                        HStack(alignment: .top, spacing: 32) {
                            establishmentHeader.frame(minWidth: 340)
                            loyaltySection.frame(minWidth: 320)
                        }
                    }
                    VStack(alignment: .leading, spacing: 24) {
                        establishmentHeader
                        loyaltySection
                    }
                }

                if let feedback {
                    Label(feedback, systemImage: "checkmark.circle")
                        .font(.footnote).foregroundStyle(.tint)
                        .accessibilityIdentifier("detail.feedback")
                }

                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(place.address)
                        if let url = URL(string: place.website) {
                            Link("Business website", destination: url)
                        }
                        Text("One stamp per visit. Claiming saves a coupon in Redeemed and starts a new card. No expiry.")
                        Text("Demo offers, artwork, and client IDs. Not affiliated with these businesses.")
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Client ID").font(.caption).foregroundStyle(.tint)
                            Text(place.clientID)
                                .font(.footnote.monospaced())
                                .textSelection(.enabled)
                                .accessibilityIdentifier("detail.clientID")
                            Button("Copy client ID", systemImage: "doc.on.doc") {
                                UIPasteboard.general.string = place.clientID
                                feedback = "Client ID copied."
                            }
                            .frame(minHeight: 44)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.muted)
                    .padding(.top, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Text("Program details").font(.subheadline.weight(.medium))
                }
                .padding(20)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: 8))

                if let membership {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeading(title: "Activity")
                        ForEach(membership.events.prefix(3)) { HistoryRow(event: $0) }
                        if membership.events.count > 3 {
                            Button("See all activity") { sheet = .history }
                                .font(.subheadline).frame(minHeight: 44)
                        }
                    }
                    .padding(20)
                    .background(Color.surface, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(24)
            .frame(maxWidth: 1_100)
            .frame(maxWidth: .infinity)
        }
        .background { AppBackground() }
        .appNavigationTitle("Card")
        .sensoryFeedback(.impact(weight: .medium), trigger: stampFeedback)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if active {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(membership?.isFavorite == true ? "Remove favorite" : "Favorite", systemImage: "star") {
                            do { try store.setFavorite(membership?.isFavorite != true, for: place) }
                            catch { failure = error.localizedDescription }
                        }
                        Button("Groups", systemImage: "folder") { sheet = .groups }
                        Button("Preview branding", systemImage: "photo") { sheet = .branding }
                        Button("Archive card", systemImage: "archivebox") { confirmingArchive = true }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Card options")
                }
            }
        }
        .sheet(item: $sheet) { item in
            switch item {
            case .branding:
                BrandingPreviewView(place: place)
            case .groups:
                GroupMembershipView(place: place)
            case .wallet:
                WalletStatusView()
            case .showCard:
                CounterCardView(place: place)
            case .history:
                NavigationStack {
                    List(membership?.events ?? []) { event in
                        HistoryRow(event: event).listRowBackground(Color.surface)
                    }
                    .scrollContentBackground(.hidden)
                    .background { AppBackground() }
                    .appNavigationTitle("Activity")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { sheet = nil }
                        }
                    }

                }
            case .coupon(let id):
                NavigationStack {
                    CouponDetailView(couponID: id)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { sheet = nil }
                            }
                        }
                }
            }
        }
        .alert("Claim \(place.rewardDescription)?", isPresented: $confirmingRedemption) {
            Button("Claim reward") {
                do {
                    let coupon = try store.claimReward(at: place)
                    sheet = .coupon(coupon.id)
                } catch {
                    failure = error.localizedDescription
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save a demo coupon in Redeemed and start a fresh card.")
        }
        .confirmationDialog("Archive this card?", isPresented: $confirmingArchive, titleVisibility: .visible) {
            Button("Archive card") {
                store.setArchived(true, for: place)
                dismiss()
            }
        } message: {
            Text("Stamps and activity are retained. Restore the card from Archived cards on Home.")
        }
        .alert("Unable to update card", isPresented: Binding(
            get: { failure != nil },
            set: { if !$0 { failure = nil } }
        )) {
            Button("OK") { failure = nil }
        } message: {
            Text(failure ?? "")
        }
    }

    private var establishmentHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            MerchantCover(place: place)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityIdentifier("detail.cover")
            Text(place.name)
                .font(.system(.title, design: theme.fontDesign).weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(place.neighborhood).font(.subheadline).foregroundStyle(Color.muted)
        }
    }

    private var loyaltySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            PunchCard(place: place, stamps: stamps)
            if active {
                if complete {
                    Button("Claim reward") { confirmingRedemption = true }
                        .buttonStyle(PrimaryButton())
                        .accessibilityIdentifier("detail.claim")
                } else {
                    Button("Add demo stamp") {
                        do {
                            try withAnimation(reduceMotion || !theme.allowsMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8)) {
                                try store.addStamp(to: place)
                            }
                            stampFeedback.toggle()
                        } catch { failure = error.localizedDescription }
                    }
                    .buttonStyle(PrimaryButton())
                    .accessibilityIdentifier("detail.simulateVisit")
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { customerCodeButton; walletButton }
                    VStack(spacing: 12) { customerCodeButton; walletButton }
                }
                .buttonStyle(SecondaryButton())
            } else {
                Button(membership == nil ? "Add card" : "Restore card") { store.join(place) }
                    .buttonStyle(PrimaryButton())
                    .accessibilityIdentifier("detail.join")
            }
            Text("Demo program. Not a real offer.")
                .font(.footnote.weight(.medium)).foregroundStyle(Color.primary)
        }
    }

    private var customerCodeButton: some View {
        Button("Show card") { sheet = .showCard }.accessibilityIdentifier("detail.showCard")
    }

    private var walletButton: some View {
        Button("Apple Wallet") { sheet = .wallet }.accessibilityIdentifier("detail.wallet")
    }
}

private enum DetailSheet: Identifiable {
    case wallet, showCard, history, branding, groups
    case coupon(UUID)

    var id: String {
        switch self {
        case .branding: "branding"
        case .groups: "groups"
        case .wallet: "wallet"
        case .showCard: "showCard"
        case .history: "history"
        case .coupon(let id): "coupon.\(id.uuidString)"
        }
    }
}

struct HistoryRow: View {
    let event: VisitEvent
    @Environment(\.appAccent) private var accent

    private var title: String {
        switch event.kind {
        case .joined: "Program joined"
        case .stamp: "Stamp collected"
        case .reward: event.rewardTitle ?? "Reward redeemed"
        }
    }

    private var change: String {
        switch event.kind {
        case .joined: "Joined"
        case .stamp: "+1"
        case .reward: event.stampCost.map { "-\($0)" } ?? "Used"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: event.kind == .reward ? "gift" : event.kind == .joined ? "plus.circle" : "checkmark.seal")
                .foregroundStyle(.tint).frame(width: 25)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline)
                Text(event.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.footnote.weight(.medium)).foregroundStyle(Color.primary)
            }
            Spacer()
            Text(change).font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(accent.color)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

struct WalletStatusView: View {
    var message = "Apple Wallet isn't implemented yet."
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "wallet.bifold").font(.largeTitle).foregroundStyle(.tint)
                PageTitle(text: message, size: 28)
                    .accessibilityIdentifier("wallet.status")
            }
            .padding(28)
            .frame(maxWidth: 560, maxHeight: .infinity, alignment: .topLeading)
            .frame(maxWidth: .infinity)
            .background { AppBackground() }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct CounterCardView: View {
    let place: Place
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PlaceMark(place: place, size: 44).foregroundStyle(.tint)
                    PageTitle(text: place.name, size: 30)
                    Text("Customer codes aren't implemented yet.")
                        .foregroundStyle(Color.muted)
                }
                .padding(28)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background { AppBackground() }
            .appNavigationTitle("Customer card")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
