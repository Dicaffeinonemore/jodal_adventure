# 출근! 조달청 신입

2026 조달청 AI 게임·콘텐츠 공모전 출품용 웹 게임 (Godot 4.5+, Compatibility, GDScript).

## 처음 실행

1. Godot 4.5 이상(Standard 버전, .NET 아님)을 설치하고 이 폴더의 `project.godot`을 연다.
2. F5로 실행. PC에서는 F2로 터치 조작 UI를 켜고 끌 수 있다(마우스 클릭이 터치로 처리됨).
3. 웹 빌드: 에디터 메뉴 Editor > Manage Export Templates에서 템플릿 설치 후 Project > Export > Web.
4. 바로 해 보기: `python tools/make_single_html.py`로 만든 `build/jodal_rookie.html`을 더블클릭한다(서버 불필요, 크롬·엣지 권장).

조작: 방향키/WASD 이동(Shift를 누르면 달리기), Space·Enter 말 걸기, Esc 메뉴, Q 아이템, 하단 메뉴 바(업무·가방·성장·저장). 운전 미니게임은 ← →.

개발 규칙과 구조는 `CLAUDE.md`, 기획·우선순위·일정은 `docs/plan.md`.
임시 도트는 `python tools/gen_placeholders.py`로 다시 만들 수 있다(Pillow 필요, macOS는 python3).
