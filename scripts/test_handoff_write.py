#!/usr/bin/env python3
"""음성 테스트 — 인수인계 **라벨 파일** 규격(`R1-6-27` · O172).

🔴🔴 **왜 이 테스트가 있나**(`R3-2`): 이 세션이 만든 것은 「판정식을 파일명으로 옮기는 설계」다.
  설계가 옳아도 **경계 판정**(무엇이 조각이고 무엇이 아닌가)이 틀리면 조용히 어긋난다 —
  실제로 이 워크스페이스는 같은 폴더의 조각 수를 **35(`split_doc`) ↔ 36(`doc_census`)** 으로
  다르게 세고 있었고 아무 게이트도 그것을 신고하지 않았다.

🔴 **축은 여기 세지 않는다**(`R1-5`·`R3-2` — 수를 적으면 stale 이 된다). 각 `axis()` 가 스스로 센다.
🟢 **격리** = 실제 문서를 건드리지 않는다. `tempfile` 로 가짜 허브·조각·라벨을 만들고
  `doc_census.ROOT` 를 그 폴더로 바꿔 끼운다 ⇒ 🔴 삭제 연산이 필요 없다(`R1-7-7` 회피).
🟢 **오염 기반 축** = 분모를 일부러 더럽혀(사이드카·규격 위반 파일) **검출과 역방향 오탐을 양축 단정**한다.
🟢 **「고치기 전 구현으로 돌리면 실패」 실증** = 종전 `endswith(ext)` 판정을 재현해 **다른 값이 나오는 것**을 단정한다.
"""
import io
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import doc_census                                    # noqa: E402
import handoff_write                                 # noqa: E402

FAILS = []
NASSERT = [0]


def ok(cond, msg):
    NASSERT[0] += 1
    if not cond:
        FAILS.append(msg)
        print('  🔴 %s' % msg)


def axis(n, title):
    print('── 축%d. %s' % (n, title))


def fixture(labels=(), chunks=3, sidecar=True, stem='DOC'):
    """가짜 문서군을 만든다. 반환 = (tmpdir, 허브 상대경로, 조각 폴더명).

    🔴 `stem` 을 바꿀 수 있게 둔 이유 = 축8 은 `session_brief.label_units()` 를 **그대로 호출**해야
      한다(판정식을 테스트가 재현하면 그것이 곧 `J8`「같은 것을 다르게 재는」 결함이다)
      ⇒ 그 함수가 상수로 들고 있는 허브명(`99_NEXT_SESSION`)과 같은 이름으로 픽스처를 만든다.
    """
    d = tempfile.mkdtemp(prefix='o172_')
    outdir = '%s_조각' % stem
    os.makedirs(os.path.join(d, outdir))
    hub = os.path.join(d, '%s.md' % stem)
    io.open(hub, 'w', encoding='utf-8').write(
        '<!-- SPLIT-OUTDIR: %s -->\n# %s (허브)\n' % (outdir, stem))
    for n in range(1, chunks + 1):
        io.open(os.path.join(d, outdir, '%s-%03d.md' % (stem, n)), 'w',
                encoding='utf-8').write('<!-- BODY-BEGIN -->\n본문 %d\n' % n)
    if sidecar:
        io.open(os.path.join(d, outdir, '00_선택표.md'), 'w',
                encoding='utf-8').write('# 선택표\n')
    for name in labels:
        io.open(os.path.join(d, outdir, name), 'w', encoding='utf-8').write(
            '<!-- HANDOFF-LABEL %s -->\n## 0-TEST. 인수인계 %s\n' % (name, name))
    return d, '%s.md' % stem, outdir


