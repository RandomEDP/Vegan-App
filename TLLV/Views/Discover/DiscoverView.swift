import SwiftUI

struct DiscoverView: View {
    @Environment(CatalogStore.self) private var catalog
    @Environment(AppRouter.self) private var router
    @Environment(AccountStore.self) private var account
    @State private var showingAbout = false
    @State private var showingNewsletter = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 32) {
                    hero

                    if let message = catalog.errorMessage, catalog.restaurants.isEmpty {
                        ContentUnavailableView("Can’t Load the Guide", systemImage: "wifi.slash", description: Text(message))
                    }

                    if !catalog.latestReviews.isEmpty { reviewsSection }
                    if !catalog.collections.isEmpty { guidesSection }
                    perksBanner
                    if !catalog.news.isEmpty { newsSection }
                    listsBanner
                    meetClare
                    newsletterCard
                }
                .padding(.bottom, 24)
            }
            .refreshable { await catalog.refresh() }
            .navigationTitle("Discover")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAbout = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Account")
                }
            }
            .sheet(isPresented: $showingAbout) {
                NavigationStack { AccountView().contentDestinations() }
                    .appHosts()
            }
            .sheet(isPresented: $showingNewsletter) {
                NewsletterSheet()
            }
            .contentDestinations()
        }
    }

    // MARK: Sections

    private var hero: some View {
        VStack(spacing: 8) {
            Image("Wordmark")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 340)
                .accessibilityLabel("The Little London Vegan")
            Text("The ultimate vegan guide to London")
                .font(.headline)
                .foregroundStyle(Color("Lavender"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal)
        .background(Color("BrandBackground"), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal)
    }

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Restaurant Reviews", subtitle: "Clare’s latest visits") {
                PlaceListView(title: "Restaurant Reviews", places: catalog.restaurants.filter { $0.image != nil })
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(catalog.latestReviews) { place in
                        NavigationLink(value: place) {
                            PlaceCard(place: place)
                                .containerRelativeFrame(.horizontal, count: 5, span: 3, spacing: 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private var guidesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Clare’s Guides") {
                GuidesView(embedded: true)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(catalog.collections) { collection in
                        NavigationLink(value: collection) {
                            GuideCoverCard(title: collection.coverTitle, eyebrow: "Member guide", image: collection.image)
                                .overlay(alignment: .topTrailing) {
                                    if !account.isMember { PremiumBadge().padding(10) }
                                }
                                .containerRelativeFrame(.horizontal, count: 6, span: 5, spacing: 12)
                                .frame(height: 200)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private var perksBanner: some View {
        Button {
            router.tab = .perks
        } label: {
            BannerCard(
                symbol: "tag.fill",
                title: "Perks",
                message: "Exclusive restaurant & brand discounts for Premium members",
                action: "View all perks"
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private var listsBanner: some View {
        Button {
            router.tab = .saved
        } label: {
            BannerCard(
                symbol: "list.bullet.rectangle.portrait.fill",
                title: "See it, save it, sort it.",
                message: "Save places you love and sort them into your own lists.",
                action: "Create a list"
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private var newsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Latest News") {
                NewsListView()
            }
            VStack(spacing: 0) {
                ForEach(catalog.news.prefix(3)) { item in
                    NavigationLink(value: item) {
                        NewsRow(item: item)
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if item.id != catalog.news.prefix(3).last?.id {
                        Divider().padding(.leading)
                    }
                }
            }
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal)
        }
    }

    private var meetClare: some View {
        NavigationLink {
            AboutView()
        } label: {
            HStack(spacing: 16) {
                RemoteImage(url: Site.resolveURL("/assets/ima-latest-clare.webp"), symbol: "person.fill")
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("WHO’S BEHIND TLLV?")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Meet Clare")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private var newsletterCard: some View {
        Button {
            showingNewsletter = true
        } label: {
            BannerCard(
                symbol: "envelope.fill",
                title: "The TLLV Newsletter",
                message: "New openings, closures, menus, reviews & more.",
                action: "Subscribe"
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}

// MARK: - Shared cards

struct BannerCard: View {
    let symbol: String
    let title: String
    let message: String
    let action: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("BrandBackground").opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }
}

struct GuideCoverCard: View {
    let title: String
    var eyebrow: String?
    let image: URL?

    var body: some View {
        RemoteImage(url: image, symbol: "book.fill")
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    if let eyebrow {
                        Text(eyebrow.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                }
                .padding()
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// A plain list of places, used for "See All" destinations.
struct PlaceListView: View {
    let title: String
    let places: [Place]

    var body: some View {
        List(places) { place in
            NavigationLink(value: place) {
                PlaceRow(place: place)
            }
            .placeContextMenu(place)
        }
        .listStyle(.plain)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
