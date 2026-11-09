import SwiftUI

struct HomeView: View {
    @Environment(LoyaltyStore.self) private var store
    @Environment(MerchantBrandingStore.self) private var branding
    @Binding var tab: AppTab
    @State private var showingArchive = false
    @State private var showingGroups = false
    @State private var filter = CollectionFilter.all
    @State private var failure: String?

    private var places: [Place] {
        switch filter {
        case .all: store.activePlaces
        case .favorites: store.activePlaces.filter { store.membership(for: $0)?.isFavorite == true }
        case .group(let id):
            store.groups.first(where: { $0.id == id }).map { store.places(in: $0) } ?? []
        }
    }

    private var collectionName: String {
        switch filter {
        case .all: "All places"
        case .favorites: "Favorites"
        case .group(let id): store.groups.first(where: { $0.id == id })?.name ?? "All places"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        PageTitle(text: "Home").accessibilityIdentifier("heading.home")
                        Spacer()
                        Button {
                            showingArchive = true
                        } label: {
                            Image(systemName: "archivebox").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Archived cards")
                    }
                    ViewThatFits(in: .horizontal) {
                        collectionControls
                        VStack(alignment: .leading, spacing: 8) { collectionPicker; groupsButton }
                    }
                    if store.activePlaces.isEmpty {
                        ContentUnavailableView {
                            Label("No cards", systemImage: "rectangle.stack")
                        } actions: {
                            Button("Search for a business") { tab = .search }
                        }
                    } else if places.isEmpty {
                        ContentUnavailableView {
                            Text(filter == .favorites ? "No favorites" : "No places in this group")
                        }
                    } else {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            ForEach(places) { place in
                                ZStack(alignment: .topTrailing) {
                                    NavigationLink(value: place) {
                                        PlaceGalleryTile(place: place, stamps: store.membership(for: place)?.stamps ?? 0)
                                    }
                                    .buttonStyle(CardPressStyle(allowsMotion: branding.theme(for: place).allowsMotion))
                                    .accessibilityIdentifier("card.\(place.id)")
                                    Button {
                                        do {
                                            try store.setFavorite(
                                                store.membership(for: place)?.isFavorite != true, for: place
                                            )
                                        } catch { failure = error.localizedDescription }
                                    } label: {
                                        Image(systemName: store.membership(for: place)?.isFavorite == true ? "star.fill" : "star")
                                            .font(.body.weight(.medium))
                                            .frame(width: 44, height: 44)
                                            .foregroundStyle(Color.primary)
                                            .background(Color.surface, in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Favorite \(place.name)")
                                    .accessibilityAddTraits(store.membership(for: place)?.isFavorite == true ? .isSelected : [])
                                    .accessibilityIdentifier("favorite.\(place.id)")
                                    .padding(8)
                                }
                            }
                        }
                        Button("Add a business") {
                            tab = .search
                        }
                        .font(.subheadline)
                        .frame(minHeight: 44)
                        .buttonStyle(TextButton())
                    }
                }
                .padding(24)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background { AppBackground() }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Place.self) { PlaceDetailView(place: $0) }
            .sheet(isPresented: $showingArchive) { ArchiveView() }
            .sheet(isPresented: $showingGroups) { GroupsView() }
            .onChange(of: store.groups) {
                if case .group(let id) = filter, !store.groups.contains(where: { $0.id == id }) { filter = .all }
            }
            .alert("Couldn't update favorite", isPresented: Binding(
                get: { failure != nil }, set: { if !$0 { failure = nil } }
            )) {
                Button("OK") { failure = nil }
            } message: { Text(failure ?? "") }
        }
    }

    private var collectionControls: some View {
        HStack { collectionPicker; Spacer(); groupsButton }
    }

    private var collectionPicker: some View {
        Menu {
            Picker("Collection", selection: $filter) {
                Text("All places").tag(CollectionFilter.all)
                Text("Favorites").tag(CollectionFilter.favorites)
                ForEach(store.groups) { group in
                    Text(group.name).tag(CollectionFilter.group(group.id))
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(collectionName).fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.down").font(.caption)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("home.collection")
    }

    private var groupsButton: some View {
        Button("Groups") { showingGroups = true }
            .frame(minHeight: 44)
            .accessibilityIdentifier("home.groups")
    }
}

private enum CollectionFilter: Hashable {
    case all, favorites, group(UUID)
}

struct GroupsView: View {
    @Environment(LoyaltyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editing: PlaceGroup?
    @State private var creating = false
    @State private var deleting: PlaceGroup?
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            List {
                if store.groups.isEmpty {
                    Text("No groups").foregroundStyle(Color.muted)
                }
                ForEach(store.groups) { group in
                    HStack(spacing: 8) {
                        Button { editing = group } label: {
                            HStack {
                                Text(group.name)
                                Spacer()
                                Text("\(store.places(in: group).count) places").foregroundStyle(Color.muted)
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("group.edit.\(group.name)")
                        Menu {
                            Button("Rename", systemImage: "pencil") { editing = group }
                            Button("Delete group", systemImage: "trash", role: .destructive) {
                                deleting = group
                            }
                        } label: {
                            Image(systemName: "ellipsis").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Options for \(group.name)")
                        .accessibilityIdentifier("group.options.\(group.name)")
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) { deleting = group }
                    }
                }
                Button("New group") { creating = true }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("group.create")
            }
            .appNavigationTitle("Groups")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $editing) { GroupEditorView(group: $0) }
            .sheet(isPresented: $creating) { GroupEditorView(group: nil) }
            .alert("Delete this group?", isPresented: Binding(
                get: { deleting != nil }, set: { if !$0 { deleting = nil } }
            )) {
                Button("Delete group", role: .destructive) {
                    guard let deleting else { return }
                    do { try store.deleteGroup(deleting) }
                    catch { failure = error.localizedDescription }
                    self.deleting = nil
                }
                .accessibilityIdentifier("group.confirmDelete")
                Button("Cancel", role: .cancel) { deleting = nil }
                    .accessibilityIdentifier("group.cancelDelete")
            } message: { Text("Cards, punches, favorites, and coupons stay.") }
            .alert("Couldn't update group", isPresented: Binding(
                get: { failure != nil }, set: { if !$0 { failure = nil } }
            )) {
                Button("OK") { failure = nil }
            } message: { Text(failure ?? "") }
        }
    }
}

struct GroupMembershipView: View {
    let place: Place
    @Environment(LoyaltyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var creating = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(place.name) {
                    ForEach(store.groups) { group in
                        Toggle(group.name, isOn: Binding(
                            get: { group.placeIDs.contains(place.id) },
                            set: { included in
                                let ids = group.placeIDs.filter { $0 != place.id } + (included ? [place.id] : [])
                                do { try store.saveGroup(id: group.id, name: group.name, placeIDs: ids) }
                                catch { failure = error.localizedDescription }
                            }
                        ))
                    }
                    Button("New group") { creating = true }
                }
            }
            .appNavigationTitle("Groups")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $creating) { GroupEditorView(group: nil, initialPlaceID: place.id) }
            .alert("Couldn't update group", isPresented: Binding(
                get: { failure != nil }, set: { if !$0 { failure = nil } }
            )) {
                Button("OK") { failure = nil }
            } message: { Text(failure ?? "") }
        }
    }
}

