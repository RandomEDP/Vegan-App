import Foundation
import Observation
import SwiftUI // IndexSet helpers for List editing (remove(atOffsets:), move(fromOffsets:))

/// A user-made list ("See it, save it, sort it.").
struct SavedList: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var placeIDs: [Int] = []
    var created = Date.now
}

/// Favourites and custom lists, stored on device.
@MainActor
@Observable
final class SavedStore {
    private(set) var favourites: [Int] = []
    private(set) var lists: [SavedList] = []

    private struct Snapshot: Codable {
        var favourites: [Int]
        var lists: [SavedList]
    }

    private let storageKey = "tllv.saved.v1"

    init() {
        if DemoMode.isEnabled {
            favourites = DemoMode.favouriteIDs
            lists = [SavedList(name: "Date night", placeIDs: DemoMode.dateNightIDs),
                     SavedList(name: "Birthday ideas", placeIDs: Array(DemoMode.favouriteIDs.suffix(2)))]
            return
        }
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            favourites = snapshot.favourites
            lists = snapshot.lists
        }
    }

    private func persist() {
        guard !DemoMode.isEnabled else { return }
        let snapshot = Snapshot(favourites: favourites, lists: lists)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    // MARK: Favourites

    func isFavourite(_ place: Place) -> Bool { favourites.contains(place.id) }

    func toggleFavourite(_ place: Place) {
        if let index = favourites.firstIndex(of: place.id) {
            favourites.remove(at: index)
        } else {
            favourites.insert(place.id, at: 0)
        }
        persist()
    }

    func removeFavourites(at offsets: IndexSet) {
        favourites.remove(atOffsets: offsets)
        persist()
    }

    // MARK: Lists

    @discardableResult
    func createList(named name: String, with place: Place? = nil) -> SavedList {
        var list = SavedList(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        if let place { list.placeIDs.append(place.id) }
        lists.insert(list, at: 0)
        persist()
        return list
    }

    func rename(_ list: SavedList, to name: String) {
        guard let index = lists.firstIndex(where: { $0.id == list.id }) else { return }
        lists[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
    }

    func deleteLists(at offsets: IndexSet) {
        lists.remove(atOffsets: offsets)
        persist()
    }

    func delete(_ list: SavedList) {
        lists.removeAll { $0.id == list.id }
        persist()
    }

    func list(id: SavedList.ID) -> SavedList? {
        lists.first { $0.id == id }
    }

    func contains(_ place: Place, in list: SavedList) -> Bool {
        self.list(id: list.id)?.placeIDs.contains(place.id) ?? false
    }

    func toggle(_ place: Place, in list: SavedList) {
        guard let index = lists.firstIndex(where: { $0.id == list.id }) else { return }
        if let placeIndex = lists[index].placeIDs.firstIndex(of: place.id) {
            lists[index].placeIDs.remove(at: placeIndex)
        } else {
            lists[index].placeIDs.append(place.id)
        }
        persist()
    }

    func removePlaces(at offsets: IndexSet, from list: SavedList) {
        guard let index = lists.firstIndex(where: { $0.id == list.id }) else { return }
        lists[index].placeIDs.remove(atOffsets: offsets)
        persist()
    }

    func movePlaces(from source: IndexSet, to destination: Int, in list: SavedList) {
        guard let index = lists.firstIndex(where: { $0.id == list.id }) else { return }
        lists[index].placeIDs.move(fromOffsets: source, toOffset: destination)
        persist()
    }
}
