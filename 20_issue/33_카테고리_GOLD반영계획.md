<!-- LLM-METADATA
doc_id: ISSUE_33_CATEGORY_GOLD_PLAN
doc_role: BRONZE 카테고리성 컬럼 GOLD·SV 반영 계획·판정표(O262-B · 사용자 지시 「반영할 수 있는 데이터는 전부 GOLD·SV」)
project: GN_DW (굿네이버스)
created: 2026-10-25
created_by: O262-B
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

# 33. 카테고리 GOLD·SV 반영 계획 (O262-B)

> 계정 = UM80684(개발계) · 2026-10-25 · 분모 = O262 점검 96건(`tmp/o262_audit/O262_카테고리_GOLD미반영_점검.md`).
> 정밀측정 = 정확 COUNT DISTINCT·상위값·채움(`tmp/o262b/d_measure.json`) · 코드원장 = `TC_CMMN_DTL_CD` 전 그룹 도메인 대조(등급 = 31 등재부 규칙 · 완전포함 그룹 1개 = B · 다수 = C · 없음 = D).
> 🔴 라벨은 B·C 이고 의미가 맞을 때만 붙인다 · D 는 코드 raw 만(R2-7 라벨 창작 금지).

## 1. D군 49건 판정 (D 47 + C 재분류 REGIST_DEPT_CD 2)

