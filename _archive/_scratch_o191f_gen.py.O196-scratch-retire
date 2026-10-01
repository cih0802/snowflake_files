#!/usr/bin/env python3
"""O191-F 임시 — 2차-B 2단 2묶음(UNION·다원천 SILVER 9종) 명세 → 타입 조회 · 중복 검사 · DDL/모델 조각 생성·적용.
사용: python3 _scratch_o191f_gen.py check | apply"""
import io, json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sfconn import conn  # noqa: E402
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TAG = 'O191-F 2차-B 2단 2묶음'
T = lambda c: f"NULLIF(TRIM({c}),'')"
# model: (branches in UNION order, [(silver_col, {src: expr}, src_col_for_type)])
SPEC = {
 'CRM_EVENT': (['TM_MS_EVENT', 'TM_MS_CRMN'], [
   ('PRZWIN_PSNNL_CO', {'TM_MS_EVENT': 'PRZWIN_PSNNL_CO'}),
   ('PRZWIN_GFT_SNDNG_DE', {'TM_MS_EVENT': T('PRZWIN_GFT_SNDNG_DE')}),
   ('CRMN_PLACE_NM', {'TM_MS_CRMN': T('CRMN_PLACE_NM')}),
   ('CRMN_PART_STRT_DE', {'TM_MS_CRMN': T('CRMN_PART_STRT_DE')}),
   ('CRMN_PART_END_DE', {'TM_MS_CRMN': T('CRMN_PART_END_DE')}),
   ('TAT', {'TM_MS_CRMN': 'TAT'}),
   ('RESRCE_SRVC_FG', {'TM_MS_CRMN': T('RESRCE_SRVC_FG')}),
   ('CPR_DIV_CD', {'TM_MS_CRMN': T('CPR_DIV_CD')}),
   ('ENTRPS_CD', {'TM_MS_CRMN': T('ENTRPS_CD')}),
   ('USE_YN', {'TM_MS_CRMN': T('USE_YN')})]),
 'CRM_EVENT_PARTICIPATION': (['TD_MS_EVENT_PRTCPNT_DTL', 'TD_MS_CRMN_PRTCPNT'], [
   ('EVENT_PARTCPT_DIV_CD', {'TD_MS_EVENT_PRTCPNT_DTL': T('EVENT_PARTCPT_DIV_CD')}),
   ('RQST_DATE', {'TD_MS_CRMN_PRTCPNT': T('RQST_DATE')}),
   ('SELF_PARTCPT_CD', {'TD_MS_CRMN_PRTCPNT': T('SELF_PARTCPT_CD')}),
   ('ACMPNY_PARTCPT_CO', {'TD_MS_CRMN_PRTCPNT': 'ACMPNY_PARTCPT_CO'}),
   ('PARTCPT_TIME_CO', {'TD_MS_CRMN_PRTCPNT': 'PARTCPT_TIME_CO'}),
   ('RCPMNY_STAT_CD', {'TD_MS_CRMN_PRTCPNT': T('RCPMNY_STAT_CD')}),
   ('RCPMNY_DATE', {'TD_MS_CRMN_PRTCPNT': T('RCPMNY_DATE')}),
   ('REFND_DATE', {'TD_MS_CRMN_PRTCPNT': T('REFND_DATE')})]),
 'CRM_MEMBER': (['TM_MM_FDRM_MBER_INFO', 'TM_MM_ONCE_MBER_INFO'], [
   ('CHRCTR_RECPTN_YN', {'TM_MM_FDRM_MBER_INFO': T('f.CHRCTR_RECPTN_YN'), 'TM_MM_ONCE_MBER_INFO': T('o.CHRCTR_RECPTN_YN')}),
   ('SPECL_MNG_CD1', {'TM_MM_FDRM_MBER_INFO': T('f.SPECL_MNG_CD1'), 'TM_MM_ONCE_MBER_INFO': T('o.SPECL_MNG_CD1')}),
   ('FDRM_MBER_TRNSFER_FG', {'TM_MM_ONCE_MBER_INFO': T('o.FDRM_MBER_TRNSFER_FG')})]),
 'CRM_PAYMENT_BILLING': (['TM_PM_MBRFEE_ACMSLT', 'TM_PM_DNTN_DTLS'], [
   ('RQEST_MT', {'TM_PM_MBRFEE_ACMSLT': T('RQEST_MT')}),
   ('RQEST_SQNC', {'TM_PM_MBRFEE_ACMSLT': 'RQEST_SQNC'}),
   ('TOGETH_WTDRW_YN', {'TM_PM_MBRFEE_ACMSLT': T('TOGETH_WTDRW_YN')}),
   ('SETLE_ENTRPS_CD', {'TM_PM_MBRFEE_ACMSLT': T('SETLE_ENTRPS_CD'), 'TM_PM_DNTN_DTLS': T('SETLE_ENTRPS_CD')}),
   ('ONCE_CMPGN_CD', {'TM_PM_DNTN_DTLS': T('ONCE_CMPGN_CD')}),
   ('ACMSLT_DEPT_CD', {'TM_PM_DNTN_DTLS': T('ACMSLT_DEPT_CD')}),
   ('USE_YN', {'TM_PM_MBRFEE_ACMSLT': T('USE_YN'), 'TM_PM_DNTN_DTLS': T('USE_YN')})]),
 'CRM_RELATION_ACTIVITY': (['TM_RM_RELATNSP_LETTER_INFO', 'TM_RM_RELATNSP_GFTMNEY_INFO'], [
   ('LETTER_STAT_CD', {'TM_RM_RELATNSP_LETTER_INFO': T('LETTER_STAT_CD')}),
   ('LANG_CD', {'TM_RM_RELATNSP_LETTER_INFO': T('LANG_CD')}),
   ('ONLINE_POST_WRITNG_YN', {'TM_RM_RELATNSP_LETTER_INFO': T('ONLINE_POST_WRITNG_YN')}),
   ('ONLINE_INFLOW_CD', {'TM_RM_RELATNSP_LETTER_INFO': T('ONLINE_INFLOW_CD')}),
   ('UNREPLY_RSN_CD', {'TM_RM_RELATNSP_LETTER_INFO': T('UNREPLY_RSN_CD'), 'TM_RM_RELATNSP_GFTMNEY_INFO': T('UNREPLY_RSN_CD')}),
   ('MBRFEE_KEY', {'TM_RM_RELATNSP_GFTMNEY_INFO': 'MBRFEE_KEY'}),
   ('SETLE_DE', {'TM_RM_RELATNSP_GFTMNEY_INFO': 'SETLE_DE'}),
   ('SETLE_CD', {'TM_RM_RELATNSP_GFTMNEY_INFO': T('SETLE_CD')}),
   ('GFT_DIV_CD', {'TM_RM_RELATNSP_GFTMNEY_INFO': T('GFT_DIV_CD')}),
   ('GFTMNEY_DOLLAR_AMT', {'TM_RM_RELATNSP_GFTMNEY_INFO': 'GFTMNEY_DOLLAR_AMT'}),
   ('APRV_DE', {'TM_RM_RELATNSP_GFTMNEY_INFO': 'APRV_DE'}),
   ('TRNSFER_YN', {'TM_RM_RELATNSP_GFTMNEY_INFO': T('TRNSFER_YN')})]),
 'CRM_SEND_REQUEST': (['TM_MS_EMAIL_SNDNG', 'TM_MS_MSG_AT_SNDNG', 'TM_MS_PSTMTR_SNDNG', 'SND_REQ_MST'], [
   ('SNDNG_CD_ID', {s: T('SNDNG_CD_ID') for s in ('TM_MS_EMAIL_SNDNG', 'TM_MS_MSG_AT_SNDNG', 'TM_MS_PSTMTR_SNDNG')}),
   ('SNDNG_DTL_CD_ID', {s: T('SNDNG_DTL_CD_ID') for s in ('TM_MS_EMAIL_SNDNG', 'TM_MS_MSG_AT_SNDNG', 'TM_MS_PSTMTR_SNDNG')}),
   ('PRCS_DE', {s: 'PRCS_DE' for s in ('TM_MS_EMAIL_SNDNG', 'TM_MS_MSG_AT_SNDNG', 'TM_MS_PSTMTR_SNDNG')}),
   ('PRCS_YN', {'TM_MS_EMAIL_SNDNG': T('PRCS_YN')}),
   ('TMPLAT_ID', {'TM_MS_MSG_AT_SNDNG': T('TMPLAT_ID'), 'SND_REQ_MST': T('TMPL_CODE')}),
   ('ALTRTV_MSG_SNDNG_YN', {'TM_MS_MSG_AT_SNDNG': T('ALTRTV_MSG_SNDNG_YN'), 'SND_REQ_MST': T('ALT_SMS_YN')}),
   ('LQY_YN', {'TM_MS_PSTMTR_SNDNG': T('LQY_YN')}),
   ('RE_SNDNG_YN', {'TM_MS_PSTMTR_SNDNG': T('RE_SNDNG_YN')}),
   ('MSG_TYPE', {'SND_REQ_MST': T('MSG_TYPE')}),
   ('REGULARLY', {'SND_REQ_MST': T('REGULARLY')}),
   ('SEND_STATUS', {'SND_REQ_MST': T('SEND_STATUS')}),
   ('SEND_ROUND', {'SND_REQ_MST': 'SEND_ROUND'}),
   ('CONDITION_TITLE', {'SND_REQ_MST': T('CONDITION_TITLE')}),
   ('MENU_CODE', {'SND_REQ_MST': T('MENU_CODE')}),
   ('SERVICE_MENU_CODE', {'SND_REQ_MST': T('SERVICE_MENU_CODE')}),
   ('USE_YN', {'SND_REQ_MST': T('USE_YN')})]),
 'CRM_SEND_RESULT': (['TD_MS_EMAIL_LQY_SNDNG', 'TD_MS_MSG_AT_LQY_SNDNG', 'TD_MS_PSTMTR_LQY_SNDNG', 'SND_REQ_MST'], [
   ('RECPTN_CNT', {'TD_MS_EMAIL_LQY_SNDNG': 'SUM(RECPTN_CNT)'}),
   ('ALTRTV_SNDNG_CNT', {'TD_MS_MSG_AT_LQY_SNDNG': 'SUM(AT_ALTRTV_SNDNG_CNT)'}),
   ('SNDNG_STRT_DT', {'TD_MS_EMAIL_LQY_SNDNG': 'MIN(SNDNG_STRT_DT)'}),
   ('SNDNG_END_DT', {'TD_MS_EMAIL_LQY_SNDNG': 'MAX(SNDNG_END_DT)'}),
   ('RESVE_SNDNG_DE', {'TD_MS_MSG_AT_LQY_SNDNG': 'MIN(RESVE_SNDNG_DE)'}),
   ('SNDNG_SQNC', {'TD_MS_PSTMTR_LQY_SNDNG': 'MAX(SNDNG_SQNC)'}),
   ('SNDNG_TIT', {'TD_MS_PSTMTR_LQY_SNDNG': "MAX(NULLIF(TRIM(SNDNG_TIT),''))"})]),
 'CRM_SEND_MEMBER': (['TD_MS_EMAIL_SNDNG_DTLS', 'TD_MS_MSG_AT_SNDNG_DTLS', 'TD_MS_PSTMTR_SNDNG_DTL', 'SND_MEMBER_LIST'], [
   ('ALTRTV_MSG_SNDNG_YN', {'TD_MS_MSG_AT_SNDNG_DTLS': T('ALTRTV_MSG_SNDNG_YN')}),
   ('RELATNSP_KEY', {'TD_MS_PSTMTR_SNDNG_DTL': 'RELATNSP_KEY', 'SND_MEMBER_LIST': 'RELATNSP_KEY'}),
   ('MNG_NO', {'TD_MS_PSTMTR_SNDNG_DTL': T('MNG_NO')}),
   ('MSG_KEY', {'SND_MEMBER_LIST': T('MSG_KEY')}),
   ('CINFO', {'SND_MEMBER_LIST': T('CINFO')}),
   ('RESPONSED_YN', {'SND_MEMBER_LIST': T('RESPONSED_YN')}),
   ('RESPONSED_DT', {'SND_MEMBER_LIST': 'RESPONSED_DT'}),
   ('REAL_SEND_DT', {'SND_MEMBER_LIST': 'REAL_SEND_DT'})]),
 'CRM_CAMPAIGN': (['TM_CM_CMPGN_MNG'], [
   ('USE_DEPT_CD', {'TM_CM_CMPGN_MNG': T('c.USE_DEPT_CD')}),
   ('USE_SCOPE', {'TM_CM_CMPGN_MNG': T('c.USE_SCOPE')}),
   ('USE_YN', {'TM_CM_CMPGN_MNG': T('c.USE_YN')}),
   ('CMPGN_PRPT_YN', {'TM_CM_CMPGN_MNG': T('c.CMPGN_PRPT_YN')}),
   ('SPNSR_ENTRPRS_ID', {'TM_CM_CMPGN_MNG': T('c.SPNSR_ENTRPRS_ID')}),
   ('EMRGNCY_AID_BPLC_CD', {'TM_CM_CMPGN_MNG': T('c.EMRGNCY_AID_BPLC_CD')}),
   ('BRND_USE_YN', {'TM_CM_BRND_MNG': T('b.USE_YN')})]),
}
SRC_COL_OVERRIDE = {('SND_REQ_MST', 'TMPL_CODE'), ('SND_REQ_MST', 'ALT_SMS_YN')}


