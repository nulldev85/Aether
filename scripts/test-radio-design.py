"""Lineup-reference checks for Aether's app-wide restyle; no live repository needed."""
import ast
import hashlib
import json
from pathlib import Path
import re
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = json.loads((ROOT / "docs/lineup-style-reference.json").read_text(encoding="utf-8"))


def luminance(value):
    channels = [(value >> shift & 255) / 255 for shift in (16, 8, 0)]
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return sum(c * weight for c, weight in zip(linear, (0.2126, 0.7152, 0.0722)))


def contrast(first, second):
    lo, hi = sorted((luminance(first), luminance(second)))
    return (hi + 0.05) / (lo + 0.05)


def source(relative):
    return (ROOT / relative).read_text(encoding="utf-8")


class RadioDesignTests(unittest.TestCase):
    def setUp(self):
        self.theme = source("IPTVRadio/App/AetherTheme.swift")

    def test_exact_lineup_palette_and_dimensions(self):
        self.assertIn(REFERENCE["commit"], self.theme)
        for name, color in REFERENCE["palette"].items():
            with self.subTest(color=name):
                self.assertRegex(self.theme, rf"static let {name} = (?:Color\(uiColor: )?rgb\(0x{color}\)")
        for name in ("panelRadius", "compactRadius", "panelInset", "panelGap", "sideMargin", "padding", "itemHeight"):
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

    def test_body_and_quiet_text_have_readable_contrast_on_lineup_panels(self):
        for background in (0x1C1C1E, 0x2C2C2E):
            for foreground in (0xFFFFFF, 0xCCCCCC, 0x9E9EA5):
                with self.subTest(background=background, foreground=foreground):
                    self.assertGreaterEqual(contrast(foreground, background), 4.5)

    def test_station_logos_have_no_app_added_tiles(self):
        rows = source("IPTVRadio/Features/Components/StationRow.swift")
        # Check the modifiers on the logo, not the enclosing station card.
        logo = rows.split("StationArtwork(logoURL: displayedStation.logoURL", 1)[1]
        logo = logo.split("VStack(alignment:", 1)[0]
        self.assertIn(".frame(width: 64, height: 64)", logo)
        self.assertNotIn(".background(", logo)
        self.assertNotIn(".overlay(", logo)
        artwork = rows.split("struct StationArtwork: View", 1)[1].split("struct PlaybackArtwork:", 1)[0]
        self.assertNotIn(".background(", artwork)
        self.assertNotIn(".fill(", artwork)
        self.assertIn(".aspectRatio(contentMode: .fit)", artwork)
        # Keep existing provider-background removal and image caching intact.
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

    def test_reference_accent_has_nontext_control_contrast(self):
        # Exact Lineup broadcast red, not an invented replacement. This check
        # does not claim every small white-on-red label meets body-text AA.
        self.assertGreaterEqual(contrast(0xFF3347, 0x1C1C1E), 3)
        self.assertGreaterEqual(contrast(0xFFFFFF, 0xFF3347), 3)

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

    def test_icon_geometry_is_preserved_and_colors_match_lineup(self):
        icon_source = source("scripts/generate-aether-icon.py")
        tree = ast.parse(icon_source)
        for node in ast.walk(tree):
            if isinstance(node, ast.Constant) and isinstance(node.value, str) and re.fullmatch(r"#[0-9A-Fa-f]{6}", node.value):
                node.value = "COLOR"
        self.assertEqual(hashlib.sha256(ast.dump(tree, include_attributes=False).encode()).hexdigest(),
                         "a6f531875b98f7d03bf91d6703cbddf17898f007ceed1a59f3619aacda6d22f9")
        self.assertIn('SPINDLE = "#FF3347"', icon_source)
        self.assertIn('FOREST = "#1C1C1E"', icon_source)
        data = (ROOT / "IPTVRadio/Assets.xcassets/AppIcon.appiconset/AppIcon.png").read_bytes()
        width, height, depth, mode = struct.unpack(">IIBB", data[16:26])
        self.assertEqual((width, height, depth, mode), (1024, 1024, 8, 2))

    def test_navigation_uses_lineup_capsule_and_one_clearance_owner(self):
        navigation = source("IPTVRadio/Features/Root/MainTabView.swift")
        self.assertIn("AetherNavigationLayout.reservedHeight(", navigation)
        self.assertIn('accessibilityIdentifier("aether.navigation.custom")', navigation)
        self.assertIn("AetherTheme.selected : .clear, in: Capsule()", navigation)
        self.assertIn(".tint(.white)", navigation)
        self.assertNotIn("flatControlsClearance", source("IPTVRadio/Features/Settings/SettingsView.swift"))
        self.assertNotIn(".frame(height: 61 +", source("IPTVRadio/Features/Favorites/FavoritesTabView.swift"))

    def test_system_accent_asset_matches_the_shared_red(self):
        asset = json.loads(source("IPTVRadio/Assets.xcassets/AccentColor.colorset/Contents.json"))
        for item in asset["colors"]:
            components = item["color"]["components"]
            self.assertAlmostEqual(float(components["red"]), 1, places=5)
            self.assertAlmostEqual(float(components["green"]), 0x33 / 255, places=5)
            self.assertAlmostEqual(float(components["blue"]), 0x47 / 255, places=5)


if __name__ == "__main__":
    unittest.main()
