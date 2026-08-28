# O105 종료 반영(2차) — 원장 §1 O105 행을 「완료」 압축본으로 통째 교체하고 이력 §O105 를 정정한다.
# Co-authored with CoCo
#
# 왜 통째 교체인가: 1차 시도는 증분 치환이었는데 행이 **2000자를 넘겼다**(`R1-5-1`). 이 행은 이미
#   상세를 담고 있었고 그 상세는 `02 §O105`·`99_NEXT §0-KKK`·이력 §O105 에 **중복 실재**한다
#   ⇒ 원장 행은 `O66` 규약대로 **판정 요약 + 포인터**로 축약하는 것이 옳다(증분으로는 줄일 수 없다).
# 🔴 행 키(제목 셀)는 보존한다 — `index_row_gate` 가 삭제를 유실로 잡는다(`R1-7-4`).
# 안전장치: ① O105 행이 유일한지 assert ② 앞뒤 행(헤더 구분선·O104) 제자리 assert ③ 스냅샷
#           ④ 쓴 뒤 행 수 불변·2000자 이내·핵심 토큰 보존 재검증.
# R1-7-9: 백틱이 본문에 있어 셸을 경유시키지 않고 파일로 만들어 실행한다.

import glob
import hashlib
import shutil

IDX = sorted(glob.glob("20_issue/00_INDEX*-001.md"))[0]
SNAP_IDX = "_archive/00_INDEX_이슈원장-001.md.O105-final2"

ROW = (
    "| 🆕 🟢 **`O105` — 이슈1·2 실적재 검증 + Agent 2종 보강·배포 + 추천질문 축약 + WIDE 동결 전환 + SV 규칙7 시정** "
    "| 🟢 **전 계층 반영 완료** · 🟢 **WIDE build·검증 통과** · 🟠 **잔여 4** · "
    "🔴 **자기결함 5(전건 정정)** · 🔴 **동시편집 사고 1** "
    "| **[2026-08-28 O105 · 계정 `ZL50263`]** 🔒 정의 104 ↔ 참조 104 · `R1-4-3` 이행. "
    "🟢 **반영** = 원천 계보가 요청 명세와 일치(`TM_MM_FDRM_MBER_DVLP_AMT` ⟵`CMPGN_CD`⟶ `TM_CM_CMPGN_MNG`) · "
    "SILVER `CRM_MEMBER_DEV` 18컬럼 · GOLD `FACT_MEMBER_EVENT` `*_AT_EVENT` 18 · `DIM_CAMPAIGN` 4 · "
    "`WIDE_MEMBER_EVENT` 9축 · `SV_MEMBER_EVENT` 9차원 · 승계 손실 **0**. "
    "🟢 **이슈2 값 검증** = DW 라벨 ↔ `TC_CMMN_DTL_CD` **전건 일치**(CM035·CM019) · **미매핑 0/36,164 양축** · "
    "창작 라벨 0 · 결손은 원천 승계뿐(BRONZE NULL 1,459/36,163 ⇒ DIM 34,704 **정확 상쇄**). "
    "🔴→🟢 **Agent 미반영 해소** = 착수 시 스펙 3종 신규축 토큰 **0**(`O98 ▣BB` 미결) ⇒ 2종에 차원 4종 + "
    "**동결값 성격** + **「법인」 두 축 구별**(조직 `ORG_CORP` 불가 ↔ 세부캠페인 `CPR_DIV_NM` 가능) 명시 · "
    "배포(사용자 `09_2` `ADD VERSION FROM` · ⑳) `VERSION$9`·`VERSION$5` **is_default** · **기능검증** = "
    "법인구분별 질의가 통합 195,796 등 반환 + 두 축 구별·동결값·DEV 전용 자발 고지 ⇒ 「산출 불가」 오답 해소. "
    "🟢 **추천질문** 34→**12**(도구당 1 + 원천 1 · 상한 15 규약 `08_AGENT_spec.md` 등재 · O84 가 30→10 후 34 로 복귀했었다). "
    "🟢 **WIDE 동결 전환 완료** = 모델 11컬럼 `c.*`→`f.*_AT_EVENT` + yml 11 · `dbt build` **PASS=2** · "
    "불변식 2종 통과(소스 11/11 · 행수 불변 · 채움 전환 前과 동일 · 마스터 등가 **0/3,594,843** PK · "
    "STOP 9축 non-NULL **0** ⇒ NULL 의미 불변). "
    "🟢 **SV 규칙7** = `약 36%` 2곳 제거 ⇒ 라이브 위반 **0**(🔴 `audit_ddl_rule7` 분모에 SV DDL 부재 · 스캐너 신설). "
    "🔴 **자기결함 5**(전건 보고 전 적발·정정 · 팬아웃 2 · 검사기 분모 공백 3) · 🔴🔴 **재진단** = 초판 원인 "
    "「분모 미확인」은 **증상**이라 5번째를 못 막았다 ⇒ 진짜 원인 = **WIDE 에 유일키 없는데 조인 대조**"
    "(FME PK 미선언) · 처방 = **WIDE 는 집계 비교 · 등가는 base 팩트에서**. "
    "🔴 **동시편집 `C7`** = 타 세션 동일 라벨 행 ⇒ 승인 후 1행 통합 · **게이트 3종 침묵**(`R3-9` 신규). "
    "🟢 **등재·유지** = 이력 `01_세션이력-035` · `99_NEXT` 재균형 **12→13** · 골든 2회(전건 승인). "
    "🟠 **잔여 4** = SV 규칙7 **10건**+재배포 · `agent_tool_claim_gate` 로직 · 추천질문 상한 게이트 · "
    "`R1-7-2` 보강(`C7`) · 부수 `09_2` COMMENT 「추천질문 31」 stale(실제 **12**) "
    "| 🔴 **장문 정본 = `02 §O105` · 이력 §O105 · `99_NEXT §0-KKK`** · `cortex_project/agents/*/agent_spec.yaml` |"
)

