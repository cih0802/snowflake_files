# 답안(MSTR 결과 CSV) → GN_DW.MSTR.CHK_MSTR_ANSWER 적재 (원문 문자열 그대로 + 행번호 · 재실행 시 교체)
#   사용: python3 mstr_load_answer.py "../mstr-answer.csv" --batch 1차
import argparse, csv, io, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mstr_common as C

COLS = ['TEAM_GRP', 'SUB_GRP', 'BSNS_GRP', 'STRD_MT_NM', 'STRD_DE_NM', 'CPR_DIV_NM', 'DEPT4_NM', 'DEPT2_NM',
        'DEPT_NM', 'BRND_NM', 'UPPER_CMPGN_NM', 'CMPGN_NM', 'CMPGN_CD', 'DVLP_DIV_NM', 'SPNSR_BSNS2_NM',
        'SEX_NM', 'AGE_TERM_NM', 'DVLP_CNT_TXT', 'DVLP_MBR_TXT', 'RMK', 'CP_GRP']


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('csv')
    ap.add_argument('--batch', default='1차')
    a = ap.parse_args()
    rows = list(csv.reader(io.open(a.csv, encoding='utf-8-sig')))
    hdr, body = rows[0], rows[1:]
    if len(hdr) != len(COLS):
        sys.exit('컬럼 수 불일치 %d != %d' % (len(hdr), len(COLS)))
    cn = C.conn(); cur = cn.cursor()
    t = '%s.%s.CHK_MSTR_ANSWER' % (C.TARGET_DB, C.TARGET_SCHEMA)
    cur.execute('CREATE TABLE IF NOT EXISTS %s (BATCH VARCHAR, ROW_NO NUMBER, %s, LOAD_TS TIMESTAMP_NTZ) '
                "COMMENT = 'MSTR 원 리포트 답안(CSV 원문) — 이관 결과 대조용. 적재 = tools/mstr_load_answer.py'"
                % (t, ', '.join(c + ' VARCHAR' for c in COLS)))
    cur.execute('DELETE FROM %s WHERE BATCH = %%s' % t, (a.batch,))
    cur.executemany('INSERT INTO %s (BATCH, ROW_NO, %s, LOAD_TS) VALUES (%%s, %%s, %s, CURRENT_TIMESTAMP())'
                    % (t, ', '.join(COLS), ', '.join(['%s'] * len(COLS))),
                    [[a.batch, i + 1] + [v.strip() for v in r] for i, r in enumerate(body)])
    cur.execute('SELECT COUNT(*) FROM %s WHERE BATCH = %%s' % t, (a.batch,))
    print('LOADED', t, a.batch, cur.fetchone()[0], 'rows (csv', len(body), ')')


if __name__ == '__main__':
    main()
