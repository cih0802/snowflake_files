# O242-B — VQR 31건 한글 별칭·반올림(바깥 감싸기 · 원 SQL 무변경) · Co-authored with CoCo
# 사용: python3 apply_vqr.py [--apply]   (기본 = dry-run · 대상 행 대조만)
# 매핑 근거 = tmp/o242b/vqr_raw.txt(원문) · 한글명 = 그 SV 필드 동의어·COMMENT 업무명 + 단위 · R = ROUND(,2)::NUMBER(38,2)
import io, sys, hashlib, shutil, os
D = '05_SV-Agent_ai/'
# (파일, 원문 줄번호, [(출력열, 한글명, 반올림)], 바깥 ORDER BY)
M = [
 ('05_02_SV_DDL_MEMBER_EVENT.sql', 190, [('DVLP_DIV_NM','개발구분',0),('EVENT_ROWS','개발(건)',0),('DISTINCT_MEMBERS','고유 회원수(명)',0)], 'EVENT_ROWS DESC NULLS LAST'),
 ('05_02_SV_DDL_MEMBER_EVENT.sql', 195, [('ORG_DEPARTMENT','부서',0),('SPONSORSHIP_CPR_DIV_NM','법인구분',0),('DEV_MEMBER_COUNT','개발 회원수(명)',0),('TOTAL_DEV_CNT','개발(건)',0)], 'ORG_DEPARTMENT'),
 ('05_02_SV_DDL_MEMBER_EVENT.sql', 200, [('CAMPAIGN_TYPE','캠페인카테고리',0),('MONTH','월',0),('CAMPAIGN_STOP_MEMBER_COUNT','중단 회원수(명)',0),('TOTAL_CAMPAIGN_STOP_CNT','중단(건)',0)], 'CAMPAIGN_TYPE, MONTH'),
 ('05_02_SV_DDL_MEMBER_EVENT.sql', 205, [('ORG_DIV_GROUP','본부',0),('ORG_DIV_GROUP_CODE','본부코드',0),('ORG_DIV','지부',0),('ORG_DIV_CODE','지부코드',0),('DEV_MEMBER_COUNT','개발 회원수(명)',0)], 'DEV_MEMBER_COUNT DESC NULLS LAST'),
 ('05_03_SV_DDL_MEMBER_COHORT.sql', 114, [('CAMPAIGN_NAME','캠페인',0),('TOTAL_ACQ_MEMBERS','가입 회원수(명)',0),('AVG_TENURE_DAYS','평균 유지기간(일)',1),('CHURN_RATE_12M','12개월 중단률(%)',1)], 'TOTAL_ACQ_MEMBERS DESC NULLS LAST'),
 ('05_04_SV_DDL_SERVICE.sql', 203, [('YEAR','연도',0),('MONTH','월',0),('TOTAL_SEND_MEMBERS','발송 대상 회원수(명)',0)], 'YEAR, MONTH'),
 ('05_04_SV_DDL_SERVICE.sql', 208, [('YEAR','연도',0),('MONTH','월',0),('D5_INCREASE_MEMBERS','발송 후 5일 내 증액 회원수(명)',0),('D5_STOP_MEMBERS_SUM','발송 후 5일 내 중단 회원수(명)',0)], 'YEAR, MONTH'),
 ('05_04_SV_DDL_SERVICE.sql', 213, [('D5_STOP_DISTINCT_MEMBERS','발송 후 5일 내 중단 회원수(명)',0),('DISTINCT_SEND_MEMBERS','발송 회원수(명)',0)], None),
 ('05_05_SV_DDL_EVENT_PARTICIPATION.sql', 104, [('PART_EVENT_KIND_NAME','행사종류',0),('PART_STATUS_NAME','참여상태',0),('TOTAL_PARTICIPANTS','참여자수(명)',0),('DISTINCT_PARTICIPANTS','고유 참여 회원수(명)',0)], 'PART_EVENT_KIND_NAME, TOTAL_PARTICIPANTS DESC NULLS LAST'),
 ('05_06_SV_DDL_BUDGET.sql', 67, [('CAL_YEAR','연도',0),('CAL_MONTH','월',0),('TOTAL_PLAN_BUDGET','편성예산(원)',0),('TOTAL_EXEC_BUDGET','집행예산(원)',0)], 'CAL_YEAR, CAL_MONTH'),
 ('05_06_SV_DDL_BUDGET.sql', 72, [('BUDGET_CATEGORY','예산구분',0),('BUDGET_ITEM_NAME','세세목',0),('TOTAL_PLAN_BUDGET','편성예산(원)',0),('TOTAL_EXEC_BUDGET','집행예산(원)',0)], 'TOTAL_PLAN_BUDGET DESC NULLS LAST'),
 ('05_07_SV_DDL_AD.sql', 197, [('AD_CTGR_NM','캠페인카테고리',0),('TOTAL_AD_COST','광고비(원)',0),('MULTI_REP_AD_COST','복수 카테고리 대표값 광고비(원)',0)], 'TOTAL_AD_COST DESC NULLS LAST'),
 ('05_07_SV_DDL_AD.sql', 202, [('AD_SOURCE_TYPE','출처유형',0),('TOTAL_AD_COST','광고비(원)',0)], 'TOTAL_AD_COST DESC NULLS LAST'),
 ('05_07_SV_DDL_AD.sql', 207, [('YEAR','연도',0),('WEEK_OF_YEAR','주차',0),('TOTAL_IMPRESSIONS','노출수(회)',0),('TOTAL_CLICKS','클릭수(회)',0),('CTR','클릭률(%)',1)], 'YEAR, WEEK_OF_YEAR'),
 ('05_07_SV_DDL_AD.sql', 212, [('YR','연도',0),('MN','월',0),('IMP','노출수(회)',0),('IMP_PREV_YEAR','전년 동월 노출수(회)',0),('CLK','클릭수(회)',0),('CLK_PREV_YEAR','전년 동월 클릭수(회)',0),('COST','광고비(원)',0),('COST_PREV_YEAR','전년 동월 광고비(원)',0),('CLK_YOY_PCT','클릭수 전년 대비 증감률(%)',1),('COST_YOY_PCT','광고비 전년 대비 증감률(%)',1)], 'YR, MN'),
 ('05_08_SV_DDL_DEV_ACHIEVEMENT.sql', 66, [('ORG_DEPARTMENT','부서',0),('TOTAL_GOAL_CNT','목표(건)',0),('TOTAL_ACTUAL_CNT','실적(건)',0),('ACHIEVEMENT_RATE','달성율(%)',1)], 'ACHIEVEMENT_RATE DESC NULLS LAST'),
 ('05_08_SV_DDL_DEV_ACHIEVEMENT.sql', 71, [('CAL_YEAR','연도',0),('CAL_MONTH','월',0),('TOTAL_GOAL_CNT','목표(건)',0),('TOTAL_ACTUAL_CNT','실적(건)',0)], 'CAL_YEAR, CAL_MONTH'),
 ('05_09_SV_DDL_MEMBER_FEE.sql', 90, [('SPONSORSHIP','후원사업',0),('PAYMENT_METHOD','납입방식',0),('TOTAL_BILLED_AMT','청구액(원)',0),('PAYMENT_RATE_FEE','납부율(%)',1)], 'TOTAL_BILLED_AMT DESC NULLS LAST'),
 ('05_09_SV_DDL_MEMBER_FEE.sql', 95, [('CAL_YEAR','연도',0),('ACQ_CPR_DIV','법인구분',0),('TOTAL_BILLED_AMT','청구액(원)',0),('TOTAL_PAID_FEE_BILLABLE','납입액(원)',0),('PAYMENT_RATE_FEE','납부율(%)',1)], 'CAL_YEAR DESC'),
 ('05_10_SV_DDL_MEMBER_SPONSOR_BIZ.sql', 88, [('SPONSORSHIP','후원사업',0),('CURRENTLY_ACTIVE_MEMBERS','현재 활동회원수(명)',0)], 'CURRENTLY_ACTIVE_MEMBERS DESC NULLS LAST'),
 ('05_12_SV_DDL_RELATION_ACTIVITY.sql', 76, [('YEAR','연도',0),('MONTH','월',0),('ACTIVITY_TYPE','활동유형',0),('TOTAL_ACTIVITY_CNT','결연활동(건)',0),('DISTINCT_ACTIVITY_MEMBERS','활동 회원수(명)',0),('TOTAL_GIFT_AMT','선물금(원)',0)], 'YEAR, MONTH, ACTIVITY_TYPE'),
 ('05_15_SV_DDL_GA_BEHAVIOR.sql', 83, [('DEFAULT_CHANNEL_GROUP','채널그룹',0),('TOTAL_EVENT_CNT','이벤트수(건)',0),('IDENTIFIED_VISITORS','식별 방문자수(명)',0)], 'TOTAL_EVENT_CNT DESC'),
 ('05_15_SV_DDL_GA_BEHAVIOR.sql', 88, [('PAGE_PATH','페이지 경로',0),('TOTAL_EVENT_CNT','이벤트수(건)',0),('IDENTIFIED_VISITORS','식별 방문자수(명)',0)], 'TOTAL_EVENT_CNT DESC'),
 ('05_16_SV_DDL_BUDGET_YEARLY.sql', 51, [('BUDGET_YEAR','연도',0),('BUDGET_PROCEDURE','예산차수',0),('TOTAL_PLAN_BUDGET_YEAR','편성예산(원)',0),('TOTAL_EXEC_BUDGET_YEAR','집행예산(원)',0),('EXEC_RATE_YEAR','집행율(%)',1)], 'BUDGET_YEAR'),
 ('05_17_SV_DDL_MEMBER_STATUS_ASOF.sql', 47, [('MEMBER_STATUS_NAME','회원상태',0),('MEMBER_COUNT','회원수(명)',0)], 'MEMBER_COUNT DESC'),
 ('05_18_SV_DDL_MEMBER_SERVICE_COHORT.sql', 138, [('RECEIVED_FLAG','수신여부',0),('MEMBER_COUNT','회원수(명)',0),('GENERAL_EVENT_PART_RATE','일반행사 참여율(%)',1),('CAMPAIGN_EVENT_PART_RATE','캠페인행사 참여율(%)',1)], 'RECEIVED_FLAG'),
 ('05_24_SV_DDL_CAMPAIGN_CUM_STOP.sql', 64, [('CAMPAIGN_NAME','캠페인',0),('CUM_STOP','누계 중단(건)',0),('CUM_DEV','누계 개발(건)',0),('YEAR_START_ACTIVE','연도초 활동(건)',0),('CUM_STOP_RATE','누계중단율(%)',1)], 'CUM_STOP DESC NULLS FIRST'),
 ('05_25_SV_DDL_CAMPAIGN_MONTHLY.sql', 94, [('CAMPAIGN_NAME','캠페인',0),('ACTIVE_CNT_SUM','활동(건)',0),('CUM_DEV_CNT_SUM','누계 개발(건)',0),('YEAR_START_ACTIVE_CNT_SUM','연도초 활동(건)',0),('CAMPAIGN_ACTIVE_RATE','활동율(%)',1)], 'ACTIVE_CNT_SUM DESC NULLS FIRST'),
 ('22_ML_SV_DDL.sql', 301, [('TS','예측월',0),('FORECAST_AMT','개발금액 예측(원)',0)], 'TS'),
 ('22_ML_SV_DDL.sql', 417, [('SERIES_NAME','마케팅채널',0),('AVG_FORECAST_LTV','회원평균 후원금액 예측(원)',1)], 'AVG_FORECAST_LTV DESC NULLS LAST'),
 ('22_ML_SV_DDL.sql', 535, [('MEMBER_DIV_NAME','회원구분',0),('MODEL_CONVERT_MEMBERS','모델 전환분류 회원수(명)',0),('PREDICTED_ONCE_MEMBERS','예측 대상 일시회원수(명)',0),('AVG_CONVERT_PROB','평균 전환확률',1)], 'PREDICTED_ONCE_MEMBERS DESC'),
]
apply = '--apply' in sys.argv
os.makedirs('tmp/o242b/bak', exist_ok=True)
byf = {}
for f, ln, cols, od in M:
    byf.setdefault(f, []).append((ln, cols, od))
