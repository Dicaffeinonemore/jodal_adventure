# 출근! 조달청 신입 — Claude Code 작업 가이드

2026 조달청 AI 게임·콘텐츠 공모전(AI 게임 부문) 출품용 웹 게임입니다.
조달청 신입이 마스코트 나르미(황새)·달이(다람쥐)의 도움을 받아 조달 업무를 처리하며 성장하는
픽셀풍 타이쿤 + 미니게임 육성 시뮬레이션입니다.

- **마감: 2026-11-22(일) 23:59.** 11/19 밤 P0 완료, 11/20 밤 기능 동결, 11/21 테스트·시연영상.
- 제출물: 웹 실행 파일(html), 시연영상 1분 내외(MP4, 1080p 이상), 신청서(AI 활용 내역 포함).
- 기획·우선순위·일정 전체: `docs/plan.md`. 새 기능을 만들기 전에 우선순위부터 확인한다.

## 현재 상태 (중요)

11/17 Godot 4.5.2에서 처음 실행·검증했다. `--import`, `--quit-after 600`, 장면별 단독 실행에서 오류 0건이고,
헤드리스 스모크 테스트가 코어 루프 3바퀴(강제 퇴근·다음 날 보고·메뉴·저장/불러오기·퇴근 포함)를 통과한다.
웹 빌드는 헤드리스 크롬에서 PC 모드와 모바일 에뮬레이션으로 확인했다. **휴대폰 실기 테스트는 아직이다**
(`docs/playtest-checklist.md`).

## 기술 규칙 (바꾸지 말 것)

- Godot **4.5 이상**, 렌더러 **Compatibility**(웹은 이것만 지원), 언어 **GDScript만**(Godot 4의 C#은 웹 내보내기 불가).
- 웹 내보내기는 **Thread Support 끔**(단일 스레드). iOS 사파리 호환과 일반 호스팅을 위해서다.
- 기준 해상도 640×360, stretch `viewport` + aspect `expand`. 픽셀아트는 Nearest 필터, 정수 배율.
- 한글은 반드시 번들 폰트(갈무리, `UiTheme`)로 표시한다. 웹에는 시스템 폰트가 없어서 기본 폰트로는 한글이 네모로 깨진다.
  Galmuri11은 12px 기준(12, 24), Galmuri9는 10px.
- 입력은 **액션만** 읽는다(`move_*`, `interact`, `cancel`, `quick_item`). 액션은 `scripts/autoload/input_setup.gd`에서 코드로 등록한다. 터치 UI는 같은 액션을 누른다.
- 캐릭터 이동은 상하좌우 4방향만. 대각선 금지.
- 정적 타이핑을 쓴다. `Dictionary` 값처럼 타입이 Variant인 식에는 `:=` 대신 `var x: int = ...`로 명시한다.
- 플레이어에게 보이는 문장은 `scripts/systems/story.gd`와 `scripts/data/task_data.gd`에만 둔다. 말투는 해요체.
- 조달 정책 설명(`POLICY_TIPS`, `GENERAL_TIPS`)은 사실이어야 한다. 새로 쓰거나 고칠 때는 공식 출처(조달청 누리집 등)를 확인하고, 확인 못 한 내용은 넣지 않는다.
- 저작권: 제노니아는 분위기 참고만. 에셋·UI·폰트를 가져오지 않는다. 외부 에셋은 라이선스(CC0/OFL 등)를 확인하고 `docs/ai-usage-log.md`의 출처 표에 적는다.
- AI로 만든 것(코드, 아트, 대사, 사운드)은 작업할 때마다 `docs/ai-usage-log.md`에 한 줄씩 기록한다. 신청서에 그대로 쓴다.

## 검증 명령

`godot`은 Godot 4.5+ 실행 파일 경로로 바꿔 쓴다(macOS: `/Applications/Godot.app/Contents/MacOS/Godot`).

```bash
# 1) 리소스 임포트 + 스크립트 오류 확인 (처음 한 번, 에셋을 바꾼 뒤마다)
godot --headless --path . --import

# 2) 게임을 잠깐 실행해서 런타임 오류 확인 (출력에 SCRIPT ERROR / ERROR가 없어야 함)
godot --headless --path . --quit-after 600

# 2-1) 코어 루프 자동 플레이 (마지막 줄이 SMOKE OK, SCRIPT ERROR가 없어야 함)
#      타이틀 화면만 도는 2)와 달리 맵·운전·대화·저장 경로를 전부 실행한다. user://save.json을 지운다.
godot --headless --path . --fixed-fps 60 --script res://tests/smoke_loop.gd

# 3) 웹 내보내기 (에디터에서 Web 내보내기 템플릿을 먼저 설치)
mkdir -p build/web && godot --headless --path . --export-release "Web" build/web/index.html

# 4) 로컬 서버로 확인. 같은 와이파이의 휴대폰에서 http://<PC IP>:8000 으로 접속
python3 -m http.server 8000 -d build/web
```

`--import`가 없는 버전이면 `godot --headless --path . --editor --quit`을 쓴다.
기능을 끝낼 때마다 1), 2), 2-1)을 돌려 오류가 없음을 확인한 뒤 커밋한다.
릴리스 빌드는 스크립트 오류를 콘솔에 찍지 않는다. 웹에서만 나는 문제는 `--export-debug`로 내보내 브라우저 콘솔을 본다.

