"""Offline checks for the shell refresh's explicit preservation boundaries."""
import ast
import hashlib
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
FROZEN_PLAYER = {
    "IPTVRadio/App/AetherTheme.swift": "e2a2549eea31303d23648d424224893f11cb9cfd7b5510586a54e1124e080b7e",
    "IPTVRadio/Features/NowPlaying/MiniPlayerView.swift": "6dde5b0af0c9cf979bba9f8752dd247319ae79fb8603c9c61832d55cd696d1b5",
    "IPTVRadio/Features/NowPlaying/NowPlayingView.swift": "3243456e224eb3f1826da0cc18cb4798eaeff5e9cd8b695f9340ffe60b130a36",
    "IPTVRadio/Features/NowPlaying/VinylRecordView.swift": "29e632406d2372b4ade4a9ff63114ce994604378272df11d6350a5f626b15329",
    "IPTVRadio/Assets.xcassets/AccentColor.colorset/Contents.json": "81a6af3c3371414995da62113f5816aaeaac912c35f3e29c3e805bc794ed6db9",
}


def luminance(value):
    channels = [(value >> shift & 255) / 255 for shift in (16, 8, 0)]
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return sum(c * weight for c, weight in zip(linear, (0.2126, 0.7152, 0.0722)))


def contrast(first, second):
    lo, hi = sorted((luminance(first), luminance(second)))
    return (hi + 0.05) / (lo + 0.05)


class RadioDesignTests(unittest.TestCase):
    def setUp(self):
        self.theme = (ROOT / "IPTVRadio/App/AetherInterface.swift").read_text(encoding="utf-8")
        self.colors = {name: (int(light, 16), int(dark, 16)) for name, light, dark in re.findall(
            r"static let (\w+) = (?:Color\(uiColor: )?adaptive\(light: 0x([0-9A-F]+), dark: 0x([0-9A-F]+)", self.theme)}

    def test_player_views_palette_and_global_accent_are_unchanged(self):
        for relative, expected in FROZEN_PLAYER.items():
            with self.subTest(file=relative):
                actual = hashlib.sha256((ROOT / relative).read_text(encoding="utf-8").encode()).hexdigest()
                self.assertEqual(actual, expected, "User explicitly excluded now-playing from the redesign")

    def test_icon_changes_are_color_literals_only(self):
        tree = ast.parse((ROOT / "scripts/generate-aether-icon.py").read_text(encoding="utf-8"))
        for node in ast.walk(tree):
            if isinstance(node, ast.Constant) and isinstance(node.value, str) and re.fullmatch(r"#[0-9A-Fa-f]{6}", node.value):
                node.value = "COLOR"
        actual = hashlib.sha256(ast.dump(tree, include_attributes=False).encode()).hexdigest()
        self.assertEqual(actual, "a6f531875b98f7d03bf91d6703cbddf17898f007ceed1a59f3619aacda6d22f9")

    def test_body_text_and_controls_meet_contrast_in_both_appearances(self):
        for appearance in range(2):
            for foreground in ("uiPrimaryText", "secondaryText", "uiMutedIcon", "uiAccent"):
                for background in ("canvas", "surface", "uiNavigationSurface"):
                    with self.subTest(appearance=appearance, foreground=foreground, background=background):
                        self.assertGreaterEqual(contrast(self.colors[foreground][appearance], self.colors[background][appearance]), 4.5)

    def test_accent_button_labels_meet_contrast(self):
        for appearance in range(2):
            self.assertGreaterEqual(contrast(self.colors["onAccent"][appearance], self.colors["uiAccent"][appearance]), 4.5)

    def test_shell_background_is_flat_and_separate_from_player(self):
        self.assertIn("static let background = canvas", self.theme)
        self.assertNotIn("LinearGradient(", self.theme)
        self.assertNotIn("AetherTheme.", self.theme)

    def test_shared_playback_artwork_keeps_original_theme(self):
        source = (ROOT / "IPTVRadio/Features/Components/StationRow.swift").read_text(encoding="utf-8")
        artwork = source.split("/// A station's channel logo.", 1)[1]
        self.assertNotIn("AetherInterface.", artwork)
        self.assertIn("AetherTheme.logoShadow", artwork)

    def test_player_presentations_do_not_inherit_new_shell_tint(self):
        for relative in ("Root/MainTabView.swift", "Radio/AetherDialView.swift"):
            source = (ROOT / "IPTVRadio/Features" / relative).read_text(encoding="utf-8")
            for line, following in zip(source.splitlines(), source.splitlines()[1:]):
                if "MiniPlayerView(onOpen:" in line or "NowPlayingView()" in line:
                    self.assertEqual(following.strip(), ".tint(AetherTheme.accent)")


if __name__ == "__main__":
    unittest.main()
