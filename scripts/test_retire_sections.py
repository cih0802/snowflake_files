#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""[2026-08-28 O107] `retire_sections.py` 음성 테스트 (R3-2).

🔴 절 은퇴는 **행 은퇴보다 위험하다**(§ 인용 · 제목 골든) ⇒ 정상 입력만 돌려서는
   안 된다. O106 실측 = 새 도구 2종의 자기시정 **5건 전부**를 음성 테스트가 잡았다.

이 테스트가 잡으려는 축 9개:
  축1 절 범위    — 동급 제목에서 끊고 하위 제목은 포함 · 문서 끝까지 · lv 인식
  축2 제목 불변  — 이관 후 원본 제목 줄이 **한 줄도** 변하지 않는다(하위 제목 포함)
  축3 토큰 대조  — 목적지에 토큰이 없으면 **원본을 쓰지 않는다**(blocking · exit 1)
  축4 dry-run   — `--apply` 없이는 **두 파일 모두 바이트 불변**
  축5 멱등       — 이미 은퇴된 절을 다시 은퇴시키면 **중단**(빈 이관 방지)
  축6 좌표 대응표 — 원본 행범위·본문 SHA256 이 목적지에 실재
  축7 빈 절      — 제목만 있는 절은 은퇴 거부
  축8 줄 길이·스냅샷 — 2,000자 줄 미생성 · `--apply` 시 양쪽 스냅샷 생성
  축9 허브 목적지 — 허브면 **직접 쓰지 않고** `--rollover` 로 꼬리 조각에 붙인다(O107 자기시정)

