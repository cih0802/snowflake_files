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
    '00_guides/01_문서분할_규약.md',   # [O83-E] R1-6 무변경 이관 신설
    '00_guides/02_파일쓰기_안전규약.md',   # [O85] R1-7 무변경 이관 신설
    '20_issue/00_INDEX_이슈원장.md',
    '20_issue/00_BRIEF.md',       # [O106] 세션 착수 브리핑(자동 생성 · session_brief.py)
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
    '20_issue/91_사고사례집.md',   # [O106] 조문 경위 무변경 이관부
    '20_issue/92_실측필요_후속작업.md',   # [O106] 자동 생성(gen_measure_backlog.py)
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


def chunk_files(p):
    """[2026-08-14 O82] 허브로 분할된 문서의 조각 파일 목록(연번 순).

    🔴 왜 필요한가: `split_doc.py` 가 정본을 허브 + `-001…-00N` 조각으로 나누면
    제목이 조각으로 이동한다. 이 게이트의 분모(`DOCS`)는 허브만 보므로
    **제목 219건이 「유실」로 오탐**됐다(실제로는 조각에 그대로 있고 concat
    SHA256 이 원문과 일치한다). 분모를 조각까지 넓히지 않으면 게이트가
    「이동」을 「삭제」로 판정해 정상 작업을 막는다 — `P106` 의 반대 방향 사고다.
    ⇒ 조각 제목을 **허브 문서의 제목 집합에 합산**한다(골든 재발행 불요).

    ⚠️ 이 함수는 2026-08-18 사용자 discard 로 한 번 소실됐다가 재적용됐다.
    `C7`(동시 편집) 환경에서 파일 단위 discard 는 **타 세션 변경까지 되돌린다**.
    """
    out = []
    n = 1
    while True:
        c = p.with_name('%s-%03d%s' % (p.stem, n, p.suffix))
        if not c.exists():
            break
        out.append(c)
        n += 1
    if out:
        return out
    # [2026-08-18 O83] 폴더 분할(`split_doc.py --outdir`) 대응.
    #   🔴 왜 필요한가: `01_세션이력.md` 조각은 `20_issue/01_세션이력_조각/` 폴더에 있다.
    #   형제만 찾으면 조각으로 **이동한** 제목 전량이 「유실」로 잡혀 게이트가 실패한다
    #   (`R1-6-8` 이 219건 오탐으로 이미 실증한 사고의 폴더판 — 실제로 104건+ 로 재발했다).
    #   🔴 폴더명을 **stem 으로 추측하지 않는다** — 추측판이 실제 폴더명과 달라 한 번 실패했다.
    #   허브가 `<!-- SPLIT-OUTDIR: … -->` 로 자기기술하므로 그것을 읽는다.
    m = re.search(r'<!--\s*SPLIT-OUTDIR:\s*(.+?)\s*-->', p.read_text(encoding='utf-8'))
    if not m:
        return out
    d = p.parent / m.group(1).strip()
    if d.is_dir():
        n = 1
        while True:
            c = d / ('%s-%03d%s' % (p.stem, n, p.suffix))
            if not c.exists():
                break
            out.append(c)
            n += 1
    return out


def collect():
    cur = {}
    for d in DOCS:
        p = ROOT / d
        if not p.exists():
            cur[d] = None          # 파일 부재도 사고다 — 아래 판정에서 FAIL 로 다룬다
            continue
        hs = headings(p.read_text(encoding='utf-8'))
        for c in chunk_files(p):
            hs.extend(headings(c.read_text(encoding='utf-8')))
        cur[d] = hs
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
            # 🔴 [2026-08-18 O83-H] **⚪ 신설 → 🔴 FAIL 로 격상했다.**
            #   종전에는 골든에 없는 문서를 `added`(⚪ 정보)로 흘렸다. 그래서
            #   `00_guides/01_문서분할_규약.md` 이 `DOCS` 분모에는 있는데 골든이 없어
            #   **그 문서의 제목 유실이 실질적으로 미검사**인 상태가 조용히 유지됐다.
            #   ⇒ 분모에 있으면서 골든에 없는 것은 **게이트의 침묵**이므로 blocking 이다.
            #   🔴 이것이 O83-E 의 「분모를 넓혔는데 게이트가 침묵했다」와 같은 유형이다:
            #   **분모 등재와 기준선 발행은 별개의 두 동작**이고, 하나만 하면 0 이 나온다.
            fails.append(
                f'{d}: 골든 미등재 — 제목 {len(now)}개가 **유실 검사 대상 밖**이다. '
                f'유실 0 을 먼저 확인한 뒤 `--update-golden --reason "<사유>"` 로 발행하라')
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
