#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""[2026-08-28 O107] `split_doc.py` 조각 선택표 음성 테스트 (R3-2 · 착수표 ⑥ 선례 상속).

🔴 왜 음성 테스트인가: O106 이 만든 도구 2종에서 자기시정 **5건**이 나왔고 **전부**
   음성 테스트가 잡았다(정상 입력만 돌려서는 하나도 발견되지 않았다).
   ⇒ 새 게이트·생성기는 **실패 케이스로 먼저 때린다**(`R3-2` · 선례 = `test_doc_census.py`).

이 테스트가 잡으려는 축 7개:
  축1 제목 추출 — 인용 접두(`> ####`)·표 중간 시작 조각·제목 0개 조각
  축2 ID 추출  — 오탐(조문 `R1-3-7`·날짜 `2026-08-28`·`SPONSORSHIP_SK`) 과 정탐(`DEC-41`·`O59-G`)
  축3 캡·절단  — 캡 초과 시 「… 외 N건」 실재 · 제목 TITLE_MAX 절단
  축4 한 줄 길이 — 항목이 많아도 **2,000자 줄이 생기지 않는다**(R1-5 가드)
  축5 표 무해성 — 선택표가 마크다운 표를 깨지 않는다(`|` 를 항목에 넣지 않는다)
  축6 republish 무해성 — 허브만 다시 쓰고 **조각은 바이트 불변**이며 concat 해시가 보존된다
  축7 이어짐 귀속 — 제목 0개 조각을 「(이어짐) 앞 절」로 적고, **문서 첫 구간에는 창작하지 않는다**

