# -*- coding: utf-8 -*-
"""[2026-08-10 O51-F] 광고 계열 뷰 COMMENT — 이관 문안 교정 + 빈 축/희소축 경고 오버레이.

대상 = ① 신규 이관 2뷰(`WIDE_AD_BROADCAST` 35 · `WIDE_AD_DIGITAL` 33)
       ② O51-C 적용 6뷰(`WIDE_AD_PERFORMANCE`·`WIDE_GA_BEHAVIOR`·`WIDE_BUDGET`·
          `WIDE_TARGET_DEV`·`WIDE_AD_BROADCAST_CASE`·`WIDE_TARGET_BIZ`) — **경고 부착만**.

🔴 왜 ②까지 손대는가: O51-D-C 의 빈 축 감사는 **O51-D 대상 8객체만** 스캔했다. O51-C 가 이미 물리에
   배포한 136컬럼은 감사되지 않은 채였고, 재스캔에서 **전건 센티넬 8건**이 침묵 중임이 드러났다(O51-F-B).
   전건 센티넬은 GROUP BY 가 단일 그룹을 성공적으로 반환하므로 **오답이 에러 없이 나온다.**

⚠️ 99 §0 규칙 7 준수: COMMENT 에 실측 수치를 넣지 않는다. 판정(전건·극소·소수·부분·대부분)만 적고
   행수·비율은 `20_issue/00_INDEX_이슈원장.md` §O51-F 에 둔다.

🔴 P115 자기적용: 본 모듈의 채움률 근거는 **long format** 스캔에서 왔다. 다열 단일행 카운트를 눈으로
   맞추다 `CONV_CALL_CNT` 를 배선 역전으로 오판한 사건이 있었고, 원천 교차 확인으로 철회했다.
"""
_S = "실측 규모는 이슈원장 §O51-F."

# ── 원인별 템플릿 ─────────────────────────────────────────────────────────────
def _fk_null(fact, fk, extra=""):
    return ("🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: "
            f"`{fact}.{fk}` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** "
            f"차원 자체는 채워져 있다. {extra}{_S}")


def _sent(fact, fk, extra=""):
    return ("🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 "
            "단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = "
            f"`{fact}.{fk}` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — "
            f"「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. {extra}{_S}")


def _src_empty(src, extra=""):
    return ("🔴🔴[O51-F 실측] **전건 NULL — 원천 자체가 비어 있다**"
            f"(`{src}`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 "
            f"대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. {extra}{_S}")


def _dim_empty(dcol, why):
    return (f"🔴🔴[O51-F 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: {dcol}. {why} {_S}")


def _only(who):
    return f" ⚠️**{who} 전용** — 다른 원천 행은 개념 자체가 없어 NULL 이며 결측이 아니다."


def _sparse(deg, extra=""):
    return f" 🔴[O51-F 실측] 채움이 **{deg}**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. {extra}{_S}"


_HOLIDAY = ("🔴🔴[O51-F 실측] **휴일축이 미주입이다 — 전건 `FALSE`.** `DIM_DATE.IS_HOLIDAY` 에 TRUE 가 "
            "하나도 없다. NULL 이 아니라 FALSE 라서 **집계가 성공한 것처럼 보이고**, 「휴일 대비 평일 성과」 "
            "질의가 **전건 평일**로 응답된다. ⇒ 이 컬럼으로 휴일 분석을 하지 말 것(기지 **HOL-1** — 공휴일 원천이 전 스키마에 없어 외부 입고 대기). " + _S)

_CREATIVE_LOST = ("🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` "
                  "과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). ")

