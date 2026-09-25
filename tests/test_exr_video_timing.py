"""EXR video timing regressions using only Python's standard library.

Run: python3 -m unittest discover -s tests -p test_exr_video_timing.py -v
Requires oiiotool, GNU Parallel, ImageMagick, FFmpeg/ffprobe, and an OCIO
config containing ACES - ACEScg and Output - sRGB. All media is temporary.
"""

from fractions import Fraction
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
CONVERTERS = (
    ("exrtomp4.sh", ".mp4"),
    ("exrtomp4_dailies.sh", ".mp4"),
    ("exrtoprores422.sh", "_prores422.mov"),
    ("exrtoprores444.sh", "_prores444.mov"),
)
FRAME_COUNT = 12
TOOLS = ("oiiotool", "parallel", "identify", "ffmpeg", "ffprobe")


@unittest.skipUnless(all(shutil.which(tool) for tool in TOOLS),
                     "EXR video CLI tools required")
class ExrVideoTiming(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="exr-video-timing-")
        cls.addClassCleanup(cls.temp.cleanup)
        cls.work = Path(cls.temp.name)
        # Avoid unrelated exported interactive shell functions in parallel jobs.
        cls.env = {key: value for key, value in os.environ.items()
                   if not key.startswith("BASH_FUNC_")}
        cls.env["SHELL"] = "/bin/bash"
        cls.fixtures = {}
        for name, metadata in (
            ("24", ["--attrib:type=float", "FramesPerSecond", "24"]),
            ("48", ["--attrib:type=float", "FramesPerSecond", "48"]),
            ("missing", []),
            ("invalid", ["--sattrib", "FramesPerSecond", "not-a-rate"]),
            ("fractional", ["--attrib:type=rational", "FramesPerSecond", "30000/1001"]),
        ):
            path = cls.work / (name + ".exr")
            subprocess.run(
                ["oiiotool", "--pattern", "constant:color=.2,.1,.05,1", "64x64", "4",
                 *metadata, "-o", str(path)],
                env=cls.env, check=True, capture_output=True, text=True, timeout=30,
            )
            cls.fixtures[name] = path

    def run_tool(self, *args, cwd):
        result = subprocess.run(
            list(map(str, args)), cwd=cwd, env=self.env,
            capture_output=True, text=True, timeout=120,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def sequence(self, folder, fixture, basename="frame"):
        folder.mkdir(parents=True)
        for frame in range(1, FRAME_COUNT + 1):
            shutil.copyfile(self.fixtures[fixture], folder / f"{basename}.{frame:04d}.exr")
        return folder

    def assert_video(self, path, fps):
        result = self.run_tool(
            "ffprobe", "-v", "error", "-select_streams", "v:0", "-count_frames",
            "-show_entries", "stream=nb_read_frames,avg_frame_rate,duration", "-of", "json",
            path, cwd=path.parent,
        )
        stream = json.loads(result.stdout)["streams"][0]
        self.assertEqual(int(stream["nb_read_frames"]), FRAME_COUNT, str(path))
        self.assertEqual(Fraction(stream["avg_frame_rate"]), Fraction(fps), str(path))
        self.assertAlmostEqual(float(stream["duration"]), FRAME_COUNT / float(Fraction(fps)),
                               delta=0.0001, msg=str(path))

    def check_converters(self, fixture, expected_fps, *flags):
        for script, suffix in CONVERTERS:
            with self.subTest(script=script, fixture=fixture, flags=flags):
                folder = self.sequence(self.work / self._testMethodName / script, fixture)
                self.run_tool(ROOT / "video" / script, "-j", "2", *flags, cwd=folder)
                self.assert_video(folder / ("frame" + suffix), expected_fps)

    def test_metadata_rate_and_every_frame_preserved(self):
        self.check_converters("24", "24")

    def test_missing_metadata_defaults_to_30(self):
        self.check_converters("missing", "30")

    def test_invalid_metadata_defaults_to_30(self):
        self.check_converters("invalid", "30")

    def test_explicit_rate_overrides_metadata(self):
        self.check_converters("24", "24000/1001", "-fps", "24000/1001")

    def test_rational_metadata_preserves_exact_rate(self):
        self.check_converters("fractional", "30000/1001")

    def test_high_rate_does_not_duplicate_last_frame(self):
        self.check_converters("48", "48")

    def test_numbered_links_preserve_gapped_numeric_order_and_spaces(self):
        folder = self.work / "temporary PNGs with spaces"
        folder.mkdir()
        for frame in (100, 2, 10, 7):
            (folder / f"render pass.{frame}_converted.png").write_text(str(frame))
        (folder / "unrelated.png").write_text("ignore this file")
        self.run_tool(
            "bash", "-c", 'source "$1"; exr_video_link_frames "$2"',
            "bash", ROOT / "lib" / "exr_video.sh", folder, cwd=self.work,
        )
        links = sorted((folder / "frames").glob("*.png"))
        self.assertEqual(len(links), 4)
        self.assertEqual([link.name for link in links], [f"{index:08d}.png" for index in range(4)])
        for link, frame in zip(links, (2, 7, 10, 100)):
            self.assertTrue(link.is_symlink(), str(link))
            self.assertEqual(link.resolve(), folder / f"render pass.{frame}_converted.png")
            self.assertEqual(link.read_text(), str(frame))

    def test_prores_multiple_folders_resolve_rates_independently(self):
        for script, suffix in CONVERTERS[2:]:
            with self.subTest(script=script):
                output = self.work / self._testMethodName / script
                sequences = [
                    self.sequence(output / "first", "24", "first"),
                    self.sequence(output / "second", "missing", "second"),
                    self.sequence(output / "third", "48", "third"),
                ]
                self.run_tool(ROOT / "video" / script, "-j", "2", *sequences, cwd=output)
                for basename, fps in (("first", "24"), ("second", "30"), ("third", "48")):
                    self.assert_video(output / (basename + suffix), fps)


if __name__ == "__main__":
    unittest.main()
