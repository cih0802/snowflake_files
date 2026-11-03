import re,sys,csv,io
DEV=re.compile(r'SR61467|IW20760|개발계|\(개발\)',re.I)
def split_row(l):
    s=l.strip()
    if not(s.startswith('|') and s.endswith('|')): return None
    return [c for c in re.split(r'(?<!\\)\|',s[1:-1])]
def md(text):
    out=[];lines=text.split('\n');i=0
    while i<len(lines):
        r=split_row(lines[i])
        if r and i+1<len(lines) and split_row(lines[i+1]) and re.match(r'^\s*\|[\s:\-|]+\|\s*$',lines[i+1]):
            drop=[k for k,c in enumerate(r) if DEV.search(c) and not re.search('운영',c)]
            j=i
            while j<len(lines) and split_row(lines[j]) is not None: j+=1
            for l in lines[i:j]:
                if drop:
                    c=split_row(l); c=[x for k,x in enumerate(c) if k not in drop]; l='|'+'|'.join(c)+'|'
                out.append(l)
            i=j; continue
        out.append(lines[i]); i+=1
    t='\n'.join(out)
    t=re.sub(r'^(as_of: [^\n(]*)\(ZL50263 운영계 실측 캡처 반영 · 직전 IW20760\)',r'\1(ZL50263 운영계 실측)',t,flags=re.M)
    return t
def csvf(text):
    lines=text.split('\n'); hdr=[k for k,l in enumerate(lines) if l and not l.lstrip('\ufeff').startswith('#')]
    if not hdr: return text
    h=hdr[0]; rows=list(csv.reader(io.StringIO('\n'.join(lines[h:]))))
    drop=[k for k,c in enumerate(rows[0]) if DEV.search(c) and '운영' not in c]
    if not drop: return text
    b=io.StringIO(); w=csv.writer(b,lineterminator='\n')
    for r in rows: w.writerow([x for k,x in enumerate(r) if k not in drop])
    return '\n'.join(lines[:h])+'\n'+b.getvalue().rstrip('\n')+('\n' if text.endswith('\n') else '')
for f in sys.argv[1:]:
    t=open(f,encoding='utf-8').read()
    n=md(t) if f.endswith('.md') else csvf(t) if f.endswith('.csv') else t
    if n!=t: open(f,'w',encoding='utf-8').write(n); print('edited',f)
