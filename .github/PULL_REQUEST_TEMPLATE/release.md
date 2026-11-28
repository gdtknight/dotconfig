## 릴리스 개요
- **릴리스 버전**: `vX.Y.Z`
- **반영 경로**: `dev` → `main`

## 주요 포함 변경 사항
- 이전 릴리스 이후 `dev`에 누적된 핵심 기능·수정 요약

## 문서 동기화 체크리스트 (필수)
- [ ] `README.md` / `README.en.md` 최신 상태 반영 (단일 명령 코드 블록 유지)
- [ ] GitHub Wiki (`gdtknight/dotconfig.wiki.git`) 상세 문서 업데이트 완료
- [ ] `docs/ARCHITECTURE.ko.md` / `docs/ARCHITECTURE.md` 동기화 확인

## 검증 및 릴리스 절차
- [ ] `verify` CI 체크 통과 확인
- [ ] `main` 머지 후 `git tag vX.Y.Z && git push origin vX.Y.Z` 실행
- [ ] `.github/workflows/release.yml` 통해 GitHub Release 발행 확인

## 관련 릴리스 이슈
- Closes #
