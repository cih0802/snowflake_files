> #### 🟢 [2026-09-17 O163] DDL↔라이브 드리프트 37건 전수 규명 + `DEC-50` SILVER 미집행 8건 개명 + 라이브 복원(드리프트 0 · FK 56) 완결
>
> - **착수 배경**: 사용자 dbt build 가 `16 model(s) failed out of 560` 로 실패했고 첫 에러가
>   `003001 (42501) … must have MODIFY granted on TABLE` 였다. 사용자 가설 = *"O160 이후 요건
>   (CRM 7~8월 백업 신규코드 적재)으로 파이프라인을 수정했는데, 요건에 해당되지 않는 테이블이
>   stale한데 그냥 넘어가서 ddl과 dbt가 문제가 생긴 것 같다"*.
>
> 1. 🔴 **「권한 문제」가 아니었다 — `GRANT MODIFY ON TABLE` 은 존재하지 않는 권한이다.**
>    - `GRANT MODIFY ON {ALL|FUTURE} TABLES` 4건 전부 `Invalid object type 'TABLE' for privilege 'MODIFY'` 로 실패.
>      ⇒ 이 메시지는 **OWNERSHIP 요구의 표현**이고 권한 부여로 해결할 수 있는 종류가 아니다.
>    - 발화 문장 실측 = `alter  table … add column` (**공백 2칸**). 🔴 `grep "alter table"` 로는
>      한 번 놓쳤다 — dbt 가 두 칸으로 발행한다. 로그 조사 시 주의.
>    - 원인 경로 = `+on_schema_change: append_new_columns` 의 **ADD COLUMN**. 가드 매크로
>      `gn_no_structural_alter` 는 **타입 확장만** 막고 그 헤더 22~24행이 컬럼 추가 경로를
>      의도적으로 열어 두었다 ⇒ O95(P82 방어)와 O121(구조 보호)이 **서로 충돌**하며, 그 충돌은
>      DDL 과 모델의 컬럼 집합이 일치할 때만 잠재 상태로 남는다.
>
> 2. 🟢 **어긋난 축 규명 = 「모델↔DDL」이 아니라 「DDL 파일↔라이브」였다.**
>    - 신설 도구 `scripts/o163_ddl_live_drift.py` 로 전수 실측 = **컬럼 드리프트 37건 · MISSING_TABLE 0건**.
>    - 15모델 전건에서 **DDL 파일과 dbt 모델의 컬럼 집합이 완전 일치**하고 라이브만 낡음.
>      ⇒ 라이브는 이력 `01_세션이력-059.md:119` 기재대로 **계정 재구축(2026-09-07) 후
>      O139~O142 가 손댄 것만 재생성**된 부분 복구 상태였다.
>    - 🟢 **요건 반영분은 이미 라이브에 있었다**(사용자 가설 확증): `CRM_MKTNG_CODE` ·
>      `CRM_SEND_MEMBER_OPEN_LOG` · `CRM_SEND_MEMBER_LINK_LOG` · `CRM_MEMBER_CONVERT_HIST` 4종 실재 ·
>      `MKTG_CHANNEL` 4곳 배선(`CRM_CAMPAIGN`·`CRM_MEMBER_DEV`·`DIM_CAMPAIGN`·`FACT_MEMBER_EVENT`).
>      CRM 계열 드리프트는 `CRM_EVENT_PARTICIPATION.EVENT_SOURCE` **1건**뿐이고 깨진 15개는
>      예산·광고·행사·발송·후원 계열 = **전부 요건 무관 테이블**이었다.
>
> 3. 🔴 **자기판정 2건 철회(사용자 지적으로 반증)**.
>    - 초판은 `FACT_AD_DIGITAL` 7건·`FACT_AD_PERFORMANCE` 3건을 「라이브 최신 · DDL stale」로
>      판정했다. 사용자 지적(*"O133 개명이 GA→AGENCY일텐데 그럼 ddl이 맞는것 아닌가"*)을 받아
>      모델을 실독하니 **DDL 이 맞았다**: `FACT_AD_DIGITAL.sql:17~24` 가
>      `PAGE_TYPE_NM as PAGE_TYPE` 형태로 **SILVER=원천명(P규약) / GOLD=의미명** 2층 구조를 구현한다
>      ⇒ O133 이 `06_DDL.sql` 을 고치지 않은 것은 누락이 아니다. **역방향 드리프트 0건**.
>    - 🔴 개명 2건을 한 묶음으로 뭉갠 것도 정정했다: O133 = `DEC-46` 원천명 복원(GA 무관) ·
>      **O142 = `DEC-51` GA→AGENCY**. 사용자 규칙(*"ga 명칭은 ga4스키마 테이블만"*)은 후자의 근거와
>      정확히 일치하고, 라이브가 `GA_CONV_*` 인 이유는 「SV 때문에 취소」가 아니라 **계정 재구축 소실**이었다.
>    - 🔴 「보류 3건은 build 성공」이라던 초판 근거도 **오류**였다 — 실측하니 그 6모델은 **전부 SKIP**
>      (상류 실패)이라 모델↔라이브 대조가 애초에 수행되지 않았다. 모델 실독으로 재판정 =
>      `FACT_MEMBER_COHORT` 34/34 · `DIM_MEMBER_ACQUISITION` 21/21 · `FACT_EVENT_ATTENDANCE` 16/16 ·
>      `FACT_AD_DIGITAL` 7/7 · `FACT_AD_PERFORMANCE` 3/3 **전건 모델 실재** ⇒ 라이브만 낡음.
>
> 4. 🟢 **`DEC-50` SILVER 미집행 8건 개명(사용자 지적)**.
>    - 실측 = `06_DDL.sql` 의 `GA_*` 는 **0건**(GOLD 집행 완료 · `DIM_MEMBER_IDENTITY` =
>      `BIGQUERY_MEMBER_ID`)인데 SILVER 는 미집행이었다. 근거 = `_sources.yml` 활성 source 4종
>      (`SILVER`·`BRONZE_CRM`·`BRONZE_ERP`·`BRONZE_AGENCY`)에 **`BRONZE_GA4` 배선 0건**(29행은 주석)
>      ⇒ `GA_` 를 정당화할 계통이 파이프라인에 없다. 라이브 `BRONZE_GA4` 2테이블은 미연결.
>    - 개명 = `GA_SESSION_ID/_NUMBER/_KEY` → `BIGQUERY_SESSION_*`(`BIGQUERY_BASIC`·`BIGQUERY_EVENT`) ·
>      `GA_MEMBER_ID` → `BIGQUERY_MEMBER_ID`(`BIGQUERY_IDENTITY`·`IDENTITY_MEMBER_XREF`).
>    - 반영 = dbt 모델 6개 + DDL 2개(08·09) + 생성기 3개 + 가드 매크로 목록.
>      🔴🔴 **최대 위험 = `EP_GA_SESSION_ID`·`EP_GA_SESSION_NUMBER`** 는
>      `BIGQUERY_REFINED_DATA` 의 **외부 Python 적재 원천 컬럼**(개명표 §1 `EXTERNAL_PYTHON`)인데
>      개명 대상을 **부분문자열로 포함**한다 ⇒ negative lookbehind `(?<!EP_)` 로 보호하고
>      치환 후 **EP_ 개수 불변**을 단정했다(도구 = `scripts/o163_dec50_rename.py`).
>    - 🟢 **유지 판정 2축**: `AGENCY_AD_ROW_DGT.GA_AD_COST`·`GA_CONV_MBER_CNT` 는
>      `BRONZE_AGENCY.DGT_AD_CMPGN_DTLS` 에 **원천 실재**(P규약 · `DEC-51` 이 GOLD 노출을
>      `AGENCY_CONV_*` 로 이미 분리) · `GAC_*` 는 Google Ads Campaign 축(별개 · 백로그).
>    - 🟢 역사 기록은 **원문 보존**했다(08 DDL 1271·1293~1295) — 08 DDL 1343~1351 에
>      「개명 누락으로 읽지 마라」 배너를 남겼다(`R2-8-3`).
>
> 5. 🔴🔴 **도구 자기결함 2건을 스스로 적발했다 — 둘 다 데이터 손실로 이어질 수 있었다.**
>    - ㉠ **주석 CREATE 오인**: 초판 `CREATE_RE` 가 `-- CREATE OR REPLACE TABLE …` 까지 선언으로
>      세어 `SILVER.BIGQUERY_REFINED_DATA`(08 DDL 1283행 **커밋아웃**)를 복원 대상에 넣었다.
>      🔴 그대로 실행하면 **외부 Python 적재 11,600,680행이 영구 소실**됐다(dbt 가 재적재하지 않는다).
>      ⇒ 판정식 = CREATE 매칭이 속한 줄 선두가 `--` 면 선언이 아니다. 시정 후 DDL 선언 85→**84** ·
>      드리프트 37→**36** · 그 테이블은 `LIVE_ONLY_TABLE` 로 정확히 재분류됐다.
>    - ㉡ **SQL 키워드 오탐**: `FACT_MEMBER_SPONSORSHIP_SPAN` 에서 `BEGIN`·`CASE`·`AND` 를
>      컬럼으로 잡아 없는 드리프트를 만들었다(DDL 본문 CASE 식의 들여쓰기가 컬럼 정의와 같다).
>      `NOT_COL` 에 키워드 보강 ⇒ DDL_ONLY 28→**25**.
>
> 6. 🟢 **라이브 복원 집행(사용자 승인 · `R4-4-3`)** — DDL 파일 전수 실행.
>    - 선행 실측으로 3대 우려를 해소했다: **GRANT** = FUTURE GRANTS(SILVER 13 + GOLD 41 ·
>      ADMIN·ANALYST·ENGINEER·SERVICE·VIEWER)로 자동 복구 · **FK** = DDL 이 별도
>      `ALTER … FOREIGN KEY … NOT ENFORCED` 로 부여 · **데이터** = 대상 36개 전부 dbt 모델 실재(부재 0).
>      ⇒ 개명표 §5 의 「`CREATE OR REPLACE` 금지」는 **개명 맥락**의 지침이고, 낡은 세대를 정본으로
>      복원하는 이 작업에는 위 3축이 정비돼 있어 성립한다.
>    - 실행 경로 = `snow sql -f`. 🔴 `EXECUTE IMMEDIATE FROM` 은 스크립트 안의 `USE ROLE` 을
>      거부하고(65행 `unexpected 'USE'`), `snow sql -f` 는 **선행 블록주석의 세미콜론**에서 깨져
>      첫 문장이 `Empty SQL statement` 가 된다(3~64행 `/*…*/` 중첩) ⇒ 주석 블록을 제외한
>      실행본(`tmp/_o163_exec_silver.sql`·`_gold.sql`)을 만들어 실행했다.
>    - 🟢 **O142 사고 회피**: 파일 내 `USE ROLE GN_DW_ADMIN` 으로 실행해 **OWNERSHIP =
>      `GN_DW_ADMIN`** 을 확보했다(O142 는 `SV_AD` 를 `ACCOUNTADMIN` 으로 만들어 소비 3역할이
>      읽지 못했다 · `01_세션이력-059.md:257`).
>    - 실측 결과 = **드리프트 36 → 0건** · **GOLD FK 20 → 56건** · SILVER 48 · GOLD 37 ·
>      `BIGQUERY_REFINED_DATA` **11,600,680행 보존** · `FACT_MEMBER_FEE` GRANT 26건 자동 복구 ·
>      `table_ddl_column_gate` **84/84 집합 일치**(blocking 0 · 순서 드리프트 0).
>
> 7. 🔴 **자기결함(순서 오류) — 산출물 4종을 데이터 미적재 상태에서 재생성해 덮었다.**
>    - 라이브 복원 직후(dbt build **전**) `census_columns` + 생성기 4종을 돌렸는데,
>      생성기가 라이브 **데이터**를 읽어 판정하므로 결과가 무의미해졌다:
>      `04.rows` 563→246 · `05.WAIT` 27→89 · `09.조립가능` 267→**12** · `09.값없음` 52→**341**.
>    - 🟢 **골든은 갱신하지 않았다** — 빈 상태를 기준선으로 만들면 그 골든이 거짓이 된다
>      (`R1-7-4` 「FAIL 을 `--update-golden` 으로 덮지 마라」).
>    - 🔴 `_archive` 에 그 4종 스냅샷이 없어 되돌릴 수 없다 ⇒ **복구 경로 = dbt build 후 재생성**
>      이고 이를 인수인계 필수 항목으로 올렸다. 교훈 = **산출물 재생성은 적재 이후다.**
>
> 8. 🟢 **게이트·테스트**: 게이트 6종 전건 rc=0 · `table_ddl_column_gate` 84/84 ·
>    음성 테스트 33종 중 실패 3 → `test_gate_census` 는 신설 도구 2건 등재로 **11/11 해소**
>    (`o163_ddl_live_drift` = `NEEDS_ARGS` · `o163_dec50_rename` = `MUTATES`) ·
>    `test_generators` 는 위 7항 사유로 **의도적 미해소** · `test_verify_wide_doc` 는
>    인수인계 §0-JJJJ ▣JJJJ2 에 이미 등재된 **선행결함**(라이브 뷰 부재).
>
> - **read 미반환**: 0건 · 재호출 0건.
> - **`R4-4-2 ㉡` 적용**(지시 동봉) · 확정위반 = 7항 1건(산출물 재생성 순서).
