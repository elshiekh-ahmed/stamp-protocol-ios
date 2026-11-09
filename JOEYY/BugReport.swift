import Observation
import SwiftUI
import UIKit

/// Remembers the most recently shown screen so bug reports can include it.
@MainActor
@Observable
final class ScreenTracker {
    var current = "Launch"
}

private struct TrackScreen: ViewModifier {
    @Environment(ScreenTracker.self) private var tracker
    let name: String

    func body(content: Content) -> some View {
        content.onAppear { tracker.current = name }
    }
}

extension View {
    func trackScreen(_ name: String) -> some View {
        modifier(TrackScreen(name: name))
    }
}

enum BugReport {
    /// Issues are filed in this repository. The reporter submits them from Safari while signed in to GitHub.
    static let repository = "jarenadams21/stamp-protocol-ios"
    static let fieldLimit = 1_500

    struct Diagnostics: Equatable {
        var appVersion: String
        var build: String
        var device: String
        var system: String
        var screen: String
        var appearance: String
        var reportedAt: Date

        @MainActor
        static func current(screen: String, appearance: String) -> Diagnostics {
            let info = Bundle.main.infoDictionary
            return Diagnostics(
                appVersion: info?["CFBundleShortVersionString"] as? String ?? "unknown",
                build: info?["CFBundleVersion"] as? String ?? "unknown",
                device: modelIdentifier(),
                system: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
                screen: screen,
                appearance: appearance,
                reportedAt: .now
            )
        }

        private static func modelIdentifier() -> String {
            if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
                return "\(simulated) (Simulator)"
            }
            var systemInfo = utsname()
            uname(&systemInfo)
            return withUnsafeBytes(of: systemInfo.machine) { raw in
                String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
            }
        }
    }

    static func body(whatHappened: String, expected: String, steps: String, diagnostics: Diagnostics) -> String {
        func section(_ title: String, _ text: String) -> String {
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return "## \(title)\n\(value.isEmpty ? "_Not provided_" : String(value.prefix(fieldLimit)))\n"
        }
        let timestamp = diagnostics.reportedAt.formatted(.iso8601)
        return [
            section("What happened", whatHappened),
            section("What did you expect?", expected),
            section("Steps to reproduce", steps),
            """
            ## Environment
            | | |
            |---|---|
            | App | JOEYY \(diagnostics.appVersion) (\(diagnostics.build)), business side |
            | Device | \(diagnostics.device) |
            | OS | \(diagnostics.system) |
            | Screen | \(diagnostics.screen) |
            | Appearance | \(diagnostics.appearance) |
            | Reported | \(timestamp) |

            _Reported from the in-app bug button. Attach a screenshot below if it helps._
            """
        ].joined(separator: "\n")
    }

    static func issueURL(title: String, body: String) -> URL? {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        func encode(_ value: String) -> String {
            value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        }
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = "title=\(encode(title))&body=\(encode(body))&labels=bug"
        return URL(string: "https://github.com/\(repository)/issues/new?\(query)")
    }
}

/// Ladybug button shown in every business page header.
struct BugReportButton: View {
    @Environment(ScreenTracker.self) private var tracker
    @State private var reportingScreen: String?

    var body: some View {
        Button {
            reportingScreen = tracker.current
        } label: {
            Image(systemName: "ladybug").frame(width: 44, height: 44)
        }
        .accessibilityLabel("Report a bug")
        .accessibilityIdentifier("bug.report")
        .sheet(item: Binding(
            get: { reportingScreen.map(ReportedScreen.init) },
            set: { reportingScreen = $0?.id }
        )) { item in
            BugReportView(screen: item.id)
        }
    }
}

private struct ReportedScreen: Identifiable {
    let id: String
}

struct BugReportView: View {
    let screen: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("accent") private var accent = AppAccent.orange.rawValue
    @State private var title = ""
    @State private var whatHappened = ""
    @State private var expected = ""
    @State private var steps = ""
    @State private var openFailed = false

    private var diagnostics: BugReport.Diagnostics {
        .current(screen: screen, appearance: "\(appearance) / \(accent)")
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Short summary", text: $title)
                        .accessibilityIdentifier("bug.title")
                } header: {
                    Text("Title").foregroundStyle(.tint)
                }
                Section {
                    TextField("What happened?", text: $whatHappened, axis: .vertical)
                        .lineLimit(3...8)
                    TextField("What did you expect?", text: $expected, axis: .vertical)
                        .lineLimit(2...6)
                    TextField("Steps to reproduce", text: $steps, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("Details").foregroundStyle(.tint)
                }
                Section {
                    let info = diagnostics
                    LabeledContent("Screen", value: info.screen)
                    LabeledContent("App", value: "\(info.appVersion) (\(info.build))")
                    LabeledContent("Device", value: info.device)
                    LabeledContent("OS", value: info.system)
                } header: {
                    Text("Included automatically").foregroundStyle(.tint)
                } footer: {
                    Text("Opens a pre-filled issue in \(BugReport.repository) on GitHub. Review it, attach a screenshot if helpful, and submit while signed in.")
                }
            }
            .appNavigationTitle("Report a bug")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") { submit() }
                        .disabled(!canSubmit)
                        .accessibilityIdentifier("bug.continue")
                }
            }
            .alert("Couldn't open GitHub", isPresented: $openFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Check that Safari is available, then try again.")
            }
        }
    }

    private func submit() {
        let body = BugReport.body(whatHappened: whatHappened, expected: expected, steps: steps, diagnostics: diagnostics)
        guard let url = BugReport.issueURL(title: title, body: body) else {
            openFailed = true
            return
        }
        openURL(url) { accepted in
            if accepted {
                dismiss()
            } else {
                openFailed = true
            }
        }
    }
}
