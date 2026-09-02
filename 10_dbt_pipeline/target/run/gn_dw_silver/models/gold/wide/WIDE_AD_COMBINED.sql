create or replace view GN_DW.GOLD.WIDE_AD_COMBINED
    (
      AD_PERF_DK COMMENT $$행 식별자(GRAIN·PK) MD5(AD_SOURCE_TYPE|ROW_HASH|DUP_SEQ). 위성 3종 조인키. 발급지점=SILVER.AGENCY_AD_ROW_* (DEC-11)$$,
      PERF_DATE_SK COMMENT $$실적일 (분석축, FK→DIM_DATE)$$,
      CAMPAIGN_SK COMMENT $$캠페인 (분석축, FK→DIM_CAMPAIGN). ⚠️현재 0 스캐폴드 — Q10 이름매칭 대기$$,
      MKTG_CAMPAIGN_SK COMMENT $$[O45] 마케팅캠페인 대리키 (FK→DIM_MARKETING_CAMPAIGN). 광고↔CRM 결합축. 🔴미도달 행은 0(미매핑) 버킷이며 이 버킷을 「미집행」으로 읽지 말 것 — 도달률 실측은 이슈원장 §O45. 🔴개발캠페인(CAMPAIGN_SK) grain 결합 금지 — 광고비가 대규모로 팬아웃한다(배수 실측 = 이슈원장 §O45).$$,
      AD_CREATIVE_SK COMMENT $$광고소재/매체 (분석축, FK→DIM_AD_CREATIVE). ⚠️현재 0 스캐폴드 — 부분키 매칭 설계 대기$$,
      DEVICE_SK COMMENT $$디바이스 (분석축, FK→DIM_DEVICE). DEC-10 실배선: 실기기 해시SK / 방송=(해당없음) / 미매핑=0$$,
      AD_COST COMMENT $$광고비(원) (#6). 원천별 컬럼 상이 — COST_TYPE 은 SILVER 보유$$,
      IMPRESSIONS COMMENT $$노출수 (#23). DIGITAL 전용(방송 원천 부재)$$,
      CLICKS COMMENT $$클릭수(행동 횟수, ≠회원명) (#24). DIGITAL 전용. CTR 분자 공#9$$,
      INBOUND_CALL COMMENT $$인입콜 (#25). REBRDC(TEXT→TRY_TO_NUMBER)·VIDEO 보유, DGT 부재$$,
      GA_CONV_MEMBERS COMMENT $$GA전환수(명) — **DIGITAL 전용**. ⚠️O16 교정(2026-07-28): 종전에 REBRDC 개발회원수가 혼입돼 있었다 — 재방송 개발실적은 FACT_AD_BROADCAST.DVLP_MEMBER_CNT 로 이관했다. 혼입 규모 = 이슈원장 §O16.$$,
      GA_CONV_CNT COMMENT $$GA전환수(건/VU) — **DIGITAL 전용**. ⚠️O16 교정(2026-07-28): 종전에 REBRDC 개발건수가 혼입돼 있었고 그 비중이 과반이었다 → FACT_AD_BROADCAST.DVLP_CNT 로 이관. 혼입 규모 = 이슈원장 §O16. ⚠️합계가 소수로 나오므로 건수가 아니다 — 어의 현업확인 잔여(O5).$$,
      DAY_OF_WEEK COMMENT $$요일 (degen, AD_DATE 파생)$$,
      WEEK_OF_YEAR COMMENT $$주차 (degen, AD_DATE 파생)$$,
      AD_SOURCE_TYPE COMMENT $$광고유형 DIGITAL/VIDEO/REBROADCAST (degen). 출처 명시축(DEC-8·§3-A-4) — DW_SOURCE_SYSTEM(시스템 출처)과 2단 추적. DEVICE_TYPE=(해당없음) 행의 방송 여부 판별 수단$$,
      PAGE_TYPE COMMENT $$페이지유형 ← DGT.PAGE_TYPE_NM ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      AD_GROUP_NM COMMENT $$광고그룹명 ← DGT.AD_GRP_NM ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      GROUP_DIV COMMENT $$그룹구분 ← DGT.GRP_DIV_NM ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      CREATIVE_TYPE COMMENT $$소재유형 ← DGT.MATR_TY_NM ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      AD_TYPE_NM COMMENT $$광고유형명(대행사 표기) ← DGT.AD_TY_NM. ⚠️코어 AD_SOURCE_TYPE(원천 출처축 DIGITAL/VIDEO/REBROADCAST)과 다른 개념 ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      READ_CNT COMMENT $$읽음수 ← DGT.READ_CNT (가산) ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      MEDIA_POTENTIAL_CUST_CNT COMMENT $$매체 잠재고객수 ← DGT.MEDIA_PTNT_CUST_CNT (가산) ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. 🆕🔴🔴[2026-09-01 O129 보강] **디지털행도 전건 NULL 이다** — 원천 `BRONZE_AGENCY.DGT_AD_CMPGN_DTLS.MEDIA_PTNT_CUST_CNT` 는 컬럼은 실재하고 **값이 전건 공백**(대행사 미보고)이다. ⇒ 🔴 스코프를 디지털로 좁혀도 값은 나오지 않는다 — 이 컬럼은 현재 **어떤 스코프에서도 집계 불가**다(0/'해당없음' 대체 해석 금지 · P21). 정본 = 문서30 §7-C.$$,
      CRM_DEV_CNT COMMENT $$CRM 개발건수 ← DGT.CRM_DVLP_CNT (가산) ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      CTR_SRC COMMENT $$[비가산 N] 대행사 산정 CTR ← DGT.CTR. DW 재계산=CLICKS/IMPRESSIONS ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      CVR_SRC COMMENT $$[비가산 N] 대행사 산정 CVR ← DGT.CVR. DW 재계산=GA_CONV_MEMBERS/CLICKS (O5 확정) ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      CPC_SRC COMMENT $$[비가산 N] 대행사 산정 CPC ← DGT.CPC. DW 재계산=AD_COST/CLICKS ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      CPM_SRC COMMENT $$[비가산 N] 대행사 산정 CPM ← DGT.CPM. DW 재계산=AD_COST/IMPRESSIONS×1000 ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      CPA_SRC COMMENT $$[비가산 N] 대행사 산정 CPA ← DGT.CPA. DW 재계산=AD_COST/GA_CONV_CNT ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      DEV_UNIT_PRICE_SRC COMMENT $$[비가산 N] 대행사 산정 개발단가 ← DGT.DEV_UNIT_PRICE. DW 재계산=AD_COST/개발건수 ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      VTR_SRC COMMENT $$[비가산 N] 대행사 산정 VTR ← DGT.VTR. base 부재로 재계산 불가(대조 대상 아닌 유일값) ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 **NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      TIME_BAND COMMENT $$시간대 ← VIDEO.TIME_RNG / REBRDC.TIME_RNG_DIV_NM(1순위)·BRDC_TIME(대체). 코어에서 이관(종전 CAST(NULL) 하드코딩) ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      CM_POSITION COMMENT $$CM위치 ← VIDEO.CM_AREA [VIDEO 전용]. 코어에서 이관 ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      RT_TYPE COMMENT $$RT(재방송)유형 ← REBRDC.RE_BRDC_TY_NM [REBRDC 전용]. 코어에서 이관 ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      AD_START_TIME COMMENT $$광고시작시간 ← VIDEO.AD_STRT_TIME [VIDEO 전용]. 코어에서 이관 🔴🔴[WIDE_AD_COMBINED] **VIDEO(본방송) 전용이다** — 재방송(REBRDC) 원천에는 이 컬럼이 **아예 없다**(BRONZE `REBRDC_AD_CMPGN_DTLS` 에 시각 컬럼 부재 · 보유 항목은 방송시간·방송월뿐). 따라서 재방송행의 NULL 은 적재 지연이 아니라 **해당 없음**이다(P20 3분류). 시각 기반 분석은 VIDEO 로 스코프하고, 재방송을 포함한 시간대 분석은 TIME_BAND 를 쓸 것. 전용축 판정 근거 = 이슈원장 §429.$$,
      AD_END_TIME COMMENT $$광고종료시간 ← VIDEO.AD_END_TIME [VIDEO 전용]. 신규 노출 🔴🔴[WIDE_AD_COMBINED] **VIDEO(본방송) 전용이다** — 재방송(REBRDC) 원천에는 이 컬럼이 **아예 없다**(BRONZE `REBRDC_AD_CMPGN_DTLS` 에 시각 컬럼 부재 · 보유 항목은 방송시간·방송월뿐). 따라서 재방송행의 NULL 은 적재 지연이 아니라 **해당 없음**이다(P20 3분류). 시각 기반 분석은 VIDEO 로 스코프하고, 재방송을 포함한 시간대 분석은 TIME_BAND 를 쓸 것. 전용축 판정 근거 = 이슈원장 §429.$$,
      BROADCAST_DATE COMMENT $$송출일 ← VIDEO.BRDC_DATE / REBRDC.DATE. ⚠️코어 PERF_DATE_SK(실적일)와 구분. 코어에서 이관 🔴[WIDE_AD_COMBINED] **송출일이며 코어의 실적일(PERF_DATE_SK)과 다른 축**이다 — 둘을 같은 시간축으로 섞지 말 것. 🟢본방송(VIDEO)·재방송(REBRDC) **양 원천 모두에 있다**(BRONZE `VIDEO_AD_CMPGN_DTLS.BRDC_DATE` · `REBRDC_AD_CMPGN_DTLS.DATE`) — 같은 방송 위성의 시각 3컬럼(AD_START_TIME·AD_END_TIME·PRG_START_TIME)이 VIDEO 전용인 것과 **다르다**. ⇒ 재방송을 포함한 **일자 단위** 방송 분석은 이 컬럼으로 가능하다. 디지털행은 원천 부재로 NULL.$$,
      PROGRAM_NM COMMENT $$프로그램/편성명 ← VIDEO.SCHDL_NM / REBRDC.BRDC_NM ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      CHANNEL_COMPANY COMMENT $$채널사 ← VIDEO.CHNNL_NM / REBRDC.CHNNL_CMPNY ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      CHANNEL_COMPANY_TYPE COMMENT $$채널사유형 ← VIDEO.CHNNL_CMPNY_TY_NM [VIDEO 전용] ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      SPOT_TYPE COMMENT $$SPOT유형 ← VIDEO.SPOT_TY [VIDEO 전용] ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      DURATION_SEC COMMENT $$🔴 광고 초수 ← VIDEO.AD_SEC(TEXT→TRY_TO_NUMBER) [VIDEO 전용] — **현재 값 신뢰 금지(O29)**. 적재값의 스케일이 「초」로 읽으면 맞지 않는다(µs 해석 유력하나 미확정·현업 확인 대기). 원천 HH:MM:SS 형식 행이 캐스팅에서 무성 소실돼 유효 커버리지가 매우 낮다(파싱하면 대부분 회복) — 규모 실측은 이슈원장 §O29. REBRDC NULL 은 결손이 아니라 원천 부재. ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      DAY_DIV COMMENT $$요일구분 평일/주말 ← VIDEO.DAY_DIV_NM [VIDEO 전용] ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      PRG_START_TIME COMMENT $$프로그램 시작시간 ← VIDEO.PRG_STRT_TIME [VIDEO 전용] 🔴🔴[WIDE_AD_COMBINED] **VIDEO(본방송) 전용이다** — 재방송(REBRDC) 원천에는 이 컬럼이 **아예 없다**(BRONZE `REBRDC_AD_CMPGN_DTLS` 에 시각 컬럼 부재 · 보유 항목은 방송시간·방송월뿐). 따라서 재방송행의 NULL 은 적재 지연이 아니라 **해당 없음**이다(P20 3분류). 시각 기반 분석은 VIDEO 로 스코프하고, 재방송을 포함한 시간대 분석은 TIME_BAND 를 쓸 것. 전용축 판정 근거 = 이슈원장 §429.$$,
      CTV_DIV COMMENT $$CTV구분 ← VIDEO.CTV_DIV_NM [VIDEO 전용] ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      BRDC_DIV COMMENT $$방송구분 ← REBRDC.BRDC_DIV_NM [REBRDC 전용] ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      AD_CNT COMMENT $$광고횟수 ← VIDEO·REBRDC.AD_CNT (가산) ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      CONV_CALL_CNT COMMENT $$전환콜 ← VIDEO.CONV_CALL_CNT [VIDEO 전용]. 코어 INBOUND_CALL(인입콜)과 별개 measure ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. 🆕🔴🔴[2026-09-01 O129 보강] **VIDEO 행도 전건 NULL 이다** — 원천 `BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.CONV_CALL_CNT` 는 컬럼은 실재하고 **값이 전건 공백**(대행사 미보고)이다(REBROADCAST 원천에는 컬럼 자체가 없다). ⇒ 🔴 스코프를 VIDEO 로 좁혀도 값은 나오지 않는다 — **어떤 스코프에서도 집계 불가**다. ⚠️ 인입콜(`REBRDC.INBOUND_CALL_CNT`)은 채워져 있으니 **두 축을 혼동하지 말 것**. 정본 = 문서30 §7-C.$$,
      DVLP_MEMBER_CNT COMMENT $$개발회원수 ← REBRDC.DVLP_MBER_CNT [REBRDC 전용]. ⚠️O16 이관: 종전에 코어 GA_CONV_MEMBERS 로 혼입돼 있었다(GA 전환이 아니라 재방송 개발실적). ⚠️소수 척도를 유지하는 이유 = 원천에 0.5 단위 값이 실존해 정수 타입으로 내리면 반올림이 총합을 왜곡한다 — 해당 행·왜곡 규모는 이슈원장 §O16. 원천값 보존 우선. ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      DVLP_CNT COMMENT $$개발건수 ← REBRDC.DVLP_CNT [REBRDC 전용]. ⚠️O16 이관: 종전 코어 GA_CONV_CNT 로 혼입(GA 전환 아님) ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.$$,
      BRDC_AD_VIEW_RT_SRC COMMENT $$[비가산 N] 대행사 산정 광고시청률 ← VIDEO.AD_VIEW_RT [VIDEO 전용]. base 부재로 DW 재계산 불가 ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. ⚠️[WIDE_AD_COMBINED] 디지털 위성에 동명 컬럼이 있어 **BRDC_ 접두**를 붙였다 — 이 컬럼은 방송 원천값이다. 디지털 쪽 동명 컬럼과 같은 표에서 비교하지 말 것.$$,
      BRDC_CPC_SRC COMMENT $$[비가산 N] 대행사 산정 CPC ← VIDEO.CPC(TEXT) [VIDEO 전용]. DW 재계산=AD_COST/CLICKS (DEC-9 대조용) ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것. ⚠️[WIDE_AD_COMBINED] 디지털 위성에 동명 컬럼이 있어 **BRDC_ 접두**를 붙였다 — 이 컬럼은 방송 원천값이다. 디지털 쪽 동명 컬럼과 같은 표에서 비교하지 말 것.$$
    )
    comment = $$GOLD 광고 팩트 3종(FAP 코어 + FAD 디지털위성 + FAB 방송위성)을 AD_PERF_DK 로 1:1 pre-join 한 소비뷰 — PK=AD_PERF_DK(전건 유일·fan-out 0). 위성은 원천유형별 완전분할이라 LEFT JOIN 이 행수를 늘리지 않는다(디지털행=방송컬럼 NULL, 방송행=디지털컬럼 NULL — **결측이 아니라 원천 부재**). 🔴디지털/방송 measure 는 상호배타다 — AD_SOURCE_TYPE 필터 없이 혼합 집계하면 왜곡된다. 🔴1:N 위성 FACT_AD_BROADCAST_CASE 는 의도적으로 제외했다(사례 수만큼 광고비 복제). 🔴🔴[O53 신설] 종전 SERVING.FACT_AD_COMBINED(helper 뷰 · SQL 스크립트 소유)를 대체한다 — SV 가 GOLD 만 참조하도록 계층을 올리고 소유주를 dbt 로 옮겼다(DEC-34 ③ · 팩트를 재구성하므로 ref() 위상정렬 필수). 종전 helper 에 없던 **방송 시간축 4컬럼(AD_START_TIME·AD_END_TIME·BROADCAST_DATE·PRG_START_TIME)을 추가**했다 — 그 4컬럼은 VIDEO 전용이며 재방송에는 원천 자체가 없다. ⚠️SV_AD base 재배선은 로드맵 6단계 소관이다. ⚠️원천 증량(캠페인 상위코드·공통코드 신설 예정 · 문서40 CMP-1) 시 이 모델 1곳 + 차원만 고치면 반영된다.$$
    as (
      -- O53 — `GOLD.WIDE_AD_COMBINED`(dbt 소유 GOLD 뷰) 모델 + yml columns[] 기계 생성.
-- Co-authored with CoCo
--
-- 무엇을 만드는가
--   광고 팩트 3종(FAP 코어 + FAD 디지털위성 + FAB 방송위성)을 `AD_PERF_DK` 로 1:1 pre-join 한
--   **51컬럼 GOLD 뷰**. SV_AD 의 새 base 다(재배선은 O53 6단계).
--
-- 왜 GOLD 뷰인가 (사용자 제약 3개를 동시에 만족하는 유일 형태)
--   ① 데이터 중복 저장 불가        → 뷰(물리 저장 0)
--   ② SV 는 GOLD 만 본다           → 스키마를 SERVING → GOLD 로 올린다
--   ③ 다음 주 신설 코드 즉시 반영   → dbt 모델 1곳 수정 + ref() 위상정렬·리니지·build 게이트
--   DEC-34 분류상 **③(팩트를 재구성 → ref() 필수)** 에 정확히 해당한다.
--   ⚠️ 대가: SV_AD 가 「dbt build 없이는 배포 불가」 계열로 편입된다.
--
-- 종전 대비 달라지는 것
--   · 스키마 SERVING → GOLD · 소유주 SQL 스크립트(05_7_SV_DDL_AD.sql 내부) → dbt 모델
--   · **방송 시간축 4컬럼 추가**(AD_START_TIME·AD_END_TIME·BROADCAST_DATE·PRG_START_TIME)
--     → helper 뷰가 이 4컬럼을 빼고 있어 SV_AD 에서 방송 시각 축이 도달 불가였다.
--
-- 문안: 신규 작성 0 — `06_DDL.sql` 의 세 팩트 인라인 COMMENT 를 파싱해 이관한다.
--   · 이름이 바뀐 2컬럼(BRDC_AD_VIEW_RT_SRC·BRDC_CPC_SRC)은 접두 사유를 덧붙인다.
--   · 방송 전용 컬럼에는 **디지털행 NULL = 원천 부재** 경고를 덧붙인다(P20 — 시간축 NULL 3분류).
--   · 시간축 4컬럼에는 **VIDEO 전용 · REBRDC 구조적 부재** 를 덧붙인다(원장 §429 기지 사실).
--
-- ⚠️ 컬럼 COMMENT 정본 = `_wide_schema.yml` columns[] (materialized='gn_view_commented').
--   SELECT 컬럼·순서를 바꾸면 `scripts/gen_o53_ad_combined.py` 로 **동시 재생성**할 것 —
--   Snowflake 는 CREATE VIEW 컬럼목록과 SELECT 개수·순서가 정확히 일치해야 한다.


select
    -- ── 코어(FAP) — 3원천 공통 ──
    fap.AD_PERF_DK,
    fap.PERF_DATE_SK,
    fap.CAMPAIGN_SK,
    fap.MKTG_CAMPAIGN_SK,
    fap.AD_CREATIVE_SK,
    fap.DEVICE_SK,
    fap.AD_COST,
    fap.IMPRESSIONS,
    fap.CLICKS,
    fap.INBOUND_CALL,
    fap.GA_CONV_MEMBERS,
    fap.GA_CONV_CNT,
    fap.DAY_OF_WEEK,
    fap.WEEK_OF_YEAR,
    fap.AD_SOURCE_TYPE,
    -- ── 디지털 위성(FAD) — 방송행은 NULL(원천 부재) ──
    dig.PAGE_TYPE,
    dig.AD_GROUP_NM,
    dig.GROUP_DIV,
    dig.CREATIVE_TYPE,
    dig.AD_TYPE_NM,
    dig.READ_CNT,
    dig.MEDIA_POTENTIAL_CUST_CNT,
    dig.CRM_DEV_CNT,
    dig.CTR_SRC,
    dig.CVR_SRC,
    dig.CPC_SRC,
    dig.CPM_SRC,
    dig.CPA_SRC,
    dig.DEV_UNIT_PRICE_SRC,
    dig.VTR_SRC,
    -- ── 방송 위성(FAB) — 디지털행은 NULL(원천 부재) · 시간축 4컬럼은 VIDEO 전용 ──
    brc.TIME_BAND,
    brc.CM_POSITION,
    brc.RT_TYPE,
    brc.AD_START_TIME,
    brc.AD_END_TIME,
    brc.BROADCAST_DATE,
    brc.PROGRAM_NM,
    brc.CHANNEL_COMPANY,
    brc.CHANNEL_COMPANY_TYPE,
    brc.SPOT_TYPE,
    brc.DURATION_SEC,
    brc.DAY_DIV,
    brc.PRG_START_TIME,
    brc.CTV_DIV,
    brc.BRDC_DIV,
    brc.AD_CNT,
    brc.CONV_CALL_CNT,
    brc.DVLP_MEMBER_CNT,
    brc.DVLP_CNT,
    brc.AD_VIEW_RT_SRC as BRDC_AD_VIEW_RT_SRC,
    brc.CPC_SRC as BRDC_CPC_SRC
from GN_DW.GOLD.FACT_AD_PERFORMANCE fap
-- 위성은 AD_PERF_DK 로 원천유형별 완전분할이라 LEFT JOIN 이 행수를 늘리지 않는다(fan-out 0).
--   1:N 위성인 FACT_AD_BROADCAST_CASE 는 **의도적으로 제외**한다 — 사례 수만큼 광고비가 복제된다.
left join GN_DW.GOLD.FACT_AD_DIGITAL   dig on fap.AD_PERF_DK = dig.AD_PERF_DK
left join GN_DW.GOLD.FACT_AD_BROADCAST brc on fap.AD_PERF_DK = brc.AD_PERF_DK
    );