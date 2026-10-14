# O229 GOLD.WIDE_AD_BROADCAST_CASE 라이브 0행 — 적재 경로 확인 (jw08094 · 2026-10-14)

| 계층 | 객체 | 실측 |
|---|---|---|
| BRONZE | `GN_DW.BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS` | 컬럼 21 · `CASE%` 0 |
| SILVER staging | `GN_DW.SILVER.AGENCY_AD_ROW_REBRDC` | 컬럼 30 · `CASE%` 0 |
| SILVER | `AGENCY_AD_BROADCAST_CASE` | 0행 (INFORMATION_SCHEMA ROW_COUNT) |
| GOLD | `FACT_AD_BROADCAST_CASE` | 0행 |
| GOLD | `WIDE_AD_BROADCAST_CASE`(VIEW) | 상류 0행 |
| 대조 | `AGENCY_AD_BROADCAST` · `FACT_AD_BROADCAST` | 49,959 |

- 모델 원문 = `10_dbt_pipeline/models/silver/agency/AGENCY_AD_BROADCAST_CASE.sql:10`
  「원천 12번 재편으로 REBRDC 의 CASE1_*~CASE3_* 반복군 15컬럼이 **전부 소멸**」 · `:27` `WHERE 1=0`.
- 판정 = 🟢 **결함 아님 · 설계된 0행 스캐폴드**(O182). 원천 재제공 시 복원(모델 주석 `:13`).
- 노출 점검 = `grep -rlI BROADCAST_CASE cortex_project/ 05_SV-Agent_ai/`(rc=0) → `04_SV_설계.md` · `_archive/` 원본 SQL 뿐
  ⇒ SV·Agent 배선 0 · 🟢 사용자 노출 영향 없음 · **이 항목 닫음**.

_Co-authored with CoCo_
