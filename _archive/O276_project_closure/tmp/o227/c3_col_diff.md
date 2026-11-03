# O227 C3 컬럼 전후 대조

### DIM_BUDGET_ITEM.BDGT_UNIT_NM 
- 전: 예산단위명(ERP 원천 BDGT_UNIT_NM 그대로 · 조직명 표기 · 코드 없음). 세세목에 1:1 종속(2026-10-02 O198 실측 179/179). 🔴 DIM_ORG(CRM 조직)와 다른 체계다 — 같은 이름의 팀이라도 ORG_SK 로 조인하지 말 것. 실측 값 6종(ERP 표기 그대로)
- 후: 예산단위명(ERP 원천 BDGT_UNIT_NM 그대로 · 조직명 표기 · 코드 없음). 세세목에 1:1 종속(2026-10-02 실측 179/179). 🔴 DIM_ORG(CRM 조직)와 다른 체계다 — 같은 이름의 팀이라도 ORG_SK 로 조인하지 말 것. 실측 값 6종(ERP 표기 그대로)

### DIM_ORG.IS_ACTIVE_ORG 
- 전: 활성 조직 트리 소속 여부 — 자기와 모든 상위가 USE_YN=Y 이고 LAST_UPDT_DT 유효 · 행은 지우지 않는다(O16)
- 후: 활성 조직 트리 소속 여부 — 자기와 모든 상위가 USE_YN=Y 이고 LAST_UPDT_DT 유효 · 행은 지우지 않는다

