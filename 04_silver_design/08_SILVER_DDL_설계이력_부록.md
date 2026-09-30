# 08_SILVER_테이블DDL_20260714.sql — 설계·실측 이력 부록

> O192 에서 DDL 본문을 압축하며 **본문에서 뺀 주석을 원문 그대로** 옮긴 것이다(삭제 0).
> 🔴 여기 수치는 **그 시점 · 그 계정의 기록**이다 — 현재값으로 인용하지 마라(`R2-8-4`).
> 원본 전체 = `_archive/` 스냅샷(O192-A).

## 0. 파일 머리말(원문)

```sql
-- GN_DW SILVER 테이블 정의 DDL (STEP 1 스키마 + 39테이블 CREATE). 적재쿼리는 09 참조.
-- Co-authored with CoCo
/*
  GN_DW.SILVER — 47테이블 정의 DDL (테이블 구조 정본)
    구성: CRM 29 + ERP 3 + AGENCY 8 + GA4 6 + bridge 1 = 47.
    dbt SILVER 모델 47개와 1:1 대응(구조 소유주 = 이 파일, dbt 는 데이터만 갱신).
    ※ 2026-07-29 실측 대조 완료 — INFORMATION_SCHEMA 38테이블·전 컬럼 일치.
    🟢 [2026-08-19 O87] GA4 5 → 6 (`BIGQUERY_REFINED_DATA` 신설) ⇒ 총계 38 → **39**.
       ⚠️ 위 「2026-07-29 실측 38」은 그 시점 기록이고 **아직 39 로 재실측되지 않았다**
          (이 판본은 라이브에 미적용 · 적재 전 정지). 실측 갱신은 DDL 실행 후에 한다.
    🔄 [2026-08-21] `BIGQUERY_REFINED_DATA` 가 외부 Python 적재로 전환되며 평탄화만 남기고
       파생(EVENT_DT·EVENT_SEQ·ID_SCHEME·DEVICE_TYPE·UTM/XCHAN 등)을 잃었다 ⇒ 그 파생을
       되살리는 dbt 모델 `BIGQUERY_BASIC` 을 신설한다(GA4 5 → 6, 총계 39 → **40**).
       구조는 종전 커밋아웃된 `BIGQUERY_REFINED_DATA` DDL 을 계승하되 `SRC_TABLE`·
       `SRC_FILE_NAME`·`BRONZE_LOAD_TS`(외부 적재에 계보 없음)는 제거하고
       `GAC_*`(google_ads_campaign) 3컬럼을 추가한다. `EVENT_SEQ` 결정성은 미해결(`GA4-SEQ-1`).
    🟢 [2026-09-16 O162] CRM 원천 개편(BRONZE 46 → 50) 반영:
       CRM 22 → **26** (+`CRM_MKTNG_CODE`, +`CRM_SEND_MEMBER_OPEN_LOG`, +`CRM_SEND_MEMBER_LINK_LOG`, +`CRM_MEMBER_CONVERT_HIST`).
       총계 40 → **44** 테이블.
       · `CRM_CAMPAIGN` 에 `MKTG_CHANNEL` / `MKTG_CHANNEL_NM` 컬럼 추가.
       · `CRM_SEND_MEMBER` 의 `OPEN_DT` 는 `SND_MEMBER_OPEN_LOG` 에서 회원×발송별 MIN(OPEN_DT)로 축약 적재.
       · `CRM_MARKETING_CAMPAIGN` 은 `TC_MKTNG_DTL_CD` 의 C001 기반 호환 정제 유지.
  실행 순서: 08 먼저(테이블 생성) → 09(적재). CREATE OR REPLACE 로 안전 재실행.
  🔴🔴 [2026-09-29 O188] 「안전 재실행」은 **구조만** 안전하다 — 데이터는 **비워진다.**
     증분 모델(`materialized='incremental'`)은 테이블이 존재하면 `is_incremental()` 이 참이라
     **전량 적재 분기를 타지 않고 최근 창만** 채운다 ⇒ 재생성 직후 build 는 ERROR 0 인 채 거의 빈 테이블을 남긴다.
     실사고 = O182 가 이 파일을 전체 재실행 → GA4 체인 6테이블 + `FACT_BIGQUERY_BEHAVIOR` **0행**(O187-D 발견).
     ⇒ 이 파일을 재실행했으면 **반드시 대상 증분 모델을 백필**한다:
        · GA4 = `build --select BIGQUERY_BASIC+ --vars '{"bigquery_dt_ranges": [["2024-01-01", "9999-12-31"]]}'`
        · 그 밖 = `build --select <모델>+ --full-refresh` (🔴 full-refresh 는 dbt 가 테이블을 다시 만든다 ⇒ 이 파일 COMMENT 재적용 확인)
     판정 = 재실행 전후 `COUNT(*)`·`COUNT(DISTINCT 일자)` 대사(원천 대비).
  ⚠️ 발송 2테이블(CRM_SEND_REQUEST·CRM_SEND_MEMBER)의 복합 PK 전환은 09 상단 ALTER 로 수행 —
     본 파일 CREATE 는 단일 PK 상태다(멱등 로드 흐름 유지). 이 파일만 실행하면 PK 미완성.
  🔴 [2026-08-19 O87] **GA4 4테이블은 이미 라이브에 존재하고 그중 BIGQUERY_EVENT 에 행이 있다.**
     실측 = 계정 `UA93987` · 2026-08-19 · `SILVER.BIGQUERY_EVENT` **8,161,106행**(정본 = 원장 §O87).
     🔴 이 수치는 **계정·시점에 종속**이다(`R2-8-4`) — 계정이 바뀌면 재실측할 것(`P169` 3회 발생).
     `CREATE OR REPLACE` 는 그것을 지운다. GA4 구간을 재실행할 때는 그 사실을 먼저 확인할 것
     (그 행은 dbt 를 우회해 09번 SQL 로 적재된 것이고 구 DEVICE_TYPE 로직(else 'PC')
      기준이라 `smart tv` 가 `PC` 로 오분류돼 있다 ⇒ **재적재 대상이며 보존 가치가 없다**).

  ▣ 본 파일의 범위 = 구조 계약(타입·PK·COMMENT)만. 설계근거·실측이력·리뷰기록은 이관됨:
      CRM        → 03_SILVER_작업계획_CRM전용 20260714.md
      ERP        → 05_SILVER_작업계획_ERP전용 20260714.md §6
      AGENCY     → 06_SILVER_작업계획_AGENCY전용 20260714.md §6
      GA4        → 07_GA4_SILVER_샤드통합 설계결정.md §7
      S-7 브리지 → 02_SILVER_작업계획_BRONZE-GOLD연결 20260714.md §6
    이슈·결정 ID(Q*/--O*/AD-*/DEC-*/E-*/P*) 원장 = 20_issue/00_INDEX_이슈원장.md
-- */
-- ============================================================================
-- STEP 1 — 스키마 생성
-- ============================================================================
;
/*
EXECUTE IMMEDIATE $$
DECLARE
    c1 CURSOR FOR 
        SELECT table_name, table_type 
        FROM GN_DW.INFORMATION_SCHEMA.TABLES 
        WHERE table_schema = 'SILVER'
          AND table_name != 'BIGQUERY_REFINED_DATA'; -- 예외 대상 제외
BEGIN
    FOR record IN c1 DO
        IF (record.table_type = 'BASE TABLE') THEN
            EXECUTE IMMEDIATE 'DROP TABLE GN_DW.SILVER.' || record.table_name;
        ELSEIF (record.table_type = 'VIEW') THEN
            EXECUTE IMMEDIATE 'DROP VIEW GN_DW.SILVER.' || record.table_name;
        END IF;
    END FOR;
    RETURN 'GN_DW.SILVER cleaned successfully (BIGQUERY_REFINED_DATA excluded).';
END;
$$;
*/
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE DATABASE GN_DW;
CREATE SCHEMA IF NOT EXISTS GN_DW.SILVER
    WITH MANAGED ACCESS
    COMMENT = 'Silver 레이어 — Bronze(CRM·BIGQUERY·ERP·AGENCY) 정제/변환 객체 (GOLD 입력용)';

USE SCHEMA GN_DW.SILVER;

-- ============================================================================
-- STEP 2 — CRM 22테이블
-- ============================================================================

-- CRM 1: CRM_MEMBER (회원 통합 — 정기 ∪ 일시)
--   [컬럼별 설계 및 실측 이력]
--   · SEX: 성별 원천코드 raw(정본 CM013) — BRONZE TM_MM_FDRM_MBER_INFO/ONCE_MBER_INFO.SEX 무변환. 1국내남·2국내여·3외국남·4외국여·5외국기타·6단체·7기업·8기타. ⚠️[O26] 종전 M/F/U 축약을 폐기했다 — 정본 비고가 '성별만으로는 사용하지는 않음'을 경고했고 축약이 원천 8종을 3종으로 파괴했다. 라벨=S
--     EX_NM
--   · SEX_NM: CM013 라벨 그대로(국내(남자)/외국인(여자)/단체/기업 등 8종). USE_YN 무필터 조인. [O26 신설]
--   · MBER_STAT_CD: 회원상태코드 원천 raw (정본 MM010): 1활동회원·2~6신규미납1~5·7~11장기미납1~5·12후원중단. 라벨 미배선(GOLD DIM_MEMBER.MEMBER_STATUS_NAME 이 보유). ⚠️미납 판정은 PAY_STAT_CD(DEC-3) 소관 — 이 컬럼과 혼용 금지
--   · EMAIL_STAT_CD: 이메일상태 코드 raw (정본 MM009). ONCE 원천 부재 → NULL
--   · ETC_CTTPC_REL_CD: 기타연락처 관계 코드 raw (정본 MM008). ⚠️사전 심각 불완전(활성 3 vs 원천 distinct 14) → 라벨 불가·현업 사전보완 대기. ONCE 부재 → NULL
--   · ETC_CTTPC_STAT_CD: 기타연락처 상태 코드 raw (정본 MM008). ONCE 부재 → NULL
--   · ETC_TSTM_DIV_CD: 기타 증서구분 코드 raw (정본 MS026). 원천 타입 NUMBER → TO_VARCHAR 정규화. FDRM∪ONCE 양쪽 존재
--   · MOBLPHON_STAT_CD: 휴대폰상태 코드 raw (정본 MM008). ONCE 부재 → NULL
--   · REL_CD: 관계 코드 raw (정본 CM009). ONCE 전용 — FDRM 부재 → NULL
--   · RELATNSP_DIV_CD: 결연구분 코드 raw (정본 MM019). ONCE 부재 → NULL
--   · SLRCLD_LRR_CD: 급여공제 코드 raw (정본 CM029). ⚠️폐지코드 사용중(활성2·폐지1) → 라벨 조인시 USE_YN 무필터 필수. ONCE 부재 → NULL
--   · TSTM_DIV_CD: 증서구분 코드 raw (정본 MS026). 원천 타입 NUMBER → TO_VARCHAR 정규화. FDRM∪ONCE 양쪽 존재
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## CRM_MEMBER

```text
    -- [2026-08-03 G3/O25] 정본 코드컬럼 raw 전파 (ALTER TABLE ADD COLUMN 으로 물리 반영 — 위치는 맨 끝).
```

## CRM_MEMBER_STATUS_HIST

```text
-- CRM 2: CRM_MEMBER_STATUS_HIST (회원 상태전이 · SCD2)
--   [컬럼별 설계 및 실측 이력]
--   · EFFECTIVE_FROM: SCD2 유효시작 시각
--   · EFFECTIVE_TO: SCD2 유효종료 시각
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## CRM_MEMBER_DEV