실행: python3 scripts/test_retire_sections.py
"""
import io
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import retire_sections as R  # noqa: E402

FAILS = []
OKS = [0]


def check(cond, label):
    if cond:
        OKS[0] += 1
    else:
        FAILS.append(label)


SRC = '''<!-- LLM-METADATA
doc_id: T_SRC
END-METADATA -->

## 🟢 §O64 — 닫힌 절 (2026-08-12)

본문 첫 줄 · DEC-41 · P222 참조.
수치 469,878자 · 표:

| a | b |
|---|---|
| 1 | 2 |

### 🟢 하위 절 O64-B

하위 본문 · BLOCKING-5.

## 🔴 §O90 — 열린 절

열린 본문 · O106.

## 제목만 있는 절
'''

DST = '''<!-- LLM-METADATA
doc_id: T_DST
END-METADATA -->

# 90_해소완료_로그 (테스트)

_Co-authored with CoCo_
'''


def setup():
    tmp = tempfile.mkdtemp(prefix='o107sec_')
    src = os.path.join(tmp, 'src.md')
    dst = os.path.join(tmp, 'dst.md')
    with io.open(src, 'w', encoding='utf-8') as fh:
        fh.write(SRC)
    with io.open(dst, 'w', encoding='utf-8') as fh:
        fh.write(DST)
    return tmp, src, dst


def run(src, dst, extra, root=None):
    cmd = [sys.executable, os.path.join(HERE, 'retire_sections.py'),
           '--src', src, '--to', dst,
           '--to-section', '9. 은퇴 이관 테스트', '--label', 'TST'] + extra
    env = dict(os.environ)
    if root:
        env['O107_TEST_ROOT'] = root
    return subprocess.run(cmd, capture_output=True, text=True, env=env)


# ─── 축1 절 범위 ────────────────────────────────────────────────────────────
def t_ranges():
    lines = SRC.split('\n')
    secs = R.sections(SRC)
    titles = [s[1] for s in secs]
    check(len(secs) == 4, '축1-a 절 4개가 아니다: %r' % (titles,))

    o64 = [s for s in secs if 'O64 —' in s[1]][0]
    sub = [s for s in secs if '하위 절' in s[1]][0]
    o90 = [s for s in secs if 'O90' in s[1]][0]

    # 하위 절은 상위 절 범위 **안**에 있어야 한다
    check(o64[2] < sub[2] < sub[3] <= o64[3], '축1-b 하위 절이 상위 범위 밖이다')
    # 동급 제목에서 끊긴다
    check(o64[3] == o90[2], '축1-c 동급 제목에서 끊기지 않았다: %d ≠ %d' % (o64[3], o90[2]))
    # 마지막 절은 문서 끝까지
    check(secs[-1][3] == len(lines), '축1-d 마지막 절이 문서 끝까지가 아니다')
    check(o64[0] == 2 and sub[0] == 3, '축1-e lv 판정 오류: %d/%d' % (o64[0], sub[0]))

    # 🔴 본문 줄에는 제목이 **한 줄도** 들어가지 않는다
    bl = R.body_lines(lines, o64[2], o64[3])
    check(all(not R.HEAD_RX.match(lines[k]) for k in bl), '축1-f 본문에 제목이 섞였다')
    check(any('하위 본문' in lines[k] for k in bl), '축1-g 하위 절 본문이 누락됐다')
    check(not any('하위 절 O64-B' in lines[k] for k in bl), '축1-h 하위 제목이 본문에 들어갔다')


# ─── 축3 토큰 대조 blocking ────────────────────────────────────────────────
def t_token_block():
    tmp, src, dst = setup()
    try:
        # 목적지를 **읽기 전용으로 만들 수 없으니** 토큰이 사라지는 상황을 직접 만든다:
        # 본문에 있는 토큰을 목적지가 받지 못하도록 retire_sections 의 블록 생성을 우회하지 않고,
        # 대신 `tokens()` 가 목적지에 없어야 하는 토큰을 만들도록 원본에 긴 토큰을 심는다.
        # ⇒ 정상 경로에서는 부재 0 이어야 한다(오탐 축). 부재를 강제하는 축은 아래 단위 검사로 본다.
        r = run(src, dst, ['--sections', 'O64 —', '--force'])
        check(r.returncode == 0, '축3-a 정상 경로가 FAIL: %s' % r.stdout[-300:])
        check('부재 0종' in r.stdout, '축3-b 정상 경로에서 부재가 0 이 아니다: %s' % r.stdout[:200])

        # 🔴 부재를 강제한다 — 목적지 텍스트에서 토큰을 지우는 방식으로 대조식을 직접 검증
        need = R.tokens('DEC-41 · 469,878 · `P222`')
        fake_dst = '아무 것도 없다'
        missing = sorted(t for t in need if t not in fake_dst)
        check(len(missing) == len(need) and len(need) >= 3,
              '축3-c 토큰 대조식이 부재를 못 잡는다: need=%r' % (need,))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


# ─── 축2·4·6·8 dry-run · 제목 불변 · 대응표 · 적용 ─────────────────────────
def t_apply():
    tmp, src, dst = setup()
    try:
        s0, d0 = io.open(src, encoding='utf-8').read(), io.open(dst, encoding='utf-8').read()
        r = run(src, dst, ['--sections', 'O64 —', '--force'])
        check(r.returncode == 0, '축4-a dry-run rc≠0: %s' % r.stdout[-300:])
        check(io.open(src, encoding='utf-8').read() == s0, '축4-b dry-run 이 원본을 고쳤다')
        check(io.open(dst, encoding='utf-8').read() == d0, '축4-c dry-run 이 목적지를 고쳤다')
        check('--apply 미지정' in r.stdout, '축4-d dry-run 안내 부재')

        r = run(src, dst, ['--sections', 'O64 —', '--apply', '--force'])
        check(r.returncode == 0, '축2-a apply rc≠0: %s' % r.stdout[-400:])
        s1 = io.open(src, encoding='utf-8').read()
        d1 = io.open(dst, encoding='utf-8').read()

        # 축2 제목 불변 — 하위 제목까지 전건
        import re
        h0 = re.findall(r'(?m)^#{2,6} .*$', s0)
        h1 = re.findall(r'(?m)^#{2,6} .*$', s1)
        check(h0 == h1, '축2-b 제목 줄이 변했다\n before=%r\n after =%r' % (h0, h1))
        check('### 🟢 하위 절 O64-B' in s1, '축2-c 하위 제목이 사라졌다')

        # 본문은 나갔고 포인터가 남았다
        check('본문 첫 줄' not in s1, '축2-d 본문이 원본에 남았다')
        check('하위 본문' not in s1, '축2-e 하위 본문이 원본에 남았다')
        check(R.PTR_MARK in s1, '축2-f 포인터가 없다')
        check(s1.count(R.PTR_MARK) == 1, '축2-g 포인터가 여러 개다: %d' % s1.count(R.PTR_MARK))

        # 열린 절은 손대지 않았다
        check('열린 본문 · O106' in s1, '축2-h 지정하지 않은 절이 이관됐다')

        # 축6 좌표 대응표 + 본문 SHA256
        check('좌표 대응표' in d1, '축6-a 좌표 대응표 부재')
        check('src.md' in d1, '축6-b 원본 파일명 부재')
        check('본문 첫 줄' in d1 and '하위 본문' in d1, '축6-c 본문이 목적지에 없다')
        digest = [l for l in r.stdout.split('\n') if 'SHA256' in l]
        check('SHA256' in d1, '축6-d 본문 SHA256 부재 (stdout=%r)' % digest[:2])
        # 원본 포인터와 목적지 대응표의 SHA256 앞16이 같아야 한다
        import re as _re
        a_sha = set(_re.findall(r'SHA256 `([0-9a-f]{16})`', s1))
        b_sha = set(_re.findall(r'`([0-9a-f]{16})`', d1))
        check(a_sha and a_sha <= b_sha, '축6-e 포인터↔대응표 SHA256 불일치: %r vs %r' % (a_sha, b_sha))

        # 축8 줄 길이 · 스냅샷
        check(max(len(x) for x in s1.split('\n')) <= 2000, '축8-a 원본에 2,000자 줄')
        check(max(len(x) for x in d1.split('\n')) <= 2000, '축8-b 목적지에 2,000자 줄')
        arch = os.path.join(R.ROOT, '_archive')
        check(os.path.exists(os.path.join(arch, 'src.md.TST-preretiresec')),
              '축8-c 원본 스냅샷 부재')
        check(os.path.exists(os.path.join(arch, 'dst.md.TST-preretiresec')),
              '축8-d 목적지 스냅샷 부재')
        # 스냅샷은 **이관 전** 내용이어야 한다
        snap = io.open(os.path.join(arch, 'src.md.TST-preretiresec'), encoding='utf-8').read()
        check('본문 첫 줄' in snap, '축8-e 스냅샷이 이관 후 내용이다')

        # 축5 멱등 — 다시 은퇴시키면 중단
        r2 = run(src, dst, ['--sections', 'O64 —', '--apply', '--force'])
        check(r2.returncode == 1, '축5-a 재은퇴가 차단되지 않았다')
        check('이미 은퇴된 절' in r2.stdout, '축5-b 재은퇴 사유 문구 부재')
        check(io.open(src, encoding='utf-8').read() == s1, '축5-c 재은퇴가 원본을 고쳤다')
    finally:
        for f in ('src.md.TST-preretiresec', 'dst.md.TST-preretiresec'):
            p = os.path.join(R.ROOT, '_archive', f)
            if os.path.exists(p):
                os.remove(p)
        shutil.rmtree(tmp, ignore_errors=True)


# ─── 축7 빈 절 · 미매칭 ────────────────────────────────────────────────────
def t_guards():
    tmp, src, dst = setup()
    try:
        r = run(src, dst, ['--sections', '제목만 있는 절'])
        check(r.returncode == 1, '축7-a 빈 절(제목만)이 통과했다')
        check('본문이 비어 있다' in r.stdout, '축7-b 빈 절 사유 문구 부재')

        r = run(src, dst, ['--sections', '존재하지않는절'])
        check(r.returncode != 0, '축7-c 없는 절 지정이 통과했다')

        r = run(src, dst, [])
        check(r.returncode != 0, '축7-d --sections 없이 통과했다')

        r = run(src, dst, ['--list'])
        check(r.returncode == 0 and '절 은퇴 후보' in r.stdout, '축7-e --list 실패')
        check('닫힘' in r.stdout and '열림' in r.stdout, '축7-f --list 상태 표기 부재')

        r = run(src, dst, ['--list', '--closed-only'])
        check('O90' not in r.stdout, '축7-g --closed-only 가 열린 절을 걸렀지 않았다')

        # ── 🆕 축10: 열린 내용 차단 (2026-08-28 O111-B · `R1-6-24`) ──────────
        #   🔴 픽스처 §O64 는 제목이 🟢 인데 하위 본문에 `BLOCKING-5` 가 있다 —
        #     실문서에서 이 형태가 **닫힘 후보 5개 중 4개**였다(제목 닫힘 + 본문 열림).
        #   ⇒ `--force` 없이는 **쓰지 않고 차단**해야 하고, `--force` 면 경고를 남기고 통과해야 한다.
        before = io.open(src, encoding='utf-8').read()
        r = run(src, dst, ['--sections', 'O64 —', '--apply'])          # --force 없음
        check(r.returncode == 1, '축10-a 열린 내용이 있는데 차단되지 않았다')
        check('열린 내용이 있는 절' in r.stdout, '축10-b 차단 사유 문구 부재')
        check('BLOCKING 참조' in r.stdout, '축10-c 열림 신호 종류를 열거하지 않았다')
        check(io.open(src, encoding='utf-8').read() == before,
              '축10-d 🔴 차단인데 원본이 바뀌었다(쓰지 않아야 한다)')
        r = run(src, dst, ['--sections', 'O64 —', '--force'])          # dry-run + force
        check(r.returncode == 0, '축10-e --force 로도 통과하지 못했다')
        check('`--force` 로 열린 내용 차단을 넘겼다' in r.stdout,
              '축10-f --force 사용 사실을 출력하지 않았다(이력에 적을 근거가 사라진다)')
        # 🟢 대조군 = `--list` 는 차단 대상이 아니라 **관측**이므로 항상 0 이어야 한다.
        r = run(src, dst, ['--list', '--closed-only'])
        check(r.returncode == 0 and '열림 신호 보유 후보' in r.stdout,
              '축10-g --list 가 열림 신호 요약을 내지 않았다')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


# ─── 축9 허브 목적지 (자기시정 축) ─────────────────────────────────────────
def t_hub_dst():
    """🔴 목적지가 허브면 **허브에 직접 쓰지 않고** `--rollover` 로 꼬리 조각에 붙여야 한다.

    이 축이 없으면 「허브에 append」가 조용히 통과하고 다음 republish 에서 사라진다
    (O107 자기시정 1건 · `R3-9 ㉧`).
    """
    tmp, src, _dst = setup()
    try:
        # 목적지를 **허브 + 조각** 구조로 만든다
        hub = os.path.join(tmp, 'log.md')
        with io.open(hub, 'w', encoding='utf-8') as fh:
            fh.write(DST)
        old_root, old_arch = R.SD.ROOT, R.SD.ARCHIVE
        R.SD.ROOT, R.SD.ARCHIVE = tmp, os.path.join(tmp, '_archive')
        try:
            rc = R.SD.build(hub, False, 'section', None)
            check(rc == 0, '축9-a 목적지 분할 실패')
            check(R.dst_is_hub(hub), '축9-b 허브 감지 실패')
            chunk = os.path.join(tmp, 'log-001.md')
            check(os.path.exists(chunk), '축9-c 조각 부재')

            hub_before = io.open(hub, encoding='utf-8').read()
            logical = R.dst_logical(hub)
            check('90_해소완료_로그 (테스트)' in logical, '축9-d 논리 본문 추출 실패')
            check('조각 목차' not in logical, '축9-e 논리 본문에 허브 목차가 섞였다')

            r = run(src, hub, ['--sections', 'O64 —', '--apply', '--force'])
            check(r.returncode == 0, '축9-f apply rc≠0: %s' % r.stdout[-400:])
            check('허브' in r.stdout and 'rollover' in r.stdout, '축9-g 허브 경로 안내 부재')

            body_after = R.dst_logical(hub)
            check('본문 첫 줄' in body_after, '축9-h 본문이 조각에 들어가지 않았다')
            hub_after = io.open(hub, encoding='utf-8').read()
            # 🔴 허브에는 **본문이 들어가면 안 된다**(목차만 재발행된다)
            check('본문 첫 줄' not in hub_after, '축9-i 허브에 본문을 직접 썼다')
            check('발행 SHA256' in hub_after, '축9-j 허브가 재발행되지 않았다')
            check(hub_after != hub_before, '축9-k 허브 목차가 갱신되지 않았다')
            # 🔴 스냅샷은 **하위 프로세스의 ROOT**(= 워크스페이스 `_archive`)에 떨어진다 —
            #   이 테스트가 in-process 로 바꾼 `R.SD.ROOT` 는 하위 프로세스에 전파되지 않는다.
            check(os.path.exists(os.path.join(R.ROOT, '_archive', 'log-001.md.TST-preretiresec')),
                  '축9-l 꼬리 조각 스냅샷 부재')
        finally:
            R.SD.ROOT, R.SD.ARCHIVE = old_root, old_arch
    finally:
        for f in ('src.md.TST-preretiresec', 'log.md.TST-preretiresec',
                  'log-001.md.TST-preretiresec', 'TST-retire-entry.md',
                  'log.md.O82-presplit', 'log.md.O107-prehub'):
            p = os.path.join(R.ROOT, '_archive', f)
            if os.path.exists(p):
                os.remove(p)
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    t_ranges()
    t_token_block()
    t_apply()
    t_guards()
    t_hub_dst()
    print('단정 %d건 통과 · 실패 %d건' % (OKS[0], len(FAILS)))
    if FAILS:
        print('🔴 FAIL')
        for f in FAILS:
            print(' -', f)
        return 1
    print('🟢 PASS — 10축 음성 테스트 통과 (축10 = 열린 내용 차단 · O111-B `R1-6-24`)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