| 원천 테이블 | 컬럼 | 고유 | 채움/전체 | 코드원장 | 판정 | 반영 대상 | 단계 | 근거 |
|---|---|---|---|---|---|---|---|---|
| DGT_AD_CMPGN_DTLS | `CMPGN_TYPE1_BSN_NM` | 4 | 224242/224242 | D - | 반영 | FACT_AD_PERFORMANCE·WIDE_AD_COMBINED 맨 끝 · SV 05_07 | 1 | 라벨 원값 4종(국내·해외·통합·전체) · SILVER staging 보유 |
| DGT_AD_CMPGN_DTLS | `CMPGN_TYPE2_BSN_NM` | 5 | 224242/224242 | D - | 반영 | FACT_AD_PERFORMANCE·WIDE_AD_COMBINED · SV 05_07 | 1 | 라벨 원값 5종(사례·사업·굿즈·기타·통합) |
| VIDEO_AD_CMPGN_DTLS | `CMPGN_TY_NM` | 6 | 14327/47838 | D - | 반영 | FACT_AD_PERFORMANCE·WIDE_AD_COMBINED · SV 05_07 | 1 | 라벨 원값 6종(해외 사례 등) · 채움 14,327/47,838(CTV 시트 외 NULL) |
| REBRDC_AD_CMPGN_DTLS | `CHNNL_NM` | 23 | 2190/2190 | D - | B 재분류 | 이미 FACT_AD_PERFORMANCE.MEDIA_CHANNEL_NM | - | AGENCY_AD_PERFORMANCE REBROADCAST 분기 clean_str(CHNNL_NM) |
| SND_MEMBER_LIST | `SPNSR_NM` | 58 | 5268903/11997090 | D - | B 재분류 | 이미 FACT_MESSAGE_DISPATCH.SND_SPNSR_NM(O213-E) | - | CRM_SEND_MEMBER:74 개명 |
| SND_MEMBER_LIST | `FRST_SPNSR` | 26 | 4808675/11997090 | D - | 반영 | CRM_SEND_MEMBER(SND 분기 · SND_ 접두) → FACT_MESSAGE_DISPATCH · SV 05_04 | 2 | 최초 후원사업명 26종 |
| SND_MEMBER_LIST | `CHILD_DTL_NM` | 11 | 726315/11997090 | D - | 반영 | CRM_SEND_MEMBER(SND 분기 · SND_ 접두) → FACT_MESSAGE_DISPATCH · SV 05_04 | 2 | 결연 상세상태 11종(결연중 등) |
| SND_MEMBER_LIST | `NATION_NM` | 27 | 738107/11997090 | D - | 반영 | CRM_SEND_MEMBER(SND 분기 · SND_ 접두) → FACT_MESSAGE_DISPATCH · SV 05_04 | 2 | 결연아동 국가 27종 |
| SND_MEMBER_LIST | `BPLC_KOR_NM` | 188 | 727431/11997090 | D - | 반영 | CRM_SEND_MEMBER(SND 분기 · SND_ 접두) → FACT_MESSAGE_DISPATCH · SV 05_04 | 2 | 결연아동 사업장 188종 |
| SND_MEMBER_LIST | `NEW_CHILD_PROJECT_COUNTRY` | 24 | 4981/11997090 | D - | B 재분류 | 이미 FACT_MESSAGE_DISPATCH.SND_CHILD_PROJECT_COUNTRY(O213-E) | - | CRM_SEND_MEMBER:76 개명 |
| SND_MEMBER_LIST | `SPNSR_CD` | 19 | 4808675/11997090 | C MM004 | 보류 | - | - | 🟠 코드군 C(MM004·MM011·MM294 경쟁) · 이름(SPNSR_NM)으로 대체 노출 |
| SND_MEMBER_LIST | `GENDER` | 18 | 5351009/11997090 | D - | 보류 | - | - | 🔴 코드·라벨 혼재(1·2·7·8 · 「국내(여자)」) — N-29 ⑤ 와 같은 class · 문서20 질문 추가 |
| SND_MEMBER_LIST | `CHILD_DTL_CD` | 1 | 653771/11997090 | C PM011 | 제외 | - | - | 단일값 `1` |
| SND_MEMBER_LIST | `SND_HOUR` | 18 | 11997090/11997090 | B MS049 | 제외 | - | - | 발송 시각 파생(일시 컬럼 존재) |
| SND_MEMBER_LIST | `SND_MIN` | 60 | 11997090/11997090 | D - | 제외 | - | - | 발송 분 |
| SND_MEMBER_MAIL_LINK_LOG | `LINK_PAGE` | 25 | 644/644 | D - | 제외 | - | - | URL |
| SND_REQ_MST | `ALT_SMS_YN` | 2 | 1564/2329 | B CM020 | B 재분류 | 이미 DIM_SEND_REQUEST.ALTRTV_MSG_SNDNG_YN | - | CRM_SEND_REQUEST UNION 위치(SND 분기 :106) |
| SND_REQ_MST | `CALL_NUMBER` | 1 | 1644/2329 | D - | 제외 | - | - | 단일값(대표번호) |
| SND_REQ_MST | `PERIODIC` | 2 | 12/2329 | C RM057 | 제외 | - | - | 채움 12/2,329 |
| SND_REQ_MST | `PERIODIC_WEEK` | 1 | 1/2329 | C PM038 | 제외 | - | - | 채움 1 |
| SND_REQ_MST | `SEND_MIN` | 60 | 2329/2329 | D - | 제외 | - | - | 발송 분 |
| SND_REQ_MST | `DIVIDE` | 4 | 171/2329 | D - | 제외 | - | - | 분할발송 건수 파라미터(수치) |
| SND_REQ_MST | `DIVIDE_UNIT` | 4 | 171/2329 | C CM021 | 제외 | - | - | 분할 간격 파라미터(수치) |
| SND_REQ_MST | `PAPER_YEAR` | 6 | 540/2329 | D - | 제외 | - | - | 연도 숫자(1990 등 이상치) |
| SND_REQ_MST | `EXTRA` | 1 | 1399/2329 | D - | 제외 | - | - | JSON 단일값 |
| SND_REQ_MST | `REG_NM` | 34 | 2152/2329 | D - | 제외 | - | - | 등록자 실명(PII) |
| TC_CMMN_DTL_CD | `CD_ATRB3` | 30 | 626/5916 | D - | 제외 | - | - | 코드사전 내부 속성(메타) |
| TD_MS_CRMN_PRTCPNT | `RQST_PATH_CD` | 6 | 170686/170914 | C RM300 | B 재분류 | 이미 FACT_EVENT_ATTENDANCE.PART_PATH(MS004) | - | CRM_EVENT_PARTICIPATION UNION 위치(:50 · 그룹 MS004) |
| TD_MS_MSG_AT_LQY_SNDNG | `DIVS_DTL_KEY` | 45 | 1260208/1260208 | D - | 제외 | - | - | 분할 상세 키 |
| TM_CM_MBER_DVLP_GOAL_DIV | `TEAM_NM` | 10 | 290/437 | D - | B 재분류 | 이미 FACT_TARGET_PROJECT.SRC_TEAM_NM | - | CRM_BIZ_TARGET.ORG_NM 개명 |
| TM_CM_MBER_DVLP_GOAL_DIV | `SPNSR_BSNS_DIV_NM` | 15 | 422/437 | D - | B 재분류 | 이미 FACT_TARGET_PROJECT.SRC_SPONSOR_BIZ_NM | - | CRM_BIZ_TARGET.SPONSOR_BIZ_NM 개명 |
| TM_CM_SCHDUL_MNG | `SCHDUL_CD` | 34 | 3928/4193 | B PM043 | 제외 | - | - | 휴일 일정코드 — 휴일명은 SCHDUL_TIT 로 DIM_DATE 노출(대체) |
| TM_CM_SPNSR_BSNS_INFO | `DNTN_TY_CD` | 2 | 50/50 | C RM303 | 반영 | DIM_SPONSORSHIP(코드 raw) · SV 05_10 | 1 | 2종(1·3) · 코드군 C ⇒ 라벨 없이 코드만 |
| TM_MM_FDRM_MBER_INFO | `PSTMTR_RECPTN_CD` | 23 | 1625961/1625974 | D - | B 재분류 | 이미 DIM_MEMBER PSTMTR_RECPTN(정규화) | - | CRM_MEMBER 정렬·중복제거 정규화 |
| TM_MM_FDRM_MBER_INFO | `EMAIL_RECPTN_CD` | 24 | 1625722/1625974 | D - | B 재분류 | 이미 DIM_MEMBER EMAIL_RECPTN(정규화) | - | 같음 |
| TM_MM_FDRM_MBER_INFO | `CTI_SYNCHRN_DIV_CD` | 2 | 1625973/1625974 | C RM057 | 제외 | - | - | CTI 시스템 동기화 플래그 |
| TM_MM_ONCE_MBER_INFO | `PSTMTR_RECPTN_YN` | 2 | 116664/177921 | B CM020 | B 재분류 | 이미 DIM_MEMBER PSTMTR_RECPTN(일시 분기 UNION) | - | CRM_MEMBER:75 |
| TM_MM_ONCE_MBER_INFO | `EMAIL_RECPTN_YN` | 2 | 116664/177921 | B CM020 | B 재분류 | 같음 | - | CRM_MEMBER:75 |
| TM_MM_ONCE_MBER_INFO | `CTI_SYNCHRN_DIV_CD` | 2 | 177921/177921 | C RM057 | 제외 | - | - | 시스템 플래그 |
| TM_MS_CRMN | `CRMN_DIV_CD` | 14 | 3686/3686 | C MS002 | B 재분류 | 이미 DIM_EVENT.EVENT_CATEGORY(캠페인행사 1~16 = MS002 · `_wide_schema.yml:988`) | - | CRM_EVENT UNION 2체계(일반행사 MS286 · 캠페인행사 MS002) |
| TM_MS_CRMN | `PROMO_CODE` | 11 | 13/3686 | D - | 제외 | - | - | 채움 13 · URL 혼재 |
| TM_MS_EMAIL_SNDNG | `EMAIL_RM` | 1 | 1/546420 | D - | 제외 | - | - | 채움 1(테스트) |
| TM_PM_MBRFEE_ACMSLT | `RQEST_SQNC` | 69 | 50061988/50061988 | D - | 제외 | - | - | 청구 차수(순번 수치) |
| TM_PM_MBRFEE_ACMSLT | `TOGETH_WTDRW_YN` | 2 | 50061988/50061988 | B CM020 | 보류 | - | - | 🟠 기존 제외 결정 `FACT_PAYMENT_BILLING_STATUS.sql:32` 「함께출금여부(운영 플래그)」 · 넣으면 grain 변경 ⇒ 데이터로 해소되는 사유 아님(함께출금 Y 39,401) |
| BDGT_ACMSLT_LEDGER | `BDGT_ITEM_NM` | 5 | 404/405 | D - | 제외 | - | - | 396/404 가 `0` 센티넬 |
| BDGT_ACMSLT_LEDGER | `VENDOR` | 7 | 404/405 | D - | 제외 | - | - | 거래처명 · `0` 센티넬 |
| EXPENSE_RESOLUTION | `BDGT_ITEM_NM` | 20 | 61785/111649 | D - | 반영 | FACT_EXPENSE_RESOLUTION · SV 05_23 | 1 | 예산항목명 20종 |
| TM_MM_FDRM_MBER_SPNSR_DSCNTC | `REGIST_DEPT_CD` | 54 | 965527/1077841 | D - | 반영 | FACT_MEMBER_EVENT(중단 분기 · 코드 raw) | 1 | 등록부서 54종 · 실적부서(ORG_SK)와 다른 축 |
| TM_MM_ONCE_MBER_INFO | `REGIST_DEPT_CD` | 77 | 172997/177921 | D - | 반영 | DIM_MEMBER(정기·일시 공통 · 코드 raw) | 1 | 등록부서 77종 · CRM_MEMBER 보유 |

