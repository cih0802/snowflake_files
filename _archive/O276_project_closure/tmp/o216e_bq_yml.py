# O216-E — WIDE_BIGQUERY_BEHAVIOR yml: UTM_CAMPAIGN 컬럼 추가(말미) + 캠페인 3컬럼 「영구 센티넬」 태그
# 규약 = columns[] 는 SELECT 와 개수·순서 일치(뷰 머리 주석) ⇒ CAMPAIGN_NAME 항목 블록 바로 뒤에 1항목 삽입
# 사용: python3 tmp/o216e_bq_yml.py [--apply]
# Co-authored with CoCo
import hashlib, io, re, sys, yaml

P = '/workspace/10_dbt_pipeline/models/gold/wide/_wide_schema.yml'
V = 'WIDE_BIGQUERY_BEHAVIOR'
TAG = '[O216-E A4-W 영구 센티넬]'
INS = (TAG + ' GA4 이벤트에는 CRM 캠페인 키가 없고 UTM ↔ 캠페인이 1:N(최대 902)이라 배선하지 않는다 — '
       '이 컬럼으로 GROUP BY·필터하지 않는다(GA4 캠페인 분해는 UTM_CAMPAIGN 을 쓴다). ')
NEWCOL = ('UTM_CAMPAIGN',
          'FACT_BIGQUERY_BEHAVIOR.UTM_CAMPAIGN — GA4 캠페인 UTM 원값(utm_campaign · O190 degen). '
          '🆕 [O216-E] 이 뷰의 GA4 캠페인 축 정본이다. (not set)·(organic)·(referral) 은 GA4 원값이다. '
          '🔴 창 밖 과거 행은 NULL 일 수 있다(롤링 적재 · 전량 백필 전까지). '
          '🔴 CRM 캠페인(CAMPAIGN_BK)과 1:N 이라 캠페인 마스터 축으로 환산하지 않는다.')


def h():
    return hashlib.sha256(open(P, 'rb').read()).hexdigest()


h0 = h(); assert h0 == h(), '해시 불안정'
t = io.open(P, encoding='utf-8').read()
L = t.split('\n')
s = [i for i, x in enumerate(L) if re.match(r'^\s*- name:\s*' + V + r'\s*$', x)]
assert len(s) == 1
start = s[0]; ind_m = len(L[start]) - len(L[start].lstrip())
end = next((i for i in range(start + 1, len(L)) if re.match(r'^\s*- name:\s*\S+\s*$', L[i])
            and len(L[i]) - len(L[i].lstrip()) == ind_m), len(L))
if any('name: UTM_CAMPAIGN' in L[i] for i in range(start, end)):
    print('skip(이미 적용)'); sys.exit(0)
hits = {}
for i in range(start, end):
    m = re.match(r'^(\s*)- name:\s*(CAMPAIGN_BK|CAMPAIGN_BRAND|CAMPAIGN_NAME)\s*$', L[i])
    if m:
        j = next(k for k in range(i + 1, i + 6) if L[k].lstrip().startswith('description:'))
        hits[m.group(2)] = (i, j, m.group(1))
assert set(hits) == {'CAMPAIGN_BK', 'CAMPAIGN_BRAND', 'CAMPAIGN_NAME'}, hits
for col, (i, j, _) in hits.items():
    ln = L[j]; k = ln.index('description:') + len('description:'); rest = ln[k:].lstrip(); q = rest[:1]
    assert q in ('"', "'") and TAG not in ln
    L[j] = ln[:k] + ' ' + q + INS + rest[1:]
    assert len(L[j]) < 2000
# CAMPAIGN_NAME 항목 블록의 끝 = 다음 「- name:」(같은 들여쓰기) 직전
i_name, j_name, ind = hits['CAMPAIGN_NAME']
blk_end = next((k for k in range(j_name + 1, end) if re.match(r'^' + ind + r'- name:', L[k])
                or (L[k].strip() and len(L[k]) - len(L[k].lstrip()) < len(ind))), end)
assert blk_end == end or not L[blk_end].startswith(ind + '- name:'), 'CAMPAIGN_NAME 이 마지막 컬럼이 아니다'
desc = NEWCOL[1].replace('"', '\\"')
L[blk_end:blk_end] = [f'{ind}- name: {NEWCOL[0]}', f'{ind}  description: "{desc}"']
out = '\n'.join(L)
d = yaml.safe_load(out)
m = [x for x in d['models'] if x['name'] == V][0]
names = [c['name'] for c in m['columns']]
assert len(names) == 39 and names[-1] == 'UTM_CAMPAIGN' and names[-2] == 'CAMPAIGN_NAME', names[-3:]
assert sum(TAG in (c.get('description') or '') for c in m['columns']) == 3
print('columns', len(names), '· 말미', names[-2:], '· 태그 3')
if '--apply' in sys.argv:
    assert h() == h0, '편집 중 변경됨'
    io.open(P, 'w', encoding='utf-8', newline='').write(out)
    print('WROTE', h()[:12])
print('mode =', 'APPLY' if '--apply' in sys.argv else 'DRY-RUN')
