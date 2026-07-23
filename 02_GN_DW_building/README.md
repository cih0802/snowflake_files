# 02_GN_DW_building — GN_DW 설계 정본

> `02_GN_DW_building/` 폴더의 **진입점(색인)** 문서. 각 파일의 역할·읽는 순서·현재 상태를 한곳에 정리한다.
> 프로젝트: 굿네이버스 GN_DW. 범위: PoC(`GN_DW_POC`)를 운영 등급 DW(`GN_DW`)로 이관한 **설계 작업계획서(정본)**.
> 아키텍처: **BRONZE → SILVER → GOLD → SERVING** 4계층 재설계. **라이브 배포 완료(2026-07-22).**

## 폴더 간 위상
- **이 폴더 = 설계 정본** (SERVING 스키마 도입 재설계안)
- `01_project_sample/` — GOLD 통합 **레거시**(참고용)
- `03_top-down_gold/` — **GOLD 정본**(15 DIM + 9 FACT star schema). 본 폴더 GOLD 기술은 요약, 상세는 이 폴더 참조
- `00_PoC_bak/` — 이관 원천이 된 PoC 백업

---

## 파일 명세

| 파일 | 역할 |
|------|------|
| `00_INDEX.md` | 작업계획 인덱스(개요·산출물·실행순서 13단계·원칙·위험·챕터맵). **모든 상세 메타의 출처**. |
| `01_환경_Role.md` | Timezone, Warehouse 3종, Role 계층 6종, 유저 프로비저닝. |
| `02_DB_BRONZE_SILVER.md` | DB/스키마 9종(BRONZE 4분할), BRONZE 48테이블(원천 1:1), SILVER 32테이블(정제·dbt), dbt 파이프라인. |
| `03_GOLD_SERVING.md` | GOLD star schema 24(정본 → `03_top-down_gold/`) + WIDE VIEW 9, Semantic View 5(최종 7), Agent 2(최종 3), 권한, Streamlit 0(미배포). |
| `04_운영.md` | dbt 파이프라인, 테스트, 보안(네트워크/마스킹/MFA), 모니터링. |
| `05_ARCHITECTURE.md` | 전체 아키텍처 다이어그램 + SERVING 조감도. |
| `06_RUNBOOK.md` | 운영 매뉴얼 — 일상점검/장애대응/수동실행/보안사고. |
| `07_ENVIRONMENT_RBAC_setup.sql` | **0단계 부트스트랩 실행 SQL** — WH 3·역할 6+계층·WH/스키마 grant·SERVING 스키마·CoWork object·helper 뷰 2. `01`·`03 §3.8` 설계의 실행 정본(멱등). |

---

## 읽는 순서 (신규 진입자)
1. 본 문서 → 2. `00_INDEX.md`(개요·실행순서·원칙·위험) → 3. `05_ARCHITECTURE.md`(아키텍처 조감) → 4. 챕터 `01`~`04` 순 → 5. `06_RUNBOOK.md`(운영)

> 상세 메타데이터·실행순서·설계원칙은 모두 `00_INDEX.md`에 있다. 본 README는 진입용 안내이며 INDEX를 대체하지 않는다.

## 현재 상태 (라이브 2026-07-22)
- BRONZE→SILVER→GOLD→**SERVING** 4계층 **라이브 배포 완료**. BRONZE 48(CRM 43 전수 + GA4·ERP·AGENCY 부분 입고) · SILVER 32 · GOLD 24(15 DIM+9 FACT) + WIDE VIEW 9 · SERVING SV 5(최종 7)/Agent 2(최종 3) + 보조뷰 2.
- ETL = dbt 프로젝트 `GN_DW.OPS.DW_PIPELINE`(65 models). 구설계의 정제 프로시저·Task DAG·`ETL_LOG`는 폐기(dbt 전환).
- GOLD 상세 설계(star schema)는 `03_top-down_gold/`가 **정본**이며, 본 폴더 `03_GOLD_SERVING.md`는 라이브 구조 요약.
- 잔여: GA4 전기간·ERP 모금성비용·CRM 사업목표(FACT_TARGET_BIZ 0행, E-6) 등 입고 대기분은 입고 후 SILVER/GOLD/SV 자동 확장. 보안(네트워크/마스킹/MFA)·모니터링(RM/Alert/Cost)은 설계안(운영 승격 시 배포). Streamlit·NL 스모크(트라이얼 DATA_AGENT_RUN 차단)는 미배포/대기.
