-- GN_DW 3단계: Semantic View DDL 정본 — SV_AD (광고 실적) · base = GOLD.WIDE_AD_COMBINED(dbt 소유)
-- Co-authored with CoCo
-- ============================================================================
-- ▶ 이 파일의 위상  [2026-08-05 O37 분할]
--   대상 SV = **SV_AD**. base = `GOLD.WIDE_AD_COMBINED`(dbt 모델 소유) ⇒ 🔴 이 파일은 **`dbt build` 이후에만**
--   배포 가능하다(DEC-34 §0.8-D ③ 계열 · O54 재배선). 종전 helper `SERVING.FACT_AD_COMBINED` 동봉은 폐지됐다. 이 파일 하나로 **독립 실행**된다
--
--   🔴 **파일 규약·선행 조건·정본 근거의 정본 = `05_0_SV_DDL.sql` §공통 규약** (2026-08-10 O55 DUP-1).
--      독립 실행 · 파일 간 순서 무관 · 재실행 반영 · `CREATE OR ALTER`(GRANT·소유권 보존) ·
--      분할 이력(O37) · 선행 조건은 `dbt build` **하나** · 실행 역할 `GN_DW_ADMIN`.
--      ⛔ 이 항목들을 이 파일에 다시 복제하지 말 것 — 그것이 P140(9중 중복)의 원인이었다.
--
-- ▶ 가드레일 요약 (전문 = `05_0_SV_DDL.sql` §공통규약)
--   R1 fan-out : 월팩트→`GOLD.DIM_MONTH` · 회원속성→`GOLD.DIM_MEMBER_CURRENT` ·
--                광고팩트→`GOLD.WIDE_AD_COMBINED`. raw `DIM_DATE`/`DIM_MEMBER` 직접조인 금지.
--                🔴 [2026-08-10 O54·O55] SERVING helper 3종 → GOLD 재배선 완료 후 **물리 DROP 완료**(DEC-34 §0.8-D).
--   R5 가산성  : F(flow)=SUM / D=COUNT(DISTINCT MEMBER_DK) / 비율=분자·분모 각각 집계 후 division.
--   조인키 타입: `MEMBER_DK`=VARCHAR(캐스팅 금지) · `MONTH_KEY`/`DATE_SK`/`*_SK`=NUMBER.
--   PRIMARY KEY: 실측 유일한 것만 선언. 비유일 grain 은 PK 미선언.
--   비활성 지표: 원천 미적재분은 SV 에서 아예 제외한다(빈 metric 이 0/NULL 을 사실처럼 반환).
--   COMMENT 규약: 🔴 **수치를 넣지 않는다**(Agent 가 COMMENT 를 근거로 인용 → 적재량 변하면 거짓이 된다) ·
--                `[원천]` 절은 테이블·컬럼 이름만 · 저카디널리티 코드 차원은 **실제 코드값을 열거**.
-- ============================================================================

USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

/* =====================================================================================
   6. SV_AD (overall Agent) — base GOLD.WIDE_AD_COMBINED(dbt 뷰, FAP+FAD+FAB 1:1 pre-join)
      활성: 광고비·노출·클릭·CTR(공9)·CVR(공10)·CRM개발건·개발단가(공7) [디지털]
            인바운드콜·방송횟수 [방송] · 재방송개발건·재방송 개발단가(공8) [재방송 전용]
      ⚠ 디지털/방송 measure 상호배타 — AD_SOURCE_TYPE 필터 없이 혼합집계 시 왜곡
      ⚠ 캠페인/소재 연결키 미적재 → 캠페인·소재별 분해 불가(Phase-2)
      ⚠ 전환콜(CONV_CALL_CNT)·방송 전체 개발단가는 의도적 미노출 — 근거 = 04 §6.9
   ===================================================================================== */

-- 6-0. ⛔ [2026-08-10 O54] **helper 뷰 생성 블록 제거** — 사용자 결정.
--   base 가 `SERVING.FACT_AD_COMBINED`(SQL 스크립트 소유 47컬럼) → **`GOLD.WIDE_AD_COMBINED`**
--   (dbt 소유 51컬럼 · 방송 시간축 4컬럼 포함)으로 재배선됐으므로 이 파일은 더 이상 소비뷰를 만들지 않는다.
--   🔴 이 파일에서 `CREATE VIEW GN_DW.GOLD.WIDE_AD_COMBINED` 를 되살리지 말 것 — dbt 모델
--      (`models/gold/wide/WIDE_AD_COMBINED.sql`)이 정본이며 스크립트가 덮으면 4컬럼이 소실된다.
--   ⬜ 물리 `SERVING.FACT_AD_COMBINED` 는 잔존한다 → 의존 참조 0 확인 후 로드맵 **7단계**에서 DROP.

