#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""doc_coord_gate.py — 문서가 인용하는 **파일 좌표가 실재하는지** 검사한다.

[2026-08-28 O109 신설 · 사용자 결정 · 인수 §0-NNN ④ 인용 검증의 집행 도구]

🔴 이 게이트가 푸는 문제
--------------------------------------------------------------------------
이 워크스페이스의 문장은 **좌표로 근거를 댄다**(`20_issue/10_진단_원인분석-002.md:24`).
그런데 좌표를 **죽이는 연산**이 이미 3종 있다:
  ㉠ `--to-outdir` 폴더화 — 형제 `<문서>-0NN.md` 가 `<문서>_조각/` 아래로 옮겨진다
  ㉡ `--rebalance` — 조각 경계가 바뀌어 **행 번호**가 이동한다
  ㉢ `retire_*` — 본문이 다른 문서로 이관된다
⇒ O108 폴더화 직후 실측 = **죽은 조각 좌표 5종 6회**. 게이트 6종이 전부 🟢 인
   상태였고, 죽은 좌표는 **인용을 따라가려는 다음 세션만 발견**할 수 있었다
   (그 세션은 근거를 못 찾고 「미독」으로 남긴다 — `R1-3-7` 이 막으려던 그 상태).

🟢 판정 설계 — 「항상 빨간 게이트」(`P130`)를 피한다
--------------------------------------------------------------------------
* **축1(blocking)** = **갱신형 정본**의 죽은 좌표. 정본은 지금 유효해야 한다.
* **축2(관측 ⚪)** = **append형 이력**(`01_세션이력`·`90_해소완료`·`91_사고사례집`)의
  죽은 좌표. 과거 기록은 **그 시점 사실**이므로 소급 수정 대상이 아니다(`R1-3-6`).
* **축3(경고 🟠)** = 행 번호가 **파일 끝을 넘는** 좌표. 재균형으로 흔히 어긋나므로
  blocking 으로 올리지 않는다(그러나 인용을 따라가면 엉뚱한 줄을 읽게 된다).
* 🟢 **이전 제안** — 형제 경로가 죽었고 `<문서>_조각/` 에 같은 파일이 있으면
  **고칠 경로를 같이 출력**한다(사람이 손으로 찾지 않게 한다).

🔴 음성 테스트 = `scripts/test_doc_coord_gate.py`(R3-2).

사용:
  python3 scripts/doc_coord_gate.py            # 게이트(축1 위반 시 exit 1)
  python3 scripts/doc_coord_gate.py --list     # 죽은 좌표 전건 + 이전 제안
