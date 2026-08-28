#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_measure_backlog.py — **라이브 실측이 필요한 항목**을 정본에서 추출해 문서로 낸다.

[2026-08-28 O106 신설 · `R2-8-4-c` 의 집행 장치]

🔴 왜 필요한가
--------------------------------------------------------------------------
이 워크스페이스는 **계정이 반복해 바뀐다**(`P169` — 실측된 계보:
`ls82944` → `os09358` → `DV07626` → `UA93987` → `NX55103` → `ZL50263` → …).
계정이 바뀌면 DB·SV·Agent 는 **전부 사라지는데 문서의 「완료」 판정은 그대로 남는다.**
`R2-8-4` 가 그래서 *"은퇴는 「그때 됐다」가 아니라 「지금도 있다」여야 한다"* 를 규정하고,
`R2-8-4-c` 는 *"라이브 대조가 불가한 상황에서는 판정을 보류하고 **수치를 창작하지 않는다**"*
라고 처방한다.

🔴 그런데 처방만 있고 **「보류된 것들의 목록」이 없었다.**
   ⇒ 문서작업 전용 계정에서 세션을 돌리면 보류 항목이 **문서 곳곳에 흩어진 채** 잊힌다.
   이 도구가 그것을 **한 곳에 모아** 데이터 계정 세션이 집어 갈 수 있게 한다.

🟢 손으로 쓰지 않는 이유
--------------------------------------------------------------------------
손으로 적은 목록은 이 워크스페이스에서 **17건이 stale 이 된 전례**가 있다
(`doc_census.py` docstring). ⇒ 목록도 **생성물**로 만든다.

🔴 이 도구는 DB 에 접속하지 않는다.
   「무엇을 재야 하는가」만 뽑는다. 재는 것은 데이터 계정 세션의 몫이다.

사용
--------------------------------------------------------------------------
    python3 scripts/gen_measure_backlog.py           # stdout 미리보기
    python3 scripts/gen_measure_backlog.py --write   # 20_issue/92_… 생성
"""

import argparse
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, '20_issue', '92_실측필요_후속작업.md')

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from session_brief import (family_lines, rows_of_table, strip_md, clip,   # noqa
                          open_sections, STRIKE)

# ── 라이브 실측 신호 ────────────────────────────────────────────────────
#   🔴 신호는 **문서에 이미 적혀 있는 표현**에서 뽑는다(창작 금지).
#     각 신호마다 「무엇을 재야 하는가」가 다르므로 분류를 함께 붙인다.
SIGNALS = [
    ('배포/객체 실재', re.compile(
        r'SHOW\s+(AGENTS|SEMANTIC|VIEWS|TABLES)|DESCRIBE\s+(SEMANTIC|TABLE)'
        r'|INFORMATION_SCHEMA|라이브\s*스펙|라이브\s*실측|라이브\s*대조'
        r'|라이브\s*재조회|배포\s*완료|VERSION\$')),
    ('적재 후에만 판정', re.compile(
        r'적재\s*후에만|적재\s*후\s*판정|입고\s*후|데이터\s*미입고|미적재')),
    ('dbt 실행 필요', re.compile(
        r'dbt\s+(build|run|compile|parse|test)|EXECUTE\s+DBT')),
    ('행수·비율 재측정', re.compile(
        r'재측정|재실측|팬아웃|행수\s*대조|기준선\s*대조|커버리지\s*\d')),
    ('사람 검증(UI)', re.compile(r'NL\s*스모크|CoWork\s*UI|사람이\s')),
]

# 🔴 이 문구가 있으면 **이미 닫힌 것**이라 실측 백로그가 아니다.
CLOSED = ('✅', '🟢 종결', '재착수 금지', '은퇴 이관')


def classify(text):
    return [name for name, rx in SIGNALS if rx.search(text)]


def scan_tasks():
    """착수표 열린 행 중 라이브 실측이 걸린 것."""
    lines = family_lines('99_NEXT_SESSION.md')
    out = []
    for rel, ln, cells in rows_of_table(lines, ('순',)):
        if len(cells) < 4 or STRIKE.match(cells[0]):
            continue
        if '✅' in cells[1][:8]:
            continue
        joined = ' '.join(cells)
        kinds = classify(joined)
        if not kinds:
            continue
        out.append({
            'src': '착수표',
            'key': strip_md(cells[0]),
            'what': clip(strip_md(cells[1]), 120),
            'stop': clip(strip_md(cells[2]), 34),
            'kinds': kinds,
            'where': '%s:%d' % (rel, ln),
        })
    return out


def scan_sections(hub_rel, label):
    """열린 절 중 라이브 실측이 걸린 것 — 절 본문까지 본다."""
    lines = family_lines(hub_rel)
    secs = open_sections(hub_rel, lines)
    locs = {s['where']: s['title'] for s in secs}
    out, cur, buf = [], None, []

    def flush():
        if not cur:
            return
        body = '\n'.join(buf)
        if any(c in body[:400] for c in CLOSED[1:]):
            return
        kinds = classify(cur[1] + ' ' + body)
        if kinds:
            out.append({'src': label, 'key': '—',
                        'what': clip(cur[1], 120), 'stop': '—',
                        'kinds': kinds, 'where': cur[0]})

    for rel, ln, line in lines:
        loc = '%s:%d' % (rel, ln)
        if line.startswith('## '):
            flush()
            cur = (loc, locs[loc]) if loc in locs else None
            buf = []
            continue
        if cur:
            buf.append(line)
    flush()
    return out


HEADER = """<!-- LLM-METADATA
doc_id: MEASURE_BACKLOG
doc_role: 라이브 실측이 필요한 항목 목록 — 문서작업 계정에서 판정 보류된 것들의 집합
project: GN_DW (굿네이버스)
created: 2026-08-28
created_by: O106
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