-- 6-1. SV_AD 본체
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_AD
  TABLES (
    ad AS GN_DW.GOLD.WIDE_AD_COMBINED
      PRIMARY KEY (AD_PERF_DK)
      WITH SYNONYMS ('광고 실적', '광고 성과', '매체 실적')
      COMMENT = '광고 실적 통합 팩트(FAP+FAD+FAB pre-join). AD_SOURCE_TYPE으로 디지털/방송 구분. [원천] 시스템=대행사(Agency) 일별 리포트(Google Sheet · Google Drive Excel · MS SharePoint Excel) + GA4(BigQuery 경유) · BRONZE=GN_DW.BRONZE_AGENCY: 디지털 DGT_AD_CMPGN_DTLS(광고비·노출·클릭·CRM개발건·MEDIA_NM) · 방송(비디오) VIDEO_AD_CMPGN_DTLS · 방송(재방) REBRDC_AD_CMPGN_DTLS(광고비·인입콜·방송횟수·개발건수) / GN_DW.BRONZE_BIGQUERY.EVENTS(GA 전환·기기) · SILVER=AGENCY_AD_PERFORMANCE·AGENCY_AD_CREATIVE·GA4_EVENT. ⚠_SRC 접미 컬럼은 대행사가 원천에서 이미 계산해 제공한 비율 원값(재집계 금지).',
    device AS GN_DW.GOLD.DIM_DEVICE
      PRIMARY KEY (DEVICE_SK)
      WITH SYNONYMS ('기기', '디바이스', '매체기기')
      COMMENT = '기기(디바이스) 차원. [원천] 시스템=GA4(BigQuery→Snowflake) · BRONZE=GN_DW.BRONZE_BIGQUERY.EVENTS(device.category) · SILVER=GA4_DEVICE. 방송 행은 기기 개념이 없어 (해당없음).',
    mktg AS GN_DW.GOLD.DIM_MARKETING_CAMPAIGN
      PRIMARY KEY (MKTG_CAMPAIGN_SK)
      WITH SYNONYMS ('마케팅캠페인', '캠페인')
      COMMENT = '마케팅캠페인 conformed 차원 — 광고(대행사) ↔ 개발실적(CRM)을 잇는 **유일한 결합축**이다(O45). PK 유일이라 조인이 행수를 늘리지 않는다(실측: FAP 조인 후 행수 불변). 🔴 개발캠페인(DIM_CAMPAIGN) grain 으로 내려가면 광고비가 복제된다 — 결합은 이 grain 에서만 한다. [원천] 시스템=CRM(eCRM) 마스터 + 대행사 리포트의 캠페인명 이름매칭 · BRONZE=GN_DW.BRONZE_CRM: TM_CM_MKTNG_CMPGN_MNG · SILVER=CRM_MARKETING_CAMPAIGN.',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '실적일')
      COMMENT = '일 차원. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.'
  )
  RELATIONSHIPS (
    ad_to_date   AS ad (PERF_DATE_SK) REFERENCES date (DATE_SK),
    ad_to_device AS ad (DEVICE_SK)    REFERENCES device,
    ad_to_mktg   AS ad (MKTG_CAMPAIGN_SK) REFERENCES mktg
  )
  DIMENSIONS (
    -- ── [2026-08-06 O45] 마케팅캠페인 축 (종전 「캠페인별 분해 불가」 서술 회수) ──────
    --   🔴 종전 이 SV 는 *"캠페인/소재별 분해 불가(연결키 미적재, Phase-2)"* 라고 선언하고
    --      AI_SQL_GENERATION 규칙(3)에서 **SQL 생성 자체를 거부**하게 했다. 그 서술은 이제 **절반이 거짓**이다:
    --      마케팅캠페인 분해는 되고 **소재만 불가**하다 → 서술을 쪼갰다(P61·P76).
    mktg.MARKETING_CAMPAIGN AS mktg.MKTG_CAMPAIGN_NAME
      WITH SYNONYMS ('마케팅캠페인', '마케팅 캠페인명', '캠페인', '캠페인명')
      COMMENT = '마케팅캠페인명 — 광고와 CRM 개발실적을 잇는 **유일한 결합축**이다(O45). 🔴 광고행 전체가 이 축에 도달하지는 않는다 — 미도달분은 ''(미매핑)'' 한 덩어리이므로 **이 축으로 그루핑한 광고비 합계는 전체 광고비보다 작다**. 총계를 물으면 축 없이 답하고, 캠페인별로 물으면 미매핑 버킷의 존재를 함께 밝힌다. ⚠️ **개발캠페인(개별 캠페인명)별 분해는 여전히 불가**하다 — 한 마케팅캠페인에 개발캠페인이 다수 매달려 있어 광고비를 내리면 그 배수로 복제된다(현업 배분 규칙 필요). ⚠️ **소재(광고 소재)별 분해도 불가**하다(소재 연결키 부재 · Q10)',
    mktg.DEV_CAMPAIGN_CNT   AS mktg.DEV_CAMPAIGN_CNT
      WITH SYNONYMS ('개발캠페인 수', '팬아웃 배수')
      COMMENT = '🔴**팬아웃 경고축**: 이 마케팅캠페인에 매달린 개발캠페인 수. 1 보다 크면 개발캠페인 단위로 광고비를 내릴 때 그 배수만큼 복제된다 — 이 값을 근거로 「개발캠페인별 ROI 는 배분 규칙 없이는 불가」라고 답한다',
    -- 시간
    date.PERF_DATE    AS date.FULL_DATE  WITH SYNONYMS ('실적일', '광고일', '일자') COMMENT = '광고 실적 발생일',
    date.CAL_YEAR     AS date.YEAR       WITH SYNONYMS ('연도', '년')   COMMENT = '연도',
    date.CAL_MONTH    AS date.MONTH      WITH SYNONYMS ('월')          COMMENT = '월(1~12)',
    date.CAL_QUARTER  AS date.QUARTER    WITH SYNONYMS ('분기')        COMMENT = '분기(1~4)',
    -- 코어 차원
    ad.AD_SOURCE_TYPE AS ad.AD_SOURCE_TYPE WITH SYNONYMS ('출처유형', '광고출처', '매체구분') COMMENT = '광고 출처유형. 코드값: ''DIGITAL'' · ''VIDEO''(방송 본방) · ''REBROADCAST''(재방송). 디지털/방송 measure 필터 필수. 실제값 3종: ''VIDEO''·''DIGITAL''·''REBROADCAST''',
    ad.DAY_OF_WEEK    AS ad.DAY_OF_WEEK    WITH SYNONYMS ('요일')   COMMENT = '요일. 실제값 7종: ''Fri''·''Mon''·''Sat''·''Sun''·''Thu''·''Tue''·''Wed''',
    ad.WEEK_OF_YEAR   AS ad.WEEK_OF_YEAR   WITH SYNONYMS ('주차')   COMMENT = '연중 주차',
    -- 기기
    device.DEVICE_TYPE       AS device.DEVICE_TYPE       WITH SYNONYMS ('기기유형', '디바이스유형', '모바일', 'PC') COMMENT = '기기 유형. 실제 코드값: ''M''=모바일(GA4 mobile/tablet 통합) · ''PC''=데스크톱 · ''(해당없음)''=방송광고(기기 개념 없음) · ''(unknown)''=매핑 실패 센티넬. ⚠필터 시 ''MOBILE''/''TABLET'' 아님 — 모바일은 ''M''.',
    device.DEVICE_SCOPE_DESC AS device.DEVICE_SCOPE_DESC WITH SYNONYMS ('기기범위') COMMENT = '기기 범위 설명(예: 모바일(GA4 device.category=mobile/tablet)).',
    -- 디지털 전용 차원
    ad.AD_TYPE_NM     AS ad.AD_TYPE_NM     WITH SYNONYMS ('광고유형', '광고타입') COMMENT = '디지털 광고유형(검색/디스플레이 등). AD_SOURCE_TYPE=DIGITAL 전용. 실제값 6종: ''DA''·''SA''·''BSA''·''CPM''·''CPT''·''하단DA'' + NULL',
    ad.CREATIVE_TYPE  AS ad.CREATIVE_TYPE  WITH SYNONYMS ('소재유형', '크리에이티브유형') COMMENT = '크리에이티브 유형. 디지털 전용. 원천에 일부 행만 채워져 있어 부분집합이다. 실제값 4종: ''기타''·''영상''·''이미지''·''키워드'' + NULL',
    -- 🔴 [2026-08-29 O119] 아래 두 축의 종수·열거를 **라이브 실측으로 교체**했다(`sv_code_label_gate` 축2 FAIL 2건).
    --   경위: 원천에 값이 추가됐는데 COMMENT 가 갱신되지 않아 **선언 종수 < 실제 종수** 상태였다.
    --   🔴 판정식 = 이 계열은 「0행 오답」이 아니라 **미열거**다 — 열거에 없는 값이 실재하므로
    --      Agent 가 열거를 「전체 목록」으로 읽으면 실재하는 값을 누락한 답을 낸다.
    --   ⇒ 원천에 값이 추가될 때마다 `sv_code_label_gate` 를 돌려 이 두 줄을 갱신한다.
    --   🔴🔴 **[2026-08-29 O119-B 자기시정] 초판이 `PAGE_TYPE=''전체''` 를 「집계행 라벨로 **보인다**」고
    --      추측해 라이브 COMMENT 에 실었다 — `R2-3`(COMMENT 근거 단정 금지) 위반이었다.**
    --      실측하니 **집계행이 아니다**: `''전체''` 는 소수 행에 걸친 저빈도 값이고 광고그룹도 단일이라
    --      전체 광고비의 극히 일부다(규모는 이슈원장 §O119-B 참조 · 규칙7 상 여기 적지 않는다).
    --      ⇒ 추측을 지우고 **관측 사실만** 남겼다. 🔴 판정식 = **COMMENT 는 주장 발행이다**(`R2-7-4`) —
    --      「~로 보인다」를 라이브 문안에 쓰지 마라. 모르면 「원천 확인 전」이라고 쓴다.
    ad.PAGE_TYPE      AS ad.PAGE_TYPE      WITH SYNONYMS ('페이지유형', '랜딩유형') COMMENT = '랜딩 페이지 유형. 디지털 전용. 실제값 2종: ''네이티브''·''전체'' + NULL. ⚠️ ''전체''는 저빈도 값이며 **그 의미(랜딩 유형인지 대행사 리포트의 묶음 표기인지)는 원천 확인 전**이다 — 유형별 분해에 쓰되 그 사실을 밝히고, 의미를 추측해 설명하지 말 것. 🟢 집계행(총계 중복)은 아니다 — 광고비 합계가 전체와 겹치지 않음을 실측 확인했다',
    ad.AD_GROUP_NM    AS ad.AD_GROUP_NM    WITH SYNONYMS ('광고그룹', '그룹명') COMMENT = '광고 그룹명. 디지털 전용. 실제값 14종: ''nf2134''·''nf3554''·''nf1834a''·''na2059_PC''·''ra2059_PC''·''na1849_interest''·''na2059_abroad_PC''·''ra2059_abroad_PC''·''na2059_domestic_PC''·''ra2059_domestic_PC''·''na_veteran26''·''광고세트 20260612143116''·''auto targeting test_v2_control_260624''·''auto targeting test_v2_variant_260624'' + NULL',
    -- 방송 전용 차원
    ad.CHANNEL_COMPANY AS ad.CHANNEL_COMPANY WITH SYNONYMS ('채널사', '방송사', '매체사') COMMENT = '방송 채널사. VIDEO/REBROADCAST 전용. ⚠광고비 기준 정렬 시 광고비가 없는 채널사가 섞이므로 NULLS LAST 를 명시할 것.',
    ad.TIME_BAND       AS ad.TIME_BAND       WITH SYNONYMS ('시간대', '광고시간대') COMMENT = '방송 시간대. 방송 전용.',
    ad.PROGRAM_NM      AS ad.PROGRAM_NM      WITH SYNONYMS ('프로그램', '프로그램명', '방송프로그램') COMMENT = '방송 프로그램명(고카디널리티 — Cortex Search 백킹 후보). 방송 전용.',
    ad.SPOT_TYPE       AS ad.SPOT_TYPE       WITH SYNONYMS ('스팟유형', '광고위치') COMMENT = '스팟 유형(전CM/중CM/후CM/SB). 방송 전용. 실제값 4종: ''CA''·''PR''·''SP''·''TJ'' + NULL',
    ad.CM_POSITION     AS ad.CM_POSITION     WITH SYNONYMS ('CM위치', '광고순서') COMMENT = 'CM 내 위치. 방송 전용. 실제값 16종: ''`''(🔴 **오염값** — 백틱 1문자이며 정상 CM 위치가 아니다. 이 값으로 필터하지 말 것 · 규모·경위는 이슈원장 참조)·''E-1st''·''E-2nd''·''E-3rd''·''E-4th''·''E-5th''·''E-6th''·''E-7th''·''T-1st''·''T-2nd''·''T-3rd''·''T-4th''·''T-5th''·''T-6th''·''T-7th''·''middle'' + NULL',
    ad.RT_TYPE         AS ad.RT_TYPE         WITH SYNONYMS ('재방유형', '방송유형구분') COMMENT = '본방/재방 유형. 방송 전용. 실제값 2종: ''특집''·''재송출'' + NULL'
  )
  METRICS (
    -- 공통 measure
    ad.TOTAL_AD_COST   AS SUM(ad.AD_COST)
      WITH SYNONYMS ('광고비', '광고비 총액', '매체비') COMMENT = '광고비 합계(원). F(가산). 디지털+방송 합산 가능.',
    ad.TOTAL_IMPRESSIONS AS SUM(ad.IMPRESSIONS)
      WITH SYNONYMS ('노출수', '노출', '임프레션') COMMENT = '노출수 합계. F(가산). 디지털 전용(방송은 NULL).',
    ad.TOTAL_CLICKS AS SUM(ad.CLICKS)
      WITH SYNONYMS ('클릭수', '클릭') COMMENT = '클릭수 합계. F(가산). 디지털 전용(방송은 NULL).',
    ad.TOTAL_INBOUND_CALL AS SUM(ad.INBOUND_CALL)
      WITH SYNONYMS ('인바운드콜', '전화문의', '콜수') COMMENT = '인바운드 전화 건수 합계. F(가산). 방송 전용(디지털은 NULL) — VIDEO·REBROADCAST 모두 존재.',
    ad.TOTAL_GA_CONV_MEMBERS AS SUM(ad.GA_CONV_MEMBERS)
      WITH SYNONYMS ('GA전환회원', '전환회원수') COMMENT = 'GA 전환 회원수 합계. F(가산). 디지털 전용.',
    ad.CTR AS SUM(ad.CLICKS) / NULLIF(SUM(ad.IMPRESSIONS), 0) * 100
      WITH SYNONYMS ('클릭률', 'CTR') COMMENT = '공9 CTR(%) = 클릭수 ÷ 노출수 ×100. 비율(N). 디지털 전용.',
    ad.CVR AS SUM(ad.GA_CONV_MEMBERS) / NULLIF(SUM(ad.CLICKS), 0) * 100
      WITH SYNONYMS ('전환율', 'CVR') COMMENT = '공10 CVR(%) = GA전환회원 ÷ 클릭수 ×100. 비율(N). 디지털 전용.',
    -- 디지털 전용 measure
    ad.TOTAL_CRM_DEV_CNT AS SUM(ad.CRM_DEV_CNT)
      WITH SYNONYMS ('CRM개발건', 'CRM 개발건수', '디지털개발건') COMMENT = 'CRM 개발건수 합계(디지털). F(가산). ⚠원천에 비정수(소수) 값이 섞여 있어 기여도 배분값일 가능성이 있다 → "건수"로 정수 단정 금지(어의 미확정, 03 §8.5 §6-H). ⚠원천이 개발건수 제공을 중단하고 단가를 직접 제공하는 포맷으로 바뀐 시점 이후는 미적재다 — 적재 구간은 데이터에서 확인할 것(03 §8.5.1).',
    -- 분자를 분모 적재행으로 정합(CASE WHEN): 미적재행 광고비를 분자에 넣으면 단가가 과대계상된다(04 §6.9 · 03 §8.5.1-(4)).
    ad.DEV_UNIT_PRICE AS SUM(CASE WHEN ad.CRM_DEV_CNT IS NOT NULL THEN ad.AD_COST END) / NULLIF(SUM(ad.CRM_DEV_CNT), 0)
      WITH SYNONYMS ('개발단가', 'CPA', '건당 광고비') COMMENT = '공7 디지털 개발단가(원) = 광고비 ÷ CRM개발건. 비율(N). DIGITAL 전용. 분자를 개발건수 적재행으로 정합(미적재행 광고비 제외). ⚠원천 포맷 변경 이후 구간은 개발건수가 없어 산출 불가(NULL) — 산출 가능한 최신 구간은 데이터에서 확인할 것.',
    ad.TOTAL_READ_CNT AS SUM(ad.READ_CNT)
      WITH SYNONYMS ('조회수', '열람수', '읽기수') COMMENT = '콘텐츠 조회수 합계(디지털). F(가산).',
    ad.TOTAL_MEDIA_POTENTIAL AS SUM(ad.MEDIA_POTENTIAL_CUST_CNT)
      WITH SYNONYMS ('매체잠재고객수', '잠재고객') COMMENT = '매체 잠재고객수 합계(디지털). F(가산).',
    -- 방송 전용 measure
    --   ⚠ 전환콜(CONV_CALL_CNT)은 의도적 미노출 — 대행사 원천(BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS)이
    --     전건 비어 있어 빈 metric이 된다. helper 뷰 컬럼은 무손실 원칙상 유지하고 SV 노출만 차단한다.
    --     원천이 실제 제공을 시작하면 이 metric만 되살린다(구조 불변). 근거·선례 = 04 §6.9 · 현업확인 AD-6.
    ad.TOTAL_AD_CNT AS SUM(ad.AD_CNT)
      WITH SYNONYMS ('방송횟수', '광고집행횟수', '편성횟수') COMMENT = '방송 광고 집행 횟수 합계. F(가산). VIDEO/REBROADCAST 전용.',
    ad.TOTAL_DVLP_CNT AS SUM(ad.DVLP_CNT)
      WITH SYNONYMS ('재방송개발건', '방송개발건', '방송 개발회원건수') COMMENT = '재방송 개발건수 합계. F(가산). **REBROADCAST 전용** — VIDEO는 원천(BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS)에 개발 컬럼이 **구조적으로 부재**하므로(대행사 비디오 리포트는 개발 대신 전환콜 보고) 결손이 아니다. ⚠VIDEO를 포함한 "방송 전체" 개발 규모로 확대 해석 금지.',
    ad.TOTAL_DVLP_MEMBER_CNT AS SUM(ad.DVLP_MEMBER_CNT)
      WITH SYNONYMS ('재방송개발회원', '방송개발회원', '방송 개발회원수') COMMENT = '재방송 개발회원수 합계. F(가산). **REBROADCAST 전용**(VIDEO 원천에 컬럼 부재).',
    -- 공8 재방송 개발단가 — 명명이 `BRDC_`(방송)가 아니라 `REBRDC_`(재방송)인 이유: VIDEO 원천에 개발 개념이
    --   없어 "방송 개발단가"라는 이름이 스코프를 오인시킨다. 판정 경위 = 03 §8.5 §6-I · 04 §6.4.1.
    ad.REBRDC_DEV_UNIT_PRICE AS SUM(CASE WHEN ad.DVLP_CNT IS NOT NULL THEN ad.AD_COST END) / NULLIF(SUM(ad.DVLP_CNT), 0)
      WITH SYNONYMS ('재방송 개발단가', '재방송 CPA', '재방송 건당 광고비') COMMENT = '공8 재방송 개발단가(원) = 재방송 광고비 ÷ 재방송 개발건. 비율(N). **REBROADCAST 전용**(VIDEO 원천에 개발 컬럼 부재 → 방송 전체 단가가 아님). 분자를 개발건수 적재행으로 정합. ⚠`AD_SOURCE_TYPE=''REBROADCAST''` 필터 전제 — VIDEO 혼합 시 과대계상된다.'
  )
  COMMENT = 'Phase-1 광고 실적 SV(base GOLD.WIDE_AD_COMBINED — dbt 소유 GOLD 뷰). [원천 요약] 원천시스템=대행사(Agency) 일별 리포트(Google Sheet·Drive Excel·SharePoint Excel) + GA4(BigQuery 경유) · BRONZE=GN_DW.BRONZE_AGENCY(디지털 DGT_AD_CMPGN_DTLS · 방송 VIDEO_AD_CMPGN_DTLS+REBRDC_AD_CMPGN_DTLS) + GN_DW.BRONZE_BIGQUERY.EVENTS → SILVER(AGENCY_AD_PERFORMANCE·AGENCY_AD_CREATIVE·GA4_EVENT) → GOLD(FAP+FAD+FAB). ⚠예산(SV_BUDGET)은 ERP 원천으로 서로 다른 시스템 — 교차 집계 불가. 테이블별 상세 원천은 각 테이블 COMMENT의 [원천] 절 참조. 활성: 광고비·노출·클릭·CTR(공9)·CVR(공10)·CRM개발건·개발단가(공7) [디지털] / 인바운드콜·방송횟수 [방송] / 재방송개발건·재방송 개발단가(공8) [재방송 전용]. ⚠디지털/방송 measure 상호배타. [2026-08-06 O45] 🔴 **마케팅캠페인별 분해가 활성화됐다 — 종전 "캠페인/소재별 분해 불가" 서술은 절반이 거짓이므로 쪼갰다**(P61). ✅ **마케팅캠페인**(MARKETING_CAMPAIGN) 축으로 광고비·노출·클릭·CTR·개발단가를 분해할 수 있다. ⛔ **소재별은 여전히 불가**(소재 연결키 부재 · Q10). ⛔ **개발캠페인(개별 캠페인명)별도 불가** — 연결키가 없어서가 아니라 한 마케팅캠페인에 개발캠페인이 다수 매달려 광고비 배분 규칙이 없기 때문이다(DEV_CAMPAIGN_CNT 축으로 그 배수를 확인할 수 있다). 해소 경로는 원천 입고가 아니라 **현업 배분 규칙 1건**이다. ⚠️ 마케팅캠페인 축으로 그루핑하면 미도달 광고행이 ''(미매핑)''으로 모이므로 캠페인별 합계 <