- 집계 = 반영 11 · B 재분류 12 · 보류 3 · 제외 23
- 단계 1 = SILVER 보유 → GOLD 열 추가(맨 끝) · 단계 2 = SILVER 열 추가 → GOLD → SV

## 2. 반영 작업 단계

| 순 | 작업 | 정지점 |
|---|---|---|
| [1] | SILVER 모델·08 DDL(단계 2) · GOLD 모델·06_DDL·yml(맨 끝 append) | — |
| [2] | `44_DEPLOY_CATEGORY_GOLD.sql` [D1] SILVER·GOLD ADD COLUMN(소유자 GN_DW_ADMIN · 🔴 08·06 전체 재실행 금지) | 사용자 승인(2026-10-25) |
| [3] | 👤 dbt 재배포 + build(대상 모델 + 하류) | 👤 build |
| [4] | [D2] 대사 — 원천 고유값 = GOLD 고유값 · 행수 불변 · 채움 = 원천 채움 | 불일치 시 멈춤 |
| [5] | SV 차원 추가 → 배포 → 게이트(sv_common_block · sv_no_rollup · sv_code_label · sv_enum_newvalue) | rc=0 |
| [6] | 노출감사 LINEAGE_MAP 등록 · 문서실행순서 41~42 | — |

## 3. B군 기록 — GOLD 가 이미 개명·파생으로 노출(감사기 이름매칭 한계 · P13)

