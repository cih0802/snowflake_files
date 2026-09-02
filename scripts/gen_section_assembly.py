# 보고서필드 섹션 조립가능성 검사기 (05 문서 §2·§3 전수)
# Co-authored with CoCo
"""
`05_지표GOLD매핑.md` §2·§3 의 보고서필드 매핑은 **라벨 → GOLD 물리컬럼** 매핑이다.
그 섹션의 필드들이 **한 표에 같은 grain 으로 공존할 수 있는지는 판정하지 않는다.**
이 검사기가 그 판정을 한다.

판정 방법 (전부 실측 — 추론 없음)
  1. 각 팩트의 grain 축을 물리 컬럼에서 읽는다 (시간축 DATE_SK/MONTH_KEY/PERF_DATE_SK · 엔티티축 MEMBER_DK 등)
  2. 각 팩트의 차원 FK 를 census 로 검사해 **전건 센티넬(=도달 불가)** 을 골라낸다
  3. 섹션의 앵커 팩트를 정한다 (그 섹션 필드가 가장 많이 가리키는 팩트)
  4. 필드별 판정:
       조립가능       앵커 팩트의 컬럼(degenerate 포함)이거나, 앵커에서 살아있는 FK 로 도달하는 DIM 의 컬럼,
                     또는 앵커와 1:1 인 위성 팩트의 컬럼
       집계필요       ◐ **불가가 아니다** — 대상이 앵커보다 잘아서(fine→coarse) 사전집계 후 조인하면 팬아웃 0
       배분규칙필요   대상이 앵커보다 굵어서(coarse→fine) 배분·귀속 규칙이 필요하다 = 업무 판단
       형제팩트중복   같은 원천의 다른 grain 팩트 — 조인이 아니라 **앵커를 바꿔서** 얻어야 한다
       도달불가       그 DIM 으로 가는 앵커의 FK 가 전건 센티넬(또는 FK 미선언)
       grain부정합    엔티티축이 다르거나 조밀도 순위를 판정할 수 없다
       타원천        원천 시스템이 다르고 연결키가 없다
       값없음        컬럼은 있으나 전건 0/NULL (census)
       판정불가      GOLD 매핑이 SV metric·미정 등으로 물리 컬럼이 아니다

🔴 [2026-08-07 O47] 종전에는 위 5종(집계필요·배분규칙필요·형제팩트중복·grain부정합 + 위성 오판)을
   **`grain부정합` 한 라벨로 묶고 있었다.** 해소 주체가 쿼리·설계·현업으로 전부 다른데 같은 이름을
   달고 있어 **과잉 차단**이 발생했다(실측: 35건 중 7건이 사전집계만으로 해결 · 1건은 순수 오판).
"""
import csv, json, os, re, sys, collections
from datetime import date

# [2026-08-06 O45] P0 필드매핑 교정 등록부를 배선한다.
#   🔴 왜 필요한가: O45 로 축(마케팅캠페인·획득귀속·회비팩트)을 실제로 만들고 GATE-F 까지
#   통과했는데, `05` 의 필드→컬럼 매핑은 **여전히 옛 죽은 컬럼**을 가리켰다. 그래서 이 검사기가
#   「도달불가」로 정확히 판정하고도 O45 의 효과가 산출물에 하나도 나타나지 않았다(실측: 신규
#   객체 4종이 09/05 CSV 에 등장 횟수 0). **축을 만드는 것과 매핑을 그 축으로 돌리는 것은 별개다.**
#   등록부는 curation 이므로 생성기에 하드코딩하지 않고 별 모듈로 둔다(P85-②).
try:
    # 🔴 샌드박스 python 은 sys.path[0] 이 runfiles 로 고정되어 **스크립트 디렉터리가 경로에 없다**.
    #   `import field_mapping_override` 만 쓰면 조용히 실패하고 교정 0건으로 생성된다(실측 발생).
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import field_mapping_override as FMO
except Exception as _e:              # 등록부가 없어도 생성은 되게 한다(교정 0건으로)
    FMO = None
    print("WARN: field_mapping_override 미탑재 —", _e)


def corrected_gmap(field_value, raw_gmap):
    """(교정된 매핑, 교정유형, 교정사유, 원래매핑) — 교정이 없으면 유형·사유 빈 값."""
    if FMO:
        ov = FMO.apply(field_value)
        if ov:
            return ov[0], ov[1], ov[2], raw_gmap
    return raw_gmap, "", "", ""

WS = os.environ.get("GN_DW_WS", "/workspace")
OUT_DIR = os.environ.get("GN_DW_OUT", os.path.join(WS, "30_output_share"))
SRC_CSV = os.environ.get("GN_DW_METRIC_CSV", os.path.join(OUT_DIR, "05_지표GOLD매핑.csv"))
CENSUS = os.environ.get("GN_DW_CENSUS", "/tmp/census.json")
SCHEMA = os.environ.get("GN_DW_SCHEMA", "/tmp/schema.json")
MEASURED = os.environ.get("GN_DW_MEASURED", date.today().isoformat())


# ── BRONZE 근거 등록부 ──────────────────────────────────────────────
# 「왜 조립이 안 되는가」를 GOLD FK 상태로만 말하면 소비자는 배선 실수인지 원천 부재인지 구별할 수 없다.
# 각 차단 축의 **BRONZE 원천 실측**을 함께 적는다. 전 항목 2026-08-06 직접 조회로 확인했다.
BRONZE_EVIDENCE = {
    ("FACT_TARGET_DEV", "DIM_DATE"):
        "목표 원천 `BRONZE_CRM.TM_CM_MBER_DVLP_GOAL`(25,344행 · 11컬럼) 전수 확인 — 시간축이 "
        "`STDYY`(기준연도)+`STDR_MT`(기준월) **둘뿐이고 일자 컬럼이 존재하지 않는다**. "
        "월 목표를 일자에 반복하면 이중계상이므로 일별 목표는 원천적으로 불가.",
    ("FACT_TARGET_DEV", "DIM_AD_CREATIVE"):
        "① 목표 원천 `TM_CM_MBER_DVLP_GOAL` 11컬럼에 매체·브랜드 컬럼 **없음**(축 = `DEPT_ID`·`MBER_DVLP_DIV_CD` 뿐). "
        "② 광고 원천 `BRONZE_AGENCY.{DGT,VIDEO,REBRDC}_AD_CMPGN_DTLS` 3종에 **부서 컬럼 0개**. "
        "→ 목표측·광고측 **양쪽 모두 상대 축이 없다**.",
    ("FACT_TARGET_DEV", "DIM_BUDGET_ITEM"):
        "예산 원천 `BRONZE_ERP.BDGT_ACMSLT_LEDGER` **64컬럼 전수 검사 결과 부서 코드 컬럼 0개** — "
        "조직은 `BDGT_UNIT_NM`(예산단위 **이름**) 149종만 있다. CRM 부서명과 이름이 일치하는 것은 "
        "**86/149(57.7%)** 이고, 목표 원천에는 예산과목 축이 없다.",
    ("FACT_BUDGET", "DIM_ORG"):
        "`BRONZE_ERP.BDGT_ACMSLT_LEDGER` 64컬럼에 **부서 코드 없음**(이름 `BDGT_UNIT_NM` 만) → "
        "`FACT_BUDGET.ORG_SK` 75,996/75,996 전건 센티넬. 이름 조인도 57.7% 만 맞는다.",
    ("FACT_AD_PERFORMANCE", "DIM_AD_CREATIVE"):
        "`FACT_AD_PERFORMANCE.AD_CREATIVE_SK` **243,545/243,545 전건 센티넬**. "
        "`DIM_AD_CREATIVE` 는 8,716행·`MEDIA_NAME` 106종이 실재하지만 **팩트에서 도달할 수 없다** — "
        "소재 연결키가 대행사 원천에 없다(Q10).",
    ("FACT_AD_PERFORMANCE", "DIM_CAMPAIGN"):
        "AGENCY 원천 3종에 **캠페인 코드 컬럼 0개** — 이름만 있다(`CMPGN_NM`·`UPPER_CMPGN_NM`·`MKT_CMPGN_NM`). "
        "🟢 단 `SILVER.AGENCY_AD_PERFORMANCE.CAMPAIGN_NM`(240,291/243,545 채움 · 110종)이 "
        "`DIM_CAMPAIGN.MARKETING_CAMPAIGN`(322종) 축에 **218,402행 = 89.7% 도달**한다 → "
        "**마케팅캠페인 grain 이면 조립 가능**(§4 참조). 개발캠페인 grain 으로 내리면 181.6배 폭발.",
    ("FACT_MEMBER_MONTHLY", "DIM_CAMPAIGN"):
        "원천에 캠페인이 없는 것이 아니다 — `FACT_MEMBER_EVENT.CAMPAIGN_SK` 는 실적재다. "
        "회원-월 grain 에서 다중캠페인 후원(7.98% · 단일 회원-월 최대 60개)을 어느 캠페인에 귀속시킬지 "
        "**규칙이 미확정(O8)** 이라 `FMM.CAMPAIGN_SK` 를 센티넬로 두었다. 규칙 없이 조인하면 fan-out 으로 기준선이 붕괴한다. "
        "→ 캠페인 분해는 `FACT_MEMBER_EVENT`(사건 grain) 또는 `FACT_MEMBER_COHORT`(회원 grain)에서 한다.",
    ("FACT_MEMBER_MONTHLY", "DIM_SPONSORSHIP"):
        "위와 동일 원인(O8 다중후원 귀속 규칙 미확정) — `FMM.SPONSORSHIP_SK` 전건 센티넬.",
    ("FACT_MEMBER_MONTHLY", "DIM_PAYMENT"):
        "`FMM.PAYMENT_SK` 전건 센티넬 + `DIM_PAYMENT.FEE_TYPE` 전건 NULL. "
        "원천 `MBRFEE_DIV_CD` 는 `SILVER.CRM_PAYMENT_BILLING` 에 보존돼 있다 → **내부 배선 사안**.",
    ("FACT_MEMBER_MONTHLY", "DIM_ORG"):
        "`FACT_MEMBER_MONTHLY` 에 **`ORG_SK` 컬럼 자체가 없다**(물리 확인). 회원-월 grain 에 부서를 붙이려면 "
        "회원의 소속부서 개념이 필요한데 원천은 **사건(개발)에만 부서를 준다**. "
        "→ 부서별 실적은 `FACT_MEMBER_EVENT.ORG_SK`(개발행 실키) 또는 `FACT_DEV_ACHIEVEMENT` 에서 낸다.",
    ("FACT_MEMBER_MONTHLY", "DIM_DATE"):
        "`FACT_MEMBER_MONTHLY` 는 **월 grain**(`MONTH_KEY`)이고 `DATE_SK` 가 없다. "
        "일자 분해는 `FACT_MEMBER_EVENT.DATE_SK`(사건 grain)에서만 가능하다.",
    ("FACT_SERVICE_EVENT", "DIM_CAMPAIGN"):
        "`FSE.CAMPAIGN_SK` 전건 센티넬 — 발송 원천(`TM_MS_*_SNDNG` 계열)에 캠페인 코드가 없다. "
        "발송은 캠페인이 아니라 **발송요청 단위**로 관리된다.",
    ("FACT_GA_BEHAVIOR", "DIM_MEMBER"):
        "GA4 는 `user_pseudo_id` 기반이고 회원번호는 `user_id` 가 있을 때만 잡힌다. "
        "현재 BRONZE_BIGQUERY 는 **2일 샤드**(`events_20260501`·`events_20260719`)뿐이고 "
        "`SILVER.IDENTITY_MEMBER_XREF` 2,009행에 불과하다(G-5).",
    ("FACT_GA_BEHAVIOR", "DIM_CAMPAIGN"):
        "`FGA.CAMPAIGN_SK` 전건 센티넬 — GA4 `utm_campaign` 문자열과 CRM 캠페인 코드를 잇는 키가 없다(Q10).",
    ("FACT_EVENT_PARTICIPATION", "DIM_SPONSORSHIP"):
        "`FEP.SPONSORSHIP_SK` 전건 센티넬 — 행사 참여 원천(`TD_MS_EVENT_PRTCPNT_DTL`)에 후원사업 축이 없다.",
}
# 팩트 ↔ 팩트 grain 부정합의 BRONZE 근거 + **올바른 대안**
FACT_PAIR_EVIDENCE = {
    ("FACT_TARGET_DEV", "FACT_MEMBER_MONTHLY"):
        "목표는 **부서 grain**(원천 `TM_CM_MBER_DVLP_GOAL.DEPT_ID`)이고 `FACT_MEMBER_MONTHLY` 는 "
        "**회원-월 grain** 이며 **`ORG_SK` 컬럼이 아예 없다**(물리 확인). 원천이 부서를 주는 곳은 "
        "**개발 사건**(`TM_MM_FDRM_MBER_DVLP_AMT.ACMSLT_DEPT_CD`)뿐이다. "
        "🟢 **올바른 대안 = `FACT_DEV_ACHIEVEMENT`**(grain `MONTH_KEY × ORG_SK × DEV_TYPE` · "
        "`GOAL_CNT`·`ACTUAL_CNT`·`*_YTD`·`*_YEAR` 완비) 또는 `FACT_MEMBER_EVENT.ORG_SK`. "
        "⚠️ 일자까지 필요하면 `FACT_MEMBER_EVENT.DATE_SK` 를 쓰되 **목표와는 대응시킬 수 없다**.",
    ("FACT_MEMBER_MONTHLY", "FACT_TARGET_DEV"):
        "위 항목의 역방향 — 회원-월 팩트에 부서 목표를 붙일 수 없다. `FACT_DEV_ACHIEVEMENT` 를 쓴다.",
    ("FACT_MEMBER_MONTHLY", "FACT_MEMBER_EVENT"):
        "`FACT_MEMBER_EVENT` 는 **사건(일) grain**, `FACT_MEMBER_MONTHLY` 는 **월 grain** 이다. "
        "FMM 은 FME 의 월 롤업이므로(`SUM(DEV_CNT)` 양쪽 **2,291,878 동일**) 같은 표에서 더하면 **이중계상**이다. "
        "필요한 축을 가진 쪽 **하나만** 고른다 — 일자·부서·사유·캠페인은 FME, 회비·미납은 FMM.",
    ("FACT_SERVICE_EVENT", "FACT_MEMBER_MONTHLY"):
        "발송은 **발송 건 grain**(`SEND_KEY`), 회원월은 **회원-월 grain** 이다. 발송 대상 회원의 회비를 "
        "같은 표에 놓으면 발송 건수만큼 회비가 복제된다(실측 38,470,780행 vs 고유회원 1,031,971 = **37.3배**).",
    ("FACT_SERVICE_EVENT", "FACT_MEMBER_EVENT"):
        "발송 건 grain ↔ 개발·중단 사건 grain. 두 사건은 **1:1 대응이 아니다** — "
        "발송 후 반응을 보려면 `FACT_SERVICE_EVENT.D5_*` 코호트 컬럼을 써야 하나 그것은 **전건 0**(미구현)이다.",
    ("FACT_AD_PERFORMANCE", "FACT_AD_BROADCAST"):
        "`FACT_AD_PERFORMANCE`(243,545 = 코어)는 `FACT_AD_DIGITAL`(205,059) + `FACT_AD_BROADCAST`(38,486) 를 "
        "이미 포함한 **상위 집계**다. 둘을 같은 표에서 합하면 **이중계상**이다.",
}
DIM_IDENTITY_NOTE = (
    "`DIM_MEMBER_IDENTITY` 는 GA↔CRM 신원 브리지 전용 차원이고 CRM 팩트에서 가는 FK 가 없다. "
    "회원번호·회원키는 `DIM_MEMBER`(자연키 `MEMBER_DK` 조인)에서 얻는다 — 이 행은 **매핑 대상 차원이 잘못 지정**된 경우다."
)