# 92_실측필요_후속작업 (자동 생성)

> 🔴🔴 **이 파일은 자동 생성물이다 — 여기에 내용을 쓰지 마라.**
> `python3 scripts/gen_measure_backlog.py --write` 가 **통째로 다시 쓴다**
> ⇒ 손으로 적은 문장은 **조용히 사라진다**. 내용은 정본에 쓰고 이 파일을 재생성한다.

> 🔴 **이 문서의 용도** — 이 워크스페이스는 **문서작업 전용 계정**에서도 돌아간다.
> 그런 세션은 `R2-8-4-c` 에 따라 **라이브 판정을 보류하고 수치를 창작하지 않는다.**
> 보류된 항목이 문서 곳곳에 흩어지면 잊히므로 여기에 모은다.
> ⇒ **데이터가 있는 계정의 세션이 이 목록을 집어 간다.**

> 🔴 **여기 실린 것은 「무엇을 재야 하는가」이고 「측정값」이 아니다.**
> 측정값을 이 파일에 적지 마라 — 정본(원장 §1 · 문서10 · 문서50)에 적고 이 파일을 재생성한다.

## 0. 계정은 「작업 기준점」이다 — 판정의 근거가 아니다

> 🆕 **[2026-08-28 O106 사용자 결정]** 이 워크스페이스의 계정은 **앞으로도 계속 바뀐다.**
> ⇒ 🔴 **계정 식별자를 문서에 적을 의무가 없고, 적더라도 판정의 중요한 근거로 쓰지 않는다.**
> · 적힌 계정과 현재 계정이 **같다는 것이 객체 실재를 증명하지 않는다**(그 사이 DROP 될 수 있다).
> · **다르다는 것이 부재를 증명하지도 않는다**(이관으로 객체가 함께 옮겨졌을 수 있다).
> ⇒ 🟢 **근거는 조회 결과뿐이고 계정명은 맥락(작업 기준점)이다**(지침 `R3-9 ㉤`).

> 그래서 아래 항목을 재기 전에 하는 일은 **계정명 대조가 아니라 객체 조회**다.
> 계정을 확인하는 이유는 「어디서 재고 있는지」를 세션 안에서 붙잡아 두기 위한 것뿐이다.

```sql
-- 기준점 확인용(판정 근거로 인용하지 않는다)
SELECT CURRENT_ACCOUNT(), CURRENT_REGION(), CURRENT_ROLE(), CURRENT_WAREHOUSE();
```

> 🔴 **구 계정 수치를 인용하지 마라**(`R2-8-4`). 특히 GA4 「285,676,588행 / 911테이블」은
> 구 계정 원천 실측이고 이후 판본은 **3개월 샘플**이다 — 대조하면 반드시 틀린 판정이 나온다.
> 🟢 이것은 계정명 때문이 아니라 **측정 스코프가 달라서**다. 판정 축은 언제나 **분모 정의**다.

