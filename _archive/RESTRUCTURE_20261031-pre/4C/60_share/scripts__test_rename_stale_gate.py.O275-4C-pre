#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""test_rename_stale_gate.py — `rename_stale_gate.py` 음성 테스트.

[2026-09-10 O155 신설 · `R3-2` = 게이트를 만들면 음성 테스트를 같이 만든다]

🔴 왜 음성 테스트인가
--------------------------------------------------------------------------
「고친 뒤 통과」는 증거가 아니다. **고치기 전 코드에서 반드시 실패하는 축**이 있어야
그 게이트가 결함을 본다는 증거가 된다(11번 문서 §성공 판정식).

이 파일은 게이트가 **놓쳤던 실물 4종**을 회귀 축으로 고정한다:
* 축2 `(구 FACT_SERVICE_EVENT)` 병기 = **통과해야 한다**(O155 1차 판정식이 오탐한 형태).
* 축3 `FACT_TARGET_MEMBER_DEV` = `FACT_TARGET_DEV` 의 **부분문자열이 아니다**(경계 오탐).
* 축4 파일·라이브가 **똑같이 틀린** 경우 = `comment_drift_gate` 는 🟢 인데 이 게이트는 잡는다.
* 축6 기준선 **증가**는 FAIL · **감소**는 통과(해소 진척을 막지 않는다).
"""
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))

import rename_stale_gate as G  # noqa: E402

PASS, FAIL = [], []


def check(axis, cond, detail=''):
    (PASS if cond else FAIL).append(axis)
    sys.stdout.write('  %s %s%s\n' % ('🟢' if cond else '🔴', axis,
                                      (' — ' + detail) if detail else ''))


def main():
    sys.stdout.write('=' * 62 + '\n')
    sys.stdout.write('test_rename_stale_gate.py — 개명 잔여 게이트 음성 테스트\n')
    sys.stdout.write('=' * 62 + '\n\n')

    # ── 축1 무자격 잔여는 반드시 잡힌다 ────────────────────────────────
    line = '개발 사건 건수는 `FACT_MEMBER_LIFECYCLE` 를 쓴다.'
    m = G.RX.search(line)
    check('축1 무자격 옛 이름 검출',
          m is not None and not G.qualified(line, m.start()),
          '검출=%s' % (m.group(1) if m else None))

    # ── 축2 병기는 통과한다(O155 1차 판정식이 여기서 오탐했다) ──────────
    quals = [
        'GOLD.FACT_MESSAGE_DISPATCH(구 FACT_SERVICE_EVENT)가 죽었다.',
        '`DIM_MEMBER`(구 DIM_MEMBER_CURRENT)를 테이블로 신설하고',
        '| `FACT_TARGET_DEV` | **`FACT_TARGET_MEMBER_DEV`** | 개명 사유 |',
    ]
    okc = 0
    for q in quals:
        mm = G.RX.search(q)
        if mm and G.qualified(q, mm.start()):
            okc += 1
    check('축2 병기 3형태 전건 통과(오탐 0)', okc == len(quals),
          '통과 %d/%d' % (okc, len(quals)))

    # ── 축3 경계 — 개명 후 이름이 옛 이름으로 잡히면 안 된다 ────────────
    news = ['FACT_TARGET_MEMBER_DEV', 'FACT_MEMBER_DEV_ACHIEVEMENT',
            'FACT_MEMBER_SPONSORSHIP_SPAN', 'FACT_EVENT_ATTENDANCE',
            'FACT_MESSAGE_DISPATCH', 'FACT_MEMBER_EVENT', 'DIM_MEMBER']
    leak = [n for n in news if G.RX.search(n)]
    check('축3 개명 후 이름 오탐 0', not leak, '오탐=%s' % (leak or '없음'))

    # ── 축4 파일·라이브 동시 오류 시나리오 = 드리프트 0 인데 이 게이트는 잡는다 ─
    same = "COMMENT = 'Phase-1 회원 상태전이 SV (base: GOLD.FACT_MEMBER_LIFECYCLE)'"
    mm = G.RX.search(same)
    check('축4 드리프트 0 이어도 검출(SV COMMENT 실물)',
          mm is not None and not G.qualified(same, mm.start()),
          'O155 가 이 형태를 라이브에서 적발했다')

    # ── 축5 버킷 분류 — 이력·근거철·생성물이 축1에 섞이지 않는다 ─────────
    #: 🆕 🔴 [2026-09-16 O169] **골든·측정 스냅샷 축(`SNAPSHOT`)을 추가했다.**
    #:   🔎 근거 = 그 json 들에는 축2 의 처방(「재생성으로 해소」)이 **통하지 않았다** —
    #:      `golden/doc_headings.json` 의 옛 이름 다수가 **골든 자신의 `_updates` 감사 이력**이고,
    #:      `outputs.json` 의 다수는 **수기 문서를 복사한 측정값**이다(둘 다 재생성해도 남는다).
    #:   🔴 역방향 오탐 축도 함께 단정한다 = **진짜 생성물은 여전히 `GEN`** 이어야 한다.
    cases = [
        ('20_issue/01_세션이력_조각/01_세션이력-004.md', 'HIST'),
        ('99_NEXT_SESSION_조각/99_NEXT_SESSION-030.md', 'HIST'),
        ('20_issue/_o154_evidence.md', 'HIST'),
        ('30_output_share/02_gold 스키마 컬럼 인벤토리_20260904.csv', 'GEN'),
        ('20_issue/00_BRIEF.md', 'GEN'),
        ('30_output_share/01_DW_현업활용가이드.md', 'LIVE'),
        ('10_dbt_pipeline/models/gold/wide/WIDE_MEMBER_FEE.sql', 'LIVE'),
        # 🆕 O169 — 골든·측정 스냅샷은 소급 수정 대상이 아니다(축3 취급).
        ('scripts/golden/doc_headings.json', 'HIST'),
        ('scripts/golden/rename_stale_baseline.json', 'HIST'),
        ('scripts/outputs.json', 'HIST'),
        ('scripts/doc_headings.json', 'HIST'),
        ('scripts/index_rows.json', 'HIST'),
        # 🔴 역방향 = 재생성이 실제로 듣는 산출물은 GEN 을 유지해야 한다.
        ('30_output_share/09_보고서필드_조립가능성_x.md', 'GEN'),
        ('20_issue/92_실측필요_후속작업.md', 'GEN'),
    ]
    wrong = [(r, G.bucket(r), exp) for r, exp in cases if G.bucket(r) != exp]
    check('축5 버킷 분류 %d건 전건 일치' % len(cases), not wrong,
          '오분류=%s' % (wrong or '없음'))

    # ── 축6 기준선 증감 판정 — 증가는 FAIL · 감소는 통과 ────────────────
    #: 🔴🔴 [2026-09-16 O169 시정] 종전 구현은 증가 시나리오를 **「기준선을 현재보다 5 낮춘다」**
    #:   (`max(0, len(cur) - 5)`)로 만들었다. 그 식은 **현재가 0 이면 성립하지 않는다** —
    #:   0 보다 낮은 기준선이 없으므로 증감이 0 이 되고 rc=0 이 나온다.
    #:   실사고 = O169 가 축1 을 **68 → 0** 으로 내린 순간 이 축이 FAIL 로 뒤집혔다(게이트는 정상).
    #:   🟢 판정식 = **「현재」를 낮출 수 없으면 「현재」를 올려라** ⇒ 증가 시나리오는 기준선 0 에
    #:   **오염 파일을 주입한 임시 분모**를 붙여 만든다(감소 시나리오만 기준선을 올린다).
    #:   🟢 교훈 = **경계값 0 에서 무력해지는 단정은 목표를 달성한 날 무력해진다.**
    tmp = tempfile.mkdtemp(prefix='o155g_')
    try:
        real_bl, real_root, real_dirs = G.BASELINE, G.ROOT, G.SCAN_DIRS
        fake = os.path.join(tmp, 'baseline.json')
        cur = G.scan()[0]['LIVE']

        # 증가 시나리오 = 기준선 0 + 오염 파일 1건을 심은 임시 분모.
        poison_dir = os.path.join(tmp, 'poison')
        os.makedirs(poison_dir)
        old_name = sorted(G.RENAMES)[0]
        with io.open(os.path.join(poison_dir, 'a.md'), 'w', encoding='utf-8') as fh:
            fh.write('이 줄은 %s 를 병기 없이 쓴다\n' % old_name)
        with io.open(fake, 'w', encoding='utf-8') as fh:
            json.dump({'axis1_total': 0, 'per_file': {}}, fh)
        G.BASELINE, G.ROOT, G.SCAN_DIRS = fake, tmp, ('poison',)
        rc_up = _run_main()
        G.ROOT, G.SCAN_DIRS = real_root, real_dirs

        # 감소 시나리오 = 기준선을 현재보다 높게 둔다(실분모 그대로).
        with io.open(fake, 'w', encoding='utf-8') as fh:
            json.dump({'axis1_total': len(cur) + 5, 'per_file': {}}, fh)
        rc_down = _run_main()
        G.BASELINE = real_bl
        check('축6 증가=FAIL · 감소=통과', rc_up == 1 and rc_down == 0,
              'rc 증가=%s · 감소=%s (현재 축1=%d)' % (rc_up, rc_down, len(cur)))
    finally:
        G.BASELINE, G.ROOT, G.SCAN_DIRS = real_bl, real_root, real_dirs
        shutil.rmtree(tmp, ignore_errors=True)

    # ── 축7 기준선 부재 = FAIL(조용히 통과하지 않는다) ──────────────────
    tmp2 = tempfile.mkdtemp(prefix='o155h_')
    try:
        real = G.BASELINE
        G.BASELINE = os.path.join(tmp2, 'nope.json')
        rc_none = _run_main()
        G.BASELINE = real
        check('축7 기준선 부재 = FAIL', rc_none == 1, 'rc=%s' % rc_none)
    finally:
        shutil.rmtree(tmp2, ignore_errors=True)

    # ── 🆕 축9 [O166] 분모에 `scripts/` 가 들어 있다 ─────────────────────
    #   🔴 이 축은 **고치기 전 코드에서 반드시 실패한다**(종전 `SCAN_DIRS` 에 'scripts' 없음).
    #   실해 = 생성기 판정 등록부의 개명 잔여 343건이 검사 밖이었고 09 산출물 타원천이 전건 오판이었다.
    check('축9 SCAN_DIRS 에 scripts/ 편입', 'scripts' in G.SCAN_DIRS,
          'SCAN_DIRS=%s' % (G.SCAN_DIRS,))

    # ── 🆕 축10 [O166] scripts/ 안의 무자격 옛 이름은 실제로 검출된다 ────
    #   🔴 분모 편입만으로는 부족하다 — **스캔이 그 파일을 실제로 읽는지**를 오염 기반으로 단정한다.
    #   방법 = `scripts/` 하위에 옛 이름을 심은 임시 파일을 만들고 축1 에 잡히는지 본다.
    #   🔴 파일명에 `_o###_` 를 쓰지 마라 — `EVIDENCE` 정규식이 **근거철로 오분류**한다
    #     (O166 초판이 `_o166_probe_planted.py` 로 심어 축1 검출 0건을 받았다 · 자기시정 1).
    probe_rel = 'scripts/zzprobe_planted_gate.py'
    probe_abs = os.path.join(ROOT, probe_rel)
    try:
        with io.open(probe_abs, 'w', encoding='utf-8') as fh:
            fh.write("SRC = {'FACT_SERVICE_EVENT': 'CRM'}\n")
        live_now = G.scan()[0]['LIVE']
        caught = [h for h in live_now if h[0] == probe_rel]
        check('축10 scripts/ 심은 옛 이름 검출', len(caught) == 1,
              '검출=%d건' % len(caught))
    finally:
        if os.path.exists(probe_abs):
            os.remove(probe_abs)

    # ── 🆕 축11 [O166] 자기참조·픽스처는 축1 에 섞이지 않는다 ────────────
    #   🔴 역방향 오탐 축이다 — 대응표 파일과 음성 테스트는 **옛 이름이 있어야 정상**이다.
    self_cases = [
        ('scripts/rename_stale_gate.py', 'HIST'),
        ('scripts/test_rename_stale_gate.py', 'HIST'),
        # 🔴 [2026-09-16 O169 정정] 종전 이 줄은 `'GEN'` 을 단정했다 —
        #   `SNAPSHOT` 축 신설로 **골든·측정 스냅샷은 `HIST`** 다(축5 와 같은 판정).
        #   🟢 두 축이 같은 파일을 다르게 단정하고 있었다면 그것이 `R3-9 ㉡`(같은 것을 다르게 재는
        #   지점)이므로, 축을 늘릴 때는 **기존 축의 단정도 함께 재라.**
        ('scripts/golden/outputs.json', 'HIST'),
        ('scripts/o51d_view_comments/desc_ad.py', 'HIST'),
        ('scripts/gen_section_assembly.py', 'LIVE'),
    ]
    swrong = [(r, G.bucket(r), e) for r, e in self_cases if G.bucket(r) != e]
    check('축11 자기참조·픽스처 버킷 5건 전건 일치', not swrong,
          '오분류=%s' % (swrong or '없음'))

    # ── 🆕 축12 [O168] 「구 → 신」 화살표 병기는 자격이고, 흐름 화살표는 아니다 ──
    #   🔴 이 축이 없어서 두 결함이 동시에 났다:
    #     ㉠ 게이트 = `DIM_GA_EVENT` → `DIM_BIGQUERY_EVENT` (개명 선언)을 **위반으로 셌다**
    #     ㉡ 치환기 = `'→ '` 를 줄 마커로 써서 **흐름 화살표 90건을 개명 서술로 오인**해 건너뛰었다
    #   ⇒ 두 방향을 한 축에서 같이 단정한다(한쪽만 고치면 다른 쪽이 조용히 남는다).
    import _o166_rename_fix as FX
    pair = '1. GOLD 차원: `DIM_GA_EVENT` → `DIM_BIGQUERY_EVENT` (`BIGQUERY_EVENT_SK`)'
    flow = '| 사업목표(`CRM_BIZ_TARGET`→`FACT_TARGET_BIZ`) 데이터 입고 |'
    fk = '| `FACT_DEV_ACHIEVEMENT` → `DIM_BUDGET_ITEM` FK 부재 | 1 |'
    m1 = G.RX.search(pair)
    m2 = G.RX.search(flow)
    m3 = G.RX.search(fk)
    check('축12-㉠ 개명 화살표는 게이트 자격(위반 아님)',
          m1 is not None and G.qualified(pair, m1.start(), m1.group(1)),
          '매치=%s' % (m1 and m1.group(1)))
    check('축12-㉡ 흐름 화살표는 자격이 아니다(위반으로 남는다)',
          m2 is not None and not G.qualified(flow, m2.start(), m2.group(1)),
          '매치=%s' % (m2 and m2.group(1)))
    check('축12-㉢ 치환기가 개명 화살표 줄은 건드리지 않는다',
          FX.fix_line(pair)[1] == 0, '치환=%d' % FX.fix_line(pair)[1])
    check('축12-㉣ 치환기가 흐름 화살표 줄은 치환한다(2건)',
          FX.fix_line(flow)[1] == 1 and FX.fix_line(fk)[1] == 1,
          '흐름=%d · FK=%d' % (FX.fix_line(flow)[1], FX.fix_line(fk)[1]))
    #   🔴 콜론 병기 = `구: X` 형태. `NEAR` 가 `'구 '`·`'(구'` 만 갖고 있어 놓쳤다(실물 = dbt 테스트 주석).
    colon = '--   (구: WIDE_DEV_ACHIEVEMENT 뷰 → 구: FACT_DEV_ACHIEVEMENT → 현: X 테이블).'
    mc = [m for m in G.RX.finditer(colon)]
    check('축12-㉤ 콜론 병기 `구:` 는 자격이다',
          bool(mc) and all(G.qualified(colon, m.start(), m.group(1)) for m in mc),
          '매치 %d건' % len(mc))
    #   🔴 자기 새 이름이 아닌 이름과의 화살표는 면제 사유가 아니다(구멍 방지).
    other = '`FACT_TARGET_BIZ` → `DIM_BIGQUERY_EVENT` 로 조인한다'
    mo = G.RX.search(other)
    check('축12-㉥ 타 객체와의 화살표는 면제하지 않는다',
          mo is not None and not G.qualified(other, mo.start(), mo.group(1)),
          '매치=%s' % (mo and mo.group(1)))

    # ── 축8 CLI 무인자 실행이 rc 0/1 만 낸다(크래시 금지) ────────────────
    p = subprocess.run([sys.executable, os.path.join(ROOT, 'scripts',
                                                     'rename_stale_gate.py')],
                       cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    check('축8 CLI 크래시 0', p.returncode in (0, 1), 'rc=%d' % p.returncode)

    sys.stdout.write('\n' + '-' * 62 + '\n')
    if FAIL:
        sys.stdout.write('🔴 축 %d개 · 통과 %d · 실패 %d\n'
                         % (len(PASS) + len(FAIL), len(PASS), len(FAIL)))
        for f in FAIL:
            sys.stdout.write('   🔴 %s\n' % f)
        return 1
    sys.stdout.write('🟢 축 %d개 전건 통과\n' % len(PASS))
    return 0


def _run_main():
    """게이트 `main()` 을 인자 없이 돌려 rc 만 받는다(출력은 버린다)."""
    argv, out = sys.argv, sys.stdout
    sys.argv = ['rename_stale_gate.py']
    sys.stdout = io.StringIO()
    try:
        return G.main()
    finally:
        sys.argv, sys.stdout = argv, out


if __name__ == '__main__':
    sys.exit(main())
