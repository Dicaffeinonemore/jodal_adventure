"""Pack the Godot web export (build/web) into ONE html file that runs by double-click.

A normal Godot web build needs a web server: browsers refuse to fetch index.wasm /
index.pck from file://. This script embeds those files (gzip + base64) in the page and
wraps window.fetch / AudioWorklet.addModule so the engine gets them from memory.
DecompressionStream does the unzipping (Chrome/Edge 80+, Safari 16.4+, Firefox 113+).

When the game cannot start on someone else's computer, the page explains why in Korean
instead of a black screen or Godot's English notice:
  - a plain-HTML help box that appears after a few seconds unless the page's scripts ran to
    the end (messenger / mail previews and phone file viewers that don't run scripts,
    files cut short in transfer)
  - checks before start: WebGL2 (graphics acceleration), WebAssembly / DecompressionStream
  - embedded data length check (damaged or truncated file)
  - Godot's failure notice is translated into steps the player can follow
It also writes build/jodal_rookie.zip (the html + 실행 방법.txt): mail and messengers that
block or alter .html attachments pass a zip untouched.

Usage (after exporting the Web preset to build/web):
    python tools/make_single_html.py [build/web] [build/jodal_rookie.html]
"""

import base64
import gzip
import sys
import zipfile
from pathlib import Path

SRC = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
OUT = Path(sys.argv[2] if len(sys.argv) > 2 else "build/jodal_rookie.html")
NAME = "index"  # export_presets.cfg exports to build/web/index.html

# Shown without any script: hidden by CSS for HELP_DELAY, removed by the last script
# in the page. If scripts never run (or the file was cut short) it fades in.
HELP_DELAY = "5s"
HELP_HTML = """
<style>
.jr-box { position: fixed; left: 50%%; top: 50%%; transform: translate(-50%%, -50%%); z-index: 1000;
  width: min(560px, calc(100%% - 32px)); box-sizing: border-box; padding: 18px 22px;
  background: #fbf3dc; color: #2e2636; border: 3px solid #261e2c; border-radius: 10px;
  font: 15px/1.6 "Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans KR", sans-serif;
  box-shadow: 0 4px 0 rgba(0,0,0,.35); }
.jr-box h2 { margin: 0 0 8px; font-size: 18px; }
.jr-box ul { margin: 0; padding-left: 20px; }
.jr-box li { margin: 4px 0; }
.jr-box .jr-detail { margin-top: 10px; font: 12px/1.4 monospace; color: #6a6070; white-space: pre-wrap;
  word-break: break-all; max-height: 7em; overflow: auto; }
#jr-help { opacity: 0; pointer-events: none; animation: jr-show 0.3s %(delay)s forwards; }
@keyframes jr-show { to { opacity: 1; pointer-events: auto; } }
.jr-banner { position: fixed; left: 8px; right: 8px; top: 8px; z-index: 1001; padding: 8px 12px;
  background: #261e2c; color: #fbf3dc; border-radius: 8px;
  font: 13px/1.5 "Malgun Gothic", "Apple SD Gothic Neo", sans-serif; }
</style>
<div id="jr-help" class="jr-box">
  <h2>게임 화면이 나오지 않나요?</h2>
  <ul>
    <li>이 파일은 <b>PC의 크롬, 엣지, 웨일</b>에서 더블클릭해서 여는 게임이에요.</li>
    <li>카카오톡·메일의 <b>미리보기</b> 화면에서는 실행되지 않아요. 파일을 PC에 저장한 뒤 열어 주세요.</li>
    <li>아이폰 '파일' 앱이나 휴대폰 미리보기에서는 실행되지 않을 수 있어요.</li>
    <li>파일이 덜 받아졌을 수도 있어요. 원본 크기는 약 %(size)sMB예요. 다시 받아 주세요.</li>
  </ul>
</div>
"""

