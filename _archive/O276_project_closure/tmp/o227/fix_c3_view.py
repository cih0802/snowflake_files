#!/usr/bin/env python3
"""O227 ③-① C3 뷰 레벨 10건 — _wide_*.yml model description 의 이슈ID·경위 문장 제거 + 라이브 실측으로 stale 주장 정정.
라이브 실측(xh20001 · 2026-10-14 · O227) = FACT_AD_PERFORMANCE CAMPAIGN_SK·AD_CREATIVE_SK ≠0 0행 · PERF_IS_HOLIDAY TRUE 12,254행 ·
  BQ YEAR = 2024·2025·2026 · BQ IS_HOLIDAY TRUE 66,725행 · BQ 세션지표 non-null 0 · WIDE_BUDGET ORG_DEPARTMENT·CAMPAIGN_NAME distinct 1('(미매핑)') ·
  WIDE_AD_BROADCAST_CASE 0행(캠페인 주장 검증 불가 ⇒ 삭제).
반영 = 👤 dbt build(gn_view_commented) — 이 스크립트는 파일만 고친다. 사용: python3 tmp/o227/fix_c3_view.py [--apply]
Co-authored with CoCo
"""
import hashlib, io, json, sys
import yaml

D = '/workspace/10_dbt_pipeline/models/gold/wide/'
NEW = {
 'WIDE_BIGQUERY_BEHAVIOR': (
  "BigQuery 행동 팩트(FGA) 평탄화 — DATE·BIGQUERY_EVENT·BIGQUERY_SOURCE·DEVICE·CAMPAIGN·IDENTITY. 비가산 지표의 상위 재합산 금지. "
  "IDENTITY_* 는 `DIM_MEMBER_IDENTITY` 활성으로 실조인된다 — 브리지는 1:1 이라 팬아웃이 없다. "
  "🔴세션 품질 지표(AVG_SESSION_DURATION·BOUNCE_RATE)와 회원번호는 전건 비어 있고, 캠페인축은 전건 센티넬이다. "
  "⚠️연도별 적재 구간이 고르지 않을 수 있다 — 연도·계절 추이는 기간별 행수를 먼저 확인한 뒤 해석한다."),
 'WIDE_AD_PERFORMANCE': (
  "광고 성과 **코어** 팩트(FAD) 평탄화 — DATE·CAMPAIGN·AD_CREATIVE·DEVICE. grain=AD_PERF_DK. "
  "방송 전용 속성은 위성 뷰(WIDE_AD_BROADCAST)에 있다 — 본 뷰는 3원천 공통 컬럼만 담는다. "
  "**전 유형 집계는 본 뷰만 사용**할 것(위성 뷰와 합산하면 이중계상). "
  "🔴`CAMPAIGN_SK`·`AD_CREATIVE_SK` 는 전건 0(미배선)이다 — 캠페인·매체·소재 속성이 전건 NULL 또는 `'(미매핑)'` 센티넬이다. "
  "센티넬은 GROUP BY 가 단일 그룹을 반환해 **오답이 에러 없이 나온다.** 🟢대안 = 마케팅캠페인 축. "
  "⚠️AD_SOURCE_TYPE(원천 출처축) ≠ AD_CREATIVE_TYPE(소재 광고유형). 🔴행수는 하드코딩하지 않는다(재적재마다 변한다)."),
 'WIDE_AD_BROADCAST': (
  "방송광고 위성 팩트(FAD_B) 평탄화 — grain=AD_PERF_DK. 코어와 1:1 이라 코어 measure(AD_COST·INBOUND_CALL) 동반 노출 → 방송 분석을 단일 뷰로 완결한다. "
  "⚠️코어 뷰(WIDE_AD_PERFORMANCE)와 함께 합산하면 방송 행이 이중계상된다 — 전 유형 집계는 코어 뷰만. "
  "⚠️컬럼 NULL 은 두 방송 원천(VIDEO·REBROADCAST) 중 한쪽 전용 속성이며 결측이 아니다. "
  "DVLP_MEMBER_CNT·DVLP_CNT = 재방송 개발실적(GA 전환 아님). _SRC 는 대행사 산정 비가산(N). "
  "🔴매체·소재축과 캠페인명은 사용 불가 상태다(FK 미배선). 🔴행수는 하드코딩하지 않는다(재적재마다 변한다)."),
 'WIDE_AD_DIGITAL': (
  "디지털광고 위성 팩트(FAD_D) 평탄화 — grain=AD_PERF_DK. 코어와 1:1 이라 코어 measure(AD_COST·IMPRESSIONS·CLICKS·GA_CONV_*) 동반 노출 → 비율 재계산 base 를 같은 뷰에서 확보한다. "
  "⚠️코어 뷰와 함께 합산하면 디지털 행이 이중계상된다. _SRC 7종은 대행사 산정 **비가산(N)** — 집계는 base 재계산(예: CTR=SUM(CLICKS)/SUM(IMPRESSIONS))이고 _SRC 는 행 단위 대조용이다. "
  "DEVICE_TYPE 동반(디지털은 기기가 실존 · 실적재 PC·M). 🔴매체·소재축과 캠페인명은 사용 불가 상태다(FK 미배선) · AD_SOURCE_TYPE 은 단일값이다. "
  "🔴행수는 하드코딩하지 않는다(재적재마다 변한다)."),
 'WIDE_AD_BROADCAST_CASE': (
  "재방송 사례 위성 팩트(FAD_BC) 평탄화 — grain=AD_PERF_DK×CASE_SEQ. ⚠️코어에 **1:N** 이므로 코어 measure 를 의도적으로 미노출한다(fan-out 방지) — 사례 속성 분포·빈도 분석 전용. "
  "방송 횟수는 COUNT(DISTINCT AD_PERF_DK) 로 계수한다. 아동명 미노출(개인정보 판정 대기). 🔴행수는 하드코딩하지 않는다(재적재마다 변한다)."),
 'WIDE_TARGET_BIZ': (
  "사업목표 팩트(FTG_B) 평탄화 — ORG·SPONSORSHIP·CAMPAIGN. 월 grain=MONTH_KEY. [원천: CRM → BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV]. "
  "🔴🔴 GOAL_TYPE_NM(목표유형 · 유형마다 단위 상이)으로 반드시 필터 — 후원사업·회원개발은 같은 개발 목표의 다른 분해라 합산 금지."),
 'WIDE_BUDGET': (
  "예산 팩트(FBD) 평탄화 — ORG·BUDGET_ITEM·CAMPAIGN·SPONSORSHIP. 월 grain=MONTH_KEY. 🔴외부 원천 미입고로 전건 NULL: 집행 추정 · FUNDRAISING_COST. "
  "🔴🔴`AD_COST` 는 폐기 슬롯(의도적 영구 NULL)이다 — 광고비는 **`SERVING.SV_AD.TOTAL_AD_COST`**(base `GOLD.WIDE_AD_COMBINED` ← `FACT_AD_PERFORMANCE`)를 본다. "
  "🔴🔴`PLAN_BUDGET_YEAR` 도 폐기 슬롯이다 — 연 편성예산은 **`FACT_BUDGET_YEARLY`**(연 grain)를 본다. "
  "⚠️광고비는 예산 원장에 예산항목이 없어 `BUDGET_ITEM_SK` 귀속 근거가 없다 — **예산과 같은 표에 합산하지 말 것**(원천·grain 이 다르고 광고 팩트와 이중계상이 된다). "
  "🔴🔴 **부서·캠페인별 분해가 현재 불가능**하다 — `ORG_DEPARTMENT`·`CAMPAIGN_BK`·`CAMPAIGN_NAME` 이 전건 `'(미매핑)'` 센티넬이라 「부서별 예산·집행」 요구에 **조용히 총계 1행**이 돌아온다. "
  "조직 상위 계층(CORP·DIVISION·TEAM)도 차원 자체가 비어 있다."),
 'WIDE_MEMBER_FEE': (
  "회비 분해 팩트(FMF) 평탄화 — SPONSORSHIP·PAYMENT·DATE(최종납입일)·MEMBER[현재버전]·ACQUISITION[획득귀속]. "
  "grain = 회원 × 회비월 × 후원사업 × 회비구분 × 납입유형 × 결제수단. "
  "[원천: CRM → BRONZE_CRM.TM_PM_MBRFEE_ACMSLT(회비) ∪ TM_PM_DNTN_DTLS(기부금) → SILVER.CRM_PAYMENT_BILLING → GOLD.FACT_MEMBER_FEE]. "
  "🔴기부금 지류의 청구액·회비구분 NULL 은 결측이 아니라 **구조적 부재**다 — TM_PM_DNTN_DTLS 에 RQEST_AMT·MBRFEE_DIV_CD·MBER_NO 컬럼이 **아예 없다**(회원키는 ONCE_MBER_NO). "
  "⇒ 납부율·미납 분모는 회비로 스코프 · 분자는 PAID_FEE_BILLABLE. "
  "🔴🔴WIDE_MEMBER_MONTHLY 와 **같은 표에서 회비 measure 합산 금지** — 같은 원천을 다른 grain 으로 담은 형제 팩트이며 청구액이 크게 부풀어 오른다. "
  "🔴「후원사업」·「부서」는 축이 둘이다 — SPONSORSHIP_NAME/ACQ_DEPARTMENT=획득·납입 대상, 사건 축은 WIDE_MEMBER_EVENT 소관."),
 'WIDE_MEMBER_SERVICE_COHORT': (
  "서비스 수신 코호트 — 회원(획득 코호트) × 서비스그룹 × 수신연도. 발송(FACT_MESSAGE_DISPATCH)·획득(DIM_MEMBER_ACQUISITION)·중단(FACT_MEMBER_EVENT)·행사참여(FACT_EVENT_ATTENDANCE)를 회원 단위로 미리 결합해 "
  "SV 간 교차결합 없이 「수신/미수신 비교」·「발송 후 5일 내 중단자 특성」·「수신회원 유지기간·참여횟수」를 답한다. "
  "🔴수신 행 = 그 해 그 그룹 발송을 1회 이상 받은 회원(연도별 1행) · 미수신 행 = 획득 코호트 회원 중 그 그룹을 받은 적 없는 회원(RECEIVE_YEAR NULL 1행). "
  "🟢서비스그룹은 원천 서비스코드(발송코드 MS049 상위 카테고리) 우선 · 카테고리가 없는 발송은 발송 제목 부분일치(MATCH_BASIS 로 근거 구분). 🔴수신·미수신 차이는 인과(효과)가 아니다."),
 'WIDE_SPNSR_CLS_AGGR': (
  "회원실 회비예측 월간 후원 분류별 집계(월 grain). 원천 = SILVER.MM_SPNSR_CLS_AGGR_DATA(부서 자체 수식 · ML 예측 아님). "
  "AGGR_TY_NM(감액/개발/중단/활동/회비)마다 VALUE1·VALUE2 의 뜻이 다를 수 있다 — 서로 다른 집계 유형을 합산하지 말 것. "
  "VALUE1·VALUE2 = 후원분류집계 예측값1·2 — 원천 SILVER 테이블명(회원실 회비예측 월간 후원 분류별 집계)에서 유래한 명칭이다(현업 회신). 예측값2 는 회비 유형에만 값이 있다."),
}
FILE = {k: '_wide_dept_aggr_schema.yml' if k == 'WIDE_SPNSR_CLS_AGGR' else '_wide_schema.yml' for k in NEW}
apply = '--apply' in sys.argv
txt = {}
for f in set(FILE.values()):
    p = D + f
    a, b = (hashlib.sha256(open(p, 'rb').read()).hexdigest() for _ in range(2))
    assert a == b, 'hash unstable ' + f
    txt[f] = io.open(p, encoding='utf-8').read().split('\n')
for v, new in NEW.items():
    L = txt[FILE[v]]
    i = [k for k, s in enumerate(L) if s == '  - name: ' + v]
    assert len(i) == 1, v
    j = next(k for k in range(i[0] + 1, i[0] + 6) if L[k].startswith('    description: '))
    old = yaml.safe_load(L[j].strip())['description']
    assert len(old) > 150, (v, 'multi-line description?')
    L[j] = '    description: ' + json.dumps(new, ensure_ascii=False)
    assert yaml.safe_load(L[j].strip())['description'] == new
    print(f'{v} | {len(old)} → {len(new)}자 | L{j + 1}')
if apply:
    for f, L in txt.items():
        io.open(D + f, 'w', encoding='utf-8').write('\n'.join(L))
    for f in txt:
        yaml.safe_load(open(D + f))
print('APPLIED' if apply else 'DRY-RUN')
