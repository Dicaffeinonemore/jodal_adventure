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

11/17 오후 기획 개편(집에서 시작하는 하루, 타이쿤풍 HUD, 2등신 SD, 업무 판단·이벤트·업그레이드)을 반영했다.
개편 내용은 `docs/plan.md`의 "11/17 기획 변경".

## 기술 규칙 (바꾸지 말 것)

- Godot **4.5 이상**, 렌더러 **Compatibility**(웹은 이것만 지원), 언어 **GDScript만**(Godot 4의 C#은 웹 내보내기 불가).
- 웹 내보내기는 **Thread Support 끔**(단일 스레드). iOS 사파리 호환과 일반 호스팅을 위해서다.
- 기준 해상도 640×360, stretch `canvas_items` + aspect `expand`. 픽셀아트는 Nearest 필터.
  (11/18 레벨업 폰트로 바꾸면서 `viewport`에서 변경. 글씨를 화면 해상도로 그려 선명하게 하려고. 되돌리면 글씨가 뿌옇게 번진다.)
- 한글은 반드시 번들 폰트(레벨업 LevelUp, `UiTheme`)로 표시한다. 웹에는 시스템 폰트가 없어서 기본 폰트로는 한글이 네모로 깨진다.
  외곽선 폰트(Regular·Bold, SIL OFL 1.1, `assets/fonts/OFL-LevelUp.md`). 크기는 `SIZE`·`SIZE_SMALL` 12, `SIZE_LARGE` 24.
  자동 줄바꿈 라벨은 `UiTheme.keep_words()`를 거친다(한글 음절 사이 U+2060을 넣어 단어 중간에서 줄이 안 바뀌게).
- 입력은 **액션만** 읽는다(`move_*`, `interact`, `cancel`, `quick_item`, `run`, 하단 바 단축키 `menu_task` B·`menu_bag` I·`menu_growth` C·`menu_save` U). 액션은 `scripts/autoload/input_setup.gd`에서 코드로 등록한다. 터치 UI는 같은 액션을 누른다.
- 캐릭터 이동은 상하좌우 4방향만. 대각선 금지.
- 정적 타이핑을 쓴다. `Dictionary` 값처럼 타입이 Variant인 식에는 `:=` 대신 `var x: int = ...`로 명시한다.
- 플레이어에게 보이는 문장은 `scripts/systems/story.gd`와 `scripts/data/task_data.gd`에만 둔다. 말투는 해요체.
- 조달 정책 설명(`POLICY_TIPS`, `GENERAL_TIPS`, 나라장터 PC 문구)은 사실이어야 한다. 새로 쓰거나 고칠 때는 공식 출처(조달청 누리집 등)를 확인해 `docs/procurement-facts.md`에 적고, 확인 못 한 내용은 넣지 않는다.
- 저작권: 제노니아와 참고 영상(초보자 던전 마스터 플레이 영상)은 분위기 참고만. 에셋·UI·폰트를 가져오지 않는다. 외부 에셋은 라이선스(CC0/OFL 등)를 확인하고 `docs/ai-usage-log.md`의 출처 표에 적는다.
- AI로 만든 것(코드, 아트, 대사, 사운드)은 작업할 때마다 `docs/ai-usage-log.md`에 한 줄씩 기록한다. 신청서에 그대로 쓴다.

## 검증 명령

`godot`은 Godot 4.5+ 실행 파일 경로로 바꿔 쓴다(macOS: `/Applications/Godot.app/Contents/MacOS/Godot`).

```bash
# 1) 리소스 임포트 + 스크립트 오류 확인 (처음 한 번, 에셋을 바꾼 뒤마다)
godot --headless --path . --import

# 2) 게임을 잠깐 실행해서 런타임 오류 확인 (출력에 SCRIPT ERROR / ERROR가 없어야 함)
godot --headless --path . --quit-after 600

# 2-1) 코어 루프 자동 플레이 (마지막 줄이 SMOKE OK, SCRIPT ERROR가 없어야 함)
#      타이틀 화면만 도는 2)와 달리 집·맵·운전·대화·정산·업그레이드·저장 경로를 전부 실행한다.
#      user://save.json을 지우므로 동시에 여러 개 돌리지 않는다.
#      뒤에 `-- --seed=N`을 붙이면 다른 랜덤 이벤트(긴급·특가·추가 부탁)를 탄다.
#      --headless를 빼고 `-- --shots=<절대 경로>`를 붙이면 주요 화면 스크린샷을 저장한다.
godot --headless --path . --fixed-fps 60 --script res://tests/smoke_loop.gd

# 2-2) 소리 파일 확인 (헤드리스는 소리를 재생하지 않으므로 임포트 결과만 본다. 마지막 줄이 AUDIO OK)
#      소리를 바꾼 뒤: python tools/gen_audio.py -> 1) -> 2-2)
godot --headless --path . --script res://tests/audio_check.gd

# 2-3) 납품 운전 코스 확인 (자동 운전으로 8개 코스를 연료가 남은 채·화물 60% 이상으로 도착, 입력 없어도 도착이나 견인으로 끝남. 마지막 줄 DRIVE OK)
godot --headless --path . --fixed-fps 60 --script res://tests/drive_bot.gd

# 3) 웹 내보내기 (에디터에서 Web 내보내기 템플릿을 먼저 설치)
mkdir -p build/web && godot --headless --path . --export-release "Web" build/web/index.html

# 3-1) 더블클릭으로 여는 단일 html (제출용). wasm·pck를 압축해 넣는다. 결과: build/jodal_rookie.html (~18MB)
#      + build/jodal_rookie.zip (html + 실행 방법.txt). 다른 사람에게 보낼 때는 zip을 보낸다
#      (메일·메신저가 .html 첨부를 막거나 바꾸는 경우가 있다).
python3 tools/make_single_html.py   # Windows는 python

# 3-2) Streamlit Community Cloud 배포용 복사 (배포할 때만. deploy/jodal_rookie.html.gz를 커밋·push하면 자동 재배포)
#      streamlit_app.py가 이 파일을 components.html iframe으로 전체 화면에 띄운다. 로컬 확인: streamlit run streamlit_app.py
python tools/pack_streamlit.py

# 4) 로컬 서버로 확인. 같은 와이파이의 휴대폰에서 http://<PC IP>:8000 으로 접속
python3 -m http.server 8000 -d build/web   # Windows는 python
```

단일 html은 `file://`에서 열리므로 페이지 출처가 `null`이다. 그래서 `tools/make_single_html.py`가
`fetch`(wasm·pck), 오디오 워클릿(blob 대신 data: 주소), 서비스 워커 조회를 가로챈다.
실행이 안 되는 환경(미리보기 화면, 그래픽 가속 꺼짐, 오래된 브라우저, 전송 중 잘린 파일)에서는
검은 화면 대신 한국어 안내 상자가 뜬다(`tools/make_single_html.py`의 HELP_HTML·GUARD, 이 문구만 예외로 도구에 있다).
웹 내보내기를 다시 할 때마다 3-1)도 다시 돌린다. Godot 버전을 올리면 `file://`로 열어 콘솔 오류를 확인한다.

