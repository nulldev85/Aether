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

    @Environment(\.dynamicTypeSize) private var typeSize
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 28), count: typeSize.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        RadioPageHeading(title: "Your stations", subtitle: "Saved for everyday listening.")
                        Menu {
                            Button("Add station") { editor = EditorTarget() }
                                .accessibilityIdentifier("manual.add")
                            Button("Aether Dial") { showDial = true }
                                .accessibilityIdentifier("manual.dial")
                            if manualStations.entries.count > 1 || isReordering {
                                Button(isReordering ? "Done reordering" : "Reorder stations") { isReordering.toggle() }
                                    .accessibilityIdentifier("manual.reorder")
                            }
                        } label: {
                            Image(systemName: "plus").font(.radio(20, .medium))
                                .frame(width: 44, height: 44).contentShape(Rectangle())
                        }
                        .accessibilityLabel("Manage stations")
                        .accessibilityIdentifier("manual.manage")
                    }
                    if manualStations.entries.isEmpty {
                        emptyStationContent
                    } else {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                            ForEach(manualStations.entries.enumerated().map { IndexedManualStation(index: $0.offset, entry: $0.element) }) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    StationRow(station: item.entry.station, preset: true, position: item.index + 1)
                                    if isReordering {
                                        ReorderButtons(name: item.entry.name,
                                            canMoveUp: item.index > 0, canMoveDown: item.index < manualStations.entries.count - 1,
                                            moveUp: { manualStations.move(id: item.entry.id, by: -1) },
                                            moveDown: { manualStations.move(id: item.entry.id, by: 1) })
                                    }
                                    Menu {
                                        Button("Edit Station") { editor = EditorTarget(entry: item.entry) }
                                        Button("Delete Station", role: .destructive) { delete(item.entry) }
                                    } label: {
                                        HStack {
                                            Text("Manage").font(.radio(.caption, .medium))
                                            Spacer()
                                            Image(systemName: "ellipsis")
                                        }
                                        .foregroundStyle(AetherTheme.mutedIcon)
                                        .frame(minHeight: 44).contentShape(Rectangle())
                                    }
                                    .accessibilityLabel("Manage \(item.entry.name)")
                                    .accessibilityIdentifier("manual.manage.\(item.entry.name)")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 28)
            }
            .background(AetherTheme.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editor) { target in
                ManualStationEditorView(entry: target.entry)
                    .environmentObject(environment).environmentObject(manualStations)
            }
            .sheet(isPresented: $showDial) {
                AetherDialView().environmentObject(environment)
                    .environmentObject(manualStations).environmentObject(environment.playback)
            }
            .alert("Couldn't update Radio", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) { Button("OK", role: .cancel) { errorMessage = nil } }
            message: { Text(errorMessage ?? "") }
        }
    }

    private var emptyStationContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your Radio stations")
                .font(.radio(.headline, .bold))
            Text("Start with a station you know, or discover one in Aether Dial.")
                .font(.radio(.subheadline))
                .foregroundStyle(AetherTheme.secondaryText)
                .multilineTextAlignment(.leading)
            Button {
                editor = EditorTarget()
            } label: {
                Label("Add Station", systemImage: "plus").font(.radio(.headline))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(AetherButtonStyle(prominent: true))
            .tint(AetherTheme.accent)
            .accessibilityIdentifier("manual.addEmpty")
            .padding(.top, 8)
            Button {
                showDial = true
            } label: {
                Label("Explore Aether Dial", systemImage: "safari").font(.radio(.headline))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(AetherButtonStyle())
            .tint(AetherTheme.accent)
            .accessibilityIdentifier("manual.dialEmpty")
        }
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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    RadioPageHeading(title: "Station details", subtitle: "A name and a stream link are all you need.")
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Station name", text: $name)
                            .radioField().textContentType(.name)
                            .accessibilityIdentifier("manual.name")
                        TextField("Stream URL", text: $streamURL)
                            .radioField().keyboardType(.URL)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .accessibilityIdentifier("manual.url")
                    }
                    Text("Direct MP3, AAC, Ogg, Opus, FLAC and HLS streams, or an M3U/PLS playlist. HTTP and HTTPS are supported.")
                        .font(.radio(.footnote)).foregroundStyle(AetherTheme.secondaryText)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Artwork").font(.radio(.subheadline, .semibold))
                        TextField("Logo URL (optional)", text: $logoURL)
                            .radioField().keyboardType(.URL)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .accessibilityIdentifier("manual.artwork")
                        Text("Leave this empty to look for the station logo automatically.")
                            .font(.radio(.footnote)).foregroundStyle(AetherTheme.secondaryText)
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle")
                            .font(.radio(.body)).foregroundStyle(AetherTheme.destructive)
                            .accessibilityIdentifier("manual.error")
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 28)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AetherTheme.canvas.ignoresSafeArea())
            .navigationTitle(entry == nil ? "Add Station" : "Edit Station")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.buttonStyle(AetherBarButtonStyle()).disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.buttonStyle(AetherBarButtonStyle(prominent: true))
                        .disabled(isSaving).accessibilityIdentifier("manual.save")
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
