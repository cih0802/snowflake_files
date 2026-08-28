# O105 종료 반영 — 원장 §1 행과 세션이력 §O105 를 「build·검증 완료 + 결함 5건」 기준으로 갱신한다.
# Co-authored with CoCo
#
# 배경(2026-08-28): 사용자가 `dbt build --select WIDE_MEMBER_EVENT` 를 실행(PASS=2)했고 불변식 2종이
#   전건 통과했다. 또 그 검증 과정에서 팬아웃 결함이 **5번째**로 재발해 초판 진단(「분모 미확인」)이
#   증상이었음이 드러났다 ⇒ 원장·이력의 두 서술을 실측·재진단에 맞춘다(`R4-2`·`R2-4`).
# 🔴 이력은 append형이지만 **사실 오류·불완전 서술의 제자리 정정**이므로 조각을 편집한다
#   (`90_해소완료_로그` §Q16 오진 철회가 같은 선례 · 정정 후 `--republish` 로 허브 동기화).
# 안전장치: ① 각 대상 문안이 유일한지 assert ② 스냅샷 후 쓰기 ③ 쓴 뒤 2000자·구문안 잔존 재검증.
# R1-7-9: 백틱이 본문에 있어 셸을 경유시키지 않고 파일로 만들어 실행한다.

import glob
import hashlib
import shutil

# ── ① 원장 §1 O105 행: 「WIDE 동결 전환(파일)」 → 「build·검증 완료」 + 결함 5건 ────────────────
IDX = sorted(glob.glob("20_issue/00_INDEX*-001.md"))[0]

IDX_OLD_A = (
    "🟠 **신규 발견 3**(㉠ WIDE↔SV 소스 축 불일치 ㉡ SV 지시문 `MKTG_UTM_NM` 수치 stale "
    "㉢ `agent_tool_claim_gate` 축 결함 = 선재 FAIL 1 실증) · ⚠️ **자기철회 1**(팬아웃 7,005,277행 → "
    "PK 조인 **0** 정정 · `P128`) · "
)
IDX_NEW_A = (
    "🟢 **WIDE 동결 전환 완료** — 모델 11컬럼 `c.*`→`f.*_AT_EVENT` + yml 11 description 후 사용자 "
    "`dbt build` **PASS=2 ERROR=0** · 불변식 2종 통과(소스 11/11 · 행수 4,633,105 불변 · 9축 채움 전환 前과 "
    "동일 · 마스터 등가 **0/3,594,843** PK · STOP 9축 non-NULL **0**). "
    "🟠 **신규 발견 3**(㉠ WIDE↔SV 소스 축 불일치 = **처분 완료** ㉡ SV 지시문 수치 stale ㉢ "
    "`agent_tool_claim_gate` 축 결함 = 선재 FAIL 실증) · 🔴 **자기결함 5**(전건 자기적발·정정 · 팬아웃 2 · "
    "검사기 분모 공백 3) · 🔴🔴 **재진단** = 초판이 원인을 「분모 미확인」으로 적었으나 **증상**이었고 그래서 "
    "5번째를 못 막았다 ⇒ 진짜 원인 = **WIDE 에 유일키가 없는데 조인으로 대조**(FME PK 미선언) · 처방 = "
    "**WIDE 는 집계 비교 · 등가는 base 팩트에서**(정본 `99_NEXT §0-KKK ▣EEE`) · "
)

IDX_OLD_B = (
    "🟠 **잔여** = 세션이력 등재(`--rollover` = `R4-4-3` 승인 대상) · ㉠㉡㉢ 처분 · "
    "`09_2` COMMENT 「추천질문 31」 stale(실제 34) "
)
IDX_NEW_B = (
    "🟢 **등재·유지 완료**(이력 `-035` `--rollover` · `99_NEXT` 재균형 12→13 · 골든 2회 · 전건 승인). "
    "🟠 **잔여** = ㉡㉢ 처분(SV 규칙7 10건 + 게이트 로직 · 승인) · 추천질문 상한 게이트 · `R1-7-2` 보강(`C7`) · "
    "`09_2` COMMENT 「추천질문 31」 stale(실제 **12**) "
)

# ── ② 이력 §O105 ▣F: 「dbt build 미실행」 → 실행·검증 완료 ──────────────────────────────
HIST = sorted(glob.glob("20_issue/01_세션이력_조각/01_세션이력-0*.md"))[-1]

H_OLD_F = "> · ⏸ **`dbt build` 는 실행하지 않았다**(`R4-1` 정지점) — 사용자 실행 대기.\n"
H_NEW_F = (
    "> · 🟢 **`dbt build` 완료·검증 통과**(사용자 실행 · `R4-1` 준수) — `build --target dev --select "
    "WIDE_MEMBER_EVENT` **PASS=2 WARN=0 ERROR=0 SKIP=0**. build 후 라이브 실측 = 소스 `f.*_AT_EVENT` **11/11** ·\n"
    ">   `c.*` **0** · 「적재 시점 동결값」 COMMENT 11 · 구 「DIM_CAMPAIGN.xxx」 문안 **0** · 행수 4,633,105\n"
    ">   (DEV 3,594,843 · STOP 1,038,262) **불변** · 9축 채움 **전환 前과 전건 동일** · 마스터 등가 불일치\n"
    ">   **0 / 3,594,843**(`CAMPAIGN_SK` PK 조인) · STOP 행 9축 non-NULL **0**(NULL 의미 불변 확인).\n"
)

