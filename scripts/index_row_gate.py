#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""[2026-08-18 O82-B] 원장 표 「행 키」 보존 게이트 — `C6` 처방 · 착수표 ㉑.

🔴 왜 이 게이트가 필요한가 (실증 2건):
  ① **O76-B** 의 전체 재작성 write 가 인덱스 §1 의 「마케팅용 Agent 설계 신설」(O76) 행을
     덮어써 **소실**시키고 O76-B 행을 **중복 생성**했다.
  ② **O76-C** 의 재작성이 O82 의 「🆕 조각 분할 문서」 절과 문서맵 10행을 **조용히 지웠다**.
     그 세션은 「보존 토큰 5/5」를 단정했지만 검사한 것은 문자열 `O82` **하나**였고,
     `O82` 를 포함하지 않는 편집 2건은 그 단정을 통과해 사라졌다.

  🔴 두 사고 모두 기존 게이트 **3종이 전부 통과**시켰다:
     · `ws_stage_verify` = 크기 **패딩 비교**라 내용을 보지 않는다
     · `doc_heading_gate` = **제목 집합**만 본다 (표 행은 제목이 아니다)
     · `doc_line_length_gate` = **길이**만 본다
  ⇒ 표 **행 소실·중복**은 어느 축에도 걸리지 않았다. 이 파일이 그 축이다.

판정 방식:
  표 행의 **첫 셀**(대표 ID·문서번호·현황)을 «행 키»로 삼아 **집합**을 골든과 대조한다.
  · **유실 = FAIL** (행이 사라졌다 = 데이터 손실)
  · **중복 = FAIL** (같은 키가 2행 = O76-B 가 실제로 만든 사고)
  · **신설 = PASS** (append 는 정상 작업이다)
  값(셀 내용)은 보지 않는다 — 갱신형 원장이라 값은 매 세션 바뀐다. **행의 존재**만 본다.

사용:
  python3 scripts/index_row_gate.py                    # 게이트 (유실·중복 시 exit 1)
  python3 scripts/index_row_gate.py --update-golden    # 기준선 발행/갱신
