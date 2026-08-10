# -*- coding: utf-8 -*-
"""[2026-08-07 O51-D] build 전 자체 게이트.
`CREATE VIEW` 컬럼목록은 SELECT 와 개수·순서가 정확히 일치해야 하므로
모델 SELECT alias 순서 ↔ yml columns[] 순서를 직접 대조한다(물리 스캔만으로는 부족하다 —
모델이 바뀌고 아직 build 되지 않았으면 물리는 구판을 반영한다)."""
import io, re, sys, yaml
B='/workspace/10_dbt_pipeline/models/gold/'
MODELS = {
 'WIDE_MEMBER_MONTHLY': B+'wide/WIDE_MEMBER_MONTHLY.sql',
 'WIDE_MEMBER_EVENT':   B+'wide/WIDE_MEMBER_EVENT.sql',
 'WIDE_SERVICE_EVENT':  B+'wide/WIDE_SERVICE_EVENT.sql',
 'WIDE_EVENT_PARTICIPATION': B+'wide/WIDE_EVENT_PARTICIPATION.sql',
 'WIDE_MEMBER_FEE':     B+'wide/WIDE_MEMBER_FEE.sql',
 # 🔴 [2026-08-10 O53] 3모델 제외 — 뷰 → **테이블** 전환/개명으로 이 게이트의 전제가 사라졌다.
 #   (구) WIDE_DEV_ACHIEVEMENT → FACT_DEV_ACHIEVEMENT 테이블 · DIM_MEMBER_CURRENT·DIM_MEMBER_ACQUISITION 테이블.
 #   테이블은 `CREATE VIEW` 컬럼목록 제약이 없고 COMMENT 정본이 `06_DDL.sql` 이므로 대조 축이 다르다.
 #   ⇒ 그 3종의 DDL↔모델 대조는 `scripts/gen_o53_gold_ddl.py`(선언 정본) + build 시 append 정합이 담당한다.
 #   ⚠️ 여기서 「제외」는 검사 포기가 아니다 — 축이 옮겨간 것이다(P16 거짓 안전 방지).
 # [2026-08-10 O51-F] 광고 위성 2뷰 신규 이관 — 게이트 대상에 편입.
 #   🔴 편입하지 않으면 이 2모델의 컬럼목록 불일치가 build 시점까지 드러나지 않는다.
 'WIDE_AD_BROADCAST':   B+'wide/WIDE_AD_BROADCAST.sql',
 'WIDE_AD_DIGITAL':     B+'wide/WIDE_AD_DIGITAL.sql',
 # 🔴 [2026-08-10 O53] SV_AD 의 새 base — 51컬럼. 편입하지 않으면 컬럼목록 불일치가 build 까지 안 드러난다.
 'WIDE_AD_COMBINED':    B+'wide/WIDE_AD_COMBINED.sql',
}
def strip_comments(s):
    return "\n".join(re.sub(r'--.*$','',l) for l in s.split('\n'))

def select_aliases(path):
    t = io.open(path, encoding='utf-8').read()
    t = strip_comments(t)
    # 마지막 최상위 select ... from 구간
    ms = list(re.finditer(r'(?m)^select\b', t))   # 최상위(들여쓰기 0) select 중 마지막 = 최종 투영
    if not ms: return None
    tail = t[ms[-1].end():]
    fm = re.search(r'(?m)^from\b', tail)
    body = tail[:fm.start()] if fm else tail
    items, depth, cur = [], 0, ''
    for ch in body:
        if ch in '([': depth += 1
        elif ch in ')]': depth -= 1
        if ch == ',' and depth == 0:
            items.append(cur); cur = ''
        else:
            cur += ch
    if cur.strip(): items.append(cur)
    out = []
    for it in items:
        it = ' '.join(it.split())
        if not it: continue
        a = re.search(r'\s+as\s+([A-Za-z_]\w*)$', it, re.I)
        out.append((a.group(1) if a else it.split('.')[-1]).upper())
    return out

ymls = {}
for f in (B+'wide/_wide_schema.yml', B+'_gold_ready_schema.yml'):
    for mo in (yaml.safe_load(io.open(f,encoding='utf-8'))['models'] or []):
        if mo.get('columns'): ymls[mo['name']] = [c['name'] for c in mo['columns']]