`--import`가 없는 버전이면 `godot --headless --path . --editor --quit`을 쓴다.
기능을 끝낼 때마다 1), 2), 2-1)을 돌려 오류가 없음을 확인한 뒤 커밋한다.
릴리스 빌드는 스크립트 오류를 콘솔에 찍지 않는다. 웹에서만 나는 문제는 `--export-debug`로 내보내 브라우저 콘솔을 본다.

웹 주의: `JavaScriptBridge.eval()`은 JS bool을 int, 숫자를 float로 돌려준다. `== true` 비교는 런타임 오류이므로 문자열로 받는다.
웹 소리: 단일 스레드 웹은 소리를 Web Audio 샘플로 재생한다. 오디오 버스를 실행 중에 추가하면(`AudioServer.add_bus`)
버스끼리 순환 연결되어 **모든 소리가 무음**이 된다. 버스는 Master 하나만 쓰고 볼륨은 플레이어의 `volume_db`로 조절한다.
소리를 고친 뒤에는 웹 빌드를 브라우저에서 실제로 들어 본다(헤드리스 테스트는 소리를 재생하지 않는다).
테스트 스크립트(`extends SceneTree`)에서 `RaceGame`·`QcGame`처럼 오토로드를 쓰는 클래스 이름을 직접 쓰면
오토로드보다 먼저 컴파일되어 테스트가 시작조차 안 되고 멈춘다. `load(경로)`로 불러 `set()`으로 다룬다.
웹에서는 `emulate_touch_from_mouse` 때문에 `DisplayServer.is_touchscreen_available()`이 항상 true다. 터치 판정은 `GameState.is_touch_device()`만 쓴다.

