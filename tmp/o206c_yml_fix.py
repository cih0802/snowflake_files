# O206-C — _wide_schema.yml WIDE_MEMBER_SERVICE_COHORT 의 stale 「임시 규칙」 문구 3곳 교정(단일 파일 · 해시 확인 · 토큰 대조)
# Co-authored with CoCo
import hashlib, io, sys
P = '10_dbt_pipeline/models/gold/wide/_wide_schema.yml'
h = lambda: hashlib.sha256(open(P, 'rb').read()).hexdigest()
assert h() == h()
t = io.open(P, encoding='utf-8').read()
R = [
    ('🔴서비스그룹은 발송 제목 부분일치 **임시 규칙**(현업 확인 대기).',
     '🟢[O206 A안] 서비스그룹은 원천 서비스코드(발송코드 MS049 상위 카테고리) 우선 · 카테고리가 없는 발송은 발송 제목 부분일치(MATCH_BASIS 로 근거 구분).'),
    ('서비스그룹 코드(임시 규칙) —', '서비스그룹 코드(O206 A안 · 서비스코드 우선 → 발송제목 보조) —'),
    ('서비스그룹 이름(임시 규칙 라벨). 현업 서비스명과 1:1 확정 전이다.',
     '서비스그룹 이름. 원천 서비스 카테고리명은 SVC_CATEGORY_NAMES 에 따로 있다(이 이름은 4그룹 묶음 라벨).'),
]
for a, b in R:
    n = t.count(a)
    print(n, a[:40])
    if n != 1:
        sys.exit('🔴 앵커 불일치 — 쓰지 않는다')
    t = t.replace(a, b)
if '--apply' in sys.argv:
    io.open(P, 'w', encoding='utf-8', newline='').write(t)
    print('WROTE', h()[:12])
