-- =============================================================================
-- Purpose    : 05_7_SV_DDL_AD.sql — Semantic View DDL 정본: SV_AD
-- Target     : SEMANTIC VIEW GN_DW.SERVING.SV_AD
-- Run order  : 운영계 #24 · 기존 환경 갱신 #3
-- Depends on : GN_DW.GOLD.WIDE_AD_COMBINED, GN_DW.GOLD.DIM_DEVICE, GN_DW.BRONZE_BIGQUERY.EVENTS, GN_DW.GOLD.DIM_MARKETING_CAMPAIGN, GN_DW.GOLD.DIM_DATE, GN_DW.GOLD.FACT_AD_PERFORMANCE 외 2
-- Issue      : O225-C, O232-B, O233
-- =============================================================================
-- ============================================================================
-- 05_7_SV_DDL_AD.sql — Semantic View DDL 정본: SV_AD
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능(파일 간 순서 없음).
--   · WARN: SV 의 규칙·주의는 SV COMMENT · AI_SQL_GENERATION 안에 있다(Agent 가 읽는 곳) — 이 주석에 두지 않는다.
--   · 공통 규약 = 05_0_SV_DDL.sql · 설계·실측 이력 = 05_SV_DDL_설계이력_부록.md
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

use role gn_dw_admin;
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_AD
  TABLES (
    ad AS GN_DW.GOLD.WIDE_AD_COMBINED
      PRIMARY KEY (AD_PERF_DK)
      WITH SYNONYMS ('광고 실적', '광고 성과', '매체 실적')
      COMMENT = '온-오프라인 광고 성과 통합 분석 (base: GOLD.WIDE_AD_COMBINED). [Grain: 집행일 × 캠페인 × 소재 × 디바이스]. [활성 지표: 광고비/노출/클릭/전환/CTR/CVR/CPC/CPM/ROAS]. [주의: _SRC 접미 비율 지표 단순 재합산 금지]. [원천: AGENCY 3소스 + GA4 → SILVER.AGENCY_AD_* → GOLD.WIDE_AD_COMBINED].',
    device AS GN_DW.GOLD.DIM_DEVICE
      PRIMARY KEY (DEVICE_SK)
      WITH SYNONYMS ('기기', '디바이스', '매체기기')
      COMMENT = '기기(디바이스) 차원. [원천] 시스템=GA4(BigQuery→Snowflake) · BRONZE=GN_DW.BRONZE_BIGQUERY.EVENTS(device.category) · SILVER=GA4_DEVICE. 방송 행은 기기 개념이 없어 (해당없음).',
    mktg AS GN_DW.GOLD.DIM_MARKETING_CAMPAIGN
      PRIMARY KEY (MKTG_CAMPAIGN_SK)
      WITH SYNONYMS ('마케팅캠페인', '캠페인')
      COMMENT = '마케팅캠페인 conformed 차원 — 광고(대행사) ↔ 개발실적(CRM)을 잇는 **유일한 결합축**이다. PK 유일이라 조인이 행수를 늘리지 않는다(실측: FAP 조인 후 행수 불변). 🔴 개발캠페인(DIM_CAMPAIGN) grain 으로 내려가면 광고비가 복제된다 — 결합은 이 grain 에서만 한다. [원천] 시스템=CRM(eCRM) 마스터 + 대행사 리포트의 캠페인명 이름매칭 · BRONZE=GN_DW.BRONZE_CRM: TM_CM_MKTNG_CMPGN_MNG · SILVER=CRM_MARKETING_CAMPAIGN.',
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
    mktg.MARKETING_CAMPAIGN AS mktg.MKTG_CAMPAIGN_NAME
      WITH SYNONYMS ('마케팅캠페인', '마케팅 캠페인명', '캠페인', '캠페인명', '신규10')
      COMMENT = '마케팅캠페인명 — 광고와 CRM 개발실적을 잇는 **유일한 결합축**이다. 🔴 광고행 전체가 이 축에 도달하지는 않는다 — 미도달분은 ''(미매핑)'' 한 덩어리이므로 **이 축으로 그루핑한 광고비 합계는 전체 광고비보다 작다**. 총계를 물으면 축 없이 답하고, 캠페인별로 물으면 미매핑 버킷의 존재를 함께 밝힌다. ⚠️ **개발캠페인(개별 캠페인명)별 분해는 여전히 불가**하다 — 한 마케팅캠페인에 개발캠페인이 다수 매달려 있어 광고비를 내리면 그 배수로 복제된다(현업 배분 규칙 필요). ⚠️ **소재(광고 소재)별 분해도 불가**하다(소재 연결키 부재). 🔴 **도달률은 출처유형마다 크게 다르다** — 디지털은 상당 부분 도달하지만 방송(VIDEO)은 원천 마케팅캠페인명 컬럼 소멸로 일부만 도달하고 재방송(REBROADCAST)은 도달하지 않는다 ⇒ 방송·재방송을 이 축으로 분해하지 말고, 캠페인별 질문에는 AD_SOURCE_TYPE 별 도달 비중을 조회해 함께 밝힌다. 🆕 미도달분은 0 이 아니다 — 소재명(CREATIVE_NM · 재방송은 방송명)·프로그램(PROGRAM_NM) 축으로 원천 금액 그대로 분해해 함께 보여준다',
    mktg.DEV_CAMPAIGN_CNT   AS mktg.DEV_CAMPAIGN_CNT
      WITH SYNONYMS ('개발캠페인 수', '팬아웃 배수')
      COMMENT = '🔴**팬아웃 경고축**: 이 마케팅캠페인에 매달린 개발캠페인 수. 1 보다 크면 개발캠페인 단위로 광고비를 내릴 때 그 배수만큼 복제된다 — 이 값을 근거로 「개발캠페인별 ROI 는 배분 규칙 없이는 불가」라고 답한다',
    --  [2026-10-14 O225-C] 마케팅캠페인 속성 3종(광고비 분해용 · 인입경로·채널·카테고리는 의도적으로 없다)
    mktg.MKTG_UTM_NM AS mktg.MKTG_UTM_NM
      WITH SYNONYMS ('UTM', 'UTM 캠페인', '마케팅캠페인 UTM')
      COMMENT = '마케팅캠페인의 UTM 라벨(CRM 마케팅 코드 U001 · 마케팅캠페인당 1개). 광고비를 UTM 별로 나눌 때 쓴다. 대행사 원천의 UTM 태그(UTM_CMPGN_NM)와는 다른 축이다(그쪽은 광고행 원값).',
    mktg.DOMESTIC_OVERSEAS AS mktg.DOMESTIC_OVERSEAS
      WITH SYNONYMS ('국내해외', '국내/해외', '캠페인 국내해외', '공15')
      COMMENT = '마케팅캠페인 국내/통합/해외(MM295). 🔴 한 마케팅캠페인 아래 값이 갈리면(소수 · 실측은) 매핑 행수 최다 값을 대표로 쓴다 — DOMESTIC_OVERSEAS_IS_MULTI=TRUE 비중을 함께 밝힌다.',
    mktg.DOMESTIC_OVERSEAS_IS_MULTI AS mktg.DOMESTIC_OVERSEAS_IS_MULTI
      WITH SYNONYMS ('국내해외 대표값 여부')
      COMMENT = 'TRUE = 국내/해외 값이 여럿이라 대표값을 쓴 마케팅캠페인.',
    mktg.BIZ_CASE_TYPE AS mktg.BIZ_CASE_TYPE
      WITH SYNONYMS ('사업사례', '사업/사례', '캠페인 사업사례', '공16')
      COMMENT = '마케팅캠페인 굿즈/기타/사례/사업(MM296). 🔴 한 마케팅캠페인 아래 값이 갈리면 매핑 행수 최다 값을 대표로 쓴다 — BIZ_CASE_TYPE_IS_MULTI=TRUE 비중을 함께 밝힌다.',
    mktg.BIZ_CASE_TYPE_IS_MULTI AS mktg.BIZ_CASE_TYPE_IS_MULTI
      WITH SYNONYMS ('사업사례 대표값 여부')
      COMMENT = 'TRUE = 사업/사례 값이 여럿이라 대표값을 쓴 마케팅캠페인.',
    --  [2026-10-15 O232-B] 마케팅캠페인 대표 카테고리(캠페인 목록 속성용 · 광고비 분해는 ad.AD_CTGR_NM)
    mktg.CMPGN_CTGR_NM AS mktg.CMPGN_CTGR_NM
      WITH SYNONYMS ('마케팅캠페인 카테고리', '마케팅캠페인 대표 카테고리')
      COMMENT = '마케팅캠페인 대표 캠페인카테고리(매핑 행수 최다). 🔴 카테고리별 광고비는 이 축이 아니라 ad.AD_CTGR_NM 으로 낸다 — 이 축은 미연결 재방송·영상의 소재 매핑 카테고리를 놓친다.',
    mktg.CMPGN_CTGR_IS_MULTI AS mktg.CMPGN_CTGR_IS_MULTI
      WITH SYNONYMS ('마케팅캠페인 카테고리 대표값 여부')
      COMMENT = 'TRUE = 카테고리가 여럿이라 대표값을 쓴 마케팅캠페인.',
    mktg.CMPGN_CTGR_NM_LIST AS mktg.CMPGN_CTGR_NM_LIST
      WITH SYNONYMS ('마케팅캠페인 카테고리 목록')
      COMMENT = '마케팅캠페인 카테고리명 나열(쉼표 구분 · 첫 항목 = 대표 CMPGN_CTGR_NM). 🔴 표시 전용 — GROUP BY·WHERE·합산 금지.',
    date.PERF_DATE    AS date.FULL_DATE  WITH SYNONYMS ('실적일', '광고일', '일자', '날짜') COMMENT = '광고 실적 발생일',
    date.FULL_DATE AS date.FULL_DATE  COMMENT = '달력 날짜(DIM_DATE.FULL_DATE) — PERF_DATE 와 같은 값이다(Analyst 가 추측하는 식별자를 실재화). 둘 중 하나만 쓴다.',
    date.CAL_YEAR     AS date.YEAR       WITH SYNONYMS ('연도', '년')   COMMENT = '연도',
    date.CAL_MONTH    AS date.MONTH      WITH SYNONYMS ('월')          COMMENT = '월(1~12)',
    date.YEAR AS date.YEAR    COMMENT = '연도(DIM_DATE.YEAR) — CAL_YEAR 와 같은 값(Analyst 가 추측하는 식별자를 실재화). 둘 중 하나만 쓴다.',
    date.MONTH AS date.MONTH  COMMENT = '월(DIM_DATE.MONTH) — CAL_MONTH 와 같은 값(추측 식별자 실재화). 둘 중 하나만 쓴다.',
    date.CAL_QUARTER  AS date.QUARTER    WITH SYNONYMS ('분기')        COMMENT = '분기(1~4)',
    ad.AD_SOURCE_TYPE AS ad.AD_SOURCE_TYPE WITH SYNONYMS ('출처유형', '광고출처', '매체구분') COMMENT = '광고 출처유형. 코드값: ''DIGITAL'' · ''VIDEO''(방송 본방) · ''REBROADCAST''(재방송). 디지털/방송 measure 필터 필수. 실제값 3종: ''VIDEO''·''DIGITAL''·''REBROADCAST''',
    ad.DAY_OF_WEEK    AS ad.DAY_OF_WEEK    WITH SYNONYMS ('요일')   COMMENT = '요일. 실제값 7종: ''Fri''·''Mon''·''Sat''·''Sun''·''Thu''·''Tue''·''Wed''',
    ad.WEEK_OF_YEAR   AS ad.WEEK_OF_YEAR   WITH SYNONYMS ('주차')   COMMENT = '연중 주차',
    device.DEVICE_TYPE       AS device.DEVICE_TYPE       WITH SYNONYMS ('기기유형', '디바이스유형', '모바일', 'PC', '공14') COMMENT = '기기 유형. 실제 코드값: ''M''=모바일(GA4 mobile/tablet 통합) · ''PC''=데스크톱 · ''(해당없음)''=방송광고(기기 개념 없음) · ''(unknown)''=매핑 실패 센티넬. ⚠필터 시 ''MOBILE''/''TABLET'' 아님 — 모바일은 ''M''.',
    device.DEVICE_SCOPE_DESC AS device.DEVICE_SCOPE_DESC WITH SYNONYMS ('기기범위') COMMENT = '기기 범위 설명(예: 모바일(GA4 device.category=mobile/tablet)).',
    ad.AD_TYPE_NM     AS ad.AD_TYPE_NM     WITH SYNONYMS ('광고유형', '광고타입', '공13') COMMENT = '디지털 광고유형(검색/디스플레이 등). AD_SOURCE_TYPE=DIGITAL 전용. 값 목록은 이 컬럼을 SELECT DISTINCT 로 조회한다(열거를 여기 박지 않는다).',
    ad.CREATIVE_TYPE  AS ad.CREATIVE_TYPE  WITH SYNONYMS ('소재유형', '크리에이티브유형') COMMENT = '크리에이티브 유형. 디지털 전용. 원천에 일부 행만 채워져 있어 부분집합이다. 실제값 5종: ''기타''·''영상''·''이미지''·''키워드''·''해당없음'' + NULL. ⚠️ ''해당없음''은 원천이 넣은 값이며 NULL 과 다르다(합치지 않는다)',
    ad.PAGE_TYPE      AS ad.PAGE_TYPE      WITH SYNONYMS ('페이지유형', '랜딩유형') COMMENT = '랜딩 페이지 유형. 디지털 전용. 값 목록은 이 컬럼을 SELECT DISTINCT 로 조회한다(열거를 여기 박지 않는다). ⚠️ ''전체'' 값이 섞여 있고 **그 의미(랜딩 유형인지 대행사 리포트의 묶음 표기인지)는 원천 확인 전**이다 — 유형별 분해에 쓰되 그 사실을 밝히고, 의미를 추측해 설명하지 말 것. 🟢 집계행(총계 중복)은 아니다 — 광고비 합계가 전체와 겹치지 않음을 실측 확인했다',
    ad.AD_GROUP_NM    AS ad.AD_GROUP_NM    WITH SYNONYMS ('광고그룹', '그룹명') COMMENT = '광고 그룹명. 디지털 전용. 고카디널리티이며 원천 재적재로 값이 바뀐다 ⇒ 값 목록은 이 컬럼을 SELECT DISTINCT 로 조회한다(열거를 여기 박지 않는다).',
    ad.CHANNEL_COMPANY AS ad.CHANNEL_COMPANY WITH SYNONYMS ('채널사', '방송사', '매체사', '공12') COMMENT = '방송 채널사. VIDEO/REBROADCAST 전용. ⚠광고비 기준 정렬 시 광고비가 없는 채널사가 섞이므로 NULLS LAST 를 명시할 것.',
    ad.TIME_BAND       AS ad.TIME_BAND       WITH SYNONYMS ('시간대', '광고시간대') COMMENT = '방송 시간대. 방송 전용. ⚠️ 표기 형식이 원천마다 다르다 — VIDEO 는 ''N시대'' 구간 라벨, REBROADCAST 는 ''HH:MM:SS'' 시각이다(원천 재편) ⇒ 두 출처를 섞어 이 축으로 그루핑하지 말고 AD_SOURCE_TYPE 으로 먼저 나눈다.',
    ad.PROGRAM_NM      AS ad.PROGRAM_NM      WITH SYNONYMS ('프로그램', '프로그램명', '방송프로그램') COMMENT = '방송 프로그램명(고카디널리티 — Cortex Search 백킹 후보). 방송 전용.',
    ad.SPOT_TYPE       AS ad.SPOT_TYPE       WITH SYNONYMS ('스팟유형', '광고위치') COMMENT = '스팟 유형(전CM/중CM/후CM/SB). 방송 전용. 실제값 4종: ''CA''·''PR''·''SP''·''TJ'' + NULL',
    ad.CM_POSITION     AS ad.CM_POSITION     WITH SYNONYMS ('CM위치', '광고순서', '공21') COMMENT = 'CM 내 위치. 방송 전용. 실제값 16종: ''`''(🔴 **오염값** — 백틱 1문자이며 정상 CM 위치가 아니다. 이 값으로 필터하지 말 것 ··''st''·''E-2nd''·''E-3rd''·''th''·''E-5th''·''E-6th''·''E-7th''·''T-1st''·''T-2nd''·''T-3rd''·''T-4th''·''T-5th''·''T-6th''·''T-7th''·''middle'' + NULL',
    ad.RT_TYPE         AS ad.RT_TYPE         WITH SYNONYMS ('재방유형', '방송유형구분', '특집', '특집방송', '특집/재송출') COMMENT = '본방/재방 유형. REBROADCAST 전용(VIDEO 는 전건 NULL). 실제값 2종: ''재송출''·''방송'' + NULL. 🆕 [O238 W1] 질문의 「특집」 = 값 ''방송''(현업이 보고용 명칭을 「특집」→「방송」으로 합의 · 원천 값은 그대로) ⇒ 「특집」으로 물으면 RT_TYPE = ''방송'' 으로 거르고 답변에 「특집(= 방송)」으로 표기한다.',
    ad.DURATION_SEC    AS ad.DURATION_SEC    WITH SYNONYMS ('초수', '광고초수', '영상초수', '광고길이', '초', '공22') COMMENT = '방송 광고 영상 초수(초 단위, 요구사항 #22). 🔴 영상(VIDEO) 전용 — 재방송·디지털은 전건 NULL ⇒ AD_SOURCE_TYPE=''VIDEO'' 로 고정해 쓴다. 실제값 4종: 30·60·90·120 + NULL(영상 행 일부).',
    ad.BRDC_DIV AS ad.BRDC_DIV
      WITH SYNONYMS ('방송구분', '본방/재방')
      COMMENT = '방송구분(레귤러·본방송·재방송·삼방송·보상송출·송출오류) — 🔴 REBROADCAST 전용 · 디지털행은 NULL(원천 부재) ⇒ 출처유형 REBROADCAST 로 고정해 쓴다.',
    ad.CHANNEL_COMPANY_TYPE AS ad.CHANNEL_COMPANY_TYPE
      WITH SYNONYMS ('채널사유형', '방송사 유형', '공13')
      COMMENT = '채널사유형(지상파·종편·케이블·CTV·YOUTUBETV·퍼포머셜·TEADS·기타·미확인) — 🔴 VIDEO 전용 · 디지털행은 NULL ⇒ 출처유형 VIDEO 로 고정해 쓴다.',
    ad.CTV_DIV AS ad.CTV_DIV
      WITH SYNONYMS ('CTV구분', 'TV/CTV')
      COMMENT = 'CTV구분(TV·CTV·기타·미확인) — 🔴 VIDEO 전용 · 디지털행은 NULL.',
    ad.DAY_DIV AS ad.DAY_DIV
      WITH SYNONYMS ('요일구분', '주중/주말')
      COMMENT = '요일구분(주중·토·일) — 🔴 VIDEO 전용 · 디지털행은 NULL.',
    ad.MEDIA_CHANNEL_NM AS ad.MEDIA_CHANNEL_NM
      WITH SYNONYMS ('매체', '매체명', '광고 매체', '매체별', '공12')
      COMMENT = '매체/채널명 원값(YOUTUBE·META·NBRAND·EBS·GDN·MMT 등) — 디지털·영상·재방송 3원천 공통. 「매체별 광고비·성과」 질문의 1순위 축. ⚠️방송 채널사만 보려면 CHANNEL_COMPANY.',
    ad.CREATIVE_NM AS ad.CREATIVE_NM
      WITH SYNONYMS ('소재명', '광고 소재', '소재', '공20')
      COMMENT = '소재명(디지털 MATR · 영상 MATR_NM · 재방송은 방송명). 원천별 의미가 달라 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프한다.',
    ad.COST_TYPE AS ad.COST_TYPE
      WITH SYNONYMS ('비용유형', '광고비 산정 기준')
      COMMENT = '비용유형 GA(디지털)·집행(영상)·편성(재방송) 3값 — 광고비 산정 기준이 원천별로 다르다는 표시(AD_SOURCE_TYPE 과 사실상 1:1).',
    ad.BDGT_SOURCE_NM AS ad.BDGT_SOURCE_NM
      WITH SYNONYMS ('예산출처', '법인(사단/사복)', '예산 법인')
      COMMENT = '예산출처 사단·사복·통합 원값(디지털·영상). 🔴재방송은 원천 개념 없음 = NULL(결측 아님).',
    ad.MATR_TY_NM AS ad.MATR_TY_NM
      WITH SYNONYMS ('소재유형(디지털·영상)', '영상/이미지')
      COMMENT = '소재유형 원값(영상·이미지 등 · 디지털·영상). 재방송 NULL(원천 부재). ⚠️CREATIVE_TYPE 은 디지털 전용 같은 원천값 — 영상까지 보려면 이 축.',
    ad.CMPGN_TYPE_BSN_NM AS ad.CMPGN_TYPE_BSN_NM
      WITH SYNONYMS ('캠페인유형', '사업유형', '국내/해외 사례', '공17')
      COMMENT = '캠페인유형(사업) 원값 6종: 국내 사례·국내 사업·해외 사례·해외 굿즈·통합 기타·통합 통합 [디지털 전용 · 방송 NULL].',
    ad.UTM_CMPGN_NM AS ad.UTM_CMPGN_NM
      WITH SYNONYMS ('UTM 캠페인', 'UTM 태그')
      COMMENT = 'UTM 캠페인 태그 원값(turn24b·children2406 등) [디지털 전용].',
    ad.BSNS_CASE_DIV_NM AS ad.BSNS_CASE_DIV_NM
      WITH SYNONYMS ('사업/사례 구분', '영상 소재 구분', '공16')
      COMMENT = '사업/사례 구분 원값 사례·굿즈·사업·기타 [영상 전용 · 그 밖 NULL].',
    ad.CM AS ad.CM
      WITH SYNONYMS ('CM 구분', '전CM/중CM/후CM')
      COMMENT = 'CM 구분 원값 전CM·중CM·후CM·전SPOT CM·후SPOT CM [영상 전용]. ⚠️CM_POSITION(CM 위치)과 다른 원천 컬럼.',
    ad.DMST_OVSEA_DIV_NM AS ad.DMST_OVSEA_DIV_NM
      WITH SYNONYMS ('국내/해외', '국내해외 구분', '공15')
      COMMENT = '국내/해외 구분 원값 국내·해외·통합 [영상 전용 · 그 밖 NULL].',
    --  [2026-10-15 O232-B] 광고비 귀속 카테고리(전 광고행 단일 축 · 원천 CRM 캠페인카테고리 MM294)
    ad.AD_CTGR_NM AS ad.AD_CTGR_NM
      WITH SYNONYMS ('광고비 귀속 카테고리', '캠페인 카테고리', '캠페인카테고리', '카테고리별 광고비')
      COMMENT = '광고비 귀속 캠페인카테고리명(원천 CRM 캠페인카테고리). 이름매칭·UTM 으로 마케팅캠페인에 연결된 행 = 그 마케팅캠페인의 대표 카테고리 · 연결되지 않은 재방송·영상 행 = 소재 매핑 확정 카테고리 · 귀속 없음 = NULL. 🔴 대표값이 섞여 있다 — 카테고리별 광고비를 답할 때 AD_CTGR_IS_MULTI = TRUE 광고비 비중과 NULL(귀속 없음) 광고비를 함께 밝힌다.',
    ad.AD_CTGR_CD AS ad.AD_CTGR_CD
      WITH SYNONYMS ('카테고리 코드', '캠페인카테고리 코드')
      COMMENT = '광고비 귀속 캠페인카테고리 코드(MM294 · AD_CTGR_NM 과 1:1).',
    ad.AD_CTGR_SRC AS ad.AD_CTGR_SRC
      WITH SYNONYMS ('카테고리 귀속 출처', '카테고리 출처')
      COMMENT = '카테고리 귀속 출처. 실제값 3종: ''MKTG_REP''(마케팅캠페인 대표값)·''CREATIVE_MAP''(소재 매핑 확정)·''NONE''(귀속 없음).',
    ad.AD_CTGR_IS_MULTI AS ad.AD_CTGR_IS_MULTI
      WITH SYNONYMS ('카테고리 대표값 여부', '카테고리 다중')
      COMMENT = 'TRUE = 마케팅캠페인 아래 카테고리가 여럿이라 대표값을 쓴 행. CREATIVE_MAP = FALSE · NONE = NULL.',
    --  [2026-10-15 O233 #36] 표시 전용 카테고리명 나열(그루핑·필터 금지)
    ad.AD_CTGR_NM_LIST AS ad.AD_CTGR_NM_LIST
      WITH SYNONYMS ('카테고리 전체 목록', '해당 카테고리 전부')
      COMMENT = '광고비 귀속 카테고리명 나열(쉼표 구분 · 첫 항목 = AD_CTGR_NM). 🔴 표시 전용 — GROUP BY·WHERE·합산에 쓰지 않는다(집계는 AD_CTGR_NM). 다중 캠페인이 어떤 카테고리에 걸쳐 있는지 보여줄 때만 함께 SELECT 한다.'
  )
  METRICS (
    ad.TOTAL_AD_COST   AS SUM(ad.AD_COST)
      WITH SYNONYMS ('광고비', '광고비 총액', '매체비', '공6', '신규10') COMMENT = '광고비 합계(원). F(가산). 디지털+방송 합산 가능.',
    ad.TOTAL_IMPRESSIONS AS SUM(ad.IMPRESSIONS)
      WITH SYNONYMS ('노출수', '노출', '임프레션', '공23') COMMENT = '노출수 합계. F(가산). 디지털 전용(방송은 NULL).',
    ad.TOTAL_CLICKS AS SUM(ad.CLICKS)
      WITH SYNONYMS ('클릭수', '클릭', '공24') COMMENT = '클릭수 합계. F(가산). 디지털 전용(방송은 NULL).',
    ad.TOTAL_INBOUND_CALL AS SUM(ad.INBOUND_CALL)
      WITH SYNONYMS ('인바운드콜', '전화문의', '콜수', '공25') COMMENT = '인바운드 전화 건수 합계. F(가산). 방송 전용(디지털은 NULL) — VIDEO·REBROADCAST 모두 존재.',
    ad.TOTAL_AGENCY_CONV_MEMBERS AS SUM(ad.AGENCY_CONV_MEMBERS)
      WITH SYNONYMS ('대행사전환회원', '전환회원수', '대행사전환') COMMENT = '대행사 전환 회원수 합계. F(가산). 디지털 전용.',
    ad.CTR AS SUM(IFF(ad.IMPRESSIONS > 0, ad.CLICKS, 0)) / NULLIF(SUM(ad.IMPRESSIONS), 0) * 100
      WITH SYNONYMS ('클릭률', 'CTR') COMMENT = '공9 CTR(%) = 클릭수 ÷ 노출수 ×100. 비율(N). 디지털 전용. 🔴 O240: 노출 0·클릭>0 행(DIGITAL · 추적링크 직접유입)의 클릭은 분자에서 뺀다 — 분모 없는 클릭이 소재별 CTR 을 상한(전량 클릭) 이상으로 만든다. 전체 클릭수는 TOTAL_CLICKS 로 따로 답한다.',
    ad.CVR AS SUM(ad.AGENCY_CONV_MEMBERS) / NULLIF(SUM(ad.CLICKS), 0) * 100
      WITH SYNONYMS ('전환율', 'CVR') COMMENT = '공10 CVR(%) = 대행사전환회원 ÷ 클릭수 ×100. 비율(N). 디지털 전용.',
    ad.TOTAL_CRM_DEV_CNT AS SUM(ad.CRM_DEV_CNT)
      WITH SYNONYMS ('CRM개발건', 'CRM 개발건수', '디지털개발건', '공4') COMMENT = 'CRM 개발건수 합계(디지털). F(가산). ⚠원천에 비정수(소수) 값이 섞여 있어 기여도 배분값일 가능성이 있다 → "건수"로 정수 단정 금지(어의 미확정). ⚠원천이 개발건수 제공을 중단하고 단가를 직접 제공하는 포맷으로 바뀐 시점 이후는 미적재다 — 적재 구간은 데이터에서 확인할 것. 🔴 원천 CRM_DEV_CNT 가 비어 있으면 이 지표는 NULL 이다 — NULL 을 0·추정치로 바꾸지 말고 「원천 미적재로 산출 불가」라고 답한다.',
    ad.DEV_UNIT_PRICE AS SUM(CASE WHEN ad.CRM_DEV_CNT IS NOT NULL THEN ad.AD_COST END) / NULLIF(SUM(ad.CRM_DEV_CNT), 0)
      WITH SYNONYMS ('개발단가', 'CPA', '건당 광고비') COMMENT = '공7 디지털 개발단가(원) = 광고비 ÷ CRM개발건. 비율(N). DIGITAL 전용. 분자를 개발건수 적재행으로 정합(미적재행 광고비 제외). ⚠원천 포맷 변경 이후 구간은 개발건수가 없어 산출 불가(NULL) — 산출 가능한 최신 구간은 데이터에서 확인할 것. 🔴 분모 CRM_DEV_CNT 가 비어 있으면 전 구간 NULL 이다 — 다른 단가로 대체하지 말고 「원천 미적재로 산출 불가」라고 답하며 대안으로 GA 개발단가(공8)를 별도 지표로 안내한다.',
    ad.GA_DEV_UNIT_PRICE AS SUM(CASE WHEN ad.AGENCY_CONV_CNT IS NOT NULL THEN ad.AD_COST END) / NULLIF(SUM(ad.AGENCY_CONV_CNT), 0)
      WITH SYNONYMS ('GA 개발단가', 'GA CPA', 'GA 건당 광고비', '공8') COMMENT = '공8 GA 개발단가(원) = GA 광고비 ÷ GA 개발(건). 분모 = 대행사 리포트의 GA 전환(건). 비율(N). DIGITAL 전용(방송은 분모가 없어 NULL). 분자를 분모 적재행으로 정합. ⚠소수 전환값을 반올림하지 않는다. ⚠GA4 이벤트(BigQuery) 기반 후원건과는 규모가 다르다 — 이 지표의 분모는 대행사 보고값이다.',
    ad.GA_DEV_CNT AS SUM(ad.AGENCY_CONV_CNT)
      WITH SYNONYMS ('GA 개발(건)', 'GA 개발건수', '일별리포트 개발건수', '일별리포트 개발(건)', 'GA 전환(건)', '공5') COMMENT = '일별리포트(대행사 디지털 리포트) GA 개발(건) 합계 = 공8 GA 개발단가의 분모. F(가산). DIGITAL 전용(방송 NULL). 「GA·일별리포트」를 명시한 개발건수 질문에 쓴다(사용자 결정 A) — 명시가 없으면 MSTR 개발(건) 소관이다. ⚠소수 값이 섞여 있어 정수 건수로 단정하지 않는다. 🔴 MSTR 개발(건)·CRM 개발건과 한 표에서 합산·비교하지 않는다. 매체(META 등)별은 MEDIA_CHANNEL_NM 축.',
    ad.TOTAL_READ_CNT AS SUM(ad.READ_CNT)
      WITH SYNONYMS ('조회수', '열람수', '읽기수') COMMENT = '콘텐츠 조회수 합계(디지털). F(가산).',
    ad.TOTAL_MEDIA_POTENTIAL AS SUM(ad.MEDIA_POTENTIAL_CUST_CNT)
      WITH SYNONYMS ('매체잠재고객수', '잠재고객') COMMENT = '매체 잠재고객수 합계(디지털). F(가산). 🔴 원천 MEDIA_POTENTIAL_CUST_CNT 가 비어 있으면 NULL 이다 — 0·추정치로 답하지 말고 「원천 미적재로 산출 불가」라고 답한다.',
    ad.TOTAL_AD_CNT AS SUM(ad.AD_CNT)
      WITH SYNONYMS ('방송횟수', '광고집행횟수', '편성횟수') COMMENT = '방송 광고 집행 횟수 합계. F(가산). VIDEO/REBROADCAST 전용.',
    ad.TOTAL_DVLP_CNT AS SUM(ad.DVLP_CNT)
      WITH SYNONYMS ('재방송개발건', '방송개발건', '방송 개발회원건수') COMMENT = '방송 개발건수 합계(대행사 보고). F(가산). VIDEO·REBROADCAST 전용(디지털은 NULL). 🔴 VIDEO 도 개발건을 보고한다(일부 행만 채워짐 · 미보고 행은 NULL). ⚠️ 두 대행사 리포트의 개발 정의가 같은지는 원천 확인 전이다 ⇒ 합계를 물으면 AD_SOURCE_TYPE 별로 나눠 함께 보여준다.',
    ad.TOTAL_DVLP_MEMBER_CNT AS SUM(ad.DVLP_MEMBER_CNT)
      WITH SYNONYMS ('재방송개발회원', '방송개발회원', '방송 개발회원수') COMMENT = '방송 개발회원수 합계(대행사 보고). F(가산). VIDEO·REBROADCAST 전용 — VIDEO 는 일부 행만 채워짐.',
    ad.REBRDC_DEV_UNIT_PRICE AS SUM(CASE WHEN ad.DVLP_CNT IS NOT NULL THEN ad.AD_COST END) / NULLIF(SUM(ad.DVLP_CNT), 0)
      WITH SYNONYMS ('재방송 개발단가', '재방송 CPA', '재방송 건당 광고비') COMMENT = '재방송 개발단가(원) — 참고 지표(공8 아님 · 공8 은 GA_DEV_UNIT_PRICE) = 재방송 광고비 ÷ 재방송 개발건. 비율(N). **REBROADCAST 전용**(방송 전체 단가가 아님 · VIDEO 단가는 이 metric 의 범위 밖). 분자를 개발건수 적재행으로 정합. ⚠`AD_SOURCE_TYPE=''REBROADCAST''` 필터 전제 — VIDEO 혼합 시 과대계상된다.'
  )
  COMMENT = 'Phase-1 광고 실적 SV (base: GOLD.WIDE_AD_COMBINED). 대행사(디지털/방송) 일별 리포트 및 GA4 기반 광고비, 노출, 클릭, 전환, 방송실적 통합 뷰. ⚠️ 디지털/방송 measure는 상호배타적이며, 광고비만 전체 합산 가능. 마케팅캠페인(MKTG_CAMPAIGN_NAME) 축으로 분해 가능(소재별/개별캠페인별 분해 불가). 예산(SV_BUDGET) 및 회원개발실적(SV_MEMBER_EVENT)과의 교차 집계는 불가.'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O241-R 반올림 · 전 SV 공통] 최종 SELECT 에서 비율(%)·평균·확률·초·기여도 등 소수 값은 ROUND(<식>, 2)::NUMBER(38,2) 로 반올림해 출력한다(FLOAT 그대로 두면 0.98999… 처럼 보이므로 NUMBER 로 캐스팅한다 · 집계 식 바깥에 씌우며 정렬·필터에는 원래 식을 쓴다). 금액·건수·명수는 숫자형 그대로 둔다(문자열로 바꾸지 않는다 — 쉼표는 답변 작성 단계에서 붙인다). [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙 · O259 개정] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 단 표에 합계·소계 행을 붙이지 않는다(ROLLUP·CUBE·GROUPING SETS 금지 · 평면 GROUP BY 만). 전체 합이 필요하면 행이 아니라 같은 SELECT 의 열로 붙인다(SUM(SUM(x)) OVER () · COUNT DISTINCT·HAVING 이 있으면 그룹 없는 CTE 를 CROSS JOIN) — 답변에서는 그 열을 표에 싣지 않고 표 밖 본문 1줄로 적는다. 비율은 분자·분모 measure 를 열로 함께 낸다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 출처 필터: 노출·클릭·CTR·CVR·CRM개발건·개발단가(공7)·조회수·잠재고객 질의는 AD_SOURCE_TYPE=''DIGITAL'' 자동 추가. 인바운드콜·방송횟수·방송 개발건수·방송 개발회원수는 AD_SOURCE_TYPE IN (''VIDEO'',''REBROADCAST'') 추가하고 개발건수는 출처별로 나눠 반환. GA 개발단가(공8)·GA 개발(건)(GA_DEV_CNT)은 AD_SOURCE_TYPE=''DIGITAL'' 추가. 재방송 개발단가(참고 · 공8 아님)는 AD_SOURCE_TYPE=''REBROADCAST'' 추가. 광고비만 전체 합산 허용. (2) 기간 미지정 시: 최신 데이터 연월 기준 직전 12개월로 한정하며 연·월 평면 GROUP BY 로 반환(합계 행 없음). (3) 캠페인 분해: MARKETING_CAMPAIGN 축으로 그루핑하며 ''(미매핑)'' 버킷 존재로 캠페인별 합계 < 전체 합계임을 명시. 🆕 (O230 · 0원 단정 금지) 캠페인별 질문은 미매핑 버킷을 0·산출 불가로 두지 말고 AD_SOURCE_TYPE 별로 나눈 뒤 원천 축으로 분해한 결과를 함께 반환한다 — REBROADCAST·VIDEO·DIGITAL 미매핑 행은 ad.CREATIVE_NM(재방송 = 방송명) 으로 그루핑하고(VIDEO 는 ad.PROGRAM_NM 도 가능), 연결분 + 미매핑 분해의 합이 같은 기간 TOTAL_AD_COST 와 같아야 한다. 방송명을 특정 마케팅캠페인 값으로 바꾸거나 합치지 않는다. 소재별 및 개별 개발캠페인별 ROI/단가는 생성 거부 및 사유 안내. (4) 기기 필터: 모바일은 DEVICE_TYPE=''M'', 데스크톱은 ''PC''. 방송은 ''(해당없음)''. (5) 정렬: 방송 차원 광고비 기준 정렬 시 ORDER BY ... DESC NULLS LAST 사용. (기준시점 규칙) 「최근 N주·N개월」·기간 미지정 질의의 기준 시점은 **비상관 CTE 1개**에서 그 CTE 의 FROM 에 쓴 이름으로만 MAX 를 구하고 본 쿼리에 CROSS JOIN 한다. 스칼라·상관 서브쿼리로 기준 시점을 구하지 않는다. 광고 성과일은 ad 에 없다 — date.FULL_DATE(ad.PERF_DATE_SK = date.DATE_SK 조인)로만 건다(ad.PERF_DATE 는 없다). metric 이름을 컬럼처럼 참조하지 말고 정의식으로 집계한다. ORDER BY 에는 SELECT 별칭을 글자 그대로 쓴다. (전년대비) 전년 대비는 월(또는 주) 집계 CTE 를 만든 뒤 **그 CTE 를 연도-1 로 자기조인**한다(LAG 는 빠진 월이 있으면 어긋난다). 디지털 광고는 2024-01 부터 적재돼 있으므로 「전년 데이터 없음」으로 답하지 않는다. 광고와 개발실적의 전년 대비를 함께 물으면 이 SV(광고)와 SV_MEMBER_EVENT(개발)를 **각각 호출해 월 단위로 나란히** 보여주고, 한 SQL 로 조인하지 않는다(교차 집계 불가). (소속 테이블) 마케팅캠페인 축은 **mktg.MARKETING_CAMPAIGN** 이다 — ad 테이블에 없다(ad.MARKETING_CAMPAIGN 은 invalid identifier) ⇒ ad JOIN mktg ON ad.MKTG_CAMPAIGN_SK = mktg.MKTG_CAMPAIGN_SK 로 붙인다. 기기 축은 device.*, 날짜 축은 date.* 소속이다. (🆕 O225-C 캠페인 속성 분해) 광고비는 마케팅캠페인 단위로만 붙어 있다 — UTM(MKTG_UTM_NM)·국내/해외·사업/사례별로는 이 SV 로 나눈다(국내/해외·사업/사례는 대표값이므로 *_IS_MULTI 비중을 밝힌다). 🔴 캠페인 인입경로·마케팅채널별 광고비는 이 SV 로 내지 않는다 — 마케팅캠페인 하나 아래 값이 갈리는 비중이 커서(실측은 이슈원장 §O225) 대표값이 왜곡된다. 그 축의 성과(개발·회비)는 회원 측 SV(SV_MEMBER_EVENT·SV_MEMBER_FEE·SV_PAYMENT_BILLING_STATUS)로 안내한다.
  (🆕 O232-B 카테고리별 광고비) 캠페인 카테고리별 광고비는 ad.AD_CTGR_NM 으로 그루핑한다(mktg 축이 아니라 ad 축 — 미연결 재방송·영상의 소재 매핑 카테고리까지 포함한다). 반드시 같은 쿼리에서 ① 카테고리별 TOTAL_AD_COST ② 그중 AD_CTGR_IS_MULTI = TRUE 광고비(대표값 · 실제로는 여러 카테고리에 걸친 캠페인) ③ AD_CTGR_NM IS NULL(귀속 없음) 광고비를 함께 반환하고, 카테고리 합 + 귀속 없음 = 같은 기간 전체 광고비임을 맞춘다. 대표값 광고비를 다른 카테고리로 나누거나 배분하지 않는다.'
  AI_VERIFIED_QUERIES (
    vqr_o232b_ad_cost_by_category AS (
      QUESTION '캠페인 카테고리별 광고비(대표값·귀속 없음 포함)'
      VERIFIED_BY '(DW = O232-B)'
      SQL 'SELECT AD_CTGR_NM AS "캠페인카테고리", TOTAL_AD_COST AS "광고비(원)", MULTI_REP_AD_COST AS "복수 카테고리 대표값 광고비(원)" FROM (SELECT COALESCE(ad.AD_CTGR_NM, ''(귀속 없음)'') AS AD_CTGR_NM, SUM(ad.AD_COST) AS TOTAL_AD_COST, SUM(CASE WHEN ad.AD_CTGR_IS_MULTI THEN ad.AD_COST END) AS MULTI_REP_AD_COST FROM ad GROUP BY COALESCE(ad.AD_CTGR_NM, ''(귀속 없음)'') ORDER BY TOTAL_AD_COST DESC NULLS LAST) ORDER BY TOTAL_AD_COST DESC NULLS LAST'
    ),
    vqr_ad_cost_by_source AS (
      QUESTION '출처유형별 광고비 합계'
      VERIFIED_BY '(DW = O190)'
      SQL 'SELECT AD_SOURCE_TYPE AS "출처유형", TOTAL_AD_COST AS "광고비(원)" FROM (SELECT ad.AD_SOURCE_TYPE, SUM(ad.AD_COST) AS TOTAL_AD_COST FROM ad GROUP BY ad.AD_SOURCE_TYPE ORDER BY TOTAL_AD_COST DESC NULLS LAST) ORDER BY TOTAL_AD_COST DESC NULLS LAST'
    ),
    vqr_o191_digital_weekly_ctr AS (
      QUESTION '최근 8주 디지털 광고 주차별 노출·클릭·CTR'
      VERIFIED_BY '(DW = O191)'
      SQL 'SELECT YEAR AS "연도", WEEK_OF_YEAR AS "주차", TOTAL_IMPRESSIONS AS "노출수(회)", TOTAL_CLICKS AS "클릭수(회)", ROUND(CTR, 2)::NUMBER(38,2) AS "클릭률(%)" FROM (WITH mx AS (SELECT MAX(date.FULL_DATE) AS md FROM ad JOIN date ON ad.PERF_DATE_SK = date.DATE_SK WHERE ad.AD_SOURCE_TYPE = ''DIGITAL'') SELECT date.YEAR, ad.WEEK_OF_YEAR, SUM(ad.IMPRESSIONS) AS TOTAL_IMPRESSIONS, SUM(ad.CLICKS) AS TOTAL_CLICKS, SUM(ad.CLICKS) / NULLIF(SUM(ad.IMPRESSIONS), 0) * 100 AS CTR FROM ad JOIN date ON ad.PERF_DATE_SK = date.DATE_SK CROSS JOIN mx WHERE ad.AD_SOURCE_TYPE = ''DIGITAL'' AND date.FULL_DATE > DATEADD(WEEK, -8, mx.md) GROUP BY date.YEAR, ad.WEEK_OF_YEAR ORDER BY date.YEAR, ad.WEEK_OF_YEAR) ORDER BY YEAR, WEEK_OF_YEAR'
    ),
    vqr_o191_digital_monthly_yoy AS (
      QUESTION '디지털 광고 월별 노출·클릭·광고비 전년 동월 대비'
      VERIFIED_BY '(DW = O191)'
      SQL 'SELECT YR AS "연도", MN AS "월", IMP AS "노출수(회)", IMP_PREV_YEAR AS "전년 동월 노출수(회)", CLK AS "클릭수(회)", CLK_PREV_YEAR AS "전년 동월 클릭수(회)", COST AS "광고비(원)", COST_PREV_YEAR AS "전년 동월 광고비(원)", ROUND(CLK_YOY_PCT, 2)::NUMBER(38,2) AS "클릭수 전년 대비 증감률(%)", ROUND(COST_YOY_PCT, 2)::NUMBER(38,2) AS "광고비 전년 대비 증감률(%)" FROM (WITH m AS (SELECT date.YEAR AS YR, date.MONTH AS MN, SUM(ad.IMPRESSIONS) AS IMP, SUM(ad.CLICKS) AS CLK, SUM(ad.AD_COST) AS COST FROM ad JOIN date ON ad.PERF_DATE_SK = date.DATE_SK WHERE ad.AD_SOURCE_TYPE = ''DIGITAL'' GROUP BY date.YEAR, date.MONTH) SELECT c.YR, c.MN, c.IMP, p.IMP AS IMP_PREV_YEAR, c.CLK, p.CLK AS CLK_PREV_YEAR, c.COST, p.COST AS COST_PREV_YEAR, (c.CLK - p.CLK) / NULLIF(p.CLK, 0) * 100 AS CLK_YOY_PCT, (c.COST - p.COST) / NULLIF(p.COST, 0) * 100 AS COST_YOY_PCT FROM m c LEFT JOIN m p ON p.YR = c.YR - 1 AND p.MN = c.MN ORDER BY c.YR, c.MN) ORDER BY YR, MN'
    )
  );

