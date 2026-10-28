import SwiftUI

/// Favorites tab: only the stations the user has starred, nothing else.
struct FavoritesTabView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @State private var isReordering = false

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let stations = favorites.favorites.map(\.station)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        RadioPageHeading(title: "Favorites", subtitle: "\(favorites.favorites.count) saved stations")
                        if favorites.favorites.count > 1 || isReordering {
                            Button { isReordering.toggle() } label: {
                                Text(isReordering ? "Done" : "Arrange").font(.radio(.subheadline, .medium))
                                    .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                            }
                            .accessibilityIdentifier("favorites.reorder")
                        }
                    }
                    if favorites.favorites.isEmpty {
                        EmptyStateView(title: "No favorites yet", message: "Tap the star on any station to keep it here.", systemImage: "star")
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 28),
                                                 count: typeSize.isAccessibilitySize ? 1 : 2),
                                  alignment: .leading, spacing: 28) {
                            ForEach(favorites.favorites.enumerated().map { IndexedFavorite(index: $0.offset, entry: $0.element) }) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    StationRow(station: item.entry.station, playbackQueue: stations, preset: true, position: item.index + 1)
                                    if isReordering {
                                        ReorderButtons(name: item.entry.station.name,
                                            canMoveUp: item.index > 0, canMoveDown: item.index < favorites.favorites.count - 1,
                                            moveUp: { favorites.move(id: item.entry.id, by: -1) },
                                            moveDown: { favorites.move(id: item.entry.id, by: 1) })
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 28)
            }
            .toolbar(.hidden, for: .navigationBar)
            .background(AetherTheme.canvas.ignoresSafeArea())
        }
    }
}

private struct IndexedFavorite: Identifiable {
    let index: Int
    let entry: FavoritesStore.Entry
    var id: String { entry.id }
}
