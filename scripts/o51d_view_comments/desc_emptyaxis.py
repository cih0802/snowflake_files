# -*- coding: utf-8 -*-
"""[2026-08-07 O51-D-C] **빈 축 경고** — 전건 NULL / 전건 센티넬 컬럼.

🔴 왜 필요한가: O51-D 의 목적은 오답 방지인데, 43컬럼이 「값이 하나도 없다」는 사실을 문안에서 침묵했다.
   전건 센티넬('(미매핑)')은 NULL 보다 위험하다 — GROUP BY 하면 단일 그룹이 나와 **집계에 성공한 것처럼 보인다.**

⚠️ 99 §0 규칙 7 준수: **COMMENT 에 실측 수치를 넣지 않는다.** 판정(전건/다수/과반)만 적고
   행수·비율은 `20_issue/00_INDEX_이슈원장.md` §O51-D-C 에 둔다. 수치는 재빌드·입고마다 stale 이 된다.

원인 3유형(실측으로 분리):
  A) 팩트 FK 가 전건 센티넬 → 차원 속성이 NULL, BK/NAME 만 '(미매핑)' 문자열
  B) 차원 컬럼 자체가 전건 NULL
  C) 팩트 컬럼 자체가 전건 NULL

탐지기 = `nullscan.py`(상시 게이트). 새 컬럼·새 뷰가 늘면 다시 돌린다.

⚠️ 파일명 주의: 원래 `desc_empty.py` 였으나 그 경로가 스테이지에서 유령 상태가 돼(P99: 마운트 쓰기가
   조용히 사라지고 경로가 ENOENT 로 고착) 이름을 바꿨다. `desc_empty.py` 를 다시 만들려 하지 말 것.
"""
_SRC = "실측 규모는 이슈원장 §O51-D-C."


def _fk(fk, fact):
    return ("🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: "
            f"`{fact}.{fk}` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** "
            f"차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. {_SRC}")


def _sent(fk, fact):
    return ("🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 "
            "단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = "
            f"`{fact}.{fk}` 의 실측값이 센티넬 하나뿐이다. "
            f"⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. {_SRC}")


def _dim(dcol, why):
    return (f"🔴🔴[O51-D 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: {dcol}. {why} {_SRC}")


def _fact(fcol):
    return ("🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**"
            f"(`{fcol}`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). "
            f"필터 조건으로 쓰면 전건이 탈락한다. {_SRC}")


_ORG = ("`DIM_ORG` 는 **DEPARTMENT 만 채워져 있고 CORP·DIVISION·TEAM 은 전건 비어 있다.** "
        "부서 코드에서 상위 계층을 유도하는 규칙이 미확정이다(CONF-4) ⇒ **조직 계층 분석은 현재 불가**하고 "
        "부서 단위까지만 된다.")
_APPLY = "행사 신청채널은 원천 행사 마스터에 값이 없다 ⇒ **신청채널 분석은 불가**하다."

