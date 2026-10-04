#!/usr/bin/env python3
# O201-C — O18x 이력·원장 소급 등재용 항목 생성(라벨 파일 ▣-0 절 원문 발췌 · 가필 없음)
import io, os, re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, '99_NEXT_SESSION_조각')
HIS = ['O0182-A', 'O0183-B', 'O0183-C', 'O0188-C', 'O0188-D', 'O0188-E', 'O0188-F', 'O0188-G']
IDX = ['O0181-B', 'O0183-B', 'O0183-C', 'O0183-D', 'O0188-B', 'O0188-C', 'O0188-D', 'O0188-E',
       'O0188-F', 'O0188-G', 'O0189-B', 'O0189-C']

def first_section(lab):
    s = io.open(os.path.join(D, '99_NEXT_SESSION-%s.md' % lab), encoding='utf-8').read().splitlines()
    i = next(k for k, l in enumerate(s) if l.startswith('### '))
    head = s[i][4:].strip()
    body = []
    for l in s[i + 1:]:
        if l.startswith('### '):
            break
        if l.strip():
            body.append(l)
    return head, body

def short(lab):
    return 'O%s' % lab[2:].lstrip('0')

out = ['## O201-C — O18x 이력 소급 등재(라벨 파일 ▣-0 원문 발췌 · 가필 없음) (2026-10-03 · 계정 JU93656 · 사용자 승인)', '',
       '- 근거 = `20_issue/_o201_inspection_evidence.md` §E13(이력 부재 8 실측) · 원문 = 각 라벨 파일 첫 ▣ 절.', '']
for lab in HIS:
    head, body = first_section(lab)
    out.append('> #### [소급] %s — %s' % (short(lab), head[:200]))
    out.append('> · 원문 좌표 = `99_NEXT_SESSION_조각/99_NEXT_SESSION-%s.md`' % lab)
    for l in body[:6]:
        out.append('> ' + l[:900])
    out.append('')
io.open(os.path.join(ROOT, 'tmp', '_o201c_history_backfill.md'), 'w', encoding='utf-8').write('\n'.join(out) + '\n')

cells = ' · '.join('`%s`(`99_NEXT_SESSION-%s.md`)' % (short(l), l) for l in IDX)
row = ('| 🟢 **`O201-C`** — (소급 등재 · O201-B §E13 실측) 원장 §1 행이 없던 O18x 라벨 12단위 · 상태 정본 = 각 라벨 파일 (2026-10-03 · JU93656) '
       '| 🟢 소급 12 · 이력 소급 8(`01_세션이력` O201-C 항목) | %s | `20_issue/_o201_inspection_evidence.md` §E13 |' % cells)
io.open(os.path.join(ROOT, 'tmp', '_o201c_index_row.txt'), 'w', encoding='utf-8').write(row + '\n')
print(len(out), 'lines · row chars', len(row))
