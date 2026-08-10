# -*- coding: utf-8 -*-
"""[2026-08-07 O51-D] 생성된 columns 블록만 교체 반영(멱등). 주석·description 은 건드리지 않는다.
patch_yml.py 는 최초 반영용(주석 삽입·DIM 신규 등재 포함)이고, 이 스크립트는 **재반영 전용**이다."""
import io, re, sys
FILES = ['/workspace/10_dbt_pipeline/models/gold/wide/_wide_schema.yml',
         '/workspace/10_dbt_pipeline/models/gold/_gold_ready_schema.yml']
TARGETS = ['WIDE_MEMBER_MONTHLY','WIDE_MEMBER_EVENT','WIDE_SERVICE_EVENT',
           'WIDE_EVENT_PARTICIPATION','WIDE_MEMBER_FEE','WIDE_DEV_ACHIEVEMENT',
           'DIM_MEMBER_CURRENT','DIM_MEMBER_ACQUISITION']
def load(t): return io.open(f'/tmp/o51d_out/{t}.cols.yml',encoding='utf-8').read().rstrip('\n')

done=set()
for f in FILES:
    txt = io.open(f, encoding='utf-8').read()
    idx = [m.start() for m in re.finditer(r'(?m)^  - name: (\w+)\s*$', txt)]
    out, changed = [txt[:idx[0]]], 0
    for i,s in enumerate(idx):
        e = idx[i+1] if i+1 < len(idx) else len(txt)
        blk = txt[s:e]; name = re.match(r'  - name: (\w+)', blk).group(1)
        if name in TARGETS:
            lines, keep, j = blk.split('\n'), [], 0
            while j < len(lines):
                if re.match(r'^    columns:\s*$', lines[j]):
                    j += 1
                    while j < len(lines) and (lines[j].startswith('      ') or lines[j].strip()==''): j += 1
                    continue
                keep.append(lines[j]); j += 1
            blk = '\n'.join(keep).rstrip('\n') + '\n' + load(name) + '\n'
            changed += 1; done.add(name)
        out.append(blk)
    res = ''.join(out)
    io.open(f,'w',encoding='utf-8').write(res)
    print(f"{f.split('/')[-1]}: {changed}모델 columns 재반영 · {len(res):,}B")
missing = set(TARGETS)-done
if missing: sys.exit(f"🔴 미반영 모델: {missing}")
print("✅ 8/8 반영")
