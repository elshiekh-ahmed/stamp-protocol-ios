import SwiftUI

struct OverviewView: View {
    @Environment(PartnerStore.self) private var store
    @Environment(\.appAccent) private var accent
    @Binding var tab: BusinessTab
    @State private var period = ReportPeriod.month

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        PageHeader("Overview", identifier: "heading.overview")
                        if let business = store.business {
                            HStack(spacing: 12) {
                                LogoView(data: business.logoPNG, name: business.name, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(business.name)
                                        .font(.headline.weight(.medium))
                                        .foregroundStyle(accent.color)
                                    if !business.location.isEmpty {
                                        Text(business.location)
                                            .font(.caption)
                                            .foregroundStyle(Color.muted)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }

                    if let program = store.currentProgram, let business = store.business {
                        VStack(alignment: .leading, spacing: 10) {
                            Button { tab = .card } label: {
                                BusinessCardTile(
                                    name: business.name, location: business.location,
                                    reward: program.rewardDescription, requiredPunches: program.requiredPunches,
                                    design: program.design,
                                    detail: "\(program.requiredPunches) stamps / Version \(program.version) live"
                                )
                            }
                            .buttonStyle(CardPressStyle(allowsMotion: program.design.theme.allowsMotion))
                            .accessibilityIdentifier("overview.program")
                            if store.cardsFinishingOlderVersions > 0 {
                                Text("\(store.cardsFinishingOlderVersions) cards still finishing older versions")
                                    .font(.footnote)
                                    .foregroundStyle(Color.muted)
                                    .accessibilityIdentifier("overview.finishing")
                            }
                        }
                    } else {
                        Notice(
                            symbol: "rectangle.portrait.on.rectangle.portrait",
                            title: "Publish your card",
                            message: "Set how many stamps earn a reward and design the card customers collect."
                        )
                        Button("Design your card") { tab = .card }
                            .buttonStyle(PrimaryButton())
                            .accessibilityIdentifier("overview.design")
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeading(title: "Activity", detail: period.title)
                        Picker("Period", selection: $period) {
                            ForEach(ReportPeriod.allCases) { option in
                                Text(option.rawValue).tag(option)
                                    .accessibilityLabel(option.title)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("overview.period")

                        let summary = store.summary(for: period)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                            MetricTile(
                                title: "Cardholders", value: summary.enrolledCardholders,
                                caption: "Lifetime", identifier: "enrolled"
                            )
                            MetricTile(title: "Stamps", value: summary.punches, caption: period.title, identifier: "punches")
                            MetricTile(
                                title: "Rewards earned", value: summary.rewardsEarned,
                                caption: period.title, identifier: "earned"
                            )
                            MetricTile(
                                title: "Rewards redeemed", value: summary.rewardsRedeemed,
                                caption: period.title, identifier: "redeemed"
                            )
                        }
                        Text("Stamps and rewards are recorded when customers collect at checkout. These figures come from sample data stored on this device.")
                            .font(.footnote)
                            .foregroundStyle(Color.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .background(Color.surface, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(24)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background { AppBackground() }
            .toolbar(.hidden, for: .navigationBar)
            .trackScreen("Overview")
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: Int
    let caption: String
    let identifier: String
    @Environment(\.appAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline).foregroundStyle(Color.muted)
            Text(value, format: .number)
                .font(.title.weight(.medium).monospacedDigit())
                .foregroundStyle(accent.color)
                .contentTransition(.numericText())
            Text(caption).font(.caption).foregroundStyle(Color.muted)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(Color.paper, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.rule))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("overview.metric.\(identifier)")
    }
}
