# Claude Code 시작 방법

## 1. 프로젝트 폴더 준비 (한 번만)

```bash
# 압축 파일을 원하는 위치에 풀기 (예: ~/projects)
mkdir -p ~/projects && cd ~/projects
unzip ~/Downloads/jodal-rookie.zip
cd jodal-rookie

# git으로 기록 시작 (기능 단위로 되돌릴 수 있게)
git init && git add -A && git commit -m "Initial skeleton"

# Godot 실행 파일을 터미널에서 'godot'으로 부를 수 있게 (macOS 예시)
# echo 'alias godot="/Applications/Godot.app/Contents/MacOS/Godot"' >> ~/.zshrc && source ~/.zshrc
# Windows는 Godot exe가 있는 폴더를 PATH에 추가하거나, 아래 프롬프트에 exe 경로를 직접 적는다.

claude
```

Godot 4.5 이상 Standard 버전(.NET 아님)과 Web 내보내기 템플릿이 설치되어 있어야 한다.

## 2. 첫 프롬프트 (그대로 붙여넣기)

```
이 폴더는 2026 조달청 AI 게임·콘텐츠 공모전에 낼 Godot 웹 게임 "출근! 조달청 신입"이야.
마감은 11/22(일) 23:59이고, 11/19 밤까지 P0를 끝내야 해.

먼저 CLAUDE.md와 docs/plan.md를 읽고 규칙과 우선순위를 파악해 줘.
이 뼈대는 Godot 없이 작성돼서 아직 한 번도 실행되지 않았어. 그래서 오늘 할 일은 이거야:

1. `godot --headless --path . --import` 와 `godot --headless --path . --quit-after 600` 을 돌려서
   나오는 SCRIPT ERROR / ERROR 를 전부 고쳐 줘. 오류가 0이 될 때까지 반복해.
   (godot 명령이 없으면 나한테 Godot 실행 파일 경로를 물어봐.)
2. 코어 루프가 끝까지 도는지 코드로 따라가면서 확인해 줘:
   타이틀 -> 출입증 발급 -> 청사 인트로 -> 팀장 -> 나라장터 PC -> 주차장 차 -> 운전 -> 학교 행정실 -> 청사 복귀 -> 팀장 보고 -> 보상.
   막히는 지점이 있으면 고치고, 내가 직접 플레이해서 확인할 체크리스트를 만들어 줘.
3. Web 프리셋으로 build/web 에 내보내고, 휴대폰에서 테스트할 수 있게 로컬 서버 실행 방법을 알려 줘.
4. 고친 내용을 기능 단위로 커밋하고, docs/plan.md 의 상태 칸을 갱신하고, docs/ai-usage-log.md 에 기록해 줘.

작업 규칙:
- P0가 끝나기 전에는 P1/P2에 손대지 마.
- 게임 구조나 기획을 크게 바꿔야 하면 먼저 나한테 물어봐.
- 조달 정책 문구를 새로 쓸 때는 공식 출처를 확인하고, 확인 못 하면 넣지 마.
- 끝나면 오늘 한 일, 남은 P0, 내가 직접 해야 할 일(실기 테스트, 아트 등)을 짧게 정리해 줘.
```

## 3. 이후 날마다 쓰는 프롬프트

```
docs/plan.md 의 일정 기준으로 오늘(<날짜>) 할 일을 진행해 줘.
시작 전에 남은 P0/P1 목록과 오늘 계획을 보여 주고, 기능 하나 끝날 때마다
검증 명령(import, quit-after)을 돌려서 오류가 없을 때만 커밋해 줘.
plan.md 상태 칸과 ai-usage-log.md 도 갱신해 줘.
```

아트 교체할 때:

```
assets/sprites/placeholder/ 에 있는 임시 도트를 새 그림으로 바꿀 거야. 새 파일은 <폴더>에 있어.
tools/gen_placeholders.py 맨 위의 프레임 배치와 맞는지 확인하고, 안 맞으면 어떻게 고쳐야 하는지 알려 줘.
맞으면 같은 파일명으로 교체하고 게임에서 깨지는 곳이 없는지 확인해 줘.
```
