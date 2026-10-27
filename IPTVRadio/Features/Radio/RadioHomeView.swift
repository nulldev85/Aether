import SwiftUI

/// Home tab prioritizing SiriusXM-labelled stations.
struct RadioHomeView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        NavigationStack {
            Group {
                if library.state == .loaded {
                    stationList
                } else {
                    LibraryStateView(state: library.state) {
                        Task { await library.refresh() }
                    }
                }
            }
            .navigationTitle("SXM")
            .navigationBarTitleDisplayMode(.inline)
            .background(AetherTheme.background.ignoresSafeArea())
            .refreshable {
                await library.refresh()
            }
            .toolbar {
                if !library.siriusStations.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            AllStationsView(title: "SiriusXM Stations", stations: library.siriusStations)
                        } label: {
                            Text("All \(library.siriusStations.count)")
                                .font(.radio(.subheadline, .semibold))
                        }
                        .accessibilityIdentifier("radio.seeAll")
                    }
                }
            }
        }
    }

    private var stationList: some View {
        let stations = library.siriusStations
        if stations.isEmpty {
            return AnyView(
                EmptyStateView(
                    title: "No SiriusXM-labelled stations",
                    message: settings.siriusOnly
                        ? "SiriusXM-only filtering is on. Turn it off in Settings to see all detected radio stations."
                        : "No stations matched the SiriusXM rules. Adjust the keywords in Settings if your provider labels them differently.",
                    systemImage: "antenna.radiowaves.left.and.right"
                )
            )
        }
        return AnyView(
            List {
                RadioPageHeading(title: "SiriusXM", subtitle: "Your world of sound, on the dial.", eyebrow: "AETHER / THE LINEUP")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                AetherSectionLabel(title: "Channel directory", detail: "\(stations.count) stations")
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                ForEach(stations) { station in
                    StationRow(station: station)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        )
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
    }
}
