# O252 현업 리뷰 CSV 생성 — 폐지·개편 부서 귀속 후보(중단 2024~2026 발생 부서만)
# 원천 = GN_DW.PUBLIC.TMP_O252_MODEL(= models/gold/dim/DIM_ORG_SUCCESSION.sql 렌더 결과 · 개발계)
import csv
import snowflake.connector

SQL = """
WITH st AS (
  SELECT SPNSR_ACMSLT_DEPT_CD d,
         COUNT_IF(DSCNTC_MONTH_KEY BETWEEN 202401 AND 202412) y24,
         COUNT_IF(DSCNTC_MONTH_KEY BETWEEN 202501 AND 202512) y25,
         COUNT_IF(DSCNTC_MONTH_KEY BETWEEN 202601 AND 202612) y26
  FROM GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN
  WHERE DSCNTC_MONTH_KEY BETWEEN 202401 AND 202612 GROUP BY 1)
SELECT m.OLD_DEPT_ID, m.OLD_DEPARTMENT, o.ORG_PATH old_org_path,
       o.ACMSLT_DIV_GROUP_NM old_acmslt_group, o.ACMSLT_DIV_NM old_acmslt_div,
       st.y24, st.y25, st.y26,
       m.MAP_METHOD, m.CUR_DEPT_ID, m.CUR_DEPARTMENT, m.CUR_ORG_PATH,
       m.FLOW_CAND_DEPT_ID, f.DEPT_NM flow_cand_nm, m.FLOW_EVIDENCE_CNT, m.FLOW_SHARE, m.FLOW_LIFT,
       CASE WHEN m.MAP_METHOD = 'UNMAPPED' THEN '필수'
            WHEN m.MAP_METHOD IN ('AUTO_ORG_PARENT','AUTO_ACMSLT_PARENT') THEN '권장(상위 귀속)'
            WHEN m.MAP_METHOD = 'AUTO_MEMBER_FLOW' AND m.FLOW_LIFT < 6 THEN '권장(근거 약함)'
            ELSE '선택' END review_priority,
       '' confirm_cur_dept_id, '' confirm_note
FROM GN_DW.PUBLIC.TMP_O252_MODEL m
JOIN st ON st.d = m.OLD_DEPT_ID
JOIN GN_DW.GOLD.DIM_ORG o ON o.ORG_SK = m.OLD_ORG_SK
LEFT JOIN GN_DW.SILVER.CRM_ORG f ON f.DEPT_ID = m.FLOW_CAND_DEPT_ID
WHERE m.MAP_METHOD <> 'SELF'
ORDER BY st.y24 + st.y25 + st.y26 DESC
"""

HDR_KO = [
    '폐지부서코드', '폐지부서명', '폐지부서_조직경로', '폐지부서_실적구분', '폐지부서_실적본부지부',
    '중단_2024', '중단_2025', '중단_2026',
    '귀속방법', '귀속부서코드', '귀속부서명', '귀속부서_조직경로',
    '회원흐름_후보코드', '회원흐름_후보명', '회원흐름_근거건수', '회원흐름_점유율', '회원흐름_lift',
    '검토우선순위', '확정_귀속부서코드(현업기입)', '확정_비고(현업기입)',
]

con = snowflake.connector.connect(connection_name='default')
try:
    cur = con.cursor()
    cur.execute(SQL)
    rows = cur.fetchall()
finally:
    con.close()

out = '/workspace/30_output_share/O252_폐지부서_귀속_현업리뷰_20261021.csv'
with open(out, 'w', encoding='utf-8-sig', newline='') as fh:
    w = csv.writer(fh)
    w.writerow(HDR_KO)
    for r in rows:
        w.writerow(['' if v is None else v for v in r])
print('rows', len(rows), out)
