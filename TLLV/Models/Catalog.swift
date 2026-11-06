import Foundation
import CoreLocation

// MARK: - Catalog (GET /api/catalog)

struct Catalog: Decodable {
    var records: [Place]
    var collections: [GuideCollection]
    var siteContent: SiteContent
    var news: [NewsItem]

    private enum CodingKeys: String, CodingKey { case records, collections, siteContent, news }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        records = (try? c.decode([FailableDecodable<Place>].self, forKey: .records))?.compactMap(\.value) ?? []
        collections = (try? c.decode([FailableDecodable<GuideCollection>].self, forKey: .collections))?.compactMap(\.value) ?? []
        siteContent = (try? c.decode(SiteContent.self, forKey: .siteContent)) ?? SiteContent()
        news = (try? c.decode([FailableDecodable<NewsItem>].self, forKey: .news))?.compactMap(\.value) ?? []
    }
}

/// Skips a single malformed element instead of failing the whole array.
struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

// MARK: - Place (restaurant review or travel guide)

struct OpeningHours: Decodable, Hashable {
    /// 0 = Sunday … 6 = Saturday, matching JavaScript's Date.getDay().
    let day: Int
    let open: String
    let close: String
}

struct TravelPlace: Decodable, Hashable {
    var name: String
    var type: String?
    var veganOffering: String?
    var heading: String?
    var cuisine: String?
    var description: String?
    var url: URL?
    var address: String?

    private enum CodingKeys: String, CodingKey { case name, type, veganOffering, heading, cuisine, description, url, address }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.lenientString(.name) ?? "Unnamed"
        type = c.lenientString(.type)
        veganOffering = c.lenientString(.veganOffering)
        heading = c.lenientString(.heading)
        cuisine = c.lenientString(.cuisine)
        description = c.lenientString(.description)
        url = c.lenientURL(.url)
        address = c.lenientString(.address)
    }
}

struct Place: Identifiable, Decodable, Hashable {
    enum Kind: String { case restaurant, travel }

    let id: Int
    var kind: Kind
    var name: String
    var lifecycle: String
    var published: Bool
    var planOnly: Bool

    // Where
    var address: String?
    var area: String?
    var region: String?
    var country: String?
    var nearestStation: String?
    var walkingDistance: String?
    var latitude: Double?
    var longitude: Double?

    // What
    var cuisine: [String]
    var cardLabel: String?
    var venue: [String]
    var status: String?
    var veganOffering: String?
    var price: String?
    var priceRank: Int
    var meals: [String]
    var occasion: [String]
    var features: [String]
    var dishes: [String]
    var recommended: Bool
    var fave: String?
    var quote: String?
    var summary: String?
    var hours: [OpeningHours]

    // Accessibility & policies
    var glutenFreeFriendly: Bool?
    var wheelchairFriendly: Bool?
    var dogPolicy: String?

    // Media & links
    var image: URL?
    var gallery: [URL]
    var phone: String?
    var website: URL?
    var booking: URL?
    var review: URL?
    var instagram: URL?
    var lastOrders: URL?
    var googleMaps: URL?
    var publishedAt: Date?

    // Travel guides
    var destination: String?
    var travelPlaces: [TravelPlace]
    var guideBody: String?
    var highlights: [String]

    private enum CodingKeys: String, CodingKey {
        case id, kind, name, lifecycle, published, planOnly
        case address, area, region, country, nearestStation, walkingDistance, lat, lng
        case cuisine, cardLabel, venue, status, veganOffering, price, priceRank, meals, occasion, features, dishes
        case recommended, fave, quote, summary, hours
        case glutenFreeFriendly, wheelchairFriendly, dogPolicy
        case image, gallery, phone, website, booking, review, instagram, lastOrders, googleMapsUri, sourcePublishedAt
        case destination, places, guideBody, highlights
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.lenientInt(.id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing id")
        }
        self.id = id
        kind = Kind(rawValue: c.lenientString(.kind) ?? "") ?? .restaurant
        name = c.lenientString(.name) ?? "Untitled"
        lifecycle = c.lenientString(.lifecycle) ?? "active"
        published = c.lenientBool(.published) ?? true
        planOnly = c.lenientBool(.planOnly) ?? false

        address = c.lenientString(.address)
        area = c.lenientString(.area)
        region = c.lenientString(.region)
        country = c.lenientString(.country)
        nearestStation = c.lenientString(.nearestStation)
        walkingDistance = c.lenientString(.walkingDistance)
        latitude = c.lenientDouble(.lat)
        longitude = c.lenientDouble(.lng)

