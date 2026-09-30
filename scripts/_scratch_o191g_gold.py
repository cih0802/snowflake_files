#!/usr/bin/env python3
"""O191-G 임시 — 2차-B GOLD 전파 38컬럼: SILVER 라이브 타입 → 06_DDL CREATE 삽입 + ALTER 생성.
사용: python3 _scratch_o191g_gold.py check | apply | alter"""
import io, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sfconn import conn  # noqa: E402
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DDL = os.path.join(ROOT, '03_top-down_gold/06_DDL.sql')
TAG = 'O191-G 2차-B GOLD 전파'
# gold table: (silver table, [(gold_col, silver_col)])
SPEC = {
 'DIM_EVENT': ('CRM_EVENT', ['PRZWIN_PSNNL_CO', 'PRZWIN_GFT_SNDNG_DE', 'CRMN_PLACE_NM', 'CRMN_PART_STRT_DE',
               'CRMN_PART_END_DE', 'TAT', 'RESRCE_SRVC_FG', 'CPR_DIV_CD', 'ENTRPS_CD', 'USE_YN']),
 'DIM_CAMPAIGN': ('CRM_CAMPAIGN', ['USE_DEPT_CD', 'USE_SCOPE', 'USE_YN', 'CMPGN_PRPT_YN', 'SPNSR_ENTRPRS_ID',
                  'EMRGNCY_AID_BPLC_CD', 'BRND_USE_YN']),
 'DIM_MEMBER': ('CRM_MEMBER', ['CHRCTR_RECPTN_YN', 'SPECL_MNG_CD1', 'FDRM_MBER_TRNSFER_FG']),
 'DIM_SPONSORSHIP': ('CRM_SPONSORSHIP', ['SORT_ORDR', 'USE_YN']),
 'FACT_EVENT_ATTENDANCE': ('CRM_EVENT_PARTICIPATION', ['EVENT_PARTCPT_DIV_CD', 'RQST_DATE', 'SELF_PARTCPT_CD',
                           'ACMPNY_PARTCPT_CO', 'PARTCPT_TIME_CO', 'RCPMNY_STAT_CD', 'RCPMNY_DATE', 'REFND_DATE']),
 'FACT_MESSAGE_DISPATCH': ('CRM_SEND_MEMBER', ['ALTRTV_MSG_SNDNG_YN', 'RELATNSP_KEY', 'MNG_NO', 'MSG_KEY', 'CINFO',
                           'RESPONSED_YN', 'RESPONSED_DT', 'REAL_SEND_DT']),
}


def typ(dt, ln, p, s):
    if dt == 'TEXT': return f'VARCHAR({ln})'
    if dt == 'NUMBER': return f'NUMBER({p},{s})'
    return dt


def main():
    mode = sys.argv[1]
    c = conn().cursor(); c.execute('use warehouse GN_DW_ETL_WH')
    c.execute("select table_name,column_name,data_type,character_maximum_length,numeric_precision,numeric_scale,comment "
              "from GN_DW.INFORMATION_SCHEMA.COLUMNS where table_schema='SILVER'")
    sv = {(r[0], r[1]): r[2:] for r in c.fetchall()}
    c.execute("select table_name,column_name from GN_DW.INFORMATION_SCHEMA.COLUMNS where table_schema='GOLD'")
    gd = {(r[0], r[1]) for r in c.fetchall()}
    rows = []
    for g, (s, cols) in SPEC.items():
        for col in cols:
            dt, ln, p, sc, cm = sv[(s, col)]
            base = cm.split(' [원천 COMMENT')[0]
            src = cm.split('[원천 COMMENT · ')[1].split(']')[0] if '[원천 COMMENT · ' in cm else s
            rows.append((g, col, typ(dt, ln, p, sc), f"{base} [SILVER.{s} 승계 · 원천 {src}] · {TAG}"))
            if (g, col) in gd: print('!! 이미 존재', g, col)
    print('cols', len(rows))
    if mode == 'check':
        for r in rows: print(r[0], r[1], r[2])
        return
    alters = [f"ALTER TABLE GN_DW.GOLD.{g} ADD COLUMN IF NOT EXISTS {col} {t} COMMENT '{cm}';" for g, col, t, cm in rows]
    if mode == 'alter':
        c.execute('use role GN_DW_ADMIN')
        for a in alters: c.execute(a)
        print('alter', len(alters)); return
    L = io.open(DDL, encoding='utf-8').read().split('\n')
    for g in SPEC:
        h = [k for k, l in enumerate(L) if l.startswith(f'CREATE OR REPLACE TABLE GN_DW.GOLD.{g} (')]
        assert len(h) == 1, g
        e = next(k for k in range(h[0], len(L)) if L[k].startswith(')'))
        pk = [k for k in range(h[0], e) if L[k].strip().startswith(('PRIMARY KEY', 'CONSTRAINT'))]
        new = [f"    {col:<22} {t:<15} COMMENT '{cm}'," for gg, col, t, cm in rows if gg == g]
        if pk:
            L[pk[0]:pk[0]] = new
        else:
            last = e - 1
            while L[last].strip().startswith('--') or not L[last].strip(): last -= 1
            if not L[last].rstrip().endswith(','): L[last] = L[last].rstrip() + ','
            new[-1] = new[-1].rstrip(',')
            L[e:e] = new
    L += ['', f'-- 🆕 [2026-09-30 {TAG}] SILVER 2차-B 컬럼 중 같은 grain GOLD 6종 {len(rows)}컬럼'
              ' — DDL 선행 · ADMIN 적용 · 모델 후행 · 문서32 §3 원칙'] + alters
    io.open(DDL, 'w', encoding='utf-8').write('\n'.join(L))
    print('applied')


if __name__ == '__main__':
    main()
