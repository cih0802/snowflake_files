#!/usr/bin/env python3
# O201-B ⑥-2 — 「후속 미등장」 후보 J3 판정: 핵심 토큰을 O190 이후 라벨·원장·문서50·문서20·라이브로 대조
import io, os, re, glob, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))
from sfconn import conn, q
rd = lambda p: io.open(p, encoding='utf-8').read()
later = [p for p in glob.glob(os.path.join(ROOT, '99_NEXT_SESSION_조각', '99_NEXT_SESSION-O0*-*.md')) if re.search(r'O0(19\d|20\d)-', p)]
docs = later + glob.glob(os.path.join(ROOT, '20_issue', '00_INDEX_이슈원장_조각', '*.md')) \
    + glob.glob(os.path.join(ROOT, '20_issue', '50_dbt_파이프라인_미결조치_조각', '*.md')) \
    + glob.glob(os.path.join(ROOT, '20_issue', '20_현업확인_요청_조각', '*.md'))
BODY = {p: rd(p) for p in docs}

def hits(tok):
    return sorted({os.path.basename(p) for p, s in BODY.items() if tok in s and re.search(r'O0?(19\d|20\d)|2026-(09-(29|30)|10-)', s)})

ITEMS = [  # (원 라벨, 항목, 대조 토큰)
    ('O180-A/B', 'jinja_config_gate 축5·축3', 'jinja_config_gate'),
    ('O180-A/B·O181', '--vars 무시 원인', '--vars'),
    ('O180-A/B·O181-B', 'SILVER_2.CRM_MEMBER_DEV GRANT UPDATE', 'GRANT UPDATE'),
    ('O180-A', '문서50·문서20 유형 재정의(증분형)', '증분형'),
    ('O180-B', 'I2 MUTATES 무플래그', 'MUTATES'),
    ('O180-B', 'doc_coord_gate 줄 내용 축', '줄 내용'),
    ('O181-B', '열린 문항 잔여 J3 실측 · §E·§M-4 질문 발행', '§M-4'),
    ('O181-B', 'sv_code_label_gate 재측정', 'sv_code_label_gate'),
    ('O182-A', 'dbt 전용 롤 GN_DW_DBT', 'GN_DW_DBT'),
    ('O182-A', 'VIDEO 캠페인 축 도달률 급락', 'VIDEO 캠페인'),
    ('O182-A', 'CRM 신규 3종 배선', '신규 3종'),
    ('O182-A', 'cortex-project.yaml P66 철회', 'P66'),
    ('O183-A', 'D5 발송유형 필터(DEC-33 ①)', 'DEC-33'),
    ('O183-A', '공45~47·54~57·77~78 비율 지표', '공45'),
    ('O183-C', 'WARN 21 확인', 'WARN 2'),
    ('O188-D', 'A-7·A-8·A-10·A-11', 'A-10'),
    ('O188-E', '30번 §2 질문 21건', '질문 21'),
    ('O188-E', 'W3·B2~B12 처분', 'W3'),
    ('O188-E', 'DGT 6월 이전분 재송부', 'DGT'),
    ('O188-F', '2차-B 연결 테이블 누락 컬럼', '2차-B'),
    ('O188-F', '새 GOLD 9종 SV 노출 여부', 'GOLD 9종'),
]
out = []
for lab, item, tok in ITEMS:
    h = hits(tok)
    out.append('%-16s %-40s 토큰=%-20s 후속문서 %d %s' % (lab, item, tok, len(h), ','.join(h[:3])))

cn = conn()
live = {}
_, r = q("SHOW ROLES LIKE 'GN_DW_DBT'", cn); live['GN_DW_DBT 롤'] = len(r)
_, r = q("SELECT COUNT(*) FROM GN_DW.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='GOLD' AND TABLE_NAME='DIM_ORG'", cn); live['DIM_ORG 실재'] = r[0][0]
_, r = q("SELECT COUNT(*) FROM GN_DW.GOLD.DIM_ORG", cn); live['DIM_ORG 행'] = r[0][0]
_, r = q("SHOW SEMANTIC VIEWS LIKE 'SV_TARGET_BIZ' IN SCHEMA GN_DW.SERVING", cn); live['SV_TARGET_BIZ'] = len(r)
_, r = q("SELECT COUNT(*) FROM GN_DW.INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='SILVER_2'", cn); live['SILVER_2 스키마'] = r[0][0]
cn.close()
out.append('라이브(JU93656) = ' + ' · '.join('%s %s' % kv for kv in live.items()))
txt = '\n'.join(out)
io.open(os.path.join(ROOT, 'tmp', '_o201b_o18x_j3.out'), 'w', encoding='utf-8').write(txt + '\n')
print(txt)