실행: python3 scripts/test_split_doc_toc.py
"""
import io
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import split_doc as S  # noqa: E402

FAILS = []
OKS = [0]


def check(cond, label):
    if cond:
        OKS[0] += 1
    else:
        FAILS.append(label)


def L(text):
    return text.split('\n')


# ─── 축1 제목 추출 ──────────────────────────────────────────────────────────
def t_titles():
    lines = L('| a | b |\n|---|---|\n| 1 | 2 |\n## 절 하나\n본문\n### 절 둘\n> #### 인용 제목')
    got = S.titles_in(lines, 0, len(lines))
    check(got == ['절 하나', '절 둘', '인용 제목'],
          '축1-a 제목 3종 추출 실패: %r' % (got,))

    # 제목이 0개인 구간(= 「제목 없는 선두 구간」의 원인) — 빈 목록이어야 한다
    check(S.titles_in(lines, 0, 3) == [], '축1-b 제목 0개 구간이 비지 않았다')

    # 표 구분자를 제목에 넣으면 표가 깨진다 ⇒ `/` 로 치환돼야 한다
    check('|' not in S.clean_title('## a | b'), '축1-c 제목의 `|` 가 남았다')

    # TITLE_MAX 절단 + 말줄임 표시
    long_t = '## ' + ('가' * 200)
    ct = S.clean_title(long_t)
    check(len(ct) == S.TITLE_MAX and ct.endswith('…'),
          '축1-d 제목 절단 실패: len=%d' % len(ct))

    # 중복 제목은 1회만
    dup = L('## 같은 절\n본문\n## 같은 절')
    check(S.titles_in(dup, 0, len(dup)) == ['같은 절'], '축1-e 중복 제목이 두 번 실렸다')


# ─── 축7 이어짐 귀속 (①의 본체) ────────────────────────────────────────────
def t_carryover():
    doc = L('## §1 대시보드\n\n| a |\n|---|\n| 1 |\n| 2 |\n| 3 |\n## §2 결정\n본문')
    # 표 중간에서 시작하는 조각(5~7행) — 제목이 0개이므로 「이어짐」이어야 한다
    check(S.enclosing_title(doc, 4) == '§1 대시보드',
          '축7-a 이어지는 절 귀속 실패: %r' % (S.enclosing_title(doc, 4),))
    lab = S.head_label(doc, 4, 7)
    check(lab == '(이어짐) §1 대시보드', '축7-b 선두 절 셀이 「이어짐」이 아니다: %r' % lab)

    # 🔴 문서 첫 구간은 이어질 절이 없다 — 「이어짐」을 창작하면 거짓이 된다
    check(S.enclosing_title(doc, 0) is None, '축7-c 문서 첫 구간에 이어짐을 창작했다')
    check(S.head_label(doc, 1, 3) == '(이어짐) §1 대시보드', '축7-d 앞 절 귀속 실패')
    check(S.head_label(doc, 0, 1) == '§1 대시보드', '축7-e 제목이 있는 조각 라벨 오류')

    # 🔴 종전 문구가 남아 있으면 ① 이 해결되지 않은 것이다
    check('(제목 없는 선두 구간)' not in S.head_label(doc, 4, 7),
          '축7-f 종전 「제목 없는 선두 구간」 문구가 남았다')

    # 가장 가까운 앞 제목이어야 한다(문서 최상단 제목이 아니다)
    check(S.enclosing_title(doc, 8) == '§2 결정',
          '축7-g 가장 가까운 앞 제목이 아니다: %r' % (S.enclosing_title(doc, 8),))


# ─── 축2 ID 추출 (오탐이 본체다) ────────────────────────────────────────────
def t_ids():
    text = ('`R1-3-7` 과 `R4-4-1` 은 조문이다. 날짜 2026-08-28 · 수치 469,878자.\n'
            'FME.SPONSORSHIP_SK · TM_MM_FDRM_MBER_SPNSR · COMPUTE_WH\n'
            'DEC-41 · P222 · O59-G · O106 · Q12 · BLOCKING-5 · AD1\n')
    got = S.ids_in(L(text), 0, 3)

    for want in ('DEC-41', 'P222', 'O59-G', 'O106', 'Q12', 'BLOCKING-5'):
        check(want in got, '축2-a 정탐 누락: %s (got=%r)' % (want, got))

    # 🔴 오탐 축 — 조문 번호는 이슈 ID 가 아니다
    for bad in ('R1-3', 'R1-3-7', 'R4-4-1'):
        check(bad not in got, '축2-b 조문 번호를 ID 로 오탐: %s' % bad)

    # 🔴 오탐 축 — 식별자 내부(`SPONSORSHIP_SK` 의 `P`·`_SK`)·날짜 조각을 물지 않는다
    for bad in ('P2026', 'O8_', 'P_SK'):
        check(bad not in got, '축2-c 식별자 내부 오탐: %s' % bad)
    check(not [g for g in got if g.startswith('P') and len(g) > 6],
          '축2-d 비정상적으로 긴 P-ID 오탐: %r' % (got,))

    # 정렬 = 접두 → 숫자(문자열 정렬이면 O106 < O59 로 어긋난다)
    order = S.ids_in(L('O106 O59 O9'), 0, 1)
    check(order == ['O9', 'O59', 'O106'], '축2-e 숫자 정렬 실패: %r' % (order,))


# ─── 축3·4 캡 · 줄 길이 ────────────────────────────────────────────────────
def t_wrap():
    many = ['O%d' % k for k in range(1, 200)]
    out = S.wrap_items('- ID: ', many, 80)
    joined = '\n'.join(out)
    check('… 외 **119건**' in joined, '축3-a 캡 초과 표기(… 외 N건) 부재: %r' % (out[-1][-40:],))
    check(max(len(x) for x in out) <= 2000, '축4-a 2,000자 초과 줄 발생')

    # 🔴 캡 이내라도 **soft 를 넘으면 줄을 나눠야 한다** — 캡만으로는 줄 길이가 담보되지 않는다
    #   (`O1`…`O199` 는 캡 80 이면 566자로 한 줄에 들어간다 ⇒ 캡 ≠ 줄 길이 가드).
    wide = S.wrap_items('- ID: ', many, 199)
    check(len(wide) > 1, '축3-b soft 초과인데 한 줄에 몰렸다(%d자)' % max(len(x) for x in wide))
    check(max(len(x) for x in wide) <= 2000, '축4-a2 2,000자 초과 줄 발생')
    check(max(len(x) for x in wide) <= S.PICK_LINE_SOFT + 40,
          '축4-b soft 한도를 크게 넘겼다: %d' % max(len(x) for x in wide))

    # 장문 제목 30개(캡 이내)도 나뉘어야 한다
    longs = S.wrap_items('- 절: ', ['가' * 60] * 1 + ['나' * 60] * 29, 30)
    check(len(longs) > 1, '축3-b2 장문 제목 30개가 한 줄에 몰렸다')
    check(max(len(x) for x in longs) <= S.PICK_LINE_SOFT + 70,
          '축4-b2 장문 제목 줄이 soft 를 크게 넘겼다: %d' % max(len(x) for x in longs))

    check(S.wrap_items('- 절: ', [], 30) == ['- 절: (없음)'], '축3-c 빈 목록 표기 실패')
    # 캡 이내면 「… 외」가 없어야 한다(있으면 「전량이 아니다」로 오해된다)
    check('외 **' not in '\n'.join(S.wrap_items('- ID: ', ['O1', 'O2'], 80)),
          '축3-d 캡 이내인데 잔여 표기가 붙었다')


# ─── 축5·6 실제 문서로 왕복 ────────────────────────────────────────────────
DOC = '''<!-- LLM-METADATA
doc_id: TEST_DOC
END-METADATA -->

## 1. 상태 대시보드

| 라벨 | 표제 | 상태 |
|---|---|---|
| `O106` | 개편 | 🟢 |
| `O59-G` | 이력 | 🟢 |

## 2. 결정

DEC-41 로 닫았다. 조문 `R1-3-7` 은 그대로다.

### 2-1. 잔여

P222 · BLOCKING-5 · Q12 참조.
'''


def t_roundtrip():
    tmp = tempfile.mkdtemp(prefix='o107_')
    try:
        src = os.path.join(tmp, 'T_문서.md')
        with io.open(src, 'w', encoding='utf-8') as fh:
            fh.write(DOC)
        old_root, old_archive = S.ROOT, S.ARCHIVE
        S.ROOT, S.ARCHIVE = tmp, os.path.join(tmp, '_archive')
        try:
            rc = S.build(src, False, 'section', None)
            check(rc == 0, '축6-a build 가 FAIL: rc=%d' % rc)

            hub = S.read_text(src)
            check('## 조각 선택표' in hub, '축5-a 선택표 절이 허브에 없다')
            for want in ('DEC-41', 'P222', 'BLOCKING-5', 'Q12', 'O106', 'O59-G'):
                check(want in hub, '축5-b 허브 선택표에 ID 누락: %s' % want)
            check('R1-3-7' not in hub.split('## 조각 선택표')[1],
                  '축5-c 선택표에 조문 번호가 실렸다')
            check('1. 상태 대시보드' in hub and '2-1. 잔여' in hub,
                  '축5-d 선택표에 절 제목 누락')

            # 축5 표 무해성 — 허브의 표 열수가 정합해야 한다
            bad = _col_violations(hub)
            check(not bad, '축5-e 허브 표 열수 결손: %r' % (bad[:3],))
            check(max(len(x) for x in hub.split('\n')) <= 2000, '축4-c 허브에 2,000자 줄')

            # 축6 republish — 조각 바이트 불변 + concat 해시 보존
            paths = [S.chunk_path(src, k) for k in range(1, 99)]
            paths = [p for p in paths if os.path.exists(p)]
            before = {p: S.read_text(p) for p in paths}
            h_before = S.sha('\n'.join(S.collect_bodies(src, None)[0]))
            rc = S.republish(src)
            check(rc == 0, '축6-b republish 가 FAIL: rc=%d' % rc)
            after = {p: S.read_text(p) for p in paths}
            check(before == after, '축6-c republish 가 조각을 변경했다')
            h_after = S.sha('\n'.join(S.collect_bodies(src, None)[0]))
            check(h_before == h_after, '축6-d 본문 해시가 바뀌었다')
            check('발행 SHA256' in S.read_text(src), '축6-e 발행 라벨 미기록')
            # 🔴 [2026-08-28 O109] 스냅샷 이름의 세션 라벨이 **인자화**됐다 —
            #   라벨 미지정 시 `snapshot_util.LABEL_FALLBACK`(UNLABELED) 이 쓰인다.
            snap_p = os.path.join(S.ARCHIVE, 'T_문서.md.UNLABELED-prehub')
            check(os.path.exists(snap_p), '축6-f 재작성 전 허브 스냅샷이 없다')
            # 🔴 되돌림 스냅샷이 **재작성 전** 내용이어야 한다(후를 저장하면 되돌림이 무의미하다)
            snap = S.read_text(snap_p)
            check('원문 SHA256' in snap, '축6-g 스냅샷이 재작성 후 내용이다')
        finally:
            S.ROOT, S.ARCHIVE = old_root, old_archive
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def _col_violations(text):
    """허브 표의 열수 결손(선택표가 표를 깨지 않았는지)."""
    import split_issue_index as SI
    bad, hdr = [], None
    for n, l in enumerate(text.split('\n'), 1):
        s = l.strip()
        if not s.startswith('|'):
            hdr = None
            continue
        if set(s.replace('|', '').replace('-', '').replace(':', '').strip()) == set():
            continue
        try:
            got = len(SI.split_row(s))
        except AssertionError:
            continue
        if hdr is None:
            hdr = got
            continue
        if got != hdr:
            bad.append('%d행 %d열(헤더 %d열)' % (n, got, hdr))
    return bad


# ─── 축8 폴더 이전(--to-outdir) ─────────────────────────────────────────────
def t_to_outdir():
    """🔴 이전은 **삭제를 포함**한다 ⇒ 「바이트 동일 확인 전에는 안 지운다」를 테스트가 고정한다."""
    tmp = tempfile.mkdtemp(prefix='o107out_')
    try:
        src = os.path.join(tmp, 'T_이전.md')
        with io.open(src, 'w', encoding='utf-8') as fh:
            fh.write(DOC)
        old_root, old_archive = S.ROOT, S.ARCHIVE
        S.ROOT, S.ARCHIVE = tmp, os.path.join(tmp, '_archive')
        try:
            check(S.build(src, False, 'section', None) == 0, '축8-a 사전 분할 실패')
            before = S.sha('\n'.join(S.collect_bodies(src, None)[0]))
            sib = [p for p in (S.chunk_path(src, k) for k in range(1, 9)) if os.path.exists(p)]
            check(len(sib) >= 1, '축8-b 형제 조각 부재')

            # 🔴 `_조각` 접미 없는 폴더명은 거부해야 한다(R1-6-10 실사고)
            rc = S.to_outdir(src, 'T_이전', apply=True)
            check(rc == 1, '축8-c `_조각` 접미 없는 폴더명이 통과했다')
            check(not os.path.isdir(os.path.join(tmp, 'T_이전')), '축8-d 거부했는데 폴더를 만들었다')
            check(all(os.path.exists(p) for p in sib), '축8-e 거부했는데 형제를 지웠다')

            # dry-run 은 아무것도 쓰지 않는다
            rc = S.to_outdir(src, 'T_이전_조각', apply=False)
            check(rc == 0, '축8-f dry-run rc≠0')
            check(not os.path.isdir(os.path.join(tmp, 'T_이전_조각')), '축8-g dry-run 이 폴더를 만들었다')
            check(all(os.path.exists(p) for p in sib), '축8-h dry-run 이 형제를 지웠다')

            # 실제 이전 — 🔴 2단계 분리(1단계는 복사만)
            rc = S.to_outdir(src, 'T_이전_조각', apply=True)
            check(rc == 0, '축8-i 1단계 rc≠0')
            check(all(os.path.exists(p) for p in sib), '축8-j1 1단계가 형제를 지웠다')
            check(S.hub_outdir(src) is None, '축8-j2 1단계가 마커를 바꿨다')
            snap_p = os.path.join(S.ARCHIVE, 'T_이전.md.UNLABELED-pretooutdir')
            check(os.path.exists(snap_p), '축8-j3 1단계 스냅샷이 없다')
            snap = S.read_text(snap_p)
            check(S.sha(snap) == before, '축8-j4 스냅샷이 이전 전 논리 문서가 아니다')

            # 🔴 선행 해시 대조 — 조각을 고치고 재발행하지 않으면 **거부**해야 한다
            c1 = S.chunk_path(src, 1)
            keep = S.read_text(c1)
            S.write_text(c1, keep + '\n추가된 줄(미재발행)\n')
            rc = S.to_outdir(src, 'T_이전_조각', apply=True, drop=True)
            check(rc == 1, '축8-k1 미재발행 편집 상태에서 2단계가 통과했다')
            check(all(os.path.exists(p) for p in sib), '축8-k2 거부했는데 형제를 지웠다')
            S.write_text(c1, keep)          # 원복

            # 2단계 — 해시 3자 일치 후 삭제
            rc = S.to_outdir(src, 'T_이전_조각', apply=True, drop=True)
            check(rc == 0, '축8-l1 2단계 rc≠0')
            check(not any(os.path.exists(p) for p in sib), '축8-l2 형제가 남았다')
            after = S.sha('\n'.join(S.collect_bodies(src, 'T_이전_조각')[0]))
            check(before == after, '축8-m 본문 해시가 바뀌었다')
            hub = S.read_text(src)
            check('SPLIT-OUTDIR: T_이전_조각' in hub, '축8-n 허브 마커 미기록')
            check('T_이전_조각/T_이전-001.md' in hub, '축8-o 허브 목차 경로가 폴더로 안 바뀌었다')
            check(S.hub_outdir(src) == 'T_이전_조각', '축8-p hub_outdir 판정 실패')

            # 🔴 멱등 — 이미 폴더면 재이전을 거부한다
            check(S.to_outdir(src, 'T_이전_조각', apply=True) == 1, '축8-q 재이전이 차단되지 않았다')

            # 🔴 doc_census 가 마커를 따라야 한다(선언이 sibling 이어도)
            import doc_census as C
            old_croot = C.ROOT
            C.ROOT = tmp
            try:
                paths = C.chunk_paths('T_이전.md', 'sibling')
                check(len(paths) >= 1 and all('T_이전_조각' in p for p in paths),
                      '축8-r chunk_paths 가 마커를 안 따랐다: %r' % (paths,))
            finally:
                C.ROOT = old_croot
        finally:
            S.ROOT, S.ARCHIVE = old_root, old_archive
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    t_titles()
    t_carryover()
    t_ids()
    t_wrap()
    t_roundtrip()
    t_to_outdir()
    print('단정 %d건 통과 · 실패 %d건' % (OKS[0], len(FAILS)))
    if FAILS:
        print('🔴 FAIL')
        for f in FAILS:
            print(' -', f)
        return 1
    print('🟢 PASS — 8축 음성 테스트 통과')
    return 0


if __name__ == '__main__':
    sys.exit(main())