전체 합계다 — 총계는 축 없이 답한다. ⚠️ **광고비 ÷ CRM 개발실적(FACT_MEMBER_EVENT)** 형태의 개발단가는 이 SV 로 산출할 수 없다(cross-fact — metric 식은 자기 logical table 컬럼만 참조 가능). 이 SV 의 개발단가(공7)는 **대행사가 리포트한 디지털 개발건수** 기준이다. 두 정의를 섞지 말 것. ⚠개발단가(공7)는 원천 포맷 변경 이후 구간 산출 불가(원천이 개발건수 대신 단가 제공). ⚠개발건수/개발단가는 **REBROADCAST 전용** — VIDEO 원천(VIDEO_AD_CMPGN_DTLS)에 개발 컬럼이 구조적으로 부재하므로 "방송 전체" 지표가 아니다. ⚠전환콜(CONV_CALL_CNT)은 대행사 원천이 전건 비어 있어 이 SV에 measure가 없다 — 질문받으면 미제공으로 안내(추정치 생성 금지). ⚠수치·기간은 이 COMMENT에 두지 않는다 — 반드시 SV를 조회해 답할 것.'
  AI_SQL_GENERATION '핵심 규칙: (1) AD_SOURCE_TYPE 필터가 없는 질문에서 노출·클릭·CTR·CVR·CRM개발건·개발단가(공7)·조회수·잠재고객은 반드시 AD_SOURCE_TYPE=''DIGITAL'' 필터를 자동 추가한다. 인바운드콜·방송횟수는 AD_SOURCE_TYPE IN (''VIDEO'',''REBROADCAST'') 필터를 자동 추가한다. **개발건수(재방송개발건·재방송개발회원)와 재방송 개발단가(공8)는 AD_SOURCE_TYPE=''REBROADCAST'' 필터를 자동 추가한다** — VIDEO 원천에 개발 컬럼이 없어 혼합 시 과대계상된다. 광고비만 전체 합산 허용. (2) 적용 조건(기간·그룹 미지정 시): 데이터에 실제 존재하는 최신 연월(MAX(연월)) 기준 직전 12개월로 한정하고, GROUP BY ROLLUP((연,월))로 월별 행 + 총계 행을 함께 반환한다. (3) **캠페인별 분해는 마케팅캠페인 축으로 답한다**(O45 · 종전의 「SQL 생성 거부」 규칙은 폐기됐다): MARKETING_CAMPAIGN 으로 그루핑하고, ''(미매핑)'' 버킷이 존재하므로 **캠페인별 합계가 전체 합계보다 작다는 점을 답변에 명시**한다. 🔴 **소재별 분해는 여전히 불가**하다(소재 연결키 부재) — SQL 을 생성하지 말고 사유를 답한다. 🔴 **개발캠페인(개별 캠페인명)별 ROI·개발단가도 생성하지 않는다** — 한 마케팅캠페인에 개발캠페인이 다수 매달려 광고비를 내리면 그 배수로 복제된다(DEV_CAMPAIGN_CNT 로 배수를 보여주며 설명한다). 필요한 것은 원천 입고가 아니라 현업의 광고비 배분 규칙이다. 🔴 **광고비 ÷ CRM 개발실적** 형태의 개발단가를 이 SV 에서 만들지 않는다 — 개발실적은 다른 팩트(FACT_MEMBER_EVENT)에 있어 cross-fact 이며 SV metric 식으로 표현할 수 없다. 이 SV 의 개발단가는 대행사 리포트 기준임을 밝힌다. (4) 기기 필터: 모바일은