TOKENS = ["195,796", "0/3,594,843", "34→**12**", "PASS=2", "미매핑 0/36,164", "C7", "VERSION$9",
          "약 36%", "ORG_CORP", "O98 ▣BB", "01_세션이력-035", "12→13"]


def main() -> None:
    raw = open(IDX, encoding="utf-8").read()
    lines = raw.split("\n")
    hits = [i for i, s in enumerate(lines) if s.startswith("| 🆕 🟢 **`O105`")]
    assert len(hits) == 1, f"O105 행이 {len(hits)}개 — 중단"
    i = hits[0]
    assert lines[i - 1].startswith("|---"), f"직전이 헤더 구분선이 아니다: {lines[i-1][:40]!r}"
    assert "O104" in lines[i + 1], f"직후가 O104 행이 아니다: {lines[i+1][:40]!r}"
    assert len(ROW) <= 2000, f"신규 행 {len(ROW)}자 — 상한 초과"

    shutil.copyfile(IDX, SNAP_IDX)
    lines[i] = ROW
    out = "\n".join(lines)
    open(IDX, "w", encoding="utf-8").write(out)

    chk = open(IDX, encoding="utf-8").read()
    L = chk.split("\n")
    over = [n + 1 for n, s in enumerate(L) if len(s) > 2000]
    miss = [t for t in TOKENS if t not in chk]
    print(f"스냅샷      = {SNAP_IDX}")
    print(f"줄 수       = {len(lines)} (불변 {len(lines) == len(L)})")
    print(f"바이트      = {len(raw.encode())} -> {len(chk.encode())}")
    print(f"SHA256      = {hashlib.sha256(chk.encode()).hexdigest()[:16]}")
    print(f"O105 행 길이 = {len(ROW)}자 (상한 2000)")
    print(f"2000자 초과 = {over}")
    print(f"토큰 부재   = {miss} (0건이어야 통과 · 분모 {len(TOKENS)})")
    print(f"O104 보존   = {'O104' in L[i + 1]}")
    assert not over and not miss and "O104" in L[i + 1]


if __name__ == "__main__":
    main()