# 팩트의 시간축·엔티티축 (물리 컬럼에서 확인된 것만 적는다)
TIME_AXIS = {"DATE_SK": "일", "PERF_DATE_SK": "일", "MONTH_KEY": "월", "ACQ_DATE_SK": "일(획득)"}
ENTITY_HINT = ["MEMBER_DK", "ORG_SK", "BUDGET_ITEM_SK", "AD_PERF_DK", "EVENT_SK",
               "SEND_KEY", "PARTCPT_SEQ", "GA_SESSION_KEY"]

# 원천 시스템 (dbt source 스키마에서 파생하지 않고 팩트명으로 구분 — 소수라 명시가 더 안전)
ABBREV = {
    "FMM": "FACT_MEMBER_MONTHLY", "FME": "FACT_MEMBER_EVENT", "FSE": "FACT_SERVICE_EVENT",
    "FAD": "FACT_AD_PERFORMANCE", "FGA": "FACT_GA_BEHAVIOR", "FBD": "FACT_BUDGET",
    "FEP": "FACT_EVENT_PARTICIPATION", "FMC": "FACT_MEMBER_COHORT",
    "FTG-D": "FACT_TARGET_DEV", "FTG_D": "FACT_TARGET_DEV",
    "FTG-B": "FACT_TARGET_BIZ", "FTG_B": "FACT_TARGET_BIZ",
}

# 차원 조인이 대리키(_SK)가 아니라 자연키(_DK)로 걸리는 경우 — 실측 확인된 것만 적는다
#   [2026-08-06 O45] `DIM_MEMBER_ACQUISITION` 추가. **뷰**라서 `schema["tables"]` 에 없고,
#   조인은 `MEMBER_DK` 자연키다. 등재하지 않으면 검사기가 「FK 가 없다 = 도달불가」로 오판한다
#   (실측 48행 오판 발생). 팬아웃 0 은 O45_VERIFY GATE-C 로 검증됨(40,054,883 = 40,054,883).
DK_JOIN = {"MEMBER_DK": ["DIM_MEMBER", "DIM_MEMBER_ACQUISITION"]}

SRC_SYS = {
    "FACT_MEMBER_MONTHLY": "CRM", "FACT_MEMBER_EVENT": "CRM", "FACT_MEMBER_COHORT": "CRM",
    "FACT_SERVICE_EVENT": "CRM", "FACT_EVENT_PARTICIPATION": "CRM", "FACT_TARGET_DEV": "CRM",
    "FACT_TARGET_BIZ": "CRM", "FACT_BUDGET": "ERP",
    "FACT_AD_PERFORMANCE": "AGENCY", "FACT_AD_DIGITAL": "AGENCY",
    "FACT_AD_BROADCAST": "AGENCY", "FACT_AD_BROADCAST_CASE": "AGENCY",
    "FACT_GA_BEHAVIOR": "GA4",
    # [2026-08-06 O45] 미등재 시 `SRC_SYS.get()` 이 "?" 를 돌려 **원천 상이 = 타원천**으로 오판한다
    #   (실측 10행 오판 발생). 원천은 SILVER.CRM_PAYMENT_BILLING = CRM 이다.
    "FACT_MEMBER_FEE": "CRM",
    # 🔴 [2026-08-10 O56] **같은 함정이 재발했다.** O53 이 `WIDE_DEV_ACHIEVEMENT`(뷰) →
    #   `FACT_DEV_ACHIEVEMENT`(테이블)로 개명·전환하면서 이 팩트가 **앵커 후보로 새로 진입**했는데
    #   등록부에 넣지 않아 원천이 `?` 가 되어 **타원천 오판 3건**이 났다(1-1 「월목표」 · 1-2 「개발(건)」 ·
    #   1-3 「월 목표」). 원천은 개발실적 `TM_MM_FDRM_MBER_DVLP_AMT` + 목표 `TM_CM_MBER_DVLP_GOAL` = **CRM** 이다.
    #   ⇒ **GOLD 에 팩트가 추가되면 이 등록부를 함께 갱신한다**(O45 주석이 이미 경고하고 있었다 · P140 계열).
    "FACT_DEV_ACHIEVEMENT": "CRM",
}

# [2026-08-06 O45] **동일 원천 형제 팩트** — 시간·엔티티축이 같아 보여도 함께 조립하면 이중계상.
#   🔴 이 등록부가 없으면 검사기가 `FMM`+`FMF` 를 「축 동일 = 조립가능」으로 오판한다(실측 8행 발생).
#   실측 증거: `FMM ⋈ FMF (MEMBER_DK, MONTH_KEY)` → 행 40,054,883 → 40,262,076 이고
#   `SUM(FMM.BILLED_AMT)` 가 891,959,790,888 → **1,056,821,121,099 (+18.5% 과대계상)** 이 된다.
#   → 필드는 얻을 수 있지만 **앵커를 바꿔서** 얻어야 한다(둘을 조인하는 것이 아니다).
SAME_SOURCE_SIBLING = {
    frozenset(("FACT_MEMBER_MONTHLY", "FACT_MEMBER_FEE")):
        "둘 다 `SILVER.CRM_PAYMENT_BILLING` 파생이다. 실측 조인 시 `FMM.BILLED_AMT` 891,959,790,888 → "
        "1,056,821,121,099 = **+18.5% 과대계상**(행 40,054,883 → 40,262,076). "
        "🔴 이 필드는 **`FACT_MEMBER_FEE` 를 앵커로 바꿔서** 얻어야 한다 — FMM 과 같은 표에 두지 말 것. "
        "회원-월 요약이 필요하면 FMM, 회비 분해가 필요하면 FMF 중 **하나만** 고른다.",
}

# ── [2026-08-07 O47] 1:1 위성 팩트 등록부 ────────────────────────────
# 🔴 위성은 **grain 비교 대상이 아니다.** 조인키가 위성 쪽 PK 이면 코어와 1:1 이라 팬아웃이 0 이고
#   코어와 같은 표에 둘 수 있다(DEC-13 기확정). 그런데 종전 검사기는 위성에 `*_DATE_SK` 가 없는 것을
#   보고 「시간축 없음 → grain부정합」으로 차단했다(실측 오판: 광고시작시간).
#   판정 기준은 시간축 존재가 아니라 **조인키 유일성**이다(P96-③).
#   실측 2026-08-07: `FAD_B.AD_PERF_DK` 38,486 전건 유일 · `FAP ⋈ FAD_B` → 38,486행(폭발 0).
#   ⚠️ `FACT_AD_BROADCAST_CASE` 는 **1:N**(AD_PERF_DK × CASE_SEQ)이라 여기에 넣지 않는다 — measure 미노출(DEC-13).
ONE_TO_ONE_SATELLITE = {
    frozenset(("FACT_AD_PERFORMANCE", "FACT_AD_BROADCAST")):
        "위성 `FACT_AD_BROADCAST` 는 `AD_PERF_DK` **PK = 코어와 1:1**(실측 38,486 전건 유일 · "
        "조인 후 38,486행 = 폭발 0) → 코어와 같은 표에 둘 수 있다(DEC-13). "
        "위성에 `*_DATE_SK` 가 없는 것은 시간축 부재가 아니라 **코어가 시간축을 소유**하기 때문이다",
    frozenset(("FACT_AD_PERFORMANCE", "FACT_AD_DIGITAL")):
        "위성 `FACT_AD_DIGITAL` 는 `AD_PERF_DK` **PK = 코어와 1:1**(실측 205,059 · 205,059+38,486=243,545 "
        "완전 수직분할) → 코어와 같은 표에 둘 수 있다(DEC-13)",
}