# ── ① 이관 문안 교정 (10_ 참고본의 누락·오기) ────────────────────────────────
# 🔴 verbatim 이관 금지(O51-D-B `(as-was)` 선례). 실측으로 적발된 것만 고친다.
AD_TRANSFER_FIX = {
    ('WIDE_AD_BROADCAST', 'AD_VIEW_RT_SRC'):
        "광고시청률(대행사 산정) — 비가산 N, 재합산 금지." + _only('VIDEO'),
    ('WIDE_AD_BROADCAST', 'CPC_SRC'):
        "CPC(대행사 산정) — 비가산 N, 재합산 금지." + _only('VIDEO'),
    ('WIDE_AD_DIGITAL', 'AD_TYPE_NM'):
        "광고유형명(대행사 표기). [O51-F BRONZE 실측] 실적재 값 = **하단DA·DA·CPT·BSA·SA·CPM**. "
        "🔴`AD_SOURCE_TYPE`(VIDEO/REBROADCAST/DIGITAL)과 **다른 개념**이다 — 이름이 비슷해 혼용되기 쉽다.",
    ('WIDE_AD_DIGITAL', 'AD_SOURCE_TYPE'):
        "광고 원천유형. 🔴본 뷰는 **DIGITAL 단일값**이다(위성이 원천유형으로 수직분할되어 있다) — "
        "GROUP BY 대상이 아니며, 유형 간 비교는 코어 `WIDE_AD_PERFORMANCE` 에서 한다.",
    ('WIDE_AD_BROADCAST', 'AD_SOURCE_TYPE'):
        "광고 원천유형 — 본 뷰는 방송 2종(**VIDEO·REBROADCAST**)만 담는다. "
        "🔴두 원천은 보고 항목이 다르다: 전용 컬럼이 서로 배타적이며 NULL 은 결측이 아니라 개념 부재다. "
        "디지털은 본 뷰에 없다 — 전 유형 집계는 코어 `WIDE_AD_PERFORMANCE`.",
}

