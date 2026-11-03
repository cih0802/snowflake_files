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

## 5. 스키마 개명 이력 (정본)

> 물리 스키마명이 바뀌면 **이 표에 먼저 적고** 코드 결합점을 고친다. dbt 모델·매크로명은 개명 대상이 아니다.

| 일자 | 변경 | 유형 | 실행 DDL |
|---|---|---|---|
| 2026-08-14 | `GN_DW.BRONZE_GA4` → **`GN_DW.BRONZE_BIGQUERY`** | 스키마명만 | `ALTER SCHEMA BRONZE_GA4 RENAME TO BRONZE_BIGQUERY;` |

### 왜 바꿨나
이 BRONZE 스키마의 원천은 **GA4 제품이 아니라 BigQuery export**다. GA4 외 BigQuery 유입도 같은
스키마로 수용할 수 있도록 **원천 시스템(BigQuery) 기준 명명**으로 통일했다.

### 무엇이 바뀌지 않았나 (혼동 주의)
🔴 개명된 것은 **스키마명 하나뿐**이다. 아래는 전부 **불변**이며, "왜 아직 GA4냐"는 결함이 아니다.

| 대상 | 값 | 왜 그대로인가 |
|---|---|---|
| 매크로 | `ga4_union_shards` | GA4 = 데이터 도메인 명칭(스키마 위치와 무관) |
| SILVER 모델 | `BIGQUERY_EVENT`·`BIGQUERY_EVENT_DIM`·`BIGQUERY_IDENTITY`·`BIGQUERY_DEVICE`·`BIGQUERY_TRAFFIC_SOURCE` | 하류 GOLD·SV·Agent 전량이 이 이름에 결합 |
| 샤드 테이블 | `events_YYYYMMDD` (소문자 인용식별자) | BigQuery export 산출물 원형 |
| dbt source 이름 | (GA4는 source 선언 없음) | `INFORMATION_SCHEMA` 동적조회 설계 — 설계결정서 §2 |

### 코드 결합점 (다시 개명할 때 고칠 곳)
GA4 스키마명은 dbt 안에서 **`macros/ga4_union_shards.sql` 의 리터럴 2곳**에만 존재한다.

1. `WHERE table_schema = 'BRONZE_BIGQUERY'` — 샤드 목록 동적 조회
2. `FROM {{ target.database }}.BRONZE_BIGQUERY."{{ t }}"` — 샤드 UNION 본문

⚠️ 매크로는 `ref()`/`source()` 를 쓰지 않으므로 **dbt 가 개명 누락을 컴파일 단계에서 잡아주지 못한다.**
개명 후 검증은 `dbt build --select +BIGQUERY_EVENT` 로 **실행**해야 드러난다(compile 만으로는 통과한다).

### 데이터 값에 남는 영향
SILVER GA4 5모델의 `DW_SOURCE_TABLE` 리터럴이 `'BRONZE_GA4.events'` → `'BRONZE_BIGQUERY.events'` 로
바뀌었다. 🔴 **이미 적재된 행의 값은 자동으로 갱신되지 않는다** — 다음 `dbt build` 로 재적재되는
행부터 새 값이 들어가므로, 한동안 두 값이 공존한다. 계보 조회 시 `LIKE 'BRONZE_%.events'` 로 볼 것.

---
_Co-authored with CoCo_

---

## 🔖 [2026-08-05 세션 반영] O38-E · O39 · O40 · O40-B

> 정본 = `20_issue/10_진단_원인분석.md` **§22-J(O38-E) · §23(O39) · §24(O40)** · 신규 원칙 **P77~P82**.

### 🔴 `gold.fact` 에 `on_schema_change: fail` 적용 (O40-B · P82)

**왜**: 기본값 `ignore` 는 모델에 있고 대상 테이블에 없는 컬럼을 **에러도 워닝도 없이 버린다.**
🟢 **WARN 내역 정본** = `20_issue/50_dbt_파이프라인_미결조치.md` §WARN 27건 전량 목록 ·
근본원인 = `20_issue/00_INDEX_이슈원장.md` O41 §잔여① (고아 회원 9,247명 단일 원인 · 실결함은 `PART_STATUS` 1건뿐).

이번에 실제로 겪었다 — O40 에서 컬럼 2종을 추가하고 build 가 `PASS=370 WARN=27 ERROR=0 SKIP=0` 으로
끝났는데 `INSERT` 가 대상 테이블의 **56컬럼만** 써서 신규 컬럼이 생기지 않았다.
🔴 **"ERROR=0" 은 성공 신호가 아니었다.**

**왜 `append_new_columns` 가 아닌가**: GOLD DDL 정본은 `03_top-down_gold/06_DDL.sql` 이고 dbt 는
파이프라인만 실행한다. 자동 ALTER 는 정본과 조용히 어긋나므로, **수동 DDL 거버넌스를 유지하면서
불일치만 큰 소리로 드러내는** `fail` 을 택했다.

**적용 전 안전 검증(2026-08-05)**: `dbt compile` 후 13개 팩트의 컴파일 SQL 을 `SELECT * FROM (...) LIMIT 0`
으로 실행해 **모델 산출 컬럼 vs 테이블 컬럼 전량 대조** → 드리프트 **0건** 확인 후 적용.
`dbt list --output json` 으로 유효 config `"on_schema_change": "fail"` 반영 확인.

### ⚠️ 팩트에 컬럼을 추가하는 표준 절차 (이 순서를 지킬 것)
1. `03_top-down_gold/06_DDL.sql` 수정(정본)
2. `ALTER TABLE ... ADD COLUMN` 실행
3. `INFORMATION_SCHEMA.COLUMNS` 로 **컬럼 존재 확인** ← 건너뛰면 4~5가 무증상 실패한다
4. dbt 모델 수정
5. `dbt build --select <FACT>`
6. 🔴 **`COUNT(<신규컬럼>)` 비NULL 건수 검증** — 행수·기존 값 불변만 보면 통과해 버린다

> 🔴 교훈: **실행 순서를 문서에 적는 것과 선행 단계를 실제로 완료해 두는 것은 다르다.** 넘길 때는
> 「무엇을 먼저 해야 하는지」가 아니라 **「지금 무엇만 하면 되는지」** 상태로 만들어 넘긴다.

_Co-authored with CoCo_
