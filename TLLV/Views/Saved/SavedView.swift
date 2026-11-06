import SwiftUI

struct SavedView: View {
    @Environment(CatalogStore.self) private var catalog
    @Environment(SavedStore.self) private var saved
    @Environment(AppRouter.self) private var router
    @Environment(AccountStore.self) private var account
    @State private var showingNewList = false
    @State private var newListName = ""

    private var favourites: [Place] { saved.favourites.compactMap(catalog.place(id:)) }

    var body: some View {
        NavigationStack {
            if account.isEntitled(to: .favourites) {
                savedContent
            } else {
                ScrollView {
                    PremiumLockedView(feature: .customLists,
                                      secondaryTitle: "Browse Free Restaurant Reviews",
                                      secondaryAction: { router.tab = .explore })
                        .padding()
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Saved")
            }
        }
    }

    private var savedContent: some View {
            List {
                Section {
                    NavigationLink {
                        FavouritesView()
                    } label: {
                        Label {
                            HStack {
                                Text("Favourites")
                                Spacer()
                                Text("\(favourites.count)").foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "heart.fill").foregroundStyle(Color.accentColor)
                        }
                    }
                }

                Section {
                    ForEach(saved.lists) { list in
                        NavigationLink(value: list) {
                            ListRow(list: list)
                        }
                    }
                    .onDelete { saved.deleteLists(at: $0) }

                    Button {
                        showingNewList = true
                    } label: {
                        Label("New List", systemImage: "plus")
                    }
                } header: {
                    Text("My Lists")
                } footer: {
                    if saved.lists.isEmpty {
                        Text("See it, save it, sort it. Make lists like “Date night” or “Birthday ideas” and add places from any review.")
                    }
                }

                if !favourites.isEmpty {
                    Section("Recently Saved") {
                        ForEach(favourites.prefix(5)) { place in
                            NavigationLink(value: place) { PlaceRow(place: place) }
                                .placeContextMenu(place)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Saved")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !saved.lists.isEmpty { EditButton() }
                }
            }
            .alert("New List", isPresented: $showingNewList) {
                TextField("List name", text: $newListName)
                Button("Cancel", role: .cancel) { newListName = "" }
                Button("Create") {
                    if !newListName.trimmingCharacters(in: .whitespaces).isEmpty {
                        saved.createList(named: newListName)
                    }
                    newListName = ""
                }
            } message: {
                Text("Give your list a name.")
            }
            .contentDestinations()
    }
}

private struct ListRow: View {
    let list: SavedList
    @Environment(CatalogStore.self) private var catalog

    var body: some View {
        let cover = list.placeIDs.lazy.compactMap { catalog.place(id: $0)?.image }.first
        HStack(spacing: 12) {
            RemoteImage(url: cover, symbol: "list.bullet")
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(list.name).font(.headline)
                Text(list.placeIDs.count == 1 ? "1 place" : "\(list.placeIDs.count) places")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct FavouritesView: View {
    @Environment(CatalogStore.self) private var catalog
    @Environment(SavedStore.self) private var saved
    @State private var showingMap = false

    var body: some View {
        let places = saved.favourites.compactMap(catalog.place(id:))
        List {
            ForEach(places) { place in
                NavigationLink(value: place) { PlaceRow(place: place) }
                    .placeContextMenu(place)
            }
            .onDelete { saved.removeFavourites(at: $0) }
        }
        .listStyle(.plain)
        .overlay {
            if places.isEmpty {
                ContentUnavailableView("No Favourites Yet", systemImage: "heart",
                                       description: Text("Tap the heart on any restaurant to save it here."))
            }
        }
        .navigationTitle("Favourites")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingMap = true } label: { Image(systemName: "map") }
                    .disabled(places.isEmpty)
                    .accessibilityLabel("Show on map")
            }
        }
        .sheet(isPresented: $showingMap) {
            PlacesMapSheet(title: "Favourites", places: places)
        }
    }
}

struct SavedListDetailView: View {
    let listID: SavedList.ID
    @Environment(CatalogStore.self) private var catalog
    @Environment(SavedStore.self) private var saved
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var showingRename = false
    @State private var showingMap = false
    @State private var showingDelete = false
    @State private var name = ""

    var body: some View {
        if let list = saved.list(id: listID) {
            let places = list.placeIDs.compactMap(catalog.place(id:))
            List {
                ForEach(places) { place in
                    NavigationLink(value: place) { PlaceRow(place: place) }
                }
                .onDelete { saved.removePlaces(at: $0, from: list) }
                .onMove { saved.movePlaces(from: $0, to: $1, in: list) }
            }
            .listStyle(.plain)
            .overlay {
                if places.isEmpty {
                    ContentUnavailableView {
                        Label("No Places Yet", systemImage: "list.bullet")
                    } description: {
                        Text("Add places from any restaurant using Add to List.")
                    } actions: {
                        Button("Explore Restaurants") { router.tab = .explore }
                    }
                }
            }
            .navigationTitle(list.name)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showingMap = true } label: { Image(systemName: "map") }
                        .disabled(places.isEmpty)
                        .accessibilityLabel("Show on map")
                    Menu {
                        Button {
                            name = list.name
                            showingRename = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showingDelete = true
                        } label: {
                            Label("Delete List", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    EditButton()
                }
            }
            .alert("Rename List", isPresented: $showingRename) {
                TextField("List name", text: $name)
                Button("Cancel", role: .cancel) {}
                Button("Save") { if !name.isEmpty { saved.rename(list, to: name) } }
            }
            .confirmationDialog("Delete “\(list.name)”?", isPresented: $showingDelete, titleVisibility: .visible) {
                Button("Delete List", role: .destructive) {
                    saved.delete(list)
                    dismiss()
                }
            } message: {
                Text("This can’t be undone.")
            }
            .sheet(isPresented: $showingMap) {
                PlacesMapSheet(title: list.name, places: places)
            }
        } else {
            ContentUnavailableView("List Deleted", systemImage: "trash")
        }
    }
}

/// Lets the user tick which lists a place belongs to.
struct AddToListSheet: View {
    let place: Place
    @Environment(SavedStore.self) private var saved
    @Environment(\.dismiss) private var dismiss
    @State private var newListName = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        saved.toggleFavourite(place)
                    } label: {
                        row(title: "Favourites", symbol: "heart.fill", isOn: saved.isFavourite(place))
                    }
                }
                Section("My Lists") {
                    ForEach(saved.lists) { list in
                        Button {
                            saved.toggle(place, in: list)
                        } label: {
                            row(title: list.name, symbol: "list.bullet", isOn: saved.contains(place, in: list))
                        }
                    }
                    HStack {
                        Image(systemName: "plus.circle.fill").foregroundStyle(Color.accentColor)
                        TextField("New list", text: $newListName)
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .onSubmit(createList)
                    }
                }
            }
            .navigationTitle("Save \(place.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sensoryFeedback(.selection, trigger: saved.lists)
        }
        .presentationDetents([.medium, .large])
    }

    private func createList() {
        let trimmed = newListName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        saved.createList(named: trimmed, with: place)
        newListName = ""
    }

    private func row(title: String, symbol: String, isOn: Bool) -> some View {
        HStack {
            Label(title, systemImage: symbol).foregroundStyle(.primary)
            Spacer()
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .contentShape(Rectangle())
    }
}