"""

import argparse
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

#: 스캔 대상 루트(1단계 하위 폴더까지). 🔴 분모를 형제 파일명에 의존시키지 않는다.
SCAN_DIRS = ('20_issue', '00_guides', '99_NEXT_SESSION_조각')

#: 스캔에서 제외하는 폴더·파일.
SKIP_DIRS = ('_archive', '__pycache__', 'logs', 'target', '.git')

#: 🔴 자동 생성물은 정본이 아니다 — 좌표가 틀리면 **생성기**를 고쳐야 한다.
SKIP_FILES = ('00_BRIEF.md', '92_실측필요_후속작업.md')

#: `_` 로 시작하는 루트 파일은 **작업 부산물**이다(`_o1NN_entry.md` = `--rollover` 입력 원본 ·
#: 이력에 이미 편입된 사본). 정본이 아니므로 분모에서 뺀다 — 넣으면 같은 좌표가 이력과
#: 부산물에서 **두 번** 잡혀 경고가 영구히 부풀고, 고칠 자리가 없다(`P130`).
SKIP_PREFIX = ('_',)

#: append형 이력 = 과거 기록이라 죽은 좌표를 blocking 으로 올리지 않는다(축2).
HISTORY_PREFIX = ('01_세션이력', '90_해소완료_로그', '91_사고사례집')

#: 좌표 정규식 — `20_issue/…-0NN.md:24` · `<문서>_조각/<문서>-0NN.md` · `20_issue/xx_….md`
#: 🆕 🔴🔴 [2026-08-30 O124-B] **세션 근거철(`_o1NN_evidence.md`) 관례를 분모에 넣었다.**
#:   실사고 = O123-D 가 원장 §1 · 이력 2곳 · `99_NEXT` 1곳 = **4곳에서 근거철을 인용했는데
#:   그 파일은 실재한 적이 없다.** 게이트 6종이 전부 🟢 인 상태로 통과했다.
#:   🔴 원인 = 이 정규식이 파일명을 **`[0-9]{2}_` 로 시작하는 것만** 잡았다 ⇒ 접두 `_` 로
#:   시작하는 근거철은 **원리적으로 분모 밖**이었다(`P106` 「분모가 좁은 게이트」의 재현).
#:   🔴 이것은 O124 자신에게도 위험했다 — `_o124_evidence.md` 를 원장·이력·`99_NEXT`·게이트 주석
#:   **5곳**에서 인용하는데, 그 파일이 지워지면 같은 방식으로 **조용히** 죽는다.
#:   ⚠️ 대안 접미(`_notes`·`_memo` 등)까지 넓히지 않는다 — 실재하는 관례 하나만 좁게 잡는다.
COORD = re.compile(
    r'(?<![\w/])((?:20_issue/|00_guides/|99_NEXT_SESSION_조각/)?'
    r'(?:[0-9A-Za-z가-힣_]+_조각/)?'
    r'(?:[0-9]{2}_[0-9A-Za-z가-힣_]+(?:-[0-9]{3})?|_[0-9A-Za-z]+_evidence)\.md)'
    r'(?::([0-9]+))?')


def keep(name):
    """분모에 넣을 파일명인가(`.md` · 생성물 아님 · 부산물 아님)."""
    return (name.endswith('.md') and name not in SKIP_FILES
            and not name.startswith(SKIP_PREFIX))


def md_files():
    """스캔 대상 `.md` 를 모은다(직속 + 1단계 하위 · 정렬 · 중복 제거)."""
    out = []
    for d in SCAN_DIRS:
        base = os.path.join(ROOT, d)
        if not os.path.isdir(base):
            continue
        for f in sorted(os.listdir(base)):
            p = os.path.join(base, f)
            if os.path.isfile(p) and keep(f):
                out.append(p)
            elif os.path.isdir(p) and f not in SKIP_DIRS:
                for g in sorted(os.listdir(p)):
                    if keep(g):
                        out.append(os.path.join(p, g))
    for f in sorted(os.listdir(ROOT)):
        if os.path.isfile(os.path.join(ROOT, f)) and keep(f):
            out.append(os.path.join(ROOT, f))
    seen, uniq = set(), []
    for p in out:
        rp = os.path.realpath(p)
        if rp in seen:
            continue
        seen.add(rp)
        uniq.append(p)
    return uniq


def candidates(coord):
    """좌표 문자열이 가리킬 수 있는 실제 경로 후보를 만든다(선언 순서대로)."""
    cands = [coord]
    if not coord.startswith(('20_issue/', '00_guides/', '99_NEXT_SESSION_조각/')):
        cands += ['20_issue/' + coord, '00_guides/' + coord]
    return cands


_INDEX = None


def basename_index():
    """워크스페이스 전역 `basename → [상대경로]` 인덱스(1회 구축 · 캐시).

    🔴🔴 [O109 자기시정] 초판은 후보 경로를 `20_issue/`·`00_guides/` 로만 만들어
      **다른 폴더에 실재하는 문서**(`30_output_share/08_AGENT_spec.md` 등)를
      「죽었다」고 103건 잡았다 — 그것이 `P130`(항상 빨간 게이트)의 정확한 재현이고,
      게이트를 끄게 만드는 가장 흔한 실패다. ⇒ **실재 판정의 분모는 전역**이다.
    """
    global _INDEX
    if _INDEX is not None:
        return _INDEX
    idx = {}
    for dirpath, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if f.endswith('.md'):
                rel = os.path.relpath(os.path.join(dirpath, f), ROOT)
                idx.setdefault(f, []).append(rel)
    _INDEX = idx
    return idx


_ARCH = None


def archive_index():
    """🆕 [2026-08-28 O111 신설] **은퇴본 전용** `basename → [상대경로]` 인덱스.

    🔴🔴 왜 필요한가 (O111 실측 · 인수인계 진단이 틀렸던 지점)
      `basename_index()` 는 `SKIP_DIRS`(= `_archive` 포함)를 **가지치기**한다.
      그래서 `_archive/` 아래에만 남은 문서를 인용하면 등급이 `dead` 가 되고
      게이트는 **「참조 대상이 어디에도 없다」**로 찍는다.
      · 실측 = 축1b 9건 중 **8건**이 이 오분류였다
        (`02_원천결손_Gap분석.md` 5 · `00_README_이관안내.md` 3 ⇒ 둘 다
         `30_output_share/_archive/20260716·20260806/` 에 **실재**한다).
      · 🔴 인수인계는 이 9건을 「`_archive` 에도 없다 ⇒ 삭제인지 개칭인지 사람 판단」
        이라고 적었는데, **그 전제 자체가 게이트의 오분류**였다.
        ⇒ 사람 판단이 필요한 것은 **1건**뿐이다(`00_통합이슈_레지스트리_20260715.md`).
    🟢 처방 = `_archive` 를 **스캔 원본**에서는 계속 빼되(스냅샷은 정본이 아니다)
      **실재 판정 분모**에는 넣고, 등급을 `archived` 로 따로 세운다(축6).
      ⇒ ③ `index_row_gate` 와 같은 원리다: **제외 규칙은 그 근거가 성립하는 축에만.**
    """
    global _ARCH
    if _ARCH is not None:
        return _ARCH
    idx = {}
    skip = tuple(d for d in SKIP_DIRS if d != '_archive')
    for dirpath, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in skip]
        if '_archive' not in os.path.relpath(dirpath, ROOT).split(os.sep):
            continue
        for f in files:
            if f.endswith('.md'):
                rel = os.path.relpath(os.path.join(dirpath, f), ROOT)
                idx.setdefault(f, []).append(rel)
    _ARCH = idx
    return idx


def abbrev_match(base):
    """약칭 좌표(`10_진단-002.md`)가 가리킬 만한 실제 파일을 찾는다.

    판정 = `<번호>_<접두>` 가 실제 파일 stem 의 **접두**이고 연번이 같다.
    이런 좌표는 사람이 따라갈 수는 있으므로 **경고(🟠)** 로 낮춘다.
    """
    m = re.match(r'^([0-9]{2}_[^-]+)-([0-9]{3})\.md$', base)
    if not m:
        m2 = re.match(r'^([0-9]{2}_.+)\.md$', base)
        if not m2:
            return None
        for name, paths in basename_index().items():
            if name.startswith(m2.group(1)):
                return paths[0]
        return None
    pre, num = m.group(1), m.group(2)
    for name, paths in basename_index().items():
        if name.startswith(pre) and name.endswith('-%s.md' % num):
            return paths[0]
    return None


def relocated(coord):
    """형제 경로가 죽었을 때 **폴더 방식** 대안 경로를 만든다(없으면 None).

    `20_issue/10_진단_원인분석-002.md` → `20_issue/10_진단_원인분석_조각/10_진단_원인분석-002.md`
    """
    base = os.path.basename(coord)
    m = re.match(r'^(.*)-([0-9]{3})\.md$', base)
    if not m:
        return None
    stem = m.group(1)
    for d in list(SCAN_DIRS) + ['']:
        p = os.path.join(d, '%s_조각' % stem, base) if d else os.path.join('%s_조각' % stem, base)
        if os.path.exists(os.path.join(ROOT, p)):
            return p
    return None


def resolve(coord):
    """좌표를 판정한다 — `(등급, 실제경로 or None, 제안 or None)`.

    등급 = `live`(그 경로에 실재) · `bare`(디렉터리 없이 파일명만 썼고 그 이름이
           실재 — 이 워크스페이스의 정상 관례다) · `moved`(**경로를 붙여 썼는데**
           그 경로에 없고 다른 곳에 있다 = 좌표가 죽었다) · `abbrev`(약칭 · 경고) ·
           `dead`(어디에도 없다).

    🔴🔴 [O109 2차 자기시정] 초판·2판은 `08_AGENT_spec.md` 처럼 **디렉터리를 생략한
      정상 표기**를 죽은 좌표로 잡아 99건을 냈다. 문서가 파일명만 쓰는 것은
      **관례**이고 이름이 유일하면 따라갈 수 있다 ⇒ blocking 대상은
      **「경로를 명시했는데 그 경로가 없는 것」**으로 좁힌다(그것만이 O108 폴더화가
      실제로 깨뜨린 축이다). 넓히면 `P130`(항상 빨간 게이트)가 된다.
    """
    for c in candidates(coord):
        if os.path.exists(os.path.join(ROOT, c)):
            return 'live', c, None
    base = os.path.basename(coord)
    hit = basename_index().get(base)
    has_dir = '/' in coord
    if hit:
        if not has_dir:
            # 🆕 [2026-08-28 O110 · O109 D6] 같은 파일명이 **여러 곳**에 있으면
            #   「파일명만 써도 따라갈 수 있다」는 근거가 성립하지 않는다 ⇒ 모호성 경고.
            return ('ambiguous' if len(hit) > 1 else 'bare'), hit[0], None
        return 'moved', hit[0], hit[0]
    fix = relocated(coord)
    if fix:
        return 'moved' if has_dir else 'bare', fix, fix if has_dir else None
    ab = abbrev_match(base)
    if ab:
        return 'abbrev', ab, ab
    # 🆕 [2026-08-28 O111] 은퇴본만 남은 문서 = `dead` 가 아니라 `archived`(축6).
    arch = archive_index().get(base)
    if arch:
        return 'archived', arch[0], None
    return 'dead', None, None


def nlines(rel):
    with io.open(os.path.join(ROOT, rel), encoding='utf-8', errors='replace') as fh:
        return fh.read().count('\n') + 1


def is_history(path):
    return os.path.basename(path).startswith(HISTORY_PREFIX)


def scan():
    """(dead_canon, dead_history, overflow, abbrev, ambiguous, archived) — 각 항목 = dict."""
    dead_canon, dead_hist, overflow, abbrev, ambiguous = [], [], [], [], []
    archived = []
    for p in md_files():
        rel = os.path.relpath(p, ROOT)
        hist = is_history(p)
        with io.open(p, encoding='utf-8', errors='replace') as fh:
            lines = fh.read().split('\n')
        for n, line in enumerate(lines, 1):
            for m in COORD.finditer(line):
                coord, lineno = m.group(1), m.group(2)
                if coord == os.path.basename(rel):
                    continue
                grade, got, fix = resolve(coord)
                item = {'src': rel, 'line': n, 'coord': coord, 'fix': fix,
                        'target': got, 'hist': hist}
                if grade in ('moved', 'dead'):
                    (dead_hist if hist else dead_canon).append(item)
                    if got is None:
                        continue
                elif grade == 'archived':
                    archived.append(item)
                    continue          # 은퇴본은 행 번호 대조 대상이 아니다
                elif grade == 'abbrev':
                    abbrev.append(item)
                elif grade == 'ambiguous':
                    item['places'] = len(basename_index().get(
                        os.path.basename(coord), []))
                    ambiguous.append(item)
                if lineno and got:
                    tot = nlines(got)
                    if int(lineno) > tot:
                        overflow.append({'src': rel, 'line': n, 'coord': coord,
                                         'target': got, 'want': int(lineno),
                                         'have': tot, 'hist': hist})
    return dead_canon, dead_hist, overflow, abbrev, ambiguous, archived


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument('--list', action='store_true', help='죽은 좌표 전건을 보인다')
    a = ap.parse_args(argv)

    dead_canon, dead_hist, overflow, abbrev, ambiguous, archived = scan()
    fixable = [it for it in dead_canon if it['fix']]
    unknown = [it for it in dead_canon if not it['fix']]
    print('[문서 좌표 실재 게이트] 스캔 %d파일' % len(md_files()))
    # 🔴 blocking 은 **우리 연산이 깨뜨린 것**(이전 제안이 있는 것)에만 건다.
    #   참조 대상이 아예 없는 것은 사람 판단이 필요하고, blocking 으로 걸면
    #   아무도 못 고치는 상태로 게이트가 영구 FAIL 이 된다(`P130`).
    print('  축1a 경로가 깨진 좌표(우리 연산이 옮겼다 · blocking): %d건' % len(fixable))
    for it in (fixable if a.list else fixable[:20]):
        print('    🔴 %s:%d  %s  ⇒ 고칠 경로 = %s'
              % (it['src'], it['line'], it['coord'], it['fix']))
    print('  축1b 참조 대상이 어디에도 없다(경고 · 사람 판단): %d건' % len(unknown))
    for it in (unknown if a.list else unknown[:10]):
        print('    🟠 %s:%d  %s' % (it['src'], it['line'], it['coord']))
    print('  축2 이력(append형) 죽은 좌표: %d건 (관측 · 소급 수정 대상 아님)' % len(dead_hist))
    if a.list:
        for it in dead_hist:
            print('    ⚪ %s:%d  %s' % (it['src'], it['line'], it['coord']))
    print('  축3 행 번호가 파일 끝을 넘는 좌표: %d건 (경고)' % len(overflow))
    for it in (overflow if a.list else overflow[:10]):
        print('    🟠 %s:%d  %s → %s 은 %d줄' % (
            it['src'], it['line'], it['coord'], it['target'], it['have']))
    print('  축4 약칭 좌표(정확한 파일명이 아니다): %d건 (경고)' % len(abbrev))
    for it in (abbrev if a.list else abbrev[:10]):
        print('    🟠 %s:%d  %s → 아마 %s' % (
            it['src'], it['line'], it['coord'], it['fix']))
    print('  축5 모호한 파일명 인용(같은 이름이 여러 곳): %d건 (경고)' % len(ambiguous))
    for it in (ambiguous if a.list else ambiguous[:10]):
        print('    🟠 %s:%d  %s → %d곳에 있다(첫 후보 %s) ⇒ 경로를 붙여라'
              % (it['src'], it['line'], it['coord'], it['places'], it['target']))
    # 🆕 [2026-08-28 O111] 축6 = 은퇴본만 존재. 종전에는 축1b「어디에도 없다」로 섞여
    #   **삭제 판단을 요구**했으나, 실체는 `_archive/` 에 남아 있어 따라갈 수 있다.
    print('  축6 은퇴본만 존재(`_archive/` 에 실재 · 관측): %d건' % len(archived))
    for it in (archived if a.list else archived[:10]):
        print('    ⚪ %s:%d  %s → 은퇴본 %s' % (
            it['src'], it['line'], it['coord'], it['target']))

    print('')
    if fixable:
        print('🔴 FAIL — 경로가 깨진 좌표 %d건. 인용을 따라갈 수 없다.' % len(fixable))
        print('   🟢 고치는 방법 = 그 **조각**을 `edit` 로 수정한 뒤 허브를 재발행한다:')
        print('      python3 scripts/split_doc.py <허브> --republish --label O1NN')
        return 1
    print('✅ 게이트 통과 — 경로가 깨진 좌표 0건 (경고 %d건은 사람 판단)' % len(unknown))
    return 0


if __name__ == '__main__':
    sys.exit(main())
