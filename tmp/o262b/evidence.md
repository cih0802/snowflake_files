# O262-B evidence — B·C·D 카테고리 GOLD·SV 반영 (UM80684 · 2026-10-25)

## E0 입력

- 분모 = `tmp/o262_audit/O262_카테고리_GOLD미반영_점검.md` 96건(A21·B15·C13·D47)
- 판정표 정본 = `20_issue/33_카테고리_GOLD반영계획.md`

## E1 B 15건 — GOLD 노출 좌표 실측 = `tmp/o262b/abc_raw.txt`(모델:줄 · 용도)

## E2 C 13건 — 보류 원문 = `tmp/o262b/c_reasons_raw.txt`

- CMPGN_TRGET_CD = 도메인 10/10 ⊂ CM002(「캠페인대상」 · 동일 크기 경쟁 그룹 존재 ⇒ 등급 C · 의미 일치로 라벨) · SILVER 조인 라벨 35,860/35,860 · CRM_CODE 중복 0
- SPNSR_TYPE = `1` 242,021 잔존 ⇒ 보류 · TRNSFER_RSN_CD = 단일값 `1` 87,750 · PM 28그룹 포함(D) ⇒ 보류
- SND_YN·TRNSMS_STAT_CD = `CRM_SEND_MEMBER` UNION → `FACT_MESSAGE_DISPATCH.SEND_STATUS` ⇒ B

## E3 D 49건 정밀측정 = `tmp/o262b/d_measure.json` · `d_measure.txt`(정확 COUNT DISTINCT · 상위 12 · TC_CMMN_DTL_CD 전 그룹 대조)

- 재분류 근거(모델 주석·UNION 위치 실측):
  - CRMN_DIV_CD → `_wide_schema.yml:988` EVENT_CATEGORY 캠페인행사 MS002
  - RQST_PATH_CD → `CRM_EVENT_PARTICIPATION.sql:50` PARTCPT_PATH_CD(MS004)
  - ALT_SMS_YN → `CRM_SEND_REQUEST.sql:106` ALTRTV_MSG_SNDNG_YN
  - SPNSR_NM·NEW_CHILD_PROJECT_COUNTRY → `CRM_SEND_MEMBER.sql:74,76` SND_ 접두(O213-E)
  - TOGETH_WTDRW_YN 보류 = `FACT_PAYMENT_BILLING_STATUS.sql:32` 기존 제외 결정(운영 플래그 · grain)
  - EXPENSE BDGT_ITEM_NM = 목·세목·세세목 일치 451/61,785 ⇒ 별도 축 반영

## E4 [D1] = `05_SV-Agent_ai/44_DEPLOY_CATEGORY_GOLD.sql` 21문장 성공 · INFORMATION_SCHEMA 18/18

## E5 [D2] 👤 build 후 (GOLD = SILVER 일치)

| 열 | 고유 | 채움 |
|---|---|---|
| DIM_CAMPAIGN.CAMPAIGN_TARGET_NAME | 10 | 35,860 |
| FAP.CMPGN_TYPE1_BSN_NM / TYPE2 / CMPGN_TY_NM | 4 / 5 / 6 | 224,242 / 224,242 / 14,327 |
| DIM_SPONSORSHIP.DNTN_TY_CD | 2 | 50 |
| FER.BDGT_ITEM_NM | 20 | 61,785 |
| DIM_MEMBER.REGIST_DEPT_CD | 365 | 1,798,970 |
| FME.REGIST_DEPT_CD(STOP) | 54 | 965,526 (= SILVER CRM_MEMBER_DISCONTINUE) |
| FMD.SND_FRST_SPNSR / CHILD_DTL / NATION / BPLC | 26 / 11 / 27 / 188 | 4,808,674 / 726,244 / 738,036 / 727,360 (= SILVER) |

- 원천 대비 1~71행 차 = SILVER 기존 QUALIFY(중복 제거)·키 필터 · 이번 변경 무관

## E6 SV = 9종 배포(05_01·02·04·07·10·19·23·24·25 · deploy_sv rc=0) · 스냅샷 `_archive/*.O262-B-o262bsvdim*`

## E7 노출감사 재생성(30_output_share · LINEAGE_MAP O262-B 절) = 노출됨(GOLD) 495 → 540 · SILVER까지만 378 → 337