웹 주의: `JavaScriptBridge.eval()`은 JS bool을 int, 숫자를 float로 돌려준다. `== true` 비교는 런타임 오류이므로 문자열로 받는다.
웹에서는 `emulate_touch_from_mouse` 때문에 `DisplayServer.is_touchscreen_available()`이 항상 true다. 터치 판정은 `GameState.is_touch_device()`만 쓴다.

## 구조

```
project.godot            해상도, 렌더러, autoload
export_presets.cfg       Web 프리셋 (단일 스레드, build/web/index.html)
scripts/autoload/        전역 싱글톤 (project.godot의 순서대로 로드)
  input_setup.gd         입력 액션 등록
  ui_theme.gd            폰트·색·Theme, make_label(), edge_margin()
  game_state.gd          저장되는 모든 상태, 피로도/컨디션, 인벤토리, 저장/불러오기(user://save.json)
  item_db.gd             아이템 정의와 효과 적용
  scene_router.gd        페이드 장면 전환, next_spawn
  dialogue.gd            대화창 say()/choose()/toast()
scripts/systems/
  story.gd (autoload)    코어 루프, NPC 대화, 상점, 메뉴, 인트로, 강제 퇴근
  korean.gd              조사(을/를, 이/가, 로/으로...), 천 단위 쉼표
  sprite_util.gd         스프라이트 시트 -> SpriteFrames
scripts/data/task_data.gd  업무(조달 요청) 데이터, 검수 등급
scripts/world/
  map_base.gd            맵 공통: ASCII 레이아웃 -> 타일, NPC·오브젝트·출구·플레이어·카메라·HUD·터치 UI 배치
  tiles.gd               코드로 만드는 TileSet, ASCII 범례, 충돌 타일
  interactable.gd        조사 가능한 오브젝트 (나라장터 PC, 자판기, 납품 차량...)
  maps/office_map.gd     정부청사 (52x30)
  maps/school_map.gd     한빛초등학교 (32x20)
scripts/actors/          player.gd(4방향 이동·상호작용), npc.gd, character_visual.gd(레이어+틴트)
scripts/ui/              title_screen.gd, character_create.gd, hud.gd, touch_controls.gd
scripts/minigames/drive_game.gd  운전(운송) 미니게임
scenes/                  각 .tscn은 루트 노드 + 스크립트만 있다. 자식은 스크립트가 만든다.
assets/fonts/            갈무리 폰트 (OFL)
assets/sprites/placeholder/  임시 도트 (tools/gen_placeholders.py로 생성)
tests/smoke_loop.gd      헤드리스 코어 루프 테스트 (웹 내보내기에서 제외)
tools/, docs/            Godot이 무시함(.gdignore)
```

### 코어 루프 (story.gd의 `Step`)

`NONE` -팀장 대화-> `ACCEPTED` -나라장터 PC에서 업체 선택-> `VENDOR_CHOSEN` -주차장 차량-> 운전 미니게임
-> `ARRIVED`(학교 도착) -행정실 실장-> 검수(업체 품질 × 화물 상태) -> `DELIVERED` -청사 복귀, 팀장 보고-> 보상 -> `NONE`.
하루 업무 `DAILY_TASKS`건을 마치면 팀장에게 퇴근. 피로도 100이면 강제 퇴근(`GameState.forced_leave`).

### 확장하는 법

- 맵 추가: `MapBase`를 상속한 스크립트 + 루트만 있는 `.tscn`. `SceneRouter.MAPS`에 id 등록.
  레이아웃 문자열은 모든 행 길이가 같아야 한다. 범례는 `Tiles.LEGEND`.
- 업무 추가: `TaskData.TASKS`에 항목 추가. 목적지가 새 맵이면 `Story.PLACE_NAMES`와 해당 맵의 수요기관 NPC 대화도 추가.
- NPC 추가: `Story.NPCS`에 이름·스프라이트·색, 맵의 `npcs()`에 위치, `Story.talk()`에 대화.
- 아이템 추가: `ItemDB.ITEMS` + 아이콘, 판매처는 `Story.VENDING_ITEMS`/`TICKET_ITEMS`.
- 진짜 아트로 교체: 같은 파일명·같은 프레임 배치(`tools/gen_placeholders.py` 상단 설명)로 덮어쓰면 된다.
  에디터에서 타일을 칠하고 싶으면 맵 씬에 TileMapLayer를 추가하고 `layout()`을 비우는 방향으로 바꾼다.

## 알려진 빈틈 (TODO)

- 대화 초상화 없음 (이름 색만 있음).
- 터치 UI 여백이 고정값. `DisplayServer.get_display_safe_area()`로 노치 대응 필요 (P1).
- 사운드 없음 (P1). 오디오는 첫 터치 이후 재생해야 한다(타이틀 화면에서 시작).
- 품질 검사 미니게임 없음 (P1). 현재 검수는 숫자 계산만 한다.
- P1 NPC(선배 주무관, 업체 사장님, 식당 이모)는 배치만 되어 있고 대사가 짧다.
- 모바일 웹에서 이름 입력은 브라우저 `prompt()`로 처리한다. 실기에서 확인 필요.
