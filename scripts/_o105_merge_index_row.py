# O105 원장 §1 중복 행 2개(141·142)를 단일 선점 등재 행으로 통합하는 1회용 스크립트.
# Co-authored with CoCo
#
# 배경: 2026-08-28 10:42 KST 타 세션이 -001 에 O105 행을 삽입·허브 재발행했고,
#       10:46 KST 본 세션이 또 하나를 삽입해 O105 행이 2개가 됐다(C7 동시 편집).
#       사용자 승인(「내 행으로 통합 · 141행 내용 흡수」)에 따라 두 행을 1행으로 합친다.
# 안전장치: ① 대상 두 줄이 모두 O105 를 포함하는지 assert ② 앞뒤 줄(헤더 구분선 · O104)이
#           제자리인지 assert ③ 스냅샷을 남긴 뒤 쓴다 ④ 쓴 뒤 행 수·O105 출현 수를 재검증.
# R1-7-9: 본문에 백틱이 있어 셸 인라인을 쓰지 않고 파일로 만들어 실행한다.

import glob
import hashlib
import shutil

PATH = sorted(glob.glob("20_issue/00_INDEX*-001.md"))[0]
SNAP = "_archive/00_INDEX_이슈원장-001.md.O105-pre-merge"

MERGED = (
    "| 🆕 🔒 **`O105` 선점 등재 — 이슈1(캠페인 7속성)·이슈2(후원/법인구분) "
    "실적재 기준 GOLD·SV·Agent 반영 검증 + Agent 스펙 보강** "
    "| 🔒 **착수 등재**(산출물 저작 전) · 🟢 **SILVER·GOLD·SV 전건 반영** · "
    "🔴 **Agent 3종 미반영** · 🟠 **신규 발견 2** · ⚠️ **자기철회 1** "
    "| **[2026-08-28 O105]** 🔒 라벨 = `--next O` = **O105**"
    "(정의 104 ↔ 참조 104 **양축 일치**) · `R1-4-3` 이행. "
    "지시 = 「실적재 기준으로 이슈1·2 가 gold·sv·agent 까지 반영됐는지 확인」 → "
    "「agent 정의 yaml 을 읽고 수정」. 계정 = **`ZL50263`**(O102 정본 동일 · `R2-8-4-a`). "
    "🟢 **원천 계보 = 요청 명세와 일치** — `TM_MM_FDRM_MBER_DVLP_AMT` ⟵`CMPGN_CD`⟶ "
    "`TM_CM_CMPGN_MNG`(`CRM_MEMBER_DEV.sql:99·105`). "
    "🟢 **반영 확인** = SILVER `CRM_MEMBER_DEV` 18컬럼(ord 25~42) · "
    "GOLD `FACT_MEMBER_EVENT` `*_AT_EVENT` 18컬럼(ord 35~52) · `DIM_CAMPAIGN` ord 21~28 · "
    "`WIDE_MEMBER_EVENT` 9축(ord 53~62) · `SV_MEMBER_EVENT` **9차원**(동결값 `fme.*_AT_EVENT`) · "
    "SV 기능 조회 성공. 승계 손실 **0**(18컬럼 COUNT 전건 동일 · 3,594,825/3,594,843 · "
    "채움 예외 2 = `MKTG_UTM_NM` 18.13%·`MK_CMPGN_NM` 67.65%). "
    "🟢 **이슈2 값 검증** = DW 라벨 ↔ `TC_CMMN_DTL_CD` 전건 일치"
    "(CM035 1정기후원/2일시후원 · CM019 A통합/I사단/S사복) · **미매핑 0/36,164 양축** · "
    "창작 라벨 0 · 결손은 **원천 승계뿐**(BRONZE NULL 1,459/36,163 ⇒ "
    "DIM 34,704 = 36,164−1,459−센티넬1 **정확 상쇄**) + grain 조인 실패 18행(0.0005%). "
    "🔴🔴 **최대 적발 = Agent 미반영** — 스펙 3종(파일·라이브)에서 `MKTG_UTM`·`CMMN_BRND`·"
    "`SPNSR_DIV`·`CPR_DIV`·`공통브랜드`·`후원구분`·`법인구분`·`동결` 토큰 **0건** ⇒ "
    "`O98 ▣BB` 3순위가 열려 있었다. 🟠 **신규 발견 2** = ㉠ **WIDE↔SV 소스 축 불일치**"
    "(WIDE 9축 = `DIM_CAMPAIGN` 실시간 조인 `c.*` ↔ SV = 동결값 · 현 시점 불일치 "
    "**0/3,594,843**(`CAMPAIGN_SK` PK 조인)이나 마스터 정정 시 Streamlit↔Cowork 이 갈라진다) "
    "㉡ **SV 지시문 stale**(`MKTG_UTM_NM` 「약 36%」는 캠페인 grain 값이고 이 SV 의 "
    "**사건 grain 실측은 18.13%**). ⚠️ **자기철회 1** = 초판이 WIDE↔FME 를 업무키로 조인해 "
    "**7,005,277행 팬아웃**(>3,594,843)을 만들고 불일치 45만~62만을 보고 ⇒ PK 조인 재측정 **0** "
    "으로 정정(분모 미확인 = `P128` 축). 🔴 **동시 편집 사고(`C7`) 적발** = 본 행은 타 세션이 "
    "10:42 KST 삽입한 O105 행과 **중복**이었고 사용자 승인으로 1행 통합했다 — "
    "🔴 `index_row_gate`(행 키 상이)·`id_collision_gate`(참조 형태)·`R1-7-2`(직전 읽기와 "
    "대조하지 않는다) **3종 전부 침묵**했다 ⇒ `R3-9` 축 신규 사례 "
    "| 이 행 · `20_issue/50_dbt_파이프라인_미결조치.md` §O105 · "
    "`cortex_project/agents/*/agent_spec.yaml` |"
)