```text
-- CRM 3: CRM_MEMBER_DEV (개발약정)
--   [컬럼별 설계 및 실측 이력]
--   · DVLP_DIV_CD: 개발구분코드 (정본 MM015: 1신규 2증액 3감액 4재후원 5후원중단). 라벨=DVLP_DIV_NM. 🔴 MM015(개발구분) ≠ MM010(회원상태) — 두 그룹 모두 '후원중단'을 포함해 혼동되기 쉽다. 회원상태는 CRM_MEMBER.MBER_STAT_CD(MM010)
--   · DVLP_DIV_NM: 개발구분명 — 정본 MM015 라벨(1신규/2증액/3감액/4재후원/5후원중단). CRM_CODE 빌드시점 조인. 컬럼명은 정본 컬럼정의서 504행 현업 용어쌍 (O24)
--   · CANCL_RDCAMT_RSN_CD: 취소·감액사유 코드 raw (정본 MM002). ⚠️31종 중 18종이 폐지코드 → 라벨 조인시 USE_YN 무필터 필수
--   · MBER_DIV_CD: 회원구분 코드 raw (정본 MM018). 라벨 미배선
--   · SEX: 성별 코드 raw (정본 CM013). ✅[O26] CRM_MEMBER.SEX 도 CM013 raw 로 복원되어 동명이의 해소 — 비교·UNION 가능(종전 'M/F/U 정규화값이라 금지' 경고 폐기)
--   · SPNSR_AMT_CD: 후원금액구분 코드 raw (정본 CM012). 금액 원값은 SPNSR_AMT
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
--   · MBER_INFLOW_PATH_CD: 개발인입경로코드 (MM293). 라벨=MBER_INFLOW_PATH_NM. CRM_CAMPAIGN 비정규화
--   · MBER_INFLOW_PATH_NM: 개발인입경로명 (MM293 라벨). CRM_CAMPAIGN 비정규화
--   · CMPGN_CTGR_CD: 캠페인 카테고리코드 (MM294). 라벨=CMPGN_CTGR_NM. CRM_CAMPAIGN 비정규화
--   · CMPGN_CTGR_NM: 캠페인 카테고리명 (MM294 라벨). CRM_CAMPAIGN 비정규화
--   · CMPGN_TYPE1_BSN: 캠페인 유형1 코드 (MM295) = 국내/통합/해외 축. 라벨=CMPGN_TYPE1_NM. CRM_CAMPAIGN 비정규화
--   · CMPGN_TYPE1_NM: 캠페인 유형1명 (MM295 라벨): 국내 / 통합 / 해외. CRM_CAMPAIGN 비정규화
--   · CMPGN_TYPE2_BSN: 캠페인 유형2 코드 (MM296) = 굿즈/기타/사례/사업 축. 라벨=CMPGN_TYPE2_NM. CRM_CAMPAIGN 비정규화
--   · CMPGN_TYPE2_NM: 캠페인 유형2명 (MM296 라벨): 굿즈 / 기타 / 사례 / 사업. CRM_CAMPAIGN 비정규화
--   · MKTG_CMPGN_NM: 마케팅캠페인 코드 (※_NM 접미이나 실제는 FK→TM_CM_MKTNG_CMPGN_MNG.MK_CMPGN_CD). CRM_CAMPAIGN 비정규화
--   · MK_CMPGN_NM: 마케팅 캠페인명 (라벨, Q16 해소). CRM_CAMPAIGN 비정규화
--   · CMMN_BRND: MM297 공통브랜드 코드. CRM_CAMPAIGN 비정규화
--   · CMMN_BRND_NM: MM297 공통브랜드명. CRM_CAMPAIGN 비정규화
--   · MKTG_UTM: TM_CM_MKTNG_UTM 코드. CRM_CAMPAIGN 비정규화
--   · MKTG_UTM_NM: TM_CM_MKTNG_UTM 라벨. CRM_CAMPAIGN 비정규화
--   · SPNSR_DIV_CD: 후원구분 코드 raw (정본 CM035). CRM_CAMPAIGN 비정규화
--   · CPR_DIV_CD: 법인구분 코드 raw (정본 CM019: I=사단/S=사복/A=통합). CRM_CAMPAIGN 비정규화
--   · PARENT_CAMPAIGN_NAME: 상위캠페인명(UPPER_CMPGN_CD 자기조인 라벨). CRM_CAMPAIGN 비정규화
--   · PROMO_METHOD_NAME: 홍보방법명 (CM008 라벨). CRM_CAMPAIGN 비정규화
--   · SRC_LOAD_DT: 원천(BRONZE) 적재시각 워터마크 — incremental merge 필터 기준값 (2026-08-25 증분 전략)
    -- [2026-08-03 G3/O25] 정본 코드컬럼 raw 전파 (ALTER TABLE ADD COLUMN 으로 물리 반영 — 위치는 맨 끝).,
    -- [2026-09-16 O162] 마케팅채널(C002) — CRM_CAMPAIGN 비정규화
    -- [DEC-43 2026-08-25] 캠페인 SV 3종 스냅샷 동결 잔여 3속성(BRND_NM 은 종전 "미사용" 결정을 뒤집는다).,
    -- [2026-08-25 안내1/안내2] 캠페인 비정규화 18컬럼 + 증분 워터마크(ALTER TABLE ADD COLUMN 으로 물리 반영 — 위치는 맨 끝).
    --   CRM_CAMPAIGN 조인 결과를 그대로 승계한다(컬럼명 1:1 동일 — 아래 CRM_CAMPAIGN 정의 참조).,
```

## CRM_MEMBER_AMT_CHANGE

```text
-- CRM 4: CRM_MEMBER_AMT_CHANGE (증감)
--   [컬럼별 설계 및 실측 이력]
--   · MBER_DIV_CD: 회원구분 코드 raw (정본 MM018: 1개인/2기업/3단체). 라벨 미배선
--   · SETLE_CD: 결제수단 코드 raw (정본 PM040). 라벨 미배선
--   · SEX: 성별 코드 raw (정본 CM013). ✅[O26] CRM_MEMBER.SEX 도 CM013 raw 로 복원되어 동명이의 해소 — 비교·UNION 가능(종전 'M/F/U 정규화값이라 금지' 경고 폐기)
--   · SPNSR_AMT_CD: 후원금액구분 코드 raw (정본 CM012). 금액 원값은 SPNSR_AMT
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
    -- [2026-08-03 G3/O25] 정본 코드컬럼 raw 전파 (ALTER TABLE ADD COLUMN 으로 물리 반영 — 위치는 맨 끝).
```

## CRM_MEMBER_DISCONTINUE

```text
-- CRM 5: CRM_MEMBER_DISCONTINUE (중단)
--   [컬럼별 설계 및 실측 이력]
--   · DSCNTC_PATH_NM: 중단경로명 — MM287 라벨(1=SYSTEM/2=CRM/3=홈페이지). 코드는 DSCNTC_PATH. USE_YN 무필터 조인 (O25)
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
    -- [2026-08-03 G3/O25] 정본 코드컬럼 raw 전파 (ALTER TABLE ADD COLUMN 으로 물리 반영 — 위치는 맨 끝).,
```

## CRM_MEMBER_RESPONSOR

```text
-- CRM 6: CRM_MEMBER_RESPONSOR (재후원)
--   [컬럼별 설계 및 실측 이력]
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## CRM_MEMBER_SPONSOR_BIZ

```text
-- CRM 7: CRM_MEMBER_SPONSOR_BIZ (회원×후원사업)
--   [컬럼별 설계 및 실측 이력]
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## CRM_SPONSOR_RELATION

```text
-- CRM 8: CRM_SPONSOR_RELATION (결연)
--   [컬럼별 설계 및 실측 이력]
--   · RELATNSP_DSCNTC_YN: 결연 중단여부. ⚠️값은 Y/N 이 아니라 0/1 — 현업 정의서 명시 "0=후원중;1=후원중단". 실측 1=667,278(전건 중단일 보유)/0=195,332(전건 미보유). ★'Y' 로 필터하면 전건 0 반환(O20 교정 2026-07-31)
--   · RELATNSP_DSCNTC_RSN_CD: 결연중단사유 코드 raw (정본 MM002). 원천 타입 NUMBER → TO_VARCHAR 정규화. ⚠️30종 중 16종 폐지코드 → 라벨 조인시 USE_YN 무필터 필수
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
    -- [2026-08-03 G3/O25] 정본 코드컬럼 raw 전파 (ALTER TABLE ADD COLUMN 으로 물리 반영 — 위치는 맨 끝).
```

## CRM_PAYMENT_BILLING

```text
-- CRM 9: CRM_PAYMENT_BILLING (납입·청구)
--   [컬럼별 설계 및 실측 이력]
--   · PAY_STAT_CD: 납입상태코드. ★미납 판정축(DEC-3): 미납 = F OR NULL. 판정은 이 컬럼 단독
--   · SETLE_CD: 결제수단코드. ★RQEST_RST_CD 코드그룹 결정자(W1/DEC-17) — 단독 조인 금지
--   · RQEST_RST_CD: 청구결과코드(PG 결과). ★사유축. 실측 101종·채움 99.67%·최대길이 28. ⚠️PG사별 이종 네임스페이스 → 코드 단독 조인 금지('01'=41개·'02'=43개·'03'=36개 코드그룹에 동시 존재, SETLE_CD=1 실패/=8 성공으로 의미 상반). 조인키 = (코드그룹, 코드) 복합. 코드그룹 = SETLE_CD+자릿수: 1&2자리→PM0
--     02 / 1&4자리→PM032 / 2→PM018 / 12→PM033 / 5→PM019. ★★REASON_SK 배선은 미납(PAY_STAT_CD='F') 행에 한정 — 성공행에 매핑하면 라벨이 반대로 붙는다(SETLE_CD=8, 1,374행). F 한정 시 의미 모순 0 검증. 기부금 branch 는 원천 컬럼 부재로 NULL
--   · PRCS_RST_CD: 처리결과코드. ⚠️PAY_STAT_CD 의 거울 컬럼 — 실측 F↔F 6,262,245 / S↔S 39,805,846, 불일치 179,052행(0.386%), 사유 분해력 없음(7종). ★미납 판정·사유 분해에 사용 금지. 원천 보존·감사 목적. 기부금 branch 는 원천 컬럼 부재로 NULL
--   · CPR_DIV_CD: 법인구분 코드 raw (정본 CM019). 회비∪기부금 양쪽 존재
--   · MBER_DIV_CD: 회원구분 코드 raw (정본 MM018). 회비 전용 — 기부금 부재 → NULL
--   · MBRFEE_DIV_CD: 회비구분 코드 raw (정본 PM010). 회비 전용 → 기부금 NULL
--   · OPERT_DIV_CD: 작업구분 코드 raw (정본 MM014). 회비 전용 → 기부금 NULL
--   · MBRFEE_PRCS_STAT_CD: 처리상태 코드 raw (정본 PM013). 🔴회비 전용 — 기부금 원천에도 동명 컬럼이 있으나 정본이 코드그룹 미지정이라 O16형 의미혼입 방지를 위해 NULL 유지. 미납 판정은 PAY_STAT_CD(DEC-3) 불변. [O26] MBRFEE_ 접두 = 원천 테이블 TM_PM_MBRFEE_ACMSLT 변별토큰 — CRM_SEND_REQUEST.PSTMTR
--     _PRCS_STAT_CD(MS061)와 동명이의였다. BRONZE 실측 도메인 완전 분리: 여기 R 144,028·S 46,247,143·F 449 vs PSTMTR 0/1 (2026-08-04 재확인)
--   · RETUN_RSN_CD: 반환사유 코드 raw (정본 PM042). 회비∪기부금 양쪽 존재
--   · RQEST_DIV_CD: 청구구분 코드 raw (정본 PM024). 회비 전용 → 기부금 NULL
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
    -- W1(DEC-17, 2026-07-31): 결제결과코드 2종 추가. ★사유축 전용 — 미납 판정은 DEC-3(PAY_STAT_CD) 불변.
    --   기존 테이블에는 ALTER TABLE ADD COLUMN 으로 반영 → 물리 컬럼 위치는 맨 끝(공통감사 뒤).
    --   신규 재생성 시에는 이 위치. dbt append 는 컬럼명 기준 INSERT 라 순서 무관(동작 영향 없음).
    -- [2026-08-03 G3/O25] 정본 코드컬럼 raw 전파 (ALTER TABLE ADD COLUMN 으로 물리 반영 — 위치는 맨 끝).
```

