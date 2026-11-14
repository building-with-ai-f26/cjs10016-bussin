import SwiftUI
import MapKit

struct SearchView: View {
    let saved: SavedPlaces
    @Binding var path: [Place]
    @State private var search = PlaceSearch()
    @State private var resolving = false
    @State private var lookupFailed = false
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var search = search
        List {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Address, building, or restaurant", text: $search.query)
                        .focused($focused)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                    if resolving { ProgressView() }
                }
            }
            if search.query.trimmingCharacters(in: .whitespaces).isEmpty {
                savedSection("Favorites", saved.favorites, icon: "star.fill")
                savedSection("Recent", saved.recents.filter { !saved.isFavorite($0) }, icon: "clock")
            } else if search.failed || lookupFailed {
                Text("Search isn't reachable right now. Check your connection and try again.")
                    .foregroundStyle(.secondary)
            } else {
                Section {
                    ForEach(search.suggestions, id: \.self) { s in
                        Button { Task { await pick(s) } } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(s.title).foregroundStyle(Color.primary)
                                if !s.subtitle.isEmpty {
                                    Text(s.subtitle).font(.footnote).foregroundStyle(Color.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Where to?")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            focused = true
            Analytics.capture("search_opened")
        }
    }

    @ViewBuilder
    private func savedSection(_ title: String, _ places: [Destination], icon: String) -> some View {
        if !places.isEmpty {
            Section(title) {
                ForEach(places) { d in
                    Button { open(d, from: title == "Favorites" ? .favorite : .recent) } label: { Label(d.name, systemImage: icon).foregroundStyle(Color.primary) }
                }
            }
        }
    }

    private func pick(_ s: MKLocalSearchCompletion) async {
        resolving = true
        defer { resolving = false }
        guard let d = await search.resolve(s) else { lookupFailed = true; return }
        lookupFailed = false
        open(d, from: .search)
    }

    /// Replace the search screen with the answer, so Back goes home.
    private func open(_ d: Destination, from source: Analytics.PlaceSource) {
        Analytics.capture("place_selected", ["source": source.rawValue])
        saved.noteSearched(d)
        path = [.trip(d)]
    }
}
