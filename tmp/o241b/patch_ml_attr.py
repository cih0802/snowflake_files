# O241-M — ML SV 3종에 기준월 시점 회원 특성 축(ma = SERVING.ML_MEMBER_ATTR_ASOF_V) 배선 + O241-R 반올림(25 파일) · 멱등
# Co-authored with CoCo
import re
TBL = ("    ma AS GN_DW.SERVING.ML_MEMBER_ATTR_ASOF_V\n      PRIMARY KEY (STDR_MT, MBER_NO)\n"
       "      WITH SYNONYMS ('회원 특성', '예측 회원 특성', '기준월 시점 회원 속성')\n"
       "      COMMENT = '예측 대상 회원의 기준월 말 시점 특성(성별·연령대·지역·회원상태·회원구분·후원금액대·유지기간대·신규기존·납입방식). grain = 기준월 × 회원. 🔴 모델 피처가 아니다 — 예측 결과를 특성으로 나눠 보는 집계용이다. 미매칭 = (미매칭).'")
DIMS = [('GENDER_NAME', "'성별', '남녀'", '성별(기준월 말 시점). 🔴 모델 피처가 아니다.'),
        ('AGE_BAND', "'연령대', '나이대'", '연령대(기준월 말 시점). 값에 기업·단체·기타가 섞여 있다 — 개인 연령 분석은 회원구분 개인으로 거른다.'),
        ('REGION', "'지역', '거주지역', '시도'", '지역(기준월 말 시점).'),
        ('MEMBER_STATUS_NAME', "'회원상태'", '회원상태(기준월 말 시점).'),
        ('MEMBER_TYPE_NAME', "'회원구분', '법인구분', '개인 기업 단체'", '회원구분 = 개인·기업·단체(법인구분 · 기준월 말 시점).'),
        ('AMOUNT_BAND', "'후원금액대', '금액대'", '후원금액대(그 달 회원 월실적 금액대1).'),
        ('TENURE_BAND', "'유지기간', '가입기간', '후원기간대'", '유지기간대(그 달 회원 월실적 기간대1).'),
        ('NEW_EXISTING', "'신규기존', '신규 기존 구분'", '신규/기존(그 달 회원 월실적).'),
        ('PAYMENT_METHOD_NAME', "'납입방식', '결제수단'", '납입방식(그 달 청구액이 가장 큰 결제수단 · 잠정).'),
        ('ATTR_MATCHED', "'특성 매칭 여부'", 'TRUE=기준월 시점 회원 이력이 매칭됐다. FALSE 회원은 특성이 (미매칭)이다.')]
AI = ('[O241-M 회원 특성 축] 성별·연령대·지역·회원상태·회원구분(법인구분)·후원금액대·유지기간·신규기존·납입방식으로 나눠 달라는 질문은 ma 테이블 차원으로 GROUP BY 한다(기준월 말 시점 · 모델 피처 아님). '
      '회원수는 반드시 예측 테이블 회원번호의 COUNT(DISTINCT) 로 센다. (미매칭) 행은 따로 밝힌다. ')
R = ('[O241-R 반올림 · 전 SV 공통] 최종 SELECT 에서 비율(%)·평균·확률·초·기여도 등 소수 값은 ROUND(<식>, 2) 로 반올림해 출력한다(집계 식 바깥에 씌우며 정렬·필터에는 원래 식을 쓴다). '
     '금액·건수·명수는 숫자형 그대로 둔다(문자열로 바꾸지 않는다 — 쉼표는 답변 작성 단계에서 붙인다). ')
K = '[O206 출력 규칙 · 전 SV 공통] '
TARGET = {'22_ML_SV_DDL.sql': [('SV_ML_MEMBER_RISK', 'mr'), ('SV_ML_SPONSOR_RISK', 'sr')],
          '25_ML_CHURN_CMPGN_CTGR_DDL.sql': [('SV_ML_CHURN_CAMPAIGN', 'cc')]}
OLD_INACT = '비활성: 회원상태·결제수단·법인구분·가입기간 등 회원 속성 축(원천 피처 제거로 미배선) · '
for f, svs in TARGET.items():
    s = open(f, encoding='utf-8').read()
    if 'O241-R' not in s:
        s = s.replace(K, R + K)
    for sv, a in svs:
        st = s.index('CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.' + sv + '\n')
        en = s.index('\nGRANT ', st)
        b = s[st:en]
        if 'ML_MEMBER_ATTR_ASOF_V' in b:
            print(sv, 'skip'); continue
        i = b.index('\n  )\n  DIMENSIONS (')
        b = b[:i] + ',\n' + TBL + '\n  )\n  RELATIONSHIPS (\n    ' + a + '_to_member_attr AS ' + a + '(STDR_MT, MBER_NO) REFERENCES ma\n  )\n  DIMENSIONS (' + b[i + len('\n  )\n  DIMENSIONS ('):]
        j = b.index('\n  )\n  METRICS (')
        d = ',\n'.join(f"    ma.{c} AS ma.{c}\n      WITH SYNONYMS ({syn})\n      COMMENT = '{cm}'" for c, syn, cm in DIMS)
        b = b[:j] + ',\n' + d + b[j:]
        k = b.index("  AI_SQL_GENERATION '") + len("  AI_SQL_GENERATION '")
        b = b[:k] + AI + b[k:]
        b = b.replace(OLD_INACT, '활성(O241-M): 기준월 시점 회원 특성 축(ma · 성별·연령대·지역·회원상태·회원구분·금액대·유지기간·납입방식 · 모델 피처 아님) · 비활성: ')
        s = s[:st] + b + s[en:]
        print(sv, 'OK')
    m = max(len(l) for l in s.splitlines()); assert m <= 2000, (f, m)
    open(f, 'w', encoding='utf-8').write(s)
