import SwiftUI

enum PlaybackLicenseFiles {
    static var entries: [(name: String, text: String)] {
        let urls = Bundle.main.urls(forResourcesWithExtension: "txt", subdirectory: nil) ?? []
        return urls.filter { $0.lastPathComponent.hasPrefix("PlaybackLicense-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                let name = url.deletingPathExtension().lastPathComponent
                    .replacingOccurrences(of: "PlaybackLicense-", with: "")
                return (name, text)
            }
    }
}

struct PlaybackLicensesView: View {
    private let entries = PlaybackLicenseFiles.entries

    var body: some View {
        List {
            Section {
                Text("AetherEngine 7.38.1 and its decoder libraries")
                    .font(.radio(.body))
                Link("AetherEngine source", destination: URL(string: "https://github.com/superuser404notfound/AetherEngine/tree/7.38.1")!)
                    .font(.radio(.body, .medium))
                Link("FFmpegBuild source", destination: URL(string: "https://github.com/superuser404notfound/FFmpegBuild/tree/3.7.1")!)
                    .font(.radio(.body, .medium))
                Link("LibDovi source", destination: URL(string: "https://github.com/superuser404notfound/LibDovi/tree/2.1.0")!)
                    .font(.radio(.body, .medium))
            }
            ForEach(entries, id: \.name) { entry in
                NavigationLink {
                    ScrollView {
                        Text(entry.text).font(.radio(.footnote)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading).padding()
                    }
                    .navigationTitle(entry.name)
                    .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Text(entry.name).font(.radio(.body, .medium))
                }
            }
        }
        .radioSettingsList()
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }
}
