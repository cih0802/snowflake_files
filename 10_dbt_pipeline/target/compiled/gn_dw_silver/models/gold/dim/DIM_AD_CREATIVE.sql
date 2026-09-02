-- DIM_AD_CREATIVE: 광고소재/매체 차원 (SILVER.AGENCY_AD_CREATIVE 3소스 UNION → GOLD 소재차원), 순서9-C 신설.
-- Co-authored with CoCo
-- 매핑 가정(순서9-C 데이터 실측): PLATFORM=SOURCE_SYSTEM(DIGITAL/VIDEO/REBROADCAST 매체구분) · AD_TYPE=소재유형(CREATIVE_TYPE_NM)
--   · CM_POSITION=CM_AREA_NM · MEDIA_NAME=MEDIA_CHANNEL_NM · CREATIVE=CREATIVE_NM.
-- 🔴 [2026-09-01 O129 주석 회수] 종전 이 자리에 있던
--   *"원천 부재 → NULL: PLATFORM_TYPE·RT_TYPE·TARGET_GROUP (AGENCY 원천 미보유. 입고/현업 확인 시 채움)"* 는
--   **세 컬럼을 한 문장으로 뭉갠 것이고 그중 `RT_TYPE` 은 거짓이었다**(`R2-7-2` 위반 · `P14` 3회차).
--   ⇒ 사유는 **컬럼별로** 아래 각 산출 줄에 적는다. 정본(사유·처분·근거 좌표) = **문서30 §7-C-1**.
--   🔴 사유의 정본은 **컬럼 COMMENT(`06_DDL.sql`)** 이고 이 주석은 포인터다 — 두 곳에 쓰면 한 곳이 낡는다.
-- 🔴 [O29 2026-08-04 주석 회수] `DURATION_SEC` 를 위 "원천 부재" 목록에 넣은 것은 **거짓이었다** —
--   원천은 실재한다: SILVER `AGENCY_AD_CREATIVE.AD_SEC_NM` VIDEO 1,217/1,279=95.2% ·
--   BRONZE `VIDEO_AD_CMPGN_DTLS.AD_SEC` 33,890/36,416=93.1%. (P14 위반 사례)
--   🔴 그러나 **채움이 정답이 아니었다** — 같은 축이 `FACT_AD_BROADCAST.DURATION_SEC` 에 이미
--   배선돼 있다(§18-D ① 같은 역할 컬럼 우선).
-- ✅ [DEC-30] 판정 완료 = **중복축 DROP**. `06_DDL.sql` 에서 컬럼이 제거됐다(오배치 중복축).
--   🔴 [2026-08-04 O30] 그런데 이 모델은 계속 `CAST(NULL) as DURATION_SEC` 를 산출하고 있었다.
--   dbt incremental append 는 **대상 테이블에 없는 산출 컬럼을 에러 없이 버린다** → 2회 빌드 동안
--   무증상으로 폐기됐다(P57). 산출 자체를 제거해 모델과 정본 DDL 을 일치시킨다.
--   초수 정본 소재지 = `FACT_AD_BROADCAST.DURATION_SEC`(방송 grain).
--   DW_SOURCE_SYSTEM='AGENCY' 상수(A-2/Q9: 행단위 대행사/GoogleAds 구분 불요 — GoogleAds 는 GA4 트랙).


with s as (
    select * from GN_DW.SILVER.AGENCY_AD_CREATIVE
)

select
    ABS(HASH(COALESCE(CAST(CREATIVE_DK AS VARCHAR), '∅')))    as AD_CREATIVE_SK,
    CREATIVE_DK                       as AD_CREATIVE_BK,
    MEDIA_CHANNEL_NM                  as MEDIA_NAME,
    SOURCE_SYSTEM                     as PLATFORM,        -- 매체구분(DIGITAL/VIDEO/REBROADCAST)
    -- 🟢 [O129] 「원천 부재」 = 참. BRONZE AGENCY 3테이블에 「매체유형」 축이 없고, 인접 유형축
    --    (AD_TY_NM·MATR_TY_NM·PAGE_TYPE_NM)은 전부 다른 목적지에 배선돼 대체물이 아니다.
    --    요건 #13 은 살아 있으므로 현업 확인 대상이다. 정본 = 문서30 §7-C-1.
    CAST(NULL AS VARCHAR)             as PLATFORM_TYPE,
    CREATIVE_NM                       as CREATIVE,
    CM_AREA_NM                        as CM_POSITION,
    -- 🔴🔴 [O129-B 2026-09-01] RT_TYPE 산출 제거 — DEC-30 과 **동일 유형의 오배치 중복축**이었다.
    --    종전 주석의 「원천 부재」는 거짓이었다: REBRDC_AD_CMPGN_DTLS.RE_BRDC_TY_NM 이 실재한다.
    --    정본 소재지 = FACT_AD_BROADCAST.RT_TYPE(DEC-8 방송 degen 위성 이관 · 도달 실측 완료).
    --    ⚠️ 이 차원의 AD_TYPE 에도 같은 원천이 흘러오지만 그것은 3원천 혼합축이므로 대체축이 아니다.
    --    드랍 근거 = 소비처 0(WIDE 노출 0 · SV_AD 의 ad.RT_TYPE 은 WIDE_AD_COMBINED 의 위성 계열).
    --    🔴 P57 재발 방지 = 정본 DDL(06_DDL.sql)·라이브 ALTER·본 모델을 같은 세션에 맞췄다. 상세 = 문서30 §7-C-1.
    CREATIVE_TYPE_NM                  as AD_TYPE,         -- 소재/광고유형(3원천 혼합축)
    -- 🟠 [O129] AGENCY 원천 부재는 참이나 **정본 트랙은 GA4** 다 — 잠재고객(타겟그룹)은 원천표기 GA →
    --    GA4_USER 에서 정제 예정(phase-2 미착수) ⇒ 대행사 축으로는 영구 NULL. 정본 = 문서30 §7-C-1.
    CAST(NULL AS VARCHAR)             as TARGET_GROUP,
    'AGENCY'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'd38ba6a1-836d-4cd8-ac8f-ef838313ba18'                    AS DW_BATCH_ID
from s

union all
-- unknown 멤버(SK=0): FACT_AD_PERFORMANCE.AD_CREATIVE_SK 미매핑 조인 유실 방지 센티넬
--   컬럼 9개 = SK·BK·MEDIA_NAME·PLATFORM·PLATFORM_TYPE·CREATIVE·CM_POSITION·AD_TYPE·TARGET_GROUP
--   (DURATION_SEC 제거로 10 → RT_TYPE 제거[O129-B]로 9. NULL 은 7개.
--    🔴 위 select 목록과 개수가 어긋나면 UNION 이 컴파일 실패한다 — 컬럼을 지울 때 이 줄을 같이 고쳐라)
select 0, '(미매핑)', NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    'AGENCY'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'd38ba6a1-836d-4cd8-ac8f-ef838313ba18'                    AS DW_BATCH_ID