# ── ② 빈 축(전건 NULL·전건 센티넬) 경고 — 8뷰 ────────────────────────────────
AD_EMPTY = {
    # ─ 신규 이관 2뷰 ─
    ('WIDE_AD_BROADCAST', 'AD_MEDIA_NAME'):  _fk_null('FACT_AD_PERFORMANCE', 'AD_CREATIVE_SK', _CREATIVE_LOST),
    ('WIDE_AD_BROADCAST', 'AD_CREATIVE'):    _fk_null('FACT_AD_PERFORMANCE', 'AD_CREATIVE_SK', _CREATIVE_LOST),
    ('WIDE_AD_DIGITAL',   'AD_MEDIA_NAME'):  _fk_null('FACT_AD_PERFORMANCE', 'AD_CREATIVE_SK', _CREATIVE_LOST),
    ('WIDE_AD_DIGITAL',   'AD_CREATIVE'):    _fk_null('FACT_AD_PERFORMANCE', 'AD_CREATIVE_SK', _CREATIVE_LOST),
    ('WIDE_AD_BROADCAST', 'CONV_CALL_CNT'):
        _src_empty('BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.CONV_CALL_CNT',
                   "🔴🔴종전 문서가 *「VIDEO 는 개발실적 대신 전환콜을 보고한다」* 고 적었으나 "
                   "**그 컬럼도 원천에서 전건 비어 있다** — 즉 VIDEO 구간은 개발도 전환콜도 측정할 수 없다"
                   "(AD-5 보강). REBROADCAST 원천에는 컬럼 자체가 없다. "),
    ('WIDE_AD_DIGITAL', 'MEDIA_POTENTIAL_CUST_CNT'):
        _src_empty('BRONZE_AGENCY.DGT_AD_CMPGN_DTLS.MEDIA_PTNT_CUST_CNT'),
    ('WIDE_AD_BROADCAST', 'CAMPAIGN_NAME'): _sent('FACT_AD_PERFORMANCE', 'CAMPAIGN_SK',
        "🟢대안 = 마케팅캠페인 축(`MKTG_CAMPAIGN_SK`)은 살아 있다(O45) — 광고↔개발 결합은 그 grain 에서 한다. "),
    ('WIDE_AD_DIGITAL', 'CAMPAIGN_NAME'):   _sent('FACT_AD_PERFORMANCE', 'CAMPAIGN_SK',
        "🟢대안 = 마케팅캠페인 축(`MKTG_CAMPAIGN_SK`)은 살아 있다(O45) — 광고↔개발 결합은 그 grain 에서 한다. "),
    ('WIDE_AD_BROADCAST', 'PERF_IS_HOLIDAY'): _HOLIDAY,
    ('WIDE_AD_DIGITAL',   'PERF_IS_HOLIDAY'): _HOLIDAY,

    # ─ O51-C 적용 6뷰: 경고 부착만(기존 문안 보존) ─
    ('WIDE_AD_PERFORMANCE', 'CAMPAIGN_BK'):   _sent('FACT_AD_PERFORMANCE', 'CAMPAIGN_SK'),
    ('WIDE_AD_PERFORMANCE', 'CAMPAIGN_NAME'): _sent('FACT_AD_PERFORMANCE', 'CAMPAIGN_SK'),
    ('WIDE_AD_PERFORMANCE', 'AD_CREATIVE_BK'): _sent('FACT_AD_PERFORMANCE', 'AD_CREATIVE_SK', _CREATIVE_LOST),
    ('WIDE_AD_PERFORMANCE', 'CAMPAIGN_BRAND'):        _fk_null('FACT_AD_PERFORMANCE', 'CAMPAIGN_SK'),
    ('WIDE_AD_PERFORMANCE', 'CAMPAIGN_PARENT'):       _fk_null('FACT_AD_PERFORMANCE', 'CAMPAIGN_SK'),
    ('WIDE_AD_PERFORMANCE', 'CAMPAIGN_PROMO_METHOD'): _fk_null('FACT_AD_PERFORMANCE', 'CAMPAIGN_SK'),
    ('WIDE_AD_PERFORMANCE', 'CAMPAIGN_TYPE'):         _fk_null('FACT_AD_PERFORMANCE', 'CAMPAIGN_SK'),
    ('WIDE_AD_PERFORMANCE', 'AD_MEDIA_NAME'):    _fk_null('FACT_AD_PERFORMANCE', 'AD_CREATIVE_SK', _CREATIVE_LOST),
    ('WIDE_AD_PERFORMANCE', 'AD_CREATIVE'):      _fk_null('FACT_AD_PERFORMANCE', 'AD_CREATIVE_SK', _CREATIVE_LOST),
    ('WIDE_AD_PERFORMANCE', 'AD_CREATIVE_TYPE'): _fk_null('FACT_AD_PERFORMANCE', 'AD_CREATIVE_SK', _CREATIVE_LOST),
    ('WIDE_AD_PERFORMANCE', 'AD_PLATFORM'):      _fk_null('FACT_AD_PERFORMANCE', 'AD_CREATIVE_SK'),
    ('WIDE_AD_PERFORMANCE', 'AD_PLATFORM_TYPE'): _fk_null('FACT_AD_PERFORMANCE', 'AD_CREATIVE_SK'),
    ('WIDE_AD_PERFORMANCE', 'AD_TARGET_GROUP'):  _fk_null('FACT_AD_PERFORMANCE', 'AD_CREATIVE_SK'),
    ('WIDE_AD_PERFORMANCE', 'PERF_IS_HOLIDAY'):  _HOLIDAY,

    ('WIDE_AD_BROADCAST_CASE', 'CAMPAIGN_NAME'): _sent('FACT_AD_PERFORMANCE', 'CAMPAIGN_SK'),

    ('WIDE_GA_BEHAVIOR', 'CAMPAIGN_BK'):   _sent('FACT_GA_BEHAVIOR', 'CAMPAIGN_SK'),
    ('WIDE_GA_BEHAVIOR', 'CAMPAIGN_NAME'): _sent('FACT_GA_BEHAVIOR', 'CAMPAIGN_SK'),
    ('WIDE_GA_BEHAVIOR', 'CAMPAIGN_BRAND'): _fk_null('FACT_GA_BEHAVIOR', 'CAMPAIGN_SK'),
    ('WIDE_GA_BEHAVIOR', 'IS_HOLIDAY'):    _HOLIDAY,
    ('WIDE_GA_BEHAVIOR', 'AVG_SESSION_DURATION'):
        _src_empty('BRONZE_GA4 세션 지표', "GA4 원천 적재 범위 자체가 좁다(G-5 하드블로커). "),
    ('WIDE_GA_BEHAVIOR', 'BOUNCE_RATE'):
        _src_empty('BRONZE_GA4 세션 지표', "GA4 원천 적재 범위 자체가 좁다(G-5 하드블로커). "),
    ('WIDE_GA_BEHAVIOR', 'IDENTITY_MEMNUM'):
        _fk_null('FACT_GA_BEHAVIOR', 'IDENTITY_SK',
                 "🔴익명 세션이 다수라 회원번호가 붙지 않는다 — 회원 귀속 분석은 `IDENTITY_SK` 를 "
                 "`DIM_MEMBER_IDENTITY` 브리지로 풀어야 하며 unknown 비중을 분모에서 제외할지 먼저 정할 것(O49). "),
    ('WIDE_GA_BEHAVIOR', 'YEAR'):
        ("🔴🔴[O51-F 실측] **단일값이다 — GA4 실적재가 한 해의 일부 구간뿐이다**(G-5 하드블로커). "
         "연도별·계절별 추이를 이 뷰로 산출하면 **구간 하나를 전체로 오독**한다. "
         "⇒ 기간 비교는 광고·회원 팩트로 하고, GA 지표는 해당 구간 내부 분석에만 쓸 것. " + _S),

    ('WIDE_BUDGET', 'CAMPAIGN_BK'):      _sent('FACT_BUDGET', 'CAMPAIGN_SK'),
    ('WIDE_BUDGET', 'CAMPAIGN_NAME'):    _sent('FACT_BUDGET', 'CAMPAIGN_SK'),
    ('WIDE_BUDGET', 'ORG_DEPARTMENT'):   _sent('FACT_BUDGET', 'ORG_SK',
        "🔴🔴예산 원장은 **부서별 분해가 현재 불가능**하다 — 「부서별 예산·집행」 요구에 총계 1행이 돌아온다. "),
    ('WIDE_BUDGET', 'CAMPAIGN_BRAND'):   _fk_null('FACT_BUDGET', 'CAMPAIGN_SK'),
    ('WIDE_BUDGET', 'SPONSORSHIP_BK'):   _fk_null('FACT_BUDGET', 'SPONSORSHIP_SK'),
    ('WIDE_BUDGET', 'SPONSORSHIP_NAME'): _fk_null('FACT_BUDGET', 'SPONSORSHIP_SK'),
    ('WIDE_BUDGET', 'ORG_CORP'):     _dim_empty('`DIM_ORG.CORP`',
        "`DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4)."),
    ('WIDE_BUDGET', 'ORG_DIVISION'): _dim_empty('`DIM_ORG.DIVISION`',
        "`DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4)."),
    ('WIDE_BUDGET', 'ORG_TEAM'):     _dim_empty('`DIM_ORG.TEAM`',
        "`DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4)."),
    ('WIDE_BUDGET', 'PLAN_BUDGET_YEAR'):
        _src_empty('ERP 연간 편성 원천', "🔴외부 원천 미입고(E-1/E-4 하드블로커). "),
    ('WIDE_BUDGET', 'EXEC_BUDGET_EST'):
        _src_empty('ERP 집행 추정 원천', "🔴외부 원천 미입고(E-1/E-4 하드블로커). "),
    ('WIDE_BUDGET', 'FUNDRAISING_COST'):
        _src_empty('ERP 모금성비용 원천', "🔴외부 원천 미입고(**E-1** 하드블로커) — 모금성비용은 원천 확정 대기다. "),
    ('WIDE_BUDGET', 'AD_COST'):
        _src_empty('ERP 예산 원장의 광고비 컬럼',
                   "🔴예산 원장에는 광고비 항목이 없다(**E-4**) — 광고비는 대행사 원천(`WIDE_AD_PERFORMANCE`)에서 "
                   "가져오며 **예산과 같은 표에 합산하지 말 것**(원천이 다르다 · 순서9-K 표 분리 근거). "),

    ('WIDE_TARGET_DEV', 'ORG_CORP'):     _dim_empty('`DIM_ORG.CORP`',
        "`DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4)."),
    ('WIDE_TARGET_DEV', 'ORG_DIVISION'): _dim_empty('`DIM_ORG.DIVISION`',
        "`DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4)."),
    ('WIDE_TARGET_DEV', 'ORG_TEAM'):     _dim_empty('`DIM_ORG.TEAM`',
        "`DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4)."),

    # ── 사후 대조에서 적발된 잔여 침묵 2종(2026-08-10) ─────────────────────────
    # 🔴 build 후 「스캔 위반 75건 ↔ 물리 COMMENT」를 대조했더니 25건이 문안에서 침묵했다.
    #   17건은 0행 뷰(`WIDE_TARGET_BIZ`)라 뷰 레벨에 E-6 가 적혀 있었지만 **컬럼 단독으로는 침묵**이었고,
    #   `WIDE_AD_BROADCAST_CASE.AD_SOURCE_TYPE` 은 **형제 뷰(DIGITAL)에는 달아 준 경고를 여기엔 빠뜨렸다** —
    #   같은 성격의 축을 뷰마다 다르게 처리한 일관성 결함이다. 즉시 이행한다(마커만 남기지 않는다).
    ('WIDE_AD_BROADCAST_CASE', 'AD_SOURCE_TYPE'):
        ("🔴[O51-F 실측] **단일값 REBROADCAST 뿐이다** — 본 뷰는 재방송 사례 전용이라 VIDEO 사례가 없다. "
         "GROUP BY 대상이 아니며, **이 뷰로 VIDEO 대비 재방송을 비교하면 재방송만 보고 결론을 낸다.** "
         "원천유형 비교는 코어 `WIDE_AD_PERFORMANCE` 에서 한다. " + _S),
}