def src_col(expr):
    m = re.findall(r'(?:\b[a-z]\.)?\b([A-Z][A-Z0-9_]+)\b', expr)
    m = [x for x in m if x not in ('NULLIF', 'TRIM', 'SUM', 'MIN', 'MAX')]
    return m[0]


def ddl_type(dt, ln, p, s):
    if dt == 'TEXT': return f'VARCHAR({ln})'
    if dt == 'NUMBER': return f'NUMBER({p},{s})'
    return {'TIMESTAMP_NTZ': 'TIMESTAMP_NTZ', 'DATE': 'DATE', 'FLOAT': 'FLOAT', 'TIMESTAMP_LTZ': 'TIMESTAMP_LTZ'}.get(dt, dt)


CTE_FINAL = {'CRM_EVENT', 'CRM_EVENT_PARTICIPATION', 'CRM_SEND_MEMBER'}
RANK = {'NUMBER': 0, 'TEXT': 1}


def resolve(br, m):
    """원천별 표현식 보정(비TEXT 는 TRIM 제거) + 공통 타입(가장 넓은 쪽)."""
    types, exprs = [], {}
    for src, e in m.items():
        scol = src_col(e); dt, ln, p, s, cm = br[(src, scol)]
        if dt != 'TEXT' and e.startswith('NULLIF(TRIM('):
            e = re.sub(r"NULLIF\(TRIM\(([^)]+)\),''\)", r'\1', e)
        if e.startswith('SUM('): dt, p, s = 'NUMBER', 18, 0
        exprs[src] = e; types.append((dt, ln or 0, p or 0, s or 0, cm))
    base = {t[0] for t in types}
    if base == {'DATE', 'TIMESTAMP_NTZ'}:
        return {k: f'{v}::TIMESTAMP_NTZ' for k, v in exprs.items()}, 'TIMESTAMP_NTZ', types[0][4]
    if len(base) > 1: raise SystemExit(f'!! 타입 불일치 {m} {base}')
    dt = types[0][0]
    typ = ddl_type(dt, max(t[1] for t in types), max(t[2] for t in types), max(t[3] for t in types))
    return exprs, typ, types[0][4]


