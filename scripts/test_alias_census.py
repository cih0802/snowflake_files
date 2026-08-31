#!/usr/bin/env python3
# alias_census.classify 의 음성 테스트 — 초판이 실제로 낸 오분류를 회귀 축으로 고정한다.
# Co-authored with CoCo
#
# 🔴 왜 이 테스트가 필요한가 (2026-08-30 O122)
#   `alias_census.py` 초판은 `NULL as DW_BATCH_ID` 와 `end as DURATION_SEC` 를
#   「이명 pass-through」로 세어 SILVER 위반을 **90건으로 과대 집계**했다(실제 32건).
#   그 결함은 게이트가 아니라 **사람이 샘플을 눈으로 보다가** 발견했다
#   ⇒ 정상 입력만 넣어 보면 초판도 「통과」했다(지침 R3-2 가 말하는 바로 그 상태).
#   그래서 이 테스트는 **초판이 틀렸던 입력을 회귀 축으로 박아 둔다.**
#
# 판정 = 종료코드다. 🔴 출력 문구로 판정하지 마라(지침 O120 「파이프 뒤 $? 금지」와 같은 축).
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import alias_census as ac  # noqa: E402

CASES = [
    # (라벨, expr, alias, 기대 class, 기대 source_name)
    ("동명 bare", "MBER_NO", "MBER_NO", "A_same", "MBER_NO"),
    ("동명 bare 대소문자", "mber_no", "MBER_NO", "A_same", "mber_no"),
    ("이명 bare", "HMPG_ID", "HOMEPAGE_ID", "B_renamed", "HMPG_ID"),
    ("동명 수식", "s.OPEN_DT", "OPEN_DT", "A_same", "OPEN_DT"),
    ("이명 수식", "s.FRST_REGIST_DT", "JOIN_DT", "B_renamed", "FRST_REGIST_DT"),
    # 🔴 회귀 축 — 초판은 아래 둘을 B_renamed 로 셌다.
    ("리터럴 NULL(회귀)", "NULL", "DW_BATCH_ID", "D_literal", "NULL"),
    ("CASE 종결 end(회귀)", "end", "DURATION_SEC", "D_literal", "end"),
    ("리터럴 TRUE", "TRUE", "IS_ACTIVE", "D_literal", "TRUE"),
    # 🟢 DEC-25 15-A 가 규정한 개명 = 위반이 아니다.
    ("라벨 조인", "DTL_CD_NM", "AREA_NM", "E_label_join", "DTL_CD_NM"),
    ("라벨 조인 수식", "c.DTL_CD_NM", "EVENT_DIV_NM", "E_label_join", "DTL_CD_NM"),
    # 표현식 = 로직 유입 지점.
    ("함수", "TRY_TO_NUMBER(YEAR)", "BUDGET_YEAR", "C_expr", None),
    ("문자열 결합", "A || '-' || B", "GA_SESSION_KEY", "C_expr", None),
    ("MD5 파생키", "MD5(COALESCE(X,''))", "BUDGET_ITEM_DK", "C_expr", None),
    ("산술", "AMT / 1000", "AMT_K", "C_expr", None),
]


def main() -> int:
    passed = 0
    failed = []
    for label, expr, alias, want_class, want_src in CASES:
        got_class, got_src = ac.classify(expr, alias)
        ok = got_class == want_class and got_src == want_src
        if ok:
            passed += 1
        else:
            failed.append((label, expr, alias, want_class, want_src, got_class, got_src))

    # 축: 회귀 케이스가 초판 오분류(B_renamed)로 돌아가지 않았는가
    regress = [c for c in CASES if "회귀" in c[0]]
    regress_bad = [c for c in regress if ac.classify(c[1], c[2])[0] == "B_renamed"]

    # 축: 분류 상수가 비어 있지 않은가(오염 시 전 케이스가 조용히 통과한다)
    const_bad = []
    if not ac.NOT_A_COLUMN:
        const_bad.append("NOT_A_COLUMN 이 비었다")
    if not ac.LABEL_SOURCES:
        const_bad.append("LABEL_SOURCES 가 비었다")

    print(f"== alias_census.classify 음성 테스트 — 케이스 {len(CASES)} ==")
    print(f"   통과 {passed} · 실패 {len(failed)}")
    print(f"   회귀 축(초판 오분류 재발) = {len(regress_bad)}건 (0 이어야 한다)")
    print(f"   상수 오염 축 = {len(const_bad)}건 (0 이어야 한다)")
    for label, expr, alias, wc, ws, gc, gs in failed:
        print(f"   🔴 {label}: ({expr!r} as {alias}) 기대 {wc}/{ws} → 실제 {gc}/{gs}")
    for msg in const_bad:
        print(f"   🔴 {msg}")

    if failed or regress_bad or const_bad:
        print("🔴 FAIL")
        return 1
    print("🟢 PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
