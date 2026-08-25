-- FACT_MEMBER_MONTHLY: 회원 월 팩트 (billing ∪ FME 스파인) — A1: 개발/중단 FME 롤업 + HAS_BILLING 출처플래그
-- Co-authored with CoCo
-- [2026-08-03 O27/DEC-28] 회비 3분해(#66·#67·#68) 실배선 — 종전 `0` 하드코딩 폐기.
--   원천 `CRM_PAYMENT_BILLING.MBRFEE_DIV_CD`(PM010) 97.6% 채움 · 정본 정의는 billing CTE 주석 참조.
--   🔴 3컬럼 합 ≠ PAID_FEE (선물금 G·긴급구호 U 는 정본 정의상 미귀속) — 검산식은 CTE 주석에 실측치로 병기.
-- ✅ A1(2026-07-21): 스파인 = 회비(CRM_PAYMENT_BILLING) ∪ 개발/중단(FACT_MEMBER_EVENT 월 롤업).
--    · 개발/중단이 난 달(납입無 ~2.26M 월×회원)도 포함 → DEV/STOP 온전 집계(과소집계 해소).
--    · HAS_BILLING=TRUE  → 구 billing 스파인(≈37.79M)과 동일. 회비/청구/미납 지표 불변. (보수적 소비: WHERE HAS_BILLING)
--    · HAS_BILLING=FALSE → 개발/중단만 있는 월(회비 measure NULL). (정확 소비: 필터 없이 전체)
-- ⚠️ 스캐폴드 잔여(전건 0/NULL): ACTIVE/증감/누계/미납건·CAMPAIGN/PAYMENT_SK·DEV_TYPE·밴드·플래그
--    → 상태이력(CRM_MEMBER_STATUS_HIST)·금액변경(CRM_MEMBER_AMT_CHANGE) 원천 + O8 grain 규칙(B2) 후속.
-- ✅ DEC-41(2026-08-20 O92): SPONSORSHIP_SK 배선 — **그 달 후원사업이 하나로 확정된 월만** 채운다.
--    · 다중 사업 월은 `SPONSORSHIP_SK=0`(센티넬) 유지 + `IS_MULTI_SPONSORSHIP=TRUE` 로 표시한다.
--    · 🔴 대표 규칙(최대 납입액·최빈 등)을 쓰지 않는다 — 금액 기준은 다중 월의 상당 비율에서 **동점**이라
--      결정되지 않고, 2차 tiebreak 는 업무 의미 없는 임의 규칙이 된다(P21 창작 금지).
--      판정 근거·실측 수치는 **`20_issue/30_설계_의사결정.md` §28**(DEC-41)에만 둔다(R2-6 = 코드에 수치 금지).
--    · 🔴 이 결정은 후원사업 축 한정이다 — `PAYMENT_SK`(별건·O51-D-P1 연동)·`CAMPAIGN_SK`(B3 원천 부재)는 그대로 0.
--    · 🔴 `FME.SPONSORSHIP_SK`(STOP 한정)와 **규칙을 합치지 말 것** — 그쪽은 사건 grain 이고 동시중단 팬아웃이 있다.
-- ✅ W3(DEC-24, 2026-07-31): REASON_SK 배선 — 미납(F) 대표사유 = 최종차수(MBRFEE_SQNC 최대)의 결과코드.
--    코드그룹 매핑(SETLE_CD→PM002/PM032/PM018/PM033/PM019) + DIM_REASON 해시 조인.
--    🔴 F 행에 한정. S 행 매핑 시 라벨 의미 역전 — 절대 금지.
--    ⚠️ 대표 1개로 축약하므로 복수사유 1.45% 소실. 사유분포분석은 SILVER 직접 조회.
-- ✅ W4(DEC-22, 2026-07-31): ML 파생 4종 배선.
--    요건1 = AMT_INCREASE/DECREASE_CUM_CNT (월말까지 누적 증/감액 이력 횟수, CRM_MEMBER_AMT_CHANGE)
--    요건3 = PAID_SPONSOR_BIZ_CNT·IS_MULTI_PAID_BIZ (그 달 납입 발생 사업수, 회비·PAY_AMT>0 한정)
--    🔴 정본 (건)=약정금액÷10,000 과 다른 실제 개수·횟수 — INCREASE_CNT(#151)·DECREASE_CNT(#38)와 혼용 금지(CONF-2).
--    ⚠️ 요건2(연속미납횟수)는 스파인 sparse(gap>1 3.94%·최대370개월)로 run-length 오판 → W4 제외, dense 스파인 선행 필요.
-- ⚠️ DEV_CNT = FME 사건수(금액/10000 아님 — 06_DDL 주석/별도트랙).
-- 순서9(G-1/G-2 해소): incremental+append+pre-hook TRUNCATE(dbt_project.yml gold.fact). DDL 구조·타입·FK 보존, 데이터만 전체 갱신(멱등). append 라 unique_key 불요.
-- 순서9-C(#80/DEC-4): UNPAID_FLAG_EOM/BOM — 미납 = PAY_STAT_CD IN ('F', NULL).
{{ config(
    tags=['gold_pending']
) }}

with b as (
    select * from {{ ref('CRM_PAYMENT_BILLING') }}
),

-- [2026-08-03 O27/DEC-28] 회비 3분해용 회원유형 lookup.
--   `CRM_PAYMENT_BILLING` 에는 회원유형 컬럼이 없어 마스터에서 가져온다.
--   🟢 fan-out 0: `CRM_MEMBER` 는 MEMBER_DK 유일(1,763,065행 = 1,763,065 distinct, 실측).
--   ⚠️ MEMBER_DK 의 'S' 접두로 유도하지 않는다 — 실제 컬럼이 있으면 컬럼을 쓴다(DEC-27 §17-D #1 교훈).
--   ⚠️ 키 컬럼을 `MT_MEMBER_DK` 로 개명한다 — `MEMBER_DK` 로 두면 billing 의 `group by MEMBER_DK` 가
--      별칭(`MBER_NO as MEMBER_DK`) 대신 조인된 컬럼으로 해석돼 컴파일이 깨진다(실측 확인).
mtype as (
    select MEMBER_DK as MT_MEMBER_DK, MEMBER_TYPE as MT_MEMBER_TYPE from {{ ref('CRM_MEMBER') }}
),

-- 회비/청구 집계 (월×회원) — 구 로직 유지(멱등)
billing as (
    select
        COALESCE({{ month_key_clamp('TRY_TO_NUMBER(MBRFEE_MT)') }}, {{ month_key_clamp("TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM'))") }}, 0) as MONTH_KEY,  -- 회비월 우선, 무효/NULL 이면 납입월 폴백, 둘 다 무효면 0=Unknown월
        b.MBER_NO                                     as MEMBER_DK,
        SUM(PAY_AMT)                                  as PAID_FEE,
        SUM(RQEST_AMT)                                as BILLED_AMT,
        -- ── [2026-08-03 O27/DEC-28] 회비 3분해 (정본 지표 #66·#67·#68) ──────────────
        -- 정본 정의(02_지표사전 공통:91~93):
        --   #66 정기회비          = 정기회원이 **정기후원사업으로** 납입하는 회비
        --   #67 정기회원 일시회비 = 정기회원이 **정기후원사업 외 비지정(기타·국내사업·해외사업)** 으로 납부하는 일시회비
        --   #68 일시회원 일시회비 = **일시회원이 납부하는 회비**(구분 없이 전부)
        -- 원천 = `MBRFEE_DIV_CD` = **PM010** 4종: E=정기 · G=선물금 · I=일시 · U=긴급구호
        --   3원 대조(2026-08-03 실측): PM010 사전 4종 × 실적재 distinct 4종 = **4/4 일치**
        -- 🟢 회원유형×회비구분 교차 실측이 매핑을 확정한다 — 경계가 완전히 깨끗하다:
        --   FDRM 은 **항상 값이 있고**(E 46,267,706 · G 82,607 · I 38,617 · U 2,690)
        --   ONCE 는 **항상 NULL**(1,129,938) · 마스터부재 314행도 NULL
        --   ⇒ NULL = 일시회원 이라는 판정이 실측으로 성립한다(추론 아님).
        -- 🔴 G(선물금)·U(긴급구호)는 3컬럼 어디에도 넣지 않는다 — 정본 #67 이 열거한
        --    "기타·국내사업·해외사업" 에 선물금·긴급구호가 없고, 선물금은 **별도 지표**가 있다
        --    (#90 선물금참여(명)·#91 선물금참여(원) → `FACT_SERVICE_EVENT.GIFT_PART_*`).
        --    긴급구호는 대응 지표가 없다. 억지로 귀속시키면 정의 창작이다(DEC-17-B).
        -- ⚠️ 따라서 **3컬럼 합 ≠ PAID_FEE** 다. 검산(2026-08-03 · 본 모델 실행 결과로 확인):
        --    #66 759,530,956,167 + #67 5,365,351,828 + #68 126,337,814,788 = 891,234,122,783
        --    본 모델 PAID_FEE 합 895,178,309,108 − 891,234,122,783 = **3,944,186,325**
        --      = G(선물금) 3,408,190,000 + U(긴급구호) 495,788,354 + 마스터부재 74,880,671
        --        **− 불량 5행 34,672,700**(아래 `MBER_NO is not null` 로 제외되는 행) → 정확히 일치.
        --    ⚠️ SILVER 원표 전체 합(895,212,981,808)과 다르다 — 그 차이가 곧 불량 5행이다.
        --       전표 기준으로 검산하면 34,672,700 만큼 어긋나므로 **모델 출력 기준으로 검산**할 것.
        SUM(CASE WHEN m.MT_MEMBER_TYPE = 'FDRM' AND b.MBRFEE_DIV_CD = 'E'
                 THEN b.PAY_AMT END)                   as REGULAR_FEE,
        SUM(CASE WHEN m.MT_MEMBER_TYPE = 'FDRM' AND b.MBRFEE_DIV_CD = 'I'
                 THEN b.PAY_AMT END)                   as REGULAR_ONETIME_FEE,
        SUM(CASE WHEN m.MT_MEMBER_TYPE = 'ONCE'
                 THEN b.PAY_AMT END)                   as ONETIME_ONETIME_FEE,
        -- ── [2026-08-05 O40] 납부율·미납금액 모집단 일치 컬럼 2종 신설 ──────────────
        -- 🔴 결함: `PAID_FEE`(=SUM(PAY_AMT))는 **회비 ∪ 기부금** 이고 `BILLED_AMT`(=SUM(RQEST_AMT))는
        --    **회비뿐**이다. 기부금 원천 `TM_PM_DNTN_DTLS` 에는 청구 컬럼이 아예 없다
        --    (SILVER 실측: PAYMENT_TYPE='기부금' 1,130,252행 전건 `RQEST_AMT` NULL · `MBRFEE_MT` 도 NULL).
        --    → 두 값을 나누면 분자에만 기부금이 더해져 납부율이 구조적으로 과대해진다(P63 모집단 불일치).
        --    무증상이 아니라 **이미 사고가 났다**: 전 기간 `PAYMENT_RATE` **100.36%** · `TOTAL_UNPAID_AMT`
        --    **−3,218,518,220(음수)** 이 실측된다. 2025 는 93.98%(실제 85.65%)로 그럴싸해 더 위험했다.
        -- 🟢 판별자는 `PAYMENT_TYPE` 이다 — 실측으로 정확하다:
        --    PAYMENT_TYPE='회비' 46,391,620행 = `MBRFEE_DIV_CD` 비NULL 46,391,620행 (**정확 일치**)
        --    PAYMENT_TYPE='기부금' 1,130,252행 = `MBRFEE_DIV_CD` 비NULL 0행
        --    ⚠️ `ONETIME_ONETIME_FEE`(회원유형 ONCE 기준)로 빼는 방식은 **쓰지 않는다** — 축이 다르고
        --       마스터부재 314행이 어느 쪽에도 안 들어가 정의가 새어 나간다(근사 40,000원 어긋남 실측).
        SUM(CASE WHEN b.PAYMENT_TYPE = '회비' THEN b.PAY_AMT END)  as PAID_FEE_BILLABLE,
        -- 정본 DEC-3 미납 정의 = `PAY_STAT_CD IN ('F', NULL)` 인 **청구액**. 차감식(청구−납입)을 폐기한다.
        --   ⚠️ 분자는 `RQEST_AMT`(청구액)다 — 미납은 "청구했으나 안 들어온 금액"이므로 PAY_AMT 가 아니다.
        --   시뮬레이션(2026-08-05 · 본 모델 MONTH_KEY 로직 재현): 2025 = **29,251,314,636** 으로
        --   BRONZE 직접 집계값과 **정확히 일치**(차감식은 12,335,580,090 = 2.37배 과소였다).
        SUM(CASE WHEN b.PAY_STAT_CD = 'F' OR b.PAY_STAT_CD IS NULL
                 THEN b.RQEST_AMT END)                            as UNPAID_BILLED_AMT,
        -- #80(DEC-4): 월×회원에 미납 청구행(PAY_STAT_CD='F' OR NULL)이 하나라도 있으면 월말 미납.
        BOOLOR_AGG(PAY_STAT_CD = 'F' OR PAY_STAT_CD IS NULL)  as UNPAID_FLAG_EOM
    from b
    left join mtype m on m.MT_MEMBER_DK = b.MBER_NO   -- 1:1 lookup (fan-out 0, 실측 확인)
    where b.MBER_NO is not null                       -- 순수 불량 5행 제외(NOT NULL MEMBER_DK)
    group by MONTH_KEY, b.MBER_NO
),

-- W3(DEC-24): 월×회원 대표 미납사유. F행 한정, 최종차수(MBRFEE_SQNC 최대)의 결과코드로 REASON_SK 산출.
-- DIM_REASON 직접 조인으로 FK 무결성 보장(해시 독립계산 시 33건 orphan 발생 → 방지).
reason_rep as (
    select
        ranked.MONTH_KEY, ranked.MEMBER_DK,
        COALESCE(dr.REASON_SK, 0) as REASON_SK
    from (
        select
            COALESCE({{ month_key_clamp('TRY_TO_NUMBER(MBRFEE_MT)') }}, {{ month_key_clamp("TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM'))") }}, 0) as MONTH_KEY,
            MBER_NO as MEMBER_DK,
            CASE
                WHEN SETLE_CD = '1' AND LENGTH(RQEST_RST_CD) <= 2 THEN 'PM002'
                WHEN SETLE_CD = '1' AND LENGTH(RQEST_RST_CD) > 2  THEN 'PM032'
                WHEN SETLE_CD = '2'  THEN 'PM018'
                WHEN SETLE_CD = '12' THEN 'PM033'
                WHEN SETLE_CD = '5'  THEN 'PM019'
            END as CODE_GROUP,
            RQEST_RST_CD,
            ROW_NUMBER() OVER (
                PARTITION BY
                    COALESCE({{ month_key_clamp('TRY_TO_NUMBER(MBRFEE_MT)') }}, {{ month_key_clamp("TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM'))") }}, 0),
                    MBER_NO
                ORDER BY MBRFEE_SQNC DESC NULLS LAST, RQEST_DE DESC, RQEST_RST_CD
            ) as rn
        from b
        where PAY_STAT_CD = 'F'
          and MBER_NO is not null
          and RQEST_RST_CD is not null
    ) ranked
    left join {{ ref('DIM_REASON') }} dr
        on dr.REASON_TYPE = ranked.CODE_GROUP
       and dr.REASON_CODE = ranked.RQEST_RST_CD
    where ranked.rn = 1
),

-- W4 요건3(DEC-22): 그 달 실제 납입한 후원사업 수 (회비 한정, PAY_AMT>0).
-- 🔴 약정 보유 사업수 아님 — 납입 발생 사업수. 정본 (건)=금액/10,000 과 무관한 실제 개수.
paid_biz as (
    select
        COALESCE({{ month_key_clamp('TRY_TO_NUMBER(MBRFEE_MT)') }}, {{ month_key_clamp("TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM'))") }}, 0) as MONTH_KEY,
        MBER_NO                                       as MEMBER_DK,
        COUNT(DISTINCT SPNSR_BSNS_ID)                 as PAID_SPONSOR_BIZ_CNT
    from b
    where PAYMENT_TYPE = '회비'
      and MBER_NO is not null
      and PAY_AMT > 0
      and SPNSR_BSNS_ID is not null
    group by MONTH_KEY, MEMBER_DK
),

-- [2026-08-20 O92 / DEC-41] 월×회원 대표 후원사업 — 단일 확정 월만 SK 배선, 다중은 센티넬 0 + 플래그.
-- 🔴 축 주의 — 위 `paid_biz`(W4 요건3)와 **모집단이 다르다.** 두 플래그가 어긋나는 것은 결함이 아니다:
--    · `IS_MULTI_PAID_BIZ`     = 회비 한정 + `PAY_AMT>0` ⇒ 「그 달 실제 **납입이 발생한** 사업이 여럿인가」
--    · `IS_MULTI_SPONSORSHIP`  = 청구·기부금 포함 전 행     ⇒ 「그 달 회비 행이 **귀속된** 사업이 여럿인가」
--    ⇒ 미납만 있는 월은 앞이 0/FALSE 인데 뒤는 TRUE 일 수 있다. 같은 것을 다르게 재는 것이 아니라 다른 질문이다.
-- 🟢 `MIN(SPNSR_BSNS_ID)` 는 대표 선정이 아니다 — `SPONSOR_BIZ_CNT = 1` 일 때만 쓰므로 그 값이 유일값이다.
--    다중 월에서는 이 값을 **쓰지 않는다**(대표를 고르지 않는 것이 DEC-41 의 내용이다).
-- 🟢 DIM_SPONSORSHIP 직접 조인으로 FK 무결성 보장(해시 독립계산 시 orphan 위험 — reason_rep 와 동일 패턴).
--    fan-out 0 근거 = `SPONSORSHIP_BK` 유일성 **실측 확인**(중복 초과 0 · NULL 0 · 2026-08-20 O92-B).
--    🔴 R2-6: 카디널리티 수치는 여기 적지 않는다 — 정본은 `20_issue/30_설계_의사결정.md` §28-D 다.
--    (O92 가 이 자리에 미실측 수치 「50」을 적었고 실측은 51행이었다 ⇒ 수치를 코드에 두면 이렇게 틀린다.)
sponsor_rep as (
    select
        agg.MONTH_KEY,
        agg.MEMBER_DK,
        agg.SPONSOR_BIZ_CNT,
        CASE WHEN agg.SPONSOR_BIZ_CNT = 1 THEN COALESCE(ds.SPONSORSHIP_SK, 0) ELSE 0 END as SPONSORSHIP_SK
    from (
        select
            COALESCE({{ month_key_clamp('TRY_TO_NUMBER(MBRFEE_MT)') }}, {{ month_key_clamp("TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM'))") }}, 0) as MONTH_KEY,
            MBER_NO                                       as MEMBER_DK,
            COUNT(DISTINCT SPNSR_BSNS_ID)                 as SPONSOR_BIZ_CNT,
            MIN(SPNSR_BSNS_ID)                            as SOLE_SPNSR_BSNS_ID
        from b
        where MBER_NO is not null
          and SPNSR_BSNS_ID is not null
        group by MONTH_KEY, MEMBER_DK
    ) agg
    left join {{ ref('DIM_SPONSORSHIP') }} ds
        on ds.SPONSORSHIP_BK = agg.SOLE_SPNSR_BSNS_ID
),

-- W4 요건1(DEC-22) step1: 금액변경 이력을 월×회원 증액/감액 횟수로 집계.
-- 범위 밖 발생일 88행(19000101 등)은 month_key_clamp → 0(Unknown월) 라우팅.
amt_month as (
    select
        COALESCE({{ month_key_clamp('TRY_TO_NUMBER(SUBSTR(OCCRRNC_DE,1,6))') }}, 0) as MONTH_KEY,
        MBER_NO                                            as MEMBER_DK,
        SUM(CASE WHEN RDCAMT_YN = 'N' THEN 1 ELSE 0 END)   as INC_CNT,
        SUM(CASE WHEN RDCAMT_YN = 'Y' THEN 1 ELSE 0 END)   as DEC_CNT
    from {{ ref('CRM_MEMBER_AMT_CHANGE') }}
    where MBER_NO is not null
    group by MONTH_KEY, MEMBER_DK
),

-- 개발/중단 월 롤업 (월×회원) — FME(일 grain) → 월 집계. A1 핵심.
fme_rollup as (
    select
        FLOOR(DATE_SK / 100)                          as MONTH_KEY,   -- YYYYMMDD→YYYYMM (FME DATE_SK 는 이미 범위클램프; 0 → 0=Unknown월)
        MEMBER_DK,
        SUM(DEV_CNT)                                  as DEV_CNT,      -- 개발 사건수 합
        IFF(SUM(DEV_CNT) > 0, 1, 0)                    as DEV_MEMBERS,  -- 월×회원 grain: 개발발생 1/0 (다월 SUM 시 distinct 회원수)
        SUM(STOP_CNT)                                 as STOP_CNT,      -- 중단 사건수 합
        IFF(SUM(STOP_CNT) > 0, 1, 0)                   as STOP_MEMBERS
    from {{ ref('FACT_MEMBER_EVENT') }}
    group by MONTH_KEY, MEMBER_DK
),

-- 통합 스파인 = billing ∪ fme (월×회원 유일)
spine as (
    select MONTH_KEY, MEMBER_DK from billing
    union
    select MONTH_KEY, MEMBER_DK from fme_rollup
),

-- ═══ [2026-08-20 O93 · CONF-3 해소] 활동회원 as-of 판정 ═══════════════════════
-- 정본 = `02_지표사전 공통.md` #51 월말활동회원 · #52 월말활동회원(건).
--   #51 = 조회년월 기준 해당월 활동회원 (활동 + 미납1~미납5 포함 = 상태코드 1~11)
--   #52 = 월 활동회원의 **전체후원사업금액 / 10,000**
--
-- 🟢 판정축을 상태코드가 아니라 **후원사업 미중단 보유**로 잡았다. 이유 3가지:
--   ① 상태코드는 **현재값**이라 과거 월을 as-of 로 평가할 수 없다(소급 적용은 과거 활동회원 창작이다).
--   ② 상태이력(`CRM_MEMBER_STATUS_HIST`)은 회원 커버리지가 부분이다 — 이력 없는 회원이
--      「무변경」인지 「미기록」인지 원천이 구분해 주지 않는다.
--   ③ 후원사업 중단일은 **사업 단위로 완비**돼 있고, 중단 기록의 부재는 결측이 아니라
--      「중단하지 않았다」는 정보다 ⇒ 커버리지 공백이 원리적으로 없다.
--   🔴 그리고 이 축이 #52(건)의 분자(`SPNSR_AMT`)를 **같은 판정 안에서** 제공한다 —
--      상태코드 축으로는 (건)을 만들 수 없다(금액이 상태에 붙어 있지 않다).
--   🟢 현업 앵커(코드 1~11 현재값)와의 대조 결과는 `20_issue/30_설계_의사결정.md` §29 에 둔다(R2-6).
--
-- ⚠️ MONTH_KEY=0(Unknown 월)은 as-of 를 정의할 수 없다 ⇒ 활동 measure 를 **NULL** 로 둔다.
--    🔴 0 으로 두지 않는다 — 0 은 「활동 없음」이고 NULL 은 「판정 불가」다. 이 구분이 이 작업의 출발점이었다
--       (전건 0 이 *"활동회원 0명"* 으로 에러 없이 조회되던 문제).
-- ⚠️ (건)은 **비가산 축이 아니다** — 회원 grain 금액/10,000 이므로 회원 간 합산은 정당하다.
--    다만 `ACTIVE_CNT` 와 `ACTIVE_MEMBERS` 를 **더하지 말 것**(단위가 다르다).
active_asof as (
    select
        sp.MONTH_KEY,
        sp.MEMBER_DK,
        -- 당월말(=#51·#52 정본 축)
        COUNT(DISTINCT case when sv.DSCNTC_MONTH_KEY is null or sv.DSCNTC_MONTH_KEY > sp.MONTH_KEY
                            then sv.SPNSR_BSNS_NO end)                       as ACTIVE_BIZ_CNT,
        SUM(case when sv.DSCNTC_MONTH_KEY is null or sv.DSCNTC_MONTH_KEY > sp.MONTH_KEY
                 then sv.SPNSR_AMT else 0 end)                               as ACTIVE_BIZ_AMT,
        -- 전월말 (DEC-19 「동일 함수에 ADD_MONTHS(-1) 적용」)
        SUM(case when sv.START_MONTH_KEY <= {{ month_key_offset('sp.MONTH_KEY', -1) }}
                  and (sv.DSCNTC_MONTH_KEY is null
                       or sv.DSCNTC_MONTH_KEY > {{ month_key_offset('sp.MONTH_KEY', -1) }})
                 then sv.SPNSR_AMT else 0 end)                               as PREV_BIZ_AMT,
        -- 연초(YYYY01)·연말(YYYY12) as-of. 월키 산술로 구한다(FLOOR/100 → *100+01·+12).
        SUM(case when sv.START_MONTH_KEY <= FLOOR(sp.MONTH_KEY/100)*100 + 1
                  and (sv.DSCNTC_MONTH_KEY is null
                       or sv.DSCNTC_MONTH_KEY > FLOOR(sp.MONTH_KEY/100)*100 + 1)
                 then sv.SPNSR_AMT else 0 end)                               as YEAR_START_BIZ_AMT,
        SUM(case when sv.START_MONTH_KEY <= FLOOR(sp.MONTH_KEY/100)*100 + 12
                  and (sv.DSCNTC_MONTH_KEY is null
                       or sv.DSCNTC_MONTH_KEY > FLOOR(sp.MONTH_KEY/100)*100 + 12)
                 then sv.SPNSR_AMT else 0 end)                               as YEAR_END_BIZ_AMT
    from spine sp
    join {{ ref('CRM_MEMBER_SPONSOR_SPAN') }} sv
      on sv.MBER_NO = sp.MEMBER_DK
     and sv.START_MONTH_KEY <= sp.MONTH_KEY   -- 당월 기준 개시 필터(다른 as-of 축은 위 case 안에서 재평가)
    where sp.MONTH_KEY > 0                    -- Unknown 월 제외 ⇒ 아래 left join 에서 NULL 로 남는다
    group by sp.MONTH_KEY, sp.MEMBER_DK
),

-- W4 요건1 step2: 월말까지 누적 증액/감액 횟수 (running total).
-- 🟢 sparse 스파인에서도 정확 — 직전 행을 참조하지 않고 "그 월 이하 전체 합"이라 결측월 영향 없음.
--    (요건2 연속미납은 반대로 직전 행 의존이라 gap 3.94%에서 오판 → W4 범위 제외, dense 스파인 선행 필요)
-- 축 = spine ∪ amt_month: 스파인에 없는 월의 변경 이력도 누적에 반영되도록 union 후 running sum.
amt_cum as (
    select
        ax.MEMBER_DK, ax.MONTH_KEY,
        SUM(COALESCE(am.INC_CNT, 0)) OVER (PARTITION BY ax.MEMBER_DK ORDER BY ax.MONTH_KEY
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)  as AMT_INCREASE_CUM_CNT,
        SUM(COALESCE(am.DEC_CNT, 0)) OVER (PARTITION BY ax.MEMBER_DK ORDER BY ax.MONTH_KEY
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)  as AMT_DECREASE_CUM_CNT
    from (
        select MEMBER_DK, MONTH_KEY from spine
        union
        select MEMBER_DK, MONTH_KEY from amt_month
    ) ax
    left join amt_month am on am.MEMBER_DK = ax.MEMBER_DK and am.MONTH_KEY = ax.MONTH_KEY
),

joined as (
    select
        sp.MONTH_KEY,
        sp.MEMBER_DK,
        0 as CAMPAIGN_SK,
        -- [2026-08-20 O92 / DEC-41] 단일 확정 월만 배선. 다중 월·후원사업 부재 월은 0(센티넬) 유지.
        COALESCE(sr.SPONSORSHIP_SK, 0) as SPONSORSHIP_SK,
        0 as PAYMENT_SK,
        COALESCE(rr.REASON_SK, 0) as REASON_SK,   -- W3(DEC-24): 미납 대표사유. 비미납/미매핑=0
        COALESCE(fr.DEV_CNT, 0)      as DEV_CNT,
        COALESCE(fr.DEV_MEMBERS, 0)  as DEV_MEMBERS,
        COALESCE(fr.STOP_CNT, 0)     as STOP_CNT,
        0 as UNPAID_CNT,
        -- ═══ [2026-08-20 O93] 활동 계열 실배선 — 종전 `0 as …` 하드코딩 폐기 ═══════════
        -- 🔴 NULL vs 0 의 의미를 분리한다: `active_asof` 미매칭(= Unknown 월이거나 후원사업 이력 없음)은
        --    **NULL**(판정 불가/해당 없음)이고, 매칭됐지만 미중단 사업이 없으면 **0**(활동 아님)이다.
        --    종전에는 둘 다 0 이라 *"활동회원 0명"* 이 정상값처럼 반환됐다.
        aa.ACTIVE_BIZ_AMT / 10000            as ACTIVE_CNT,        -- #52 (건) = 활동 후원사업금액/10,000
        IFF(aa.ACTIVE_BIZ_CNT > 0, 1, 0)     as ACTIVE_MEMBERS,    -- #51 (명) = 월말 활동 1/0 (SUM 시 회원수)
        -- 🔴 누계 2종은 채우지 않는다 — 정본에 **`활동 누계`의 정의가 없다.**
        --    「누적 활동 개월수」인지 「누적 활동 금액」인지 「기수 누계」인지 결정되지 않았고,
        --    아무 것이나 고르면 정의 창작이다(DEC-17-B). 정의가 오면 이 두 줄만 교체하면 된다.
        CAST(NULL AS NUMBER(18,4)) as ACTIVE_CUM_CNT,
        CAST(NULL AS NUMBER(38,0)) as ACTIVE_CUM_MEMBERS,
        0 as INCREASE_CNT, 0 as INCREASE_MEMBERS, 0 as DECREASE_CNT, 0 as CHURN_CNT,
        aa.YEAR_START_BIZ_AMT / 10000        as YEAR_START_ACTIVE_CNT,   -- 연초(YYYY01) as-of
        aa.YEAR_END_BIZ_AMT   / 10000        as YEAR_END_ACTIVE_CNT,     -- 연말(YYYY12) as-of
        -- 🟢 당월말 = `ACTIVE_CNT` 와 같은 값이다 — 판정 자체가 as-of 월말이므로 축이 하나다.
        --    두 컬럼을 남겨 두는 이유는 DDL 구조 보존(소비 쿼리 호환)이다. 값 불일치가 아니다.
        aa.ACTIVE_BIZ_AMT / 10000            as MONTH_END_ACTIVE_CNT,
        aa.PREV_BIZ_AMT   / 10000            as PREV_MONTH_END_ACTIVE_CNT,  -- DEC-19 (d) ADD_MONTHS(-1)
        0 as CAMPAIGN_UNPAID_CNT, 0 as STATUS_UNPAID_CNT,
        -- [O27/DEC-28] 회비 3분해 실배선. NULL(해당 구분 납입 없음)은 0 으로 보정하지 않는다
        --   — 0 은 "납입액 0원", NULL 은 "그 구분의 납입이 없음"이라 의미가 다르다(P21).
        bl.REGULAR_FEE                as REGULAR_FEE,           -- #66 정기회원×정기(PM010 E)
        bl.REGULAR_ONETIME_FEE        as REGULAR_ONETIME_FEE,   -- #67 정기회원×일시(PM010 I)
        bl.ONETIME_ONETIME_FEE        as ONETIME_ONETIME_FEE,   -- #68 일시회원 전체
        bl.PAID_FEE,
        bl.BILLED_AMT,
        bl.PAID_FEE_BILLABLE          as PAID_FEE_BILLABLE,   -- [O40] 회비만 납입액(납부율 분자 정본)
        bl.UNPAID_BILLED_AMT          as UNPAID_BILLED_AMT,   -- [O40] DEC-3 정본 미납 청구액
        0 as INBOUND_CALL_CNT, 0 as TS_CALL_CNT,       -- ⚠️ 비-CRM 수기 미수령(C-8)
        CAST(NULL AS VARCHAR)  as DEV_TYPE,
        CAST(NULL AS BOOLEAN)  as NEW_FLAG, CAST(NULL AS BOOLEAN) as INCREASE_FLAG, CAST(NULL AS BOOLEAN) as REDONATE_FLAG,
        CAST(NULL AS DATE)     as JOIN_DATE, CAST(NULL AS DATE) as STOP_DATE,
        CAST(NULL AS VARCHAR)  as AMOUNT_BAND1, CAST(NULL AS VARCHAR) as AMOUNT_BAND2,
        CAST(NULL AS VARCHAR)  as PERIOD_BAND1, CAST(NULL AS VARCHAR) as PERIOD_BAND2,
        0 as SPONSOR_MONTHS, 0 as SPONSOR_YEARS, 0 as PAID_MONTHS,
        CAST(NULL AS VARCHAR)  as NEW_EXISTING_FLAG,
        bl.UNPAID_FLAG_EOM,
        -- W4(DEC-22): ML 전용 파생 4종. 🔴 정본 (건)=금액/10,000 과 다른 실제 개수·횟수 (CONF-2 주의).
        COALESCE(ac.AMT_INCREASE_CUM_CNT, 0)           as AMT_INCREASE_CUM_CNT,
        COALESCE(ac.AMT_DECREASE_CUM_CNT, 0)           as AMT_DECREASE_CUM_CNT,
        -- HAS_BILLING=FALSE(개발/중단 전용 월)는 NULL — 0으로 채우면 "납입 사업 0개"로 오독되어 완납률 왜곡.
        CASE WHEN bl.MEMBER_DK IS NOT NULL THEN COALESCE(pb.PAID_SPONSOR_BIZ_CNT, 0) END  as PAID_SPONSOR_BIZ_CNT,
        CASE WHEN bl.MEMBER_DK IS NOT NULL THEN COALESCE(pb.PAID_SPONSOR_BIZ_CNT, 0) > 1 END as IS_MULTI_PAID_BIZ,
        -- [2026-08-20 O92 / DEC-41] 그 달 귀속 후원사업이 여럿인가 = SPONSORSHIP_SK 가 0 인 이유의 구분자.
        --   🔴 0 에는 두 사유가 섞인다: ㉠ 다중(여기 TRUE) ㉡ 회비 행에 후원사업 자체가 없음(FALSE).
        --      플래그 없이 0 만 보면 두 사유를 가를 수 없다 — 그것이 이 컬럼의 존재 이유다(감사 가능성).
        --   ⚠️ HAS_BILLING=FALSE(개발/중단 전용 월)는 FALSE 다 — 회비 행이 없으니 다중일 수 없다.
        COALESCE(sr.SPONSOR_BIZ_CNT > 1, FALSE)        as IS_MULTI_SPONSORSHIP,
        -- A1: 출처 플래그. billing 매칭 행 존재 여부(billing MEMBER_DK 는 group 키라 매칭 시 non-null).
        IFF(bl.MEMBER_DK IS NOT NULL, TRUE, FALSE)     as HAS_BILLING,
        {{ gold_meta('CRM') }}
    from spine sp
    left join billing    bl on sp.MONTH_KEY = bl.MONTH_KEY and sp.MEMBER_DK = bl.MEMBER_DK
    left join fme_rollup fr on sp.MONTH_KEY = fr.MONTH_KEY and sp.MEMBER_DK = fr.MEMBER_DK
    left join reason_rep rr on sp.MONTH_KEY = rr.MONTH_KEY and sp.MEMBER_DK = rr.MEMBER_DK
    left join paid_biz   pb on sp.MONTH_KEY = pb.MONTH_KEY and sp.MEMBER_DK = pb.MEMBER_DK
    left join amt_cum    ac on sp.MONTH_KEY = ac.MONTH_KEY and sp.MEMBER_DK = ac.MEMBER_DK
    left join sponsor_rep sr on sp.MONTH_KEY = sr.MONTH_KEY and sp.MEMBER_DK = sr.MEMBER_DK  -- DEC-41
    -- [2026-08-20 O93] 활동 as-of. left join 이라 미매칭 월은 활동 measure 가 NULL 로 남는다(의도).
    left join active_asof aa on sp.MONTH_KEY = aa.MONTH_KEY and sp.MEMBER_DK = aa.MEMBER_DK
)

select
    j.*,
    -- #80 월초(BOM) = 전월말(EOM) 상태. 회원별 월순 LAG(union 스파인 전체 월 기준; 결측월은 직전 존재월 근사).
    LAG(j.UNPAID_FLAG_EOM) OVER (PARTITION BY j.MEMBER_DK ORDER BY j.MONTH_KEY)  as UNPAID_FLAG_BOM
from joined j
