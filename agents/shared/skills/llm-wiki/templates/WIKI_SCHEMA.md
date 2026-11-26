# {{WIKI_NAME}} Schema

**도메인**: {{DOMAIN}}  
**생성일**: {{DATE}}  

---

## 1. 계층 및 수정 규칙

1. **`raw/` (불변 원본 계층)**:
   - 외부 문서·노트·이미지(`raw/assets/`) 저장.
   - LLM은 읽기 전용으로만 접근하며 원본 파일 내용 수정·삭제 금지.
2. **`wiki/` (LLM 유지보수 지식 계층)**:
   - LLM이 요약(`sources/`), 엔티티(`entities/`), 개념(`concepts/`), 종합(`syntheses/`), 시각화(`visuals/*.excalidraw.md`), 색인(`index.md`), 로그(`log.md`)를 직접 작성·갱신.
   - 기술 문서는 서술형 종결어미와 1인칭을 배제한 간결한 명사형·개조식 문장 유지.
3. **`WIKI_SCHEMA.md` (운영 규약)**:
   - 도메인 특성에 맞춰 사용자·LLM이 함께 개정.

---

## 2. 파일·링크·시각화 규칙

- 파일명은 소문자 kebab-case 사용 (`예: three-vendor-ssot.md`).
- 모든 콘텐츠 페이지 상단에 YAML Frontmatter(`id`, `type`, `aliases`, `tags`, `created`, `updated`, `sources`, `status`) 필수 기재.
- 위키 내부 연결은 `[[wikilink]]` 사용 (동명 파일 충돌 시 `[[concepts/name]]` 형태 경로 표기).
- 구조·흐름·비교 시각화 시 `wiki/visuals/<slug>.excalidraw.md` 생성 후 본문에 `![[<slug>.excalidraw]]` 임베드.
- `.excalidraw.md`는 `excalidraw_gen.py`로 생성·검증하며 Prettier 등 범용 포매터 적용 금지.

---

## 3. 표준 작업 절차

- **Ingest**: `raw/` 원본 정독 → `wiki/sources/<slug>.md` 생성 → `entities/`·`concepts/` 갱신 및 모순 기록 → 필요 시 Excalidraw 시각화 추가 → `wiki/index.md` 갱신 → `wiki/log.md` 기록.
- **Query**: `wiki/index.md` 탐색 → 관련 페이지 정독 → 출처 포함 답변 → 재사용 가치 높은 종합/비교 결과는 `wiki/syntheses/`로 역축적.
- **Lint**: `wiki_tool.py lint` 정적 검사(깨진 링크·고아 페이지·프론트매터·Excalidraw 스키마) + 의미적 모순·구식 주장·개념 페이지 누락 점검 → `wiki/log.md` 기록.
