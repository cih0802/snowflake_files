# MSTR 1차 이관 대상 → Snowflake 전환 작업계획

## 1. 목적
`mstr DDL 원본/1차 이관대상 관련 추출/` 폴더에 있는 SQL 5개는 MSTR 원천 DB(SQL Server, T-SQL) 기준입니다. 이를 Snowflake 문법으로 바꿔 `snowflake 적용 ddl/` 폴더에 저장합니다.

- **원천(읽기 전용)**: `GN_DW.BRONZE_CRM` (MSTR_ODS.DBO.* 와 같은 이름의 테이블)
- **산출물(중간·최종 마트)**: `GN_DW.MSTR` 스키마 (새로 생성)
- 원본 MSTR_ODS에는 직접 연결하지 않습니다. 모든 원천 참조는 `GN_DW.BRONZE_CRM`으로 바꿉니다.

## 2. 산출물 (총 6개, `15_MSTR 이관 PoC/snowflake 적용 ddl/`)

| # | 파일명 | 내용 | 원본 |
|---|---|---|---|
| 0 | `00_mstr_schema_role.sql` | MSTR 스키마 생성, 롤 생성 및 권한 매핑 | (신규) |
| 1 | `01_table_script.sql` | 테이블 DDL 9개 | table_script.sql |
| 2 | `02_view_script.sql` | 뷰 DDL 13개 | view_script.sql |
| 3 | `03_function_script.sql` | UDTF 2개 | function_script.sql |
| 4 | `04_sp_script.sql` | 프로시저 11개 (Snowflake Scripting) | sp_script.sql |
| 5 | `05_mstr_1차_이관_대상_쿼리.sql` | MSTR 리포트 쿼리 전환본 | mstr 1차 이관 대상 쿼리.sql |

실행 순서: 00 → 01 → 02 → 03 → 04 → (적재 프로시저 실행) → 05  
※ 뷰와 함수가 서로를 참조하므로(FN이 `D_SPNSR_BSNS_V` 참조), 02(뷰)를 03(함수)보다 먼저 실행합니다.

## 3. 원천 매핑 (MSTR_ODS.DBO → GN_DW.BRONZE_CRM)

| MSTR 원천 | Snowflake 원천 | 존재 여부 |
|---|---|---|
| TC_CMMN_CD / TC_CMMN_DTL_CD | BRONZE_CRM.TC_CMMN_CD / TC_CMMN_DTL_CD | O |
| TM_CM_BRND_MNG | BRONZE_CRM.TM_CM_BRND_MNG | O |
| TM_CM_CMPGN_MNG | BRONZE_CRM.TM_CM_CMPGN_MNG | O |
| TM_CM_DEPT_INFO | BRONZE_CRM.TM_CM_DEPT_INFO | O |
| TM_CM_SPNSR_BSNS_INFO | BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO | O |
| TM_MM_FDRM_MBER_DVLP_AMT / _INFO / _RE_SPNSR / _SPNSR / _SPNSR_BSNS / _SPNSR_DSCNTC | BRONZE_CRM 같은 이름 | O |
| **EXPLCAMPLIST** | **없음** | **X** → 확인 필요 (아래 6장) |

MSTR 내부 객체(`mart.*`, `dbo.FN_*`)는 모두 `GN_DW.MSTR.*`로 매핑합니다.

## 4. 단계별 작업

### Step 0. 스키마·롤 (`00_mstr_schema_role.sql`)
- `CREATE SCHEMA IF NOT EXISTS GN_DW.MSTR`
- 롤 구성 (안)
  - `MSTR_ETL_ROLE`: BRONZE_CRM SELECT, MSTR 스키마 CREATE TABLE/VIEW/FUNCTION/PROCEDURE, DML, 웨어하우스 USAGE
  - `MSTR_READ_ROLE`: MSTR 스키마 USAGE + 모든/미래 테이블·뷰 SELECT (BI 조회용)
  - 두 롤을 `SYSADMIN`에 상속시키고 담당 사용자에게 GRANT