## CRM_PAYMENT_METHOD

```text
-- CRM 10: CRM_PAYMENT_METHOD (결제수단)
--   [컬럼별 설계 및 실측 이력]
--   · APPLCNT_MBER_REL_CD: 신청자-회원 관계 코드 raw (정본 CM009)
--   · CPR_DIV_CD: 법인구분 코드 raw (정본 CM019)
--   · CRTFC_MTH_CD: 인증방법 코드 raw (정본 MM014)
--   · FNLT_DIV_CD: 금융기관구분 코드 raw (정본 PM050). 기관코드 원값은 FNLT_CD
--   · RCEPT_DIV_CD: 접수구분 코드 raw (정본 PM003)
--   · RQST_DIV_CD: 요청구분 코드 raw (정본 PM004)
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
    -- [2026-08-03 G3/O25] 정본 코드컬럼 raw 전파 (ALTER TABLE ADD COLUMN 으로 물리 반영 — 위치는 맨 끝).
```

## CRM_CAMPAIGN

```text
-- CRM 11: CRM_CAMPAIGN (캠페인 마스터)
--   [2026-07-16 BRONZE 재입고] 캠페인 분류 5컬럼이 원천에서 채워짐(33,915/36,143 = 93.8%) →
--     코드→라벨 병행보존(master §3) 적용. Q2·Q3(캠페인 라벨)·Q16(마케팅캠페인 연결) 해소.
--   코드군: 카테고리=MM294(56) · 인입경로=MM293(16) · 유형1=MM295(3) · 유형2=MM296(4)
--   ⚠️ 유형1/유형2 의미 주의 — 유형1=국내/통합/해외, 유형2=굿즈/기타/사례/사업. 혼동 금지.
--   ⚠️ 고아 코드(코드사전 미등재, 라벨 NULL로 남김): CMPGN_CTGR_CD=58(23행) · CMPGN_TYPE1_BSN=4(740행)
--   [컬럼별 설계 및 실측 이력]
--   · CMPGN_CTGR_CD: 캠페인 카테고리코드 (MM294). 라벨=CMPGN_CTGR_NM
--   · CMPGN_CTGR_NM: 캠페인 카테고리명 (MM294 라벨). 예: 국내사례캠페인·굿즈캠페인·해외캠페인
--   · MBER_INFLOW_PATH_CD: 개발인입경로코드 (MM293). 라벨=MBER_INFLOW_PATH_NM
--   · MBER_INFLOW_PATH_NM: 개발인입경로명 (MM293 라벨). 예: 디지털·방송·영상광고·지역개발·마케팅콜개발
--   · CMPGN_TYPE1_BSN: 캠페인 유형1 코드 (MM295) = 국내/통합/해외 축. 라벨=CMPGN_TYPE1_NM
--   · CMPGN_TYPE1_NM: 캠페인 유형1명 (MM295 라벨): 국내 / 통합 / 해외
--   · CMPGN_TYPE2_BSN: 캠페인 유형2 코드 (MM296) = 굿즈/기타/사례/사업 축. 라벨=CMPGN_TYPE2_NM
--   · CMPGN_TYPE2_NM: 캠페인 유형2명 (MM296 라벨): 굿즈 / 기타 / 사례 / 사업
--   · MKTG_CMPGN_NM: 마케팅캠페인 코드 (※_NM 접미이나 실제는 FK→TM_CM_MKTNG_CMPGN_MNG.MK_CMPGN_CD, 323종·고아 0)
--   · CMPGN_TRGET_CD: 캠페인대상 코드 raw — TM_CM_CMPGN_MNG.CMPGN_TRGET_CD (정본 CM002). 라벨 미배선
--   · CPR_DIV_CD: 법인구분 코드 raw — TM_CM_CMPGN_MNG.CPR_DIV_CD (정본 CM019: I=사단/S=사복/A=통합). 라벨=CPR_DIV_NM
--   · SPNSR_DIV_CD: 후원구분 코드 raw — TM_CM_CMPGN_MNG.SPNSR_DIV_CD (정본 CM035). 라벨=SPNSR_DIV_NM
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
--   · CMMN_BRND: MM297 공통브랜드 코드. 라벨=CMMN_BRND_NM
--   · MKTG_UTM: TM_CM_MKTNG_UTM 코드. 라벨=MKTG_UTM_NM
--   · MKTG_CHANNEL: 마케팅 채널 코드 — TM_CM_CMPGN_MNG.MKTG_CHANNEL · TC_MKTNG_DTL_CD C002 대응.
--     2026-09-16(O162) CRM 원천 개편 시 신규. 라벨=MKTG_CHANNEL_NM
--   · PROMO_METHOD_NAME: 홍보방법명 — PR_MTH_CD 라벨(CM008, 구 GOLD DIM_CAMPAIGN §O37 로직 이관)
--   · PARENT_CAMPAIGN_NAME: 상위캠페인명 — UPPER_CMPGN_CD 자기조인 라벨(구 GOLD DIM_CAMPAIGN §O37 로직 이관)
    -- [DEC-43 2026-08-25] 캠페인 SV 3종 스냅샷 동결 잔여 2속성(BRND_NM 은 위 327행에 이미 존재).,
    -- [2026-08-03 G3/O25] 정본 코드컬럼 raw 전파 (ALTER TABLE ADD COLUMN 으로 물리 반영 — 위치는 맨 끝).,
    -- [라벨 배선 완료분] CPR_DIV_CD·SPNSR_DIV_CD 라벨 + MM297 공통브랜드 + UTM (ALTER TABLE ADD COLUMN 으로 물리 반영 — 위치는 맨 끝).,
```

## CRM_SPONSORSHIP

```text
-- CRM 12: CRM_SPONSORSHIP (후원사업 마스터)
--   [컬럼별 설계 및 실측 이력]
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## CRM_ORG

```text
-- CRM 13: CRM_ORG (조직 마스터)
--   [컬럼별 설계 및 실측 이력]
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
LAST_UPDT_DT:-- 🆕 O189 편입(ALTER ADD · 라이브 ordinal 말미)
```

## CRM_DEV_TARGET

```text
-- CRM 14: CRM_DEV_TARGET (개발목표)
--   [컬럼별 설계 및 실측 이력]
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## CRM_SEND_REQUEST

```text
-- CRM 15: CRM_SEND_REQUEST (발송요청)
--   [컬럼별 설계 및 실측 이력]
--   · MSG_DIV_CD: 메시지구분 코드 raw (정본 MS010). MSG_AT 채널 전용 — 그 외 채널은 개념 부재로 NULL
--   · PSTMTR_PRCS_STAT_CD: 처리상태 코드 raw (정본 MS061). PSTMTR 채널 전용 — 그 외 NULL. [O26] PSTMTR_ 접두 = 원천 테이블 TM_MS_PSTMTR_SNDNG 변별토큰 — CRM_PAYMENT_BILLING.MBRFEE_PRCS_STAT_CD(PM013)와 동명이의였다. BRONZE 실측 도메인 완전 분리: 여기 0=170·1=3,631 vs MB
--     RFEE R/S/F (2026-08-04 재확인)
--   · SNDNG_TIME_DIV_CD: 발송시간구분 코드 raw (정본 MS267). MSG_AT 채널 전용 — 그 외 NULL
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
    -- [2026-08-03 G3/O25] 정본 코드컬럼 raw 전파 (ALTER TABLE ADD COLUMN 으로 물리 반영 — 위치는 맨 끝).
```

## CRM_SEND_MEMBER

```text
-- CRM 16: CRM_SEND_MEMBER (발송×회원)
--   [컬럼별 설계 및 실측 이력]
--   · SNDNG_RST_CD: 발송결과코드 (축A raw · 🔴채널별 다체계 — SEND_CHANNEL 또는 SEND_STATUS_GROUP 동반 필수)
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
--   · SEND_STATUS_GROUP: 축A 코드군 ID (조인키 · MSG_AT=MS282). 🟢운영서버 코드사전 대조로 확정(2026-08-11 · 등급 C→B) — 종전 「정황 등급」 표기는 해소됐다. EMAIL·SND·PSTMTR 은 NULL
--   · SEND_STATUS_NAME: 축A 라벨 (CRM_CODE 조인). 🔴EMAIL·SND 는 사전에 라벨 문자열이 없어 **의도적 NULL**(문서30 §23-J 결정 3 · 현업 §M-4) · PSTMTR 은 원천 부재
--   · SEND_RESULT_CD: 축B(신설) 통신사 결과코드 raw — MSG_AT=TRNSMS_FAILR_CD_ID · SND=CALL_STATUS. 🟢두 채널이 같은 코드공간을 공유(conformed)
--   · SEND_RESULT_GROUP: 축B 코드군 ID = MS283 이 정의한 4종(MS056 공통·MS057 알림톡·MS058 SMS·MS059 MMS). 🟢리터럴이 아니라 조인 결과에서 얻는다 — 4그룹 코드값 중복 0(실측)
--   · SEND_RESULT_NAME: 축B 라벨 (CRM_CODE 조인). 사전 초과값은 NULL 유지 + warn 관측(DEC-17-B)
--   · OPEN_DT: 오픈시각 — 🔴 **SND 채널만 존재**한다(원천 SND_MEMBER_LIST.OPEN_DT · 원천에서도 ALTER 로 나중에 붙은 컬럼). EMAIL·MSG_AT·PSTMTR 은 원천에 오픈 컬럼이 없어 NULL 이다. ⚠️ NULL 의 뜻이 두 가지다: ㉠ 채널이 SND 가 아니다 ㉡ SND 이지만 측정 개시 이전 발송이다(= 미측정, 「열지 않았다
--     」가 아니다). 오픈율 분모는 관측 구간의 SND 발송으로 한정할 것.
    -- [2026-08-11 O59-N · DEC-35 1단계] 코드→라벨 계층화. 매핑 = 문서31 · 결정 = 문서30 §23-J.
    --   🔴 **선언 위치가 감사컬럼 뒤인 것은 의도다**(이 파일의 확립된 규약 · 06_DDL.sql:298 과 동일 근거) —
    --      라이브에는 `ALTER TABLE ADD COLUMN` 으로 추가되어 물리 ordinal 이 맨 끝이 된다. 감사컬럼 앞에 적으면
    --      신규 환경 재구축 시 컬럼 순서가 라이브와 달라진다.
    -- [2026-08-20 O93 · 2026-09-16 O162 개정] 오픈시각 — GOLD.FACT_MESSAGE_DISPATCH.OPEN_MEMBERS 의 유일 원천.
    --   🔴 2026-09-15 원천 SND_MEMBER_LIST.OPEN_DT 삭제로 인해 신규 BRONZE SND_MEMBER_OPEN_LOG 에서
    --      회원×발송별 MIN(OPEN_DT) 로 축약 적재되어 상위 인터페이스를 보존한다.
FRST_BRND_CD:-- 🆕 O189 편입(ALTER ADD · 라이브 ordinal 말미)
```

## CRM_SEND_RESULT

