# O197 — MSTR 1차 이관 추출본 재생성(구분자 결함 수정 + 누락 의존 5종 추가)
# 원본(UTF-16LE) 4종 → 추출본(UTF-8) 4종. 읽기 전용 원본 · 출력은 추출 폴더 4파일만 덮는다.
import re, io, os

SRC = '/workspace/15_MSTR 이관 PoC/mstr DDL 원본'
DST = SRC + '/1차 이관대상 관련 추출'
SEP = '\n\n-- ' + '=' * 70 + '\n\n'

TARGETS = {
    'table_script.sql': ('TABLE', [
        'F_MM_SPNSR_DVLP_SUM', 'F_MM_SPNSR_DVLP', 'D_BRND_CD', 'D_CMPGN_CD',
        'D_SPNSR_BSNS_INFO', 'D_CMMN_DTL_CD', 'D_STRD_CAL_CD', 'D_CM_DEPT_INFO',
        'D_CMPGN_EXPL_CD', 'D_MBER_DVLP_GOAL_CD', 'BchLog']),
    'view_script.sql': ('VIEW', [
        'D_DVLP_DIV_CD', 'D_STRD_DE_CD', 'D_CPR_DIV_CD', 'D_DEPT4_CD', 'D_DEPT_CD',
        'D_DEPT3_CD', 'D_UP_CMPGN_CD', 'D_SEX_CD', 'D_AGE_TERM_CD', 'D_DEPT2_CD',
        'D_PR_MTH_CD', 'D_STRD_MT_CD', 'D_SPNSR_BSNS_V']),
    'sp_script.sql': ('PROCEDURE', [
        'USP_F_MM_SPNSR_DVLP_SUM', 'USP_F_MM_SPNSR_DVLP_SUM_INIT', 'USP_F_MM_SPNSR_DVLP',
        'USP_D_BRND_CD', 'USP_D_CMPGN_CD', 'USP_D_CMPGN_EXPL_CD', 'USP_D_SPNSR_BSNS_INFO',
        'USP_D_STRD_DE_CD', 'USP_D_CM_DEPT_INFO', 'USP_D_CMMN_DTL_CD', 'USP_D_STRD_CAL_CD',
        'USP_D_MBER_DVLP_GOAL_CD', 'USP_BCHLOG', 'USP_BCHERR']),
    'function_script.sql': ('FUNCTION', ['FN_MM_ACT_DATE', 'FN_MM_SPNSR_DVLP']),
}

for fname, (kind, names) in TARGETS.items():
    text = io.open(os.path.join(SRC, fname), encoding='utf-16').read().replace('\r\n', '\n')
    starts = [m.start() for m in re.finditer(r'(?im)^CREATE\s+(?:TABLE|VIEW|PROCEDURE|PROC|FUNCTION)\b', text)]
    starts.append(len(text))
    blocks = {}
    for s, e in zip(starts, starts[1:]):
        b = text[s:e]
        m = re.match(r'CREATE\s+\w+\s+(?:\[?\w+\]?\.)?\[?(\w+)\]?', b, re.I)
        # 블록 끝 = 마지막 GO 까지 (뒤따르는 다음 객체 헤더 주석 제외)
        g = list(re.finditer(r'(?im)^GO\s*$', b))
        if g:
            b = b[:g[0].end()]
        blocks[m.group(1).upper()] = b.strip()
    out, miss = [], []
    for n in names:
        if n.upper() in blocks:
            out.append(blocks[n.upper()])
        else:
            miss.append(n)
    io.open(os.path.join(DST, fname), 'w', encoding='utf-8').write(SEP.join(out) + '\n')
    print(fname, 'objects', len(out), 'missing', miss)