struct GroupEditorView: View {
    let group: PlaceGroup?
    @Environment(LoyaltyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selected: Set<String>
    @State private var confirmingDeletion = false
    @State private var failure: String?

    init(group: PlaceGroup?, initialPlaceID: String? = nil) {
        self.group = group
        _name = State(initialValue: group?.name ?? "")
        _selected = State(initialValue: Set(group?.placeIDs ?? initialPlaceID.map { [$0] } ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Group name", text: $name)
                        .accessibilityIdentifier("group.name")
                }
                Section("Places") {
                    ForEach(Place.catalog.filter { store.membership(for: $0) != nil }) { place in
                        Toggle(isOn: Binding(
                            get: { selected.contains(place.id) },
                            set: { if $0 { selected.insert(place.id) } else { selected.remove(place.id) } }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(place.name)
                                if store.membership(for: place)?.archived == true {
                                    Text("Archived").font(.caption).foregroundStyle(Color.muted)
                                }
                            }
                        }
                        .accessibilityIdentifier("group.place.\(place.id)")
                    }
                }
                if group != nil {
                    Section {
                        Button("Delete group", role: .destructive) { confirmingDeletion = true }
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("group.delete")
                    }
                }
            }
            .appNavigationTitle(group == nil ? "New group" : "Edit group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try store.saveGroup(id: group?.id, name: name, placeIDs: selected.sorted())
                            dismiss()
                        } catch { failure = error.localizedDescription }
                    }
                    .accessibilityIdentifier("group.save")
                }
            }
            .alert("Delete this group?", isPresented: $confirmingDeletion) {
                if let group {
                    Button("Delete group", role: .destructive) {
                        do {
                            try store.deleteGroup(group)
                            dismiss()
                        } catch { failure = error.localizedDescription }
                    }
                    .accessibilityIdentifier("group.confirmDelete")
                }
                Button("Cancel", role: .cancel) {}
                    .accessibilityIdentifier("group.cancelDelete")
            } message: { Text("Cards, punches, favorites, and coupons stay.") }
            .alert("Couldn't update group", isPresented: Binding(
                get: { failure != nil }, set: { if !$0 { failure = nil } }
            )) {
                Button("OK") { failure = nil }
            } message: { Text(failure ?? "") }
        }
    }
}