```text
-- CRM 17: CRM_SEND_RESULT (발송×채널 집계)
--   [컬럼별 설계 및 실측 이력]
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## CRM_EVENT

```text
-- CRM 18: CRM_EVENT (행사 마스터)
--   [컬럼별 설계 및 실측 이력]
--   · EVENT_DIV_CD: 행사구분코드 (raw · 🔴원천별 다체계 — EVENT_SOURCE 동반 필수)
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
--   · EVENT_DIV_GROUP: 행사구분 코드군 ID (EVENT=MS286 · CRMN=MS002 · 등급 B 배타 확정)
--   · EVENT_DIV_NM: 행사구분 라벨 (CRM_CODE 조인 · 두 체계 겹침 0)
    -- [2026-08-11 O59-N · DEC-35 1단계] 코드→라벨 계층화. 매핑 = 문서31 · 결정 = 문서30 §23-J.
    --   🔴 **선언 위치가 감사컬럼 뒤인 것은 의도다**(이 파일의 확립된 규약 · 06_DDL.sql:298 과 동일 근거) —
    --      라이브에는 `ALTER TABLE ADD COLUMN` 으로 추가되어 물리 ordinal 이 맨 끝이 된다. 감사컬럼 앞에 적으면
    --      신규 환경 재구축 시 컬럼 순서가 라이브와 달라진다.
```

## CRM_EVENT_PARTICIPATION

```text
-- CRM 19: CRM_EVENT_PARTICIPATION (행사×참여자)
--   [컬럼별 설계 및 실측 이력]
--   · PARTCPT_STAT_CD: 참여상태코드 (raw · 🔴원천별 2체계 O28 — EVENT_KEY 접두 또는 PARTCPT_STAT_GROUP 동반 필수)
--   · PARTCPT_CHNNL_CD: 참여채널코드 (raw · EVENT 전용 — CRMN 은 원천 컬럼 부재)
--   · PARTCPT_PATH_CD: 참여경로코드 (raw · CRMN 원천 컬럼명은 RQST_PATH_CD 신청경로)
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
--   · PARTCPT_STAT_GROUP: 참여상태 코드군 ID (EVENT=MS304 · CRMN=MS006). 🔴두 원천의 「참여」 정의가 다르다 — 합산 금지
--   · PARTCPT_STAT_NM: 참여상태 라벨 (CRM_CODE 조인). ⚠️EVENT 계열은 사전 라벨이 **영문**(Success·1_step_right…)이며 현업 한글 표기 회신 대기(문서20 §M-1) — 창작하지 않았다
--   · PARTCPT_CHNNL_GROUP: 참여채널 코드군 ID (EVENT=MS302 · 등급 B 배타 확정 — 근거·규모는 문서31 §3). CRMN 은 원천 컬럼 부재로 NULL
--   · PARTCPT_PATH_GROUP: 참여경로 코드군 ID (EVENT=MS303 · CRMN=MS004). 🟢운영서버 코드사전 대조로 확정(2026-08-11 · 등급 C→B)
    -- [2026-08-11 O59-N · DEC-35 1단계] 코드→라벨 계층화. 매핑 = 문서31 · 결정 = 문서30 §23-J.
    --   🔴 **선언 위치가 감사컬럼 뒤인 것은 의도다**(이 파일의 확립된 규약 · 06_DDL.sql:298 과 동일 근거) —
    --      라이브에는 `ALTER TABLE ADD COLUMN` 으로 추가되어 물리 ordinal 이 맨 끝이 된다. 감사컬럼 앞에 적으면
    --      신규 환경 재구축 시 컬럼 순서가 라이브와 달라진다.
```

## CRM_RELATION_ACTIVITY

```text
-- CRM 20: CRM_RELATION_ACTIVITY (결연활동 · EHGT 제외)
--   [컬럼별 설계 및 실측 이력]
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## CRM_CODE

