---
name: 릴리스 준비 (Release)
about: dev 브랜치 변경사항을 main으로 반영하고 태그·릴리스 및 README/Wiki 동기화
title: "[Release] vX.Y.Z"
labels: release
---

## 릴리스 대상
- **버전**: `vX.Y.Z`
- **반영 경로**: `dev` → `main`

## 변경 요약
- 포함할 주요 기능, 버그 수정, 구조 변경 요약

## 문서 동기화 체크리스트 (필수)
- [ ] `README.md` / `README.en.md` 최신화 (블록당 단일 명령 `bash` 규칙 유지)
- [ ] GitHub Wiki (`gdtknight/dotconfig.wiki.git`) 관련 기술 페이지 업데이트
- [ ] `docs/ARCHITECTURE.ko.md` / `docs/ARCHITECTURE.md` 변경 여부 점검

## 배포 체크리스트
- [ ] Release PR (`dev` → `main`, `.github/PULL_REQUEST_TEMPLATE/release.md`) 생성
- [ ] `verify` CI 통과 및 `main` 머지 완료
- [ ] `main` 최신 커밋에 `vX.Y.Z` 태그 생성 및 푸시 → GitHub Release 자동 발행 확인
