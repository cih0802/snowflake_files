# O114 라이브 실측 근거 (2026-08-29 · 판정보다 먼저 기록 · `R1-3-7-c`)

> 🔴 이 파일은 **판정 근거 원문 보관용**이다. 판정은 이 기록 뒤에 한다.
> 계정 = `sz99178` · 역할 `ACCOUNTADMIN` · 웨어하우스 `COMPUTE_WH`
> 🔴 계정명은 **맥락**이고 근거는 **조회 결과**다(`R3-9 ㉤` · O106 사용자 결정).

## A. 계정 성격 판정 — 이 계정은 C(대상) 계정이다

`SHOW DATABASES` 실측(2026-08-29 05:30 UTC) = 7건 =
`ADMIN` · `GN_DW` · `SANDBOX` · `SNOWFLAKE` · `SNOWFLAKE_LEARNING_DB` ·
`SNOWFLAKE_SAMPLE_DATA` · `USER$TRIALADMIN`.

* `GN_DW` = 2026-08-28 21:24:06 -0700 생성 · owner `GN_DW_ADMIN` · comment 「굿네이버스 데이터웨어하우스」
* 🔴 **A 계정 원천 DB(CRM·ERP 원본)는 이 계정에 없다** ⇒ `㉢`(02번 5·6단계 재실행)은
  **이 계정에서 수행 불가**다. 「없음」이 아니라 **「이 계정에서 접근 불가」**다.

## B. `GN_DW` 스키마별 테이블 수 (INFORMATION_SCHEMA · BASE TABLE)

| 스키마 | 테이블 |
|---|---|
| `BRONZE_AGENCY` | 4 |
| `BRONZE_CRM` | 46 |
| `BRONZE_ERP` | 2 |
| `GOLD` | 37 |
| `ML` | 16 |
| `SILVER` | 43 |

⇒ 🟢 **DDL 은 O113 갱신본(브론즈 52 = CRM 46 + ERP 2 + AGENCY 4)으로 이미 생성돼 있다.**

## C. `㉠ BDGT_ACMSLT_LEDGER` — 컬럼 순서·데이터 실측

`GN_DW.INFORMATION_SCHEMA.COLUMNS` 조회 결과 = **67행**(`BRONZE_ERP` 소재).
선두 5컬럼 원문 =

| ORDINAL_POSITION | COLUMN_NAME | DATA_TYPE |
|---|---|---|
| 1 | `YEAR` | TEXT |
| 2 | `INCOME_EXPS_DIV_NM` | TEXT |
| 3 | `BDGT_PRCD_NM` | TEXT |
| 4 | `BDGT_UNIT_NM` | TEXT |
| 5 | `JANG_NM` | TEXT |

* 🟢 **`BDGT_PRCD_NM` 이 3번째에 실재**한다 = 2026-08-29 신규 구조다.
* 🟢 **`MNYRS_COST_DIV_YN` 은 67컬럼 어디에도 없다** = 삭제분이 반영돼 있다.
* 말미 = 64 `YEAR_BDGT_AMT_12` · 65 `CHN_BDGT_AMT_12` · 66 `ADJ_BDGT_AMT_12` · 67 `EXEC_AMT_12`.

`INFORMATION_SCHEMA.TABLES` 원문(`BRONZE_ERP`) =

| TABLE_NAME | ROW_COUNT | BYTES | CREATED |
|---|---|---|---|
| `BDGT_ACMSLT_LEDGER` | 0 | 0 | 2026-08-28 22:23:08.260 -0700 |
| `EXPENSE_RESOLUTION` | 0 | 0 | 2026-08-28 22:23:09.253 -0700 |

직접 `COUNT(*)` 재확인(메타데이터 신뢰 금지 · 4건 동시 조회) =
`BDGT_ACMSLT_LEDGER` = **0** · `EXPENSE_RESOLUTION` = **0** ·
`TM_CM_MKTNG_UTM` = **0** · `TM_CM_CMPGN_MNG` = **0**.

## D. 전 스키마 적재 상태 — 0행

`ROW_COUNT > 0` 인 테이블 수를 스키마별로 집계한 결과 =
`BRONZE_AGENCY` 0/4 · `BRONZE_CRM` 0/46 · `BRONZE_ERP` 0/2 ·
`GOLD` 0/37 · `ML` 0/16 · `SILVER` 0/43 · **총계 0행**.

⇒ 🟢 **이 계정에는 아직 어떤 데이터도 적재되지 않았다.**
🔴 이 「0」은 **「대상이 아니다」가 아니라 「아직 적재 전」**이다(`R2-8-4-c`).

## E. `㉥` 스테이지 재실측 — `SANDBOX.TOOLS.MIG_LOAD_STAGE`

1회차 `LIST @SANDBOX.TOOLS.MIG_LOAD_STAGE` 전량(1,968행) 접두별 집계 =

| 접두 | 테이블 디렉터리 | 파일 | MB | 최초 수정 | 최종 수정 |
|---|---|---|---|---|---|
| `BRONZE_AGENCY/` | 4 | 5 | 4.3 | 04:37:50 | 04:37:51 |
| `BRONZE_CRM/` | 46 | 280 | 3,101.4 | 04:38:28 | 04:44:23 |
| `BRONZE_ERP/` | 2 | 2 | 0.7 | 04:37:43 | 04:37:43 |
| `ML/` | 16 | 54 | 28.9 | 04:37:58 | 04:38:14 |
| `SILVER/` | 1 | 1,623 | 25,973.4 | 04:51:24 | 05:29:43 |

