"""Streamlit Community Cloud entry point: shows the single-html web build full screen.

The game itself is deploy/jodal_rookie.html.gz (made by tools/pack_streamlit.py).
components.html puts it in an iframe (srcdoc) that allows scripts, same-origin storage
(the save file lives in IndexedDB), fullscreen and prompt(), which the game needs.
"""

import gzip
from pathlib import Path

import streamlit as st
import streamlit.components.v1 as components

ROOT = Path(__file__).parent
GAME = ROOT / "deploy" / "jodal_rookie.html.gz"
ICON = ROOT / "deploy" / "icon.png"

st.set_page_config(
	page_title="출근! 조달청 신입",
	page_icon=str(ICON) if ICON.exists() else None,
	layout="wide",
	initial_sidebar_state="collapsed",
)

# Hide Streamlit's chrome and let the game iframe fill the window (16:9 base, aspect expand).
st.html("""
<style>
header, footer, #MainMenu,
[data-testid="stHeader"], [data-testid="stToolbar"], [data-testid="stDecoration"],
[data-testid="stStatusWidget"], [data-testid="stSidebar"] { display: none !important; }
html, body, .stApp, [data-testid="stAppViewContainer"], [data-testid="stMain"] {
	background: #000 !important; overflow: hidden !important;
}
.block-container, [data-testid="stMainBlockContainer"] {
	padding: 0 !important; margin: 0 !important; max-width: 100% !important;
}
[data-testid="stVerticalBlock"] { gap: 0 !important; }
iframe {
	display: block; width: 100vw !important; border: 0;
	height: 100vh !important; height: 100dvh !important;
}
</style>
""")


@st.cache_resource(show_spinner=False)
def game_html() -> str:
	return gzip.decompress(GAME.read_bytes()).decode("utf-8")


if not GAME.exists():
	st.error("deploy/jodal_rookie.html.gz 가 없어요. tools/pack_streamlit.py 를 실행해 주세요.")
	st.stop()

components.html(game_html(), height=720, scrolling=False)