def apply(plan):
    ddlp = os.path.join(ROOT, '04_silver_design/08_SILVER_테이블DDL_20260714.sql')
    ddl = io.open(ddlp, encoding='utf-8').read().split('\n')
    for model, (branches, cols) in plan.items():
        mp = os.path.join(ROOT, f'10_dbt_pipeline/models/silver/crm/{model}.sql')
        L = io.open(mp, encoding='utf-8').read().split('\n')
        for src in branches:
            if model == 'CRM_CAMPAIGN':
                key = 'FROM base c'
            else:
                key = "source('bronze_crm','" + src + "')"
            idx = [i for i, l in enumerate(L) if key in l and l.lstrip().upper().startswith('FROM')]
            assert len(idx) == 1, (model, src, idx)
            first = src == branches[0]
            add = []
            for o in cols:
                e = o['exprs'].get(src) or (o['exprs'].get('TM_CM_BRND_MNG') if model == 'CRM_CAMPAIGN' else None)
                e = e or f"CAST(NULL AS {o['type']})"
                add.append(f"  ,{e} AS {o['col']}" if (first or model == 'CRM_SEND_MEMBER') else f"  ,{e}")
            if first or model == 'CRM_SEND_MEMBER':
                add.insert(0, f'  -- [2026-09-30 {TAG}] 누락 컬럼(원천별 분기 · 비해당 원천 = 형 맞춘 NULL · 감사컬럼 뒤)')
            L[idx[0]:idx[0]] = add
        if model == 'CRM_SEND_MEMBER':
            i = [k for k, l in enumerate(L) if l.strip().startswith('FROM snd_base')]; assert len(i) == 1
            L[i[0]:i[0]] = ['    ,' + ', '.join(o['col'] for o in cols)]
        if model in CTE_FINAL:
            i = [k for k, l in enumerate(L) if l.strip() == 'FROM base b']; assert len(i) == 1
            L[i[0]:i[0]] = [f"  ,b.{o['col']:<30} AS {o['col']}" for o in cols]
        io.open(mp, 'w', encoding='utf-8').write('\n'.join(L))
        # DDL CREATE
        h = [k for k, l in enumerate(ddl) if l.startswith(f'CREATE OR REPLACE TABLE GN_DW.SILVER.{model} (')]
        assert len(h) == 1, model
        e = next(k for k in range(h[0], len(ddl)) if ddl[k].startswith(') COMMENT'))
        pk = [k for k in range(h[0], e) if ddl[k].strip().startswith('PRIMARY KEY')]
        new = [f"    {o['col']:<19} {o['type']:<15} COMMENT '{o['comment']}'," for o in cols]
        if pk:
            ddl[pk[0]:pk[0]] = new
        else:
            last = e - 1
            while ddl[last].strip().startswith('--') or not ddl[last].strip(): last -= 1
            if not ddl[last].rstrip().endswith(','): ddl[last] = ddl[last].rstrip() + ','
            new[-1] = new[-1].rstrip(',')
            ddl[e:e] = new
    alters = [f'', f'-- 🆕 [2026-09-30 {TAG}] UNION·다원천 SILVER 9종 누락 컬럼 {sum(len(v[1]) for v in plan.values())}개 — DDL 선행 · ADMIN 적용 · 모델 후행']
    for model, (_, cols) in plan.items():
        for o in cols:
            alters.append(f"ALTER TABLE GN_DW.SILVER.{model} ADD COLUMN IF NOT EXISTS {o['col']} {o['type']} COMMENT '{o['comment']}';")
    ddl += alters
    io.open(ddlp, 'w', encoding='utf-8').write('\n'.join(ddl))
    io.open(os.path.join(ROOT, 'tmp/o191f_alters.sql'), 'w', encoding='utf-8').write('\n'.join(alters[2:]))