- FUTURE GRANTS를 설정해 나중에 생기는 객체에도 권한이 자동 적용되게 합니다.

### Step 1. 테이블 (`01_table_script.sql`)
- 대상: F_MM_SPNSR_DVLP_SUM, D_BRND_CD, D_CMPGN_CD, D_SPNSR_BSNS_INFO, D_CMMN_DTL_CD, D_STRD_CAL_CD, D_CM_DEPT_INFO, D_CMPGN_EXPL_CD, BCHLOG
- 바꿀 내용
  - `[mart].[X]` → `GN_DW.MSTR.X`, 대괄호 제거
  - 타입: `NVARCHAR/VARCHAR(n)`→`VARCHAR(n)`, `DATETIME`→`TIMESTAMP_NTZ`, `BIT`→`BOOLEAN`, `MONEY`→`NUMBER(19,4)`, `INT IDENTITY`→`NUMBER AUTOINCREMENT`
  - `ON [PRIMARY]`, `WITH (PAD_INDEX…)`, `CLUSTERED`, `GO`, `SET ANSI_NULLS` 등 제거
  - PK/UNIQUE는 선언만 유지 (Snowflake에서는 강제되지 않음)
  - 큰 팩트(F_MM_SPNSR_DVLP_SUM)는 `CLUSTER BY (STRD_MT)` 적용을 검토
- 타입 정밀도는 BRONZE_CRM 원천 컬럼과 비교해 맞춥니다.

### Step 2. 뷰 (`02_view_script.sql`)
- 13개 뷰를 `CREATE OR REPLACE VIEW GN_DW.MSTR.…`로 변환
- 함수 치환: `ISNULL`→`IFNULL/COALESCE`, `CONVERT(CHAR(8),dt,112)`→`TO_CHAR(dt,'YYYYMMDD')`, `CONVERT(CHAR(6),dt,112)`→`TO_CHAR(dt,'YYYYMM')`, `+` 문자열 연결→`||`
- `D_SPNSR_BSNS_V`의 원천은 `GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR(_BSNS)`로 변경

### Step 3. 함수 (`03_function_script.sql`)
- `FN_MM_ACT_DATE`, `FN_MM_SPNSR_DVLP` (Inline TVF) → SQL UDTF
  `CREATE OR REPLACE FUNCTION GN_DW.MSTR.FN_…(STRD_MT VARCHAR) RETURNS TABLE(…) AS $$ … $$`
- 반환 컬럼 목록과 타입을 명시
- `@STRD_MT`→`STRD_MT`, `DateAdd(d,-1,x)`→`DATEADD(day,-1,x)`, `CONVERT(DATE, s)`→`TO_DATE(s,'YYYYMMDD')`
- `@STRD_MT + '31'`처럼 말일을 문자열로 붙이는 부분은 동작을 그대로 유지(문자열 비교)하고, 필요하면 `LAST_DAY`로 바꿀지 검토
- UDTF 안의 윈도우 함수(LAG, ROW_NUMBER)가 지원되는지 컴파일로 확인

### Step 4. 프로시저 (`04_sp_script.sql`)
- T-SQL 프로시저 → `LANGUAGE SQL` Snowflake Scripting
- 주요 변환 규칙

