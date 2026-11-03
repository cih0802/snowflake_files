# O206 — 전 SV AI_SQL_GENERATION 에 「한글 출력 별칭」 공통 규칙을 넣는다 (멱등 · 해시 2회 확인 · R1-7-2)
# 사용: python3 tmp/o206_sv_korean_alias.py [--apply]
# Co-authored with CoCo
import glob, hashlib, io, re, sys

MARK = '[O206 출력 규칙'
RULE = ('[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". '
        '한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). '
        '동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. '
        '따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. '
        'ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). '
        '이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다.')

def sha(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()

apply = '--apply' in sys.argv
files = sorted(glob.glob('05_SV-Agent_ai/05_*_SV_DDL_*.sql') + ['05_SV-Agent_ai/22_ML_SV_DDL.sql', '05_SV-Agent_ai/23_MSTR_SV_DDL.sql'])
total = 0
for p in files:
    h1, h2 = sha(p), sha(p)
    if h1 != h2:
        print('UNSTABLE', p); continue
    t = io.open(p, encoding='utf-8').read()
    n_sv = len(re.findall(r'^CREATE OR ALTER SEMANTIC VIEW', t, re.M))
    if MARK in t:
        print('SKIP(이미 적용)', p, 'SV=%d' % n_sv); continue
    pat = re.compile(r"^(  AI_SQL_GENERATION ')", re.M)
    n_ai = len(pat.findall(t))
    new = pat.sub(lambda m: m.group(1) + RULE + '\n  ', t)
    added = 0
    if n_ai < n_sv:
        # 절이 없는 SV: SV 수준 COMMENT 문장(행 첫 2칸 COMMENT = '...';) 끝의 ; 앞에 절을 추가한다
        pat2 = re.compile(r"^(  COMMENT = '(?:[^']|'')*')(;)", re.M)
        new, added = pat2.subn(lambda m: m.group(1) + "\n  AI_SQL_GENERATION '" + RULE + "'" + m.group(2), new)
    print(('APPLY ' if apply else 'DRY   ') + p, 'SV=%d AI=%d +절=%d' % (n_sv, n_ai, added), 'sha=' + h1[:12])
    if n_ai + added != n_sv:
        print('  🔴 SV 수와 절 수 불일치 — 손으로 확인'); continue
    total += n_sv
    if apply:
        io.open(p, 'w', encoding='utf-8', newline='').write(new)
        print('  after sha=' + sha(p)[:12])
print('SV 합계 =', total)