## 구조

```
project.godot            해상도, 렌더러, autoload
export_presets.cfg       Web 프리셋 (단일 스레드, build/web/index.html)
scripts/autoload/        전역 싱글톤 (project.godot의 순서대로 로드)
  input_setup.gd         입력 액션 등록
  ui_theme.gd            폰트·색·Theme, make_label(), edge_margin()
  game_state.gd          저장되는 모든 상태, 피로도/컨디션, 인벤토리, 저장/불러오기(user://save.json)
  item_db.gd             아이템·구내식당 메뉴(MEALS) 정의와 효과 적용
  scene_router.gd        페이드 장면 전환, next_spawn
  dialogue.gd            대화창 say()/choose()/toast() (크림색 말풍선), 전체 화면 창 플래그 set_overlay()
  sound.gd (마지막)      배경음악 play_bgm()(맵별 MAP_BGM, 크로스페이드)·효과음 play(), 음량(배경음악·효과음 0~10, user://settings.json).
                         버튼은 자동으로 confirm 소리(meta "sfx_off"면 제외), 보상 팝업은 글자·색으로 소리를 고른다
scripts/systems/
  story.gd (autoload)    코어 루프, 수요기관(DESTINATIONS), NPC 대화, 자판기·구내식당, 메뉴, 인트로, 강제 퇴근
  korean.gd              조사(을/를, 이/가, 로/으로...), 천 단위 쉼표
  sprite_util.gd         스프라이트 시트 -> SpriteFrames
scripts/data/task_data.gd  업무(조달 요청) 데이터, 검수 등급(요구 품질 기준), 품질 검사 공식(qc_*), 시설 업그레이드
scripts/data/track_data.gd 납품 운전 코스 8개(수요기관마다 2개, 직선 5차선 길이), 테마(도심·공원·숲·강변·해안·시골 마을·시장·신도시), 학교 쉬운 설정(EASY)
scripts/world/
  map_base.gd            맵 공통: ASCII 레이아웃 -> 타일, NPC·오브젝트·간판(signs)·출구·플레이어·카메라·HUD·터치 UI 배치,
                         목표 화살표(Story.objective_target), HUD를 피하는 카메라, 작은 방은 2배 확대
  tiles.gd               코드로 만드는 TileSet, ASCII 범례, 충돌 타일
  interactable.gd        조사 가능한 오브젝트 (나라장터 PC, 자판기, 납품 차량...)
  maps/home_map.gd       주인공 집 (18x8): 침대·옷장·냉장고, 현관 -> 청사
  maps/office_map.gd     정부청사 (40x24): 1층 현관 -> 집(퇴근)
  maps/school_map.gd     수요기관: 한빛초등학교 (28x18)  ┐ 위쪽 건물 안, 외관 1줄(간판·유리문),
  maps/fire_map.gd       수요기관: 한빛소방서 (28x14)    │ 아래쪽 앞마당(꽃 잔디·납품 차량 arrival),
  maps/clinic_map.gd     수요기관: 한빛보건소 (28x14)    │ 맨 아래 출구 -> 청사 주차장
  maps/center_map.gd     수요기관: 한빛동 행정복지센터 (28x14) │
  maps/nursing_map.gd    수요기관: 한빛시립요양원 (28x14)  │ (11/18 추가 3곳, 외관 타일 6·7·8)
  maps/police_map.gd     수요기관: 한빛경찰서 (28x14)     │
  maps/hospital_map.gd   수요기관: 한빛시립병원 (28x14)   ┘
  maps/lab_map.gd        품질검사실 (18x8, 2배 확대): 청사 로비 왼쪽 벽 문, 검사대(J)·컨베이어·서 검사관
scripts/actors/          player.gd(4방향 이동·달리기·상호작용),
                         npc.gd(CharacterBody2D. 집 칸에서 3칸 안을 한 칸씩 4방향으로 돌아다님. 김 팀장·식당 이모·서 검사관·
                         담당자(receiver)는 제자리 = `Story.STATIONARY`/`npc_wanders()`. 벽·출구·스폰·오브젝트 주변 칸은
                         `MapBase.npc_can_enter()`가 막는다. 대화·창이 열리면 멈춤),
                         character_visual.gd(피부·옷 바탕·옷 색·얼굴·머리 5레이어, 색은 틴트)
scripts/ui/              title_screen.gd, character_create.gd, hud.gd, touch_controls.gd,
                         procurement_pc.gd(나라장터 모니터 창: 업체 선택), meal_window.gd(구내식당 식사 장면·결과),
                         event_window.gd(짧은 이벤트 장면 창: carry = 일 돕기, inspect = 검사관 결과)
                         phone_menu.gd(Esc 메뉴 = 스마트폰 홈 화면: 시계·체력 배터리·앱 6개(phone_apps.png)·오늘 할 일 알림)
                         volume_window.gd(소리 설정 창: 배경음악·효과음 음량. 타이틀 [소리 설정]과 폰 [소리] 앱, Story.volume_settings())
                         title_screen.gd: 마을(title_town.png 2배) 가운데 조달청 건물(간판·깃발에 픽셀 로고), 지붕 위 타이틀 간판
                         splash_screen.gd(메인 장면): 조달청 로고(assets/splash/pps_logo.png) -> Story.CREDIT("Made By 이승훈") -> 타이틀. 키·탭으로 넘김
scripts/minigames/race_game.gd   납품 운전(scenes/minigames/drive.tscn, 11/20 고속도로식으로 개편): 위에서 내려다보는 5차선 직선 도로를
                                 조달청 -> 수요기관 건물까지 달린다. 차선형 캐주얼 레이싱의 규칙만 참고(이름·그림·화면 구성은 자체 제작).
                                 자동 가속, ←→ 한 칸씩 차선 변경, ↓ 감속(BRAKE_SPEED), ↑·Space 점프(차·울타리·기름 넘기, 차 지붕에 착지하면 한 번 더),
                                 Q·Shift 터보(게이지 완충 또는 가방의 에너지 드링크: 잠깐 빠르고 무적, 앞차는 갓길로 비킴).
                                 연속 추월 = 콤보(점수·터보 게이지), 앞차 바로 뒤에서 빠져나가며 추월 = 아슬아슬(2배), 앞차 뒤에 붙으면 슬립스트림.
                                 연료는 계속 줄고 체크포인트 4곳·연료통이 채운다. 바닥나면 견인 = task.late(보고 때 평판 -4).
                                 공정 규칙: 새 차 줄은 항상 2차선 이상 비움, 울타리 옆에는 차를 안 만들고 차가 울타리를 피해 감,
                                 장애물은 화면에 들어오기 전 위쪽 가장자리에 "!", 앞차 차선 변경은 플레이어와 멀 때만 깜빡이 후.
                                 결과: 화물 상태 -> 납품 품질, 별 = 주운 별 + 남은 연료·점수 보너스. 문구는 Story.DRIVE_TEXT.
                                 출발·도착 건물 그림은 assets bld_<id>.png(tools/gen_placeholders.py가 타이틀 마을에서 잘라 냄)
scripts/minigames/qc_game.gd     품질 검사: 컨베이어 불량품 골라내기(흠집·얼룩·금·빠진 부분). 찾은 불량만큼 납품 품질 상승
scenes/                  각 .tscn은 루트 노드 + 스크립트만 있다. 자식은 스크립트가 만든다.
assets/fonts/            레벨업 폰트 Regular·Bold (OFL)
assets/sprites/placeholder/  도트 (tools/gen_placeholders.py로 생성). 나르미·달이는 공식 마스코트 그림(tools/ref/mascots.png)을 보고 그린 픽셀 격자(NARUMI·DARI),
                         조달청 로고는 tools/ref/pps_logo.jpg를 픽셀화(make_logo, 타이틀 간판·깃발, 출입증 pps_logo.png)
assets/splash/           스플래시용 조달청 로고 원본(축소본)
assets/audio/            임시 칩튠 BGM 3곡(bgm_home·town·drive, 루프)·효과음 21종 (tools/gen_audio.py로 합성, QOA 압축 임포트)
tests/smoke_loop.gd      헤드리스 코어 루프 테스트 (웹 내보내기에서 제외)
tests/audio_check.gd     소리 파일 임포트 확인 (BGM 루프, 효과음 존재)
tests/drive_bot.gd       납품 운전 8개 코스 자동 도착 확인
tools/, docs/            Godot이 무시함(.gdignore)
streamlit_app.py, requirements.txt, .streamlit/, deploy/   Streamlit Community Cloud 배포 (README "Streamlit 배포")
```

