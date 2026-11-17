"""Copy the single-html build into deploy/ for Streamlit Community Cloud.

build/ is git-ignored, so the Streamlit app (streamlit_app.py) reads the game from
deploy/jodal_rookie.html.gz, which is committed. gzip with mtime=0 keeps the output
byte-identical when the html did not change, so an unchanged build makes no git diff.

Run only when you want to update the deployed game (each run adds ~13MB to git history):
    python tools/make_single_html.py
    python tools/pack_streamlit.py
then commit deploy/ and push. Streamlit Cloud redeploys on push.
"""

import gzip
import shutil
import sys
from pathlib import Path

SRC = Path(sys.argv[1] if len(sys.argv) > 1 else "build/jodal_rookie.html")
ICON = Path("build/web/index.icon.png")
OUT_DIR = Path("deploy")


def main() -> None:
	if not SRC.exists():
		sys.exit(f"{SRC} not found: run tools/make_single_html.py first")
	OUT_DIR.mkdir(exist_ok=True)
	(OUT_DIR / ".gdignore").touch()
	out = OUT_DIR / "jodal_rookie.html.gz"
	data = gzip.compress(SRC.read_bytes(), compresslevel=9, mtime=0)
	if out.exists() and out.read_bytes() == data:
		print(f"{out}  unchanged")
	else:
		out.write_bytes(data)
		print(f"{out}  {len(data) / 1e6:.1f} MB")
	if ICON.exists():
		shutil.copyfile(ICON, OUT_DIR / "icon.png")


if __name__ == "__main__":
	main()
