# field_mapping_override.py — 보고서필드 → GOLD 매핑 교정 등록부
# Co-authored with CoCo
"""
[2026-08-06 O44/O45] P0 매핑 교정 — GOLD 변경 없이 39필드를 바로잡는다.

🔴 왜 등록부로 분리하는가
  · 정본 인벤토리(`99_provided_definition/04·05_*_보고서필드 인벤토리.md`)는 현업 산출물이고
    우리가 고칠 권한이 없다. 그러나 그 라벨을 GOLD 컬럼에 **정확일치로 붙인 결과가 틀렸다**.
  · 생성기 본문에 하드코딩하면 O43(P85)에서 겪은 「생성기 안에서 stale 되는 사실」이 재발한다.
    → 큐레이션은 **등록부로 분리**하고 매 실행 유효성을 검증한다(P85-②).

교정 근거는 전부 물리 실측(2026-08-06)이며, 각 항목에 근거를 적어 둔다.
사용법: `gen_metric_gold_mapping.py` 가 이 모듈을 import 해서 보고서필드 행 출력 시 적용한다.
"""

# (필드값) → (교정 GOLD 매핑, 사유, 유형)
#   유형: WRONG_DIM   매핑 대상 차원이 잘못 지정됨
#         WRONG_GRAIN 팩트의 grain 에 그 축이 없음
#         OPENED_O45  O45 신설 객체로 새로 열림
FIELD_MAPPING_OVERRIDE = {
    "회원번호": (
        "DIM_MEMBER.MEMBER_DK", "WRONG_DIM",
        "`DIM_MEMBER_IDENTITY` 는 GA↔CRM 신원 브리지 전용 차원이고 **CRM 팩트에서 가는 FK 가 없다**. "
        "회원번호는 모든 팩트에 `MEMBER_DK` 로 실재하고 `DIM_MEMBER` 자연키 조인이 살아 있다. "
        "이 오매핑이 12필드에 걸쳐 반복됐다."),
    "member_id(=회원번호)": (
        "DIM_MEMBER.MEMBER_DK", "WRONG_DIM",
        "위와 동일. 단 앵커가 `FACT_AD_PERFORMANCE` 인 경우 **광고 팩트에는 회원 축이 아예 없다** — "
        "회원 귀속은 GA4 전기간 입고(G-5) + 광고 연결키(Q10) 이후에만 가능하다."),
    "아동번호": (
        "(미매핑 — 결연 도메인 SILVER 모델 부재)", "WRONG_DIM",
        "`TM_RM_CHILD_MSTR_INFO` 는 `_sources.yml` 미등록 = **SILVER 모델 자체가 없다**. "
        "결함이 아니라 도메인 스코프 밖이다(07_코드체계 §4-1 의 「SILVER 모델 부재」 6건과 동일 계열)."),
    "일별 실적": (
        "FACT_MEMBER_EVENT.DEV_CNT", "WRONG_GRAIN",
        "`FACT_MEMBER_MONTHLY` 에 `DATE_SK` 가 **없다**(물리 확인) — 일자 분해가 원천적으로 불가하다. "
        "일 grain 은 `FME.DATE_SK` 뿐이다. ⚠️단 목표(`FACT_TARGET_DEV`)에는 일자 축이 없으므로 "
        "**목표 대비 일별 달성률은 여전히 불가**하다(목표 원천 `TM_CM_MBER_DVLP_GOAL` 시간축 = `STDYY`+`STDR_MT`)."),
    "월 실적": (
        "WIDE_DEV_ACHIEVEMENT.ACTUAL_CNT", "WRONG_GRAIN",
        "부서별 실적을 `FMM` 에서 낼 수 없다 — **`FMM` 에 `ORG_SK` 가 없다**(물리 확인). "
        "원천이 부서를 주는 곳은 개발 사건(`ACMSLT_DEPT_CD`)뿐이다. "
        "목표·실적 대응 정본은 `WIDE_DEV_ACHIEVEMENT`(grain `MONTH_KEY × ORG_SK × DEV_TYPE`)."),
    "기준년월": (
        "FACT_MEMBER_MONTHLY.MONTH_KEY", "WRONG_GRAIN",
        "월 팩트에 `DIM_DATE`(일 차원)를 걸 수 없다. 월 축은 `MONTH_KEY` 이고 라벨은 `SERVING.DIM_MONTH` 다."),
    "기준일(납입일)": (
        "FACT_MEMBER_FEE.LAST_PAY_DATE_SK", "OPENED_O45",
        "[O45] 회비 팩트 신설로 열렸다. 납입일(`PAY_DE` 채움 41,115,150 = 86.5%)은 회비 grain 에만 있다. "
        "🔴 시점 축이며 합계가 아니다."),
    "납입방식": (
        "FACT_MEMBER_FEE.PAYMENT_SK", "OPENED_O45",
        "[O45] 결제수단은 **회비 행의 속성**이다(`SETLE_CD` 11종 · 채움 99.78%). `FMM` 은 회원-월 grain 이라 "
        "붙이면 귀속 규칙이 필요했다. ⚠️라벨 커버리지 99.3% — 5종(`3`·`10`·`6`·`13`·`7`)은 코드그룹 미특정(O45-B)."),
    "결제방식": (
        "FACT_MEMBER_FEE.PAYMENT_SK", "OPENED_O45", "위 「납입방식」과 동일 축이다."),
    "후원사업": (
        "FACT_MEMBER_FEE.SPONSORSHIP_SK (회비) / DIM_MEMBER_ACQUISITION.ACQ_SPONSORSHIP_SK (획득)",
        "OPENED_O45",
        "🔴 **같은 라벨이 두 축이다**. 회비·미납 분석의 후원사업 = **납입 대상**(회비 행에 붙은 값, "
        "`SPNSR_BSNS_ID` 채움 99.83%) → `FACT_MEMBER_FEE`. 개발·중단·회원특성 분석의 후원사업 = "
        "**획득 시점**(그 회원을 데려온 사업) → `DIM_MEMBER_ACQUISITION`. 한 회원이 여러 후원사업에 내므로 "
        "회원-월 grain 에 하나로 붙일 수 없다(회원-월 37,148,615 → 회원-월-후원사업 39,563,730). "
        "⚠️ 목표(`FACT_TARGET_DEV`)에는 후원사업 축이 없어 **목표 대비 후원사업별 달성률은 불가**하다."),
    "브랜드": (
        "DIM_MEMBER_ACQUISITION.ACQ_BRAND", "OPENED_O45",
        "[O45] `FMM.CAMPAIGN_SK` 는 O8(다중귀속 규칙 미확정)로 전건 센티넬이다. "
        "**「획득 시점」 명시 규칙**으로 회원 1행에 캠페인을 확정해 우회했다(팬아웃 0 실측)."),
    "상위캠페인": (
        "DIM_MEMBER_ACQUISITION.ACQ_PARENT_CAMPAIGN_NAME", "OPENED_O45", "위와 동일 경로."),
    "홍보방법": (
        "DIM_MEMBER_ACQUISITION.ACQ_PROMO_METHOD_NAME", "OPENED_O45", "위와 동일 경로."),
    "캠페인": (
        "DIM_MEMBER_ACQUISITION.ACQ_CAMPAIGN_NAME", "OPENED_O45", "위와 동일 경로."),
    "캠페인명": (
        "DIM_MEMBER_ACQUISITION.ACQ_CAMPAIGN_NAME", "OPENED_O45", "위와 동일 경로."),
    "후원사업(2)명": (
        "DIM_MEMBER_ACQUISITION.ACQ_SPONSORSHIP_NAME", "OPENED_O45",
        "전환회원 특성·LTV 섹션의 후원사업은 **획득 귀속**이 의미상 맞다(그 회원을 데려온 사업)."),
    "부서": (
        "DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT (회원분석) / WIDE_MEMBER_EVENT.ORG_DEPARTMENT (개발실적)",
        "OPENED_O45",
        "🔴 **같은 라벨이 두 축이다**(O34 `_AT_PLEDGE`/`_AT_EVENT` 규약 재적용). "
        "개발실적보고의 부서 = **사건 부서** · 연간분석(회비)의 부서 = **획득 부서**. 두 값은 다르다."),
    "부서명": (
        "DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT", "OPENED_O45", "위 「부서」와 동일 — 회원 분석 문맥."),
    "가입부서": (
        "DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT", "OPENED_O45",
        "「가입」 부서는 정의상 **획득 시점** 부서다 — 현재 소속(`DIM_ORG.DEPARTMENT`)에 붙이면 "
        "조직 개편 이력이 섞여 조용히 틀린다(P60)."),
    "최초브랜드": (
        "DIM_MEMBER_ACQUISITION.ACQ_BRAND", "OPENED_O45",
        "「최초」 = 획득 시점. `DIM_CAMPAIGN.BRAND` 는 캠페인 속성이라 **회원 축으로 도달할 수 없다**"
        "(`FMM.CAMPAIGN_SK` 전건 센티넬 = O8)."),
    "후원사업명": (
        "FACT_MEMBER_FEE.SPONSORSHIP_SK (회비) / DIM_MEMBER_ACQUISITION.ACQ_SPONSORSHIP_SK (획득)",
        "OPENED_O45", "위 「후원사업」과 동일 — 🔴 같은 라벨이 두 축이다."),
    # ── 단위 함정(건/명) — 인벤토리 라벨이 「명」이라 적었으나 물리 컬럼은 플래그 SUM = 건수다(O39) ──
    "발송(명)": (
        "SV metric — SV_SERVICE.DISTINCT_SEND_MEMBERS = COUNT(DISTINCT MEMBER_DK)", "WRONG_UNIT",
        "🔴 `FACT_SERVICE_EVENT.SEND_MEMBERS` 는 0/1 플래그의 SUM 이라 **건수**다 — 「명」으로 쓰면 "
        "과대값이 나온다(O39 실측: SUM 38,470,780 vs 고유회원 1,031,971 = 37.3배). "
        "「명」은 SV 의 `COUNT(DISTINCT)` metric 으로 답해야 한다."),
    "발송건수": (
        "FACT_SERVICE_EVENT.SEND_MEMBERS", "WRONG_UNIT",
        "이쪽이 물리 컬럼의 실제 의미(건수)다. 컬럼명이 `_MEMBERS` 라 「명」으로 오해된다(O39·P78)."),
    "성공(명)": (
        "FACT_SERVICE_EVENT.SUCCESS_MEMBERS", "WRONG_UNIT",
        "`_MEMBERS` 는 건수 플래그 계열이다(O39). ⚠️ 이 컬럼은 O39-B 로 **전건 0**(값 미주입) — "
        "조회하면 `0` 이 돌아온다."),
    "성공건수": (
        "FACT_SERVICE_EVENT.SUCCESS_MEMBERS", "WRONG_UNIT", "위와 동일 컬럼 · 전건 0."),
    "실패(명)": (
        "FACT_SERVICE_EVENT.FAIL_MEMBERS", "WRONG_UNIT", "위와 동일 계열 · O39-B 전건 0."),
    "오픈(명)": (
        "FACT_SERVICE_EVENT.OPEN_MEMBERS", "WRONG_UNIT",
        "🔴 원천 `URL_OTHBC_*` 가 **전건 NULL** 이라 값이 없다(C-9-R). 컬럼 존재를 가용성으로 읽지 말 것."),
    "납입(명)": (
        "SV metric — 납입회원수(명) = COUNT(DISTINCT MEMBER_DK WHERE 납입성공)", "WRONG_UNIT",
        "물리 컬럼이 없다(#80 미구현). 원천은 실재하므로 SV 에서 산출 가능하다 — "
        "`FACT_MEMBER_FEE`(회비 grain)에서 회원 distinct 로 센다. 🔴 `PAID_FEE` 를 「명」으로 쓰지 말 것."),
}