```text
-- CRM 21: CRM_CODE (코드 사전)
--   [컬럼별 설계 및 실측 이력]
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## CRM_MKTNG_CODE

```text
-- CRM 22: CRM_MKTNG_CODE (마케팅 통합 코드 사전 — 2026-09-16 O162 신설)
--   [설계 및 실측 이력]
--   · 원천: BRONZE_CRM.TC_MKTNG_DTL_CD (16컬럼). TM_CM_MKTNG_CMPGN_MNG · TM_CM_MKTNG_UTM 통합분.
--   · 🔴 기존 코드 테이블(TC_CMMN_CD/TC_CMMN_DTL_CD)과 연관성 없는 별개 네임스페이스.
--   · CD_ID 현재 3종 = C001(마케팅캠페인명) · C002(채널) · U001(UTM). 향후 마케팅 코드도 여기에 증분.
```

## CRM_SEND_MEMBER_OPEN_LOG

```text
-- CRM 23: CRM_SEND_MEMBER_OPEN_LOG (메일 오픈 로그 — 2026-09-16 O162 신설)
--   [설계 및 실측 이력]
--   · 원천: BRONZE_CRM.SND_MEMBER_OPEN_LOG (8컬럼).
--   · 구 SND_MEMBER_LIST.OPEN_DT 가 확장된 오픈 세부 로그.
```

## CRM_SEND_MEMBER_LINK_LOG

```text
-- CRM 24: CRM_SEND_MEMBER_LINK_LOG (메일 링크 클릭 로그 — 2026-09-16 O162 신설)
--   [설계 및 실측 이력]
--   · 원천: BRONZE_CRM.SND_MEMBER_MAIL_LINK_LOG (13컬럼).
```

## CRM_MEMBER_CONVERT_HIST

```text
-- CRM 25: CRM_MEMBER_CONVERT_HIST (일시→정기 회원 전환 매핑 — 2026-09-16 O162 신설)
--   [설계 및 실측 이력]
--   · 원천: BRONZE_CRM.TM_MM_FDRM_MBER_DT_DTLS (5컬럼).
--   · ⚠️ 회비이관 시에만 기록되는 부분집합 매핑.
```

## CRM_MEMBER_SPONSOR_SPAN

```text
-- CRM 24: CRM_MEMBER_SPONSOR_SPAN (회원×후원사업 활동구간)  [2026-08-20 O93 신설]
--   🔴 존재 이유 = 정본 #51「월말활동회원」의 **as-of 판정**에 구간이 필요한데 기존 모델에는 없었다:
--      CRM_MEMBER_SPONSOR_BIZ 는 MBER_NO·시작일이 없고(키가 SPNSR_NO), CRM_MEMBER_STATUS_HIST 는
--      회원 커버리지가 부분이다. 후원 마스터(TM_MM_FDRM_MBER_SPNSR)를 붙여 두 축을 얻는다.
--   [컬럼별 설계 및 실측 이력]
--   · MBER_NO: 회원번호 — 후원 마스터에서 얻는다(후원사업 테이블에는 없다).
--   · SPNSR_BSNS_NO: 후원사업번호 (PK). 🟢재후원 시 **새 번호가 발급**되므로 「재후원 넘버링 > 중단 넘버링」 조건이 이 축에 이미 반영돼 있다(정본 #51 비고의 tie-break 가 불필요해지는 이유). ⚠️채번의 시간 단조성은 초기 구간에서 성립하지 않는다 — tie-break 를 쓰는 설계라면 그 구간에서 작동하지 않는다. 구간 경계와 규모는 20_issue/3
--     0_설계_의사결정 §13-D 2 를 보라(R2-6: 수치는 문서에만).
--   · SPNSR_AMT: 후원사업 약정금액 원단위. 🟢정본 #52 활동회원(건) = 활동 사업의 이 금액 합 / 10,000.
--   · START_MONTH_KEY: 활동 개시 월키 YYYYMM. ⚠️**후원(SPNSR_NO) 등록월의 근사**다 — 원천에 후원사업 단위 시작일이 없다. 같은 후원 아래 사업이 나중에 추가되면 시작을 실제보다 이르게 본다(활동 과대 방향). 사업 단위 시작일이 입고되면 교체할 자리.
--   · DSCNTC_MONTH_KEY: 중단 월키 YYYYMM. 🔴 NULL = **미중단**(현재까지 활동)이며 결측이 아니다 — 중단 기록의 부재가 곧 「중단하지 않았다」는 정보다. 이 성질 덕분에 활동 판정에 커버리지 공백이 없다.
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
JOIN_PATH_CD:-- 🆕 O189 편입(ALTER ADD · 라이브 ordinal 말미)
CMPGN_CD:-- 🆕 O189-B 2차-B
```

## CRM_BIZ_TARGET

```text
-- CRM 22: CRM_BIZ_TARGET (사업목표 — ⛔ 입고 대기)
--   [컬럼별 설계 및 실측 이력]
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
    -- 🆕 [2026-09-29 O188] 원천 `BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV` 입고 → 원천 축 보존(선언 위치 = 감사컬럼 뒤 · ALTER ADD 규약).
    --   🔴 GOAL_TYPE_NM 은 이중계상 가드다 — 「연사업」·「팀」 두 유형의 12개월 합이 348,024 · 348,000 으로 거의 같다
    --      (같은 목표의 다른 분해로 추정 · 문서20 N-24 ① 회신 대기) ⇒ **유형을 섞어 합산하지 말 것**.
    -- 🆕 [2026-09-30 O190] 원천 정의 갱신(2026-09-29) 반영 — ALTER ADD 규약(말미) · 하단 O190 절 참조.
```

## CRM_MARKETING_CAMPAIGN

```text
-- ############################################################################
-- [2026-08-06 O45 · 2026-09-16 O162 개정] SILVER 마케팅캠페인 마스터
-- ----------------------------------------------------------------------------
-- Q16 「MKTG_CMPGN_NM 전건 NULL」 오진 철회의 산물. 실측: 브리지 조인 100% 해소 ·
-- AGENCY 광고 캠페인명과 이름 일치 76/105(72.4%) → 광고행 89.7% 도달.
-- 🔴 2026-09-15 원천 TM_CM_MKTNG_CMPGN_MNG 가 삭제되고 TC_MKTNG_DTL_CD 로 통합됨.
--    dbt 모델에서는 TC_MKTNG_DTL_CD (CD_ID='C001') 필터링으로 재정의되어 상위 호환성 유지.
-- 실행 스크립트 정본 = 03_top-down_gold/O45_ASSEMBLY_AXES.sql §1
-- ############################################################################
--   [컬럼별 설계 및 실측 이력]
--   · MK_CMPGN_CD: PK. 마케팅캠페인 코드 (TC_MKTNG_DTL_CD DTL_CD_ID 대응)
--   · MK_CMPGN_NM: 마케팅캠페인명 (TC_MKTNG_DTL_CD DTL_CD_NM 대응)
--   · USE_YN: 사용여부(원천 그대로 — 폐지분도 과거 실적에 붙으므로 제외하지 않는다)
```

## CRM_CAMPAIGN_SPONSOR_BIZ_BRIDGE

```text
-- ############################################################################
-- [2026-09-09 O151] 신규 SILVER 브릿지 테이블 — DEC-45 캠페인 ↔ 후원사업 브릿지
-- ----------------------------------------------------------------------------
-- CRM_CAMPAIGN.SPNSR_BSNS_ID 쉼표 다중값 1:N 정규화 브릿지.
-- ############################################################################
```

## CRM_BIZ_PLACE

```text
-- ============================================================================
-- 🆕 [2026-09-29 O189] O188-A~F 모델 변경분 DDL 정본 편입 (dbt 선행 절차 ①② 누락 시정)
--   🔴 경위: O188 은 모델만 고치고 08_SILVER DDL을 갱신하지 않았다 ⇒ GN_DW_DBT 가
--      ㉠ 신규 테이블 CTAS(CREATE TABLE 권한 없음) ㉡ on_schema_change ALTER ADD COLUMN(MODIFY 없음)
--      에서 거부됐고, **pre-hook TRUNCATE 는 먼저 성공**해 기존 테이블이 0행으로 남았다(2026-09-29 00:21 build).
--   🟢 실행 주체 = GN_DW_ADMIN. 기존 테이블은 ALTER(데이터 보존) · 신규는 CREATE OR REPLACE(현재 미존재).
--   🟢 타입 정본 = 모델 렌더 결과(상류 TEMP 그림자 + DESCRIBE · O189 임시 계측 · 삭제됨) — 타입 불일치 ALTER 재발 방지(O121).
--   🟢 재검증 = `python3 scripts/table_ddl_column_gate.py`(DDL 없는 모델도 blocking 으로 잡는다 · O189 수리).
--   ⚠️ COMMENT 1차본 = BRONZE 원천 COMMENT 상속(출처 표기) · 파생 컬럼은 「모델 파생」 표기 — 문안 보강은 후속.
-- ============================================================================
-- SILVER.CRM_ORG — 기존 테이블 컬럼 증설 (ordinal 말미 · 데이터 보존)
-- SILVER.CRM_SEND_MEMBER — 기존 테이블 컬럼 증설 (ordinal 말미 · 데이터 보존)
-- SILVER.CRM_MEMBER_SPONSOR_SPAN — 기존 테이블 컬럼 증설 (ordinal 말미 · 데이터 보존)
-- 🆕 [2026-09-29 O189-B · 2차-B 1단] 후원 마스터 누락 컬럼 2종(문서32 §3 `TM_MM_FDRM_MBER_SPNSR`) — DDL 선행 · ADMIN 적용 후 모델
-- 🆕 [2026-09-30 O190] 원천 정의 갱신 하류 반영 — `TM_CM_MBER_DVLP_GOAL_DIV.BDGT_PRCD_NM`('예산절차')
--   실측(bt97381) = 값 1종 '연사업' 438행 · ERP 같은 축 어휘 = 연사업 / 추가경정 ⇒ 편성 차수(당초/추경) 축으로 판정.
--   ⇒ TARGET_TYPE = 연사업→'당초' · 추가경정→'추경' 파생 · DK 해시에 포함(추경 입고 시 키 충돌 방지).
-- 🆕 [2026-09-30 O191-E · 2차-B 2단 1묶음] 단일원천 SILVER 5종 누락 컬럼 21개(문서32 §3) — DDL 선행 · ADMIN 적용 · 모델 후행
--   🔴 제외 = 개인정보(결제자명·연락처·카드유효기간·빌키·인증데이터·인증파일) · 감사일시/등록자 · 파일 메타 · 이미 배선된 컬럼
-- SILVER CRM_BIZ_PLACE — O188-F 2차-A 신설 · 원천 = BRONZE_CRM.TM_RM_BPLC_MNG
```

## CRM_CHILD

```text
-- SILVER CRM_CHILD — O188-F 2차-A 신설 · 원천 = BRONZE_CRM.TM_RM_CHILD_MSTR_INFO
```

## CRM_CODE_GROUP

```text
-- SILVER CRM_CODE_GROUP — O188-F 2차-A 신설 · 원천 = BRONZE_CRM.TC_CMMN_CD
```

## CRM_INSTT_ACCOUNT

```text
-- SILVER CRM_INSTT_ACCOUNT — O188-F 2차-A 신설 · 원천 = BRONZE_CRM.TM_PM_INSTT_ACNUT
```

## CRM_MSG_TEMPLATE

```text
-- SILVER CRM_MSG_TEMPLATE — O188-F 2차-A 신설 · 원천 = BRONZE_CRM.TM_MS_AT_TMPLAT_MNG
```

## CRM_MSG_TEMPLATE_BUTTON

```text
-- SILVER CRM_MSG_TEMPLATE_BUTTON — O188-F 2차-A 신설 · 원천 = BRONZE_CRM.TD_MS_AT_TMPLAT_BTN_LIST
```

## CRM_PAYMENT_METHOD_HIST

```text
-- SILVER CRM_PAYMENT_METHOD_HIST — O188-F 2차-A 신설 · 원천 = BRONZE_CRM.TH_PM_SETLE_INFO_HIST
```

## CRM_RELATION_CHANGE

```text
-- SILVER CRM_RELATION_CHANGE — O188-F 2차-A 신설 · 원천 = BRONZE_CRM.TM_RM_RELATNSP_CHG_INFO
```

## CRM_RELATION_DEV

```text
-- SILVER CRM_RELATION_DEV — O188-F 2차-A 신설 · 원천 = BRONZE_CRM.TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT
```

## CRM_SETLE_CMPNY_ACCOUNT

```text
-- SILVER CRM_SETLE_CMPNY_ACCOUNT — O188-F 2차-A 신설 · 원천 = BRONZE_CRM.TM_PM_SETLE_CMPNY_ACNT
```

## ERP_BUDGET_ITEM

```text
-- ============================================================================
-- STEP 3 — ERP 2테이블 + CRM_BIZ_TARGET (원천=CRM, E-6 입고대기)
-- ============================================================================
-- ERP 1: ERP_BUDGET_ITEM (예산과목 마스터)
--   [컬럼별 설계 및 실측 이력]
--   · BUDGET_ITEM_DK: MD5 해시 대체키 (PK) = MD5(연도|수입지출|예산단위|장|관|항|목|세목|세세목|재원)
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## ERP_BUDGET

```text
-- ERP 2: ERP_BUDGET (월별 편성/추경/조정/집행)
--   [컬럼별 설계 및 실측 이력]
--   · BUDGET_ITEM_DK: 예산과목 대체키 (PK, →ERP_BUDGET_ITEM)
--   · BUDGET_PROCEDURE: 예산 편성 차수 (연사업 / 추가경정 · DEC-44)
--   · DVLP_INBOUND_PATH: 개발 유입경로 (원천 DVLP_INBOUND_PATH 승계). 실측 8종
--   · BDGT_UNIT_NM: 예산단위명 (원천 BDGT_UNIT_NM 승계). 실측 6종
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
    -- 🆕 [2026-09-30 O190] E-1 선배선(판정 중립 · 현업 회신 전 · 문서20 -009) — ALTER ADD 규약(말미)
```

## ERP_BUDGET_YEARLY

```text
-- ERP 3: ERP_BUDGET_YEARLY (예산 연 총액)  [2026-08-20 O93 신설]
--   🔴 왜 ERP_BUDGET 에 합치지 않았나 = grain 이 다르다. 그쪽은 월 grain(원장 1행 → 12행)이라
--      연 총액을 넣으면 12벌로 복제되고 SUM 이 12배가 된다. 원장은 연 총액과 월별 12벌을 **한 행에** 담는다.
--   [컬럼별 설계 및 실측 이력]
--   · BUDGET_ITEM_DK: 예산과목 대체키 (PK, →ERP_BUDGET_ITEM). 🟢 ERP_BUDGET·ERP_BUDGET_ITEM 과 **동일 MD5 산식** — 식을 바꿀 때 세 곳을 함께 바꿔야 한다.
--   · BUDGET_YEAR: 예산연도 YYYY (PK). 본 테이블의 grain 은 **연**이다.
--   · BUDGET_PROCEDURE: 예산 편성 차수 (연사업 / 추가경정 · DEC-44)
--   · YEAR_BDGT_TOT_AMT: 연 편성예산 총액 원단위 = 원천 YEAR_BDGT_TOT_AMT
--   · CHN_BDGT_TOT_AMT: 연 추경예산 총액 원단위 = 원천 CHN_BDGT_TOT_AMT
--   · ADJ_BDGT_TOT_AMT: 연 조정예산 총액 원단위 = 원천 ADJ_BDGT_TOT_AMT. ⚠️편성보다 클 수 있다(추경·전용 반영).
--   · EXEC_TOT_AMT: 연 집행 총액 원단위 = 원천 EXEC_TOT_AMT. ⚠️ERP_BUDGET 의 월 집행 12개월 합과 반드시 일치하지 않는다 — 원천이 두 값을 따로 관리한다. 불일치는 원천 상태이므로 맞추지 말 것.
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## AGENCY_AD_CREATIVE

```text
-- ============================================================================
-- STEP 4 — AGENCY 8테이블 (코어 2 + staging 3 + 위성 3)
--   ⚠️ AD_PERF_DK 는 staging 3종(AGENCY_AD_ROW_*)이 **발급 단일지점**이다.
--      코어·위성·GOLD 는 값을 승계만 하며 재계산 금지(재계산 시 위성 조인 붕괴).
--   ⚠️ staging 은 BRONZE 컬럼명·타입을 그대로 보존한다(개명·형변환 금지). 정제는 코어/위성 담당.
--   ⚠️ staging 의 YEAR·MONTH·WEEK·DOW·BRDC_MT 는 '2025년'·'03월' 형태의 텍스트다 —
--      숫자 파싱 금지, 시간축은 DATE 컬럼에서 파생할 것(과거 96% NULL 결함 원인).
--   🔴🔴 [2026-09-17 O171 예외 신설 · 사용자 결정] **DGT 는 위 금지의 예외다.**
--      원천 12번 DGT 가 2026-06 전후로 시간축 방식을 바꾸는 중이다(개발 진행 중) ⇒
--        · 2026-06-01 이후 = `DATE` 채움(신방식) · 2026-05-31 이전 = `DATE` 공백 + 텍스트축만(구방식 고정분)
--      실측 = 203,138행 중 `DATE` NULL **194,058(95.53%)** ⇒ 위 규약이 신뢰하라고 한 컬럼이 비었다.
--      🟢 DGT 의 텍스트축 실측 값은 '2025년'이 아니라 **'2025'·'3'·'6'** 이고, `DATE` 가 있는 9,080행에서
--         파생값이 **9,080/9,080 일치(불일치 0)** 이며 NULL 행의 파생 최대값은 **2026-05-31**(6월 이후 0건).
--      ⇒ 코어 `AGENCY_AD_PERFORMANCE` 가 `COALESCE(DATE, TRY_TO_DATE(YEAR||MM||DD))` 로 폴백한다.
--      🔴 **파싱은 코어에서만 한다** — staging 은 원천 무손실이므로 이 파생 컬럼을 갖지 않는다.
--      🔴 **REBRDC·VIDEO 는 예외가 아니다**(둘 다 `DATE`/`BRDC_DATE` 널 0 실측) — 금지 유지.
--      🔴 `DATE_FROM_PARTS` 는 쓰지 마라 — 불량 월/일을 조용히 롤오버한다. `TRY_TO_DATE` 를 쓴다.
-- ============================================================================
-- AGENCY 1: AGENCY_AD_CREATIVE (매체·소재 차원)
--   [컬럼별 설계 및 실측 이력]
--   · CREATIVE_DK: MD5(소스+매체+소재+유형+CM위치+초수) 대체키 (PK)
--   · SOURCE_SYSTEM: 소스 시스템 (DIGITAL/REBROADCAST/VIDEO)
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## AGENCY_AD_PERFORMANCE

```text
-- AGENCY 2: AGENCY_AD_PERFORMANCE (3소스 UNION 광고성과)
--   [컬럼별 설계 및 실측 이력]
--   · AD_PERF_DK: 행 식별자 MD5(AD_SOURCE_TYPE|ROW_HASH|DUP_SEQ). 위성 조인키
--   · AD_SOURCE_TYPE: 광고유형 출처축. 실측값 DIGITAL/VIDEO/REBROADCAST. GOLD FAD degenerate 로 승격
--   · SOURCE_SYSTEM: 소스 시스템. ⚠️실측 AD_SOURCE_TYPE 와 전건 동일값(불일치 0) — 중복 컬럼, 신규 소비는 AD_SOURCE_TYPE 사용
--   · UPPER_CAMPAIGN_NM: VIDEO 분기만 값을 넣는다. DIGITAL 은 2026-09-17(O171) 자로 NULL —
--     원천 12번 DGT 의 상위캠페인 컬럼이 utm_campaign(CMPGN_UTM_NM)으로 개명돼 **개념 자체가 사라졌다**.
--     🔴 그 자리에 utm 을 끼우지 않는다(한 컬럼에 개념 2종 혼입 = O16 동형 결함).
--     utm 값은 AGENCY_AD_ROW_DGT.CMPGN_UTM_NM(무손실 staging)에 보존된다. REBROADCAST 는 원천 부재로 NULL.
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
    -- 🆕 [2026-09-29 O188] 신규지표 #9 「매체별 직접모금비」(편성비+광고비+콜센터운영비) 요건 ⇒ REBRDC 비용 분해 승격.
    --   선언 위치 = 감사컬럼 뒤(ALTER ADD COLUMN 규약). DIGITAL·VIDEO 행은 원천 개념 부재 ⇒ NULL.
```

## AGENCY_AD_ROW_DGT

```text
-- AGENCY 3: AGENCY_AD_ROW_DGT (DGT 무손실 staging + AD_PERF_DK 발급)
--   [컬럼별 설계 및 실측 이력]
--   · CMPGN_UTM_NM: 원천 12번 `DGT_AD_CMPGN_DTLS` 28번째 컬럼. 2026-09-17(O171) 개명 반영 —
--     구 이름 `UPPER_CMPGN_NM`('상위캠페인') → 현 `CMPGN_UTM_NM`('utm_campaign').
--     🔴 `VIDEO_AD_CMPGN_DTLS` 의 동명 컬럼은 개명 대상이 아니다(AGENCY_AD_ROW_VIDEO 는 구 이름 유지)
--     ⇒ 전역 치환 금지. staging 규약대로 원천 이름을 그대로 보존한다.
--   · 🔴🔴 [2026-09-28 O182] 원천 12번 재편(36→41) — 원천 이름 그대로 재정의했다(모델 `AGENCY_AD_ROW_DGT.sql` 머리말과 동일 목록).
--     제거 CPR_NM·DMST_OVSEA_DIV_NM·BSNS_CASE_DIV_NM·CMPGN_TY_NM · 개명 GA_AD_COST→AD_COST ·
--     GA_CONV_MBER_CNT→SPNSER_MBER_CNT · DEV_UNIT_PRICE→DVLP_UNIT_PRICE · CMPGN_UTM_NM→UTM_CMPGN_NM ·
--     신규 BDGT_SOURCE_NM·CMPGN_TYPE_BSN_NM·CMPGN_TYPE1/2_BSN_NM·MARKUP_AMT·VAT_AMT·LAST_STMT_AMT·TOTAL_CPA·TOTAL_DVLP_UNIT_PRICE.
--     ⚠️ 위 O171 줄의 `CMPGN_UTM_NM` 은 이제 원천에서 `UTM_CMPGN_NM` 이다(이 파일은 원천 이름을 따른다).
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## AGENCY_AD_ROW_VIDEO

```text
-- AGENCY 4: AGENCY_AD_ROW_VIDEO (VIDEO 무손실 staging + AD_PERF_DK 발급)
--   [컬럼별 설계 및 실측 이력]
--   · 🔴🔴 [2026-09-28 O182] 원천 12번 재편(32→37) — 원천 이름 그대로 재정의(모델 `AGENCY_AD_ROW_VIDEO.sql` 머리말과 동일 목록).
--     제거 DUR_PD_MATR_CHN·CONV_CALL_CNT·BRDC_MT·CTV_DIV_NM·MKT_CMPGN_NM·SPNSR_BSNS_NM ·
--     개명 ACTL_PUR_AD_COST_KRW→LAST_AD_COST · CPC(TEXT)→CPC_CALL_CNT(FLOAT) ·
--     신규 MONTH·AD_TY_NM·BDGT_SOURCE_NM·DEVICE_NM·DAY·SPNSER_CNT·DVLP_CNT·CMPGN_NM·MATR_TY_NM·EXPSR_CNT·CLICK_CNT.
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## AGENCY_AD_ROW_REBRDC

```text
-- AGENCY 5: AGENCY_AD_ROW_REBRDC (REBRDC 무손실 staging + AD_PERF_DK 발급)
--   [컬럼별 설계 및 실측 이력]
--   · DUP_SEQ: 전컬럼 중복 그룹 내 순번(실측 중복 0)
--   · 🔴🔴 [2026-09-28 O182] 원천 12번 재편(34→21) — 원천 이름 그대로 재정의(모델 `AGENCY_AD_ROW_REBRDC.sql` 머리말과 동일 목록).
--     제거 RE_BRDC_TY_NM·BRDC_MT·TIME_RNG_DIV_NM·CELEB_NM·DMST_OVSEA_DIV_NM·CASE1_*~CASE3_* 15컬럼 ·
--     개명 CHNNL_CMPNY→CHNNL_NM · DATE→BRDC_DATE ·
--     신규 MONTH·DAY·UPPER_CMPGN_CD·CMPGN_CD·CONTENTS_PUR_COST·CALL_CTR_OPER_COST·TOT_COST.
--     ⇒ 출연자명·아동명(PII O14) 컬럼이 원천에서 사라져 판정 대상이 소멸했다.
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## AGENCY_AD_DIGITAL

```text
-- AGENCY 6: AGENCY_AD_DIGITAL (디지털 고유속성 위성)
--   [컬럼별 설계 및 실측 이력]
--   · CRM_DVLP_CNT: CRM 개발건수 (가산). ⚠️실측 189,252행 중 13.0%가 비정수(기여도 배분 추정·어의 미확정 AD-2) · ⚠️2026-05 이후 원천 제공 중단(AD-3) → DEV_UNIT_PRICE_SRC 와 상호배타
--   · DEV_UNIT_PRICE_SRC: [비가산] 대행사 산정 개발단가. ⚠️2026-06부터 전건 제공(8,401행) — CRM_DEV_CNT 와 겹치는 행 0건, 검증관계 아닌 기간보완 관계(AD-3)
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## AGENCY_AD_BROADCAST

```text
-- AGENCY 7: AGENCY_AD_BROADCAST (방송 고유속성 위성)
--   ⚠️ [VIDEO 전용]/[REBRDC 전용] 표기 컬럼의 NULL 은 결측이 아니라 **해당 원천에 항목이 없음**이다.
--      비율지표 분모로 쓸 때 전체 37,886행을 모집단으로 잡으면 과대계상된다(AD-5·P21).
--   [컬럼별 설계 및 실측 이력]
--   · DURATION_SEC: 광고 초수 [VIDEO 전용] — HH:MM:SS 파싱값(초). 값 집합 {30,60,90,120}. 숫자표기 1,151행은 단위 미확정으로 NULL 유지. REBRDC 는 원천 부재
--   · DVLP_MEMBER_CNT: 개발회원수 [REBRDC 전용 — VIDEO 원천에 항목 부재]. 유효 모집단 = REBRDC 2,064행
--   · DVLP_CNT: 개발건수 [REBRDC 전용 — VIDEO 원천에 항목 부재]. 실측 1,982/2,064(96.0%). 개발단가 분모는 REBRDC 단독으로 한정(AD-5)
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
    -- 🟢 [DEC-30 2026-08-04] HH:MM:SS 파싱 배선 — 96.6% 무성 소실 복구(3.2%→93.1%).
    --   ⚠️ 숫자 3종(30/60/90 ×10^6)은 단위 미확정이라 의도적 NULL(문서20 §J 회신 대기).
    --   ⚠️ TRY_TO_TIME 금지 — '30000000' 을 05:20:00(19,200초)로 조용히 바꾼다(P48).
```

## AGENCY_AD_BROADCAST_CASE

```text
-- AGENCY 8: AGENCY_AD_BROADCAST_CASE (REBRDC 사례 언피벗)
--   [컬럼별 설계 및 실측 이력]
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## BIGQUERY_BASIC

```text
-- ============================================================================
-- STEP 5 — GA4 6테이블 (트랙 B)
--   🟢 [2026-08-18 O86] G-5 해소 — BRONZE 는 일별 샤드가 아니라 통합 1테이블이다.
--      `GN_DW.BRONZE_BIGQUERY.EVENTS` = 285,676,588행 / 911일(events_20240101~20260719 · 결번 0).
--      ⇒ 종전 헤더의 「1일 샤드 PoC 상태(G-5 하드블로커)」·「구조 변경 불요」는 **둘 다 폐기**다.
--        구조 변경은 실제로 필요했다 — 아래 O87 항목 2건.
--   🟢 [2026-08-19 O87] 신설 1 + 구조 개정 3.
--      · 신설 `BIGQUERY_REFINED_DATA` = 평탄화 통합 **기반 테이블**(GA4_* 5종의 유일 입력).
--        계층 내 파생 허용 근거 = DEC-37 · 원천 접두 명명 근거 = DEC-38.
--      · `BIGQUERY_EVENT` PK 4번째 키 `BATCH_ORDERING_ID` → **`EVENT_SEQ`**(GA4-PK-1 해소 · 손실 0).
--      · `USER_ID`·`USER_ID_FILLED`·`GA_MEMBER_ID` **VARCHAR(10) → VARCHAR(64)**
--        + `ID_SCHEME` 분류축 신설(GA4-LEN-1 해소). 길이 확장만 하면 매칭 분모가 왜곡된다.
--   🟢 [2026-08-21] 구조 개정 3.
--   🔴 GA4 5테이블로 원복했다.
--   🔄 [2026-08-21] `BIGQUERY_REFINED_DATA` 외부 Python 전환으로 파생 컬럼 소실 ⇒
--      `BIGQUERY_BASIC` 신설로 GA4 5 → 6 재복원(아래 실제 CREATE — 커밋아웃 블록 계승).
-- ============================================================================
-- -- GA4 0: BIGQUERY_REFINED_DATA (평탄화 통합 기반 테이블) — 🆕 [2026-08-19 O87]
-- --   grain = 1행 / (USER_PSEUDO_ID, EVENT_TIMESTAMP, EVENT_NAME, EVENT_SEQ)
-- --   설계근거·전제·비용 = 07_GA4_SILVER_샤드통합 설계결정.md 머리말 §「SILVER 평탄화 통합 테이블」
-- --   ⚠️ 이 테이블만 SILVER 에서 **원천 접두(BIGQUERY_)** 를 쓴다. 나머지는 도메인 접두(GA4_).
-- CREATE OR REPLACE TABLE GN_DW.SILVER.BIGQUERY_REFINED_DATA (
--     USER_PSEUDO_ID          VARCHAR(200)    NOT NULL COMMENT '세션 스파인 (PK)',
--     EVENT_TIMESTAMP         NUMBER          NOT NULL COMMENT 'UTC microsec (PK)',
--     EVENT_NAME              VARCHAR(200)    NOT NULL COMMENT '이벤트명 (PK)',
--     EVENT_SEQ               NUMBER          NOT NULL COMMENT '동일 3키 내 순번 (PK). GA4GN_DW.INFORMATION_SCHEMA-PK-1 조치① surrogate — 계보(SRC_FILE_NAME)+BATCH_ORDERING_ID 순 정렬. BATCH_ORDERING_ID 가 2024 상반기에 없어 PK 로 쓸 수 없던 문제를 대체한다. 🔴 [O87-B] 정렬 튜플이 동일한 행이 실재하므로 이 순번은 재실행 간 안정성이 미실증이다 — 미결 GA4-SEQ-1. 규모 실측 정본 = 20_issue/90_해소완료_로그.md §1-B',
--     EVENT_DATE              VARCHAR(8)      COMMENT '원본 YYYYMMDD',
--     EVENT_DT                DATE            NOT NULL COMMENT '업무일자 DATE. 🔴 프루닝 키 — 하류 range 조회는 반드시 이 컬럼으로 제한(빼면 2.86억행 전량 스캔)',
--     EVENT_TS                TIMESTAMP_NTZ   COMMENT '파생 TIMESTAMP',
--     USER_ID                 VARCHAR(64)     COMMENT 'GA4 user_id 원본(불변 보존). 🔴 GA4-LEN-1 조치① — 종전 VARCHAR(10)은 이메일·app- 접두 포맷에서 길이 초과로 적재 실패했다. CRM 회원번호가 아닌 값도 들어온다 ⇒ 반드시 ID_SCHEME 과 함께 읽을 것. 규모 실측 정본 = 20_issue/90_해소완료_로그.md §1-B-실측(R2-6: COMMENT 에 수치 미기재)',
--     ID_SCHEME               VARCHAR(20)     COMMENT 'ID 체계 분류축(GA4-LEN-1 조치②). 값 = MBER_NO(7자리 CRM) / ONCE_MBER_NO(S+8자리) / APP(app- 접두) / EMAIL(@ 포함) / INVALID(원천 오류값 "null"·"undefined") / UNCLASSIFIED(미분류 = 신규 포맷 조기경보 · 기대값 0). 🔴 CRM 조인 가능한 것은 앞 2종뿐이다 — 채움률 분모에 뒤 4종을 넣으면 조용히 과소 보고된다. USER_ID 가 NULL 이면 이 컬럼도 NULL(라벨 창작 금지 · R2-7). 규모 실측 정본 = 20_issue/90_해소완료_로그.md §1-B-실측',
--     GA_SESSION_ID           NUMBER          COMMENT 'GA 세션ID. 🔴 user_pseudo_id 내에서만 유일 — 단독 세션키 사용 금지(다른 사용자 세션 오병합)',
--     GA_SESSION_NUMBER       NUMBER          COMMENT 'GA 세션 번호',
--     GA_SESSION_KEY          VARCHAR         COMMENT '파생 세션 자연키 = user_pseudo_id ∥ "-" ∥ ga_session_id (복합 필수)',
--     SESSION_ENGAGED         VARCHAR(5)      COMMENT '세션 engaged 여부. 혼합타입 원천 → COALESCE(string_value, int_value)',
--     ENGAGEMENT_TIME_MSEC    NUMBER          COMMENT '참여시간 msec (비가산 raw — 율·평균은 GOLD/SV 소관)',
--     PAGE_LOCATION           VARCHAR         COMMENT '페이지 URL',
--     PAGE_TITLE              VARCHAR         COMMENT '페이지 제목',
--     PAGE_REFERRER           VARCHAR         COMMENT '리퍼러 URL',
--     EVENT_CATEGORY          VARCHAR         COMMENT '이벤트 카테고리 (event_params 승격)',
--     EVENT_ACTION            VARCHAR         COMMENT '이벤트 액션 (event_params 승격)',
--     EVENT_LABEL             VARCHAR         COMMENT '이벤트 라벨. 혼합타입(문자+숫자) 고카디널리티 — GA-2 리스크',
--     PERCENT_SCROLLED        NUMBER          COMMENT '스크롤 비율',
--     LINK_URL                VARCHAR         COMMENT '클릭 링크 URL',
--     LINK_TEXT               VARCHAR         COMMENT '클릭 링크 텍스트',
--     DEVICE_TYPE             VARCHAR(10)     COMMENT '디바이스 유형 파생(GA4 공식 = platform × device.category). 값 = APP / M / PC / (unknown). 🔴 라이브 관측은 M·PC·(unknown) 3종이고 APP 은 0건이다(platform=WEB 단독 · O2 APP 휴면). ⚠️ device:category 의 smart tv 가 (unknown) 으로 격리된다 — TV 라벨 신설 여부 = 미결 GA4-TV-1. 규모 실측 정본 = 20_issue/90_해소완료_로그.md §1-B-실측',
--     DEVICE_CATEGORY         VARCHAR         COMMENT '디바이스 카테고리(원본). 값 = mobile / desktop / tablet / smart tv 4종. 🔴 smart tv 는 DEVICE_TYPE 에서 (unknown) 으로 격리된다(미결 GA4-TV-1). 규모 실측 정본 = 20_issue/90_해소완료_로그.md §1-B-실측',
--     OS                      VARCHAR         COMMENT '운영체제',
--     BROWSER                 VARCHAR         COMMENT '브라우저',
--     LANGUAGE                VARCHAR         COMMENT '언어',
--     PLATFORM                VARCHAR(50)     COMMENT '플랫폼. 전 기간 실측 WEB 단독(ANDROID/IOS 0건)',
--     IS_ACTIVE_USER          BOOLEAN         COMMENT '활성 사용자 여부',
--     GEO_COUNTRY             VARCHAR         COMMENT '국가',
--     GEO_CITY                VARCHAR         COMMENT '도시',
--     UTM_SOURCE              VARCHAR         COMMENT 'UTM source (센티넬 (not set)/(direct) NULLIF)',
--     UTM_MEDIUM              VARCHAR         COMMENT 'UTM medium (센티넬 (not set)/(none)/(direct) NULLIF)',
--     UTM_CAMPAIGN            VARCHAR         COMMENT 'UTM campaign',
--     UTM_CONTENT             VARCHAR         COMMENT 'UTM content',
--     UTM_TERM                VARCHAR         COMMENT 'UTM term',
--     SOURCE_MEDIUM           VARCHAR         COMMENT '파생 source / medium',
--     XCHAN_SOURCE            VARCHAR         COMMENT 'cross_channel source',
--     XCHAN_MEDIUM            VARCHAR         COMMENT 'cross_channel medium',
--     XCHAN_CAMPAIGN          VARCHAR         COMMENT 'cross_channel campaign',
--     DEFAULT_CHANNEL_GROUP   VARCHAR         COMMENT '기본 채널그룹. 🔴 정규화 금지(정상 라벨 — 센티넬 아님)',
--     BATCH_ORDERING_ID       NUMBER          COMMENT '배치 내 정렬 ID. 🔴 NOT NULL 아님 — 원천 events_20240719 부터 생긴 컬럼이라 2024 상반기는 전건 NULL 이다. PK 에서 내려왔고 EVENT_SEQ 정렬 근거로만 쓴다. ⚠️ 2024 상반기는 이 컬럼이 전건 NULL 이므로 EVENT_SEQ 정렬이 사실상 SRC_FILE_NAME 부터 시작한다 — 미결 GA4-SEQ-1. 규모 실측 정본 = 20_issue/90_해소완료_로그.md §1-B-실측',
--     SRC_TABLE               VARCHAR(64)     NOT NULL COMMENT '원본 일별 테이블명(events_YYYYMMDD). 원천 대조 키 — BRONZE 계보 승계',
--     SRC_FILE_NAME           VARCHAR(512)    NOT NULL COMMENT '파일 단위 계보. 중복 적재 검출 + EVENT_SEQ 결정적 정렬 근거 — BRONZE 계보 승계',
--     BRONZE_LOAD_TS          TIMESTAMP_LTZ   NOT NULL COMMENT 'BRONZE 적재 배치 식별(= EVENTS.LOAD_TS). 업무일자 EVENT_DT 와 구분',
--     DW_SOURCE_SYSTEM        VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
--     DW_SOURCE_TABLE         VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
--     DW_LOAD_TS              TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
--     DW_UPDATE_TS            TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
--     DW_BATCH_ID             VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)',
--     PRIMARY KEY (USER_PSEUDO_ID, EVENT_TIMESTAMP, EVENT_NAME, EVENT_SEQ)
-- ) COMMENT = 'BRONZE_BIGQUERY.EVENTS 평탄화 통합 기반 테이블(GA4 계열의 유일 입력). event_params FLATTEN·VARIANT 경로 추출·DEVICE_TYPE 파생을 1회로 통합 — 종전 5모델이 각자 2.86억행을 읽던 것을 1회로 줄인다. 계층 내 파생 허용 = DEC-37 · 원천 접두 명명 = DEC-38. 🔴 조회 시 EVENT_DT 범위 제한 필수';
-- BIGQUERY 0: BIGQUERY_BASIC (평탄화 재파생 기반 테이블) — 🆕 [2026-08-21]
--   grain = 1행 / (USER_PSEUDO_ID, EVENT_TIMESTAMP, EVENT_NAME, EVENT_SEQ)
--   입력 = source('silver_external','BIGQUERY_REFINED_DATA')(외부 Python 적재 · 118컬럼 평탄화 · 파생 0).
--   위 커밋아웃 블록(구 `BIGQUERY_REFINED_DATA` dbt 모델 DDL)을 계승 — SRC_TABLE·SRC_FILE_NAME·
--   BRONZE_LOAD_TS 는 외부 적재에 계보가 없어 제거. GAC_*(google_ads_campaign) 3컬럼 신설.
--   🔴 [2026-09-17 O163] **위 커밋아웃 블록과 1271행의 `GA_*` 표기는 의도적으로 남겼다** —
--      `DEC-50`(가공계층 `ga`/`ga4` → `BIGQUERY` 전면 전환)을 이 세션이 집행하면서
--      **현행 컬럼 선언·설명만** 개명하고 **역사 기록은 원문 보존**했다(`R2-8-3` 「되돌릴 수 없음을
--      전제로 판단한다」 · 과거 시점 서술을 현재 이름으로 고치면 그 시점의 사실이 거짓이 된다).
--      ⇒ 🔴 **다음 세션은 이 4곳을 「개명 누락」으로 읽지 마라.** 현행 정본은 아래 CREATE 문이다.
--      집행 대상 8건 = `BIGQUERY_BASIC`·`BIGQUERY_EVENT` 의 SESSION 3컬럼 ×2 ·
--      `BIGQUERY_IDENTITY`·`IDENTITY_MEMBER_XREF` 의 `BIGQUERY_MEMBER_ID`.
--      ⚠️ 원천 `EP_GA_SESSION_ID`·`EP_GA_SESSION_NUMBER` 는 `BIGQUERY_REFINED_DATA` 의
--         **외부 Python 적재 원천 컬럼**이라 개명 대상이 아니다(개명표 §1 `EXTERNAL_PYTHON` 축).
--   🔴 EVENT_SEQ 결정성 미해결(GA4-SEQ-1) — ROW_NUMBER 는 PK 유일성만 보장하고 재실행 간
--      순번 안정성은 보장하지 않는다(정본 = 20_issue/90_해소완료_로그.md §GA4-SEQ-1).
--   [컬럼별 설계 및 실측 이력]
--   · EVENT_SEQ: 동일 3키 내 순번 (PK). ROW_NUMBER OVER(PARTITION BY 3키 ORDER BY BATCH_EVENT_INDEX,EVENT_BUNDLE_SEQUENCE_ID). 🔴 두 컬럼 모두 100% 비NULL인데도 3키 중복의 8.66%(2025-06 실측)가 그대로 남는다 — 값 자체가 원천에서 중복. PK 유일성은 ROW_NUMBER 구조상
--      보장되지만 재실행 간 순번 안정성은 미실증(GA4-SEQ-1). 규모 실측 정본 = 20_issue/90_해소완료_로그.md §GA4-SEQ-1
--   · EVENT_DT: 업무일자 DATE. 🔴 프루닝 키 — 하류 range 조회는 반드시 이 컬럼으로 제한
--   · USER_ID: GA4 user_id 원본(불변 보존). USER_ID 사용 — UP_MEMBER_ID 는 선행 0 소실 확인(예: "0470071"→"470071")로 ID_SCHEME 정규식과 불일치
--   · ID_SCHEME: ID 체계 분류축. 값 = MBER_NO(7자리)/ONCE_MBER_NO(S+8자리)/APP(app- 접두)/EMAIL(@ 포함)/INVALID("null"·"undefined")/UNCLASSIFIED. USER_ID NULL 이면 이 컬럼도 NULL
--   · BIGQUERY_SESSION_ID: BigQuery 세션ID(EP_GA_SESSION_ID TRY_CAST)
--   · BIGQUERY_SESSION_NUMBER: BigQuery 세션 번호(EP_GA_SESSION_NUMBER TRY_CAST)
--   · BIGQUERY_SESSION_KEY: 파생 세션 자연키 = user_pseudo_id ∥ "-" ∥ ga_session_id
--   · SESSION_ENGAGED: 세션 engaged 여부(EP_SESSION_ENGAGED)
--   · ENGAGEMENT_TIME_MSEC: 참여시간 msec(EP_ENGAGEMENT_TIME_MSEC TRY_CAST)
--   · EVENT_CATEGORY: 이벤트 카테고리(EP_EVENT_CATEGORY, 센티넬 NULLIF)
--   · EVENT_ACTION: 이벤트 액션(EP_EVENT_ACTION, 센티넬 NULLIF)
--   · EVENT_LABEL: 이벤트 라벨(EP_EVENT_LABEL, 센티넬 NULLIF)
--   · PERCENT_SCROLLED: 스크롤 비율(EP_PERCENT_SCROLLED TRY_CAST)
--   · DEVICE_TYPE: 디바이스 유형 파생. PC=platform WEB×device_category desktop / M=device_category mobile·tablet / APP=platform ANDROID·IOS. smart tv 등 미분류는 (unknown)(GA4-TV-1)
--   · UTM_SOURCE: UTM source(STSLC_MC_SOURCE, 센티넬 NULLIF)
--   · UTM_MEDIUM: UTM medium(STSLC_MC_MEDIUM, 센티넬 NULLIF)
--   · UTM_CAMPAIGN: UTM campaign(STSLC_MC_CAMPAIGN_NAME)
--   · SOURCE_MEDIUM: 파생 source / medium = XCHAN_SOURCE || " / " || XCHAN_MEDIUM
--   · XCHAN_SOURCE: cross_channel source(STSLC_CRC_SOURCE)
--   · XCHAN_MEDIUM: cross_channel medium(STSLC_CRC_MEDIUM)
--   · XCHAN_CAMPAIGN: cross_channel campaign(STSLC_CRC_CAMPAIGN_NAME)
--   · DEFAULT_CHANNEL_GROUP: 기본 채널그룹(STSLC_CRC_DEFAULT_CHANNEL_GROUP). 정규화 금지(정상 라벨)
--   · GAC_AD_GROUP_ID: google_ads_campaign 광고그룹 ID(STSLC_GAC_AD_GROUP_ID) — 🆕 [2026-08-21] 신설, 현재 하류 미소비
--   · GAC_AD_GROUP_NAME: google_ads_campaign 광고그룹명(STSLC_GAC_AD_GROUP_NAME) — 🆕 [2026-08-21] 신설, 현재 하류 미소비
--   · GAC_CAMPAIGN_NAME: google_ads_campaign 캠페인명(STSLC_GAC_CAMPAIGN_NAME) — 🆕 [2026-08-21] 신설, 현재 하류 미소비
--   · BATCH_ORDERING_ID: 배치 내 정렬 ID(BATCH_EVENT_INDEX 승계). EVENT_SEQ 정렬 1순위 근거로만 사용
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## BIGQUERY_TRAFFIC_SOURCE

