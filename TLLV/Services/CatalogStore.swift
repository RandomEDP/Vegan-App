import Foundation
import Observation

/// Loads TLLV content from the same public API the website uses, with an on-disk
/// cache and a bundled snapshot so the app opens instantly and works offline.
@MainActor
@Observable
final class CatalogStore {
    private(set) var restaurants: [Place] = []
    private(set) var latestReviews: [Place] = []
    private(set) var travelGuides: [Place] = []
    private(set) var collections: [GuideCollection] = []
    private(set) var news: [NewsItem] = []
    private(set) var perks: [Perk] = []
    private(set) var siteContent = SiteContent()
    private(set) var lastUpdated: Date?
    private(set) var isRefreshing = false
    private(set) var errorMessage: String?

    private(set) var cuisines: [String] = []
    private(set) var regions: [String] = []
    private(set) var areas: [String] = []

    private var placesByID: [Int: Place] = [:]
    private var didLoad = false

    private var session: URLSession { Site.session }

    private var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("catalog.json")
    }

    // MARK: Loading

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await loadLocalCopy()
        await refresh()
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        async let catalogResult: Void = refreshCatalog()
        async let perksResult: Void = refreshPerks()
        _ = await (catalogResult, perksResult)
    }

    private func loadLocalCopy() async {
        let sources = [cacheURL, Bundle.main.url(forResource: "catalog-seed", withExtension: "json")].compactMap { $0 }
        for url in sources {
            if let catalog = try? await Self.decodeCatalog(contentsOf: url) {
                apply(catalog)
                return
            }
        }
    }

    /// Decoding ~3 MB of JSON happens off the main thread to keep scrolling smooth.
    nonisolated private static func decodeCatalog(contentsOf url: URL) async throws -> Catalog {
        try await Task.detached(priority: .userInitiated) {
            try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
        }.value
    }

    nonisolated private static func decodeCatalog(data: Data) async throws -> Catalog {
        try await Task.detached(priority: .userInitiated) {
            try JSONDecoder().decode(Catalog.self, from: data)
        }.value
    }

    private func refreshCatalog() async {
        var components = URLComponents(url: Site.baseURL.appendingPathComponent("api/catalog"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "app", value: "ios")]
        do {
            let (data, response) = try await session.data(from: components.url!)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let catalog = try await Self.decodeCatalog(data: data)
            guard !catalog.records.isEmpty else { throw URLError(.cannotParseResponse) }
            apply(catalog)
            try? data.write(to: cacheURL, options: .atomic)
            lastUpdated = .now
            errorMessage = nil
        } catch {
            if restaurants.isEmpty {
                errorMessage = "Couldn’t load the guide. Check your connection and pull to refresh."
            }
        }
    }

    private func refreshPerks() async {
        do {
            let (data, _) = try await session.data(from: Site.baseURL.appendingPathComponent("api/perks"))
            let response = try JSONDecoder().decode(PerksResponse.self, from: data)
            perks = sortPerks(response.items)
        } catch {
            // Perks are optional; keep whatever we had.
        }
    }

    private func apply(_ catalog: Catalog) {
        let listed = catalog.records.filter(\.isListed)
        restaurants = listed.sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
        latestReviews = Array(restaurants.filter { $0.image != nil }.prefix(12))
        travelGuides = catalog.records
            .filter { $0.kind == .travel && $0.published && $0.lifecycle != "closed" }
            .sorted { $0.name < $1.name }
        collections = catalog.collections.filter(\.published).sorted { $0.sortOrder < $1.sortOrder }
        news = catalog.news
            .filter { $0.status == "published" }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        siteContent = catalog.siteContent
        placesByID = Dictionary(catalog.records.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        cuisines = Self.facet(listed.flatMap(\.cuisine))
        regions = Self.facet(listed.compactMap(\.region))
        areas = Self.facet(listed.compactMap(\.area))
        if !perks.isEmpty { perks = sortPerks(perks) }
    }

    private static func facet(_ values: [String]) -> [String] {
        let counts = Dictionary(values.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.keys.sorted { lhs, rhs in
            counts[lhs, default: 0] == counts[rhs, default: 0] ? lhs < rhs : counts[lhs, default: 0] > counts[rhs, default: 0]
        }
    }

    private func sortPerks(_ items: [Perk]) -> [Perk] {
        let order = Dictionary(siteContent.perkOrder.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        return items.sorted { (order[$0.id] ?? .max) < (order[$1.id] ?? .max) }
    }

    // MARK: Lookups

    func place(id: Int) -> Place? { placesByID[id] }

    func places(in collection: GuideCollection) -> [Place] {
        collection.included.compactMap { Int($0) }.compactMap { placesByID[$0] }.filter { $0.lifecycle != "closed" }
    }

    func venue(for perk: Perk) -> Place? {
        perk.venueIDs.lazy.compactMap { self.placesByID[$0] }.first
    }

    func perks(for place: Place) -> [Perk] {
        perks.filter { $0.venueIDs.contains(place.id) }
    }

    var travelGuidesByCountry: [(country: String, guides: [Place])] {
        Dictionary(grouping: travelGuides, by: { $0.country ?? "Elsewhere" })
            .map { (country: $0.key, guides: $0.value) }
            .sorted { lhs, rhs in
                // Keep the UK first, like the website.
                if lhs.country == "United Kingdom" { return true }
                if rhs.country == "United Kingdom" { return false }
                return lhs.country < rhs.country
            }
    }

    // MARK: Newsletter (POST /api/newsletter)

    struct NewsletterResult { let message: String }

    func subscribeToNewsletter(email: String) async throws -> NewsletterResult {
        var request = URLRequest(url: Site.baseURL.appendingPathComponent("api/newsletter"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "consent": true, "website": ""])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        if json?["confirmationRequired"] as? Bool == true {
            return NewsletterResult(message: "Check your inbox and confirm your email to finish signing up.")
        }
        return NewsletterResult(message: "You’re in! Keep your eyes peeled for your first newsletter.")
    }
}
