#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""test_doc_census.py — `doc_census.scan_text` 의 **음성 테스트**.

[2026-08-28 O106 신설 · `R3-2` 의 집행]

🔴 왜 이 테스트가 필요한가 — 이 함수는 한 세션에 **두 번** 틀렸다
--------------------------------------------------------------------------
1. **재현율 결함**: 「같은 줄에 문서명 1개」만 봐서 실제 **17건 중 13건**만 잡았다(`P106`).
2. **정밀도 결함**: 분모를 넓히자 원장 §1 긴 행(최대 1,644자)에서 **오탐 2건**이 났다
   (*"원장 7조각 중 2개만 읽고 착수"* · *"`--rebalance` 7→8조각"* = **과거 기록**).

⇒ 두 축은 서로 밀어낸다. 한쪽만 테스트하면 다른 쪽이 조용히 깨진다
  ⇒ **두 축을 같은 테스트에 고정**한다.

실행
--------------------------------------------------------------------------
    python3 scripts/test_doc_census.py        # 전건 통과해야 exit 0
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import doc_census as C                                       # noqa: E402
from doc_census import scan_text                             # noqa: E402

FAILS = []
#: 🔴 [O112-B] 단정 수를 손으로 적지 않는다 — `check()` 가 센다(`R3-9 ㉦`).
COUNTS = {'checks': 0}
# 실측값(합성) — 이 값과 다른 기재가 stale 이다.
ACTUAL = {
    '00_INDEX_이슈원장': 8,
    '50_dbt_파이프라인_미결조치': 18,
    '01_세션이력': 35,
    '01_세션이력_조각': 35,
    '90_해소완료_로그': 3,
    '99_NEXT_SESSION': 13,
    '03_이슈상세': 2,
}
# 바이트 축(미분할 문서) · 분할여부 축
SIZES = {'40_입고대기_원천의존': 18784, '01_문서분할_규약': 21231, '00_BRIEF': 11213}
SPLIT = {'90_해소완료_로그': True, '01_세션이력': True,
         '40_입고대기_원천의존': False, '00_BRIEF': False}


def check(name, got, want):
    COUNTS['checks'] += 1
    if got == want:
        print('  ✅ %s' % name)
    else:
        print('  🔴 %s — got=%r want=%r' % (name, got, want))
        FAILS.append(name)


def docs(found):
    return sorted((f['doc'], f['written']) for f in found)


def axes(found):
    """축까지 포함한 비교용 — 바이트·미분할 축은 축 이름이 판정의 일부다."""
    return sorted((f['doc'], f['axis'], f['written']) for f in found)


# ── 재현율 축 ───────────────────────────────────────────────────────────
R1 = "| 00 | `00_INDEX_이슈원장.md` | `-001` ~ `-005` (5개 · **형제**) | 374줄 |"
R2 = "| `50_dbt_파이프라인_미결조치.md` | **갱신형** | 상태 전이 | 조각 13 · `--rebalance` |"
# 문서명과 수가 **다른 줄**(이월로 잡아야 한다)
R3 = ("2. `20_issue/50_dbt_파이프라인_미결조치.md` — 필수 정독.\n"
      "   🆕 **허브 + 조각 `-001`~`-012` 로 분할됐다**(재균형 후).")
# `01_세션이력` 과 `01_세션이력_조각` 동시 등장(모호 회피 = 근접 귀속)
R4 = "| `01_세션이력.md` | **append형** | append-only | 폴더 `01_세션이력_조각/` 31조각 |"

# ── 정밀도 축 ───────────────────────────────────────────────────────────
# 과거 기록 2형태 — stale 이 아니다
P1 = "| 🆕 🔴 **O91 자기검토** | ... `R1-1` 원장 **7조각 중 2개만** 읽고 착수 ... `90_해소완료_로그` |"
P2 = "| 🆕 🟢 **`DEC-40` 확정** | 사용자 승인 `--rebalance` 7→8조각으로 자리 확보 ... `90_해소완료_로그` |"
# 「분할 전」 고정 기록
P3 = "| 30 | `30_설계_의사결정.md` | 조각 | 분할 전 1,165줄 / 141,004B | 조각 7 |"
# 긴 행에서 무관한 문서에 귀속하지 않는다(수치 앞 80자에 문서명 없음)
P4 = ("| 🆕 정리 | " + "가" * 200 + " 조각 99개 " + "나" * 200 +
      " `90_해소완료_로그` 언급 |")