# ── 라벨 별칭 등록부 (보고서 표기 → 정본 인벤토리/지표사전 라벨) ──
# 🔴 왜 등록부인가: 종전 생성기는 이 표를 **본문에 하드코딩**하고 있었고, 소스가 유실됐을 때
#    표 내용을 복원할 수 없었다(추측 복원은 금지 — 틀린 매핑이 「정확일치」로 표기된다).
#    또 표기 변형의 대부분은 **규칙으로 흡수 가능**하다(단위 접미 제거·어순 정렬·률/율 통일)
#    → 생성기는 규칙을 쓰고, **의미가 달라 규칙으로 못 잇는 것만** 여기에 근거와 함께 등재한다.
# 등재 기준: 좌변이 보고서 표기 · 우변이 정본 라벨이며, 우변이 실제로 인벤토리/지표사전에
#    존재하는지 생성기가 매 실행 검증한다(미해소 시 경고 출력).
LABEL_ALIAS = {
    # 디바이스 분해 — 같은 물리 컬럼의 슬라이스(분해축 열이 필터를 명시한다)
    "PC방문수": "방문수(명)", "M방문수": "방문수(명)", "APP방문수": "방문수(명)",
    "방문수 합계": "방문수(명)",
    "PC활성사용자": "활성사용자수(명)", "M활성사용자": "활성사용자수(명)",
    "APP활성사용자": "활성사용자수(명)", "활성사용자 합계": "활성사용자수(명)",
    # 시간축 표기
    "기준년도": "년", "기준일자": "실제 일자",
    # 예산 — 보고서는 「월/연」을 앞에, 인벤토리는 뒤에 둔다(어순 규칙으로 안 잡히는 잔여분)
    "월 집행예산(ERP 마감값)": "집행예산(ERP, 월)", "월 집행예산(추정치)": "집행예산(추정)",
    # 광고·GA 표기
    "매체유형명": "플랫폼/매체유형", "세션콘텐츠": "세션 수동 광고 콘텐츠",
    "세션수동콘텐츠": "세션 수동 광고 콘텐츠",
    # 조직 — CONF-4 로 `DIM_ORG.DIVISION` 이 「실적지부」로 재정의됐다(값 NULL·산출규칙 미확정)
    "실적지부": "본부/지부", "법인구분": "법인", "법인명": "법인",
    # 회원 속성 — ⚠️ `연령`→`연령대` 는 **약정 시점 스냅샷**이다(O34·P60)
    "연령": "연령대", "성별(회원)": "성별",
    # 행사(이벤트) — 「이벤트」는 GA 이벤트와 동명이의라 정본은 「행사」다
    "이벤트명": "행사명", "이벤트 구분": "행사구분", "이벤트구분": "행사구분",
    "이벤트 관리": "참여횟수", "총 참여수": "참여횟수",   # A-11 확정: 이벤트 관리 = 총참여수
    # 회비
    "납입(원)": "납입회비(원)", "총납입금액(회비)": "납입회비(원)",
    # 밴드 — 보고서가 산출 기준을 괄호로 적는다. 기준 ÷10,000 = 1번 밴드
    "후원금액대(약정금액 기준 ÷ 10000원)": "후원금액대1 5만",
    "후원기간대(납입기준)": "후원기간대1 5년",
}