### 하루 (story.gd)

집(07:30, 첫날은 알람 인트로) -현관-> 청사 로비(09:00, 첫날은 달이 인트로) -> 업무 `DAILY_TASKS`건
-> 1층 현관으로 퇴근 -> 집 저녁 정산(`GameState.day_log`) -> 침대에서 잠(`GameState.end_day`, 일당) -> 다음 날.
피로도 100이면 강제 퇴근(`GameState.forced_leave`): 나르미 대사 -> 집 저녁 정산. 진행 중 업무는 다음 날로 넘어간다.
`GameState.map_id`는 현재 맵이고 "이어서 출근하기"는 그 맵에서 재개한다.

### 코어 루프 (story.gd의 `Step`)

`NONE` -팀장 대화(업무 배정, 긴급 판정)-> `ACCEPTED` -나라장터 PC에서 업체 선택(특가 판정)-> `VENDOR_CHOSEN`
-로비 왼쪽 품질검사실 검사대-> 품질 검사(`task.qc_done`, `qc_quality`) -주차장 차량-> 납품 운전 -> `ARRIVED`(수요기관 앞마당 도착) -담당자(receiver)-> 검수 -> `DELIVERED`(추가 부탁 판정)
-청사 복귀, 팀장 보고-> 보상(팀 예산 = 아낀 예산, 평판, 경험치, 성과급) -> `NONE`.
검수 점수 = 납품 품질(업체 품질 + 품질 검사로 바꾼 불량품 몫, `Story.delivered_quality()`) × 화물 상태. 업무의 `required` 이상이면 보통, +15 이상이면 우수(`TaskData.grade`).
팀 예산은 하단 바 [성장]에서 시설 업그레이드(`TaskData.UPGRADES`)에 쓴다.

