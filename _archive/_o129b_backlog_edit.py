#!/usr/bin/env python3
"""O129-B: 착수표(99_NEXT_SESSION-020) 용량 회복 + 착수 항목 4건 등재.

🔴 왜 스크립트인가 = 대상 표 행이 2,000 B 를 넘어 `edit` 앵커로 다루면 행이 쪼개진다
   (`R1-7-8` · O127-B 실사고). ⇒ 줄 인덱스 지정 치환으로 한다.
🔴 압축은 닫힌 행(`~~㉜~~`)만 · 행 키·열 수 보존(`R1-7-4`) ·
   원문 목적지 실재는 `R2-8-1` 토큰 대조로 선확인했다(40,262,076 / 3,003 단정 / PASS 40 → 부재 0).
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(ROOT, '99_NEXT_SESSION_조각', '99_NEXT_SESSION-020.md')

COMPRESS_LINE = 125          # 1-indexed
COMPRESS_MUST_START = '| ~~㉜~~ |'
COMPRESSED = (
    '| ~~㉜~~ | ✅ **[2026-08-31 O125-C 완료] dbt schema yml 미등재 7모델 등재** — 커버리지 **7 → 0** '
    '| — | 🟢 **[O129-B 용량 압축]** 장문 셀을 포인터로 대체했다(닫힌 행 · 행 키·열 수 보존 · `R1-7-4`). '
    '원문 = **원장 §1 `O125-C` 행 · 이력 §O125-C** — 삭제가 아니라 포인터화이며 목적지 실재를 '
    '`R2-8-1` 토큰 대조로 확인했다(부재 0) |'
)

LAST_ROW_MUST_START = '| **㊳** |'

NEW_ROWS = [
    '| **㊶** | 🔴 **[2026-09-01 O129-B 신규] 영구 NULL 컬럼 COMMENT 사유 기재 — 등재표 ❌ 행** '
    '| 🔴 사유 미확보분 **창작 금지**(`R2-7-1`) · 라이브 `ALTER … COMMENT` '
    '| 🟢 컬럼명 정본 = 문서30 **§7-C 등재표**(재는 방법 포함) · 처방 = **§7-C-2**. '
    '🔴 **드랍이 아니라 사유 기재가 선행**이다. 🟢 `DIM_AD_CREATIVE` 3컬럼은 O129-B 가 이행 완료 |',

    '| **㊷** | 🔴 **[2026-09-01 O129-B 신규] §7-B A군 드랍 미집행 2건** — '
    '`FACT_BUDGET.PLAN_BUDGET_YEAR`(`DEC42`) · `FACT_EVENT_PARTICIPATION.INCREASE_FLAG` '
    '| 🔴 **둘 다 WIDE 뷰에 노출** ⇒ 순서 = 파일 → 뷰 재생성(dbt · `R4-1`) → base DROP '
    '| 🔴 판정은 O96 이 닫았고 **집행이 열려 있다**(라이브 실재 확인). '
    '⚠️ O129-B 의 `RT_TYPE` 집행은 **소비처 0** 이어서 뷰 재생성이 불요했다 — 이 2건은 다르다 |',

    '| **㊸** | 🟠 **[2026-09-01 O129-B 신규] 초수(요건 `#22`) SV 노출 판정** '
    '| 🟠 커버리지 판단 = `P18` DoD ③ '
    '| 🟢 **O29 결함 2축(무성 소실·단위 오류)은 해소됐다** ⇒ 잔여는 결함이 아니라 **커버리지**다'
    '(숫자표기분 µs 해석 미확정 = O29 잔여 ②). 정본 소재지 = `FACT_AD_BROADCAST.DURATION_SEC` · '
    '판정처 = `30_마케팅_AGENT_설계.md` 초수 행 |',

    '| **㊹** | 🟠 **[2026-09-01 O129-B 신규] `FMM` degen 6컬럼 grain 판정**(신설 **G군**) '
    '| 🔴 grain 판정 전 **드랍·채움 둘 다 금지** '
    '| 🟢 근거 = 문서30 **§7-C 등재표 머리말**(G군 신설). 대체처(`FME.DVLP_DIV_CD`·`JOIN_DATE`·`STOP_DATE`)는 '
    '**도달 가능**하나 `FMM`(회원×월) ↔ `FME`(사건) grain 이 다르다 ⇒ A군으로 처리하면 '
    '`PLAN_BUDGET_YEAR` 형 **12배 과대** 위험 |',
]


def main():
    with open(TARGET, encoding='utf-8') as fh:
        lines = fh.read().split('\n')

    before_bytes = os.path.getsize(TARGET)

    idx = COMPRESS_LINE - 1
    if not lines[idx].startswith(COMPRESS_MUST_START):
        print('🔴 중단 — %d행이 %r 로 시작하지 않는다: %r'
              % (COMPRESS_LINE, COMPRESS_MUST_START, lines[idx][:60]))
        return 1
    old_cells = lines[idx].count('|')
    lines[idx] = COMPRESSED
    if lines[idx].count('|') != old_cells:
        print('🔴 중단 — 열 구분자 수가 바뀐다 (%d → %d)'
              % (old_cells, lines[idx].count('|')))
        return 1

    # 마지막 표 행 뒤에 신규 행을 덧붙인다
    last = None
    for i, ln in enumerate(lines):
        if ln.startswith(LAST_ROW_MUST_START):
            last = i
    if last is None:
        print('🔴 중단 — 마지막 표 행(%s)을 찾지 못했다' % LAST_ROW_MUST_START)
        return 1
    for r in NEW_ROWS:
        if r.count('|') != old_cells:
            print('🔴 중단 — 신규 행 열 수 불일치: %r' % r[:50])
            return 1
    lines[last + 1:last + 1] = NEW_ROWS

    with open(TARGET, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(lines))

    after_bytes = os.path.getsize(TARGET)
    print('🟢 압축 1행 + 등재 %d행' % len(NEW_ROWS))
    print('   바이트 %d → %d (변화 %+d · 상한 40960 · 여유 %d)'
          % (before_bytes, after_bytes, after_bytes - before_bytes,
             40960 - after_bytes))
    if after_bytes > 40960:
        print('🔴 상한 초과 — 되돌려야 한다')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
