# -*- coding: utf-8 -*-
"""정본 문서의 **절 제목 집합 감소**를 검출하는 게이트 (2026-08-13 O68 신설).

🔴🔴 왜 필요한가 — 같은 사고가 **5회** 났다(O67-B A7 · 문서50 §O67-B):
  O63-J ① · O64 ㉠ · O67(문서50 §O65) · O67-B(`99_NEXT_SESSION.md` §0-A-3) ·
  O67-B(문서50 §O65 **재차**). 4회째는 「3회째」라 보고한 직후에, 5회째는 **4회째를 문서에
  적는 편집에서** 났다 ⇒ **주의로는 끊기지 않는다**는 것이 실증됐다.
  🟢 근본 원인도 O67-B 가 특정했다: 절을 삽입할 때 **다음 절의 제목을 `old_string` 의 꼬리로
  잡고** `new_string` 에서 그 제목을 빠뜨린다. 본문은 남고 **제목 줄만** 사라지므로
  길이·바이트·스테이지 검사에 걸리지 않는다 — 어느 게이트의 축에도 없던 영역이다(O63-J 총평).
  ⇒ 처방 ㉠ = 앵커에 다음 절 제목을 넣지 않는다(구분선 `---` 까지만 잡는다) · **㉡ = 이 게이트**.

판정
  · 골든에 있던 제목이 **사라지면 FAIL**(감소 = 유실 신호).
  · 새 제목이 늘어나는 것은 정상이다(절 신설) ⇒ 보고만 하고 통과시킨다.
  · 제목 **개수**가 아니라 **집합**을 본다 — 개수 보존 교환(제목 1개 삭제 + 1개 신설)을
    통과시키면 안 된다(`test_generators` O48-B 의 「개수 보존 앵커 교환」과 같은 함정).
  · 의도적 삭제·개명은 `--update-golden` 으로 반영한다. 🔴 갱신 전에 **왜 사라졌는지**를
    규명한다 — 규명 없이 갱신하면 유실을 기준선에 굳힌다(`P214`).

사용
  python3 scripts/doc_heading_gate.py                  # 판정(감소 시 exit 1)
  python3 scripts/doc_heading_gate.py --update-golden  # 기준선 갱신
  python3 scripts/doc_heading_gate.py --self-check     # 검출력 자기검사(P106)
"""
import datetime as _dt
import json
import re
import sys
from pathlib import Path

ROOT = Path('/workspace')
GOLDEN = ROOT / 'scripts' / 'golden' / 'doc_headings.json'

# 정본 문서만 담는다(`R1-3-6`). 🔴 `01_세션이력.md` 는 append-only 이력이라 정본이 아니지만
#   **제목 유실은 이력에서도 사고**이므로 포함한다 — 이 게이트는 독해 의무가 아니라 구조 보존을 본다.
DOCS = [
    '00_guides/00_작업지침_세션운영규칙.md',
    '20_issue/00_INDEX_이슈원장.md',
    '20_issue/01_세션이력.md',
    '20_issue/02_상태상세_대시보드_갱신형.md',
    '20_issue/03_이슈상세.md',
    '20_issue/10_진단_원인분석.md',
    '20_issue/20_현업확인_요청.md',
    '20_issue/30_설계_의사결정.md',
    '20_issue/31_코드군_매핑등재부.md',
    '20_issue/40_입고대기_원천의존.md',
    '20_issue/50_dbt_파이프라인_미결조치.md',
    '20_issue/90_해소완료_로그.md',
    '99_NEXT_SESSION.md',
]

# `#`~`####` 만 본다. 🔴 인용 접두(`> #### [2026-08-13 O67]`)도 잡는다 — 이력 항목이 그 형태다.
HEAD = re.compile(r'^(?:>\s*)?(#{1,4})\s+(.*?)\s*$')


def headings(text):
    """제목 집합을 돌려준다. 값 = `레벨|제목문자열`(공백 정규화)."""
    out = []
    for ln in text.splitlines():
        m = HEAD.match(ln)
        if m:
            out.append(f'{len(m.group(1))}|{" ".join(m.group(2).split())}')
    return out


def collect():
    cur = {}
    for d in DOCS:
        p = ROOT / d
        if not p.exists():
            cur[d] = None          # 파일 부재도 사고다 — 아래 판정에서 FAIL 로 다룬다
            continue
        cur[d] = headings(p.read_text(encoding='utf-8'))
    return cur


def judge(cur, golden):
    """(fail 목록, 신설 목록) 을 돌려준다."""
    fails, added = [], []
    for d, base in golden.items():
        now = cur.get(d)
        if now is None:
            fails.append(f'{d}: 파일이 없다(골든에는 제목 {len(base)}개)')
            continue
        lost = [h for h in base if h not in now]
        if lost:
            for h in lost[:8]:
                fails.append(f'{d}: 제목 유실 ▸ {h}')
            if len(lost) > 8:
                fails.append(f'{d}: … 외 {len(lost) - 8}건 유실')
        new = [h for h in now if h not in base]
        if new:
            added.append(f'{d}: 신설 {len(new)}개 (예: {new[0][:70]})')
    for d, now in cur.items():
        if d not in golden and now is not None:
            added.append(f'{d}: 골든 미등재 문서 — 제목 {len(now)}개')
    return fails, added


