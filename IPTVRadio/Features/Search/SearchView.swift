import SwiftUI

/// Search across station names, genres, categories and metadata.
struct SearchView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var manualStations: ManualStationStore

    var body: some View {
        NavigationStack {
            ZStack {
                AetherTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    RadioPageHeading(title: "Find your\nfrequency.", subtitle: "A station, a genre, a familiar voice.", eyebrow: "AETHER / SEARCH")
                        .padding(.horizontal, 20)
                    searchField
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    Group {
                        if library.state == .loaded || !manualStations.entries.isEmpty {
                            searchContent
                        } else {
                            LibraryStateView(state: library.state) {
                                Task { await library.refresh() }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .background(AetherTheme.background.ignoresSafeArea())
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AetherTheme.accent)
            TextField("", text: $library.searchQuery,
                      prompt: Text("Station, genre, show or category")
                        .foregroundStyle(AetherTheme.mutedIcon))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .foregroundStyle(AetherTheme.primaryText)
                .accessibilityIdentifier("search.field")
                .font(.radio(.body))
            if !library.searchQuery.isEmpty {
                Button {
                    library.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AetherTheme.mutedIcon)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .font(.radio(.body))
        .padding(.horizontal, 16)
        .frame(minHeight: 54)
        .background(AetherTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AetherTheme.divider, lineWidth: 1))
    }

    @ViewBuilder
    private var searchContent: some View {
        let query = library.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.count < 2 {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    AetherSectionLabel(title: "A place to start")
                    ForEach(["Rock", "Jazz", "News", "Country", "Talk"], id: \.self) { term in
                        Button {
                            library.searchQuery = term
                        } label: {
                            HStack {
                                Text(term).font(.radio(.title3, .bold))
                                Spacer()
                                Image(systemName: "arrow.up.left").font(.radio(14, .medium))
                                    .foregroundStyle(AetherTheme.accent)
                            }
                            .foregroundStyle(AetherTheme.primaryText)
                            .frame(minHeight: 48)
                            .overlay(alignment: .bottom) { AetherTheme.divider.frame(height: 0.5) }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("search.suggestion.\(term.lowercased())")
                    }
                    Text("Search your provider's stations and the stations you've saved. Enter at least two characters.")
                        .font(.radio(.footnote)).foregroundStyle(AetherTheme.secondaryText)
                        .padding(.top, 12)
                }
                .padding(.horizontal, AetherTheme.margin)
            }
        } else {
            let manualResults = manualStations.entries.lazy.map(\.station).filter {
                $0.name.lowercased().contains(query) || $0.groupTitle.lowercased().contains(query)
            }
            let results = (library.state == .loaded ? library.searchResults() : []) + Array(manualResults)
            if results.isEmpty {
                EmptyStateView(
                    title: "No matches",
                    message: "Nothing matched \"\(library.searchQuery)\".",
                    systemImage: "questionmark.circle"
                )
            } else {
                List {
                    ForEach(results) { station in
                        StationRow(station: station)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}