DEVICE_TYPE=''M''(''MOBILE''/''TABLET'' 아님), 데스크톱은 ''PC''. 방송은 ''(해당없음)''이므로 기기별 분석은 디지털에만 적용한다. (5) 개발단가(공7, 디지털)는 원천이 개발건수 제공을 중단한 시점 이후 NULL이다. 기간을 하드코딩하지 말고 CRM_DEV_CNT 가 존재하는 최신 연월을 데이터에서 조회해 그 시점까지로 한정하고, 그 이후는 원천 포맷 변경으로 산출 불가임을 답변에 명시한다. (6) 개발건수·개발단가를 "방송"으로 묻더라도 **재방송(REBROADCAST) 전용 지표**임을 답변에 명시한다 — VIDEO는 대행사 원천에 개발 컬럼이 없어 집계 대상이 아니며(결손이 아니라 구조적 부재), 방송 전체 개발 규모로 단정하면 안 된다. (7) **전환콜**은 이 SV에 measure가 없다 — 대행사 원천(VIDEO_AD_CMPGN_DTLS.CONV_CALL_CNT)이 전건 비어 있기 때문이다. 질문받으면 SQL을 생성하지 말고 미제공 사유를 답하고, 인바운드콜(INBOUND_CALL)로 대체 가능한지 되묻는다. 전환콜 수치를 추정·창작하지 않는다. (8) 채널사·프로그램 등 방송 차원을 광고비 기준으로 정렬할 때는 ORDER BY ... DESC NULLS LAST 를 쓴다 — 기본값 NULLS FIRST 면 광고비 없는 항목이 상위를 점유한다.';


