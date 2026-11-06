import SwiftUI

@main
struct TLLVApp: App {
    @State private var catalog = CatalogStore()
    @State private var saved = SavedStore()
    @State private var location = LocationManager()
    @State private var router = AppRouter()
    @State private var account = AccountStore()

    init() {
        // Restaurant photos are re-used across tabs, so give them a generous cache.
        URLCache.shared = URLCache(memoryCapacity: 64 * 1024 * 1024, diskCapacity: 512 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(catalog)
                .environment(saved)
                .environment(location)
                .environment(router)
                .environment(account)
                .task {
                    async let content: Void = catalog.loadIfNeeded()
                    async let session: Void = account.refresh()
                    _ = await (content, session)
                }
        }
    }
}

struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            Tab("Discover", systemImage: "house", value: AppTab.discover) {
                DiscoverView()
            }
            Tab("Explore", systemImage: "map", value: AppTab.explore) {
                ExploreView()
            }
            Tab("Guides", systemImage: "book", value: AppTab.guides) {
                GuidesView()
            }
            Tab("Perks", systemImage: "tag", value: AppTab.perks) {
                PerksView()
            }
            Tab("Saved", systemImage: "heart", value: AppTab.saved) {
                SavedView()
            }
        }
        .appHosts()
    }
}

/// Every navigation stack can push any piece of TLLV content.
struct ContentDestinations: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: Place.self) { place in
                if place.kind == .travel {
                    TravelGuideDetailView(guide: place)
                } else {
                    PlaceDetailView(place: place)
                }
            }
            .navigationDestination(for: GuideCollection.self) { CollectionDetailView(collection: $0) }
            .navigationDestination(for: NewsItem.self) { NewsDetailView(item: $0) }
            .navigationDestination(for: Perk.self) { PerkDetailView(perk: $0) }
            .navigationDestination(for: SavedList.self) { SavedListDetailView(listID: $0.id) }
    }
}

extension View {
    func contentDestinations() -> some View { modifier(ContentDestinations()) }
}
