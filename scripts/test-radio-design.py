"""Minimal Graphite design and preserved-behavior checks; no live repository needed."""
import hashlib
import json
from pathlib import Path
import re
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = json.loads((ROOT / "docs/graphite-style-reference.json").read_text(encoding="utf-8"))


def luminance(value):
    channels = [(value >> shift & 255) / 255 for shift in (16, 8, 0)]
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return sum(c * weight for c, weight in zip(linear, (0.2126, 0.7152, 0.0722)))


def contrast(first, second):
    lo, hi = sorted((luminance(first), luminance(second)))
    return (hi + 0.05) / (lo + 0.05)


def source(relative):
    return (ROOT / relative).read_text(encoding="utf-8")


def icon_geometry_digest(text):
    # Freeze the original drawing source, allowing only six-digit color edits.
    # ast.dump is a debugging format whose empty-field output varies by Python
    # version. Source hashing also keeps every coordinate and render option.
    normalized = text.replace("\r\n", "\n")
    normalized = re.sub(r'''(['"])#[0-9A-Fa-f]{6}\1''', r'\1COLOR\1', normalized)
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


class RadioDesignTests(unittest.TestCase):
    def setUp(self):
        self.theme = source("IPTVRadio/App/AetherTheme.swift")

    def test_exact_graphite_palette_and_dimensions(self):
        self.assertIn(REFERENCE["name"], self.theme)
        for name, color in REFERENCE["palette"].items():
            with self.subTest(color=name):
                self.assertRegex(self.theme, rf"static let {name} = (?:Color\(uiColor: )?rgb\(0x{color}\)")
        for name in ("panelRadius", "compactRadius", "panelInset", "panelGap", "sideMargin", "utilityTarget", "minimumTarget"):
            self.assertRegex(self.theme, rf"static let {name}: CGFloat = {REFERENCE[name]}\b")

    def test_entire_app_uses_one_dark_rounded_theme(self):
        app = source("IPTVRadio/IPTVRadioApp.swift")
        self.assertIn(".preferredColorScheme(.dark)", app)
        self.assertIn(".fontDesign(.rounded)", app)
        self.assertIn(".environment(\\.font, .radio(.body))", app)
        self.assertIn("design: .rounded", self.theme)
        self.assertNotIn("adaptive(", self.theme)
        self.assertNotIn("LinearGradient(", self.theme)
        self.assertFalse((ROOT / "IPTVRadio/App/AetherInterface.swift").exists())
        for path in (ROOT / "IPTVRadio/Features").rglob("*.swift"):
            text = path.read_text(encoding="utf-8")
            self.assertNotIn("AetherInterface.", text)
            self.assertNotIn("design: .serif", text)

    def test_body_and_quiet_text_have_readable_contrast_on_all_graphite_surfaces(self):
        for background in (0x101113, 0x181A1D, 0x1D2024, 0x292D33):
            for foreground in (0xC7CBD1, 0xA2AAB5, 0xAEB6C1, 0x959DA8, 0xB28D92, 0xA69A88):
                with self.subTest(background=background, foreground=foreground):
                    self.assertGreaterEqual(contrast(foreground, background), 4.5)

    def test_station_logos_have_no_app_added_tiles(self):
        rows = source("IPTVRadio/Features/Components/StationRow.swift")
        for logo in rows.split("StationArtwork(logoURL: displayedStation.logoURL")[1:]:
            modifiers = logo.split("stationText", 1)[0]
            self.assertNotIn(".background(", modifiers)
            self.assertNotIn(".overlay(", modifiers)
        artwork = rows.split("struct StationArtwork: View", 1)[1].split("struct PlaybackArtwork:", 1)[0]
        self.assertNotIn(".background(", artwork)
        self.assertNotIn(".fill(", artwork)
        self.assertIn(".aspectRatio(contentMode: .fit)", artwork)
        self.assertIn("return LogoBackgroundKeyer.keyed(image)", rows)
        dial = source("IPTVRadio/Features/Radio/AetherDialView.swift")
        logo = dial.split("StationArtwork(logoURL: station.logoURL", 1)[1].split("VStack(alignment:", 1)[0]
        self.assertNotIn(".background(", logo)

    def test_settings_control_labels_and_values_choose_rounded_fonts_explicitly(self):
        components = source("IPTVRadio/App/AetherComponents.swift")
        toggle = components.split("struct AetherSettingToggle:", 1)[1].split("struct AetherLabeledValue:", 1)[0]
        self.assertIn("Toggle(isOn: $isOn)", toggle)
        self.assertIn("Text(title).font(.radio(textStyle, .medium))", toggle)
        value = components.split("struct AetherLabeledValue:", 1)[1].split("struct AetherFormSection<", 1)[0]
        self.assertIn("Text(title).font(.radio(textStyle, .medium))", value)
        self.assertIn("Text(value).font(.radio(textStyle))", value)
        self.assertIn("Text(title).font(.radio(.footnote, .semibold))", components)
        for path in (ROOT / "IPTVRadio/Features/Settings").glob("*.swift"):
            text = path.read_text(encoding="utf-8")
            with self.subTest(file=path.name):
                # Native title-only constructors used to rely on root inheritance.
                self.assertNotRegex(text, r'(?<![A-Za-z])Toggle\("')
                self.assertNotRegex(text, r'LabeledContent\(\s*"')
                self.assertNotRegex(text, r'\bSection\(\s*"')
        settings = source("IPTVRadio/Features/Settings/SettingsView.swift")
        self.assertEqual(settings.count("AetherSettingToggle("), 8)
        self.assertIn("Text(title).font(.radio(.body, .medium))", settings)

    def test_app_owned_text_inputs_do_not_rely_on_root_font_inheritance(self):
        count = 0
        for path in (ROOT / "IPTVRadio/Features").rglob("*.swift"):
            lines = path.read_text(encoding="utf-8").splitlines()
            for index, line in enumerate(lines):
                if not re.search(r"\b(?:TextField|SecureField|TextEditor)\(", line):
                    continue
                count += 1
                # Include multiline prompts and their immediate modifier chain.
                modifiers = "\n".join(lines[index:index + 10])
                with self.subTest(file=path.name, line=index + 1):
                    self.assertRegex(modifiers, r"\.font\(\.radio\(|\.radioField\(\)")
        self.assertGreaterEqual(count, 15)

    def test_neutral_labels_and_dim_button_fills_have_text_contrast(self):
        for background in (0x101113, 0x181A1D, 0x1D2024, 0x292D33):
            self.assertGreaterEqual(contrast(0x9CA5B1, background), 4.5)
        self.assertIn("static let onAccent = primaryText", self.theme)
        self.assertGreaterEqual(contrast(0xC7CBD1, 0x292D33), 7)

    def test_ui_is_dim_neutral_and_has_no_tuner_or_bright_control_fills(self):
        for name, value in REFERENCE["palette"].items():
            channels = [int(value[index:index + 2], 16) for index in (0, 2, 4)]
            with self.subTest(color=name):
                self.assertLessEqual(max(channels), 215)
                self.assertLessEqual(max(channels) - min(channels), 24)
        components = source("IPTVRadio/App/AetherComponents.swift")
        self.assertNotIn("AetherTuningRule", components)
        self.assertNotIn("eyebrow", components)
        self.assertNotIn(".tracking(", components)
        self.assertIn("prominent ? AetherTheme.selected : Color.clear", components)
        for path in (ROOT / "IPTVRadio/Features").rglob("*.swift"):
            text = path.read_text(encoding="utf-8")
            self.assertNotIn("AetherTuningRule", text)
            self.assertNotRegex(text, r"\.background\([^{}\n]*AetherTheme\.accent\b")

    def test_requested_rounded_font_implementation_is_preserved_exactly(self):
        font = self.theme.split("extension Font", 1)[1].split("enum AetherNavigationLayout", 1)[0]
        self.assertEqual(hashlib.sha256(font.encode()).hexdigest(), REFERENCE["preservedFontDigest"])

    def test_original_vinyl_renderer_and_pause_motion_guards_are_preserved(self):
        disc = source("IPTVRadio/Features/NowPlaying/VinylRecordView.swift")
        self.assertEqual(hashlib.sha256(disc.encode()).hexdigest(),
                         "29e632406d2372b4ade4a9ff63114ce994604378272df11d6350a5f626b15329")
        for relative in ("MiniPlayerView.swift", "NowPlayingView.swift"):
            player = source("IPTVRadio/Features/NowPlaying/" + relative)
            self.assertIn("VinylRecordView(", player)
            self.assertIn("playback.state.isPlaying && scenePhase == .active && !reduceMotion", player)

    def test_playback_engine_and_car_call_repair_are_unchanged(self):
        aggregate = ""
        for path in sorted((ROOT / "IPTVRadio/Playback").rglob("*.swift")):
            aggregate += path.relative_to(ROOT).as_posix() + "\0" + path.read_text(encoding="utf-8") + "\0"
        self.assertEqual(hashlib.sha256(aggregate.encode()).hexdigest(), REFERENCE["preservedPlaybackDigest"])

    def test_full_player_docks_a_slim_card_separately_from_scrollable_record_content(self):
        player = source("IPTVRadio/Features/NowPlaying/NowPlayingView.swift")
        body = player.split("private func recordContent", 1)[0]
        self.assertIn(".safeAreaInset(edge: .bottom, spacing: 0)", body)
        self.assertIn("controlCard", body)
        self.assertNotIn("ScrollView", body)
        content = player.split("private func recordContent", 1)[1].split("private var controlCard:", 1)[0]
        self.assertIn("ViewThatFits(in: .vertical)", content)
        self.assertIn("ScrollView", content)
        self.assertIn('accessibilityIdentifier("nowplaying.detailsScroll")', content)
        self.assertNotIn("controlCard", content)
        self.assertIn(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)", content)
        for name, value in (("transportButtonSize", 64), ("skipButtonSize", 48),
                            ("controlRowGap", 8), ("controlVerticalPadding", 12)):
            self.assertRegex(player, rf"static let {name}: CGFloat = {value}\b")
        self.assertNotIn(".ignoresSafeArea", body.split(".safeAreaInset", 1)[1].split(".foregroundStyle", 1)[0])

    def test_icon_geometry_is_preserved_and_colors_match_graphite(self):
        icon_source = source("scripts/generate-aether-icon.py")
        # Frozen from the original merged drawing at f403d74, not the failed
        # runner's output. The current source matches after masking colors.
        self.assertEqual(icon_geometry_digest(icon_source),
                         "3dd3fa134d18d4bedb4366d1abf846492f55fb8155a54eb3faba252495fd88b8")
        self.assertIn('SPINDLE = "#9CA5B1"', icon_source)
        self.assertIn('FOREST = "#101113"', icon_source)
        data = (ROOT / "IPTVRadio/Assets.xcassets/AppIcon.appiconset/AppIcon.png").read_bytes()
        width, height, depth, mode = struct.unpack(">IIBB", data[16:26])
        self.assertEqual((width, height, depth, mode), (1024, 1024, 8, 2))

    def test_icon_fingerprint_allows_recoloring_but_rejects_drawing_changes(self):
        original = source("scripts/generate-aether-icon.py")
        expected = icon_geometry_digest(original)
        self.assertEqual(icon_geometry_digest(original.replace("\n", "\r\n")), expected)
        self.assertEqual(icon_geometry_digest(original.replace('"#9CA5B1"', '"#123456"')), expected)
        for before, after in (("SIDE = 1024", "SIDE = 1023"),
                              ("(256, 270, 734, 748)", "(255, 270, 734, 748)"),
                              ("radius=px(39)", "radius=px(38)")):
            with self.subTest(change=before):
                self.assertIn(before, original)
                self.assertNotEqual(icon_geometry_digest(original.replace(before, after, 1)), expected)

    def test_workspace_navigation_and_player_have_separate_layout_owners(self):
        navigation = source("IPTVRadio/Features/Root/MainTabView.swift")
        self.assertEqual(navigation.count("TabView(selection:"), 1)
        self.assertIn('accessibilityIdentifier("aether.navigation.header")', navigation)
        self.assertIn("workspaceHeader\n            TabView", navigation)
        self.assertEqual(navigation.count(".safeAreaInset(edge: .bottom, spacing: 0)"), 1)
        self.assertIn("MiniPlayerView(onOpen:", navigation)
        for old in ("AetherTabBar", "reservedHeight(", "GeometryReader", "nativeNavigation"):
            self.assertNotIn(old, navigation)
        self.assertNotIn(".overlay(alignment: .bottom)", navigation.split("private var workspaceHeader:", 1)[0])
        self.assertIn("settings.liquidGlassEnabled", navigation)
        mini = source("IPTVRadio/Features/NowPlaying/MiniPlayerView.swift")
        self.assertIn('accessibilityIdentifier("aether.playback.shelf")', mini)
        self.assertNotIn("RoundedRectangle(", mini)
        self.assertNotIn(".padding(.horizontal, AetherTheme.margin)", mini)

    def test_presets_settings_pages_and_unboxed_controls_replace_the_old_structure(self):
        for path in ("Radio/ManualRadioView.swift", "Favorites/FavoritesTabView.swift"):
            text = source("IPTVRadio/Features/" + path)
            self.assertIn("LazyVGrid(", text)
            self.assertIn("preset: true", text)
            self.assertIn("typeSize.isAccessibilitySize ? 1 : 2", text)
        settings = source("IPTVRadio/Features/Settings/SettingsView.swift")
        self.assertIn("categoryPage(category)", settings)
        self.assertNotIn("categoryBar", settings)
        self.assertNotIn("selectedCategory", settings)
        self.assertNotIn(".background(AetherTheme.surface, in:", settings)
        player = source("IPTVRadio/Features/NowPlaying/NowPlayingView.swift")
        controls = player.split("private var controlCard:", 1)[1].split("private var header:", 1)[0]
        self.assertNotIn(".background(", controls)
        self.assertIn(".multilineTextAlignment(.leading)", player)
        # Controls keep minimum-sized interactive label rectangles, not just
        # a small glyph inside a frame invisible to hit testing/accessibility.
        self.assertEqual(player.count(".frame(width: NowPlayingLayout.skipButtonSize, height: NowPlayingLayout.skipButtonSize)\n                    .contentShape(Rectangle())"), 2)
        self.assertIn(".frame(width: 44, height: 44).contentShape(Rectangle())", player)
        rows = source("IPTVRadio/Features/Components/StationRow.swift")
        self.assertIn("private var favoriteButton:", rows)
        play_label = rows.split("Button(action: play)", 1)[1].split('.buttonStyle(.plain)', 1)[0]
        self.assertNotIn("Button {", play_label)

    def test_system_accent_asset_matches_the_shared_gray(self):
        asset = json.loads(source("IPTVRadio/Assets.xcassets/AccentColor.colorset/Contents.json"))
        for item in asset["colors"]:
            components = item["color"]["components"]
            self.assertAlmostEqual(float(components["red"]), 0x9C / 255, places=5)
            self.assertAlmostEqual(float(components["green"]), 0xA5 / 255, places=5)
            self.assertAlmostEqual(float(components["blue"]), 0xB1 / 255, places=5)

    def test_every_destination_has_the_new_identity_without_dropping_features(self):
        components = source("IPTVRadio/App/AetherComponents.swift")
        self.assertIn(".font(.radio(.title, .heavy))", components)
        settings = source("IPTVRadio/Features/Settings/SettingsView.swift")
        self.assertIn('value: "Dark"', settings)
        self.assertNotIn('value: "Lineup"', settings)
        for control in ("cellular", "siriusOnly", "liquidGlass", "streamDiagnostics", "signOut"):
            self.assertIn(f'"settings.{control}"', settings)
        search = source("IPTVRadio/Features/Search/SearchView.swift")
        self.assertIn("library.searchQuery = term", search)
        self.assertIn("library.searchResults()", search)
        self.assertIn(".searchQuery = \"\"", search)
        manual = source("IPTVRadio/Features/Radio/ManualRadioView.swift")
        self.assertIn("ScrollView {", manual)
        self.assertIn("emptyStationContent", manual)
        for path in ("Auth/LoginView.swift", "Radio/ManualRadioView.swift", "Radio/RadioHomeView.swift",
                     "Favorites/FavoritesTabView.swift", "Search/SearchView.swift", "Radio/AetherDialView.swift"):
            self.assertIn("RadioPageHeading(", source("IPTVRadio/Features/" + path))
            self.assertNotIn("eyebrow:", source("IPTVRadio/Features/" + path))

    def test_release_notes_are_human_readable_and_published_with_source_metadata(self):
        notes = source("RELEASE_NOTES.md")
        self.assertTrue(notes.startswith("## What's new\n"))
        self.assertGreaterEqual(len(re.findall(r"^- ", notes, re.M)), 4)
        self.assertNotRegex(notes, r"(?i)TODO|TBD|XCTAssert|SwiftCompile|exit code")
        workflow = source(".github/workflows/ios.yml")
        self.assertIn('Path("RELEASE_NOTES.md").read_text', workflow)
        self.assertIn('notes.write("\\n" + whats_new + "\\n")', workflow)


if __name__ == "__main__":
    unittest.main()