/* =====================================================================================
   GRANT — Cortex Analyst 소비 권한 (docs: REFERENCES, SELECT 필요 · USAGE 아님)
      ANALYST 가 VIEWER 를 상속하나 명확성을 위해 3역할 모두 명시(02 §E 패턴).
      🟢 [2026-08-10 O54] 본문이 `CREATE OR ALTER` 이므로 **기존 GRANT 는 보존**된다 →
         아래 GRANT 는 멱등 재확인이다. 🔴 판정은 소유자 세션이 아니라 **소비 역할 세션**으로
         한다(P126) — 검사기 = `scripts/sv_unit_gate.py`.
         분할의 이점: GRANT 가 대상 SV 와 같은 파일에 있어 빠뜨릴 수 없다.
   ===================================================================================== */
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_AD TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_AD TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_AD TO ROLE GN_DW_SERVICE;


/* =====================================================================================
   스모크 검증 (배포 직후 실행) — 04 §0.1 DoD
      원리: `SEMANTIC_VIEW(...)` 집계 == 단일 FACT 직접 SUM 일치 → 조인 fan-out 0 검증.
      🔴 판정은 **절대값이 아니라 불변식**으로 한다. 적재량은 계정·시점마다 다르므로
         "sv_val == fact_val" 같은 관계식이 참인지만 본다. 기대 절대값을 문서에 박으면
         재현 시 전항 오탐이 된다(04 §6.9-(8)).
      ▶ SV 9종 전체를 아우르는 배포 검증(소유권·GRANT·구조 대조·base 스키마) = `05_0_SV_DDL.sql`
   ===================================================================================== */
USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- ─── 8-B. SV_AD 스모크 ─────────────────────────────────────────────────────────────
-- (8-4) fan-out 0: SV 집계 == 코어 FACT 직접 SUM (위성 2개 1:1 조인 검증)
SELECT (SELECT TOTAL_AD_COST FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_AD METRICS TOTAL_AD_COST)) AS sv_val,
       (SELECT SUM(AD_COST)  FROM GN_DW.GOLD.FACT_AD_PERFORMANCE)                           AS fact_val;
--   판정: sv_val == fact_val

-- (8-5) 수직분할 완결성: 디지털 + 방송 == 코어 전건 (helper 뷰 LEFT JOIN 안전성 근거)
SELECT (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_AD_PERFORMANCE) AS fap,
       (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_AD_DIGITAL)     AS dig,
       (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_AD_BROADCAST)   AS brc,
       (SELECT COUNT(*) FROM GN_DW.GOLD.WIDE_AD_COMBINED) AS combined;
--   판정: dig + brc == fap  AND  combined == fap  (→ 중복 팽창 없음)

-- (8-6) 디지털 지표 산출 (CTR·CVR·개발단가)
--   🔴 SEMANTIC_VIEW(...) 내부에 FILTER 절로 `ad.컬럼` 을 쓰면 **문법 오류**다
--      ("syntax error ... unexpected 'ad'"). 차원을 DIMENSIONS 에 넣고 **바깥 WHERE 에서
--      별칭 없는 컬럼명**으로 걸러야 한다(04 §6.9-(6)).
SELECT CAL_YEAR, AD_SOURCE_TYPE, TOTAL_AD_COST, CTR, CVR, DEV_UNIT_PRICE
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_AD
  DIMENSIONS date.CAL_YEAR, ad.AD_SOURCE_TYPE
  METRICS TOTAL_AD_COST, CTR, CVR, DEV_UNIT_PRICE
)
WHERE AD_SOURCE_TYPE = 'DIGITAL'
ORDER BY 1;
--   판정: 연도별 행이 나오고 CTR/CVR 이 NULL 아님. 개발단가는 최신 구간에서 NULL 일 수 있다(원천 포맷 변경).

