# Excalidraw Visualization Specification (`excalidraw_gen.py`)

Obsidian Excalidraw 플러그인(`excalidraw-plugin: parsed`) 호환 `.excalidraw.md` 다이어그램 생성·검증 명세.

---

## 1. 입력 JSON 스펙 구조

```json
{
  "title": "다이어그램 제목",
  "direction": "LR",
  "tags": ["architecture", "wiki"],
  "sources": ["[[overview]]"],
  "groups": [
    { "id": "grp-core", "label": "Core Layer", "color": "#1971c2" }
  ],
  "nodes": [
    {
      "id": "node-a",
      "label": "Raw Sources\n(불변 원본)",
      "kind": "source",
      "group": "grp-core",
      "link": "[[three-vendor-ssot]]"
    }
  ],
  "edges": [
    {
      "from": "node-a",
      "to": "node-b",
      "label": "ingest",
      "style": "solid",
      "bidirectional": false
    }
  ]
}
```

### 최상위 필드
| 필드 | 타입 | 기본값 | 설명 |
| :--- | :--- | :--- | :--- |
| `title` | string | `"Diagram"` | 프론트매터 `id` 슬러그 및 설명 기준 제목 |
| `direction` | `"LR"` \| `"TB"` | `"LR"` | 자동 배치 방향 (`LR`: 좌→우, `TB`: 상→하) |
| `tags` | string[] | `[]` | 프론트매터 `tags`에 `excalidraw`와 함께 병합 |
| `sources` | string[] | `[]` | 연관 위키 페이지 또는 출처 링크 |
| `groups` | object[] | `[]` | 배경 프레임 그룹 (`id`, `label`, 선택 `color`) |
| `nodes` | object[] | `[]` | 다이어그램 노드 목록 |
| `edges` | object[] | `[]` | 노드 간 화살표 연결 목록 |

### 노드 필드 (`nodes[]`)
| 필드 | 타입 | 필수 | 설명 |
| :--- | :--- | :---: | :--- |
| `id` | string | ✅ | 고유 식별자 (결정적 시드 계산에 사용) |
| `label` | string | ✅ | 도형 내부 텍스트 (`\n` 줄바꿈 및 CJK 폭 자동 계산) |
| `kind` | string | — | 시맨틱 팔레트 키 (기본 `"default"`) |
| `shape` | string | — | `"rectangle"` \| `"ellipse"` \| `"diamond"` (`kind` 기본값 덮어쓰기) |
| `group` | string | — | 소속 `groups[].id` |
| `link` | string | — | 클릭 가능한 위키 링크 (`[[page]]`) 또는 URL (`## Element Links` 등록) |
| `x`, `y` | number | — | 수동 좌표 (생략 시 방향·의존 계층 기반 자동 배치) |
| `width`, `height` | number | — | 수동 크기 (생략 시 텍스트 길이·줄 수 기반 자동 계산) |

### 엣지 필드 (`edges[]`)
| 필드 | 타입 | 기본값 | 설명 |
| :--- | :--- | :--- | :--- |
| `from`, `to` | string | — | 출발·도착 `nodes[].id` (필수) |
| `label` | string | `""` | 화살표 중앙 바인딩 라벨 |
| `style` | `"solid"` \| `"dashed"` \| `"dotted"` | `"solid"` | 화살표 선 스타일 |
| `bidirectional` | boolean | `false` | 양방향 화살촉 여부 |

---

## 2. 시맨틱 팔레트 (`KIND_STYLES`)

| `kind` | 기본 도형 | Stroke | Background | 용도 |
| :--- | :--- | :--- | :--- | :--- |
| `source` | `rectangle` | `#1971c2` | `#d0ebff` | `raw/` 원본·외부 입력·데이터 소스 |
| `concept` | `rectangle` | `#2f9e44` | `#d3f9d8` | 핵심 개념·패턴·규칙 |
| `entity` | `rectangle` | `#6741d9` | `#e5dbff` | 모듈·도구·에이전트·컴포넌트 |
| `synthesis` | `rectangle` | `#e8590c` | `#ffe8cc` | 종합 결론·리포트·산출물 |
| `decision` | `diamond` | `#c2255c` | `#ffdeeb` | 분기 조건·아키텍처 판단(ADR) |
| `warning` | `rectangle` | `#c92a2a` | `#ffe3e3` | 모순·리스크·차단 가드·주의점 |
| `system` | `rectangle` | `#0c8599` | `#c5f6fa` | 런타임·호스트·외부 서비스 |
| `default` | `rectangle` | `#1e1e1e` | `#f1f3f5` | 일반 항목 |

---

## 3. Obsidian `.excalidraw.md` 포맷 규격

1. **Frontmatter**: `excalidraw-plugin: parsed`, `type: excalidraw`, `tags: [excalidraw, ...]` 필수.
2. **경고 배너**: `==⚠ Switch to EXCALIDRAW VIEW in the MORE OPTIONS menu of this document. ⚠==`
3. **`# Excalidraw Data`**:
   - `## Text Elements`: 각 텍스트 블록 끝에 ` ^<text_id>` 부착 (Obsidian 검색·링크 인덱싱 대상).
   - `## Element Links`: 도형 클릭 링크를 `^<shape_id>: [[<target>]]` 형식으로 기록 (`link` 속성 존재 시 생성).
   - `%% ... %%` 내부 `## Drawing` + ```` ```json ````: Excalidraw v2 JSON (`type: "excalidraw"`, `version: 2`, `elements`, `appState`, `files`).
4. **양방향 바인딩 규칙**:
   - 도형 내부 텍스트: `shape.boundElements`에 `{"id": text_id, "type": "text"}` 등록 + `text.containerId = shape.id`.
   - 화살표 연결: `arrow.startBinding`/`endBinding`에 대상 `elementId` 지정 + 양쪽 도형 `boundElements`에 `{"id": arrow_id, "type": "arrow"}` 등록.
5. **위키 임베드 및 포매터 보호**:
   - 본문 삽입 문법: `![[<name>.excalidraw]]` (또는 경로 포함 `![[visuals/<name>.excalidraw]]`).
   - `agents/shared/hooks/hook.py`는 `.excalidraw.md`와 `.excalidraw`를 Prettier 자동 포매팅에서 제외해 `%%...%%` 및 `^id` 손상을 방지.

---

## 4. 권장 시각화 패턴 (5종)

1. **아키텍처 계층도 (`LR`, `groups` 활용)**: `system`·`entity`·`warning` 조합으로 레이어 간 데이터/제어 흐름 표현.
2. **개념 관계맵 (`LR` 또는 `TB`)**: `concept` 노드와 `link: "[[...]]"`로 위키 페이지 탐색 허브 구성.
3. **의사결정 흐름도 (`TB`, `decision` 다이아몬드)**: 조건 분기(`yes`/`no` 라벨)와 결과 경로 시각화.
4. **트레이드오프·비교도 (`groups` 2~3열 배치)**: 대안별 장단점(`concept` vs `warning`) 및 최종 선택(`synthesis`) 대비.
5. **타임라인·파이프라인 (`LR`)**: 단계별 순차 처리(`source` → 처리 → `synthesis`)와 피드백 루프(`dashed`) 표현.
