# AI 활용 기록 (신청서용)

공모전 요건: AI를 활용해 제작한 게임. 작업할 때마다 한 줄씩 추가한다.

| 날짜 | 도구 | 만든 것 | 사람이 한 일 |
| --- | --- | --- | --- |
| 2026-11-14 | Claude | 기획서 정리, 우선순위·일정 수립 | 게임 구상(장르, 주인공, 조력자, 그래픽 방향) |
| 2026-11-14 | Claude | Godot 프로젝트 뼈대(GDScript 전체), 맵 레이아웃, 대사 초안 | 기능 요구사항 정의 |
| 2026-11-14 | Claude | 임시 도트 생성 스크립트(tools/gen_placeholders.py) | - |
| 2026-11-17 | Claude Code | Godot 4.5.2 첫 실행 검증, 코어 루프 자동 플레이 테스트(tests/smoke_loop.gd), 웹 빌드 | 검증 범위 지시, 결과 확인 |
| 2026-11-17 | Claude Code | 버그 수정: 타이틀 첫 탭이 버튼까지 누름, 인트로·대화 겹침, PC 브라우저를 휴대폰으로 판정 | 작업 지시, 결과 검토 |
| 2026-11-17 | Claude Code | 직접 플레이 체크리스트(docs/playtest-checklist.md) | 실기 테스트(예정) |

## 외부 에셋 출처

| 에셋 | 출처 | 라이선스 |
| --- | --- | --- |
| 갈무리(Galmuri) 폰트 | https://github.com/quiple/galmuri (npm: galmuri 2.40.3) | SIL OFL 1.1 (assets/fonts/OFL-Galmuri.md) |