# Runs first: feature checks, the Korean failure box, and a watchdog on Godot's own status.
GUARD = r"""
(function () {
	var SIZE = "%(size)s";
	var MSG = {
		old: ["이 브라우저에서는 게임을 실행할 수 없어요", [
			"최신 <b>크롬, 엣지, 웨일</b> 브라우저로 열어 주세요.",
			"파일을 오른쪽 클릭 → <b>연결 프로그램</b> → Google Chrome 또는 Microsoft Edge를 고르면 돼요.",
			"인터넷 익스플로러와 오래된 브라우저는 지원하지 않아요."]],
		webgl: ["그래픽 가속(WebGL2)을 쓸 수 없어요", [
			"크롬·엣지 <b>설정 → 시스템 → '가능한 경우 그래픽 가속 사용'</b>을 켜고 브라우저를 다시 시작해 주세요.",
			"회사·학교 PC나 원격 데스크톱에서는 막혀 있을 수 있어요. 다른 PC에서 열어 주세요.",
			"그래픽 드라이버를 업데이트하면 해결되기도 해요. (주소창에 chrome://gpu 를 넣으면 상태를 볼 수 있어요)"]],
		corrupt: ["파일이 손상되었어요", [
			"전송 중에 파일이 잘렸거나 바뀌었어요. 원본 크기는 약 " + SIZE + "MB예요.",
			"메신저나 메일로 보낼 때는 <b>zip 파일</b>(jodal_rookie.zip)로 보내면 안전해요.",
			"받은 파일을 다시 내려받아 주세요."]],
		error: ["게임을 시작하지 못했어요", [
			"<b>PC의 크롬, 엣지, 웨일</b>에서 열어 주세요.",
			"파일이 덜 받아졌으면 다시 내려받아 주세요. (원본 약 " + SIZE + "MB)",
			"다른 탭과 프로그램을 닫고 다시 열어 보세요. 메모리가 부족하면 실행되지 않아요."]]
	};
	var BANNER = {
		inapp: "메신저 앱 안의 브라우저에서 열렸어요. 실행되지 않으면 메뉴에서 '다른 브라우저로 열기'를 눌러 주세요.",
		slow: "로딩이 오래 걸리고 있어요. 휴대폰이나 저사양 PC에서는 1~2분 걸릴 수 있어요. 계속 멈춰 있으면 PC의 크롬이나 엣지로 열어 주세요."
	};
	var shown = false;
	function esc(s) {
		return String(s).replace(/[&<>]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c]; });
	}
	function fail(kind, detail) {
		if (shown) return;
		shown = true;
		var m = MSG[kind] || MSG.error;
		var help = document.getElementById("jr-help");
		if (help) help.remove();
		var box = document.createElement("div");
		box.className = "jr-box";
		box.id = "jr-error";
		box.innerHTML = "<h2>" + m[0] + "</h2><ul><li>" + m[1].join("</li><li>") + "</li></ul>"
			+ (detail ? "<div class='jr-detail'>" + esc(detail) + "</div>" : "");
		(document.body || document.documentElement).appendChild(box);
	}
	function banner(kind) {
		if (shown || document.getElementById("jr-banner-" + kind)) return;
		var b = document.createElement("div");
		b.className = "jr-banner";
		b.id = "jr-banner-" + kind;
		b.textContent = BANNER[kind];
		(document.body || document.documentElement).appendChild(b);
		setTimeout(function () { b.remove(); }, 15000);
	}
	window.__jrFail = fail;

	var gl = null;
	try { gl = document.createElement("canvas").getContext("webgl2"); } catch (e) { gl = null; }
	if (!window.WebAssembly || typeof DecompressionStream === "undefined" || !window.fetch || !window.Promise) {
		fail("old", navigator.userAgent);
	} else if (!gl) {
		fail("webgl", "WebGL2 unavailable - " + navigator.userAgent);
	}
	if (/KAKAOTALK|NAVER\(inapp|Line\/|Instagram|FBAN|FBAV|DaumApps|everytimeApp/i.test(navigator.userAgent)) {
		banner("inapp");
	}
	// Godot removes #status once the game runs, or shows #status-notice on failure.
	var t0 = Date.now();
	var timer = setInterval(function () {
		if (!document.getElementById("status")) { clearInterval(timer); return; }
		var notice = document.getElementById("status-notice");
		if (notice && notice.style.display === "block" && notice.textContent) {
			clearInterval(timer);
			var text = notice.textContent;
			fail(/WebGL/.test(text) ? "webgl" : (/damaged|incorrect header|invalid|unexpected end/i.test(text) ? "corrupt" : "error"), text);
		} else if (Date.now() - t0 > 60000) {
			clearInterval(timer);
			banner("slow");
		}
	}, 500);
})();
"""

