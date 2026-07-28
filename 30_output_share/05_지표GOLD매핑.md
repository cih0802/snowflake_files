<!-- LLM-METADATA
doc_id: METRIC_TO_GOLD_MAPPING
doc_role: 지표번호 → GOLD(FACT/DIM/SV·물리컬럼·SV base) 추적 장표 (현업용)
project: GN_DW (굿네이버스)
grounded_on: 02_지표 분류.md · 02·03 지표사전 · 04_SV파생 매핑.md · 05_필드 인벤토리.md(보고서필드→GOLD 물리컬럼 정본) · gen_column_mapping.py · 04·05 보고서필드 인벤토리
generator: scripts/gen_metric_gold_mapping.py
generated: auto (do-not-edit)
END-METADATA -->

# 지표 → GOLD 매핑 장표 (현업용)

> ⚙️ **생성기**: `scripts/gen_metric_gold_mapping.py` — 본 파일은 자동 생성물입니다. 직접 수정 금지 — 생성기 scripts/gen_metric_gold_mapping.py 수정 후 재실행하세요.
> **읽는 법**: 현업/기획이 원하는 **지표(지표번호)** 를 기준으로, 그 지표가 GOLD의 어느 **배속(FACT/DIM/SV)** 에
> 어떤 **물리컬럼**(measure·dimension) 또는 **SV base**(derived=율/구성비/LTV 등)로 매핑됐고, 그 값이
> 어떤 **SILVER→BRONZE 원천**에서 오는지 한 줄로 추적합니다.
> 상태: **OK** 사용가능 · **PARTIAL** 일부 대기(GA/AGENCY/ERP·identity) · **WAIT** 원천 입고 대기(FTG-B 사업목표 등)

## 0. 요약

