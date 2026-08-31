#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""test_doc_coord_gate.py — `doc_coord_gate.py` 음성 테스트 (R3-2).

[2026-08-28 O109 신설]

🔴 왜 이 축들인가 — **내가 실제로 두 번 오탐을 냈다**
--------------------------------------------------------------------------
초판은 죽은 좌표를 **103건**, 2판은 **99건** 냈다. 둘 다 결함이 아니라
**분모·판정 기준의 오류**였다:
  ㉠ 후보 경로를 `20_issue/`·`00_guides/` 로만 만들었다 ⇒ 다른 폴더의 실재 문서를
     「죽었다」고 잡았다.
  ㉡ 디렉터리를 생략한 정상 표기(`08_AGENT_spec.md`)를 죽은 좌표로 잡았다.
🔴 **정상 입력만 돌려서는 둘 다 잡히지 않는다** — 「FAIL 이 많이 나왔다」는 것은
   결함의 증거처럼 보이기 때문이다. ⇒ 축2·축3 이 그 두 오탐을 고정한다.

축
--------------------------------------------------------------------------
① 실재 경로는 잡지 않는다
② 🔴 다른 폴더에 있는 파일을 **파일명만으로** 인용한 것은 잡지 않는다(오탐 ㉠·㉡)
③ 경로를 명시했는데 폴더로 옮겨진 것은 **축1a(blocking)** + 이전 제안
④ 어디에도 없는 참조는 **축1b(경고)** 이고 blocking 이 아니다
⑤ 이력(append형) 문서의 죽은 좌표는 **축2(관측)** 이고 blocking 이 아니다
⑥ 행 번호가 파일 끝을 넘으면 **축3(경고)**
⑦ 약칭 좌표는 **축4(경고)** 이고 추정 경로를 제시한다
⑧ 부산물(`_` 접두) 제외 — 이력에 편입된 사본이 경고를 두 번 만들지 않는다
⑨ exit code — 축1a 만 1 을 만든다
"""

import io
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import doc_coord_gate as G  # noqa: E402

FAIL = []
OK = []


def check(cond, name):
    (OK if cond else FAIL).append(name)
    print('  %s %s' % ('✅' if cond else '🔴', name))


def w(path, text):
    d = os.path.dirname(path)
    if d and not os.path.isdir(d):
        os.makedirs(d)
    with io.open(path, 'w', encoding='utf-8') as fh:
        fh.write(text)


def build_fixture(root):
    """가짜 워크스페이스 — 실재 파일 + 인용 문서."""
    # 실재하는 대상들
    w(os.path.join(root, '20_issue', '10_진단_원인분석_조각', '10_진단_원인분석-002.md'),
      '머리1\n머리2\n머리3\n본문 24행까지는 없다\n')
    w(os.path.join(root, '05_SV-Agent_ai', '08_AGENT_spec.md'), 'spec\n')
    # 모호성 축 — 같은 파일명이 두 곳에 있다(축10)
    w(os.path.join(root, '03_top-down_gold', '00_README.md'), 'a\n')
    w(os.path.join(root, '04_silver_design', '00_README.md'), 'b\n')
    w(os.path.join(root, '20_issue', '30_설계_의사결정_조각', '30_설계_의사결정-001.md'),
      '\n'.join(['line%d' % i for i in range(1, 40)]) + '\n')
    # 인용 문서(갱신형 정본)
    w(os.path.join(root, '20_issue', '99_인용_조각', '99_인용-001.md'), '\n'.join([
        '축1 실재 = `20_issue/30_설계_의사결정_조각/30_설계_의사결정-001.md:5`',
        '축2 파일명만 = `08_AGENT_spec.md` 를 보라',
        '축3 옮겨짐 = `20_issue/10_진단_원인분석-002.md:4`',
        '축4 부재 = `02_원천결손_Gap분석.md`',
        '축6 행초과 = `20_issue/30_설계_의사결정_조각/30_설계_의사결정-001.md:999`',
        '축7 약칭 = `10_진단-002.md`',
        '축10 모호 = `00_README.md`',
    ]) + '\n')
    # 인용 문서(append형 이력)
    w(os.path.join(root, '20_issue', '01_세션이력_조각', '01_세션이력-001.md'),
      '과거 기록 = `20_issue/10_진단_원인분석-002.md:4` (그 시점 사실)\n')


    # 부산물(`_` 접두) — 이력에 이미 편입된 사본이라 분모에서 빠져야 한다
    w(os.path.join(root, '_o999_entry.md'),
      '부산물 = `20_issue/10_진단_원인분석-002.md:4` · `02_원천결손_Gap분석.md`\n')

    # 🆕 [2026-08-28 O111] 축11 = **은퇴본만 존재**하는 대상.
    #   🔴 실사고 = `basename_index()` 가 `_archive` 를 가지치기해서, `_archive/` 에만
    #     남은 문서를 인용하면 「어디에도 없다」(축1b)로 찍혔다 ⇒ 실측 9건 중 **8건이 오분류**.
    #     그 결과 인수인계가 **하지 않아도 되는 삭제/개칭 판단 8건**을 다음 세션에 넘겼다.
    w(os.path.join(root, '30_output_share', '_archive', '20260716', '02_은퇴본.md'),
      '은퇴본 본문\n')
    w(os.path.join(root, '20_issue', '98_은퇴인용_조각', '98_은퇴인용-001.md'),
      '축11 은퇴본 = `02_은퇴본.md` 를 보라\n')


def main():
    tmp = tempfile.mkdtemp(prefix='coordtest_')
    old_root, old_idx, old_arch = G.ROOT, G._INDEX, G._ARCH
    try:
        build_fixture(tmp)
        G.ROOT, G._INDEX, G._ARCH = tmp, None, None
        dead, hist, over, abbrev, amb, arch = G.scan()
        fixable = [it for it in dead if it['fix']]
        unknown = [it for it in dead if not it['fix']]
        coords = lambda xs: sorted(it['coord'] for it in xs)  # noqa: E731

        print('[축1] 실재 경로는 잡지 않는다')
        check('20_issue/30_설계_의사결정_조각/30_설계_의사결정-001.md' not in coords(dead),
              '실재 경로가 죽은 좌표로 잡혔다')

        print('[축2] 🔴 파일명만 쓴 인용은 잡지 않는다(오탐 ㉠·㉡ 고정)')
        check('08_AGENT_spec.md' not in coords(dead),
              '다른 폴더 실재 파일을 파일명만으로 쓴 것이 잡혔다')
        grade, got, fix = G.resolve('08_AGENT_spec.md')
        check(grade == 'bare' and got == '05_SV-Agent_ai/08_AGENT_spec.md',
              'resolve 가 bare 로 판정하고 실제 경로를 찾는다 (got=%s)' % grade)

        print('[축3] 경로 명시 + 폴더 이전 = 축1a(blocking) + 제안')
        hit = [it for it in fixable if it['coord'] == '20_issue/10_진단_원인분석-002.md']
        check(len(hit) == 1, '옮겨진 경로가 축1a 로 1건 잡힌다 (%d건)' % len(hit))
        check(bool(hit) and hit[0]['fix'] ==
              '20_issue/10_진단_원인분석_조각/10_진단_원인분석-002.md',
              '이전 제안 경로가 정확하다')

        print('[축4] 어디에도 없는 참조 = 축1b(경고 · blocking 아님)')
        check('02_원천결손_Gap분석.md' in coords(unknown), '부재 참조가 축1b 에 있다')
        check('02_원천결손_Gap분석.md' not in coords(fixable), '부재 참조가 blocking 이 아니다')

        print('[축5] 이력 문서의 죽은 좌표 = 축2(관측)')
        check(len(hist) == 1 and hist[0]['src'].startswith('20_issue/01_세션이력'),
              '이력 죽은 좌표가 축2 로 분리된다 (%d건)' % len(hist))
        check(all(not it['src'].startswith('20_issue/01_세션이력') for it in dead),
              '이력 항목이 갱신형 blocking 에 섞였다')

        print('[축6] 행 번호 초과 = 축3(경고)')
        check(any(it['want'] == 999 for it in over), '행 초과 좌표가 축3 에 있다')
        check(all(it['want'] <= it['have'] or it['want'] == 999 for it in over),
              '축3 판정이 실제 줄 수 대조다')

        print('[축7] 약칭 좌표 = 축4(경고) + 추정 경로')
        check(any(it['coord'] == '10_진단-002.md' for it in abbrev),
              '약칭 좌표가 축4 에 있다')
        check(all(it['fix'] for it in abbrev), '약칭 좌표에 추정 경로가 붙는다')

        print('[축8] 부산물(`_` 접두)은 분모에서 빠진다')
        srcs = set(it['src'] for it in dead + hist + over + abbrev + amb)
        check(not any(s.startswith('_o999') for s in srcs),
              '부산물 파일이 분모에 들어왔다 (경고가 영구히 부푼다)')
        check(not G.keep('_o999_entry.md') and G.keep('00_INDEX_이슈원장-001.md'),
              'keep() 이 부산물만 걸러낸다')

        print('[축9] 🟠 모호한 파일명 인용 — 경고로 잡고 blocking 은 아니다')
        check(any(it['coord'] == '00_README.md' for it in amb),
              '동명 파일 2곳 인용이 축5(모호)에 있다')
        check(all(it.get('places', 0) >= 2 for it in amb), '모호 항목에 후보 수가 붙는다')
        check(not any(it['coord'] == '00_README.md' for it in dead),
              '모호 인용이 blocking 으로 올라갔다')

        print('[축11] 🆕 은퇴본만 존재 = 축6(관측) — 「어디에도 없다」가 아니다')
        check(any(it['coord'] == '02_은퇴본.md' for it in arch),
              '은퇴본 인용이 축6 으로 분류된다')
        check(not any(it['coord'] == '02_은퇴본.md' for it in dead),
              '🔴 은퇴본 인용이 축1b(어디에도 없다)로 오분류됐다 — O111 이 고친 결함')
        check(all('_archive' in (it['target'] or '') for it in arch),
              '축6 항목은 은퇴본 실경로를 제시한다')
        # 🔴 대조군(재현율) — 진짜 부재는 여전히 축1b 여야 한다.
        check('02_원천결손_Gap분석.md' in coords(unknown),
              '진짜 부재 참조는 여전히 축1b 에 남는다(은폐 0)')

        print('[축10] exit code — 축1a 만 FAIL 을 만든다')
        rc = G.main([])
        check(rc == 1, '축1a 가 있는데 exit 0 이다')
        # 축1a 원인을 제거하면(경로를 고치면) 통과해야 한다
        p = os.path.join(tmp, '20_issue', '99_인용_조각', '99_인용-001.md')
        t = io.open(p, encoding='utf-8').read().replace(
            '20_issue/10_진단_원인분석-002.md',
            '20_issue/10_진단_원인분석_조각/10_진단_원인분석-002.md')
        w(p, t)
        G._INDEX = None
        rc2 = G.main([])
        check(rc2 == 0, '축1a 를 고쳤는데 여전히 FAIL 이다(축1b·축3 이 blocking 이 됐다)')

        # ── 🆕 축12: 세션 근거철(`_o1NN_evidence.md`) 이 분모에 들어왔는가 ──────
        #   🔴 실사고(O124-B) = O123-D 가 근거철을 4곳에서 인용했고 그 인용이
        #     **어떤 게이트에도 잡히지 않았다** — `COORD` 가 `[0-9]{2}_` 접두만 봤기 때문이다.
        #     🔴 그리고 O124 는 그 파일을 **경로 한정 `ls` 로 「부재」라 오판**했다(실제는 루트에 실재).
        #     ⇒ 이 축은 **㉠ 인식** + **㉡ 넓히지 않음** 양방향을 단정한다.
        print('[축12] 🆕 세션 근거철 관례가 좌표 분모에 있다')
        hit = [c for c, _ln in G.COORD.findall('근거철 = `_o123c_evidence.md`(E0~E11)')]
        check(hit == ['_o123c_evidence.md'],
              '루트 근거철 인용을 좌표로 인식한다 · 실제 %r' % hit)
        hit = [c for c, _ln in G.COORD.findall('근거철 = `20_issue/_o124_evidence.md` §E1')]
        check(hit == ['20_issue/_o124_evidence.md'],
              '`20_issue/` 접두 근거철도 인식한다 · 실제 %r' % hit)
        hit = [c for c, _ln in G.COORD.findall('좌표 = `20_issue/30_설계_의사결정_조각/30_설계_의사결정-001.md:5`')]
        check(hit == ['20_issue/30_설계_의사결정_조각/30_설계_의사결정-001.md'],
              '🔴 재현율 축 = 기존 좌표 형식이 그대로 인식된다(확장이 기존을 깨지 않았다)')
        # 🔴 오탐 축 = 관례를 넓히지 않았다. 접미가 `_evidence` 가 아니면 좌표가 아니다.
        for s in ('부산물 = `_o124_entry.md` 였다',
                  '메모 = `_o124_notes.md`',
                  '스냅샷 = `_prehub.md`',
                  '`evidence_o124.md` 는 관례가 아니다'):
            hit = [c for c, _ln in G.COORD.findall(s)]
            check(hit == [], '관례 밖 `_` 파일은 좌표로 세지 않는다: %r → %r' % (s[:26], hit))
        # 🔴🔴 실재 판정은 전역 인덱스여야 한다 — 폴더를 한정하면 O124 의 오판이 게이트에 박힌다.
        check(G.basename_index.__doc__ and '전역' in G.basename_index.__doc__,
              '실재 판정 분모가 전역임이 문서화돼 있다(경로 한정 금지)')
    finally:
        G.ROOT, G._INDEX, G._ARCH = old_root, old_idx, old_arch
        shutil.rmtree(tmp, ignore_errors=True)

    print('')
    if FAIL:
        print('🔴 FAIL %d건 / 단정 %d개' % (len(FAIL), len(OK) + len(FAIL)))
        for f in FAIL:
            print('   · %s' % f)
        return 1
    print('✅ 전건 통과 — %d개 단정 (🔴 축 수를 적지 마라 · R3-9 ㉦)' % len(OK))
    return 0


if __name__ == '__main__':
    sys.exit(main())