# 조각 문맥 토큰이 없으면 후보가 아니다
P5 = "| `90_해소완료_로그.md` | append형 | 닫힌 항목 3개 보존 | 미분할 |"
# 값이 맞으면 잡지 않는다
P6 = "| `99_NEXT_SESSION.md` | 갱신형 | 인수인계 | 조각 13 · `--rebalance` |"
# 🔴🔴 [O108] **이월 귀속 × 긴 행** — 이 가드가 없으면 stale 3건이 오탐된다.
#   실사고 = 원장 §1 에 문서명을 언급한 행을 넣자, **다음 행들(1,458~1,911자)의 무관한 수치**가
#   그 문서의 조각 수 기재로 오인됐다. 1행은 문서명을 언급하지만 조각 수 주장은 하지 않고,
#   2·3행은 문서명이 없는 **긴 행**이다 ⇒ 검출 0 이어야 한다.
P7 = ("| 🆕 착수 | 순서 = `03_이슈상세`(인용 0) → `00_INDEX`(마지막) |\n"
      "| 🆕 O107 | " + "서술 " * 80 + " 조각 14개 재구성 · " + "근거 " * 80 + " |\n"
      "| 🆕 O106 | " + "서술 " * 80 + " 조각 12개 무효 · " + "근거 " * 80 + " |")
# 🟢 대조군 — **짧은** 다음 줄에서는 이월 귀속이 살아 있어야 한다(P7 로 재현율을 죽이지 않았다는 증거)
P8 = ("2. `20_issue/03_이슈상세.md` — 참조.\n"
      "   허브 + 조각 `-001`~`-009` 로 분할됐다.")