# 0행 뷰(`WIDE_TARGET_BIZ`) 전 컬럼 — 컬럼 단독으로도 사유가 보이게 한다.
_ZERO_ROW = ("🔴[O51-F 실측] **본 뷰는 현재 0행이다**(E-6 외부 원천 미입고) — 이 컬럼이 비어 있는 것은 "
             "컬럼 결함이 아니라 **뷰 전체에 행이 없어서**다. 입고되면 자동으로 채워진다. "
             "⚠️0행 뷰는 집계가 NULL·0 을 반환하므로 「값이 0이다」로 오독하지 말 것. " + _S)
for _c in ('MONTH_KEY', 'CAL_YEAR', 'CAL_MONTH', 'ANNUAL_GOAL_CNT', 'SUPP_GOAL_CNT',
           'ANNUAL_CUM_GOAL_CNT', 'SUPP_CUM_GOAL_CNT', 'DW_SOURCE_SYSTEM', 'ORG_CORP',
           'ORG_DIVISION', 'ORG_DEPARTMENT', 'ORG_TEAM', 'SPONSORSHIP_BK', 'SPONSORSHIP_NAME',
           'CAMPAIGN_BK', 'CAMPAIGN_BRAND', 'CAMPAIGN_NAME'):
    AD_EMPTY[('WIDE_TARGET_BIZ', _c)] = _ZERO_ROW