### DIM_SEND_TYPE.SEND_TYPE_L 
- 전: 발송구분(대) (#133) 분석 라벨 ← SEND_GBN_TOP_NM. 🔴정본 #133 과 불일치(2026-08-04 실측): #133 은 6종(결연/회비/서비스/사업보고/참여/기타)인데 실측 라벨 **9종** — 추가 3종 = 회원만족(MS052)·회원서비스(MS054)·회원(MS047+MS053). #133 은 생략기호가 없어 완전열거로 읽힌다 → 불일치 실재. 문서20 §L 현업 확인 · 데이터 우선 보존(DEC-26). ⚠️대분류는 코드그룹과 1:1 이 아니다 — 결연=MS046+MS051 · 기타=MS0505+MS055 · 회원=MS047+MS053 (코드그룹 12종 → 라벨 9종). 🟢SEND_GBN_TOP 12종 전부 CRM_CODE.CD_ID 실재 확인
- 후: 발송구분(대) (#133) 분석 라벨 ← SEND_GBN_TOP_NM. 🔴정본 #133 과 불일치(2026-08-04 실측): #133 은 6종(결연/회비/서비스/사업보고/참여/기타)인데 실측 라벨 **9종** — 추가 3종 = 회원만족(MS052)·회원서비스(MS054)·회원(MS047+MS053). #133 은 생략기호가 없어 완전열거로 읽힌다 → 불일치 실재. 현업 확인 대상 · 데이터 우선 보존. ⚠️대분류는 코드그룹과 1:1 이 아니다 — 결연=MS046+MS051 · 기타=MS0505+MS055 · 회원=MS047+MS053 (코드그룹 12종 → 라벨 9종). 🟢SEND_GBN_TOP 12종 전부 CRM_CODE.CD_ID 실재 확인

### DIM_SPONSORSHIP.CPR_DIV_CD 
- 전: [O202] 후원사업 법인구분 코드(CM019: A 통합 · I 사단 · S 사복) — MSTR 법인 축. 코드id:CM019. [SILVER.CRM_SPONSORSHIP 승계]
- 후: 후원사업 법인구분 코드(CM019: A 통합 · I 사단 · S 사복) — MSTR 법인 축. 코드id:CM019. [SILVER.CRM_SPONSORSHIP 승계]

### DIM_SPONSORSHIP.CPR_DIV_NM 
- 전: [O202] 후원사업 법인구분명(통합/사단/사복). 코드id:CM019. 🔴 세부캠페인 법인(FACT_MEMBER_EVENT.CPR_DIV_*_AT_EVENT)과 다른 축.
- 후: 후원사업 법인구분명(통합/사단/사복). 코드id:CM019. 🔴 세부캠페인 법인(FACT_MEMBER_EVENT.CPR_DIV_*_AT_EVENT)과 다른 축.

### FACT_AD_BROADCAST.CPC_CALL_SRC 
- 전: [비가산 N] 대행사 산정 **콜당** 단가 ← VIDEO.CPC(TEXT) [VIDEO 전용]. 🔴 클릭 분모가 아니다 — 디지털 CPC_CLICK_SRC 와 합산 금지 (O174 개명)
- 후: [비가산 N] 대행사 산정 **콜당** 단가 ← VIDEO.CPC(TEXT) [VIDEO 전용]. 🔴 클릭 분모가 아니다 — 디지털 CPC_CLICK_SRC 와 합산 금지

### FACT_AD_BROADCAST.DURATION_SEC 
- 전: 🔴 광고 초수 ← VIDEO.AD_SEC(TEXT→TRY_TO_NUMBER) [VIDEO 전용] — **현재 값 신뢰 금지(O29)**. 적재값이 초로 읽을 수 없는 크기라 「초」로 해석하면 오답이다(µs 해석 유력하나 미확정·현업 확인 대기 · 실측값은 문서10 §26). 원천 HH:MM:SS 표기가 캐스팅에서 무성 소실 → 유효 커버리지와 파싱 시 회복률은 문서10 §26. REBRDC NULL 은 결손 아니라 원천 부재
- 후: 🔴 광고 초수 ← VIDEO.AD_SEC(TEXT→TRY_TO_NUMBER) [VIDEO 전용] — **현재 값 신뢰 금지**. 적재값이 초로 읽을 수 없는 크기라 「초」로 해석하면 오답이다(µs 해석 유력하나 미확정·현업 확인 대기). 원천 HH:MM:SS 표기가 캐스팅에서 무성 소실 → 유효 커버리지가 낮다(파싱하면 대부분 회복). REBRDC NULL 은 결손 아니라 원천 부재

### FACT_AD_BROADCAST.DVLP_CNT 
- 전: 개발건수 ← REBRDC.DVLP_CNT [VIDEO·REBRDC · O185 정정: O182 원천 재편 후 VIDEO 도 일부 행 보고 · 출처별 집계]. ⚠️O16 이관: 종전 코어 AGENCY_CONV_CNT 로 혼입(대행사 전환 아님)
- 후: 개발건수 ← REBRDC.DVLP_CNT [VIDEO·REBRDC · 정정: 원천 재편 후 VIDEO 도 일부 행 보고 · 출처별 집계]. ⚠️종전 코어 AGENCY_CONV_CNT 로 혼입(대행사 전환 아님)

### FACT_AD_BROADCAST.DVLP_MEMBER_CNT 
- 전: 개발회원수 ← REBRDC.DVLP_MBER_CNT [VIDEO·REBRDC · O185 정정: O182 원천 재편 후 VIDEO 도 일부 행 보고 · 출처별 집계]. ⚠️O16 이관: 종전 코어 AGENCY_CONV_MEMBERS 로 혼입(대행사 전환이 아니라 재방송 개발실적). ⚠️소수 척도 유지 이유: 원천에 0.5 단위 값이 실존해 NUMBER(38,0) 은 반올림으로 총합을 왜곡한다(해당 행·왜곡 규모는 문서10 §26). 원천값 보존 우선
- 후: 개발회원수 ← REBRDC.DVLP_MBER_CNT [VIDEO·REBRDC · 정정: 원천 재편 후 VIDEO 도 일부 행 보고 · 출처별 집계]. ⚠️종전 코어 AGENCY_CONV_MEMBERS 로 혼입(대행사 전환이 아니라 재방송 개발실적). ⚠️소수 척도 유지 이유: 원천에 0.5 단위 값이 실존해 NUMBER(38,0) 은 반올림으로 총합을 왜곡한다. 원천값 보존 우선

### FACT_AD_DIGITAL.CPC_CLICK_SRC 
- 전: [비가산 N] 대행사 산정 **클릭당** 단가 ← DGT.CPC. DW 재계산=AD_COST/CLICKS. 🔴 방송 CPC_CALL_SRC 와 합산 금지 (O174 개명)
- 후: [비가산 N] 대행사 산정 **클릭당** 단가 ← DGT.CPC. DW 재계산=AD_COST/CLICKS. 🔴 방송 CPC_CALL_SRC 와 합산 금지

### FACT_BUDGET.AD_COST 
- 전: 광고비(원) 🔴🔴 폐기 슬롯이다 — 의도적 영구 NULL(외부 입고 대기가 아니다 · 2026-09-21 O175 판정). 예산 원장에는 광고비 예산항목이 없고, 대행사 원천의 광고비는 이미 GOLD.FACT_AD_PERFORMANCE.AD_COST 로 일 grain 배선돼 있다. 🔴 광고비를 이 컬럼으로 묻지 말 것 — 정본은 SERVING.SV_AD.TOTAL_AD_COST(base GOLD.WIDE_AD_COMBINED)다. 🔴 예산과 같은 표에 합산하지 말 것(원천·grain 이 다르고 광고 팩트와 이중계상이 된다 · 순서9-K 표 분리 근거). ⚠️ 종전 문안의 「원천 자체가 비어 있다 · 대행사가 항목을 보고하지 않는다」는 거짓이었다(경위·규모는 이슈원장 §O175).
- 후: 광고비(원) 🔴🔴 폐기 슬롯이다 — 의도적 영구 NULL(외부 입고 대기가 아니다 · 2026-09-21 판정). 예산 원장에는 광고비 예산항목이 없고, 대행사 원천의 광고비는 이미 GOLD.FACT_AD_PERFORMANCE.AD_COST 로 일 grain 배선돼 있다. 🔴 광고비를 이 컬럼으로 묻지 말 것 — 정본은 SERVING.SV_AD.TOTAL_AD_COST(base GOLD.WIDE_AD_COMBINED)다. 🔴 예산과 같은 표에 합산하지 말 것(원천·grain 이 다르고 광고 팩트와 이중계상이 된다 · 순서9-K 표 분리 근거).

### FACT_BUDGET.DVLP_INBOUND_PATH 
- 전: 개발 유입경로(ERP 원천 DVLP_INBOUND_PATH 그대로 · 퇴화 차원 · 2026-10-02 O198 DEC-60). 실측 값 7종(디지털·방송·재송출·영상광고·뉴미디어·모금시스템·콜개발). 🔴 NULL = ERP 원장행에 유입경로가 기재되지 않은 예산(개발 비용이 아닌 과목이 대부분 · 집행액 0) — 창작 라벨로 채우지 않는다(R2-7). 🔴 grain 키의 일부다 — 같은 월·세세목에 경로가 2~3종 있다
- 후: 개발 유입경로(ERP 원천 DVLP_INBOUND_PATH 그대로 · 퇴화 차원 · 2026-10-02). 실측 값 7종(디지털·방송·재송출·영상광고·뉴미디어·모금시스템·콜개발). 🔴 NULL = ERP 원장행에 유입경로가 기재되지 않은 예산(개발 비용이 아닌 과목이 대부분 · 집행액 0) — 창작 라벨로 채우지 않는다. 🔴 grain 키의 일부다 — 같은 월·세세목에 경로가 2~3종 있다

### FACT_BUDGET.EXEC_BUDGET_EST 
- 전: 집행예산(추정 · 원) 🔴🔴 [O51-F 실측] 전건 NULL — 원천 자체가 비어 있다(ERP 집행 추정 원천). 결측이 아니라 대행사가 항목을 보고하지 않는다: 0 이나 「해당없음」 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 🔴 외부 원천 미입고(E-1 소관 · ⚠️ 종전 문안의 E-4 병기는 O175 가 철회했다 — 광고비는 원천 부재가 아니다). 실측 규모는 이슈원장 §O51-F.
- 후: 집행예산(추정 · 원) 🔴🔴 전건 NULL — 원천 자체가 비어 있다(ERP 집행 추정 원천). 결측이 아니라 대행사가 항목을 보고하지 않는다: 0 이나 「해당없음」 으로 대체 해석하지 말 것. 필터 조건으로 쓰면 전건이 탈락한다. 🔴 외부 원천 미입고.

### FACT_BUDGET.EXEC_DIRECT_MNYRS_1 
- 전: 직접모금비1(원천 DIRECT_MNYRS_YN_1=Y) 원장행의 집행액(원) — 🔴 화면·답변에는 「직접모금비1」 이름 그대로 표시하고 직접모금비2 와 나란히 보여준다(현업 회신 42 · DEC-57). 하나를 「모금성비용」으로 부르지 않는다. 부분집합이며 EXEC_BUDGET_ERP 이하
- 후: 직접모금비1(원천 DIRECT_MNYRS_YN_1=Y) 원장행의 집행액(원) — 🔴 화면·답변에는 「직접모금비1」 이름 그대로 표시하고 직접모금비2 와 나란히 보여준다(현업 회신 42). 하나를 「모금성비용」으로 부르지 않는다. 부분집합이며 EXEC_BUDGET_ERP 이하

### FACT_BUDGET.FUNDRAISING_COST 
- 전: 모금성비용(원) 🔴 의도적 NULL — 현업 회신 42(DEC-57): 모금성비용은 하나로 정하지 않고 원장 플래그 이름 그대로 직접모금비1(EXEC_DIRECT_MNYRS_1)·직접모금비2(EXEC_DIRECT_MNYRS_2)를 나란히 쓴다. 🔴 이 컬럼으로 묻지 말 것 — 두 컬럼을 쓴다. ⚠️ 종전 문안의 「원천 자체가 비어 있다 · 대행사가 항목을 보고하지 않는다」는 거짓이었다(원천 플래그 실재 · O175).
- 후: 모금성비용(원) 🔴 의도적 NULL — 현업 회신 42: 모금성비용은 하나로 정하지 않고 원장 플래그 이름 그대로 직접모금비1(EXEC_DIRECT_MNYRS_1)·직접모금비2(EXEC_DIRECT_MNYRS_2)를 나란히 쓴다. 🔴 이 컬럼으로 묻지 말 것 — 두 컬럼을 쓴다.

### FACT_BUDGET.PLAN_BUDGET_MONTH 
- 전: 편성예산(월 · 원). 🔴🔴 [2026-08-29 O114-B] 12개월 합산해도 FACT_BUDGET_YEARLY.PLAN_BUDGET_YEAR 와 일치하지 않는다 — 원천 원장의 월 배분이 부분적이어서 연 총액의 상당 부분이 월 컬럼에 배분되지 않는다(원천 특성 · 모델 결함 아님 · 실측 규모는 이슈원장·이력 소관 R2-6). ⇒ 🔴 「편성예산」을 답할 때 월·연 중 어느 축인지 밝혀라 — 밝히지 않으면 두 답이 갈린다. 🟢 대비: 집행은 연=월 정합이다(EXEC_BUDGET_ERP 월합 = FACT_BUDGET_YEARLY.EXEC_BUDGET_YEAR). 🔴 예산 편성 차수(「연사업」 / 「추가경정」)를 GROUP BY 에 넣지 않으면 본예산과 추경이 합산된다 — 다만 이 테이블은 BUDGET_PROCEDURE 컬럼을 보유하므로 차수별 분해가 가능하다(2026-09-22 O176 실측 · 규모는 이슈원장 소관 R2-6). ⚠️ WIDE_BUDGET 은 이 컬럼을 노출하지 않으므로 거기서는 분해가 불가능하다 — 「차수별 분해 불가」는 뷰 축의 사실이며 이 테이블에는 적용되지 않는다.
- 후: 편성예산(월 · 원). 🔴🔴 12개월 합산해도 FACT_BUDGET_YEARLY.PLAN_BUDGET_YEAR 와 일치하지 않는다 — 원천 원장의 월 배분이 부분적이어서 연 총액의 상당 부분이 월 컬럼에 배분되지 않는다(원천 특성 · 모델 결함 아님 ·. ⇒ 🔴 「편성예산」을 답할 때 월·연 중 어느 축인지 밝혀라 — 밝히지 않으면 두 답이 갈린다. 🟢 대비: 집행은 연=월 정합이다(EXEC_BUDGET_ERP 월합 = FACT_BUDGET_YEARLY.EXEC_BUDGET_YEAR). 🔴 예산 편성 차수(「연사업」 / 「추가경정」)를 GROUP BY 에 넣지 않으면 본예산과 추경이 합산된다 — 다만 이 테이블은 BUDGET_PROCEDURE 컬럼을 보유하므로 차수별 분해가 가능하다(2026-09-22 실측 ·. ⚠️ WIDE_BUDGET 은 이 컬럼을 노출하지 않으므로 거기서는 분해가 불가능하다 — 「차수별 분해 불가」는 뷰 축의 사실이며 이 테이블에는 적용되지 않는다.

### FACT_MEMBER_COHORT.ACQ_MKTG_CMPGN_NM 
- 전: 획득 캠페인의 마케팅 캠페인명(Q16 라벨).
- 후: 획득 캠페인의 마케팅 캠페인명(라벨).

### FACT_MEMBER_EVENT.DEV_CNT 
- 전: 개발(건) (#149) = [O202 사용자 결정] MSTR 정의: 사건의 MSTR 인정금액 ÷ 10,000(신규·재후원 = 미중단 후원사업·월합>0 · 증액 = 감액 상계 순증액). 원본 FN_MM_SPNSR_DVLP B1·B2.
- 후: 개발(건) (#149) = MSTR 정의: 사건의 MSTR 인정금액 ÷ 10,000(신규·재후원 = 미중단 후원사업·월합>0 · 증액 = 감액 상계 순증액). 원본 FN_MM_SPNSR_DVLP B1·B2.

### FACT_MEMBER_EVENT.DEV_MEMBERS 
- 전: 「명」이 아니다 (#148) — [O202] MSTR 개발 인정 행이면 1 · 기간 개발(명) = COUNT DISTINCT 회원.
- 후: 「명」이 아니다 (#148) — MSTR 개발 인정 행이면 1 · 기간 개발(명) = COUNT DISTINCT 회원.

### FACT_MEMBER_EVENT.MKTG_CMPGN_NM_AT_EVENT 
- 전: 마케팅 캠페인명(Q16 라벨).
- 후: 마케팅 캠페인명(라벨).

### FACT_MEMBER_MONTHLY.DEV_CNT 
- 전: 개발(건) (#4) = [O202] MSTR 개발(건)(인정금액 ÷ 10,000) 월 합.
- 후: 개발(건) (#4) = MSTR 개발(건)(인정금액 ÷ 10,000) 월 합.

### FACT_MEMBER_MONTHLY.DEV_MEMBERS 
- 전: 개발(명) (#148) = [O202] 그 달 MSTR 개발 인정 행 보유 1/0.
- 후: 개발(명) (#148) = 그 달 MSTR 개발 인정 행 보유 1/0.

### FACT_MEMBER_MONTHLY.STOP_AMT_CNT 
- 전: [O202] 중단(건) (#35) = 그 달 중단 후원사업 약정금액 ÷ 10,000. 공54~57 분자(DEV_CNT 와 같은 단위). STOP_CNT(사건 수)와 다르다.
- 후: 중단(건) (#35) = 그 달 중단 후원사업 약정금액 ÷ 10,000. 공54~57 분자(DEV_CNT 와 같은 단위). STOP_CNT(사건 수)와 다르다.

### FACT_MEMBER_SPONSORSHIP_SPAN.ACQ_MKTG_CMPGN_NM 
- 전: 대표캠페인의 마케팅 캠페인명(Q16 라벨) — 동결값
- 후: 대표캠페인의 마케팅 캠페인명(라벨) — 동결값

### FACT_MEMBER_SPONSORSHIP_SPAN.SPNSR_BSNS_NO 
- 전: 후원사업번호(회원별 약정 일련번호, Q15).
- 후: 후원사업번호(회원별 약정 일련번호).

### FACT_MEMBER_SPONSORSHIP_SPAN.SPNSR_NO 
- 전: 후원번호(Q15).
- 후: 후원번호.

### FACT_MESSAGE_DISPATCH.SEND_REQUEST_SK 
- 전: 발송 요청 (FK→DIM_SEND_REQUEST) · 0=요청 미매칭 [O196-D DEC-58]
- 후: 발송 요청 (FK→DIM_SEND_REQUEST) · 0=요청 미매칭

### FACT_PAYMENT_BILLING_STATUS.UNPAID_BILLED_AMT 
- 전: 미납 청구액(원) = 결제상태 F 또는 NULL 인 청구액(DEC-3) · FACT_MEMBER_FEE 와 같은 식.
- 후: 미납 청구액(원) = 결제상태 F 또는 NULL 인 청구액 · FACT_MEMBER_FEE 와 같은 식.

### FACT_TARGET_PROJECT.GOAL_TYPE_NM 
- 전: 목표 지표 유형 원천 표기 그대로(O190 · 9종): 건 = 후원사업·회원개발 / 명 = 월말활동회원 / 원 = 정기회비 / 비율 = 후원사업활동율·신규기존활동율·후원사업납입율·신규기존납입율·신규기존누계납입율. 🔴 유형마다 단위가 달라 섞어 합산하지 말 것 · 후원사업과 회원개발은 같은 개발 목표의 다른 분해(문서20 N-24)
- 후: 목표 지표 유형 원천 표기 그대로(9종): 건 = 후원사업·회원개발 / 명 = 월말활동회원 / 원 = 정기회비 / 비율 = 후원사업활동율·신규기존활동율·후원사업납입율·신규기존납입율·신규기존누계납입율. 🔴 유형마다 단위가 달라 섞어 합산하지 말 것 · 후원사업과 회원개발은 같은 개발 목표의 다른 분해

### WIDE_AD_BROADCAST.AD_CREATIVE 
- 전: DIM_AD_CREATIVE.CREATIVE — 소재 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F.
- 후: DIM_AD_CREATIVE.CREATIVE — 소재 🔴🔴 **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다.

### WIDE_AD_BROADCAST.AD_END_TIME 
- 전: 광고종료시간 (VIDEO 전용) 🔴[O51-F 실측] 채움이 **VIDEO 안에서 부분**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. ⚠️시작시간은 더 많이 채워져 있어 **시작·종료를 함께 요구하면 표본이 줄어든다**. 실측 규모는 이슈원장 §O51-F.
- 후: 광고종료시간 (VIDEO 전용) 🔴 채움이 **VIDEO 안에서 부분**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. ⚠️시작시간은 더 많이 채워져 있어 **시작·종료를 함께 요구하면 표본이 줄어든다**.

### WIDE_AD_BROADCAST.AD_MEDIA_NAME 
- 전: DIM_AD_CREATIVE.MEDIA_NAME — 매체명 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F.
- 후: DIM_AD_CREATIVE.MEDIA_NAME — 매체명 🔴🔴 **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다.

### WIDE_AD_BROADCAST.BRDC_DIV 
- 전: 방송구분 (REBRDC 전용) 🔴[O51-F 실측] 채움이 **REBROADCAST 안에서도 일부**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F.
- 후: 방송구분 (REBRDC 전용) 🔴 채움이 **REBROADCAST 안에서도 일부**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다.

### WIDE_AD_BROADCAST.CAMPAIGN_NAME 
- 전: [O216-G Q10 영구 센티넬] 광고 원천·예산 원장에 개발캠페인 코드가 없다(현업 회신 Q10 「코드 없음」) — 배선되지 않으며 이 컬럼으로 GROUP BY·필터하지 않는다(광고는 마케팅캠페인·UTM 캠페인·매체 축으로 분해한다). DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 🟢대안 = 마케팅캠페인 축(`MKTG_CAMPAIGN_SK`)은 살아 있다(O45) — 광고↔개발 결합은 그 grain 에서 한다. 실측 규모는 이슈원장 §O51-F.
- 후: [영구 센티넬] 광고 원천·예산 원장에 개발캠페인 코드가 없다(현업 회신 「코드 없음」) — 배선되지 않으며 이 컬럼으로 GROUP BY·필터하지 않는다(광고는 마케팅캠페인·UTM 캠페인·매체 축으로 분해한다). DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 🔴🔴 **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 🟢대안 = 마케팅캠페인 축(`MKTG_CAMPAIGN_SK`)은 살아 있다 — 광고↔개발 결합은 그 grain 에서 한다.

### WIDE_AD_BROADCAST.CONV_CALL_CNT 
- 전: 전환콜 (VIDEO 전용) — 인입콜과 별개 🔴🔴[O51-F 실측] **전건 NULL — 원천 자체가 비어 있다**(`BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.CONV_CALL_CNT`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 🔴🔴종전 문서가 *「VIDEO 는 개발실적 대신 전환콜을 보고한다」* 고 적었으나 **그 컬럼도 원천에서 전건 비어 있다** — 즉 VIDEO 구간은 개발도 전환콜도 측정할 수 없다(AD-5 보강). REBROADCAST 원천에는 컬럼 자체가 없다. 실측 규모는 이슈원장 §O51-F.
- 후: 전환콜 (VIDEO 전용) — 인입콜과 별개 🔴🔴 **전건 NULL — 원천 자체가 비어 있다**(`BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.CONV_CALL_CNT`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것. 필터 조건으로 쓰면 전건이 탈락한다. 🔴🔴종전 문서가 *「VIDEO 는 개발실적 대신 전환콜을 보고한다」* 고 적었으나 **그 컬럼도 원천에서 전건 비어 있다** — 즉 VIDEO 구간은 개발도 전환콜도 측정할 수 없다(보강). REBROADCAST 원천에는 컬럼 자체가 없다.

### WIDE_AD_BROADCAST.CPC_CALL_SRC 
- 전: 방송 **콜당** 단가(대행사 산정) — 비가산 N, 재합산 금지. 🔴 클릭 분모가 아니다(O174 개명 · 디지털 CPC_CLICK_SRC 와 합산 금지). ⚠️**VIDEO 전용** — 다른 원천 행은 개념 자체가 없어 NULL 이며 결측이 아니다.
- 후: 방송 **콜당** 단가(대행사 산정) — 비가산 N, 재합산 금지. 🔴 클릭 분모가 아니다(개명 · 디지털 CPC_CLICK_SRC 와 합산 금지). ⚠️**VIDEO 전용** — 다른 원천 행은 개념 자체가 없어 NULL 이며 결측이 아니다.

### WIDE_AD_BROADCAST.CTV_DIV 
- 전: CTV구분 (VIDEO 전용) 🔴[O51-F 실측] 채움이 **VIDEO 안에서도 소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F.
- 후: CTV구분 (VIDEO 전용) 🔴 채움이 **VIDEO 안에서도 소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다.

### WIDE_AD_BROADCAST.DVLP_CNT 
- 전: 개발건수 (방송 · VIDEO·REBRDC) — ⚠️GA 전환이 아님(O16 분리). 🔴 [O184 정정] 종전 「REBROADCAST 전용」은 O182 원천 재편으로 거짓이 됐다 — VIDEO 도 일부 행에 보고한다. 디지털행은 원천 부재로 NULL. 출처(AD_SOURCE_TYPE)별로 나눠 집계할 것.
- 후: 개발건수 (방송 · VIDEO·REBRDC) — ⚠️GA 전환이 아님. 🔴 종전 「REBROADCAST 전용」은 원천 재편으로 거짓이 됐다 — VIDEO 도 일부 행에 보고한다. 디지털행은 원천 부재로 NULL. 출처(AD_SOURCE_TYPE)별로 나눠 집계할 것.

### WIDE_AD_BROADCAST.DVLP_MEMBER_CNT 
- 전: 개발회원수 (방송 · VIDEO·REBRDC) — ⚠️GA 전환이 아님(O16 분리). 🔴 [O184 정정] 종전 「REBROADCAST 전용」은 O182 원천 재편으로 거짓이 됐다 — VIDEO 도 일부 행에 보고한다. 디지털행은 원천 부재로 NULL. 출처(AD_SOURCE_TYPE)별로 나눠 집계할 것.
- 후: 개발회원수 (방송 · VIDEO·REBRDC) — ⚠️GA 전환이 아님. 🔴 종전 「REBROADCAST 전용」은 원천 재편으로 거짓이 됐다 — VIDEO 도 일부 행에 보고한다. 디지털행은 원천 부재로 NULL. 출처(AD_SOURCE_TYPE)별로 나눠 집계할 것.

### WIDE_AD_BROADCAST.INBOUND_CALL 
- 전: [코어] 인입콜수 🔴[O51-F 실측] 채움이 **VIDEO 안에서 부분**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🔴채널·시간대별 인입콜 비교 시 미보고 행이 0 이 아니라 NULL 이므로 평균이 왜곡될 수 있다. 실측 규모는 이슈원장 §O51-F.
- 후: [코어] 인입콜수 🔴 채움이 **VIDEO 안에서 부분**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🔴채널·시간대별 인입콜 비교 시 미보고 행이 0 이 아니라 NULL 이므로 평균이 왜곡될 수 있다.

### WIDE_AD_BROADCAST.PERF_IS_HOLIDAY (덮어쓰기)
- 전: DIM_DATE.IS_HOLIDAY — 실적일 휴일여부 🔴🔴[O51-F 실측] **휴일축이 미주입이다 — 전건 `FALSE`.** `DIM_DATE.IS_HOLIDAY` 에 TRUE 가 하나도 없다. NULL 이 아니라 FALSE 라서 **집계가 성공한 것처럼 보이고**, 「휴일 대비 평일 성과」 질의가 **전건 평일**로 응답된다. ⇒ 이 컬럼으로 휴일 분석을 하지 말 것(기지 **HOL-1** — 공휴일 원천이 전 스키마에 없어 외부 입고 대기). 실측 규모는 이슈원장 §O51-F.
- 후: DIM_DATE.IS_HOLIDAY — 실적일 휴일여부. ⚠️공휴일 원천이 반영돼 TRUE 행이 있다 — 휴일·평일 비교 시 기간마다 휴일 수가 다르므로 일평균으로 비교할 것.

### WIDE_AD_BROADCAST.SPOT_TYPE 
- 전: SPOT유형 (VIDEO 전용) 🔴[O51-F 실측] 채움이 **VIDEO 안에서 부분**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F.
- 후: SPOT유형 (VIDEO 전용) 🔴 채움이 **VIDEO 안에서 부분**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다.

### WIDE_AD_BROADCAST_CASE.AD_SOURCE_TYPE 
- 전: 광고 원천유형 — 본 뷰는 REBROADCAST 만 🔴[O51-F 실측] **단일값 REBROADCAST 뿐이다** — 본 뷰는 재방송 사례 전용이라 VIDEO 사례가 없다. GROUP BY 대상이 아니며, **이 뷰로 VIDEO 대비 재방송을 비교하면 재방송만 보고 결론을 낸다.** 원천유형 비교는 코어 `WIDE_AD_PERFORMANCE` 에서 한다. 실측 규모는 이슈원장 §O51-F.
- 후: 광고 원천유형 — 본 뷰는 REBROADCAST 만 🔴 **단일값 REBROADCAST 뿐이다** — 본 뷰는 재방송 사례 전용이라 VIDEO 사례가 없다. GROUP BY 대상이 아니며, **이 뷰로 VIDEO 대비 재방송을 비교하면 재방송만 보고 결론을 낸다.** 원천유형 비교는 코어 `WIDE_AD_PERFORMANCE` 에서 한다.

### WIDE_AD_BROADCAST_CASE.CAMPAIGN_NAME 
- 전: [O216-G Q10 영구 센티넬] 광고 원천·예산 원장에 개발캠페인 코드가 없다(현업 회신 Q10 「코드 없음」) — 배선되지 않으며 이 컬럼으로 GROUP BY·필터하지 않는다(광고는 마케팅캠페인·UTM 캠페인·매체 축으로 분해한다). DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 실측 규모는 이슈원장 §O51-F.
- 후: [영구 센티넬] 광고 원천·예산 원장에 개발캠페인 코드가 없다(현업 회신 「코드 없음」) — 배선되지 않으며 이 컬럼으로 GROUP BY·필터하지 않는다(광고는 마케팅캠페인·UTM 캠페인·매체 축으로 분해한다). DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 🔴🔴 **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다.

### WIDE_AD_COMBINED.AD_END_TIME 
- 전: 광고종료시간 ← VIDEO.AD_END_TIME [VIDEO 전용]. 신규 노출 🔴🔴[WIDE_AD_COMBINED] **VIDEO(본방송) 전용이다** — 재방송(REBRDC) 원천에는 이 컬럼이 **아예 없다**(BRONZE `REBRDC_AD_CMPGN_DTLS` 에 시각 컬럼 부재 · 보유 항목은 방송시간·방송월뿐). 따라서 재방송행의 NULL 은 적재 지연이 아니라 **해당 없음**이다(P20 3분류). 시각 기반 분석은 VIDEO 로 스코프하고, 재방송을 포함한 시간대 분석은 TIME_BAND 를 쓸 것. 전용축 판정 근거 = 이슈원장 §429.
- 후: 광고종료시간 ← VIDEO.AD_END_TIME [VIDEO 전용]. 신규 노출 🔴🔴[WIDE_AD_COMBINED] **VIDEO(본방송) 전용이다** — 재방송(REBRDC) 원천에는 이 컬럼이 **아예 없다**(BRONZE `REBRDC_AD_CMPGN_DTLS` 에 시각 컬럼 부재 · 보유 항목은 방송시간·방송월뿐). 따라서 재방송행의 NULL 은 적재 지연이 아니라 **해당 없음**이다(3분류). 시각 기반 분석은 VIDEO 로 스코프하고, 재방송을 포함한 시간대 분석은 TIME_BAND 를 쓸 것.

### WIDE_AD_COMBINED.AD_PERF_DK 
- 전: 행 식별자(GRAIN·PK) MD5(AD_SOURCE_TYPE|ROW_HASH|DUP_SEQ). 위성 3종 조인키. 발급지점=SILVER.AGENCY_AD_ROW_* (DEC-11)
- 후: 행 식별자(GRAIN·PK) MD5(AD_SOURCE_TYPE|ROW_HASH|DUP_SEQ). 위성 3종 조인키. 발급지점=SILVER.AGENCY_AD_ROW_*

### WIDE_AD_COMBINED.AD_SOURCE_TYPE 
- 전: 광고유형 DIGITAL/VIDEO/REBROADCAST (degen). 출처 명시축(DEC-8·§3-A-4) — DW_SOURCE_SYSTEM(시스템 출처)과 2단 추적. DEVICE_TYPE=(해당없음) 행의 방송 여부 판별 수단
- 후: 광고유형 DIGITAL/VIDEO/REBROADCAST (degen). 출처 명시축(§3-A-4) — DW_SOURCE_SYSTEM(시스템 출처)과 2단 추적. DEVICE_TYPE=(해당없음) 행의 방송 여부 판별 수단

### WIDE_AD_COMBINED.AD_START_TIME 
- 전: 광고시작시간 ← VIDEO.AD_STRT_TIME [VIDEO 전용]. 코어에서 이관 🔴🔴[WIDE_AD_COMBINED] **VIDEO(본방송) 전용이다** — 재방송(REBRDC) 원천에는 이 컬럼이 **아예 없다**(BRONZE `REBRDC_AD_CMPGN_DTLS` 에 시각 컬럼 부재 · 보유 항목은 방송시간·방송월뿐). 따라서 재방송행의 NULL 은 적재 지연이 아니라 **해당 없음**이다(P20 3분류). 시각 기반 분석은 VIDEO 로 스코프하고, 재방송을 포함한 시간대 분석은 TIME_BAND 를 쓸 것. 전용축 판정 근거 = 이슈원장 §429.
- 후: 광고시작시간 ← VIDEO.AD_STRT_TIME [VIDEO 전용]. 코어에서 이관 🔴🔴[WIDE_AD_COMBINED] **VIDEO(본방송) 전용이다** — 재방송(REBRDC) 원천에는 이 컬럼이 **아예 없다**(BRONZE `REBRDC_AD_CMPGN_DTLS` 에 시각 컬럼 부재 · 보유 항목은 방송시간·방송월뿐). 따라서 재방송행의 NULL 은 적재 지연이 아니라 **해당 없음**이다(3분류). 시각 기반 분석은 VIDEO 로 스코프하고, 재방송을 포함한 시간대 분석은 TIME_BAND 를 쓸 것.

### WIDE_AD_COMBINED.AGENCY_CONV_CNT 
- 전: 대행사 전환수(건/VU) — **DIGITAL 전용**. ⚠️O16 교정(2026-07-28): 종전에 REBRDC 개발건수가 혼입돼 있었고 그 비중이 과반이었다 → FACT_AD_BROADCAST.DVLP_CNT 로 이관. 혼입 규모 = 이슈원장 §O16. ⚠️합계가 소수로 나오므로 건수가 아니다 — 어의 현업확인 잔여(O5).
- 후: 대행사 전환수(건/VU) — **DIGITAL 전용**. ⚠️종전에 REBRDC 개발건수가 혼입돼 있었고 그 비중이 과반이었다 → FACT_AD_BROADCAST.DVLP_CNT 로 이관. ⚠️합계가 소수로 나오므로 건수가 아니다 — 어의 현업확인 잔여.

### WIDE_AD_COMBINED.AGENCY_CONV_MEMBERS 
- 전: 대행사 전환수(명) — **DIGITAL 전용**. ⚠️O16 교정(2026-07-28): 종전에 REBRDC 개발회원수가 혼입돼 있었다 — 재방송 개발실적은 FACT_AD_BROADCAST.DVLP_MEMBER_CNT 로 이관했다. 혼입 규모 = 이슈원장 §O16.
- 후: 대행사 전환수(명) — **DIGITAL 전용**. ⚠️종전에 REBRDC 개발회원수가 혼입돼 있었다 — 재방송 개발실적은 FACT_AD_BROADCAST.DVLP_MEMBER_CNT 로 이관했다.

### WIDE_AD_COMBINED.CAMPAIGN_SK 
- 전: 캠페인 (분석축, FK→DIM_CAMPAIGN). ⚠️현재 0 스캐폴드 — Q10 이름매칭 대기
- 후: 캠페인 (분석축, FK→DIM_CAMPAIGN). ⚠️현재 0 스캐폴드 — 이름매칭 대기

### WIDE_AD_COMBINED.CONV_CALL_CNT 
- 전: 전환콜 ← VIDEO.CONV_CALL_CNT [VIDEO 전용]. 코어 INBOUND_CALL(인입콜)과 별개 measure ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. 🆕🔴🔴[2026-09-01 O129 보강] **VIDEO 행도 전건 NULL 이다** — 원천 `BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.CONV_CALL_CNT` 는 컬럼은 실재하고 **값이 전건 공백**(대행사 미보고)이다(REBROADCAST 원천에는 컬럼 자체가 없다). ⇒ 🔴 스코프를 VIDEO 로 좁혀도 값은 나오지 않는다 — **어떤 스코프에서도 집계 불가**다. ⚠️ 인입콜(`REBRDC.INBOUND_CALL_CNT`)은 채워져 있으니 **두 축을 혼동하지 말 것**. 정본 = 문서30 §7-C.
- 후: 전환콜 ← VIDEO.CONV_CALL_CNT [VIDEO 전용]. 코어 INBOUND_CALL(인입콜)과 별개 measure ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. 🔴🔴 **VIDEO 행도 전건 NULL 이다** — 원천 `BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.CONV_CALL_CNT` 는 컬럼은 실재하고 **값이 전건 공백**(대행사 미보고)이다(REBROADCAST 원천에는 컬럼 자체가 없다). ⇒ 🔴 스코프를 VIDEO 로 좁혀도 값은 나오지 않는다 — **어떤 스코프에서도 집계 불가**다. ⚠️ 인입콜(`REBRDC.INBOUND_CALL_CNT`)은 채워져 있으니 **두 축을 혼동하지 말 것**.

### WIDE_AD_COMBINED.CPC_CALL_SRC 
- 전: [비가산 N] 대행사 산정 **콜당** 단가 ← VIDEO.CPC(TEXT) [VIDEO 전용] — 🔴 [O174] 종전 이름 BRDC_CPC_SRC 는 접두로만 구분해 **같은 지표의 다른 출처**로 읽혔다(실제로는 분모가 클릭 ↔ 콜로 다르다). DW 재계산=AD_COST/CLICKS (DEC-9 대조용) ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. ⚠️[WIDE_AD_COMBINED] 디지털 위성에 동명 컬럼이 있어 **BRDC_ 접두**를 붙였다 — 이 컬럼은 방송 원천값이다. 디지털 쪽 동명 컬럼과 같은 표에서 비교하지 말 것.
- 후: [비가산 N] 대행사 산정 **콜당** 단가 ← VIDEO.CPC(TEXT) [VIDEO 전용] — 🔴 종전 이름 BRDC_CPC_SRC 는 접두로만 구분해 **같은 지표의 다른 출처**로 읽혔다(실제로는 분모가 클릭 ↔ 콜로 다르다). DW 재계산=AD_COST/CLICKS (대조용) ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. ⚠️[WIDE_AD_COMBINED] 디지털 위성에 동명 컬럼이 있어 **BRDC_ 접두**를 붙였다 — 이 컬럼은 방송 원천값이다. 디지털 쪽 동명 컬럼과 같은 표에서 비교하지 말 것.

### WIDE_AD_COMBINED.CPC_CLICK_SRC 
- 전: [비가산 N] 대행사 산정 **클릭당** 단가 ← DGT.CPC(O174 개명 · 방송 CPC_CALL_SRC 와 분모가 다르다 ⇒ 합산 금지). DW 재계산=AD_COST/CLICKS ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.
- 후: [비가산 N] 대행사 산정 **클릭당** 단가 ← DGT.CPC(개명 · 방송 CPC_CALL_SRC 와 분모가 다르다 ⇒ 합산 금지). DW 재계산=AD_COST/CLICKS ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.

### WIDE_AD_COMBINED.DEVICE_SK 
- 전: 디바이스 (분석축, FK→DIM_DEVICE). DEC-10 실배선: 실기기 해시SK / 방송=(해당없음) / 미매핑=0
- 후: 디바이스 (분석축, FK→DIM_DEVICE). 실배선: 실기기 해시SK / 방송=(해당없음) / 미매핑=0

### WIDE_AD_COMBINED.DURATION_SEC 
- 전: 🔴 광고 초수 ← VIDEO.AD_SEC(TEXT→TRY_TO_NUMBER) [VIDEO 전용] — **현재 값 신뢰 금지(O29)**. 적재값의 스케일이 「초」로 읽으면 맞지 않는다(µs 해석 유력하나 미확정·현업 확인 대기). 원천 HH:MM:SS 형식 행이 캐스팅에서 무성 소실돼 유효 커버리지가 매우 낮다(파싱하면 대부분 회복) — 규모 실측은 이슈원장 §O29. REBRDC NULL 은 결손이 아니라 원천 부재. ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.
- 후: 🔴 광고 초수 ← VIDEO.AD_SEC(TEXT→TRY_TO_NUMBER) [VIDEO 전용] — **현재 값 신뢰 금지**. 적재값의 스케일이 「초」로 읽으면 맞지 않는다(µs 해석 유력하나 미확정·현업 확인 대기). 원천 HH:MM:SS 형식 행이 캐스팅에서 무성 소실돼 유효 커버리지가 매우 낮다(파싱하면 대부분 회복) — REBRDC NULL 은 결손이 아니라 원천 부재. ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.

### WIDE_AD_COMBINED.DVLP_CNT 
- 전: 개발건수 ← REBRDC.DVLP_CNT [VIDEO·REBRDC · O184 정정: VIDEO 도 O182 원천 재편 후 일부 행 보고 · 출처별 집계]. ⚠️O16 이관: 종전 코어 AGENCY_CONV_CNT 로 혼입(대행사 전환 아님) ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.
- 후: 개발건수 ← REBRDC.DVLP_CNT [VIDEO·REBRDC · 정정: VIDEO 도 원천 재편 후 일부 행 보고 · 출처별 집계]. ⚠️종전 코어 AGENCY_CONV_CNT 로 혼입(대행사 전환 아님) ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.

### WIDE_AD_COMBINED.DVLP_MEMBER_CNT 
- 전: 개발회원수 ← REBRDC.DVLP_MBER_CNT [VIDEO·REBRDC · O184 정정: VIDEO 도 O182 원천 재편 후 일부 행 보고 · 출처별 집계]. ⚠️O16 이관: 종전에 코어 AGENCY_CONV_MEMBERS 로 혼입돼 있었다(대행사 전환이 아니라 재방송 개발실적). ⚠️소수 척도를 유지하는 이유 = 원천에 0.5 단위 값이 실존해 정수 타입으로 내리면 반올림이 총합을 왜곡한다 — 해당 행·왜곡 규모는 이슈원장 §O16. 원천값 보존 우선. ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.
- 후: 개발회원수 ← REBRDC.DVLP_MBER_CNT [VIDEO·REBRDC · 정정: VIDEO 도 원천 재편 후 일부 행 보고 · 출처별 집계]. ⚠️종전에 코어 AGENCY_CONV_MEMBERS 로 혼입돼 있었다(대행사 전환이 아니라 재방송 개발실적). ⚠️소수 척도를 유지하는 이유 = 원천에 0.5 단위 값이 실존해 정수 타입으로 내리면 반올림이 총합을 왜곡한다 — 해당 행·왜곡 원천값 보존 우선. ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.

### WIDE_AD_COMBINED.MEDIA_POTENTIAL_CUST_CNT 
- 전: 매체 잠재고객수 ← DGT.MEDIA_PTNT_CUST_CNT (가산) ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. 🆕🔴🔴[2026-09-01 O129 보강] **디지털행도 전건 NULL 이다** — 원천 `BRONZE_AGENCY.DGT_AD_CMPGN_DTLS.MEDIA_PTNT_CUST_CNT` 는 컬럼은 실재하고 **값이 전건 공백**(대행사 미보고)이다. ⇒ 🔴 스코프를 디지털로 좁혀도 값은 나오지 않는다 — 이 컬럼은 현재 **어떤 스코프에서도 집계 불가**다(0/'해당없음' 대체 해석 금지 · P21). 정본 = 문서30 §7-C.
- 후: 매체 잠재고객수 ← DGT.MEDIA_PTNT_CUST_CNT (가산) ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. 🔴🔴 **디지털행도 전건 NULL 이다** — 원천 `BRONZE_AGENCY.DGT_AD_CMPGN_DTLS.MEDIA_PTNT_CUST_CNT` 는 컬럼은 실재하고 **값이 전건 공백**(대행사 미보고)이다. ⇒ 🔴 스코프를 디지털로 좁혀도 값은 나오지 않는다 — 이 컬럼은 현재 **어떤 스코프에서도 집계 불가**다(0/'해당없음' 대체 해석 금지).

### WIDE_AD_COMBINED.MKTG_CAMPAIGN_SK 
- 전: [O45] 마케팅캠페인 대리키 (FK→DIM_MARKETING_CAMPAIGN). 광고↔CRM 결합축. 🔴미도달 행은 0(미매핑) 버킷이며 이 버킷을 「미집행」으로 읽지 말 것 — 도달률 실측은 이슈원장 §O45. 🔴개발캠페인(CAMPAIGN_SK) grain 결합 금지 — 광고비가 대규모로 팬아웃한다(배수 실측 = 이슈원장 §O45).
- 후: 마케팅캠페인 대리키 (FK→DIM_MARKETING_CAMPAIGN). 광고↔CRM 결합축. 🔴미도달 행은 0(미매핑) 버킷이며 이 버킷을 「미집행」으로 읽지 말 것. 🔴개발캠페인(CAMPAIGN_SK) grain 결합 금지 — 광고비가 대규모로 팬아웃한다.

### WIDE_AD_COMBINED.PRG_START_TIME 
- 전: 프로그램 시작시간 ← VIDEO.PRG_STRT_TIME [VIDEO 전용] 🔴🔴[WIDE_AD_COMBINED] **VIDEO(본방송) 전용이다** — 재방송(REBRDC) 원천에는 이 컬럼이 **아예 없다**(BRONZE `REBRDC_AD_CMPGN_DTLS` 에 시각 컬럼 부재 · 보유 항목은 방송시간·방송월뿐). 따라서 재방송행의 NULL 은 적재 지연이 아니라 **해당 없음**이다(P20 3분류). 시각 기반 분석은 VIDEO 로 스코프하고, 재방송을 포함한 시간대 분석은 TIME_BAND 를 쓸 것. 전용축 판정 근거 = 이슈원장 §429.
- 후: 프로그램 시작시간 ← VIDEO.PRG_STRT_TIME [VIDEO 전용] 🔴🔴[WIDE_AD_COMBINED] **VIDEO(본방송) 전용이다** — 재방송(REBRDC) 원천에는 이 컬럼이 **아예 없다**(BRONZE `REBRDC_AD_CMPGN_DTLS` 에 시각 컬럼 부재 · 보유 항목은 방송시간·방송월뿐). 따라서 재방송행의 NULL 은 적재 지연이 아니라 **해당 없음**이다(3분류). 시각 기반 분석은 VIDEO 로 스코프하고, 재방송을 포함한 시간대 분석은 TIME_BAND 를 쓸 것.

### WIDE_AD_COMBINED.RT_TYPE 
- 전: RT(재방송)유형 ← REBRDC.DIV_NM(재송출/방송 · O182 재편 전 RE_BRDC_TY_NM) [REBRDC 전용]. 코어에서 이관 ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.
- 후: RT(재방송)유형 ← REBRDC.DIV_NM(재송출/방송 · 재편 전 RE_BRDC_TY_NM) [REBRDC 전용]. 코어에서 이관 ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.

### WIDE_AD_DIGITAL.AD_CREATIVE 
- 전: DIM_AD_CREATIVE.CREATIVE — 소재 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F.
- 후: DIM_AD_CREATIVE.CREATIVE — 소재 🔴🔴 **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다.

### WIDE_AD_DIGITAL.AD_GROUP_NM 
- 전: 광고그룹명 🔴[O51-F 실측] 채움이 **극히 일부**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F.
- 후: 광고그룹명 🔴 채움이 **극히 일부**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다.

### WIDE_AD_DIGITAL.AD_MEDIA_NAME 
- 전: DIM_AD_CREATIVE.MEDIA_NAME — 매체명 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F.
- 후: DIM_AD_CREATIVE.MEDIA_NAME — 매체명 🔴🔴 **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다.

### WIDE_AD_DIGITAL.AD_TYPE_NM 
- 전: 광고유형명(대행사 표기). [O51-F BRONZE 실측] 실적재 값 = **하단DA·DA·CPT·BSA·SA·CPM**. 🔴`AD_SOURCE_TYPE`(VIDEO/REBROADCAST/DIGITAL)과 **다른 개념**이다 — 이름이 비슷해 혼용되기 쉽다.
- 후: 광고유형명(대행사 표기). 실적재 값 = **하단DA·DA·CPT·BSA·SA·CPM**. 🔴`AD_SOURCE_TYPE`(VIDEO/REBROADCAST/DIGITAL)과 **다른 개념**이다 — 이름이 비슷해 혼용되기 쉽다.

### WIDE_AD_DIGITAL.AGENCY_CONV_CNT 
- 전: [코어] 대행사 전환수(건/VU) — CPA 분모(O16 교정 후 디지털 전용) 🔴[O51-F 실측] 채움이 **부분**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🔴비율 metric 의 분모로 쓸 때는 분자 커버리지를 먼저 맞출 것 — 분모만 부분이면 조용히 과대계상된다(P18). 실측 규모는 이슈원장 §O51-F.
- 후: [코어] 대행사 전환수(건/VU) — CPA 분모(교정 후 디지털 전용) 🔴 채움이 **부분**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🔴비율 metric 의 분모로 쓸 때는 분자 커버리지를 먼저 맞출 것 — 분모만 부분이면 조용히 과대계상된다.

### WIDE_AD_DIGITAL.AGENCY_CONV_MEMBERS 
- 전: [코어] 대행사 전환수(명) — CVR 분자(O16 교정 후 디지털 전용)
- 후: [코어] 대행사 전환수(명) — CVR 분자(교정 후 디지털 전용)

### WIDE_AD_DIGITAL.CAMPAIGN_NAME 
- 전: DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 🟢대안 = 마케팅캠페인 축(`MKTG_CAMPAIGN_SK`)은 살아 있다(O45) — 광고↔개발 결합은 그 grain 에서 한다. 실측 규모는 이슈원장 §O51-F.
- 후: DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 🔴🔴 **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 🟢대안 = 마케팅캠페인 축(`MKTG_CAMPAIGN_SK`)은 살아 있다 — 광고↔개발 결합은 그 grain 에서 한다.

### WIDE_AD_DIGITAL.CPA_SRC 
- 전: CPA(대행사 산정) — 비가산 N. DW 재계산=SUM(AD_COST)/SUM(AGENCY_CONV_CNT) 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것. 실측 규모는 이슈원장 §O51-F.
- 후: CPA(대행사 산정) — 비가산 N. DW 재계산=SUM(AD_COST)/SUM(AGENCY_CONV_CNT) 🔴 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것.

### WIDE_AD_DIGITAL.CPC_CLICK_SRC 
- 전: 디지털 **클릭당** 단가(대행사 산정 · O174 개명) — 비가산 N. DW 재계산=SUM(AD_COST)/SUM(CLICKS) 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것. 실측 규모는 이슈원장 §O51-F.
- 후: 디지털 **클릭당** 단가(대행사 산정 · 개명) — 비가산 N. DW 재계산=SUM(AD_COST)/SUM(CLICKS) 🔴 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것.

### WIDE_AD_DIGITAL.CPM_SRC 
- 전: CPM(대행사 산정) — 비가산 N. DW 재계산=SUM(AD_COST)/SUM(IMPRESSIONS)*1000 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것. 실측 규모는 이슈원장 §O51-F.
- 후: CPM(대행사 산정) — 비가산 N. DW 재계산=SUM(AD_COST)/SUM(IMPRESSIONS)*1000 🔴 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것.

### WIDE_AD_DIGITAL.CREATIVE_TYPE 
- 전: 소재유형(원천 표기) 🔴[O51-F 실측] 채움이 **부분**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F.
- 후: 소재유형(원천 표기) 🔴 채움이 **부분**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다.

### WIDE_AD_DIGITAL.CTR_SRC 
- 전: CTR(대행사 산정) — 비가산 N. DW 재계산=SUM(CLICKS)/SUM(IMPRESSIONS) 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것. 실측 규모는 이슈원장 §O51-F.
- 후: CTR(대행사 산정) — 비가산 N. DW 재계산=SUM(CLICKS)/SUM(IMPRESSIONS) 🔴 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것.

### WIDE_AD_DIGITAL.CVR_SRC 
- 전: CVR(대행사 산정) — 비가산 N. DW 재계산=SUM(AGENCY_CONV_MEMBERS)/SUM(CLICKS) 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것. 실측 규모는 이슈원장 §O51-F.
- 후: CVR(대행사 산정) — 비가산 N. DW 재계산=SUM(AGENCY_CONV_MEMBERS)/SUM(CLICKS) 🔴 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 🟢DW 재계산은 전건 가능하다 — 집계에는 base 를 쓸 것.

### WIDE_AD_DIGITAL.DEV_UNIT_PRICE_SRC 
- 전: 개발단가(대행사 산정) — 비가산 N 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. ⚠️원천 포맷 변경으로 개발건수와 **상호배타**다(AD-3) — 개발단가는 두 컬럼이 기간을 보완하는 관계이며 교차검증 관계가 아니다. 실측 규모는 이슈원장 §O51-F.
- 후: 개발단가(대행사 산정) — 비가산 N 🔴 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. ⚠️원천 포맷 변경으로 개발건수와 **상호배타**다 — 개발단가는 두 컬럼이 기간을 보완하는 관계이며 교차검증 관계가 아니다.

### WIDE_AD_DIGITAL.GROUP_DIV 
- 전: 그룹구분 🔴[O51-F 실측] 채움이 **극히 일부**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F.
- 후: 그룹구분 🔴 채움이 **극히 일부**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다.

### WIDE_AD_DIGITAL.MEDIA_POTENTIAL_CUST_CNT 
- 전: 매체 잠재고객수 🔴🔴[O51-F 실측] **전건 NULL — 원천 자체가 비어 있다**(`BRONZE_AGENCY.DGT_AD_CMPGN_DTLS.MEDIA_PTNT_CUST_CNT`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-F.
- 후: 매체 잠재고객수 🔴🔴 **전건 NULL — 원천 자체가 비어 있다**(`BRONZE_AGENCY.DGT_AD_CMPGN_DTLS.MEDIA_PTNT_CUST_CNT`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것. 필터 조건으로 쓰면 전건이 탈락한다.

### WIDE_AD_DIGITAL.PAGE_TYPE 
- 전: 페이지유형 🔴[O51-F 실측] 채움이 **극히 일부**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F.
- 후: 페이지유형 🔴 채움이 **극히 일부**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다.

### WIDE_AD_DIGITAL.PERF_IS_HOLIDAY (덮어쓰기)
- 전: DIM_DATE.IS_HOLIDAY — 실적일 휴일여부 🔴🔴[O51-F 실측] **휴일축이 미주입이다 — 전건 `FALSE`.** `DIM_DATE.IS_HOLIDAY` 에 TRUE 가 하나도 없다. NULL 이 아니라 FALSE 라서 **집계가 성공한 것처럼 보이고**, 「휴일 대비 평일 성과」 질의가 **전건 평일**로 응답된다. ⇒ 이 컬럼으로 휴일 분석을 하지 말 것(기지 **HOL-1** — 공휴일 원천이 전 스키마에 없어 외부 입고 대기). 실측 규모는 이슈원장 §O51-F.
- 후: DIM_DATE.IS_HOLIDAY — 실적일 휴일여부. ⚠️공휴일 원천이 반영돼 TRUE 행이 있다 — 휴일·평일 비교 시 기간마다 휴일 수가 다르므로 일평균으로 비교할 것.

### WIDE_AD_DIGITAL.READ_CNT 
- 전: 읽음수 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. 실측 규모는 이슈원장 §O51-F.
- 후: 읽음수 🔴 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다.

### WIDE_AD_DIGITAL.VTR_SRC 
- 전: VTR(대행사 산정) — 비가산 N, base 부재로 재계산 불가 🔴[O51-F 실측] 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. base 가 원천에 없어 DW 재계산도 불가하다. 실측 규모는 이슈원장 §O51-F.
- 후: VTR(대행사 산정) — 비가산 N, base 부재로 재계산 불가 🔴 채움이 **소수**다. 커버리지를 모르고 비중·순위를 내면 결론이 뒤집힌다. base 가 원천에 없어 DW 재계산도 불가하다.

### WIDE_AD_PERFORMANCE.AD_CREATIVE 
- 전: DIM_AD_CREATIVE.CREATIVE — 소재 (#20) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F.
- 후: DIM_AD_CREATIVE.CREATIVE — 소재 (#20) 🔴🔴 **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다.

### WIDE_AD_PERFORMANCE.AD_CREATIVE_BK 
- 전: DIM_AD_CREATIVE.AD_CREATIVE_BK — 광고소재 업무키 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F.
- 후: DIM_AD_CREATIVE.AD_CREATIVE_BK — 광고소재 업무키 🔴🔴 **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다.

### WIDE_AD_PERFORMANCE.AD_CREATIVE_TYPE 
- 전: DIM_AD_CREATIVE.AD_TYPE — 소재 광고유형 (⚠️AD_SOURCE_TYPE 과 다른 개념) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F.
- 후: DIM_AD_CREATIVE.AD_TYPE — 소재 광고유형 (⚠️AD_SOURCE_TYPE 과 다른 개념) 🔴🔴 **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다.

### WIDE_AD_PERFORMANCE.AD_MEDIA_NAME 
- 전: DIM_AD_CREATIVE.MEDIA_NAME — 매체명 (#11) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다(기지 **P52·O38-C**, 연결키는 **Q10** 소관). 실측 규모는 이슈원장 §O51-F.
- 후: DIM_AD_CREATIVE.MEDIA_NAME — 매체명 (#11) 🔴🔴 **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴🔴 원천에는 있는 축이다 — SILVER `AGENCY_AD_PERFORMANCE.MEDIA_CHANNEL_NM`·`CREATIVE_NM` 과 BRONZE 매체명은 **전건 채워져 있다.** GOLD 에서만 소실됐다 — 팩트 FK 가 0 하드코딩이다.

### WIDE_AD_PERFORMANCE.AD_PLATFORM 
- 전: DIM_AD_CREATIVE.PLATFORM — 플랫폼 (#12) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F.
- 후: DIM_AD_CREATIVE.PLATFORM — 플랫폼 (#12) 🔴🔴 **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다.

### WIDE_AD_PERFORMANCE.AD_PLATFORM_TYPE 
- 전: DIM_AD_CREATIVE.PLATFORM_TYPE — 플랫폼/매체유형 (#13) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL**. 🆕🔴🔴[2026-09-01 O129 정정] 종전 문안의 *「원인은 차원이 아니라 팩트 FK 가 전건 센티넬이다 · 차원 자체는 채워져 있다」* 는 **이 컬럼에 대해 거짓이었다**(O51-F 오버레이가 여러 컬럼에 같은 문안을 도포한 결과 · O96 이 재검증 대상으로 지목한 그 건이다). 원인이 **두 개**다: ① 팩트 FK 가 전건 센티넬(`FACT_AD_PERFORMANCE.AD_CREATIVE_SK`) ② **차원 컬럼 자체가 전건 NULL**(`GOLD.DIM_AD_CREATIVE.PLATFORM_TYPE`). ⇒ 🔴 **FK 를 고쳐도 이 축은 채워지지 않는다.** 사유 = BRONZE AGENCY 3테이블에 「매체유형」 축이 없다(인접 유형축은 전부 다른 목적지에 배선돼 대체물이 아니다) ⇒ 요건 #13 은 현업 확인 대상. 정본 = 문서30 §7-C-1.
- 후: DIM_AD_CREATIVE.PLATFORM_TYPE — 플랫폼/매체유형 (#13) 🔴🔴 **이 뷰에서 전건 NULL**. 원인이 **두 개**다: ① 팩트 FK 가 전건 센티넬(`FACT_AD_PERFORMANCE.AD_CREATIVE_SK`) ② **차원 컬럼 자체가 전건 NULL**(`GOLD.DIM_AD_CREATIVE.PLATFORM_TYPE`). ⇒ 🔴 **FK 를 고쳐도 이 축은 채워지지 않는다.** 사유 = BRONZE AGENCY 3테이블에 「매체유형」 축이 없다(인접 유형축은 전부 다른 목적지에 배선돼 대체물이 아니다) ⇒ 요건 #13 은 현업 확인 대상.

### WIDE_AD_PERFORMANCE.AD_SOURCE_TYPE 
- 전: 광고 원천유형 DIGITAL/VIDEO/REBROADCAST — 출처 명시축(팩트 degen, DEC-8)
- 후: 광고 원천유형 DIGITAL/VIDEO/REBROADCAST — 출처 명시축(팩트 degen)

### WIDE_AD_PERFORMANCE.AD_TARGET_GROUP 
- 전: DIM_AD_CREATIVE.TARGET_GROUP — 타겟그룹 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL**. 🆕🔴🔴[2026-09-01 O129 정정] 종전 문안의 *「차원 자체는 채워져 있다」* 는 **이 컬럼에 대해 거짓이었다**(O51-F 도포본 · O96 이 재검증 대상으로 지목한 그 건이다). 원인이 **두 개**다: ① 팩트 FK 가 전건 센티넬(`FACT_AD_PERFORMANCE.AD_CREATIVE_SK`) ② **차원 컬럼 자체가 전건 NULL**(`GOLD.DIM_AD_CREATIVE.TARGET_GROUP`). ⇒ 🔴 **FK 를 고쳐도 이 축은 채워지지 않는다.** 사유 = 원천 트랙이 **GA4** 다(잠재고객=타겟그룹은 원천표기 GA → `GA4_USER` 정제 예정 · phase-2 미착수) ⇒ **대행사 축으로는 영구히 NULL** 이다. 정본 = 문서30 §7-C-1.
- 후: DIM_AD_CREATIVE.TARGET_GROUP — 타겟그룹 🔴🔴 **이 뷰에서 전건 NULL**. 원인이 **두 개**다: ① 팩트 FK 가 전건 센티넬(`FACT_AD_PERFORMANCE.AD_CREATIVE_SK`) ② **차원 컬럼 자체가 전건 NULL**(`GOLD.DIM_AD_CREATIVE.TARGET_GROUP`). ⇒ 🔴 **FK 를 고쳐도 이 축은 채워지지 않는다.** 사유 = 원천 트랙이 **GA4** 다(잠재고객=타겟그룹은 원천표기 GA → `GA4_USER` 정제 예정 · phase-2 미착수) ⇒ **대행사 축으로는 영구히 NULL** 이다.

### WIDE_AD_PERFORMANCE.AGENCY_CONV_CNT 
- 전: 대행사 전환수(건/VU) — 디지털 전용(O16 교정: 재방송 개발실적 제외)
- 후: 대행사 전환수(건/VU) — 디지털 전용(교정: 재방송 개발실적 제외)

### WIDE_AD_PERFORMANCE.AGENCY_CONV_MEMBERS 
- 전: 대행사 전환수(명) — 디지털 전용(O16 교정: 재방송 개발실적 제외)
- 후: 대행사 전환수(명) — 디지털 전용(교정: 재방송 개발실적 제외)

### WIDE_AD_PERFORMANCE.CAMPAIGN_BK 
- 전: [O216-G Q10 영구 센티넬] 광고 원천·예산 원장에 개발캠페인 코드가 없다(현업 회신 Q10 「코드 없음」) — 배선되지 않으며 이 컬럼으로 GROUP BY·필터하지 않는다(광고는 마케팅캠페인·UTM 캠페인·매체 축으로 분해한다). DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 실측 규모는 이슈원장 §O51-F.
- 후: [영구 센티넬] 광고 원천·예산 원장에 개발캠페인 코드가 없다(현업 회신 「코드 없음」) — 배선되지 않으며 이 컬럼으로 GROUP BY·필터하지 않는다(광고는 마케팅캠페인·UTM 캠페인·매체 축으로 분해한다). DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴 **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다.

### WIDE_AD_PERFORMANCE.CAMPAIGN_BRAND 
- 전: [O216-G Q10 영구 센티넬] 광고 원천·예산 원장에 개발캠페인 코드가 없다(현업 회신 Q10 「코드 없음」) — 배선되지 않으며 이 컬럼으로 GROUP BY·필터하지 않는다(광고는 마케팅캠페인·UTM 캠페인·매체 축으로 분해한다). DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F.
- 후: [영구 센티넬] 광고 원천·예산 원장에 개발캠페인 코드가 없다(현업 회신 「코드 없음」) — 배선되지 않으며 이 컬럼으로 GROUP BY·필터하지 않는다(광고는 마케팅캠페인·UTM 캠페인·매체 축으로 분해한다). DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴 **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다.

### WIDE_AD_PERFORMANCE.CAMPAIGN_NAME 
- 전: [O216-G Q10 영구 센티넬] 광고 원천·예산 원장에 개발캠페인 코드가 없다(현업 회신 Q10 「코드 없음」) — 배선되지 않으며 이 컬럼으로 GROUP BY·필터하지 않는다(광고는 마케팅캠페인·UTM 캠페인·매체 축으로 분해한다). DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 실측 규모는 이슈원장 §O51-F.
- 후: [영구 센티넬] 광고 원천·예산 원장에 개발캠페인 코드가 없다(현업 회신 「코드 없음」) — 배선되지 않으며 이 컬럼으로 GROUP BY·필터하지 않는다(광고는 마케팅캠페인·UTM 캠페인·매체 축으로 분해한다). DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴 **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다.

### WIDE_AD_PERFORMANCE.CAMPAIGN_PARENT 
- 전: DIM_CAMPAIGN.PARENT_CAMPAIGN — 공통상위캠페인 (#119) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F.
- 후: DIM_CAMPAIGN.PARENT_CAMPAIGN — 공통상위캠페인 (#119) 🔴🔴 **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다.

### WIDE_AD_PERFORMANCE.CAMPAIGN_PROMO_METHOD 
- 전: DIM_CAMPAIGN.PROMO_METHOD — 홍보방법 (#118) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F.
- 후: DIM_CAMPAIGN.PROMO_METHOD — 홍보방법 (#118) 🔴🔴 **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다.

### WIDE_AD_PERFORMANCE.CAMPAIGN_TYPE 
- 전: DIM_CAMPAIGN.CAMPAIGN_TYPE — 캠페인 유형 (#17) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F.
- 후: DIM_CAMPAIGN.CAMPAIGN_TYPE — 캠페인 유형 (#17) 🔴🔴 **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_AD_PERFORMANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다.

### WIDE_AD_PERFORMANCE.DEVICE_SCOPE_DESC 
- 전: DIM_DEVICE.DEVICE_SCOPE_DESC — 기기축 적용범위 자기설명(DEC-10)
- 후: DIM_DEVICE.DEVICE_SCOPE_DESC — 기기축 적용범위 자기설명

### WIDE_AD_PERFORMANCE.PERF_IS_HOLIDAY (덮어쓰기)
- 전: DIM_DATE.IS_HOLIDAY — 실적일 휴일여부 🔴🔴[O51-F 실측] **휴일축이 미주입이다 — 전건 `FALSE`.** `DIM_DATE.IS_HOLIDAY` 에 TRUE 가 하나도 없다. NULL 이 아니라 FALSE 라서 **집계가 성공한 것처럼 보이고**, 「휴일 대비 평일 성과」 질의가 **전건 평일**로 응답된다. ⇒ 이 컬럼으로 휴일 분석을 하지 말 것(기지 **HOL-1** — 공휴일 원천이 전 스키마에 없어 외부 입고 대기). 실측 규모는 이슈원장 §O51-F.
- 후: DIM_DATE.IS_HOLIDAY — 실적일 휴일여부. ⚠️공휴일 원천이 반영돼 TRUE 행이 있다 — 휴일·평일 비교 시 기간마다 휴일 수가 다르므로 일평균으로 비교할 것.

### WIDE_BIGQUERY_BEHAVIOR.AVG_SESSION_DURATION 
- 전: [비가산] 평균세션시간 — 재합산 금지 (#98) 🔴🔴[O51-F 실측] **전건 NULL — 원천 자체가 비어 있다**(`BRONZE_BIGQUERY 세션 지표`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. BigQuery 원천 적재 범위 자체가 좁다(G-5 하드블로커). 실측 규모는 이슈원장 §O51-F.
- 후: [비가산] 평균세션시간 — 재합산 금지 (#98) 🔴🔴 **전건 NULL — 원천 자체가 비어 있다**(`BRONZE_BIGQUERY 세션 지표`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것. 필터 조건으로 쓰면 전건이 탈락한다.

### WIDE_BIGQUERY_BEHAVIOR.BOUNCE_RATE 
- 전: [비가산] 이탈율 — 재합산 금지 (#108) 🔴🔴[O51-F 실측] **전건 NULL — 원천 자체가 비어 있다**(`BRONZE_BIGQUERY 세션 지표`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. BigQuery 원천 적재 범위 자체가 좁다(G-5 하드블로커). 실측 규모는 이슈원장 §O51-F.
- 후: [비가산] 이탈율 — 재합산 금지 (#108) 🔴🔴 **전건 NULL — 원천 자체가 비어 있다**(`BRONZE_BIGQUERY 세션 지표`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것. 필터 조건으로 쓰면 전건이 탈락한다.

### WIDE_BIGQUERY_BEHAVIOR.CAMPAIGN_BK 
- 전: [O216-E A4-W 영구 센티넬] GA4 이벤트에는 CRM 캠페인 키가 없고 UTM ↔ 캠페인이 1:N(최대 902)이라 배선하지 않는다 — 이 컬럼으로 GROUP BY·필터하지 않는다(GA4 캠페인 분해는 UTM_CAMPAIGN 을 쓴다). DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_BIGQUERY_BEHAVIOR.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 실측 규모는 이슈원장 §O51-F.
- 후: [영구 센티넬] GA4 이벤트에는 CRM 캠페인 키가 없고 UTM ↔ 캠페인이 1:N(최대 902)이라 배선하지 않는다 — 이 컬럼으로 GROUP BY·필터하지 않는다(GA4 캠페인 분해는 UTM_CAMPAIGN 을 쓴다). DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴 **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_BIGQUERY_BEHAVIOR.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다.

### WIDE_BIGQUERY_BEHAVIOR.CAMPAIGN_BRAND 
- 전: [O216-E A4-W 영구 센티넬] GA4 이벤트에는 CRM 캠페인 키가 없고 UTM ↔ 캠페인이 1:N(최대 902)이라 배선하지 않는다 — 이 컬럼으로 GROUP BY·필터하지 않는다(GA4 캠페인 분해는 UTM_CAMPAIGN 을 쓴다). DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_BIGQUERY_BEHAVIOR.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F.
- 후: [영구 센티넬] GA4 이벤트에는 CRM 캠페인 키가 없고 UTM ↔ 캠페인이 1:N(최대 902)이라 배선하지 않는다 — 이 컬럼으로 GROUP BY·필터하지 않는다(GA4 캠페인 분해는 UTM_CAMPAIGN 을 쓴다). DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴 **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_BIGQUERY_BEHAVIOR.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다.

### WIDE_BIGQUERY_BEHAVIOR.CAMPAIGN_NAME 
- 전: [O216-E A4-W 영구 센티넬] GA4 이벤트에는 CRM 캠페인 키가 없고 UTM ↔ 캠페인이 1:N(최대 902)이라 배선하지 않는다 — 이 컬럼으로 GROUP BY·필터하지 않는다(GA4 캠페인 분해는 UTM_CAMPAIGN 을 쓴다). DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_BIGQUERY_BEHAVIOR.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 실측 규모는 이슈원장 §O51-F.
- 후: [영구 센티넬] GA4 이벤트에는 CRM 캠페인 키가 없고 UTM ↔ 캠페인이 1:N(최대 902)이라 배선하지 않는다 — 이 컬럼으로 GROUP BY·필터하지 않는다(GA4 캠페인 분해는 UTM_CAMPAIGN 을 쓴다). DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴 **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_BIGQUERY_BEHAVIOR.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다.

### WIDE_BIGQUERY_BEHAVIOR.IDENTITY_MEMNUM (덮어쓰기)
- 전: DIM_MEMBER_IDENTITY.MEMNUM — memnum (#111) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_BIGQUERY_BEHAVIOR.IDENTITY_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴익명 세션이 다수라 회원번호가 붙지 않는다 — 회원 귀속 분석은 `IDENTITY_SK` 를 `DIM_MEMBER_IDENTITY` 브리지로 풀어야 하며 unknown 비중을 분모에서 제외할지 먼저 정할 것(O49). 실측 규모는 이슈원장 §O51-F.
- 후: DIM_MEMBER_IDENTITY.MEMNUM — memnum (#111). 🔴🔴 **이 뷰에서 전건 NULL** 이다 — 회원 귀속은 `IDENTITY_SK` 를 `DIM_MEMBER_IDENTITY` 브리지로 풀어야 하며 unknown 비중을 분모에서 제외할지 먼저 정할 것.

### WIDE_BIGQUERY_BEHAVIOR.IS_HOLIDAY (덮어쓰기)
- 전: DIM_DATE.IS_HOLIDAY — 휴일여부 🔴🔴[O51-F 실측] **휴일축이 미주입이다 — 전건 `FALSE`.** `DIM_DATE.IS_HOLIDAY` 에 TRUE 가 하나도 없다. NULL 이 아니라 FALSE 라서 **집계가 성공한 것처럼 보이고**, 「휴일 대비 평일 성과」 질의가 **전건 평일**로 응답된다. ⇒ 이 컬럼으로 휴일 분석을 하지 말 것(기지 **HOL-1** — 공휴일 원천이 전 스키마에 없어 외부 입고 대기). 실측 규모는 이슈원장 §O51-F.
- 후: DIM_DATE.IS_HOLIDAY — 휴일여부. ⚠️공휴일 원천이 반영돼 TRUE 행이 있다 — 휴일·평일 비교 시 기간마다 휴일 수가 다르므로 일평균으로 비교할 것.

### WIDE_BIGQUERY_BEHAVIOR.UTM_CAMPAIGN 
- 전: FACT_BIGQUERY_BEHAVIOR.UTM_CAMPAIGN — GA4 캠페인 UTM 원값(utm_campaign · O190 degen). 🆕 [O216-E] 이 뷰의 GA4 캠페인 축 정본이다. (not set)·(organic)·(referral) 은 GA4 원값이다. 🔴 2025-06-26 이전은 원천(SILVER.BIGQUERY_EVENT)에도 값이 없어 NULL 이다(수집 공백 · 백필로 채워지지 않음 · O216-E 실측). 🔴 CRM 캠페인(CAMPAIGN_BK)과 1:N 이라 캠페인 마스터 축으로 환산하지 않는다.
- 후: FACT_BIGQUERY_BEHAVIOR.UTM_CAMPAIGN — GA4 캠페인 UTM 원값(utm_campaign · degen). 이 뷰의 GA4 캠페인 축 정본이다. (not set)·(organic)·(referral) 은 GA4 원값이다. 🔴 2025-06-26 이전은 원천(SILVER.BIGQUERY_EVENT)에도 값이 없어 NULL 이다(수집 공백 · 백필로 채워지지 않음 · 실측). 🔴 CRM 캠페인(CAMPAIGN_BK)과 1:N 이라 캠페인 마스터 축으로 환산하지 않는다.

### WIDE_BIGQUERY_BEHAVIOR.YEAR (덮어쓰기)
- 전: DIM_DATE.YEAR — 년 🔴🔴[O51-F 실측] **단일값이다 — BigQuery 실적재가 한 해의 일부 구간뿐이다**(G-5 하드블로커). 연도별·계절별 추이를 이 뷰로 산출하면 **구간 하나를 전체로 오독**한다. ⇒ 기간 비교는 광고·회원 팩트로 하고, BigQuery 지표는 해당 구간 내부 분석에만 쓸 것. 실측 규모는 이슈원장 §O51-F.
- 후: DIM_DATE.YEAR — 년. ⚠️BigQuery 적재 구간이 연도마다 고르지 않을 수 있다 — 연도·계절 추이는 연도별 행수를 먼저 확인한 뒤 해석할 것.

### WIDE_BUDGET.AD_COST 
- 전: 광고비(원) 🔴🔴**폐기 슬롯이다 — 의도적 영구 NULL**(외부 입고 대기가 아니다 · 2026-09-21 O175 판정). 예산 원장에는 광고비 예산항목이 없고, 대행사 원천의 광고비는 이미 `GOLD.FACT_AD_PERFORMANCE.AD_COST` 로 일 grain 배선돼 있다. 🔴**광고비를 이 컬럼으로 묻지 말 것** — 정본은 `SERVING.SV_AD.TOTAL_AD_COST`(base `GOLD.WIDE_AD_COMBINED`)다. 🔴예산과 같은 표에 합산하지 말 것(원천·grain 이 다르고 광고 팩트와 이중계상이 된다 · 순서9-K 표 분리 근거). ⚠️종전 문안의 *「원천 자체가 비어 있다 · 대행사가 항목을 보고하지 않는다」*는 **거짓이었다**(경위·규모는 이슈원장 §O175).
- 후: 광고비(원) 🔴🔴**폐기 슬롯이다 — 의도적 영구 NULL**(외부 입고 대기가 아니다 · 2026-09-21 판정). 예산 원장에는 광고비 예산항목이 없고, 대행사 원천의 광고비는 이미 `GOLD.FACT_AD_PERFORMANCE.AD_COST` 로 일 grain 배선돼 있다. 🔴**광고비를 이 컬럼으로 묻지 말 것** — 정본은 `SERVING.SV_AD.TOTAL_AD_COST`(base `GOLD.WIDE_AD_COMBINED`)다. 🔴예산과 같은 표에 합산하지 말 것(원천·grain 이 다르고 광고 팩트와 이중계상이 된다 · 순서9-K 표 분리 근거).

### WIDE_BUDGET.CAMPAIGN_BK 
- 전: [O216-D A4-X 영구 센티넬] 원천에 캠페인 연결 키가 없어 이 뷰에서는 **배선을 기다려도 값이 생기지 않는다** — 이 컬럼으로 GROUP BY·필터하지 않는다(캠페인 분해는 FACT_MEMBER_EVENT·MSTR 를 쓴다). DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_BUDGET.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 실측 규모는 이슈원장 §O51-F.
- 후: [영구 센티넬] 원천에 캠페인 연결 키가 없어 이 뷰에서는 **배선을 기다려도 값이 생기지 않는다** — 이 컬럼으로 GROUP BY·필터하지 않는다(캠페인 분해는 FACT_MEMBER_EVENT·MSTR 를 쓴다). DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴 **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_BUDGET.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다.

### WIDE_BUDGET.CAMPAIGN_BRAND 
- 전: DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_BUDGET.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F.
- 후: DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴 **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_BUDGET.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다.

### WIDE_BUDGET.CAMPAIGN_NAME 
- 전: [O216-D A4-X 영구 센티넬] 원천에 캠페인 연결 키가 없어 이 뷰에서는 **배선을 기다려도 값이 생기지 않는다** — 이 컬럼으로 GROUP BY·필터하지 않는다(캠페인 분해는 FACT_MEMBER_EVENT·MSTR 를 쓴다). DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_BUDGET.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 실측 규모는 이슈원장 §O51-F.
- 후: [영구 센티넬] 원천에 캠페인 연결 키가 없어 이 뷰에서는 **배선을 기다려도 값이 생기지 않는다** — 이 컬럼으로 GROUP BY·필터하지 않는다(캠페인 분해는 FACT_MEMBER_EVENT·MSTR 를 쓴다). DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴 **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_BUDGET.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다.

### WIDE_BUDGET.EXEC_BUDGET_EST 
- 전: 집행예산(추정, 원) 🔴🔴[O51-F 실측] **전건 NULL — 원천 자체가 비어 있다**(`ERP 집행 추정 원천`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 🔴외부 원천 미입고(E-1 소관 · ⚠️종전 문안의 `E-4` 병기는 O175 가 철회했다 — 광고비는 원천 부재가 아니다). 실측 규모는 이슈원장 §O51-F.
- 후: 집행예산(추정, 원) 🔴🔴 **전건 NULL — 원천 자체가 비어 있다**(`ERP 집행 추정 원천`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것. 필터 조건으로 쓰면 전건이 탈락한다. 🔴외부 원천 미입고.

### WIDE_BUDGET.FUNDRAISING_COST 
- 전: 모금성비용(원) 🔴🔴[O51-F 실측] **전건 NULL — 원천 자체가 비어 있다**(`ERP 모금성비용 원천`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 🔴외부 원천 미입고(**E-1** 하드블로커) — 모금성비용은 원천 확정 대기다. 실측 규모는 이슈원장 §O51-F.
- 후: 모금성비용(원) 🔴🔴 **전건 NULL — 원천 자체가 비어 있다**(`ERP 모금성비용 원천`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것. 필터 조건으로 쓰면 전건이 탈락한다. 🔴외부 원천 미입고( 하드블로커) — 모금성비용은 원천 확정 대기다.

### WIDE_BUDGET.ORG_CORP 
- 전: DIM_ORG.CORP — 법인 (#114). 🔴DIM_ORG 는 **SCD1**(DEC-2)이라 as-was 가 아니다 — 조직 개편 시 과거 사건에도 **현재 조직명**이 붙는다(조직 변경이력 원천·as-was 요구가 없어 SCD1 로 확정). 🔴🔴[O51-F 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.CORP`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4). 실측 규모는 이슈원장 §O51-F.
- 후: DIM_ORG.CORP — 법인 (#114). 🔴DIM_ORG 는 **SCD1**이라 as-was 가 아니다 — 조직 개편 시 과거 사건에도 **현재 조직명**이 붙는다(조직 변경이력 원천·as-was 요구가 없어 SCD1 로 확정). 🔴🔴 **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.CORP`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다.

### WIDE_BUDGET.ORG_DEPARTMENT 
- 전: DIM_ORG.DEPARTMENT — 부서 (#116). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴「부서」는 축이 둘이다 — 이 컬럼은 **사건 부서**이고 획득 부서는 DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT 다(O34). 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_BUDGET.ORG_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 🔴🔴예산 원장은 **부서별 분해가 현재 불가능**하다 — 「부서별 예산·집행」 요구에 총계 1행이 돌아온다. 실측 규모는 이슈원장 §O51-F.
- 후: DIM_ORG.DEPARTMENT — 부서 (#116). 🔴SCD1 — current-value 이며 as-was 가 아니다. 🔴🔴「부서」는 축이 둘이다 — 이 컬럼은 **사건 부서**이고 획득 부서는 DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT 다. 🔴🔴 **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_BUDGET.ORG_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 🔴🔴예산 원장은 **부서별 분해가 현재 불가능**하다 — 「부서별 예산·집행」 요구에 총계 1행이 돌아온다.

### WIDE_BUDGET.ORG_DIVISION 
- 전: DIM_ORG.DIVISION — 본부/지부 (#115). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴[O51-F 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.DIVISION`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4). 실측 규모는 이슈원장 §O51-F.
- 후: DIM_ORG.DIVISION — 본부/지부 (#115). 🔴SCD1 — current-value 이며 as-was 가 아니다. 🔴🔴 **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.DIVISION`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다.

### WIDE_BUDGET.ORG_TEAM 
- 전: DIM_ORG.TEAM — 팀. 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴[O51-F 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.TEAM`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4). 실측 규모는 이슈원장 §O51-F.
- 후: DIM_ORG.TEAM — 팀. 🔴SCD1 — current-value 이며 as-was 가 아니다. 🔴🔴 **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.TEAM`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다.

### WIDE_BUDGET.PLAN_BUDGET_MONTH 
- 전: 
- 후: 

### WIDE_BUDGET.SPONSORSHIP_BK 
- 전: DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_BUDGET.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F.
- 후: DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키 🔴🔴 **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_BUDGET.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다.

### WIDE_BUDGET.SPONSORSHIP_NAME 
- 전: DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_BUDGET.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F.
- 후: DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123) 🔴🔴 **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_BUDGET.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다.

### WIDE_EVENT_PARTICIPATION.CAMPAIGN_BK 
- 전: [O216-D A4-X 영구 센티넬] 원천에 캠페인 연결 키가 없어 이 뷰에서는 **배선을 기다려도 값이 생기지 않는다** — 이 컬럼으로 GROUP BY·필터하지 않는다(캠페인 분해는 FACT_MEMBER_EVENT·MSTR 를 쓴다). DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_EVENT_ATTENDANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.
- 후: [영구 센티넬] 원천에 캠페인 연결 키가 없어 이 뷰에서는 **배선을 기다려도 값이 생기지 않는다** — 이 컬럼으로 GROUP BY·필터하지 않는다(캠페인 분해는 FACT_MEMBER_EVENT·MSTR 를 쓴다). DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴 **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_EVENT_ATTENDANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것.

### WIDE_EVENT_PARTICIPATION.CAMPAIGN_BRAND 
- 전: DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_EVENT_ATTENDANCE.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴 **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_EVENT_ATTENDANCE.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다.

### WIDE_EVENT_PARTICIPATION.CAMPAIGN_NAME 
- 전: [O216-D A4-X 영구 센티넬] 원천에 캠페인 연결 키가 없어 이 뷰에서는 **배선을 기다려도 값이 생기지 않는다** — 이 컬럼으로 GROUP BY·필터하지 않는다(캠페인 분해는 FACT_MEMBER_EVENT·MSTR 를 쓴다). DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_EVENT_ATTENDANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.
- 후: [영구 센티넬] 원천에 캠페인 연결 키가 없어 이 뷰에서는 **배선을 기다려도 값이 생기지 않는다** — 이 컬럼으로 GROUP BY·필터하지 않는다(캠페인 분해는 FACT_MEMBER_EVENT·MSTR 를 쓴다). DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴 **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_EVENT_ATTENDANCE.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것.

### WIDE_EVENT_PARTICIPATION.EVENT_APPLY_CHANNEL 
- 전: DIM_EVENT.APPLY_CHANNEL — 신청경로 🔴🔴[O51-D 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_EVENT.APPLY_CHANNEL`. 행사 신청채널은 원천 행사 마스터에 값이 없다 ⇒ **신청채널 분석은 불가**하다. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_EVENT.APPLY_CHANNEL — 신청경로 🔴🔴 **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_EVENT.APPLY_CHANNEL`. 행사 신청채널은 원천 행사 마스터에 값이 없다 ⇒ **신청채널 분석은 불가**하다.

### WIDE_EVENT_PARTICIPATION.EVENT_BK (덮어쓰기)
- 전: DIM_EVENT.EVENT_BK — 행사 업무키 🔴[O51-D 실측] `'(미매핑)'` 이 **다수**다 — 행사 마스터 없는 고아 행사가 한 그룹으로 뭉친다. 행사 식별은 `PART_EVENT_BK` 를 쓴다. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_EVENT.EVENT_BK — 행사 업무키. 행사 식별은 팩트 원천키 `PART_EVENT_BK` 를 쓴다.

### WIDE_EVENT_PARTICIPATION.EVENT_KIND 
- 전: DIM_EVENT.EVENT_KIND — 🔴[O59-P 정정] 종전 설명 「온라인/오프라인」은 **거짓이었다**. 실제 값은 `EVENT`(일반행사) · `CRMN`(캠페인행사) = **원천 판별자**다(온·오프라인 구분은 `EVENT_CATEGORY` 소관). 🔴이 컬럼이 O28 다체계의 판별자다 — 참여상태·경로를 이 축 없이 합산하면 정의가 다른 두 체계를 섞는다. 라벨축 = `EVENT_KIND_NAME`
- 후: DIM_EVENT.EVENT_KIND — 🔴 종전 설명 「온라인/오프라인」은 **거짓이었다**. 실제 값은 `EVENT`(일반행사) · `CRMN`(캠페인행사) = **원천 판별자**다(온·오프라인 구분은 `EVENT_CATEGORY` 소관). 🔴이 컬럼이 다체계의 판별자다 — 참여상태·경로를 이 축 없이 합산하면 정의가 다른 두 체계를 섞는다. 라벨축 = `EVENT_KIND_NAME`

### WIDE_EVENT_PARTICIPATION.EVENT_KIND_NAME 
- 전: DIM_EVENT.EVENT_KIND_NAME — 행사종류 라벨(일반행사/캠페인행사). ⚠️판별자 라벨은 코드사전에 존재할 수 없어 `CASE` 로 만든다(DEC-35 §23-B 헛점4 의 명문 예외 · 미등재 값은 NULL 로 떨어져 warn 이 잡는다)
- 후: DIM_EVENT.EVENT_KIND_NAME — 행사종류 라벨(일반행사/캠페인행사). ⚠️판별자 라벨은 코드사전에 존재할 수 없어 `CASE` 로 만든다(§23-B 헛점4 의 명문 예외 · 미등재 값은 NULL 로 떨어져 warn 이 잡는다)

### WIDE_EVENT_PARTICIPATION.EVENT_NAME (덮어쓰기)
- 전: DIM_EVENT.EVENT_NAME — 행사명 🔴[O51-D 실측] `'(미매핑)'` 이 **다수**다 — 고아 행사들이 한 이름으로 합쳐진다. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_EVENT.EVENT_NAME — 행사명. ⚠️행사 마스터가 없는 행사는 이름이 합쳐질 수 있다 — 식별은 `PART_EVENT_BK` 로 한다.

### WIDE_EVENT_PARTICIPATION.EVENT_RECRUIT_HEADCOUNT 
- 전: DIM_EVENT.RECRUIT_HEADCOUNT — 행사 모집인원(정원) ← `SILVER CRM_EVENT.RCRIT_PSNNL_CO`. 일부 행사는 정원이 없다. 🔴🔴**행사 grain 속성이므로 참여행에서 SUM 금지** — 참여행마다 반복되어 **두 자리 배수로 과대계상**된다(실측 배율은 이슈원장 §O51-D-C). 정원 대비 참여율은 행사 단위로 집계한 뒤 나눌 것. 🔧[DEC-30] 종전 팩트의 RECRUIT_CNT 를 제거하고 이 행사 차원 값으로 대체했다.
- 후: DIM_EVENT.RECRUIT_HEADCOUNT — 행사 모집인원(정원) ← `SILVER CRM_EVENT.RCRIT_PSNNL_CO`. 일부 행사는 정원이 없다. 🔴🔴**행사 grain 속성이므로 참여행에서 SUM 금지** — 참여행마다 반복되어 **두 자리 배수로 과대계상**된다. 정원 대비 참여율은 행사 단위로 집계한 뒤 나눌 것. 🔧 종전 팩트의 RECRUIT_CNT 를 제거하고 이 행사 차원 값으로 대체했다.

### WIDE_EVENT_PARTICIPATION.MEMBER_AGE_BAND 
- 전: DIM_MEMBER.AGE_BAND — 연령대명 · **CM014** 라벨. 코드 = MEMBER_AGE_CD. 🔴빈 값은 두 갈래이며 **둘 다 개발약정 원천 행이 없는 경우**다 — 일시회원('ONCE')은 전건, 정기회원(FDRM)은 일부. 연령 개념은 존재하므로 '(해당없음)' 이 아니라 NULL 이고 미매핑도 없다. '미상' 으로 창작하지 않는다(R2-7-1). 🔴**연속형 나이가 아니다** — 평균·재구간화 금지(원천이 이미 구간화해 제공한다 · DEC-28). 🔴**현재 나이가 아니다** — 개발약정 시점 스냅샷이고 BRONZE 에 생년월일 축이 없어 시점정확 연령은 산출 불가다(O34). ⚠️연령 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것(P128).
- 후: DIM_MEMBER.AGE_BAND — 연령대명 · **CM014** 라벨. 코드 = MEMBER_AGE_CD. 🔴빈 값은 두 갈래이며 **둘 다 개발약정 원천 행이 없는 경우**다 — 일시회원('ONCE')은 전건, 정기회원(FDRM)은 일부. 연령 개념은 존재하므로 '(해당없음)' 이 아니라 NULL 이고 미매핑도 없다. '미상' 으로 창작하지 않는다. 🔴**연속형 나이가 아니다** — 평균·재구간화 금지(원천이 이미 구간화해 제공한다). 🔴**현재 나이가 아니다** — 개발약정 시점 스냅샷이고 BRONZE 에 생년월일 축이 없어 시점정확 연령은 산출 불가다. ⚠️연령 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것.

### WIDE_EVENT_PARTICIPATION.MEMBER_AGE_CD 
- 전: DIM_MEMBER.AGE — 연령대 원천코드 raw. 코드그룹 **CM014(나이)**. 코드사전 = 1'10대 미만'·2'10대'·3'20대'·4'30대'·5'40대'·6'50대'·7'60대'·8'70대'·9'70대 이상'·10단체·11기업·12기타 · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AGE)에 **사전 전종이 등장**한다. 🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지. 구간은 우리가 만든 것이 아니라 원천이 이미 구간화해 제공한다(DEC-28). ⚠️사전 자체에 8'70대'와 9'70대 이상'이 **의미 중복**으로 공존한다 — 70대 이상 집계 시 두 코드를 함께 취할 것. ⚠️BRONZE 원천 컬럼 COMMENT '연령'(NUMBER)은 오류다. 라벨 = MEMBER_AGE_BAND. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.AGE — 연령대 원천코드 raw. 코드그룹 **CM014(나이)**. 코드사전 = 1'10대 미만'·2'10대'·3'20대'·4'30대'·5'40대'·6'50대'·7'60대'·8'70대'·9'70대 이상'·10단체·11기업·12기타 · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AGE)에 **사전 전종이 등장**한다. 🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지. 구간은 우리가 만든 것이 아니라 원천이 이미 구간화해 제공한다. ⚠️사전 자체에 8'70대'와 9'70대 이상'이 **의미 중복**으로 공존한다 — 70대 이상 집계 시 두 코드를 함께 취할 것. ⚠️BRONZE 원천 컬럼 COMMENT '연령'(NUMBER)은 오류다. 라벨 = MEMBER_AGE_BAND. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_EVENT_PARTICIPATION.MEMBER_AREA_CD 
- 전: DIM_MEMBER.AREA_CD — 지역 원천코드 raw. 코드그룹 **CM018**. 코드사전 = (1서울·2경기·3인천·4강원·5대전·6충남·7충북·8광주·9전북·10전남·11대구·12경북·13경남·14울산·15부산·16제주·17기타·18세종) · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD)에 **사전 전종 + 라벨 없는 센티넬 '0'** 이 나타난다. ⚠️CM018 의 그룹명은 '신규시도구분'이지만 상세코드 값은 전부 시·도다(정본 공#131 지역정의가 약칭이라 정식명 그룹 CM011 이 아니다). 🔴**현재 거주지가 아니다** — 이 값은 그 버전 시점까지 최근 개발약정의 스냅샷이며 BRONZE 전체에 현주소 축이 없다(O34). 라벨 = MEMBER_REGION. 사건 시점 정확값은 WIDE_MEMBER_EVENT.AREA_CD_AT_EVENT. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.AREA_CD — 지역 원천코드 raw. 코드그룹 **CM018**. 코드사전 = (1서울·2경기·3인천·4강원·5대전·6충남·7충북·8광주·9전북·10전남·11대구·12경북·13경남·14울산·15부산·16제주·17기타·18세종) · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD)에 **사전 전종 + 라벨 없는 센티넬 '0'** 이 나타난다. ⚠️CM018 의 그룹명은 '신규시도구분'이지만 상세코드 값은 전부 시·도다(정본 공#131 지역정의가 약칭이라 정식명 그룹 CM011 이 아니다). 🔴**현재 거주지가 아니다** — 이 값은 그 버전 시점까지 최근 개발약정의 스냅샷이며 BRONZE 전체에 현주소 축이 없다. 라벨 = MEMBER_REGION. 사건 시점 정확값은 WIDE_MEMBER_EVENT.AREA_CD_AT_EVENT. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_EVENT_PARTICIPATION.MEMBER_GENDER_NAME 
- 전: DIM_MEMBER.GENDER_NAME — 성별 분석 라벨(정본 공#130). 코드그룹 **CM017(회원특성(성별))**. CM017 은 CM013 과 **코드 도메인이 동일(1~8)한 재라벨 그룹**이며 국내/외국인 구분을 지운다 — 1남자·2여자·3남자·4여자·5기타·6단체·7기업·8기타 ⇒ **서로 다른 코드가 같은 라벨로 합쳐진다**(남자/여자/기타/단체/기업). 정본 공#130 값정의와 일치. ⚠️CM017 은 정본 컬럼정의서가 어떤 컬럼에도 지정하지 않은 그룹이다(현업 확인 대상). ⚠️종전 하드코딩 '여성/남성/미상'은 라벨을 축약하고 법인·단체를 '미상'으로 오라벨했다(O26 교정). 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.GENDER_NAME — 성별 분석 라벨(정본 공#130). 코드그룹 **CM017(회원특성(성별))**. CM017 은 CM013 과 **코드 도메인이 동일(1~8)한 재라벨 그룹**이며 국내/외국인 구분을 지운다 — 1남자·2여자·3남자·4여자·5기타·6단체·7기업·8기타 ⇒ **서로 다른 코드가 같은 라벨로 합쳐진다**(남자/여자/기타/단체/기업). 정본 공#130 값정의와 일치. ⚠️CM017 은 정본 컬럼정의서가 어떤 컬럼에도 지정하지 않은 그룹이다(현업 확인 대상). ⚠️종전 하드코딩 '여성/남성/미상'은 라벨을 축약하고 법인·단체를 '미상'으로 오라벨했다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_EVENT_PARTICIPATION.MEMBER_REGION 
- 전: DIM_MEMBER.REGION — 지역명(정본 공#131) · **CM018** 약칭 라벨. 코드 = MEMBER_AREA_CD. 🔴빈 값이 세 갈래다 — ①일시회원(MEMBER_TYPE='ONCE')은 개발약정 **행 자체가 없어** NULL 이다(지역 개념은 존재하므로 '(해당없음)' 이 아니다) ②정기회원(FDRM) 중 개발약정이 없는 행도 NULL ③센티넬 코드 '0' 은 사전에 라벨이 없어 NULL. 🟢미매핑(코드는 있는데 사전에 없음)은 없다. '미상' 으로 창작하지 않는다(R2-7-1). 🔴**현재 거주지가 아니다** — 개발약정 시점 스냅샷이며 BRONZE 에 현주소 축이 없다(O34). ⚠️지역 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것 — ONCE 를 분모에 넣으면 채움률이 조용히 낮아진다(P128).
- 후: DIM_MEMBER.REGION — 지역명(정본 공#131) · **CM018** 약칭 라벨. 코드 = MEMBER_AREA_CD. 🔴빈 값이 세 갈래다 — ①일시회원(MEMBER_TYPE='ONCE')은 개발약정 **행 자체가 없어** NULL 이다(지역 개념은 존재하므로 '(해당없음)' 이 아니다) ②정기회원(FDRM) 중 개발약정이 없는 행도 NULL ③센티넬 코드 '0' 은 사전에 라벨이 없어 NULL. 🟢미매핑(코드는 있는데 사전에 없음)은 없다. '미상' 으로 창작하지 않는다. 🔴**현재 거주지가 아니다** — 개발약정 시점 스냅샷이며 BRONZE 에 현주소 축이 없다. ⚠️지역 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것 — ONCE 를 분모에 넣으면 채움률이 조용히 낮아진다.

### WIDE_EVENT_PARTICIPATION.MEMBER_STATUS_NAME 
- 전: DIM_MEMBER.MEMBER_STATUS_NAME — 회원상태명(MM010 라벨, 정본 공#132). 코드 = MBER_STAT_CD. MM010 은 **폐지코드가 없고 실적재가 사전과 일치**한다 ⇒ 사전 조인만으로 전건 라벨화된다(하드코딩 금지 P31). 값 = 활동회원 / 신규미납1~5 / 장기미납1~5 / 후원중단. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원(DIM_MEMBER.MEMBER_TYPE='ONCE')은 회원상태 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원(FDRM) 중 원천 상태코드 자체가 결손인 행만 **NULL** 이다. 두 사건을 '미상' 같은 한 값으로 뭉개지 않는다(R2-7-1). ⚠️미납 단계(1~5)는 **경과 차수**이며 금액 규모가 아니다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.MEMBER_STATUS_NAME — 회원상태명(MM010 라벨, 정본 공#132). 코드 = MBER_STAT_CD. MM010 은 **폐지코드가 없고 실적재가 사전과 일치**한다 ⇒ 사전 조인만으로 전건 라벨화된다(하드코딩 금지). 값 = 활동회원 / 신규미납1~5 / 장기미납1~5 / 후원중단. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원(DIM_MEMBER.MEMBER_TYPE='ONCE')은 회원상태 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원(FDRM) 중 원천 상태코드 자체가 결손인 행만 **NULL** 이다. 두 사건을 '미상' 같은 한 값으로 뭉개지 않는다. ⚠️미납 단계(1~5)는 **경과 차수**이며 금액 규모가 아니다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_EVENT_PARTICIPATION.MEMBER_TYPE_NAME 
- 전: DIM_MEMBER.MEMBER_TYPE_NAME — 회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. MM018 은 폐지코드가 없고 실적재가 사전과 일치한다. 🟢빈 값이 없는 축이다 — 센티넬 '(해당없음)'·NULL 모두 없고 전건 라벨화된다. 앞으로 사전에 없는 코드가 인입되면 **NULL 로 드러나며** '미상' 같은 값으로 덮지 않는다(R2-7-1). 🔴이름이 비슷한 DIM_MEMBER.MEMBER_TYPE(=FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다** — 다른 축이다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.MEMBER_TYPE_NAME — 회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. MM018 은 폐지코드가 없고 실적재가 사전과 일치한다. 🟢빈 값이 없는 축이다 — 센티넬 '(해당없음)'·NULL 모두 없고 전건 라벨화된다. 앞으로 사전에 없는 코드가 인입되면 **NULL 로 드러나며** '미상' 같은 값으로 덮지 않는다. 🔴이름이 비슷한 DIM_MEMBER.MEMBER_TYPE(=FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다** — 다른 축이다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_EVENT_PARTICIPATION.PART_CHANNEL_GROUP 
- 전: 참여채널 코드군 ID (조인키 · 일반행사→MS302). 캠페인행사는 원천에 채널 축이 없어 NULL(구조적 부재 · P21)
- 후: 참여채널 코드군 ID (조인키 · 일반행사→MS302). 캠페인행사는 원천에 채널 축이 없어 NULL(구조적 부재)

### WIDE_EVENT_PARTICIPATION.PART_EVENT_BK 
- 전: FACT_EVENT_ATTENDANCE.EVENT_BK — degenerate key: **팩트가 보유한 원천 행사키**(전건 채움). 🔴같은 뷰의 EVENT_BK(=DIM_EVENT 매칭분)와 **다르다** — 행사 마스터가 없는 **고아 행사**가 EVENT_SK=0 으로 뭉개져 서로 구별되지 않으므로 이 컬럼으로 식별을 보존한다. 차원 미매칭분의 EVENT_BK 는 '(미매핑)'이지만 **PART_EVENT_BK 는 원천값을 그대로 갖는다.** 차원 미매칭분의 EVENT_BK 는 '(미매핑)'이지만 PART_EVENT_BK 는 원천값을 그대로 갖는다. 🔷행 유일 식별 = (PART_EVENT_BK, MEMBER_DK, PARTCPT_SEQ). ⚠️접두(EVENT_/CRMN_)가 원천 코드체계 판별자(O28).
- 후: FACT_EVENT_ATTENDANCE.EVENT_BK — degenerate key: **팩트가 보유한 원천 행사키**(전건 채움). 🔴같은 뷰의 EVENT_BK(=DIM_EVENT 매칭분)와 **다르다** — 행사 마스터가 없는 **고아 행사**가 EVENT_SK=0 으로 뭉개져 서로 구별되지 않으므로 이 컬럼으로 식별을 보존한다. 차원 미매칭분의 EVENT_BK 는 '(미매핑)'이지만 **PART_EVENT_BK 는 원천값을 그대로 갖는다.** 차원 미매칭분의 EVENT_BK 는 '(미매핑)'이지만 PART_EVENT_BK 는 원천값을 그대로 갖는다. 🔷행 유일 식별 = (PART_EVENT_BK, MEMBER_DK, PARTCPT_SEQ). ⚠️접두(EVENT_/CRMN_)가 원천 코드체계 판별자.

### WIDE_EVENT_PARTICIPATION.PART_EVENT_KIND 
- 전: FACT_EVENT_ATTENDANCE.EVENT_KIND — **팩트가 보유한 원천 계열 판별 코드**(전건 채움 · 값 EVENT/CRMN). 🔴같은 뷰의 EVENT_KIND(=DIM_EVENT 유래)와 **다르다** — 차원축은 행사 마스터 미매칭 구간이 '(미매핑)' 이라 계열을 알려주지 못한다. ⇒ **계열 분해·O28 다체계 판별은 이 컬럼**으로 한다. 라벨은 PART_EVENT_KIND_NAME.
- 후: FACT_EVENT_ATTENDANCE.EVENT_KIND — **팩트가 보유한 원천 계열 판별 코드**(전건 채움 · 값 EVENT/CRMN). 🔴같은 뷰의 EVENT_KIND(=DIM_EVENT 유래)와 **다르다** — 차원축은 행사 마스터 미매칭 구간이 '(미매핑)' 이라 계열을 알려주지 못한다. ⇒ **계열 분해 다체계 판별은 이 컬럼**으로 한다. 라벨은 PART_EVENT_KIND_NAME.

### WIDE_EVENT_PARTICIPATION.PART_STATUS_GROUP 
- 전: 참여상태 코드군 ID (조인키 · 일반행사→MS304 · 캠페인행사→MS006). 🔴O28 다체계의 **구조적 해소축**이다 — `PART_STATUS` 단독 필터·GROUP BY 는 두 체계를 섞는다(판별자 = 이 컬럼 또는 `EVENT_KIND`). 🔴두 원천의 「참여」 정의 자체가 다르므로 합산 금지
- 후: 참여상태 코드군 ID (조인키 · 일반행사→MS304 · 캠페인행사→MS006). 🔴다체계의 **구조적 해소축**이다 — `PART_STATUS` 단독 필터·GROUP BY 는 두 체계를 섞는다(판별자 = 이 컬럼 또는 `EVENT_KIND`). 🔴두 원천의 「참여」 정의 자체가 다르므로 합산 금지

### WIDE_EVENT_PARTICIPATION.SELF_PART_FLAG 
- 전: 본인참여 여부 — 캠페인행사 자기참여코드(MS060) 파생: 1(본인만)·2(함께)=TRUE · 0(동반자만)=FALSE(`FACT_EVENT_ATTENDANCE.sql`). 🔴 일반행사 행은 원천에 자기참여 컬럼이 없어 전건 NULL 이다(구조적 부재) — NULL 을 FALSE·'본인 미참여'로 읽지 말 것. 종전 「전건 NULL·미적재」(O51-D) 판정은 2차-B 배선(O191-G)으로 해소됐다.
- 후: 본인참여 여부 — 캠페인행사 자기참여코드(MS060) 파생: 1(본인만)·2(함께)=TRUE · 0(동반자만)=FALSE(`FACT_EVENT_ATTENDANCE.sql`). 🔴 일반행사 행은 원천에 자기참여 컬럼이 없어 전건 NULL 이다(구조적 부재) — NULL 을 FALSE·'본인 미참여'로 읽지 말 것. 종전 「전건 NULL·미적재」 판정은 2차-B 배선으로 해소됐다.

### WIDE_EVENT_PARTICIPATION.SPONSORSHIP_BK 
- 전: DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_EVENT_ATTENDANCE.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키 🔴🔴 **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_EVENT_ATTENDANCE.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것.

### WIDE_EVENT_PARTICIPATION.SPONSORSHIP_NAME 
- 전: DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123) 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_EVENT_ATTENDANCE.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123) 🔴🔴 **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_EVENT_ATTENDANCE.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것.

### WIDE_MEMBER_EVENT.AGE_AT_EVENT 
- 전: FACT_MEMBER_EVENT.AGE_AT_EVENT — 연령대 코드 raw, **사건(개발약정) 시점 값**. 코드그룹 **CM014**. 원천 `TM_MM_FDRM_MBER_DVLP_AMT.AGE` 의 사건행별 값을 무변환 전파한다. 🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지(1'10대 미만'~9'70대 이상'·10단체·11기업·12기타). 🔴MEMBER_AGE_CD(=현재버전 경유 '최근 약정' 스냅샷)와 **다른 축**이며 같은 회원도 사건마다 값이 다를 수 있다 — 이 컬럼이 그 사건 당시의 정확값이다. ⚠️중단원천 행은 원천 컬럼 부재로 NULL(0 아님, P21). 라벨 = AGE_BAND_AT_EVENT.
- 후: FACT_MEMBER_EVENT.AGE_AT_EVENT — 연령대 코드 raw, **사건(개발약정) 시점 값**. 코드그룹 **CM014**. 원천 `TM_MM_FDRM_MBER_DVLP_AMT.AGE` 의 사건행별 값을 무변환 전파한다. 🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지(1'10대 미만'~9'70대 이상'·10단체·11기업·12기타). 🔴MEMBER_AGE_CD(=현재버전 경유 '최근 약정' 스냅샷)와 **다른 축**이며 같은 회원도 사건마다 값이 다를 수 있다 — 이 컬럼이 그 사건 당시의 정확값이다. ⚠️중단원천 행은 원천 컬럼 부재로 NULL(0 아님). 라벨 = AGE_BAND_AT_EVENT.

### WIDE_MEMBER_EVENT.AGE_BAND_AT_EVENT 
- 전: FACT_MEMBER_EVENT.AGE_BAND_AT_EVENT — **사건 시점** 연령대명(CM014 사전 조인, 하드코딩 아님 P31). 코드 = AGE_AT_EVENT. ✅'10대 미만'이 상위인 것은 **오류가 아니다** — 편지쓰기대회 계열 캠페인(희망편지·가족그림편지·세계시민교육편지)이 학교·부모 DB 를 통해 아동 본인 명의로 약정을 맺기 때문이다. 결측·기본값 오염으로 설명하지 말 것(O34-B). ⚠️사전에 8'70대'·9'70대 이상'이 의미 중복으로 공존한다. 🔴MEMBER_AGE_BAND(현재버전 스냅샷)와 값이 다를 수 있다. 중단원천 행은 NULL.
- 후: FACT_MEMBER_EVENT.AGE_BAND_AT_EVENT — **사건 시점** 연령대명(CM014 사전 조인, 하드코딩 아님). 코드 = AGE_AT_EVENT. ✅'10대 미만'이 상위인 것은 **오류가 아니다** — 편지쓰기대회 계열 캠페인(희망편지·가족그림편지·세계시민교육편지)이 학교·부모 DB 를 통해 아동 본인 명의로 약정을 맺기 때문이다. 결측·기본값 오염으로 설명하지 말 것. ⚠️사전에 8'70대'·9'70대 이상'이 의미 중복으로 공존한다. 🔴MEMBER_AGE_BAND(현재버전 스냅샷)와 값이 다를 수 있다. 중단원천 행은 NULL.

### WIDE_MEMBER_EVENT.AREA_CD_AT_EVENT 
- 전: FACT_MEMBER_EVENT.AREA_CD_AT_EVENT — 지역 코드 raw, **사건(개발약정) 시점 값**. 코드그룹 **CM018**(지표 공#131). 원천 `TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD` 무변환 전파 · 실적재에 **사전 전종 + 라벨 없는 센티넬 '0'** 이 나타난다. 🔴MEMBER_AREA_CD(현재버전 경유 최근 약정 스냅샷)와 **다른 축** — 이사 등으로 사건마다 값이 다를 수 있다. ⚠️**현재 거주지가 아니다** — BRONZE 전체에 현주소 축이 없어 현재 지역은 산출 불가(O34). ⚠️중단원천 행은 원천 컬럼 부재로 NULL. 라벨 = REGION_AT_EVENT.
- 후: FACT_MEMBER_EVENT.AREA_CD_AT_EVENT — 지역 코드 raw, **사건(개발약정) 시점 값**. 코드그룹 **CM018**(지표 공#131). 원천 `TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD` 무변환 전파 · 실적재에 **사전 전종 + 라벨 없는 센티넬 '0'** 이 나타난다. 🔴MEMBER_AREA_CD(현재버전 경유 최근 약정 스냅샷)와 **다른 축** — 이사 등으로 사건마다 값이 다를 수 있다. ⚠️**현재 거주지가 아니다** — BRONZE 전체에 현주소 축이 없어 현재 지역은 산출 불가. ⚠️중단원천 행은 원천 컬럼 부재로 NULL. 라벨 = REGION_AT_EVENT.

### WIDE_MEMBER_EVENT.CAMPAIGN_BIZ_CASE_TYPE 
- 전: 캠페인 굿즈/기타/사례/사업 구분 라벨. 코드그룹 **MM296**. ⚠️ CAMPAIGN_DOMESTIC_OVERSEAS(유형1=국내/해외 축)와 다른 축이다 — 혼동 금지. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.CMPGN_TYPE2_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).
- 후: 캠페인 굿즈/기타/사례/사업 구분 라벨. 코드그룹 **MM296**. ⚠️ CAMPAIGN_DOMESTIC_OVERSEAS(유형1=국내/해외 축)와 다른 축이다 — 혼동 금지. 🔴🔴 **소스 = FACT_MEMBER_EVENT.CMPGN_TYPE2_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축). 전환 시점 두 소스 값은 전건 동일했다. ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다. 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문).

### WIDE_MEMBER_EVENT.CAMPAIGN_CATEGORY 
- 전: 캠페인 **카테고리** 라벨(정본 공#17). 코드그룹 **MM294(캠페인 카테고리)**. ⚠️ 원천 `TM_CM_CMPGN_MNG.CMPGN_CTGR_CD` 에 코드사전 미등재 코드가 실재해 그 행은 라벨이 비고, 미채움 행도 있다(규모는 이슈원장 참조). ⚠️ **사전 자체에 동일 라벨 중복**이 있어 라벨로 GROUP BY 하면 두 코드가 합쳐진다. ⚠️ 업무용어는 '카테고리'이고 상위캠페인은 CAMPAIGN_PARENT 다. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.CMPGN_CTGR_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).
- 후: 캠페인 **카테고리** 라벨(정본 공#17). 코드그룹 **MM294(캠페인 카테고리)**. ⚠️ 원천 `TM_CM_CMPGN_MNG.CMPGN_CTGR_CD` 에 코드사전 미등재 코드가 실재해 그 행은 라벨이 비고, 미채움 행도 있다. ⚠️ **사전 자체에 동일 라벨 중복**이 있어 라벨로 GROUP BY 하면 두 코드가 합쳐진다. ⚠️ 업무용어는 '카테고리'이고 상위캠페인은 CAMPAIGN_PARENT 다. 🔴🔴 **소스 = FACT_MEMBER_EVENT.CMPGN_CTGR_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축). 전환 시점 두 소스 값은 전건 동일했다. ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다. 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문).

### WIDE_MEMBER_EVENT.CAMPAIGN_CMMN_BRND 
- 전: 공통브랜드 라벨. 코드그룹 **MM297**. ⚠️ 라벨이 MM293(개발인입경로)과 상당 중복되나 현업 확인상 별도 축으로 유지한다. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.CMMN_BRND_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).
- 후: 공통브랜드 라벨. 코드그룹 **MM297**. ⚠️ 라벨이 MM293(개발인입경로)과 상당 중복되나 현업 확인상 별도 축으로 유지한다. 🔴🔴 **소스 = FACT_MEMBER_EVENT.CMMN_BRND_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축). 전환 시점 두 소스 값은 전건 동일했다. ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다. 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문).

### WIDE_MEMBER_EVENT.CAMPAIGN_CPR_DIV_CD 
- 전: 세부캠페인 법인구분 원천코드. 코드그룹 **CM019**: A=통합 · I=사단 · S=사복. 🔴 라벨이 아니다 — 사람이 읽는 이름은 CAMPAIGN_CPR_DIV_NM. 🔴 조직 계층의 법인(ORG_CORP)과 **다른 축**이다 — ORG_CORP 는 전건 비어 있고 이 축은 채워진다. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.CPR_DIV_CD_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).
- 후: 세부캠페인 법인구분 원천코드. 코드그룹 **CM019**: A=통합 · I=사단 · S=사복. 🔴 라벨이 아니다 — 사람이 읽는 이름은 CAMPAIGN_CPR_DIV_NM. 🔴 조직 계층의 법인(ORG_CORP)과 **다른 축**이다 — ORG_CORP 는 전건 비어 있고 이 축은 채워진다. 🔴🔴 **소스 = FACT_MEMBER_EVENT.CPR_DIV_CD_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축). 전환 시점 두 소스 값은 전건 동일했다. ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다. 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문).

### WIDE_MEMBER_EVENT.CAMPAIGN_CPR_DIV_NM 
- 전: CAMPAIGN_CPR_DIV_CD 를 CM019 로 해소한 라벨(통합/사단/사복). 🔴 조직 계층의 법인(ORG_CORP)과 **다른 축**이다 — 「법인별」 질문은 어느 축인지 먼저 가린다. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.CPR_DIV_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).
- 후: CAMPAIGN_CPR_DIV_CD 를 CM019 로 해소한 라벨(통합/사단/사복). 🔴 조직 계층의 법인(ORG_CORP)과 **다른 축**이다 — 「법인별」 질문은 어느 축인지 먼저 가린다. 🔴🔴 **소스 = FACT_MEMBER_EVENT.CPR_DIV_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축). 전환 시점 두 소스 값은 전건 동일했다. ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다. 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문).

### WIDE_MEMBER_EVENT.CAMPAIGN_DOMESTIC_OVERSEAS 
- 전: 캠페인 국내/통합/해외 라벨. 코드그룹 **MM295**. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.CMPGN_TYPE1_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).
- 후: 캠페인 국내/통합/해외 라벨. 코드그룹 **MM295**. 🔴🔴 **소스 = FACT_MEMBER_EVENT.CMPGN_TYPE1_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축). 전환 시점 두 소스 값은 전건 동일했다. ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다. 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문).

### WIDE_MEMBER_EVENT.CAMPAIGN_INFLOW_PATH 
- 전: 개발인입경로 라벨 = **모집 채널**. 코드그룹 **MM293(개발인입경로)**. 🔴 이 축을 「현업 주요캠페인 분류축」이라고 적었던 기술은 **거짓이므로 회수됐다**(O37) — 모집 채널이다. 캠페인 카테고리 = CAMPAIGN_CATEGORY(MM294) · 상위캠페인 = CAMPAIGN_PARENT. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.MBER_INFLOW_PATH_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).
- 후: 개발인입경로 라벨 = **모집 채널**. 코드그룹 **MM293(개발인입경로)**. 🔴 이 축을 「현업 주요캠페인 분류축」이라고 적었던 기술은 **거짓이므로 회수됐다** — 모집 채널이다. 캠페인 카테고리 = CAMPAIGN_CATEGORY(MM294) · 상위캠페인 = CAMPAIGN_PARENT. 🔴🔴 **소스 = FACT_MEMBER_EVENT.MBER_INFLOW_PATH_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축). 전환 시점 두 소스 값은 전건 동일했다. ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다. 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문).

### WIDE_MEMBER_EVENT.CAMPAIGN_MARKETING_CAMPAIGN 
- 전: 마케팅캠페인명 라벨(Q16 해소). 🔴 광고비 결합은 이 라벨이 아니라 MKTG_CAMPAIGN_SK(FK)를 쓴다 — 라벨로 결합하면 안 된다(O44/O45). 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.MKTG_CMPGN_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).
- 후: 마케팅캠페인명 라벨. 🔴 광고비 결합은 이 라벨이 아니라 MKTG_CAMPAIGN_SK(FK)를 쓴다 — 라벨로 결합하면 안 된다. 🔴🔴 **소스 = FACT_MEMBER_EVENT.MKTG_CMPGN_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축). 전환 시점 두 소스 값은 전건 동일했다. ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다. 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문).

### WIDE_MEMBER_EVENT.CAMPAIGN_MKTG_UTM 
- 전: UTM 라벨. 코드사전이 아니라 원천 TM_CM_MKTNG_UTM(MK_UTM/MK_UTM_NM)과 연동된 값. ⚠️ 원천 미등재 코드가 많아 라벨 채움이 낮다 — **결측이 아니라 미등재**다. 🔴 채움 비율은 규칙7 상 여기 적지 않는다(재적재마다 stale 이 된다) ⇒ 조회로 확인하고 UTM별 분해가 부분집합임을 밝힐 것. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.MKTG_UTM_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).
- 후: UTM 라벨. 코드사전이 아니라 원천 TM_CM_MKTNG_UTM(MK_UTM/MK_UTM_NM)과 연동된 값. ⚠️ 원천 미등재 코드가 많아 라벨 채움이 낮다 — **결측이 아니라 미등재**다. 🔴 채움 비율은 규칙7 상 여기 적지 않는다(재적재마다 stale 이 된다) ⇒ 조회로 확인하고 UTM별 분해가 부분집합임을 밝힐 것. 🔴🔴 **소스 = FACT_MEMBER_EVENT.MKTG_UTM_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축). 전환 시점 두 소스 값은 전건 동일했다. ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다. 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문).

### WIDE_MEMBER_EVENT.CAMPAIGN_SPNSR_DIV_CD 
- 전: 세부캠페인 후원구분 원천코드. 코드그룹 **CM035**: 1=정기후원 · 2=일시후원. 🔴 라벨이 아니다 — 사람이 읽는 이름은 CAMPAIGN_SPNSR_DIV_NM. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.SPNSR_DIV_CD_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).
- 후: 세부캠페인 후원구분 원천코드. 코드그룹 **CM035**: 1=정기후원 · 2=일시후원. 🔴 라벨이 아니다 — 사람이 읽는 이름은 CAMPAIGN_SPNSR_DIV_NM. 🔴🔴 **소스 = FACT_MEMBER_EVENT.SPNSR_DIV_CD_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축). 전환 시점 두 소스 값은 전건 동일했다. ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다. 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문).

### WIDE_MEMBER_EVENT.CAMPAIGN_SPNSR_DIV_NM 
- 전: CAMPAIGN_SPNSR_DIV_CD 를 CM035 로 해소한 라벨(정기후원/일시후원). ⚠️ DIM_SPONSORSHIP.SPONSORSHIP_DIV_NAME(후원사업 축 CM035)과 코드사전은 같지만 **적용 대상이 다르다** — 이 컬럼은 세부캠페인 단위 구분이다. 🔴🔴 [2026-08-28 O105] **소스 = FACT_MEMBER_EVENT.SPNSR_DIV_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축 · DEC-43 계열). 전환 시점 두 소스 값은 전건 동일했다(규모·근거 = 이슈원장 §O105). ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문 · `R2-7-3`).
- 후: CAMPAIGN_SPNSR_DIV_CD 를 CM035 로 해소한 라벨(정기후원/일시후원). ⚠️ DIM_SPONSORSHIP.SPONSORSHIP_DIV_NAME(후원사업 축 CM035)과 코드사전은 같지만 **적용 대상이 다르다** — 이 컬럼은 세부캠페인 단위 구분이다. 🔴🔴 **소스 = FACT_MEMBER_EVENT.SPNSR_DIV_NM_AT_EVENT (적재 시점 동결값)** — 종전 DIM_CAMPAIGN 실시간 조인에서 전환했다. 캠페인 마스터가 이후 정정·개칭돼도 **과거 개발이력 사건의 값은 바뀌지 않는다**(SV_MEMBER_EVENT 와 같은 축). 전환 시점 두 소스 값은 전건 동일했다. ⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다. 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 채우기 때문).

### WIDE_MEMBER_EVENT.DEV_CNT 
- 전: 개발(건) (#149) = **MSTR 정의**(O202 · 사용자 결정): 이 사건의 MSTR 인정금액 ÷ 10,000(신규·재후원 = 미중단 후원사업·후원사업×월 합>0 행 금액 · 증액 = 감액 상계 순증액 · 그 밖 0). 원본 = FN_MM_SPNSR_DVLP B1·B2 + USP_F_MM_SPNSR_DVLP_SUM. 🟢 MSTR 전건 일치 검증(수치 = 이슈원장 §O202). 🔴 GN_DW.MSTR 지표와 같은 표에서 합산 금지.
- 후: 개발(건) (#149) = **MSTR 정의**(사용자 결정): 이 사건의 MSTR 인정금액 ÷ 10,000(신규·재후원 = 미중단 후원사업·후원사업×월 합>0 행 금액 · 증액 = 감액 상계 순증액 · 그 밖 0). 원본 = FN_MM_SPNSR_DVLP B1·B2 + USP_F_MM_SPNSR_DVLP_SUM. 🟢 MSTR 전건 일치 검증(수치 =). 🔴 GN_DW.MSTR 지표와 같은 표에서 합산 금지.

### WIDE_MEMBER_EVENT.DVLP_DIV_NM 
- 전: FACT_MEMBER_EVENT.DVLP_DIV_NM — 개발구분명(MM015 라벨): 신규·증액·감액·재후원·후원중단. 코드 = DVLP_DIV_CD. MM015 는 폐지코드가 없고 실적재가 사전과 일치한다. 🔴🔴값 '후원중단' 은 EVENT_TYPE='STOP' 과 **동일 사건이 거의 전부 중복 존재**한다(동일 회원·일자) — 두 축을 합산하면 이중계상이다(O24 · 현업확인 대기).
- 후: FACT_MEMBER_EVENT.DVLP_DIV_NM — 개발구분명(MM015 라벨): 신규·증액·감액·재후원·후원중단. 코드 = DVLP_DIV_CD. MM015 는 폐지코드가 없고 실적재가 사전과 일치한다. 🔴🔴값 '후원중단' 은 EVENT_TYPE='STOP' 과 **동일 사건이 거의 전부 중복 존재**한다(동일 회원·일자) — 두 축을 합산하면 이중계상이다(현업확인 대기).

### WIDE_MEMBER_EVENT.MEMBER_AGE_BAND 
- 전: DIM_MEMBER.AGE_BAND — 연령대명 · **CM014** 라벨. 코드 = MEMBER_AGE_CD. 🔴빈 값은 두 갈래이며 **둘 다 개발약정 원천 행이 없는 경우**다 — 일시회원('ONCE')은 전건, 정기회원(FDRM)은 일부. 연령 개념은 존재하므로 '(해당없음)' 이 아니라 NULL 이고 미매핑도 없다. '미상' 으로 창작하지 않는다(R2-7-1). 🔴**연속형 나이가 아니다** — 평균·재구간화 금지(원천이 이미 구간화해 제공한다 · DEC-28). 🔴**현재 나이가 아니다** — 개발약정 시점 스냅샷이고 BRONZE 에 생년월일 축이 없어 시점정확 연령은 산출 불가다(O34). ⚠️연령 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것(P128).
- 후: DIM_MEMBER.AGE_BAND — 연령대명 · **CM014** 라벨. 코드 = MEMBER_AGE_CD. 🔴빈 값은 두 갈래이며 **둘 다 개발약정 원천 행이 없는 경우**다 — 일시회원('ONCE')은 전건, 정기회원(FDRM)은 일부. 연령 개념은 존재하므로 '(해당없음)' 이 아니라 NULL 이고 미매핑도 없다. '미상' 으로 창작하지 않는다. 🔴**연속형 나이가 아니다** — 평균·재구간화 금지(원천이 이미 구간화해 제공한다). 🔴**현재 나이가 아니다** — 개발약정 시점 스냅샷이고 BRONZE 에 생년월일 축이 없어 시점정확 연령은 산출 불가다. ⚠️연령 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것.

### WIDE_MEMBER_EVENT.MEMBER_AGE_CD 
- 전: DIM_MEMBER.AGE — 연령대 원천코드 raw. 코드그룹 **CM014(나이)**. 코드사전 = 1'10대 미만'·2'10대'·3'20대'·4'30대'·5'40대'·6'50대'·7'60대'·8'70대'·9'70대 이상'·10단체·11기업·12기타 · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AGE)에 **사전 전종이 등장**한다. 🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지. 구간은 우리가 만든 것이 아니라 원천이 이미 구간화해 제공한다(DEC-28). ⚠️사전 자체에 8'70대'와 9'70대 이상'이 **의미 중복**으로 공존한다 — 70대 이상 집계 시 두 코드를 함께 취할 것. ⚠️BRONZE 원천 컬럼 COMMENT '연령'(NUMBER)은 오류다. 라벨 = MEMBER_AGE_BAND. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.AGE — 연령대 원천코드 raw. 코드그룹 **CM014(나이)**. 코드사전 = 1'10대 미만'·2'10대'·3'20대'·4'30대'·5'40대'·6'50대'·7'60대'·8'70대'·9'70대 이상'·10단체·11기업·12기타 · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AGE)에 **사전 전종이 등장**한다. 🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지. 구간은 우리가 만든 것이 아니라 원천이 이미 구간화해 제공한다. ⚠️사전 자체에 8'70대'와 9'70대 이상'이 **의미 중복**으로 공존한다 — 70대 이상 집계 시 두 코드를 함께 취할 것. ⚠️BRONZE 원천 컬럼 COMMENT '연령'(NUMBER)은 오류다. 라벨 = MEMBER_AGE_BAND. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_MEMBER_EVENT.MEMBER_AREA_CD 
- 전: DIM_MEMBER.AREA_CD — 지역 원천코드 raw. 코드그룹 **CM018**. 코드사전 = (1서울·2경기·3인천·4강원·5대전·6충남·7충북·8광주·9전북·10전남·11대구·12경북·13경남·14울산·15부산·16제주·17기타·18세종) · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD)에 **사전 전종 + 라벨 없는 센티넬 '0'** 이 나타난다. ⚠️CM018 의 그룹명은 '신규시도구분'이지만 상세코드 값은 전부 시·도다(정본 공#131 지역정의가 약칭이라 정식명 그룹 CM011 이 아니다). 🔴**현재 거주지가 아니다** — 이 값은 그 버전 시점까지 최근 개발약정의 스냅샷이며 BRONZE 전체에 현주소 축이 없다(O34). 라벨 = MEMBER_REGION. 사건 시점 정확값은 WIDE_MEMBER_EVENT.AREA_CD_AT_EVENT. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.AREA_CD — 지역 원천코드 raw. 코드그룹 **CM018**. 코드사전 = (1서울·2경기·3인천·4강원·5대전·6충남·7충북·8광주·9전북·10전남·11대구·12경북·13경남·14울산·15부산·16제주·17기타·18세종) · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD)에 **사전 전종 + 라벨 없는 센티넬 '0'** 이 나타난다. ⚠️CM018 의 그룹명은 '신규시도구분'이지만 상세코드 값은 전부 시·도다(정본 공#131 지역정의가 약칭이라 정식명 그룹 CM011 이 아니다). 🔴**현재 거주지가 아니다** — 이 값은 그 버전 시점까지 최근 개발약정의 스냅샷이며 BRONZE 전체에 현주소 축이 없다. 라벨 = MEMBER_REGION. 사건 시점 정확값은 WIDE_MEMBER_EVENT.AREA_CD_AT_EVENT. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_MEMBER_EVENT.MEMBER_ENROLL_PATH_NAME 
- 전: DIM_MEMBER.ENROLL_PATH_NAME — 가입경로명(MM014 라벨). 코드 = JOIN_PATH_CD. 실제로 나타나는 라벨은 **홈페이지·CRM·모바일웹·외주콜센터·모바일앱·REG** 다 — 사전에는 희망TV·EDU 도 있으나 **실적재에 없으므로** 그 둘을 포함해 열거하면 거짓이다. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원('ONCE')은 가입경로 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원 중 가입경로 코드만 결손인 행은 **NULL** 이다(회원상태가 NULL 인 행과 같은 행이 아니다). '미상' 으로 채우지 않는다(R2-7-1). 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.ENROLL_PATH_NAME — 가입경로명(MM014 라벨). 코드 = JOIN_PATH_CD. 실제로 나타나는 라벨은 **홈페이지·CRM·모바일웹·외주콜센터·모바일앱·REG** 다 — 사전에는 희망TV·EDU 도 있으나 **실적재에 없으므로** 그 둘을 포함해 열거하면 거짓이다. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원('ONCE')은 가입경로 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원 중 가입경로 코드만 결손인 행은 **NULL** 이다(회원상태가 NULL 인 행과 같은 행이 아니다). '미상' 으로 채우지 않는다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_MEMBER_EVENT.MEMBER_GENDER_NAME 
- 전: DIM_MEMBER.GENDER_NAME — 성별 분석 라벨(정본 공#130). 코드그룹 **CM017(회원특성(성별))**. CM017 은 CM013 과 **코드 도메인이 동일(1~8)한 재라벨 그룹**이며 국내/외국인 구분을 지운다 — 1남자·2여자·3남자·4여자·5기타·6단체·7기업·8기타 ⇒ **서로 다른 코드가 같은 라벨로 합쳐진다**(남자/여자/기타/단체/기업). 정본 공#130 값정의와 일치. ⚠️CM017 은 정본 컬럼정의서가 어떤 컬럼에도 지정하지 않은 그룹이다(현업 확인 대상). ⚠️종전 하드코딩 '여성/남성/미상'은 라벨을 축약하고 법인·단체를 '미상'으로 오라벨했다(O26 교정). 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.GENDER_NAME — 성별 분석 라벨(정본 공#130). 코드그룹 **CM017(회원특성(성별))**. CM017 은 CM013 과 **코드 도메인이 동일(1~8)한 재라벨 그룹**이며 국내/외국인 구분을 지운다 — 1남자·2여자·3남자·4여자·5기타·6단체·7기업·8기타 ⇒ **서로 다른 코드가 같은 라벨로 합쳐진다**(남자/여자/기타/단체/기업). 정본 공#130 값정의와 일치. ⚠️CM017 은 정본 컬럼정의서가 어떤 컬럼에도 지정하지 않은 그룹이다(현업 확인 대상). ⚠️종전 하드코딩 '여성/남성/미상'은 라벨을 축약하고 법인·단체를 '미상'으로 오라벨했다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_MEMBER_EVENT.MEMBER_REGION 
- 전: DIM_MEMBER.REGION — 지역명(정본 공#131) · **CM018** 약칭 라벨. 코드 = MEMBER_AREA_CD. 🔴빈 값이 세 갈래다 — ①일시회원(MEMBER_TYPE='ONCE')은 개발약정 **행 자체가 없어** NULL 이다(지역 개념은 존재하므로 '(해당없음)' 이 아니다) ②정기회원(FDRM) 중 개발약정이 없는 행도 NULL ③센티넬 코드 '0' 은 사전에 라벨이 없어 NULL. 🟢미매핑(코드는 있는데 사전에 없음)은 없다. '미상' 으로 창작하지 않는다(R2-7-1). 🔴**현재 거주지가 아니다** — 개발약정 시점 스냅샷이며 BRONZE 에 현주소 축이 없다(O34). ⚠️지역 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것 — ONCE 를 분모에 넣으면 채움률이 조용히 낮아진다(P128).
- 후: DIM_MEMBER.REGION — 지역명(정본 공#131) · **CM018** 약칭 라벨. 코드 = MEMBER_AREA_CD. 🔴빈 값이 세 갈래다 — ①일시회원(MEMBER_TYPE='ONCE')은 개발약정 **행 자체가 없어** NULL 이다(지역 개념은 존재하므로 '(해당없음)' 이 아니다) ②정기회원(FDRM) 중 개발약정이 없는 행도 NULL ③센티넬 코드 '0' 은 사전에 라벨이 없어 NULL. 🟢미매핑(코드는 있는데 사전에 없음)은 없다. '미상' 으로 창작하지 않는다. 🔴**현재 거주지가 아니다** — 개발약정 시점 스냅샷이며 BRONZE 에 현주소 축이 없다. ⚠️지역 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것 — ONCE 를 분모에 넣으면 채움률이 조용히 낮아진다.

### WIDE_MEMBER_EVENT.MEMBER_STATUS_NAME 
- 전: DIM_MEMBER.MEMBER_STATUS_NAME — 회원상태명(MM010 라벨, 정본 공#132). 코드 = MBER_STAT_CD. MM010 은 **폐지코드가 없고 실적재가 사전과 일치**한다 ⇒ 사전 조인만으로 전건 라벨화된다(하드코딩 금지 P31). 값 = 활동회원 / 신규미납1~5 / 장기미납1~5 / 후원중단. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원(DIM_MEMBER.MEMBER_TYPE='ONCE')은 회원상태 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원(FDRM) 중 원천 상태코드 자체가 결손인 행만 **NULL** 이다. 두 사건을 '미상' 같은 한 값으로 뭉개지 않는다(R2-7-1). ⚠️미납 단계(1~5)는 **경과 차수**이며 금액 규모가 아니다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.MEMBER_STATUS_NAME — 회원상태명(MM010 라벨, 정본 공#132). 코드 = MBER_STAT_CD. MM010 은 **폐지코드가 없고 실적재가 사전과 일치**한다 ⇒ 사전 조인만으로 전건 라벨화된다(하드코딩 금지). 값 = 활동회원 / 신규미납1~5 / 장기미납1~5 / 후원중단. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원(DIM_MEMBER.MEMBER_TYPE='ONCE')은 회원상태 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원(FDRM) 중 원천 상태코드 자체가 결손인 행만 **NULL** 이다. 두 사건을 '미상' 같은 한 값으로 뭉개지 않는다. ⚠️미납 단계(1~5)는 **경과 차수**이며 금액 규모가 아니다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_MEMBER_EVENT.MEMBER_TYPE_NAME 
- 전: DIM_MEMBER.MEMBER_TYPE_NAME — 회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. MM018 은 폐지코드가 없고 실적재가 사전과 일치한다. 🟢빈 값이 없는 축이다 — 센티넬 '(해당없음)'·NULL 모두 없고 전건 라벨화된다. 앞으로 사전에 없는 코드가 인입되면 **NULL 로 드러나며** '미상' 같은 값으로 덮지 않는다(R2-7-1). 🔴이름이 비슷한 DIM_MEMBER.MEMBER_TYPE(=FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다** — 다른 축이다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.MEMBER_TYPE_NAME — 회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. MM018 은 폐지코드가 없고 실적재가 사전과 일치한다. 🟢빈 값이 없는 축이다 — 센티넬 '(해당없음)'·NULL 모두 없고 전건 라벨화된다. 앞으로 사전에 없는 코드가 인입되면 **NULL 로 드러나며** '미상' 같은 값으로 덮지 않는다. 🔴이름이 비슷한 DIM_MEMBER.MEMBER_TYPE(=FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다** — 다른 축이다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_MEMBER_EVENT.NEW_EXISTING_FLAG (덮어쓰기)
- 전: 신규기존 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_EVENT.NEW_EXISTING_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.
- 후: 신규기존.

### WIDE_MEMBER_EVENT.ORG_CORP 
- 전: DIM_ORG.CORP — 법인 (#114). 🔴DIM_ORG 는 **SCD1**(DEC-2)이라 as-was 가 아니다 — 조직 개편 시 과거 사건에도 **현재 조직명**이 붙는다(조직 변경이력 원천·as-was 요구가 없어 SCD1 로 확정). 🔴🔴[O51-D 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.CORP`. `DIM_ORG` 는 **DEPARTMENT 만 채워져 있고 CORP·DIVISION·TEAM 은 전건 비어 있다.** 부서 코드에서 상위 계층을 유도하는 규칙이 미확정이다(CONF-4) ⇒ **조직 계층 분석은 현재 불가**하고 부서 단위까지만 된다. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_ORG.CORP — 법인 (#114). 🔴DIM_ORG 는 **SCD1**이라 as-was 가 아니다 — 조직 개편 시 과거 사건에도 **현재 조직명**이 붙는다(조직 변경이력 원천·as-was 요구가 없어 SCD1 로 확정). 🔴🔴 **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.CORP`. `DIM_ORG` 는 **DEPARTMENT 만 채워져 있고 CORP·DIVISION·TEAM 은 전건 비어 있다.** 부서 코드에서 상위 계층을 유도하는 규칙이 미확정이다 ⇒ **조직 계층 분석은 현재 불가**하고 부서 단위까지만 된다.

### WIDE_MEMBER_EVENT.ORG_DEPARTMENT 
- 전: DIM_ORG.DEPARTMENT — 부서 (#116). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴「부서」는 축이 둘이다 — 이 컬럼은 **사건 부서**이고 획득 부서는 DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT 다(O34). 🔴[O51-D 실측] `'(미매핑)'` 이 **다수**다 — 중단원천 행은 부서가 없다. 부서별 집계 시 이 그룹이 상위권 규모로 나타나며 **실재 부서가 아니다.** 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_ORG.DEPARTMENT — 부서 (#116). 🔴SCD1 — current-value 이며 as-was 가 아니다. 🔴🔴「부서」는 축이 둘이다 — 이 컬럼은 **사건 부서**이고 획득 부서는 DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT 다. 🔴 `'(미매핑)'` 이 **다수**다 — 중단원천 행은 부서가 없다. 부서별 집계 시 이 그룹이 상위권 규모로 나타나며 **실재 부서가 아니다.**

### WIDE_MEMBER_EVENT.ORG_DIVISION 
- 전: DIM_ORG.DIVISION — 본부/지부 (#115). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴[O51-D 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.DIVISION`. `DIM_ORG` 는 **DEPARTMENT 만 채워져 있고 CORP·DIVISION·TEAM 은 전건 비어 있다.** 부서 코드에서 상위 계층을 유도하는 규칙이 미확정이다(CONF-4) ⇒ **조직 계층 분석은 현재 불가**하고 부서 단위까지만 된다. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_ORG.DIVISION — 본부/지부 (#115). 🔴SCD1 — current-value 이며 as-was 가 아니다. 🔴🔴 **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.DIVISION`. `DIM_ORG` 는 **DEPARTMENT 만 채워져 있고 CORP·DIVISION·TEAM 은 전건 비어 있다.** 부서 코드에서 상위 계층을 유도하는 규칙이 미확정이다 ⇒ **조직 계층 분석은 현재 불가**하고 부서 단위까지만 된다.

### WIDE_MEMBER_EVENT.ORG_TEAM 
- 전: DIM_ORG.TEAM — 팀. 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴[O51-D 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.TEAM`. `DIM_ORG` 는 **DEPARTMENT 만 채워져 있고 CORP·DIVISION·TEAM 은 전건 비어 있다.** 부서 코드에서 상위 계층을 유도하는 규칙이 미확정이다(CONF-4) ⇒ **조직 계층 분석은 현재 불가**하고 부서 단위까지만 된다. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_ORG.TEAM — 팀. 🔴SCD1 — current-value 이며 as-was 가 아니다. 🔴🔴 **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.TEAM`. `DIM_ORG` 는 **DEPARTMENT 만 채워져 있고 CORP·DIVISION·TEAM 은 전건 비어 있다.** 부서 코드에서 상위 계층을 유도하는 규칙이 미확정이다 ⇒ **조직 계층 분석은 현재 불가**하고 부서 단위까지만 된다.

### WIDE_MEMBER_EVENT.REGION_AT_EVENT 
- 전: FACT_MEMBER_EVENT.REGION_AT_EVENT — **사건 시점** 지역명(CM018 약칭 라벨, 지표 공#131). 코드 = AREA_CD_AT_EVENT. ⚠️센티넬 코드 '0' 은 사전에 라벨이 없어 NULL 이다 — '미상'으로 창작하지 않는다. ⚠️**현재 거주지가 아니다**(O34). 🔴MEMBER_REGION(현재버전 스냅샷)과 값이 다를 수 있다. 중단원천 행은 NULL. 🟢이 뷰 안에 캠페인 축이 함께 있어 지역 × 캠페인 교차가 성립한다.
- 후: FACT_MEMBER_EVENT.REGION_AT_EVENT — **사건 시점** 지역명(CM018 약칭 라벨, 지표 공#131). 코드 = AREA_CD_AT_EVENT. ⚠️센티넬 코드 '0' 은 사전에 라벨이 없어 NULL 이다 — '미상'으로 창작하지 않는다. ⚠️**현재 거주지가 아니다**. 🔴MEMBER_REGION(현재버전 스냅샷)과 값이 다를 수 있다. 중단원천 행은 NULL. 🟢이 뷰 안에 캠페인 축이 함께 있어 지역 × 캠페인 교차가 성립한다.

### WIDE_MEMBER_EVENT.SPNSR_AMT 
- 전: FACT_MEMBER_EVENT.SPNSR_AMT — 후원금액(원) raw. 원천 TM_MM_FDRM_MBER_DVLP_AMT.SPNSR_AMT 무변환 전파. 🔴감액·후원중단 사건은 **음수**다 — 무조건 SUM 하면 개발금액이 상계된다. 🔴정본 공#38 감액(건)·#151 증액(건)이 **금액을 만원 단위로 나눈 값**이라는 규약이므로 원금액을 보존한다(설계 §1·CONF-2) — 이 컬럼을 그대로 '건수'로 쓰지 말 것. ⚠️중단원천 행은 NULL.
- 후: FACT_MEMBER_EVENT.SPNSR_AMT — 후원금액(원) raw. 원천 TM_MM_FDRM_MBER_DVLP_AMT.SPNSR_AMT 무변환 전파. 🔴감액·후원중단 사건은 **음수**다 — 무조건 SUM 하면 개발금액이 상계된다. 🔴정본 공#38 감액(건)·#151 증액(건)이 **금액을 만원 단위로 나눈 값**이라는 규약이므로 원금액을 보존한다(설계 §1) — 이 컬럼을 그대로 '건수'로 쓰지 말 것. ⚠️중단원천 행은 NULL.

### WIDE_MEMBER_EVENT.SPONSORSHIP_CPR_DIV_CD 
- 전: [2026-10-06 O202 · 사용자 결정] **후원사업 법인구분** 원천코드(코드그룹 CM019: A=통합 · I=사단 · S=사복). MSTR 법인 축과 같은 원천(TM_CM_SPNSR_BSNS_INFO.CPR_DIV_CD)이다. 🔴 「법인·사단·사복」 질의의 **기본 축** — CAMPAIGN_CPR_DIV_*(세부캠페인 법인)·ORG_CORP(조직 법인)와 다른 축이다. ⚠️ STOP 행은 후원사업 미배선분이 SK=0 이라 NULL 이다.
- 후: **후원사업 법인구분** 원천코드(코드그룹 CM019: A=통합 · I=사단 · S=사복). MSTR 법인 축과 같은 원천(TM_CM_SPNSR_BSNS_INFO.CPR_DIV_CD)이다. 🔴 「법인·사단·사복」 질의의 **기본 축** — CAMPAIGN_CPR_DIV_*(세부캠페인 법인)·ORG_CORP(조직 법인)와 다른 축이다. ⚠️ STOP 행은 후원사업 미배선분이 SK=0 이라 NULL 이다.

### WIDE_MEMBER_EVENT.SPONSORSHIP_CPR_DIV_NM 
- 전: SPONSORSHIP_CPR_DIV_CD 를 CM019 로 해소한 라벨(통합/사단/사복). 「사단법인」=사단 · 「사회복지법인」=사복. 🔴 법인 질의 기본 축(O202) — 세부캠페인 법인(CAMPAIGN_CPR_DIV_NM)으로 답하지 마라.
- 후: SPONSORSHIP_CPR_DIV_CD 를 CM019 로 해소한 라벨(통합/사단/사복). 「사단법인」=사단 · 「사회복지법인」=사복. 🔴 법인 질의 기본 축 — 세부캠페인 법인(CAMPAIGN_CPR_DIV_NM)으로 답하지 마라.

### WIDE_MEMBER_EVENT.SPONSORSHIP_DIV_NAME 
- 전: [2026-08-19 O89] 후원사업 분류 **최상위** — 정기일시후원구분 라벨(코드사전 CM035): 정기후원 · 일시후원. 3계층 = DIV_NAME → GROUP_NAME → SPONSORSHIP_NAME. 🟢DEV 브랜치는 O45 로 배선돼 **분류별 개발실적 집계가 된다.** ⚠️STOP 브랜치는 `SPONSORSHIP_SK` 센티넬 0 이라 `'(미매핑)'` 이다 — 중단 분해는 개발원천 코드5 경로를 쓸 것(DEC-32 철회·O47). 🔴DEV·STOP 을 합산하면 이중계상이다(O24).
- 후: 후원사업 분류 **최상위** — 정기일시후원구분 라벨(코드사전 CM035): 정기후원 · 일시후원. 3계층 = DIV_NAME → GROUP_NAME → SPONSORSHIP_NAME. 🟢DEV 브랜치는 로 배선돼 **분류별 개발실적 집계가 된다.** ⚠️STOP 브랜치는 `SPONSORSHIP_SK` 센티넬 0 이라 `'(미매핑)'` 이다 — 중단 분해는 개발원천 코드5 경로를 쓸 것(철회). 🔴DEV·STOP 을 합산하면 이중계상이다.

### WIDE_MEMBER_EVENT.SPONSORSHIP_GROUP_NAME 
- 전: [2026-08-19 O89] 후원사업 분류 **중위** — SPONSORSHIP_ABBR(코드)을 코드사전 CM003(후원약칭)으로 해소한 라벨: 국내 · 결연 · 해외구호 · 북한 · 기타 · 해외 · 선물금(미사용). 사업수 17/1/6/3/21/2 = 50. 🔴🔴**이 컬럼 단독으로 「해외」를 집계하지 말 것** — 해외구호(3)와 해외(6)가 갈라지고 6은 정기일시=일시후원에서만 나타난다 ⇒ 정확한 분류축은 **(DIV_NAME, GROUP_NAME) 쌍**이다. ⚠️STOP 브랜치 센티넬은 위 DIV_NAME 주석과 동일.
- 후: 후원사업 분류 **중위** — SPONSORSHIP_ABBR(코드)을 코드사전 CM003(후원약칭)으로 해소한 라벨: 국내 · 결연 · 해외구호 · 북한 · 기타 · 해외 · 선물금(미사용). 사업수 17/1/6/3/21/2 = 50. 🔴🔴**이 컬럼 단독으로 「해외」를 집계하지 말 것** — 해외구호(3)와 해외(6)가 갈라지고 6은 정기일시=일시후원에서만 나타난다 ⇒ 정확한 분류축은 **(DIV_NAME, GROUP_NAME) 쌍**이다. ⚠️STOP 브랜치 센티넬은 위 DIV_NAME 주석과 동일.

### WIDE_MEMBER_EVENT.STOP_CHANNEL_NM 
- 전: FACT_MEMBER_EVENT.STOP_CHANNEL_NM — 중단경로명. 코드그룹 **MM287(중단경로)**. 코드 = STOP_CHANNEL. 코드사전 = 1 SYSTEM · 2 CRM · 3 홈페이지 · 실적재에 **사전 전종이 등장**한다. ⚠️'SYSTEM' 은 배치가 자동 처리한 중단(장기미납 등)이며 회원의 능동적 해지 채널이 아니다 — 채널 분석 시 분리할 것. ⚠️개발원천 행은 개념 부재로 NULL. ⚠️215지표 밖 — 현업 수요 확인 대상(O25).
- 후: FACT_MEMBER_EVENT.STOP_CHANNEL_NM — 중단경로명. 코드그룹 **MM287(중단경로)**. 코드 = STOP_CHANNEL. 코드사전 = 1 SYSTEM · 2 CRM · 3 홈페이지 · 실적재에 **사전 전종이 등장**한다. ⚠️'SYSTEM' 은 배치가 자동 처리한 중단(장기미납 등)이며 회원의 능동적 해지 채널이 아니다 — 채널 분석 시 분리할 것. ⚠️개발원천 행은 개념 부재로 NULL. ⚠️215지표 밖 — 현업 수요 확인 대상.

### WIDE_MEMBER_FEE.ACQ_AGE_BAND 
- 전: 획득 시점 연령대명(**CM014** 라벨) ← FACT_MEMBER_COHORT.ACQ_AGE_BAND. 코드 = FMC.ACQ_AGE_CD. 🔴**현재 나이가 아니다** — BRONZE 에 생년월일이 없어 현재 연령은 산출 불가(O34). 🔴연속형이 아니므로 평균·재구간화 금지. ✅'10대 미만'이 상위인 것은 오류가 아니다(편지쓰기대회 계열 아동 모집 캠페인) — 결측·기본값 오염으로 설명하지 말 것(O34-B). ⚠️사전에 '70대'·'70대 이상'이 의미 중복으로 공존한다.
- 후: 획득 시점 연령대명(**CM014** 라벨) ← FACT_MEMBER_COHORT.ACQ_AGE_BAND. 코드 = FMC.ACQ_AGE_CD. 🔴**현재 나이가 아니다** — BRONZE 에 생년월일이 없어 현재 연령은 산출 불가. 🔴연속형이 아니므로 평균·재구간화 금지. ✅'10대 미만'이 상위인 것은 오류가 아니다(편지쓰기대회 계열 아동 모집 캠페인) — 결측·기본값 오염으로 설명하지 말 것. ⚠️사전에 '70대'·'70대 이상'이 의미 중복으로 공존한다.

### WIDE_MEMBER_FEE.ACQ_BIZ_CASE_TYPE 
- 전: [O205] 획득 캠페인의 사업사례구분 라벨 ← DIM_MEMBER_ACQUISITION.ACQ_BIZ_CASE_TYPE. 🔴획득 시점 동결값.
- 후: 획득 캠페인의 사업사례구분 라벨 ← DIM_MEMBER_ACQUISITION.ACQ_BIZ_CASE_TYPE. 🔴획득 시점 동결값.

### WIDE_MEMBER_FEE.ACQ_CAMPAIGN_SK 
- 전: DIM_MEMBER_ACQUISITION.ACQ_CAMPAIGN_SK — **획득(가입) 캠페인** 대리키(FK→DIM_CAMPAIGN). 0=미매핑. 🔴회비를 낸 캠페인이 아니라 **이 회원을 데려온** 캠페인이다 — FMM/FMF 의 회비 자체에는 캠페인 축이 없어(전건 센티넬) 획득 시점 규칙으로 귀속시킨 것이다(O45·O8 우회). 🔴LEFT JOIN 필수 — 개발 사건이 없는 회원은 NULL 이다. 🔴🔴손실 규모는 **회원 기준으로 읽어야** 한다 — INNER 조인이 잃는 것은 회원이며, 행 가중 비율은 손실을 크게 축소해 보이게 한다(O51-D 정정 · 규모는 이슈원장 §O51-D).
- 후: DIM_MEMBER_ACQUISITION.ACQ_CAMPAIGN_SK — **획득(가입) 캠페인** 대리키(FK→DIM_CAMPAIGN). 0=미매핑. 🔴회비를 낸 캠페인이 아니라 **이 회원을 데려온** 캠페인이다 — FMM/FMF 의 회비 자체에는 캠페인 축이 없어(전건 센티넬) 획득 시점 규칙으로 귀속시킨 것이다(우회). 🔴LEFT JOIN 필수 — 개발 사건이 없는 회원은 NULL 이다. 🔴🔴손실 규모는 **회원 기준으로 읽어야** 한다 — INNER 조인이 잃는 것은 회원이며, 행 가중 비율은 손실을 크게 축소해 보이게 한다(.

### WIDE_MEMBER_FEE.ACQ_CAMPAIGN_TYPE 
- 전: [O205] 획득 캠페인의 캠페인카테고리(=주요캠페인) ← DIM_MEMBER_ACQUISITION.ACQ_CAMPAIGN_TYPE. 🔴**획득 시점 적재 동결값**이다 — WIDE_MEMBER_EVENT 의 사건 시점 캠페인카테고리와 다른 축이다. ML 회비 예측(캠페인카테고리)과 이름이 같아도 실적·예측을 한 표에 합산하지 않는다.
- 후: 획득 캠페인의 캠페인카테고리(=주요캠페인) ← DIM_MEMBER_ACQUISITION.ACQ_CAMPAIGN_TYPE. 🔴**획득 시점 적재 동결값**이다 — WIDE_MEMBER_EVENT 의 사건 시점 캠페인카테고리와 다른 축이다. ML 회비 예측(캠페인카테고리)과 이름이 같아도 실적·예측을 한 표에 합산하지 않는다.

### WIDE_MEMBER_FEE.ACQ_CMMN_BRND_NM 
- 전: [O205] 획득 캠페인의 공통브랜드(MM297 라벨) ← DIM_MEMBER_ACQUISITION.ACQ_CMMN_BRND_NM. ⚠️ACQ_BRAND(캠페인 브랜드)와 다른 축이다. 🔴획득 시점 동결값.
- 후: 획득 캠페인의 공통브랜드(MM297 라벨) ← DIM_MEMBER_ACQUISITION.ACQ_CMMN_BRND_NM. ⚠️ACQ_BRAND(캠페인 브랜드)와 다른 축이다. 🔴획득 시점 동결값.

### WIDE_MEMBER_FEE.ACQ_CPR_DIV_NM 
- 전: [O205] 획득 세부캠페인의 법인구분 라벨(CM019 통합/사단/사복) ← DIM_MEMBER_ACQUISITION.ACQ_CPR_DIV_NM. 🔴조직 계층 법인(ORG_CORP · 산출 불가)과 다른 축이다.
- 후: 획득 세부캠페인의 법인구분 라벨(CM019 통합/사단/사복) ← DIM_MEMBER_ACQUISITION.ACQ_CPR_DIV_NM. 🔴조직 계층 법인(ORG_CORP · 산출 불가)과 다른 축이다.

### WIDE_MEMBER_FEE.ACQ_DEPARTMENT 
- 전: 🔴**획득(최초개발) 시점 부서**다. 개발실적보고의 「부서」(=사건 부서)와 다르다 — 사건 부서는 WIDE_MEMBER_EVENT.ORG_DEPARTMENT 를 쓴다(O34 _AT_PLEDGE/_AT_EVENT 규약의 재적용)
- 후: 🔴**획득(최초개발) 시점 부서**다. 개발실적보고의 「부서」(=사건 부서)와 다르다 — 사건 부서는 WIDE_MEMBER_EVENT.ORG_DEPARTMENT 를 쓴다(_AT_PLEDGE/_AT_EVENT 규약의 재적용)

### WIDE_MEMBER_FEE.ACQ_DOMESTIC_OVERSEAS 
- 전: [O205] 획득 캠페인의 국내해외 구분 라벨 ← DIM_MEMBER_ACQUISITION.ACQ_DOMESTIC_OVERSEAS. 🔴획득 시점 동결값.
- 후: 획득 캠페인의 국내해외 구분 라벨 ← DIM_MEMBER_ACQUISITION.ACQ_DOMESTIC_OVERSEAS. 🔴획득 시점 동결값.

### WIDE_MEMBER_FEE.ACQ_INFLOW_PATH 
- 전: [O205] 획득 캠페인의 개발인입경로(MM293 라벨) ← DIM_MEMBER_ACQUISITION.ACQ_INFLOW_PATH. 🔴획득 시점 동결값.
- 후: 획득 캠페인의 개발인입경로(MM293 라벨) ← DIM_MEMBER_ACQUISITION.ACQ_INFLOW_PATH. 🔴획득 시점 동결값.

### WIDE_MEMBER_FEE.ACQ_MARKETING_CAMPAIGN 
- 전: 획득 캠페인의 마케팅캠페인(O45 conformed 축). 광고비와 결합할 때 이 축을 쓴다 — 개발캠페인 단위로 내리면 광고비가 복제된다(팬아웃)
- 후: 획득 캠페인의 마케팅캠페인(conformed 축). 광고비와 결합할 때 이 축을 쓴다 — 개발캠페인 단위로 내리면 광고비가 복제된다(팬아웃)

### WIDE_MEMBER_FEE.ACQ_MKTG_UTM_NM 
- 전: [O205] 획득 캠페인의 UTM 라벨 ← DIM_MEMBER_ACQUISITION.ACQ_MKTG_UTM_NM. ⚠️채움이 낮다(코드사전 미등재분은 NULL · 결측이 아니라 미등재) ⇒ UTM 별 합계는 전체보다 작다.
- 후: 획득 캠페인의 UTM 라벨 ← DIM_MEMBER_ACQUISITION.ACQ_MKTG_UTM_NM. ⚠️채움이 낮다(코드사전 미등재분은 NULL · 결측이 아니라 미등재) ⇒ UTM 별 합계는 전체보다 작다.

### WIDE_MEMBER_FEE.ACQ_ORG_SK 
- 전: DIM_MEMBER_ACQUISITION.ACQ_ORG_SK — **획득 시점 담당조직** 대리키(FK→DIM_ORG). 0=미매핑. 🔴「현재 소속」이 아니다. 🔴🔴「부서」는 축이 둘이다 — 개발실적보고의 부서 = **사건 부서**(WIDE_MEMBER_EVENT.ORG_*) · 연간분석(회비)의 부서 = **획득 부서**(이 축). 두 값은 다르며 이름으로 구분되지 않으면 소비 측이 조용히 틀린다(O34 규약).
- 후: DIM_MEMBER_ACQUISITION.ACQ_ORG_SK — **획득 시점 담당조직** 대리키(FK→DIM_ORG). 0=미매핑. 🔴「현재 소속」이 아니다. 🔴🔴「부서」는 축이 둘이다 — 개발실적보고의 부서 = **사건 부서**(WIDE_MEMBER_EVENT.ORG_*) · 연간분석(회비)의 부서 = **획득 부서**(이 축). 두 값은 다르며 이름으로 구분되지 않으면 소비 측이 조용히 틀린다(규약).

### WIDE_MEMBER_FEE.ACQ_PROMO_METHOD_NAME 
- 전: 획득 캠페인의 홍보방법명 ← DIM_CAMPAIGN.PROMO_METHOD_NAME. 코드그룹 **CM008(홍보방법)**. [O51-D BRONZE 실측] CM008 사전은 100종을 넘는 대형 그룹이며 채널·랜딩·매체가 한 축에 섞여 있다(PC캠페인-홈페이지·M배너광고(DA)·TM·TS·가두·교회개발·직원개발·서신 등) — 🔴상위 집계가 필요하면 이 축이 아니라 개발인입경로(MM293)를 쓴다.
- 후: 획득 캠페인의 홍보방법명 ← DIM_CAMPAIGN.PROMO_METHOD_NAME. 코드그룹 **CM008(홍보방법)**. CM008 사전은 100종을 넘는 대형 그룹이며 채널·랜딩·매체가 한 축에 섞여 있다(PC캠페인-홈페이지·M배너광고(DA)·TM·TS·가두·교회개발·직원개발·서신 등) — 🔴상위 집계가 필요하면 이 축이 아니라 개발인입경로(MM293)를 쓴다.

### WIDE_MEMBER_FEE.ACQ_REGION 
- 전: 획득 시점 지역명(**CM018** 약칭 라벨) ← FACT_MEMBER_COHORT.ACQ_REGION. 코드 = FMC.ACQ_AREA_CD. 🔴**현재 거주지가 아니다** — BRONZE 에 현주소 축이 없다(O34). ⚠️센티넬 코드 '0'(개발약정 실적재에 존재)은 사전에 라벨이 없어 NULL 이며 '미상'으로 창작하지 않는다.
- 후: 획득 시점 지역명(**CM018** 약칭 라벨) ← FACT_MEMBER_COHORT.ACQ_REGION. 코드 = FMC.ACQ_AREA_CD. 🔴**현재 거주지가 아니다** — BRONZE 에 현주소 축이 없다. ⚠️센티넬 코드 '0'(개발약정 실적재에 존재)은 사전에 라벨이 없어 NULL 이며 '미상'으로 창작하지 않는다.

### WIDE_MEMBER_FEE.ACQ_SPNSR_DIV_NM 
- 전: [O205] 획득 세부캠페인의 후원구분 라벨(CM035 정기후원/일시후원) ← DIM_MEMBER_ACQUISITION.ACQ_SPNSR_DIV_NM. ⚠️SPONSORSHIP_DIV_NAME(납입 대상 후원사업의 정기일시구분)과 다른 축이다.
- 후: 획득 세부캠페인의 후원구분 라벨(CM035 정기후원/일시후원) ← DIM_MEMBER_ACQUISITION.ACQ_SPNSR_DIV_NM. ⚠️SPONSORSHIP_DIV_NAME(납입 대상 후원사업의 정기일시구분)과 다른 축이다.

### WIDE_MEMBER_FEE.BILLED_AMT 
- 전: 청구액(원) = SUM(RQEST_AMT). 🔴FMM 과 **동일한 식**이므로 두 팩트의 전체 합계가 일치해야 한다 — 이 일치가 검증 관문이다(GATE-D · 기준값은 이슈원장 §O45). 🔴🔴WIDE_MEMBER_MONTHLY 의 회비 measure 와 **같은 표에서 합산 금지**(DEC-31) — 동일 원천을 다른 grain 으로 담은 형제 팩트라 이중계상된다.
- 후: 청구액(원) = SUM(RQEST_AMT). 🔴FMM 과 **동일한 식**이므로 두 팩트의 전체 합계가 일치해야 한다 — 이 일치가 검증 관문이다(기준값은). 🔴🔴WIDE_MEMBER_MONTHLY 의 회비 measure 와 **같은 표에서 합산 금지** — 동일 원천을 다른 grain 으로 담은 형제 팩트라 이중계상된다.

### WIDE_MEMBER_FEE.BILLING_ROWS 
- 전: 집계된 원천 회비행 수. 🔴금액이 아니다 — 「건수」로 쓰지 말 것(정본 (건) 정의는 CONF-2 미결)
- 후: 집계된 원천 회비행 수. 🔴금액이 아니다 — 「건수」로 쓰지 말 것(정본 (건) 정의는 미결)

### WIDE_MEMBER_FEE.FEE_DIV_CD 
- 전: 회비구분 코드 raw. 코드그룹 **PM010(회비구분)**. [O51-D BRONZE 실측] 사전 4종이며 **숫자가 아니라 알파벳 코드**다 — E정기·I일시·U긴급구호·G선물금. 실적재에 **사전 전종이 등장**하며 **E(정기)가 압도적**이다. 🔴기부금 행은 원천에 이 컬럼이 없어 NULL 이다 — **결측이 아니라 해당없음**(P21). 라벨 = FEE_DIV_NAME.
- 후: 회비구분 코드 raw. 코드그룹 **PM010(회비구분)**. 사전 4종이며 **숫자가 아니라 알파벳 코드**다 — E정기·I일시·U긴급구호·G선물금. 실적재에 **사전 전종이 등장**하며 **E(정기)가 압도적**이다. 🔴기부금 행은 원천에 이 컬럼이 없어 NULL 이다 — **결측이 아니라 해당없음**. 라벨 = FEE_DIV_NAME.

### WIDE_MEMBER_FEE.FEE_DIV_NAME 
- 전: 회비구분(PM010 실측 확정): 정기·선물금·일시·긴급구호. 🔴기부금 행은 원천이 NULL 이다 — 결측이 아니라 해당없음(P21)
- 후: 회비구분(PM010 실측 확정): 정기·선물금·일시·긴급구호. 🔴기부금 행은 원천이 NULL 이다 — 결측이 아니라 해당없음

### WIDE_MEMBER_FEE.GENDER_NAME 
- 전: DIM_MEMBER.GENDER_NAME — 성별 분석 라벨(정본 공#130). 코드그룹 **CM017(회원특성(성별))**. [O51-D BRONZE 실측] CM017 은 CM013 과 코드 도메인이 동일(1~8)한 재라벨 그룹이며 국내/외국인 구분을 지운다 ⇒ **라벨 5종**(남자/여자/기타/단체/기업). 🔴이 뷰에는 SEX_NM(국내·외국인 축)이 없다 — 그 축이 필요하면 WIDE_MEMBER_MONTHLY 를 쓴다. 🔴현재버전 스냅샷이다.
- 후: DIM_MEMBER.GENDER_NAME — 성별 분석 라벨(정본 공#130). 코드그룹 **CM017(회원특성(성별))**. CM017 은 CM013 과 코드 도메인이 동일(1~8)한 재라벨 그룹이며 국내/외국인 구분을 지운다 ⇒ **라벨 5종**(남자/여자/기타/단체/기업). 🔴이 뷰에는 SEX_NM(국내·외국인 축)이 없다 — 그 축이 필요하면 WIDE_MEMBER_MONTHLY 를 쓴다. 🔴현재버전 스냅샷이다.

### WIDE_MEMBER_FEE.MEMBER_DK 
- 전: 회원 자연키(= 팩트 조인키, FK→DIM_MEMBER.MEMBER_DK). 🔴VARCHAR(10) 규약(O12/AC-1) — 원천 MBER_NO 최대길이 9 실측. 🔴기부금 지류(BRONZE_CRM.TM_PM_DNTN_DTLS)에는 MBER_NO 컬럼이 **아예 없다**(회원키가 ONCE_MBER_NO) — 기부금 행의 회원 축은 구조적으로 부재하다. ⚠️FMM 규약과 일치시키기 위해 MBER_NO IS NOT NULL 을 적용한다(O45-C).
- 후: 회원 자연키(= 팩트 조인키, FK→DIM_MEMBER.MEMBER_DK). 🔴VARCHAR(10) 규약 — 원천 MBER_NO 최대길이 9 실측. 🔴기부금 지류(BRONZE_CRM.TM_PM_DNTN_DTLS)에는 MBER_NO 컬럼이 **아예 없다**(회원키가 ONCE_MBER_NO) — 기부금 행의 회원 축은 구조적으로 부재하다. ⚠️FMM 규약과 일치시키기 위해 MBER_NO IS NOT NULL 을 적용한다.

### WIDE_MEMBER_FEE.MEMBER_STATUS_NAME 
- 전: DIM_MEMBER.MEMBER_STATUS_NAME — 회원상태명(MM010 라벨). 코드 = MBER_STAT_CD. 값 = 활동회원 / 신규미납1~5 / 장기미납1~5 / 후원중단. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원(DIM_MEMBER.MEMBER_TYPE='ONCE')은 회원상태 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원(FDRM) 중 원천 상태코드 자체가 결손인 행만 **NULL** 이다. 두 사건을 '미상' 같은 한 값으로 뭉개지 않는다(R2-7-1). MM010 은 **폐지코드가 없고 실적재가 사전과 일치**한다 ⇒ 사전 조인만으로 전건 라벨화된다. 🔴현재버전 스냅샷이다.
- 후: DIM_MEMBER.MEMBER_STATUS_NAME — 회원상태명(MM010 라벨). 코드 = MBER_STAT_CD. 값 = 활동회원 / 신규미납1~5 / 장기미납1~5 / 후원중단. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원(DIM_MEMBER.MEMBER_TYPE='ONCE')은 회원상태 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원(FDRM) 중 원천 상태코드 자체가 결손인 행만 **NULL** 이다. 두 사건을 '미상' 같은 한 값으로 뭉개지 않는다. MM010 은 **폐지코드가 없고 실적재가 사전과 일치**한다 ⇒ 사전 조인만으로 전건 라벨화된다. 🔴현재버전 스냅샷이다.

### WIDE_MEMBER_FEE.MEMBER_TYPE_NAME 
- 전: DIM_MEMBER.MEMBER_TYPE_NAME — 회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. 🟢빈 값이 없는 축이다 — 센티넬 '(해당없음)'·NULL 모두 없고 전건 라벨화된다. 앞으로 사전에 없는 코드가 인입되면 **NULL 로 드러나며** '미상' 같은 값으로 덮지 않는다(R2-7-1). 🔴이름이 비슷한 DIM_MEMBER.MEMBER_TYPE(FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다**.
- 후: DIM_MEMBER.MEMBER_TYPE_NAME — 회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. 🟢빈 값이 없는 축이다 — 센티넬 '(해당없음)'·NULL 모두 없고 전건 라벨화된다. 앞으로 사전에 없는 코드가 인입되면 **NULL 로 드러나며** '미상' 같은 값으로 덮지 않는다. 🔴이름이 비슷한 DIM_MEMBER.MEMBER_TYPE(FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다**.

### WIDE_MEMBER_FEE.PAID_FEE 
- 전: 납입 총액(원) = 회비 + 기부금. 🔴납부율 분자로 쓰지 말 것(O40) — PAID_FEE_BILLABLE 을 쓴다
- 후: 납입 총액(원) = 회비 + 기부금. 🔴납부율 분자로 쓰지 말 것 — PAID_FEE_BILLABLE 을 쓴다

### WIDE_MEMBER_FEE.PAID_FEE_BILLABLE 
- 전: 회비 납입액(원) — 납부율 분자 정본(O40)
- 후: 회비 납입액(원) — 납부율 분자 정본

### WIDE_MEMBER_FEE.PAYMENT_METHOD_NAME 
- 전: DIM_PAYMENT.SETTLE_METHOD — 결제수단 라벨. 코드그룹 **PM040(결제정보)**. 원본 코드는 SETLE_CD. [O51-D BRONZE 실측 2026-08-07] 🟢**O45-B(코드그룹 미특정)가 해소됐다** — SETLE_CD 의 코드그룹은 PM040 이고 회비 원천 실적재 값(1자동이체·2신용카드·3신용카드즉시·4회비통장·5휴대폰·6휴대폰즉시·7MICR·8OCR·10실시간계좌이체·12네이버페이·13가상계좌즉시)이 **전부 PM040 사전에 존재**한다. 🔴미매핑 원인은 코드그룹 부재가 아니라 **DIM_PAYMENT 가 결제수단 마스터(TM_PM_SETLE_INFO)의 distinct SETLE_CD 로만 만들어지고 그 마스터에 이 5종이 없다**는 것이다 ⇒ 처방 = DIM_PAYMENT 를 PM040 사전 기준으로 생성(재배선은 O51-D 범위 밖·별건 미결). 미라벨 행은 **코드는 있으나 차원에 행이 없는 5종(3·6·7·10·13)** 과 **SETLE_CD 자체가 NULL 인 행** 으로 나뉜다(규모는 이슈원장 §O45·§O51-D). ⚠️종전 문안의 *'코드그룹 미특정 · 6개 그룹이 전부 의미 무관'* 은 이 실측으로 폐기한다.
- 후: DIM_PAYMENT.SETTLE_METHOD — 결제수단 라벨. 코드그룹 **PM040(결제정보)**. 원본 코드는 SETLE_CD. 🟢**코드그룹이 특정됐다** — SETLE_CD 의 코드그룹은 PM040 이고 회비 원천 실적재 값(1자동이체·2신용카드·3신용카드즉시·4회비통장·5휴대폰·6휴대폰즉시·7MICR·8OCR·10실시간계좌이체·12네이버페이·13가상계좌즉시)이 **전부 PM040 사전에 존재**한다. 🔴미매핑 원인은 코드그룹 부재가 아니라 **DIM_PAYMENT 가 결제수단 마스터(TM_PM_SETLE_INFO)의 distinct SETLE_CD 로만 만들어지고 그 마스터에 이 5종이 없다**는 것이다 ⇒ 처방 = DIM_PAYMENT 를 PM040 사전 기준으로 생성(재배선은 범위 밖·별건 미결). 미라벨 행은 **코드는 있으나 차원에 행이 없는 5종(3·6·7·10·13)** 과 **SETLE_CD 자체가 NULL 인 행** 으로 나뉜다.

### WIDE_MEMBER_FEE.PAYMENT_SK 
- 전: 결제수단 대리키(FK→DIM_PAYMENT) ← SETLE_CD 를 gold_sk 로 해싱. 0=미매핑. ⚠️라벨 커버리지가 완전하지 않다 — 원본 코드는 SETLE_CD 로 보존한다. 🟢[O51-D 실측] 미매핑 원인이 규명됐다 — DIM_PAYMENT 가 결제수단 마스터(TM_PM_SETLE_INFO)의 distinct SETLE_CD 만으로 만들어지는데 회비 원천에는 **마스터에 없는 코드가 존재**한다. 사전(PM040) 기준으로 만들면 전건 라벨화된다(O45-B 처방).
- 후: 결제수단 대리키(FK→DIM_PAYMENT) ← SETLE_CD 를 gold_sk 로 해싱. 0=미매핑. ⚠️라벨 커버리지가 완전하지 않다 — 원본 코드는 SETLE_CD 로 보존한다. 🟢 미매핑 원인이 규명됐다 — DIM_PAYMENT 가 결제수단 마스터(TM_PM_SETLE_INFO)의 distinct SETLE_CD 만으로 만들어지는데 회비 원천에는 **마스터에 없는 코드가 존재**한다. 사전(PM040) 기준으로 만들면 전건 라벨화된다.

### WIDE_MEMBER_FEE.PAYMENT_TYPE 
- 전: 납입유형 = 회비/기부금. 🔴납부율·미납 분석은 회비만으로 스코프할 것 — 기부금은 원천에 청구(RQEST_AMT)가 전건 NULL 이라 분모에 들어갈 수 없다(O40)
- 후: 납입유형 = 회비/기부금. 🔴납부율·미납 분석은 회비만으로 스코프할 것 — 기부금은 원천에 청구(RQEST_AMT)가 전건 NULL 이라 분모에 들어갈 수 없다

### WIDE_MEMBER_FEE.SETLE_CD 
- 전: degenerate key: 결제수단 원본 코드 ← 원천 SETLE_CD(코드그룹 **PM040 결제정보**). 차원 라벨이 없는 코드를 잃지 않기 위해 보존한다. [O51-D 실측] 회비 원천 실적재 값 = 1자동이체 · 2신용카드 · 12네이버페이 · 8OCR · 4회비통장 · 3신용카드즉시 · 5휴대폰 · 10실시간계좌이체 · 6휴대폰즉시 · 13가상계좌즉시 · 7MICR (앞쪽이 최빈). 🟢**실적재 전종이 PM040 사전에 라벨을 갖는다** — 라벨화 공백은 코드 미상이 아니라 DIM_PAYMENT 생성 소스 문제다(O45-B 해소, 상세는 PAYMENT_METHOD_NAME).
- 후: degenerate key: 결제수단 원본 코드 ← 원천 SETLE_CD(코드그룹 **PM040 결제정보**). 차원 라벨이 없는 코드를 잃지 않기 위해 보존한다. 회비 원천 실적재 값 = 1자동이체 · 2신용카드 · 12네이버페이 · 8OCR · 4회비통장 · 3신용카드즉시 · 5휴대폰 · 10실시간계좌이체 · 6휴대폰즉시 · 13가상계좌즉시 · 7MICR (앞쪽이 최빈). 🟢**실적재 전종이 PM040 사전에 라벨을 갖는다** — 라벨화 공백은 코드 미상이 아니라 DIM_PAYMENT 생성 소스 문제다(해소, 상세는 PAYMENT_METHOD_NAME).

### WIDE_MEMBER_FEE.SPONSORSHIP_DIV_NAME 
- 전: [2026-08-19 O89] 납입 대상 후원사업 분류의 **최상위** — 정기일시후원구분 라벨(코드사전 CM035): 정기후원 · 일시후원. 3계층 = DIV_NAME → GROUP_NAME → SPONSORSHIP_NAME. 🟢**이 뷰가 분류 집계의 정본 경로다** — `SPONSORSHIP_SK` 가 거의 전건 채움이라 FMM(전건 센티넬)과 달리 실제 분해가 된다. ⚠️획득 후원사업 축(ACQ_*)과 다른 축이다 — 같은 표에서 섞지 말 것.
- 후: 납입 대상 후원사업 분류의 **최상위** — 정기일시후원구분 라벨(코드사전 CM035): 정기후원 · 일시후원. 3계층 = DIV_NAME → GROUP_NAME → SPONSORSHIP_NAME. 🟢**이 뷰가 분류 집계의 정본 경로다** — `SPONSORSHIP_SK` 가 거의 전건 채움이라 FMM(전건 센티넬)과 달리 실제 분해가 된다. ⚠️획득 후원사업 축(ACQ_*)과 다른 축이다 — 같은 표에서 섞지 말 것.

### WIDE_MEMBER_FEE.SPONSORSHIP_GROUP_NAME 
- 전: [2026-08-19 O89] 납입 대상 후원사업 분류의 **중위** — SPONSORSHIP_ABBR(코드)을 코드사전 CM003(후원약칭)으로 해소한 라벨: 국내 · 결연 · 해외구호 · 북한 · 기타 · 해외 · 선물금(미사용). 사업수 17/1/6/3/21/2 = 50. 🔴🔴**이 컬럼 단독으로 「해외」를 집계하지 말 것** — 해외구호(3)와 해외(6)가 갈라지고 6은 정기일시=일시후원에서만 나타난다 ⇒ 정확한 분류축은 **(DIV_NAME, GROUP_NAME) 쌍**이다. ⚠️인용 시 스코프 병기 — 기부금 지류는 회비구분이 구조적으로 부재하다(O40).
- 후: 납입 대상 후원사업 분류의 **중위** — SPONSORSHIP_ABBR(코드)을 코드사전 CM003(후원약칭)으로 해소한 라벨: 국내 · 결연 · 해외구호 · 북한 · 기타 · 해외 · 선물금(미사용). 사업수 17/1/6/3/21/2 = 50. 🔴🔴**이 컬럼 단독으로 「해외」를 집계하지 말 것** — 해외구호(3)와 해외(6)가 갈라지고 6은 정기일시=일시후원에서만 나타난다 ⇒ 정확한 분류축은 **(DIV_NAME, GROUP_NAME) 쌍**이다. ⚠️인용 시 스코프 병기 — 기부금 지류는 회비구분이 구조적으로 부재하다.

### WIDE_MEMBER_FEE.SPONSORSHIP_NAME 
- 전: 🔴**납입 대상** 후원사업 — 회비 행에 붙은 값이다(원천 SPNSR_BSNS_ID · 거의 전건 채움). 획득 후원사업(ACQ_SPONSORSHIP_NAME)과 다르다: 한 회원이 여러 후원사업에 낸다. 🔴이 축을 grain 에 넣으면 회원-월 조합 수가 늘어난다 — 그것이 이 팩트를 FMM 과 분리한 이유다(증가율 실측은 이슈원장 §O45·§O51-D).
- 후: 🔴**납입 대상** 후원사업 — 회비 행에 붙은 값이다(원천 SPNSR_BSNS_ID · 거의 전건 채움). 획득 후원사업(ACQ_SPONSORSHIP_NAME)과 다르다: 한 회원이 여러 후원사업에 낸다. 🔴이 축을 grain 에 넣으면 회원-월 조합 수가 늘어난다 — 그것이 이 팩트를 FMM 과 분리한 이유다.

### WIDE_MEMBER_FEE.SPONSORSHIP_SK 
- 전: 🔴**납입 대상** 후원사업 대리키(FK→DIM_SPONSORSHIP) ← 원천 SPNSR_BSNS_ID. 0=미매핑. [O51-D 실측] **거의 전건 채움**이며 후원사업 종류는 수십 개다. 🔴획득 후원사업 ACQ_SPONSORSHIP_SK 와 **의미가 다르다** — 같은 라벨로 두 축이 존재한다. 이 축이 grain 에 들어간 것이 이 팩트를 FMM 과 분리한 이유다 — [O51-D 실측] 이 축을 붙이면 **회원-월 조합 수가 늘어 grain 이 깨진다**(증가율은 이슈원장 §O45·§O51-D). ⚠️인용 시 스코프를 함께 적을 것 — 종전 수치는 **BRONZE 회비 지류만**(MBER_NO not null) 스코프여서 분모가 다르다.
- 후: 🔴**납입 대상** 후원사업 대리키(FK→DIM_SPONSORSHIP) ← 원천 SPNSR_BSNS_ID. 0=미매핑. **거의 전건 채움**이며 후원사업 종류는 수십 개다. 🔴획득 후원사업 ACQ_SPONSORSHIP_SK 와 **의미가 다르다** — 같은 라벨로 두 축이 존재한다. 이 축이 grain 에 들어간 것이 이 팩트를 FMM 과 분리한 이유다 — 이 축을 붙이면 **회원-월 조합 수가 늘어 grain 이 깨진다**. ⚠️인용 시 스코프를 함께 적을 것 — 종전 수치는 **BRONZE 회비 지류만**(MBER_NO not null) 스코프여서 분모가 다르다.

### WIDE_MEMBER_FEE.UNPAID_BILLED_AMT 
- 전: 미납 청구액(원) — DEC-3 정본 = PAY_STAT_CD IN (F, NULL) 인 청구액. 🔴차감식(청구−납입) 아님. ⚠️조회 시점 스냅샷 — 과거 미납이 이후 납입되면 값이 바뀐다
- 후: 미납 청구액(원) — 정본 = PAY_STAT_CD IN (F, NULL) 인 청구액. 🔴차감식(청구−납입) 아님. ⚠️조회 시점 스냅샷 — 과거 미납이 이후 납입되면 값이 바뀐다

### WIDE_MEMBER_MONTHLY.AMOUNT_BAND1 (덮어쓰기)
- 전: 후원금액대1 5만 (#72) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.AMOUNT_BAND1`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.
- 후: 후원금액대1 5만 (#72). 🔴값이 없는 행은 NULL 이다 — 0 이나 '해당없음' 으로 대체 해석하지 말 것.

### WIDE_MEMBER_MONTHLY.AMOUNT_BAND2 (덮어쓰기)
- 전: 후원금액대2 1만 (#73) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.AMOUNT_BAND2`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.
- 후: 후원금액대2 1만 (#73). 🔴값이 없는 행은 NULL 이다 — 0 이나 '해당없음' 으로 대체 해석하지 말 것.

### WIDE_MEMBER_MONTHLY.CAMPAIGN_BK (덮어쓰기)
- 전: [O216-D A4-X 영구 센티넬] 원천에 캠페인 연결 키가 없어 이 뷰에서는 **배선을 기다려도 값이 생기지 않는다** — 이 컬럼으로 GROUP BY·필터하지 않는다(캠페인 분해는 FACT_MEMBER_EVENT·MSTR 를 쓴다). DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키. ⚠️캠페인이 연결되지 않은 행은 `'(미매핑)'` — 캠페인별 합계는 전체보다 작다.

### WIDE_MEMBER_MONTHLY.CAMPAIGN_BRAND (덮어쓰기)
- 전: DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_CAMPAIGN.BRAND — 공통브랜드 (#117). ⚠️캠페인이 연결되지 않은 행은 NULL — 캠페인별 합계는 전체보다 작다.

### WIDE_MEMBER_MONTHLY.CAMPAIGN_NAME (덮어쓰기)
- 전: [O216-D A4-X 영구 센티넬] 원천에 캠페인 연결 키가 없어 이 뷰에서는 **배선을 기다려도 값이 생기지 않는다** — 이 컬럼으로 GROUP BY·필터하지 않는다(캠페인 분해는 FACT_MEMBER_EVENT·MSTR 를 쓴다). DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120). ⚠️캠페인이 연결되지 않은 행은 `'(미매핑)'` — 캠페인별 합계는 전체보다 작다.

### WIDE_MEMBER_MONTHLY.CAMPAIGN_PARENT (덮어쓰기)
- 전: DIM_CAMPAIGN.PARENT_CAMPAIGN — 공통상위캠페인 (#119) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_CAMPAIGN.PARENT_CAMPAIGN — 공통상위캠페인 (#119). ⚠️캠페인이 연결되지 않은 행은 NULL — 캠페인별 합계는 전체보다 작다.

### WIDE_MEMBER_MONTHLY.CAMPAIGN_PROMO_METHOD (덮어쓰기)
- 전: DIM_CAMPAIGN.PROMO_METHOD — 홍보방법 (#118) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_CAMPAIGN.PROMO_METHOD — 홍보방법 (#118). ⚠️캠페인이 연결되지 않은 행은 NULL — 캠페인별 합계는 전체보다 작다.

### WIDE_MEMBER_MONTHLY.CAMPAIGN_TYPE (덮어쓰기)
- 전: DIM_CAMPAIGN.CAMPAIGN_TYPE — 캠페인 유형 (#17) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_CAMPAIGN.CAMPAIGN_TYPE — 캠페인 유형 (#17). ⚠️캠페인이 연결되지 않은 행은 NULL — 캠페인별 합계는 전체보다 작다.

### WIDE_MEMBER_MONTHLY.DEV_CNT 
- 전: 개발(건) (#4·5·149) = **MSTR 정의**(O202 · 사용자 결정): 회원×월 MSTR 인정금액 ÷ 10,000 합. 인정금액 = 신규·재후원은 미중단 후원사업·월합>0 행의 금액, 증액은 감액과 상계한 순증액(원본 FN_MM_SPNSR_DVLP B1·B2). 소수가 나온다. 🔴 GN_DW.MSTR 지표와 같은 표에서 합산 금지(정의가 같아도 출처가 다르다).
- 후: 개발(건) (#4·5·149) = **MSTR 정의**(사용자 결정): 회원×월 MSTR 인정금액 ÷ 10,000 합. 인정금액 = 신규·재후원은 미중단 후원사업·월합>0 행의 금액, 증액은 감액과 상계한 순증액(원본 FN_MM_SPNSR_DVLP B1·B2). 소수가 나온다. 🔴 GN_DW.MSTR 지표와 같은 표에서 합산 금지(정의가 같아도 출처가 다르다).

### WIDE_MEMBER_MONTHLY.DEV_TYPE (덮어쓰기)
- 전: 개발구분 (#121) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.DEV_TYPE`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.
- 후: 개발구분 (#121). ⚠️채움이 일부다 — 개발구분별 비중은 값이 있는 행 기준임을 밝힐 것. 🔴값이 없는 행은 NULL 이다 — 0 이나 '해당없음' 으로 대체 해석하지 말 것.

### WIDE_MEMBER_MONTHLY.INCREASE_FLAG (덮어쓰기)
- 전: 증액여부 (#33) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.INCREASE_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.
- 후: 증액여부 (#33).

### WIDE_MEMBER_MONTHLY.JOIN_DATE (덮어쓰기)
- 전: 캠페인 가입일 (#27) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.JOIN_DATE`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C. 🟢대체 경로 = `MEMBER_FIRST_JOIN_DATE`(DIM_MEMBER 경유).
- 후: 캠페인 가입일 (#27).

### WIDE_MEMBER_MONTHLY.MEMBER_AGE_BAND 
- 전: DIM_MEMBER.AGE_BAND — 연령대명 · **CM014** 라벨. 코드 = MEMBER_AGE_CD. 🔴빈 값은 두 갈래이며 **둘 다 개발약정 원천 행이 없는 경우**다 — 일시회원('ONCE')은 전건, 정기회원(FDRM)은 일부. 연령 개념은 존재하므로 '(해당없음)' 이 아니라 NULL 이고 미매핑도 없다. '미상' 으로 창작하지 않는다(R2-7-1). 🔴**연속형 나이가 아니다** — 평균·재구간화 금지(원천이 이미 구간화해 제공한다 · DEC-28). 🔴**현재 나이가 아니다** — 개발약정 시점 스냅샷이고 BRONZE 에 생년월일 축이 없어 시점정확 연령은 산출 불가다(O34). ⚠️연령 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것(P128).
- 후: DIM_MEMBER.AGE_BAND — 연령대명 · **CM014** 라벨. 코드 = MEMBER_AGE_CD. 🔴빈 값은 두 갈래이며 **둘 다 개발약정 원천 행이 없는 경우**다 — 일시회원('ONCE')은 전건, 정기회원(FDRM)은 일부. 연령 개념은 존재하므로 '(해당없음)' 이 아니라 NULL 이고 미매핑도 없다. '미상' 으로 창작하지 않는다. 🔴**연속형 나이가 아니다** — 평균·재구간화 금지(원천이 이미 구간화해 제공한다). 🔴**현재 나이가 아니다** — 개발약정 시점 스냅샷이고 BRONZE 에 생년월일 축이 없어 시점정확 연령은 산출 불가다. ⚠️연령 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것.

### WIDE_MEMBER_MONTHLY.MEMBER_AGE_CD 
- 전: DIM_MEMBER.AGE — 연령대 원천코드 raw. 코드그룹 **CM014(나이)**. 코드사전 = 1'10대 미만'·2'10대'·3'20대'·4'30대'·5'40대'·6'50대'·7'60대'·8'70대'·9'70대 이상'·10단체·11기업·12기타 · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AGE)에 **사전 전종이 등장**한다. 🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지. 구간은 우리가 만든 것이 아니라 원천이 이미 구간화해 제공한다(DEC-28). ⚠️사전 자체에 8'70대'와 9'70대 이상'이 **의미 중복**으로 공존한다 — 70대 이상 집계 시 두 코드를 함께 취할 것. ⚠️BRONZE 원천 컬럼 COMMENT '연령'(NUMBER)은 오류다. 라벨 = MEMBER_AGE_BAND. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.AGE — 연령대 원천코드 raw. 코드그룹 **CM014(나이)**. 코드사전 = 1'10대 미만'·2'10대'·3'20대'·4'30대'·5'40대'·6'50대'·7'60대'·8'70대'·9'70대 이상'·10단체·11기업·12기타 · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AGE)에 **사전 전종이 등장**한다. 🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지. 구간은 우리가 만든 것이 아니라 원천이 이미 구간화해 제공한다. ⚠️사전 자체에 8'70대'와 9'70대 이상'이 **의미 중복**으로 공존한다 — 70대 이상 집계 시 두 코드를 함께 취할 것. ⚠️BRONZE 원천 컬럼 COMMENT '연령'(NUMBER)은 오류다. 라벨 = MEMBER_AGE_BAND. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_MEMBER_MONTHLY.MEMBER_AREA_CD 
- 전: DIM_MEMBER.AREA_CD — 지역 원천코드 raw. 코드그룹 **CM018**. 코드사전 = (1서울·2경기·3인천·4강원·5대전·6충남·7충북·8광주·9전북·10전남·11대구·12경북·13경남·14울산·15부산·16제주·17기타·18세종) · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD)에 **사전 전종 + 라벨 없는 센티넬 '0'** 이 나타난다. ⚠️CM018 의 그룹명은 '신규시도구분'이지만 상세코드 값은 전부 시·도다(정본 공#131 지역정의가 약칭이라 정식명 그룹 CM011 이 아니다). 🔴**현재 거주지가 아니다** — 이 값은 그 버전 시점까지 최근 개발약정의 스냅샷이며 BRONZE 전체에 현주소 축이 없다(O34). 라벨 = MEMBER_REGION. 사건 시점 정확값은 WIDE_MEMBER_EVENT.AREA_CD_AT_EVENT. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.AREA_CD — 지역 원천코드 raw. 코드그룹 **CM018**. 코드사전 = (1서울·2경기·3인천·4강원·5대전·6충남·7충북·8광주·9전북·10전남·11대구·12경북·13경남·14울산·15부산·16제주·17기타·18세종) · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD)에 **사전 전종 + 라벨 없는 센티넬 '0'** 이 나타난다. ⚠️CM018 의 그룹명은 '신규시도구분'이지만 상세코드 값은 전부 시·도다(정본 공#131 지역정의가 약칭이라 정식명 그룹 CM011 이 아니다). 🔴**현재 거주지가 아니다** — 이 값은 그 버전 시점까지 최근 개발약정의 스냅샷이며 BRONZE 전체에 현주소 축이 없다. 라벨 = MEMBER_REGION. 사건 시점 정확값은 WIDE_MEMBER_EVENT.AREA_CD_AT_EVENT. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_MEMBER_MONTHLY.MEMBER_ENROLL_PATH_NAME 
- 전: DIM_MEMBER.ENROLL_PATH_NAME — 가입경로명(MM014 라벨). 코드 = JOIN_PATH_CD. 실제로 나타나는 라벨은 **홈페이지·CRM·모바일웹·외주콜센터·모바일앱·REG** 다 — 사전에는 희망TV·EDU 도 있으나 **실적재에 없으므로** 그 둘을 포함해 열거하면 거짓이다. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원('ONCE')은 가입경로 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원 중 가입경로 코드만 결손인 행은 **NULL** 이다(회원상태가 NULL 인 행과 같은 행이 아니다). '미상' 으로 채우지 않는다(R2-7-1). 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.ENROLL_PATH_NAME — 가입경로명(MM014 라벨). 코드 = JOIN_PATH_CD. 실제로 나타나는 라벨은 **홈페이지·CRM·모바일웹·외주콜센터·모바일앱·REG** 다 — 사전에는 희망TV·EDU 도 있으나 **실적재에 없으므로** 그 둘을 포함해 열거하면 거짓이다. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원('ONCE')은 가입경로 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원 중 가입경로 코드만 결손인 행은 **NULL** 이다(회원상태가 NULL 인 행과 같은 행이 아니다). '미상' 으로 채우지 않는다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_MEMBER_MONTHLY.MEMBER_GENDER_NAME 
- 전: DIM_MEMBER.GENDER_NAME — 성별 분석 라벨(정본 공#130). 코드그룹 **CM017(회원특성(성별))**. CM017 은 CM013 과 **코드 도메인이 동일(1~8)한 재라벨 그룹**이며 국내/외국인 구분을 지운다 — 1남자·2여자·3남자·4여자·5기타·6단체·7기업·8기타 ⇒ **서로 다른 코드가 같은 라벨로 합쳐진다**(남자/여자/기타/단체/기업). 정본 공#130 값정의와 일치. ⚠️CM017 은 정본 컬럼정의서가 어떤 컬럼에도 지정하지 않은 그룹이다(현업 확인 대상). ⚠️종전 하드코딩 '여성/남성/미상'은 라벨을 축약하고 법인·단체를 '미상'으로 오라벨했다(O26 교정). 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.GENDER_NAME — 성별 분석 라벨(정본 공#130). 코드그룹 **CM017(회원특성(성별))**. CM017 은 CM013 과 **코드 도메인이 동일(1~8)한 재라벨 그룹**이며 국내/외국인 구분을 지운다 — 1남자·2여자·3남자·4여자·5기타·6단체·7기업·8기타 ⇒ **서로 다른 코드가 같은 라벨로 합쳐진다**(남자/여자/기타/단체/기업). 정본 공#130 값정의와 일치. ⚠️CM017 은 정본 컬럼정의서가 어떤 컬럼에도 지정하지 않은 그룹이다(현업 확인 대상). ⚠️종전 하드코딩 '여성/남성/미상'은 라벨을 축약하고 법인·단체를 '미상'으로 오라벨했다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_MEMBER_MONTHLY.MEMBER_REGION 
- 전: DIM_MEMBER.REGION — 지역명(정본 공#131) · **CM018** 약칭 라벨. 코드 = MEMBER_AREA_CD. 🔴빈 값이 세 갈래다 — ①일시회원(MEMBER_TYPE='ONCE')은 개발약정 **행 자체가 없어** NULL 이다(지역 개념은 존재하므로 '(해당없음)' 이 아니다) ②정기회원(FDRM) 중 개발약정이 없는 행도 NULL ③센티넬 코드 '0' 은 사전에 라벨이 없어 NULL. 🟢미매핑(코드는 있는데 사전에 없음)은 없다. '미상' 으로 창작하지 않는다(R2-7-1). 🔴**현재 거주지가 아니다** — 개발약정 시점 스냅샷이며 BRONZE 에 현주소 축이 없다(O34). ⚠️지역 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것 — ONCE 를 분모에 넣으면 채움률이 조용히 낮아진다(P128).
- 후: DIM_MEMBER.REGION — 지역명(정본 공#131) · **CM018** 약칭 라벨. 코드 = MEMBER_AREA_CD. 🔴빈 값이 세 갈래다 — ①일시회원(MEMBER_TYPE='ONCE')은 개발약정 **행 자체가 없어** NULL 이다(지역 개념은 존재하므로 '(해당없음)' 이 아니다) ②정기회원(FDRM) 중 개발약정이 없는 행도 NULL ③센티넬 코드 '0' 은 사전에 라벨이 없어 NULL. 🟢미매핑(코드는 있는데 사전에 없음)은 없다. '미상' 으로 창작하지 않는다. 🔴**현재 거주지가 아니다** — 개발약정 시점 스냅샷이며 BRONZE 에 현주소 축이 없다. ⚠️지역 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것 — ONCE 를 분모에 넣으면 채움률이 조용히 낮아진다.

### WIDE_MEMBER_MONTHLY.MEMBER_STATUS_NAME 
- 전: DIM_MEMBER.MEMBER_STATUS_NAME — 회원상태명(MM010 라벨, 정본 공#132). 코드 = MBER_STAT_CD. MM010 은 **폐지코드가 없고 실적재가 사전과 일치**한다 ⇒ 사전 조인만으로 전건 라벨화된다(하드코딩 금지 P31). 값 = 활동회원 / 신규미납1~5 / 장기미납1~5 / 후원중단. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원(DIM_MEMBER.MEMBER_TYPE='ONCE')은 회원상태 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원(FDRM) 중 원천 상태코드 자체가 결손인 행만 **NULL** 이다. 두 사건을 '미상' 같은 한 값으로 뭉개지 않는다(R2-7-1). ⚠️미납 단계(1~5)는 **경과 차수**이며 금액 규모가 아니다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.MEMBER_STATUS_NAME — 회원상태명(MM010 라벨, 정본 공#132). 코드 = MBER_STAT_CD. MM010 은 **폐지코드가 없고 실적재가 사전과 일치**한다 ⇒ 사전 조인만으로 전건 라벨화된다(하드코딩 금지). 값 = 활동회원 / 신규미납1~5 / 장기미납1~5 / 후원중단. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원(DIM_MEMBER.MEMBER_TYPE='ONCE')은 회원상태 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원(FDRM) 중 원천 상태코드 자체가 결손인 행만 **NULL** 이다. 두 사건을 '미상' 같은 한 값으로 뭉개지 않는다. ⚠️미납 단계(1~5)는 **경과 차수**이며 금액 규모가 아니다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_MEMBER_MONTHLY.MEMBER_TYPE_NAME 
- 전: DIM_MEMBER.MEMBER_TYPE_NAME — 회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. MM018 은 폐지코드가 없고 실적재가 사전과 일치한다. 🟢빈 값이 없는 축이다 — 센티넬 '(해당없음)'·NULL 모두 없고 전건 라벨화된다. 앞으로 사전에 없는 코드가 인입되면 **NULL 로 드러나며** '미상' 같은 값으로 덮지 않는다(R2-7-1). 🔴이름이 비슷한 DIM_MEMBER.MEMBER_TYPE(=FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다** — 다른 축이다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.MEMBER_TYPE_NAME — 회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. MM018 은 폐지코드가 없고 실적재가 사전과 일치한다. 🟢빈 값이 없는 축이다 — 센티넬 '(해당없음)'·NULL 모두 없고 전건 라벨화된다. 앞으로 사전에 없는 코드가 인입되면 **NULL 로 드러나며** '미상' 같은 값으로 덮지 않는다. 🔴이름이 비슷한 DIM_MEMBER.MEMBER_TYPE(=FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다** — 다른 축이다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_MEMBER_MONTHLY.NEW_EXISTING_FLAG (덮어쓰기)
- 전: 신규/기존(시점귀속, #113) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.NEW_EXISTING_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.
- 후: 신규/기존(시점귀속, #113).

### WIDE_MEMBER_MONTHLY.NEW_FLAG (덮어쓰기)
- 전: 신규여부 (#32) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.NEW_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.
- 후: 신규여부 (#32).

### WIDE_MEMBER_MONTHLY.PAYMENT_FEE_TYPE 
- 전: DIM_PAYMENT.FEE_TYPE — 회비유형(정기/일시) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.PAYMENT_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C. ⚠️게다가 `DIM_PAYMENT.FEE_TYPE` 자체도 전건 비어 있다(이중 결손).
- 후: DIM_PAYMENT.FEE_TYPE — 회비유형(정기/일시) 🔴🔴 **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.PAYMENT_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. ⚠️게다가 `DIM_PAYMENT.FEE_TYPE` 자체도 전건 비어 있다(이중 결손).

### WIDE_MEMBER_MONTHLY.PAYMENT_METHOD 
- 전: DIM_PAYMENT.PAYMENT_METHOD — 납입방식 (#125) 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_MEMBER_MONTHLY.PAYMENT_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_PAYMENT.PAYMENT_METHOD — 납입방식 (#125) 🔴🔴 **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_MEMBER_MONTHLY.PAYMENT_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것.

### WIDE_MEMBER_MONTHLY.PAYMENT_SETTLE_METHOD 
- 전: DIM_PAYMENT.SETTLE_METHOD — 결제방식 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.PAYMENT_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_PAYMENT.SETTLE_METHOD — 결제방식 🔴🔴 **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.PAYMENT_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다.

### WIDE_MEMBER_MONTHLY.PERIOD_BAND1 (덮어쓰기)
- 전: 후원기간대1 5년 (#74) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.PERIOD_BAND1`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.
- 후: 후원기간대1 5년 (#74).

### WIDE_MEMBER_MONTHLY.PERIOD_BAND2 (덮어쓰기)
- 전: 후원기간대2 1년 (#75) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.PERIOD_BAND2`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.
- 후: 후원기간대2 1년 (#75).

### WIDE_MEMBER_MONTHLY.REDONATE_FLAG (덮어쓰기)
- 전: 재후원여부 (#34) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.REDONATE_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.
- 후: 재후원여부 (#34).

### WIDE_MEMBER_MONTHLY.SPONSORSHIP_ABBR (덮어쓰기)
- 전: DIM_SPONSORSHIP.SPONSORSHIP_ABBR — 약칭 (#124) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MEMBER_MONTHLY.SPONSORSHIP_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C. 🟢[2026-08-19 O89] 이 컬럼은 **코드(1~6)** 이고 라벨은 SPONSORSHIP_GROUP_NAME 이다 — 코드사전 CM003(후원약칭)으로 특정됐다(SPB-G 종결).
- 후: DIM_SPONSORSHIP.SPONSORSHIP_ABBR — 약칭 (#124). 이 컬럼은 **코드(1~6)** 이고 라벨은 SPONSORSHIP_GROUP_NAME 이다(코드사전 CM003 후원약칭). ⚠️후원사업이 연결되지 않은 행은 NULL — 후원사업별 합계는 전체보다 작다.

### WIDE_MEMBER_MONTHLY.SPONSORSHIP_BK (덮어쓰기)
- 전: DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_MEMBER_MONTHLY.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키. ⚠️후원사업이 연결되지 않은 행은 `'(미매핑)'` — 후원사업별 합계는 전체보다 작다.

### WIDE_MEMBER_MONTHLY.SPONSORSHIP_DIV_NAME (덮어쓰기)
- 전: [2026-08-19 O89] 후원사업 분류 **최상위** — 정기일시후원구분 라벨(코드사전 CM035): 정기후원 · 일시후원. 3계층 = DIV_NAME → GROUP_NAME → SPONSORSHIP_NAME. 🔴🔴 이 뷰에서는 `FACT_MEMBER_MONTHLY.SPONSORSHIP_SK` 가 **전건 센티넬(0)** 이라 이 라벨도 `'(미매핑)'` 이다 — 분류별 분해는 `WIDE_MEMBER_FEE`(거의 전건 채움) 또는 `WIDE_MEMBER_EVENT`(DEV 브랜치 배선)를 쓸 것. 센티넬 원인은 O8(다중후원·다중캠페인 귀속 규칙 현업 미회신)이다.
- 후: 후원사업 분류 **최상위** — 정기일시후원구분 라벨(코드사전 CM035): 정기후원 · 일시후원. 3계층 = DIV_NAME → GROUP_NAME → SPONSORSHIP_NAME. ⚠️후원사업이 연결되지 않은 행은 NULL — 후원사업별 합계는 전체보다 작다.

### WIDE_MEMBER_MONTHLY.SPONSORSHIP_GROUP_NAME (덮어쓰기)
- 전: [2026-08-19 O89] 후원사업 분류 **중위** — SPONSORSHIP_ABBR(코드)을 코드사전 CM003(후원약칭)으로 해소한 라벨: 국내 · 결연 · 해외구호 · 북한 · 기타 · 해외 · 선물금(미사용). 사업수 17/1/6/3/21/2 = 50. 🔴🔴**이 컬럼 단독으로 「해외」를 집계하지 말 것** — 해외구호(3)와 해외(6)가 갈라지고 6은 정기일시=일시후원에서만 나타난다 ⇒ 정확한 분류축은 **(DIV_NAME, GROUP_NAME) 쌍**이다. 🔴🔴 이 뷰에서는 팩트 FK 가 전건 센티넬이라 `'(미매핑)'` 이다(위 DIV_NAME 주석과 동일).
- 후: 후원사업 분류 **중위** — SPONSORSHIP_ABBR(코드)을 코드사전 CM003(후원약칭)으로 해소한 라벨: 국내 · 결연 · 해외구호 · 북한 · 기타 · 해외 · 선물금(미사용). 🔴🔴**이 컬럼 단독으로 「해외」를 집계하지 말 것** — 해외구호와 해외가 갈라지고 해외는 일시후원에서만 나타난다 ⇒ 정확한 분류축은 **(DIV_NAME, GROUP_NAME) 쌍**이다. ⚠️후원사업이 연결되지 않은 행은 NULL — 후원사업별 합계는 전체보다 작다.

### WIDE_MEMBER_MONTHLY.SPONSORSHIP_NAME (덮어쓰기)
- 전: DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123) 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_MEMBER_MONTHLY.SPONSORSHIP_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123). ⚠️후원사업이 연결되지 않은 행은 `'(미매핑)'` — 후원사업별 합계는 전체보다 작다.

### WIDE_MEMBER_MONTHLY.STOP_DATE (덮어쓰기)
- 전: 가입캠페인 중단일 (#26) 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MEMBER_MONTHLY.STOP_DATE`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C. 🟢대체 경로 = `MEMBER_LAST_STOP_DATE`(DIM_MEMBER as-of) 또는 WIDE_MEMBER_EVENT.
- 후: 가입캠페인 중단일 (#26). ⚠️값이 있는 행은 일부다. 🟢대체 경로 = `MEMBER_LAST_STOP_DATE`(DIM_MEMBER as-of) 또는 WIDE_MEMBER_EVENT.

### WIDE_MEMBER_SERVICE_COHORT.CAMPAIGN_EVENT_PART_ROWS 
- 전: 캠페인행사(CRMN) 참여 기록 행 수(전 기간). ⚠️원천에 참여일이 없어(FEA 날짜 = 행사 시작일) 수신 전후 구분을 하지 않는다(O205-B).
- 후: 캠페인행사(CRMN) 참여 기록 행 수(전 기간). ⚠️원천에 참여일이 없어(FEA 날짜 = 행사 시작일) 수신 전후 구분을 하지 않는다.

### WIDE_MEMBER_SERVICE_COHORT.CHRG_DEPT_NAMES 
- 전: [O206] 그 연도 수신 발송의 템플릿 담당부서명(CRM_ORG · 여러 개면 ' · ' 로 이음). 처리자→부서 마스터는 원천에 없어 템플릿 담당부서로 대신한다. 템플릿이 없는 발송만 받았으면 NULL.
- 후: 그 연도 수신 발송의 템플릿 담당부서명(CRM_ORG · 여러 개면 ' · ' 로 이음). 처리자→부서 마스터는 원천에 없어 템플릿 담당부서로 대신한다. 템플릿이 없는 발송만 받았으면 NULL.

### WIDE_MEMBER_SERVICE_COHORT.CULTURE_EVENT_PART_ROWS 
- 전: [O206] 문화서비스 계열 캠페인행사(DIM_EVENT.EVENT_CATEGORY = MS002 6 문화서비스 · 14 전시 · 15 서적 · 16 공연) 참여 기록 행 수(전 기간). 「문화이벤트」 질문의 유사 매핑 대상.
- 후: 문화서비스 계열 캠페인행사(DIM_EVENT.EVENT_CATEGORY = MS002 6 문화서비스 · 14 전시 · 15 서적 · 16 공연) 참여 기록 행 수(전 기간). 「문화이벤트」 질문의 유사 매핑 대상.

### WIDE_MEMBER_SERVICE_COHORT.D5_STOP_SPONSOR_DAYS 
- 전: D5 중단 회원의 후원기간(일) = 획득일 → D+1~D+5 첫 중단일(O205-B). 🔴중단 사건 원천에는 가입일·후원금액이 없어(구조적 NULL) 획득 코호트 기준으로 계산한다 — 후원금액은 ACQ_SPNSR_AMT 를 쓴다.
- 후: D5 중단 회원의 후원기간(일) = 획득일 → D+1~D+5 첫 중단일. 🔴중단 사건 원천에는 가입일·후원금액이 없어(구조적 NULL) 획득 코호트 기준으로 계산한다 — 후원금액은 ACQ_SPNSR_AMT 를 쓴다.

### WIDE_MEMBER_SERVICE_COHORT.MATCH_BASIS 
- 전: [O206 A안] 그 수신 행이 서비스그룹에 든 근거 — '서비스코드'(발송코드 MS049 상위 서비스코드 = 원천 서비스 카테고리) · '발송제목'(카테고리가 없어 제목 부분일치로 매핑) · '서비스코드+발송제목'. 미수신 행은 NULL.
- 후: 그 수신 행이 서비스그룹에 든 근거 — '서비스코드'(발송코드 MS049 상위 서비스코드 = 원천 서비스 카테고리) · '발송제목'(카테고리가 없어 제목 부분일치로 매핑) · '서비스코드+발송제목'. 미수신 행은 NULL.

### WIDE_MEMBER_SERVICE_COHORT.ONLINE_EVENT_PART_ROWS 
- 전: [O206] 온라인 구분 일반행사(DIM_EVENT.EVENT_CATEGORY = MS286 100 온라인) 참여 기록 행 수(전 기간). 「온라인 이벤트」 질문의 유사 매핑 대상.
- 후: 온라인 구분 일반행사(DIM_EVENT.EVENT_CATEGORY = MS286 100 온라인) 참여 기록 행 수(전 기간). 「온라인 이벤트」 질문의 유사 매핑 대상.

### WIDE_MEMBER_SERVICE_COHORT.ONLINE_EVENT_PART_ROWS_AFTER 
- 전: [O206] 첫 수신일 이후 온라인 구분 일반행사 참여 기록 행 수. 미수신 행은 NULL(기준일 없음).
- 후: 첫 수신일 이후 온라인 구분 일반행사 참여 기록 행 수. 미수신 행은 NULL(기준일 없음).

### WIDE_MEMBER_SERVICE_COHORT.RECEIVED_SABOK_FLAG 
- 전: [O206] 그 연도 사복 법인 발송 수신 여부(판정 규칙은 RECEIVED_SADAN_FLAG 와 같다). 미수신 행은 NULL.
- 후: 그 연도 사복 법인 발송 수신 여부(판정 규칙은 RECEIVED_SADAN_FLAG 와 같다). 미수신 행은 NULL.

### WIDE_MEMBER_SERVICE_COHORT.RECEIVED_SADAN_FLAG 
- 전: [O206] 그 연도 사단 법인 발송 수신 여부. 법인 = 서비스코드명의 (사단)/(사복)/(통합) → 없으면 알림톡·메일 템플릿 법인구분(CPR_DIV_CD · CM019). 미수신 행은 NULL.
- 후: 그 연도 사단 법인 발송 수신 여부. 법인 = 서비스코드명의 (사단)/(사복)/(통합) → 없으면 알림톡·메일 템플릿 법인구분(CPR_DIV_CD · CM019). 미수신 행은 NULL.

### WIDE_MEMBER_SERVICE_COHORT.RECEIVED_TONGHAP_FLAG 
- 전: [O206] 그 연도 통합 법인 발송 수신 여부(판정 규칙은 RECEIVED_SADAN_FLAG 와 같다). 🔴 세 플래그가 모두 FALSE 인 수신 = 서비스코드·템플릿이 없어 법인을 판별할 수 없는 발송만 받은 회원. 미수신 행은 NULL.
- 후: 그 연도 통합 법인 발송 수신 여부(판정 규칙은 RECEIVED_SADAN_FLAG 와 같다). 🔴 세 플래그가 모두 FALSE 인 수신 = 서비스코드·템플릿이 없어 법인을 판별할 수 없는 발송만 받은 회원. 미수신 행은 NULL.

### WIDE_MEMBER_SERVICE_COHORT.RECEIVE_ROWS 
- 전: 그 연도 수신일 수(서로 다른 발송일 개수 · O205-B). 🔴회원수가 아니다.
- 후: 그 연도 수신일 수(서로 다른 발송일 개수). 🔴회원수가 아니다.

### WIDE_MEMBER_SERVICE_COHORT.SERVICE_GROUP_CD 
- 전: 서비스그룹 코드(O206 A안 · 서비스코드 우선 → 발송제목 보조) — SNG_INSTANT·PERSONAL_NEW_SADAN·LUCKY_CARD·LONGTERM_THANKS. 🔴반드시 하나로 고정한다(그룹 간 합산 금지 · 한 발송이 여러 그룹에 들 수 있다).
- 후: 서비스그룹 코드(A안 · 서비스코드 우선 → 발송제목 보조) — SNG_INSTANT·PERSONAL_NEW_SADAN·LUCKY_CARD·LONGTERM_THANKS. 🔴반드시 하나로 고정한다(그룹 간 합산 금지 · 한 발송이 여러 그룹에 들 수 있다).

### WIDE_MEMBER_SERVICE_COHORT.SVC_CATEGORY_NAMES 
- 전: [O206] 그 연도 수신 발송의 원천 서비스 카테고리명(발송코드 MS049 상위코드명 · 여러 개면 ' · ' 로 이음). 서비스코드 계층이 없는 발송만 받았으면 NULL.
- 후: 그 연도 수신 발송의 원천 서비스 카테고리명(발송코드 MS049 상위코드명 · 여러 개면 ' · ' 로 이음). 서비스코드 계층이 없는 발송만 받았으면 NULL.

### WIDE_SERVICE_EVENT.CAMPAIGN_BK (덮어쓰기)
- 전: [O216-D A4-X 영구 센티넬] 원천에 캠페인 연결 키가 없어 이 뷰에서는 **배선을 기다려도 값이 생기지 않는다** — 이 컬럼으로 GROUP BY·필터하지 않는다(캠페인 분해는 FACT_MEMBER_EVENT·MSTR 를 쓴다). DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_MESSAGE_DISPATCH.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키. ⚠️일부 행만 캠페인이 연결돼 있고 나머지는 `'(미매핑)'` 다 — 캠페인별 합계는 전체보다 훨씬 작으므로 커버리지를 함께 밝힐 것.

### WIDE_SERVICE_EVENT.CAMPAIGN_BRAND (덮어쓰기)
- 전: DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MESSAGE_DISPATCH.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_CAMPAIGN.BRAND — 공통브랜드 (#117). ⚠️일부 행만 캠페인이 연결돼 있고 나머지는 NULL 다 — 캠페인별 합계는 전체보다 훨씬 작으므로 커버리지를 함께 밝힐 것.

### WIDE_SERVICE_EVENT.CAMPAIGN_NAME (덮어쓰기)
- 전: [O216-D A4-X 영구 센티넬] 원천에 캠페인 연결 키가 없어 이 뷰에서는 **배선을 기다려도 값이 생기지 않는다** — 이 컬럼으로 GROUP BY·필터하지 않는다(캠페인 분해는 FACT_MEMBER_EVENT·MSTR 를 쓴다). DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴[O51-D 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이므로 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_MESSAGE_DISPATCH.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 캠페인·후원사업별 분해를 시도하지 말 것. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120). ⚠️일부 행만 캠페인이 연결돼 있고 나머지는 `'(미매핑)'` 다 — 캠페인별 합계는 전체보다 훨씬 작으므로 커버리지를 함께 밝힐 것.

### WIDE_SERVICE_EVENT.CAMPAIGN_PARENT (덮어쓰기)
- 전: DIM_CAMPAIGN.PARENT_CAMPAIGN — 공통상위캠페인 (#119) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MESSAGE_DISPATCH.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_CAMPAIGN.PARENT_CAMPAIGN — 공통상위캠페인 (#119). ⚠️일부 행만 캠페인이 연결돼 있고 나머지는 NULL 다 — 캠페인별 합계는 전체보다 훨씬 작으므로 커버리지를 함께 밝힐 것.

### WIDE_SERVICE_EVENT.CAMPAIGN_PROMO_METHOD (덮어쓰기)
- 전: DIM_CAMPAIGN.PROMO_METHOD — 홍보방법 (#118) 🔴🔴[O51-D 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_MESSAGE_DISPATCH.CAMPAIGN_SK` 는 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있으니 다른 팩트에서는 쓸 수 있다. 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_CAMPAIGN.PROMO_METHOD — 홍보방법 (#118). ⚠️일부 행만 캠페인이 연결돼 있고 나머지는 NULL 다 — 캠페인별 합계는 전체보다 훨씬 작으므로 커버리지를 함께 밝힐 것.

### WIDE_SERVICE_EVENT.MAIL_RECEIVE_FLAG 
- 전: 메일수신여부 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MESSAGE_DISPATCH.MAIL_RECEIVE_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.
- 후: 메일수신여부 🔴🔴 **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MESSAGE_DISPATCH.MAIL_RECEIVE_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것. 필터 조건으로 쓰면 전건이 탈락한다.

### WIDE_SERVICE_EVENT.MEMBER_AGE_BAND 
- 전: DIM_MEMBER.AGE_BAND — 연령대명 · **CM014** 라벨. 코드 = MEMBER_AGE_CD. 🔴빈 값은 두 갈래이며 **둘 다 개발약정 원천 행이 없는 경우**다 — 일시회원('ONCE')은 전건, 정기회원(FDRM)은 일부. 연령 개념은 존재하므로 '(해당없음)' 이 아니라 NULL 이고 미매핑도 없다. '미상' 으로 창작하지 않는다(R2-7-1). 🔴**연속형 나이가 아니다** — 평균·재구간화 금지(원천이 이미 구간화해 제공한다 · DEC-28). 🔴**현재 나이가 아니다** — 개발약정 시점 스냅샷이고 BRONZE 에 생년월일 축이 없어 시점정확 연령은 산출 불가다(O34). ⚠️연령 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것(P128).
- 후: DIM_MEMBER.AGE_BAND — 연령대명 · **CM014** 라벨. 코드 = MEMBER_AGE_CD. 🔴빈 값은 두 갈래이며 **둘 다 개발약정 원천 행이 없는 경우**다 — 일시회원('ONCE')은 전건, 정기회원(FDRM)은 일부. 연령 개념은 존재하므로 '(해당없음)' 이 아니라 NULL 이고 미매핑도 없다. '미상' 으로 창작하지 않는다. 🔴**연속형 나이가 아니다** — 평균·재구간화 금지(원천이 이미 구간화해 제공한다). 🔴**현재 나이가 아니다** — 개발약정 시점 스냅샷이고 BRONZE 에 생년월일 축이 없어 시점정확 연령은 산출 불가다. ⚠️연령 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것.

### WIDE_SERVICE_EVENT.MEMBER_AGE_CD 
- 전: DIM_MEMBER.AGE — 연령대 원천코드 raw. 코드그룹 **CM014(나이)**. 코드사전 = 1'10대 미만'·2'10대'·3'20대'·4'30대'·5'40대'·6'50대'·7'60대'·8'70대'·9'70대 이상'·10단체·11기업·12기타 · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AGE)에 **사전 전종이 등장**한다. 🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지. 구간은 우리가 만든 것이 아니라 원천이 이미 구간화해 제공한다(DEC-28). ⚠️사전 자체에 8'70대'와 9'70대 이상'이 **의미 중복**으로 공존한다 — 70대 이상 집계 시 두 코드를 함께 취할 것. ⚠️BRONZE 원천 컬럼 COMMENT '연령'(NUMBER)은 오류다. 라벨 = MEMBER_AGE_BAND. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.AGE — 연령대 원천코드 raw. 코드그룹 **CM014(나이)**. 코드사전 = 1'10대 미만'·2'10대'·3'20대'·4'30대'·5'40대'·6'50대'·7'60대'·8'70대'·9'70대 이상'·10단체·11기업·12기타 · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AGE)에 **사전 전종이 등장**한다. 🔴**연속형 나이가 아니다** — 평균·구간 재계산 금지. 구간은 우리가 만든 것이 아니라 원천이 이미 구간화해 제공한다. ⚠️사전 자체에 8'70대'와 9'70대 이상'이 **의미 중복**으로 공존한다 — 70대 이상 집계 시 두 코드를 함께 취할 것. ⚠️BRONZE 원천 컬럼 COMMENT '연령'(NUMBER)은 오류다. 라벨 = MEMBER_AGE_BAND. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_SERVICE_EVENT.MEMBER_AREA_CD 
- 전: DIM_MEMBER.AREA_CD — 지역 원천코드 raw. 코드그룹 **CM018**. 코드사전 = (1서울·2경기·3인천·4강원·5대전·6충남·7충북·8광주·9전북·10전남·11대구·12경북·13경남·14울산·15부산·16제주·17기타·18세종) · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD)에 **사전 전종 + 라벨 없는 센티넬 '0'** 이 나타난다. ⚠️CM018 의 그룹명은 '신규시도구분'이지만 상세코드 값은 전부 시·도다(정본 공#131 지역정의가 약칭이라 정식명 그룹 CM011 이 아니다). 🔴**현재 거주지가 아니다** — 이 값은 그 버전 시점까지 최근 개발약정의 스냅샷이며 BRONZE 전체에 현주소 축이 없다(O34). 라벨 = MEMBER_REGION. 사건 시점 정확값은 WIDE_MEMBER_EVENT.AREA_CD_AT_EVENT. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.AREA_CD — 지역 원천코드 raw. 코드그룹 **CM018**. 코드사전 = (1서울·2경기·3인천·4강원·5대전·6충남·7충북·8광주·9전북·10전남·11대구·12경북·13경남·14울산·15부산·16제주·17기타·18세종) · 실적재(TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD)에 **사전 전종 + 라벨 없는 센티넬 '0'** 이 나타난다. ⚠️CM018 의 그룹명은 '신규시도구분'이지만 상세코드 값은 전부 시·도다(정본 공#131 지역정의가 약칭이라 정식명 그룹 CM011 이 아니다). 🔴**현재 거주지가 아니다** — 이 값은 그 버전 시점까지 최근 개발약정의 스냅샷이며 BRONZE 전체에 현주소 축이 없다. 라벨 = MEMBER_REGION. 사건 시점 정확값은 WIDE_MEMBER_EVENT.AREA_CD_AT_EVENT. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_SERVICE_EVENT.MEMBER_GENDER_NAME 
- 전: DIM_MEMBER.GENDER_NAME — 성별 분석 라벨(정본 공#130). 코드그룹 **CM017(회원특성(성별))**. CM017 은 CM013 과 **코드 도메인이 동일(1~8)한 재라벨 그룹**이며 국내/외국인 구분을 지운다 — 1남자·2여자·3남자·4여자·5기타·6단체·7기업·8기타 ⇒ **서로 다른 코드가 같은 라벨로 합쳐진다**(남자/여자/기타/단체/기업). 정본 공#130 값정의와 일치. ⚠️CM017 은 정본 컬럼정의서가 어떤 컬럼에도 지정하지 않은 그룹이다(현업 확인 대상). ⚠️종전 하드코딩 '여성/남성/미상'은 라벨을 축약하고 법인·단체를 '미상'으로 오라벨했다(O26 교정). 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.GENDER_NAME — 성별 분석 라벨(정본 공#130). 코드그룹 **CM017(회원특성(성별))**. CM017 은 CM013 과 **코드 도메인이 동일(1~8)한 재라벨 그룹**이며 국내/외국인 구분을 지운다 — 1남자·2여자·3남자·4여자·5기타·6단체·7기업·8기타 ⇒ **서로 다른 코드가 같은 라벨로 합쳐진다**(남자/여자/기타/단체/기업). 정본 공#130 값정의와 일치. ⚠️CM017 은 정본 컬럼정의서가 어떤 컬럼에도 지정하지 않은 그룹이다(현업 확인 대상). ⚠️종전 하드코딩 '여성/남성/미상'은 라벨을 축약하고 법인·단체를 '미상'으로 오라벨했다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_SERVICE_EVENT.MEMBER_REGION 
- 전: DIM_MEMBER.REGION — 지역명(정본 공#131) · **CM018** 약칭 라벨. 코드 = MEMBER_AREA_CD. 🔴빈 값이 세 갈래다 — ①일시회원(MEMBER_TYPE='ONCE')은 개발약정 **행 자체가 없어** NULL 이다(지역 개념은 존재하므로 '(해당없음)' 이 아니다) ②정기회원(FDRM) 중 개발약정이 없는 행도 NULL ③센티넬 코드 '0' 은 사전에 라벨이 없어 NULL. 🟢미매핑(코드는 있는데 사전에 없음)은 없다. '미상' 으로 창작하지 않는다(R2-7-1). 🔴**현재 거주지가 아니다** — 개발약정 시점 스냅샷이며 BRONZE 에 현주소 축이 없다(O34). ⚠️지역 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것 — ONCE 를 분모에 넣으면 채움률이 조용히 낮아진다(P128).
- 후: DIM_MEMBER.REGION — 지역명(정본 공#131) · **CM018** 약칭 라벨. 코드 = MEMBER_AREA_CD. 🔴빈 값이 세 갈래다 — ①일시회원(MEMBER_TYPE='ONCE')은 개발약정 **행 자체가 없어** NULL 이다(지역 개념은 존재하므로 '(해당없음)' 이 아니다) ②정기회원(FDRM) 중 개발약정이 없는 행도 NULL ③센티넬 코드 '0' 은 사전에 라벨이 없어 NULL. 🟢미매핑(코드는 있는데 사전에 없음)은 없다. '미상' 으로 창작하지 않는다. 🔴**현재 거주지가 아니다** — 개발약정 시점 스냅샷이며 BRONZE 에 현주소 축이 없다. ⚠️지역 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것 — ONCE 를 분모에 넣으면 채움률이 조용히 낮아진다.

### WIDE_SERVICE_EVENT.MEMBER_STATUS_NAME 
- 전: DIM_MEMBER.MEMBER_STATUS_NAME — 회원상태명(MM010 라벨, 정본 공#132). 코드 = MBER_STAT_CD. MM010 은 **폐지코드가 없고 실적재가 사전과 일치**한다 ⇒ 사전 조인만으로 전건 라벨화된다(하드코딩 금지 P31). 값 = 활동회원 / 신규미납1~5 / 장기미납1~5 / 후원중단. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원(DIM_MEMBER.MEMBER_TYPE='ONCE')은 회원상태 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원(FDRM) 중 원천 상태코드 자체가 결손인 행만 **NULL** 이다. 두 사건을 '미상' 같은 한 값으로 뭉개지 않는다(R2-7-1). ⚠️미납 단계(1~5)는 **경과 차수**이며 금액 규모가 아니다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.MEMBER_STATUS_NAME — 회원상태명(MM010 라벨, 정본 공#132). 코드 = MBER_STAT_CD. MM010 은 **폐지코드가 없고 실적재가 사전과 일치**한다 ⇒ 사전 조인만으로 전건 라벨화된다(하드코딩 금지). 값 = 활동회원 / 신규미납1~5 / 장기미납1~5 / 후원중단. 🔴빈 값이 두 가지 뜻으로 갈린다 — 일시회원(DIM_MEMBER.MEMBER_TYPE='ONCE')은 회원상태 개념이 **원천에 없어** 센티넬 '(해당없음)' 이고, 정기회원(FDRM) 중 원천 상태코드 자체가 결손인 행만 **NULL** 이다. 두 사건을 '미상' 같은 한 값으로 뭉개지 않는다. ⚠️미납 단계(1~5)는 **경과 차수**이며 금액 규모가 아니다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_SERVICE_EVENT.MEMBER_STOP_FLAG 
- 전: 결연회원 중단여부 🔴🔴[O51-D 실측] **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MESSAGE_DISPATCH.MEMBER_STOP_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. 실측 규모는 이슈원장 §O51-D-C.
- 후: 결연회원 중단여부 🔴🔴 **전건 NULL** — **팩트 컬럼 자체가 비어 있다**(`FACT_MESSAGE_DISPATCH.MEMBER_STOP_FLAG`). 결측이 아니라 **미적재**다: 0·FALSE·'해당없음' 으로 대체 해석하지 말 것. 필터 조건으로 쓰면 전건이 탈락한다.

### WIDE_SERVICE_EVENT.MEMBER_TYPE_NAME 
- 전: DIM_MEMBER.MEMBER_TYPE_NAME — 회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. MM018 은 폐지코드가 없고 실적재가 사전과 일치한다. 🟢빈 값이 없는 축이다 — 센티넬 '(해당없음)'·NULL 모두 없고 전건 라벨화된다. 앞으로 사전에 없는 코드가 인입되면 **NULL 로 드러나며** '미상' 같은 값으로 덮지 않는다(R2-7-1). 🔴이름이 비슷한 DIM_MEMBER.MEMBER_TYPE(=FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다** — 다른 축이다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다(회원당 버전 수는 이슈원장 참조)
- 후: DIM_MEMBER.MEMBER_TYPE_NAME — 회원구분명(MM018 라벨): 개인·기업·단체. 코드 = MBER_DIV_CD. MM018 은 폐지코드가 없고 실적재가 사전과 일치한다. 🟢빈 값이 없는 축이다 — 센티넬 '(해당없음)'·NULL 모두 없고 전건 라벨화된다. 앞으로 사전에 없는 코드가 인입되면 **NULL 로 드러나며** '미상' 같은 값으로 덮지 않는다. 🔴이름이 비슷한 DIM_MEMBER.MEMBER_TYPE(=FDRM 정기회원 / ONCE 일시회원)의 라벨이 **아니다** — 다른 축이다. 🔴 회원 **현재버전**(DIM_MEMBER IS_CURRENT 1건) 스냅샷이며 사건 시점 값이 아니다 — SCD2 다버전을 순진하게 조인하면 조용히 팬아웃한다

### WIDE_SERVICE_EVENT.SEND_RESULT_NAME 
- 전: 축B 라벨 (CRM_CODE 조인). 사전 초과값은 NULL 유지 + dbt warn 관측(DEC-17-B · 센티넬 창작 금지) — 미매칭 규모는 이슈원장 §O59-N·문서20 §M-5
- 후: 축B 라벨 (CRM_CODE 조인). 사전 초과값은 NULL 유지 + dbt warn 관측(센티넬 창작 금지) —

### WIDE_SERVICE_EVENT.SEND_TYPE_L 
- 전: DIM_SEND_TYPE.SEND_TYPE_L — 발송구분(대) 분석 라벨(정본 공#133) ← SND_REQ_MST.SEND_GBN_TOP_NM. 코드 = SEND_TYPE_L_CD. [O51-D 실측] **여러 코드가 같은 라벨로 축약**된다 — 결연=MS046+MS051 · 기타=MS0505+MS055 · 회원=MS047+MS053. ⇒ 라벨로 GROUP BY 하면 코드가 합쳐진다(대분류는 코드그룹과 1:1 이 아니다). 🔴정본 공#133 과 **불일치**: #133 은 결연/회비/서비스/사업보고/참여/기타 만 열거하는데 실측 라벨에는 **회원만족(MS052)·회원서비스(MS054)·회원(MS047+MS053)이 더 있다.** #133 에 생략기호가 없어 완전열거로 읽히므로 불일치는 실재한다 → 현업 확인 대상, 데이터 우선 보존(DEC-26). ⚠️커버리지가 낮다 — 비매칭은 센티넬 '(미매핑)'(DEC-30). 규모는 이슈원장 §O51-D-C 참조. 🔴🔴[O51-D 실측] `'(미매핑)'` 이 **과반을 크게 넘는다** — 발송구분 대분류는 매칭되는 행이 소수다. 커버리지를 모르고 대분류별 비중을 내면 **결론이 뒤집힌다.** 실측 규모는 이슈원장 §O51-D-C.
- 후: DIM_SEND_TYPE.SEND_TYPE_L — 발송구분(대) 분석 라벨(정본 공#133) ← SND_REQ_MST.SEND_GBN_TOP_NM. 코드 = SEND_TYPE_L_CD. **여러 코드가 같은 라벨로 축약**된다 — 결연=MS046+MS051 · 기타=MS0505+MS055 · 회원=MS047+MS053. ⇒ 라벨로 GROUP BY 하면 코드가 합쳐진다(대분류는 코드그룹과 1:1 이 아니다). 🔴정본 공#133 과 **불일치**: #133 은 결연/회비/서비스/사업보고/참여/기타 만 열거하는데 실측 라벨에는 **회원만족(MS052)·회원서비스(MS054)·회원(MS047+MS053)이 더 있다.** #133 에 생략기호가 없어 완전열거로 읽히므로 불일치는 실재한다 → 현업 확인 대상, 데이터 우선 보존. ⚠️커버리지가 낮다 — 비매칭은 센티넬 '(미매핑)'. 🔴🔴 `'(미매핑)'` 이 **과반을 크게 넘는다** — 발송구분 대분류는 매칭되는 행이 소수다. 커버리지를 모르고 대분류별 비중을 내면 **결론이 뒤집힌다.**

### WIDE_SERVICE_EVENT.SEND_TYPE_L_CD 
- 전: DIM_SEND_TYPE.SEND_GBN_TOP — 발송구분(대) 코드 raw. 🔴🔴**이 값은 상세코드가 아니라 CRM_CODE 의 코드그룹 ID(CD_ID) 자체다.** [O51-D 실측] `SND_REQ_MST.SEND_GBN_TOP` 실적재 값 = **MS046·MS047·MS048·MS049·MS050·MS0501·MS0505·MS051·MS052·MS053·MS054·MS055** 이며 **전부 `TC_CMMN_CD.CD_ID` 에 실재**한다. ⇒ 상세코드 사전(`TC_CMMN_DTL_CD`)에서 찾으면 나오지 않는다. 라벨 = SEND_TYPE_L.
- 후: DIM_SEND_TYPE.SEND_GBN_TOP — 발송구분(대) 코드 raw. 🔴🔴**이 값은 상세코드가 아니라 CRM_CODE 의 코드그룹 ID(CD_ID) 자체다.** `SND_REQ_MST.SEND_GBN_TOP` 실적재 값 = **MS046·MS047·MS048·MS049·MS050·MS0501·MS0505·MS051·MS052·MS053·MS054·MS055** 이며 **전부 `TC_CMMN_CD.CD_ID` 에 실재**한다. ⇒ 상세코드 사전(`TC_CMMN_DTL_CD`)에서 찾으면 나오지 않는다. 라벨 = SEND_TYPE_L.

### WIDE_SERVICE_EVENT.SEND_TYPE_M_CD 
- 전: DIM_SEND_TYPE.SEND_GBN_MID — 발송구분(중) 코드 raw ← SND_REQ_MST.SEND_GBN_MID. 🔴🔴**코드 단독 사용 금지 — 이 코드는 부모(대) 그룹 안에서만 유일하다.** [O51-D BRONZE 실측] 값 '01' 이 부모에 따라 '결제오류'·'모바일소식지(사단)'·'기타_사단'·'기부금영수증(사단)'·'기타' 등 서로 다른 뜻이며 실적재 (코드,라벨) 쌍 37종이 나온다. ⇒ 반드시 **(대,중) 쌍**으로 해석할 것. 라벨 = SEND_TYPE_M.
- 후: DIM_SEND_TYPE.SEND_GBN_MID — 발송구분(중) 코드 raw ← SND_REQ_MST.SEND_GBN_MID. 🔴🔴**코드 단독 사용 금지 — 이 코드는 부모(대) 그룹 안에서만 유일하다.** 값 '01' 이 부모에 따라 '결제오류'·'모바일소식지(사단)'·'기타_사단'·'기부금영수증(사단)'·'기타' 등 서로 다른 뜻이며 실적재 (코드,라벨) 쌍 37종이 나온다. ⇒ 반드시 **(대,중) 쌍**으로 해석할 것. 라벨 = SEND_TYPE_M.

### WIDE_SERVICE_EVENT.SEND_TYPE_S_CD 
- 전: DIM_SEND_TYPE.SEND_GBN_BOT — 발송구분(소) 코드 raw ← SND_REQ_MST.SEND_GBN_BOT (CRM_CODE.UPPER_CD_ID 계층 하위). 🔴**코드 단독 모호** — [O51-D 실측] 같은 코드('0101'·'0401' 등)가 부모에 따라 다른 뜻이다. ⇒ **(대,중,소) 경로**로만 해석할 것. 라벨 = SEND_TYPE_S.
- 후: DIM_SEND_TYPE.SEND_GBN_BOT — 발송구분(소) 코드 raw ← SND_REQ_MST.SEND_GBN_BOT (CRM_CODE.UPPER_CD_ID 계층 하위). 🔴**코드 단독 모호** — 같은 코드('0101'·'0401' 등)가 부모에 따라 다른 뜻이다. ⇒ **(대,중,소) 경로**로만 해석할 것. 라벨 = SEND_TYPE_S.

### WIDE_TARGET_BIZ.ANNUAL_GOAL_CNT 
- 전: 당초 목표값(#152). 🔴 단위는 GOAL_TYPE_NM 에 따른다(건·명·원·비율) — 유형 필터 없이 합산 금지 · O190
- 후: 당초 목표값(#152). 🔴 단위는 GOAL_TYPE_NM 에 따른다(건·명·원·비율) — 유형 필터 없이 합산 금지

### WIDE_TARGET_BIZ.CPR_DIV_NM 
- 전: 법인구분 (사단/사복) (O188).
- 후: 법인구분 (사단/사복).

### WIDE_TARGET_BIZ.DTL_DIV_NM 
- 전: 세부구분 원천 표기(채널 등 · 회원개발 유형만 · 그 외 NULL) · O190.
- 후: 세부구분 원천 표기(채널 등 · 회원개발 유형만 · 그 외 NULL).

### WIDE_TARGET_BIZ.GOAL_TYPE_NM 
- 전: 목표 지표 유형 원천 표기 그대로(O190 · 9종): 건 = 후원사업·회원개발 / 명 = 월말활동회원 / 원 = 정기회비 / 비율 = 후원사업활동율·신규기존활동율·후원사업납입율·신규기존납입율·신규기존누계납입율. 🔴 유형마다 단위가 달라 섞어 합산하지 말 것 · 후원사업과 회원개발은 같은 개발 목표의 다른 분해(문서20 N-24).
- 후: 목표 지표 유형 원천 표기 그대로(9종): 건 = 후원사업·회원개발 / 명 = 월말활동회원 / 원 = 정기회비 / 비율 = 후원사업활동율·신규기존활동율·후원사업납입율·신규기존납입율·신규기존누계납입율. 🔴 유형마다 단위가 달라 섞어 합산하지 말 것 · 후원사업과 회원개발은 같은 개발 목표의 다른 분해.

### WIDE_TARGET_BIZ.NEW_OLD_DIV_NM 
- 전: 신규/기존 구분 원천 표기. 🔴 비율 유형에는 소계 행(합계·신규합계)이 있다 — 신규/기존과 함께 합산하면 이중계상. 회원개발 유형은 NULL · O190.
- 후: 신규/기존 구분 원천 표기. 🔴 비율 유형에는 소계 행(합계·신규합계)이 있다 — 신규/기존과 함께 합산하면 이중계상. 회원개발 유형은 NULL.

### WIDE_TARGET_BIZ.ORG_CORP 
- 전: DIM_ORG.CORP — 법인 (#114). 🔴DIM_ORG 는 **SCD1**(DEC-2)이라 as-was 가 아니다 — 조직 개편 시 과거 사건에도 **현재 조직명**이 붙는다(조직 변경이력 원천·as-was 요구가 없어 SCD1 로 확정).
- 후: DIM_ORG.CORP — 법인 (#114). 🔴DIM_ORG 는 **SCD1**이라 as-was 가 아니다 — 조직 개편 시 과거 사건에도 **현재 조직명**이 붙는다(조직 변경이력 원천·as-was 요구가 없어 SCD1 로 확정).

### WIDE_TARGET_BIZ.ORG_DEPARTMENT 
- 전: DIM_ORG.DEPARTMENT — 부서 (#116). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴「부서」는 축이 둘이다 — 이 컬럼은 **사건 부서**이고 획득 부서는 DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT 다(O34).
- 후: DIM_ORG.DEPARTMENT — 부서 (#116). 🔴SCD1 — current-value 이며 as-was 가 아니다. 🔴🔴「부서」는 축이 둘이다 — 이 컬럼은 **사건 부서**이고 획득 부서는 DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT 다.

### WIDE_TARGET_BIZ.ORG_DIVISION 
- 전: DIM_ORG.DIVISION — 본부/지부 (#115). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다.
- 후: DIM_ORG.DIVISION — 본부/지부 (#115). 🔴SCD1 — current-value 이며 as-was 가 아니다.

### WIDE_TARGET_BIZ.ORG_DIV_NM 
- 전: O188-E 조직구분(본부/지부/대면) — 원천 표기.
- 후: 조직구분(본부/지부/대면) — 원천 표기.

### WIDE_TARGET_BIZ.ORG_PATH 
- 전: O188-E 조직표 부서 경로(DIM_ORG.ORG_PATH · 활성 조직 트리 · 매칭 실패 행은 NULL).
- 후: 조직표 부서 경로(DIM_ORG.ORG_PATH · 활성 조직 트리 · 매칭 실패 행은 NULL).

### WIDE_TARGET_BIZ.ORG_TEAM 
- 전: DIM_ORG.TEAM — 팀. 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다.
- 후: DIM_ORG.TEAM — 팀. 🔴SCD1 — current-value 이며 as-was 가 아니다.

### WIDE_TARGET_BIZ.SRC_SPONSOR_BIZ_NM 
- 전: 원천 후원사업 표기 그대로 — 후원사업 유형 = 사업명 · 회원개발 유형 = 4그룹(국내/결연/해외프로젝트/기타) · O190.
- 후: 원천 후원사업 표기 그대로 — 후원사업 유형 = 사업명 · 회원개발 유형 = 4그룹(국내/결연/해외프로젝트/기타).

### WIDE_TARGET_BIZ.SRC_TEAM_NM 
- 전: O188-E 원천 팀명(TEAM_NM) 그대로 — 조직 차원 매칭 실패(동명·비조직명) 행도 이 값으로 구분된다.
- 후: 원천 팀명(TEAM_NM) 그대로 — 조직 차원 매칭 실패(동명·비조직명) 행도 이 값으로 구분된다.

### WIDE_TARGET_DEV.ORG_CORP 
- 전: DIM_ORG.CORP — 법인 (#114). 🔴DIM_ORG 는 **SCD1**(DEC-2)이라 as-was 가 아니다 — 조직 개편 시 과거 사건에도 **현재 조직명**이 붙는다(조직 변경이력 원천·as-was 요구가 없어 SCD1 로 확정). 🔴🔴[O51-F 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.CORP`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4). 실측 규모는 이슈원장 §O51-F.
- 후: DIM_ORG.CORP — 법인 (#114). 🔴DIM_ORG 는 **SCD1**이라 as-was 가 아니다 — 조직 개편 시 과거 사건에도 **현재 조직명**이 붙는다(조직 변경이력 원천·as-was 요구가 없어 SCD1 로 확정). 🔴🔴 **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.CORP`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다.

### WIDE_TARGET_DEV.ORG_DEPARTMENT 
- 전: DIM_ORG.DEPARTMENT — 부서 (#116). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴「부서」는 축이 둘이다 — 이 컬럼은 **사건 부서**이고 획득 부서는 DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT 다(O34).
- 후: DIM_ORG.DEPARTMENT — 부서 (#116). 🔴SCD1 — current-value 이며 as-was 가 아니다. 🔴🔴「부서」는 축이 둘이다 — 이 컬럼은 **사건 부서**이고 획득 부서는 DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT 다.

### WIDE_TARGET_DEV.ORG_DIVISION 
- 전: DIM_ORG.DIVISION — 본부/지부 (#115). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴[O51-F 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.DIVISION`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4). 실측 규모는 이슈원장 §O51-F.
- 후: DIM_ORG.DIVISION — 본부/지부 (#115). 🔴SCD1 — current-value 이며 as-was 가 아니다. 🔴🔴 **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.DIVISION`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다.

### WIDE_TARGET_DEV.ORG_TEAM 
- 전: DIM_ORG.TEAM — 팀. 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴[O51-F 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.TEAM`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4). 실측 규모는 이슈원장 §O51-F.
- 후: DIM_ORG.TEAM — 팀. 🔴SCD1 — current-value 이며 as-was 가 아니다. 🔴🔴 **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.TEAM`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다.

_Co-authored with CoCo_