수습 스토리(11/19): `GameState.tasks_completed` 0~14는 `TaskData.STORY_TASK_IDS` 순서의 고정 업무(3건 = 1챕터),
15번째 보고 뒤 `Story._play_ending()`, 이후 자유 모드(`pick_index`·랜덤 긴급). 일수가 아니라 완료 업무 수로 판정한다(강제 퇴근 대비).
대사는 `Story.STORY_EPISODES`(업무별)·`STORY_CHAPTERS`(출근 브리핑·퇴근 일기)·`AMBIENT_AFTER`(납품 후 주민, 플래그 `done_<업무 id>`)·`ENDING_STORY`.
스토리 대사의 `%s`는 `Story._fmt()`가 `replace`로 이름을 넣는다(`%` 연산자 금지).
업체 선택은 `ProcurementPC`(모니터 창), 식사는 구내식당 식권 발매기 -> `MealWindow`(하루 `ItemDB.MEALS_PER_DAY`끼).
두 창은 `Dialogue.set_overlay()`로 입력을 잠그고 터치 UI·하단 바를 숨긴다. 문구는 전부 Story가 넘긴다.

### 확장하는 법

- 맵 추가: `MapBase`를 상속한 스크립트 + 루트만 있는 `.tscn`. `SceneRouter.MAPS`에 id 등록.
  레이아웃 문자열은 모든 행 길이가 같아야 한다. 범례는 `Tiles.LEGEND`.
