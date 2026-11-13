"""Makes the README's screenshots from the sample app's screenshot test.

Reads the PNGs that Tools/SampleScreenshots/run.sh or CI's sample-screenshots artifact holds,
scales the ones the README shows to 600 pixels wide and saves them with a 256-colour palette in
Docs/Images, so the repository stays small. Needs Pillow (python3 -m pip install pillow).

Usage: python3 Tools/SampleScreenshots/readme_images.py SHOTS_FOLDER
"""

import pathlib
import sys

from PIL import Image

WIDTH = 600
SHOTS = {
    "02-doors.png": "doors.png",
    "11-ring.png": "ring.png",
    "12-call.png": "call.png",
    "04-keypad.png": "keypad.png",
}


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    source = pathlib.Path(sys.argv[1])
    target = pathlib.Path(__file__).resolve().parents[2] / "Docs" / "Images"
    target.mkdir(parents=True, exist_ok=True)
    missing = [name for name in SHOTS if not (source / name).is_file()]
    if missing:
        print(f"missing in {source}: {', '.join(missing)}", file=sys.stderr)
        return 1
    for name, output in SHOTS.items():
        with Image.open(source / name) as shot:
            height = round(shot.height * WIDTH / shot.width)
            small = shot.convert("RGB").resize((WIDTH, height), Image.LANCZOS)
            small.quantize(colors=256, method=Image.Quantize.MEDIANCUT).save(target / output, optimize=True)
        print(f"{target / output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
