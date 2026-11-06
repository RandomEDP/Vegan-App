import Foundation
import Observation

enum AppTab: Hashable {
    case discover, explore, guides, perks, saved
}

/// Shared app navigation state, so cards on Discover can jump to other tabs.
@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = .discover
    var explore = PlaceFilter()
}

enum VeganFilter: String, CaseIterable, Identifiable {
    case any = "Any"
    case fullyVegan = "Fully vegan"
    case veganOptions = "Vegan options"
    var id: String { rawValue }
}

enum PlaceSort: String, CaseIterable, Identifiable {
    case newest = "Newest reviews"
    case name = "Name"
    case nearest = "Nearest"
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .newest: "clock"
        case .name: "textformat"
        case .nearest: "location"
        }
    }
}

/// The website's "Narrow it down" filters.
struct PlaceFilter: Equatable {
    var query = ""
    var vegan: VeganFilter = .any
    var cuisines: Set<String> = []
    var regions: Set<String> = []
    var prices: Set<Int> = []
    var openNow = false
    var clareRecommends = false
    var dogFriendly = false
    var glutenFreeFriendly = false
    var acceptsBookings = false
    var sort: PlaceSort = .newest
    /// Dish search is a Premium feature on the website.
    var searchDishes = true

    /// What a free user gets: name/area search only, no Premium filters.
    var freeVersion: PlaceFilter {
        var free = PlaceFilter()
        free.query = query
        free.sort = sort == .nearest ? .newest : sort
        free.searchDishes = false
        return free
    }

    struct FeatureToggle: Identifiable {
        let title: String
        let symbol: String
        let keyPath: WritableKeyPath<PlaceFilter, Bool>
        var id: String { title }
    }

    static let featureFilters: [FeatureToggle] = [
        FeatureToggle(title: "Open now", symbol: "clock", keyPath: \.openNow),
        FeatureToggle(title: "Clare’s faves", symbol: "star", keyPath: \.clareRecommends),
        FeatureToggle(title: "Dog-friendly", symbol: "pawprint", keyPath: \.dogFriendly),
        FeatureToggle(title: "Gluten-free friendly", symbol: "leaf", keyPath: \.glutenFreeFriendly),
        FeatureToggle(title: "Takes bookings", symbol: "calendar.badge.checkmark", keyPath: \.acceptsBookings)
    ]

    var activeCount: Int {
        var count = cuisines.count + regions.count + prices.count
        if vegan != .any { count += 1 }
        for item in Self.featureFilters where self[keyPath: item.keyPath] { count += 1 }
        return count
    }

    mutating func clearFilters() {
        let keepQuery = query
        let keepSort = sort
        self = PlaceFilter()
        query = keepQuery
        sort = keepSort
    }

    func matches(_ place: Place, now: Date = .now) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmed.isEmpty {
            let haystack = searchDishes ? place.searchText : place.basicSearchText
            let words = trimmed.split(separator: " ")
            if !words.allSatisfy({ haystack.contains($0) }) { return false }
        }
        switch vegan {
        case .any: break
        case .fullyVegan: if !place.isFullyVegan { return false }
        case .veganOptions: if place.isFullyVegan { return false }
        }
        if !cuisines.isEmpty, cuisines.isDisjoint(with: place.cuisine) { return false }
        if !regions.isEmpty, !regions.contains(place.region ?? "") { return false }
        if !prices.isEmpty, !prices.contains(place.priceRank) { return false }
        if clareRecommends, !place.recommended { return false }
        if dogFriendly, !(place.features.contains("Dog-friendly") || place.dogPolicy?.lowercased() == "yes") { return false }
        if glutenFreeFriendly, place.glutenFreeFriendly != true { return false }
        if acceptsBookings, !(place.features.contains("Accepts bookings") || place.booking != nil) { return false }
        if openNow, place.isOpen(at: now) != true { return false }
        return true
    }
}
