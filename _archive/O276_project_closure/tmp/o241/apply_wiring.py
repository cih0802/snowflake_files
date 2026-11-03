# O241 ⑥ 3단계 — 판정표(㉠)를 SV DDL 동의어에 반영(일회용 · 멱등)
#   --check : 판정표 커버리지·필드 실재만 검증(쓰기 없음) · 인자 없음 = 반영
import csv, io, os, re, shutil, sys
os.chdir('/workspace')
SVDIR = '05_SV-Agent_ai'
BAK = 'tmp/o241/bak'
dec = [r for r in csv.DictReader(io.open('tmp/o241/wiring_decisions.tsv', encoding='utf-8'), delimiter='\t')]
want = {r['지표#'] for r in csv.DictReader(io.open('tmp/o241/unwired_121.csv', encoding='utf-8-sig'))}
got = {r['지표#'] for r in dec if r['판정'] != '-'}
print('판정 대상', len(want), '판정', len(got), '누락', sorted(want - got), '초과', sorted(got - want))

files = {}
for fn in sorted(os.listdir(SVDIR)):
    if re.match(r'05_\d+_SV_DDL_.+\.sql$', fn):
        t = io.open(os.path.join(SVDIR, fn), encoding='utf-8').read()
        m = re.search(r'SEMANTIC VIEW [\w.]*?(SV_\w+)', t)
        if m:
            files[m.group(1)] = fn

todo = {}
for r in dec:
    if r['판정'] != '㉠':
        continue
    k = r['지표#']
    tok = ('공' + k[1:]) if k.startswith('공') else ('신규' + k[1:])
    for f in [x for x in r['대상필드'].split(';') if x]:
        sv, fld = f.split('.')
        todo.setdefault(sv, {}).setdefault(fld, []).append(tok)

ITEM = re.compile(r'^ {4}(\w+)\.(\w+)\s+AS\s')
miss, changed = [], {}
for sv, flds in sorted(todo.items()):
    fn = files.get(sv)
    if not fn:
        miss.append(sv + ' (SV 파일 없음)')
        continue
    p = os.path.join(SVDIR, fn)
    lines = io.open(p, encoding='utf-8').read().split('\n')
    starts = {}
    for i, ln in enumerate(lines):
        m = ITEM.match(ln)
        if m and m.group(2) not in starts:
            starts[m.group(2)] = i
    for fld, toks in flds.items():
        if fld not in starts:
            miss.append(f'{sv}.{fld}')
            continue
        i = starts[fld]
        j = i + 1
        while j < len(lines) and not ITEM.match(lines[j]) and not re.match(r'^ {0,2}\S', lines[j]):
            j += 1
        span = range(i, j)
        body = '\n'.join(lines[i:j])
        add = [t for t in dict.fromkeys(toks) if f"'{t}'" not in body]
        if not add:
            continue
        ins = ', '.join(f"'{t}'" for t in add)
        done = False
        for x in span:
            k0 = lines[x].find('WITH SYNONYMS (')
            if k0 >= 0:
                # 🔴 닫는 괄호는 따옴표 밖에서만 찾는다(동의어 안 「개발(건)」 괄호 오인 = 1차 실패 원인)
                q, end = False, -1
                for c in range(k0 + len('WITH SYNONYMS ('), len(lines[x])):
                    ch = lines[x][c]
                    if ch == "'":
                        q = not q
                    elif ch == ')' and not q:
                        end = c
                        break
                if end < 0:
                    done = None
                    break
                lines[x] = lines[x][:end] + ', ' + ins + lines[x][end:]
                done = True
                break
        if done is None:
            miss.append(f'{sv}.{fld} (동의어 괄호가 줄을 넘는다)')
            continue
        if not done:
            for x in span:
                if ' COMMENT = ' in lines[x]:
                    lines[x] = lines[x].replace(' COMMENT = ', f' WITH SYNONYMS ({ins}) COMMENT = ', 1)
                    done = True
                    break
                if lines[x].strip().startswith('COMMENT = '):
                    ind = lines[x][:len(lines[x]) - len(lines[x].lstrip())]
                    lines.insert(x, f'{ind}WITH SYNONYMS ({ins})')
                    done = True
                    break
        if not done:
            miss.append(f'{sv}.{fld} (삽입 위치 없음)')
            continue
        changed.setdefault(fn, []).append(f'{fld}+{",".join(add)}')
    if '--check' not in sys.argv and fn in changed:
        os.makedirs(BAK, exist_ok=True)
        b = os.path.join(BAK, fn + '.O241-before')
        if not os.path.exists(b):
            shutil.copyfile(p, b)
        io.open(p, 'w', encoding='utf-8').write('\n'.join(lines))
print('부재', miss)
for fn, c in changed.items():
    print(fn, len(c), '항목')