EMPTY_AXIS = {
    # ── A) 팩트 FK 전건 센티넬 → 차원 속성 NULL ────────────────────────────
    ('WIDE_MEMBER_MONTHLY', 'CAMPAIGN_BRAND'):        _fk('CAMPAIGN_SK', 'FACT_MEMBER_MONTHLY'),
    ('WIDE_MEMBER_MONTHLY', 'CAMPAIGN_PARENT'):       _fk('CAMPAIGN_SK', 'FACT_MEMBER_MONTHLY'),
    ('WIDE_MEMBER_MONTHLY', 'CAMPAIGN_PROMO_METHOD'): _fk('CAMPAIGN_SK', 'FACT_MEMBER_MONTHLY'),
    ('WIDE_MEMBER_MONTHLY', 'CAMPAIGN_TYPE'):         _fk('CAMPAIGN_SK', 'FACT_MEMBER_MONTHLY'),
    ('WIDE_MEMBER_MONTHLY', 'SPONSORSHIP_ABBR'):      _fk('SPONSORSHIP_SK', 'FACT_MEMBER_MONTHLY'),
    ('WIDE_MEMBER_MONTHLY', 'PAYMENT_SETTLE_METHOD'): _fk('PAYMENT_SK', 'FACT_MEMBER_MONTHLY'),
    ('WIDE_SERVICE_EVENT', 'CAMPAIGN_BRAND'):         _fk('CAMPAIGN_SK', 'FACT_SERVICE_EVENT'),
    ('WIDE_SERVICE_EVENT', 'CAMPAIGN_PARENT'):        _fk('CAMPAIGN_SK', 'FACT_SERVICE_EVENT'),
    ('WIDE_SERVICE_EVENT', 'CAMPAIGN_PROMO_METHOD'):  _fk('CAMPAIGN_SK', 'FACT_SERVICE_EVENT'),
    ('WIDE_EVENT_PARTICIPATION', 'CAMPAIGN_BRAND'):   _fk('CAMPAIGN_SK', 'FACT_EVENT_PARTICIPATION'),
    ('WIDE_MEMBER_MONTHLY', 'PAYMENT_FEE_TYPE'):
        _fk('PAYMENT_SK', 'FACT_MEMBER_MONTHLY')
        + " ⚠️게다가 `DIM_PAYMENT.FEE_TYPE` 자체도 전건 비어 있다(이중 결손).",
    # ── A') 전건 센티넬 **문자열** ────────────────────────────────────────
    ('WIDE_MEMBER_MONTHLY', 'CAMPAIGN_BK'):           _sent('CAMPAIGN_SK', 'FACT_MEMBER_MONTHLY'),
    ('WIDE_MEMBER_MONTHLY', 'CAMPAIGN_NAME'):         _sent('CAMPAIGN_SK', 'FACT_MEMBER_MONTHLY'),
    ('WIDE_MEMBER_MONTHLY', 'SPONSORSHIP_BK'):        _sent('SPONSORSHIP_SK', 'FACT_MEMBER_MONTHLY'),
    ('WIDE_MEMBER_MONTHLY', 'SPONSORSHIP_NAME'):      _sent('SPONSORSHIP_SK', 'FACT_MEMBER_MONTHLY'),
    ('WIDE_MEMBER_MONTHLY', 'PAYMENT_METHOD'):        _sent('PAYMENT_SK', 'FACT_MEMBER_MONTHLY'),
    ('WIDE_SERVICE_EVENT', 'CAMPAIGN_BK'):            _sent('CAMPAIGN_SK', 'FACT_SERVICE_EVENT'),
    ('WIDE_SERVICE_EVENT', 'CAMPAIGN_NAME'):          _sent('CAMPAIGN_SK', 'FACT_SERVICE_EVENT'),
    ('WIDE_EVENT_PARTICIPATION', 'CAMPAIGN_BK'):      _sent('CAMPAIGN_SK', 'FACT_EVENT_PARTICIPATION'),
    ('WIDE_EVENT_PARTICIPATION', 'CAMPAIGN_NAME'):    _sent('CAMPAIGN_SK', 'FACT_EVENT_PARTICIPATION'),
    ('WIDE_EVENT_PARTICIPATION', 'SPONSORSHIP_BK'):   _sent('SPONSORSHIP_SK', 'FACT_EVENT_PARTICIPATION'),
    ('WIDE_EVENT_PARTICIPATION', 'SPONSORSHIP_NAME'): _sent('SPONSORSHIP_SK', 'FACT_EVENT_PARTICIPATION'),
    # ── B) 차원 컬럼 자체 전건 NULL ───────────────────────────────────────
    ('WIDE_MEMBER_EVENT', 'ORG_CORP'):                   _dim('`DIM_ORG.CORP`', _ORG),
    ('WIDE_MEMBER_EVENT', 'ORG_DIVISION'):               _dim('`DIM_ORG.DIVISION`', _ORG),
    ('WIDE_MEMBER_EVENT', 'ORG_TEAM'):                   _dim('`DIM_ORG.TEAM`', _ORG),
    ('WIDE_EVENT_PARTICIPATION', 'EVENT_APPLY_CHANNEL'): _dim('`DIM_EVENT.APPLY_CHANNEL`', _APPLY),
    # ── C) 팩트 컬럼 자체 전건 NULL ───────────────────────────────────────
    ('WIDE_MEMBER_MONTHLY', 'DEV_TYPE'):          _fact('FACT_MEMBER_MONTHLY.DEV_TYPE'),
    ('WIDE_MEMBER_MONTHLY', 'NEW_FLAG'):          _fact('FACT_MEMBER_MONTHLY.NEW_FLAG'),
    ('WIDE_MEMBER_MONTHLY', 'INCREASE_FLAG'):     _fact('FACT_MEMBER_MONTHLY.INCREASE_FLAG'),
    ('WIDE_MEMBER_MONTHLY', 'REDONATE_FLAG'):     _fact('FACT_MEMBER_MONTHLY.REDONATE_FLAG'),
    ('WIDE_MEMBER_MONTHLY', 'JOIN_DATE'):
        _fact('FACT_MEMBER_MONTHLY.JOIN_DATE')
        + " 🟢대체 경로 = `MEMBER_FIRST_JOIN_DATE`(DIM_MEMBER 경유).",
    ('WIDE_MEMBER_MONTHLY', 'STOP_DATE'):
        _fact('FACT_MEMBER_MONTHLY.STOP_DATE')
        + " 🟢대체 경로 = `MEMBER_LAST_STOP_DATE`(DIM_MEMBER as-of) 또는 WIDE_MEMBER_EVENT.",
    ('WIDE_MEMBER_MONTHLY', 'AMOUNT_BAND1'):      _fact('FACT_MEMBER_MONTHLY.AMOUNT_BAND1'),
    ('WIDE_MEMBER_MONTHLY', 'AMOUNT_BAND2'):      _fact('FACT_MEMBER_MONTHLY.AMOUNT_BAND2'),
    ('WIDE_MEMBER_MONTHLY', 'PERIOD_BAND1'):      _fact('FACT_MEMBER_MONTHLY.PERIOD_BAND1'),
    ('WIDE_MEMBER_MONTHLY', 'PERIOD_BAND2'):      _fact('FACT_MEMBER_MONTHLY.PERIOD_BAND2'),
    ('WIDE_MEMBER_MONTHLY', 'NEW_EXISTING_FLAG'): _fact('FACT_MEMBER_MONTHLY.NEW_EXISTING_FLAG'),
    ('WIDE_MEMBER_EVENT', 'NEW_EXISTING_FLAG'):   _fact('FACT_MEMBER_EVENT.NEW_EXISTING_FLAG'),
    ('WIDE_SERVICE_EVENT', 'MAIL_RECEIVE_FLAG'):  _fact('FACT_SERVICE_EVENT.MAIL_RECEIVE_FLAG'),
    ('WIDE_SERVICE_EVENT', 'MEMBER_STOP_FLAG'):   _fact('FACT_SERVICE_EVENT.MEMBER_STOP_FLAG'),
    ('WIDE_SERVICE_EVENT', 'SEND_STATUS2'):
        _fact('FACT_SERVICE_EVENT.SEND_STATUS2')
        + " 🟢대체 경로 = `SEND_STATUS`(대부분 채워져 있다).",
    ('WIDE_EVENT_PARTICIPATION', 'INCREASE_FLAG'):  _fact('FACT_EVENT_PARTICIPATION.INCREASE_FLAG'),
    ('WIDE_EVENT_PARTICIPATION', 'SELF_PART_FLAG'): _fact('FACT_EVENT_PARTICIPATION.SELF_PART_FLAG'),
}

