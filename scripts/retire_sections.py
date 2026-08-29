#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""retire_sections.py — 갱신형 정본의 **닫힌 절**을 append형 로그로 은퇴 이관한다.

[2026-08-28 O107 신설 · 인수인계 ▣GGG ② 집행 도구]

🔴 이 도구가 푸는 문제
--------------------------------------------------------------------------
`retire_rows.py` 는 **표 본문 행의 장문 셀**만 다룬다(`big_cell_index`).
그래서 「문서50 완료절 18개 은퇴」 계획이 **도구가 없어 O106 에서 철회**됐다.
절은 문서 총량의 대부분을 차지하는데 총량을 줄이는 연산이 없었다.

🔴🔴 절은 행 키보다 위험하다 — 그래서 설계가 다르다
--------------------------------------------------------------------------
절은 다른 문서가 **`§번호`·`§제목`으로 인용**하고 `doc_heading_gate` 가
**제목 집합**을 골든으로 고정한다. 절을 통째로 옮기면 두 축이 동시에 깨진다:
  ㉠ 인용 좌표가 죽는다(원본에서 그 절이 사라진다)
  ㉡ `doc_heading_gate` 가 **제목 유실**로 FAIL 한다(골든을 덮어야 통과된다 =
     `R1-7-4` 가 금지한 「FAIL 을 골든으로 덮기」와 같은 유혹)

🟢 그래서 이 도구는 **절을 옮기지 않는다 — 절 「본문」만 옮긴다.**
   `retire_rows.py` 가 「행을 지우지 않고 셀만 비운다」로 `R1-7-4` 와 공존한 것과
   **같은 설계**다(행 키 ↔ 절 제목이 대응한다).
   * **제목 줄은 하위 제목까지 한 줄도 건드리지 않는다** ⇒ 제목 유실 **원리적으로 0**.
   * 제목 아래 본문만 목적지로 **무변경 이동**하고 그 자리에 **포인터 1줄**을 남긴다.
   * ⇒ `§O64` 로 인용한 문장은 **그대로 유효**하고, 그 좌표를 따라가면 포인터가 있다.

🔴 `R2-8`(정본 이관 무결성) 집행 — 삭제 전에 기계로 대조한다
--------------------------------------------------------------------------
* `R2-8-1` 토큰 대조: 이동 본문의 수치·ID·백틱 토큰이 **목적지에 전건 실재**해야
  원본을 고친다. 1종이라도 부재면 **중단**(blocking · exit 1).
* `R2-8-2` 무변경: 본문은 **바이트 그대로** 옮긴다(재작성·요약 금지).
  이동 본문 SHA256 을 양쪽에 적어 나중에 대조할 수 있게 한다.
* `R2-8-3` 되돌릴 수 없음: 쓰기 직전 **양쪽 파일을 스냅샷**한다(`R1-7-6`).
* 기본은 **dry-run**. 쓰려면 `--apply` 를 명시한다.
* 🔴 `R4-4-3`: 다중 파일 재작성이므로 **지시가 동봉돼도 사용자 승인**을 받고 실행한다.

🔴🔴 목적지가 **허브**면 허브에 직접 쓰지 않는다
--------------------------------------------------------------------------
`90_해소완료_로그.md` 는 O106 이 **폴더 분할**해 이제 **자동 생성물**이다.
거기에 append 하면 다음 `--republish`·`--rollover` 가 **통째로 다시 써서 사라진다**
(`R3-9 ㉧` · 이 워크스페이스가 4번 당한 유형). ⇒ 이 도구는 허브를 감지하면
**`split_doc.py --rollover`** 로 **꼬리 조각**에 붙인다(`R1-6-15` 정본 경로).
⚠️ 그래서 토큰 대조 분모도 「허브 텍스트」가 아니라 **조각 concat(논리 본문)** 이다 —
   허브만 보면 기존 토큰이 전부 부재로 잡혀 **오탐으로 항상 FAIL** 한다.

사용
--------------------------------------------------------------------------
    # 후보 보기(절감 큰 순 · 닫힌 절만 보려면 --closed-only)
    python3 scripts/retire_sections.py --src 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-008.md --list

    # 좌표 대응표 + 토큰 대조까지 보고 멈춘다(기본 dry-run)
    python3 scripts/retire_sections.py \
        --src 20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-008.md \
        --sections "O64" \
        --to 20_issue/90_해소완료_로그.md \
        --to-section "7. 은퇴 이관 — 문서50 완료 절 (2026-08-28 O107)" \
        --label O107

    # 실제 이관
    ... --apply

