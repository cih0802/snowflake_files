# O216-G — Q10 「코드 없음」 확정(사용자 2026-10-12) → AD 캠페인 컬럼 「영구 센티넬」 태그(_wide_schema.yml)
# 대상 = WIDE_AD_BROADCAST.CAMPAIGN_NAME · WIDE_AD_BROADCAST_CASE.CAMPAIGN_NAME · WIDE_AD_PERFORMANCE.CAMPAIGN_BK·CAMPAIGN_NAME·CAMPAIGN_BRAND
# 실측(CK24285) = 전건 '(미매핑)' 단일값 또는 전건 NULL · 원장·광고 원천에 개발캠페인 코드 컬럼 0(Q10)
# 방식 = o216e_bq_yml.py 와 같다(description 앞 1구절 · 멱등 · 해시 선확인 · YAML 파싱 검증) · 라이브 = 다음 dbt build
# 사용: python3 tmp/o216g_ad_yml.py [--apply]
# Co-authored with CoCo
import hashlib, io, re, sys, yaml

P = '/workspace/10_dbt_pipeline/models/gold/wide/_wide_schema.yml'
TARGET = {'WIDE_AD_BROADCAST': {'CAMPAIGN_NAME'}, 'WIDE_AD_BROADCAST_CASE': {'CAMPAIGN_NAME'},
          'WIDE_AD_PERFORMANCE': {'CAMPAIGN_BK', 'CAMPAIGN_NAME', 'CAMPAIGN_BRAND'}}
TAG = '[O216-G Q10 영구 센티넬]'
INS = (TAG + ' 광고 원천·예산 원장에 개발캠페인 코드가 없다(현업 회신 Q10 「코드 없음」) — 배선되지 않으며 '
       '이 컬럼으로 GROUP BY·필터하지 않는다(광고는 마케팅캠페인·UTM 캠페인·매체 축으로 분해한다). ')


def h():
    return hashlib.sha256(open(P, 'rb').read()).hexdigest()


h0 = h(); assert h0 == h(), '해시 불안정'
L = io.open(P, encoding='utf-8').read().split('\n')
model = None; model_ind = None; hits = []
for i, ln in enumerate(L):
    m = re.match(r'^(\s*)- name:\s*(\S+)\s*$', ln)
    if not m:
        continue
    ind = len(m.group(1))
    if m.group(2).startswith('WIDE_') and (model_ind is None or ind <= model_ind):
        model, model_ind = m.group(2), ind; continue
    if model in TARGET and m.group(2) in TARGET[model] and ind > model_ind:
        j = next(k for k in range(i + 1, i + 6) if L[k].lstrip().startswith('description:'))
        hits.append((model, m.group(2), j))
print('대상', len(hits), [(a, b) for a, b, _ in hits])
assert len(hits) == 5, '대상 수 ≠ 5'
n = 0
for v, col, j in hits:
    ln = L[j]
    if TAG in ln:
        continue
    k = ln.index('description:') + len('description:'); rest = ln[k:].lstrip(); q = rest[:1]
    assert q in ('"', "'"), f'{v}.{col} 인용 형식 미지원'
    L[j] = ln[:k] + ' ' + q + INS + rest[1:]
    assert len(L[j]) < 2000
    n += 1
out = '\n'.join(L)
d = yaml.safe_load(out)
cnt = sum(TAG in (c.get('description') or '') for m in d['models'] for c in m.get('columns', []))
assert cnt == 5, cnt
print('삽입', n, '· YAML OK · 태그', cnt)
if '--apply' in sys.argv and n:
    assert h() == h0, '편집 중 변경됨'
    io.open(P, 'w', encoding='utf-8', newline='').write(out)
    print('WROTE', h()[:12])
print('mode =', 'APPLY' if '--apply' in sys.argv else 'DRY-RUN')
