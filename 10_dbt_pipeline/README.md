<!-- LLM-METADATA
doc_id: DBT_PIPELINE_README
doc_role: 폴더 안내 — 10_dbt_pipeline 역할·구성·문서 읽는 순서 (진입점)
project: GN_DW (굿네이버스)
created: 2026-07-16
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

# 10_dbt_pipeline — 폴더 안내 (README)

> GN_DW(굿네이버스) 데이터웨어하우스의 **dbt 파이프라인 프로젝트**와 그 **운영·성능·핸드오프 문서**를 담는 폴더입니다.
> 이슈·설계 원장은 별도 폴더 `20_issue/`에 있으며, 본 폴더 문서는 그 원장과 상호 연동됩니다.

---

## 1. 폴더 역할

- **dbt 프로젝트 소스**(`models/`·`macros/`·`dbt_project.yml`·`profiles.yml`)의 저작·버전 관리 공간.
- 배포 대상 객체: `GN_DW.OPS.DW_PIPELINE` (dbt project, 운영 전용 스키마).
- 워크스페이스 스테이지: `snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline`.
- **현재 상태(2026-07-16 실측)**: SILVER 32 + GOLD 33(dim 15 + fact 9 + WIDE view 9) = **65 models**. full `dbt build` green. WIDE VIEW **9/9** 완결.
- 운영 계약: 온디맨드 `EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';` (`run` 금지, `build` 사용).

---

## 2. 문서 읽는 순서 (번호 = 읽는 순서)

| # | 파일 | 역할 | 언제 읽나 |
|---|---|---|---|
| — | `README.md` (본 문서) | 폴더·문서 지도 | 진입점 |
| **00** | `00_배포운영_통합_20260715.md` | **배포·운영 정본** — 현재 상태·배포 절차(CREATE/ALTER/EXECUTE)·불변 운영규칙(R1~R5)·잔존이슈·§7 진행요건 총괄표 | **가장 먼저** — 파이프라인 전체를 파악할 때 |
| **10** | `10_성능검토_정적코드분석_20260716.md` | **성능검토(정적)** — 모델 코드·규모 기반 조인/윈도우/spill/클러스터링 타당성 + §7 EXPLAIN·QUERY_PROFILE 실측 체크리스트 | 성능·엔진 관점 설계검증 시 |
| **11** | `11_성능검토_운영리스크_20260716.md` | **성능검토(운영리스크·이슈연계)** — 이슈원장 트리거(D1 재적재·G-5 pseudo-grain·P7 stale) 기반 비용·조치 우선순위 판정 | "언제 무엇을 조치하나" 판단 시 |
| **90** | `90_NEXT_SESSION_순서9-D_20260715.md` | **세션 핸드오프 프롬프트** — 다음 세션 착수용 상태 스냅샷·규칙·대기항목 | 작업을 이어서 재개할 때 |

> **성능검토 2종 구분(이름 혼동 해소)**: `10`=정적 코드/엔진 분석(구조가 타당한가), `11`=이슈원장 연계 운영 트리거(언제 조치가 필요한가). 상호 자매 문서로, 관점만 다릅니다.

---

## 3. 기타 구성물

| 경로 | 내용 |
|---|---|
| `models/` | SILVER 32 + GOLD(dim/fact/wide) dbt 모델 |
| `macros/` | `gold_helpers`(gold_sk·gold_meta·date_sk 등)·`silver_helpers`·`ga4_union_shards`·`generate_schema_name` |
| `dbt_project.yml` · `profiles.yml` | 프로젝트 설정(`+full_refresh:false`·fact append+pre-hook TRUNCATE 등) |
| `dbt_setting.sql` | 초기 세팅 SQL |
| `target/` · `logs/` | dbt 산출물·로그(생성물) |
| `_archive/` | 통합 전 원본 문서(DEPLOY_RUNBOOK·PIPELINE_STATE·작업가이드·예견이슈·99_ORCHESTRATION 등) 보존 |

---

## 4. 연계 문서 (20_issue 원장)

| 문서 | 역할 |
|---|---|
| `20_issue/00_INDEX_이슈원장.md` | 이슈 원장 허브·상태 대시보드·크로스워크 |
| `20_issue/10_진단_원인분석.md` | 진단패턴·핵심교훈·트랙 착수게이트 |
| `20_issue/20_현업확인_요청.md` | 현업 회신 대기 항목·의심데이터 A~E |
| `20_issue/30_설계_의사결정.md` | D1~D3·결정대기 GOLD·설계 트리거 |
| `20_issue/40_입고대기_원천의존.md` | 외부 원천 하드블로커(G-5·E-1·E-4·E-6 등) |
| `20_issue/41_입고요청서_CRM_BIZ_TARGET.md` (+`_BRONZE_DDL.sql`) | E-6 입고요청서·BRONZE DDL 제안 |
| `20_issue/50_dbt_파이프라인_미결조치.md` | BLOCKING·DONE·warn→error 복귀 추적표 |
| `20_issue/90_해소완료_로그.md` | 닫힌 항목 이력 |

---
_Co-authored with CoCo_
