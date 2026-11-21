"""Copy the 조달 상식 illustrations into assets/tips/ at game size.

    python tools/import_tip_images.py "<folder with the original PNGs>"

The originals are named by their keyword (계약보증금.png ...). They are ~1400x768,
2 MB each, too heavy for the single html, so this resizes them to 1024 px wide and
saves them under English ids (Story.TIP_PICTURES maps id -> keyword shown as title).
Godot imports them as lossy WebP with mipmaps (see the .import files).
"""
import sys
from pathlib import Path

from PIL import Image

WIDTH = 1024
OUT = Path(__file__).resolve().parent.parent / "assets" / "tips"
# original file name (keyword) -> id used by Story.TIP_PICTURES
FILES = {
    "계약보증금": "contract_deposit",
    "긴급 입찰": "urgent_bid",
    "나라장터 전자조달시스템": "narajangteo",
    "나르미 달이 소개": "mascots",
    "녹색제품 구매 품질 확인": "green_products",
    "대전 본청 및 11개 지방조달청": "regional_offices",
    "적격심사 과정": "qualification",
    "조달청 청훈": "motto",
    "조달청의 역사": "history",
    "조달품질원 및 조달품질신문고": "quality",
    "주요 원자재 비축 방출": "stockpile",
    "혁신조달": "innovation",
}


def main() -> None:
    src = Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    for name, tip_id in FILES.items():
        im = Image.open(src / f"{name}.png").convert("RGB")
        h = round(im.height * WIDTH / im.width)
        im = im.resize((WIDTH, h), Image.LANCZOS)
        im.save(OUT / f"{tip_id}.png", optimize=True)
        print(f"{name} -> {tip_id}.png {im.size}")


if __name__ == "__main__":
    main()
