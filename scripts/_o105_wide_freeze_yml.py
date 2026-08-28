# WIDE_MEMBER_EVENT 캠페인 9속성(11컬럼) description 을 소스 전환(DIM 실시간 → FME 동결값)에 맞춰
# 고치는 1회용 스크립트.
# Co-authored with CoCo
#
# 배경(2026-08-28 O105 · 사용자 지시 「wide 수정해줘」): 모델 SELECT 를 `c.*` → `f.*_AT_EVENT` 로 바꿨다.
#   `_wide_schema.yml` 의 `columns[].description` 이 **라이브 뷰 컬럼 COMMENT 의 정본**이므로(O51-D)
#   문안이 그대로면 라이브가 「DIM_CAMPAIGN.xxx」라고 거짓을 말한다 — O96 이 적발한 것과 같은 유형이다
#   (Agent·Analyst 가 COMMENT 를 답변 근거로 쓴다 · R2-7-4·P212).
# 🔴 규칙7 준수: 문안에 실측 수치(커버리지%·행수)를 넣지 않는다. 규모는 이슈원장 §O105 로 넘긴다.
# 🔴 컬럼 이름·순서·개수는 바꾸지 않는다 — yml columns[] 와 SELECT 불일치는 build ERROR 다.
# 안전장치: ① 대상 11컬럼이 WIDE_MEMBER_EVENT 블록 안에서 각각 유일한지 assert
#           ② description 이 1줄인지 assert(다줄이면 중단) ③ 스냅샷 후 쓰기 ④ 쓴 뒤 yaml 파싱·개수 재검증.

import hashlib
import re
import shutil

PATH = "10_dbt_pipeline/models/gold/wide/_wide_schema.yml"
SNAP = "_archive/_wide_schema.yml.O105-pre-wide-freeze"

FROZEN = (
    "🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.{src} (적재 시점 동결값)** — "
    "종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 "
    "**과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). "
    "전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). "
    "⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 종전 실시간 조인에서는 "
    "센티넬 조인으로 '(미매핑)' 이 나왔으므로 **NULL 의 뜻이 바뀐 지점**이다(0·'미상' 으로 대체 해석 금지)."
)

NEW = {
    "CAMPAIGN_CATEGORY": (
        "캠페인 **카테고리** 라벨(정본 공#17). 코드그룹 **MM294(캠페인 카테고리)**. "
        "⚠️ 원천 `TM_CM_CMPGN_MNG.CMPGN_CTGR_CD` 에 코드사전 미등재 코드가 실재해 그 행은 라벨이 비고, "
        "미채움 행도 있다(규모는 이슈원장 참조). ⚠️ **사전 자체에 동일 라벨 중복**이 있어 라벨로 GROUP BY 하면 "
        "두 코드가 합쳐진다. ⚠️ 업무용어는 '카테고리'이고 상위캠페인은 CAMPAIGN_PARENT 다. " + FROZEN
    ),
    "CAMPAIGN_INFLOW_PATH": (
        "개발인입경로 라벨 = **모집 채널**. 코드그룹 **MM293(개발인입경로)**. "
        "🔴 이 축을 「현업 주요캠페인 분류축」이라고 적었던 기술은 **거짓이므로 회수됐다**(O37) — 모집 채널이다. "
        "캠페인 카테고리 = CAMPAIGN_CATEGORY(MM294) · 상위캠페인 = CAMPAIGN_PARENT. " + FROZEN
    ),
    "CAMPAIGN_DOMESTIC_OVERSEAS": (
        "캠페인 국내/통합/해외 라벨. 코드그룹 **MM295**. " + FROZEN
    ),
    "CAMPAIGN_BIZ_CASE_TYPE": (
        "캠페인 굿즈/기타/사례/사업 구분 라벨. 코드그룹 **MM296**. "
        "⚠️ CAMPAIGN_DOMESTIC_OVERSEAS(유형1=국내/해외 축)와 다른 축이다 — 혼동 금지. " + FROZEN
    ),
    "CAMPAIGN_MARKETING_CAMPAIGN": (
        "마케팅캠페인명 라벨(Q16 해소). 🔴 광고비 결합은 이 라벨이 아니라 MKTG_CAMPAIGN_SK(FK)를 쓴다 — "
        "라벨로 결합하면 안 된다(O44/O45). " + FROZEN
    ),
    "CAMPAIGN_CMMN_BRND": (
        "공통브랜드 라벨. 코드그룹 **MM297**. "
        "⚠️ 라벨이 MM293(개발인입경로)과 상당 중복되나 현업 확인상 별도 축으로 유지한다. " + FROZEN
    ),
    "CAMPAIGN_MKTG_UTM": (
        "UTM 라벨. 코드사전이 아니라 원천 TM_CM_MKTNG_UTM(MK_UTM/MK_UTM_NM)과 연동된 값. "
        "⚠️ 원천 미등재 코드가 많아 라벨 채움이 낮다 — **결측이 아니라 미등재**다. "
        "🔴 채움 비율은 규칙7 상 여기 적지 않는다(재적재마다 stale 이 된다) ⇒ 조회로 확인하고 "
        "UTM별 분해가 부분집합임을 밝힐 것. " + FROZEN
    ),
    "CAMPAIGN_SPNSR_DIV_CD": (
        "세부캠페인 후원구분 원천코드. 코드그룹 **CM035**: 1=정기후원 · 2=일시후원. "
        "🔴 라벨이 아니다 — 사람이 읽는 이름은 CAMPAIGN_SPNSR_DIV_NM. " + FROZEN
    ),
    "CAMPAIGN_SPNSR_DIV_NM": (
        "CAMPAIGN_SPNSR_DIV_CD 를 CM035 로 해소한 라벨(정기후원/일시후원). "
        "⚠️ DIM_SPONSORSHIP.SPONSORSHIP_DIV_NAME(후원사업 축 CM035)과 코드사전은 같지만 "
        "**적용 대상이 다르다** — 이 컬럼은 세부캠페인 단위 구분이다. " + FROZEN
    ),
    "CAMPAIGN_CPR_DIV_CD": (
        "세부캠페인 법인구분 원천코드. 코드그룹 **CM019**: A=통합 · I=사단 · S=사복. "
        "🔴 라벨이 아니다 — 사람이 읽는 이름은 CAMPAIGN_CPR_DIV_NM. "
        "🔴 조직 계층의 법인(ORG_CORP)과 **다른 축**이다 — ORG_CORP 는 전건 비어 있고 이 축은 채워진다. " + FROZEN
    ),
    "CAMPAIGN_CPR_DIV_NM": (
        "CAMPAIGN_CPR_DIV_CD 를 CM019 로 해소한 라벨(통합/사단/사복). "
        "🔴 조직 계층의 법인(ORG_CORP)과 **다른 축**이다 — 「법인별」 질문은 어느 축인지 먼저 가린다. " + FROZEN
    ),
}

