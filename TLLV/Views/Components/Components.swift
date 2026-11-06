import SwiftUI
import SafariServices

// MARK: - Remote image

/// AsyncImage with a calm placeholder and fill cropping.
struct RemoteImage: View {
    let url: URL?
    var symbol = "fork.knife"

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                placeholder
            default:
                placeholder.overlay { if url != nil { ProgressView() } }
            }
        }
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color(.tertiarySystemFill))
            .overlay {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
    }
}

// MARK: - Tags

struct TagLabel: View {
    let text: String
    var symbol: String?
    var prominent = false

    var body: some View {
        Label {
            Text(text)
        } icon: {
            if let symbol { Image(systemName: symbol) }
        }
        .labelStyle(.titleAndIcon)
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(prominent ? Color.white : Color.accentColor)
        .background(prominent ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.accentColor.opacity(0.12)), in: Capsule())
    }
}

struct VeganBadge: View {
    let place: Place
    var body: some View {
        TagLabel(text: place.veganLabel, symbol: "leaf.fill", prominent: place.isFullyVegan)
    }
}

// MARK: - Rows & cards

struct PlaceRow: View {
    let place: Place
    var note: String?
    var distance: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RemoteImage(url: place.image)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(place.name)
                        .font(.headline)
                        .lineLimit(1)
                    if place.recommended {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Clare recommends")
                    }
                }
                Text([place.subtitle, place.price].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    VeganBadge(place: place)
                    if let distance {
                        Text(distance).font(.caption).foregroundStyle(.secondary)
                    } else if let station = place.nearestStation {
                        Label(station, systemImage: "tram.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                if let note, !note.isEmpty {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// Large photo card used in horizontal carousels (App Store style).
struct PlaceCard: View {
    let place: Place

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(4 / 5, contentMode: .fit)
                .overlay { RemoteImage(url: place.image) }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    FavouriteButton(place: place, style: .overlay)
                        .padding(10)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(place.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let date = place.publishedAt {
                    Text(date.tllvShort)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

struct FavouriteButton: View {
    enum Style { case toolbar, overlay }

    let place: Place
    var style: Style = .toolbar
    @Environment(SavedStore.self) private var saved
    @Environment(AccountStore.self) private var account
    @Environment(\.showPaywall) private var showPaywall

    var body: some View {
        let isFavourite = account.isMember && saved.isFavourite(place)
        Button {
            guard account.isEntitled(to: .favourites) else {
                showPaywall(.favourites)
                return
            }
            withAnimation(.snappy) { saved.toggleFavourite(place) }
        } label: {
            switch style {
            case .toolbar:
                Image(systemName: isFavourite ? "heart.fill" : "heart")
            case .overlay:
                Image(systemName: isFavourite ? "heart.fill" : "heart")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isFavourite ? Color.accentColor : Color.primary)
                    .frame(width: 36, height: 36)
                    .background(.regularMaterial, in: Circle())
            }
        }
        .buttonStyle(.plain)
        .contentTransition(.symbolEffect(.replace))
        .sensoryFeedback(.selection, trigger: isFavourite)
        .accessibilityLabel(isFavourite ? "Remove \(place.name) from favourites" : "Save \(place.name) to favourites")
    }
}

// MARK: - Section header

struct SectionHeader<Destination: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.bold())
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if Destination.self != EmptyView.self {
                NavigationLink("See All", destination: destination)
                    .font(.body)
            }
        }
        .padding(.horizontal)
    }
}

extension SectionHeader where Destination == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.destination = { EmptyView() }
    }
}

// MARK: - In-app Safari

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(named: "AccentColor")
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

struct IdentifiedURL: Identifiable {
    let id = UUID()
    let url: URL
}

/// Opens web links in an in-app Safari sheet (like Apple's own apps), while
/// phone, Maps and app links go to the system.
struct InAppBrowser: ViewModifier {
    @State private var presented: IdentifiedURL?

    func body(content: Content) -> some View {
        content
            .environment(\.openURL, OpenURLAction { url in
                guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
                    return .systemAction
                }
                let host = url.host()?.lowercased() ?? ""
                if host.contains("maps.apple.com") || host.contains("instagram.com") || host.contains("tiktok.com") || host.contains("youtube.com") {
                    return .systemAction(url)
                }
                presented = IdentifiedURL(url: url)
                return .handled
            })
            .sheet(item: $presented) { item in
                SafariView(url: item.url).ignoresSafeArea()
            }
    }
}

extension View {
    func inAppBrowser() -> some View { modifier(InAppBrowser()) }
}

// MARK: - Helpers

enum MapsLink {
    static func appleMaps(for place: Place) -> URL? {
        var components = URLComponents(string: "https://maps.apple.com/")!
        var items = [URLQueryItem(name: "q", value: place.name)]
        if let coordinate = place.coordinate {
            items.append(URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"))
        } else if let address = place.address {
            items.append(URLQueryItem(name: "address", value: address))
        }
        components.queryItems = items
        return components.url
    }

    static func search(_ query: String) -> URL? {
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return components.url
    }
}

extension String {
    /// Turns the website's light markdown (*emphasis*) into an AttributedString.
    var markdownAttributed: AttributedString {
        (try? AttributedString(markdown: self, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(self)
    }
}
