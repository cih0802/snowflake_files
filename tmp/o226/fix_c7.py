#!/usr/bin/env python3
"""O226 ⑩ C7 — COMMENT 의 실재하지 않는 BRONZE 원천명을 dbt source() 기준 실명으로 교체(줄 지정 · 1회 치환).
매핑 근거 = 10_dbt_pipeline/models/silver/**.sql 의 source('bronze_crm', ...) 실측(O226)."""
import hashlib, io, sys

FIX = [  # (파일, 1-based 줄, 옛 토큰, 새 토큰)
    ('03_top-down_gold/06_DDL.sql', 83, 'TM_CM_DEPT_MNG', 'TM_CM_DEPT_INFO'),
    ('03_top-down_gold/06_DDL.sql', 117, 'TM_MM_MBER_MNG', 'TH_MM_FDRM_MBER_STNG_DTLS'),
    ('03_top-down_gold/06_DDL.sql', 414, 'TM_CM_CODE_DTL', 'TC_CMMN_DTL_CD'),
    ('04_silver_design/08_SILVER_테이블DDL_20260714.sql', 61, 'BRONZE_CRM.TM_MM_MBER_MNG', 'BRONZE_CRM.TM_MM_FDRM_MBER_INFO ∪ TM_MM_ONCE_MBER_INFO'),
    ('04_silver_design/08_SILVER_테이블DDL_20260714.sql', 79, 'TH_MM_MBER_STAT_HIST', 'TH_MM_FDRM_MBER_STNG_DTLS'),
    ('04_silver_design/08_SILVER_테이블DDL_20260714.sql', 187, 'TM_MM_FDRM_MBER_RSPNSR', 'TM_MM_FDRM_MBER_RE_SPNSR'),
    ('04_silver_design/08_SILVER_테이블DDL_20260714.sql', 203, 'TM_MM_MBER_SPNSR_BSNS', 'TM_MM_FDRM_MBER_SPNSR_BSNS'),
    ('04_silver_design/08_SILVER_테이블DDL_20260714.sql', 222, 'TM_MM_CHLDRN_STLM_INFO', 'TM_RM_RELATNSP_MSTR_INFO'),
    ('04_silver_design/08_SILVER_테이블DDL_20260714.sql', 298, 'TM_PM_SETLE_MNG', 'TM_PM_SETLE_INFO'),
    ('04_silver_design/08_SILVER_테이블DDL_20260714.sql', 383, 'TM_CM_DEPT_MNG', 'TM_CM_DEPT_INFO'),
    ('04_silver_design/08_SILVER_테이블DDL_20260714.sql', 605, 'TM_MM_LTR_EXCHG ∪ TM_MM_GIFT_DLVRY', 'TM_RM_RELATNSP_LETTER_INFO ∪ TM_RM_RELATNSP_GFTMNEY_INFO'),
    ('04_silver_design/08_SILVER_테이블DDL_20260714.sql', 624, 'TM_CM_CODE_DTL', 'TC_CMMN_DTL_CD'),
    ('04_silver_design/08_SILVER_테이블DDL_20260714.sql', 765, 'TM_CM_CMPGN_SPNSR_BSNS', 'TM_CM_CMPGN_MNG'),
    ('05_SV-Agent_ai/05_02_SV_DDL_MEMBER_EVENT.sql', 39, 'TM_CM_DEPT_MNG', 'TM_CM_DEPT_INFO'),
]
apply = '--apply' in sys.argv
files = {}
for f, n, old, new in FIX:
    p = '/workspace/' + f
    if p not in files:
        raw = io.open(p, encoding='utf-8', newline='').read()
        files[p] = [raw, raw.split('\n'), hashlib.sha256(raw.encode()).hexdigest()[:12]]
    L = files[p][1]
    c = L[n - 1].count(old)
    print(f'{f}:{n} {old} → {new} count={c}')
    if c != 1:
        sys.exit(f'🔴 ABORT: 줄 {n} 의 토큰 수 {c} ≠ 1')
    L[n - 1] = L[n - 1].replace(old, new)
for p, (raw, L, h) in files.items():
    out = '\n'.join(L)
    print(p, 'sha', h, '→', hashlib.sha256(out.encode()).hexdigest()[:12], 'Δchars', len(out) - len(raw))
    if apply:
        io.open(p, 'w', encoding='utf-8', newline='').write(out)
print('APPLIED' if apply else 'DRY-RUN')
