USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_ETL_WH;
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE DEPLOY FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';
USE ROLE GN_DW_DBT;

EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select FACT_AD_PERFORMANCE+ CRM_RELATION_ACTIVITY+ DIM_RELATIONSHIP+ CRM_EVENT+ DIM_BUDGET_ITEM+ ERP_EXPENSE_RESOLUTION+';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select BIGQUERY_SESSION+ --vars ''{"bigquery_dt_ranges": [["2024-01-01", "9999-12-31"]]}''';
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='retry';

SELECT 20261007;
-- USE ROLE ACCOUNTADMIN;
-- DROP DATABASE GN_DW;

use role gn_dw_analyst;
use warehouse gn_dw_analytics_wh;
SELECT COUNT(DISTINCT STRD_MT) loaded, MAX(CASE WHEN STRD_MT < '202601' THEN STRD_MT END) last_hist, COUNT(*) rows_ FROM GN_DW.MSTR.F_MM_SPNSR_DVLP;

describe table GN_DW.BRONZE_ERP.SYNC_ERR_INFO;
select * from GN_DW.BRONZE_ERP.SYNC_ERR_INFO;

/*
Brief regenerating. First step: run VERSION$6 eval to separate 6차 vs 7차 cause — reading a resolved config to clone it.

Creating VERSION$6 variants and a parameterized eval runner.

The Snowflake account just got **suspended** ("lack of payment method") partway through. Checking whether anything live still works.That count may come from metadata alone, so it doesn't prove compute works. Checking the status of the one eval that did start.

Line 10 looks like an "MSTR 먼저" rule for 개발 questions. Reading the orchestration text in full for the regressed areas.

MKT keeps the "미정의 지표 → 계산 전 확인" rule. But Q19·Q21 (budget optimization · threshold) are "답변 불가 + 대안" guardrail items. Checking whether that rule survived.

네, 개선할 수 있습니다. 다만 점수가 떨어진 주된 이유는 Agent 답변 품질이 나빠져서가 아닙니다. 채점에 쓰는 정답지가 지금 Agent의 도구 구성과 맞지 않아서입니다. 그리고 분석 도중 **Snowflake 계정이 정지되어**("lack of payment method") 수정 배포와 재측정은 하지 못했습니다.

**실행 상태**
- 6차와 7차 중 어느 쪽 때문에 떨어졌는지 가르려고 VERSION$6 eval을 시작했습니다.
- 경영·기획 1건만 시작된 직후 계정이 정지됐고, 회원·마케팅은 시작에 실패했습니다. 상태 조회도 막혀 점수는 하나도 얻지 못했습니다.
- 그래서 아래 원인은 Agent 설정 파일, 문항 정답표(`06_O208_문항코퍼스.csv`), `tmp/o214_eval_regress.tsv`를 대조해 오프라인으로 판정한 것입니다.

**점수 하락 원인**
1. **정답지와 도구 구성 불일치 (가장 큰 원인).** 비교 기준인 O211-B(5차)는 경영·기획 Agent 도구가 17개였을 때 측정했습니다. 6차에서 4차 상태로 되돌리며 10개가 됐고, 7차에서 2개를 더해 지금은 12개입니다.
   - 그 결과 경영·기획 21문항 중 7문항(Q03·Q04·Q05·Q06·Q07·X1·X2)은 정답으로 지정된 도구가 지금 Agent에 없습니다.
   - 빠진 도구는 `analyst_mbrfee_prdt_actl`, `analyst_member_event`, `analyst_member_fee`, `analyst_ml_fee_forecast`입니다.
   - 따라서 경영·기획 하락은 7차가 아니라 6차 되돌리기 결정에서 나온 것으로 보입니다. VERSION$6 eval로 확인해야 합니다.
2. **규칙 충돌 (X1·X2).** 6차에 들어간 지시가 "개발인입경로·캠페인카테고리 축의 개발 실적은 MSTR 도구로 답한다"입니다. Agent는 이 지시대로 움직였는데, 정답지는 이전 규칙 기준이라 `analyst_member_event`를 기대합니다.
3. **마케팅 "도구 없이 답해야 하는" 문항 (Q19·Q20·Q21).** "계산 전에 먼저 확인한다" 규칙은 남아 있습니다. 하지만 예산 최적 배분·효율 임계점·채널×캠페인 최적 조합 같은 질문이 그 대상으로 명시돼 있지 않아 `analyst_ad`를 바로 호출합니다.
4. **회원 R14·D3.** 정답지는 도구 1개를 기대하는데 Agent는 여러 도구를 함께 씁니다. 지시문 결함보다는 정답지를 도구 1개로 잡은 쪽의 문제일 가능성이 큽니다.

**개선 방법 (결정 필요)**
- **A안 (추천).** 6차 되돌리기 결정은 그대로 두고 정답지만 맞춥니다.
  - 경영·기획 7문항의 정답 도구를 현행 구성으로 고친 데이터셋 V3를 만듭니다. 예를 들어 Q03·Q04는 회원 Agent로 안내하는 것을 정답으로, X1·X2는 `analyst_mstr_spnsr_dvlp`를 정답으로 둡니다.
  - 마케팅 확인 규칙에 "최적 배분·임계점·조합 최적화"를 대상으로 명시하는 문장을 넣습니다.
  - 고친 정답지로 다시 측정한 결과를 새 기준선으로 삼습니다.
- **B안.** 빠진 4개 도구를 경영·기획에 다시 넣고 2번 규칙을 정리합니다. 6차에서 확정해 재론하지 않기로 한 결정을 뒤집는 것이라 결정을 받아야 합니다.

**다음 단계**
1. 계정에 결제수단을 등록해 정지를 풀어 주셔야 합니다. 이 부분은 제가 할 수 없습니다.
2. 풀리면 `python3 tmp/o215_eval.py start 'VERSION$6' v6b`로 VERSION$6 eval을 다시 돌려 6차·7차 영향을 가릅니다. 과금은 이미 승인받은 범위입니다.
3. A안과 B안 중 하나를 정해 주시면 Agent 수정, 새 버전 추가, 재측정까지 이어서 진행합니다.

인수인계(`99_NEXT_SESSION-O0215-A.md`), 원장 행, 세션 이력은 갱신했습니다.
*/