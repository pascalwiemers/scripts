"""EXR conversion regressions. Run: python3 -m unittest discover -s tests -v

Requires OpenImageIO's Python module, numpy and oiiotool, plus an OCIO config
containing ACES - ACEScg and Output - sRGB. WebP/package tests need ImageMagick;
video tests additionally need GNU Parallel and FFmpeg. All outputs are temporary.
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

import numpy as np
import OpenImageIO as oiio

ROOT = Path(__file__).resolve().parents[1]


class ExrConverters(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="exr-converters-")
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.env = dict(os.environ, JOBS="2", SHELL="/bin/bash")
        self.bare = self.fixture("bare", "R,G,B,A", ".2,.1,.05,.5")
        self.prefixed = self.fixture("light pass", "light.R,light.G,light.B,light.A", ".2,.1,.05,.5")
        self.rgb = self.fixture("rgb", "light.R,light.G,light.B", ".2,.1,.05")

    def run_tool(self, *args, cwd=None, success=True):
        result = subprocess.run(list(map(str, args)), cwd=cwd or self.work,
                                env=self.env, capture_output=True, text=True, timeout=120)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        self.assertNotIn("Unknown channel", result.stderr)
        return result

    def fixture(self, name, channels, color):
        path = self.work / (name + ".exr")
        self.run_tool("oiiotool", "--pattern", "constant:color=" + color,
                      "64x64", len(channels.split(",")), "--chnames", channels, "-o", path)
        return path

    def read(self, path):
        image = oiio.ImageBuf(str(path))
        pixels = image.get_pixels(oiio.FLOAT)
        self.assertIsNotNone(pixels, str(path))
        return image.spec(), pixels

    def test_still_formats_match_bare_channels(self):
        for script, ext in [("exrtopng.sh", "png"), ("exrtojpg.sh", "jpg"), ("exrtotiff.sh", "tiff")]:
            with self.subTest(script=script):
                self.run_tool(ROOT / "image" / script, self.bare, self.prefixed, self.rgb)
                spec, pixels = self.read(self.prefixed.with_suffix("." + ext))
                np.testing.assert_array_equal(pixels, self.read(self.bare.with_suffix("." + ext))[1])
                self.assertGreater(pixels[:, :, :3].max(), .1)
                self.assertEqual(spec.nchannels, 3 if ext == "jpg" else 4)
                if ext != "jpg":
                    self.assertEqual(spec.format, oiio.UINT16)
                    np.testing.assert_allclose(pixels[:, :, 3], .5, atol=1/65535)
                self.assertEqual(self.read(self.rgb.with_suffix("." + ext))[0].nchannels, 3)

    @unittest.skipUnless(shutil.which("convert"), "ImageMagick required")
    def test_webp_and_imagepack(self):
        self.run_tool(ROOT / "image/exrtowebp.sh", self.bare, self.prefixed, self.rgb)
        np.testing.assert_array_equal(self.read(self.bare.with_suffix(".webp"))[1],
                                      self.read(self.prefixed.with_suffix(".webp"))[1])
        self.run_tool(ROOT / "image/imagepack.sh", self.prefixed)
        for ext in ["jpg", "png", "tiff", "webp"]:
            spec, pixels = self.read(self.work / "package" / ext / (self.prefixed.stem + "." + ext))
            self.assertGreater(pixels[:, :, :3].max(), .1)
        self.assertEqual((self.work / "package/exr" / self.prefixed.name).read_bytes(), self.prefixed.read_bytes())

    def test_missing_and_ambiguous_rgb_fail(self):
        invalid = [self.fixture("depth", "Z", "1"),
                   self.fixture("incomplete", "R,G,A", ".2,.1,.5"),
                   self.fixture("ambiguous", "a.R,a.G,a.B,b.R,b.G,b.B", ".1,.2,.3,.3,.2,.1")]
        scripts = [("exrtopng.sh", "png"), ("exrtojpg.sh", "jpg"), ("exrtotiff.sh", "tiff")]
        if shutil.which("convert"):
            scripts.append(("exrtowebp.sh", "webp"))
        for source in invalid:
            for script, ext in scripts:
                result = self.run_tool(ROOT / "image" / script, source, success=False)
                self.assertIn("needs one RGB layer", result.stderr)
                self.assertFalse(source.with_suffix("." + ext).exists())
        if shutil.which("convert"):
            result = self.run_tool(ROOT / "image/imagepack.sh", invalid[0], success=False)
            self.assertIn("needs one RGB layer", result.stderr)
            self.assertNotIn("Done.", result.stdout)

    def test_bare_beauty_preferred(self):
        combined = self.fixture("combined", "R,G,B,A,light.R,light.G,light.B", ".2,.1,.05,.5,1,1,1")
        self.run_tool(ROOT / "image/exrtopng.sh", self.bare, combined)
        np.testing.assert_array_equal(self.read(self.bare.with_suffix(".png"))[1],
                                      self.read(combined.with_suffix(".png"))[1])

    def test_split_and_aov_tiff(self):
        depth = self.fixture("depth", "Z", "2.5")
        multipart = self.work / "multipart.exr"
        self.run_tool("oiiotool", self.bare, "--attrib", "oiio:subimagename", "C",
                      self.prefixed, "--attrib", "oiio:subimagename", "light", "--siappend",
                      depth, "--attrib", "oiio:subimagename", "depth", "--siappend", "-o", multipart)
        self.run_tool(ROOT / "image/exrsplit.sh", multipart)
        spec, pixels = self.read(self.work / "layers/multipart_light.exr")
        self.assertEqual(tuple(spec.channelnames), ("R", "G", "B", "A"))
        np.testing.assert_array_equal(pixels, self.read(self.prefixed)[1])
        self.run_tool(ROOT / "image/misc/exrtotiffaov.sh", multipart)
        self.assertGreater(self.read(self.work / "multipart_aov/multipart_light.tiff")[1].max(), .1)
        self.assertEqual(self.read(self.work / "multipart_aov/multipart_depth.tiff")[0].format, oiio.FLOAT)
        data = self.fixture("utility", "depth.Z", "2.5")
        self.run_tool(ROOT / "image/misc/exrtotiffaov.sh", data)
        spec, pixels = self.read(self.work / "utility_aov/utility_depth.tiff")
        self.assertEqual(spec.format, oiio.FLOAT)
        np.testing.assert_array_equal(pixels, 2.5)

    @unittest.skipUnless(all(shutil.which(t) for t in ("ffmpeg", "parallel", "identify")), "Video tools required")
    def test_videos_and_failure_propagation(self):
        for name, ext, extra in [("exrtomp4.sh", ".mp4", []),
                                 ("exrtomp4.sh", ".mp4", ["-meta"]),
                                 ("exrtomp4_dailies.sh", ".mp4", []),
                                 ("exrtoprores422.sh", "_prores422.mov", []),
                                 ("exrtoprores422.sh", "_prores422.mov", ["-meta"]),
                                 ("exrtoprores444.sh", "_prores444.mov", []),
                                 ("exrtoprores444.sh", "_prores444.mov", ["-meta"])]:
            with self.subTest(script=name, flags=extra):
                folder = self.work / (name + "".join(extra))
                folder.mkdir()
                shutil.copy(self.prefixed, folder / "frame.0001.exr")
                shutil.copy(self.rgb, folder / "frame.0002.exr")
                self.run_tool(ROOT / "video" / name, "-j", "1", *extra, cwd=folder)
                output = folder / ("frame" + ext)
                self.assertTrue(output.exists())
                decoded = folder / "decoded.png"
                self.run_tool("ffmpeg", "-v", "error", "-i", output, "-frames:v", "1", decoded)
                self.assertGreater(self.read(decoded)[1][:, :, :3].max(), .1)
                # No caller may report success or create video after channel selection fails.
                output.unlink()
                bad = self.fixture("bad", "Z", "1")
                shutil.copy(bad, folder / "frame.0001.exr")
                self.run_tool(ROOT / "video" / name, "-j", "1", *extra, cwd=folder, success=False)
                self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