-- (8-7) 상호배타 확인 + 기기 차원 조인
SELECT AD_SOURCE_TYPE, DEVICE_TYPE, TOTAL_AD_COST, TOTAL_CLICKS, TOTAL_INBOUND_CALL, TOTAL_AD_CNT
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_AD
  DIMENSIONS ad.AD_SOURCE_TYPE, device.DEVICE_TYPE
  METRICS TOTAL_AD_COST, TOTAL_CLICKS, TOTAL_INBOUND_CALL, TOTAL_AD_CNT
)
ORDER BY 1, 2;
--   판정(구조 불변식):
--     DIGITAL     · M / PC       : 클릭 있음 · 인바운드콜·방송횟수 **NULL**
--     REBROADCAST · (해당없음)   : 인바운드콜·방송횟수 있음 · 클릭 **NULL**
--     VIDEO       · (해당없음)   : 인바운드콜·방송횟수 있음 · 클릭 **NULL**
--   → 기기 코드가 'M'/'PC'/'(해당없음)' 임을 확인(=SV comment 와 일치). 'MOBILE' 아님.

-- (8-8) 방송 전용 축 조인 (채널사)
--   🔴 `ORDER BY <metric> DESC` 는 Snowflake 기본이 **NULLS FIRST** → 광고비 NULL 채널사가
--      상위를 차지해 "top N" 이 오염된다 → `NULLS LAST` 필수(04 §6.9-(7)).
SELECT CHANNEL_COMPANY, TOTAL_AD_COST, TOTAL_INBOUND_CALL, TOTAL_AD_CNT, TOTAL_DVLP_CNT
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_AD
  DIMENSIONS ad.CHANNEL_COMPANY
  METRICS TOTAL_AD_COST, TOTAL_INBOUND_CALL, TOTAL_AD_CNT, TOTAL_DVLP_CNT
)
WHERE CHANNEL_COMPANY IS NOT NULL
ORDER BY TOTAL_AD_COST DESC NULLS LAST
LIMIT 10;
--   ⚠ TOTAL_DVLP_CNT 는 REBROADCAST 전용 부분합 — 채널사별 개발 규모 비교에 쓰지 말 것.

-- (8-9) 미노출 metric 확인 — 아래는 **에러가 나야 정상**
--   SELECT BRDC_DEV_UNIT_PRICE FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_AD METRICS BRDC_DEV_UNIT_PRICE);
--   SELECT TOTAL_CONV_CALL_CNT FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_AD METRICS TOTAL_CONV_CALL_CNT);
--   판정: 둘 다 `invalid identifier` — 방송 전체 개발단가와 전환콜은 의도적 미노출이다(04 §6.9).
--     재방송 한정 단가는 `REBRDC_DEV_UNIT_PRICE`(AD_SOURCE_TYPE='REBROADCAST' 필터 전제)로 노출된다.