- 수요기관 추가: 맵(위 방식, `signs()`·`parked_truck()`·arrival 스폰·맨 아래 출구) + `Story.DESTINATIONS`에
  이름·담당자(receiver)·대사 + `Story.NPCS`·`tools/gen_placeholders.py`의 `human_npc`로 사람 추가.
  담당자가 카운터 뒤면 `npcs()` 항목에 `reach`, 테스트용 `from`(말 거는 칸)을 준다.
  운전 코스는 `TrackData.DESTINATION_TRACKS`, 도착 건물 그림은 `bld_<id>.png`(`make_extra_buildings()`),
  테스트는 `tests/smoke_loop.gd`의 `PLACES`. 업무는 장소를 먼저 고른다(`TaskData.pick_index`, 직전 장소 제외).
- 업무 추가: `TaskData.TASKS`의 **맨 뒤에** 항목 추가(저장 파일이 업무 번호를 기억한다)(`destination`, `required`, `fragile` 포함). 업체 3곳은 "기준을 넘는 가장 싼 업체"가
  업무마다 달라지게 값을 잡는다.
- 업그레이드 추가: `TaskData.UPGRADES` + 효과는 `GameState.upgrade_level(id)`를 읽는 곳(Story, 운전)에 넣는다.
- NPC 추가: `Story.NPCS`에 이름·스프라이트·색, 맵의 `npcs()`에 위치, `Story.talk()`에 대화.
  기본은 돌아다닌다. 제자리에 두려면 `Story.STATIONARY`에 넣거나 `npcs()` 항목에 `"wander": false`.
  사람 스프라이트는 플레이어와 같은 3x4 걷기 시트(`human_npc`), 마스코트는 1줄 2프레임.
- 원문철 변호사(청사 주차장): `Story.DASHCAM_QUIZ` 블랙박스 퀴즈. 운전 상식만 쓰고 법 조문·숫자는 넣지 않는다.
- 아이템 추가: `ItemDB.ITEMS` + 아이콘, 판매처는 `Story.VENDING_ITEMS`. 식사 메뉴는 `ItemDB.MEALS` + 3프레임 음식 그림, 순서는 `Story.TICKET_MEALS`.
- 외형 추가: 헤어·옷은 `tools/gen_placeholders.py`의 `HAIR_*`/`OUTFITS`에 그림을 추가하고
  `GameState.HAIR_STYLE_COUNT`/`OUTFIT_STYLE_COUNT`, `Story.LOOK_NAMES`를 맞춘다. 색은 `GameState`의 색 배열에 추가.
- 진짜 아트로 교체: 같은 파일명·같은 프레임 배치(`tools/gen_placeholders.py` 상단 설명)로 덮어쓰면 된다.
  타일은 `TILES` 순서 = `Tiles` enum 순서(뒤에만 추가). `python tools/gen_placeholders.py <png>`는 미리보기 시트도 만든다.
  에디터에서 타일을 칠하고 싶으면 맵 씬에 TileMapLayer를 추가하고 `layout()`을 비우는 방향으로 바꾼다.

## 알려진 빈틈 (TODO)

- 대화 초상화 없음 (이름 색만 있음).
- 터치 UI 여백이 고정값. `DisplayServer.get_display_safe_area()`로 노치 대응 필요 (P1).
- 소리는 코드로 합성한 임시 칩튠이다. 진짜 음원으로 바꾸려면 같은 파일명으로 덮어쓴다(BGM은 .import의 loop_mode=2 유지).
  웹에서는 첫 터치 이후에만 재생된다(타이틀 화면의 첫 탭에서 시작, `Sound.unlocked`).
- P1 NPC(선배 주무관, 업체 사장님, 식당 이모)는 배치만 되어 있고 대사가 짧다.
- 모바일 웹에서 이름 입력은 브라우저 `prompt()`로 처리한다. 실기에서 확인 필요.