⚠️ 이관 후 반드시 실행한다
    python3 scripts/split_doc.py <허브> --republish   # 조각을 고쳤으므로(R1-6-13)
    python3 scripts/doc_heading_gate.py              # 제목 유실 0 확인(골든 덮지 말 것)
    python3 scripts/index_row_gate.py                # 표를 품은 절이면 행 키 확인
    python3 scripts/line_len.py <경로들>              # 한 줄 2,000자(R1-5-4)
"""

import argparse
import hashlib
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# 토큰 규칙은 `retire_rows.py` 와 **같아야 한다** — 두 도구가 다른 기준으로 「대조 통과」를
# 보고하면 어느 쪽을 믿을지 알 수 없다(`R1-6-17` 「같은 것을 다르게 재는 지점」).
from retire_rows import tokens, nbytes, read_text, write_text  # noqa: E402
import split_doc as SD  # noqa: E402
from snapshot_util import add_label_arg, resolve_label, snapshot  # noqa: E402

HEAD_RX = re.compile(r'^(#{2,6}) +(.*)$')
CLOSED_RX = re.compile(r'^\s*(?:🟢|✅)')
# 포인터 줄 — 멱등성 판정에 쓴다(이미 은퇴한 절을 다시 은퇴시키면 빈 이관이 된다).
PTR_MARK = '은퇴 이관 →'

# 🆕 🔴🔴 [2026-08-28 O111-B 신설] **본문 열린 내용 탐지** — 「닫힘」은 제목 판정일 뿐이다.
#   🔴 실측 근거(O111-B 가 승인받아 실적용을 시도하며 후보를 **읽고** 발견했다):
#     `50_dbt_…-014.md` §`✅ [DONE 순서9-C] dbt project 배포 + full build green 달성` 은
#     제목이 ✅ 인데 본문에
#       · **`warn→error 복귀 추적표`** = 복귀 트리거가 **아직 열린** 항목(BLOCKING-1 · 마스터 전량입고 대기) 7행
#       · **WARN 27건 전량 목록** = *"🔴 이 표가 없어서 같은 질문이 두 번 나왔다"* 라고
#         **존재 이유를 스스로 적어 둔** 표
#     를 담고 있었다 ⇒ 은퇴시키면 **살아 있는 추적표를 닫힌 로그로 옮긴다.**
#   🔴 이 워크스페이스의 관례상 **닫힌 제목 아래에 열린 추적이 붙는 것이 흔하다**
#     (완료 보고 + 그 완료의 잔여 조건을 같은 절에 쓴다) ⇒ **제목 이모지만으로는 대량 적용이 불가**하다.
#   🟢 처방 = 본문에서 「열림 신호」를 세어 **표시하고 기본 차단**한다(`--force` 로만 통과).
#     ⚠️ 이것은 사람 판단을 대체하지 않는다 — **읽으라는 경고를 숫자로 만든 것**이다.
OPEN_SIGNALS = (
    ('상태 이모지 🔴/🟠/🟡', re.compile(r'🔴|🟠|🟡')),
    ('복귀·전환 트리거', re.compile(r'복귀 트리거|복귀 조건|warn→error|전환 대기')),
    ('미결·대기 표기', re.compile(r'미결|대기 중|회신 대기|승인 대기|미적용|미배선|미갱신')),
    ('BLOCKING 참조', re.compile(r'BLOCKING-\d')),
    ('존재 이유 자기선언', re.compile(r'이 표가 없어서|없으면 같은 질문')),
)


def open_signals(body):
    """절 본문의 「열림 신호」를 (이름, 건수) 목록으로 돌려준다."""
    out = []
    for name, rx in OPEN_SIGNALS:
        n = len(rx.findall(body))
        if n:
            out.append((name, n))
    return out


def sha(s):
    return hashlib.sha256(s.encode('utf-8')).hexdigest()


def sections(text):
    """(level, 제목, 시작줄, 끝줄) — 끝줄은 배타적. 다음 **동급 이상** 제목 앞까지."""
    lines = text.split('\n')
    heads = []
    for i, l in enumerate(lines):
        m = HEAD_RX.match(l)
        if m:
            heads.append((len(m.group(1)), m.group(2).strip(), i))
    out = []
    for k, (lv, title, i) in enumerate(heads):
        end = len(lines)
        for lv2, _t2, j in heads[k + 1:]:
            if lv2 <= lv:
                end = j
                break
        out.append((lv, title, i, end))
    return out


def body_lines(lines, a, b):
    """[a, b) 중 **제목이 아닌** 줄 번호 목록.

    🔴 제목 줄은 하위 제목까지 **전건 제외**한다 — 이것이 이 도구의 안전 계약이다
    (제목을 옮기면 `doc_heading_gate` 유실 + `§` 인용 사망 · 모듈 docstring 참조).
    """
    return [i for i in range(a, b) if not HEAD_RX.match(lines[i])]


def is_retired(lines, a, b):
    """이미 은퇴된 절인가(포인터만 남아 있는가)."""
    return any(PTR_MARK in lines[i] for i in body_lines(lines, a, b))


def dst_is_hub(dst):
    """목적지가 **분할 문서의 허브**인가.

    🔴🔴 [2026-08-28 O107 자기시정] 최초 구현은 `retire_rows.py` 의 기본 목적지
    (`20_issue/90_해소완료_로그.md`)를 그대로 물려받아 **허브에 직접 append** 했다.
    그러나 O106 이 그 문서를 **폴더 분할**했으므로 그 파일은 이제 **자동 생성물**이고,
    거기에 쓴 본문은 다음 `--republish`·`--rollover` 에서 **경고 없이 사라진다**
    (`R3-9 ㉧` · 이 워크스페이스가 4번 당한 유형). ⇒ 허브면 `--rollover` 경로를 쓴다.
    """
    outdir = SD.hub_outdir(dst)
    return os.path.exists(SD.chunk_path(dst, 1, outdir))


def dst_logical(dst):
    """목적지의 **논리 본문** — 허브면 조각 concat, 아니면 파일 내용."""
    if dst_is_hub(dst):
        parts, _ = SD.collect_bodies(dst, SD.hub_outdir(dst))
        return '\n'.join(parts)
    return read_text(dst)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', required=True, help='은퇴 대상 조각(또는 단일 문서) 경로')
    ap.add_argument('--sections', default='',
                    help='절 제목 부분문자열 · 쉼표 구분(예: "O64,O63")')
    ap.add_argument('--to', default='20_issue/90_해소완료_로그.md', help='append형 목적지')
    ap.add_argument('--to-section', default=None, help='목적지에 만들 절 제목')
    add_label_arg(ap, help_text='포인터·스냅샷에 적을 세션 라벨(예: O110). '
                                '생략하면 환경변수 SESSION_LABEL, 그것도 없으면 UNLABELED')
    ap.add_argument('--list', action='store_true', help='후보만 보고 종료(절감 큰 순)')
    ap.add_argument('--closed-only', action='store_true',
                    help='--list 에서 선두가 🟢/✅ 인 절만 보인다')
    ap.add_argument('--min-bytes', type=int, default=0, help='--list 하한(바이트)')
    ap.add_argument('--apply', action='store_true', help='실제로 쓴다(기본은 dry-run)')
    # 🆕 [2026-08-28 O111-B] 열린 내용 차단을 넘긴다 — **읽었다는 선언**이다.
    ap.add_argument('--force', action='store_true',
                    help='열림 신호가 있어도 진행(그 절을 읽었을 때만 · 이력에 적을 것)')
    a = ap.parse_args()
    a.label = resolve_label(a.label)

    src = a.src if os.path.isabs(a.src) else os.path.join(ROOT, a.src)
    dst = a.to if os.path.isabs(a.to) else os.path.join(ROOT, a.to)
    for p in (src, dst):
        if not os.path.exists(p):
            raise SystemExit('🔴 경로 부재: %s' % p)

    stext = read_text(src)
    slines = stext.split('\n')
    secs = sections(stext)

    # ── --list ───────────────────────────────────────────────────────────
    if a.list:
        rows = []
        for lv, title, i, j in secs:
            bl = body_lines(slines, i, j)
            b = nbytes('\n'.join(slines[k] for k in bl))
            if b < a.min_bytes:
                continue
            closed = bool(CLOSED_RX.match(title))
            if a.closed_only and not closed:
                continue
            body = '\n'.join(slines[k] for k in bl)
            rows.append((b, i, j, lv, title, closed, is_retired(slines, i, j),
                         open_signals(body)))
        rows.sort(reverse=True)
        print('[절 은퇴 후보] %s · 절 %d개 (표시 %d개)'
              % (os.path.basename(src), len(secs), len(rows)))
        print('%9s %6s %4s %5s %5s  %s'
              % ('본문B', '행', 'lv', '상태', '열림신호', '절 제목'))
        for b, i, _j, lv, title, closed, retired, sig in rows[:40]:
            st = '은퇴됨' if retired else ('닫힘' if closed else '열림')
            n = sum(c for _n, c in sig)
            print('%9d %6d %4d %5s %5s  %s'
                  % (b, i + 1, lv, st, ('🔴%d' % n) if n else '—', title[:52]))
            for name, c in sig:
                print('%28s · %s %d건' % ('', name, c))
        live = [r for r in rows if not r[6]]
        risky = [r for r in live if r[7]]
        print('표시 절 본문 합계 = %s B (이미 은퇴 %d개 제외 시 %s B)'
              % (format(sum(r[0] for r in rows), ','), len(rows) - len(live),
                 format(sum(r[0] for r in live), ',')))
        print('🔴 「닫힘」은 제목 선두 이모지 판정일 뿐이다 — 은퇴 전에 그 절을 읽어라.')
        # 🆕 [O111-B] 열림 신호가 있는 후보를 **숫자로** 분리해 보고한다.
        print('🔴🔴 열림 신호 보유 후보 %d / %d — 이 절들은 제목이 닫힘이어도 **본문에 살아 있는'
              ' 추적이 있다**(실측 선례 = §DONE 순서9-C 의 warn→error 복귀 추적표).'
              % (len(risky), len(live)))
        if risky:
            print('   ⇒ 은퇴 대상에서 **먼저 빼라**. 넣으려면 그 절을 읽고 `--force` 를 준다.')
        return 0

    want = [w.strip() for w in a.sections.split(',') if w.strip()]
    if not want:
        raise SystemExit('🔴 --sections 가 비었다(또는 --list 를 써라).')
    if not a.to_section:
        raise SystemExit('🔴 --to-section 이 필요하다(목적지 절 제목).')

    picked, seen = [], set()
    for w in want:
        hit = [s for s in secs if w in s[1]]
        if not hit:
            raise SystemExit('🔴 --sections 에 맞는 절이 없다: %r (--list 로 확인하라)' % w)
        if len(hit) > 1:
            print('⚠️ %r 가 절 %d개에 걸린다 — 전건 이관한다: %s'
                  % (w, len(hit), ' / '.join(h[1][:30] for h in hit)))
        for h in hit:
            if h[2] in seen:
                continue
            seen.add(h[2])
            picked.append(h)
    picked.sort(key=lambda s: s[2])

    # 🔴 이미 은퇴된 절을 다시 은퇴시키면 **포인터를 목적지로 옮기는 빈 이관**이 된다.
    already = [s for s in picked if is_retired(slines, s[2], s[3])]
    if already:
        print('🔴 이미 은퇴된 절이 있다 — 중단한다(빈 이관 방지):')
        for s in already:
            print('   -', s[1][:60])
        return 1

    # 🆕 🔴🔴 [2026-08-28 O111-B] **열린 내용 차단** — 제목이 닫힘이어도 본문이 살아 있으면 막는다.
    #   실측 선례 = §`✅ [DONE 순서9-C]` 안의 warn→error 복귀 추적표(열린 트리거 7행).
    #   🔴 이 검사가 없으면 **살아 있는 추적표가 닫힌 로그로 옮겨진다** — 되돌리기 비용이 크다.
    risky = []
    for lv, title, i, j in picked:
        bl = body_lines(slines, i, j)
        sig = open_signals('\n'.join(slines[k] for k in bl))
        if sig:
            risky.append((title, sig))
    if risky and not a.force:
        print('🔴🔴 열린 내용이 있는 절이 대상에 있다 — 중단한다(살아 있는 추적을 닫지 않기 위해):')
        for title, sig in risky:
            print('   - %s' % title[:70])
            for name, c in sig:
                print('       · %s %d건' % (name, c))
        print('   🟢 처방 = ㉠ 그 절을 **읽고** ㉡ 정말 닫혔으면 `--force` 를 준다')
        print('             ㉢ 아니면 대상에서 빼라(부분 은퇴가 정답인 경우가 많다).')
        return 1
    if risky and a.force:
        print('⚠️ `--force` 로 열린 내용 차단을 넘겼다 — 절 %d개에 열림 신호가 있다.' % len(risky))
        print('   🔴 이 사실은 이력·원장에 **그대로 적어라**(판단의 근거가 사람에게 있다).')

    # ── 이동 본문 구성 + 좌표 대응표 ──────────────────────────────────────
    plan = []
    for lv, title, i, j in picked:
        bl = body_lines(slines, i, j)
        body = '\n'.join(slines[k] for k in bl).strip('\n')
        if not body.strip():
            print('🔴 절 본문이 비어 있다(제목만) — 은퇴 대상이 아니다: %s' % title[:60])
            return 1
        subs = [t for (_lv2, t, i2, _j2) in secs if i < i2 < j]
        plan.append(dict(lv=lv, title=title, a=i, b=j, body=body, blines=bl, subs=subs))

    block = ['', '## %s' % a.to_section, '',
             '> 🔴 **절 본문 무변경 이관**(`R2-8` · `%s`). 원본에는 **제목 줄이 그대로 남아 있고**'
             % a.label,
             '> 이 문서에는 그 절의 **본문 원문**이 있다. 원본에는 이 절을 가리키는 포인터 1줄만 남았다.',
             '> ⚠️ **절을 삭제한 것이 아니다** — `§제목` 인용 좌표와 `doc_heading_gate` 제목 집합을',
             '> 보존하기 위해 **제목(하위 제목 포함)은 한 줄도 옮기지 않았다**.',
             '',
             '### 좌표 대응표 (원본 → 이 문서)', '',
             '| 원본 파일 | 원본 행범위 | lv | 절 제목 | 본문 B | 본문 SHA256(앞16) |',
             '|---|---|---|---|---|---|']
    for p in plan:
        block.append('| `%s` | %d~%d | %d | %s | %s | `%s` |'
                     % (os.path.basename(src), p['a'] + 1, p['b'], p['lv'],
                        p['title'].replace('|', '/'),
                        format(nbytes(p['body']), ','), sha(p['body'])[:16]))
    block.append('')
    for p in plan:
        block.append('#### 이관 본문 — %s' % p['title'].replace('|', '/'))
        block.append('')
        if p['subs']:
            block.append('> ⚠️ 이 절의 **하위 절 본문도 함께** 들어 있다(하위 제목은 원본에 남았다): %s'
                         % ' · '.join(s.replace('|', '/')[:40] for s in p['subs']))
            block.append('')
        block.append(p['body'])
        block.append('')

    hub_dst = dst_is_hub(dst)
    dtext = read_text(dst)
    dlogical = dst_logical(dst)
    entry = '\n'.join(block).rstrip() + '\n'
    sig = '_Co-authored with CoCo_'
    if hub_dst:
        # 🔴 허브에 직접 쓰지 않는다 — `--rollover` 가 **꼬리 조각**에 붙인다(`R1-6-15`).
        #   토큰 대조 대상은 「허브 + 논리 본문 + 추가분」이어야 한다(허브만 보면 부재로 오탐).
        new_dtext = dlogical.rstrip() + '\n\n' + entry
    elif dtext.rstrip().endswith(sig):
        body = dtext.rstrip()[:-len(sig)].rstrip()
        new_dtext = body + '\n' + entry.rstrip() + '\n\n' + sig + '\n'
    else:
        new_dtext = dtext.rstrip() + '\n' + entry

    # ── R2-8-1 토큰 대조 (blocking) ──────────────────────────────────────
    need = set()
    for p in plan:
        need |= tokens(p['body'])
    missing = sorted(t for t in need if t not in new_dtext)
    print('[R2-8-1 토큰 대조] 대상 토큰 %d종 · 목적지 부재 %d종' % (len(need), len(missing)))
    if missing:
        print('🔴 FAIL — 부재 토큰이 있어 원본을 수정하지 않는다:')
        for t in missing[:20]:
            print('   -', t)
        return 1

    # ── 원본 치환: 본문 줄 → 포인터 1줄 (제목 줄 전건 불변) ────────────────
    ptr = {}
    for p in plan:
        ptr[p['blines'][0]] = (
            '✅ **[%s] %s `%s` §%s** — 이 절 본문을 그 문서로 **무변경 이동**했다'
            '(`R2-8` 토큰 대조 통과 · 본문 SHA256 `%s`). '
            '🔴 **절 삭제가 아니다**: 제목 줄과 `§` 인용 좌표는 그대로다(`R1-7-4` 축).'
            % (a.label, PTR_MARK, os.path.basename(dst),
               a.to_section.split('.')[0], sha(p['body'])[:16]))
    drop = set()
    for p in plan:
        drop |= set(p['blines'])
    out = []
    for i, l in enumerate(slines):
        if i in ptr:
            out.append('')
            out.append(ptr[i])
            out.append('')
        elif i in drop:
            continue
        else:
            out.append(l)
    new_stext = re.sub(r'\n{3,}', '\n\n', '\n'.join(out))

    # ── 자가 검증 3축 (게이트가 잡기 전에 여기서 막는다) ───────────────────
    def heads_of(t):
        return [m.group(0) for m in re.finditer(r'(?m)^#{2,6} .*$', t)]
    h_before, h_after = heads_of(stext), heads_of(new_stext)
    if h_before != h_after:
        lost = [h for h in h_before if h not in h_after]
        print('🔴 제목 줄이 변했다 — 쓰지 않는다. 유실 %d개: %s'
              % (len(lost), lost[:5]))
        return 1
    over = [(n, len(l)) for n, l in enumerate(new_stext.split('\n'), 1) if len(l) > 2000]
    if over:
        print('🔴 2,000자 초과 줄 발생(%r) — 쓰지 않는다(R1-5).' % over[:3])
        return 1
    over_d = [(n, len(l)) for n, l in enumerate(new_dtext.split('\n'), 1) if len(l) > 2000]
    if over_d:
        print('🔴 목적지에 2,000자 초과 줄 발생(%r) — 쓰지 않는다.' % over_d[:3])
        return 1

    print('원본 %s: %s B → %s B (절감 %s B)'
          % (os.path.basename(src), format(nbytes(stext), ','),
             format(nbytes(new_stext), ','), format(nbytes(stext) - nbytes(new_stext), ',')))
    if hub_dst:
        print('목적지 %s = **허브** ⇒ `--rollover` 로 꼬리 조각에 붙인다(허브 직접 쓰기 금지)'
              % os.path.basename(dst))
        print('   논리 본문 %s B → %s B (추가 %s B)'
              % (format(nbytes(dlogical), ','), format(nbytes(new_dtext), ','),
                 format(nbytes(entry), ',')))
    else:
        print('목적지 %s: %s B → %s B' % (os.path.basename(dst), format(nbytes(dtext), ','),
                                        format(nbytes(new_dtext), ',')))
    print('이관 절 %d개 · 이동 본문 %s B' % (len(plan), format(sum(nbytes(p['body']) for p in plan), ',')))
    print('🟢 제목 줄 %d개 전건 불변 · 2,000자 초과 0' % len(h_before))
    print('[좌표 대응표]')
    for p in plan:
        print('   %s:%d~%d  lv%d  %s  → %s §%s'
              % (os.path.basename(src), p['a'] + 1, p['b'], p['lv'], p['title'][:44],
                 os.path.basename(dst), a.to_section.split('.')[0]))

    if not a.apply:
        print('\n--apply 미지정 — 파일을 쓰지 않았다(dry-run).')
        return 0

    arch = os.path.join(ROOT, '_archive')
    if not os.path.isdir(arch):
        os.makedirs(arch)
    snap_targets = [src, dst]
    if hub_dst:
        # 허브 목적지는 **꼬리 조각**이 실제 쓰기 대상이다 ⇒ 그것도 스냅샷한다.
        _parts, dpaths = SD.collect_bodies(dst, SD.hub_outdir(dst))
        snap_targets.append(dpaths[-1])
    for p in snap_targets:
        # 🔴 [2026-08-28 O110 · `R1-7-10`] 헬퍼 경유 — 같은 라벨 재실행 시 기존 스냅샷을
        #   덮지 않고 `.2`·`.3` 으로 보존한다(종전 직접 쓰기는 조용히 덮었다 · O109 D2).
        snapshot(p, 'preretiresec', label=a.label, archive=arch)

    if hub_dst:
        entry_path = os.path.join(arch, '%s-retire-entry.md' % a.label)
        write_text(entry_path, entry)
        print('추가분 파일 = %s' % os.path.relpath(entry_path, ROOT))
        rc = SD.rollover(dst, entry_path)
        if rc != 0:
            print('🔴 rollover FAIL — **원본은 고치지 않았다**(순서상 목적지가 먼저다).')
            return 1
    else:
        write_text(dst, new_dtext)
    write_text(src, new_stext)
    print('\n🟢 기록 완료. 이어서 실행하라:')
    print('   python3 scripts/split_doc.py <원본 허브> --republish')
    print('   python3 scripts/doc_heading_gate.py    # 🔴 FAIL 을 골든으로 덮지 마라')
    print('   python3 scripts/index_row_gate.py')
    print('   python3 scripts/doc_census.py')
    print('   되돌리려면 `_archive/*.%s-preretiresec` 파일을 제자리에 복사한다.' % a.label)
    return 0


if __name__ == '__main__':
    sys.exit(main())