"""
import argparse
import io
import json
import os
import re
import sys
import time
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GOLDEN = os.path.join(ROOT, 'scripts', 'golden', 'index_rows.json')

# 표 행 소실이 실제로 발생한 표면만 본다. 넓히면 P130(항상 빨간 게이트)이 된다.
TARGETS = [
    '20_issue/00_INDEX_이슈원장.md',
    '20_issue/02_상태상세_대시보드_갱신형.md',
    '20_issue/03_이슈상세.md',
    '99_NEXT_SESSION.md',
]

# 표 열수 판정은 O66 계약을 상속한다 — `|` 개수 세기는 백틱 코드스팬에서 오탐한다.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from split_issue_index import split_row  # noqa: E402

EMOJI = re.compile(
    '[\U0001F300-\U0001FAFF\u2190-\u21FF\u2600-\u27BF\uFE0F\u2B00-\u2BFF\u3030\u303D]')


def read_text(path):
    with io.open(path, encoding='utf-8') as fh:
        return fh.read()


def is_separator(s):
    return set(s.replace('|', '').replace('-', '').replace(':', '').strip()) == set()


def row_key(cell):
    """첫 셀 → 안정적인 행 키.

    장식(볼드·백틱·물결·이모지·`<br>`)을 벗겨 낸다. 갱신형 원장은 같은 행의 장식을
    자주 바꾸므로 장식을 남기면 **정상 편집이 「유실+신설」로 보인다**(오탐 경로).
    """
    s = re.sub(r'<br\s*/?>', ' ', cell)
    s = s.replace('*', '').replace('`', '').replace('~', '')
    s = EMOJI.sub(' ', s)
    return re.sub(r'\s+', ' ', s).strip()


SECTION_RX = re.compile(r'^\s*#{1,6}\s+(.*?)\s*$')

BODY_BEGIN = '<!-- BODY-BEGIN (아래는 원문 무변경 · 편집 금지) -->'


def logical_text(path):
    """허브 + 조각 본문(센티넬 아래)을 연번 순서로 이어붙인 **논리 문서**.

    🔴 [2026-08-18 O83] 조각을 **파일별로** 스캔하면 안 된다 — 표와 절 문맥이 조각
    경계를 넘어가는데 파일별 스캔은 매 파일에서 `section`·`in_table` 을 초기화하고,
    조각 머리말 3줄이 `in_table` 을 다시 꺼 버린다.
    실측 사고: 인덱스 분할 직후 §1 표의 행 **35건이 「유실」로 오탐**됐다 —
    조각 `-002` 가 §1 표의 **본문 행 중간에서 시작**해 헤더·구분행을 앞 조각에 두고
    있었기 때문이다. 같은 시점 `split_doc --verify` 의 concat SHA256 은 **일치**했으므로
    내용은 온전했고 결함은 이 게이트의 분모에 있었다(`R1-6-8` 계열의 세 번째 재발).
    ⇒ 분할 계약(`BODY-BEGIN` 센티넬 아래만 본문)을 그대로 상속해 원문을 복원한 뒤 센다.
    """
    parts = [read_text(path)]
    for c in chunk_files(path):
        t = read_text(c)
        if BODY_BEGIN + '\n' in t:
            t = t.split(BODY_BEGIN + '\n', 1)[1]
        parts.append(t)
    return '\n'.join(parts)


def collect_keys(text):
    """텍스트의 모든 표 행 키를 순서대로 돌려준다(헤더·구분행 제외).

    🔴 [2026-08-18 O83] 인자는 **경로가 아니라 텍스트**다 — 분할 문서는
    `logical_text()` 로 허브+조각을 이어붙인 뒤 **한 번에** 스캔해야 절·표 문맥이
    조각 경계를 넘어 유지된다(위 `logical_text` docstring 의 35건 오탐 사고).

    🔴 [2026-08-18 O82-C 교정] 키는 **「절 제목 ¦ 첫 셀」** 로 절 단위 한정한다.
    첫 셀만 쓰면 **한 파일 안의 서로 다른 표가 같은 키를 갖는다.** 실측 오탐:
    인덱스 §0 문서맵의 `| 02 | …` 행과 §0 조각분할표의 `| 02 | …` 행이 **중복 5건**으로
    잡혀 게이트가 실패했다(02·03·20·30·50). 두 행은 **다른 표의 다른 행**이다.
    ⇒ 절 제목으로 한정하면 표가 구분되고, 절 제목이 바뀌면 `doc_heading_gate` 가 잡는다
    (두 게이트의 축이 겹치지 않게 나뉘어 있다).
    """
    keys = []
    in_table = False
    section = '(머리말)'
    for line in text.split('\n'):
        m = SECTION_RX.match(line)
        if m:
            section = ' '.join(m.group(1).split())[:60]
            in_table = False
            continue
        s = line.strip()
        if not s.startswith('|'):
            in_table = False
            continue
        if is_separator(s):
            in_table = True          # 구분행 다음부터가 본문 행이다
            continue
        if not in_table:
            continue                 # 헤더 행은 키가 아니다
        try:
            cells = split_row(s)
        except AssertionError:
            continue
        k = row_key(cells[0]) if cells else ''
        if k:
            keys.append('%s ¦ %s' % (section, k))
    return keys


def chunk_files(path):
    """[2026-08-18 O82-C] 허브로 분할된 문서의 조각 파일 목록(연번 순).

    🔴 왜 필요한가: `split_doc.py` 가 `02`·`03`·`99_NEXT` 를 허브 + 조각으로 나누면
    **표 행이 전부 조각으로 이동**한다. 이 게이트의 분모는 허브만 보므로 확장하지 않으면
    **행 448개가 「유실」로 대량 오탐**되고 정상 분할이 막힌다.
    ⇒ `R1-6-8`(제목 게이트에서 같은 사고가 이미 났다)의 이 게이트판 선제 적용이다.
    """
    base, ext = os.path.splitext(path)
    out = []
    n = 1
    while True:
        c = '%s-%03d%s' % (base, n, ext)
        if not os.path.exists(c):
            break
        out.append(c)
        n += 1
    if out:
        return out
    # [2026-08-18 O83] 폴더 분할(`split_doc.py --outdir`) 대응 — 형제가 없으면 폴더를 본다.
    #   🔴 이 분기가 없으면 폴더로 나눈 문서의 표 행이 **전량 유실로 오탐**된다.
    #   같은 축의 사고가 형제 방식에서 이미 448행 규모로 났다(위 docstring).
    #   🔴 폴더명은 **추측하지 않고** 허브의 `<!-- SPLIT-OUTDIR: … -->` 마커에서 읽는다
    #   (stem 추측판이 실제 폴더명과 달라 제목 게이트에서 104건+ 오탐이 실제로 났다).
    m = re.search(r'<!--\s*SPLIT-OUTDIR:\s*(.+?)\s*-->', read_text(path))
    if not m:
        return out
    d = os.path.join(os.path.dirname(path), m.group(1).strip())
    if os.path.isdir(d):
        n = 1
        while True:
            c = os.path.join(d, '%s-%03d%s' % (os.path.basename(base), n, ext))
            if not os.path.exists(c):
                break
            out.append(c)
            n += 1
    return out


def collect():
    cur = {}
    for t in TARGETS:
        p = os.path.join(ROOT, t)
        if not os.path.exists(p):
            cur[t] = None
            continue
        keys = collect_keys(logical_text(p))
        cur[t] = keys
    return cur


# 🔴 [2026-08-18 O83-B] 허브의 **자동 생성 표**는 행 키 골든 축에서 제외한다.
#   이유: `--rebalance` 는 조각 경계를 **의도적으로** 바꾸므로 「구 행범위」 값이 함께 바뀐다
#   (실측: `1~288` → `1~187`) ⇒ 골든 대비 **유실 5건**으로 FAIL 했다(오탐).
#   이 표들은 손으로 유지하는 원장 행이 아니라 도구가 매번 재생성하는 파생물이고,
#   무결성은 `split_doc --verify` 게이트1(concat SHA256)이 이미 보증한다.
#   ⇒ 이 게이트는 **사람이 쓰는 원장 행**만 지킨다(축이 겹치면 정상 작업이 막힌다 · `R1-6-8`).
GENERATED_SECTIONS = ('조각 목차', '구 행번호 → 신 좌표 대응표')


def is_generated(key):
    """행 키가 허브 자동 생성 표의 것인가. 키 형식 = `절 제목 ¦ 첫 셀`."""
    sec = key.split(' ¦ ', 1)[0].strip()
    return sec in GENERATED_SECTIONS


def judge(cur, golden):
    """반환 = (fails, added, observed).

    🆕 🔴🔴 [2026-08-28 O111] **제외 규칙(`is_generated`)은 「유실」 축에만 적용한다.**
      종전에는 `base`·`now` 를 **한 번에** 걸러서 중복 축까지 같이 좁혔다.
      · 자동 생성 표를 유실 축에서 빼는 근거(O83-B)는 **「값이 매번 바뀐다」**인데,
        그 근거는 **중복 축에는 성립하지 않는다** — 도구가 같은 행을 두 번 찍는 것은
        유실과 똑같이 사고다. ⇒ 근거가 없는 축까지 눈을 감고 있었다.
      · 🟢 실측(O111 착수 시점) = 자동 생성 표의 중복은 **0건**이었다.
        즉 이 분리로 오늘 당장 새 FAIL 이 생기지는 않는다(재현율만 회복한다).

    🆕 🔴🔴 [2026-08-28 O111] **「절대 중복」을 별도로 관측해 보고한다.**
      🔴 종전 요약은 `중복 0` 이라고 찍었지만, 그것은 **「골든 대비 증가 0」**이었다.
        실측 = `00_INDEX` 리스트 291 ↔ 집합 281 ⇒ **중복 10행이 실재**하는데
        출력만 보면 「중복이 없다」로 읽힌다(판정이 아니라 **문구가 은폐**했다).
      🟢 그러나 절대 중복은 **blocking 이 아니다** — 실측 2종의 정체는
        `🔷 Phase 배정 ¦ P1`(×4) · `¦ P2`(×8) 로, **첫 셀이 유일키가 아닌 정상 표**다.
        ⇒ blocking 으로 올리면 정상 문서가 막힌다(`P130` 「항상 빨간 게이트」).
      ⇒ 판정은 **골든 대비 증가**로 두고, 절대 중복은 **숫자로 노출**한다.
        🔴 인수인계의 진단(「`GENERATED_SECTIONS` 제외 규칙에 가려졌다」)은 **틀렸다** —
          가려진 것이 아니라 **다른 것을 세고 있었다.**
    """
    fails, added, observed = [], [], {}
    for t, base in golden.items():
        now = cur.get(t)
        if now is None:
            fails.append('%s: 파일이 없다(골든에는 행 %d개)' % (t, len(base)))
            continue

        # ── 유실 축: 자동 생성 표 제외(O83-B 근거가 성립하는 유일한 축) ──
        base_l = [k for k in base if not is_generated(k)]
        now_l = [k for k in now if not is_generated(k)]
        bcl, ncl = Counter(base_l), Counter(now_l)
        lost = sorted(k for k in bcl if ncl[k] < bcl[k])
        if lost:
            fails.append('%s: 행 유실 %d건 ▸ %s' % (
                t, len(lost), ' / '.join(lost[:6])))

        # ── 중복 축: 제외하지 않는다(전량) ──────────────────────────────
        bc, nc = Counter(base), Counter(now)
        dup = sorted(k for k in nc if nc[k] > 1 and nc[k] > bc.get(k, 0))
        if dup:
            fails.append('%s: 행 중복 %d건 ▸ %s' % (
                t, len(dup), ' / '.join('%s(×%d)' % (k, nc[k]) for k in dup[:6])))

        # ── 관측 축: 절대 중복(판정 아님 · 문구 은폐 방지) ────────────────
        dup_abs = {k: v for k, v in nc.items() if v > 1}
        observed[t] = {
            'rows': len(now),
            'uniq': len(set(now)),
            'dup_keys': len(dup_abs),
            'dup_rows': len(now) - len(set(now)),
            'dup_gen': len([k for k in dup_abs if is_generated(k)]),
            'sample': sorted(dup_abs.items(), key=lambda x: -x[1])[:3],
        }

        new = sorted(k for k in nc if bc[k] < nc[k] and k not in bc)
        if new:
            added.append((t, new))

    for t in cur:
        if t not in golden:
            added.append((t, ['(골든에 없는 신규 파일)']))
    return fails, added, observed


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument('--update-golden', action='store_true')
    # 🔴 [2026-08-28 O109] 재발행 **사유·라벨·시각**을 기록한다.
    #   종전에는 인자가 없어 골든 note 가 「O82-B 신설」에 고정돼 있었고, 이후의
    #   모든 재발행이 **누가 왜 올렸는지 흔적 없이** 기준선을 갈아치웠다
    #   (`R1-7-4` 는 「FAIL 을 골든으로 덮지 마라」인데, 정당한 재발행조차 근거가
    #    남지 않으면 나중에 그 둘을 **구별할 수 없다**).
    ap.add_argument('--reason', default=None,
                    help='골든 재발행 사유(권고 · 미지정이면 경고를 낸다)')
    ap.add_argument('--label', default=None,
                    help='재발행 세션 라벨(예: O109). 생략하면 환경변수 SESSION_LABEL')
    a = ap.parse_args(argv)

    cur = collect()

    if a.update_golden:
        os.makedirs(os.path.dirname(GOLDEN), exist_ok=True)
        prev = {}
        if os.path.exists(GOLDEN):
            prev = json.load(io.open(GOLDEN, encoding='utf-8'))
        rows = {k: v for k, v in cur.items() if v is not None}
        label = a.label or os.environ.get('SESSION_LABEL', '') or 'UNLABELED'
        entry = {
            'date': time.strftime('%Y-%m-%d %H:%M:%S'),
            'label': label,
            'reason': a.reason or '(사유 미기재)',
            'rows_before': sum(len(v) for v in prev.get('rows', {}).values()),
            'rows_after': sum(len(v) for v in rows.values()),
        }
        payload = {
            'note': '원장 표 행 키 기준선 — C6 처방(착수표 ㉑) · O82-B 신설',
            'history': (prev.get('history') or []) + [entry],
            'rows': rows,
        }
        with io.open(GOLDEN, 'w', encoding='utf-8') as fh:
            json.dump(payload, fh, ensure_ascii=False, indent=1, sort_keys=True)
            fh.write('\n')
        tot = sum(len(v) for v in payload['rows'].values())
        print('🟢 골든 발행 — 표면 %d · 행 키 %d개 (이전 %d) → %s'
              % (len(payload['rows']), tot, entry['rows_before'],
                 os.path.relpath(GOLDEN, ROOT)))
        print('   발행 이력 = %s · %s · %s'
              % (entry['date'], entry['label'], entry['reason']))
        if not a.reason:
            print('   🟠 `--reason` 미지정 — 다음 세션이 「왜 올렸는지」를 알 수 없다.')
        for k, v in sorted(payload['rows'].items()):
            print('   %-46s %4d행' % (os.path.basename(k), len(v)))
        return 0

    if not os.path.exists(GOLDEN):
        print('🔴 골든이 없다 — 먼저 `--update-golden` 을 실행할 것: %s'
              % os.path.relpath(GOLDEN, ROOT))
        return 1

    golden = json.load(io.open(GOLDEN, encoding='utf-8'))['rows']
    tot = sum(len(v) for v in cur.values() if v)
    print('[원장 행 키 게이트] 표면 %d · 현재 행 %d · 골든 %d'
          % (len(TARGETS), tot, sum(len(v) for v in golden.values())))

    fails, added, observed = judge(cur, golden)
    for t, new in added:
        print('  ⚪ %s: 신설 %d행 (예: %s)'
              % (t, len(new), new[0][:70]))

    # 🆕 [2026-08-28 O111] 절대 중복을 **숫자로** 노출한다(판정 아님 · 문구 은폐 방지).
    for t in sorted(observed):
        o = observed[t]
        mark = '⚪' if o['dup_rows'] == 0 else '🟠'
        print('  %s %s: 행 %d · 고유 %d · 중복 %d행(키 %d종 · 자동생성표 %d종)'
              % (mark, os.path.basename(t), o['rows'], o['uniq'],
                 o['dup_rows'], o['dup_keys'], o['dup_gen']))
        for k, v in o['sample']:
            print('       ×%d  %s' % (v, k[:80]))
    print('  🔵 절대 중복은 blocking 이 아니다 — 「첫 셀이 유일키가 아닌 표」가 실재한다'
          '(`🔷 Phase 배정`). 판정 축 = **골든 대비 증가**.')

    if fails:
        print('\n🔴 게이트 실패 — 행 집합이 깨졌다(전체 재작성 write 의 전형 · C5·C7)')
        for f in fails:
            print(' -', f)
        print('\n   복구: 소실 행을 `edit` 부분 치환으로 되살린 뒤 재실행한다.')
        print('   🔴 `--update-golden` 으로 덮지 마라 — 그것은 사고를 기준선으로 만드는 것이다.')
        return 1
    # 🔴 [O111] 주의 문구는 **판정 줄보다 먼저** 찍고 이모지로 시작하지 않는다 —
    #   `session_brief.gate_verdict` 는 **마지막 상태 이모지 줄**을 판정으로 읽으므로
    #   판정 뒤에 🔴 로 시작하는 줄을 두면 브리핑이 이 게이트를 **FAIL 로 표시**한다
    #   (O109 D5 와 같은 축의 사고를 만들 뻔했다 — 게이트 출력은 계약이다).
    print('\n   (주의) 아래 통과 문장은 「중복이 없다」가 아니다 —'
          ' 절대 중복은 위 관측 줄을 보라.')
    print('✅ 게이트 통과 — 행 유실 0 · 골든 대비 중복 증가 0')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
