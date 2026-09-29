"""O188-D 임시: 문서20 -001 의 O188-A 판정 블록 6개를 블록당 1줄로 병합(내용 무변경 · 줄 수만 축소). 1회용."""
import io, sys, hashlib
P = '/workspace/20_issue/20_현업확인_요청_조각/20_현업확인_요청-001.md'
RANGES = [(165, 170), (208, 212), (229, 236), (257, 258), (280, 288), (323, 330)]
EXPECT_HEAD = {165: '**판정**: 🟢 **[2026-09-29 O188', 208: '**판정**: ⛔ **[2026-09-29 O188',
               229: '**판정**: 🟡 **[2026-09-29 O188', 257: '**판정**: 🟢 **[2026-09-29 O188',
               280: '**판정**: 🟢 **[2026-09-29 O188', 323: '**판정**: 🟢 **[2026-09-29 O188'}
raw = io.open(P, encoding='utf-8').read()
L = raw.split('\n')
if len(L) not in (332, 333):
    sys.exit('LEN %d' % len(L))
for s, e in RANGES:
    if not L[s - 1].startswith(EXPECT_HEAD[s]):
        sys.exit('HEAD MISMATCH %d %r' % (s, L[s - 1][:40]))
    for i in range(s + 1, e + 1):
        if not L[i - 1].startswith('>'):
            sys.exit('NOT QUOTE %d %r' % (i, L[i - 1][:40]))
before = ''.join(l.lstrip('> ').strip() for l in L)
for s, e in reversed(RANGES):
    parts = [L[s - 1].rstrip()] + [L[i - 1].lstrip('>').strip() for i in range(s + 1, e + 1)]
    L[s - 1:e] = [' '.join(parts)]
after = ''.join(l.lstrip('> ').strip() for l in L)
strip = lambda t: t.replace(' ', '')
if strip(before) != strip(after):
    sys.exit('CONTENT DRIFT')
io.open(P, 'w', encoding='utf-8').write('\n'.join(L))
print('ok lines', len(L), 'maxlen', max(len(l) for l in L))