fail = 0
for name, path in MODELS.items():
    sel = select_aliases(path); ym = ymls.get(name)
    if ym is None: print(f"🔴 {name}: yml columns[] 없음"); fail += 1; continue
    if sel == ym:
        print(f"✅ {name:<26} {len(sel):>3}컬럼 · SELECT 순서 완전일치")
    else:
        fail += 1
        print(f"🔴 {name:<26} SELECT {len(sel)} vs yml {len(ym)} 불일치")
        for i,(a,b) in enumerate(zip(sel,ym)):
            if a!=b: print(f"    [{i}] SELECT={a}  yml={b}"); break
        if len(sel)!=len(ym):
            print("    SELECT 만:", set(sel)-set(ym), " yml 만:", set(ym)-set(sel))

# TODO·escape 점검
for f in (B+'wide/_wide_schema.yml', B+'_gold_ready_schema.yml'):
    txt = io.open(f,encoding='utf-8').read()
    n = txt.count('TODO(O51-D)')
    print(("🔴 " if n else "✅ ") + f"{f.split('/')[-1]}: TODO(O51-D) {n}건")
    if n: fail += 1

# ══════════════════════════════════════════════════════════════════════════════
# [2026-08-10 O51-F] 완결성 게이트 — 「빈 축 스캔 위반 ↔ 문안」 대조를 **build 전** 에 한다.
#
# 🔴🔴 신설 사유(본 세션 실측): 이 대조를 **물리 COMMENT 기준으로 build 후에** 돌렸고, 그 결과
#   누락 18건이 build 뒤에 드러나 **재빌드가 발생했다.** 그런데 물리를 볼 이유가 없었다 —
#   문안 정본은 yml 이고 스캔 결과 파일도 이미 있었다. ⇒ 기준을 yml 로 바꿔 build 전으로 옮긴다.
#   🆕 P120: 「무엇이 빠졌나」를 묻는 검사는 **정본(yml) 기준으로 build 전** 에 돌린다.
#     물리 기준 검사는 「반영됐나」만 물어야 한다. 둘을 섞으면 build 가 검증 수단이 되어
#     build → 적발 → 재빌드 루프가 생긴다. **build 는 반영 수단이다.**
#
# 판정: 스캔이 「전건NULL·전건센티넬·단일값」으로 지목한 컬럼은 문안이 그 사실을 말해야 한다.
#   면제 = 설계상 단일값이 정상인 컬럼(원천별 수직분할 뷰의 DW_SOURCE_SYSTEM). 근거 = 이슈원장 §O51-F.
import os
SCAN = '/tmp/nullscan8.txt'
EXEMPT_COLS = {'DW_SOURCE_SYSTEM'}
KEY = ('전건 NULL','전건NULL','센티넬','단일값','미주입','0행','비어 있다','원천부재')

if not os.path.exists(SCAN):
    print("⚠️  완결성 게이트 건너뜀 — 스캔 결과 없음(%s). nullscan8 을 먼저 돌릴 것." % SCAN)
else:
    ymld = {}
    for f in (B+'wide/_wide_schema.yml', B+'_gold_ready_schema.yml'):
        for mo in (yaml.safe_load(io.open(f,encoding='utf-8'))['models'] or []):
            if mo.get('columns'):
                ymld[mo['name']] = {c['name']: (c.get('description') or '') for c in mo['columns']}
    silent, exempt = [], 0
    for line in io.open(SCAN, encoding='utf-8'):
        p2 = line.rstrip('\n').split('\t')
        if len(p2) < 4: continue
        v, col, flag = p2[0], p2[1], p2[3]
        if col in EXEMPT_COLS:
            exempt += 1; continue
        d = ymld.get(v, {}).get(col)
        if d is None:
            silent.append((v, col, 'yml 미등재')); continue
        if not any(k in d for k in KEY):
            silent.append((v, col, flag))
    print(("🔴 " if silent else "✅ ") + "완결성: 스캔 위반 대조 · 문안 침묵 %d건 · 설계상 면제 %d건" % (len(silent), exempt))
    for v, col, fl in silent:
        print("    🔴 침묵: %s.%s (%s)" % (v, col, fl))
    if silent: fail += 1

print("\n" + ("🔴 게이트 실패" if fail else "✅ 게이트 전항 통과 — dbt build 가능"))
sys.exit(1 if fail else 0)