"""

FOOTER = """
---

## 재생성

```
python3 scripts/gen_measure_backlog.py --write
```

> 🟢 항목이 닫히면 **정본에서 상태를 바꾸고**(취소선 또는 🟢/✅) 이 파일을 재생성한다.
> 🔴 이 파일에서 직접 지우지 마라 — 다음 생성에서 되살아난다.

_Co-authored with CoCo_
"""


def build():
    items = []
    items += scan_tasks()
    items += scan_sections('20_issue/50_dbt_파이프라인_미결조치.md', '문서50')
    items += scan_sections('20_issue/40_입고대기_원천의존.md', '문서40')

    L = [HEADER]
    a = L.append
    by = {}
    for it in items:
        for k in it['kinds']:
            by.setdefault(k, []).append(it)

    a('## 1. 분류별 요약 (실측)')
    a('')
    a('| 분류 | 건수 | 데이터 계정에서 무엇을 하는가 |')
    a('|---|---|---|')
    HOW = {
        '배포/객체 실재': '`SHOW`/`DESCRIBE`/`INFORMATION_SCHEMA` 로 객체 실재를 대조한다(`P33`)',
        '적재 후에만 판정': 'BRONZE 적재를 확인한 뒤에만 판정한다 — 미적재 상태의 0 은 근거가 아니다',
        'dbt 실행 필요': '🔴 **에이전트가 실행하지 않는다**(`R4-1`) — 명령을 제시하고 사용자가 실행',
        '행수·비율 재측정': '기준선과 대조한다. 🔴 계정이 바뀌었으면 기준선도 무효다',
        '사람 검증(UI)': '🔴 **사람만 할 수 있다** — CoWork UI 에서 수동 확인',
    }
    for k in HOW:
        if k in by:
            a('| **%s** | %d | %s |' % (k, len(by[k]), HOW[k]))
    a('')
    a('> 총 **%d항목**(분류 중복 포함 %d) · 정본 좌표를 함께 실었다.'
      % (len(items), sum(len(v) for v in by.values())))
    a('')

    a('## 2. 항목 전건 (정본 좌표 포함)')
    a('')
    a('| 출처 | 키 | 무엇을 재야 하는가 | 분류 | 정지점 | 정본 좌표 |')
    a('|---|---|---|---|---|---|')
    for it in items:
        a('| %s | %s | %s | %s | %s | `%s` |' % (
            it['src'], it['key'], it['what'], ' · '.join(it['kinds']),
            it['stop'], it['where']))
    a('')

    a('## 3. 이 계정(문서작업용)에서 하지 말 것')
    a('')
    a('| 금지 | 이유 |')
    a('|---|---|')
    a('| 라이브 객체 수를 **추정해 적기** | `R2-8-4-c` — 수치 창작 금지. 「재측정 대기」로 표기한다 |')
    a('| 과거 세션 수치를 **현재값으로 인용** | `R2-8-4` · `C8` — 계정이 바뀌면 객체는 사라지고 판정만 남는다 |')
    a('| 「배포 완료」 판정을 **`90` 으로 은퇴** | `R2-8-4-b` — 라이브 대조 없이 닫지 마라 |')
    a('| `dbt build`/`run`/`compile`/`parse` 실행 | `R4-1` — 사용자가 직접 실행한다 |')
    a('| 은퇴 로그(`90`)를 근거로 **「라이브에 있다」** | `R2-8-4-d` — `90` 은 닫힌 항목 보존소다 |')
    a(FOOTER)
    return '\n'.join(L), len(items)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--write', action='store_true')
    a = ap.parse_args()
    text, n = build()
    if not a.write:
        print(text)
        print('── %d항목 · %s B' % (n, format(len(text.encode()), ',')))
        return 0
    with io.open(OUT, 'w', encoding='utf-8', newline='') as fh:
        fh.write(text)
    print('🟢 %s 생성 — %d항목 · %s B'
          % (os.path.relpath(OUT, ROOT), n, format(len(text.encode()), ',')))
    return 0


if __name__ == '__main__':
    sys.exit(main())
