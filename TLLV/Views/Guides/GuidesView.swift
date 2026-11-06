import SwiftUI
import MapKit

struct GuidesView: View {
    enum Scope: String, CaseIterable, Identifiable {
        case london = "London", travel = "Travel"
        var id: String { rawValue }
    }

    /// When pushed from Discover the view lives inside that tab's stack.
    var embedded = false

    @Environment(CatalogStore.self) private var catalog
    @Environment(AccountStore.self) private var account
    @State private var scope: Scope = .london
    @State private var search = ""

    var body: some View {
        if embedded {
            content
        } else {
            NavigationStack {
                content.contentDestinations()
            }
        }
    }

    private var content: some View {
        List {
            Section {
                Picker("Guides", selection: $scope) {
                    ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            switch scope {
            case .london: londonGuides
            case .travel: travelGuides
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Guides")
        .searchable(text: $search, prompt: scope == .london ? "Search guides" : "Search destinations")
        .refreshable { await catalog.refresh() }
    }

    @ViewBuilder
    private var londonGuides: some View {
        if let intro = catalog.siteContent.londonIntro, search.isEmpty {
            Section {
                Text(intro).font(.callout).foregroundStyle(.secondary)
            }
        }
        Section {
            ForEach(catalog.collections.filter { matches($0.coverTitle + " " + $0.title) }) { collection in
                NavigationLink(value: collection) {
                    GuideCoverCard(title: collection.coverTitle,
                                   eyebrow: account.isMember ? "\(catalog.places(in: collection).count) places" : "Member guide",
                                   image: collection.image)
                        .frame(height: 180)
                        .overlay(alignment: .topTrailing) {
                            if !account.isMember { PremiumBadge().padding(10) }
                        }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                .listRowSeparator(.hidden)
            }
        }
    }

    @ViewBuilder
    private var travelGuides: some View {
        if let intro = catalog.siteContent.travelIntro, search.isEmpty {
            Section {
                Text(intro).font(.callout).foregroundStyle(.secondary)
            }
        }
        ForEach(catalog.travelGuidesByCountry, id: \.country) { group in
            let guides = group.guides.filter { matches([$0.name, group.country].joined(separator: " ")) }
            if !guides.isEmpty {
                Section(group.country) {
                    ForEach(guides) { guide in
                        NavigationLink(value: guide) {
                            HStack(spacing: 12) {
                                RemoteImage(url: guide.image, symbol: "airplane")
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(guide.destination ?? guide.name).font(.headline)
                                    if !guide.travelPlaces.isEmpty {
                                        Text("\(guide.travelPlaces.count) places")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func matches(_ text: String) -> Bool {
        search.isEmpty || text.localizedCaseInsensitiveContains(search)
    }
}

// MARK: - London collection

struct CollectionDetailView: View {
    let collection: GuideCollection
    @Environment(CatalogStore.self) private var catalog
    @Environment(AccountStore.self) private var account
    @State private var showingMap = false
    @State private var showFullIntro = false

    var body: some View {
        let places = catalog.places(in: collection)
        List {
            Section {
                RemoteImage(url: collection.image, symbol: "book.fill")
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .listRowInsets(EdgeInsets())
                VStack(alignment: .leading, spacing: 8) {
                    Text(collection.title).font(.title2.bold())
                    if let description = collection.description {
                        Text(description.markdownAttributed)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(showFullIntro ? nil : 4)
                        Button(showFullIntro ? "Show Less" : "Read More") {
                            withAnimation { showFullIntro.toggle() }
                        }
                        .font(.callout.weight(.semibold))
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 4)
            }

            if account.isEntitled(to: .editorialGuides) {
                Section("\(places.count) Places") {
                    ForEach(places) { place in
                        NavigationLink(value: place) {
                            PlaceRow(place: place, note: collection.placeNotes[String(place.id)])
                        }
                        .placeContextMenu(place)
                        .placeSwipeActions(place)
                    }
                }
            } else {
                Section {
                    PremiumLockedView(feature: .editorialGuides)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(collection.coverTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if account.isEntitled(to: .editorialGuides) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingMap = true
                    } label: {
                        Image(systemName: "map")
                    }
                    .accessibilityLabel("Show on map")
                }
            }
        }
        .sheet(isPresented: $showingMap) {
            PlacesMapSheet(title: collection.coverTitle, places: places)
        }
    }
}

/// A full-screen map of a set of places, used by guides and lists.
struct PlacesMapSheet: View {
    let title: String
    let places: [Place]
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Int?

    var body: some View {
        NavigationStack {
            Map(initialPosition: .automatic, selection: $selection) {
                UserAnnotation()
                ForEach(places.filter { $0.coordinate != nil }) { place in
                    Marker(place.name, systemImage: "fork.knife", coordinate: place.coordinate!)
                        .tint(place.isFullyVegan ? Color.accentColor : Color("Lavender"))
                        .tag(place.id)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .safeAreaInset(edge: .bottom) {
                if let id = selection, let place = places.first(where: { $0.id == id }) {
                    NavigationLink(value: place) {
                        PlaceRow(place: place)
                            .padding(12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .contentDestinations()
        }
        .appHosts()
    }
}

// MARK: - Travel guide

struct TravelGuideDetailView: View {
    let guide: Place
    @Environment(\.openURL) private var openURL

    /// The guide body is plain text: a heading line, then " · "-separated items.
    private var bodySections: [(title: String, items: [String])] {
        guard let body = guide.guideBody else { return [] }
        return body.components(separatedBy: "\n\n").compactMap { block -> (title: String, items: [String])? in
            let lines = block.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
            guard let title = lines.first else { return nil }
            let items = lines.dropFirst()
                .flatMap { $0.components(separatedBy: " · ") }
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return items.isEmpty ? nil : (title, items)
        }
    }

    var body: some View {
        List {
            Section {
                RemoteImage(url: guide.image, symbol: "airplane")
                    .frame(height: 260)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .listRowInsets(EdgeInsets())
                VStack(alignment: .leading, spacing: 4) {
                    Text(guide.destination ?? guide.name).font(.largeTitle.bold())
                    if let country = guide.country {
                        Label(country, systemImage: "globe.europe.africa").foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if !guide.travelPlaces.isEmpty {
                Section("Where to Eat") {
                    ForEach(Array(guide.travelPlaces.enumerated()), id: \.offset) { _, place in
                        Button {
                            if let url = place.url ?? MapsLink.search(place.name) { openURL(url) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name).font(.headline).foregroundStyle(.primary)
                                    Text([place.type, place.veganOffering].compactMap { $0 }.joined(separator: " · "))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    if let description = place.description {
                                        Text(description).font(.footnote).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "map").foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }

            ForEach(bodySections, id: \.title) { section in
                Section(section.title) {
                    FlowLayout(spacing: 6) {
                        ForEach(section.items, id: \.self) { TagLabel(text: $0) }
                    }
                    .padding(.vertical, 4)
                }
            }

            if let review = guide.review {
                Section {
                    Button {
                        openURL(review)
                    } label: {
                        Label("Read the full guide", systemImage: "doc.text")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(guide.destination ?? guide.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let review = guide.review {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: review)
                }
            }
        }
    }
}