| T-SQL | Snowflake |
|---|---|
| `@i_ym VARCHAR(6)`, `OUTPUT` 파라미터 | `I_YM VARCHAR` 인자, 결과 메시지는 `RETURNS VARCHAR`로 반환 |
| `SET NOCOUNT`, `ISOLATION LEVEL READ UNCOMMITTED` | 제거 |
| `WHILE @@ROWCOUNT > 0 DELETE TOP(10000) … WITH(TABLOCK)` | `DELETE FROM … WHERE STRD_MT = :I_YM;` 한 번에 실행 |
| `@@ROWCOUNT` | `SQLROWCOUNT` |
| `@@PROCID` | 프로시저 이름 문자열 상수 |
| `BEGIN TRY … END TRY BEGIN CATCH` | `BEGIN … EXCEPTION WHEN OTHER THEN … END` |
| `BEGIN TRAN / COMMIT / ROLLBACK` | `BEGIN TRANSACTION / COMMIT / ROLLBACK` |
| `EXEC MART.USP_BCHLOG …` | `CALL GN_DW.MSTR.USP_BCHLOG(…)` |
| `GETDATE()` | `CURRENT_TIMESTAMP()` |
| `FROM dbo.FN_X(@p)` | `FROM TABLE(GN_DW.MSTR.FN_X(:I_YM))` |
| 변수 참조 | SQL 안에서는 `:VAR` (콜론 접두사) |

- 오류 정보는 `SQLERRM`, `SQLCODE`로 `USP_BCHERR`에 기록
- (선택) 월별 적재 순서를 Task로 구성하는 것은 후속 과제로 둡니다.

### Step 5. 리포트 쿼리 (`05_mstr_1차_이관_대상_쿼리.sql`)
- `mart.`→`GN_DW.MSTR.` 접두사 변경. 나머지 SELECT·JOIN·GROUP BY는 ANSI라 거의 그대로 사용
- 하단의 `[분석엔진 계산 단계: …]` 블록은 MSTR 엔진 내부 단계라 SQL이 아닙니다. 주석으로 남기고, 필요하면 동적 집계(@{…})는 GROUP BY/GROUPING SETS로 따로 구현

## 5. 검증 계획
1. 각 파일을 `only_compile`로 컴파일 검증 → 00~04 순서로 실제 생성
2. 차원 적재 프로시저 실행 → 팩트 `CALL USP_F_MM_SPNSR_DVLP_SUM('202601','POC')`
3. 행 수 확인, 키 NULL 비율 확인, `BCHLOG`에 기록됐는지 확인
4. 05 쿼리 실행 결과(2026-01, DVLP_DIV_CD 1·2·4)를 MSTR 리포트 결과와 비교 (건수, `SUM(SPNSR_AMT)`, 회원 수)

## 6. 리스크·확인 필요 사항
- **EXPLCAMPLIST가 BRONZE_CRM에 없음**: `D_CMPGN_EXPL_CD` 적재(USP_D_CMPGN_CD 계열)에 영향이 있습니다. 대안은 (a) 원천 적재 요청, (b) 임시로 빈 테이블/수동 CSV, (c) 해당 로직 제외 중 선택해야 합니다.
- BRONZE_CRM 컬럼명·타입이 MSTR_ODS와 완전히 같은지 컬럼 단위로 비교해야 합니다.
- `D_STRD_CAL_CD`(달력)는 원천 없이 프로시저로 생성되는지 확인하고, 필요하면 `GENERATOR`로 생성합니다.
- 롤 이름과 권한을 받을 사용자는 결정이 필요합니다. 현재는 ACCOUNTADMIN으로 실행 중이며, 운영 시에는 전용 롤 사용을 권장합니다.
- 원본 소스는 UTF-16이었고, 추출본과 전환본은 UTF-8로 저장합니다.

## 7. 작업 체크리스트 (O197 · 2026-10-01 · 개발계 pw69582 실행 결과)
- [x] 00 스키마·롤 — 신규 롤 없이 기존 GN_DW 롤 체계(07_ENVIRONMENT_RBAC_setup.sql) 재사용 · 배포 완료
- [x] BRONZE_CRM ↔ 원본 컬럼 대조 — 원천 12/13 실재 · 컬럼명 동일 · `BRTHDY` 부재(→ AGE NULL)
- [x] 01 테이블 10 · 02 뷰 13 · 03 함수 2 · 04 프로시저 13 — 배포 + 매니페스트↔라이브 대조 일치
- [x] 05 리포트 쿼리 — 202601 결과 10,227행 · 차원명 미매핑 0 · 회귀 기준선 기록(`tools/manifests/1차.json`)
- [x] **ExplCampList 제외 확정** — IT 확인(스페셜 캠페인 하드코딩 · 2년 미갱신 · skip) ⇒ `D_CMPGN_EXPL_CD` 라이브 DROP ·
      조인 제거 · CLS1/2 고정 99 · SPCL 고정 N (전후 결과 동일)