# 🔴 교정으로도 열리지 않는 것 — 「불가」를 명시해 두어야 다음 세션이 다시 파지 않는다
STILL_BLOCKED = {
    "기준일시": "목표 원천 `TM_CM_MBER_DVLP_GOAL` 11컬럼 시간축이 `STDYY`+`STDR_MT` 뿐 — 일자 컬럼 부재",
    "매체명(브랜드2)": "`FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 243,545/243,545 전건 센티넬 + 목표측 매체 축 부재",
    "예산구분": "`BRONZE_ERP.BDGT_ACMSLT_LEDGER` 64컬럼 중 **부서 코드 0개** — 이름 일치도 86/149(57.7%)",
    "소재": "대행사 원천에 소재 연결키 없음(Q10)",
    "요일": "목표 grain 에 일자 축 부재 — 실적 단독은 `FME` 로 가능",
    "주차": "위와 동일",
}


def apply(field_value):
    """필드값에 교정이 있으면 (매핑, 유형, 사유), 없으면 None."""
    return FIELD_MAPPING_OVERRIDE.get(field_value)


def label_alias(field_value):
    """보고서 표기 → 정본 라벨 (의미 별칭). 정규화 규칙으로 흡수되지 않는 것만 등재."""
    return LABEL_ALIAS.get(field_value)


def blocked_reason(field_value):
    return STILL_BLOCKED.get(field_value)


def validate(known_field_values):
    """등록부 항목이 여전히 인벤토리에 실재하는지 검증(P85-② — 매 실행 유효성 확인).
    반환: 인벤토리에 없는 등록부 키 목록(= 죽은 항목 → 제거 대상)."""
    return sorted(set(FIELD_MAPPING_OVERRIDE) - set(known_field_values))
