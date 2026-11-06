import SwiftUI

/// "Narrow it down" — the website's filter panel as a native form sheet.
struct FilterSheet: View {
    @Binding var filter: PlaceFilter
    let resultCount: Int

    @Environment(CatalogStore.self) private var catalog
    @Environment(\.dismiss) private var dismiss
    @State private var showAllCuisines = false

    private let priceLabels = [1: "£", 2: "££", 3: "£££", 4: "££££"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Vegan status", selection: $filter.vegan) {
                        ForEach(VeganFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section("Right now") {
                    ForEach(PlaceFilter.featureFilters) { item in
                        Toggle(isOn: Binding(
                            get: { filter[keyPath: item.keyPath] },
                            set: { filter[keyPath: item.keyPath] = $0 }
                        )) {
                            Label(item.title, systemImage: item.symbol)
                        }
                    }
                }

                Section("Price") {
                    HStack {
                        ForEach(1...4, id: \.self) { rank in
                            let isOn = filter.prices.contains(rank)
                            Button {
                                if isOn { filter.prices.remove(rank) } else { filter.prices.insert(rank) }
                            } label: {
                                Text(priceLabels[rank] ?? "")
                                    .font(.body.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(isOn ? Color.white : Color.primary)
                                    .background(isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color(.tertiarySystemFill)),
                                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isOn ? .isSelected : [])
                        }
                    }
                }

                Section("Region") {
                    ForEach(catalog.regions, id: \.self) { region in
                        checkRow(region, isOn: filter.regions.contains(region)) {
                            filter.regions.formSymmetricDifference([region])
                        }
                    }
                }

                Section {
                    ForEach(showAllCuisines ? catalog.cuisines : Array(catalog.cuisines.prefix(10)), id: \.self) { cuisine in
                        checkRow(cuisine, isOn: filter.cuisines.contains(cuisine)) {
                            filter.cuisines.formSymmetricDifference([cuisine])
                        }
                    }
                    if catalog.cuisines.count > 10 {
                        Button(showAllCuisines ? "Show Fewer" : "Show All \(catalog.cuisines.count) Cuisines") {
                            withAnimation { showAllCuisines.toggle() }
                        }
                    }
                } header: {
                    Text("Cuisine")
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear All") { filter.clearFilters() }
                        .disabled(filter.activeCount == 0)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Show \(resultCount)") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func checkRow(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(.primary)
                Spacer()
                if isOn {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
