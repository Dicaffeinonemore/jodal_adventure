"""Regression checks for scenery previously carried along by the hopping sprites."""
import unittest
from pathlib import Path

from PIL import Image, ImageSequence


class TitleAnimationTest(unittest.TestCase):
    def test_scenery_stays_put_throughout_the_loop(self):
        root = Path(__file__).resolve().parents[1]
        with Image.open(root / "tools/ref/opening-screen.png") as source, Image.open(
            root / "docs/title_anim.gif"
        ) as animation:
            # Two patches of foliage, the pale lintel and the post beside Dali's ear.
            points = [(545, 650), (960, 510), (853, 412), (1095, 620)]
            samples = [(round(x * animation.width / source.width),
                        round(y * animation.height / source.height)) for x, y in points]
            reference = source.convert("RGB").resize(animation.size, Image.Resampling.LANCZOS)
            self.assertGreater(animation.n_frames, 1)
            first = animation.convert("RGB")
            for frame in ImageSequence.Iterator(animation):
                rgb = frame.convert("RGB")
                for point in samples:
                    with self.subTest(frame=animation.tell(), point=point):
                        self.assertEqual(rgb.getpixel(point), first.getpixel(point))
                        expected = reference.getpixel(point)
                        self.assertLess(max(abs(a - b) for a, b in zip(rgb.getpixel(point), expected)), 25)


if __name__ == "__main__":
    unittest.main()
