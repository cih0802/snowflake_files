#!/usr/bin/env python3
"""test_doc_type_gate_denominator — `doc_type_gate.actual_docs()` 분모 편입 음성 테스트.

🔴 **왜 이 테스트가 있는가** (2026-09-01 O129-B 신설)

`doc_type_gate` 는 `EXTRA_DOCS`(20_issue 폴더 밖 상시 독해 문서)의 조각을 편입할 때
**형제 방식(`<stem>-001.md`)만** 찾고 **폴더 방식(`<stem>_조각/`)은 보지 않았다.**
`99_NEXT_SESSION` 은 O107 의 `--to-outdir` 로 폴더 방식으로 이전됐으므로,
그 시점부터 이 게이트는 그 문서를 **허브 1개**로 셌다.

실해 = 조각 24개가 분모 밖 ⇒ 실측 여유 **34 B** 인 조각을 게이트가 **6,503 B** 로 보고했고,
`doc_census`(실측 축)와 **판정이 갈렸다**(`R3-9 ㉡`). 게이트는 그 사이 계속 🟢 였다.

🔴 **판정식 = 정상 입력만으로는 이 결함이 안 잡힌다.** 폴더 방식 조각이 분모에 들어오는지를
**직접 세어** 단정해야 한다. 그래서 이 테스트는 「오염(폴더 제거)」 축을 함께 둔다.

사용 = `python3 scripts/test_doc_type_gate_denominator.py` (rc=0 이면 통과)
"""
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import doc_type_gate as dtg  # noqa: E402

FAILS = []
ASSERTS = 0


def check(label, got, want):
    global ASSERTS
    ASSERTS += 1
    if got != want:
        FAILS.append('%s — got %r · want %r' % (label, got, want))
        print('  🔴 %s — got %r · want %r' % (label, got, want))
    else:
        print('  🟢 %s — %r' % (label, got))


def touch(path, body='x\n'):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(body)


def build(tmp, with_folder=True, folder_name='hubB_조각'):
    """형제 방식 1문서 + 폴더 방식 1문서를 만든다."""
    empty_doc_dir = os.path.join(tmp, '20_issue_empty')
    os.makedirs(empty_doc_dir, exist_ok=True)

    touch(os.path.join(tmp, 'hubA.md'))
    touch(os.path.join(tmp, 'hubA-001.md'))
    touch(os.path.join(tmp, 'hubA-002.md'))

    touch(os.path.join(tmp, 'hubB.md'))
    if with_folder:
        touch(os.path.join(tmp, folder_name, 'hubB-001.md'))
        touch(os.path.join(tmp, folder_name, 'hubB-002.md'))
        # 비대상 확장자는 편입되지 않아야 한다
        touch(os.path.join(tmp, folder_name, 'notes.txt'))
    return empty_doc_dir


def run(tmp, empty_doc_dir):
    """ROOT·DOC_DIR·EXTRA_DOCS 를 임시 구조로 갈아끼우고 분모를 센다."""
    old = (dtg.ROOT, dtg.DOC_DIR, dtg.EXTRA_DOCS)
    dtg.ROOT = tmp
    dtg.DOC_DIR = empty_doc_dir
    dtg.EXTRA_DOCS = ['hubA.md', 'hubB.md']
    try:
        fam = dtg.actual_docs()
    finally:
        dtg.ROOT, dtg.DOC_DIR, dtg.EXTRA_DOCS = old
    return {k: sorted(os.path.basename(p) for p in v) for k, v in fam.items()}


def main():
    print('== doc_type_gate 분모 편입 음성 테스트 ==')

    # 축1·축2 — 두 방식이 모두 편입되는가
    tmp = tempfile.mkdtemp(prefix='dtg_ok_')
    try:
        edd = build(tmp, with_folder=True)
        fam = run(tmp, edd)
        check('축1 형제 방식 편입 파일 수(허브+조각2)', len(fam.get('hubA.md', [])), 3)
        check('축2 폴더 방식 편입 파일 수(허브+조각2)', len(fam.get('hubB.md', [])), 3)
        check('축3 폴더 내 비대상 확장자 제외(notes.txt)',
              'notes.txt' in fam.get('hubB.md', []), False)
        check('축4 폴더 조각 파일명 정확', fam.get('hubB.md', []),
              ['hubB-001.md', 'hubB-002.md', 'hubB.md'])
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # 축5(오염) — 폴더를 없애면 허브 1개로 떨어지는가(= 수정 전 상태의 재현)
    tmp = tempfile.mkdtemp(prefix='dtg_bad_')
    try:
        edd = build(tmp, with_folder=False)
        fam = run(tmp, edd)
        check('축5 오염(폴더 부재) → 허브 1개로 떨어진다', len(fam.get('hubB.md', [])), 1)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # 축6 — `_조각` 접미가 없는 유사 폴더는 편입하지 않는다(R1-6-10 접미 규약)
    tmp = tempfile.mkdtemp(prefix='dtg_suffix_')
    try:
        edd = build(tmp, with_folder=True, folder_name='hubB_parts')
        fam = run(tmp, edd)
        check('축6 `_조각` 접미 없는 폴더는 미편입', len(fam.get('hubB.md', [])), 1)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # 축7 — 실물 회귀: 99_NEXT_SESSION 이 허브 1개로 세어지지 않는가
    fam_real = dtg.actual_docs()
    real = len(fam_real.get('99_NEXT_SESSION.md', []))
    global ASSERTS
    ASSERTS += 1
    if real <= 1:
        FAILS.append('축7 실물 회귀 — 99_NEXT_SESSION 분모가 %d 개다(조각 미편입)' % real)
        print('  🔴 축7 실물 회귀 — 99_NEXT_SESSION 분모 %d 개(조각 미편입)' % real)
    else:
        print('  🟢 축7 실물 회귀 — 99_NEXT_SESSION 분모 %d 개(조각 편입됨)' % real)

    print('---')
    print('단정 %d건 · 실패 %d건' % (ASSERTS, len(FAILS)))
    if FAILS:
        print('🔴 FAIL')
        for f in FAILS:
            print('  - ' + f)
        return 1
    print('🟢 PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main())