-- GRANT — SV 재배포(CREATE OR ALTER) 뒤에도 함께 실행
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_AD TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_AD TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_AD TO ROLE GN_DW_SERVICE;

USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 스모크(배포 확인 · 배포 러너는 실행하지 않는다)
SELECT (SELECT TOTAL_AD_COST FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_AD METRICS TOTAL_AD_COST)) AS sv_val,
       (SELECT SUM(AD_COST)  FROM GN_DW.GOLD.FACT_AD_PERFORMANCE)                           AS fact_val;

SELECT (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_AD_PERFORMANCE) AS fap,
       (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_AD_DIGITAL)     AS dig,
       (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_AD_BROADCAST)   AS brc,
       (SELECT COUNT(*) FROM GN_DW.GOLD.WIDE_AD_COMBINED) AS combined;

SELECT CAL_YEAR, AD_SOURCE_TYPE, TOTAL_AD_COST, CTR, CVR, DEV_UNIT_PRICE
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_AD
  DIMENSIONS date.CAL_YEAR, ad.AD_SOURCE_TYPE
  METRICS TOTAL_AD_COST, CTR, CVR, DEV_UNIT_PRICE
)
WHERE AD_SOURCE_TYPE = 'DIGITAL'
ORDER BY 1;

SELECT AD_SOURCE_TYPE, DEVICE_TYPE, TOTAL_AD_COST, TOTAL_CLICKS, TOTAL_INBOUND_CALL, TOTAL_AD_CNT
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_AD
  DIMENSIONS ad.AD_SOURCE_TYPE, device.DEVICE_TYPE
  METRICS TOTAL_AD_COST, TOTAL_CLICKS, TOTAL_INBOUND_CALL, TOTAL_AD_CNT
)
ORDER BY 1, 2;

SELECT CHANNEL_COMPANY, TOTAL_AD_COST, TOTAL_INBOUND_CALL, TOTAL_AD_CNT, TOTAL_DVLP_CNT
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_AD
  DIMENSIONS ad.CHANNEL_COMPANY
  METRICS TOTAL_AD_COST, TOTAL_INBOUND_CALL, TOTAL_AD_CNT, TOTAL_DVLP_CNT
)
WHERE CHANNEL_COMPANY IS NOT NULL
ORDER BY TOTAL_AD_COST DESC NULLS LAST
LIMIT 10;