# ── 부분 센티넬(전건은 아니지만 비중이 커서 오답 위험) ────────────────────
PARTIAL = {
    ('WIDE_MEMBER_EVENT', 'ORG_DEPARTMENT'):
        " 🔴[O51-D 실측] `'(미매핑)'` 이 **다수**다 — 중단원천 행은 부서가 없다. "
        "부서별 집계 시 이 그룹이 상위권 규모로 나타나며 **실재 부서가 아니다.** " + _SRC,
    ('WIDE_EVENT_PARTICIPATION', 'EVENT_BK'):
        " 🔴[O51-D 실측] `'(미매핑)'` 이 **다수**다 — 행사 마스터 없는 고아 행사가 한 그룹으로 뭉친다. "
        "행사 식별은 `PART_EVENT_BK` 를 쓴다. " + _SRC,
    ('WIDE_EVENT_PARTICIPATION', 'EVENT_NAME'):
        " 🔴[O51-D 실측] `'(미매핑)'` 이 **다수**다 — 고아 행사들이 한 이름으로 합쳐진다. " + _SRC,
    ('WIDE_SERVICE_EVENT', 'SEND_TYPE_L'):
        " 🔴🔴[O51-D 실측] `'(미매핑)'` 이 **과반을 크게 넘는다** — 발송구분 대분류는 매칭되는 행이 소수다. "
        "커버리지를 모르고 대분류별 비중을 내면 **결론이 뒤집힌다.** " + _SRC,
}


def apply_empty_axis(view, d):
    """d = {col: desc}. 실측 근거 경고를 **덧붙인다**(기존 문안 보존)."""
    n = 0
    for col in list(d):
        for tbl in (EMPTY_AXIS, PARTIAL):
            if (view, col) in tbl:
                add = tbl[(view, col)].strip()
                if add not in d[col]:
                    d[col] = d[col].rstrip() + " " + add
                    n += 1
    return n
