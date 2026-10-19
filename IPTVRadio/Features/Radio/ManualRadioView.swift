import SwiftUI

/// Personal stations entered by the listener, separate from the IPTV lineup.
struct ManualRadioView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var manualStations: ManualStationStore

    @State private var editor: EditorTarget?
    @State private var showDial = false
    @State private var errorMessage: String?
    @State private var isReordering = false

    private struct EditorTarget: Identifiable {
        let id: String
        let entry: ManualStationEntry?

        init(entry: ManualStationEntry? = nil) {
            self.entry = entry
            id = entry?.id ?? "new"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if manualStations.entries.isEmpty {
                    emptyState
                } else {
                    List {
                        RadioPageHeading(title: "Radio", subtitle: "\(manualStations.entries.count) stations. In your order.")
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        ForEach(manualStations.entries.enumerated().map { IndexedManualStation(index: $0.offset, entry: $0.element) }) { item in
                            let entry = item.entry
                            HStack(spacing: 4) {
                                StationRow(station: entry.station)
                                if isReordering {
                                    ReorderButtons(
                                        name: entry.name,
                                        canMoveUp: item.index > 0,
                                        canMoveDown: item.index < manualStations.entries.count - 1,
                                        moveUp: { manualStations.move(id: entry.id, by: -1) },
                                        moveDown: { manualStations.move(id: entry.id, by: 1) }
                                    )
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) { delete(entry) }
                                    .font(.radio(.body, .medium))
                                Button("Edit") { editor = EditorTarget(entry: entry) }
                                    .font(.radio(.body, .medium))
                                    .tint(AetherTheme.accent)
                            }
                            .contextMenu {
                                Button {
                                    editor = EditorTarget(entry: entry)
                                } label: {
                                    Label("Edit Station", systemImage: "pencil")
                                        .font(.radio(.body, .medium))
                                }
                                Button(role: .destructive) {
                                    delete(entry)
                                } label: {
                                    Label("Delete Station", systemImage: "trash")
                                        .font(.radio(.body, .medium))
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Radio")
            .navigationBarTitleDisplayMode(.inline)
            .background(AetherTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showDial = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "safari")
                            Text("Dial").font(.radio(.subheadline, .semibold))
                        }
                        .font(.radio(.subheadline, .semibold))
                    }
                    .accessibilityLabel("Aether Dial")
                    .accessibilityIdentifier("manual.dial")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        if manualStations.entries.count > 1 || isReordering {
                            Button {
                                isReordering.toggle()
                            } label: {
                                if isReordering {
                                    Text("Done").font(.radio(.body, .semibold))
                                } else {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .foregroundStyle(AetherTheme.mutedIcon)
                                }
                            }
                            .accessibilityLabel(isReordering ? "Done reordering" : "Reorder stations")
                            .accessibilityIdentifier("manual.reorder")
                        }
                        Button {
                            editor = EditorTarget()
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(AetherTheme.mutedIcon)
                        }
                        .accessibilityLabel("Add station")
                        .accessibilityIdentifier("manual.add")
                    }
                }
            }
            .sheet(item: $editor) { target in
                ManualStationEditorView(entry: target.entry)
                    .environmentObject(environment)
                    .environmentObject(manualStations)
            }
            .sheet(isPresented: $showDial) {
                AetherDialView()
                    .environmentObject(environment)
                    .environmentObject(manualStations)
                    .environmentObject(environment.playback)
            }
            .alert("Couldn't update Radio", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            RadioPageHeading(title: "Radio", subtitle: "A place for your own stations.")
            AetherIconTile(symbol: "antenna.radiowaves.left.and.right", size: 64)
            Text("Your Radio stations")
                .font(.radio(20, .bold))
            Text("Add a stream link or find a station in Aether Dial. MP3, AAC, HLS, M3U and PLS links are supported.")
                .font(.radio(.subheadline))
                .foregroundStyle(AetherTheme.secondaryText)
                .multilineTextAlignment(.leading)
            Button {
                editor = EditorTarget()
            } label: {
                Label("Add Station", systemImage: "plus")
                    .font(.radio(.headline))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(AetherButtonStyle(prominent: true))
            .tint(AetherTheme.accent)
            .accessibilityIdentifier("manual.addEmpty")
            .padding(.top, 8)
            Button {
                showDial = true
            } label: {
                Label("Explore Aether Dial", systemImage: "safari")
                    .font(.radio(.headline))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(AetherButtonStyle())
            .tint(AetherTheme.accent)
            .accessibilityIdentifier("manual.dialEmpty")
        }
        .padding(24)
        .frame(maxWidth: 420, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity)
    }

    private func delete(_ entry: ManualStationEntry) {
        do {
            try manualStations.remove(id: entry.id)
            environment.favorites.remove(entry.station)
        } catch {
            errorMessage = (error as? ManualStationError)?.errorDescription
                ?? "The station could not be removed. Try again."
        }
    }
}

private struct IndexedManualStation: Identifiable {
    let index: Int
    let entry: ManualStationEntry
    var id: String { entry.id }
}

private struct ManualStationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var manualStations: ManualStationStore

    let entry: ManualStationEntry?
    @State private var name: String
    @State private var streamURL: String
    @State private var logoURL: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(entry: ManualStationEntry?) {
        self.entry = entry
        _name = State(initialValue: entry?.name ?? "")
        _streamURL = State(initialValue: entry?.streamURL.absoluteString ?? "")
        _logoURL = State(initialValue: entry?.logoURL?.absoluteString ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Station name", text: $name)
                        .font(.radio(.body))
                        .textContentType(.name)
                        .accessibilityIdentifier("manual.name")
                    TextField("Stream URL", text: $streamURL)
                        .font(.radio(.body))
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("manual.url")
                } header: {
                    Text("Station")
                        .font(.radio(.footnote, .semibold))
                } footer: {
                    Text("Use a direct MP3, AAC, AAC+, Ogg, Opus, FLAC or HLS (.m3u8) link, or an M3U/PLS station playlist. HTTP and HTTPS are supported.")
                        .font(.radio(.footnote))
                }
                AetherFormSection("Optional") {
                    TextField("Logo URL", text: $logoURL)
                        .font(.radio(.body))
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("manual.artwork")
                    Text("We'll look for the station logo automatically. Paste a logo URL to choose your own.")
                        .font(.radio(.caption))
                        .foregroundStyle(AetherTheme.secondaryText)
                }
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle")
                            .font(.radio(.body))
                            .foregroundStyle(AetherTheme.destructive)
                            .accessibilityIdentifier("manual.error")
                    }
                }
            }
            .radioSettingsList()
            .navigationTitle(entry == nil ? "Add Station" : "Edit Station")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(AetherBarButtonStyle())
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .buttonStyle(AetherBarButtonStyle(prominent: true))
                        .fontWeight(.semibold)
                        .disabled(isSaving)
                        .accessibilityIdentifier("manual.save")
                }
            }
        }
        .tint(AetherTheme.accent)
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        let input = ManualStationInput(name: name, streamURL: streamURL, logoURL: logoURL)
        Task {
            defer { isSaving = false }
            do {
                let station = try await manualStations.save(
                    input,
                    editing: entry?.id,
                    httpClient: environment.httpClient
                )
                environment.favorites.replace(station)
                environment.history.replace(station)
                dismiss()
            } catch {
                errorMessage = (error as? ManualStationError)?.errorDescription
                    ?? "The station could not be saved. Try again."
            }
        }
    }
}