조회 시각 = `CURRENT_TIMESTAMP()` **2026-08-29 05:30:02 UTC**.

2회차 `LIST @SANDBOX.TOOLS.MIG_LOAD_STAGE/SILVER/` (약 105초 후) =
**1,687 파일 · 26,984.9 MB · 최종 수정 05:31:28 UTC**.

⇒ 🔴 **SILVER 는 105초에 +64파일 · +1,011.5 MB = 업로드 진행 중이다.**
⇒ 🟢 **`BRONZE_CRM` 은 스테이지 46 디렉터리 = DDL 46 테이블로 집합이 일치하고
최종 수정이 04:44:23 로 약 47분간 무변화** ⇒ 업로드 완료로 판정 가능하다.
⚠️ O113 이 「측정 중 계속 증가」로 남긴 것은 **그 시점의 진행 중 상태**였고 지금은 정지했다.
⚠️ O113 의 「SILVER 0건 = 미언로드」도 지금은 **1,687 파일 실재**다 —
「0건」이 「대상 아님」이 아니었음을 실물로 확인했다(`R2-8-4-c` · `▣TTT3`).

## F. `㉡` SILVER COMMENT 공백 9건 — 라이브 제3축 확인

`GN_DW.SILVER.BIGQUERY_REFINED_DATA` 의 해당 9컬럼 `COMMENT` 조회 결과 =
**9건 전부 `None`**(`STSLC_CRC_CAMPAIGN_NAME` · `STSLC_CRC_DEFAULT_CHANNEL_GROUP` ·
`STSLC_CRC_PRIMARY_CHANNEL_GROUP` · `STSLC_CRC_SOURCE_PLATFORM` ·
`STSLC_GAC_AD_GROUP_ID` · `STSLC_GAC_AD_GROUP_NAME` · `STSLC_GAC_CAMPAIGN_NAME` ·
`STSLC_MC_CAMPAIGN_NAME` · `STSLC_MC_SOURCE_PLATFORM`).

⇒ 부재는 **원천 · 인수인계 · 라이브 3곳 전부**다(종전 2축 → 3축으로 강화).
🔴 그래도 **문안을 창작하지 않는다** — 3곳 부재는 「빠진 것」과 「의미 미확정」을
여전히 구별해 주지 않는다. 원천 소관자 확인이 선행이다.

## G-0. 🟢 07번 A.1 (4) CSV 헤더 ↔ 라이브 테이블 대조 — 68/68 MATCH

07번이 「유일한 방어선」이라 선언한 검사(`ORDER_OR_NAME_MISMATCH` 탐지)를
**접두별로 범위 한정**해 실행했다. 범위 한정 이유 = `SILVER/`(26,984.9 MB)가
업로드 중이고 전량 스캔은 비용이 크다. `FF_CSV_PEEK` 는 `IF NOT EXISTS` 로 확인
(응답 = 「already exists, statement succeeded」 ⇒ **기존 객체를 교체하지 않았다**).

| 범위 | 대조 결과 |
|---|---|
| `BRONZE_ERP` 2 | `BDGT_ACMSLT_LEDGER` **67/67 MATCH** · `EXPENSE_RESOLUTION` **16/16 MATCH** |
| `BRONZE_AGENCY` 4 + `ML` 16 | **20건 전부 MATCH**(다른 진단값 0건) |
| `BRONZE_CRM` 46 | **46건 전부 MATCH** — `TM_CM_CMPGN_MNG`(36/36) · `TM_CM_MKTNG_UTM`(12/12) 포함 |
| `SILVER` 1 | 🔴 **미실행** — 업로드 진행 중이라 헤더가 확정되지 않았다 |

⇒ 🟢 **`COUNT_MISMATCH` 0 · `ORDER_OR_NAME_MISMATCH` 0 · `TABLE_MISSING` 0 · `FILE_MISSING` 0.**
⇒ 🟢 `TM_CM_CMPGN_MNG` 36 · `TM_CM_MKTNG_UTM` 12 가 CSV 헤더로도 확인됐다
  = O113 이 문서에서 판정한 원천 델타가 **실물 CSV 와 일치**한다.
⇒ 🔴 **`㉠` 의 「값이 한 칸씩 밀렸다」 위험은 이 계정에서 성립하지 않는다**:
  ㉠ 테이블이 0행이고 ㉡ 컬럼 순서가 CSV 와 MATCH 다. **TRUNCATE 는 불필요하며
  실행해도 효과가 없다**(대상 행이 없다).

## G. `handoff_ddl_gate.py` 실행 결과 (문서 축 · 라이브 무관)

판정 축 = 축1 테이블 집합 0 · 축2 컬럼 이름·순서 0 · 축3 타입 0 ·
축4 DEFAULT 0 · 축5 컬럼 COMMENT 0 · 축6 테이블 COMMENT 0 ·
축7 문서 stale 0(문서 13개 검사).
관측 축 = 원천 미제공 → 인수인계 보강 969건(정상) · **COMMENT 양쪽 부재 9건**(경고).
⇒ 🟠 `PASS(경고)` — 인수 기대치와 일치한다.
