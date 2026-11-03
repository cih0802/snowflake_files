create or replace semantic view SV_MSTR_SPNSR_DVLP
	tables (
		MD as GN_DW.SERVING.MSTR_SPNSR_DVLP_V with synonyms=('MSTR 개발','MSTR 후원개발','MSTR 리포트','정기회원 후원개발') comment='MSTR 정기회원 후원개발 리포트 (base: SERVING.MSTR_SPNSR_DVLP_V). [Grain: 개발 팩트 1행]. [활성 지표: MSTR 개발(건)·개발(명)·후원금액]. [주의: MSTR 기준 정의, GN_DW 지표와 합산 금지, 개발(명) 비가산]. [원천: BRONZE_CRM → GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM(MSTR 이관 로직) → SERVING.MSTR_SPNSR_DVLP_V].',
		GL as GN_DW.SERVING.MSTR_DVLP_GOAL_V with synonyms=('MSTR 개발 목표','개발 목표','목표 달성') comment='🆕 [O207] MSTR 개발 목표·실적 (base: SERVING.MSTR_DVLP_GOAL_V). [Grain: 실적부서 × 기준년월 × 개발구분]. [활성 지표: 월 목표(건)·실적(건)·달성률]. [주의: 실질 목표는 신규만 · md 테이블과 조인하지 않는다].',
		YE as GN_DW.SERVING.MSTR_DVLP_YE_TREND_V with synonyms=('연도말 개발 예측','연말 개발 전망','연도말 추세') comment='🆕 [O207] MSTR 연도말 개발 추세 참고치 (base: SERVING.MSTR_DVLP_YE_TREND_V). [Grain: 실적부서 × 기준연도 × 개발구분]. [활성 지표: 연 목표·마감월 실적·추세 참고치·목표 대비 %]. [주의: 모델 예측 아님 · 직전 3개 마감월 평균 기반].',
		YB as GN_DW.SERVING.MSTR_DVLP_YE_TREND_BSNS_V with synonyms=('후원사업별 연도말 개발 예측','후원사업별 연말 전망') comment='🆕 [O207] MSTR 후원사업2 별 연도말 개발 추세 참고치 (base: SERVING.MSTR_DVLP_YE_TREND_BSNS_V). [Grain: 후원사업2 × 기준연도 × 개발구분]. [주의: 모델 예측 아님 · 후원사업 축에는 목표가 없다].'
	)
	dimensions (
		MD.STRD_MT as md.STRD_MT with synonyms=('기준년월','기준월') comment='기준년월(YYYYMM 문자열). 🔴 적재 범위는 조회해서 확인한다(열거하지 않는다).',
		MD.STRD_DE as md.STRD_DE with synonyms=('기준일자','발생일자') comment='발생일자(YYYYMMDD 문자열).',
		MD.DVLP_DIV_CD as md.DVLP_DIV_CD with synonyms=('개발구분코드') comment='MSTR 개발구분코드. 라벨은 DVLP_DIV_NM.',
		MD.DVLP_DIV_NM as md.DVLP_DIV_NM with synonyms=('개발구분') comment='MSTR 개발구분명(신규/증액/감액/재후원/후원중단). 🔴 MSTR 「개발」 리포트 기본 범위는 신규·증액·재후원이다.',
		MD.CPR_DIV_NM as md.CPR_DIV_NM with synonyms=('법인','법인구분') comment='법인구분명(MSTR 표기).',
		MD.DEPT4_NM as md.DEPT4_NM with synonyms=('구분_팀','부서4') comment='MSTR 실적부서4(리포트 「구분_팀」).',
		MD.DEPT3_NM as md.DEPT3_NM with synonyms=('본부/지부','부서3') comment='MSTR 실적부서3(리포트 「본부/지부」).',
		MD.DEPT2_NM as md.DEPT2_NM with synonyms=('팀/지부','부서2') comment='MSTR 실적부서2(리포트 「팀/지부」).',
		MD.DEPT_NM as md.DEPT_NM with synonyms=('부서','실적부서') comment='MSTR 실적부서명(리포트 「부서」). 🔴 GN_DW 부서 차원과 같은 조직이라 단정하지 않는다.',
		MD.BRND_NM as md.BRND_NM with synonyms=('브랜드','브랜드명','세부 브랜드','CRM 브랜드') comment='브랜드명(원천 COMMENT = 브랜드 · 60여 종). 🆕 [O212-B 원천 컬럼명 원칙] 「브랜드」는 이 축이다 — 「공통브랜드」를 말할 때만 CMMN_BRND_NM 을 쓴다.',
		MD.UPPER_CMPGN_NM as md.UPPER_CMPGN_NM with synonyms=('상위캠페인') comment='상위캠페인명.',
		MD.CMPGN_CD as md.CMPGN_CD with synonyms=('캠페인코드','CP') comment='캠페인코드(리포트 「CP」).',
		MD.CMPGN_NM as md.CMPGN_NM with synonyms=('캠페인') comment='캠페인명.',
		MD.PR_MTH_NM as md.PR_MTH_NM with synonyms=('홍보방법') comment='홍보방법명.',
		MD.SPNSR_BSNS_NM as md.SPNSR_BSNS_NM with synonyms=('후원사업') comment='후원사업명.',
		MD.SPNSR_BSNS2_NM as md.SPNSR_BSNS2_NM with synonyms=('후원사업2') comment='MSTR 후원사업2(재분류 그룹 · 리포트 「후원사업2」).',
		MD.SEX_NM as md.SEX_NM with synonyms=('성별') comment='성별명(MSTR 표기).',
		MD.AGE_TERM_NM as md.AGE_TERM_NM with synonyms=('연령대') comment='연령대명(MSTR 구간).',
		MD.NEW_OLD_DIV_NM as md.NEW_OLD_DIV_NM with synonyms=('신규기존구분','신규/기존','신규 기존') comment='🆕 [O206-D] MSTR 신규기존구분명. 실제값: ''신규''·''기존''(코드 99 = ''없음''). 🔴 MSTR 원천이 개발 건마다 판정해 둔 값이다 — 가입일로 다시 계산하지 않는다(MSTR 에는 가입일 컬럼이 없다).',
		MD.MBER_NO as md.MBER_NO with synonyms=('회원번호') comment='회원번호. 개발(명) 중복제거 전용 — 회원 목록 질의에는 쓰지 않는다.',
		MD.SPNSR_TERM_NM as md.SPNSR_TERM_NM with synonyms=('후원기간대','후원기간') comment='🆕 [O207] 후원기간대(CM016 · 1년 미만/1~5년/5~10년/10년 이상 · 첫 후원일 → 발생일).',
		MD.SPNSR_TERM2_NM as md.SPNSR_TERM2_NM with synonyms=('후원기간대2','후원기간 1년 단위') comment='🆕 [O207] 후원기간대2(DMMM08 · 1년 단위 11구간).',
		MD.SPNSR_AMT_NM as md.SPNSR_AMT_NM with synonyms=('후원금액범위','후원금액대') comment='🆕 [O207] 후원금액범위(CM012 · 원천 판정값). 🔴 그 행 후원금액의 구간이 아니다 — 개발금액 구간은 후원금액대2 를 쓴다.',
		MD.SPNSR_AMT2_NM as md.SPNSR_AMT2_NM with synonyms=('후원금액대2','개발금액대') comment='🆕 [O207] 후원금액대2(DMMM09 · 1만원 단위 · 후원사업별 최초 정상 개발건 금액 기준 · 「없음」 = 매칭 없음).',
		MD.SETLE_NM as md.SETLE_NM with synonyms=('결제수단','결제방법','납입방법') comment='🆕 [O207] 결제수단(PM040 · 자동이체·신용카드·휴대폰·네이버페이 등).',
		MD.MBER_DIV_NM as md.MBER_DIV_NM with synonyms=('회원구분','개인/기업/단체') comment='🆕 [O207] 회원구분(MM018 · 개인·기업·단체).',
		MD.AREA_NM as md.AREA_NM with synonyms=('지역','시도') comment='🆕 [O207] 시도(CM011). 🔴 「기타」가 큰 비중을 차지한다 · 라벨 없는 코드는 NULL.',
		MD.SPNSR_BSNS_ABRV_NM as md.SPNSR_BSNS_ABRV_NM with synonyms=('후원약칭','국내/해외/결연') comment='🆕 [O207] 후원약칭(CM003 · 국내·결연·해외·해외구호·북한 등).',
		MD.CANCL_RDCAMT_RSN_NM as md.CANCL_RDCAMT_RSN_NM with synonyms=('중단사유','감액사유','중단·감액 사유') comment='🆕 [O207] 중단·감액 사유. 🔴 개발구분 후원중단 = 후원중단사유(MM005) · 감액 = 후원사업취소사유(MM002) · 그 외 개발구분은 NULL(개념 없음). 사유 질문은 개발구분을 후원중단 또는 감액 하나로 고정한다.',
		MD.PRE_CMPGN_NM as md.PRE_CMPGN_NM with synonyms=('직전캠페인','이전 캠페인') comment='🆕 [O207] 직전캠페인(재후원 전 마지막 캠페인). 🔴 재후원·금액>0 행에만 값이 있다.',
		MD.CMMN_BRND_NM as md.CMMN_BRND_NM with synonyms=('공통브랜드','공통 브랜드') comment='🆕 [O212] 공통브랜드(MM297 · 예: 디지털·교육기관·지역개발·대면모금·영상광고·재송출·방송). 「공통브랜드」를 말할 때 쓴다(「브랜드」는 BRND_NM). 캠페인 마스터 현재값.',
		MD.DVLP_INFLOW_PATH_NM as md.DVLP_INFLOW_PATH_NM with synonyms=('개발인입경로','인입경로','개발 인입경로','모집채널') comment='🆕 [O212] 개발인입경로(MM293 · 12종 · 예: 디지털·방송·대면모금·교육기관·지역개발·콜개발·영상광고·재송출). 캠페인 마스터 현재값. 🔴 공통브랜드와 라벨이 겹쳐 보여도 다른 축이다 — 한쪽 값으로 다른 쪽을 필터하지 않는다.',
		MD.CMPGN_TYPE2_NM as md.CMPGN_TYPE2_NM with synonyms=('캠페인유형2','캠페인유형(사업/사례)','사업사례구분','사업/사례') comment='🆕 [O212] 캠페인유형2(원천 COMMENT = 캠페인유형(사업/사례) · MM296 · 4종 = 사례·사업·굿즈·기타). 「캠페인유형2」·「사업/사례」를 말할 때 쓴다 — 「캠페인유형」은 CMPGN_TYPE1_NM(국내/해외)이다. 캠페인 마스터 현재값.',
		MD.CMPGN_CTGR_NM as md.CMPGN_CTGR_NM with synonyms=('캠페인카테고리','주요캠페인','캠페인 카테고리','캠페인 소분류') comment='🆕 [O212] 캠페인카테고리(MM294 · 세부 40여 종 · 예: 초등캠페인·국내사례캠페인·해외캠페인·희망TV). 「캠페인카테고리」「주요캠페인」을 명시할 때만 쓴다. 🔴 캠페인유형2 의 엄격한 하위가 아니다(한 카테고리가 여러 유형2 에 걸친다).',
		MD.CMPGN_TYPE1_NM as md.CMPGN_TYPE1_NM with synonyms=('캠페인유형','캠페인 유형','캠페인유형(국내/해외)','국내해외','국내/해외') comment='🆕 [O212-B] 캠페인유형(원천 COMMENT = 캠페인유형(국내/해외) · MM295 · 국내·해외·통합 등). 「캠페인유형」을 말할 때 쓴다(「캠페인유형2」는 사업/사례 CMPGN_TYPE2_NM). 캠페인 마스터 현재값.',
		GL.STRD_MT as gl.STRD_MT with synonyms=('목표 기준년월') comment='🆕 [O207] 목표·실적 기준년월(YYYYMM).',
		GL.STRD_YY as gl.STRD_YY with synonyms=('목표 기준연도') comment='🆕 [O207] 목표·실적 기준연도(YYYY).',
		GL.DVLP_DIV_CD as gl.DVLP_DIV_CD with synonyms=('목표 개발구분코드') comment='🆕 [O207] 개발구분코드(1 = 신규).',
		GL.DVLP_DIV_NM as gl.DVLP_DIV_NM with synonyms=('목표 개발구분') comment='🆕 [O207] 개발구분. 🔴 실질 목표는 신규만 있다 — 목표 질문은 신규로 고정한다.',
		GL.DEPT4_NM as gl.DEPT4_NM with synonyms=('목표 구분_팀') comment='🆕 [O207] 실적부서4(구분_팀).',
		GL.DEPT3_NM as gl.DEPT3_NM with synonyms=('목표 본부/지부') comment='🆕 [O207] 실적부서3(본부/지부).',
		GL.DEPT2_NM as gl.DEPT2_NM with synonyms=('목표 팀/지부') comment='🆕 [O207] 실적부서2(팀/지부).',
		GL.DEPT_NM as gl.DEPT_NM with synonyms=('목표 부서') comment='🆕 [O207] 실적부서명(목표 등록 단위).',
		GL.CLOSED_MONTH_YN as gl.CLOSED_MONTH_YN with synonyms=('마감월 여부') comment='🆕 [O207] Y = 마감월 · N = 진행 중인 최신 기준월 또는 미래 월(부분 실적).',
		YE.STRD_YY as ye.STRD_YY with synonyms=('전망 기준연도') comment='🆕 [O207] 연도말 추세 참고치 기준연도(YYYY).',
		YE.AS_OF_MT as ye.AS_OF_MT with synonyms=('산출 기준월') comment='🆕 [O207] 산출 기준 최신 기준년월(진행 중 · 부분 실적).',
		YE.DVLP_DIV_CD as ye.DVLP_DIV_CD with synonyms=('전망 개발구분코드') comment='🆕 [O207] 개발구분코드(1 = 신규).',
		YE.DVLP_DIV_NM as ye.DVLP_DIV_NM with synonyms=('전망 개발구분') comment='🆕 [O207] 개발구분. 🔴 목표 대비 % 는 신규에만 의미가 있다.',
		YE.DEPT4_NM as ye.DEPT4_NM with synonyms=('전망 구분_팀') comment='🆕 [O207] 실적부서4(구분_팀).',
		YE.DEPT3_NM as ye.DEPT3_NM with synonyms=('전망 본부/지부') comment='🆕 [O207] 실적부서3(본부/지부).',
		YE.DEPT2_NM as ye.DEPT2_NM with synonyms=('전망 팀/지부') comment='🆕 [O207] 실적부서2(팀/지부).',
		YE.DEPT_NM as ye.DEPT_NM with synonyms=('전망 부서') comment='🆕 [O207] 실적부서명.',
		YB.STRD_YY as yb.STRD_YY with synonyms=('후원사업 전망 기준연도') comment='🆕 [O207] 기준연도(YYYY).',
		YB.AS_OF_MT as yb.AS_OF_MT with synonyms=('후원사업 전망 산출 기준월') comment='🆕 [O207] 산출 기준 최신 기준년월(진행 중).',
		YB.DVLP_DIV_CD as yb.DVLP_DIV_CD with synonyms=('후원사업 전망 개발구분코드') comment='🆕 [O207] 개발구분코드(1 = 신규).',
		YB.DVLP_DIV_NM as yb.DVLP_DIV_NM with synonyms=('후원사업 전망 개발구분') comment='🆕 [O207] 개발구분.',
		YB.SPNSR_BSNS2_NM as yb.SPNSR_BSNS2_NM with synonyms=('전망 후원사업2','후원사업별 전망') comment='🆕 [O207] 후원사업2(MSTR 재분류).'
	)
	metrics (
		MD.MSTR_DVLP_CNT as ROUND(SUM(md.SPNSR_AMT_CNT), 4) with synonyms=('개발(건)','MSTR 개발건','개발 건수') comment='MSTR 개발(건) = 후원금액 ÷ 10,000 의 합(소수 4자리). 🔴 GN_DW 개발건수(사건 건수)와 정의가 다르다.',
		MD.MSTR_DVLP_MEMBERS as COUNT(DISTINCT md.MBER_NO) with synonyms=('개발(명)','MSTR 개발 회원수','개발 명') comment='MSTR 개발(명) = 회원번호 중복제거. 🔴 비가산 — 하위 그룹 값을 더해 상위 값을 만들지 않는다.',
		MD.MSTR_SPNSR_AMT as SUM(md.SPNSR_AMT) with synonyms=('후원금액','개발 금액') comment='후원금액 합계(원). 감액·후원중단 구분은 음수다.',
		MD.MSTR_ROW_CNT as SUM(md.DVLP_CNT) with synonyms=('개발 행수','원천 건수') comment='원천 개발구분건수 합계(행 단위). MSTR 리포트 「개발(건)」이 아니다.',
		GL.GOAL_DVLP_CNT as SUM(gl.GOAL_CNT) with synonyms=('개발 목표(건)','목표(건)','월 목표') comment='🆕 [O207] MSTR 개발 목표(건) 합. 🔴 실질 목표는 신규만 있다.',
		GL.GOAL_ACT_CNT as ROUND(SUM(gl.ACT_CNT), 4) with synonyms=('목표 대비 실적(건)','실적(건)') comment='🆕 [O207] 목표와 같은 키(부서×월×개발구분)의 MSTR 개발(건) 실적 합(소수 4자리).',
		GL.GOAL_ACHV_RATE as ROUND(DIV0(SUM(IFF(gl.GOAL_CNT > 0, gl.ACT_CNT, 0)), SUM(gl.GOAL_CNT)) * 100, 1) with synonyms=('목표 달성률(%)','달성률','달성율') comment='🆕 [O207] 목표 달성률(%) = 목표가 있는 부서·월 실적 ÷ 목표 × 100(소수 1자리). 🔴 목표 없는 부서 실적은 분자에서 뺀다.',
		YE.YE_GOAL_CNT as SUM(ye.YY_GOAL_CNT) with synonyms=('연 개발 목표(건)','연간 목표') comment='🆕 [O207] 연 개발 목표(건) = 월 목표 합.',
		YE.YE_CLOSED_ACT_CNT as ROUND(SUM(ye.CLOSED_ACT_CNT), 4) with synonyms=('마감월 누적 실적(건)','연누적 실적') comment='🆕 [O207] 그 해 마감월 MSTR 개발(건) 실적 합.',
		YE.YE_CUR_MONTH_ACT_CNT as ROUND(SUM(ye.CUR_MONTH_ACT_CNT), 4) with synonyms=('진행 월 부분 실적(건)') comment='🆕 [O207] 진행 중 최신 기준월의 부분 실적(참고 · 추세 산식에 쓰지 않는다).',
		YE.YE_LAST3_AVG_CNT as ROUND(SUM(ye.LAST3_AVG_CNT), 4) with synonyms=('직전 3개월 평균(건)') comment='🆕 [O207] 직전 3개 마감월 월평균 실적(건 · 현재 연도만).',
		YE.YE_TREND_DVLP_CNT as ROUND(SUM(ye.YE_TREND_CNT), 4) with synonyms=('연도말 개발 추세 참고치(건)','연도말 예측(건)','연말 전망(건)') comment='🆕 [O207] 연도말 개발 추세 참고치(건) = 마감월 실적 + 남은 월 × 직전 3개월 평균. 🔴🔴 모델 예측이 아니다 — 답변에 「추세 참고치(모델 예측 아님)」를 밝힌다.',
		YE.YE_TREND_GOAL_RATE as ROUND(DIV0(SUM(IFF(ye.YY_GOAL_CNT > 0, ye.YE_TREND_CNT, 0)), SUM(ye.YY_GOAL_CNT)) * 100, 1) with synonyms=('연 목표 대비 추세(%)','연말 달성 전망(%)') comment='🆕 [O207] 연 목표 대비 추세 참고치(%) = 목표가 있는 부서의 추세 참고치 ÷ 연 목표 × 100(소수 1자리).',
		YB.YB_CLOSED_ACT_CNT as ROUND(SUM(yb.CLOSED_ACT_CNT), 4) with synonyms=('후원사업 마감월 누적 실적(건)') comment='🆕 [O207] 후원사업2 별 그 해 마감월 MSTR 개발(건) 실적 합.',
		YB.YB_LAST3_AVG_CNT as ROUND(SUM(yb.LAST3_AVG_CNT), 4) with synonyms=('후원사업 직전 3개월 평균(건)') comment='🆕 [O207] 후원사업2 별 직전 3개 마감월 월평균 실적(건).',
		YB.YB_TREND_DVLP_CNT as ROUND(SUM(yb.YE_TREND_CNT), 4) with synonyms=('후원사업 연도말 개발 추세 참고치(건)','후원사업별 연도말 예측(건)') comment='🆕 [O207] 후원사업2 별 연도말 개발 추세 참고치(건). 🔴 모델 예측이 아니다 · 목표 없음.'
	)
	comment='MSTR 정기회원 후원개발 SV(MSTR 1차 이관 · O197/O200-B). base=SERVING.MSTR_SPNSR_DVLP_V. 🔴🔴 **MSTR 기준 정의다** — GN_DW 회원 SV(SV_MEMBER_EVENT 등)의 개발건수·회원수와 정의가 달라 같은 표에 합산·차감하지 않는다. 🔴🔴 **MSTR 개발(건) = 후원금액 ÷ 10,000** 이다(사건 건수가 아니다). 🔴 개발(명)은 중복제거라 비가산이다. 🔴 MSTR 「개발」 리포트의 기본 범위는 개발구분 신규·증액·재후원이다 — 감액·후원중단을 섞지 않는다. 🔴 적재 기준월은 PoC 범위로 제한돼 있다 — 조회로 확인한다. 활성: 개발(건)·개발(명)·후원금액 · 기준년월/기준일자/개발구분/법인/부서4·3·2·부서/브랜드/상위캠페인/캠페인/홍보방법/후원사업/후원사업2/성별/연령대/신규기존구분 축 · 🆕 [O207] 후원기간대·후원기간대2·후원금액범위·후원금액대2·결제수단·회원구분·시도·후원약칭·중단/감액 사유·직전캠페인 축 · 🆕 [O212] 공통브랜드·개발인입경로·캠페인유형(국내/해외)·캠페인유형2(사업/사례)·캠페인카테고리 축(캠페인 마스터 현재값) · 목표(gl: 월 목표·실적·달성률) · 연도말 추세 참고치(ye: 부서 · yb: 후원사업2 · 모델 예측 아님). 🔴 md·gl·ye·yb 네 테이블은 서로 조인하지 않는다(관계 없음 · 질문마다 한 테이블만 쓴다).'
	ai_sql_generation '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 🔴🔴 **개발구분 미지정 시 MSTR 개발 리포트 범위인 신규·증액·재후원(DVLP_DIV_CD IN (''1'',''2'',''4''))으로 한정하고 그 사실을 밝힌다.** 감액·후원중단은 사용자가 명시할 때만 포함하며 개발과 합산하지 않는다. (2) 🔴🔴 **「개발(건)」은 MSTR_DVLP_CNT(후원금액÷10,000 합)다** — 행 수(COUNT)나 MSTR_ROW_CNT 로 바꾸지 않는다. 답변에 「MSTR 기준」임을 밝힌다. (3) 🔴 **개발(명)은 COUNT(DISTINCT md.MBER_NO)로 그 그룹에서 직접 센다** — 하위 그룹 합으로 만들지 않는다. (4) 🔴 **기준년월 미지정 시 데이터에 존재하는 최신 기준년월 하나로 한정하고 밝힌다.** (5) 🔴 **GN_DW 지표와 섞지 않는다.** (6) **금액은 원 단위다.** (7) 적용 조건(그룹 미지정 시): 최신 기준년월 + 신규·증액·재후원으로 한정해 개발구분별 개발(건)·개발(명)·후원금액을 반환한다. (8) 🔴 metric 이름을 md 컬럼처럼 참조하지 않는다 — 정의식(ROUND(SUM(md.SPNSR_AMT_CNT), 4) 등)으로 집계한다. (9) 🆕 [O206-D] 개발(건)은 소수 4자리로 반올림해 낸다 — ROUND(SUM(md.SPNSR_AMT_CNT), 4). (10) 🆕 [O206-D] 「신규/기존」 구분은 md.NEW_OLD_DIV_NM 으로 그룹·필터한다 — 가입일이 없다고 산출 불가로 답하지 않는다.
  🆕 [O207 규칙] (11) 🔴🔴 **md·gl·ye·yb 는 서로 조인하지 않는다** — 개발 실적의 축 분해(후원기간대·결제수단·시도·사유 등)는 md, 목표·달성률은 gl, 부서별·전사 연도말 예측·전망은 ye, 후원사업별 연도말 예측·전망은 yb(목표 없음) 하나만 쓴다. (12) 🔴🔴 **목표는 gl·ye 로만 낸다** — 실질 목표는 신규만 있으므로 목표·달성률·연도말 전망 질문은 개발구분 신규(DVLP_DIV_CD = ''1'')로 고정하고 그 사실을 밝힌다. (13) 🔴🔴 **ye 의 연도말 값은 「추세 참고치(모델 예측 아님)」다** — 산식(마감월 실적 + 남은 월 × 직전 3개 마감월 평균)과 산출 기준월(ye.AS_OF_MT)을 함께 반환하고, 연도 미지정 시 ye.AS_OF_MT 가 속한 연도로 한정한다. 진행 중인 최신 기준월(gl.CLOSED_MONTH_YN = ''N'')의 실적은 부분 실적이라 달성률 비교에서 따로 밝힌다. 🆕 [O207-C] 누계·연간 달성률은 마감월(gl.CLOSED_MONTH_YN = ''Y'')만으로 계산한다 — 미래 월 목표와 부분 실적을 함께 더하면 달성률이 낮게 왜곡된다. (14) 🔴 중단·감액 사유(md.CANCL_RDCAMT_RSN_NM)는 개발구분을 후원중단 또는 감액 하나로 고정해 묻는다 — 두 개발구분의 사유 코드 체계가 다르다. (15) 🔴 후원금액범위(md.SPNSR_AMT_NM)는 원천 판정값이다 — 「개발금액 구간」 질문은 후원금액대2(md.SPNSR_AMT2_NM)로 답한다. (16) 🔴 부서별 질문에서 목표 없는 부서는 달성률을 만들지 않고 「목표 미등록」으로 밝힌다. 🆕 [O212 분류 축 · 대분류 우선] (17) 🔴🔴 🆕 [O212-B 원천 컬럼명 원칙] 질문의 분류 이름은 원천 컬럼 COMMENT 의 한글 이름 그대로 축에 대응한다 — 「브랜드」 = md.BRND_NM · 「공통브랜드」 = md.CMMN_BRND_NM · 「캠페인유형」 = md.CMPGN_TYPE1_NM(국내/해외) · 「캠페인유형2」 = md.CMPGN_TYPE2_NM(사업/사례) · 「캠페인카테고리」·「주요캠페인」 = md.CMPGN_CTGR_NM · 「개발인입경로」·「인입경로」 = md.DVLP_INFLOW_PATH_NM. 묻지 않은 분류 축을 함께 GROUP BY 하지 않는다. (18) 🔴 네 분류 축은 캠페인 마스터 현재값이다 — 축 이름에 「공통브랜드」 등 업무명을 그대로 별칭으로 쓴다.'
	ai_verified_queries (
		VQR_O207_YE_TREND_DEPT4 AS ( 
QUESTION '구분_팀별 올해 연도말 신규 개발 예측(목표 대비)' 
VERIFIED_BY '(O207 · 원천 직접 집계 대조 · 2026 신규 전사 참고치 250,243.3201건 / 목표 352,702건 = 70.9% · 산출 기준월 202610)'
SQL 'SELECT ye.DEPT4_NM AS "전망 구분_팀", MAX(ye.AS_OF_MT) AS "산출 기준월", SUM(ye.YY_GOAL_CNT) AS "연 개발 목표(건)", ROUND(SUM(ye.CLOSED_ACT_CNT), 4) AS "마감월 누적 실적(건)", ROUND(SUM(ye.LAST3_AVG_CNT), 4) AS "직전 3개월 평균(건)", ROUND(SUM(ye.YE_TREND_CNT), 4) AS "연도말 개발 추세 참고치(건)", ROUND(DIV0(SUM(IFF(ye.YY_GOAL_CNT > 0, ye.YE_TREND_CNT, 0)), SUM(ye.YY_GOAL_CNT)) * 100, 1) AS "연 목표 대비 추세(%)" FROM ye WHERE ye.DVLP_DIV_CD = ''1'' AND ye.STRD_YY = LEFT(ye.AS_OF_MT, 4) GROUP BY ROLLUP(ye.DEPT4_NM) ORDER BY 6 DESC NULLS FIRST'),
		VQR_O207_GOAL_MONTH AS ( 
QUESTION '올해 마감월까지 월별 신규 개발 목표와 실적, 달성률' 
VERIFIED_BY '(O207 · 2026-01 달성률 93.3% · 2026-09 76.5% · 마감월 누계 70.1% 원천 대조 · O207-C 마감월 한정 교정)'
SQL 'SELECT gl.STRD_MT AS "목표 기준년월", SUM(gl.GOAL_CNT) AS "개발 목표(건)", ROUND(SUM(gl.ACT_CNT), 4) AS "목표 대비 실적(건)", ROUND(DIV0(SUM(IFF(gl.GOAL_CNT > 0, gl.ACT_CNT, 0)), SUM(gl.GOAL_CNT)) * 100, 1) AS "목표 달성률(%)" FROM gl WHERE gl.DVLP_DIV_CD = ''1'' AND gl.CLOSED_MONTH_YN = ''Y'' AND gl.STRD_YY = (SELECT LEFT(MAX(STRD_MT), 4) FROM gl WHERE CLOSED_MONTH_YN = ''Y'') GROUP BY ROLLUP(gl.STRD_MT) ORDER BY 1 NULLS LAST'),
		VQR_O207_STOP_REASON AS ( 
QUESTION '최신 기준월 후원중단 사유별 개발(건)·개발(명)' 
VERIFIED_BY '(O207 · 사유 = MM005 · 후원중단 한정)'
SQL 'SELECT md.CANCL_RDCAMT_RSN_NM AS "중단사유", ROUND(SUM(md.SPNSR_AMT_CNT), 4) AS "개발(건)", COUNT(DISTINCT md.MBER_NO) AS "개발(명)" FROM md WHERE md.DVLP_DIV_CD = ''5'' AND md.STRD_MT = (SELECT MAX(STRD_MT) FROM md) GROUP BY md.CANCL_RDCAMT_RSN_NM ORDER BY 2')
	);