def main():
    print('=' * 72)
    print('[음성 테스트] 인수인계 라벨 파일 규격 (R1-6-27 · O172)')
    print('=' * 72)
    real_root = doc_census.ROOT

    # ── 축1. 조각 열거는 패턴으로 판정한다(오염 = 사이드카 + 라벨 파일) ─────
    axis(1, '조각 열거 — 사이드카·라벨 파일은 조각이 아니다')
    d, hub, outdir = fixture(labels=('DOC-O0172-A.md', 'DOC-O0171-B.md'))
    doc_census.ROOT = d
    try:
        chunks = doc_census.chunk_paths(hub, outdir)
        names = sorted(os.path.basename(p) for p in chunks)
        ok(names == ['DOC-001.md', 'DOC-002.md', 'DOC-003.md'],
           '조각 3개만 나와야 한다 — 실제 %r' % names)
        ok(all('00_선택표' not in n for n in names), '사이드카가 조각에 섞였다')
        ok(all('-O0' not in n for n in names), '라벨 파일이 조각에 섞였다')

        # 🔴 역방향 오탐 축 — 진짜 조각은 반드시 세야 한다(분모를 좁혀 놓고 0 을 내면 그것도 결함이다)
        ok(len(chunks) == 3, '진짜 조각을 못 셌다(역방향 오탐)')

        # 🔴🔴 「고치기 전 구현으로 돌리면 실패한다」 실증 = 종전 `endswith(ext)` 판정 재현
        legacy = sorted(f for f in os.listdir(os.path.join(d, outdir))
                        if f.endswith('.md'))
        ok(len(legacy) != len(chunks),
           '종전 판정식과 값이 같다 — 이 테스트가 결함을 재현하지 못한다')
        print('     🔎 종전 %d ↔ 신 %d (차이 = 사이드카 1 + 라벨 2)'
              % (len(legacy), len(chunks)))

        # ── 축2. 라벨 파일 열거·정렬 = 발생 순서 ────────────────────────────
        axis(2, '라벨 열거 정렬 — O번호 → 접미 길이 → 접미')
        labs = [os.path.basename(p) for p in doc_census.label_paths(hub, outdir)]
        ok(labs == ['DOC-O0171-B.md', 'DOC-O0172-A.md'],
           '정렬이 발생 순서가 아니다 — %r' % labs)
    finally:
        doc_census.ROOT = real_root
        shutil.rmtree(d, ignore_errors=True)

    d, hub, outdir = fixture(labels=('DOC-O0059-Z.md', 'DOC-O0059-AA.md',
                                     'DOC-O0060-A.md'))
    doc_census.ROOT = d
    try:
        labs = [os.path.basename(p) for p in doc_census.label_paths(hub, outdir)]
        ok(labs == ['DOC-O0059-Z.md', 'DOC-O0059-AA.md', 'DOC-O0060-A.md'],
           '길이 우선 정렬이 깨졌다(`-Z` < `-AA` 여야 한다) — %r' % labs)
    finally:
        doc_census.ROOT = real_root
        shutil.rmtree(d, ignore_errors=True)

    # ── 축3. 규격 위반은 열거에서 빠진다 — 그래서 따로 세야 한다 ─────────────
    axis(3, '규격 위반 검출 — 무접미·3자리는 조용히 빠진다')
    d, hub, outdir = fixture(labels=('DOC-O0172.md', 'DOC-O172-A.md',
                                     'DOC-O0173-A.md'))
    doc_census.ROOT = d
    try:
        labs = [os.path.basename(p) for p in doc_census.label_paths(hub, outdir)]
        ok(labs == ['DOC-O0173-A.md'],
           '규격 위반이 열거에 섞였거나 정상이 빠졌다 — %r' % labs)
        rx = doc_census.label_rx('DOC', '.md')
        ok(rx.match('DOC-O0172-A.md') is not None, '정상 파일명을 거부했다')
        ok(rx.match('DOC-O0172.md') is None, '무접미를 통과시켰다')
        ok(rx.match('DOC-O172-A.md') is None, '3자리를 통과시켰다')
        ok(rx.match('DOC-O0172-a.md') is None, '소문자 접미를 통과시켰다')
        ok(rx.match('DOC-O0172-ABC.md') is None, '3자 접미를 통과시켰다')
    finally:
        doc_census.ROOT = real_root
        shutil.rmtree(d, ignore_errors=True)

    # ── 축4. 접미 시퀀스 ────────────────────────────────────────────────────
    axis(4, '접미 시퀀스 — 최초는 A · 26번째는 AA')
    ok(handoff_write.suffix_seq(0) == 'A', '최초 접미가 A 가 아니다')
    ok(handoff_write.suffix_seq(25) == 'Z', '26번째가 Z 가 아니다')
    ok(handoff_write.suffix_seq(26) == 'AA', '27번째가 AA 가 아니다')
    ok(sorted(['Z', 'AA'], key=lambda s: (len(s), s)) == ['Z', 'AA'],
       '길이 우선 정렬 규칙이 깨졌다')

    # ── 축5. 라벨 파싱 — 무접미는 거부한다(사용자 결정 ⓑ) ────────────────────
    axis(5, '라벨 파싱 — 무접미 거부 · 규격 위반 거부')
    ok(handoff_write.parse_label('O172-A') == (172, 'A'), '정상 라벨 파싱 실패')
    ok(handoff_write.parse_label('§O172-B') == (172, 'B'), '`§` 접두를 못 걷었다')
    for bad in ('O172', 'O172-', 'O172-a', '172-A', 'O172-ABC'):
        try:
            handoff_write.parse_label(bad)
            ok(False, '규격 위반 %r 을 통과시켰다' % bad)
        except SystemExit:
            ok(True, '')

    # ── 축6. session_brief — 라벨 파일이 있으면 그것이 현행이다 ──────────────
    axis(6, 'session_brief 현행 판정 — 라벨 최대값 · 취소선 무관')
    import session_brief
    d, hub, outdir = fixture(labels=('DOC-O0171-A.md', 'DOC-O0172-A.md'))
    doc_census.ROOT = d
    real_sb_root = session_brief.ROOT
    session_brief.ROOT = d
    try:
        paths = doc_census.label_paths(hub, outdir)
        ok(os.path.basename(paths[-1]) == 'DOC-O0172-A.md',
           '최대값이 현행으로 뽑히지 않았다')
        # 🔴 취소선을 넣어도 판정이 흔들리지 않아야 한다(종전 실사고 3건의 원인 축)
        p = os.path.join(d, outdir, 'DOC-O0172-A.md')
        io.open(p, 'a', encoding='utf-8').write(
            '\n## 0-OLD. ~~여기서 시작한다~~ 로 승계\n')
        paths2 = doc_census.label_paths(hub, outdir)
        ok(paths == paths2, '문면(취소선)이 파일 열거를 바꿨다 — 판정이 기재에 의존한다')
    finally:
        session_brief.ROOT = real_sb_root
        doc_census.ROOT = real_root
        shutil.rmtree(d, ignore_errors=True)

    # ── 축7. 쓰기 계약 — 덮지 않는다 · 2,000자 초과는 쓰지 않는다 ────────────
    axis(7, '쓰기 계약 — 멱등 SKIP · 줄길이 가드는 쓰기 전에 막는다')
    d, hub, outdir = fixture()
    doc_census.ROOT = d
    real_hw_root = handoff_write.ROOT
    handoff_write.ROOT = d
    handoff_write.HUB_REL = hub
    try:
        entry = os.path.join(d, 'entry.md')
        io.open(entry, 'w', encoding='utf-8').write('## 0-AAAA. 시작\n\n▣ 항목 1\n')
        rc = handoff_write.write_entry(172, 'A', entry, '2026-09-17')
        ok(rc == 0, '정상 쓰기가 실패했다')
        dst = handoff_write.label_file(172, 'A')
        ok(os.path.exists(dst), '라벨 파일이 만들어지지 않았다')
        body = io.open(dst, encoding='utf-8').read()
        ok('<!-- HANDOFF-LABEL O0172-A -->' in body, '라벨 마커가 없다')
        ok(body.rstrip().endswith('_Co-authored with CoCo_'), '서명이 없다')

        rc2 = handoff_write.write_entry(172, 'A', entry, '2026-09-17')
        ok(rc2 == 1, '이미 있는 파일을 덮으려 했다(멱등 SKIP 실패)')

        long_entry = os.path.join(d, 'long.md')
        io.open(long_entry, 'w', encoding='utf-8').write('가' * 2100 + '\n')
        rc3 = handoff_write.write_entry(172, 'B', long_entry, '2026-09-17')
        ok(rc3 == 1, '2,000자 초과 엔트리를 통과시켰다')
        ok(not os.path.exists(handoff_write.label_file(172, 'B')),
           '가드가 막았는데 파일이 생겼다 — 「쓰지 않는다」 계약 위반')

        num, suf = handoff_write.next_label(172)
        ok((num, suf) == (172, 'B'), '다음 접미가 B 가 아니다 — %r' % (suf,))
    finally:
        handoff_write.ROOT = real_hw_root
        handoff_write.HUB_REL = '99_NEXT_SESSION.md'
        doc_census.ROOT = real_root
        shutil.rmtree(d, ignore_errors=True)

    # ── 축8. 다단위 세션 — 후속 단위를 써도 앞 단위가 사라지지 않는다 ──────────
    #   🆕 🔴🔴 [O172-B 신설 · 자기결함이 이 축의 부재로 통과했다]
    #     실사고 = `label_handoff` 초판이 `paths[-1]` **한 파일만** 실어 `O172-B` 를 쓰는 순간
    #     `O172-A` 가 브리핑에서 사라졌다. 🔴 축6 은 「최대값이 뽑히는가」만 단정해 **이것을 통과시켰다.**
    #     ⇒ 🟢 판정식 = **「최대값이 맞는가」와 「그 세션 전 단위가 보이는가」는 다른 축이다.**
    axis(8, '다단위 세션 — 현행의 단위는 파일이 아니라 세션(O번호)이다')
    import session_brief
    S = '99_NEXT_SESSION'
    d, hub, outdir = fixture(labels=('%s-O0171-A.md' % S, '%s-O0172-A.md' % S,
                                     '%s-O0172-B.md' % S), stem=S)
    doc_census.ROOT = d
    real_sb_root = session_brief.ROOT
    session_brief.ROOT = d
    try:
        # 🟢 판정식을 재현하지 않고 **실제 함수**를 호출한다(`J8` 회피).
        units = [os.path.basename(p) for p in session_brief.label_units()]
        ok(units == ['%s-O0172-A.md' % S, '%s-O0172-B.md' % S],
           '현행 세션의 단위가 전건 나오지 않았다 — %r' % units)
        ok(len(units) == 2, '후속 단위를 쓰자 앞 단위가 사라졌다(초판 결함의 재발)')

        # 🔴🔴 「고치기 전 구현으로 돌리면 실패한다」 실증 = 초판 `paths[-1]` 재현
        legacy = [os.path.basename(doc_census.label_paths(hub, outdir)[-1])]
        ok(legacy != units, '초판 판정식과 결과가 같다 — 이 축이 결함을 재현하지 못한다')
        print('     🔎 초판 %r ↔ 신 %r' % (legacy, units))

        # 🔴 역방향 오탐 축 — 앞 세션(O0171)은 **승계**이므로 현행에 섞이면 안 된다
        ok('%s-O0171-A.md' % S not in units,
           'O번호가 낮은 승계 단위가 현행에 섞였다(역방향 오탐)')

        # 🟢 브리핑 §2 가 실을 항목이 **두 파일에서** 모이는가(하위 항목 축까지 확인)
        cur, subs, lines = session_brief.label_handoff()
        ok(cur is not None and cur.get('is_label'), '라벨 판정이 서지 않았다')
        ok(len(set(r for r, _n, _l in lines)) == 2,
           '본문 분모가 한 파일에 갇혔다 — 누락 대조가 오탐한다')
        ok(len(cur.get('units') or []) == 2, '브리핑에 실릴 단위 목록이 2개가 아니다')
    finally:
        session_brief.ROOT = real_sb_root
        doc_census.ROOT = real_root
        shutil.rmtree(d, ignore_errors=True)

    print('=' * 72)
    print('단정 %d건 · 실패 %d건' % (NASSERT[0], len(FAILS)))
    if FAILS:
        for f in FAILS:
            print('  🔴 %s' % f)
        print('🔴 FAIL')
        return 1
    print('🟢 PASS — 전건 통과')
    return 0


if __name__ == '__main__':
    sys.exit(main())
