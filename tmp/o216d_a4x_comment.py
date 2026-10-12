# O216-D — O91-F A4-X 8건 「영구 센티넬」 COMMENT 명시(뷰 제외 대신 · GRANT 보존 · 승인 불요 권고안)
# 대상 = WIDE_BUDGET · WIDE_EVENT_PARTICIPATION · WIDE_MEMBER_MONTHLY · WIDE_SERVICE_EVENT 의 CAMPAIGN_BK·CAMPAIGN_NAME
# 방식 = _wide_schema.yml 의 description 앞에 1구절 삽입(텍스트 치환 · 멱등 · 해시 선확인) — 라이브 반영은 dbt build(O51 규약)
# 사용: python3 tmp/o216d_a4x_comment.py [--apply]
# Co-authored with CoCo
import hashlib, io, re, sys

P = '/workspace/10_dbt_pipeline/models/gold/wide/_wide_schema.yml'
VIEWS = ['WIDE_BUDGET', 'WIDE_EVENT_PARTICIPATION', 'WIDE_MEMBER_MONTHLY', 'WIDE_SERVICE_EVENT']
COLS = ['CAMPAIGN_BK', 'CAMPAIGN_NAME']
TAG = '[O216-D A4-X 영구 센티넬]'
INS = (TAG + ' 원천에 캠페인 연결 키가 없어 이 뷰에서는 **배선을 기다려도 값이 생기지 않는다** — '
       '이 컬럼으로 GROUP BY·필터하지 않는다(캠페인 분해는 FACT_MEMBER_EVENT·MSTR 를 쓴다). ')


def h():
    return hashlib.sha256(open(P, 'rb').read()).hexdigest()


h0 = h(); assert h0 == h(), '해시 불안정'
L = io.open(P, encoding='utf-8').read().split('\n')
cur_model = None; hits = []
for i, ln in enumerate(L):
    m = re.match(r'^\s*- name:\s*(\S+)\s*$', ln)
    if m:
        ind = len(ln) - len(ln.lstrip())
        if m.group(1) in VIEWS or m.group(1).startswith('WIDE_'):
            if ind <= 4:
                cur_model = m.group(1); continue
        if cur_model in VIEWS and m.group(1) in COLS:
            for j in range(i + 1, min(i + 6, len(L))):
                if L[j].lstrip().startswith('description:'):
                    hits.append((cur_model, m.group(1), j)); break
print('대상', len(hits), [(a, b) for a, b, _ in hits])
assert len(hits) == 8, '대상 수 ≠ 8'
n = 0
for v, col, j in hits:
    ln = L[j]
    if TAG in ln:
        continue
    k = ln.index('description:') + len('description:')
    rest = ln[k:].lstrip()
    q = rest[:1]
    assert q in ('"', "'"), f'{v}.{col} 인용 형식 미지원: {rest[:20]}'
    L[j] = ln[:k] + ' ' + q + INS + rest[1:]
    assert len(L[j]) < 2000, f'{v}.{col} 2000자 초과'
    n += 1
print('삽입', n)
if '--apply' in sys.argv and n:
    assert h() == h0, '편집 중 변경됨'
    io.open(P, 'w', encoding='utf-8', newline='').write('\n'.join(L))
    print('WROTE', h()[:12])
print('mode =', 'APPLY' if '--apply' in sys.argv else 'DRY-RUN')