        cuisine = c.lenientStrings(.cuisine)
        cardLabel = c.lenientString(.cardLabel)
        venue = c.lenientStrings(.venue)
        status = c.lenientString(.status)
        veganOffering = c.lenientString(.veganOffering)
        price = c.lenientString(.price)
        priceRank = c.lenientInt(.priceRank) ?? 0
        meals = c.lenientStrings(.meals)
        occasion = c.lenientStrings(.occasion)
        features = c.lenientStrings(.features)
        dishes = c.lenientStrings(.dishes)
        recommended = c.lenientBool(.recommended) ?? false
        fave = c.lenientString(.fave)
        quote = c.lenientString(.quote)
        summary = c.lenientString(.summary)
        hours = (try? c.decodeIfPresent([FailableDecodable<OpeningHours>].self, forKey: .hours))?.compactMap(\.value) ?? []

        glutenFreeFriendly = c.lenientBool(.glutenFreeFriendly)
        wheelchairFriendly = c.lenientBool(.wheelchairFriendly)
        dogPolicy = c.lenientString(.dogPolicy)

        image = c.lenientURL(.image)
        gallery = c.lenientStrings(.gallery).compactMap(Site.resolveURL)
        phone = c.lenientString(.phone)
        website = c.lenientURL(.website)
        booking = c.lenientURL(.booking)
        review = c.lenientURL(.review)
        instagram = c.lenientURL(.instagram)
        lastOrders = c.lenientURL(.lastOrders)
        googleMaps = c.lenientURL(.googleMapsUri)
        publishedAt = c.lenientDate(.sourcePublishedAt)

        destination = c.lenientString(.destination)
        travelPlaces = (try? c.decodeIfPresent([FailableDecodable<TravelPlace>].self, forKey: .places))?.compactMap(\.value) ?? []
        guideBody = c.lenientString(.guideBody)
        highlights = c.lenientStrings(.highlights)
    }

    static func == (lhs: Place, rhs: Place) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Place {
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude, latitude != 0 || longitude != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isListed: Bool {
        kind == .restaurant && published && !planOnly && lifecycle != "closed"
    }

    var isFullyVegan: Bool {
        status == "Vegan" || veganOffering == "Fully vegan"
    }

    /// The short label shown under a name, e.g. "Chinese · London Fields".
    var subtitle: String {
        [cardLabel ?? cuisine.first, area].compactMap { $0 }.joined(separator: " · ")
    }

    var veganLabel: String {
        if isFullyVegan { return "Fully vegan" }
        return veganOffering ?? status ?? "Vegan options"
    }

    var allPhotos: [URL] {
        var seen = Set<URL>()
        return ([image].compactMap { $0 } + gallery).filter { seen.insert($0).inserted }
    }

    var basicSearchText: String {
        [name, area, region, nearestStation, cardLabel, destination, country].compactMap { $0 }
            .joined(separator: " ").lowercased()
    }

    var searchText: String {
        ([name, area, region, nearestStation, cardLabel, fave, destination, country].compactMap { $0 }
            + cuisine + dishes).joined(separator: " ").lowercased()
    }

    // MARK: Opening hours (all times are London time)

    private static func minutes(_ value: String) -> Int? {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }

    func isOpen(at date: Date = .now) -> Bool? {
        guard !hours.isEmpty else { return nil }
        let calendar = Site.londonCalendar
        let weekday = calendar.component(.weekday, from: date) - 1
        let now = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        for slot in hours {
            guard let open = Self.minutes(slot.open), var close = Self.minutes(slot.close) else { continue }
            if close <= open { close += 24 * 60 }
            if slot.day == weekday, now >= open, now < close { return true }
            // Late-night slots that started yesterday.
            let yesterday = (weekday + 6) % 7
            if slot.day == yesterday, close > 24 * 60, now + 24 * 60 < close { return true }
        }
        return false
    }

    func hours(on day: Int) -> [OpeningHours] {
        hours.filter { $0.day == day }
    }
}

// MARK: - Guides

struct GuideCollection: Identifiable, Decodable, Hashable {
    let id: String
    var title: String
    var coverTitle: String
    var description: String?
    var image: URL?
    var included: [String]
    var placeNotes: [String: String]
    var published: Bool
    var sortOrder: Int

    private enum CodingKeys: String, CodingKey { case id, title, coverTitle, description, image, included, placeNotes, published, sortOrder }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientString(.id) ?? UUID().uuidString
        title = c.lenientString(.title) ?? "Guide"
        coverTitle = c.lenientString(.coverTitle) ?? title
        description = c.lenientString(.description)
        image = c.lenientURL(.image)
        if let ints = try? c.decodeIfPresent([Int].self, forKey: .included) {
            included = ints.map(String.init)
        } else {
            included = c.lenientStrings(.included)
        }
        placeNotes = (try? c.decodeIfPresent([String: String].self, forKey: .placeNotes)) ?? [:]
        published = c.lenientBool(.published) ?? true
        sortOrder = c.lenientInt(.sortOrder) ?? 0
    }

    static func == (lhs: GuideCollection, rhs: GuideCollection) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Site content

struct Testimonial: Decodable, Identifiable, Hashable {
    let id: String
    let preview: String
    let full: String
}

struct SiteContent: Decodable {
    var aboutTitle = "Who is The Little London Vegan?"
    var aboutBody = ""
    var londonIntro: String?
    var travelIntro: String?
    var testimonials: [Testimonial] = []
    var perkOrder: [String] = []