bad = 0
for f, items in byf.items():
    p = D + f
    raw = io.open(p, encoding='utf-8').read(); L = raw.split('\n')
    for ln, cols, od in items:
        line = L[ln - 1]; ind = line[:len(line) - len(line.lstrip())]; s = line.strip()
        if not (s.startswith("SQL '") and s.endswith("'") and 'AS "' not in s):
            print('🔴 앵커 불일치', f, ln); bad += 1; continue
        inner = s[5:-1]
        miss = [c for c, _, _ in cols if c not in inner]
        if miss:
            print('🔴 열 부재', f, ln, miss); bad += 1; continue
        sel = ', '.join((f'ROUND({c}, 2)::NUMBER(38,2)' if r else c) + f' AS "{k}"' for c, k, r in cols)
        L[ln - 1] = ind + f"SQL 'SELECT {sel} FROM ({inner})" + (f' ORDER BY {od}' if od else '') + "'"
    if apply and not bad:
        shutil.copy(p, 'tmp/o242b/bak/' + f)
        io.open(p, 'w', encoding='utf-8', newline='').write('\n'.join(L))
        print('WRITE', f, hashlib.sha256(raw.encode()).hexdigest()[:12], '->', hashlib.sha256('\n'.join(L).encode()).hexdigest()[:12])
print('대상', len(M), '파일', len(byf), '결함', bad, 'APPLY' if apply else 'DRY')
