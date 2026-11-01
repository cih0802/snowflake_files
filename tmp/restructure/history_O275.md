## O275 — 문서정리 = 워크스페이스 목적별 재편 4-A·4-B·4-C (2026-10-31 · TRIALADMIN · TQ68205 · ㉡ 적용 · 확정위반 2(R1-7-2 병렬 edit · 골든 값 치환))

- 착수 = `--next O` → O275 · 원장 §1 행 선점(첫 쓰기) · 계획 정본 = `00_WORKSPACE_RESTRUCTURE_PLAN.md`(v2) · 지도 = `00_WORKSPACE_MAP.md`.
- 4-A = 26폴더 README 목적·상태(정본/참고/중복/구버전/임시) 기입 · 기존 README 13곳 누락 보완(append · 본문 바이트 보존) · 스냅샷 4A 27건 · 2000자·제목·행 게이트 PASS.
- 4-B = 사용자 결정 ㉠ 90 → 80·85 고정(현업 원본·납품물) ㉡ 고정 외 전부 이동 + 전후 매핑표 ㉢ 날짜<20261001 중복 → `_archive/` ㉣ archive 도 기재 · 최종 v3 = `MOVE_MAP.csv` 124행 · `MOVE_MAP_files.csv` 2,665행 · archive 4(80 사본 보유 · 2건 내용 상이 = 80 정제본) · v1·v2 스냅샷 = `_archive/RESTRUCTURE_20261031-pre/4B/`.
- 4-C = 70 → 60 → 10 → 30 → 50 → 40 → 20 → 루트 스크래치 · 2,665파일 · 스테이지 `cortex ws ls` 대조 신규 부재 0 · 원본 잔존 0 · 치환 499건 · 라이브 경로(`versions/live/cortex_project/agents/`·`12_agent개선과제/output/`) 배포 SQL 도 치환.
- 🔴 소실 1 = `30_output_share/_archive/20260830/20260826_아키텍처 지도 요약본.html.O104-pre`(33,169 B · copy Errno 2 후 원본 소실 · 동일 해시 사본 0) · 사용자 백업 보유 → 복원 대기 · `tmp/restructure/LOST_FILES.csv`.
- 사고·처방 ㉠ 샌드박스 재시작 3회 · 마운트 정지 1회 → 실행기 재개형(원본 부재+대상 실재 = 완료 · 해시 동일 쌍 = 원본 삭제 · 파일당 3회 재시도) + `chunk_move.py` 분할 ㉡ `_archive` 내부 배포 코드가 치환 대상에 잡힘 → 동결 영역 제외(치환 전 정지라 변경 0) ㉢ 골든 JSON 값 치환 → 4C 이전본 복원 + 문서 경로 키만 갱신.
- 게이트 = 제목 · 행 · 좌표 · 유형 · 조문순서 · census · Jinja PASS · 잔여 = 4-D 스킬 재생성 · 최종 잔존 스캔 · 4-E.
- read 미반환 0 · 재호출 0 · 인수인계 = `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0275-A.md`.