# ── ③ 이력 §O105 ▣H: 결함 3→5건 + 재진단 ─────────────────────────────────────────────
H_OLD_H = (
    "> ##### ▣ H. 🔴 자기적발 — 같은 결함(`P128` 분모 미확인)을 한 세션에 두 번 냈다\n"
)
H_NEW_H = (
    "> ##### ▣ H. 🔴🔴 자기적발 — 같은 결함을 한 세션에 **다섯 번** 냈고, 초판 진단이 틀렸다\n"
    ">\n"
    "> 🔴🔴 **초판은 이 절을 「두 번」으로 적고 원인을 `P128` 분모 미확인으로 진단했다 — 둘 다 틀렸다.**\n"
    "> 실제 발생은 **5회**(팬아웃 2 · 검사기 분모 공백 3)이고, 결정적으로 **㉠ 직후 그 교훈을 프롬프트에\n"
    "> 적어 놓고도 build 후 재검증에서 같은 업무키 조인을 다시 써 6,547,453행 팬아웃을 만들었다**\n"
    "> ⇒ 「분모를 확인하라」는 처방은 **행동을 바꾸지 못했다**(체크리스트를 늘리는 처방의 한계).\n"
    "> 🟢 **재진단 = `WIDE_MEMBER_EVENT` 에 조인 가능한 유일키가 없는데도 매번 조인으로 대조하려 한 것**이\n"
    "> 원인이다 — base 인 FME 는 **PK 미선언**이고 `(DATE_SK,MEMBER_DK,EVENT_TYPE)` 비유일임이 SV COMMENT 에\n"
    "> 이미 적혀 있었다 ⇒ **어떤 업무키 조합으로도 1:1 조인이 성립하지 않는다.**\n"
    "> 🟢 **처방(행동 규칙)** = ㉮ **WIDE 는 조인 대상이 아니라 집계 비교 대상으로 다룬다**(행수·채움·분포를\n"
    "> 각각 재고 조인하지 않는다 — 실제로 이 방식으로 ㉤ 를 해결했다) ㉯ **등가 검증은 base 팩트에서** 한다\n"
    "> (`FACT_MEMBER_EVENT` ↔ `DIM_CAMPAIGN` 은 `CAMPAIGN_SK` 가 차원 PK 라 1:1 보장) ㉰ 조인을 쓸 때는\n"
    "> **결과 행수를 SELECT 안에서 함께 반환**해 기대 분모와 같은 화면에 보이게 한다.\n"
    "> ⇒ 정본 = `99_NEXT §0-KKK ▣EEE`(5건 표 + 처방).\n"
)

H_OLD_H2 = (
    "> 🔴 **두 건의 공통 뿌리 = 조인·추출 결과의 행수(분모)를 기대값과 먼저 대조하지 않은 것**이다.\n"
    "> 🟢 **교훈** = 팬아웃·누락은 불일치를 **만들어내거나 지운다** — 대조 전에 **분모 일치를 먼저 확인**한다.\n"
)
H_NEW_H2 = (
    "> ㉢ **`sv_rule7_scan` 초판**이 `COMMENT =` 만 보고 `AI_SQL_GENERATION` 지시문을 놓쳐 라이브 도달분을\n"
    ">   「문서 주석」으로 오분류했다. ㉣ **WIDE 전환 문안**에 「NULL 의 뜻이 바뀐다」를 미실측 단정으로 넣었다\n"
    ">   (실측 반증 후 3표면 정정). ㉤ **build 후 재검증에서 팬아웃 2회차**(위 재진단 참조).\n"
    "> 🔴 부수로 **정규식 분모 공백** 1건 더 — `[A-Za-z_]+` 가 숫자 포함 컬럼명(`CMPGN_TYPE1/TYPE2_NM_AT_EVENT`)을\n"
    ">   못 잡아 소스 검증을 `9/11` 로 과소 보고했다(라인 추출로 정정) ⇒ **검사기 분모 공백 누계 3회**.\n"
    "> 🟢 **전건 보고 전 자기적발**했고 ㉡ 는 재사용 게이트로 승격했다.\n"
)


def patch(path, pairs, label):
    raw = open(path, encoding="utf-8").read()
    for old, _ in pairs:
        n = raw.count(old)
        assert n == 1, f"{label}: 대상 문안이 {n}건(1이어야 한다) — 중단\n  {old[:70]!r}"
    snap = f"_archive/{path.split('/')[-1]}.O105-final"
    shutil.copyfile(path, snap)
    out = raw
    for old, new in pairs:
        out = out.replace(old, new)
    open(path, "w", encoding="utf-8").write(out)
    over = [i + 1 for i, s in enumerate(out.split("\n")) if len(s) > 2000]
    for old, _ in pairs:
        assert old not in out, f"{label}: 구 문안 잔존 — 중단"
    print(f"{label}: 치환 {len(pairs)}건 · {len(raw.encode())} -> {len(out.encode())}B · "
          f"SHA {hashlib.sha256(out.encode()).hexdigest()[:12]} · 2000자초과 {over} · 스냅샷 {snap}")
    assert not over


def main() -> None:
    # ① 원장 행은 _o105_finalize_index_row2.py 로 전체 교체 처리했다(증분으로는 2000자 상한을 못 지켰다).
    patch(HIST, [(H_OLD_F, H_NEW_F), (H_OLD_H, H_NEW_H), (H_OLD_H2, H_NEW_H2)],
          f"② 이력 {HIST.split('/')[-1]} §O105")

    # 사후: 원장 행이 여전히 1개이고 상한 이내인지
    L = open(IDX, encoding="utf-8").read().split(chr(10))
    rows = [(i + 1, len(s)) for i, s in enumerate(L) if s.startswith("| 🆕 🟢 **`O105`")]
    print(f"\n원장 O105 행 = {rows} (1개 · 2000자 이내여야 통과)")
    assert len(rows) == 1 and rows[0][1] <= 2000


if __name__ == "__main__":
    main()
