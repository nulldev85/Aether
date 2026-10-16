import importlib.util
import plistlib
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("aether_build", Path(__file__).with_name("check-aether-build.py"))
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


class BundleChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.app = Path(self.temp.name) / "Radio.app"
        self.app.mkdir()
        self.info = {"CFBundleSupportedPlatforms": ["iPhoneOS"], "CFBundleExecutable": "Radio", "MinimumOSVersion": "18.0"}
        self.write_info()
        (self.app / "Radio").touch()
        for name in checker.FRAMEWORKS:
            framework = self.app / "Frameworks" / f"AetherLib{name}.framework"
            framework.mkdir(parents=True)
            (framework / f"AetherLib{name}").touch()
        resource = self.app / "AetherEngine_AetherEngine.bundle"
        resource.mkdir()
        (resource / "silent-atmos.mp4").touch()
        for name in checker.NOTICES:
            (self.app / f"PlaybackLicense-{name}.txt").touch()
        self.links = "@rpath/AetherLibavcodec.framework/AetherLibavcodec (compatibility version 1.0.0)"
        self.mock = patch.object(checker, "command", side_effect=lambda *args: "arm64" if args[0] == "lipo" else self.links)
        self.mock.start()
        self.addCleanup(self.mock.stop)

    def write_info(self):
        (self.app / "Info.plist").write_bytes(plistlib.dumps(self.info))

    def test_complete_device_payload_passes(self):
        checker.verify(self.app)

    def test_simulator_payload_is_rejected_even_when_arm64(self):
        self.info["CFBundleSupportedPlatforms"] = ["iPhoneSimulator"]
        self.write_info()
        with self.assertRaisesRegex(AssertionError, "Simulator bundle"):
            checker.verify(self.app)

    def test_missing_decoder_is_rejected(self):
        (self.app / "Frameworks/AetherLibavcodec.framework/AetherLibavcodec").unlink()
        with self.assertRaisesRegex(AssertionError, "not embedded"):
            checker.verify(self.app)

    def test_missing_runtime_dependency_is_rejected(self):
        self.links = "@rpath/Unembedded.framework/Unembedded (compatibility version 1.0.0)"
        with self.assertRaisesRegex(AssertionError, "Unresolved dynamic dependency"):
            checker.verify(self.app)

    def test_old_vlc_payload_is_rejected(self):
        (self.app / "Frameworks/MobileVLCKit.framework").mkdir()
        with self.assertRaisesRegex(AssertionError, "VLC must not remain"):
            checker.verify(self.app)

    def test_disabled_object_decoder_is_rejected(self):
        (self.app / "Frameworks/DTSX.framework").mkdir()
        with self.assertRaisesRegex(AssertionError, "Optional object-audio"):
            checker.verify(self.app)

    def test_missing_acknowledgement_is_rejected(self):
        (self.app / "PlaybackLicense-AetherEngine.txt").unlink()
        with self.assertRaisesRegex(AssertionError, "License not reachable"):
            checker.verify(self.app)


if __name__ == "__main__":
    unittest.main()
