import SwiftUI

/// Home tab prioritizing SiriusXM-labelled stations.
struct RadioHomeView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    RadioPageHeading(title: "SiriusXM", subtitle: "\(library.siriusStations.count) channels from your provider")
                    if !library.siriusStations.isEmpty {
                        NavigationLink {
                            AllStationsView(title: "SiriusXM Stations", stations: library.siriusStations)
                        } label: {
                            Image(systemName: "list.bullet").font(.radio(18))
                                .frame(width: 44, height: 44).contentShape(Rectangle())
                        }
                        .accessibilityLabel("All SiriusXM stations").accessibilityIdentifier("radio.seeAll")
                    }
                }
                .padding(.horizontal, 24)
                if library.state != .loaded {
                    LibraryStateView(state: library.state) { Task { await library.refresh() } }
                        .frame(maxHeight: .infinity, alignment: .top)
                } else if library.siriusStations.isEmpty {
                    EmptyStateView(title: "No SiriusXM-labelled stations",
                        message: settings.siriusOnly
                            ? "Turn off SiriusXM-only filtering in Settings to see other radio stations."
                            : "Adjust detection keywords in Settings if your provider labels stations differently.")
                        .frame(maxHeight: .infinity, alignment: .top)
                } else {
                    List(library.siriusStations) { StationRow(station: $0) }
                        .listStyle(.plain).scrollContentBackground(.hidden)
                        .refreshable { await library.refresh() }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .background(AetherTheme.canvas.ignoresSafeArea())
        }
    }
}

/// Flat list of any provided station collection.
struct AllStationsView: View {
    let title: String
    let stations: [RadioStation]

    var body: some View {
        List {
            AetherSectionLabel(title: "Channel directory", detail: "\(stations.count) stations")
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
            ForEach(stations) { station in
                StationRow(station: station)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AetherTheme.canvas)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}