# ── [2026-08-10 O56] 판정 교정 등록부 5종 (O49 적발 17건 + 신규 4건) ────────
# 🔴 왜 등록부인가: 17건은 **처방이 틀린 것이 아니라 판정이 틀린 것**이었다. 검사기가 보지 않는
#   세 가지가 원인이다 — ① 필드가 요구하는 시간 grain ② 브리지 차원 경유 ③ measure 의 가산성.
#   실측 근거는 전부 2026-08-10 O56 재측정분이다(계정 정지 이전 O49 값을 현 스키마에서 재확인).

# ① 섹션 앵커 강제 — 「최다 히트」가 섹션이 요구하는 grain 을 만족하지 못할 때
SECTION_ANCHOR_OVERRIDE = {
    "2-1. [회원] 주간 중단보고": (
        "FACT_MEMBER_EVENT",
        "섹션명이 **주간**이고 필드가 `*당월 주차` 를 명시하는데, 최다 히트 앵커 `FACT_MEMBER_MONTHLY` 는 "
        "`MONTH_KEY` 만 갖고 `DATE_SK` 가 **없어 주차 축이 원천적으로 부재**하다. `FACT_MEMBER_EVENT` 로 "
        "교체하면 **손실 0** 이다 — 실측(O56): FME 월 롤업 = FMM **466개월 전건 일치**"
        "(STOP 불일치 0 · DEV 불일치 0 · STOP 1,038,262 · DEV 2,291,878). 센티넬 `FME.DATE_SK=0` 은 "
        "90행(DEV 88 · STOP 0)뿐이고, 주차 집계를 실제로 실행하면 **1,795주 행**이 생성되며 "
        "STOP 합계가 FME·FMM 과 **1,038,262 로 동일**하다."),
    "4. 전환회원 특성": (
        "FACT_MEMBER_EVENT",
        "[O136 착수표 ⑰] 전환회원 특성 섹션은 개발구분 5종 및 전환 사건 시점의 속성을 분석하므로 "
        "회원×월 요약(`FACT_MEMBER_MONTHLY`)이 아닌 사건 팩트 `FACT_MEMBER_EVENT` 가 정본 앵커다."),
    "5. 캠페인별 LTV (신규)": (
        "FACT_MEMBER_COHORT",
        "[O136 착수표 ⑰] 캠페인별 LTV 섹션은 평균 유지기간, 12개월 이탈률, 최초 가입캠페인 중단일을 "
        "분석하므로 회원 획득 코호트 팩트 `FACT_MEMBER_COHORT` 가 정본 앵커다."),
}

# ② 필드가 요구하는 시간 grain — 앵커가 그 축을 못 가지면 「조립가능」이 될 수 없다(P104)
#    🔴 이것이 17건 중 6건의 원인이다: 앵커에 컬럼이 있으니 「앵커 로컬 = 조립가능」으로 통과했다.
REQUIRED_TIME_GRAIN = [
    (r"주차|주간|주별", "일",
     "주차 수치는 **일 축**에서만 산출된다 — 주는 일의 파생이며 월의 하위가 아니다. "
     "월 팩트에서 주차를 낼 수 있는 경로는 존재하지 않는다"),
    (r"\*?일별|일일|일간", "일",
     "일 단위 수치는 **일 축**이 필요하다 — 월 팩트에는 일자 분해 경로가 없다"),
]

# ③ 브리지 차원 경유 — 직접 FK 가 없어도 1:1 브리지가 있으면 도달한다
#    🔴 이것이 17건 중 7건의 원인이다(3-7 좌측 성별·연령대·지역·후원사업·상위캠페인·가입캠페인·후원금액).
IDENTITY_BRIDGE = {
    "FACT_GA_BEHAVIOR": {
        "bridge": "DIM_MEMBER_IDENTITY",
        "key": "MEMBER_DK",
        "reaches": ["DIM_MEMBER", "DIM_MEMBER_CURRENT", "DIM_MEMBER_ACQUISITION"],
        "why": (
            "`FGA` 에 `MEMBER_DK` 가 없다는 사실은 **회원 축 도달불가를 뜻하지 않는다** — "
            "`DIM_MEMBER_IDENTITY` 가 **전건 1:1 브리지**다(실측 O56: 1,763,066행 · `IDENTITY_SK` 유일 "
            "1,763,066 · `MEMBER_DK` 유일 1,763,066 · NULL 0). 2홉 조인 실측: base 68,836 → "
            "**47,112**(= 68,836 − unknown 21,724 **정확히 일치** ⇒ 실회원 행 전건 매칭 · 팬아웃 0) · "
            "3홉(+`DIM_MEMBER_ACQUISITION`) 45,792. "
            "채움(분모 = 실회원 행 47,112 · P128): 성별 **47,112 = 100%** · 연령대·지역 **45,601 = 96.79%** · "
            "획득축 **45,792 = 97.20%**. "
            "🔴 단서 두 가지: ㉮ `IDENTITY_SK = 0`(unknown) **21,724행 = 31.6%** 이므로 **분모로 쓰면 과소**다 — "
            "실회원 모집단을 명시할 것 ㉯ 🔴 **`DIM_MEMBER` 를 직접 조인하지 말 것** — SCD2 라서 "
            "**7,925,716행**(회원 1,763,065)이고 필터 없이 조인하면 **161,729행 = 2.35배 팬아웃**한다. "
            "`DIM_MEMBER_CURRENT` 또는 `IS_CURRENT = TRUE` 를 쓰면 47,112 로 정확하다"),
    },
}

# ④ 비가산 measure — 값이 있고 도달도 되지만 **더하면 틀리는** 컬럼
#    🔴 「조립가능」을 취소하지 않는다(제 grain 에서는 맞다). 기간·주차 합산 처방만 금지한다.
NONADDITIVE_MEASURE = {
    ("FACT_MEMBER_EVENT", "STOP_MEMBERS"): (
        "`STOP_MEMBERS` 는 「명」이 아니라 **사건행당 1 인 플래그**다 — 실측(O56) "
        "`SUM(STOP_MEMBERS) = SUM(STOP_CNT) = 중단행수` 가 전부 **1,038,262** 로 동일하다. "
        "주차별로 집계해 더하면 **972,925** 인데 실제 distinct 회원은 **903,064** 라 **7.74% 과대**다"
        "(같은 회원이 여러 주에 중단). 🟢 BRONZE 독립 확증: 원천 "
        "`TM_MM_FDRM_MBER_SPNSR_DSCNTC` 행 **1,038,262** · distinct `MBER_NO` **903,064** — "
        "GOLD 와 정확히 일치한다. ⇒ 처방은 「사전집계 후 SUM」이 아니라 "
        "**`COUNT(DISTINCT MEMBER_DK)`(비가산)** 이며 **주차 합계를 월로 더하지 않는다**"),
    ("FACT_MEMBER_MONTHLY", "DEV_MEMBERS"): (
        "🔴 **[O56 신규 적발]** `DEV_MEMBERS` 도 비가산이다 — 실측 `SUM(DEV_MEMBERS)` **1,996,977** vs "
        "실제 distinct 개발회원 **1,585,923** = **410,054 과대(25.9%)**. 회원-월 grain 이라 "
        "**같은 회원이 여러 달에 개발**되면 중복 계상된다(`SUM(DEV_CNT)` = 2,291,878 은 건수라 정상). "
        "⇒ 「개발(명)」을 여러 월에 걸쳐 물으면 **`COUNT(DISTINCT MEMBER_DK)`** 로 낸다. "
        "O49 는 이 필드를 검사하지 않았다(P79/O39 와 같은 유형의 3건째 재발)"),
}

# ⑤ FK 는 있으나 **의미가 다른** 경로 — FK 존재를 의미 도달로 읽으면 오답이 된다
#    🔴 O49 §6 의 F4 미검증 항목. (앵커, 차원, 필드값) 조합으로만 발동한다.
SEMANTIC_FK_MISMATCH = {
    ("FACT_MEMBER_FEE", "DIM_DATE", "기준일자"): (
        "`FMF` 에서 `DIM_DATE` 로 가는 FK 는 **`LAST_PAY_DATE_SK`(최종납입일)·`LAST_BILL_DATE_SK`(최종청구일)** "
        "둘뿐이고 **「기준일자」가 아니다** — 둘 다 사건 시점이며 보고 기준일이 아니다. "
        "실측(O56): 40,262,076행 중 센티넬(0) `LAST_PAY_DATE_SK` **1,869,272(4.64%)** · "
        "`LAST_BILL_DATE_SK` **646,712(1.61%)** · 시간축은 `MONTH_KEY` **252개월**뿐이다. "
        "🔴 FK 가 있다는 사실을 **의미 도달로 읽은 오판**이다(P96 계열) — 기준일자는 일 축을 가진 "
        "팩트(`FME.DATE_SK`)에서 얻는다"),
}

# SCD2 차원 — 조인 시 현재행 필터가 필수인 차원(팬아웃 방지 · P131 계열)
SCD2_DIM = {
    "DIM_MEMBER": (
        "🔴 `DIM_MEMBER` 는 **SCD2** 다 — 실측(O56) **7,925,716행 / 회원 1,763,065**(현재행 1,763,065). "
        "`IS_CURRENT = TRUE` 없이 조인하면 **4.49배 팬아웃**한다(FGA 실측 68,836 → 161,729 = 2.35배). "
        "⇒ `DIM_MEMBER_CURRENT` 를 쓰거나 `IS_CURRENT = TRUE` 를 명시할 것"),
}

# ── [2026-08-07 O47] 시간축 조밀도 순위 ──────────────────────────────
# 🔴 「축이 다르다」만으로 닫으면 **방향**이 사라진다. 방향에 따라 해소 주체가 완전히 다르다:
#   · fine → coarse (대상이 앵커보다 잘다)  = **사전집계 후 조인**으로 해결. 테이블 신설 불요.
#       실측 증명: `FMM ⋈ (FSE→회원·월 사전집계)` 행 40,054,883 **불변** · 청구액 891,959,790,888 **불변**.
#       종전 기재 「37.3배 복제」는 naive 조인의 결과이고 grain 의 필연이 아니었다.
#   · coarse → fine (대상이 앵커보다 굵다)  = **배분 규칙**이 필요하다(업무 판단). 이것만 「불가」다.
# 숫자가 작을수록 잘다(fine).
TIME_RANK = {"일": 0, "일(획득)": 0, "월": 1}

# [2026-08-07 O47] 매핑이 여러 축을 병기할 때 어느 판정을 채택할지의 우선순위(좋은 것부터).
#   🔴 「좋은 판정을 고른다」가 아니라 **「앵커에서 실제로 도달하는 축을 고른다」** 는 뜻이다 —
#   각 후보를 실측 판정한 결과 중에서 고르므로 없는 경로를 만들어내지 않는다.
VERDICT_PREF = ["조립가능", "집계필요", "판정불가(SV파생)",
                "배분규칙필요", "형제팩트중복", "도달불가", "grain부정합", "요구grain부정합",
                "값없음", "타원천", "원천부재", "판정불가"]

# 🔴 [2026-08-07 O48] **생성기 간 출력 문자열 계약**(O46 §3-① · P92).
#   `05` 생성기(`gen_metric_gold_mapping.py`)는 SV 파생 지표의 GOLD 매핑을 이 접두로 시작하는
#   문자열로 쓰고, 이 검사기는 그 접두로 「물리 컬럼이 아님」을 판정한다.
#   접두가 한쪽에서만 바뀌면 **에러 없이 분류만 무너진다**(실측: SV파생 67→10 · 판정불가 9→103).
#   ⇒ 상수로 고정하고 `scripts/test_generators.py::T3` 가 양쪽 생성기·산출물에서 계약을 검사한다.
SV_METRIC_PREFIX = "SV metric"



