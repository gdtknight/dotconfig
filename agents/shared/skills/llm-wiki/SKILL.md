---
name: llm-wiki
description: "Obsidian + Excalidraw 연동 LLM Wiki 구축·운영 공용 스킬. \"/llm-wiki\", \"위키 초기화\", \"위키에 인제스트해줘\", \"위키 쿼리\", \"위키 린트\", \"Excalidraw 다이어그램으로 정리해줘\" 요청이나 작업 경로에 wiki/index.md와 wiki/log.md가 존재할 때 사용. Raw(불변 원본) / Wiki(지속 누적 마크다운 + Excalidraw 시각화) / Schema 3계층으로 개인·프로젝트 지식 베이스를 유지보수한다."
---

# /llm-wiki

Obsidian과 Excalidraw 시각화를 결합해 개인·프로젝트 지식 베이스를 지속적으로 누적·연결·검증하는 공용 스킬.

---

## 1. 3계층 아키텍처

| 계층 | 경로 | 소유·수정 권한 | 역할 |
| :--- | :--- | :--- | :--- |
| **Raw Sources** | `raw/`, `raw/assets/` | 사용자 큐레이션 (LLM 수정 금지) | 기사·논문·메모·로컬 이미지 등 불변 원본 |
| **Wiki** | `wiki/` (`index.md`, `log.md`, `overview.md`, `sources/`, `entities/`, `concepts/`, `syntheses/`, `visuals/`) | LLM 전담 생성·갱신 | 요약·엔티티·개념·종합·`.excalidraw.md` 다이어그램 |
| **Schema** | `WIKI_SCHEMA.md` | 사용자·LLM 공동 진화 | 볼트 구조, 프론트매터, 인제스트·시각화·린트 규약 |

---

## 2. 스크립트 경로 해석 규칙

번들 스크립트는 스킬 디렉터리(`SKILL.md` 인접 `scripts/`) 기준으로 호출.

- Claude Code: `~/.claude/skills/llm-wiki/scripts/`
- Gemini / Antigravity: `~/.gemini/config/skills/llm-wiki/scripts/`
- Codex CLI: `~/.codex/skills/llm-wiki/scripts/`
- 저장소 내부 직접 실행 시: `agents/shared/skills/llm-wiki/scripts/`

---

## 3. 핵심 워크플로우 (5 Operations)

### 3.1 `init <dir>` — 위키·Obsidian 볼트 초기화
- 기본 명령:
  ```bash
  python3 "<skill_dir>/scripts/wiki_tool.py" init "<target_dir>" --name "<Title>" --domain "<Domain>"
  ```
- 코드 저장소 내 `templates/` 중복 생성을 피할 때는 `--no-templates` 플래그 추가.
- 개인 Obsidian 볼트 기본 경로(macOS iCloud): `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/<VaultName>`

### 3.2 `ingest <source>` — 원본 인제스트 및 위키 통합
1. **원본 정독**: `raw/` 내 대상 문서 확인 (`raw/assets/` 인라인 이미지는 텍스트 판독 후 이미지 파일 별도 시각 확인).
2. **핵심 추출 및 대조**: 주장·근거·엔티티·개념 추출 후 `wiki/index.md`와 기존 페이지를 대조해 보강·모순 여부 식별 (`accuracy.md` 준수).
3. **소스 요약 생성**: `wiki/sources/<slug>.md` 작성 (상단 YAML Frontmatter 필수).
4. **지식 누적 갱신**: 관련 `wiki/entities/*.md`, `wiki/concepts/*.md` 생성 또는 수정 및 `[[wikilink]]` 상호 연결. 모순 발견 시 기존 내용을 임의 삭제하지 않고 양쪽 출처 병기.
5. **시각화 생성(해당 시)**: 구조·흐름·관계도가 유효한 경우 `scripts/excalidraw_gen.py`로 `wiki/visuals/<slug>.excalidraw.md` 생성 후 `![[<slug>.excalidraw]]` 임베드.
6. **카탈로그·로그 갱신**: `wiki/index.md` 항목 추가·요약 갱신 후 `wiki_tool.py log <root> ingest "<Title>"` 실행.

### 3.3 `query "<question>"` — 질의 응답 및 역축적 (File-back)
1. **색인 우선 탐색**: `wiki/index.md`에서 관련 페이지 선별 후 원문 페이지 정독 (대규모 볼트는 `qmd` CLI/MCP 병행).
2. **근거 기반 답변**: `[[Page]]` 출처를 명시해 종합 답변 작성.
3. **가치 있는 산출물 역축적**: 비교표, 심층 분석, 신규 연결 관계는 `wiki/syntheses/<slug>.md`로 저장하고 필요 시 `wiki/visuals/<slug>.excalidraw.md` 시각화 추가 후 `index.md`·`log.md` 갱신.

### 3.4 `visualize <topic|pages>` — Excalidraw 다이어그램 생성·갱신
1. [excalidraw-spec.md](references/excalidraw-spec.md) 규격에 맞춰 입력 JSON 스펙 작성.
2. 생성·검증 실행:
   ```bash
   python3 "<skill_dir>/scripts/excalidraw_gen.py" generate --input spec.json --output "<root>/wiki/visuals/<name>.excalidraw.md"
   python3 "<skill_dir>/scripts/excalidraw_gen.py" validate "<root>/wiki/visuals/<name>.excalidraw.md"
   ```
3. 관련 위키 페이지에 `![[<name>.excalidraw]]` 임베드 및 `wiki/index.md`, `wiki/log.md`(`visualize`) 갱신.
4. `.excalidraw.md` 파일의 `%%...%%` JSON 블록은 수동 편집 대신 `excalidraw_gen.py` 재실행 우선 (`hook.py`가 Prettier 자동 포매팅에서 제외).

### 3.5 `lint` — 정적 무결성 + 의미 일관성 점검
1. **정적 점검 실행**:
   ```bash
   python3 "<skill_dir>/scripts/wiki_tool.py" lint "<root>"
   ```
   - 프론트매터(`id`, `type`, `tags`, `updated`) 누락, 깨진 `[[wikilink]]`·`![[embed]]`, 고아 페이지, `index.md` 누락/유령 항목, `.excalidraw.md` 바인딩 무결성 일괄 검사.
2. **의미 점검(LLM 수행)**:
   - 페이지 간 상충 주장, 최신 소스로 대체된 구식 서술, 반복 언급되나 독립 페이지가 없는 핵심 개념, 후속 탐구 질문 및 추가 출처 후보 도출.
3. **로그 기록**: `wiki_tool.py log <root> lint "<Summary>"` 실행.

---

## 4. `graphify` 연계 원칙

- **`graphify` 역할**: 코드베이스·대규모 코퍼스의 AST 구조 추출, 커뮤니티 탐지, GraphRAG 질의.
- **`llm-wiki` 역할**: 서사적 종합, 엔티티·개념의 점진적 축적, 모순 추적, Obsidian + Excalidraw 기반 사람-에이전트 협업 시각화.
- 코드 저장소에서는 `graphify`로 구조 그래프를 파악하고, 아키텍처 결정·도메인 지식·시각 다이어그램은 `llm-wiki`로 누적.

---

## 5. 참조 문서

- Excalidraw JSON 스펙·시맨틱 팔레트·시각화 패턴: [references/excalidraw-spec.md](references/excalidraw-spec.md)
- Obsidian Frontmatter·Dataview·Web Clipper 규약: [references/obsidian-conventions.md](references/obsidian-conventions.md)