| 원천 테이블 | 컬럼 | GOLD 노출(모델:줄) | 용도 |
|---|---|---|---|
| SND_MEMBER_LIST | `SETLE_NM` | `DIM_PAYMENT.sql:24` SETTLE_METHOD | 결제수단 라벨(열 노출) |
| TD_MS_EVENT_PRTCPNT_DTL | `PRZWIN_CD` | `FACT_EVENT_ATTENDANCE.sql:71` WIN_FLAG | 당첨 여부 파생(NOT NULL) |
| TD_MS_EVENT_PRTCPNT_DTL | `PARTCPT_CHNNL_CD` | `FACT_EVENT_ATTENDANCE.sql:77` PART_CHANNEL | 열 노출(개명) |
| TD_MS_EVENT_PRTCPNT_DTL | `PARTCPT_PATH_CD` | `FACT_EVENT_ATTENDANCE.sql:76` PART_PATH | 열 노출(개명) |
| TM_CM_CMPGN_MNG | `UPPER_CMPGN_YN` | `DIM_CAMPAIGN.sql:83` IS_PARENT_CAMPAIGN_YN | 열 노출(개명) |
| TM_CM_CMPGN_MNG | `PR_MTH_CD` | `DIM_CAMPAIGN.sql:49` PROMO_METHOD(+라벨 PROMO_METHOD_NAME) | 열 노출(개명) |
| TM_CM_CMPGN_MNG | `MBER_INFLOW_PATH_CD` | `FACT_MEMBER_EVENT.sql:217` ·_AT_EVENT · `FACT_MEMBER_SPONSORSHIP_SPAN.sql:73` | 사건 시점 스냅샷(개명) |
| TM_CM_CMPGN_MNG | `CMPGN_TYPE1_BSN` | `FACT_MEMBER_EVENT.sql:221` · DIM_CAMPAIGN 라벨 DOMESTIC_OVERSEAS | 스냅샷 + 차원 라벨 |
| TM_CM_CMPGN_MNG | `CMPGN_TYPE2_BSN` | `FACT_MEMBER_EVENT.sql:223` · DIM_CAMPAIGN 라벨 BIZ_CASE_TYPE | 스냅샷 + 차원 라벨 |
| TM_CM_MBER_DVLP_GOAL | `STDYY` | `FACT_TARGET_MEMBER_DEV.sql:19` MONTH_KEY | 월키 파생(연+월) |
| TM_CM_MBER_DVLP_GOAL | `MBER_DVLP_DIV_CD` | `FACT_TARGET_MEMBER_DEV.sql:21` DEV_TYPE | 열 노출(개명) |
| TM_MM_FDRM_MBER_INFO | `SLRCLD_LRR_CD` | `DIM_MEMBER.sql:70` SLRCLD_LRR_NAME | CM029 라벨 조인 |
| TM_MS_EVENT | `EVENT_DIV_CD` | `DIM_EVENT.sql:29` EVENT_CATEGORY | 열 노출(개명) |
| TM_PM_INSTT_ACNUT | `ACNUT_DIV_CD` | `DIM_PAYMENT_ACCOUNT.sql:21` ACCOUNT_DIV_CD | 열 노출(개명) |
| BDGT_ACMSLT_LEDGER | `INCOME_EXPS_DIV_NM` | `DIM_BUDGET_ITEM.sql:24` BUDGET_CATEGORY | 열 노출(개명) |
| (C→B) SND_MEMBER_LIST | `SND_YN` | `CRM_SEND_MEMBER.sql:150` UNION 위치 → `FACT_MESSAGE_DISPATCH.sql:180` SEND_STATUS | 채널 상태 축A |
| (C→B) TD_MS_MSG_AT_SNDNG_DTLS | `TRNSMS_STAT_CD` | `CRM_SEND_MEMBER.sql:112` → SEND_STATUS(MS282) | 채널 상태 축A |
| (D→B) REBRDC_AD_CMPGN_DTLS | `CHNNL_NM` | `AGENCY_AD_PERFORMANCE` REBROADCAST → FACT MEDIA_CHANNEL_NM | 열 노출(개명) |
| (D→B) TM_CM_MBER_DVLP_GOAL_DIV | `TEAM_NM`·`SPNSR_BSNS_DIV_NM` | `FACT_TARGET_PROJECT.sql:53-54` SRC_TEAM_NM·SRC_SPONSOR_BIZ_NM | 열 노출(개명) |
| (D→B) TM_MM_FDRM/ONCE_MBER_INFO | `*_RECPTN_CD`·`*_RECPTN_YN` | `CRM_MEMBER.sql:33-36,75` 정규화 → DIM_MEMBER EMAIL_RECPTN·PSTMTR_RECPTN | 수신 동의 정규화 |