# ── ③ 희소축 경고 ────────────────────────────────────────────────────────────
AD_SPARSE = {
    ('WIDE_AD_DIGITAL', 'PAGE_TYPE'):      _sparse('극히 일부'),
    ('WIDE_AD_DIGITAL', 'GROUP_DIV'):      _sparse('극히 일부'),
    ('WIDE_AD_DIGITAL', 'AD_GROUP_NM'):    _sparse('극히 일부'),
    ('WIDE_AD_DIGITAL', 'READ_CNT'):       _sparse('소수'),
    ('WIDE_AD_DIGITAL', 'VTR_SRC'):        _sparse('소수', "base 가 원천에 없어 DW 재계산도 불가하다. "),
    ('WIDE_AD_DIGITAL', 'CTR_SRC'):        _sparse('소수', "🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것. "),
    ('WIDE_AD_DIGITAL', 'CVR_SRC'):        _sparse('소수', "🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것. "),
    ('WIDE_AD_DIGITAL', 'CPC_SRC'):        _sparse('소수', "🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것. "),
    ('WIDE_AD_DIGITAL', 'CPM_SRC'):        _sparse('소수', "🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것. "),
    ('WIDE_AD_DIGITAL', 'CPA_SRC'):        _sparse('소수', "🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것. "),
    ('WIDE_AD_DIGITAL', 'DEV_UNIT_PRICE_SRC'):
        _sparse('소수', "⚠️원천 포맷 변경으로 개발건수와 **상호배타**다(AD-3) — 개발단가는 두 컬럼이 "
                        "기간을 보완하는 관계이며 교차검증 관계가 아니다. "),
    ('WIDE_AD_DIGITAL', 'CREATIVE_TYPE'):  _sparse('부분'),
    ('WIDE_AD_DIGITAL', 'GA_CONV_CNT'):    _sparse('부분', "🔴비율 metric 의 분모로 쓸 때는 분자 커버리지를 "
                                                          "먼저 맞출 것 — 분모만 부분이면 조용히 과대계상된다(P18). "),
    ('WIDE_AD_BROADCAST', 'CTV_DIV'):      _sparse('VIDEO 안에서도 소수'),
    ('WIDE_AD_BROADCAST', 'BRDC_DIV'):     _sparse('REBROADCAST 안에서도 일부'),
    ('WIDE_AD_BROADCAST', 'SPOT_TYPE'):    _sparse('VIDEO 안에서 부분'),
    ('WIDE_AD_BROADCAST', 'AD_END_TIME'):  _sparse('VIDEO 안에서 부분',
        "⚠️시작시간은 더 많이 채워져 있어 **시작·종료를 함께 요구하면 표본이 줄어든다**. "),
    ('WIDE_AD_BROADCAST', 'INBOUND_CALL'): _sparse('VIDEO 안에서 부분',
        "🔴채널·시간대별 인입콜 비교 시 미보고 행이 0 이 아니라 NULL 이므로 평균이 왜곡될 수 있다. "),
    ('WIDE_AD_BROADCAST', 'DVLP_MEMBER_CNT'): _only('REBROADCAST') +
        " ⚠️GA 전환이 아니다(O16 분리) — 재방송 개발실적이다.",
    ('WIDE_AD_BROADCAST', 'DVLP_CNT'):        _only('REBROADCAST') +
        " ⚠️GA 전환이 아니다(O16 분리) — 재방송 개발실적이다.",
}

