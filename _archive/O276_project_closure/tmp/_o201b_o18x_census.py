#!/usr/bin/env python3
# O201-B ⑥ — O180~O189 검토(2판 · J2 시정): 라벨 단위별 ① 파일 ② 원장 §1 ③ 이력 ④ 남은 작업 열림 행 승계
#   시정 = 이력 제목이 `> #### 🟢 [날짜 O183] …` 형태 · 남은 작업 절 제목이 「남은 작업」/「다음이 할 일」 · 순 셀 `**1**`
import io, os, re, glob
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rd = lambda p: io.open(p, encoding='utf-8').read()
H = sorted(glob.glob(os.path.join(ROOT, '99_NEXT_SESSION_조각', '99_NEXT_SESSION-O018[0-9]-*.md')))
IDX = ''.join(rd(p) for p in glob.glob(os.path.join(ROOT, '20_issue', '00_INDEX_이슈원장_조각', '*.md')))
HIS = ''.join(rd(p) for p in glob.glob(os.path.join(ROOT, '20_issue', '01_세션이력_조각', '*.md')))
LATER = ''.join(rd(p) for p in sorted(glob.glob(os.path.join(ROOT, '99_NEXT_SESSION_조각', '99_NEXT_SESSION-O0*-*.md')))
                if re.search(r'O0(19\d|20\d)-', p))
his_heads = [l for l in HIS.splitlines() if re.match(r'^>?\s*#{2,4}\s', l)]

def open_rows(s):
    rows, on = [], False
    for l in s.splitlines():
        if l.startswith('### '):
            on = ('남은 작업' in l) or ('다음이 할 일' in l)
            continue
        if on and l.startswith('|') and not re.match(r'^\|\s*[-#순]', l):
            c = [x.strip() for x in l.strip('|').split('|')]
            if len(c) < 2 or set(c[0]) <= set('-: '):
                continue
            if '~~' in c[0] or c[1].startswith(('✅', '~~', '🟢 ~~')):
                continue
            rows.append(re.sub(r'[*`]', '', c[1]))
    return rows

out, nums = [], set()
for p in H:
    g = re.search(r'O0(1[89]\d)-([A-Z]+)', os.path.basename(p)).groups()
    label, base = 'O%s-%s' % g, 'O%s' % g[0]
    nums.add(int(g[0]))
    in_idx = ('`%s`' % label) in IDX or (g[1] == 'A' and ('`%s`' % base) in IDX)
    pat = re.compile(r'\b%s\b' % re.escape(label) + ('|\\b%s\\]' % base if g[1] == 'A' else ''))
    in_his = any(pat.search(h) for h in his_heads)
    rows = open_rows(rd(p))
    miss = [t for t in rows if t[:14] not in LATER]
    out.append('%-8s 원장=%s 이력=%s 열림=%d 후속미등장=%d' % (label, 'O' if in_idx else 'X', 'O' if in_his else 'X', len(rows), len(miss)))
    out += ['    · %s' % t[:100] for t in miss]
out.append('라벨 단위 %d · 결번 %s' % (len(H), sorted(set(range(180, 190)) - nums)))
txt = '\n'.join(out)
io.open(os.path.join(ROOT, 'tmp', '_o201b_o18x.out'), 'w', encoding='utf-8').write(txt + '\n')
print(txt)
