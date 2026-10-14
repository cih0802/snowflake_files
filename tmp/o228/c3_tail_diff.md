# O228 C3 잔여(SILVER·SERVING) 전후 대조

### SERVING.ML_MEMBER_RISK_V.(객체) · 21_ML_SERVING_뷰_DDL.sql
- 전: ML 회원단위 예측(중단·증액·충성) 통합. grain=기준월×회원(키 집계 후 유일). 원천 중복행은 확률 평균·분류 MAX 로 단일화했다(원천 미해소·완화 · O198 이후 피처 컬럼 없음). 예측치이며 실적이 아니다.
- 후: ML 회원단위 예측(중단·증액·충성) 통합. grain=기준월×회원(키 집계 후 유일). 원천 중복행은 확률 평균·분류 MAX 로 단일화했다(원천 미해소·완화 · 이후 피처 컬럼 없음). 예측치이며 실적이 아니다.

### SERVING.MSTR_DVLP_YE_TREND_BSNS_V.(객체) · 05_MSTR_SV_DDL.sql
- 전: 🆕 [O207] MSTR 후원사업2 별 연도말 개발 추세 참고치. 원천 = GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM. 🔴🔴 모델 예측이 아니다 · 목표 없음(목표는 부서 단위만 등록). 🔴 MSTR 기준.
- 후: MSTR 후원사업2 별 연도말 개발 추세 참고치. 원천 = GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM. 🔴🔴 모델 예측이 아니다 · 목표 없음(목표는 부서 단위만 등록). 🔴 MSTR 기준.

### SERVING.ML_CHURN_BY_CMPGN_CTGR_V.(객체) · 25_ML_CHURN_CMPGN_CTGR_DDL.sql
- 전: O224 ML 중단 예측(회원 단위 + 후원건 단위) × 기준월 말 활동 후원 캠페인카테고리. [Grain: 기준월 × 회원 × 캠페인카테고리]. [주의: 회원당 여러 카테고리 행 · 회원수는 중복제거 · 예측치이며 실적이 아니다]. [원천: GN_DW.ML → SERVING.ML_MEMBER_RISK_V · SERVING.ML_SPONSOR_RISK_V · CRM → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN].
- 후: ML 중단 예측(회원 단위 + 후원건 단위) × 기준월 말 활동 후원 캠페인카테고리. [Grain: 기준월 × 회원 × 캠페인카테고리]. [주의: 회원당 여러 카테고리 행 · 회원수는 중복제거 · 예측치이며 실적이 아니다]. [원천: GN_DW.ML → SERVING.ML_MEMBER_RISK_V · SERVING.ML_SPONSOR_RISK_V · CRM → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN].

### SERVING.MSTR_SPNSR_DVLP_V.(객체) · 05_MSTR_SV_DDL.sql
- 전: MSTR 정기회원 후원개발 리포트 서빙뷰(O200-B). 원천 = GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM + MSTR 차원(D_*) — MSTR(구 SQL Server mart) 로직을 Snowflake 로 이관한 결과다(원천 BRONZE_CRM). grain = 팩트 1행. 🔴 MSTR 기준 정의이며 GN_DW GOLD 정의와 다를 수 있다.
- 후: MSTR 정기회원 후원개발 리포트 서빙뷰. 원천 = GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM + MSTR 차원(D_*) — MSTR(구 SQL Server mart) 로직을 Snowflake 로 이관한 결과다(원천 BRONZE_CRM). grain = 팩트 1행. 🔴 MSTR 기준 정의이며 GN_DW GOLD 정의와 다를 수 있다.

### SERVING.ML_INC_BY_MKTG_CMPGN_V.(객체) · 23_ML_INC_MKTG_CMPGN_DDL.sql
- 전: O217-B ML 증액 예측(회원) × MSTR 마케팅캠페인 귀속. grain = 기준월 × 회원. 수치 원천 = SERVING.ML_MEMBER_RISK_V(증액 예측 보유 회원) · 귀속 원천 = SERVING.MSTR_SPNSR_DVLP_V.
- 후: ML 증액 예측(회원) × MSTR 마케팅캠페인 귀속. grain = 기준월 × 회원. 수치 원천 = SERVING.ML_MEMBER_RISK_V(증액 예측 보유 회원) · 귀속 원천 = SERVING.MSTR_SPNSR_DVLP_V.

### SERVING.BIZ_DEFINITION_CORPUS.(객체) · 26_BIZ_DEFINITION_CORPUS_DDL_적재.sql
- 전: O217 비즈니스 정의 코퍼스 — 현업 지표사전·용어·조직·원천 정의 + 라우팅 결정. Cortex Search(SEARCH_BIZ_DEFINITION) 원천. 수치 원천이 아니다.
- 후: 비즈니스 정의 코퍼스 — 현업 지표사전·용어·조직·원천 정의 + 라우팅 결정. Cortex Search(SEARCH_BIZ_DEFINITION) 원천. 수치 원천이 아니다.

