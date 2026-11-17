# 출근! 조달청 신입

2026 조달청 AI 게임·콘텐츠 공모전 출품용 웹 게임 (Godot 4.5+, Compatibility, GDScript).

## 처음 실행

1. Godot 4.5 이상(Standard 버전, .NET 아님)을 설치하고 이 폴더의 `project.godot`을 연다.
2. F5로 실행. PC에서는 F2로 터치 조작 UI를 켜고 끌 수 있다(마우스 클릭이 터치로 처리됨).
3. 웹 빌드: 에디터 메뉴 Editor > Manage Export Templates에서 템플릿 설치 후 Project > Export > Web.
4. 바로 해 보기: `python tools/make_single_html.py`로 만든 `build/jodal_rookie.html`을 더블클릭한다(서버 불필요, 크롬·엣지 권장).

## Streamlit 배포 (웹 주소로 공유)

Streamlit Community Cloud가 `streamlit_app.py`로 단일 html 게임을 전체 화면 iframe에 띄운다.
`build/`는 git에 안 올라가므로 게임은 `deploy/jodal_rookie.html.gz`(커밋 대상)에서 읽는다.

1. 게임 갱신: 웹 내보내기 → `python tools/make_single_html.py` → `python tools/pack_streamlit.py`
2. `deploy/` 커밋 후 GitHub에 push (실행할 때마다 git 기록이 약 13MB 늘어나니 배포할 때만 돌린다)
3. 처음 한 번: https://share.streamlit.io → Create app → 이 저장소, 브랜치 `main`, Main file path `streamlit_app.py` → Deploy.
   이후에는 push하면 자동으로 다시 배포된다.
4. 로컬 확인: `pip install -r requirements.txt` → `streamlit run streamlit_app.py` → http://localhost:8501

설정: `.streamlit/config.toml`(저장소 루트에 있어야 함), 의존성 `requirements.txt`.
저장 파일은 브라우저(IndexedDB)에 남는다. 게임은 iframe 안에서 돌기 때문에 키보드는 화면을 한 번 클릭한 뒤부터 먹는다.

조작: 방향키/WASD 이동(Shift를 누르면 달리기), Space·Enter 말 걸기, Esc 스마트폰 메뉴, Q 아이템, 하단 메뉴 바(업무 B·가방 I·성장 C·저장 U). 운전 미니게임은 ← → 핸들, ↓ 감속.

개발 규칙과 구조는 `CLAUDE.md`, 기획·우선순위·일정은 `docs/plan.md`.
임시 도트는 `python tools/gen_placeholders.py`로 다시 만들 수 있다(Pillow 필요, macOS는 python3).
