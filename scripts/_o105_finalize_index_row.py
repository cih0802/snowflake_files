# O105 원장 §1 행을 착수 등재 → 배포·검증 완료 상태로 갱신하는 1회용 스크립트.
# Co-authored with CoCo
#
# 배경: 사용자가 09_2(ADD VERSION FROM) 로 Agent 2종을 배포했고 라이브 대조·기능 테스트가 통과했다.
#       R4-2(큰 작업 종료 시 원장 갱신) · R2-4(완료 판정은 실측) · R2-8-4-a(무엇을·어느 계정에서·언제).
# 안전장치: ① 대상 행이 유일한 O105 행인지 assert ② 앞뒤 행(헤더 구분선·O104) 제자리 assert
#           ③ 스냅샷 후 쓰기 ④ 쓴 뒤 행 수 불변·O105 1개·2000자 이내 재검증.
# R1-7-9: 본문에 백틱이 있어 셸 인라인을 쓰지 않고 파일로 만들어 실행한다.

import glob
import hashlib
import shutil

PATH = sorted(glob.glob("20_issue/00_INDEX*-001.md"))[0]
SNAP = "_archive/00_INDEX_이슈원장-001.md.O105-pre-done"

ROW = (
    "| 🆕 🟢 **`O105` — 이슈1(캠페인 7속성)·이슈2(후원/법인구분) 실적재 검증 + Agent 2종 스펙 보강·배포** "
    "| 🟢 **SILVER·GOLD·SV 전건 반영** · 🟢 **Agent 2종 배포·기능검증 완료** · "
    "🟠 **신규 발견 3** · ⚠️ **자기철회 1** · 🔴 **동시편집 사고 1** "
    "| **[2026-08-28 O105 · 계정 `ZL50263`]** 🔒 라벨 정의 104 ↔ 참조 104 · `R1-4-3` 이행. "
    "🟢 **원천 계보 = 요청 명세 일치**(`TM_MM_FDRM_MBER_DVLP_AMT` ⟵`CMPGN_CD`⟶ `TM_CM_CMPGN_MNG` · "
    "`CRM_MEMBER_DEV.sql:99·105`). 🟢 **반영 확인** = SILVER `CRM_MEMBER_DEV` 18컬럼(ord 25~42) · "
    "GOLD `FACT_MEMBER_EVENT` `*_AT_EVENT` 18컬럼(ord 35~52) · `DIM_CAMPAIGN` ord 21~28 · "
    "`WIDE_MEMBER_EVENT` ord 53~62 · `SV_MEMBER_EVENT` 9차원 · 승계 손실 **0**(3,594,825/3,594,843). "
    "🟢 **이슈2 값 검증** = DW 라벨 ↔ `TC_CMMN_DTL_CD` **전건 일치**(CM035 1정기후원/2일시후원 · "
    "CM019 A통합/I사단/S사복) · **미매핑 0/36,164 양축** · 창작 라벨 0 · 결손은 원천 승계뿐"
    "(BRONZE NULL 1,459/36,163 ⇒ DIM 34,704 = 36,164−1,459−센티넬1 **정확 상쇄**) + grain 조인 실패 18행. "
    "🔴→🟢 **Agent 미반영 적발·해소** = 착수 시 스펙 3종 전건 신규축 토큰 **0**(`O98 ▣BB` 3순위 미결) ⇒ "
    "`AGENT_MEMBER`·`AGENT_MARKETING` `analyst_member_event` 에 **차원 4종 + 9속성 동결값 성격 + "
    "「법인」 두 축 구별**(조직 `ORG_CORP` 불가 ↔ 세부캠페인 `CPR_DIV_NM` 가능) 명시 · MEMBER 는 "
    "orchestration·system·추천질문(31→34) 추가. 🟢 **배포(사용자 실행 · `09_2` `ADD VERSION FROM` · ⑳)** = "
    "`AGENT_MEMBER VERSION$9`·`AGENT_MARKETING VERSION$5` **is_default** · 신규 토큰 라이브 실재"
    "(직전 버전은 전건 0) · **기능 검증** = 법인구분별 질의가 통합 195,796·사단 1,005·사복 1 반환 + "
    "답변이 두 축 구별·동결값·DEV 전용을 자발 고지 ⇒ 종전 「산출 불가」 오답 경로 해소. "
    "🟠 **신규 발견 3**(㉠ WIDE↔SV 소스 축 불일치 ㉡ SV 지시문 `MKTG_UTM_NM` 수치 stale "
    "㉢ `agent_tool_claim_gate` 축 결함 = 선재 FAIL 1 실증) · ⚠️ **자기철회 1**(팬아웃 7,005,277행 → "
    "PK 조인 **0** 정정 · `P128`) · 🔴 **동시편집 사고 `C7`**(타 세션이 같은 라벨 행 삽입 ⇒ 승인 후 1행 통합 · "
    "**게이트 3종 전부 침묵** = `R3-9` 신규 사례) ⇒ 🔴 **장문 경위·근거 정본 = `02 §O105`**. "
    "🟠 **잔여** = 세션이력 등재(`--rollover` = `R4-4-3` 승인 대상) · ㉠㉡㉢ 처분 · "
    "`09_2` COMMENT 「추천질문 31」 stale(실제 34) "
    "| **`02 §O105`**(정본) · 이 행 · "
    "`cortex_project/agents/{AGENT_MEMBER,AGENT_MARKETING}/agent_spec.yaml` |"
)


def main() -> None:
    raw = open(PATH, encoding="utf-8").read()
    lines = raw.split("\n")

    hits = [i for i, s in enumerate(lines) if s.startswith("| 🆕 🔒 **`O105`")]
    assert len(hits) == 1, f"O105 착수 행이 1개가 아니다(={len(hits)}) — 중단"
    idx = hits[0]
    assert lines[idx - 1].startswith("|---"), f"직전이 헤더 구분선이 아니다: {lines[idx-1][:40]!r}"
    assert "O104" in lines[idx + 1], f"직후가 O104 행이 아니다: {lines[idx+1][:40]!r}"
    assert len(ROW) <= 2000, f"신규 행 {len(ROW)}자 — 상한 2000 초과"

    shutil.copyfile(PATH, SNAP)
    lines[idx] = ROW
    out = "\n".join(lines)
    open(PATH, "w", encoding="utf-8").write(out)

    chk = open(PATH, encoding="utf-8").read().split("\n")
    o105 = [i + 1 for i, s in enumerate(chk) if "`O105`" in s and s.startswith("| 🆕")]
    over = [i + 1 for i, s in enumerate(chk) if len(s) > 2000]
    print(f"스냅샷        = {SNAP}")
    print(f"줄 수         = {len(lines)} (불변 확인 {len(lines) == len(chk)})")
    print(f"바이트        = {len(raw.encode())} -> {len(open(PATH, 'rb').read())}")
    print(f"SHA256        = {hashlib.sha256(open(PATH, 'rb').read()).hexdigest()[:16]}")
    print(f"O105 행       = {o105} (1개여야 통과) · 갱신행 {len(ROW)}자")
    print(f"2000자 초과   = {over}")
    print(f"O104 행 보존  = {'O104' in chk[idx + 1]}")
    assert len(o105) == 1 and not over


if __name__ == "__main__":
    main()
