# O206-D — 23_MSTR_SV_DDL.sql: ① 개발(건) 소수 4자리 고정 ② 신규기존구분 배선 (단일 파일 1회 쓰기 · 앵커 1회 일치)
# Co-authored with CoCo
import hashlib, io, sys
P = '05_SV-Agent_ai/23_MSTR_SV_DDL.sql'
h = lambda: hashlib.sha256(open(P, 'rb').read()).hexdigest()
assert h() == h()
t = io.open(P, encoding='utf-8').read()
R = [
    # 뷰 컬럼 목록
    ("  AGE_TERM_NM COMMENT '연령대명',\n",
     "  AGE_TERM_NM COMMENT '연령대명',\n"
     "  NEW_OLD_DIV_CD COMMENT '신규기존구분코드(MSTR · DMMM07 1=신규 2=기존 99=없음)',\n"
     "  NEW_OLD_DIV_NM COMMENT '신규기존구분명(MSTR 원천 판정값 · 가입일 계산이 아니다)',\n"),
    ("  SPNSR_AMT_CNT COMMENT 'MSTR 개발(건) = 후원금액 ÷ 10,000(MSTR 정의 · GN_DW 개발건수와 다름)',",
     "  SPNSR_AMT_CNT COMMENT 'MSTR 개발(건) = 후원금액 ÷ 10,000(MSTR 정의 · GN_DW 개발건수와 다름) · 🆕 [O206-D] 원천 FLOAT 를 NUMBER(18,4) 로 고정(부동소수 꼬리 제거 · 합계 불변)',"),
    # SELECT
    ("  a11.AGE_TERM_CD, a111.AGE_TERM_NM,\n  a11.MBER_NO, a11.SPNSR_AMT_CNT, a11.SPNSR_AMT, a11.DVLP_CNT\n",
     "  a11.AGE_TERM_CD, a111.AGE_TERM_NM,\n  a11.NEW_OLD_DIV_CD, a117.DTL_CD_NM,\n"
     "  a11.MBER_NO, ROUND(a11.SPNSR_AMT_CNT, 4)::NUMBER(18,4), a11.SPNSR_AMT, a11.DVLP_CNT\n"),
    # JOIN
    ("LEFT JOIN GN_DW.MSTR.D_SPNSR_BSNS_INFO a116 ON a11.SPNSR_BSNS2_ID  = a116.SPNSR_BSNS_ID;",
     "LEFT JOIN GN_DW.MSTR.D_SPNSR_BSNS_INFO a116 ON a11.SPNSR_BSNS2_ID  = a116.SPNSR_BSNS_ID\n"
     "LEFT JOIN GN_DW.MSTR.D_CMMN_DTL_CD     a117 ON a117.CD_ID = 'DMMM07' AND a11.NEW_OLD_DIV_CD = a117.DTL_CD_ID;"),
    # SV 차원
    ("      COMMENT = '연령대명(MSTR 구간).',\n",
     "      COMMENT = '연령대명(MSTR 구간).',\n"
     "    md.NEW_OLD_DIV_NM AS md.NEW_OLD_DIV_NM\n"
     "      WITH SYNONYMS ('신규기존구분', '신규/기존', '신규 기존')\n"
     "      COMMENT = '🆕 [O206-D] MSTR 신규기존구분명. 실제값: ''신규''·''기존''(코드 99 = ''없음''). 🔴 MSTR 원천이 개발 건마다 판정해 둔 값이다 — 가입일로 다시 계산하지 않는다(MSTR 에는 가입일 컬럼이 없다).',\n"),
    # 지표 반올림
    ("    md.MSTR_DVLP_CNT AS SUM(md.SPNSR_AMT_CNT)\n",
     "    md.MSTR_DVLP_CNT AS ROUND(SUM(md.SPNSR_AMT_CNT), 4)\n"),
    ("COMMENT = 'MSTR 개발(건) = 후원금액 ÷ 10,000 의 합(소수 가능). 🔴 GN_DW 개발건수(사건 건수)와 정의가 다르다.',",
     "COMMENT = 'MSTR 개발(건) = 후원금액 ÷ 10,000 의 합(소수 4자리). 🔴 GN_DW 개발건수(사건 건수)와 정의가 다르다.',"),
    # SV COMMENT 활성 축
    ("후원사업/후원사업2/성별/연령대 축.", "후원사업/후원사업2/성별/연령대/신규기존구분 축."),
    # 규칙 (9)·(10)
    ("(8) 🔴 metric 이름을 md 컬럼처럼 참조하지 않는다 — 정의식(SUM(md.SPNSR_AMT_CNT) 등)으로 집계한다.';",
     "(8) 🔴 metric 이름을 md 컬럼처럼 참조하지 않는다 — 정의식(ROUND(SUM(md.SPNSR_AMT_CNT), 4) 등)으로 집계한다. "
     "(9) 🆕 [O206-D] 개발(건)은 소수 4자리로 반올림해 낸다 — ROUND(SUM(md.SPNSR_AMT_CNT), 4). "
     "(10) 🆕 [O206-D] 「신규/기존」 구분은 md.NEW_OLD_DIV_NM 으로 그룹·필터한다 — 가입일이 없다고 산출 불가로 답하지 않는다.';"),
]
for a, b in R:
    n = t.count(a)
    if n != 1:
        sys.exit(f'🔴 앵커 {n}: {a[:50]!r}')
    t = t.replace(a, b)
if '--apply' in sys.argv:
    io.open(P, 'w', encoding='utf-8', newline='').write(t)
    print('WROTE', h()[:12])
else:
    print('DRY OK', len(R))
