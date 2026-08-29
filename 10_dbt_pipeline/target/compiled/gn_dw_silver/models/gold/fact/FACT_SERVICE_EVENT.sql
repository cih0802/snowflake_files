-- FACT_SERVICE_EVENT: 발송 서비스 팩트 (CRM_SEND_MEMBER × CRM_SEND_REQUEST) — A3: SERVICE_SK·SEND_TITLE 실채움
-- Co-authored with CoCo
-- ✅ A3(2026-07-21): 발송요청 마스터(CRM_SEND_REQUEST) SNDNG_KEY 조인(커버 99.97%) → SERVICE_SK(DIM_SERVICE 동일 해시)·SEND_TITLE(TIT) 실채움. 요청 미매칭 → SERVICE_SK=0(Unknown).
-- ⚠️ 스캐폴드 잔여: 행당 SEND_MEMBERS=1. 성과지표(SUCCESS/FAIL/OPEN·D5)=0 은 B1(코드매핑)·CAMPAIGN_SK=0 은 B3(원천 캠페인 컬럼 부재).
-- ❌ APP_PUSH_SEND_CNT/SUCCESS_CNT: 어드민 원천 ❌제외 확정(2026-07-09) → 컬럼 삭제. 내년 어드민 구현 시 컬럼 재추가(ADD COLUMN).
-- 순서9(G-1/G-2 해소): table→incremental+append+pre-hook TRUNCATE(dbt_project.yml gold.fact). DDL 구조·타입·FK 보존, 데이터만 전체 갱신(멱등). append 라 unique_key 불요.


with s as (
    select * from GN_DW.SILVER.CRM_SEND_MEMBER
),
req as (
    -- 발송요청 마스터: SNDNG_KEY unique(1,614,397). SERVICE_SK 산식 컬럼(SEND_CHANNEL·SNDNG_TY_CD) + 제목(TIT).
    -- [DEC-30 2026-08-04] 발송구분 계층 3컬럼 추가 — DIM_SEND_TYPE 조인키 산식용.
    select SNDNG_KEY, SEND_CHANNEL, SNDNG_TY_CD, TIT,
           SEND_GBN_TOP, SEND_GBN_MID, SEND_GBN_BOT
    from GN_DW.SILVER.CRM_SEND_REQUEST
),
-- 🆕 [2026-08-20 O95] 오픈 추적 개시 시점을 **데이터에서 유도**한다(리터럴 금지 · `P31`·`R2-6`).
--   왜 필요한가 = `OPEN_DT` 는 원천에 나중에 붙은 컬럼이라 **그 이전 발송은 측정 자체가 없다.**
--   그 구간을 0 으로 두면 「열지 않았다」로 읽혀 오픈율 분모를 오염시킨다 ⇒ NULL 로 구분한다.
--   ⚠️ 스칼라 1행이라 cross join 해도 fan-out 이 없다.
open_window as (
    select MIN(OPEN_DT) as OPEN_TRACK_FROM
    from s
    where OPEN_DT is not null
)