def cs_of(gold, t):
    return set(gold.get(t, []))


# 🔴 [2026-08-07 O48] 앵커 선정을 **모듈 함수로 분리**했다 — 회귀 테스트 대상이기 때문이다.
#   O47-B 사고(동점을 삽입 순서로 깨서 34행이 요동)는 오류를 내지 않는 **조용한 실패**였고
#   재빌드로 우연히 발견됐다. main() 안의 인라인 3줄은 테스트할 수 없다 →
#   `scripts/test_generators.py::T1` 이 이 함수에 **삽입 순서를 섞은 동일 집계**를 넣어
#   결과 동일함을 검사한다. 함수 시그니처·반환형이 곧 계약이다.
def pick_anchor(hit):
    """Counter/dict {fact: hit} → (anchor, tie_label).

    정렬 = (hit 내림차순, 팩트명 오름차순) → **삽입 순서와 무관하게 결정적**.
    동점이 둘 이상이면 tie_label 에 `A / B` 로 노출한다(경합 사실 자체가 판정이다).
    """
    ranked = sorted(dict(hit).items(), key=lambda kv: (-kv[1], kv[0]))
    if not ranked:
        return None, ""
    top = ranked[0][1]
    tie = [f for f, n in ranked if n == top]
    return ranked[0][0], (" / ".join(tie) if len(tie) > 1 else "")


def main():
    census = json.load(open(CENSUS, encoding="utf-8"))
    schema = json.load(open(SCHEMA, encoding="utf-8"))
    gold = schema["gold_cols"]
    facts = sorted(t for t in schema["tables"] if t.startswith("FACT_"))
    # [2026-08-06 O45] 차원 후보에 **뷰 차원**을 포함한다. `DIM_MEMBER_ACQUISITION` 은 뷰이므로
    #   `tables` 만 보면 존재 자체를 모른다 → 「FK 없음 = 도달불가」 오판의 원인이었다.
    dims = sorted({t for t in schema["tables"] if t.startswith("DIM_")}
                  | {v for v in schema["views"] if v.startswith("DIM_")})

    # ── 1. 팩트 grain 축 ──
    grain = {}
    for f in facts:
        cs = set(gold.get(f, []))
        t_ax = sorted({v for k, v in TIME_AXIS.items() if k in cs})
        e_ax = [c for c in ENTITY_HINT if c in cs]
        grain[f] = {"time": t_ax, "entity": e_ax}

    # ── 2. 팩트별 FK 생존 여부 (census) ──
    # 🔴 [2026-08-07 O47] FK 후보를 **실선언(`show imported keys`)에서 읽는다.**
    #   종전에는 `DIM_<컬럼명−_SK>` 이름 규칙만 썼고, 접두어가 붙은 FK **9종을 전부 놓쳤다**:
    #     `FAP.PERF_DATE_SK→DIM_DATE`(243,545/243,545) · `FAP.MKTG_CAMPAIGN_SK→DIM_MARKETING_CAMPAIGN`(218,402) ·
    #     `FMF.LAST_PAY_DATE_SK`(95.4%)·`LAST_BILL_DATE_SK`(98.4%) ·
    #     `FMC.ACQ_DATE_SK`·`FIRST_STOP_DATE_SK`·`ACQ_ORG_SK`·`ACQ_SPONSORSHIP_SK`·`ACQ_CAMPAIGN_SK`.
    #   그 결과 「요일·주차 도달불가」 같은 오판이 났다. **이름 규칙은 FK 의 정본이 아니다**(P96-①).
    #   이름 규칙은 FK 미선언 객체(뷰 차원 등)를 위한 **fallback** 으로만 남긴다.
    declared = schema.get("fks", {})            # {fact: {fk_col: pk_table}}
    fk_alive = collections.defaultdict(dict)   # fact -> {DIM: True/False}
    for f in facts:
        cen = census.get(f"GOLD.{f}")
        for c in gold.get(f, []):
            if not c.endswith("_SK"):
                continue
            tgt = declared.get(f, {}).get(c)
            if tgt and tgt.startswith("DIM_"):
                cand = [tgt]                    # ① 실선언 우선
            else:                               # ② fallback = 이름 규칙
                base = c[:-3]
                cand = [d for d in dims if d == "DIM_" + base or d.endswith(base)]
            if not cand:
                continue
            alive = None
            if cen:
                if cen["rows"] == 0:
                    alive = False
                else:
                    i = cen["cols"].get(c)
                    if i is not None:
                        alive = int(i["nonzero"] or 0) > 0
            for d in cand:
                # 같은 DIM 으로 가는 FK 가 둘 이상이면(예: FMF 의 PAY/BILL 일자) **하나라도 살아 있으면 도달 가능**
                if fk_alive[f].get(d) is not True:
                    fk_alive[f][d] = alive

        # 자연키(_DK) 조인
        for dk, ds in DK_JOIN.items():
            if dk in cs_of(gold, f):
                cen2 = census.get(f"GOLD.{f}")
                a2 = None
                if cen2:
                    i2 = cen2["cols"].get(dk)
                    if cen2["rows"] == 0:
                        a2 = False
                    elif i2 is not None:
                        a2 = int(i2["nonnull"] or 0) > 0
                for d in ([ds] if isinstance(ds, str) else ds):
                    if fk_alive[f].get(d) is not True:
                        fk_alive[f][d] = a2

    # ── 3. 보고서필드 행 로드 ──
    rd = list(csv.reader(open(SRC_CSV, encoding="utf-8-sig")))
    secs = {}
    cur = None
    for r in rd:
        if r and r[0].startswith("## 마케팅 보고서필드"):
            cur = "마케팅"; continue
        if r and r[0].startswith("## 회원 보고서필드"):
            cur = "회원"; continue
        if r and r[0] == "영역":
            continue
        if cur and r and len(r) >= 9 and r[0] and not r[0].startswith("#") and not r[0].startswith("##"):
            secs.setdefault(cur, []).append(r)

    rows_out = []
    for book, rs in secs.items():
        by_sec = collections.defaultdict(list)
        for r in rs:
            by_sec[(r[0], r[1])].append(r)
        for (area, sec), frs in by_sec.items():
            # 앵커 팩트 = 이 섹션이 가장 많이 가리키는 FACT
            hit = collections.Counter()
            for r in frs:
                g1 = corrected_gmap(r[2], (r[6] or "").strip())[0].lstrip("`")
                m = re.match(r"^([A-Z_\-]+)", g1)
                o1 = ABBREV.get(m.group(1), m.group(1)) if m else ""
                if o1 in grain:
                    hit[o1] += 1
            # 🔴 [2026-08-07 O47-B] **동점 시 임의 선택 금지.** `Counter.most_common()` 은 동점을
            #   삽입 순서로 깨므로, 매핑 한 건이 바뀌면 앵커가 통째로 뒤집히고 그 섹션 판정 전량이
            #   함께 뒤집힌다. 실측 사고: 3-7 좌측이 `FMM:2 / FGA:2 / FSE:2` **3파 동점**이었고
            #   O45-C 재빌드로 매핑 2건이 DIM 으로 옮겨가자 앵커가 FMM→FGA 로 뒤집혀 **15건의 판정이
            #   한꺼번에 바뀌었다**(성별·연령대·지역·후원사업 등이 조립가능↔도달불가로 요동).
            #   → ① 정렬을 **(hit 내림차순, 팩트명 오름차순)** 으로 고정해 재현 가능하게 한다.
            #     ② 동점이면 **그 사실 자체를 판정으로 노출**한다 — 「혼합섹션」이며 한 표로 만들 수
            #        없다는 것이 정답이다(앵커를 하나 골라 나머지를 「도달불가」로 적으면 거짓이 된다).
            #   🔴 [2026-08-07 O48] 로직은 `pick_anchor()` 로 분리했다 — 회귀 테스트 대상이다.
            anchor, anchor_tie = pick_anchor(hit)
            # 🔴 [2026-08-10 O56] **섹션 앵커 강제** — 「최다 히트」는 섹션이 요구하는 grain 을 모른다.
            #   2-1 은 섹션명이 「주간」이고 필드가 `*당월 주차` 를 명시하는데 앵커가 월 팩트(FMM)로
            #   잡혀 **주차 measure 6건이 조립가능으로 오판**됐다(O49 적발). 교체 손실은 실측 0 이다.
            anchor_forced = ""
            _ov = SECTION_ANCHOR_OVERRIDE.get(sec)
            if _ov and _ov[0] in grain and _ov[0] != anchor:
                anchor_forced = f"{anchor or '—'} → {_ov[0]}"
                anchor, anchor_tie = _ov[0], ""
            for r in frs:
                # 🔴 앵커 산정과 필드 판정 **양쪽 모두** 교정 매핑을 써야 한다.
                #   한쪽만 쓰면 앵커는 옛 팩트인데 필드는 새 팩트를 가리켜 전부 grain부정합이 된다.
                gmap, ov_kind, ov_why, gmap_was = corrected_gmap(r[2], (r[6] or "").strip())
                g0 = gmap.lstrip("`")
                # 🔴 [2026-08-07 O47] 매핑이 **두 축을 병기**하는 경우가 있다(예: 「후원사업」 =
                #   `FACT_MEMBER_FEE.SPONSORSHIP_SK`(납입 대상) / `DIM_MEMBER_ACQUISITION.ACQ_SPONSORSHIP_SK`(획득)).
                #   종전에는 **첫 후보만** 파싱해서, 앵커가 `FMM` 인 중단·개발 섹션에서도 회비 팩트를 골라
                #   「형제팩트중복」으로 닫았다. 병기의 취지는 「섹션에 맞는 축을 골라 쓰라」는 것이다.
                #   ⚠️ 낙관 편향(P94)이 아니다 — 후보 전부를 실측 판정한 뒤 **앵커에서 실제로 도달하는 것**을
                #      고르는 것이며, 도달하는 후보가 없으면 첫 후보의 판정을 그대로 쓴다.
                cands = []
                for _o, _c in re.findall(r"([A-Z][A-Z0-9_\-]*)\.([A-Z0-9_]+)", g0):
                    _o = ABBREV.get(_o, _o)
                    if (_o, _c) not in cands:
                        cands.append((_o, _c))
                if not cands:
                    _m = re.match(r"^([A-Z_\-]+)", g0)
                    cands = [(ABBREV.get(_m.group(1), _m.group(1)) if _m else "", "")]
                judged = [(o_, c_) + judge(anchor, o_, c_, gmap, grain, fk_alive, census, gold, dims,
                                          field=r[2])
                          for o_, c_ in cands]
                best = min(judged, key=lambda t: VERDICT_PREF.index(t[2])
                           if t[2] in VERDICT_PREF else len(VERDICT_PREF))
                obj, col, verdict, why = best
                if len(judged) > 1 and judged[0][2] != verdict:
                    why = (f"[축 병기 — 앵커 `{anchor}` 에 맞는 축 선택] `{obj}.{col}` ▸ " + why
                           + f" ▸ 다른 병기 축 `{judged[0][0]}.{judged[0][1]}` 은 `{judged[0][2]}` (O47)")
                if ov_kind:
                    why = f"[매핑교정 {ov_kind}] {ov_why} ▸ 종전 매핑 `{gmap_was}` → 교정 `{gmap}` ▸ " + why
                if anchor_tie:
                    why = (f"⚠️ **앵커 경합** — 이 섹션은 `{anchor_tie}` 가 동수로 경합하는 **혼합 섹션**이라 "
                           f"앵커를 하나 고르는 것 자체가 임의적이다. 판정은 `{anchor}` 기준이며, "
                           f"**이 섹션은 한 표가 아니라 경합 팩트 수만큼의 쿼리로 나눠야 한다**(O47-B) ▸ " + why)
                if anchor_forced:
                    why = (f"🔁 **앵커 강제 교체**({anchor_forced}) — {_ov[1]} ▸ " + why)
                rows_out.append({
                    "보고서": book, "영역": r[0], "섹션": r[1], "필드값": r[2],
                    "대응_지표#": r[5], "GOLD_매핑": gmap, "매핑근거": r[8],
                    "매핑교정": ov_kind, "종전_매핑": gmap_was,
                    "앵커_팩트": anchor or "—", "앵커_경합": anchor_tie,
                    "앵커_강제": anchor_forced,
                    "조립가능도": verdict, "판정_근거(실측)": why,
                })

    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, "09_보고서필드_조립가능성.csv")
    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows_out[0].keys()))
        w.writeheader()
        w.writerows(rows_out)

    c = collections.Counter(r["조립가능도"] for r in rows_out)
    print("전수", len(rows_out), dict(c))
    print("CSV:", path)
    # 섹션별 요약
    bysec = collections.defaultdict(collections.Counter)
    for r in rows_out:
        bysec[(r["보고서"], r["영역"], r["섹션"])][r["조립가능도"]] += 1
    for k, v in sorted(bysec.items()):
        bad = sum(n for s, n in v.items() if s != "조립가능")
        if bad:
            print(f"  {k[0]} | {k[2][:44]:44s} 총 {sum(v.values()):3d} · 문제 {bad:3d} · {dict(v)}")
    json.dump(rows_out, open("/tmp/assemble.json", "w"), ensure_ascii=False)
    write_banner(rows_out)
    write_md(rows_out, grain, fk_alive)


