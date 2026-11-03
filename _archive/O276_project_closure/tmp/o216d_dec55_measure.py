# O216-D — DEC-55 §55-A 배선분 · §55-E 재측정 항목 라이브 실측(BLOCKING-5 종결 판정용)
# 판정식 = 배선 컬럼은 COUNT_IF(값 있음) > 0 · 55-E ㉡ = 0 · ㉠ = O183 의 675,370 대비 감소
# Co-authored with CoCo
import sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

c = conn().cursor()
c.execute('USE ROLE GN_DW_ADMIN'); c.execute('USE WAREHOUSE GN_DW_ETL_WH')
COLS = {
    'FACT_MEMBER_MONTHLY': ['UNPAID_CNT', 'ACTIVE_CUM_CNT', 'ACTIVE_CUM_MEMBERS', 'INCREASE_CNT', 'INCREASE_MEMBERS',
                            'DECREASE_CNT', 'CHURN_CNT', 'STATUS_UNPAID_CNT', 'DEV_TYPE', 'INCREASE_FLAG', 'REDONATE_FLAG',
                            'JOIN_DATE', 'STOP_DATE', 'SPONSOR_MONTHS', 'SPONSOR_YEARS', 'PAID_MONTHS', 'AMOUNT_BAND1',
                            'AMOUNT_BAND2', 'PERIOD_BAND1', 'PERIOD_BAND2', 'NEW_EXISTING_FLAG', 'NEW_FLAG'],
    'FACT_MEMBER_EVENT': ['NEW_EXISTING_FLAG'],
    'FACT_EVENT_ATTENDANCE': ['CONFIRM_CNT'],
}
c.execute("SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE FROM GN_DW.INFORMATION_SCHEMA.COLUMNS "
          "WHERE TABLE_SCHEMA = 'GOLD' AND TABLE_NAME IN ('FACT_MEMBER_MONTHLY','FACT_MEMBER_EVENT','FACT_EVENT_ATTENDANCE','FACT_MESSAGE_DISPATCH')")
types = {(t, col): dt for t, col, dt in c.fetchall()}
COLS['FACT_MESSAGE_DISPATCH'] = sorted(col for (t, col) in types if t == 'FACT_MESSAGE_DISPATCH'
                                       and (col.startswith('D5_') or col.startswith('SERVICE_')))
COLS['FACT_EVENT_ATTENDANCE'] += sorted(col for (t, col) in types if t == 'FACT_EVENT_ATTENDANCE' and col.endswith('_TIMES'))
bad = 0
for t, cols in COLS.items():
    exprs = []
    for col in cols:
        dt = types.get((t, col))
        if dt is None:
            print(f'🔴 부재 {t}.{col}'); bad += 1; continue
        num = dt in ('NUMBER', 'FLOAT', 'DECIMAL')
        exprs.append(f"COUNT_IF({col} IS NOT NULL{' AND ' + col + ' <> 0' if num else ''}) AS {col}")
    if not exprs:
        continue
    c.execute(f"SELECT COUNT(*), {', '.join(exprs)} FROM GN_DW.GOLD.{t}")
    row = c.fetchone(); names = [d[0] for d in c.description]
    print(f'{t} 행 {row[0]:,}')
    for n, v in zip(names[1:], row[1:]):
        flag = '🟢' if v else '🔴'
        bad += 0 if v else 1
        print(f'   {flag} {n} {v:,}')
c.execute("SELECT COUNT_IF(PAID_MONTHS > SPONSOR_MONTHS + 1), "
          "COUNT_IF(JOIN_DATE IS NULL AND HAS_BILLING_FLAG) FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY")
e = c.fetchone()
print(f'55-E ㉡ PAID_MONTHS>SPONSOR_MONTHS+1 = {e[0]:,} (기대 0) · ㉠ 청구행 JOIN_DATE NULL = {e[1]:,} (O183 675,370)')
print('배선 컬럼 공란·부재', bad)