select
    COALESCE(CASE WHEN s.SNDNG_DE::DATE BETWEEN '1991-01-01' AND '2035-12-31'
         THEN TRY_TO_NUMBER(TO_CHAR(s.SNDNG_DE::DATE, 'YYYYMMDD')) END, 0)  as DATE_SK,   -- 범위밖/NULL → 0 (순서9)
    s.MBER_NO                                     as MEMBER_DK,
    -- A3: DIM_SERVICE.SERVICE_SK = gold_sk([SEND_CHANNEL, SNDNG_TY_CD]) 와 동일 산식(요청 마스터 값 사용). 미매칭 → 0.
    CASE WHEN r.SNDNG_KEY IS NULL THEN 0
         ELSE ABS(HASH(COALESCE(CAST(r.SEND_CHANNEL AS VARCHAR), '∅') || '‖' || COALESCE(CAST(r.SNDNG_TY_CD AS VARCHAR), '∅'))) END  as SERVICE_SK,
    0                                             as CAMPAIGN_SK,   -- B3: 원천에 캠페인 컬럼 부재(요청 마스터에도 없음)
    1                                             as SEND_MEMBERS,
    -- ═══ [2026-08-20 O93] 성공/실패/오픈 실배선 — 종전 `0 as …` 하드코딩 폐기 ═══════════════
    -- 종전 주석은 *"원천 5컬럼 전건 NULL"* 이라 적고 B1(코드매핑 미확정)으로 묶어 두었으나
    -- 🔴 **그 전제가 틀렸다.** 원천 재실측 결과 성공/실패는 회원 단위로 실재한다
    --    (EMAIL `SNDNG_RST_CD` 채움률 100% · MSG_AT `TRNSMS_STAT_CD` 채움률 98%대).
    --    전건 NULL 인 것은 **오픈·클릭뿐**이었다 ⇒ 입고 계열이 아니라 배선 계열이었다.
    --    🔴 R2-6: 실측 수치는 여기 적지 않는다 — 정본은 `30_output_share/10_원천입고_결손요약.md` §5-2 다.
    --
    -- 판정 근거를 채널별로 다르게 잡았다. **근거의 강도가 다르기 때문**이다:
    --   🟢 EMAIL  = 원천 **집계 컬럼과 교차검증**해 확정했다. 상세의 `SNDNG_RST_CD` 값별 행수가
    --      집계 테이블의 성공/실패 합과 오차 0.1% 미만으로 일치한다 ⇒ 1=성공 · 0=실패.
    --      이것은 우리 해석이 아니라 **원천 자체의 두 기록이 서로 맞은 결과**다(라벨 창작 아님).
    --   🟢 MSG_AT = **사전(MS282) 라벨**이 붙는다(2=발송완료 · 3=에러 · 4=예약취소).
    --      `SEND_STATUS_GROUP` 이 붙은 행만 판정한다 ⇒ 사전이 바뀌면 판정이 조용히 틀리는 대신
    --      매칭이 풀려 0 으로 떨어진다(안전한 실패 방향).
    --      ⚠️ 예약취소(4)는 성공도 실패도 아니다 — 발송 자체가 일어나지 않았다 ⇒ 둘 다 0.
    --   🔴 SND   = **0 으로 남긴다. 근거가 약하다.** 왜 약한지 명시(사용자 지시 2026-08-20):
    --      ① 교차검증 대상이 없다 — 요청 마스터(`SND_REQ_MST`)의 `SEND_CNT`·`FAIL_CNT` 가
    --         **전건 0** 이라 대조할 집계값 자체가 존재하지 않는다.
    --      ② `SND_YN`(Y/N)은 사전 코드군이 특정되지 않아 `CRM_CODE` 에서 가져올 라벨이 없다
    --         (§23-J 결정 3). 그리고 컬럼명이 「발송 여부」라 **발송 사실**을 뜻할 가능성이 있어
    --         「성공」으로 읽으면 의미를 바꾸는 것이 된다(DEC-17-B 라벨 창작).
    --      ③ 축B(`SEND_RESULT_NAME`)에는 사전 라벨이 붙지만 「전달」을 성공으로 읽는 것은
    --         여전히 우리 판단이고, 라벨이 NULL 인 구간이 남아 전건을 덮지 못한다.
    --      ⇒ 셋 다 「모르는 것을 아는 척하지 않는다」에 걸린다. 현업 확인 후 이 블록만 고치면 된다.
    --   🔴 PSTMTR = 0. 원천에 상태 컬럼 자체가 없다(구조적 부재 · P21).
    -- ⚠️ 따라서 이 두 measure 의 0 은 **「실패」가 아니라 채널에 따라 「판정 보류」일 수 있다.**
    --    판별자는 `SEND_TYPE` 이다 — 채널별 신뢰도를 구분해 소비할 것. 채널 무시 합산은 과소집계다.
    CASE
        WHEN s.SEND_CHANNEL = 'EMAIL'  AND s.SNDNG_RST_CD = '1' THEN 1
        WHEN s.SEND_CHANNEL = 'MSG_AT' AND s.SEND_STATUS_GROUP IS NOT NULL
                                       AND s.SNDNG_RST_CD = '2' THEN 1
        ELSE 0
    END                                           as SUCCESS_MEMBERS,
    CASE
        WHEN s.SEND_CHANNEL = 'EMAIL'  AND s.SNDNG_RST_CD = '0' THEN 1
        WHEN s.SEND_CHANNEL = 'MSG_AT' AND s.SEND_STATUS_GROUP IS NOT NULL
                                       AND s.SNDNG_RST_CD = '3' THEN 1
        ELSE 0
    END                                           as FAIL_MEMBERS,
    -- 오픈 = `SND_MEMBER_LIST.OPEN_DT`(O93 신설 원천). **SND 채널만** 측정된다.
    -- 🔴🔴 [2026-08-20 O95 자기시정] 종전 O93 구현은 `IFF(OPEN_DT IS NOT NULL, 1, 0)` 이었다 —
    --    **그것은 이 세션이 문제로 지목한 「미주입 0 스캐폴드」를 새로 만든 것이었다.**
    --    §5 에서 *"0 은 정상 집계값처럼 조용히 반환된다"* 고 경고하면서 같은 패턴을 생산했다(자기모순).
    --    ⇒ **0 과 NULL 을 의미로 분리한다**:
    --      · SND 아닌 채널        → **NULL**(원천에 오픈 컬럼 자체가 없다 = 구조적 부재)
    --      · SND · 값 있음        → **1**(오픈 사실)
    --      · SND · 추적 개시 이후 · 값 없음 → **0**(관측했고 열지 않았다 = 진짜 0)
    --      · SND · 추적 개시 이전 → **NULL**(측정 자체가 없다 — 「열지 않았다」가 아니다)
    -- 🟢 추적 개시 시점은 `open_window` 가 **데이터에서 구한다** — 경계를 리터럴로 박지 않는다(`P31`).
    -- ⚠️ 이메일·알림톡 오픈/클릭은 원천이 전건 NULL 이라 여기서도 NULL 이다(진짜 입고 대기 · `C-9-R`).
    -- ⚠️ 따라서 오픈율은 `SUM(OPEN_MEMBERS) / COUNT(OPEN_MEMBERS)` 로 계산해야 한다 —
    --    분모에 `COUNT(*)` 를 쓰면 NULL 구간(미측정·타 채널)이 섞여 과소해진다.
    CASE
        WHEN s.SEND_CHANNEL <> 'SND'                     THEN CAST(NULL AS NUMBER(38,0))
        WHEN s.OPEN_DT IS NOT NULL                       THEN 1
        WHEN ow.OPEN_TRACK_FROM IS NULL                  THEN CAST(NULL AS NUMBER(38,0))
        WHEN s.SNDNG_DE >= ow.OPEN_TRACK_FROM            THEN 0
        ELSE CAST(NULL AS NUMBER(38,0))
    END                                           as OPEN_MEMBERS,
    0 as LETTER_PART_MEMBERS, 0 as LETTER_PART_CNT, 0 as GIFT_PART_MEMBERS, 0 as GIFT_PART_AMT,
    0 as D5_LETTER_PART_MEMBERS, 0 as D5_LETTER_PART_CNT, 0 as D5_GIFT_PART_MEMBERS, 0 as D5_GIFT_PART_CNT,
    0 as D5_INCREASE_PART_MEMBERS, 0 as D5_INCREASE_PART_CNT, 0 as D5_STOP_MEMBERS, 0 as D5_STOP_CNT,
    0 as SERVICE_MEMBERS, 0 as SERVICE_CNT,
    r.TIT                                          as SEND_TITLE,    -- A3: 발송 제목 실채움(구 NULL)
    s.SNDNG_RST_CD                                as SEND_STATUS,
    CAST(NULL AS VARCHAR)                          as SEND_STATUS2,
    s.SEND_CHANNEL                                as SEND_TYPE,
    CAST(NULL AS BOOLEAN)                          as MAIL_RECEIVE_FLAG,
    CAST(NULL AS BOOLEAN)                          as MEMBER_STOP_FLAG,
    -- 🟢 [DEC-30 2026-08-04] 발송구분 차원 배선 — DIM_SEND_TYPE 과 **동일 산식**(경로 3컬럼 해시).
    --   커버리지 실측 8,300,272/38,470,780 = **21.58%**. 나머지는 발송요청에 구분값이 없어 센티넬 0.
    --   ⚠️ DEC-28 §18-C 가 인용한 0.106% 는 **요청 grain 분모**였다 — send-type 이 붙은 요청은
    --      평균 4,862.5명 발송(없는 요청 18.7명)이라 소비 grain 에서는 200배 차이가 난다(P39).
    CASE WHEN r.SEND_GBN_TOP IS NULL THEN 0
         ELSE ABS(HASH(COALESCE(CAST(r.SEND_GBN_TOP AS VARCHAR), '∅') || '‖' || COALESCE(CAST(r.SEND_GBN_MID AS VARCHAR), '∅') || '‖' || COALESCE(CAST(r.SEND_GBN_BOT AS VARCHAR), '∅'))) END as SEND_TYPE_SK,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '22ac85e6-6bb3-416e-b393-feaee28af165'                    AS DW_BATCH_ID,
    -- 🟢 [2026-08-11 O59-N · DEC-35 2단계] 발송 결과 2축 코드→라벨 전파. 코드사전 조인은 SILVER 소관.
    --    🔴 축A(SEND_STATUS)는 채널별 다체계라 SEND_STATUS_GROUP 이 판별축이다 — 종전 B1 미해소 주석의
    --       *"SNDNG_RST_CD→성공/실패 코드매핑 확정 후"* 는 **축A 라벨로는 아직 못 채운다**(EMAIL·SND 는
    --       사전 라벨 부재 · 문서20 §M-4 회신 대기) ⇒ SUCCESS/FAIL measure 는 여전히 0 이다.
    --    🟢 축B(SEND_RESULT_*)는 conformed 이고 라벨이 실제로 붙는다.
    s.SEND_STATUS_GROUP                           as SEND_STATUS_GROUP,
    s.SEND_STATUS_NAME                            as SEND_STATUS_NAME,
    s.SEND_RESULT_CD                              as SEND_RESULT_CD,
    s.SEND_RESULT_GROUP                           as SEND_RESULT_GROUP,
    s.SEND_RESULT_NAME                            as SEND_RESULT_NAME
from s
left join req r on s.SNDNG_KEY = r.SNDNG_KEY      -- SNDNG_KEY unique → fan-out 없음
cross join open_window ow                          -- [O95] 스칼라 1행 — fan-out 없음
where s.MBER_NO is not null                       -- 순수 불량 745행 제외(NOT NULL MEMBER_DK)