struct ArchiveView: View {
    @Environment(LoyaltyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var archived: [Place] {
        Place.catalog.filter { store.membership(for: $0)?.archived == true }
    }

    var body: some View {
        NavigationStack {
            List {
                if archived.isEmpty {
                    ContentUnavailableView(
                        "No archived cards", systemImage: "archivebox"
                    )
                    .listRowBackground(Color.clear)
                }
                ForEach(archived) { place in
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(place.name).font(.headline.weight(.medium)).foregroundStyle(.tint)
                            Text("\(store.membership(for: place)?.stamps ?? 0) stamps")
                                .font(.caption).foregroundStyle(Color.muted)
                        }
                        Spacer()
                        Button("Restore") { store.join(place) }.buttonStyle(.bordered)
                    }
                    .listRowBackground(Color.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .appNavigationTitle("Archived cards")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct SearchView: View {
    @Environment(LoyaltyStore.self) private var store
    @Environment(MerchantBrandingStore.self) private var branding
    @State private var query = ""
    @State private var focusedPlace: String? = Place.discoverable.first?.id

    private var matches: [Place] { Place.search(query) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PageTitle(text: "Search")
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.muted)
                        TextField("Business name or client ID", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .accessibilityIdentifier("search.query")
                        if !query.isEmpty {
                            Button {
                                query = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.muted)
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 8)
                    .frame(minHeight: 56)
                    .background(Color.surface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.rule))

                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeading(title: "Discoverable")
                            ScrollView(.horizontal) {
                                HStack(alignment: .top, spacing: 16) {
                                    ForEach(Place.discoverable) { place in
                                        NavigationLink(value: place) {
                                            DiscoveryTile(
                                                place: place,
                                                isAdded: store.membership(for: place)?.archived == false
                                            )
                                        }
                                        .buttonStyle(CardPressStyle(allowsMotion: branding.theme(for: place).allowsMotion))
                                        .containerRelativeFrame(.horizontal) { width, _ in width * 0.88 }
                                        .accessibilityIdentifier("discover.\(place.id)")
                                    }
                                }
                                .scrollTargetLayout()
                                .padding(.vertical, 14)
                            }
                            .scrollIndicators(.hidden)
                            .scrollClipDisabled()
                            .scrollTargetBehavior(.viewAligned)
                            .scrollPosition(id: $focusedPlace)
                            .sensoryFeedback(.selection, trigger: focusedPlace)
                            .accessibilityIdentifier("search.discovery")
                            Text("Demo offers. Not affiliated with these businesses.")
                                .font(.footnote)
                                .foregroundStyle(Color.muted)
                        }
                    } else {
                        if matches.isEmpty {
                            ContentUnavailableView(
                                "No matching business", systemImage: "magnifyingglass"
                            )
                        } else {
                            VStack(spacing: 0) {
                                ForEach(matches) { place in
                                    NavigationLink(value: place) {
                                        ClientRow(place: place)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("search.\(place.id)")
                                    if place.id != matches.last?.id {
                                        Divider().padding(.horizontal, 18)
                                    }
                                }
                            }
                            .background(Color.surface, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { AppBackground() }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Place.self) { PlaceDetailView(place: $0) }
        }
    }
}