SRC = {
    "CAMPAIGN_CATEGORY": "CMPGN_CTGR_NM_AT_EVENT",
    "CAMPAIGN_INFLOW_PATH": "MBER_INFLOW_PATH_NM_AT_EVENT",
    "CAMPAIGN_DOMESTIC_OVERSEAS": "CMPGN_TYPE1_NM_AT_EVENT",
    "CAMPAIGN_BIZ_CASE_TYPE": "CMPGN_TYPE2_NM_AT_EVENT",
    "CAMPAIGN_MARKETING_CAMPAIGN": "MKTG_CMPGN_NM_AT_EVENT",
    "CAMPAIGN_CMMN_BRND": "CMMN_BRND_NM_AT_EVENT",
    "CAMPAIGN_MKTG_UTM": "MKTG_UTM_NM_AT_EVENT",
    "CAMPAIGN_SPNSR_DIV_CD": "SPNSR_DIV_CD_AT_EVENT",
    "CAMPAIGN_SPNSR_DIV_NM": "SPNSR_DIV_NM_AT_EVENT",
    "CAMPAIGN_CPR_DIV_CD": "CPR_DIV_CD_AT_EVENT",
    "CAMPAIGN_CPR_DIV_NM": "CPR_DIV_NM_AT_EVENT",
}


def main() -> None:
    raw = open(PATH, encoding="utf-8").read()
    lines = raw.split("\n")

    s = [i for i, x in enumerate(lines) if x.strip() == "- name: WIDE_MEMBER_EVENT"]
    assert len(s) == 1, "WIDE_MEMBER_EVENT 블록이 유일하지 않다 — 중단"
    s = s[0]
    nxt = [i for i in range(s + 1, len(lines)) if lines[i].startswith("  - name: ")]
    e = nxt[0] if nxt else len(lines)

    idx = {}
    for i in range(s, e):
        m = re.match(r"\s*- name:\s*(\S+)\s*$", lines[i])
        if m and m.group(1) in NEW:
            assert m.group(1) not in idx, f"{m.group(1)} 이 블록 안에 중복 — 중단"
            assert lines[i + 1].lstrip().startswith("description:"), \
                f"{m.group(1)} 다음 줄이 description 이 아니다 — 중단"
            assert lines[i + 2].lstrip().startswith("- name:") or \
                re.match(r"\s*(- name:|tests:|[a-z_]+:)", lines[i + 2]), \
                f"{m.group(1)} description 이 여러 줄이다 — 중단"
            idx[m.group(1)] = i + 1
    assert len(idx) == len(NEW), f"대상 {len(NEW)} 중 {len(idx)} 만 찾음 — 중단"

    shutil.copyfile(PATH, SNAP)
    for name, li in idx.items():
        indent = lines[li][: len(lines[li]) - len(lines[li].lstrip())]
        body = NEW[name].format(src=SRC[name]).replace('"', "'")
        lines[li] = f'{indent}description: "{body}"'
    out = "\n".join(lines)
    open(PATH, "w", encoding="utf-8").write(out)

    import yaml
    d = yaml.safe_load(open(PATH, encoding="utf-8"))
    mdl = [m for m in d["models"] if m["name"] == "WIDE_MEMBER_EVENT"][0]
    cols = [c["name"] for c in mdl["columns"]]
    over = [i + 1 for i, x in enumerate(out.split("\n")) if len(x) > 2000]
    dim_left = [n for n in NEW if "DIM_CAMPAIGN." in
                [c for c in mdl["columns"] if c["name"] == n][0]["description"]]
    print(f"스냅샷        = {SNAP}")
    print(f"바이트        = {len(raw.encode())} -> {len(out.encode())}")
    print(f"SHA256        = {hashlib.sha256(out.encode()).hexdigest()[:16]}")
    print(f"yaml OK       = WIDE_MEMBER_EVENT 컬럼 {len(cols)}개")
    print(f"교체 컬럼     = {len(idx)} / {len(NEW)}")
    print(f"DIM_CAMPAIGN 잔존 = {dim_left} (0이어야 통과)")
    print(f"동결 문안 삽입    = {sum(1 for c in mdl['columns'] if '적재 시점 동결값' in c['description'])}")
    print(f"2000자 초과   = {over}")
    assert not over and not dim_left


if __name__ == "__main__":
    main()
