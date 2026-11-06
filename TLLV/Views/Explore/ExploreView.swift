import SwiftUI
import MapKit

struct ExploreView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case map = "Map", list = "List"
        var id: String { rawValue }
        var symbol: String { self == .map ? "map" : "list.bullet" }
    }

    @Environment(CatalogStore.self) private var catalog
    @Environment(LocationManager.self) private var location
    @Environment(AppRouter.self) private var router
    @Environment(AccountStore.self) private var account
    @Environment(\.showPaywall) private var showPaywall

    @State private var mode: Mode = .map
    @State private var showingFilters = false
    @State private var selectedID: Int?
    @State private var position: MapCameraPosition = .region(.london)

    private var results: [Place] {
        let filter = account.isMember ? router.explore : router.explore.freeVersion
        let now = Date.now
        let matches = catalog.restaurants.filter { filter.matches($0, now: now) }
        switch filter.sort {
        case .newest:
            return matches
        case .name:
            return matches.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nearest:
            guard location.location != nil else { return matches }
            return matches.sorted { (location.distance(to: $0) ?? .greatestFiniteMagnitude) < (location.distance(to: $1) ?? .greatestFiniteMagnitude) }
        }
    }

    var body: some View {
        @Bindable var router = router
        NavigationStack {
            let places = results
            Group {
                switch mode {
                case .map:
                    if account.isEntitled(to: .interactiveMap) {
                        mapView(places)
                    } else {
                        LockedMapView { mode = .list }
                    }
                case .list: listView(places)
                }
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $router.explore.query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: account.isMember ? "Restaurants, dishes, areas or stations" : "Restaurants, areas or stations")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("View", selection: $mode) {
                        ForEach(Mode.allCases) { mode in
                            Label(mode.rawValue, systemImage: mode.symbol).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if account.isEntitled(to: .advancedFilters) { showingFilters = true } else { showPaywall(.advancedFilters) }
                    } label: {
                        Image(systemName: account.isMember && router.explore.activeCount > 0
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel(router.explore.activeCount > 0 ? "Filters, \(router.explore.activeCount) active" : "Filters")
                }
            }
            .sheet(isPresented: $showingFilters) {
                FilterSheet(filter: $router.explore, resultCount: places.count)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .contentDestinations()
        }
    }

    // MARK: Map

    private func mapView(_ places: [Place]) -> some View {
        let mapped = places.filter { $0.coordinate != nil }
        return Map(position: $position, selection: $selectedID) {
            UserAnnotation()
            ForEach(mapped) { place in
                Marker(place.name, systemImage: place.isFullyVegan ? "leaf.fill" : "fork.knife", coordinate: place.coordinate!)
                    .tint(place.isFullyVegan ? Color.accentColor : Color("Lavender"))
                    .tag(place.id)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onAppear { location.requestLocation() }
        .safeAreaInset(edge: .top) {
            ActiveFilterBar(filter: routerFilter, count: places.count)
        }
        .safeAreaInset(edge: .bottom) {
            if let id = selectedID, let place = catalog.place(id: id) {
                MapPreviewCard(place: place) { selectedID = nil }
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                MapLegend().padding(.bottom, 8)
            }
        }
        .animation(.snappy, value: selectedID)
    }

    private var routerFilter: Binding<PlaceFilter> {
        Binding(get: { router.explore }, set: { router.explore = $0 })
    }

    // MARK: List

    private func listView(_ places: [Place]) -> some View {
        List {
            Section {
                ForEach(places) { place in
                    NavigationLink(value: place) {
                        PlaceRow(place: place, distance: router.explore.sort == .nearest ? location.distance(to: place)?.formattedDistance : nil)
                    }
                    .placeContextMenu(place)
                    .placeSwipeActions(place)
                }
            } header: {
                HStack {
                    Text("\(places.count) places")
                    Spacer()
                    Menu {
                        Picker("Sort by", selection: routerFilter.sort) {
                            ForEach(PlaceSort.allCases) { sort in
                                Label(sort.rawValue, systemImage: sort.symbol).tag(sort)
                            }
                        }
                    } label: {
                        Label((account.isMember ? router.explore.sort : router.explore.freeVersion.sort).rawValue, systemImage: "arrow.up.arrow.down")
                            .font(.subheadline)
                    }
                    .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if places.isEmpty && !catalog.restaurants.isEmpty {
                ContentUnavailableView {
                    Label("No Matches", systemImage: "magnifyingglass")
                } description: {
                    Text("Try a different search or fewer filters.")
                } actions: {
                    Button("Clear Filters") { router.explore.clearFilters(); router.explore.query = "" }
                }
            }
        }
        .onChange(of: router.explore.sort) { _, sort in
            guard sort == .nearest else { return }
            if account.isEntitled(to: .nearMeNow) {
                location.requestLocation()
            } else {
                router.explore.sort = .newest
                showPaywall(.nearMeNow)
            }
        }
        .refreshable { await catalog.refresh() }
    }
}

extension MKCoordinateRegion {
    static let london = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5098, longitude: -0.1180),
        span: MKCoordinateSpan(latitudeDelta: 0.22, longitudeDelta: 0.22)
    )
}

// MARK: - Map pieces

/// The website's "Unlock the map" panel, over a preview of the map.
private struct LockedMapView: View {
    let browseReviews: () -> Void

    var body: some View {
        ZStack {
            RemoteImage(url: Site.resolveURL("/assets/premium-map-preview.jpg"), symbol: "map")
                .blur(radius: 3)
                .overlay(Color.black.opacity(0.1))
                .ignoresSafeArea(edges: .bottom)
                .accessibilityHidden(true)
            ScrollView {
                PremiumLockedView(feature: .interactiveMap,
                                  secondaryTitle: "Browse Free Restaurant Reviews",
                                  secondaryAction: browseReviews)
                    .padding()
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

private struct MapPreviewCard: View {
    let place: Place
    let onClose: () -> Void

    var body: some View {
        NavigationLink(value: place) {
            HStack(spacing: 12) {
                RemoteImage(url: place.image)
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name).font(.headline).foregroundStyle(.primary)
                    Text(place.subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    HStack(spacing: 6) {
                        VeganBadge(place: place)
                        if let price = place.price { Text(price).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(8)
                .accessibilityLabel("Close")
            }
        }
        .buttonStyle(.plain)
    }
}

private struct MapLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            Label("Fully vegan", systemImage: "circle.fill").foregroundStyle(Color.accentColor)
            Label("Vegan-friendly", systemImage: "circle.fill").foregroundStyle(Color("Lavender"))
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
    }
}

/// Horizontally scrolling quick filters, like Apple Maps' chips.
struct ActiveFilterBar: View {
    @Binding var filter: PlaceFilter
    let count: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(VeganFilter.allCases.filter { $0 != .any }) { option in
                    chip(option.rawValue, symbol: "leaf", isOn: filter.vegan == option) {
                        filter.vegan = filter.vegan == option ? .any : option
                    }
                }
                ForEach(PlaceFilter.featureFilters) { item in
                    chip(item.title, symbol: item.symbol, isOn: filter[keyPath: item.keyPath]) {
                        filter[keyPath: item.keyPath].toggle()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func chip(_ title: String, symbol: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .background(isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.regularMaterial), in: Capsule())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isOn)
    }
}