def main():
    print('[음성 테스트] doc_census.scan_text')

    print(' 축1 재현율 — 4형태 전건 검출')
    check('범위+개수', docs(scan_text(R1, ACTUAL)), [('00_INDEX_이슈원장', 5)])
    check('조각N·', docs(scan_text(R2, ACTUAL)), [('50_dbt_파이프라인_미결조치', 13)])
    check('다른 줄 이월', docs(scan_text(R3, ACTUAL)),
          [('50_dbt_파이프라인_미결조치', 12)])
    check('폴더N조각(모호 해소)', docs(scan_text(R4, ACTUAL)),
          [('01_세션이력_조각', 31)])

    print(' 축2 정밀도 — 오탐 0')
    check('과거기록 N조각 중', scan_text(P1, ACTUAL), [])
    check('과거기록 N→M조각', scan_text(P2, ACTUAL), [])
    check('분할 전 고정기록', scan_text(P3, ACTUAL), [])
    check('긴 행 원거리 귀속 금지', scan_text(P4, ACTUAL), [])
    check('조각 문맥 없음', scan_text(P5, ACTUAL), [])
    check('값 일치 시 무검출', scan_text(P6, ACTUAL), [])
    check('이월 귀속 × 긴 행 금지', scan_text(P7, ACTUAL), [])
    check('이월 귀속(짧은 줄)은 유지', docs(scan_text(P8, ACTUAL)),
          [('03_이슈상세', 9)])

    print(' 축3 경계 — 빈 입력·미등재 문서')
    check('빈 입력', scan_text('', ACTUAL), [])
    check('미등재 문서명', scan_text('| `77_없는문서.md` | 조각 9 |', ACTUAL), [])

    # ── 축4 바이트 · 축5 미분할표기 (O106 종료 점검에서 3건이 새로 나왔다) ──
    print(' 축4 바이트 — 표 첫 셀 귀속 · 목표치 제외')
    B1 = "| `40_입고대기_원천의존.md` | **갱신형** | 하드블로커 해소 시 상태가 바뀐다 | 미분할(12,684B) · 상한 이내 |"
    check('바이트 stale 검출', axes(scan_text(B1, ACTUAL, sizes=SIZES)),
          [('40_입고대기_원천의존', '바이트', 12684)])
    B2 = "| `01_문서분할_규약.md` | 갱신형 | 도구 스펙 | 미분할(21,231B) · 상한 이내 |"
    check('값 일치 시 무검출', scan_text(B2, ACTUAL, sizes=SIZES), [])
    B3 = "| `00_BRIEF.md` | 갱신형 | 진입점 | 미분할 · 목표 ≤32,768B(축3 여유 20%) |"
    check('목표치는 주장이 아니다', scan_text(B3, ACTUAL, sizes=SIZES), [])
    B4 = "| `00_guides/00_작업지침.md` | 갱신형 | 426줄/45,116B → 256줄/24,743B 였다 | 미분할 |"
    check('변화 서술(과거)은 제외', scan_text(B4, ACTUAL, sizes=SIZES), [])
    # 🔴 등재표 행은 문서명과 수치가 80자 넘게 떨어진다 ⇒ 첫 셀 귀속이어야 한다
    B5 = ("| `01_문서분할_규약.md` | **갱신형** | " + "근거서술 " * 20 +
          " | 미분할(17,131B) · 상한 이내 |")
    check('긴 행도 첫 셀로 귀속', axes(scan_text(B5, ACTUAL, sizes=SIZES)),
          [('01_문서분할_규약', '바이트', 17131)])

    print(' 축5 미분할 표기 — 분할된 문서에 「미분할」은 stale')
    U1 = "| `90_해소완료_로그.md` | **append형** | 닫힌 항목 보존 | 미분할(상한 이내) · 초과 시 폴더 분할 |"
    check('미분할 오기 검출', axes(scan_text(U1, ACTUAL, split=SPLIT)),
          [('90_해소완료_로그', '미분할표기', 0)])
    U2 = "| `40_입고대기_원천의존.md` | 갱신형 | 상태 전이 | 미분할 · 상한 이내 |"
    check('진짜 미분할은 무검출', scan_text(U2, ACTUAL, split=SPLIT), [])
    U3 = "| 01 · 00 · 02 | ~~미분할~~ | ~~—~~ | ✅ 이 행은 대체됐다 |"
    check('취소선 미분할은 과거 기록', scan_text(U3, ACTUAL, split=SPLIT), [])
    U4 = ("| `00_guides/01_문서분할_규약.md` | 갱신형 | " + "서술 " * 30 + " | 미분할 |")
    check('미분할 carry 오염 금지', scan_text(U4, ACTUAL, split=SPLIT), [])

    print(' 축6 분할 분모 대조 — 분할 문서를 「미분할」로 취급하는 도구를 잡는가 (O112-B 신설)')
    # 🔴 왜 음성 테스트인가: 이 검사는 **현재 상태가 정상이면 언제나 0건**이라
    #   「잡는다」를 정상 입력으로는 증명할 수 없다(그것이 O112 가 겪은 침묵의 구조다).
    #   ⇒ 분모를 **일부러 오염**시켜 검출을 확인하고, 되돌려 오탐 0 을 확인한다.
    import fix_stale_counts as FS
    import doc_line_length_gate as LL

    base = C.split_denominator_check()
    check('현행 위반 0건', base, [])

    hub = C.FAMILIES[0][0]                       # 실재하는 분할 허브 1개
    FS.FLAT_SOURCES.append(hub)                  # ㉡ 오염: 분할 문서를 미분할로 선언
    got = C.split_denominator_check()
    check('FLAT 오분류 검출', any('FLAT_SOURCES' in g for g in got), True)
    FS.FLAT_SOURCES.remove(hub)
    check('오염 복구 후 0건', C.split_denominator_check(), [])

    saved = list(LL.CANON_GLOB)
    LL.CANON_GLOB[:] = ['scripts/*.py']          # ㉠ 오염: 조각을 줄길이 분모에서 제거
    got = C.split_denominator_check()
    check('줄길이 분모 누락 검출', any('분모 밖' in g for g in got), True)
    check('누락은 분할문서 전건에 보고', len([g for g in got if '분모 밖' in g]),
          len(C.FAMILIES))
    LL.CANON_GLOB[:] = saved
    check('복구 후 0건(오탐 방지)', C.split_denominator_check(), [])

    print('')
    if FAILS:
        print('🔴 실패 %d건: %s' % (len(FAILS), ', '.join(FAILS)))
        return 1
    print('✅ 전건 통과 — %d개 단정(축 = 재현율·정밀도·경계·바이트·미분할·분할분모)'
          % COUNTS['checks'])
    return 0


if __name__ == '__main__':
    sys.exit(main())