- 총 **215개** 지표 (공통 162 + 신규 53).
- 상태: ✅ OK **168** · ◐ PARTIAL **43** · ⛔ WAIT **4**
- **유형별 GOLD 매핑 규칙**: `measure`→FACT 물리컬럼 · `dimension`→DIM(또는 FMM degen/스냅샷) · `derived`→**SV metric**(분자/분모 base로 계산, 물리컬럼 아님. 단 GA4 비가산 #98·108은 FGA 물리적재).
- **약어**: FMM=FACT_MEMBER_MONTHLY · FME=FACT_MEMBER_EVENT · FSE=FACT_SERVICE_EVENT · FAD=FACT_AD_PERFORMANCE · FGA=FACT_GA_BEHAVIOR · FBD=FACT_BUDGET · FEP=FACT_EVENT_PARTICIPATION · FTG-D=FACT_TARGET_DEV · FTG-B=FACT_TARGET_BIZ · SV=Semantic View metric.

### 0-1. 보고서필드 매핑 신뢰도 (⚠ 커버리지 ≠ 정확도)

| 매핑근거 | 건수 | 신뢰도 | 해석 |
|---|---:|---|---|
| `필드인벤토리` | 341 | 높음(정확일치) | 05_필드 인벤토리.md 라벨과 정확히 일치 — 물리 GOLD 컬럼 확정 |
| `지표사전` | 37 | 높음(정확일치) | 지표사전 지표명과 정확히 일치 |
| `SV파생` | 53 | 중(규칙기반) | 율·증감·구성비·대비 등 규칙 판정 — **분자/분모 확정은 04_SV파생 매핑.md·현업 확인 필요** |
| `필드인벤토리~` | 58 | **검증필요**(부분일치) | 라벨 부분일치 — 동명이의 가능. 표본검증 권장 |
| `지표사전~` | 11 | **검증필요**(부분일치) | 지표명 부분일치 — 동명이의 가능. 표본검증 권장 |
| `(미매칭)` | 7 | — | GOLD 물리·SV 어느 쪽도 대응 없음(어드민 제외분 등) |

> **후속 작업 주의**: 위 표의 `~`(부분일치)·`SV파생` 행은 **문자열/규칙 기반 추정**이다. 현업 확정 전
> 계약·개발 산출물의 근거로 단독 인용하지 말고, `필드인벤토리`/`지표사전`(정확일치) 또는 정본 문서로 재확인할 것.
> 생성 시점 원천 문서가 바뀌면 이 장표는 **자동 갱신되지 않는다** → 생성기 재실행 필요.

## 1. 지표 → GOLD 전체 매핑

### 1-A. 공통 지표 (162)

| 지표# | 지표명 | 유형 | 소스 | 단위 | GOLD 배속 | GOLD 매핑 (물리컬럼 / SV base) | SILVER 원천 | BRONZE 원천 | 정본 계산식 | 상태 |
|---|---|---|---|---|---|---|---|---|---|---|
| `공1` | 월 목표대비 개발(%) | derived | 복합 | % | `SV` | `SV metric — 분자: DEV_CNT / 분모: GOAL_CNT` | `CRM_MEMBER_DEV.SPNSR_AMT` | `TM_MM_FDRM_MBER_DVLP_AMT.SPNSR_AMT` | 월 개발건 / 월 회원개발목표 | OK |
| `공2` | 누계 목표대비 개발(%) | derived | 복합 | % | `SV` | `SV metric — 분자: DEV_CNT(YTD) / 분모: GOAL_CNT(YTD)` | `CRM_MEMBER_DEV.SPNSR_AMT` | `TM_MM_FDRM_MBER_DVLP_AMT.SPNSR_AMT` | 누계 개발건 / 누계 회원개발목표 | OK |
| `공3` | 연 목표대비 개발(%) | derived | 복합 | % | `SV` | `SV metric — 분자: DEV_CNT(YR) / 분모: GOAL_CNT(YR)` | `CRM_MEMBER_DEV.SPNSR_AMT` | `TM_MM_FDRM_MBER_DVLP_AMT.SPNSR_AMT` | 연 개발건 / 연 회원개발목표 | OK |
| `공4` | CRM 개발(건) | measure | CRM | 건 | `FMM` | `FMM.DEV_CNT` | `CRM_MEMBER_DEV.SPNSR_AMT` | `TM_MM_FDRM_MBER_DVLP_AMT.SPNSR_AMT` | 회원번호 기준, 회원의 CRM 개발 건 ( = 전체 후원금액 / 10,000 ) | OK |
| `공5` | GA 개발(건) | measure | GA4 | 건 | `FMM` | `FMM.DEV_CNT` | `CRM_MEMBER_DEV.SPNSR_AMT` | `TM_MM_FDRM_MBER_DVLP_AMT.SPNSR_AMT` | GA 개발 건 ( = 전체 후원금액 / 10,000 ) | PARTIAL |
| `공6` | GA 광고비 | measure | GA4 | 원 | `FAD` | `FAD.AD_COST` | `AGENCY_AD_PERFORMANCE 광고비` | `DGT/REBRDC/VIDEO_AD_CMPGN_DTLS(광고비 컬럼 3종)` | GA 광고비 ( = 전체 후원금액 / 10,000 ) | PARTIAL |
| `공7` | CRM 개발단가 | derived | 복합 | 원 | `SV` | `SV metric — 분자: AD_COST / 분모: DEV_CNT` | `AGENCY_AD_PERFORMANCE 광고비` | `DGT/REBRDC/VIDEO_AD_CMPGN_DTLS(광고비 컬럼 3종)` | 광고비 / CRM 개발 건 | OK |
| `공8` | GA 개발단가 | derived | GA4 | 원 | `SV` | `SV metric — 분자: AD_COST(SRC=GA4) / 분모: DEV_CNT(SRC=GA4)` | `AGENCY_AD_PERFORMANCE 광고비` | `DGT/REBRDC/VIDEO_AD_CMPGN_DTLS(광고비 컬럼 3종)` | GA 광고비 / GA 개발 건 | PARTIAL |
| `공9` | GA CTR | derived | GA4 | % | `SV` | `SV metric — 분자: CLICKS / 분모: IMPRESSIONS` | `AGENCY_AD_PERFORMANCE` | `DGT_AD_CMPGN_DTLS(클릭)` | (광고 클릭수 / 광고 노출수) * 100 | PARTIAL |
| `공10` | GA CVR | derived | GA4 | % | `SV` | `SV metric — 분자: GA_CONV_MEMBERS / 분모: CLICKS` | `GA4_EVENT(전환 이벤트)` | `BRONZE_GA4.events_YYYYMMDD` | (광고 전환수 / 광고 클릭수) * 100 | PARTIAL |
| `공11` | 매체명(공동브랜드) | dimension | AGENCY | 코드 | `DIM_AD_CREATIVE` | `DIM_AD_CREATIVE` | `AGENCY_AD_CREATIVE` | `DGT/REBRDC/VIDEO_AD_CMPGN_DTLS` |  | PARTIAL |
| `공12` | 플랫폼 | dimension | AGENCY | 코드 | `DIM_AD_CREATIVE` | `DIM_AD_CREATIVE` | `AGENCY_AD_CREATIVE` | `DGT/REBRDC/VIDEO_AD_CMPGN_DTLS` | YOUTUBE, KBS, 당근 등 광고를 송출하는 플랫폼 | PARTIAL |
| `공13` | 플랫폼 유형 | dimension | AGENCY | 코드 | `DIM_AD_CREATIVE` | `DIM_AD_CREATIVE` | `AGENCY_AD_CREATIVE` | `DGT/REBRDC/VIDEO_AD_CMPGN_DTLS` |  | PARTIAL |
| `공14` | 기기 | dimension | AGENCY | 코드 | `DIM_AD_CREATIVE` | `DIM_AD_CREATIVE` | `AGENCY_AD_CREATIVE` | `DGT/REBRDC/VIDEO_AD_CMPGN_DTLS` |  | PARTIAL |
| `공15` | 국내/해외 구분 | dimension | AGENCY | 코드 | `DIM_CAMPAIGN` | `DIM_CAMPAIGN` | `CRM_CAMPAIGN` | `TM_CM_CMPGN_MNG (+BRND_MNG+MKTNG_CMPGN_MNG)` | 1) 국내 2) 해외 3) 전체 4) 통합 | PARTIAL |
| `공16` | 사업/사례 구분 | dimension | AGENCY | 코드 | `DIM_CAMPAIGN` | `DIM_CAMPAIGN` | `CRM_CAMPAIGN` | `TM_CM_CMPGN_MNG (+BRND_MNG+MKTNG_CMPGN_MNG)` | 1) 사례 2) 사업 3) 굿즈 4) 통합 | PARTIAL |
| `공17` | 캠페인 유형 | dimension | AGENCY | 코드 | `DIM_CAMPAIGN` | `DIM_CAMPAIGN` | `CRM_CAMPAIGN` | `TM_CM_CMPGN_MNG (+BRND_MNG+MKTNG_CMPGN_MNG)` | 1) 국내 사례 2) 국내 사업 3) 해외 사례 4) 해외 굿즈 5) 전체 굿즈 6) 통합 | PARTIAL |
| `공18` | 캠페인명 | dimension | CRM | 코드 | `DIM_CAMPAIGN` | `DIM_CAMPAIGN` | `CRM_CAMPAIGN` | `TM_CM_CMPGN_MNG (+BRND_MNG+MKTNG_CMPGN_MNG)` |  | OK |
| `공19` | 캠페인 오픈일자 | dimension | CRM | 기간 | `DIM_CAMPAIGN` | `DIM_CAMPAIGN` | `CRM_CAMPAIGN` | `TM_CM_CMPGN_MNG (+BRND_MNG+MKTNG_CMPGN_MNG)` |  | OK |
| `공20` | 소재 | dimension | AGENCY | 코드 | `DIM_AD_CREATIVE` | `DIM_AD_CREATIVE` | `AGENCY_AD_CREATIVE` | `DGT/REBRDC/VIDEO_AD_CMPGN_DTLS` |  | PARTIAL |
| `공21` | CM위치 | dimension | AGENCY | 코드 | `DIM_AD_CREATIVE` | `DIM_AD_CREATIVE` | `AGENCY_AD_CREATIVE` | `DGT/REBRDC/VIDEO_AD_CMPGN_DTLS` |  | PARTIAL |
| `공22` | 초수 | dimension | AGENCY | 코드 | `DIM_AD_CREATIVE` | `DIM_AD_CREATIVE` | `AGENCY_AD_CREATIVE` | `DGT/REBRDC/VIDEO_AD_CMPGN_DTLS` |  | PARTIAL |
| `공23` | 노출수 | measure | AGENCY | 횟수 | `FAD` | `FAD.IMPRESSIONS` | `AGENCY_AD_PERFORMANCE` | `DGT_AD_CMPGN_DTLS(노출)` |  | PARTIAL |
| `공24` | 클릭수 | measure | AGENCY | 횟수 | `FAD` | `FAD.CLICKS` | `AGENCY_AD_PERFORMANCE` | `DGT_AD_CMPGN_DTLS(클릭)` |  | PARTIAL |
| `공25` | 인입콜 | measure | AGENCY | 횟수 | `FAD` | `FAD.INBOUND_CALL` | `AGENCY_AD_PERFORMANCE` | `REBRDC/VIDEO_AD_CMPGN_DTLS` |  | PARTIAL |
| `공26` | 가입캠페인 중단일 | dimension | CRM | 기간 | `FMM(degen)` | `FMM(degen)` | `` | `` |  | OK |
| `공27` | 캠페인 가입일 | dimension | CRM | 기간 | `FMM(degen)` | `FMM(degen)` | `` | `` |  | OK |
| `공28` | 최초가입일(회원번호 생성일) | dimension | CRM | 기간 | `DIM_MEMBER` | `DIM_MEMBER` | `CRM_MEMBER (+ STATUS_HIST)` | `TM_MM_FDRM_MBER_INFO / TM_MM_ONCE_MBER_INFO / TH_MM_FDRM_MBER_STNG_DTLS` |  | OK |
| `공29` | 최초캠페인 | dimension | CRM | 코드 | `DIM_MEMBER` | `DIM_MEMBER` | `CRM_MEMBER (+ STATUS_HIST)` | `TM_MM_FDRM_MBER_INFO / TM_MM_ONCE_MBER_INFO / TH_MM_FDRM_MBER_STNG_DTLS` | 회원이 최초가입 시 가입캠페인 | OK |
| `공30` | 최종중단일 | dimension | CRM | 기간 | `DIM_MEMBER` | `DIM_MEMBER` | `CRM_MEMBER (+ STATUS_HIST)` | `TM_MM_FDRM_MBER_INFO / TM_MM_ONCE_MBER_INFO / TH_MM_FDRM_MBER_STNG_DTLS` | 회원의 최종중단일자 | OK |
| `공31` | 최종캠페인 | dimension | CRM | 코드 | `DIM_MEMBER` | `DIM_MEMBER` | `CRM_MEMBER (+ STATUS_HIST)` | `TM_MM_FDRM_MBER_INFO / TM_MM_ONCE_MBER_INFO / TH_MM_FDRM_MBER_STNG_DTLS` | 회원이 최종중단 시 최종캠페인 | OK |
| `공32` | 신규 | dimension | CRM | 코드 | `FMM(degen)` | `FMM(degen)` | `` | `` |  | OK |
| `공33` | 증액 | dimension | CRM | 코드 | `FMM(degen)` | `FMM(degen)` | `` | `` |  | OK |
| `공34` | 재후원 | dimension | CRM | 코드 | `FMM(degen)` | `FMM(degen)` | `` | `` |  | OK |
| `공35` | 중단(건) | measure | CRM | 건 | `FME→FMM` | `FME→FMM.STOP_CNT` | `CRM_MEMBER_DISCONTINUE` | `TM_MM_FDRM_MBER_SPNSR_DSCNTC.SPNSR_DSCNTC_DE` | 회원번호 기준, 후원중단한 회원의 총 개발 건 ( = 전체 후원금액 / 10,000 ) | OK |
| `공36` | 미납(건) | measure | CRM | 건 | `FME→FMM` | `FME→FMM.UNPAID_CNT` | `CRM_PAYMENT_BILLING(PAY_STAT_CD=F∪NULL)` | `TM_PM_MBRFEE_ACMSLT.PAY_STAT_CD` | 회원번호 기준, 회원상태가 미납인 회원의 총 개발 건 ( = 전체 후원금액 / 10,000 ) | OK |
| `공37` | 활동(건) | measure | CRM | 건 | `FMM` | `FMM.ACTIVE_CNT` | `` | `` | 회원번호 기준, 회원상태가 활동인 회원의 총 개발 건 ( = 전체 후원금액 / 10,000 ) | OK |
| `공38` | 감액(건) | measure | CRM | 건 | `FMM` | `FMM.DECREASE_CNT` | `CRM_MEMBER_AMT_CHANGE(RDCAMT_YN='Y')` | `TM_MM_FDRM_MBER_IRSD.SPNSR_AMT·RDCAMT_YN` | 회원번호 기준, 후원사업(세부캠페인)별 총 감액 건 ( = 전체 감액금액 / 10,000 ) | OK |
| `공39` | 개발회원 | dimension | CRM | 코드 | `DIM_MEMBER` | `DIM_MEMBER` | `CRM_MEMBER (+ STATUS_HIST)` | `TM_MM_FDRM_MBER_INFO / TM_MM_ONCE_MBER_INFO / TH_MM_FDRM_MBER_STNG_DTLS` |  | OK |
| `공40` | 활동회원 | dimension | CRM | 코드 | `DIM_MEMBER` | `DIM_MEMBER` | `CRM_MEMBER (+ STATUS_HIST)` | `TM_MM_FDRM_MBER_INFO / TM_MM_ONCE_MBER_INFO / TH_MM_FDRM_MBER_STNG_DTLS` |  | OK |
| `공41` | 중단회원 | dimension | CRM | 코드 | `DIM_MEMBER` | `DIM_MEMBER` | `CRM_MEMBER (+ STATUS_HIST)` | `TM_MM_FDRM_MBER_INFO / TM_MM_ONCE_MBER_INFO / TH_MM_FDRM_MBER_STNG_DTLS` |  | OK |
| `공42` | 미납회원 | dimension | CRM | 코드 | `DIM_MEMBER` | `DIM_MEMBER` | `CRM_MEMBER (+ STATUS_HIST)` | `TM_MM_FDRM_MBER_INFO / TM_MM_ONCE_MBER_INFO / TH_MM_FDRM_MBER_STNG_DTLS` |  | OK |
| `공43` | 신규회원 | dimension | CRM | 코드 | `DIM_MEMBER` | `DIM_MEMBER` | `CRM_MEMBER (+ STATUS_HIST)` | `TM_MM_FDRM_MBER_INFO / TM_MM_ONCE_MBER_INFO / TH_MM_FDRM_MBER_STNG_DTLS` |  | OK |
| `공44` | 기존회원 | dimension | CRM | 코드 | `DIM_MEMBER` | `DIM_MEMBER` | `CRM_MEMBER (+ STATUS_HIST)` | `TM_MM_FDRM_MBER_INFO / TM_MM_ONCE_MBER_INFO / TH_MM_FDRM_MBER_STNG_DTLS` |  | OK |
| `공45` | 활동율(%) | derived | CRM | % | `SV` | `SV metric — 분자: MONTH_END_ACTIVE_CNT / 분모: YEAR_START_ACTIVE_CNT + DEV_CNT(YTD)` | `` | `` | 월말활동회원건 / 총 개발회원건 (연도초활동회원건 + 누계개발건) | OK |
| `공46` | 신규 활동율(%) | derived | CRM | % | `SV` | `SV metric — 분자: DEV_CNT(YTD) / 분모: ACTIVE_CNT` | `CRM_MEMBER_DEV.SPNSR_AMT` | `TM_MM_FDRM_MBER_DVLP_AMT.SPNSR_AMT` | 누계개발 건 / 활동건 | OK |
| `공47` | 기존 활동율(%) | derived | CRM | % | `SV` | `SV metric — 분자: ACTIVE_CNT / 분모: DEV_CNT(YTD) + YEAR_START_ACTIVE_CNT` | `` | `` | 활동 건 / (누계개발 건 + 연도초활동 건) | OK |
| `공48` | 연도초 활동회원 | dimension | CRM | 코드 | `DIM_MEMBER` | `DIM_MEMBER` | `CRM_MEMBER (+ STATUS_HIST)` | `TM_MM_FDRM_MBER_INFO / TM_MM_ONCE_MBER_INFO / TH_MM_FDRM_MBER_STNG_DTLS` |  | OK |
| `공49` | 연도초 활동회원(건) | measure | CRM | 건 | `FMM` | `FMM.YEAR_START_ACTIVE_CNT` | `` | `` | 전년도 연도말 활동회원 건수 | OK |
| `공50` | 연도말 활동회원(건) | measure | CRM | 건 | `FMM` | `FMM (measure — 컬럼 06_DDL.sql 확인)` | `` | `` |  | OK |
| `공51` | 월말활동회원 | dimension | CRM | 코드 | `DIM_MEMBER` | `DIM_MEMBER` | `CRM_MEMBER (+ STATUS_HIST)` | `TM_MM_FDRM_MBER_INFO / TM_MM_ONCE_MBER_INFO / TH_MM_FDRM_MBER_STNG_DTLS` | 활동, 미납1~미납5까지의 회원 포함 | OK |
| `공52` | 월말활동회원(건) | measure | CRM | 건 | `FMM` | `FMM.MONTH_END_ACTIVE_CNT` | `` | `` | 월 활동회원(회원상태가 활동, 미납1~미납5)의 전체후원사업금액 / 10,000 | OK |
| `공53` | 전월말 활동회원(건) | measure | CRM | 건 | `FMM` | `FMM.PREV_MONTH_END_ACTIVE_CNT` | `` | `` |  | OK |
| `공54` | 중단율1(%) | derived | CRM | % | `SV` | `SV metric — 분자: STOP_CNT / 분모: DEV_CNT + YEAR_START_ACTIVE_CNT` | `CRM_MEMBER_DISCONTINUE` | `TM_MM_FDRM_MBER_SPNSR_DSCNTC.SPNSR_DSCNTC_DE` | 중단(건) / (개발(건) + 연도초활동회원(건)) | OK |
| `공55` | 중단율2(%) | derived | CRM | % | `SV` | `SV metric — 분자: STOP_CNT / 분모: DEV_CNT` | `CRM_MEMBER_DISCONTINUE` | `TM_MM_FDRM_MBER_SPNSR_DSCNTC.SPNSR_DSCNTC_DE` | 중단(건) / 개발(건) | OK |
| `공56` | 신규 중단율 | derived | CRM | % | `SV` | `SV metric — 분자: STOP_CNT[신규] / 분모: DEV_CNT[신규] + PREV_MONTH_END_ACTIVE_CNT[신규]` | `CRM_MEMBER_DISCONTINUE` | `TM_MM_FDRM_MBER_SPNSR_DSCNTC.SPNSR_DSCNTC_DE` | 신규중단(건) / (당월 신규개발(건) + 전월말 신규활동회원건) | OK |
| `공57` | 기존 중단율 | derived | CRM | % | `SV` | `SV metric — 분자: STOP_CNT[기존] / 분모: DEV_CNT[기존] + PREV_MONTH_END_ACTIVE_CNT[기존]` | `CRM_MEMBER_DISCONTINUE` | `TM_MM_FDRM_MBER_SPNSR_DSCNTC.SPNSR_DSCNTC_DE` | 기존중단(건) / (당월 기존개발(건) + 전월말 기존활동회원건) | OK |
| `공58` | 주간 평균 1일 중단(건) | derived | CRM | 건 | `SV` | `SV metric — 분자: STOP_CNT(주합) / 분모: 주간 일수(DIM_DATE)` | `CRM_MEMBER_DISCONTINUE` | `TM_MM_FDRM_MBER_SPNSR_DSCNTC.SPNSR_DSCNTC_DE` | 해당주간 총 중단건수 / 해당 주간 일수 | OK |
| `공59` | 증감(건) | derived | 복합 | 건 | `SV` | `SV metric — 분자: 해당 measure / 분모: (시계열)` | `` | `` | (당해년도 전주/전월/전년 수치 − 전주/전월/전년 수치) | OK |
| `공60` | 증감율(%) | derived | 복합 | % | `SV` | `SV metric — 분자: 해당 measure / 분모: 전기값` | `` | `` | (당해년도 전주/전월/전년 수치 − 전주/전월/전년 수치) / (전주/전월/전년 수치) * 100 | OK |
| `공61` | 1명당 건수 | derived | CRM | 비율 | `SV` | `SV metric — 분자: ACTIVE_CNT / 분모: ACTIVE_MEMBERS` | `` | `` | 활동회원 건 / 활동회원 명 | OK |
| `공62` | 납입율(%) | derived | CRM | % | `SV` | `SV metric — 분자: PAID_FEE / 분모: ACTIVE_CNT ×10000` | `CRM_PAYMENT_BILLING.PAY_AMT` | `TM_PM_MBRFEE_ACMSLT.PAY_AMT + TM_PM_DNTN_DTLS.PAY_AMT` | 납입회비 원 / (활동회원 건 * 10,000) | OK |
| `공63` | 누계납입율(%) | derived | CRM | % | `SV` | `SV metric — 분자: PAID_FEE(YTD) / 분모: ACTIVE_CUM_CNT ×10000` | `CRM_PAYMENT_BILLING.PAY_AMT` | `TM_PM_MBRFEE_ACMSLT.PAY_AMT + TM_PM_DNTN_DTLS.PAY_AMT` | 누계납입회비 원 / (누계 활동회원 건 * 10,000) | OK |
| `공64` | 납부율(%) | derived | CRM | % | `SV` | `SV metric — 분자: PAID_FEE / 분모: BILLED_AMT` | `CRM_PAYMENT_BILLING.PAY_AMT` | `TM_PM_MBRFEE_ACMSLT.PAY_AMT + TM_PM_DNTN_DTLS.PAY_AMT` | (납입회비 원 / 청구회비 원) * 100 | OK |
| `공65` | 누계납부율(%) | derived | CRM | % | `SV` | `SV metric — 분자: PAID_FEE(YTD) / 분모: BILLED_AMT(YTD)` | `CRM_PAYMENT_BILLING.PAY_AMT` | `TM_PM_MBRFEE_ACMSLT.PAY_AMT + TM_PM_DNTN_DTLS.PAY_AMT` | (누계납부회비 원 / 누계 청구회비 원) * 100 | OK |
| `공66` | 정기회비 | measure | CRM | 원 | `FMM` | `FMM.REGULAR_FEE` | `CRM_PAYMENT_BILLING.PAY_AMT` | `TM_PM_MBRFEE_ACMSLT.PAY_AMT` |  | OK |
| `공67` | 정기회원 일시회비 | measure | CRM | 원 | `FMM` | `FMM (measure — 컬럼 06_DDL.sql 확인)` | `` | `` | 정기회원이 정기후원사업 외 비지정(기타, 국내사업, 해외사업)으로 납부하는 일시회비 | OK |
| `공68` | 일시회원 일시회비 | measure | CRM | 원 | `FMM` | `FMM (measure — 컬럼 06_DDL.sql 확인)` | `` | `` | 일시회원이 납부하는 회비 | OK |
| `공69` | 납입회비 | measure | CRM | 원 | `FMM` | `FMM.PAID_FEE` | `CRM_PAYMENT_BILLING.PAY_AMT` | `TM_PM_MBRFEE_ACMSLT.PAY_AMT + TM_PM_DNTN_DTLS.PAY_AMT` |  | OK |
| `공70` | 납입 | measure | CRM | 원 | `FMM` | `FMM.PAID_FEE` | `CRM_PAYMENT_BILLING.PAY_AMT` | `TM_PM_MBRFEE_ACMSLT.PAY_AMT + TM_PM_DNTN_DTLS.PAY_AMT` |  | OK |
| `공71` | 청구 | measure | CRM | 원 | `FMM` | `FMM.BILLED_AMT` | `CRM_PAYMENT_BILLING.RQEST_AMT` | `TM_PM_MBRFEE_ACMSLT.RQEST_AMT` |  | OK |
| `공72` | 후원금액대1 | dimension | CRM | 코드 | `FMM(스냅샷)` | `FMM(스냅샷)` | `` | `` | 조회년월 기준 후원 약정금액 ( = 개발된 후원사업별 금액 ) / 10,000원 | OK |
| `공73` | 후원금액대2 | dimension | CRM | 코드 | `FMM(스냅샷)` | `FMM(스냅샷)` | `` | `` | 조회년월 기준 후원 약정금액 ( = 개발된 후원사업별 금액 ) / 10,000원 | OK |
| `공74` | 후원기간대1 | dimension | CRM | 코드 | `FMM(스냅샷)` | `FMM(스냅샷)` | `` | `` | 캠페인 가입일자부터 조회년월까지의 기간을 개월 기준으로, 년 기준으로 구분 | OK |
| `공75` | 후원기간대2 | dimension | CRM | 코드 | `FMM(스냅샷)` | `FMM(스냅샷)` | `` | `` | 캠페인 가입일자부터 조회년월까지의 기간을 개월 기준으로, 년 기준으로 구분 | OK |
| `공76` | 미납율(%) | derived | CRM | % | `SV` | `SV metric — 분자: UNPAID_CNT / 분모: ACTIVE_CNT` | `CRM_PAYMENT_BILLING(PAY_STAT_CD=F∪NULL)` | `TM_PM_MBRFEE_ACMSLT.PAY_STAT_CD` | 미납(건) / 활동(건) | OK |
| `공77` | 신규 미납율(%) | derived | CRM | % | `SV` | `SV metric — 분자: UNPAID_CNT[신규] / 분모: ACTIVE_CNT[신규]` | `CRM_PAYMENT_BILLING(PAY_STAT_CD=F∪NULL)` | `TM_PM_MBRFEE_ACMSLT.PAY_STAT_CD` | 신규미납(건) / 신규활동(건) | OK |
| `공78` | 기존 미납율(%) | derived | CRM | % | `SV` | `SV metric — 분자: UNPAID_CNT[기존] / 분모: ACTIVE_CNT[기존]` | `CRM_PAYMENT_BILLING(PAY_STAT_CD=F∪NULL)` | `TM_PM_MBRFEE_ACMSLT.PAY_STAT_CD` | 기존미납(건) / 기존활동(건) | OK |
| `공79` | 후원사업별 미납율(%) | derived | CRM | % | `SV` | `SV metric — 분자: UNPAID_CNT / 분모: ACTIVE_CNT` | `CRM_PAYMENT_BILLING(PAY_STAT_CD=F∪NULL)` | `TM_PM_MBRFEE_ACMSLT.PAY_STAT_CD` | 후원사업 미납(건) / 후원사업 활동(건) | OK |
| `공80` | 미납회원 감소율(%) | derived | CRM | % | `SV` | `SV metric — 분자: UNPAID_MEMBERS(월초·월말) / 분모: UNPAID_MEMBERS(월초)` | `` | `` | (월초미납명수 − 월말미납명수) / 월초미납명수 | OK |
| `공81` | 미납서비스 전환율(%) | derived | 복합 | % | `SV` | `SV metric — 분자: 납입전환 회원(명) / 분모: GA 미납서비스 클릭회원(명)` | `` | `` | 납입회원(명) / 미납서비스 클릭회원(명) * 100 | PARTIAL |
| `공82` | 미납사유 | dimension | CRM | 코드 | `DIM_REASON` | `DIM_REASON` | `CRM_MEMBER_DISCONTINUE (또는 CRM_CODE MM005)` | `TM_MM_FDRM_MBER_SPNSR_DSCNTC` | CRM > 회원요약정보 > 회비내역 > 미납/환급정보 > 미납내역 | OK |
| `공83` | 캠페인별 미납(건) | measure | CRM | 건 | `FMM` | `FMM.CAMPAIGN_UNPAID_CNT` | `` | `` | 캠페인별 미납회비금액 / 10,000원 | OK |
| `공84` | 회원상태별 미납(건) | measure | CRM | 건 | `FMM` | `FMM (measure — 컬럼 06_DDL.sql 확인)` | `` | `` | 회원상태별 미납회비금액 / 10,000원 | OK |
| `공85` | 발송수(명) | measure | CRM | 명 | `FSE` | `FSE.SEND_MEMBERS` | `CRM_SEND_MEMBER(MBER_NO distinct)` | `TD_MS_*_SNDNG_DTLS` | 회원번호 개수 기준 (중복 포함) | OK |
| `공86` | 성공수(명) | measure | CRM | 명 | `FSE` | `FSE.SUCCESS_MEMBERS` | `CRM_SEND_RESULT(성공)` | `TD_MS_EMAIL_LQY_SNDNG / TD_MS_MSG_AT_LQY_SNDNG / TD_MS_PSTMTR_LQY_SNDNG` | 회원번호 개수 기준 (중복 포함) | OK |
| `공87` | 실패수(명) | measure | CRM | 명 | `FSE` | `FSE.FAIL_MEMBERS` | `CRM_SEND_RESULT(실패)` | `TD_MS_*_LQY_SNDNG` | 회원번호 개수 기준 (중복 포함) | OK |
| `공88` | 서신참여(명) | measure | CRM | 명 | `FSE` | `FSE.LETTER_PART_MEMBERS` | `CRM_RELATION_ACTIVITY(LETTER)` | `TM_RM_RELATNSP_LETTER_INFO` | 회원번호 개수 기준 (중복 포함) | OK |
| `공89` | 서신참여(건) | measure | CRM | 건 | `FSE` | `FSE (measure — 컬럼 06_DDL.sql 확인)` | `` | `` |  | OK |
| `공90` | 선물금참여(명) | measure | CRM | 명 | `FSE` | `FSE.GIFT_PART_MEMBERS` | `` | `` | 회원번호 개수 기준 (중복 포함) | OK |
| `공91` | 선물금참여(원) | measure | CRM | 원 | `FSE` | `FSE.GIFT_PART_AMT` | `CRM_RELATION_ACTIVITY.GFTMNEY` | `TM_RM_RELATNSP_GFTMNEY_INFO.GFTMNEY` |  | OK |
| `공92` | 방문수(명) | measure | GA4 | 명 | `FGA` | `FGA (measure — 컬럼 06_DDL.sql 확인)` | `` | `` |  | PARTIAL |
| `공93` | 활성사용자수(명) | measure | GA4 | 명 | `FGA` | `FGA (measure — 컬럼 06_DDL.sql 확인)` | `` | `` |  | PARTIAL |
| `공94` | 총사용자(명) | measure | GA4 | 명 | `FGA` | `FGA (measure — 컬럼 06_DDL.sql 확인)` | `` | `` |  | PARTIAL |
| `공95` | 이벤트수(명) | measure | GA4 | 명 | `FGA` | `FGA (measure — 컬럼 06_DDL.sql 확인)` | `` | `` |  | PARTIAL |
| `공96` | 조회수(명) | measure | GA4 | 명 | `FGA` | `FGA (measure — 컬럼 06_DDL.sql 확인)` | `` | `` |  | PARTIAL |
| `공97` | 세션수(명) | measure | GA4 | 명 | `FGA` | `FGA.SESSION_CNT` | `GA4_EVENT.ga_session_id` | `BRONZE_GA4.events(event_params: ga_session_id)` |  | PARTIAL |
| `공98` | 평균세션시간 | derived | GA4 | 기간 | `FGA` | `FGA 물리적재(비가산) — SV metric — 분자: (적재컬럼 AVG_SESSION_DURATION) / 분모: —` | `GA4_EVENT + IDENTITY_MEMBER_XREF` | `BRONZE_GA4.events_YYYYMMDD` |  | PARTIAL |
| `공99` | event_category | dimension | GA4 | 코드 | `DIM_GA_EVENT` | `DIM_GA_EVENT` | `GA4_EVENT_DIM` | `BRONZE_GA4.events(event_params)` | member_id가 (not set)이 아닌 데이터 | PARTIAL |
| `공100` | event_label | dimension | GA4 | 코드 | `DIM_GA_EVENT` | `DIM_GA_EVENT` | `GA4_EVENT_DIM` | `BRONZE_GA4.events(event_params)` | 후원b1, 후원b2, 1단_대문, 퀵버튼 등 | PARTIAL |
| `공101` | event_action | dimension | GA4 | 코드 | `DIM_GA_EVENT` | `DIM_GA_EVENT` | `GA4_EVENT_DIM` | `BRONZE_GA4.events(event_params)` | member_id가 (not set)이 아닌 데이터 | PARTIAL |
| `공102` | 세션캠페인 | dimension | GA4 | 코드 | `DIM_CAMPAIGN` | `DIM_CAMPAIGN` | `CRM_CAMPAIGN` | `TM_CM_CMPGN_MNG (+BRND_MNG+MKTNG_CMPGN_MNG)` | 2024 기념일 캠페인 / 2024 ACL 등 | PARTIAL |
| `공103` | 세션 수동 광고 콘텐츠 | dimension | GA4 | 코드 | `DIM_GA_SOURCE` | `DIM_GA_SOURCE` | `GA4_TRAFFIC_SOURCE` | `BRONZE_GA4.events(traffic_source)` | 기부금영수증 인쇄 / 로그인하기 / 전체메뉴보기 등 | PARTIAL |
| `공104` | 세션 수동 검색어 | dimension | GA4 | 코드 | `DIM_GA_SOURCE` | `DIM_GA_SOURCE` | `GA4_TRAFFIC_SOURCE` | `BRONZE_GA4.events(traffic_source)` |  | PARTIAL |
| `공105` | 페이지경로+쿼리문자열 | dimension | GA4 | 코드 | `FGA(attr)` | `FGA(attr)` | `` | `` |  | PARTIAL |
| `공106` | 페이지위치 | dimension | GA4 | 코드 | `FGA(attr)` | `FGA(attr)` | `` | `` | 예) https://m.goodneighbors.kr/campaign/turn25b | PARTIAL |
| `공107` | 스크롤깊이 | measure | GA4 | 횟수 | `FGA` | `FGA.SCROLL_DEPTH` | `GA4_EVENT.percent_scrolled` | `BRONZE_GA4.events(event_params: percent_scrolled)` |  | PARTIAL |
| `공108` | 이탈율 | derived | GA4 | % | `FGA` | `FGA 물리적재(비가산) — SV metric — 분자: (적재컬럼 BOUNCE_RATE) / 분모: —` | `GA4_EVENT + IDENTITY_MEMBER_XREF` | `BRONZE_GA4.events_YYYYMMDD` |  | PARTIAL |
| `공109` | 세션 소스/매체 | dimension | GA4 | 코드 | `DIM_GA_SOURCE` | `DIM_GA_SOURCE` | `GA4_TRAFFIC_SOURCE` | `BRONZE_GA4.events(traffic_source)` |  | PARTIAL |
| `공110` | 회원번호 | dimension | CRM | 코드 | `DIM_MEMBER_IDENTITY` | `DIM_MEMBER_IDENTITY` | `CRM_MEMBER + GA4_IDENTITY` | `TM_MM_FDRM_MBER_INFO + BRONZE_GA4.events` |  | OK |
| `공111` | memnum | dimension | 복합 | 코드 | `DIM_MEMBER_IDENTITY` | `DIM_MEMBER_IDENTITY` | `CRM_MEMBER + GA4_IDENTITY` | `TM_MM_FDRM_MBER_INFO + BRONZE_GA4.events` |  | OK |
| `공112` | member id | dimension | GA4 | 코드 | `DIM_MEMBER_IDENTITY` | `DIM_MEMBER_IDENTITY` | `CRM_MEMBER + GA4_IDENTITY` | `TM_MM_FDRM_MBER_INFO + BRONZE_GA4.events` |  | PARTIAL |
| `공113` | 신규기존구분 | dimension | CRM | 코드 | `DIM_MEMBER` | `DIM_MEMBER` | `CRM_MEMBER (+ STATUS_HIST)` | `TM_MM_FDRM_MBER_INFO / TM_MM_ONCE_MBER_INFO / TH_MM_FDRM_MBER_STNG_DTLS` | 신규: 당해년도 개발, 기존: 당해년도 이전 개발 | OK |
| `공114` | 법인 | dimension | CRM | 코드 | `DIM_ORG` | `DIM_ORG` | `CRM_ORG` | `TM_CM_DEPT_INFO` |  | OK |
| `공115` | 본부/지부 | dimension | CRM | 코드 | `DIM_ORG` | `DIM_ORG` | `CRM_ORG` | `TM_CM_DEPT_INFO` |  | OK |
| `공116` | 부서 | dimension | CRM | 코드 | `DIM_ORG` | `DIM_ORG` | `CRM_ORG` | `TM_CM_DEPT_INFO` |  | OK |
| `공117` | 공통브랜드 | dimension | CRM | 코드 | `DIM_CAMPAIGN` | `DIM_CAMPAIGN` | `CRM_CAMPAIGN` | `TM_CM_CMPGN_MNG (+BRND_MNG+MKTNG_CMPGN_MNG)` |  | OK |
| `공118` | 홍보방법 | dimension | CRM | 코드 | `DIM_CAMPAIGN` | `DIM_CAMPAIGN` | `CRM_CAMPAIGN` | `TM_CM_CMPGN_MNG (+BRND_MNG+MKTNG_CMPGN_MNG)` |  | OK |
| `공119` | 공통상위캠페인 | dimension | CRM | 코드 | `DIM_CAMPAIGN` | `DIM_CAMPAIGN` | `CRM_CAMPAIGN` | `TM_CM_CMPGN_MNG (+BRND_MNG+MKTNG_CMPGN_MNG)` |  | OK |
| `공120` | 캠페인 | dimension | CRM | 코드 | `DIM_CAMPAIGN` | `DIM_CAMPAIGN` | `CRM_CAMPAIGN` | `TM_CM_CMPGN_MNG (+BRND_MNG+MKTNG_CMPGN_MNG)` |  | OK |
| `공121` | 개발구분 | dimension | CRM | 코드 | `FMM(degen)` | `FMM(degen)` | `` | `` |  | OK |
| `공122` | 결연아동코드 | dimension | GA4 | 코드 | `DIM_MEMBER_IDENTITY` | `DIM_MEMBER_IDENTITY` | `CRM_MEMBER + GA4_IDENTITY` | `TM_MM_FDRM_MBER_INFO + BRONZE_GA4.events` | "페이지 경로+쿼리 문자열"에서 파생. URL에서 childnum= 뒤에 오는 13자리. 예) https://gni.kr/url/25acl_25ABC.gn?memnum=1831636&childnum=CMR-0102-002758 → 결연아동코드 = CMR-0102-002758 | PARTIAL |
| `공123` | 후원사업(전체) | dimension | CRM | 코드 | `DIM_SPONSORSHIP` | `DIM_SPONSORSHIP` | `CRM_SPONSORSHIP` | `TM_CM_SPNSR_BSNS_INFO` |  | OK |
| `공124` | 후원사업(약칭) | dimension | CRM | 코드 | `DIM_SPONSORSHIP` | `DIM_SPONSORSHIP` | `CRM_SPONSORSHIP` | `TM_CM_SPNSR_BSNS_INFO` | 국내사단(국내아동권리보호사업(사단법인), 결식아동지원, 아동학대예방, 저소득가정지원), 국내사복(국내아동권리보호사업(사회복지법인), 국내사업, 좋은이웃(사복)), 결연(해외아동결연), 해외구호(희망학교지원사업, 해외교육지원사업, 보건의료지원사업, 식수위생지원사업, 재난구호지원사업, 해외지역개발지원사업), 기타(대북지원사업, 좋은이웃, 전체사업지원) | OK |
| `공125` | 납입방식 | dimension | CRM | 코드 | `DIM_PAYMENT` | `DIM_PAYMENT` | `CRM_PAYMENT_METHOD` | `TM_PM_SETLE_INFO` |  | OK |
| `공126` | 캠페인별 납입방식 | dimension | CRM | 코드 | `DIM_PAYMENT` | `DIM_PAYMENT` | `CRM_PAYMENT_METHOD` | `TM_PM_SETLE_INFO` |  | OK |
| `공127` | 후원기간(개월) | dimension | CRM | 기간 | `FMM(스냅샷)` | `FMM(스냅샷)` | `` | `` |  | OK |
| `공128` | 후원기간(년) | dimension | CRM | 기간 | `FMM(스냅샷)` | `FMM(스냅샷)` | `` | `` |  | OK |
| `공129` | 납입개월수 | dimension | CRM | 기간 | `FMM(스냅샷)` | `FMM(스냅샷)` | `` | `` |  | OK |
| `공130` | 성별 | dimension | CRM | 코드 | `DIM_MEMBER` | `DIM_MEMBER` | `CRM_MEMBER (+ STATUS_HIST)` | `TM_MM_FDRM_MBER_INFO / TM_MM_ONCE_MBER_INFO / TH_MM_FDRM_MBER_STNG_DTLS` |  | OK |
| `공131` | 지역 | dimension | CRM | 코드 | `DIM_MEMBER` | `DIM_MEMBER` | `CRM_MEMBER (+ STATUS_HIST)` | `TM_MM_FDRM_MBER_INFO / TM_MM_ONCE_MBER_INFO / TH_MM_FDRM_MBER_STNG_DTLS` |  | OK |
| `공132` | 회원상태 | dimension | CRM | 코드 | `DIM_MEMBER` | `DIM_MEMBER` | `CRM_MEMBER (+ STATUS_HIST)` | `TM_MM_FDRM_MBER_INFO / TM_MM_ONCE_MBER_INFO / TH_MM_FDRM_MBER_STNG_DTLS` |  | OK |
| `공133` | 발송구분(대) | dimension | CRM | 코드 | `DIM_SERVICE` | `DIM_SERVICE` | `CRM_SEND_REQUEST` | `SND_REQ_MST (SEND_GBN_TOP/MID/BOT)` |  | OK |
| `공134` | 발송구분(중) | dimension | CRM | 코드 | `DIM_SERVICE` | `DIM_SERVICE` | `CRM_SEND_REQUEST` | `SND_REQ_MST (SEND_GBN_TOP/MID/BOT)` |  | OK |
| `공135` | 발송구분(소) | dimension | CRM | 코드 | `DIM_SERVICE` | `DIM_SERVICE` | `CRM_SEND_REQUEST` | `SND_REQ_MST (SEND_GBN_TOP/MID/BOT)` |  | OK |
| `공136` | 제목(발송) | dimension | CRM | 코드 | `FSE(degen)` | `FSE(degen)` | `` | `` |  | OK |
| `공137` | 발송일 | dimension | CRM | 기간 | `DIM_DATE` | `DIM_DATE` | `(ETL 생성)` | `(원천 무관)` |  | OK |
| `공138` | 발송상태 | dimension | CRM | 코드 | `FSE(degen)` | `FSE(degen)` | `` | `` |  | OK |
| `공139` | 발송(+5일차) 서신참여(명) | measure | CRM | 명 | `FSE` | `FSE.D5_LETTER_PART_` | `` | `` |  | OK |
| `공140` | 발송(+5일차) 서신참여(건) | measure | CRM | 건 | `FSE` | `FSE.D5_LETTER_PART_` | `` | `` |  | OK |
| `공141` | 발송(+5일차) 선물금참여(명) | measure | CRM | 명 | `FSE` | `FSE.D5_LETTER_PART_` | `` | `` |  | OK |
| `공142` | 발송(+5일차) 선물금참여(건) | measure | CRM | 건 | `FSE` | `FSE.D5_LETTER_PART_` | `` | `` |  | OK |
| `공143` | 발송(+5일차) 증액참여(명) | measure | CRM | 명 | `FSE` | `FSE.D5_INCREASE_PART_` | `` | `` |  | OK |
| `공144` | 발송(+5일차) 증액참여(건) | measure | CRM | 건 | `FSE` | `FSE.CNT` | `` | `` |  | OK |
| `공145` | 발송(+5일차) 중단(명) | measure | CRM | 명 | `FSE` | `FSE.D5_STOP_` | `` | `` |  | OK |
| `공146` | 발송(+5일차) 중단(건) | measure | CRM | 건 | `FSE` | `FSE.CNT` | `` | `` |  | OK |
| `공147` | 공통캠페인 | dimension | CRM | 코드 | `DIM_CAMPAIGN` | `DIM_CAMPAIGN` | `CRM_CAMPAIGN` | `TM_CM_CMPGN_MNG (+BRND_MNG+MKTNG_CMPGN_MNG)` |  | OK |
| `공148` | 개발(명) | measure | CRM | 명 | `FME→FMM` | `FME→FMM.DEV_MEMBERS` | `CRM_MEMBER_DEV(MBER_NO distinct)` | `TM_MM_FDRM_MBER_DVLP_AMT.MBER_NO` |  | OK |
| `공149` | 개발(건) | measure | CRM | 건 | `FME→FMM` | `FME→FMM.DEV_CNT` | `CRM_MEMBER_DEV.SPNSR_AMT` | `TM_MM_FDRM_MBER_DVLP_AMT.SPNSR_AMT` |  | OK |
| `공150` | 증액(명) | measure | CRM | 명 | `FME→FMM` | `FME→FMM.INCREASE_MEMBERS` | `CRM_MEMBER_AMT_CHANGE(RDCAMT_YN='N')` | `TM_MM_FDRM_MBER_IRSD.SPNSR_AMT·RDCAMT_YN` |  | OK |
| `공151` | 증액(건) | measure | CRM | 건 | `FME→FMM` | `FME→FMM.INCREASE_CNT` | `` | `` |  | OK |
| `공152` | 연사업목표(건) | measure | CRM | 건 | `FTG-B` | `FTG-B (measure — 컬럼 06_DDL.sql 확인)` | `` | `` |  | WAIT |
| `공153` | 추경목표(건) | measure | CRM | 건 | `FTG-B` | `FTG-B (measure — 컬럼 06_DDL.sql 확인)` | `` | `` |  | WAIT |
| `공154` | 연사업누계목표(건) | measure | CRM | 건 | `FTG-B` | `FTG-B (measure — 컬럼 06_DDL.sql 확인)` | `` | `` |  | WAIT |
| `공155` | 추경누계목표(건) | measure | CRM | 건 | `FTG-B` | `FTG-B (measure — 컬럼 06_DDL.sql 확인)` | `` | `` |  | WAIT |
| `공156` | 활동(명) | measure | CRM | 명 | `FMM` | `FMM.ACTIVE_MEMBERS` | `CRM_MEMBER_STATUS_HIST + CRM_MEMBER_SPONSOR_BIZ` | `TH_MM_FDRM_MBER_STNG_DTLS + TM_MM_FDRM_MBER_SPNSR_BSNS` |  | OK |
| `공157` | 활동(건) | measure | CRM | 건 | `FMM` | `FMM.ACTIVE_CNT` | `` | `` |  | OK |
| `공158` | 활동누계(명) | measure | CRM | 명 | `FMM` | `FMM (measure — 컬럼 06_DDL.sql 확인)` | `` | `` |  | OK |
| `공159` | 활동누계(건) | measure | CRM | 건 | `FMM` | `FMM.ACTIVE_CUM_CNT` | `` | `` |  | OK |
| `공160` | 서비스(명) | measure | CRM | 명 | `FSE` | `FSE (measure — 컬럼 06_DDL.sql 확인)` | `` | `` |  | OK |
| `공161` | 서비스(건) | measure | CRM | 건 | `FSE` | `FSE (measure — 컬럼 06_DDL.sql 확인)` | `` | `` |  | OK |
| `공162` | 중단사유 | dimension | CRM | 코드 | `DIM_REASON` | `DIM_REASON` | `CRM_MEMBER_DISCONTINUE (또는 CRM_CODE MM005)` | `TM_MM_FDRM_MBER_SPNSR_DSCNTC` |  | OK |