```text
-- BIGQUERY 1: BIGQUERY_TRAFFIC_SOURCE (트래픽소스 차원)
--   [컬럼별 설계 및 실측 이력]
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## BIGQUERY_EVENT_DIM

```text
-- BIGQUERY 2: BIGQUERY_EVENT_DIM (이벤트분류 차원)
--   [컬럼별 설계 및 실측 이력]
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## BIGQUERY_DEVICE

```text
-- BIGQUERY 3: BIGQUERY_DEVICE (디바이스 차원)
--   [컬럼별 설계 및 실측 이력]
--   · DEVICE_TYPE: 디바이스 유형 파생. 실측값 PC/M 2종만(APP 휴면·O2)
--   · PLATFORM: 플랫폼. 실측값 WEB 단일(ANDROID/IOS 미입고)
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## BIGQUERY_EVENT

```text
-- BIGQUERY 4: BIGQUERY_EVENT (이벤트 팩트 소스)
--   🟢 [2026-08-19 O87] PK 4번째 키 교체 + USER_ID 확장 + ID_SCHEME 승계.
--   [컬럼별 설계 및 실측 이력]
--   · EVENT_SEQ: 동일 3키 내 순번 (PK). 🟢 GA4-PK-1 해소 — 종전 4번째 키 BATCH_ORDERING_ID 는 2024 상반기에 없어 그 구간을 NOT NULL 위반으로 배제했다. 3키로 낮춰도 중복이 남아 단순 제거도 불가였다 ⇒ 기반 테이블이 계보 순으로 부여한 surrogate 로 대체한다. 🔴 [O87-B] 성립하는 것은 「NOT NULL 위반 해소
--     」까지다 — 「손실 0」은 미실증이고 정렬 튜플 동일 행이 실재한다(미결 GA4-SEQ-1). 규모 실측 정본 = 20_issue/90_해소완료_로그.md §1-B-실측
--   · BATCH_ORDERING_ID: 배치 내 정렬 ID. 🔴 PK 아님 · NOT NULL 아님(2024 상반기 NULL) — 계보·정렬 근거로만 보존
--   · EVENT_DT: 파생 DATE. 🔴 프루닝 키 — 이 모델은 range 모델이고 pre-hook 이 이 컬럼으로 범위 DELETE 한다(silver_purge)
--   · USER_ID: GA4 user_id 원본(불변 보존). 🟢 GA4-LEN-1 해소 — 종전 VARCHAR(10)에서 이메일·app- 접두 포맷이 길이 초과로 실패했다. 🔴 CRM 회원번호가 아닌 값이 섞여 있다 ⇒ ID_SCHEME 과 함께 읽을 것. 규모 실측 정본 = 20_issue/90_해소완료_로그.md §1-B-실측
--   · ID_SCHEME: ID 체계 분류축(기반 테이블 승계). MBER_NO/ONCE_MBER_NO 만 CRM 조인 대상 · APP/EMAIL/INVALID/UNCLASSIFIED 는 회원번호 아님. 🔴 채움률 분모 판정의 정본
--   · BIGQUERY_SESSION_KEY: 파생 세션 자연키 (복합 = pseudo ∥ "-" ∥ session_id)
--   · USER_ID_FILLED: 파생 세션 전파 회원번호. 🟢 GA4-LEN-1 해소로 VARCHAR(10) → VARCHAR(64). 신뢰도는 ID_RESOLUTION 참조(SESSION_FILL 은 추론값)
--   · ID_RESOLUTION: 신원해소 DIRECT/SESSION_FILL/UNRESOLVED/CONFLICT. CONFLICT(세션 내 상이 user_id ≥2)는 미채움
--   · DEVICE_TYPE: 디바이스 유형 파생. 실측값 M/PC/(unknown) — APP 0건(platform=WEB 단독). smart tv 499행은 (unknown) 격리(GA4-TV-1)
--   · DEVICE_CATEGORY: 디바이스 카테고리 (원본). 전 기간 4종(mobile/desktop/tablet/smart tv)
--   · PLATFORM: 플랫폼. 전 기간 실측 WEB 단독(ANDROID/IOS 0건)
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## BIGQUERY_IDENTITY