ICON = {"조립가능": "✅", "도달불가": "⛔", "grain부정합": "⛔", "타원천": "⛔",
        "값없음": "⛔", "판정불가": "❔", "판정불가(SV파생)": "◐", "원천부재": "⛔",
        # [2026-08-07 O47]
        "집계필요": "◐", "배분규칙필요": "⛔", "형제팩트중복": "⛔",
        # [2026-08-10 O56]
        "요구grain부정합": "⛔"}

# 🔴 [2026-08-07 O47] **「집계필요」는 불가 집계에 넣지 않는다.** 사전집계 후 조인하면 팬아웃이 0 이고
#   테이블 신설도 업무 규칙도 필요하지 않다(실측 증명 = 코드 상단 TIME_RANK 주석).
#   불가로 세면 조립가능률이 실제보다 낮게 나오고 현업에 「안 된다」고 잘못 안내한다(P95).
BAD = ("도달불가", "grain부정합", "요구grain부정합", "타원천", "값없음",
       "배분규칙필요", "형제팩트중복", "원천부재")


# 🆕 🔴🔴 [2026-08-30 O124] **코드 스팬 셀은 이 함수만 경유한다** — 착수표 ⑨ 의 근본 원인.
#   실사고 = `09_보고서필드_조립가능성.md` 에 **표 열수 위반 5건**이 있었고(2026-08-30 O124 실측 ·
#   `doc_line_length_gate --all`), 원인은 오타가 아니라 **이 생성기가 만든 문자열**이었다.
#     종전 코드 = `` `{r['GOLD_매핑'][:60]}` `` — 값을 60자로 **자른 뒤 백틱으로 감싼다.**
#     🔴 문제는 자르는 순서가 아니라 **값 자체가 백틱을 품고 있다**는 점이다(예:
#     `⛔ 불가 — 목표 원천 \`TM_CM_MBER_DVLP_GOAL\` 11컬럼 …`) ⇒ 절단면에서
#     **백틱이 홀수 개 남아 코드 스팬이 닫히지 않는다.**
#   🔴 판정 근거(실측 · `doc_line_length_gate.split_row`) = 그 파서는 백틱마다 `in_code` 를
#     **토글**하고 `in_code` 인 동안 `|` 를 구분자로 세지 않는다 ⇒ 홀수 백틱이면 `in_code` 가
#     **행 끝까지 켜진 채 남아** 뒤따르는 `|` 가 전부 무효가 되고 열수가 **4 → 2** 로 무너진다.
#     같은 이유로 렌더러도 값을 엉뚱한 열로 읽는다.
#   🔴 **이것은 산출물을 손으로 고쳐서는 닫히지 않는다** — 재생성하면 되살아난다.
#     ⇒ 시정 지점은 **생성기**다(`R3-9 ㉧` 자동 생성물 계약).
#   🟢 처방:
#     ㉠ 🔴 **값 안의 백틱을 제거한다 — 이것이 필요하고 충분한 유일한 근본 처방이다.**
#        코드 스팬 안에 백틱은 들어갈 수 없고, 제거하면 절단 지점과 무관하게 항상 균형이 맞는다.
#     ㉡ 값 안의 `|` 를 **이스케이프**한다(견고성 보강 · 근본 원인 아님) — `split_row` 는
#        균형 잡힌 코드 스팬 안의 `|` 를 세지 않지만 **GFM 렌더러는 셀 구분자로 읽는다**
#        ⇒ 게이트가 침묵하는데 화면은 깨지는 축을 함께 막는다.
#     ㉢ 잘렸으면 `…` 를 붙여 **조용한 소실**을 막는다(가독 보강 · 근본 원인 아님).
#   🔴🔴 **[O124-B 자기정정] 초판 주석은 ㉢ 을 「자른 뒤에 감싼다(감싼 뒤 자르면 닫는 백틱이
#     잘려 나간다)」로 적었다 — 거짓이다.** 종전 코드는 **이미 자른 뒤 감쌌다** ⇒ 그 문장은
#     **존재하지 않은 버그를 처방으로 제시**한 것이고, 실제 유일한 근본 처방은 ㉠ 이다.
#     🔴 판정식 = **고친 코드가 옳아도 「무엇을 고쳤는가」의 서술은 따로 검증해야 한다**
#     (동작 검증은 통과했고 서술만 틀렸으므로 테스트가 잡을 수 없었다).
#   ⚠️ 빈 값은 코드 스팬으로 감싸지 않는다(`` `` `` 는 렌더가 깨진다).
def code_cell(s, limit):
    """표 셀에 넣을 **코드 스팬**을 안전하게 만든다(🔴 백틱 제거가 본질 · `|` 이스케이프 · `…` 표시)."""
    t = ('' if s is None else str(s)).replace('`', '').replace('\n', ' ').strip()
    if not t:
        return '—'
    cut = t[:limit]
    if len(t) > limit:
        cut = cut.rstrip() + '…'
    return '`%s`' % cut.replace('|', '\\|')