### 1-B. 신규 지표 (53)

| 지표# | 지표명 | 유형 | 소스 | 단위 | GOLD 배속 | GOLD 매핑 (물리컬럼 / SV base) | SILVER 원천 | BRONZE 원천 | 정본 계산식 | 상태 |
|---|---|---|---|---|---|---|---|---|---|---|
| `신1` | 개발캠페인별 납입회비(원) | measure | CRM | 원 | `FMM` | `FMM (measure — 컬럼 06_DDL.sql 확인)` | `` | `` | 캠페인 가입 이후 납입하는 회비 | OK |
| `신2` | 개발캠페인별 유지기간(개월) | derived | CRM | 기간 | `SV` | `SV metric — 분자: DATEDIFF(조회일, JOIN_DATE) / 분모: —` | `` | `` | 고유ID(회원번호×캠페인가입일×후원사업×캠페인명) 기준 매칭되는 캠페인가입일로부터 조회기준일까지의 총 개월수 | OK |
| `신3` | 개발캠페인별 유지기간(년) | derived | CRM | 기간 | `SV` | `SV metric — 분자: DATEDIFF(년) / 분모: —` | `` | `` | 고유ID(회원번호×캠페인가입일×후원사업×캠페인명) 기준 매칭되는 캠페인가입일로부터 조회기준일까지의 총 년수 | OK |
| `신4` | 평균 유지기간(개월) | derived | CRM | 기간 | `SV` | `SV metric — 분자: Σ(유지기간×DEV_MEMBERS) / 분모: DEV_MEMBERS(총)` | `CRM_MEMBER_DEV(MBER_NO distinct)` | `TM_MM_FDRM_MBER_DVLP_AMT.MBER_NO` | {(개발캠페인별 유지기간×해당 유지기간 총 회원수)의 합} / 캠페인 가입한 총 회원수 | OK |
| `신5` | 평균 유지기간(년) | derived | CRM | 기간 | `SV` | `SV metric — 분자: 〃 / 분모: 〃` | `` | `` | {(개발캠페인별 유지기간×해당 유지기간 총 회원수)의 합} / 캠페인 가입한 총 회원수 | OK |
| `신6` | 개발캠페인별 이탈율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 유지 cohort 회원수 / 분모: DEV_MEMBERS(누적가입)` | `` | `` | N개월 시점에 캠페인 가입유지중인 회원수 / N개월까지 가입한 회원수 | OK |
| `신7` | n개월 유지율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 유지 cohort 회원수 / 분모: DEV_MEMBERS` | `` | `` | (N개월 시점에 캠페인 가입유지중인 회원수 / N개월까지 가입한 회원수) × 100 | OK |
| `신8` | LTV(원) | derived | CRM | 원 | `SV` | `SV metric — 분자: AVG(PAID_FEE/member) / 분모: 평균기간(신4)` | `` | `` | 평균 납입회비 × 평균 활동 기간 | OK |
| `신9` | 캠페인별 개발단가(원) | derived | AGENCY | 원 | `SV` | `SV metric — 분자: PLAN_BUDGET_* 또는 AD_COST(AGENCY 편성비) / 분모: DEV_CNT[신규]` | `` | `` | 광고비(편성비) 비용 / 신규 획득 개발 건수 | PARTIAL |
| `신10` | 매체별 개발단가(원) | derived | ERP | 원 | `SV` | `SV metric — 분자: FUNDRAISING_COST / 분모: DEV_CNT[신규]` | `(원천 부재)` | `(ERP 원장에 없음)` | ERP 모금성 비용 / 신규 획득 개발 건수 | PARTIAL |
| `신11` | 캠페인별 ROI(%) | derived | 복합 | % | `SV` | `SV metric — 분자: PAID_FEE(또는 LTV) − 비용 / 분모: 비용(FBD)` | `CRM_PAYMENT_BILLING.PAY_AMT` | `TM_PM_MBRFEE_ACMSLT.PAY_AMT + TM_PM_DNTN_DTLS.PAY_AMT` | (총 수익−총 비용) / 총 비용 × 100 | OK |
| `신12` | 캠페인별 활동율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 활동건 / (개발누계건 + 연도초활동건) / 분모: 활동건 / (개발누계건 + 연도초활동건)` | `` | `` | 캠페인별 활동건 / (캠페인별 개발누계건 + 캠페인별 연도초활동건) | OK |
| `신13` | 연도별 캠페인 활동율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 〃 (조회시점) / 분모: 〃 (조회시점)` | `` | `` | 조회시점 기준 캠페인 활동건 / (캠페인 개발누계건 + 캠페인 연도초활동건) | OK |
| `신14` | 납입방식 활동율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 〃 (납입방식) / 분모: 〃 (납입방식)` | `` | `` | 캠페인별 납입방식 활동건 / (캠페인별 납입방식 개발누계건 + 캠페인별 납입방식 연도초활동건) | OK |
| `신15` | 캠페인별 중단율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 중단건 / (개발건 + 연도초활동건) / 분모: 중단건 / (개발건 + 연도초활동건)` | `` | `` | 캠페인별 중단(건) / (캠페인별 개발(건) + 캠페인별 연도초활동회원(건)) | OK |
| `신16` | 연도별 캠페인 중단율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 중단건 / (개발건 + 전월말활동건) / 분모: 중단건 / (개발건 + 전월말활동건)` | `` | `` | 조회시점 기준 캠페인 중단(건) / (캠페인 개발(건) + 캠페인 전월말활동회원(건)) | OK |
| `신17` | 캠페인별 누계중단율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 누계중단 / (누계개발 + 연도초활동건) / 분모: 누계중단 / (누계개발 + 연도초활동건)` | `` | `` | 캠페인별 누계중단(건) / (캠페인별 누계개발(건) + 캠페인별 연도초활동회원(건)) | OK |
| `신18` | 연도별 캠페인 신규 중단율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 누계중단 / 누계개발 / 분모: 누계중단 / 누계개발` | `` | `` | 조회시점 기준 캠페인 누계중단(건) / 캠페인별 누계개발(건) | OK |
| `신19` | 납입방식 중단율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 납입방식 중단건 / (개발건 + 연도초활동건) / 분모: 납입방식 중단건 / (개발건 + 연도초활동건)` | `` | `` | 캠페인별 납입방식 중단(건) / (캠페인별 납입방식 개발(건) + 캠페인별 연도초활동회원(건)) | OK |
| `신20` | 캠페인별 이탈(건) | measure | CRM | 건 | `FMM` | `FMM.CHURN_CNT` | `CRM_MEMBER_DISCONTINUE + CRM_MEMBER_AMT_CHANGE` | `TM_MM_FDRM_MBER_SPNSR_DSCNTC + TM_MM_FDRM_MBER_IRSD` | 후원취소 및 감액한 후원사업의 금액 / 10,000 | OK |
| `신21` | 캠페인별 이탈율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 이탈건 / 개발건 / 분모: 이탈건 / 개발건` | `` | `` | 캠페인별 이탈(건) / 캠페인별 개발(건) | OK |
| `신22` | 캠페인별 납입율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 월납입회비 / (월말활동건 ×10000) / 분모: 월납입회비 / (월말활동건 ×10000)` | `` | `` | 캠페인별 활동회원의 월 납입회비 / (캠페인별 월말활동회원건 × 10,000) | OK |
| `신23` | 연도별 캠페인별 납입율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 〃 (조회시점) / 분모: 〃 (조회시점)` | `` | `` | 조회시점 기준 캠페인별 활동회원의 월 납입회비 / (캠페인별 월말활동회원건 × 10,000) | OK |
| `신24` | 캠페인별 누계 납입율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 월누계납입 / (월말활동건 ×10000) / 분모: 월누계납입 / (월말활동건 ×10000)` | `` | `` | 캠페인별 활동회원 월 누계납입회비 / (캠페인별 월말활동회원건 × 10,000) | OK |
| `신25` | 연도별 캠페인 누계납입율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 〃 / 분모: 〃` | `` | `` | 조회시점 기준 캠페인별 활동회원 월 누계납입회비 / (캠페인별 월말활동회원건 × 10,000) | OK |
| `신26` | 캠페인별 납입회비 구성비(%) | derived | CRM | % | `SV` | `SV metric — 분자: 캠페인납입회비 / 총납입회비 ×100 / 분모: 캠페인납입회비 / 총납입회비 ×100` | `` | `` | 캠페인별 납입회비 / 총 납입회비 금액 × 100 | OK |
| `신27` | 캠페인별 미납율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 월미납회비 / (월말활동건 ×10000) / 분모: 월미납회비 / (월말활동건 ×10000)` | `` | `` | 캠페인별 활동회원의 월 미납회비 / (캠페인별 월말활동회원건 × 10,000) | OK |
| `신28` | 연도별 캠페인 미납율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 〃 / 분모: 〃` | `` | `` | 조회시점 기준 캠페인별 활동회원의 월 미납회비 / (캠페인별 월말활동회원건 × 10,000) | OK |
| `신29` | 캠페인별 미납회비 구성비(%) | derived | CRM | % | `SV` | `SV metric — 분자: 캠페인미납회비 / 총미납회비 ×100 / 분모: 캠페인미납회비 / 총미납회비 ×100` | `` | `` | 캠페인별 미납회비 / 총 미납회비 금액 × 100 | OK |
| `신30` | 서비스별 발송율(%) | derived | CRM | % | `SV` | `SV metric — 분자: SEND_MEMBERS / 분모: 전체회원수(명)` | `CRM_SEND_MEMBER(MBER_NO distinct)` | `TD_MS_*_SNDNG_DTLS` | 서비스별 발송수(명) / 전체회원수(명) × 100 | OK |
| `신31` | 발송대비 수신율(%) | derived | CRM | % | `SV` | `SV metric — 분자: SUCCESS_MEMBERS / 분모: SEND_MEMBERS` | `CRM_SEND_RESULT(성공)` | `TD_MS_EMAIL_LQY_SNDNG / TD_MS_MSG_AT_LQY_SNDNG / TD_MS_PSTMTR_LQY_SNDNG` | 발송성공수(명) / 발송수(명) × 100 | OK |
| `신32` | 발송대비 클릭율(%) | derived | 복합 | % | `SV` | `SV metric — 분자: GA 클릭회원(명, distinct) / 분모: SEND_MEMBERS` | `` | `` | 클릭수(명) / 발송수(명) × 100 | PARTIAL |
| `신33` | 클릭대비 전환율(%) | derived | 복합 | % | `SV` | `SV metric — 분자: DEV_MEMBERS / 분모: GA 클릭회원(명)` | `CRM_MEMBER_DEV(MBER_NO distinct)` | `TM_MM_FDRM_MBER_DVLP_AMT.MBER_NO` | 개발회원(명) / 서비스 클릭수(명) × 100 | PARTIAL |
| `신34` | 서비스별 증액율(%) | derived | CRM | % | `SV` | `SV metric — 분자: D5_INCREASE_PART_(MEMBERS/CNT) / 분모: SUCCESS_MEMBERS` | `` | `` | (증액 회원수(명,건) / 서비스별 발송 성공회원(명,건)) × 100 | OK |
| `신35` | 서비스별 증액회원 N개월 유지율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 증액코호트 유지 회원수 / 분모: D5_INCREASE_PART_MEMBERS` | `` | `` | (서비스별 증액 후 N개월 시점 유지 회원(명,건) / 서비스별 증액 회원(명,건)) × 100. 유지기간 = AVG(중단일자−가입일자) or AVG(기준일자−가입일자) | OK |
| `신36` | 서비스별 참여회원 N개월 유지율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 참여코호트 유지 회원수 / 분모: 참여회원수(서비스별 상이)` | `` | `` | (서비스별 발송 후 N개월 시점 유지 회원(명,건) / 서비스별 참여 회원(명,건)) × 100. 유지기간 = AVG(중단일자−가입일자) or AVG(기준일자−가입일자) | OK |
| `신37` | 서비스별 증액회원 납입율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 증액코호트 중 납입회원 / 분모: D5_INCREASE_PART_MEMBERS` | `` | `` | (서비스별 증액회원 중 납입회원(명,건) / 서비스별 증액회원(명,건)) × 100. 평균 납입회비 = SUM(서비스별 증액회원의 납입회비) / 서비스별 증액회원(명) | OK |
| `신38` | 서비스별 참여회원 납입율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 참여코호트 중 납입회원 / 분모: 참여회원수` | `` | `` | (서비스별 참여회원 중 납입회원(명,건) / 서비스별 참여회원(명,건)) × 100. 평균 납입회비 = SUM(서비스별 참여회원의 납입회비) / 서비스별 참여회원(명) | OK |
| `신39` | 서비스별 증액회원 중단율(%) | derived | CRM | % | `SV` | `SV metric — 분자: D5_STOP_(MEMBERS/CNT) / 분모: SEND_MEMBERS(총발송)` | `` | `` | (서비스별 증액회원 중 중단회원(명,건) / 서비스별 증액회원(명,건)) × 100. +5일내 중단(명,건) / 총 발송(명,건) | OK |
| `신40` | 서비스별 참여회원 중단율(%) | derived | CRM | % | `SV` | `SV metric — 분자: D5_STOP_(MEMBERS/CNT) / 분모: 참여회원수` | `` | `` | (서비스별 참여회원 중 중단회원(명,건) / 서비스별 참여회원(명,건)) × 100. +5일내 중단(명,건) / 총 발송(명,건) | OK |
| `신41` | 서비스별 증액회원 가입캠페인 구성비(%) | derived | CRM | % | `SV` | `SV metric — 분자: D5_INCREASE_PART(캠페인) / 분모: D5_INCREASE_PART(전체)` | `` | `` | (해당 캠페인 서비스별 증액회원(명,건) / 서비스별 전체 증액회원(명,건)) × 100 | OK |
| `신42` | 서비스별 참여회원 가입캠페인 구성비(%) | derived | CRM | % | `SV` | `SV metric — 분자: 참여(캠페인) / 분모: 참여(전체)` | `` | `` | (해당 캠페인 서비스별 참여회원(명,건) / 서비스별 참여회원(명,건)) × 100 | OK |
| `신43` | 서비스×가입캠페인별 N개월 유지율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 코호트 유지 회원수 / 분모: 캠페인 가입회원수` | `` | `` | (해당 서비스·캠페인 조합에서 N개월 시점 유지 회원(명,건) / 해당 캠페인 가입회원(명,건)) × 100 | OK |
| `신44` | 서비스별 서신 참여율(%) | derived | CRM | % | `SV` | `SV metric — 분자: LETTER_PART_MEMBERS / 분모: 참여회원수` | `CRM_RELATION_ACTIVITY(LETTER)` | `TM_RM_RELATNSP_LETTER_INFO` | (서비스별 서신 참여회원(명,건) / 해당 서비스 참여회원(명,건)) × 100 | OK |
| `신45` | 서비스별 서신참여회원 N개월 유지율(%) | derived | CRM | % | `SV` | `SV metric — 분자: D5_LETTER_PART 유지 회원수 / 분모: LETTER_PART_MEMBERS` | `` | `` | (서신참여 후 N개월 시점 유지 회원(명,건) / 서비스별 서신참여 회원(명,건)) × 100. 유지기간 = AVG(중단일자−가입일자) or AVG(기준일자−가입일자) | OK |
| `신46` | 서비스별 서신참여회원 납입율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 서신코호트 중 납입회원 / 분모: LETTER_PART_MEMBERS` | `` | `` | (서비스별 서신참여회원 중 납입회원(명,건) / 서비스별 서신참여 회원(명,건)) × 100. 평균 납입회비 = SUM(서비스별 서신참여회원의 납입회비) / 서비스별 서신참여회원(명) | OK |
| `신47` | 서비스별 서신참여회원 중단율(%) | derived | CRM | % | `SV` | `SV metric — 분자: D5_STOP(서신코호트) / 분모: LETTER_PART_MEMBERS(또는 총발송)` | `` | `` | (서비스별 서신참여회원 중 중단회원(명,건) / 서비스별 서신참여 회원(명,건)) × 100. +5일내 중단(명,건) / 총 발송(명,건) | OK |
| `신48` | 서비스별 서신참여회원 가입캠페인 구성비(%) | derived | CRM | % | `SV` | `SV metric — 분자: 서신(캠페인) / 분모: 서신(전체)` | `` | `` | (해당 캠페인 서비스별 서신참여회원(명,건) / 서비스별 전체 서신참여회원(명,건)) × 100 | OK |
| `신49` | 서비스별 선물금 참여율(%) | derived | CRM | % | `SV` | `SV metric — 분자: GIFT_PART_MEMBERS / 분모: 참여회원수` | `` | `` | (서비스별 선물금 참여회원(명,건) / 해당 서비스 참여회원(명,건)) × 100 | OK |
| `신50` | 서비스별 선물금참여회원 N개월 유지율(%) | derived | CRM | % | `SV` | `SV metric — 분자: D5_GIFT_PART 유지 회원수 / 분모: GIFT_PART_MEMBERS` | `` | `` | (서비스별 선물금참여 후 N개월 시점 유지 회원(명,건) / 서비스별 선물금참여 회원(명,건)) × 100. 유지기간 = AVG(중단일자−가입일자) or AVG(기준일자−가입일자) | OK |
| `신51` | 서비스별 선물금참여회원 납입율(%) | derived | CRM | % | `SV` | `SV metric — 분자: 선물금코호트 중 납입회원 / 분모: GIFT_PART_MEMBERS` | `` | `` | (서비스별 선물금참여회원 중 납입회원(명,건) / 서비스별 선물금참여 회원(명,건)) × 100. 평균 납입회비 = SUM(서비스별 선물금참여회원의 납입회비) / 서비스별 선물금참여회원수(명) | OK |
| `신52` | 서비스별 선물금참여회원 중단율(%) | derived | CRM | % | `SV` | `SV metric — 분자: D5_STOP(선물금코호트) / 분모: GIFT_PART_MEMBERS(또는 총발송)` | `` | `` | (서비스별 선물금참여회원 중 중단회원(명,건) / 서비스별 선물금참여 회원(명,건)) × 100. +5일내 중단(명,건) / 총 발송(명,건) | OK |
| `신53` | 서비스별 선물금참여회원 가입캠페인 구성비(%) | derived | CRM | % | `SV` | `SV metric — 분자: 선물금(캠페인) / 분모: 선물금(전체)` | `` | `` | (해당 캠페인 서비스별 선물금참여회원(명,건) / 서비스별 전체 선물금참여회원(명,건)) × 100 | OK |

---

## 2. 마케팅 보고서필드 → 지표#/GOLD 매핑

> `99_provided_definition/04_마케팅_보고서필드 인벤토리.md`(디지털/영상/재송출 효율분석 + 전환회원특성 + 캠페인별 LTV)의 필드를 지표번호·GOLD로 매핑.
> **매핑근거**: `필드인벤토리`=05_필드 인벤토리.md의 GOLD 물리 컬럼과 직접 대응(지표번호 없어도 매핑됨. 예: 연령대→`DIM_MEMBER.AGE_BAND`) · `지표사전`=지표명 일치 · `SV파생`=율/증감/구성비/집행율/1인당/납입(명)/누계 등 **물리 컬럼 없이 SV metric으로 계산**(base·원천 병기) · `~`=부분일치. 미매칭 2건은 어드민 푸시(발송·성공건수, ❌삭제 확정)뿐.

| 영역 | 섹션 | 필드값 | 데이터 원천 | TYPE | 대응 지표# | GOLD 매핑 | 분해축 | 매핑근거 |
|---|---|---|---|---|---|---|---|---|
| 마케팅 보고서 | 1. 개발현황 (목표, 실적) | 부서명 | (미정) | 문자 | `공116` | `DIM_ORG.DEPARTMENT` |  | 필드인벤토리 |
| 마케팅 보고서 | 1. 개발현황 (목표, 실적) | 기준일시 | CRM | 날짜 | `(215밖)` | `DIM_DATE.FULL_DATE` |  | 필드인벤토리 |
| 마케팅 보고서 | 1. 개발현황 (목표, 실적) | 매체명(브랜드2) | (상속) | 문자+숫자 | `공11` | `DIM_AD_CREATIVE.MEDIA_NAME` |  | 필드인벤토리 |
| 마케팅 보고서 | 1. 개발현황 (목표, 실적) | 월 목표 | CRM | 숫자(회계) | `(215밖)` | `FACT_TARGET_DEV.GOAL_CNT` |  | 필드인벤토리 |
| 마케팅 보고서 | 1. 개발현황 (목표, 실적) | 일별 실적 | (상속) | 숫자(회계) | `공4·5·149` | `FACT_MEMBER_MONTHLY.DEV_CNT` |  | 필드인벤토리 |
| 마케팅 보고서 | 1. 개발현황 (목표, 실적) | 월 실적 | (상속) | 숫자(회계) | `공4·5·149` | `FACT_MEMBER_MONTHLY.DEV_CNT` |  | 필드인벤토리 |
| 마케팅 보고서 | 1. 개발현황 (목표, 실적) | 월 목표 달성율 | (상속) | 백분율 | `공1` | `SV metric — 분자: DEV_CNT / 분모: GOAL_CNT` |  | 지표사전 |
| 마케팅 보고서 | 1. 개발현황 (목표, 실적) | (누계)월 목표 | (상속) | 숫자(회계) | `(215밖)` | `FACT_TARGET_DEV.GOAL_CNT` | 기간윈도우: YTD 누계 | 필드인벤토리 |
| 마케팅 보고서 | 1. 개발현황 (목표, 실적) | (누계)월 실적 | (상속) | 숫자(회계) | `(YTD)` | `SV metric — 누계 = base의 YTD running sum (P7·물리 미저장)` | 기간윈도우: YTD 누계 | SV파생 |
| 마케팅 보고서 | 1. 개발현황 (목표, 실적) | (누계)월 목표 달성율 | (상속) | 백분율 | `공2` | `SV metric — 분자: DEV_CNT(YTD) / 분모: GOAL_CNT(YTD)` | 기간윈도우: YTD 누계 | 지표사전 |
| 마케팅 보고서 | 1. 개발현황 (목표, 실적) | 연 목표 | (상속) | 숫자(회계) | `(215밖)` | `FACT_TARGET_DEV.GOAL_CNT` |  | 필드인벤토리 |
| 마케팅 보고서 | 1. 개발현황 (목표, 실적) | 연 목표 달성율 | (상속) | 백분율 | `공3` | `SV metric — 분자: DEV_CNT(YR) / 분모: GOAL_CNT(YR)` |  | 지표사전 |
| 마케팅 보고서 | 1. 개발현황 (목표, 실적) | 예산구분 | - | 문자 | `(215밖)` | `DIM_BUDGET_ITEM.BUDGET_CATEGORY` |  | 필드인벤토리 |
| 마케팅 보고서 | 2. 집행예산 및 개발효율 | 매체명(브랜드2) | (상속) | 문자 | `공11` | `DIM_AD_CREATIVE.MEDIA_NAME` |  | 필드인벤토리 |
| 마케팅 보고서 | 2. 집행예산 및 개발효율 | 기준일시 | ERP | 날짜 | `(215밖)` | `DIM_DATE.FULL_DATE` |  | 필드인벤토리 |
| 마케팅 보고서 | 2. 집행예산 및 개발효율 | 세세목명 | ERP | 문자 | `(215밖)` | `DIM_BUDGET_ITEM.BUDGET_ITEM_NAME` |  | 필드인벤토리 |
| 마케팅 보고서 | 2. 집행예산 및 개발효율 | 월 편성예산 | ERP | 숫자(회계) | `(215밖)` | `FACT_BUDGET.PLAN_BUDGET_MONTH` |  | 필드인벤토리 |
| 마케팅 보고서 | 2. 집행예산 및 개발효율 | (누계)편성예산 | ERP | 숫자(회계) | `(YTD)` | `SV metric — 누계 = base의 YTD running sum (P7·물리 미저장)` | 기간윈도우: YTD 누계 | SV파생 |
| 마케팅 보고서 | 2. 집행예산 및 개발효율 | 월 집행예산(ERP 마감값) | ERP | 숫자(회계) | `(215밖)` | `FACT_BUDGET.EXEC_BUDGET_ERP` |  | 필드인벤토리 |
| 마케팅 보고서 | 2. 집행예산 및 개발효율 | (누계)집행예산(ERP 마감값) | ERP | 숫자(회계) | `(YTD)` | `SV metric — 누계 = base의 YTD running sum (P7·물리 미저장)` | 기간윈도우: YTD 누계 | SV파생 |
| 마케팅 보고서 | 2. 집행예산 및 개발효율 | 연 편성예산 | ERP | 숫자(회계) | `(215밖)` | `FACT_BUDGET.PLAN_BUDGET_YEAR` |  | 필드인벤토리 |
| 마케팅 보고서 | 2. 집행예산 및 개발효율 | 연 편성 집행율 | ERP | 백분율 | `(overview)` | `SV metric — 집행율(%) = 집행예산/편성예산 (FBD, P7)` |  | SV파생 |
| 마케팅 보고서 | 2. 집행예산 및 개발효율 | 월 편성 집행율 | ERP | 백분율 | `(overview)` | `SV metric — 집행율(%) = 집행예산/편성예산 (FBD, P7)` |  | SV파생 |
| 마케팅 보고서 | 2. 집행예산 및 개발효율 | 월 집행예산(추정치) | 대행사 자료(일별레포트) | 숫자(회계) | `(215밖)` | `FACT_BUDGET.EXEC_BUDGET_EST` |  | 필드인벤토리 |
| 마케팅 보고서 | 2. 집행예산 및 개발효율 | (누계)집행예산(추정치) | 대행사 자료(일별레포트) | 숫자(회계) | `(YTD)` | `SV metric — 누계 = base의 YTD running sum (P7·물리 미저장) · base: FACT_BUDGET.EXEC_BUDGET_EST` | 기간윈도우: YTD 누계 | SV파생 |
| 마케팅 보고서 | 2. 집행예산 및 개발효율 | 예산구분 | - | 문자 | `(215밖)` | `DIM_BUDGET_ITEM.BUDGET_CATEGORY` |  | 필드인벤토리 |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | 매체명(브랜드2) | 대행사 자료(일별레포트) | 문자 | `공11` | `DIM_AD_CREATIVE.MEDIA_NAME` |  | 필드인벤토리 |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | 기준일시 | 대행사 자료(일별레포트) | 날짜 | `(215밖)` | `DIM_DATE.FULL_DATE` |  | 필드인벤토리 |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | 요일 | 대행사 자료(일별레포트) | 문자 | `(215밖)` | `DIM_DATE.DAY_OF_WEEK` |  | 필드인벤토리 |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | 주차 | 대행사 자료(일별레포트) | 숫자+문자 | `(215밖)` | `DIM_DATE.WEEK_OF_YEAR` | 기간윈도우: 주 | 필드인벤토리 |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | 광고시작시간 | 대행사 자료(일별레포트) | 시간 | `(215밖)` | `FACT_AD_PERFORMANCE.AD_START_TIME` |  | 필드인벤토리 |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | 법인명 | 대행사 자료(일별레포트) | 문자 | `공114` | `DIM_ORG.CORP` |  | 필드인벤토리 |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | 광고유형 | 대행사 자료(일별레포트) | 문자 | `(215밖)` | `DIM_AD_CREATIVE.AD_TYPE` |  | 필드인벤토리 |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | 매체유형명 | 대행사 자료(일별레포트) | 문자 | `공13` | `DIM_AD_CREATIVE.PLATFORM_TYPE` |  | 필드인벤토리~ |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | 국내/해외명 | 대행사 자료(일별레포트) | 문자 | `공15` | `DIM_CAMPAIGN.DOMESTIC_OVERSEAS` |  | 필드인벤토리~ |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | 사업/사례명 | 대행사 자료(일별레포트) | 문자 | `공16` | `DIM_CAMPAIGN.BIZ_CASE_TYPE` |  | 필드인벤토리~ |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | 캠페인 유형명 | 대행사 자료(일별레포트) | 문자 | `공17` | `DIM_CAMPAIGN.CAMPAIGN_TYPE` |  | 필드인벤토리~ |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | 캠페인명 | 대행사 자료(일별레포트) | 문자 | `공18·120·147` | `DIM_CAMPAIGN.CAMPAIGN_NAME` |  | 필드인벤토리 |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | 소재 | 대행사 자료(일별레포트) | 문자+숫자 | `공20` | `DIM_AD_CREATIVE.CREATIVE` |  | 필드인벤토리 |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | CM위치 | 대행사 자료(일별레포트) | 문자 | `공21` | `DIM_AD_CREATIVE.CM_POSITION` |  | 필드인벤토리 |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | 초수 | 대행사 자료(일별레포트) | 시간 | `공22` | `DIM_AD_CREATIVE.DURATION_SEC` |  | 필드인벤토리 |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | 광고비 | 대행사 자료(일별레포트) / Google Ads | 숫자(회계) | `(215밖)` | `FACT_BUDGET.AD_COST` |  | 필드인벤토리 |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | 노출수(횟수) | 대행사 자료(일별레포트) / Google Ads | 숫자(회계) | `공23` | `FACT_AD_PERFORMANCE.IMPRESSIONS` |  | 필드인벤토리 |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | 클릭수 | 대행사 자료(일별레포트) / Google Ads | 숫자(회계) | `공24 공9` | `FACT_AD_PERFORMANCE.CLICKS` |  | 필드인벤토리 |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | GA 전환수(명) | 대행사 자료(일별레포트) / GA | 숫자(회계) | `(215밖)` | `FACT_AD_PERFORMANCE.GA_CONV_CNT` |  | 필드인벤토리 |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | GA 전환수(건) | 대행사 자료(일별레포트) / GA | 숫자(회계) | `(215밖)` | `FACT_AD_PERFORMANCE.GA_CONV_CNT` |  | 필드인벤토리 |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | 인입콜 | 대행사 자료(일별레포트) | 숫자(회계) | `공25` | `FACT_AD_PERFORMANCE.INBOUND_CALL` |  | 필드인벤토리 |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | 잠재고객 이름(=타겟그룹) | GA | 문자 | `(215밖)` | `DIM_AD_CREATIVE.TARGET_GROUP` |  | 필드인벤토리 |
| 마케팅 보고서 | 3. 매체별 개발효율 상세 | member_id(=회원번호) | GA | 숫자 | `공110` | `DIM_MEMBER_IDENTITY` |  | 지표사전~ |
| 마케팅 보고서 | 4. 전환회원 특성 | 매체명(브랜드2) | CRM | 문자 | `공11` | `DIM_AD_CREATIVE.MEDIA_NAME` |  | 필드인벤토리 |
| 마케팅 보고서 | 4. 전환회원 특성 | 기준일시 | CRM | 날짜 | `(215밖)` | `DIM_DATE.FULL_DATE` |  | 필드인벤토리 |
| 마케팅 보고서 | 4. 전환회원 특성 | 브랜드 | CRM | 문자 | `공117` | `DIM_CAMPAIGN.BRAND` |  | 필드인벤토리 |
| 마케팅 보고서 | 4. 전환회원 특성 | 상위캠페인 | CRM | 문자 | `공119` | `DIM_CAMPAIGN.PARENT_CAMPAIGN` |  | 필드인벤토리 |
| 마케팅 보고서 | 4. 전환회원 특성 | 캠페인명 | CRM | 문자 | `공18·120·147` | `DIM_CAMPAIGN.CAMPAIGN_NAME` |  | 필드인벤토리 |
| 마케팅 보고서 | 4. 전환회원 특성 | 개발구분 | CRM | 문자 | `공121` | `FACT_MEMBER_MONTHLY.DEV_TYPE` |  | 필드인벤토리 |
| 마케팅 보고서 | 4. 전환회원 특성 | 법인명 | CRM | 문자 | `공114` | `DIM_ORG.CORP` |  | 필드인벤토리 |
| 마케팅 보고서 | 4. 전환회원 특성 | 후원사업(2)명 | CRM | 문자 | `공123` | `DIM_SPONSORSHIP.SPONSORSHIP_NAME` |  | 필드인벤토리 |
| 마케팅 보고서 | 4. 전환회원 특성 | 성별(회원) | CRM | 문자 | `공130` | `DIM_MEMBER.GENDER` |  | 필드인벤토리 |
| 마케팅 보고서 | 4. 전환회원 특성 | 연령대 | CRM | 숫자+문자 | `(215밖)` | `DIM_MEMBER.AGE_BAND` |  | 필드인벤토리 |
| 마케팅 보고서 | 4. 전환회원 특성 | 회원번호 | CRM | (미정) | `공110` | `DIM_MEMBER_IDENTITY.MEMBER_NO` |  | 필드인벤토리 |
| 마케팅 보고서 | 4. 전환회원 특성 | 개발(건) | CRM | 숫자 | `공4·5·149` | `FACT_MEMBER_MONTHLY.DEV_CNT` |  | 필드인벤토리 |
| 마케팅 보고서 | 5. 캠페인별 LTV (신규) | 매체명(브랜드2) | CRM | 문자 | `공11` | `DIM_AD_CREATIVE.MEDIA_NAME` |  | 필드인벤토리 |
| 마케팅 보고서 | 5. 캠페인별 LTV (신규) | 기준일시 | CRM | 날짜 | `(215밖)` | `DIM_DATE.FULL_DATE` |  | 필드인벤토리 |
| 마케팅 보고서 | 5. 캠페인별 LTV (신규) | 부서명 | CRM | 문자 | `공116` | `DIM_ORG.DEPARTMENT` |  | 필드인벤토리 |
| 마케팅 보고서 | 5. 캠페인별 LTV (신규) | 브랜드 | CRM | 문자 | `공117` | `DIM_CAMPAIGN.BRAND` |  | 필드인벤토리 |
| 마케팅 보고서 | 5. 캠페인별 LTV (신규) | 상위캠페인 | CRM | 문자 | `공119` | `DIM_CAMPAIGN.PARENT_CAMPAIGN` |  | 필드인벤토리 |
| 마케팅 보고서 | 5. 캠페인별 LTV (신규) | 캠페인명 | CRM | 문자 | `공18·120·147` | `DIM_CAMPAIGN.CAMPAIGN_NAME` |  | 필드인벤토리 |
| 마케팅 보고서 | 5. 캠페인별 LTV (신규) | 후원사업(2)명 | CRM | 문자 | `공123` | `DIM_SPONSORSHIP.SPONSORSHIP_NAME` |  | 필드인벤토리 |
| 마케팅 보고서 | 5. 캠페인별 LTV (신규) | 개발구분 | 4-5) 개발구분 테이블 참조 | 문자 | `공121` | `FACT_MEMBER_MONTHLY.DEV_TYPE` |  | 필드인벤토리 |
| 마케팅 보고서 | 5. 캠페인별 LTV (신규) | 회원번호 | CRM | 문자 | `공110` | `DIM_MEMBER_IDENTITY.MEMBER_NO` |  | 필드인벤토리 |
| 마케팅 보고서 | 5. 캠페인별 LTV (신규) | 개발(건) | CRM | 숫자 | `공4·5·149` | `FACT_MEMBER_MONTHLY.DEV_CNT` |  | 필드인벤토리 |
| 마케팅 보고서 | 5. 캠페인별 LTV (신규) | 가입캠페인중단일 | CRM | 날짜 | `공26` | `FACT_MEMBER_MONTHLY.STOP_DATE` |  | 필드인벤토리 |
| 마케팅 보고서 | 5. 캠페인별 LTV (신규) | 총납입금액(회비) | CRM | 숫자(회계) | `공70` | `FMM.PAID_FEE` |  | 지표사전~ |

---

## 3. 회원 보고서필드 → 지표#/GOLD 매핑

> `99_provided_definition/05_회원_보고서필드 인벤토리.md`(개발현황·회원특성·서비스 보고서의 CRM/GA 필드)를 지표번호·GOLD로 매핑.

| 영역 | 섹션 | 필드값 | 데이터 원천 | TYPE | 대응 지표# | GOLD 매핑 | 분해축 | 매핑근거 |
|---|---|---|---|---|---|---|---|---|
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · CRM 필드 | 기준일자 | CRM | 날짜 | `(215밖)` | `DIM_DATE.FULL_DATE` |  | 필드인벤토리 |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · CRM 필드 | 월목표 | CRM | 숫자(회계) | `(215밖)` | `FACT_TARGET_DEV.GOAL_CNT` |  | 필드인벤토리 |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · CRM 필드 | 누계목표 | CRM | 숫자(회계) | `(215밖)` | `FACT_TARGET_DEV.GOAL_CNT` | 기간윈도우: YTD 누계 | 필드인벤토리 |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · CRM 필드 | 연목표 | CRM | 숫자(회계) | `(215밖)` | `FACT_TARGET_DEV.GOAL_CNT` |  | 필드인벤토리 |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · CRM 필드 | 법인 | CRM | 문자 | `공114` | `DIM_ORG.CORP` |  | 필드인벤토리 |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · CRM 필드 | 부서 | CRM | 문자 | `공116` | `DIM_ORG.DEPARTMENT` |  | 필드인벤토리 |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · CRM 필드 | 브랜드 | CRM | 문자 | `공117` | `DIM_CAMPAIGN.BRAND` |  | 필드인벤토리 |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · CRM 필드 | 홍보방법 | CRM | 문자 | `공118` | `DIM_CAMPAIGN.PROMO_METHOD` |  | 필드인벤토리 |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · CRM 필드 | 상위캠페인 | CRM | 문자+숫자 | `공119` | `DIM_CAMPAIGN.PARENT_CAMPAIGN` |  | 필드인벤토리 |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · CRM 필드 | 캠페인 | CRM | 문자+숫자 | `공18·120·147` | `DIM_CAMPAIGN.CAMPAIGN_NAME` |  | 필드인벤토리 |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · CRM 필드 | 개발구분 | CRM | 문자 | `공121` | `FACT_MEMBER_MONTHLY.DEV_TYPE` |  | 필드인벤토리 |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · CRM 필드 | 후원사업 | CRM | 문자 | `공123` | `DIM_SPONSORSHIP.SPONSORSHIP_NAME` |  | 필드인벤토리 |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · CRM 필드 | 개발(명) | CRM | 숫자(회계) | `공148` | `FACT_MEMBER_MONTHLY.DEV_MEMBERS` |  | 필드인벤토리 |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · CRM 필드 | 개발(건) | CRM | 숫자(회계) | `공4·5·149` | `FACT_MEMBER_MONTHLY.DEV_CNT` |  | 필드인벤토리 |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · CRM 필드 | 월 목표대비 개발건(%) | CRM | 백분율(계산식) | `공1` | `SV metric — 분자: DEV_CNT / 분모: GOAL_CNT` |  | 지표사전 |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · CRM 필드 | 누계 목표대비 개발건(%) | CRM | 백분율(계산식) | `공2` | `SV metric — 분자: DEV_CNT(YTD) / 분모: GOAL_CNT(YTD)` | 기간윈도우: YTD 누계 | 지표사전 |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · CRM 필드 | 연 목표대비 개발건(%) | CRM | 백분율(계산식) | `공3` | `SV metric — 분자: DEV_CNT(YR) / 분모: GOAL_CNT(YR)` |  | 지표사전 |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · GA 필드 | 방문수 합계 | GA | 숫자(회계) | `공92` | `FACT_GA_BEHAVIOR.VISITS` | (전체 합계 · 축 없음) | 필드인벤토리~ |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · GA 필드 | 활성사용자 합계 | GA | 숫자(회계) | `공93` | `FACT_GA_BEHAVIOR.ACTIVE_USERS` | (전체 합계 · 축 없음) | 필드인벤토리~ |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · GA 필드 | 방문수 대비 개발건(%) | GA | 백분율 | `(SV ratio)` | `SV metric — 대비(%) = 분자/분모 ×100 — 보고서 정의상 두 base 비율(분모는 보고서 문맥 확인) · base: FACT_MEMBER_MONTHLY.DEV_CNT` |  | SV파생 |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · GA 필드 | 활성사용자 대비 개발건(%) | GA | 백분율 | `(SV ratio)` | `SV metric — 대비(%) = 분자/분모 ×100 — 보고서 정의상 두 base 비율(분모는 보고서 문맥 확인) · base: FACT_MEMBER_MONTHLY.DEV_CNT` |  | SV파생 |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · GA 필드 | PC방문수 | GA | 숫자(회계) | `공92` | `FACT_GA_BEHAVIOR.VISITS` | DIM_DEVICE.DEVICE_TYPE='PC' | 필드인벤토리~ |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · GA 필드 | M방문수 | GA | 숫자(회계) | `공92` | `FACT_GA_BEHAVIOR.VISITS` | DIM_DEVICE.DEVICE_TYPE='M' | 필드인벤토리~ |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · GA 필드 | APP방문수 | GA | 숫자(회계) | `공92` | `FACT_GA_BEHAVIOR.VISITS` | DIM_DEVICE.DEVICE_TYPE='APP' ⚠️축값 미적재(2026-07-27 실측: PC·M만) | 필드인벤토리~ |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · GA 필드 | PC활성사용자 | GA | 숫자(회계) | `공93` | `FACT_GA_BEHAVIOR.ACTIVE_USERS` | DIM_DEVICE.DEVICE_TYPE='PC' | 필드인벤토리~ |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · GA 필드 | M활성사용자 | GA | 숫자(회계) | `공93` | `FACT_GA_BEHAVIOR.ACTIVE_USERS` | DIM_DEVICE.DEVICE_TYPE='M' | 필드인벤토리~ |
| 1. 개발현황 | 1-1. [회원] 개발실적보고 (일일) · GA 필드 | APP활성사용자 | GA | 숫자(회계) | `공93` | `FACT_GA_BEHAVIOR.ACTIVE_USERS` | DIM_DEVICE.DEVICE_TYPE='APP' ⚠️축값 미적재(2026-07-27 실측: PC·M만) | 필드인벤토리~ |
| 1. 개발현황 | 1-2. [회원] 개발실적보고 (주간) · CRM 필드 | 기준일자 | CRM | 날짜 | `(215밖)` | `DIM_DATE.FULL_DATE` |  | 필드인벤토리 |
| 1. 개발현황 | 1-2. [회원] 개발실적보고 (주간) · CRM 필드 | 월 목표 | CRM | 숫자(회계) | `(215밖)` | `FACT_TARGET_DEV.GOAL_CNT` |  | 필드인벤토리 |
| 1. 개발현황 | 1-2. [회원] 개발실적보고 (주간) · CRM 필드 | 누계목표 | CRM | 숫자(회계) | `(215밖)` | `FACT_TARGET_DEV.GOAL_CNT` | 기간윈도우: YTD 누계 | 필드인벤토리 |
| 1. 개발현황 | 1-2. [회원] 개발실적보고 (주간) · CRM 필드 | 연목표 | CRM | 숫자(회계) | `(215밖)` | `FACT_TARGET_DEV.GOAL_CNT` |  | 필드인벤토리 |
| 1. 개발현황 | 1-2. [회원] 개발실적보고 (주간) · CRM 필드 | 법인 | CRM | 문자 | `공114` | `DIM_ORG.CORP` |  | 필드인벤토리 |
| 1. 개발현황 | 1-2. [회원] 개발실적보고 (주간) · CRM 필드 | 부서 | CRM | 문자 | `공116` | `DIM_ORG.DEPARTMENT` |  | 필드인벤토리 |
| 1. 개발현황 | 1-2. [회원] 개발실적보고 (주간) · CRM 필드 | 브랜드 | CRM | 문자 | `공117` | `DIM_CAMPAIGN.BRAND` |  | 필드인벤토리 |
| 1. 개발현황 | 1-2. [회원] 개발실적보고 (주간) · CRM 필드 | 홍보방법 | CRM | 문자 | `공118` | `DIM_CAMPAIGN.PROMO_METHOD` |  | 필드인벤토리 |
| 1. 개발현황 | 1-2. [회원] 개발실적보고 (주간) · CRM 필드 | 캠페인 | CRM | 문자+숫자 | `공18·120·147` | `DIM_CAMPAIGN.CAMPAIGN_NAME` |  | 필드인벤토리 |
| 1. 개발현황 | 1-2. [회원] 개발실적보고 (주간) · CRM 필드 | 후원사업 | CRM | 문자 | `공123` | `DIM_SPONSORSHIP.SPONSORSHIP_NAME` |  | 필드인벤토리 |
| 1. 개발현황 | 1-2. [회원] 개발실적보고 (주간) · CRM 필드 | 개발(건) | CRM | 숫자(회계) | `공4·5·149` | `FACT_MEMBER_MONTHLY.DEV_CNT` |  | 필드인벤토리 |
| 1. 개발현황 | 1-2. [회원] 개발실적보고 (주간) · CRM 필드 | 누계개발(건) | CRM | 숫자(회계) | `공4·5·149` | `FACT_MEMBER_MONTHLY.DEV_CNT` | 기간윈도우: YTD 누계 | 필드인벤토리 |
| 1. 개발현황 | 1-2. [회원] 개발실적보고 (주간) · CRM 필드 | 전주대비 증감(%) | CRM/계산 | 백분율 | `공60` | `SV metric — 증감율(%) = (당기−전기)/전기×100 (P7 시계열)` | 기간윈도우: 전주 | SV파생 |
| 1. 개발현황 | 1-2. [회원] 개발실적보고 (주간) · CRM 필드 | 월 목표 대비 개발(%) | CRM/계산 | 백분율 | `공1` | `SV metric — 분자: DEV_CNT / 분모: GOAL_CNT` |  | 지표사전 |
| 1. 개발현황 | 1-2. [회원] 개발실적보고 (주간) · CRM 필드 | 누계 목표 대비 개발(%) | CRM/계산 | 백분율 | `공2` | `SV metric — 분자: DEV_CNT(YTD) / 분모: GOAL_CNT(YTD)` | 기간윈도우: YTD 누계 | 지표사전 |
| 1. 개발현황 | 1-2. [회원] 개발실적보고 (주간) · CRM 필드 | 연목표 대비 개발(%) | CRM/계산 | 백분율 | `공3` | `SV metric — 분자: DEV_CNT(YR) / 분모: GOAL_CNT(YR)` |  | 지표사전 |
| 1. 개발현황 | 1-2. [회원] 개발실적보고 (주간) · CRM 필드 | 개발구성비1(%) | CRM/계산 | 백분율 | `(ratio-of-total)` | `SV metric — 구성비/비중(%) = 부분/전체×100 (예: 공26·29·신41 패턴)` |  | SV파생 |
| 1. 개발현황 | 1-2. [회원] 개발실적보고 (주간) · CRM 필드 | 개발구성비2(%) | CRM/계산 | 백분율 | `(ratio-of-total)` | `SV metric — 구성비/비중(%) = 부분/전체×100 (예: 공26·29·신41 패턴)` |  | SV파생 |
| 1. 개발현황 | 1-2. [회원] 개발실적보고 (주간) · CRM 필드 | 전년 동월 누계개발(건) | CRM | 숫자(회계) | `공149` | `FME→FMM.DEV_CNT` | 기간윈도우: 전년 동기+YTD 누계 | 지표사전~ |
| 1. 개발현황 | 1-2. [회원] 개발실적보고 (주간) · GA 필드 | 방문수 | GA | 숫자(회계) | `공92` | `FACT_GA_BEHAVIOR.VISITS` |  | 필드인벤토리~ |
| 1. 개발현황 | 1-2. [회원] 개발실적보고 (주간) · GA 필드 | 활성사용자 | GA | 숫자(회계) | `공93` | `FACT_GA_BEHAVIOR.ACTIVE_USERS` |  | 필드인벤토리~ |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 기준년월 | CRM | 날짜 | `(215밖)` | `DIM_DATE.FULL_DATE` |  | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 월 목표 | CRM | 숫자(회계) | `(215밖)` | `FACT_TARGET_DEV.GOAL_CNT` |  | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 개발(명) | CRM | 숫자(회계) | `공148` | `FACT_MEMBER_MONTHLY.DEV_MEMBERS` |  | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 개발(건) | CRM | 숫자(회계) | `공4·5·149` | `FACT_MEMBER_MONTHLY.DEV_CNT` |  | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 월목표 대비 달성율(%) | CRM/계산 | 백분율 | `공1` | `SV metric — 분자: DEV_CNT / 분모: GOAL_CNT` |  | 지표사전 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 누계 목표 | CRM | 문자 | `(215밖)` | `FACT_TARGET_DEV.GOAL_CNT` | 기간윈도우: YTD 누계 | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 누계 개발(건) | CRM | 숫자(회계) | `공4·5·149` | `FACT_MEMBER_MONTHLY.DEV_CNT` | 기간윈도우: YTD 누계 | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 누계목표 대비 달성율(%) | CRM/계산 | 백분율 | `공2` | `SV metric — 분자: DEV_CNT(YTD) / 분모: GOAL_CNT(YTD)` | 기간윈도우: YTD 누계 | 지표사전 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 연목표 | CRM | 숫자(회계) | `(215밖)` | `FACT_TARGET_DEV.GOAL_CNT` |  | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 연목표 대비 달성율(%) | CRM/계산 | 백분율 | `공3` | `SV metric — 분자: DEV_CNT(YR) / 분모: GOAL_CNT(YR)` |  | 지표사전 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 당월 1인당 후원건수 | CRM/계산 | 숫자(회계) | `공61` | `SV metric — 1명당 건수 = 활동회원(건)/활동회원(명)` | 기간윈도우: 당기 | SV파생 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 전년 동월 개발(명) | CRM | 숫자(회계) | `공148` | `FACT_MEMBER_MONTHLY.DEV_MEMBERS` | 기간윈도우: 전년 동기 | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 전년 동월 개발(건) | CRM | 숫자(회계) | `공149` | `FME→FMM.DEV_CNT` | 기간윈도우: 전년 동기 | 지표사전~ |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 전년 동월대비 증감(%) | CRM/계산 | 백분율 | `공60` | `SV metric — 증감율(%) = (당기−전기)/전기×100 (P7 시계열)` | 기간윈도우: 전년 동기 | SV파생 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 전년 누계개발(명) | CRM | 숫자(회계) | `공148` | `FACT_MEMBER_MONTHLY.DEV_MEMBERS` | 기간윈도우: 전년 동기+YTD 누계 | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 전년 누계개발(건) | CRM | 숫자(회계) | `공149` | `FME→FMM.DEV_CNT` | 기간윈도우: 전년 동기+YTD 누계 | 지표사전~ |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 전년 누계대비 증감(%) | CRM/계산 | 백분율 | `공60` | `SV metric — 증감율(%) = (당기−전기)/전기×100 (P7 시계열)` | 기간윈도우: 전년 동기+YTD 누계 | SV파생 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 전년 대비 증감(%) | CRM/계산 | 백분율 | `공60` | `SV metric — 증감율(%) = (당기−전기)/전기×100 (P7 시계열)` | 기간윈도우: 전년 동기 | SV파생 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 부서 | CRM | 문자 | `공116` | `DIM_ORG.DEPARTMENT` |  | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 브랜드 | CRM | 문자 | `공117` | `DIM_CAMPAIGN.BRAND` |  | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 홍보방법 | CRM | 문자 | `공118` | `DIM_CAMPAIGN.PROMO_METHOD` |  | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 상위캠페인 | CRM | 문자+숫자 | `공119` | `DIM_CAMPAIGN.PARENT_CAMPAIGN` |  | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 캠페인 | CRM | 문자+숫자 | `공18·120·147` | `DIM_CAMPAIGN.CAMPAIGN_NAME` |  | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 후원사업 | CRM | 문자 | `공123` | `DIM_SPONSORSHIP.SPONSORSHIP_NAME` |  | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 개발구분 | CRM | 문자 | `공121` | `FACT_MEMBER_MONTHLY.DEV_TYPE` |  | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 연령대 | CRM | 숫자+문자 | `(215밖)` | `DIM_MEMBER.AGE_BAND` |  | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 지역 | CRM | 문자 | `공131` | `DIM_MEMBER.REGION` |  | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 후원금액대(약정금액 기준 ÷ 10000원) | CRM | 숫자+문자 | `공72` | `FACT_MEMBER_MONTHLY.AMOUNT_BAND1` |  | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 후원금액대2 | CRM | 숫자+문자 | `공73` | `FMM(스냅샷)` |  | 지표사전 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 후원기간대(납입기준) | CRM | 숫자+문자 | `공74` | `FACT_MEMBER_MONTHLY.PERIOD_BAND1` |  | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 회원번호 | CRM | 숫자 | `공110` | `DIM_MEMBER_IDENTITY.MEMBER_NO` |  | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | 인바운드콜수 | CRM | 숫자 | `(215밖)` | `FACT_MEMBER_MONTHLY.INBOUND_CALL_CNT` |  | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · CRM 필드 | TS콜수 | CRM | 숫자 | `(215밖)` | `FACT_MEMBER_MONTHLY.TS_CALL_CNT` |  | 필드인벤토리 |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · GA 필드 | 방문수 | GA | 숫자(회계) | `공92` | `FACT_GA_BEHAVIOR.VISITS` |  | 필드인벤토리~ |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · GA 필드 | 활성사용자 | GA | 숫자(회계) | `공93` | `FACT_GA_BEHAVIOR.ACTIVE_USERS` |  | 필드인벤토리~ |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · GA 필드 | 방문수 | GA | 숫자(회계) | `공92` | `FACT_GA_BEHAVIOR.VISITS` |  | 필드인벤토리~ |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · GA 필드 | 활성사용자 | GA | 숫자(회계) | `공93` | `FACT_GA_BEHAVIOR.ACTIVE_USERS` |  | 필드인벤토리~ |
| 1. 개발현황 | 1-3. [회원] 개발실적보고 (월간) · GA 필드 | 이벤트수 | GA | 숫자(회계) | `공95` | `FACT_GA_BEHAVIOR.EVENT_CNT` |  | 필드인벤토리~ |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 기준일자 | CRM | 날짜 | `(215밖)` | `DIM_DATE.FULL_DATE` |  | 필드인벤토리 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 신규기존구분 | CRM | 문자 | `공113` | `DIM_MEMBER.NEW_EXISTING_FLAG` |  | 필드인벤토리 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 중단(명) *당월 주차 | CRM | 숫자(회계) | `(215밖)` | `FACT_MEMBER_EVENT.STOP_MEMBERS` | 기간윈도우: 주 | 필드인벤토리~ |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 중단(건) *당월 주차 | CRM | 숫자(회계) | `공35` | `FACT_MEMBER_EVENT.STOP_CNT` | 기간윈도우: 주 | 필드인벤토리~ |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 중단(명) *전년 동월 주차 | CRM | 숫자(회계) | `(215밖)` | `FACT_MEMBER_EVENT.STOP_MEMBERS` | 기간윈도우: 전년 동기+주 | 필드인벤토리~ |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 중단(건) *전년 동월 주차 | CRM | 숫자(회계) | `공35` | `FACT_MEMBER_EVENT.STOP_CNT` | 기간윈도우: 전년 동기+주 | 필드인벤토리~ |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 중단(명) *전전년 동월 주차 | CRM | 숫자(회계) | `(215밖)` | `FACT_MEMBER_EVENT.STOP_MEMBERS` | 기간윈도우: 전전년 동기+주 | 필드인벤토리~ |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 중단(건) *전전년 동월 주차 | CRM | 숫자(회계) | `공35` | `FACT_MEMBER_EVENT.STOP_CNT` | 기간윈도우: 전전년 동기+주 | 필드인벤토리~ |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 중단 구성비(%) | CRM | 백분율 | `(ratio-of-total)` | `SV metric — 구성비/비중(%) = 부분/전체×100 (예: 공26·29·신41 패턴)` |  | SV파생 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 전년 대비 증감(명) | CRM | 숫자(회계) | `공59` | `SV metric — 증감 = 당기−전기 (P7 시계열)` | 기간윈도우: 전년 동기 | SV파생 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 전년 대비 증감(건) | CRM | 숫자(회계) | `공59` | `SV metric — 증감 = 당기−전기 (P7 시계열)` | 기간윈도우: 전년 동기 | SV파생 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 전년 대비 건 증감(%) | CRM | 백분율 | `공60` | `SV metric — 증감율(%) = (당기−전기)/전기×100 (P7 시계열)` | 기간윈도우: 전년 동기 | SV파생 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 전전년 대비 증감(명) | CRM | 숫자(회계) | `공59` | `SV metric — 증감 = 당기−전기 (P7 시계열)` | 기간윈도우: 전전년 동기 | SV파생 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 전전년 대비 증감(건) | CRM | 숫자(회계) | `공59` | `SV metric — 증감 = 당기−전기 (P7 시계열)` | 기간윈도우: 전전년 동기 | SV파생 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 전전년 대비 건 증감(%) | CRM | 백분율 | `공60` | `SV metric — 증감율(%) = (당기−전기)/전기×100 (P7 시계열)` | 기간윈도우: 전전년 동기 | SV파생 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 기준년도 | CRM | 숫자(회계) | `(215밖)` | `DIM_DATE.FULL_DATE` |  | 필드인벤토리 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 당해년도 주간 개발건 | CRM | 숫자(회계) | `공149` | `FME→FMM.DEV_CNT` | 기간윈도우: 주 | 지표사전~ |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 전년도 주간 개발건 | CRM | 숫자(회계) | `공149` | `FME→FMM.DEV_CNT` | 기간윈도우: 전년 동기+주 | 지표사전~ |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 전전년도 주간 개발건 | CRM | 숫자(회계) | `공149` | `FME→FMM.DEV_CNT` | 기간윈도우: 전전년 동기+주 | 지표사전~ |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 중단율2(%) | CRM | 백분율 | `공55` | `SV metric — 분자: STOP_CNT / 분모: DEV_CNT` |  | 지표사전 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 가입경로 | CRM | 문자 | `(215밖)` | `DIM_MEMBER.ENROLL_PATH` |  | 필드인벤토리 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 회원번호 | CRM | 숫자 | `공110` | `DIM_MEMBER_IDENTITY.MEMBER_NO` |  | 필드인벤토리 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 법인 | CRM | 문자 | `공114` | `DIM_ORG.CORP` |  | 필드인벤토리 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 회원구분 | CRM | 문자 | `(215밖)` | `DIM_MEMBER.MEMBER_TYPE` |  | 필드인벤토리 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 납입방식 | CRM | 문자 | `공125` | `DIM_PAYMENT.PAYMENT_METHOD` |  | 필드인벤토리 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 후원금액 | CRM | 숫자(회계) | `—` | `(미매칭 — GOLD 물리·SV 대응 미확인)` |  |  |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 가입일 | CRM | 날짜 | `(215밖)` | `FACT_MEMBER_EVENT.JOIN_DATE` |  | 필드인벤토리 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 중단일 | CRM | 날짜 | `(215밖)` | `FACT_MEMBER_EVENT.STOP_DATE` |  | 필드인벤토리 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 중단사유 | CRM | 문자 | `(215밖)` | `FACT_MEMBER_EVENT.STOP_REASON` |  | 필드인벤토리 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 브랜드 | CRM | 문자 | `공117` | `DIM_CAMPAIGN.BRAND` |  | 필드인벤토리 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 상위캠페인 | CRM | 문자 | `공119` | `DIM_CAMPAIGN.PARENT_CAMPAIGN` |  | 필드인벤토리 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 가입캠페인 | CRM | 문자 | `공18·120·147` | `DIM_CAMPAIGN.CAMPAIGN_NAME` |  | 필드인벤토리 |
| 2. 회원특성 | 2-1. [회원] 주간 중단보고 · GA 필드 | 가입부서 | CRM | 문자 | `공116` | `DIM_ORG.DEPARTMENT` |  | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 연도초활동(건) | CRM | 숫자(회계) | `공49` | `FACT_MEMBER_MONTHLY.YEAR_START_ACTIVE_CNT` |  | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 신규기존구분 | CRM | 문자 | `공113` | `DIM_MEMBER.NEW_EXISTING_FLAG` |  | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 누계개발(명) | CRM | 숫자(회계) | `공148` | `FACT_MEMBER_MONTHLY.DEV_MEMBERS` | 기간윈도우: YTD 누계 | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 누계개발(건) | CRM | 숫자(회계) | `공4·5·149` | `FACT_MEMBER_MONTHLY.DEV_CNT` | 기간윈도우: YTD 누계 | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 누계중단(명) | CRM | 숫자(회계) | `(215밖)` | `FACT_MEMBER_EVENT.STOP_MEMBERS` | 기간윈도우: YTD 누계 | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 누계중단(건) | CRM | 숫자(회계) | `공35` | `FME→FMM.STOP_CNT` | 기간윈도우: YTD 누계 | 지표사전~ |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 누계중단율1(%) | CRM | 백분율 | `(YTD)` | `SV metric — 누계 = base의 YTD running sum (P7·물리 미저장)` | 기간윈도우: YTD 누계 | SV파생 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 전년도 증감(%) | CRM | 숫자(회계) | `공60` | `SV metric — 증감율(%) = (당기−전기)/전기×100 (P7 시계열)` | 기간윈도우: 전년 동기 | SV파생 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 전전년도 증감(%) | CRM | 숫자(회계) | `공60` | `SV metric — 증감율(%) = (당기−전기)/전기×100 (P7 시계열)` | 기간윈도우: 전전년 동기 | SV파생 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 개발(건) | CRM | 숫자(회계) | `공4·5·149` | `FACT_MEMBER_MONTHLY.DEV_CNT` |  | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 전월말 활동(건) | CRM | 숫자(회계) | `공53` | `FACT_MEMBER_MONTHLY.PREV_MONTH_END_ACTIVE_CNT` |  | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 중단(명) | CRM | 숫자(회계) | `(215밖)` | `FACT_MEMBER_EVENT.STOP_MEMBERS` |  | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 중단(건) | CRM | 숫자(회계) | `공35` | `FACT_MEMBER_EVENT.STOP_CNT` |  | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 월 중단율(%) | CRM | 백분율 | `(SV ratio)` | `SV metric — 비율(%) — SV time-intelligence/ratio` |  | SV파생 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 중단 증감(명) | CRM | 숫자(회계) | `공59` | `SV metric — 증감 = 당기−전기 (P7 시계열)` |  | SV파생 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 중단 증감(건) | CRM | 숫자(회계) | `공59` | `SV metric — 증감 = 당기−전기 (P7 시계열)` |  | SV파생 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 중단율 증감(%p) | CRM | 백분율 | `공60` | `SV metric — 증감율(%) = (당기−전기)/전기×100 (P7 시계열)` |  | SV파생 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 누계중단율2(%) | CRM | 백분율 | `(YTD)` | `SV metric — 누계 = base의 YTD running sum (P7·물리 미저장)` | 기간윈도우: YTD 누계 | SV파생 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 누계중단 증감(명) | CRM | 숫자(회계) | `공59` | `SV metric — 증감 = 당기−전기 (P7 시계열)` | 기간윈도우: YTD 누계 | SV파생 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 누계중단 증감(건) | CRM | 숫자(회계) | `공59` | `SV metric — 증감 = 당기−전기 (P7 시계열)` | 기간윈도우: YTD 누계 | SV파생 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 누계중단율 증감(%p) | CRM | 백분율 | `공60` | `SV metric — 증감율(%) = (당기−전기)/전기×100 (P7 시계열)` | 기간윈도우: YTD 누계 | SV파생 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 미납중단(명) | CRM | 숫자(회계) | `(215밖)` | `FACT_MEMBER_EVENT.UNPAID_STOP_MEMBERS` |  | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 미납중단(건) | CRM | 숫자(회계) | `(215밖)` | `FACT_MEMBER_EVENT.UNPAID_STOP_CNT` |  | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 전체 중 미납중단구성비(%) | CRM | 백분율 | `(ratio-of-total)` | `SV metric — 구성비/비중(%) = 부분/전체×100 (예: 공26·29·신41 패턴)` | (전체 합계 · 축 없음) | SV파생 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 전체회원 활동(건) | CRM | 숫자(회계) | `공37` | `FMM.ACTIVE_CNT` | (전체 합계 · 축 없음) | 지표사전~ |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 부서 | CRM | 문자 | `공116` | `DIM_ORG.DEPARTMENT` |  | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 브랜드 | CRM | 문자 | `공117` | `DIM_CAMPAIGN.BRAND` |  | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 상위캠페인 | CRM | 문자 | `공119` | `DIM_CAMPAIGN.PARENT_CAMPAIGN` |  | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 캠페인 | CRM | 문자 | `공18·120·147` | `DIM_CAMPAIGN.CAMPAIGN_NAME` |  | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 후원사업 | CRM | 문자 | `공123` | `DIM_SPONSORSHIP.SPONSORSHIP_NAME` |  | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 납입방식 | CRM | 문자 | `공125` | `DIM_PAYMENT.PAYMENT_METHOD` |  | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 연령대 | CRM | 숫자+문자 | `(215밖)` | `DIM_MEMBER.AGE_BAND` |  | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 최초가입일 | CRM | 날짜 | `공28` | `DIM_MEMBER.FIRST_JOIN_DATE` |  | 필드인벤토리~ |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 최종중단일 | CRM | 날짜 | `공30` | `DIM_MEMBER.LAST_STOP_DATE` |  | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 최초캠페인 | CRM | 문자 | `공29` | `DIM_MEMBER.FIRST_CAMPAIGN` |  | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 최종캠페인 | CRM | 문자 | `공31` | `DIM_MEMBER.LAST_CAMPAIGN` |  | 필드인벤토리 |
| 2. 회원특성 | 2-2. [회원] 월간 중단보고 · GA 필드 | 회원번호 | CRM | 숫자 | `공110` | `DIM_MEMBER_IDENTITY.MEMBER_NO` |  | 필드인벤토리 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 법인 | CRM | 문자 | `공114` | `DIM_ORG.CORP` |  | 필드인벤토리 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 신규기존구분(최초가입일 당해년도 기준) | CRM | 문자 | `공113` | `DIM_MEMBER.NEW_EXISTING_FLAG` | 기간윈도우: 당기 | 필드인벤토리~ |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 개발구분 | CRM | 문자 | `공121` | `FACT_MEMBER_MONTHLY.DEV_TYPE` |  | 필드인벤토리 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 실적지부(본부/지부) | CRM | 문자 | `공115` | `DIM_ORG.DIVISION` |  | 필드인벤토리 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 브랜드 | CRM | 문자 | `공117` | `DIM_CAMPAIGN.BRAND` |  | 필드인벤토리 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 홍보방법 | CRM | 문자 | `공118` | `DIM_CAMPAIGN.PROMO_METHOD` |  | 필드인벤토리 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 상위캠페인 | CRM | 문자 | `공119` | `DIM_CAMPAIGN.PARENT_CAMPAIGN` |  | 필드인벤토리 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 캠페인 | CRM | 문자 | `공18·120·147` | `DIM_CAMPAIGN.CAMPAIGN_NAME` |  | 필드인벤토리 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 후원사업 | CRM | 문자 | `공123` | `DIM_SPONSORSHIP.SPONSORSHIP_NAME` |  | 필드인벤토리 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 연령대 | CRM | 숫자(회계) | `(215밖)` | `DIM_MEMBER.AGE_BAND` |  | 필드인벤토리 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 납입방식 | CRM | 문자 | `공125` | `DIM_PAYMENT.PAYMENT_METHOD` |  | 필드인벤토리 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 개발(명) | CRM | 숫자(회계) | `공148` | `FACT_MEMBER_MONTHLY.DEV_MEMBERS` |  | 필드인벤토리 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 개발(건) | CRM | 숫자(회계) | `공4·5·149` | `FACT_MEMBER_MONTHLY.DEV_CNT` |  | 필드인벤토리 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 개발구성비(%) | CRM | 백분율 | `(ratio-of-total)` | `SV metric — 구성비/비중(%) = 부분/전체×100 (예: 공26·29·신41 패턴)` |  | SV파생 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 누계개발(명) | CRM | 숫자(회계) | `공148` | `FACT_MEMBER_MONTHLY.DEV_MEMBERS` | 기간윈도우: YTD 누계 | 필드인벤토리 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 누계개발(건) | CRM | 숫자(회계) | `공4·5·149` | `FACT_MEMBER_MONTHLY.DEV_CNT` | 기간윈도우: YTD 누계 | 필드인벤토리 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 누계개발구성비(%) | CRM | 백분율 | `(ratio-of-total)` | `SV metric — 구성비/비중(%) = 부분/전체×100 (예: 공26·29·신41 패턴)` | 기간윈도우: YTD 누계 | SV파생 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 상위캠페인 10개 | CRM | 문자 | `공119` | `DIM_CAMPAIGN.PARENT_CAMPAIGN` |  | 필드인벤토리 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 전년대비 증감 개발(명) | CRM | 숫자(회계) | `공148` | `FACT_MEMBER_MONTHLY.DEV_MEMBERS` | 기간윈도우: 전년 동기 | 필드인벤토리 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 전년대비 증감 개발(건) | CRM | 숫자(회계) | `공59` | `SV metric — 증감 = 당기−전기 (P7 시계열) · base: FACT_MEMBER_MONTHLY.DEV_CNT` | 기간윈도우: 전년 동기 | SV파생 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 전년대비 증감 개발구성비(%p) | CRM | 백분율 | `공60` | `SV metric — 증감율(%) = (당기−전기)/전기×100 (P7 시계열)` | 기간윈도우: 전년 동기 | SV파생 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 활동(명) | CRM | 숫자(회계) | `공156` | `FACT_MEMBER_MONTHLY.ACTIVE_MEMBERS` |  | 필드인벤토리 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 활동(건) | CRM | 숫자(회계) | `공37·157` | `FACT_MEMBER_MONTHLY.ACTIVE_CNT` |  | 필드인벤토리 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 활동구성비(%) | CRM | 백분율 | `(ratio-of-total)` | `SV metric — 구성비/비중(%) = 부분/전체×100 (예: 공26·29·신41 패턴)` |  | SV파생 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 활동율 | CRM | 백분율 | `공45` | `SV metric — 분자: MONTH_END_ACTIVE_CNT / 분모: YEAR_START_ACTIVE_CNT + DEV_CNT(YTD)` |  | 지표사전 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 활동율2 | CRM | 백분율 | `(SV ratio)` | `SV metric — 비율(%) — SV time-intelligence/ratio` |  | SV파생 |
| 2. 회원특성 | 2-3. [회원] 연간분석 (개발/활동) 분석 *월간기준 · GA 필드 | 평균후원기간 | CRM | 숫자(회계) | `(SV avg)` | `SV metric — 평균 — SV 집계(base AVG)` |  | SV파생 |
| 2. 회원특성 | 2-4. [회원] 연간분석 (회비) 분석 *월간기준 · GA 필드 | 납입(명) | CRM | 숫자(회계) | `(FMM 파생)` | `SV metric — 납입회원수(명) = COUNT(DISTINCT MBER_NO WHERE PAY_STAT_CD='S') · 원천 BRONZE_CRM.TM_PM_MBRFEE_ACMSLT(46.4M·적재완료)` |  | SV파생 |
| 2. 회원특성 | 2-4. [회원] 연간분석 (회비) 분석 *월간기준 · GA 필드 | 납입(원) | CRM | 숫자(회계) | `공69` | `FMM.PAID_FEE` |  | 지표사전 |
| 2. 회원특성 | 2-4. [회원] 연간분석 (회비) 분석 *월간기준 · GA 필드 | 납입구성비(%) | CRM | 백분율 | `(ratio-of-total)` | `SV metric — 구성비/비중(%) = 부분/전체×100 (예: 공26·29·신41 패턴)` |  | SV파생 |
| 2. 회원특성 | 2-4. [회원] 연간분석 (회비) 분석 *월간기준 · GA 필드 | 납입률 (납입/활동) | CRM | 문자 | `(SV ratio)` | `SV metric — 비율(%) — SV time-intelligence/ratio` |  | SV파생 |
| 2. 회원특성 | 2-4. [회원] 연간분석 (회비) 분석 *월간기준 · GA 필드 | 납입률2 (납입/총활동) | CRM | 문자 | `(SV ratio)` | `SV metric — 비율(%) — SV time-intelligence/ratio` |  | SV파생 |
| 2. 회원특성 | 2-4. [회원] 연간분석 (회비) 분석 *월간기준 · GA 필드 | 회원번호 | CRM | 문자 | `공110` | `DIM_MEMBER_IDENTITY.MEMBER_NO` |  | 필드인벤토리 |
| 2. 회원특성 | 2-4. [회원] 연간분석 (회비) 분석 *월간기준 · GA 필드 | 법인 | CRM | 문자 | `공114` | `DIM_ORG.CORP` |  | 필드인벤토리 |
| 2. 회원특성 | 2-4. [회원] 연간분석 (회비) 분석 *월간기준 · GA 필드 | 실적지부 | CRM | 문자 | `공115` | `DIM_ORG.DIVISION` |  | 필드인벤토리 |
| 2. 회원특성 | 2-4. [회원] 연간분석 (회비) 분석 *월간기준 · GA 필드 | 브랜드 | CRM | 문자 | `공117` | `DIM_CAMPAIGN.BRAND` |  | 필드인벤토리 |
| 2. 회원특성 | 2-4. [회원] 연간분석 (회비) 분석 *월간기준 · GA 필드 | 홍보방법 | CRM | 문자 | `공118` | `DIM_CAMPAIGN.PROMO_METHOD` |  | 필드인벤토리 |
| 2. 회원특성 | 2-4. [회원] 연간분석 (회비) 분석 *월간기준 · GA 필드 | 상위캠페인 | CRM | 문자 | `공119` | `DIM_CAMPAIGN.PARENT_CAMPAIGN` |  | 필드인벤토리 |
| 2. 회원특성 | 2-4. [회원] 연간분석 (회비) 분석 *월간기준 · GA 필드 | 캠페인 | CRM | 문자 | `공18·120·147` | `DIM_CAMPAIGN.CAMPAIGN_NAME` |  | 필드인벤토리 |
| 2. 회원특성 | 2-4. [회원] 연간분석 (회비) 분석 *월간기준 · GA 필드 | 후원사업 | CRM | 문자 | `공123` | `DIM_SPONSORSHIP.SPONSORSHIP_NAME` |  | 필드인벤토리 |
| 2. 회원특성 | 2-4. [회원] 연간분석 (회비) 분석 *월간기준 · GA 필드 | 회원상태 | CRM | 문자 | `공132` | `DIM_MEMBER.MEMBER_STATUS` |  | 필드인벤토리 |
| 2. 회원특성 | 2-4. [회원] 연간분석 (회비) 분석 *월간기준 · GA 필드 | 최초가입일 | CRM | 날짜 | `공28` | `DIM_MEMBER.FIRST_JOIN_DATE` |  | 필드인벤토리~ |
| 2. 회원특성 | 2-4. [회원] 연간분석 (회비) 분석 *월간기준 · GA 필드 | 납입(원) | CRM | 숫자(회계) | `공69` | `FMM.PAID_FEE` |  | 지표사전 |
| 2. 회원특성 | 2-4. [회원] 연간분석 (회비) 분석 *월간기준 · GA 필드 | 누계납입(원) | CRM | 숫자(회계) | `공70` | `FMM.PAID_FEE` | 기간윈도우: YTD 누계 | 지표사전~ |
| 2. 회원특성 | 2-4. [회원] 연간분석 (회비) 분석 *월간기준 · GA 필드 | 기준일(납입일) | CRM | 날짜 | `(215밖)` | `DIM_DATE.FULL_DATE` |  | 필드인벤토리 |
| 2. 회원특성 | 2-4. [회원] 연간분석 (회비) 분석 *월간기준 · GA 필드 | 결제방식 | CRM | 문자 | `(215밖)` | `DIM_PAYMENT.SETTLE_METHOD` |  | 필드인벤토리 |
| 2. 회원특성 | 2-4. [회원] 연간분석 (회비) 분석 *월간기준 · GA 필드 | 회원번호 | CRM | 숫자 | `공110` | `DIM_MEMBER_IDENTITY.MEMBER_NO` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 발송일 | CRM | 날짜 | `(215밖)` | `FACT_SERVICE_EVENT.DATE_SK` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 발송구분(대) | CRM | 문자 | `공133` | `DIM_SERVICE.SEND_TYPE_L` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 발송구분(중) | CRM | 문자 | `공134` | `DIM_SERVICE.SEND_TYPE_M` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 발송구분(소) | CRM | 문자 | `공135` | `DIM_SERVICE.SEND_TYPE_S` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 제목 | CRM | 문자 | `공136` | `FACT_SERVICE_EVENT.SEND_TITLE` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 발송유형 | CRM | 문자 | `(215밖)` | `FACT_SERVICE_EVENT.SEND_TYPE` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 발송(명) | CRM | 숫자(회계) | `공85` | `FACT_SERVICE_EVENT.SEND_MEMBERS` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 성공(명) | CRM | 숫자(회계) | `공86` | `FACT_SERVICE_EVENT.SUCCESS_MEMBERS` |  | 필드인벤토리~ |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 실패(명) | CRM | 숫자(회계) | `공87` | `FACT_SERVICE_EVENT.FAIL_MEMBERS` |  | 필드인벤토리~ |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 발송대비 성공율(%) | CRM | 백분율 | `(SV ratio)` | `SV metric — 대비(%) = 분자/분모 ×100 — 보고서 정의상 두 base 비율(분모는 보고서 문맥 확인)` |  | SV파생 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 회원번호 | CRM | 문자 | `공110` | `DIM_MEMBER_IDENTITY.MEMBER_NO` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 아동번호 | CRM | 문자 | `공122` | `DIM_MEMBER_IDENTITY` |  | 지표사전 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 결연회원중단여부 | CRM | 문자 | `(215밖)` | `FACT_SERVICE_EVENT.MEMBER_STOP_FLAG` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 회원상태 | CRM | 문자 | `공132` | `DIM_MEMBER.MEMBER_STATUS` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 발송상태1 | CRM | 문자 | `공138` | `FACT_SERVICE_EVENT.SEND_STATUS` |  | 필드인벤토리~ |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 발송상태2 | CRM | 문자 | `(215밖)` | `FACT_SERVICE_EVENT.SEND_STATUS2` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 중단(명) | CRM | 숫자(회계) | `(215밖)` | `FACT_MEMBER_EVENT.STOP_MEMBERS` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 중단(건) | CRM | 숫자(회계) | `공35` | `FACT_MEMBER_EVENT.STOP_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 최초캠페인 | CRM | 문자 | `공29` | `DIM_MEMBER.FIRST_CAMPAIGN` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 최초브랜드 | CRM | 문자 | `공29` | `DIM_MEMBER.FIRST_CAMPAIGN` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 최초상위캠페인 | CRM | 문자 | `공119` | `DIM_CAMPAIGN.PARENT_CAMPAIGN` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 최초 후원사업 | CRM | 문자 | `(215밖)` | `DIM_MEMBER.FIRST_SPONSORSHIP` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 현재 후원사업 | CRM | 문자 | `(215밖)` | `DIM_MEMBER.CURRENT_SPONSORSHIP` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 연령대 | CRM | 숫자+문자 | `(215밖)` | `DIM_MEMBER.AGE_BAND` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 증액(명) | CRM | 숫자(회계) | `공150` | `FACT_MEMBER_MONTHLY.INCREASE_MEMBERS` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 증액(건) | CRM | 숫자(회계) | `공151` | `FACT_MEMBER_MONTHLY.INCREASE_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 서신 참여(명) | CRM | 숫자(회계) | `공88` | `FACT_SERVICE_EVENT.LETTER_PART_MEMBERS` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 서신 참여(건) | CRM | 숫자(회계) | `공89` | `FACT_SERVICE_EVENT.LETTER_PART_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 선물금 참여(명) | CRM | 숫자(회계) | `공90` | `FACT_SERVICE_EVENT.GIFT_PART_MEMBERS` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 선물금 참여(건) | CRM | 숫자(회계) | `—` | `(미매칭 — GOLD 물리·SV 대응 미확인)` |  |  |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · CRM 필드 | 이벤트 관리 | CRM | 숫자(회계) | `(215밖)` | `DIM_EVENT.EVENT_NAME` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · GA 필드 | 조회수 | GA | 숫자(회계) | `공96` | `FACT_GA_BEHAVIOR.VIEW_CNT` |  | 필드인벤토리~ |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · GA 필드 | 이벤트수 | GA | 숫자(회계) | `공95` | `FACT_GA_BEHAVIOR.EVENT_CNT` |  | 필드인벤토리~ |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · GA 필드 | 세션수 | GA | 숫자(회계) | `공97` | `FACT_GA_BEHAVIOR.SESSION_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-1. [회원] 서비스효과성분석보고 (알림톡/이메일) *일일기준 · GA 필드 | 평균 세션 시간 | GA | 숫자(회계) | `공98` | `FACT_GA_BEHAVIOR.AVG_SESSION_DURATION` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 발송일 | CRM | 날짜 | `(215밖)` | `FACT_SERVICE_EVENT.DATE_SK` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 발송구분(대) | CRM | 문자 | `공133` | `DIM_SERVICE.SEND_TYPE_L` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 발송구분(중) | CRM | 문자 | `공134` | `DIM_SERVICE.SEND_TYPE_M` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 발송구분(소) | CRM | 문자 | `공135` | `DIM_SERVICE.SEND_TYPE_S` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 제목 | CRM | 문자 | `공136` | `FACT_SERVICE_EVENT.SEND_TITLE` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 발송유형 | CRM | 문자 | `(215밖)` | `FACT_SERVICE_EVENT.SEND_TYPE` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 발송(명) | CRM | 숫자(회계) | `공85` | `FACT_SERVICE_EVENT.SEND_MEMBERS` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 성공(명) | CRM | 숫자(회계) | `공86` | `FACT_SERVICE_EVENT.SUCCESS_MEMBERS` |  | 필드인벤토리~ |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 실패(명) | CRM | 숫자(회계) | `공87` | `FACT_SERVICE_EVENT.FAIL_MEMBERS` |  | 필드인벤토리~ |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 발송대비 성공율(%) | CRM | 백분율 | `(SV ratio)` | `SV metric — 대비(%) = 분자/분모 ×100 — 보고서 정의상 두 base 비율(분모는 보고서 문맥 확인)` |  | SV파생 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 개발(명) | CRM | 숫자(회계) | `공148` | `FACT_MEMBER_MONTHLY.DEV_MEMBERS` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 개발(건) | CRM | 숫자(회계) | `공4·5·149` | `FACT_MEMBER_MONTHLY.DEV_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 중단(명) | CRM | 숫자(회계) | `(215밖)` | `FACT_MEMBER_EVENT.STOP_MEMBERS` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 중단(건) | CRM | 숫자(회계) | `공35` | `FACT_MEMBER_EVENT.STOP_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 발송 대비 개발명(%) | CRM | 백분율 | `(SV ratio)` | `SV metric — 대비(%) = 분자/분모 ×100 — 보고서 정의상 두 base 비율(분모는 보고서 문맥 확인) · base: FACT_MEMBER_MONTHLY.DEV_MEMBERS` |  | SV파생 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 발송 대비 중단명(%) | CRM | 백분율 | `(SV ratio)` | `SV metric — 대비(%) = 분자/분모 ×100 — 보고서 정의상 두 base 비율(분모는 보고서 문맥 확인) · base: FACT_MEMBER_EVENT.STOP_MEMBERS` |  | SV파생 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 회원번호 | CRM | 숫자 | `공110` | `DIM_MEMBER_IDENTITY.MEMBER_NO` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 브랜드 | CRM | 문자 | `공117` | `DIM_CAMPAIGN.BRAND` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 상위캠페인 | CRM | 문자 | `공119` | `DIM_CAMPAIGN.PARENT_CAMPAIGN` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 캠페인 | CRM | 문자 | `공18·120·147` | `DIM_CAMPAIGN.CAMPAIGN_NAME` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 후원사업 | CRM | 문자 | `공123` | `DIM_SPONSORSHIP.SPONSORSHIP_NAME` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 연령대 | CRM | 숫자+문자 | `(215밖)` | `DIM_MEMBER.AGE_BAND` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 성별 | CRM | 문자 | `공130` | `DIM_MEMBER.GENDER` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 지역 | CRM | 문자 | `공131` | `DIM_MEMBER.REGION` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · CRM 필드 | 후원기간(개월) | CRM | 날짜 | `공127` | `FACT_MEMBER_MONTHLY.SPONSOR_MONTHS` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · GA 필드 | event_category | GA | 문자 | `공99` | `DIM_GA_EVENT` |  | 지표사전 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · GA 필드 | event_label | GA | 문자 | `공100` | `DIM_GA_EVENT` |  | 지표사전 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · GA 필드 | event_action | GA | 문자 | `공101` | `DIM_GA_EVENT` |  | 지표사전 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · GA 필드 | 세션수 | GA | 숫자(회계) | `공97` | `FACT_GA_BEHAVIOR.SESSION_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · GA 필드 | 조회수 | GA | 숫자(회계) | `공96` | `FACT_GA_BEHAVIOR.VIEW_CNT` |  | 필드인벤토리~ |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · GA 필드 | 이벤트수 | GA | 숫자(회계) | `공95` | `FACT_GA_BEHAVIOR.EVENT_CNT` |  | 필드인벤토리~ |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · GA 필드 | 참여세션수 | GA | 숫자(회계) | `(215밖)` | `FACT_GA_BEHAVIOR.ENGAGED_SESSIONS` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · GA 필드 | 이탈률 | GA | 백분율 | `공108` | `FACT_GA_BEHAVIOR.BOUNCE_RATE` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · GA 필드 | 참여율 | GA | 백분율 | `(215밖)` | `FACT_GA_BEHAVIOR.ENGAGEMENT_RATE` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · GA 필드 | 평균세션시간 | GA | 시간(분,초) | `공98` | `FACT_GA_BEHAVIOR.AVG_SESSION_DURATION` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · GA 필드 | 세션당 평균 참여 시간 | GA | 시간(분,초) | `(215밖)` | `FACT_GA_BEHAVIOR.AVG_ENGAGEMENT_TIME_PER_SESSION` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · GA 필드 | 평균 세션 시간2 | GA | 시간(분,초) | `공98` | `FACT_GA_BEHAVIOR.AVG_SESSION_DURATION` |  | 필드인벤토리~ |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · GA 필드 | 세션당 평균 참여 시간2 | GA | 시간(분,초) | `(215밖)` | `FACT_GA_BEHAVIOR.AVG_ENGAGEMENT_TIME_PER_SESSION` |  | 필드인벤토리~ |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · GA 필드 | 방문수 | GA | 숫자(회계) | `공92` | `FACT_GA_BEHAVIOR.VISITS` |  | 필드인벤토리~ |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · GA 필드 | 세션캠페인 | GA | 문자 | `공102` | `FACT_GA_BEHAVIOR.CAMPAIGN_SK` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · GA 필드 | 세션 수동 광고 콘텐츠 | GA | 문자 | `공103` | `DIM_GA_SOURCE.UTM_CONTENT` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · GA 필드 | 세션 수동 검색어 | GA | 문자 | `공104` | `DIM_GA_SOURCE.UTM_TERM` |  | 필드인벤토리 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · GA 필드 | 페이지경로+쿼리문자열 | GA | URL(회원번호포함) | `공105` | `FGA(attr)` |  | 지표사전 |
| 3. 서비스 | 3-2. [회원] 증액마케팅보고 *월간기준 · GA 필드 | 페이지위치 | GA | URL(UTM, 회원번호숫자포함) | `공106` | `FACT_GA_BEHAVIOR.PAGE_LOCATION` |  | 필드인벤토리 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · CRM 필드 | 발송일 | CRM | 날짜 | `(215밖)` | `FACT_SERVICE_EVENT.DATE_SK` |  | 필드인벤토리 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · CRM 필드 | 발송구분(대) | CRM | 문자 | `공133` | `DIM_SERVICE.SEND_TYPE_L` |  | 필드인벤토리 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · CRM 필드 | 발송구분(중) | CRM | 문자 | `공134` | `DIM_SERVICE.SEND_TYPE_M` |  | 필드인벤토리 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · CRM 필드 | 발송구분(소) | CRM | 문자 | `공135` | `DIM_SERVICE.SEND_TYPE_S` |  | 필드인벤토리 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · CRM 필드 | 제목 | CRM | 문자 | `공136` | `FACT_SERVICE_EVENT.SEND_TITLE` |  | 필드인벤토리 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · CRM 필드 | 발송(명) | CRM | 문자 | `공85` | `FACT_SERVICE_EVENT.SEND_MEMBERS` |  | 필드인벤토리 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · CRM 필드 | 성공(명) | CRM | 숫자(회계) | `공86` | `FACT_SERVICE_EVENT.SUCCESS_MEMBERS` |  | 필드인벤토리~ |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · CRM 필드 | 실패(명) | CRM | 숫자(회계) | `공87` | `FACT_SERVICE_EVENT.FAIL_MEMBERS` |  | 필드인벤토리~ |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · CRM 필드 | 발송대비 성공율(%) | CRM | 백분율 | `(SV ratio)` | `SV metric — 대비(%) = 분자/분모 ×100 — 보고서 정의상 두 base 비율(분모는 보고서 문맥 확인)` |  | SV파생 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · CRM 필드 | 오픈(명) | CRM | 숫자(회계) | `(215밖)` | `FACT_SERVICE_EVENT.OPEN_MEMBERS` |  | 필드인벤토리 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · CRM 필드 | 발송성공대비 오픈율(%) | CRM | 백분율 | `(SV ratio)` | `SV metric — 대비(%) = 분자/분모 ×100 — 보고서 정의상 두 base 비율(분모는 보고서 문맥 확인)` |  | SV파생 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · CRM 필드 | 개발(명) | CRM | 숫자(회계) | `공148` | `FACT_MEMBER_MONTHLY.DEV_MEMBERS` |  | 필드인벤토리 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · CRM 필드 | 개발(건) | CRM | 숫자(회계) | `공4·5·149` | `FACT_MEMBER_MONTHLY.DEV_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · CRM 필드 | 발송성공대비 개발율(%) | CRM | 백분율 | `(SV ratio)` | `SV metric — 대비(%) = 분자/분모 ×100 — 보고서 정의상 두 base 비율(분모는 보고서 문맥 확인)` |  | SV파생 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · CRM 필드 | 회원번호 | CRM | 문자 | `공110` | `DIM_MEMBER_IDENTITY.MEMBER_NO` |  | 필드인벤토리 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · CRM 필드 | 브랜드 | CRM | 문자 | `공117` | `DIM_CAMPAIGN.BRAND` |  | 필드인벤토리 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · CRM 필드 | 상위캠페인 | CRM | 문자 | `공119` | `DIM_CAMPAIGN.PARENT_CAMPAIGN` |  | 필드인벤토리 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · CRM 필드 | 홍보방법 | CRM | 문자 | `공118` | `DIM_CAMPAIGN.PROMO_METHOD` |  | 필드인벤토리 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · CRM 필드 | 캠페인 | CRM | 문자 | `공18·120·147` | `DIM_CAMPAIGN.CAMPAIGN_NAME` |  | 필드인벤토리 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · CRM 필드 | 개발구분 | CRM | 문자 | `공121` | `FACT_MEMBER_MONTHLY.DEV_TYPE` |  | 필드인벤토리 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · CRM 필드 | 메일수신여부 | CRM(UMS) | 문자 | `(215밖)` | `FACT_SERVICE_EVENT.MAIL_RECEIVE_FLAG` |  | 필드인벤토리 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · GA 필드 | 세션수 | GA | 숫자+문자 | `공97` | `FACT_GA_BEHAVIOR.SESSION_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · GA 필드 | 평균 세션 시간 | GA | 문자 | `공98` | `FACT_GA_BEHAVIOR.AVG_SESSION_DURATION` |  | 필드인벤토리 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · GA 필드 | 이탈율 | GA | 숫자(회계) | `공108` | `FACT_GA_BEHAVIOR.BOUNCE_RATE` |  | 필드인벤토리 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · GA 필드 | 스크롤깊이 | GA | 숫자(회계) | `공107` | `FACT_GA_BEHAVIOR.SCROLL_DEPTH` |  | 필드인벤토리 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · GA 필드 | event_category | GA | 문자 | `공99` | `DIM_GA_EVENT` |  | 지표사전 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · GA 필드 | event_label | GA | 문자 | `공100` | `DIM_GA_EVENT` |  | 지표사전 |
| 3. 서비스 | 3-3. [회원] 개발메일결과보고 *일간기준 · GA 필드 | event_action | GA | 문자 | `공101` | `DIM_GA_EVENT` |  | 지표사전 |
| 3. 서비스 | 3-4. [회원] 미납중단안내서비스보고 *일간기준 · CRM 필드 | 발송일 | CRM | 날짜 | `(215밖)` | `FACT_SERVICE_EVENT.DATE_SK` |  | 필드인벤토리 |
| 3. 서비스 | 3-4. [회원] 미납중단안내서비스보고 *일간기준 · CRM 필드 | 발송구분(대) | CRM | 문자 | `공133` | `DIM_SERVICE.SEND_TYPE_L` |  | 필드인벤토리 |
| 3. 서비스 | 3-4. [회원] 미납중단안내서비스보고 *일간기준 · CRM 필드 | 발송구분(중) | CRM | 문자 | `공134` | `DIM_SERVICE.SEND_TYPE_M` |  | 필드인벤토리 |
| 3. 서비스 | 3-4. [회원] 미납중단안내서비스보고 *일간기준 · CRM 필드 | 발송구분(소) | CRM | 문자 | `공135` | `DIM_SERVICE.SEND_TYPE_S` |  | 필드인벤토리 |
| 3. 서비스 | 3-4. [회원] 미납중단안내서비스보고 *일간기준 · CRM 필드 | 제목 | CRM | 문자 | `공136` | `FACT_SERVICE_EVENT.SEND_TITLE` |  | 필드인벤토리 |
| 3. 서비스 | 3-4. [회원] 미납중단안내서비스보고 *일간기준 · CRM 필드 | 발송유형 | CRM | 문자 | `(215밖)` | `FACT_SERVICE_EVENT.SEND_TYPE` |  | 필드인벤토리 |
| 3. 서비스 | 3-4. [회원] 미납중단안내서비스보고 *일간기준 · CRM 필드 | 발송(명) | CRM | 숫자(회계) | `공85` | `FACT_SERVICE_EVENT.SEND_MEMBERS` |  | 필드인벤토리 |
| 3. 서비스 | 3-4. [회원] 미납중단안내서비스보고 *일간기준 · CRM 필드 | 성공(명) | CRM | 숫자(회계) | `공86` | `FACT_SERVICE_EVENT.SUCCESS_MEMBERS` |  | 필드인벤토리~ |
| 3. 서비스 | 3-4. [회원] 미납중단안내서비스보고 *일간기준 · CRM 필드 | 실패(명) | CRM | 숫자(회계) | `공87` | `FACT_SERVICE_EVENT.FAIL_MEMBERS` |  | 필드인벤토리~ |
| 3. 서비스 | 3-4. [회원] 미납중단안내서비스보고 *일간기준 · CRM 필드 | 발송대비 성공율(%) | CRM | 백분율 | `(SV ratio)` | `SV metric — 대비(%) = 분자/분모 ×100 — 보고서 정의상 두 base 비율(분모는 보고서 문맥 확인)` |  | SV파생 |
| 3. 서비스 | 3-4. [회원] 미납중단안내서비스보고 *일간기준 · CRM 필드 | 회원상태 | CRM | 문자 | `공132` | `DIM_MEMBER.MEMBER_STATUS` |  | 필드인벤토리 |
| 3. 서비스 | 3-4. [회원] 미납중단안내서비스보고 *일간기준 · CRM 필드 | 납입방식 | CRM | 문자 | `공125` | `DIM_PAYMENT.PAYMENT_METHOD` |  | 필드인벤토리 |
| 3. 서비스 | 3-4. [회원] 미납중단안내서비스보고 *일간기준 · CRM 필드 | 중단채널 | CRM | 문자 | `(215밖)` | `FACT_MEMBER_EVENT.STOP_CHANNEL` |  | 필드인벤토리 |
| 3. 서비스 | 3-4. [회원] 미납중단안내서비스보고 *일간기준 · GA 필드 | 세션캠페인 | GA | 숫자+문자 | `공102` | `FACT_GA_BEHAVIOR.CAMPAIGN_SK` |  | 필드인벤토리 |
| 3. 서비스 | 3-4. [회원] 미납중단안내서비스보고 *일간기준 · GA 필드 | 세션콘텐츠 | GA | 문자 | `공103` | `DIM_GA_SOURCE.UTM_CONTENT` |  | 필드인벤토리 |
| 3. 서비스 | 3-4. [회원] 미납중단안내서비스보고 *일간기준 · GA 필드 | 조회수 | GA | 숫자(회계) | `공96` | `FACT_GA_BEHAVIOR.VIEW_CNT` |  | 필드인벤토리~ |
| 3. 서비스 | 3-4. [회원] 미납중단안내서비스보고 *일간기준 · GA 필드 | 세션수 | GA | 숫자(회계) | `공97` | `FACT_GA_BEHAVIOR.SESSION_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 참여일 | CRM | 날짜 | `(215밖)` | `FACT_EVENT_PARTICIPATION.PART_PATH` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 정기후원금 | CRM | 숫자(회계) | `(215밖)` | `FACT_EVENT_PARTICIPATION.REGULAR_DONATION` |  | 필드인벤토리~ |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 정기후원금 *(중복)* | CRM | 숫자(회계) | `(215밖)` | `FACT_EVENT_PARTICIPATION.REGULAR_DONATION` |  | 필드인벤토리~ |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 총 참여수 | CRM | 숫자(회계) | `(215밖)` | `FACT_EVENT_PARTICIPATION.PARTICIPANT_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 이벤트 참여 횟수 - 전체 | CRM | 숫자(회계) | `(215밖)` | `FACT_EVENT_PARTICIPATION.PARTICIPATION_TIMES` | (전체 합계 · 축 없음) | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 이벤트 참여 횟수 - 전체 *(중복)* | CRM | 숫자(회계) | `(215밖)` | `FACT_EVENT_PARTICIPATION.PARTICIPATION_TIMES` | (전체 합계 · 축 없음) | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 이벤트명 | CRM | 문자 | `(215밖)` | `DIM_EVENT.EVENT_NAME` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 참여자수 | CRM | 숫자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.PARTICIPANT_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 이벤트 구분 | CRM | 문자 | `(215밖)` | `DIM_EVENT.EVENT_CATEGORY` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 이벤트 구분 *(중복)* | CRM | 문자 | `(215밖)` | `DIM_EVENT.EVENT_CATEGORY` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 참여경로 | CRM | 문자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.PART_PATH` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 참여경로 *(중복)* | CRM | 문자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.PART_PATH` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 참여채널 | CRM | 문자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.PART_CHANNEL` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 참여채널 *(중복)* | CRM | 문자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.PART_CHANNEL` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 당첨여부 | CRM | 문자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.WIN_FLAG` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 이벤트구분 | CRM | 문자 | `(215밖)` | `DIM_EVENT.EVENT_CATEGORY` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 이벤트명 *(중복)* | CRM | 문자 | `(215밖)` | `DIM_EVENT.EVENT_NAME` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 법인 | CRM | 문자 | `공114` | `DIM_ORG.CORP` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 회원번호 | CRM | 숫자 | `공110` | `DIM_MEMBER_IDENTITY.MEMBER_NO` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 연령 | CRM | 숫자 | `(215밖)` | `DIM_MEMBER.AGE_BAND` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 성별 | CRM | 문자 | `공130` | `DIM_MEMBER.GENDER` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 지역 | CRM | 문자 | `공131` | `DIM_MEMBER.REGION` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 최초캠페인 | CRM | 문자 | `공29` | `DIM_MEMBER.FIRST_CAMPAIGN` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 최근캠페인 | CRM | 문자 | `공31` | `DIM_MEMBER.LAST_CAMPAIGN` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 후원사업 | CRM | 문자 | `공123` | `DIM_SPONSORSHIP.SPONSORSHIP_NAME` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 회원상태 | CRM | 문자 | `공132` | `DIM_MEMBER.MEMBER_STATUS` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 최근참여일 | CRM | 날짜 | `(215밖)` | `DIM_DATE.FULL_DATE` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 참여 횟수 | CRM | 숫자(회계) | `(215밖)` | `FACT_EVENT_PARTICIPATION.PARTICIPATION_TIMES` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 후원금액 | CRM | 숫자(회계) | `—` | `(미매칭 — GOLD 물리·SV 대응 미확인)` |  |  |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 참여채널 *(중복)* | CRM | 문자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.PART_CHANNEL` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 참여경로 *(중복)* | CRM | 문자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.PART_PATH` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · CRM 필드 | 참여상태 | CRM | 문자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.PART_STATUS` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · GA 필드 | 세션수 | GA | 숫자(회계) | `공97` | `FACT_GA_BEHAVIOR.SESSION_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · GA 필드 | 이탈률 | GA | 숫자(회계) | `공108` | `FACT_GA_BEHAVIOR.BOUNCE_RATE` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · GA 필드 | 평균 세션시간 | GA | 숫자(회계) | `공98` | `FACT_GA_BEHAVIOR.AVG_SESSION_DURATION` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · GA 필드 | 세션캠페인 | GA | 문자 | `공102` | `FACT_GA_BEHAVIOR.CAMPAIGN_SK` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · GA 필드 | 세션수동콘텐츠 | GA | 문자 | `공103` | `DIM_GA_SOURCE.UTM_CONTENT` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · GA 필드 | 세션수동검색어 | GA | 문자 | `공104` | `DIM_GA_SOURCE.UTM_TERM` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · GA 필드 | 페이지경로 | GA | URL(회원번호포함) | `공105` | `FACT_GA_BEHAVIOR.PAGE_PATH` |  | 필드인벤토리~ |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · GA 필드 | 페이지위치 | GA | URL(UTM, 회원번호숫자포함) | `공106` | `FACT_GA_BEHAVIOR.PAGE_LOCATION` |  | 필드인벤토리 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · GA 필드 | event_category | GA | 문자 | `공99` | `DIM_GA_EVENT` |  | 지표사전 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · GA 필드 | event_label | GA | 문자 | `공100` | `DIM_GA_EVENT` |  | 지표사전 |
| 3. 서비스 | 3-5. [회원] 참여콘텐츠분석보고 (온라인이벤트) *일간기준 · GA 필드 | event_action | GA | 문자 | `공101` | `DIM_GA_EVENT` |  | 지표사전 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 행사구분 | CRM | 문자 | `(215밖)` | `DIM_EVENT.EVENT_CATEGORY` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 행사명 | CRM | 문자 | `(215밖)` | `DIM_EVENT.EVENT_NAME` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 행사기간 | CRM | 날짜 | `(215밖)` | `DIM_EVENT.EVENT_START_DATE` |  | 필드인벤토리~ |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 모집인원 | CRM | 숫자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.RECRUIT_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 총 인원 | CRM | 숫자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.TOTAL_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 대기인원 | CRM | 숫자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.WAIT_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 취소인원 | CRM | 숫자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.CANCEL_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 신청확정인원 | CRM | 숫자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.CONFIRM_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 참여인원 | CRM | 숫자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.PARTICIPATE_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 불참인원 | CRM | 숫자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.ABSENT_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 행사명 *(중복)* | CRM | 문자 | `(215밖)` | `DIM_EVENT.EVENT_NAME` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 신청일자 | CRM | 날짜 | `(215밖)` | `DIM_DATE.FULL_DATE` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 법인구분 | CRM | 문자 | `공114` | `DIM_ORG.CORP` |  | 필드인벤토리~ |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 회원번호 | CRM | 숫자 | `공110` | `DIM_MEMBER_IDENTITY.MEMBER_NO` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 회원상태 | CRM | 문자 | `공132` | `DIM_MEMBER.MEMBER_STATUS` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 참여상태 | CRM | 문자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.PART_STATUS` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 본인참여 | CRM | 문자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.SELF_PART_FLAG` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 후원사업명 | CRM | 문자 | `공123` | `DIM_SPONSORSHIP.SPONSORSHIP_NAME` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 후원금액 | CRM | 숫자(회계) | `—` | `(미매칭 — GOLD 물리·SV 대응 미확인)` |  |  |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 신청경로 | CRM | 문자 | `(215밖)` | `DIM_EVENT.APPLY_CHANNEL` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 성별 | CRM | 문자 | `공130` | `DIM_MEMBER.GENDER` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 연령 | CRM | 숫자 | `(215밖)` | `DIM_MEMBER.AGE_BAND` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 대기횟수 | CRM | 숫자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.WAIT_TIMES` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 불참횟수 | CRM | 숫자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.ABSENT_TIMES` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 참여횟수 | CRM | 숫자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.PARTICIPATION_TIMES` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 누적 신청 횟수 | CRM | 숫자 | `(215밖)` | `FACT_EVENT_PARTICIPATION.CUM_APPLY_TIMES` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 증액여부(Y/N) | CRM | 문자 | `공33` | `FACT_MEMBER_MONTHLY.INCREASE_FLAG` |  | 필드인벤토리~ |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · CRM 필드 | 조회수 | 어드민 > 이벤트목록 | 숫자(회계) | `공96` | `FACT_GA_BEHAVIOR.VIEW_CNT` |  | 필드인벤토리~ |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · GA 필드 | 세션수 | GA | 숫자(회계) | `공97` | `FACT_GA_BEHAVIOR.SESSION_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · GA 필드 | 참여 세션수 | GA | 숫자(회계) | `(215밖)` | `FACT_GA_BEHAVIOR.ENGAGED_SESSIONS` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · GA 필드 | 이탈률 | GA | 숫자(회계) | `공108` | `FACT_GA_BEHAVIOR.BOUNCE_RATE` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · GA 필드 | 평균 세션시간 | GA | 숫자(회계) | `공98` | `FACT_GA_BEHAVIOR.AVG_SESSION_DURATION` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · GA 필드 | 세션캠페인 | GA | 문자 | `공102` | `FACT_GA_BEHAVIOR.CAMPAIGN_SK` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · GA 필드 | 세션수동콘텐츠 | GA | 문자 | `공103` | `DIM_GA_SOURCE.UTM_CONTENT` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · GA 필드 | 세션수동검색어 | GA | 문자 | `공104` | `DIM_GA_SOURCE.UTM_TERM` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · GA 필드 | 세션 소스/매체 | GA | 문자 | `공109` | `DIM_GA_SOURCE.SOURCE_MEDIUM` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · GA 필드 | 페이지경로 | GA | URL(회원번호포함) | `공105` | `FACT_GA_BEHAVIOR.PAGE_PATH` |  | 필드인벤토리~ |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · GA 필드 | 페이지위치 | GA | URL(UTM, 회원번호숫자포함) | `공106` | `FACT_GA_BEHAVIOR.PAGE_LOCATION` |  | 필드인벤토리 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · GA 필드 | event_category | GA | 문자 | `공99` | `DIM_GA_EVENT` |  | 지표사전 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · GA 필드 | event_label | GA | 문자 | `공100` | `DIM_GA_EVENT` |  | 지표사전 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · GA 필드 | event_action | GA | 문자 | `공101` | `DIM_GA_EVENT` |  | 지표사전 |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · GA 필드 | 이벤트수 | GA | 문자 | `공95` | `FACT_GA_BEHAVIOR.EVENT_CNT` |  | 필드인벤토리~ |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · GA 필드 | 활성사용자 | GA | 문자 | `공93` | `FACT_GA_BEHAVIOR.ACTIVE_USERS` |  | 필드인벤토리~ |
| 3. 서비스 | 3-6. [회원] 참여콘텐츠분석보고 (문화이벤트) *일간기준 · GA 필드 | 총사용자 | GA | 문자 | `공94` | `FACT_GA_BEHAVIOR.TOTAL_USERS` |  | 필드인벤토리~ |
| 3. 서비스 | 3-7. [회원] 앱참여수치분석보고 *월간기준 | 홈페이지 ID | CRM | 문자 | `(215밖)` | `DIM_MEMBER_IDENTITY.HOMEPAGE_ID` |  | 필드인벤토리 |
| 3. 서비스 | 3-7. [회원] 앱참여수치분석보고 *월간기준 | 성별 | CRM | 문자 | `공130` | `DIM_MEMBER.GENDER` |  | 필드인벤토리 |
| 3. 서비스 | 3-7. [회원] 앱참여수치분석보고 *월간기준 | 연령대 | CRM | 숫자 | `(215밖)` | `DIM_MEMBER.AGE_BAND` |  | 필드인벤토리 |
| 3. 서비스 | 3-7. [회원] 앱참여수치분석보고 *월간기준 | 지역 | CRM | 문자 | `공131` | `DIM_MEMBER.REGION` |  | 필드인벤토리 |
| 3. 서비스 | 3-7. [회원] 앱참여수치분석보고 *월간기준 | 후원사업 | CRM | 문자 | `공123` | `DIM_SPONSORSHIP.SPONSORSHIP_NAME` |  | 필드인벤토리 |
| 3. 서비스 | 3-7. [회원] 앱참여수치분석보고 *월간기준 | 상위캠페인 | CRM | 문자 | `공119` | `DIM_CAMPAIGN.PARENT_CAMPAIGN` |  | 필드인벤토리 |
| 3. 서비스 | 3-7. [회원] 앱참여수치분석보고 *월간기준 | 가입캠페인 | CRM | 문자 | `공18·120·147` | `DIM_CAMPAIGN.CAMPAIGN_NAME` |  | 필드인벤토리 |
| 3. 서비스 | 3-7. [회원] 앱참여수치분석보고 *월간기준 | 후원금액 | CRM | 문자 | `—` | `(미매칭 — GOLD 물리·SV 대응 미확인)` |  |  |
| 3. 서비스 | 3-7. [회원] 앱참여수치분석보고 *월간기준 | event_category | GA | 문자 | `공99` | `DIM_GA_EVENT` |  | 지표사전 |
| 3. 서비스 | 3-7. [회원] 앱참여수치분석보고 *월간기준 | Event_action | GA | 문자 | `공101` | `DIM_GA_EVENT` |  | 지표사전 |
| 3. 서비스 | 3-7. [회원] 앱참여수치분석보고 *월간기준 | Event_label | GA | 문자 | `공100` | `DIM_GA_EVENT` |  | 지표사전 |
| 3. 서비스 | 3-7. [회원] 앱참여수치분석보고 *월간기준 | 세션 수 | GA | 숫자(회계) | `공97` | `FACT_GA_BEHAVIOR.SESSION_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-7. [회원] 앱참여수치분석보고 *월간기준 | 이벤트수 | GA | 숫자(회계) | `공95` | `FACT_GA_BEHAVIOR.EVENT_CNT` |  | 필드인벤토리~ |
| 3. 서비스 | 3-7. [회원] 앱참여수치분석보고 *월간기준 | 발송건수 | 어드민 > 모바일앱 > 푸시발송목록 | 숫자(회계) | `—` | `(미매칭 — GOLD 물리·SV 대응 미확인)` |  |  |
| 3. 서비스 | 3-7. [회원] 앱참여수치분석보고 *월간기준 | 성공건수 | 어드민 > 모바일앱 > 푸시발송목록 | 숫자(회계) | `—` | `(미매칭 — GOLD 물리·SV 대응 미확인)` |  |  |
| 3. 서비스 | 3-7. [회원] 앱참여수치분석보고 *월간기준 · 우측 GA 필드 | event_category | GA | 문자 | `공99` | `DIM_GA_EVENT` |  | 지표사전 |
| 3. 서비스 | 3-7. [회원] 앱참여수치분석보고 *월간기준 · 우측 GA 필드 | Event_action | GA | 문자 | `공101` | `DIM_GA_EVENT` |  | 지표사전 |
| 3. 서비스 | 3-7. [회원] 앱참여수치분석보고 *월간기준 · 우측 GA 필드 | Event_label | GA | 문자 | `공100` | `DIM_GA_EVENT` |  | 지표사전 |
| 3. 서비스 | 3-7. [회원] 앱참여수치분석보고 *월간기준 · 우측 GA 필드 | 세션 수 | GA | 숫자(회계) | `공97` | `FACT_GA_BEHAVIOR.SESSION_CNT` |  | 필드인벤토리 |
| 3. 서비스 | 3-7. [회원] 앱참여수치분석보고 *월간기준 · 우측 GA 필드 | 이벤트수 | GA | 숫자(회계) | `공95` | `FACT_GA_BEHAVIOR.EVENT_CNT` |  | 필드인벤토리~ |

---
_Co-authored with CoCo_