def main(argv):
    cur = collect()
    if '--update-golden' in argv:
        # 🔴 [2026-08-13 O68-B] **갱신 사유를 파일에 남긴다.** O68 이 이 골든을 3회 갱신했고
        #   매번 「의도한 개명」이라 규명했지만 **그 규명이 어디에도 남지 않아** 다음 사람이
        #   「자기 편집을 자기가 승인」한 것과 「유실을 굳힌 것」을 구별할 수 없었다(O68-B C2).
        #   ⇒ `--reason` 을 필수로 하고 유실 목록과 함께 `_updates` 에 누적한다. `P214` 의 절차화다.
        reason = argv[argv.index('--reason') + 1] if '--reason' in argv else None
        prev = json.loads(GOLDEN.read_text(encoding='utf-8')) if GOLDEN.exists() else {}
        base = prev.get('docs', {})
        lost = {d: [h for h in b if h not in (cur.get(d) or [])] for d, b in base.items()}
        lost = {d: v for d, v in lost.items() if v}
        if base and lost and not reason:
            print('🔴 제목이 감소하는 갱신은 `--reason "<사유>"` 없이 할 수 없다 (O68-B C2):')
            for d, v in lost.items():
                for h in v[:5]:
                    print(f'   - {d} ▸ {h}')
            return 1
        hist = list(prev.get('_updates', []))
        if reason:
            hist.append({'at': _dt.datetime.now().isoformat(timespec='seconds'),
                         'reason': reason,
                         'lost': {d: v for d, v in lost.items()},
                         'total_before': sum(len(v) for v in base.values() if v),
                         'total_after': sum(len(v) for v in cur.values() if v)})
        GOLDEN.parent.mkdir(parents=True, exist_ok=True)
        GOLDEN.write_text(
            json.dumps({'_doc': '정본 문서 절 제목 집합 기준선 — O68 신설. '
                                '감소 시 FAIL. 감소를 포함한 갱신은 --reason 필수(O68-B C2).',
                        '_updates': hist, 'docs': cur}, ensure_ascii=False, indent=1) + '\n',
            encoding='utf-8')
        tot = sum(len(v) for v in cur.values() if v)
        print(f'✅ 골든 갱신 — 문서 {len([v for v in cur.values() if v is not None])}종 · 제목 {tot}개 · '
              f'유실 승인 {sum(len(v) for v in lost.values())}건 · 이력 {len(hist)}회 → {GOLDEN}')
        return 0

    if not GOLDEN.exists():
        print(f'🔴 골든이 없다 — 먼저 `--update-golden` 을 실행할 것: {GOLDEN}')
        return 1
    golden = json.loads(GOLDEN.read_text(encoding='utf-8'))['docs']
    fails, added = judge(cur, golden)
    tot = sum(len(v) for v in cur.values() if v)
    print(f'[문서 제목 게이트] 문서 {len(DOCS)}종 · 현재 제목 {tot}개 · 골든 '
          f'{sum(len(v) for v in golden.values() if v)}개')
    for a in added:
        print(f'  ⚪ {a}')
    for f in fails:
        print(f'  🔴 {f}')
    print('\n' + ('🔴 게이트 실패 — 제목 집합이 감소했다(절 삽입 시 다음 절 제목을 삼킨 사고 · O67-B A7)'
                  if fails else '✅ 게이트 통과 — 제목 유실 0'))
    return 1 if fails else 0


def self_check():
    """검출력 자기검사(`P106`) — **온전한 사본에서 통과함을 먼저 확인**한 뒤 일부러 깨뜨린다."""
    cur = collect()
    golden = {d: list(v) for d, v in cur.items() if v is not None}
    cases = []

    f0, _ = judge(cur, golden)
    cases.append(('ⓞ 온전한 사본은 통과한다(음성 샘플)', not f0))

    # ⓐ 제목 1개 삭제 → 검출되어야 한다
    d = '20_issue/50_dbt_파이프라인_미결조치.md'
    broken = {k: (list(v) if v else v) for k, v in cur.items()}
    removed = broken[d].pop(3)
    fa, _ = judge(broken, golden)
    cases.append((f'ⓐ 제목 삭제 검출 ▸ {removed[:50]}', bool(fa)))

    # ⓑ **개수 보존 교환**(1개 삭제 + 1개 신설) → 개수만 보면 통과한다. 집합 판정이라 검출되어야 한다
    broken2 = {k: (list(v) if v else v) for k, v in cur.items()}
    broken2[d][5] = '2|### O68 위조 제목'
    fb, _ = judge(broken2, golden)
    cases.append(('ⓑ 개수 보존 교환 검출(집합 판정)', bool(fb)))

    # ⓒ 파일 부재 검출
    broken3 = {k: (list(v) if v else v) for k, v in cur.items()}
    broken3['99_NEXT_SESSION.md'] = None
    fc, _ = judge(broken3, golden)
    cases.append(('ⓒ 문서 부재 검출', bool(fc)))

    # ⓓ 제목 신설은 **통과**해야 한다(절 신설은 정상)
    grown = {k: (list(v) if v else v) for k, v in cur.items()}
    grown[d].append('2|## 🟢 O99 — 신설 절')
    fd, ad = judge(grown, golden)
    cases.append(('ⓓ 제목 신설은 통과(오탐 0)', not fd and bool(ad)))

    bad = [n for n, ok in cases if not ok]
    print(f'[doc_heading_gate 자기검사] {len(cases)}건')
    for n, ok in cases:
        print(f'  {"✅" if ok else "🔴"} {n}')
    print('\n' + (f'🔴 자기검사 실패 — {len(bad)}건' if bad
                  else f'✅ 자기검사 통과 — {len(cases)}/{len(cases)}'))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(self_check() if '--self-check' in sys.argv else main(sys.argv[1:]))
