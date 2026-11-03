## O275-D~G — 실행순서 본문 · 게이트 3종 · 80·85 경로 · O275 종결 (2026-11-01 · TRIALADMIN · TQ68205 · ㉡ 적용 · 확정위반 1)

- D = 실행순서 4종 본문 경로 새 배치 치환 233건(사용자 결정) · 선택 게이트 실행 · `doc_line_length_gate` 대상 경로 3곳 정정(O275-B archive 오판 되돌림 잔존).
- F = `rename_stale_gate` PASS(`48_RBAC_SOURCE_ACCESS_ZL50263.sql:17` 잔존 뷰 실명 병기) · `live_change_gate` PASS(O272 행 `REBUILD:ALL 2026-10-30`) · `sv_unit_gate` PASS(`DEV_UNIT_PRICE_CRM` 예외 등재).
- G = A안 · `build_handoff.py` MOVE_MAP 변환 계층(80 내부 옛 이름 유지 · 574=574 · MISSING 0 · 본문 역변환) · 85 본문 37파일 109건 치환(80 문맥 54 제외).
- 🔴 확정위반 1 = 80 첫 `--apply` 를 사본 백업 없이 실행 → 420건 덮어씀(원본 기준 재빌드 · 직전 80 사본 복원 불가) · 새 경로 혼입 12파일 → 역변환 확장 재빌드로 해소.
- 🔴 실측 교훈 = 마운트 `>>` append 미지원 재발(최종 검증 스크립트 1회) → /tmp 로 우회.
- 검증 = 음성 63/63 · 브리핑 게이트 · 선택 게이트 7종 rc=0 · 원장 O275 🟢 종결 · 인수인계 `99_NEXT_SESSION-O0275-D.md`~`-G.md`.