```text
-- BIGQUERY 5: BIGQUERY_IDENTITY (신원 브리지 소스)
--   [컬럼별 설계 및 실측 이력]
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## IDENTITY_MEMBER_XREF

```text
-- ============================================================================
-- STEP 6 — 신원 브리지 (교차소스 유일 예외)
-- ============================================================================
-- IDENTITY_MEMBER_XREF: BIGQUERY_IDENTITY ↔ CRM_MEMBER 해소 브리지
--   ★GOLD 소비계약: grain = 1행/USER_PSEUDO_ID(GA 스파인) ≠ 회원 grain.
--     DIM_MEMBER_IDENTITY 구축 시 MEMBER_DK DISTINCT + UNMATCHED 제외(MEMBER_DK NOT NULL) 필수.
--     FACT 결합은 LEFT JOIN — 익명 세션이 95%다(실측 커버리지 4.84%).
--   [컬럼별 설계 및 실측 이력]
--   · BIGQUERY_MEMBER_ID: BigQuery측 식별자(=user_id_filled). 🟢 [O87] VARCHAR(10) → VARCHAR(64)(GA4-LEN-1) — 회원번호가 아닌 값도 포함되므로 ID_SCHEME 과 함께 읽을 것
--   · ID_SCHEME: 🔴 [O87 신설] BigQuery측 ID 체계. 매칭 분모 판정의 정본 — MBER_NO/ONCE_MBER_NO 만 조인 대상이다
--   · MEMBER_TYPE: 회원구분 ONCE/FDRM. 비회원 ID 체계는 NULL
--   · MATCH_METHOD: 매칭방법 MEMBER_ID_EXACT / UNMATCHED / 🆕 NOT_A_MEMBER_ID. 🔴 [O87] 종전 2분기는 「회원번호인데 CRM 에서 못 찾음」과 「애초에 회원번호가 아님」을 UNMATCHED 로 뭉개 채움률 분모를 왜곡했다 ⇒ 세 번째 값을 신설해 분리 표기. 채움률 = MEMBER_ID_EXACT / (MEMBER_ID_EXACT + 
--     UNMATCHED)
--   · DW_BATCH_ID: 적재 배치 식별자 = dbt invocation_id (공통감사)
```

## 파일 말미(원문)

```text
-- 🆕 [2026-09-30 O191-F 2차-B 2단 2묶음] UNION·다원천 SILVER 9종 누락 컬럼 78개 — DDL 선행 · ADMIN 적용 · 모델 후행
```

## 테이블 COMMENT 단축 전 원문(O192 · DEC-52 4블록 초과분)

- `BIGQUERY_BASIC`: BIGQUERY 웹/앱 이벤트 기본 Staging. [Grain: EVENT_DT × EVENT_SEQ (1행=1이벤트)]. [주의: 12컬럼 DDL 타입 캐스팅 정제]. [원천: BIGQUERY → BRONZE_BIGQUERY.EVENTS]. [적재: 롤링 윈도우 증분 — 창 [오늘-bigquery_lookback_days, 9999-12-31] 만 DELETE 후 재적재(멱등). 원천은 지연도착 종료 후 동결(freeze)돼 입고되므로 lookback 은 지연도착 방어가 아니고 실제 역할은 부분적재·중단 run 의 재처리다. 지연도착 재처리 요건이 생기면 dbt_project.yml vars.bigquery_lookback_days 값만 올려 대응 가능하다(개념 구현 상주 · 현재 3). 창보다 오래 run 을 건너뛴 구멍은 OPS.WARN_BIGQUERY_LOAD_GAP 이 감시한다].
- `BIGQUERY_EVENT`: BIGQUERY 사용자 행동 팩트 소스. [Grain: EVENT_DT × EVENT_SEQ (1행=1이벤트)]. [주의: 체류시간/스크롤/이탈률 행동 지표]. [원천: BIGQUERY → BRONZE_BIGQUERY.EVENTS]. [적재: 롤링 윈도우 증분 — 창 [오늘-bigquery_lookback_days, 9999-12-31] 만 DELETE 후 재적재(멱등). 원천은 지연도착 종료 후 동결(freeze)돼 입고되므로 lookback 은 지연도착 방어가 아니고 실제 역할은 부분적재·중단 run 의 재처리다. 지연도착 재처리 요건이 생기면 dbt_project.yml vars.bigquery_lookback_days 값만 올려 대응 가능하다(개념 구현 상주 · 현재 3). 창보다 오래 run 을 건너뛴 구멍은 OPS.WARN_BIGQUERY_LOAD_GAP 이 감시한다].
- `CRM_BIZ_TARGET`: 사업목표 마스터. [Grain: TARGET_YEAR × MONTH_NO × BDGT_PRCD_NM × GOAL_TYPE_NM × 원천 구분축(법인·신규기존·조직구분·팀·후원사업·세부구분) (1행=1목표값)]. [주의: GOAL_TYPE_NM 9종은 단위가 다르다(건·명·원·비율) — 유형 필터 필수]. [원천: CRM → BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV].
- `AGENCY_AD_ROW_REBRDC`: 재방송 광고 원천 무손실 Staging. [Grain: AD_PERF_DK (1행=1재방송광고)]. [주의: 재방송 광고 원천 21컬럼 보존(2026-09-28 원천 재편 · 사례 반복군 소멸)]. [원천: AGENCY → BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS].

_Co-authored with CoCo_