README = """출근! 조달청 신입 - 실행 방법

1. 이 zip 파일의 압축을 풀어 주세요. (오른쪽 클릭 → 압축 풀기)
2. jodal_rookie.html 을 더블클릭하면 브라우저에서 게임이 열려요.
   - PC의 크롬, 엣지, 웨일 브라우저에서 실행돼요.
   - 다른 프로그램으로 열리면: 오른쪽 클릭 → 연결 프로그램 → Google Chrome 또는 Microsoft Edge
3. 처음 열 때 10~30초 정도 로딩이 걸릴 수 있어요.
4. 소리는 타이틀 화면을 한 번 누른 뒤부터 나와요.

조작: 방향키(또는 WASD) 이동, Shift 달리기, Space/Enter 말 걸기·조사, Esc 메뉴, Q 아이템

안 될 때
- 화면에 안내 상자가 나오면 그 안내를 따라 주세요.
- 카카오톡·메일 '미리보기'에서는 실행되지 않아요. 파일을 PC에 저장한 뒤 여세요.
- 그래픽 가속이 꺼져 있으면 실행되지 않아요: 크롬/엣지 설정 → 시스템 → '가능한 경우 그래픽 가속 사용' 켜기
- 인터넷 익스플로러는 지원하지 않아요.
"""

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
		var raw = el ? el.textContent.replace(/\s+/g, "") : "";
		var want = el ? parseInt(el.getAttribute("data-len"), 10) : -1;
		if (raw.length !== want) {  // cut short or altered in transfer
			if (window.__jrFail) window.__jrFail("corrupt", e[0] + ": " + raw.length + " / " + want);
			return Promise.reject(new Error("The embedded game data is damaged (" + e[0] + ")."));
		}
		var bytes = b64ToBytes(raw);
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
	return f'<script type="text/plain" id="{element_id}" data-len="{len(b64)}">\n{lines}\n</script>\n'


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
		blocks + "<script>%(guard)s</script>\n" + f"<script>{loader}</script>\n<script>\n{engine_js}\n</script>")
	html = replace_once(html, "<body>", "<body>\n%(help)s")
	# Godot's English fallback lines; the Korean help box covers these cases.
	html = replace_once(html, "Your browser does not support the canvas tag.", "")
	html = replace_once(html, "Your browser does not support JavaScript.", "")
	# Last thing in the page: if this ran, scripts work and the file is complete.
	html = replace_once(html, "</body>",
		"<script>var h = document.getElementById('jr-help'); if (h) h.remove();</script>\n</body>")

	size = f"{(len(html.encode('utf-8')) + 9000) / 1e6:.0f}"  # + the help/guard text below
	html = html.replace("%(guard)s", GUARD % {"size": size}, 1).replace(
		"%(help)s", HELP_HTML % {"size": size, "delay": HELP_DELAY}, 1)

	OUT.parent.mkdir(parents=True, exist_ok=True)
	OUT.write_text(html, encoding="utf-8", newline="\n")
	print(f"{OUT}  {OUT.stat().st_size / 1e6:.1f} MB")
	zip_path = OUT.with_suffix(".zip")
	with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
		z.write(OUT, OUT.name)
		z.writestr("실행 방법.txt", README.replace("\n", "\r\n").encode("utf-8-sig"))
	print(f"{zip_path}  {zip_path.stat().st_size / 1e6:.1f} MB")


if __name__ == "__main__":
	main()