    init() {}

    private enum CodingKeys: String, CodingKey { case aboutTitle, aboutBody, guideIntroductions, testimonials, perkOrder }
    private enum IntroKeys: String, CodingKey { case london, travel }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        aboutTitle = c.lenientString(.aboutTitle) ?? aboutTitle
        aboutBody = c.lenientString(.aboutBody) ?? ""
        if let intros = try? c.nestedContainer(keyedBy: IntroKeys.self, forKey: .guideIntroductions) {
            londonIntro = intros.lenientString(.london)
            travelIntro = intros.lenientString(.travel)
        }
        testimonials = (try? c.decodeIfPresent([Testimonial].self, forKey: .testimonials)) ?? []
        perkOrder = c.lenientStrings(.perkOrder)
    }
}

// MARK: - News

struct NewsItem: Identifiable, Decodable, Hashable {
    enum Kind: String {
        case opening, closure, menu, event, collab, other

        var label: String {
            switch self {
            case .opening: "Opening"
            case .closure: "Closure"
            case .menu: "New menu"
            case .event: "Event"
            case .collab: "Collab"
            case .other: "News"
            }
        }

        var symbol: String {
            switch self {
            case .opening: "sparkles"
            case .closure: "xmark.circle"
            case .menu: "menucard"
            case .event: "calendar"
            case .collab: "person.2"
            case .other: "newspaper"
            }
        }
    }

    let id: String
    var headline: String
    var summary: String?
    var body: String?
    var kind: Kind
    var status: String
    var date: Date?
    var imageURL: URL?
    var restaurantID: Int?
    var externalURL: URL?
    var externalLabel: String?
    var sourceURL: URL?
    var sourceName: String?

    private enum CodingKeys: String, CodingKey {
        case id, headline, summary, body, kind, status
        case event_date, published_at, image_url, restaurant_id, external_url, external_label, source_url, source_name
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientString(.id) ?? UUID().uuidString
        headline = c.lenientString(.headline) ?? "News"
        summary = c.lenientString(.summary)
        body = c.lenientString(.body)
        kind = Kind(rawValue: c.lenientString(.kind) ?? "") ?? .other
        status = c.lenientString(.status) ?? "published"
        date = c.lenientDate(.event_date) ?? c.lenientDate(.published_at)
        imageURL = c.lenientURL(.image_url)
        restaurantID = c.lenientInt(.restaurant_id)
        externalURL = c.lenientURL(.external_url)
        externalLabel = c.lenientString(.external_label)
        sourceURL = c.lenientURL(.source_url)
        sourceName = c.lenientString(.source_name)
    }

    static func == (lhs: NewsItem, rhs: NewsItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Perks (GET /api/perks)

struct PerksResponse: Decodable {
    var items: [Perk]
    private enum CodingKeys: String, CodingKey { case items }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decode([FailableDecodable<Perk>].self, forKey: .items))?.compactMap(\.value) ?? []
    }
}

struct Perk: Identifiable, Decodable, Hashable {
    let id: String
    var perkType: String
    var venueIDs: [Int]
    var venueName: String
    var title: String
    var description: String?
    var imageURL: URL?
    var validDays: [Int]
    var validUntil: Date?
    var minimumSpendPence: Int?
    var usageLimit: String?
    var isAffiliate: Bool

    private enum CodingKeys: String, CodingKey {
        case id, perkType, venueId, venueName, title, description, imageUrl, validDays, validUntil, expiresAt, minimumSpendPence, usageLimit, affiliate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientString(.id) ?? UUID().uuidString
        perkType = c.lenientString(.perkType) ?? "in_person"
        venueIDs = c.lenientStrings(.venueId).compactMap { Int($0) }
        venueName = c.lenientString(.venueName) ?? "Partner"
        title = c.lenientString(.title) ?? "Member offer"
        description = c.lenientString(.description)
        imageURL = c.lenientURL(.imageUrl)
        validDays = (try? c.decodeIfPresent([Int].self, forKey: .validDays)) ?? []
        validUntil = c.lenientDate(.validUntil) ?? c.lenientDate(.expiresAt)
        minimumSpendPence = c.lenientInt(.minimumSpendPence)
        usageLimit = c.lenientString(.usageLimit)
        isAffiliate = c.lenientBool(.affiliate) ?? false
    }

    var isOnline: Bool { perkType != "in_person" }

    var validDaysText: String? {
        guard !validDays.isEmpty, validDays.count < 7 else { return nil }
        let symbols = Site.londonCalendar.weekdaySymbols
        return validDays.sorted().compactMap { $0 >= 0 && $0 < 7 ? symbols[$0] : nil }.joined(separator: ", ")
    }

    static func == (lhs: Perk, rhs: Perk) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
