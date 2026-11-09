import MapKit
import Observation
import SwiftUI

struct LocationSuggestion: Identifiable, Hashable, Sendable {
    let title: String
    let subtitle: String

    var id: String { "\(title)|\(subtitle)" }

    /// One line suitable for storing and displaying, such as "Seattle, WA, United States".
    var formatted: String {
        subtitle.isEmpty ? title : "\(title), \(subtitle)"
    }
}

/// Autocompletes cities, street addresses, and map listings using Apple Maps.
@MainActor
@Observable
final class LocationSearch {
    static let maxSuggestions = 6

    private(set) var suggestions: [LocationSuggestion] = []
    private(set) var isSearching = false
    private(set) var failed = false
    @ObservationIgnored private let completer = MKLocalSearchCompleter()
    @ObservationIgnored private var delegate: CompleterDelegate?

    init() {
        completer.resultTypes = [.address, .pointOfInterest]
        let delegate = CompleterDelegate { [weak self] results in
            self?.receive(results)
        }
        completer.delegate = delegate
        self.delegate = delegate
    }

    func search(_ text: String) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        failed = false
        guard !query.isEmpty else {
            completer.cancel()
            suggestions = []
            isSearching = false
            return
        }
        isSearching = true
        completer.queryFragment = query
    }

    private func receive(_ results: [LocationSuggestion]?) {
        isSearching = false
        failed = results == nil
        suggestions = results ?? []
    }
}

/// Bridges MapKit's delegate callbacks, which arrive on the main thread, to `LocationSearch`.
@MainActor
private final class CompleterDelegate: NSObject, @preconcurrency MKLocalSearchCompleterDelegate {
    private let onUpdate: @MainActor ([LocationSuggestion]?) -> Void

    init(onUpdate: @escaping @MainActor ([LocationSuggestion]?) -> Void) {
        self.onUpdate = onUpdate
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onUpdate(completer.results.prefix(LocationSearch.maxSuggestions).map {
            LocationSuggestion(title: $0.title, subtitle: $0.subtitle)
        })
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        onUpdate(nil)
    }
}

/// Form rows for choosing a location from suggestions rather than typing free text.
struct LocationField: View {
    @Binding var location: String
    @State private var search = LocationSearch()
    @State private var query = ""
    @State private var editing = false
    @FocusState private var focused: Bool

    var body: some View {
        if editing || location.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.muted)
                TextField("Search city, address, or your listing", text: $query)
                    .textContentType(.fullStreetAddress)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .submitLabel(.search)
                    .accessibilityIdentifier("business.location.search")
                if editing {
                    Button("Cancel") { stopEditing() }
                        .buttonStyle(.borderless)
                }
            }
            .onChange(of: query) { search.search(query) }

            ForEach(search.suggestions) { suggestion in
                Button {
                    location = suggestion.formatted
                    stopEditing()
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(suggestion.title).foregroundStyle(.primary)
                        if !suggestion.subtitle.isEmpty {
                            Text(suggestion.subtitle).font(.caption).foregroundStyle(Color.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("business.location.suggestion")
            }

            if let status {
                Text(status).font(.footnote).foregroundStyle(Color.muted)
            }
        } else {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse").foregroundStyle(.tint)
                Text(location)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("business.location.value")
                Button("Change") {
                    editing = true
                    focused = true
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("business.location.change")
            }
            Button("Remove location") { location = "" }
                .buttonStyle(.borderless)
        }
    }

    private var status: String? {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              search.suggestions.isEmpty else { return nil }
        if search.isSearching { return "Searching…" }
        if search.failed { return "Couldn't load suggestions. Check your connection and try again." }
        return "No matching places. Try a street address or city."
    }

    private func stopEditing() {
        editing = false
        focused = false
        query = ""
    }
}