def write_banner(rows):
    """05 §2·§3 에 삽입할 섹션별 조립가능성 배너 텍스트를 생성한다.

    🔴 [2026-08-10 O56 자기검토] 종전 docstring 은 *"생성기가 이 파일을 읽어 끼워 넣는다"* 였는데
    **거짓이다** — 전수 검색 결과 이 파일을 읽는 코드는 **0곳**이다(`gen_metric_gold_mapping.py` 포함).
    즉 이것은 **수기 삽입용 참고 산출물**이며, 05 md 의 배너는 자동 주입되지 않는다.
    ⇒ 사실대로 적는다(P132: 「없다」와 「못 찾았다」를 구분하고, 없는 소비자를 있다고 쓰지 않는다).
    """
    out = {}
    bysec = collections.defaultdict(list)
    for r in rows:
        bysec[(r["보고서"], r["영역"], r["섹션"])].append(r)
    for (book, area, sec), rs in bysec.items():
        c = collections.Counter(r["조립가능도"] for r in rs)
        ok = c["조립가능"]
        sv = c["판정불가(SV파생)"]
        agg = [r for r in rs if r["조립가능도"] == "집계필요"]
        bad = [r for r in rs if r["조립가능도"] in BAD]
        L = []
        A = L.append
        A(f"> 🔷 **이 섹션을 한 표로 조립할 수 있는가** — 총 {len(rs)}필드 · "
          f"✅조립가능 **{ok}** · ◐집계필요 **{len(agg)}** · ⛔불가 **{len(bad)}** · "
          f"◐SV파생 {sv} · ❔미매칭 {c['판정불가']}"
          + (f" · 앵커 팩트 `{rs[0]['앵커_팩트']}`" if rs[0]["앵커_팩트"] != "—" else ""))
        if rs[0].get("앵커_경합"):
            A(">")
            A(f"> 🔴 **앵커 경합 — 이 섹션은 한 표가 될 수 없습니다.** `{rs[0]['앵커_경합']}` 가 **동수로 경합**하는")
            A("> 혼합 섹션이라 앵커를 하나 고르는 것 자체가 임의적입니다. 아래 판정은 "
              f"`{rs[0]['앵커_팩트']}` 기준이며,")
            A("> **경합 팩트 수만큼의 쿼리로 나눈 뒤 공통 축(회원·월)에서 합쳐야** 합니다(O47-B).")
        if agg:
            A(">")
            A("> 🟢 **◐집계필요 필드는 「불가」가 아닙니다** — 대상 팩트를 이 섹션의 grain 으로 **먼저 집계한 뒤**")
            A("> 조인하면 됩니다(팬아웃 0 실측). 사전집계 없이 그냥 조인할 때만 이중계상이 납니다.")
            A(">")
            A("> | 필드값 | 판정 | 어떻게 조립하는가 |")
            A("> |---|---|---|")
            seen = set()
            for r in agg:
                if r["필드값"] in seen:
                    continue
                seen.add(r["필드값"])
                A(f"> | **{r['필드값']}** | ◐ 집계필요 | {r['판정_근거(실측)'].replace('|', chr(92) + '|')} |")
        if bad:
            A(">")
            A("> 🔴 **아래 필드는 이 섹션의 앵커와 같은 표에 놓을 수 없습니다.** 매핑된 컬럼이 실재한다는 것과")
            A("> **그 섹션의 grain 으로 조립된다는 것은 다릅니다** — 매핑 행만 보고 표를 만들면 조용히 틀립니다.")
            A(">")
            A("> | 필드값 | 판정 | 왜 안 되는가 (GOLD 상태 ▸ BRONZE 근거) |")
            A("> |---|---|---|")
            seen = set()
            for r in bad:
                k = (r["필드값"], r["조립가능도"])
                if k in seen:
                    continue
                seen.add(k)
                why = r["판정_근거(실측)"].replace("|", "\\|")
                A(f"> | **{r['필드값']}** | {ICON[r['조립가능도']]} {r['조립가능도']} | {why} |")
        out[f"{book}||{area}||{sec}"] = "\n".join(L)
    # 🔴 [2026-08-10 O56 자기검토] 종전에는 이 파일을 **고정 경로 `/tmp/section_banner.json`** 에 썼다.
    #   결함 2건이었다: ① `GN_DW_OUT` 을 무시하므로 **대조·기준선 실행이 정본 배너를 덮어쓴다**
    #   (실제로 오염됐고, 그 파일을 읽고 「배너 17 vs CSV 23 불일치」라는 **가짜 결함**을 잡을 뻔했다)
    #   ② `/tmp` 는 세션 중 초기화된다(P99). ⇒ 산출물 디렉터리로 옮긴다.
    path = os.path.join(OUT_DIR, "09_섹션배너.json")
    json.dump(out, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("BANNER:", path, len(out), "섹션")


def write_md(rows, grain, fk_alive):
    c = collections.Counter(r["조립가능도"] for r in rows)
    L = []
    A = L.append
    A("<!-- LLM-METADATA")
    A("doc_id: REPORT_FIELD_SECTION_ASSEMBLY")
    A("doc_role: 보고서필드 섹션 조립가능성 판정 — 05 §2·§3 전수(507행) grain 정합 검사")
    A("project: GN_DW (굿네이버스)")
    A(f"measured: {MEASURED}")
    A("generator: scripts/gen_section_assembly.py")
    A("generated: auto (do-not-edit)")
    A("principle: P36(짝짓기를 이름 유사성으로 하지 않는다) · P78(의미는 이름이 아니라 grain 으로 판정) · P85")
    A("END-METADATA -->")
    A("")
    A("# 보고서필드 섹션 조립가능성 (507행 전수)")
    A("")
    A(f"> ⚙️ **자동 생성물** — 생성기 `scripts/gen_section_assembly.py`. 측정일 **{MEASURED}**.")
    A("> **왜 이 문서가 필요한가**: `05_지표GOLD매핑.md` §2·§3 은 **필드 라벨 → GOLD 물리컬럼** 매핑이다.")
    A("> 그 표는 「영역 · 섹션 · 필드값」 순으로 배열돼 있어 **섹션 단위로 표를 조립할 수 있는 것처럼 읽히지만**,")
    A("> 필드들이 **같은 grain 으로 공존하는지는 판정하지 않는다.** 이 문서가 그 판정을 한다.")
    A("")
    A("## 0. 전수 판정 결과")
    A("")
    A("| 판정 | 건수 | 비중 | 의미 |")
    A("|---|---:|---:|---|")
    MEAN = {
        "조립가능": "앵커 팩트의 컬럼(degenerate 포함)이거나, 앵커에서 **살아있는 FK** 로 도달하는 차원의 컬럼, 또는 앵커와 **1:1 인 위성 팩트**의 컬럼",
        "집계필요": "◐ **불가가 아니다** — 대상이 앵커보다 **잘다**(fine→coarse). 앵커 grain 으로 **사전집계 후 조인**하면 팬아웃 0(실측). 테이블 신설·업무규칙 **둘 다 불요**",
        "배분규칙필요": "대상이 앵커보다 **굵다**(coarse→fine). 굵은 값을 잘게 내리려면 **배분·귀속 규칙**이 필요하다 = **업무 판단**(모델링 아님)",
        "형제팩트중복": "같은 원천의 다른 grain 팩트 — 조인이 아니라 **앵커를 바꿔서** 얻는다. 조인하면 이중계상",
        "도달불가": "그 차원으로 가는 앵커의 FK 가 **전건 센티넬**이거나 FK 자체가 없다 — 조인해도 `(미매핑)` 한 덩어리",
        "grain부정합": "엔티티축이 다르거나 시간축 조밀도 순위를 판정할 수 없다",
        "요구grain부정합": "🆕 **필드가 요구하는 시간 grain 이 앵커에 없다**(예: 「주차」인데 앵커가 월 팩트). 앵커가 그 컬럼을 갖고 있어도 **축이 없으면 쪼갤 수 없다** — 해소 경로는 **앵커 교체**다(O56·P104)",
        "값없음": "컬럼은 있으나 **전건 0/NULL** (census 실측)",
        "타원천": "원천 시스템이 다르고 연결키가 없다",
        "판정불가(SV파생)": "SV metric — 물리 컬럼이 아니므로 **base 의 조립가능도를 따른다**",
        "판정불가": "GOLD 물리·SV 어느 쪽도 대응이 확인되지 않았다",
        "원천부재": "**BRONZE 원천에 축이 없다**(등록부에 실측 사유 기재) — 내부 배선으로 열리지 않는다",
    }
    for k, v in c.most_common():
        A(f"| {ICON.get(k,'')} **{k}** | {v} | {v/len(rows)*100:.1f}% | {MEAN.get(k,'')} |")
    A("")
    n_bad = sum(v for k, v in c.items() if k in BAD)
    A(f"> ✅ **조립가능 {c['조립가능']}/{len(rows)} = {c['조립가능']/len(rows)*100:.1f}%** · "
      f"◐ **집계필요 {c['집계필요']}**(사전집계로 열린다) · ⛔ **불가 {n_bad}**")
    A("> 🔴 **`집계필요` 를 「불가」로 세지 말 것** — 대상 팩트를 섹션 grain 으로 먼저 집계하면 팬아웃이 0 이다")
    A("> (실측: `FMM ⋈ (FSE→회원·월 사전집계)` 행 40,054,883 불변 · 청구액 891,959,790,888 불변).")
    A("> 종전 판본은 이 5종을 **`grain부정합` 한 라벨로 묶어** 해소 주체가 전부 다른 문제를 같은 것으로 보이게 했다(O47·P95).")
    A("")
    A("## 1. 섹션별 요약")
    A("")
    A("| 보고서 | 섹션 | 앵커 팩트 | 총 | ✅가능 | ◐집계 | ⛔불가 | ◐SV | ❔미매칭 |")
    A("|---|---|---|---:|---:|---:|---:|---:|---:|")
    bysec = collections.defaultdict(list)
    for r in rows:
        bysec[(r["보고서"], r["영역"], r["섹션"])].append(r)
    for (book, area, sec), rs in sorted(bysec.items()):
        cc = collections.Counter(r["조립가능도"] for r in rs)
        bad = sum(n for k, n in cc.items() if k in BAD)
        anc = f"`{rs[0]['앵커_팩트']}`"
        if rs[0].get("앵커_경합"):
            anc += f" 🔴**경합**({rs[0]['앵커_경합'].count('/')+1})"
        A(f"| {book} | {sec} | {anc} | {len(rs)} | {cc['조립가능']} | {cc['집계필요']} | "
          f"**{bad}** | {cc['판정불가(SV파생)']} | {cc['판정불가']} |")
    A("")
    ties = sorted({(r["보고서"], r["섹션"], r["앵커_팩트"], r["앵커_경합"])
                   for r in rows if r.get("앵커_경합")})
    if ties:
        A("> 🔴 **앵커 경합 섹션 — 이 섹션은 한 표가 될 수 없다**(신규 판정 · O47-B)")
        A("> 아래 섹션은 여러 팩트가 **동수로** 경합해서 앵커를 하나 고르는 것 자체가 임의적이다.")
        A("> 종전 검사기는 `Counter.most_common()` 의 **삽입 순서**로 동점을 깼기 때문에, 매핑 한 건이")
        A("> 바뀌면 앵커가 뒤집히고 그 섹션 판정이 통째로 요동쳤다(실측: 3-7 좌측 15건 동시 반전).")
        A("> ⇒ **경합 팩트 수만큼 쿼리를 나눈 뒤 공통 축(회원·월)에서 합쳐야** 한다.")
        A("")
        A("| 보고서 | 섹션 | 경합 팩트(동수) | 판정 기준 앵커 |")
        A("|---|---|---|---|")
        for b, s, a, t in ties:
            A(f"| {b} | {s} | {' / '.join('`'+x.strip()+'`' for x in t.split('/'))} | `{a}` |")
        A("")
    A("## 2. 팩트 grain 축 (판정 기준)")
    A("")
    A("| 팩트 | 시간축 | 엔티티축 | 원천 |")
    A("|---|---|---|---|")
    for f in sorted(grain):
        g = grain[f]
        A(f"| `{f}` | {'/'.join(g['time']) or '**없음**'} | {', '.join(g['entity']) or '—'} | {SRC_SYS.get(f,'?')} |")
    A("")
    A("> 🔴 **`FACT_MEMBER_MONTHLY` 에는 `ORG_SK` 도 `DATE_SK` 도 없다** — 부서별·일별 실적은 이 팩트에서 낼 수 없다.")
    A("> `FACT_TARGET_DEV` 에는 `DATE_SK` 가 없다 — 일별 목표는 원천적으로 불가하다.")
    A("> ⚠️ **[O47] 「시간축 없음」이 곧 grain 부정합은 아니다** — 광고 위성(`FACT_AD_BROADCAST`·`FACT_AD_DIGITAL`)은")
    A("> `AD_PERF_DK` PK 로 코어와 **1:1** 이라 코어가 시간축을 소유한다. 판정 기준은 **조인키 유일성**이다(DEC-13·P96-③).")
    A("")
    A("## 3. 불가 판정 전량 (섹션별)")
    A("")
    for (book, area, sec), rs in sorted(bysec.items()):
        bad = [r for r in rs if r["조립가능도"] in BAD]
        if not bad:
            continue
        A(f"### {book} · {sec}  — 앵커 `{rs[0]['앵커_팩트']}` · 불가 {len(bad)}/{len(rs)}")
        A("")
        A("| 필드값 | GOLD 매핑 | 판정 | 왜 안 되는가 (GOLD 상태 ▸ BRONZE 근거) |")
        A("|---|---|---|---|")
        for r in bad:
            A(f"| {r['필드값']} | {code_cell(r['GOLD_매핑'], 60)} | {ICON[r['조립가능도']]} {r['조립가능도']} | "
              f"{r['판정_근거(실측)'].replace('|','\\|')} |")
        A("")
    # [2026-08-07 O47] 「집계필요」를 §3 과 **분리해 별 절로** 낸다.
    #   같은 절에 두면 독자가 ⛔ 와 함께 읽어 「불가 목록」으로 오독한다(P86-① 계열).
    agg_all = [r for r in rows if r["조립가능도"] == "집계필요"]
    if agg_all:
        A("## 3-B. ◐ 집계필요 전량 — **불가가 아니다** (사전집계 후 조인)")
        A("")
        A("> 대상 팩트가 앵커보다 **잘다**(fine→coarse). 앵커 grain 으로 **먼저 집계한 뒤** 조인하면 팬아웃이 0 이다.")
        A("> 실측 증명: `FMM ⋈ (FSE→회원·월 사전집계)` 행 **40,054,883 불변** · 청구액 **891,959,790,888 불변**.")
        A("> 🔴 사전집계 **없이** 그냥 조인할 때만 이중계상이 난다 — 종전 판본의 「37.3배 복제」가 바로 그 경우다.")
        A("> ⇒ 해소 주체는 **쿼리 패턴**이며 테이블 신설도 업무 규칙도 필요하지 않다(O47·P95).")
        A("")
        A("| 보고서 | 섹션 | 필드값 | 앵커 | GOLD 매핑 | 어떻게 조립하는가 |")
        A("|---|---|---|---|---|---|")
        for r in agg_all:
            A(f"| {r['보고서']} | {r['섹션'][:28]} | {r['필드값']} | `{r['앵커_팩트']}` | "
              f"{code_cell(r['GOLD_매핑'], 44)} | {r['판정_근거(실측)'].replace('|','\\|')} |")
        A("")
    A("## 3-C. 🆕 검증된 처방 쿼리 (실행 근거 첨부 · 2026-08-10 O56)")
    A("")
    A("> 🔴 **여기 실린 쿼리는 전부 실제로 실행한 것이고, 표에 적힌 값이 그 실행 결과다.**")
    A("> 종전 판본은 처방을 **산문으로만** 적었고 실행 근거가 없었다 — 그 결과 처방 4건이 틀린 채")
    A("> 통과했다(O49 적발). 처방은 쿼리로 적고 값으로 증명한다(P139).")
    A("")
    A("### ㉮ 2-1 앵커 교체 — 월 팩트로는 주차를 낼 수 없다")
    A("")
    A("`FACT_MEMBER_MONTHLY` 에는 `DATE_SK` 가 없다. 앵커를 `FACT_MEMBER_EVENT` 로 바꿔도 **손실이 0** 인지 먼저 증명한다.")
    A("")
    A("```sql")
    A("-- ① 앵커 교체 손실 검증: FME 월 롤업 = FMM (466개월 전건)")
    A("with fme as (")
    A("  select floor(DATE_SK/100) M, sum(STOP_CNT) S, sum(DEV_CNT) D")
    A("  from GN_DW.GOLD.FACT_MEMBER_EVENT group by 1),")
    A("fmm as (")
    A("  select MONTH_KEY M, sum(STOP_CNT) S, sum(DEV_CNT) D")
    A("  from GN_DW.GOLD.FACT_MEMBER_MONTHLY group by 1)")
    A("select count(*) MONTHS_COMPARED,")
    A("       count_if(coalesce(a.S,0) <> coalesce(b.S,0)) STOP_MISMATCH,")
    A("       count_if(coalesce(a.D,0) <> coalesce(b.D,0)) DEV_MISMATCH")
    A("from fme a full outer join fmm b on a.M = b.M;")
    A("-- 실행 결과: MONTHS_COMPARED=466 · STOP_MISMATCH=0 · DEV_MISMATCH=0")
    A("")
    A("-- ② 교체 후 주차 축이 실제로 나오는지 + 총계 보존")
    A("with wk as (")
    A("  select date_trunc('week', to_date(to_varchar(DATE_SK),'YYYYMMDD')) WK,")
    A("         sum(STOP_CNT) STOP_CNT")
    A("  from GN_DW.GOLD.FACT_MEMBER_EVENT where DATE_SK > 0 group by 1)")
    A("select count(*) WEEK_ROWS, sum(STOP_CNT) STOP_SUM from wk;")
    A("-- 실행 결과: WEEK_ROWS=1,795 (1991-01-07 ~ 2026-07-06) · STOP_SUM=1,038,262 = FME·FMM 총계와 동일")
    A("```")
    A("")
    A("### ㉯ 「중단(명)」·「개발(명)」은 비가산 — SUM 처방이 틀렸다")
    A("")
    A("```sql")
    A("-- ① STOP_MEMBERS 는 「명」이 아니라 사건행당 1 인 플래그다")
    A("select sum(STOP_MEMBERS) SUM_MEMBERS, sum(STOP_CNT) SUM_CNT, count_if(STOP_CNT > 0) ROWS_STOP")
    A("from GN_DW.GOLD.FACT_MEMBER_EVENT;")
    A("-- 실행 결과: 1,038,262 / 1,038,262 / 1,038,262  (셋이 동일 = 건수다)")
    A("")
    A("-- ② 주차로 쪼개 더하면 과대계상된다")
    A("with w as (")
    A("  select date_trunc('week', to_date(to_varchar(DATE_SK),'YYYYMMDD')) WK,")
    A("         count(distinct case when STOP_CNT > 0 then MEMBER_DK end) D")
    A("  from GN_DW.GOLD.FACT_MEMBER_EVENT where DATE_SK > 0 group by 1)")
    A("select sum(D) WEEKLY_SUM_DISTINCT,")
    A("       (select count(distinct case when STOP_CNT > 0 then MEMBER_DK end)")
    A("          from GN_DW.GOLD.FACT_MEMBER_EVENT where DATE_SK > 0) TRUE_DISTINCT")
    A("from w;")
    A("-- 실행 결과: 972,925 vs 903,064 = 69,861 과대 (7.74%)")
    A("")
    A("-- ③ 🟢 BRONZE 원천 독립 대조 — 「명」의 정답은 원천 distinct 다")
    A("select count(*) BRONZE_ROWS, count(distinct MBER_NO) U_MBER")
    A("from GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC;")
    A("-- 실행 결과: 1,038,262 / 903,064  → GOLD 와 정확히 일치(행수=건수 · distinct=명)")
    A("")
    A("-- ④ 🔴 [O56 신규] 개발(명)도 비가산이다 — O49 는 이 필드를 검사하지 않았다")
    A("select sum(DEV_MEMBERS) FMM_SUM, sum(DEV_CNT) FMM_CNT,")
    A("       (select count(distinct MEMBER_DK) from GN_DW.GOLD.FACT_MEMBER_EVENT")
    A("          where EVENT_TYPE = 'DEV' and DEV_CNT > 0) TRUE_DISTINCT")
    A("from GN_DW.GOLD.FACT_MEMBER_MONTHLY;")
    A("-- 실행 결과: 1,996,977 / 2,291,878 / 1,585,923  → SUM(DEV_MEMBERS) 가 25.9% 과대")
    A("```")
    A("")
    A("### ㉰ 3-7 좌측 「도달불가」 7건 — identity 브리지로 열린다")
    A("")
    A("```sql")
    A("-- ① 브리지 유일성 (1:1 이어야 팬아웃이 0 이다)")
    A("select count(*) ROWS_, count(distinct IDENTITY_SK) U_ISK, count(distinct MEMBER_DK) U_MDK,")
    A("       count_if(IDENTITY_SK is null) NULL_ISK")
    A("from GN_DW.GOLD.DIM_MEMBER_IDENTITY;")
    A("-- 실행 결과: 1,763,066 / 1,763,066 / 1,763,066 / 0  = 전건 1:1")
    A("")
    A("-- ② 🔴 처방을 틀리게 쓰면 팬아웃한다 — DIM_MEMBER 는 SCD2 다")
    A("select count(*) from GN_DW.GOLD.FACT_GA_BEHAVIOR f")
    A("  join GN_DW.GOLD.DIM_MEMBER_IDENTITY i on f.IDENTITY_SK = i.IDENTITY_SK")
    A("  join GN_DW.GOLD.DIM_MEMBER m on i.MEMBER_DK = m.MEMBER_DK;          -- ⛔ 161,729 (2.35배)")
    A("select count(*) from GN_DW.GOLD.FACT_GA_BEHAVIOR f")
    A("  join GN_DW.GOLD.DIM_MEMBER_IDENTITY i on f.IDENTITY_SK = i.IDENTITY_SK")
    A("  join GN_DW.GOLD.DIM_MEMBER_CURRENT m on i.MEMBER_DK = m.MEMBER_DK;  -- ✅ 47,112")
    A("-- base 68,836 − unknown(IDENTITY_SK=0) 21,724 = 47,112 → 실회원 행 전건 매칭 · 팬아웃 0")
    A("-- DIM_MEMBER 실측: 7,925,716행 / 회원 1,763,065 → 필터 없이 조인하면 4.49배로 늘어난다")
    A("")
    A("-- ③ 채움률은 **분모를 실회원 행으로** 잡아야 한다(P128)")
    A("-- 실행 결과(분모 47,112): 성별 47,112 = 100% · 연령대·지역 45,601 = 96.79% · 획득축 45,792 = 97.20%")
    A("-- ⚠️ unknown 21,724 = 31.6% 를 분모에 넣으면 과소로 보인다")
    A("```")
    A("")
    A("### ㉱ 「집계필요」 처방 — 사전집계 후 LEFT JOIN 은 팬아웃 0")
    A("")
    A("```sql")
    A("with pre as (")
    A("  select MEMBER_DK, floor(DATE_SK/100) MONTH_KEY,")
    A("         count(distinct case when STOP_CNT > 0 then MEMBER_DK end) STOP_MEMBERS_D")
    A("  from GN_DW.GOLD.FACT_MEMBER_EVENT where DATE_SK > 0 group by 1, 2)")
    A("select count(*) JOINED_ROWS, sum(m.BILLED_AMT) BILLED_AFTER")
    A("from GN_DW.GOLD.FACT_MEMBER_MONTHLY m")
    A("left join pre p on m.MEMBER_DK = p.MEMBER_DK and m.MONTH_KEY = p.MONTH_KEY;")
    A("-- 실행 결과: 40,054,883 (base 40,054,883 불변) · 891,959,790,888 (불변)")
    A("```")
    A("")
    A("### ㉲ F4 「기준일자」 — FK 가 있지만 의미가 다르다")
    A("")
    A("```sql")
    A("-- FMF 에서 DIM_DATE 로 가는 FK 는 최종납입일·최종청구일뿐이다(보고 기준일이 아니다)")
    A("select count(*) ROWS_,")
    A("       count_if(LAST_PAY_DATE_SK = 0) ZERO_PAY, count_if(LAST_BILL_DATE_SK = 0) ZERO_BILL,")
    A("       count(distinct MONTH_KEY) MONTHS_")
    A("from GN_DW.GOLD.FACT_MEMBER_FEE;")
    A("-- 실행 결과: 40,262,076 · 1,869,272 (4.64%) · 646,712 (1.61%) · 252")
    A("-- ⇒ 「기준일자」는 일 축을 가진 팩트(FME.DATE_SK)에서 얻는다. FK 존재를 의미 도달로 읽지 말 것")
    A("```")
    A("")
    A("### ㉳ 「가입일」·「중단일」 계보 — 앵커 교체로 흡수된다")
    A("")
    A("```sql")
    A("-- 중단일: DIM 과 팩트가 같은 원천이라 값이 완전히 같다")
    A("with f as (select MEMBER_DK, max(STOP_DATE) MX from GN_DW.GOLD.FACT_MEMBER_EVENT")
    A("           where STOP_DATE is not null group by 1),")
    A("     d as (select MEMBER_DK, LAST_STOP_DATE from GN_DW.GOLD.DIM_MEMBER_CURRENT")
    A("           where LAST_STOP_DATE is not null)")
    A("select count(*) COMPARED, count_if(f.MX <> d.LAST_STOP_DATE) MISMATCH_")
    A("from f join d on f.MEMBER_DK = d.MEMBER_DK;")
    A("-- 실행 결과: 898,425 / 불일치 0  ⇒ 컬럼명만 다르다")
    A("")
    A("-- 가입일: 이름이 비슷한데 **원천이 다르다** — 같다고 단정하면 안 된다(P104)")
    A("-- 실행 결과: 비교 1,585,933 · 일치 1,558,628 (98.28%) · 불일치 27,305 (1.72%)")
    A("--            그중 FME 가 늦은 것 26,991 (98.85%) · 중앙값 차이 0일 ⇒ 처리 지연")
    A("```")
    A("")
    A("## 4. 🟢 새로 열린 경로 — 마케팅캠페인 grain ROAS")
    A("")
    A("> 이슈원장 Q16 은 *\"캠페인↔마케팅캠페인 조인키 무효화(`MKTG_CMPGN_NM` 전건 NULL)\"* 로 기록돼 있었다.")
    A("> **이 판정은 오진이다** — 실측 결과 키가 존재하고 100% 해소된다.")
    A("")
    A("| 단계 | 실측 |")
    A("|---|---|")
    A("| `BRONZE_CRM.TM_CM_CMPGN_MNG.MKTG_CMPGN_NM` 채움 | **33,915/36,143 = 93.8%** · 323 distinct (전건 NULL 아님) |")
    A("| 브리지 조인 `MK_CMPGN_CD = MKTG_CMPGN_NM::varchar` | **33,915/33,915 = 100% 해소** |")
    A("| GOLD 도달 `DIM_CAMPAIGN.MARKETING_CAMPAIGN` | 33,915/36,144 채움 · **322종** |")
    A("| 개발실적 커버리지 | **2,278,685/2,291,878 = 99.42%** |")
    A("| 광고측 `SILVER.AGENCY_AD_PERFORMANCE.CAMPAIGN_NM` → 이 축 도달 | **218,402/243,545 = 89.7%** |")
    A("")
    A("**마케팅캠페인 grain 으로 양측을 집계하면 fan trap 없이 개발단가가 산출된다** (실측):")
    A("")
    A("| 지표 | 값 |")
    A("|---|---|")
    A("| 매칭된 마케팅캠페인 | **79** |")
    A("| 유지된 광고행 | 216,481 (폭발 없음) |")
    A("| 광고비 | 34,209,625,719 원 |")
    A("| 개발(건) | 463,279 |")
    A("| **개발단가** | **73,842 원** |")
    A("")
    A("🔴 **단 개발캠페인(`CMPGN_CD`) grain 으로 내려가면 안 된다** — 실측 팬아웃:")
    A("일치 광고캠페인명 81종(전체 110종 중) → 개발캠페인 9,750종(평균 120.4 · 최대 901) → naive 조인 시")
    A("**218,402행 → 39,669,103행 = 181.6배 폭발**하고 광고비가 그만큼 복제된다. (2026-08-06 재측정 · P89)")
    A("")
    A("→ 따라서 **차단 사유는 「연결키 부재」가 아니라 「배분 규칙 부재」**다. 해소 경로가 다르다:")
    A("원천 입고가 아니라 **현업의 광고비 배분 규칙 1건**이면 개발캠페인 단위까지 열린다(Q10 재정의 대상).")
    A("")
    A("---")
    A("_Co-authored with CoCo_")
    path = os.path.join(OUT_DIR, "09_보고서필드_조립가능성.md")
    open(path, "w", encoding="utf-8").write("\n".join(L) + "\n")
    print("MD :", path)


def _nonadditive_note(obj, col):
    """비가산 measure 면 처방 문구를 돌려준다(판정은 바꾸지 않는다)."""
    note = NONADDITIVE_MEASURE.get((obj, col))
    return (" ▸ 🔴 **비가산 처방**: " + note) if note else ""


def judge(anchor, obj, col, gmap, grain, fk_alive, census, gold, dims, field=""):
    if gmap.startswith("⛔"):
        # 05 의 등록부가 **불가 사유를 실측으로 명시**한 항목이다 — 「판정불가」로 뭉개면 사유가 사라진다.
        return "원천부재", gmap.lstrip("⛔ ").strip()
    if not obj:
        return "판정불가", "GOLD 매핑이 물리 컬럼 형태가 아니다(미정·비고 등)"
    if gmap.startswith(SV_METRIC_PREFIX) or obj == "SV":
        return "판정불가(SV파생)", "SV metric — 물리 컬럼이 아니라 base 로 계산된다. base 의 조립가능도를 따른다"
    if not anchor:
        return "판정불가", "이 섹션에 앵커 팩트가 없다(전부 차원·SV)"

    # ── [2026-08-10 O56] **필드가 요구하는 시간 grain 검사 — 다른 어떤 검사보다 먼저** ──
    # 🔴 O49 적발 17건 중 6건의 원인이다. 앵커에 컬럼이 **있으니** 「앵커 로컬 = 조립가능」으로
    #   통과했지만, 필드가 요구하는 것은 컬럼이 아니라 **주차 축**이었다(P104).
    #   컬럼 보유는 축 보유가 아니다 — `FMM.STOP_CNT` 는 있어도 주차로 쪼갤 수 없다.
    if field:
        _ax = grain.get(anchor, {}).get("time") or []
        for _pat, _need, _why in REQUIRED_TIME_GRAIN:
            if re.search(_pat, field) and _need not in _ax:
                return "요구grain부정합", (
                    f"필드값 「{field}」 이 **{_need} 축**을 요구하는데 앵커 `{anchor}` 의 시간축은 "
                    f"**{'/'.join(_ax) or '없음'}** 이다. {_why}. "
                    f"🔴 앵커가 그 컬럼을 갖고 있다는 사실은 **축을 갖고 있다는 뜻이 아니다** — "
                    f"종전 검사기는 컬럼 보유만 보고 `조립가능` 으로 통과시켰다(O49 적발 · P104). "
                    f"해소 경로 = **일 축을 가진 팩트로 앵커를 교체**한다"
                    + _nonadditive_note(obj, col))

    # ── [2026-08-07 O47] 앵커 로컬 degenerate 우선 검사 ──
    # 🔴 차원을 찾기 **전에** 앵커 팩트 자체의 컬럼을 본다.
    #   실측 오판: 「요일」·「주차」가 `DIM_DATE.DAY_OF_WEEK`/`WEEK_OF_YEAR` 로 매핑돼 「도달불가」가 됐으나,
    #   정본 소재지는 `FACT_AD_PERFORMANCE.DAY_OF_WEEK`·`WEEK_OF_YEAR` 이고 **둘 다 243,545/243,545 채움**이다.
    #   차원에 동명 컬럼이 있다는 사실이 그 차원을 경유해야 한다는 뜻은 아니다(P96-②).
    if col and obj != anchor and obj.startswith("DIM_") and col in cs_of(gold, anchor):
        cen_a = census.get(f"GOLD.{anchor}")
        ia = (cen_a or {}).get("cols", {}).get(col)
        if ia is not None and (int(ia["nonzero"] or 0) > 0 or int(ia["nonnull"] or 0) > 0):
            return "조립가능", (f"앵커 팩트 `{anchor}` 가 **동명 degenerate 컬럼 `{col}` 을 직접 보유**한다 "
                             f"(실측 채움 {int(ia['nonnull'] or 0):,}/{cen_a['rows']:,}) — "
                             f"`{obj}` 를 경유할 필요가 없다. 매핑을 앵커 로컬로 교정할 것(O47·P96-②)")

    # 값 없음 검사
    if obj.startswith("FACT_") or obj.startswith("DIM_"):
        cen = census.get(f"GOLD.{obj}")
        if cen and col:
            if cen["rows"] == 0:
                return "값없음", f"`{obj}` 0행"
            i = cen["cols"].get(col)
            if i is not None:
                nn, nz = int(i["nonnull"] or 0), int(i["nonzero"] or 0)
                if nn == 0:
                    return "값없음", f"`{obj}.{col}` 전건 NULL ({cen['rows']:,}행)"
                if nz == 0:
                    return "값없음", f"`{obj}.{col}` 전건 0 ({cen['rows']:,}행)"

    if obj == anchor:
        return "조립가능", (f"앵커 팩트 `{anchor}` 자체의 컬럼" + _nonadditive_note(obj, col))

    if obj.startswith("DIM_"):
        # 🔴 [2026-08-10 O56] **FK 생존 검사보다 먼저 「의미」를 본다.** FK 가 있다는 사실은
        #   그 FK 가 이 필드의 의미를 준다는 뜻이 아니다 — O49 §6 F4 가 이 오판이었다.
        sem = SEMANTIC_FK_MISMATCH.get((anchor, obj, field))
        if sem:
            return "도달불가", sem
        alive = fk_alive.get(anchor, {}).get(obj)
        if alive is True:
            base = f"`{anchor}` → `{obj}` FK 생존(비영 존재)"
            return "조립가능", base + (" ▸ " + SCD2_DIM[obj] if obj in SCD2_DIM else "")
        # 🔴 [2026-08-10 O56] **브리지 차원 경유** — 직접 FK 부재가 도달불가를 뜻하지 않는다.
        #   O49 적발 7건(3-7 좌측)의 원인. 브리지 유일성·팬아웃·채움을 실측한 뒤에만 연다(P94 아님).
        br = IDENTITY_BRIDGE.get(anchor)
        if br and obj in br["reaches"]:
            bridge_alive = fk_alive.get(anchor, {}).get(br["bridge"])
            if bridge_alive is True:
                return "조립가능", (
                    f"`{anchor}` → `{br['bridge']}` → `{obj}` **2홉 브리지 경유**"
                    f"(브리지 FK 생존 · 조인키 `{br['key']}`) ▸ " + br["why"]
                    + (" ▸ " + SCD2_DIM[obj] if obj in SCD2_DIM else ""))
        ev = BRONZE_EVIDENCE.get((anchor, obj), "")
        if obj == "DIM_MEMBER_IDENTITY" and not ev:
            ev = DIM_IDENTITY_NOTE
        if alive is False:
            base = f"`{anchor}` → `{obj}` FK **전건 센티넬** — 조인해도 `(미매핑)` 한 덩어리가 된다"
        else:
            base = f"`{anchor}` 에 `{obj}` 로 가는 FK 가 없다"
        return "도달불가", (base + " ▸ BRONZE 근거: " + ev) if ev else base

    if obj.startswith("FACT_"):
        ga, gb = grain.get(anchor, {}), grain.get(obj, {})
        sa, sb = SRC_SYS.get(anchor, "?"), SRC_SYS.get(obj, "?")
        pe = FACT_PAIR_EVIDENCE.get((anchor, obj), "")
        suffix = (" ▸ BRONZE 근거: " + pe) if pe else ""
        pair = frozenset((anchor, obj))
        # 🔴 동일 원천 형제 팩트는 **축 비교보다 먼저** 막는다. 축이 같아 보이는 것이 바로 함정이다.
        sib = SAME_SOURCE_SIBLING.get(pair)
        if sib:
            return "형제팩트중복", f"동일 원천 형제 팩트 — 함께 조립하면 이중계상. {sib}"
        # 🔴 [O47] 1:1 위성은 **grain 비교 대상이 아니다** — 조인키 유일성으로 판정한다(P96-③).
        sat = ONE_TO_ONE_SATELLITE.get(pair)
        if sat:
            return "조립가능", sat
        # 🔴 [O47 자기교정] **원천 검사를 방향성 검사보다 먼저** 한다.
        #   최초 수정에서 시간축 검사를 앞에 뒀더니 `FMM`(CRM) ← `FACT_GA_BEHAVIOR`(GA4) 3건이
        #   「집계필요 = 열린다」로 나왔다. **GA4 를 회원-월로 집계하려면 identity 브리지가 필요하고
        #   그 커버리지가 G-5 대기 상태**이므로 이는 낙관 편향(P94)이다. 판정은 보수적 방향으로 정렬한다.
        if sa != sb:
            return "타원천", f"원천 상이 — `{anchor}`={sa} vs `{obj}`={sb}. 연결키 확보 전 교차 금지" + suffix
        if ga.get("time") != gb.get("time"):
            # 🔴 [O47] 방향성 판정 — 축이 다르다는 사실만으로 닫으면 해소 경로가 사라진다(P95).
            ra = min([TIME_RANK.get(t, 9) for t in (ga.get("time") or [])] or [9])
            rb = min([TIME_RANK.get(t, 9) for t in (gb.get("time") or [])] or [9])
            axis = (f"시간축 상이 — `{anchor}`={'/'.join(ga.get('time') or ['없음'])} vs "
                    f"`{obj}`={'/'.join(gb.get('time') or ['없음'])}")
            if rb < ra:      # 대상이 앵커보다 **잘다** → fine→coarse = 사전집계로 해결
                return "집계필요", (
                    axis + ". 🟢 **불가가 아니다** — `" + obj + "` 를 앵커 grain 으로 **먼저 집계한 뒤** 조인하면 "
                    "팬아웃이 0 이다. 🔴 naive 조인(사전집계 없이)만 이중계상을 만든다. "
                    "실측 증명: `FMM ⋈ (FSE→회원·월 사전집계)` 행 40,054,883 **불변** · "
                    "청구액 891,959,790,888 **불변**(2026-08-07 O47)." + suffix
                    + _nonadditive_note(obj, col))
            if ra < rb:      # 대상이 앵커보다 **굵다** → coarse→fine = 배분규칙 필요
                return "배분규칙필요", (
                    axis + ". 🔴 굵은 쪽을 잘게 내리려면 **배분(귀속) 규칙**이 필요하다 — 규칙 없이 조인하면 "
                    "굵은 값이 잘은 행마다 복제된다. 이것은 모델링이 아니라 **업무 판단**이다(O47·P95)." + suffix)
            return "grain부정합", (axis + ". 조밀도 순위를 판정할 수 없다(축 정의 확인 필요)" + suffix)
        if sa != sb:
            return "타원천", f"원천 상이 — `{anchor}`={sa} vs `{obj}`={sb}. 연결키 확보 전 교차 금지" + suffix
        if ga.get("entity") != gb.get("entity"):
            return "grain부정합", (f"엔티티축 상이 — `{anchor}`={','.join(ga.get('entity') or ['없음'])} vs "
                                f"`{obj}`={','.join(gb.get('entity') or ['없음'])}" + suffix)
        return "조립가능", (f"`{obj}` 가 앵커와 시간·엔티티축 동일" + _nonadditive_note(obj, col))

    return "판정불가", f"`{obj}` 는 GOLD 팩트·차원이 아니다"


if __name__ == "__main__":
    main()
