# O249 — 자기검토 시정 6(이전 세션 R1-7-2 병렬 edit 위반 파일 재확인 · 위반 파일 목록 부재 ⇒ 85번 폴더 전수)
# 병렬 edit 손상 흔적: ㉠ 같은 3줄 이상 블록이 연달아 두 번 ㉡ md 표 행의 열 수가 헤더와 다름 ㉢ csv 행 열 수 불일치 ㉣ 2000자 초과 줄
import io, os, csv, sys
ROOT = '/workspace/85_실제 인수인계 문서'
SKIP = {'_archive', '_ENV'}
out = []
nfile = 0
for d, ds, fs in os.walk(ROOT):
    ds[:] = [x for x in ds if x not in SKIP]
    for f in fs:
        p = os.path.join(d, f)
        rel = os.path.relpath(p, ROOT)
        if f.endswith(('.md', '.sql')):
            nfile += 1
            L = io.open(p, encoding='utf-8', errors='replace').read().split('\n')
            for i, l in enumerate(L):
                if len(l) > 2000:
                    out.append((rel, i + 1, 'LONG', len(l)))
            for i in range(len(L) - 6):
                a = L[i:i + 3]
                if all(x.strip() for x in a) and a == L[i + 3:i + 6]:
                    out.append((rel, i + 1, 'DUP_BLOCK', a[0][:60]))
            if f.endswith('.md'):
                hdr = None
                for i, l in enumerate(L):
                    s = l.strip()
                    if s.startswith('|') and s.endswith('|'):
                        n = s.count('|') - s.count('\\|') - s.count('`|`')
                        if hdr is None:
                            hdr = n
                        elif set(s.replace('|', '').strip()) <= set('-: '):
                            pass
                        elif n != hdr:
                            out.append((rel, i + 1, 'TABLE_COLS', '%d!=%d' % (n, hdr)))
                    else:
                        hdr = None
        elif f.endswith('.csv'):
            nfile += 1
            rows = [r for r in csv.reader(io.open(p, encoding='utf-8-sig', errors='replace', newline=''))
                    if not (r and r[0].startswith('#'))]
            if rows:
                w = len(rows[0])
                bad = [i + 1 for i, r in enumerate(rows) if r and len(r) != w]
                if bad:
                    out.append((rel, bad[0], 'CSV_COLS', '%d rows' % len(bad)))
print('files', nfile, 'findings', len(out))
for r in out:
    print(*r, sep=' | ')
