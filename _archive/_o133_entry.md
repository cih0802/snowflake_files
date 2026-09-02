> #### 🟢 [2026-09-02 O133] DEC-44 예산 검증 완결 + DEC-46 SILVER 개명 12건 전건 집행 + FMM degen 6컬럼 G군 판정 + 요건 #22 초수 SV_AD 노출 배포
>
> - **목적**: 지난 세션(O131/O132) 준비 작업을 파이프라인 프로세스 순 × 중요도 순으로 집행.
> - **참조 정본**: 문서30 §30-I(`DEC-44`), §32-G(`DEC-46`), §7-C(FMM G군) · `20_issue/32_컬럼개명표.md` · `05_7_SV_DDL_AD.sql` · `06_DDL.sql` · `08_SILVER_테이블DDL_20260714.sql`.
>
> 1. 🟢 **[최우선] DEC-44 예산 회계 재작성 dbt build 및 실측 검증 완결 (착수표 ~~㊴~~)**:
>    - 사용자 실행 dbt build 결과: `PASS=496 WARN=39 ERROR=0 SKIP=0 TOTAL=535`.
>    - O131에서 `severity: error` 로 승격된 DEC-44 예산 테스트 3종 전건 PASS 확인.
>    - 기등재 회원 마스터 고아 축 39건과 WARN 39건 정확 일치 (신규 WARN 0건).
>    - 라이브 Snowflake `FACT_BUDGET_YEARLY` 집계 쿼리 검증: `TOTAL_PLAN=65,202,608,326`, `TOTAL_EXEC=55,094,546,653` 정확 일치 확인.
>
> 2. 🟢 **[SILVER] DEC-46 SILVER 컬럼 개명 12건 전건 집행 (착수표 ~~㉙~~)**:
>    - 안전망: `table_ddl_column_gate.py` 리팩터링 결과(79개 테이블 GOLD 37 + SILVER 42 전수 검사)를 안전망으로 활용.
>    - 대상 12건:
>      - `ERP_BUDGET_ITEM` (2건): `BUDGET_UNIT_NM` ➔ `BDGT_UNIT_NM`, `INCOME_EXPENSE_DIV` ➔ `INCOME_EXPS_DIV_NM`.
>      - `ERP_BUDGET_YEARLY` (3건): `YEAR_BUDGET_TOT_AMT` ➔ `YEAR_BDGT_TOT_AMT`, `CHN_BUDGET_TOT_AMT` ➔ `CHN_BDGT_TOT_AMT`, `ADJ_BUDGET_TOT_AMT` ➔ `ADJ_BDGT_TOT_AMT`.
>      - `AGENCY_AD_DIGITAL` (7건): `PAGE_TYPE` ➔ `PAGE_TYPE_NM`, `AD_GROUP_NM` ➔ `AD_GRP_NM`, `GROUP_DIV` ➔ `GRP_DIV_NM`, `CREATIVE_TYPE` ➔ `MATR_TY_NM`, `AD_TYPE_NM` ➔ `AD_TY_NM`, `MEDIA_POTENTIAL_CUST_CNT` ➔ `MEDIA_PTNT_CUST_CNT`, `CRM_DEV_CNT` ➔ `CRM_DVLP_CNT`.
>    - 코드 반영: dbt 모델 6개(`ERP_BUDGET_ITEM`, `DIM_BUDGET_ITEM`, `ERP_BUDGET_YEARLY`, `FACT_BUDGET_YEARLY`, `AGENCY_AD_DIGITAL`, `FACT_AD_DIGITAL`) 및 `08_SILVER_테이블DDL_20260714.sql` DDL 정합 수정.
>    - 라이브 집행: Snowflake 라이브에서 `ALTER TABLE … RENAME COLUMN` 12건 전수 집행 및 `INFORMATION_SCHEMA.COLUMNS` 실측 완료 (`CREATE OR REPLACE TABLE` 금지 규약 준수).
>    - 검증: `table_ddl_column_gate.py` 실행 결과 79/79 집합 일치 (blocking 0건) 재검증 완료. `32_컬럼개명표.md` 진행상태 12건 완료 갱신.
>
> 3. 🟢 **[GOLD] FACT_MEMBER_MONTHLY degen 6컬럼 grain 분기 집행 (착수표 ~~㊹~~)**:
>    - FMM(`DEV_TYPE`, `NEW_FLAG`, `INCREASE_FLAG`, `REDONATE_FLAG`, `JOIN_DATE`, `STOP_DATE`) 6개 컬럼에 대해 FMM(월 스냅샷) ↔ FME(사건) grain 상이에 따른 G군 판정 확정.
>    - 사건 데이터를 월 스냅샷에 합산 시 12배 과대 위험 방지를 위해 6개 컬럼 슬롯 유지 확정(드랍 금지).
>    - `06_DDL.sql` 및 라이브 테이블 COMMENT 에 사건 팩트(`FACT_MEMBER_EVENT`) 정본 안내 전파 완료.
>    - `30_설계_의사결정` §7-C 등재표 상태 갱신.
>
> 4. 🟢 **[SERVING] 요구사항 #22 영상 초수(DURATION_SEC) SV_AD 노출 및 배포 (착수표 ~~㊸~~)**:
>    - `05_7_SV_DDL_AD.sql` 에 `ad.DURATION_SEC` 차원 및 동의어/COMMENT 추가.
>    - Snowflake 라이브 `CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_AD` 배포 완료.
>    - 스모크 쿼리 검증: `SEMANTIC_VIEW(GN_DW.SERVING.SV_AD DIMENSIONS ad.DURATION_SEC METRICS TOTAL_AD_COST)` 로 초수별(30초, 60초, 90초, 120초 등) 정상 집계 확인.
>    - `30_마케팅_AGENT_설계.md` 요건 `#22` 초수 상태 🟢 갱신 완료.
>
> 5. 🟢 **거버넌스 및 게이트 검증**:
>    - `table_ddl_column_gate.py`: 79/79 PASS (blocking 0건).
>    - `index_row_gate.py`: 행 유실 0, 골든 대비 중복 증가 0.
>    - `doc_heading_gate.py` / `doc_type_gate.py` / `clause_order_gate.py` / `doc_coord_gate.py` 전원 통과.
>    - `line_len.py`: 2000자 초과 0줄.
