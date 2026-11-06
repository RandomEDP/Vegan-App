import SwiftUI

struct NewsListView: View {
    @Environment(CatalogStore.self) private var catalog
    @State private var kind: NewsItem.Kind?

    private var kinds: [NewsItem.Kind] {
        var seen = Set<String>()
        return catalog.news.map(\.kind).filter { seen.insert($0.rawValue).inserted }
    }

    var body: some View {
        List(catalog.news.filter { kind == nil || $0.kind == kind }) { item in
            NavigationLink(value: item) {
                NewsRow(item: item)
            }
        }
        .listStyle(.plain)
        .navigationTitle("News")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Show", selection: $kind) {
                        Text("All News").tag(NewsItem.Kind?.none)
                        ForEach(kinds, id: \.rawValue) { kind in
                            Label(kind.label, systemImage: kind.symbol).tag(Optional(kind))
                        }
                    }
                } label: {
                    Image(systemName: kind == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
                .accessibilityLabel("Filter news")
            }
        }
        .refreshable { await catalog.refresh() }
    }
}

struct NewsRow: View {
    let item: NewsItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Label(item.kind.label, systemImage: item.kind.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                if let date = item.date {
                    Text("·").foregroundStyle(.tertiary)
                    Text(date.tllvShort)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(item.headline)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            if let summary = item.summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NewsDetailView: View {
    let item: NewsItem
    @Environment(CatalogStore.self) private var catalog
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let image = item.imageURL {
                    RemoteImage(url: image, symbol: "newspaper")
                        .frame(height: 240)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label(item.kind.label, systemImage: item.kind.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    Text(item.headline)
                        .font(.largeTitle.bold())
                    if let date = item.date {
                        Text(date.formatted(date: .long, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Text((item.body ?? item.summary ?? "").markdownAttributed)
                    .font(.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)

                if let id = item.restaurantID, let place = catalog.place(id: id) {
                    NavigationLink(value: place) {
                        PlaceRow(place: place)
                            .padding(12)
                            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                if let url = item.externalURL ?? item.sourceURL {
                    Button {
                        openURL(url)
                    } label: {
                        Label(item.externalURL != nil ? (item.externalLabel ?? "Find out more") : "Source: \(item.sourceName ?? url.host() ?? "link")",
                              systemImage: "arrow.up.forward.square")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: Site.baseURL.appendingFragment("news"), subject: Text(item.headline), message: Text(item.headline))
            }
        }
    }
}