### SERVING.ML_ONCE_CONVERSION_V.(객체) · 21_ML_SERVING_뷰_DDL.sql
- 전: ML 일시후원회원의 정기후원 전환 예측. grain=기준월×일시후원회원이나 원천이 회원당 다중 예측행을 담는다(실행순번 없음 · DEC-59 #1 유지). 회원수는 중복제거로 센다. 예측치이며 실적이 아니다.
- 후: ML 일시후원회원의 정기후원 전환 예측. grain=기준월×일시후원회원이나 원천이 회원당 다중 예측행을 담는다(실행순번 없음 · #1 유지). 회원수는 중복제거로 센다. 예측치이며 실적이 아니다.

### SERVING.MSTR_DVLP_YE_TREND_V.(객체) · 05_MSTR_SV_DDL.sql
- 전: 🆕 [O207] MSTR 연도말 개발 추세 참고치. 원천 = SERVING.MSTR_DVLP_GOAL_V. 🔴🔴 MSTR 에 예측 로직은 없다 — 이 값은 직전 3개월 평균을 남은 달에 이어 붙인 「추세 참고치」이며 모델 예측이 아니다. 🔴 MSTR 기준.
- 후: MSTR 연도말 개발 추세 참고치. 원천 = SERVING.MSTR_DVLP_GOAL_V. 🔴🔴 MSTR 에 예측 로직은 없다 — 이 값은 직전 3개월 평균을 남은 달에 이어 붙인 「추세 참고치」이며 모델 예측이 아니다. 🔴 MSTR 기준.

### SERVING.MSTR_DVLP_GOAL_V.(객체) · 05_MSTR_SV_DDL.sql
- 전: 🆕 [O207] MSTR 개발 목표·실적 월 grain 뷰. 원천 = GN_DW.MSTR.D_MBER_DVLP_GOAL_CD(목표) + F_MM_SPNSR_DVLP_SUM(실적). 🔴 MSTR 기준이다(GN_DW GOLD FACT_TARGET_MEMBER_DEV 와 같은 원천 목표).
- 후: MSTR 개발 목표·실적 월 grain 뷰. 원천 = GN_DW.MSTR.D_MBER_DVLP_GOAL_CD(목표) + F_MM_SPNSR_DVLP_SUM(실적). 🔴 MSTR 기준이다(GN_DW GOLD FACT_TARGET_MEMBER_DEV 와 같은 원천 목표).

### SILVER.CRM_BIZ_TARGET.GOAL_TYPE_NM · 08_SILVER_테이블DDL_20260714.sql
- 전: 목표 지표 유형 원천 표기 그대로(O190 · 9종): 건 = 후원사업·회원개발 / 명 = 월말활동회원 / 원 = 정기회비 / 비율 = 후원사업활동율·신규기존활동율·후원사업납입율·신규기존납입율·신규기존누계납입율. 🔴 유형마다 단위가 달라 섞어 합산하지 말 것 · 후원사업과 회원개발은 같은 개발 목표의 다른 분해(문서20 N-24)
- 후: 목표 지표 유형 원천 표기 그대로(9종): 건 = 후원사업·회원개발 / 명 = 월말활동회원 / 원 = 정기회비 / 비율 = 후원사업활동율·신규기존활동율·후원사업납입율·신규기존납입율·신규기존누계납입율. 🔴 유형마다 단위가 달라 섞어 합산하지 말 것 · 후원사업과 회원개발은 같은 개발 목표의 다른 분해

### SILVER.AGENCY_AD_ROW_REBRDC.TOT_COST · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 총비용 = 편성비+콘텐츠구입비+콜센터운영비 (O182 신규 · 실측 전건 일치)
- 후: [원천보존] 총비용 = 편성비+콘텐츠구입비+콜센터운영비 (실측 전건 일치)

### SERVING.MSTR_SPNSR_DVLP_V.SPNSR_AMT_CNT · 05_MSTR_SV_DDL.sql
- 전: MSTR 개발(건) = 후원금액 ÷ 10,000(MSTR 정의 · GN_DW 개발건수와 다름) · 🆕 [O206-D] 원천 FLOAT 를 NUMBER(18,4) 로 고정(부동소수 꼬리 제거 · 합계 불변)
- 후: MSTR 개발(건) = 후원금액 ÷ 10,000(MSTR 정의 · GN_DW 개발건수와 다름) · 원천 FLOAT 를 NUMBER(18,4) 로 고정(부동소수 꼬리 제거 · 합계 불변)

### SERVING.ML_MEMBER_RISK_V.CHURN_GRADE · 21_ML_SERVING_뷰_DDL.sql
- 전: 중단위험 등급(F-4 · O190) — 기준월 내 백분위: 상위 10% 고위험 · 10~25% 주의 · 나머지 일반 · 예측 없음 NULL. 🔴 확률 임계가 아니라 순위다
- 후: 중단위험 등급(F-4) — 기준월 내 백분위: 상위 10% 고위험 · 10~25% 주의 · 나머지 일반 · 예측 없음 NULL. 🔴 확률 임계가 아니라 순위다

### SILVER.AGENCY_AD_DIGITAL.CPC_CLICK_SRC · 08_SILVER_테이블DDL_20260714.sql
- 전: [비가산] 대행사 산정 **클릭당** 단가 (O174 개명)
- 후: [비가산] 대행사 산정 **클릭당** 단가

### SILVER.AGENCY_AD_ROW_VIDEO.EXPSR_CNT · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 노출수 (O182 신규)
- 후: [원천보존] 노출수

### SILVER.AGENCY_AD_ROW_VIDEO.MONTH · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 월 텍스트 (O182 신규 · 「03월」 형태 혼재)
- 후: [원천보존] 월 텍스트 (「03월」 형태 혼재)

### SILVER.AGENCY_AD_ROW_DGT.TOTAL_CPA · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 통합CPA (O182 신규 · 비가산)
- 후: [원천보존] 통합CPA (비가산)

### SILVER.AGENCY_AD_ROW_VIDEO.DEVICE_NM · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 기기 (O182 신규)
- 후: [원천보존] 기기

### SILVER.AGENCY_AD_ROW_REBRDC.CALL_CTR_OPER_COST · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 콜센터운영비 (O182 신규)
- 후: [원천보존] 콜센터운영비

### SILVER.AGENCY_AD_ROW_DGT.TOTAL_DVLP_UNIT_PRICE · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 통합개발단가 (O182 신규 · 비가산)
- 후: [원천보존] 통합개발단가 (비가산)

### SILVER.AGENCY_AD_ROW_VIDEO.CLICK_CNT · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 클릭수 (O182 신규)
- 후: [원천보존] 클릭수

### SILVER.CRM_CAMPAIGN.SPNSR_BSNS_ID · 08_SILVER_테이블DDL_20260714.sql
- 전: 후원사업ID (Q16 조인키)
- 후: 후원사업ID (조인키)

### SILVER.CRM_SPONSOR_RELATION.SPNSR_BSNS_ID · 08_SILVER_테이블DDL_20260714.sql
- 전: 후원사업ID (Q15 크로스워크 파생)
- 후: 후원사업ID (크로스워크 파생)

### SILVER.AGENCY_AD_ROW_VIDEO.DAY · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 일자 텍스트 (O182 신규)
- 후: [원천보존] 일자 텍스트

### SILVER.CRM_DEV_TARGET.TARGET_TYPE · 08_SILVER_테이블DDL_20260714.sql
- 전: 목표 유형 (ORIGINAL/당초 등) [O145-8]
- 후: 목표 유형 (ORIGINAL/당초 등) [-8]

### SILVER.BIGQUERY_DEVICE.DEVICE_TYPE · 08_SILVER_테이블DDL_20260714.sql
- 전: 디바이스 유형 파생. 값 = PC / M (APP 휴면·O2).
- 후: 디바이스 유형 파생. 값 = PC / M (APP 휴면).

### SILVER.AGENCY_AD_ROW_VIDEO.SPNSER_CNT · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 후원자수 (O182 신규 · 위성 DVLP_MEMBER_CNT 원천)
- 후: [원천보존] 후원자수 (위성 DVLP_MEMBER_CNT 원천)

### SILVER.AGENCY_AD_ROW_VIDEO.CMPGN_NM · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 캠페인명 (O182 신규 · 구 MKT_CMPGN_NM 자리 · CTV 시트만 채움)
- 후: [원천보존] 캠페인명 (구 MKT_CMPGN_NM 자리 · CTV 시트만 채움)

### SILVER.AGENCY_AD_ROW_REBRDC.CONTENTS_PUR_COST · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 콘텐츠구입비 (O182 신규)
- 후: [원천보존] 콘텐츠구입비

### SILVER.AGENCY_AD_BROADCAST.CPC_CALL_SRC · 08_SILVER_테이블DDL_20260714.sql
- 전: [비가산] 대행사 산정 **콜당** 단가 [VIDEO 전용] — 🔴 클릭 분모가 아니다(O174 개명)
- 후: [비가산] 대행사 산정 **콜당** 단가 [VIDEO 전용] — 🔴 클릭 분모가 아니다

### SILVER.CRM_BIZ_TARGET.CAMPAIGN_NM · 08_SILVER_테이블DDL_20260714.sql
- 전: 캠페인 (연결키 부재 Q10)
- 후: 캠페인 (연결키 부재)

### SERVING.ML_MEMBER_RISK_V.LOYAL_GRADE · 21_ML_SERVING_뷰_DDL.sql
- 전: 장기회원 등급(F-4 · O190) — 기준월 내 백분위: 상위 5% 최상위 · 5~10% 상 · 10~25% 중 · 나머지 하 · 충성 예측 모집단만(그 외 NULL)
- 후: 장기회원 등급(F-4) — 기준월 내 백분위: 상위 5% 최상위 · 5~10% 상 · 10~25% 중 · 나머지 하 · 충성 예측 모집단만(그 외 NULL)

### SERVING.ML_SPONSOR_RISK_V.CHURN_GRADE · 21_ML_SERVING_뷰_DDL.sql
- 전: 후원건 이탈위험 등급(F-4 · O190) — 기준월 내 후원건 백분위: 상위 5% 고위험 · 5~25% 주의 · 나머지 일반. 🔴 확률 임계가 아니라 순위다
- 후: 후원건 이탈위험 등급(F-4) — 기준월 내 후원건 백분위: 상위 5% 고위험 · 5~25% 주의 · 나머지 일반. 🔴 확률 임계가 아니라 순위다

### SILVER.ERP_BUDGET.BUDGET_PROCEDURE · 08_SILVER_테이블DDL_20260714.sql
- 전: 예산 편성 차수 (연사업 / 추가경정 · DEC-44)
- 후: 예산 편성 차수 (연사업 / 추가경정)

### SILVER.AGENCY_AD_ROW_REBRDC.MONTH · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 월 텍스트 (O182 신규)
- 후: [원천보존] 월 텍스트

### SERVING.MSTR_SPNSR_DVLP_V.CMPGN_TYPE1_NM · 05_MSTR_SV_DDL.sql
- 전: 🆕 [O212-B] 캠페인유형(원천 COMMENT = 캠페인유형(국내/해외) · MM295 · 국내·해외·통합 등)
- 후: 캠페인유형(원천 COMMENT = 캠페인유형(국내/해외) · MM295 · 국내·해외·통합 등)

### SILVER.AGENCY_AD_ROW_REBRDC.DAY · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 일 텍스트 (O182 신규)
- 후: [원천보존] 일 텍스트

### SILVER.AGENCY_AD_ROW_DGT.VAT_AMT · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 부가세 (O182 신규 · 코어 광고비 미포함)
- 후: [원천보존] 부가세 (코어 광고비 미포함)

### SILVER.AGENCY_AD_ROW_VIDEO.MATR_TY_NM · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 소재유형 (O182 신규)
- 후: [원천보존] 소재유형

### SILVER.AGENCY_AD_ROW_VIDEO.DVLP_CNT · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 개발건수 (O182 신규 · 위성 DVLP_CNT 원천)
- 후: [원천보존] 개발건수 (위성 DVLP_CNT 원천)

### SILVER.AGENCY_AD_ROW_DGT.LAST_STMT_AMT · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 최종정산금액 (O182 신규 · 광고비+마크업+부가세)
- 후: [원천보존] 최종정산금액 (광고비+마크업+부가세)

### SILVER.CRM_EVENT_PARTICIPATION.PARTCPT_STAT_CD · 08_SILVER_테이블DDL_20260714.sql
- 전: 참여상태코드 (raw · 원천별 2체계 O28.
- 후: 참여상태코드 (raw · 원천별 2체계.

### SILVER.AGENCY_AD_ROW_REBRDC.UPPER_CMPGN_CD · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 상위캠페인코드 (O182 신규 · 실측 전건 NULL)
- 후: [원천보존] 상위캠페인코드 (실측 전건 NULL)

### SILVER.AGENCY_AD_ROW_VIDEO.AD_TY_NM · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 광고유형 TV/CTV/기타/미확인 (O182 신규 · 구 CTV_DIV_NM 자리)
- 후: [원천보존] 광고유형 TV/CTV/기타/미확인 (구 CTV_DIV_NM 자리)

### SILVER.AGENCY_AD_ROW_VIDEO.BDGT_SOURCE_NM · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 예산출처 (O182 신규)
- 후: [원천보존] 예산출처

### SILVER.AGENCY_AD_ROW_REBRDC.CMPGN_CD · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 캠페인코드 (O182 신규 · 실측 전건 NULL)
- 후: [원천보존] 캠페인코드 (실측 전건 NULL)

### SILVER.AGENCY_AD_ROW_DGT.MARKUP_AMT · 08_SILVER_테이블DDL_20260714.sql
- 전: [원천보존] 마크업 (O182 신규 · 코어 광고비 미포함)
- 후: [원천보존] 마크업 (코어 광고비 미포함)

_Co-authored with CoCo_