def main() -> None:
    raw = open(PATH, encoding="utf-8").read()
    lines = raw.split("\n")

    # 0-indexed: 140·141 = 원장 §1 의 두 O105 행, 142 = O104 행
    assert len(lines) == 149, f"예상 149줄 ↔ 실측 {len(lines)}줄 — 중단"
    assert lines[139].startswith("|---"), f"헤더 구분선 부재: {lines[139][:40]!r}"
    assert "O105" in lines[140], "141행에 O105 없음 — 중단"
    assert "O105" in lines[141], "142행에 O105 없음 — 중단"
    assert "O104" in lines[142], "143행이 O104 행이 아님 — 중단"
    assert "O105" not in lines[142], "143행에 O105 혼입 — 중단"

    shutil.copyfile(PATH, SNAP)

    merged_lines = lines[:140] + [MERGED] + lines[142:]
    out = "\n".join(merged_lines)
    open(PATH, "w", encoding="utf-8").write(out)

    chk = open(PATH, encoding="utf-8").read()
    chk_lines = chk.split("\n")
    o105_rows = [i + 1 for i, s in enumerate(chk_lines) if s.startswith("| 🆕 🔒 **`O105`")]
    print(f"스냅샷      = {SNAP}")
    print(f"줄 수       = {len(lines)} -> {len(chk_lines)}")
    print(f"바이트      = {len(raw.encode())} -> {len(chk.encode())}")
    print(f"SHA256      = {hashlib.sha256(chk.encode()).hexdigest()[:16]}")
    print(f"O105 행 위치 = {o105_rows} (1개여야 통과)")
    print(f"통합 행 길이 = {len(MERGED)}자 (상한 2000 · 목표 1000)")
    print(f"O104 행 보존 = {'O104' in chk_lines[140]}")
    assert len(o105_rows) == 1, "O105 행이 1개가 아니다 — 중단"


if __name__ == "__main__":
    main()
