#!/usr/bin/env python3
"""O227 ③-① C3 테이블 레벨 22건 — 이슈ID·경위 문구를 업무 명칭으로 치환(파일 정본 + 라이브 ALTER · 기본 dry-run).
사용: python3 tmp/o227/fix_c3_tbl.py [--apply]
Co-authored with CoCo
"""
import hashlib, io, sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

G = '/workspace/03_top-down_gold/06_DDL.sql'
S = '/workspace/04_silver_design/08_SILVER_테이블DDL_20260714.sql'
# 업무 명칭 = 10_dbt_pipeline/models/silver/crm/<모델>.sql 1행 머리말(O188-F 작성) 그대로
NM = {
    'CRM_BIZ_PLACE': '결연 사업장 마스터',
    'CRM_CHILD': '결연 아동 마스터',
    'CRM_CODE_GROUP': '공통 코드그룹 마스터',
    'CRM_INSTT_ACCOUNT': '기관 입금 계좌',
    'CRM_MSG_TEMPLATE': '발송 템플릿 마스터(알림톡 ∪ 이메일)',
    'CRM_MSG_TEMPLATE_BUTTON': '알림톡 템플릿 버튼',
    'CRM_PAYMENT_METHOD_HIST': '결제수단 변경 이력',
    'CRM_RELATION_CHANGE': '결연 교체 이력',
    'CRM_RELATION_DEV': '결연 개발금액 사건(결연 개발·상태 전이)',
    'CRM_SETLE_CMPNY_ACCOUNT': '결제사 계정',
}
GOLD = {
    'DIM_BIZ_PLACE': 'CRM_BIZ_PLACE', 'DIM_CHILD': 'CRM_CHILD', 'DIM_CODE_GROUP': 'CRM_CODE_GROUP',
    'DIM_MSG_TEMPLATE': 'CRM_MSG_TEMPLATE', 'DIM_MSG_TEMPLATE_BUTTON': 'CRM_MSG_TEMPLATE_BUTTON',
    'DIM_PAYMENT_ACCOUNT': 'CRM_INSTT_ACCOUNT', 'FACT_PAYMENT_METHOD_CHANGE': 'CRM_PAYMENT_METHOD_HIST',
    'FACT_RELATION_CHANGE': 'CRM_RELATION_CHANGE', 'FACT_RELATION_DEV': 'CRM_RELATION_DEV',
}
# (파일, 스키마, 객체, 옛 조각, 새 조각, 지운 ID)
JOBS = []
for t, nm in NM.items():
    JOBS.append((S, 'SILVER', t, f"'{t} — O188-F 2차-A 신설.", f"'{nm}.", 'O188-F'))
for g, s in GOLD.items():
    JOBS.append((G, 'GOLD', g, f"'{g} — O188-F 2차-A 신설.", f"'{NM[s]}.", 'O188-F'))
JOBS.append((G, 'GOLD', 'FACT_BUDGET', '(1행=1예산 · 2026-10-02 O198 DEC-60 확장 · 원천 원장 grain 과 일치)',
             '(1행=1예산 · 원천 원장 grain 과 일치)', 'O198, DEC-60'))
JOBS.append((G, 'GOLD', 'DIM_SEND_REQUEST', '요청 속성을 팩트에 degen 하지 않는다(DEC-58)]',
             '요청 속성을 팩트에 degen 하지 않는다]', 'DEC-58'))

apply = '--apply' in sys.argv
cur = conn().cursor() if apply else None
txt = {}
for f in (G, S):
    a = hashlib.sha256(open(f, 'rb').read()).hexdigest()
    b = hashlib.sha256(open(f, 'rb').read()).hexdigest()
    assert a == b, 'hash unstable ' + f
    txt[f] = io.open(f, encoding='utf-8').read()
out = []
for f, sch, obj, old, new, ids in JOBS:
    L = txt[f].split('\n')
    hit = [i for i, s in enumerate(L) if s.startswith(') COMMENT = ') and old in s]
    if len(hit) != 1:
        sys.exit(f'🔴 ABORT {obj}: 앵커 적중 {len(hit)}')
    i = hit[0]
    L[i] = L[i].replace(old, new, 1)
    txt[f] = '\n'.join(L)
    cmt = L[i][len(') COMMENT = \''):-2]
    out.append(f'{sch}.{obj} | 지운 ID = {ids} | {cmt[:120]}')
    if cur:
        cur.execute(f"ALTER TABLE GN_DW.{sch}.{obj} SET COMMENT = '{cmt}'")
if apply:
    for f in (G, S):
        io.open(f, 'w', encoding='utf-8').write(txt[f])
print('\n'.join(out))
print(len(out), 'APPLIED' if apply else 'DRY-RUN')