- [x] F_MM_SPNSR_DVLP 과거 이력 재적재(`USP_RUN_MSTR_1ST(…, TRUE)`) — SPNSR_AMT2_CD 정확도용 · 리포트 미사용
  · 🟢 2026-10-03 O200-D 집행(pw69582) · 원천 420개월(≤202601) 재적재 완료 · 202601 baseline PASS(리포트 요약 불변)
  · `mstr_verify.norm` 부동소수 6자리 반올림 보정(끝자리 흔들림 오탐 DIFF 제거 · 음성 테스트 통과)
- [ ] MSTR 원 리포트 결과와 대조(건수·금액·회원수) — MSTR 측 수치 확보 필요

## 8. 다음 단계 — 전체 이관 스킬화
- 도구 = `tools/`(README 참조) · 배치 정의 = `tools/manifests/<batch>.json` · 단계 = deps → extract → 변환 → gen → deploy → run → verify
- 1차에서 확정된 결정·변환 규칙은 매니페스트 `decisions` 와 `tools/README.md` 에 있다.
- 🟢 [2026-10-03 O200-D] 스킬 = `.snowflake/cortex/skills/mstr-migration/SKILL.md`(순서·멈춤·금지만 · 규칙 정본은 README).

## 9. Agent 배선 방침 (O203 · 2026-10-06 · 사용자 결정)

- 🟢 [O207 · 2026-10-07 · 사용자 결정 C안 → O207-C AGENT_MSTR 은퇴] MSTR 도구(analyst_mstr_spnsr_dvlp · SV_MSTR_SPNSR_DVLP)는 AGENT_MEMBER·AGENT_MARKETING·AGENT_EXECUTIVE 에 배선돼 있고 개발 실적·목표·연도말 전망의 정본이다. AGENT_MSTR 는 DROP 됐다(스펙 사본 = _archive/agent_spec.yaml.O207-C-retire-agent-mstr).
- ~~🟢 **현행 = A안**: MSTR 결과는 **AGENT_MSTR 에만** 배선한다.~~ ➔ 폐기(O207). AGENT_MEMBER·AGENT_EXECUTIVE·AGENT_MARKETING 에는 배선하지 않았다.
- ~~🔴 **다음에 MSTR 관련 작업(2차 이관·재적재·SV 변경 등)을 하면 착수 시 사용자에게 묻는다**:~~ ➔ 폐기(O207 · 더 묻지 않는다)
  「MSTR 결과는 아직 다른 Agent 에 배선되지 않았습니다(A안). 회원 분석 Agent(AGENT_MEMBER)에도 붙이는 **B안으로 전환할까요?**」
- B안 = AGENT_MEMBER 에만 MSTR 도구 추가 · 답변마다 「MSTR 기준」 표기(문구는 사용자에게 받는다) · C안 = 3종 모두(혼동 위험 최대).
- 선택지 원문 = `05_SV-Agent_ai/41_현업요청서_MSTR반영_누계개발.md` 요청 1 · 스킬 `mstr-migration` Step 6 에도 같은 질문을 넣었다.
- ⏸ **일일 적재(전월+당월) dbt 연동 = 준비만 완료 · 미적용** — 현업이 MSTR 데이터를 쓰겠다고 회신하면 `10_MSTR_일일적재_dbt연동_준비.md` §5 순서로 착수한다(그때 위 B안 질문도 함께 한다).
