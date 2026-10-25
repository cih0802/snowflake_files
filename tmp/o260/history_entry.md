## O260 — 원천 DDL 재수령 반영(50_handoff 01~08) · 인수인계 게이트 기준값 갱신 · 요건3 광고 원천 개명 코드 반영 (2026-10-23 · TRIALADMIN(UM80684) · ㉡ 적용 · 확정위반 3)

- 계정 = `UM80684`(새 개발계 · `GN_DW` 미구축 · 실측 = `SELECT CURRENT_ACCOUNT()` · DATABASES 0) ⇒ 라이브 판정 0건(R2-8-4-c).
- 사용자 결정 = `BRONZE_CRM.TM_PM_MBRFEE_ACMSLT_TEST` 이관 제외(「test용으로 만든거라서 쓰지 않을거야」).
- ① 04~07 원천 반영 = GSC `SEARCH_CONSOLE_DATA2` 삭제 · AGENCY 개명 2 · COMMENT 원천 문안 13 · CRM 파일 포맷 신규 · AGENCY 시퀀스 order · ERP 스키마 COMMENT ⇒ 브론즈 64 · 총계 80.
- ② 01·02·03·08 수치 정정 · 02 = `_TEST` REVOKE + 기준값 쿼리 제외 조건 · 🔴 02 기존 구문 오류(`AS tables,z` + 백틱) 정정 · 02 `crm_tables 기대 50` → 53 · 07 A.4 `ERP 2` → 3.
- ③ `scripts/handoff_ddl_gate.py` = `EXCLUDE` 신설 · `STALE_TOKENS` 세대 갱신(현행 80/64 · 옛 81/65 · GSC 3) · `test_handoff_ddl_gate.py` 픽스처 80/64 ⇒ 17/17 · 음성 = `tmp/o260/neg_exclude.py` PASS(인수인계에 `_TEST` 생기면 축1 1건).
- 게이트 = handoff_ddl_gate 🟢 7축 PASS(문서 13) · line_len PASS.
- ④ 요건3(착수표 ②) 코드 = `AGENCY_AD_ROW_VIDEO`·`AGENCY_AD_ROW_REBRDC`(원천명) · `AGENCY_AD_PERFORMANCE`(VIDEO 원천 컬럼만 · 출력 계약 불변) · `FACT_AD_PERFORMANCE:205` · 08 SILVER DDL 3컬럼 · 신규 `05_SV-Agent_ai/42_DEPLOY_AGENCY_AD_SRC_RENAME.sql` · 문서실행순서 36 · `32_컬럼개명표.md` 8-E.
- 🔴 AD_PERF_DK 는 바뀐다(staging ROW_HASH 가 키 이름까지 해시) — 같은 build 에서 하류 동반.
- 보류 = REBRDC `CAMPAIGN_NM` 승격(FACT 이름매칭 1순위라 O245 코드 경로 결과가 바뀜) · 코어 `UPPER_CAMPAIGN_NM`(값 = 코드) 개명 — 사용자 결정 대상.
- 미실행 = 80 재빌드(`build_handoff.py` · 다중 파일 재작성 · R4-4-3 승인 필요) · 👤 dbt build.
- 확정위반 3 = `R1-7-2` 같은 파일 `edit` 병렬(04 · 07 · 02 각 1회) — 해시 2회 동일·게이트 재실행·grep 으로 유실 0 확인.
- read 미반환 0 · 재호출 0.
