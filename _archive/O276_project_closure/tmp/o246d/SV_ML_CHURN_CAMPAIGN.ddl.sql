create or replace semantic view GN_DW.SERVING.SV_ML_CHURN_CAMPAIGN
	tables (
		CC as GN_DW.SERVING.ML_CHURN_BY_CMPGN_CTGR_V with synonyms=('중단 예측 캠페인','캠페인카테고리별 중단 위험 회원','중단 위험 회원 캠페인 매칭') comment='ML 중단 예측을 기준월 말 활동 후원 캠페인카테고리에 미리 결합한 표(base: SERVING.ML_CHURN_BY_CMPGN_CTGR_V). [Grain: 기준월 × 회원 × 캠페인카테고리]. [주의: 회원당 여러 행 · 회원수 중복제거]. [원천: GN_DW.ML → SERVING.ML_MEMBER_RISK_V · SERVING.ML_SPONSOR_RISK_V · CRM → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN].',
		MA as GN_DW.SERVING.ML_MEMBER_ATTR_ASOF_V primary key (STDR_MT,MBER_NO) with synonyms=('회원 특성','예측 회원 특성','기준월 시점 회원 속성') comment='예측 대상 회원의 기준월 시점 특성(성별·연령대·지역·회원상태·회원구분 = 기준월 말 · 후원금액대·유지기간대·신규기존·납입방식 = 기준월 행 없으면 직전 12개월 내 최근 실적 월 폴백). grain = 기준월 × 회원. 🔴 모델 피처가 아니다 — 예측 결과를 특성으로 나눠 보는 집계용이다. 미매칭 = (미매칭).',
		CS as GN_DW.SERVING.ML_CHURN_BY_SPONSORSHIP_V with synonyms=('후원사업별 중단 예측','중단 예측 후원사업','카테고리 후원사업별 중단 위험') comment='🆕 [O245] ML 중단 예측을 기준월 말 활동 약정의 캠페인카테고리 × 후원사업에 결합한 표(base: SERVING.ML_CHURN_BY_SPONSORSHIP_V). [Grain: 기준월 × 회원 × 캠페인카테고리 × 후원사업]. 「후원사업별」 또는 「캠페인카테고리 × 후원사업별」 중단 예측 질문에 쓴다. 🔴 cc 테이블과 grain 이 다르다 — 한 쿼리에서 cc 와 조인하지 않는다.'
	)
	relationships (
		CC_TO_MEMBER_ATTR as CC(STDR_MT,MBER_NO) references MA(STDR_MT,MBER_NO),
		CS_TO_MEMBER_ATTR as CS(STDR_MT,MBER_NO) references MA(STDR_MT,MBER_NO)
	)
	dimensions (
		CC.STDR_MT as cc.STDR_MT with synonyms=('기준월','예측 기준월','활동 기준월') comment='모델 실행 기준월(YYYYMM 문자열) = 활동 판정 기준월. 🔴 여러 기준월을 합산하지 않는다 — 미지정 시 최신 기준월 하나로 한정한다.',
		CC.MBER_NO as cc.MBER_NO with synonyms=('회원번호','회원') comment='회원번호. 회원수는 이 축의 중복제거로 센다.',
		CC.CMPGN_CTGR_NM as cc.CMPGN_CTGR_NM with synonyms=('캠페인카테고리','캠페인 카테고리','주요캠페인') comment='기준월 말 활동 중인 후원약정의 캠페인카테고리(MM294 · 적재 시점 동결값). 예: 고려인캠페인. 실제값은 조회로 확인한다.',
		CC.HAS_MEMBER_PRED as cc.HAS_MEMBER_PRED with synonyms=('회원 단위 예측 대상 여부') comment='TRUE = 회원 단위 중단 예측 대상 회원. 🔴 회원 단위 모델은 활동회원 일부만 예측한다 — 분모를 밝힐 때 쓴다.',
		CC.MEMBER_CHURN_GRADE as cc.MEMBER_CHURN_GRADE with synonyms=('중단위험 등급','회원 중단위험 등급','중단 가능성 등급') comment='회원 단위 중단위험 등급. 실제값 3종: ''고위험''·''주의''·''일반''. NULL = 회원 단위 예측 대상 아님(결측이 아니다).',
		CC.MEMBER_CHURN_CLASS as cc.MEMBER_CHURN_CLASS with synonyms=('회원 중단 예측 판정') comment='회원 단위 모델 판정. 실제값 2종: ''0''·''1''. NULL = 회원 단위 예측 대상 아님.',
		CC.HAS_SPONSOR_PRED as cc.HAS_SPONSOR_PRED with synonyms=('후원건 예측 대상 여부') comment='TRUE = 이 카테고리 후원건이 후원건 단위 이탈 예측 대상.',
		CC.SPONSOR_CHURN_GRADE as cc.SPONSOR_CHURN_GRADE with synonyms=('후원건 이탈위험 등급','캠페인 후원 이탈위험 등급') comment='이 카테고리 후원건 중 가장 높은 이탈위험 등급. 실제값 3종: ''고위험''·''주의''·''일반''. NULL = 후원건 예측 대상 아님.',
		CC.ACTIVE_SPNSR_CNT as cc.ACTIVE_SPNSR_CNT with synonyms=('활동 약정 수','후원 중인 약정 수') comment='그 회원이 이 캠페인카테고리로 기준월 말 활동 중인 약정 수(건). 행마다 이미 집계된 값이다 — 명단에는 이 값을 그대로 쓰고 COUNT 로 다시 세지 않는다.',
		MA.GENDER_NAME as ma.GENDER_NAME with synonyms=('성별','남녀') comment='성별(기준월 말 시점). 🔴 모델 피처가 아니다.',
		MA.AGE_BAND as ma.AGE_BAND with synonyms=('연령대','나이대') comment='연령대(기준월 말 시점). 값에 기업·단체·기타가 섞여 있다 — 개인 연령 분석은 회원구분 개인으로 거른다.',
		MA.REGION as ma.REGION with synonyms=('지역','거주지역','시도') comment='지역(기준월 말 시점).',
		MA.MEMBER_STATUS_NAME as ma.MEMBER_STATUS_NAME with synonyms=('회원상태') comment='회원상태(기준월 말 시점).',
		MA.MEMBER_TYPE_NAME as ma.MEMBER_TYPE_NAME with synonyms=('회원구분','개인 기업 단체') comment='회원구분 = 개인·기업·단체(기준월 말 시점). 🔴 법인구분(통합·사단·사복)은 CPR_DIV_NAME 이다(O245).',
		MA.AMOUNT_BAND as ma.AMOUNT_BAND with synonyms=('후원금액대','금액대') comment='후원금액대(그 달 회원 월실적 금액대1). 🆕 [O246-D] 기준월 당월 행이 없으면 직전 12개월 내 최근 실적 월 값을 쓴다(폴백) — 답변에 「기준월 말 시점」이라 쓰지 말고 「기준월(없으면 직전 실적 월) 기준」으로 쓴다.',
		MA.TENURE_BAND as ma.TENURE_BAND with synonyms=('유지기간','가입기간','후원기간대') comment='유지기간대(그 달 회원 월실적 기간대1). 🆕 [O246-D] 기준월 당월 행이 없으면 직전 12개월 내 최근 실적 월 값을 쓴다(폴백) — 답변에 「기준월 말 시점」이라 쓰지 말고 「기준월(없으면 직전 실적 월) 기준」으로 쓴다.',
		MA.NEW_EXISTING as ma.NEW_EXISTING with synonyms=('신규기존','신규 기존 구분') comment='신규/기존(그 달 회원 월실적). 🆕 [O246-D] 기준월 당월 행이 없으면 직전 12개월 내 최근 실적 월 값을 쓴다(폴백) — 답변에 「기준월 말 시점」이라 쓰지 말고 「기준월(없으면 직전 실적 월) 기준」으로 쓴다.',
		MA.PAYMENT_METHOD_NAME as ma.PAYMENT_METHOD_NAME with synonyms=('납입방식','결제수단') comment='납입방식(그 달 청구액이 가장 큰 결제수단 · 잠정). 🆕 [O246-D] 기준월 당월 행이 없으면 직전 12개월 내 최근 실적 월 값을 쓴다(폴백) — 답변에 「기준월 말 시점」이라 쓰지 말고 「기준월(없으면 직전 실적 월) 기준」으로 쓴다.',
		MA.ATTR_MATCHED as ma.ATTR_MATCHED with synonyms=('특성 매칭 여부') comment='TRUE=기준월 시점 회원 이력이 매칭됐다. FALSE 회원은 특성이 (미매칭)이다.',
		MA.REGIST_DEPT_NAME as ma.REGIST_DEPT_NAME with synonyms=('등록부서','회원 등록부서') comment='🆕 [O245] 회원 등록부서명(CRM 회원 마스터 현재 값). 🔴 실적부서·귀속부서가 아니다 — 부서 목표·실적과 대조하지 않는다.',
		MA.CPR_DIV_NAME as ma.CPR_DIV_NAME with synonyms=('법인구분','사단 사복 통합') comment='🆕 [O245] 회원 법인구분(코드사전 CM019 · 통합·사단·사복 · CRM 회원 마스터 현재 값). 개인·기업·단체 구분은 MEMBER_TYPE_NAME 이다.',
		MA.MEMBER_ACTIVE_SPNSR_CNT as ma.ACTIVE_SPNSR_CNT with synonyms=('활동 약정 수','회원 활동 약정 수','후원 중인 약정 수') comment='🆕 [O245] 그 회원의 기준월 말 활동 중인 후원약정 수(건 · 카테고리·후원사업 무관 전체). 0 = 활동 약정 없음. 회원당 1개 값이다 — 구간으로 나눠 GROUP BY 하거나 그대로 출력하고 SUM 하지 않는다.',
		CS.SP_STDR_MT as cs.STDR_MT with synonyms=('후원사업 표 기준월') comment='🆕 [O245] cs 표의 기준월(YYYYMM). 🔴 여러 기준월 합산 금지 — 미지정 시 최신 기준월 하나.',
		CS.SP_MBER_NO as cs.MBER_NO with synonyms=('후원사업 표 회원번호') comment='🆕 [O245] cs 표의 회원번호. 회원수는 이 축의 중복제거로 센다.',
		CS.SP_CMPGN_CTGR_NM as cs.CMPGN_CTGR_NM with synonyms=('후원사업 표 캠페인카테고리') comment='🆕 [O245] cs 표의 캠페인카테고리(기준월 말 활동 약정 · MM294 · 적재 시점 동결값). 실제값은 조회로 확인한다.',
		CS.SPONSORSHIP_NAME as cs.SPONSORSHIP_NAME with synonyms=('후원사업','후원사업명','활동 후원사업') comment='🆕 [O245] 기준월 말 활동 약정의 후원사업명(DIM_SPONSORSHIP). 🔴 실제값은 열거하지 않는다 — 후원사업 마스터가 늘어나면 낡는다. 값 목록은 조회로 확인한다.',
		CS.SP_ACTIVE_SPNSR_CNT as cs.ACTIVE_SPNSR_CNT with synonyms=('후원사업별 활동 약정 수') comment='🆕 [O245] 그 회원이 이 카테고리·후원사업으로 기준월 말 활동 중인 약정 수(건). 행마다 이미 집계된 값이다 — 명단에는 그대로 쓰고 COUNT 로 다시 세지 않는다.',
		CS.SP_HAS_MEMBER_PRED as cs.HAS_MEMBER_PRED with synonyms=('후원사업 표 회원 단위 예측 대상 여부') comment='🆕 [O245] TRUE = 회원 단위 중단 예측 대상 회원.',
		CS.SP_MEMBER_CHURN_GRADE as cs.MEMBER_CHURN_GRADE with synonyms=('후원사업 표 회원 중단위험 등급') comment='🆕 [O245] 회원 단위 중단위험 등급. 실제값 3종: ''고위험''·''주의''·''일반''. NULL = 회원 단위 예측 대상 아님.',
		CS.SP_SPONSOR_CHURN_GRADE as cs.SPONSOR_CHURN_GRADE with synonyms=('후원사업별 후원건 이탈위험 등급') comment='🆕 [O245] 이 카테고리·후원사업 약정 중 가장 높은 이탈위험 등급. 실제값 3종: ''고위험''·''주의''·''일반''. NULL = 후원건 예측 대상 아님.'
	)
	metrics (
		CC.ACTIVE_MEMBERS as COUNT(DISTINCT cc.MBER_NO) with synonyms=('활동회원수','후원 중인 회원수') comment='기준월 말 활동 중인 고유 회원수(명 · 중복제거). 🔴 카테고리별 값을 더하면 다중 후원 회원이 중복된다.',
		CC.MEMBER_HIGH_RISK_MEMBERS as COUNT(DISTINCT CASE WHEN cc.MEMBER_CHURN_GRADE = '고위험' THEN cc.MBER_NO END) with synonyms=('중단 고위험 회원수','중단 가능성 높은 회원수') comment='회원 단위 중단위험 등급이 고위험인 활동회원수(명 · 중복제거).',
		CC.MEMBER_PRED_MEMBERS as COUNT(DISTINCT CASE WHEN cc.HAS_MEMBER_PRED THEN cc.MBER_NO END) with synonyms=('회원 단위 예측 대상 회원수') comment='회원 단위 중단 예측 대상인 활동회원수(명 · 중복제거). 고위험 비율의 분모.',
		CC.SPONSOR_HIGH_RISK_MEMBERS as COUNT(DISTINCT CASE WHEN cc.SPONSOR_HIGH_CNT > 0 THEN cc.MBER_NO END) with synonyms=('후원건 고위험 회원수') comment='이 카테고리 후원건 중 고위험 후원건이 1건 이상인 활동회원수(명 · 중복제거).',
		CC.AVG_MEMBER_CHURN_PROB as AVG(cc.MEMBER_CHURN_PROB) with synonyms=('평균 중단확률') comment='회원 단위 중단확률 평균(0~1 · 표기는 %로 ×100). 회원당 여러 카테고리 행이 있으면 같은 회원 확률이 중복 반영된다 — 카테고리 하나로 거른 뒤 쓴다.',
		CS.SP_ACTIVE_MEMBERS as COUNT(DISTINCT cs.MBER_NO) with synonyms=('후원사업별 활동회원수') comment='🆕 [O245] 기준월 말 그 후원사업(·카테고리)으로 활동 중인 고유 회원수(명 · 중복제거). 🔴 후원사업별 값을 더하면 다중 후원 회원이 중복된다.',
		CS.SP_MEMBER_HIGH_RISK_MEMBERS as COUNT(DISTINCT CASE WHEN cs.MEMBER_CHURN_GRADE = '고위험' THEN cs.MBER_NO END) with synonyms=('후원사업별 중단 고위험 회원수') comment='🆕 [O245] 회원 단위 중단위험 등급이 고위험인 활동회원수(명 · 중복제거).',
		CS.SP_MEMBER_PRED_MEMBERS as COUNT(DISTINCT CASE WHEN cs.HAS_MEMBER_PRED THEN cs.MBER_NO END) with synonyms=('후원사업별 회원 단위 예측 대상 회원수') comment='🆕 [O245] 회원 단위 중단 예측 대상인 활동회원수(명 · 중복제거). 고위험 비율의 분모.',
		CS.SP_SPONSOR_HIGH_RISK_MEMBERS as COUNT(DISTINCT CASE WHEN cs.SPONSOR_HIGH_CNT > 0 THEN cs.MBER_NO END) with synonyms=('후원사업별 후원건 고위험 회원수') comment='🆕 [O245] 이 후원사업(·카테고리) 약정 중 고위험 후원건이 1건 이상인 활동회원수(명 · 중복제거).'
	)
	comment='ML 중단 예측 × 활동 후원 캠페인카테고리 SV. base=SERVING.ML_CHURN_BY_CMPGN_CTGR_V. [Grain: 기준월 × 회원 × 캠페인카테고리]. 「N월 활동회원 중 중단 가능성 높은 회원 중 ○○캠페인(카테고리) 후원 회원 · 회원번호 명단·수」 질문에 쓴다. 🆕 [O245] 후원사업별·카테고리 × 후원사업별 질문은 cs 테이블(ML_CHURN_BY_SPONSORSHIP_V)로 답한다. [활성 지표: 활동회원수 · 중단 고위험 회원수 · 회원 단위 예측 대상 회원수 · 후원건 고위험 회원수 · 평균 중단확률]. [주의: 머신러닝 예측치이며 실적이 아니다 · 회원 단위 모델은 활동회원 일부만 예측한다 · 회원 단위 등급과 후원건 단위 등급은 서로 다른 모델이다 · 실적 SV 와 같은 표에 합산하지 않는다]. [원천: GN_DW.ML → SERVING.ML_MEMBER_RISK_V · SERVING.ML_SPONSOR_RISK_V · CRM → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN].'
	ai_sql_generation '[O241-M · O245 회원 특성 축] 성별·연령대·지역·회원상태·회원구분·법인구분(통합·사단·사복)·등록부서·활동 약정 수·후원금액대·유지기간·신규기존·납입방식으로 나눠 달라는 질문은 ma 테이블 차원으로 GROUP BY 한다(성별·연령대·지역·회원상태·회원구분 = 기준월 말 시점 · 금액대·유지기간·신규기존·납입방식 = 기준월 행 없으면 직전 실적 월 값 · 각주에 「기준월(없으면 직전 실적 월) 기준」으로 밝힌다 · 모델 피처 아님). 회원수는 반드시 예측 테이블 회원번호의 COUNT(DISTINCT) 로 센다. (미매칭) 행은 따로 밝힌다. 🆕 [O245] ROLLUP 합계 행에는 COALESCE(차원, (미매칭)) 를 씌우지 않는다 — CASE WHEN GROUPING(차원) = 1 THEN 전체 합계 WHEN 차원 IS NULL THEN (미매칭) ELSE 차원 END 로 구분한다. [O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥에서 쓰는 차원은 그 CTE 의 SELECT 목록에 먼저 넣는다. (다) 날짜 필터는 이 시맨틱 뷰에 선언된 차원 이름만 쓴다.
  [O241-R 반올림 · 전 SV 공통] 최종 SELECT 에서 비율(%)·평균·확률·초·기여도 등 소수 값은 ROUND(<식>, 2)::NUMBER(38,2) 로 반올림해 출력한다(FLOAT 그대로 두면 0.98999… 처럼 보이므로 NUMBER 로 캐스팅한다 · 집계 식 바깥에 씌우며 정렬·필터에는 원래 식을 쓴다). 금액·건수·명수는 숫자형 그대로 둔다(문자열로 바꾸지 않는다 — 쉼표는 답변 작성 단계에서 붙인다). [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다(WITH SYNONYMS 첫 항목 · 단위 괄호). 영문 식별자를 출력 컬럼명으로 남기지 않는다.
  핵심 규칙: (1) 기준월 미지정 시 최신 기준월(MAX(cc.STDR_MT)) 하나로 한정하고 밝힌다. (2) 「중단 가능성 높은 회원」의 기본 = 회원 단위 등급 cc.MEMBER_CHURN_GRADE = ''고위험''. 질문이 「그 캠페인 후원의 이탈 위험」을 물으면 cc.SPONSOR_HIGH_CNT > 0 을 쓴다 — 어느 기준인지 표 제목에 밝힌다. (3) 캠페인카테고리는 cc.CMPGN_CTGR_NM = ''<값>'' 으로 거른다. (4) 명단 요청 = 회원번호 · 회원 중단확률(%) ROUND(cc.MEMBER_CHURN_PROB*100,2) · 회원 중단위험 등급 · 후원건 이탈위험 등급 · 활동 약정 수 cc.ACTIVE_SPNSR_CNT(값 그대로 · COUNT 금지) 를 회원번호 중복 없이 반환하고 중단확률 내림차순으로 정렬한다. (5) 명단과 함께 같은 기준월·카테고리의 활동회원수 · 회원 단위 예측 대상 회원수 · 고위험 회원수를 분모로 반환한다 — 🔴 분모 집계에는 등급 조건(MEMBER_CHURN_GRADE = ''고위험'')을 WHERE 에 넣지 않고 COUNT(DISTINCT CASE WHEN …) 로만 건다(WHERE 에 넣으면 활동회원수·예측 대상이 고위험 수와 같아지는 오류). 명단 CTE 에만 등급 조건을 둔다. (6) 🔴 실적 SV 와 조인하지 않는다. (7) 🆕 [O245] 「후원사업별」·「캠페인카테고리 × 후원사업별」 질문은 cs 테이블(cs.SPONSORSHIP_NAME · cs.SP_CMPGN_CTGR_NM)로 답한다 — 분모·고위험 규칙은 (2)·(5)와 같고 cs 컬럼으로 쓴다. 🔴 cc 와 cs 를 한 쿼리에서 조인하지 않는다(grain 이 다르다).'
	ai_verified_queries (
		VQR_O224_KOREAN_HIGH_RISK_LIST AS ( 
QUESTION '26년 9월 활동회원 중 중단가능성 높은 회원 중 고려인캠페인 후원 회원번호 명단' 
VERIFIED_BY '(DW = O224)'
SQL 'WITH base AS (SELECT cc.MBER_NO, cc.MEMBER_CHURN_PROB, cc.MEMBER_CHURN_GRADE, cc.SPONSOR_CHURN_GRADE, cc.ACTIVE_SPNSR_CNT, cc.HAS_MEMBER_PRED FROM cc WHERE cc.STDR_MT = ''202609'' AND cc.CMPGN_CTGR_NM = ''고려인캠페인''), denom AS (SELECT COUNT(DISTINCT MBER_NO) AS ACT, COUNT(DISTINCT CASE WHEN HAS_MEMBER_PRED THEN MBER_NO END) AS PRED, COUNT(DISTINCT CASE WHEN MEMBER_CHURN_GRADE = ''고위험'' THEN MBER_NO END) AS HIGH FROM base) SELECT b.MBER_NO AS "회원번호", ROUND(b.MEMBER_CHURN_PROB * 100, 2) AS "회원 중단확률(%)", b.MEMBER_CHURN_GRADE AS "회원 중단위험 등급", b.SPONSOR_CHURN_GRADE AS "후원건 이탈위험 등급", b.ACTIVE_SPNSR_CNT AS "활동 약정 수(건)", d.ACT AS "활동회원수(명)", d.PRED AS "회원 단위 예측 대상 회원수(명)", d.HIGH AS "중단 고위험 회원수(명)" FROM base b CROSS JOIN denom d WHERE b.MEMBER_CHURN_GRADE = ''고위험'' ORDER BY b.MEMBER_CHURN_PROB DESC NULLS LAST LIMIT 100'),
		VQR_O224_KOREAN_HIGH_RISK AS ( 
QUESTION '26년 9월 활동회원 중 중단가능성이 높은 회원 중 캠페인카테고리 고려인캠페인을 후원중인 회원 수' 
VERIFIED_BY '(DW = O224)'
SQL 'SELECT cc.STDR_MT AS "기준월", COUNT(DISTINCT cc.MBER_NO) AS "활동회원수(명)", COUNT(DISTINCT CASE WHEN cc.HAS_MEMBER_PRED THEN cc.MBER_NO END) AS "회원 단위 예측 대상 회원수(명)", COUNT(DISTINCT CASE WHEN cc.MEMBER_CHURN_GRADE = ''고위험'' THEN cc.MBER_NO END) AS "중단 고위험 회원수(명)", COUNT(DISTINCT CASE WHEN cc.SPONSOR_HIGH_CNT > 0 THEN cc.MBER_NO END) AS "후원건 고위험 회원수(명)" FROM cc WHERE cc.STDR_MT = ''202609'' AND cc.CMPGN_CTGR_NM = ''고려인캠페인'' GROUP BY cc.STDR_MT')
	);