def main():
    mode = sys.argv[1]
    c = conn().cursor(); c.execute('use warehouse GN_DW_ETL_WH')
    c.execute("select table_name,column_name,data_type,character_maximum_length,numeric_precision,numeric_scale,comment from GN_DW.INFORMATION_SCHEMA.COLUMNS where table_schema='BRONZE_CRM'")
    br = {(r[0], r[1]): r[2:] for r in c.fetchall()}
    c.execute("select table_name,column_name from GN_DW.INFORMATION_SCHEMA.COLUMNS where table_schema='SILVER'")
    sv = {}
    for t, col in c.fetchall(): sv.setdefault(t, set()).add(col)
    plan = {}
    for model, (branches, cols) in SPEC.items():
        out = []
        for name, m in cols:
            exprs, typ, cm = resolve(br, m)
            scol = src_col(next(iter(m.values())))
            if name in sv.get(model, set()):
                print(f'!! 이미 존재 {model}.{name}')
            srcs = ' · '.join('BRONZE_CRM.' + x for x in m)
            out.append({'col': name, 'type': typ, 'exprs': exprs,
                        'comment': f"{(cm or scol).strip()} [원천 COMMENT · {srcs}] · {TAG}"})
        plan[model] = (branches, out)
        print(model, len(out), ' '.join(f"{o['col']}:{o['type']}" for o in out))
    json.dump(plan, io.open(os.path.join(ROOT, 'tmp/o191f_plan.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print('total', sum(len(v[1]) for v in plan.values()))
    if mode == 'apply': apply(plan); print('applied')


if __name__ == '__main__':
    main()