# ── ④ 뷰 레벨 description (규칙 7 — 수치 제거) ───────────────────────────────
# 🔴 종전 뷰 description 이 행수를 하드코딩해 stale 이 됐다: 재적재(O41)로 실제 행수가 늘었고
#    그 불일치가 「원인 미규명」으로 3개월 방치됐다. ⇒ 수치를 빼고 관계만 적는다.
AD_VIEW_DESC = {
    'WIDE_AD_BROADCAST':
        "방송광고 위성 팩트(FAD_B) 평탄화 — grain=AD_PERF_DK. 코어와 1:1 이라 코어 measure"
        "(AD_COST·INBOUND_CALL) 동반 노출 → 방송 분석을 단일 뷰로 완결한다. "
        "⚠️코어 뷰(WIDE_AD_PERFORMANCE)와 함께 합산하면 방송 행이 이중계상된다 — 전 유형 집계는 코어 뷰만. "
        "⚠️컬럼 NULL 은 두 방송 원천(VIDEO·REBROADCAST) 중 한쪽 전용 속성이며 결측이 아니다. "
        "DVLP_MEMBER_CNT·DVLP_CNT = 재방송 개발실적(O16 분리 · GA 전환 아님). _SRC 는 대행사 산정 비가산(N). "
        "🔴[O51-F] 매체·소재축과 캠페인명은 사용 불가 상태다(FK 미배선 = P52·O38-C·Q10) · 휴일축 미주입(HOL-1). "
        "🔴행수는 하드코딩하지 않는다 — 재적재마다 변한다(규칙 7).",
    'WIDE_AD_DIGITAL':
        "디지털광고 위성 팩트(FAD_D) 평탄화 — grain=AD_PERF_DK. 코어와 1:1 이라 코어 measure"
        "(AD_COST·IMPRESSIONS·CLICKS·GA_CONV_*) 동반 노출 → 비율 재계산 base 를 같은 뷰에서 확보한다. "
        "⚠️코어 뷰와 함께 합산하면 디지털 행이 이중계상된다. "
        "_SRC 7종은 대행사 산정 **비가산(N)** — 집계는 base 재계산(예: CTR=SUM(CLICKS)/SUM(IMPRESSIONS))이고 "
        "_SRC 는 행 단위 대조용이다. DEVICE_TYPE 동반(디지털은 기기가 실존 · 실적재 PC·M). "
        "🔴[O51-F] 매체·소재축과 캠페인명은 사용 불가 상태다(FK 미배선 = P52·O38-C·Q10) · 휴일축 미주입(HOL-1) · "
        "AD_SOURCE_TYPE 은 단일값이다. 🔴행수는 하드코딩하지 않는다(규칙 7).",
    'WIDE_AD_PERFORMANCE':
        "광고 성과 **코어** 팩트(FAD) 평탄화 — DATE·CAMPAIGN·AD_CREATIVE·DEVICE. grain=AD_PERF_DK. "
        "[2026-07-28 DEC-8] 방송 degen 5종은 위성 뷰로 이관했다 — 본 뷰는 3원천 공통 컬럼만 담는다. "
        "**전 유형 집계는 본 뷰만 사용**할 것(위성 뷰와 합산하면 이중계상). "
        "🔴[O51-F 실측] `CAMPAIGN_SK`·`AD_CREATIVE_SK` 는 **0 스캐폴드**이며 그 귀결이 컸다 — 캠페인·매체·소재 "
        "속성이 전건 NULL 또는 전건 `'(미매핑)'` 센티넬이다(기지 **P52·O38-C** · 연결키는 **Q10**). 센티넬은 GROUP BY 가 "
        "단일 그룹을 반환해 **오답이 에러 없이 나온다.** 🟢대안 = 마케팅캠페인 축(O45). "
        "🔴휴일축(`PERF_IS_HOLIDAY`)도 전건 FALSE 로 미주입이다(**HOL-1**). "
        "DEVICE_SK 는 실배선 완료(DEC-10). ⚠️AD_SOURCE_TYPE(원천 출처축) ≠ AD_CREATIVE_TYPE(소재 광고유형). "
        "🔴행수는 하드코딩하지 않는다 — 종전 기재가 재적재로 stale 이 됐다(규칙 7).",
    'WIDE_GA_BEHAVIOR':
        "GA 행동 팩트(FGA) 평탄화 — DATE·GA_EVENT·GA_SOURCE·DEVICE·CAMPAIGN·IDENTITY. 비가산 지표의 상위 재합산 금지. "
        "IDENTITY_* 는 `DIM_MEMBER_IDENTITY` 활성으로 실조인된다 — 브리지는 1:1 이라 팬아웃이 없다(O49). "
        "🔴🔴[O51-F 실측] **GA4 실적재 구간이 한 해의 일부뿐이다**(G-5 하드블로커) → `YEAR` 가 단일값이므로 "
        "연도·계절 추이를 이 뷰로 내면 **구간 하나를 전체로 오독**한다. 기간 비교는 광고·회원 팩트로 할 것. "
        "🔴세션 품질 지표(AVG_SESSION_DURATION·BOUNCE_RATE)와 회원번호는 전건 비어 있고, 캠페인축은 전건 센티넬이다. "
        "🔴휴일축(`IS_HOLIDAY`)도 전건 FALSE 로 미주입(**HOL-1**). "
        "⚠️종전 기재 「GA4 1일 기반」은 stale 이었다 — 실적재 구간은 그보다 넓고, 정확한 범위는 이슈원장 §O51-F.",
    'WIDE_BUDGET':
        "예산 팩트(FBD) 평탄화 — ORG·BUDGET_ITEM·CAMPAIGN·SPONSORSHIP. 월 grain=MONTH_KEY. "
        "🔴외부 원천 미입고로 전건 NULL: 연간 편성·집행 추정 · FUNDRAISING_COST(**E-1**) · AD_COST(**E-4**). "
        "⚠️광고비는 예산 원장에 항목이 없다 — 대행사 원천(`WIDE_AD_PERFORMANCE`)에서 가져오며 "
        "**예산과 같은 표에 합산하지 말 것**(원천이 다르다 · 순서9-K 표 분리 근거). "
        "🔴🔴[O51-F 실측] **부서·캠페인별 분해가 현재 불가능**하다 — `ORG_DEPARTMENT`·`CAMPAIGN_BK`·`CAMPAIGN_NAME` 이 "
        "전건 `'(미매핑)'` 센티넬이라 「부서별 예산·집행」 요구에 **조용히 총계 1행**이 돌아온다. "
        "조직 상위 계층(CORP·DIVISION·TEAM)도 차원 자체가 비어 있다(CONF-4).",
    'WIDE_TARGET_DEV':
        "회원개발 목표 팩트(FTG_D) 평탄화 — ORG. 월 grain=MONTH_KEY. "
        "[2026-08-05 O38] MONTH_KEY 연도 복원으로 CAL_YEAR 가 유효해졌다(종전 1~12 라 FLOOR(MONTH_KEY/100)=0 전건). "
        "목표 대비 실적은 `WIDE_DEV_ACHIEVEMENT` 소관이다. "
        "🔴[O51-F 실측] 조직 상위 계층(ORG_CORP·ORG_DIVISION·ORG_TEAM)은 차원 자체가 비어 있어 "
        "**부서 단위까지만 분해된다**(CONF-4).",
    'WIDE_AD_BROADCAST_CASE':
        "재방송 사례 위성 팩트(FAD_BC) 평탄화 — grain=AD_PERF_DK×CASE_SEQ. "
        "⚠️코어에 **1:N** 이므로 코어 measure 를 의도적으로 미노출한다(fan-out 방지) — 사례 속성 분포·빈도 분석 전용. "
        "방송 횟수는 COUNT(DISTINCT AD_PERF_DK) 로 계수한다. 아동명 미노출(PII 판정 대기 O14). "
        "🔴[O51-F] 캠페인명은 전건 센티넬이라 캠페인별 분해가 불가하다(P52·Q10 계열). "
        "🔴행수는 하드코딩하지 않는다(규칙 7).",
}