- 🟢 등록 = `scripts/run_bronze_audit_host.py` LINEAGE_MAP(O262-B 절) ⇒ 다음 감사부터 「노출됨(GOLD)」.

## 4. C군 13건 재검증 (보류 사유 원문 = `tmp/o262b/c_reasons_raw.txt`)

| 컬럼 | 기록 원문 요지(좌표) | 현재 실측 | 판정 |
|---|---|---|---|
| `TM_CM_CMPGN_MNG.CMPGN_TRGET_CD` | 「의미·코드군 확정 후 SV 차원 추가」(20-010:277) · SILVER 「라벨 미배선 — 수요 확인 후 별도」 | 도메인 10/10 ⊂ CM002 「캠페인대상」 · 라벨 35,860/35,860 · 중복 0 | 🟢 해소 → SILVER CMPGN_TRGET_NM · DIM_CAMPAIGN 2열 · SV 5종 반영 |
| `SND_MEMBER_LIST.SPNSR_TYPE` | 「숫자 코드의 뜻을 추정하지 않는다」(20-010:260) | `1` 242,021행 여전히 혼재 | 🟠 보류 유지 |
| `SND_YN` · `TRNSMS_STAT_CD` | 의미 확정(30-009:79 · 31:42) | GOLD SEND_STATUS 로 이미 도달 | B 재분류 |
| `TM_CM_DEPT_INFO.STATS_DEPT_LVL` | DEC-5 「미사용 확정」(20-002:12) | 채움 8/1,314 | ⚪ 제외 확정 유지 |
| `TM_RM_RELATNSP_GFTMNEY_INFO.EHGT` | Q11 「현업확정 — 불필요 → 미연동」(90-002:11) | — | ⚪ 제외 확정 유지 |
| `TM_PM_MBRFEE_ACMSLT.TRNSFER_RSN_CD` | DEC-17 문맥(30-001:108) | 단일값 `1` 87,750행 · 코드군 28개 그룹에 다 들어감(D) | 🟠 보류(코드군 미특정) |
| `TM_MS_CRMN.RM2` | 원천 `)` 오입력 사고(10-009:71) | 채움 14 · 비고 | ⚪ 제외(비고) |
| `SYNC_ERR_INFO.DATA_TYPE` ×2(AGENCY·ERP) | 기록 오매칭(ML DATA_TYPE 문단) | 동기화 오류 로그 16행 | ⚪ 제외(운영 로그) |
| `SND_MEMBER_MAIL_LINK_LOG.AGENT` | 기록 오매칭(Cortex Agent 문단) | 브라우저 에이전트 5종 · 644행 | ⚪ 제외(접속 메타) |
| `REGIST_DEPT_CD` ×2 | 기록 오매칭(명명 관례 문단 30-005:132) | GOLD 미도달(rc=1 두 축) | ➡️ D군 반영(§1) |

## 5. 진행 상태

- 🟢 [2026-10-25 · UM80684] 단계 1·2 코드 반영 → [D1] 18열 실재 → 👤 build → [D2] 대사 = GOLD 고유값·채움이 SILVER 와 정확 일치(광고 224,242·14,327 · 지출 61,785 · 기부유형 50 · 캠페인대상 35,860 · SND 4종·중단 등록부서 = SILVER 동일 · 원천과의 1~71행 차는 SILVER 기존 중복제거·필터) → SV 9종 배포(문서실행순서 41·42).
- 잔여 = 👤 운영계 반영(41·42) · 보류 3건(GENDER·SPNSR_CD·TOGETH_WTDRW_YN)과 C 보류 2건(SPNSR_TYPE·TRNSFER_RSN_CD)은 현업 회신 대기.

_Co-authored with CoCo_
