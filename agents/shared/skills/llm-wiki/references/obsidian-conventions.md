# Obsidian & Knowledge Base Conventions

Obsidian 볼트 연동, YAML Frontmatter 표준, Dataview 동적 쿼리, 로컬 첨부 이미지 및 `qmd` 검색 연계 규약.

---

## 1. 볼트 표준 디렉터리 구조

```text
<vault-or-repo>/
├── WIKI_SCHEMA.md              # 도메인별 위키 규칙·워크플로우 정의
├── raw/                        # 불변 원본 (LLM 읽기 전용)
│   └── assets/                 # 로컬 다운로드 이미지·첨부 파일
├── wiki/                       # LLM 유지보수 지식 베이스
│   ├── index.md                # 주제별 카탈로그
│   ├── log.md                  # 시간순 append-only 작업 로그
│   ├── overview.md             # 전체 종합 및 진입 허브
│   ├── sources/                # 원본 1건당 요약 페이지
│   ├── entities/               # 인물·도구·시스템·프로젝트 페이지
│   ├── concepts/               # 개념·원리·패턴 페이지
│   ├── syntheses/              # 질의 결과·비교 분석 역축적 페이지
│   └── visuals/                # Excalidraw 다이어그램 (*.excalidraw.md)
└── templates/                  # 신규 노트 생성용 템플릿 (선택)
```

---

## 2. YAML Frontmatter 표준

모든 콘텐츠 페이지(`overview.md`, `sources/`, `entities/`, `concepts/`, `syntheses/`)는 아래 기본 필드를 포함.

```yaml
---
id: unique-kebab-slug
type: source | entity | concept | synthesis | overview
aliases: []
tags:
  - domain-tag
created: YYYY-MM-DD
updated: YYYY-MM-DD
sources:
  - "[[sources/example-source]]"
status: active # active | draft | needs-review | superseded
---
```

- `type: source` 페이지는 `raw_source: "raw/<filename>"` 필드 추가.
- 모순·충돌 확인 필요 페이지는 `status: needs-review` 표시 후 해결 시 `active`로 복구.

---

## 3. Dataview 쿼리 스니펫

Obsidian Dataview 플러그인 활성화 시 `wiki/index.md` 또는 대시보드 노트에 아래 쿼리 활용.

### 최근 인제스트 소스
````markdown
```dataview
TABLE updated AS "갱신일", status AS "상태", tags AS "태그"
FROM "wiki/sources"
SORT updated DESC
LIMIT 15
```
````

### 검토 필요 / 모순 플래그 페이지
````markdown
```dataview
LIST status
FROM "wiki"
WHERE status = "needs-review"
SORT updated DESC
```
````

### Excalidraw 시각화 자산 목록
````markdown
```dataview
TABLE updated AS "갱신일", sources AS "연관 문서"
FROM "wiki/visuals"
WHERE type = "excalidraw"
SORT updated DESC
```
````

---

## 4. Obsidian Web Clipper & 로컬 이미지 워크플로우

1. **Obsidian 설정**:
   - `Settings → Files and links → Default location for new attachments` → `In the folder specified below` 선택 후 `raw/assets` 지정.
   - `Settings → Hotkeys` → `Download attachments for current file` 단축키 바인딩 (예: `Cmd+Shift+D`).
2. **클리핑 절차**:
   - Web Clipper로 웹 문서를 `raw/`에 마크다운으로 저장.
   - `Download attachments for current file` 실행으로 외부 URL 이미지를 `raw/assets/`에 로컬 저장.
3. **LLM 읽기 규칙**:
   - 텍스트 본문을 먼저 읽은 뒤 참조된 `raw/assets/*` 이미지를 개별 시각 읽기 도구로 확인해 본문 맥락 보완.

---

## 5. iCloud 볼트 및 검색(`qmd`) 연동

- **macOS iCloud Obsidian 기본 경로**: `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/`
- **대규모 위키 검색(`qmd`)**:
  - 수백 페이지 이상으로 `wiki/index.md` 단일 스캔 한계가 올 경우 로컬 하이브리드 검색 엔진 `qmd`(BM25 + 벡터 + 리랭킹) CLI 또는 MCP 서버 연동 권장.
  - 소·중규모(수십~백여 소스)에서는 `wiki/index.md` 선탐색만으로 충분.
