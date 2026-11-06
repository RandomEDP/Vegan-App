import SwiftUI
import MapKit

struct PlaceDetailView: View {
    let place: Place

    @Environment(CatalogStore.self) private var catalog
    @Environment(SavedStore.self) private var saved
    @Environment(AccountStore.self) private var account
    @Environment(\.showPaywall) private var showPaywall
    @Environment(\.openURL) private var openURL
    @State private var showingLists = false

    private var perks: [Perk] { catalog.perks(for: place) }

    var body: some View {
        List {
            Section {
                gallery
                    .listRowInsets(EdgeInsets())
                header
                actionButtons
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 12, trailing: 12))
            }
            .listRowSeparator(.hidden)

            if let quote = place.quote {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Clare says", systemImage: "quote.opening")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                        Text(quote.markdownAttributed)
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                    if let fave = place.fave {
                        if account.isEntitled(to: .claresOrders) {
                            LabeledContent {
                                Text(fave).multilineTextAlignment(.trailing)
                            } label: {
                                Label("Clare’s fave dish", systemImage: "heart.text.square")
                            }
                        } else {
                            Button {
                                showPaywall(.claresOrders)
                            } label: {
                                LabeledContent {
                                    PremiumBadge()
                                } label: {
                                    Label("Clare’s fave dish", systemImage: "heart.text.square")
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }
            }

            if !perks.isEmpty {
                Section("Premium Perk") {
                    ForEach(perks) { perk in
                        NavigationLink(value: perk) {
                            Label {
                                VStack(alignment: .leading) {
                                    Text(perk.title).font(.headline)
                                    if let description = perk.description {
                                        Text(description).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                            } icon: {
                                Image(systemName: "tag.fill").foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }

            locationSection

            if !place.hours.isEmpty {
                HoursSection(place: place)
            }

            detailsSection

            linksSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let url = place.review ?? place.instagram ?? place.website {
                    ShareLink(item: url, subject: Text(place.name), message: Text("\(place.name) on The Little London Vegan"))
                }
                Menu {
                    Button {
                        if account.isEntitled(to: .customLists) { showingLists = true } else { showPaywall(.customLists) }
                    } label: {
                        Label("Add to List…", systemImage: "text.badge.plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
                FavouriteButton(place: place)
            }
        }
        .sheet(isPresented: $showingLists) {
            AddToListSheet(place: place)
        }
    }

    // MARK: Header

    private var gallery: some View {
        let photos = place.allPhotos
        return Group {
            if photos.count > 1 {
                TabView {
                    ForEach(photos, id: \.self) { url in
                        RemoteImage(url: url)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
            } else {
                RemoteImage(url: photos.first)
            }
        }
        .frame(height: 320)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(place.name)
                .font(.largeTitle.bold())
            Text([place.cuisine.joined(separator: ", "), place.area].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.headline)
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 6) {
                VeganBadge(place: place)
                if let price = place.price, !price.isEmpty { TagLabel(text: price) }
                if place.recommended { TagLabel(text: "Clare recommends", symbol: "star.fill") }
                if let open = place.isOpen() {
                    TagLabel(text: open ? "Open now" : "Closed now", symbol: "clock")
                }
            }
            if let date = place.publishedAt {
                Text("Reviewed \(date.tllvShort)")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.top, 8)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            if let maps = MapsLink.appleMaps(for: place) {
                ActionButton(title: "Directions", symbol: "arrow.triangle.turn.up.right.diamond.fill", prominent: true) { openURL(maps) }
            }
            if let phone = place.phone, let url = URL(string: "tel:" + phone.filter { $0.isNumber || $0 == "+" }) {
                ActionButton(title: "Call", symbol: "phone.fill") { openURL(url) }
            }
            if let booking = place.booking {
                ActionButton(title: "Book", symbol: "calendar") { openURL(booking) }
            }
            if let website = place.website {
                ActionButton(title: "Website", symbol: "safari.fill") { openURL(website) }
            }
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var locationSection: some View {
        Section("Location") {
            if let coordinate = place.coordinate {
                Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 700, longitudinalMeters: 700)),
                    interactionModes: []) {
                    Marker(place.name, systemImage: "fork.knife", coordinate: coordinate)
                        .tint(Color.accentColor)
                }
                .frame(height: 160)
                .listRowInsets(EdgeInsets())
                .onTapGesture {
                    if let url = MapsLink.appleMaps(for: place) { openURL(url) }
                }
                .accessibilityLabel("Map of \(place.name). Double-tap for directions.")
            }
            if let address = place.address {
                LabeledContent("Address") {
                    Text(address)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                }
            }
            if let station = place.nearestStation {
                LabeledContent {
                    Text([station, place.walkingDistance.map { "\($0) walk" }].compactMap { $0 }.joined(separator: " · "))
                } label: {
                    Label("Nearest station", systemImage: "tram.fill")
                }
            }
            if let region = place.region {
                LabeledContent("Region", value: region)
            }
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        let rows: [(String, String, [String])] = [
            ("Good for", "person.2", place.occasion),
            ("Meals", "fork.knife", place.meals),
            ("Venue", "building.2", place.venue),
            ("Dishes", "takeoutbag.and.cup.and.straw", place.dishes),
            ("Features", "checkmark.seal", place.features)
        ]
        let accessibility = accessibilityFacts
        if rows.contains(where: { !$0.2.isEmpty }) || !accessibility.isEmpty {
            Section("Details") {
                ForEach(rows.filter { !$0.2.isEmpty }, id: \.0) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(row.0, systemImage: row.1)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        FlowLayout(spacing: 6) {
                            ForEach(row.2, id: \.self) { TagLabel(text: $0) }
                        }
                    }
                    .padding(.vertical, 4)
                }
                ForEach(accessibility, id: \.title) { fact in
                    LabeledContent {
                        Text(fact.value)
                    } label: {
                        Label(fact.title, systemImage: fact.symbol)
                    }
                }
            }
        }
    }

    private struct Fact { let title: String; let symbol: String; let value: String }

    private var accessibilityFacts: [Fact] {
        var facts: [Fact] = []
        if let gf = place.glutenFreeFriendly {
            facts.append(Fact(title: "Gluten-free friendly", symbol: "leaf", value: gf ? "Yes" : "No"))
        }
        if let wheelchair = place.wheelchairFriendly {
            facts.append(Fact(title: "Wheelchair accessible", symbol: "figure.roll", value: wheelchair ? "Yes" : "No"))
        }
        if let dogs = place.dogPolicy {
            facts.append(Fact(title: "Dogs", symbol: "pawprint", value: dogs))
        }
        return facts
    }

    @ViewBuilder
    private var linksSection: some View {
        let links: [(String, String, URL?)] = [
            ("Read Clare’s review", "doc.text", place.review),
            ("Watch on Instagram", "play.rectangle", place.instagram),
            ("Watch on Last Orders", "mic", place.lastOrders == place.instagram ? nil : place.lastOrders),
            ("View on Google Maps", "map", place.googleMaps)
        ]
        let available = links.compactMap { link in link.2.map { (link.0, link.1, $0) } }
        if !available.isEmpty {
            Section("More from TLLV") {
                ForEach(available, id: \.0) { link in
                    Button {
                        openURL(link.2)
                    } label: {
                        HStack {
                            Label(link.0, systemImage: link.1)
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Hours

private struct HoursSection: View {
    let place: Place

    var body: some View {
        let today = Site.londonCalendar.component(.weekday, from: .now) - 1
        let symbols = Site.londonCalendar.weekdaySymbols
        // Start the week on Monday, as UK venues do.
        let order = [1, 2, 3, 4, 5, 6, 0]
        Section {
            ForEach(order, id: \.self) { day in
                let slots = place.hours(on: day)
                LabeledContent {
                    Text(slots.isEmpty ? "Closed" : slots.map { "\($0.open)–\($0.close)" }.joined(separator: ", "))
                        .monospacedDigit()
                        .foregroundStyle(slots.isEmpty ? .secondary : .primary)
                } label: {
                    Text(symbols[day])
                        .fontWeight(day == today ? .semibold : .regular)
                }
            }
        } header: {
            HStack {
                Text("Opening Hours")
                Spacer()
                if let open = place.isOpen() {
                    Text(open ? "Open now" : "Closed now")
                        .foregroundStyle(open ? Color.green : Color.secondary)
                        .textCase(nil)
                }
            }
        } footer: {
            Text("Hours can change, so check with the restaurant before you travel.")
        }
    }
}

// MARK: - Action button (Apple Maps style)

private struct ActionButton: View {
    let title: String
    let symbol: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.title3)
                Text(title).font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(prominent ? Color.white : Color.accentColor)
            .background(prominent ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.accentColor.opacity(0.12)),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow layout for tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Context menu & swipe actions used by every place list

struct PlaceContextMenu: ViewModifier {
    let place: Place
    @Environment(SavedStore.self) private var saved
    @Environment(AccountStore.self) private var account
    @Environment(\.showPaywall) private var showPaywall
    @Environment(\.openURL) private var openURL
    @State private var showingLists = false

    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button {
                    if account.isEntitled(to: .favourites) { saved.toggleFavourite(place) } else { showPaywall(.favourites) }
                } label: {
                    account.isMember && saved.isFavourite(place)
                        ? Label("Remove from Favourites", systemImage: "heart.slash")
                        : Label("Add to Favourites", systemImage: "heart")
                }
                Button {
                    if account.isEntitled(to: .customLists) { showingLists = true } else { showPaywall(.customLists) }
                } label: {
                    Label("Add to List…", systemImage: "text.badge.plus")
                }
                if let maps = MapsLink.appleMaps(for: place) {
                    Button {
                        openURL(maps)
                    } label: {
                        Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                    }
                }
                if let url = place.review ?? place.instagram ?? place.website {
                    ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
                }
            } preview: {
                PlacePreview(place: place)
            }
            .sheet(isPresented: $showingLists) {
                AddToListSheet(place: place)
            }
    }
}

struct PlaceSwipeActions: ViewModifier {
    let place: Place
    @Environment(SavedStore.self) private var saved
    @Environment(AccountStore.self) private var account
    @Environment(\.showPaywall) private var showPaywall

    func body(content: Content) -> some View {
        content.swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                if account.isEntitled(to: .favourites) { saved.toggleFavourite(place) } else { showPaywall(.favourites) }
            } label: {
                account.isMember && saved.isFavourite(place)
                    ? Label("Unsave", systemImage: "heart.slash.fill")
                    : Label("Save", systemImage: "heart.fill")
            }
            .tint(Color.accentColor)
        }
    }
}

private struct PlacePreview: View {
    let place: Place
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(url: place.image)
                .frame(width: 320, height: 240)
                .clipped()
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name).font(.headline)
                Text(place.subtitle).font(.subheadline).foregroundStyle(.secondary)
                if let quote = place.quote {
                    Text(quote).font(.footnote).lineLimit(3).padding(.top, 4)
                }
            }
            .padding()
        }
        .frame(width: 320)
    }
}

extension View {
    func placeContextMenu(_ place: Place) -> some View { modifier(PlaceContextMenu(place: place)) }
    func placeSwipeActions(_ place: Place) -> some View { modifier(PlaceSwipeActions(place: place)) }
}
