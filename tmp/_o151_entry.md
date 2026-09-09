> #### 🟢 [2026-09-09 O151] 현업 1차 회신 정제 룰 dbt 모델 반영 + Snowflake Native DBT PROJECT 배포 및 Task 자동화 완결
>
> - **세션 목표**: 현업 1차 회신 확정 4대 정제 룰(2-4 A, 2-1 I-2, 3-1 N-1~4, O145-8) dbt 모델 반영, `SILVER.CRM_CAMPAIGN_SPONSOR_BIZ_BRIDGE` 브릿지 모델링(DEC-45), Snowflake Native DBT PROJECT(`GN_DW.OPS.DW_PIPELINE`) 신규 버전 배포 및 일일 스케줄 Task DAG 자동화 완결.
> - **작업 배경**: `07_현업의사결정 회신/현업의사결정 회신.md`의 확정 결과에 따라 데이터 정제 룰을 상류 dbt 모델에 적용하고, 스냅샷 11종이 포함된 dbt 파이프라인의 Native 객체 배포 및 일배치 스케줄링을 구축함.
>
> **1. 현업 1차 회신 정제 룰 dbt 모델 반영 (P1)**
> 1. `[2-4 A] MBRFEE_MT 오류 보정`: `models/silver/crm/CRM_PAYMENT_BILLING.sql`에서 `MBRFEE_MT = '20251'` 5자리 비정상값을 `'202501'`로 보정하는 CASE문 반영 완료.
> 2. `[2-1 I-2] 행사 참여 이상치 정제`: `models/silver/crm/CRM_EVENT_PARTICIPATION.sql`에서 EVENT/CRMN 양 원천의 비정상 회원번호(공란 5건 및 홈페이지 테스트/보안 스캐너 2,058건 등 비표준 MBER_NO)를 `REGEXP_LIKE(TRIM(MBER_NO), '^[0-9]{7}$|^[0-9]{9}$|^S[0-9]{8}$')`로 필터링하여 정상 회원 데이터(1,134,022행)만 적재.
> 3. `[3-1 N-1~4] 개발/사업목표 껍데기 제외`: `models/gold/fact/FACT_TARGET_DEV.sql` 및 `FACT_TARGET_BIZ.sql`에 `COALESCE(GOAL_CNT, 0) > 0` / `COALESCE(TARGET_CNT, 0) > 0` 필터를 적용하여 증액/재후원 미편성 0/NULL 껍데기 데이터를 달성률 산출 모수에서 제외 정제.
> 4. `[O145-8] 개발목표 소급 규칙`: `models/silver/crm/CRM_DEV_TARGET.sql`에 `TARGET_TYPE = 'ORIGINAL'`(당초) 부여 완료.
>
> **2. 자체 가능 과제 모델링 완결 (DEC-45)**
> 1. `models/silver/bridge/CRM_CAMPAIGN_SPONSOR_BIZ_BRIDGE.sql` 신설: `BRONZE_CRM.TM_CM_CMPGN_MNG.SPNSR_BSNS_ID` 쉼표 다중값을 `LATERAL FLATTEN(INPUT => SPLIT(SPNSR_BSNS_ID, ','))`로 1:N 브릿지 정규화(93,373행).
> 2. `models/silver/_silver_bridge_schema.yml`에 모델 및 not_null, relationships(`CRM_CAMPAIGN`, `CRM_SPONSORSHIP`), unique 테스트 정의 등재.
> 3. 마스터 FK 매칭률 100.00%(미매칭 0건) 및 유일성 검증 완료.
>
> **3. Snowflake Native DBT PROJECT 배포 및 Task 자동화 (P1)**
> 1. `GN_DW.OPS.DW_PIPELINE`에 스냅샷 11종 및 신규 정제 룰이 포함된 신규 버전 `V_20260909_SNAPSHOT` 추가 배포(`ADD VERSION`) 및 소유권 `GN_DW_ADMIN` 정상화.
> 2. `EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='compile'` 검증 완료 (94 models, 11 snapshots, 449 data tests, 47 sources 100% 컴파일).
> 3. `EXECUTE DBT PROJECT ... build` 실행 검증 완료: 수정 및 신규 모델 49노드 전체 PASS=40, WARN=9, ERROR=0 통과.
> 4. 일일 배치 Task DAG 생성 및 스케줄 등록:
>    - 루트: `GN_DW.OPS.TASK_DW_SNAPSHOT_DAILY` (매일 05:30 KST, `EXECUTE DBT PROJECT ... snapshot`)
>    - 차일드: `GN_DW.OPS.TASK_DW_BUILD_DAILY` (스냅샷 완료 후 즉시, `EXECUTE DBT PROJECT ... build`)
>
> **4. 거버넌스 및 게이트 검증**
> - `scripts/line_len.py`: PASS (전체 파일 2,000자 초과 0줄)
> - `scripts/test_*.py`: 31/31 전건 PASS (rc=0)
> - 문서 정본 및 브리핑 갱신: `00_INDEX_이슈원장`, `30_설계_의사결정`(DEC-45), `01_세션이력`, `99_NEXT_SESSION.md`.