# ── ⑤ 멱등화 — 이전 O51-F 오버레이 제거 ───────────────────────────────────────
# 🔴🔴 왜 필요한가(실측 사고): 오버레이의 base 는 **이미 패치된 yml** 이다. 템플릿 문구를 고친 뒤 재실행하면
#   `if add not in d[col]` 가드가 「새 문구는 없다」고 판정해 **구 문구 뒤에 신 문구를 덧붙인다** ⇒ 경고가
#   이중으로 쌓인다(본 세션에서 `AD_MEDIA_NAME` 이 구 AD-6 문구 + 신 P52 문구를 동시 보유한 상태로 실측됐다).
#   ⇒ 적용 전에 **직전 오버레이를 잘라낸다.** 오버레이는 항상 문말에 붙으므로 첫 마커부터 끝까지 제거하면 된다.
OVERLAY_MARKS = ('🔴🔴[O51-F 실측]', '🔴[O51-F 실측]', '⚠️**REBROADCAST 전용**', '⚠️**VIDEO 전용**')


def strip_overlay(s):
    idx = [s.find(m) for m in OVERLAY_MARKS if s.find(m) >= 0]
    return s[:min(idx)].rstrip() if idx else s


def apply_ad(view, d):
    """이관 문안 교정 → 직전 오버레이 제거 → 빈 축·희소축 경고 덧붙임."""
    n_fix = n_add = 0
    for col in list(d):
        if (view, col) in AD_TRANSFER_FIX:
            d[col] = AD_TRANSFER_FIX[(view, col)]      # 전체 교체(오버레이도 함께 소거된다)
            n_fix += 1
        else:
            d[col] = strip_overlay(str(d[col]))        # 멱등화
    for col in list(d):
        for tbl in (AD_EMPTY, AD_SPARSE):
            if (view, col) in tbl:
                add = tbl[(view, col)].strip()
                if add not in d[col]:
                    d[col] = d[col].rstrip() + " " + add
                    n_add += 1
    return n_fix, n_add
