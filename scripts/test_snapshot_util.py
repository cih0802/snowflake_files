#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""test_snapshot_util.py — `snapshot_util.py` 음성 테스트 (R3-2).

[2026-08-28 O109 신설]

🔴 왜 음성 테스트인가
--------------------------------------------------------------------------
정상 입력만 돌리면 **덮어쓰기 결함은 통과한다** — 스냅샷이 「만들어졌다」는
사실만 보이고, **무엇이 사라졌는지는 보이지 않는다**(㉡ 가 O108 에서 3회
발생했는데 게이트 전수가 🟢 였던 이유가 그것이다).
그래서 이 테스트의 축은 전부 **「하지 말아야 할 일을 하지 않았는가」** 다.

축
--------------------------------------------------------------------------
① 라벨 — 인자 → 환경변수 → `UNLABELED` 순으로 해소된다(하드코딩 부재)
② 덮어쓰기 금지 — 내용이 다르면 `.2` 를 만들고 **기존 스냅샷 바이트는 불변**
③ 멱등 — 내용이 같으면 파일 수가 늘지 않는다(`reused`)
④ 무결성 — 스냅샷 바이트·SHA256 이 원본과 동일(인코딩·개행 변환 없음)
⑤ 거부 — 경로 구분자 라벨 · 빈 op · 없는 원본 · 접미 소진은 예외로 중단
⑥ 회귀 — `split_doc.py` 소스에 **하드코딩 라벨이 남아 있지 않다**
"""

import io
import os
import re
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import snapshot_util as S  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

FAIL = []
OK = []


def check(cond, name):
    (OK if cond else FAIL).append(name)
    print('  %s %s' % ('✅' if cond else '🔴', name))


def wb(path, data):
    with io.open(path, 'wb') as fh:
        fh.write(data)


def nfiles(d):
    return len(os.listdir(d))


def main():
    tmp = tempfile.mkdtemp(prefix='snaptest_')
    try:
        arch = os.path.join(tmp, '_archive')
        doc = os.path.join(tmp, 'DOC.md')
        wb(doc, '가나다\n'.encode('utf-8'))

        print('[축1] 라벨 해소 — 하드코딩 부재')
        check(S.resolve_label('O109') == 'O109', '인자 라벨이 최우선')
        check(S.resolve_label(None, env='O77') == 'O77', '인자 없으면 환경변수')
        check(S.resolve_label(None, env='') == S.LABEL_FALLBACK,
              '둘 다 없으면 UNLABELED(중단하지 않는다)')
        check(S.resolve_label('  ', env='O77') == 'O77', '공백 라벨은 미지정 취급')
        s1, st1 = S.snapshot(doc, 'presplit', label='O109', archive=arch, quiet=True)
        check(os.path.basename(s1) == 'DOC.md.O109-presplit',
              '파일명 = <base>.<label>-<op>')
        check(st1 == 'created', '최초 호출은 created')

        print('[축2] 덮어쓰기 금지 — 기존 스냅샷 바이트 불변')
        before = io.open(s1, 'rb').read()
        wb(doc, '가나다라마\n'.encode('utf-8'))          # 원본이 바뀐 뒤 재호출
        s2, st2 = S.snapshot(doc, 'presplit', label='O109', archive=arch, quiet=True)
        check(st2 == 'suffixed', '내용이 다르면 suffixed')
        check(os.path.basename(s2) == 'DOC.md.O109-presplit.2', '접미 .2 신설')
        check(io.open(s1, 'rb').read() == before, '🔴 최초 스냅샷이 덮이지 않았다')
        check(nfiles(arch) == 2, '파일 2개(최초 + 접미)')
        wb(doc, '가나다라마바\n'.encode('utf-8'))
        s3, st3 = S.snapshot(doc, 'presplit', label='O109', archive=arch, quiet=True)
        check(os.path.basename(s3) == 'DOC.md.O109-presplit.3', '접미가 .3 으로 증가')

        print('[축3] 멱등 — 같은 내용은 파일을 늘리지 않는다')
        n_before = nfiles(arch)
        s4, st4 = S.snapshot(doc, 'presplit', label='O109', archive=arch, quiet=True)
        check(st4 == 'reused', '바이트 동일 스냅샷이 있으면 reused')
        check(s4 == s3, 'reused 는 그 스냅샷 경로를 돌려준다')
        check(nfiles(arch) == n_before, '파일 수 증가 0')

        print('[축4] 무결성 — 원본과 바이트·해시 동일')
        raw = io.open(doc, 'rb').read()
        check(io.open(s3, 'rb').read() == raw, '스냅샷 바이트 동일')
        check(S.sha256_bytes(io.open(s3, 'rb').read()) == S.sha256_bytes(raw),
              'SHA256 동일')
        crlf = os.path.join(tmp, 'CRLF.md')
        wb(crlf, b'a\r\nb\r\n')
        s5, _ = S.snapshot(crlf, 'prehub', label='O109', archive=arch, quiet=True)
        check(io.open(s5, 'rb').read() == b'a\r\nb\r\n', '개행 변환 없음(CRLF 보존)')

        print('[축5] 거부 — 안전하지 않으면 예외로 중단한다')
        for bad, why in ((os.path.join('a', 'b'), '경로 구분자 라벨'),
                         ('..', '상위 경로 라벨')):
            try:
                S.snapshot(doc, 'presplit', label=bad, archive=arch, quiet=True)
                check(False, '거부: %s' % why)
            except S.SnapshotError:
                check(True, '거부: %s' % why)
        for op, why in (('', '빈 op'), ('   ', '공백 op'), ('a/b', '구분자 op')):
            try:
                S.snapshot(doc, op, label='O109', archive=arch, quiet=True)
                check(False, '거부: %s' % why)
            except S.SnapshotError:
                check(True, '거부: %s' % why)
        try:
            S.snapshot(os.path.join(tmp, 'NOPE.md'), 'presplit',
                       label='O109', archive=arch, quiet=True)
            check(False, '거부: 없는 원본')
        except S.SnapshotError:
            check(True, '거부: 없는 원본')

        arch2 = os.path.join(tmp, '_archive2')
        os.makedirs(arch2)
        base = os.path.join(arch2, 'DOC.md.O109-presplit')
        wb(base, b'x')
        for i in range(2, S.MAX_SUFFIX + 1):
            wb('%s.%d' % (base, i), b'x')
        try:
            S.snapshot(doc, 'presplit', label='O109', archive=arch2, quiet=True)
            check(False, '거부: 접미 소진')
        except S.SnapshotError:
            check(True, '거부: 접미 소진(조용한 소실보다 실패가 낫다)')

        print('[축6] 회귀 — split_doc.py 가 스냅샷을 하드코딩하지 않는다')
        src = io.open(os.path.join(ROOT, 'scripts', 'split_doc.py'),
                      encoding='utf-8').read()
        lines = [ln for ln in src.split('\n') if not ln.lstrip().startswith('#')]
        code = '\n'.join(lines)
        hard = [t for t in ('O107-prehub', 'O83B-prerebalance', 'O107-pretooutdir')
                if t in code]
        check(not hard, '쓰기 라벨 하드코딩 부재 (잔존: %s)' % (hard or '없음'))
        # 🔴 `O82-presplit` 은 **읽기 전용 기준선 조회**(baseline_snapshot)에만 남는다 —
        #   그 이름의 기존 스냅샷이 실재하므로 지우면 게이트2·3 이 조용히 꺼진다.
        #   판정은 **경로를 만드는 줄**(ARCHIVE 결합)만 본다(설명 문장은 무해하다).
        joins = [ln for ln in lines if 'ARCHIVE,' in ln and '-pre' in ln]
        check(len(joins) == 1 and 'legacy' in joins[0],
              'ARCHIVE 경로를 손으로 만드는 곳은 legacy 조회 1곳뿐 (%d곳)' % len(joins))
        check('snapshot_util' in code, 'snapshot_util 을 경유한다')
        check('shutil' not in code, 'shutil 직접 복사 부재')
        check(code.count('snapshot(src,') + code.count('snapshot_content(src,') == 4,
              '스냅샷 지점 4곳이 모두 헬퍼를 쓴다')

        print('[축7] 🔴 전수 회귀 — 스냅샷을 쓰는 도구가 전부 헬퍼를 경유한다')
        # 🔴🔴 [2026-08-28 O110 신설 · O109 D2 처방] O109 는 `split_doc` 만 배선하고
        #   `retire_rows`·`retire_sections`·`split_narrative`·`fix_stale_counts` 4종을
        #   **손대지 않은 채 「결함을 고쳤다」고 보고**했다 — `R1-6-17 ㉡`(같은 파라미터를
        #   보는 지점 전수 조사) 미이행이다. ⇒ 이 축이 그 누락을 기계로 막는다.
        wired = ('split_doc.py', 'retire_rows.py', 'retire_sections.py',
                 'split_narrative.py', 'fix_stale_counts.py')
        for name in wired:
            body = io.open(os.path.join(ROOT, 'scripts', name),
                           encoding='utf-8').read()
            code2 = '\n'.join(ln for ln in body.split('\n')
                              if not ln.lstrip().startswith('#'))
            check('snapshot_util' in code2, '%s 가 헬퍼를 import 한다' % name)
            # 🔴 우회 = **경로를 코드로 만드는 줄**(`os.path.join(... -pre ...)`)만 본다.
            #   ⚠️ [O110 자기시정] 초판은 `-pre` + `ARCHIVE` 문자열만 봐서 **docstring 문장과
            #   print 문안까지 3건 오탐**했다 — `P130`(넓은 판정식)의 세 번째 재현이다.
            bypass = [ln for ln in code2.split('\n')
                      if ('os.path.join(' in ln and '-pre' in ln
                          and ('arch' in ln or 'ARCHIVE' in ln) and 'legacy' not in ln)]
            check(not bypass, '%s 에 스냅샷 우회 경로 없음 (%s)'
                  % (name, bypass[:1] or '없음'))
        print('[축8] 회귀 — 라벨 기본값에 세션 라벨을 하드코딩하지 않는다')
        for name in wired:
            body = io.open(os.path.join(ROOT, 'scripts', name),
                           encoding='utf-8').read()
            bad = re.findall(r"add_argument\(\s*'--label'\s*,\s*default='O[\d\-A-Z]+'", body)
            check(not bad, '%s 라벨 기본값 하드코딩 없음 (%s)' % (name, bad[:1] or '없음'))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print('')
    if FAIL:
        print('🔴 FAIL %d건 / 단정 %d개' % (len(FAIL), len(OK) + len(FAIL)))
        for f in FAIL:
            print('   · %s' % f)
        return 1
    print('✅ 전건 통과 — 8축 %d개 단정' % len(OK))
    return 0


if __name__ == '__main__':
    sys.exit(main())
