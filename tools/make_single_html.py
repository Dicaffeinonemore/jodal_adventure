"""Pack the Godot web export (build/web) into ONE html file that runs by double-click.

A normal Godot web build needs a web server: browsers refuse to fetch index.wasm /
index.pck from file://. This script embeds those files (gzip + base64) in the page and
wraps window.fetch / AudioWorklet.addModule so the engine gets them from memory.
DecompressionStream does the unzipping (Chrome/Edge 80+, Safari 16.4+, Firefox 113+).

Usage (after exporting the Web preset to build/web):
    python tools/make_single_html.py [build/web] [build/jodal_rookie.html]
"""

import base64
import gzip
import sys
from pathlib import Path

SRC = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
OUT = Path(sys.argv[2] if len(sys.argv) > 2 else "build/jodal_rookie.html")
NAME = "index"  # export_presets.cfg exports to build/web/index.html

LOADER = r"""
(function () {
	// Files the engine fetches, served from the <script type="text/plain"> blocks below.
	var EMBED = {
		"%(name)s.wasm": ["gd-wasm", "application/wasm"],
		"%(name)s.pck": ["gd-pck", "application/octet-stream"]
	};
	var WORKLETS = %(worklets)s;
	function baseName(input) {
		var s = String(typeof Request !== "undefined" && input instanceof Request ? input.url : input);
		return s.split("#")[0].split("?")[0].split("/").pop();
	}
	function b64ToBytes(b64) {
		var bin = atob(b64), n = bin.length, out = new Uint8Array(n);
		for (var i = 0; i < n; i++) out[i] = bin.charCodeAt(i);
		return out;
	}
	var origFetch = window.fetch.bind(window);
	window.fetch = function (input, init) {
		var e = EMBED[baseName(input)];
		if (!e) return origFetch(input, init);
		var el = document.getElementById(e[0]);
		var bytes = b64ToBytes(el.textContent.replace(/\s+/g, ""));
		el.textContent = ""; // free the base64 text
		var stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream("gzip"));
		return Promise.resolve(new Response(stream, { status: 200, headers: { "Content-Type": e[1] } }));
	};
	// data: URLs, not blob: — a file:// page has origin "null" and worklets refuse blob:null.
	var urls = {};
	Object.keys(WORKLETS).forEach(function (k) {
		urls[k] = "data:text/javascript;base64," + btoa(unescape(encodeURIComponent(WORKLETS[k])));
	});
	// The engine asks for a service worker (PWA hook); file:// has none and rejects loudly.
	if (location.protocol === "file:" && navigator.serviceWorker) {
		try {
			navigator.serviceWorker.getRegistration = function () { return Promise.resolve(undefined); };
		} catch (err) { /* read-only in some browsers: harmless */ }
	}
	if (window.AudioWorklet && AudioWorklet.prototype.addModule) {
		var origAdd = AudioWorklet.prototype.addModule;
		AudioWorklet.prototype.addModule = function (url, opts) {
			var u = urls[baseName(url)];
			return origAdd.call(this, u || url, opts);
		};
	}
})();
"""


def replace_once(text: str, old: str, new: str) -> str:
	if text.count(old) != 1:
		sys.exit(f"index.html changed? expected exactly one '{old}'")
	return text.replace(old, new)


def data_uri(path: Path, mime: str) -> str:
	return f"data:{mime};base64," + base64.b64encode(path.read_bytes()).decode("ascii")


def b64_block(element_id: str, data: bytes) -> str:
	b64 = base64.b64encode(gzip.compress(data, 9)).decode("ascii")
	lines = "\n".join(b64[i:i + 1024] for i in range(0, len(b64), 1024))
	return f'<script type="text/plain" id="{element_id}">\n{lines}\n</script>\n'


def main() -> None:
	html = (SRC / f"{NAME}.html").read_text(encoding="utf-8")
	engine_js = (SRC / f"{NAME}.js").read_text(encoding="utf-8")
	if "</script" in engine_js:
		engine_js = engine_js.replace("</script", "<\\/script")

	import json
	worklets = {}
	for p in sorted(SRC.glob(f"{NAME}.*worklet.js")):
		worklets[p.name] = p.read_text(encoding="utf-8")
	loader = LOADER % {"name": NAME, "worklets": json.dumps(worklets).replace("</", "<\\/")}

	html = replace_once(html, f'src="{NAME}.png"', f'src="{data_uri(SRC / f"{NAME}.png", "image/png")}"')
	html = replace_once(html, f'href="{NAME}.icon.png"', f'href="{data_uri(SRC / f"{NAME}.icon.png", "image/png")}"')
	html = replace_once(html, f'href="{NAME}.apple-touch-icon.png"',
		f'href="{data_uri(SRC / f"{NAME}.apple-touch-icon.png", "image/png")}"')
	blocks = b64_block("gd-wasm", (SRC / f"{NAME}.wasm").read_bytes()) \
		+ b64_block("gd-pck", (SRC / f"{NAME}.pck").read_bytes())
	html = replace_once(html, f'<script src="{NAME}.js"></script>',
		blocks + f"<script>{loader}</script>\n<script>\n{engine_js}\n</script>")

	OUT.parent.mkdir(parents=True, exist_ok=True)
	OUT.write_text(html, encoding="utf-8", newline="\n")
	print(f"{OUT}  {OUT.stat().st_size / 1e6:.1f} MB")


if __name__ == "__main__":
	main()
