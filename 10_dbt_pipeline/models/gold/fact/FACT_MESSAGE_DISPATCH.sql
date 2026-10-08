-- FACT_MESSAGE_DISPATCH: 메시지/서비스 발송 팩트 (이메일·문자·알림톡·우편 발송 및 성공/실패/오픈 현황)
-- Co-authored with CoCo
-- 🔴 [2026-09-22 O179 · I1] 리터럴 pre_hook **제거** — `dbt_project.yml` `gold.fact:+pre-hook`
--    (`gold_fact_purge(this)`)와 **이중 실행**됐다. 🟢 둘 다 `TRUNCATE` 를 내고 TRUNCATE 는 멱등이라
--    피해 0 이었고 제거 후 기대값도 **행수 불변**이다. 🔴 제거 이유 = `RANGED_FACTS` 등재 시
--    TRUNCATE + 범위 DELETE 동시 실행으로 **에러 없이 창 크기로 쪼그라드는** 잠재 사고였다.
--    🔴 정의 지점 = `macros/gold_fact_purge.sql` 하나 · 여기에 다시 쓰지 마라.
-- 🆕 🔴 [2026-09-22 O180] **위 주석을 config 블록 밖으로 옮겼다** — config 호출은 Jinja 표현식이라
--    `--` 가 주석이 아니라 연산자로 파싱돼 컴파일이 깨졌다(`FACT_EVENT_ATTENDANCE` 가 먼저 터졌고
--    같은 결함이 O179 가 만진 GOLD 팩트 **4건 전건**에 있었다).
--    🔴 판정식 = **config 안에 `--` 주석 금지 · 주석 안에서도 Jinja 태그 인용 금지**
--       (dbt 는 파일 전체를 Jinja 로 렌더하므로 `--` 도 백틱도 Jinja 를 막지 못한다).
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    tags=['gold_ready']
) }}

with s as (
    select * from {{ ref('CRM_SEND_MEMBER') }}
),
req as (
    select SNDNG_KEY, SEND_CHANNEL, SNDNG_TY_CD, TIT,
           SEND_GBN_TOP, SEND_GBN_MID, SEND_GBN_BOT
    from {{ ref('CRM_SEND_REQUEST') }}
),
open_window as (
    select MIN(OPEN_DT) as OPEN_TRACK_FROM
    from s
    where OPEN_DT is not null
),

-- ═══ [O183] 발송(+5일차) 매칭 · 서비스 배선 (정본 #139~#146 · #160·#161) ═══════════════
-- 후속행동 사건(회원 × 사건일). 서신 = 접수일 · 선물금 = 원천에 접수일이 없어 발송일(SNDNG_DE)로 대체
--   · 증액 = FME 개발구분 '2' 사건일 · 중단 = FME 중단일. 관계키 → 회원은 CRM_SPONSOR_RELATION(1:1).
rel as (
    select distinct RELATNSP_KEY, MBER_NO from {{ ref('CRM_SPONSOR_RELATION') }}
),
followup as (
    select r.MBER_NO as MEMBER_DK, 'LETTER' as KIND, a.RCEPT_DE as EV_DATE
    from {{ ref('CRM_RELATION_ACTIVITY') }} a join rel r on r.RELATNSP_KEY = a.RELATNSP_KEY
    where a.ACTIVITY_TYPE = '서신' and a.RCEPT_DE is not null
    union all
    select r.MBER_NO, 'GIFT', a.SNDNG_DE
    from {{ ref('CRM_RELATION_ACTIVITY') }} a join rel r on r.RELATNSP_KEY = a.RELATNSP_KEY
    where a.ACTIVITY_TYPE = '선물금' and a.SNDNG_DE is not null
    union all
    select MEMBER_DK, 'INCREASE', JOIN_DATE
    from {{ ref('FACT_MEMBER_EVENT') }}
    where EVENT_TYPE = 'DEV' and DVLP_DIV_CD = '2' and JOIN_DATE is not null
    union all
    select MEMBER_DK, 'STOP', STOP_DATE
    from {{ ref('FACT_MEMBER_EVENT') }}
    where EVENT_TYPE = 'STOP' and STOP_DATE is not null
),
-- (회원, 발송일) 쌍 단위로 판정한 뒤 발송 행에 되붙인다(발송 행 키 없이 fan-out 0).
-- 🔴🔴 DEC-33 반영 — 창은 **D+1~D+5** 다(발송 당일 D+0 제외). D+0 동일자 매칭은 대부분 **사건의 결과로 나간
--    처리 통보**(중단 감사·증액 감사·접수 확인)라 포함하면 「통보가 사건을 유발했다」로 역집계된다(DEC-33 실측).
--    발송 유형(캠페인성/처리통보성) 분리는 여전히 현업 확정 대상이며 D+1~5 에도 통보성 발송이 일부 남는다(DEC-55).
send_pairs as (
    select distinct MBER_NO as MEMBER_DK, SNDNG_DE::DATE as SEND_DATE
    from s where MBER_NO is not null and SNDNG_DE is not null
),
d5 as (
    select
        p.MEMBER_DK, p.SEND_DATE,
        BOOLOR_AGG(f.KIND = 'LETTER')   as D5_LETTER,
        BOOLOR_AGG(f.KIND = 'GIFT')     as D5_GIFT,
        BOOLOR_AGG(f.KIND = 'INCREASE') as D5_INCREASE,
        BOOLOR_AGG(f.KIND = 'STOP')     as D5_STOP
    from send_pairs p
    join followup f
      on f.MEMBER_DK = p.MEMBER_DK
     and f.EV_DATE between DATEADD(day, 1, p.SEND_DATE) and DATEADD(day, 5, p.SEND_DATE)
    group by p.MEMBER_DK, p.SEND_DATE
),
-- 「활동건」 = 그 회원의 발송월 활동(건)(#157 = 약정금액/10,000) — FMM 월×회원 유일.
active_m as (
    select MONTH_KEY, MEMBER_DK, ACTIVE_CNT from {{ ref('FACT_MEMBER_MONTHLY') }}
),
-- 발송구분(대) 명칭(#133). 「서비스」 = 원천 명칭 「회원서비스」.
send_l as (
    select distinct SEND_GBN_TOP, SEND_TYPE_L from {{ ref('DIM_SEND_TYPE') }}
)

select
    COALESCE({{ date_sk('s.SNDNG_DE::DATE') }}, 0)  as DATE_SK,
    s.MBER_NO                                     as MEMBER_DK,
    CASE WHEN r.SNDNG_KEY IS NULL THEN 0
         ELSE {{ gold_sk(['r.SEND_CHANNEL', 'r.SNDNG_TY_CD']) }} END  as SERVICE_SK,
    0                                             as CAMPAIGN_SK,
    1                                             as SEND_MEMBERS,
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
    CASE
        WHEN s.SEND_CHANNEL <> 'SND'                     THEN CAST(NULL AS NUMBER(38,0))
        WHEN s.OPEN_DT IS NOT NULL                       THEN 1
        WHEN ow.OPEN_TRACK_FROM IS NULL                  THEN CAST(NULL AS NUMBER(38,0))
        WHEN s.SNDNG_DE >= ow.OPEN_TRACK_FROM            THEN 0
        ELSE CAST(NULL AS NUMBER(38,0))
    END                                           as OPEN_MEMBERS,
    -- 🔴 [O183] 비-D5 서신·선물금참여 4종은 **발송과 무관한 참여 실적**(정본 #88~#91)이라 발송 grain 에
    --    귀속 규칙이 없다 ⇒ 0 유지. 참여 실적은 D5 매칭(아래) 또는 SILVER `CRM_RELATION_ACTIVITY` 직접 조회.
    0 as LETTER_PART_MEMBERS, 0 as LETTER_PART_CNT, 0 as GIFT_PART_MEMBERS, 0 as GIFT_PART_AMT,
    -- [O183] #139~#146 = 발송 다음날~+5일 안에 그 후속행동이 있는 발송 대상 1/0 · (건) = 그 회원의 발송월 활동(건).
    -- 🆕 [2026-09-30 O190] L-1① (사용자 결정 §4 #6) — 제목에 「미납·중단·감사」 포함 발송은 **처리통보성**이라 귀속 제외.
    --   이유 = 사건의 결과로 나간 발송을 원인으로 세면 인과가 뒤집힌다(문서20 L-1 실측).
    --   🔴 제목이 없는 발송(요청 미매칭)은 판정 근거가 없어 규칙 대상이 아니다(종전대로 귀속 · 창작 0).
    IFF(d.D5_LETTER   AND NOT COALESCE(REGEXP_LIKE(r.TIT, '.*(미납|중단|감사).*'), FALSE), 1, 0) as D5_LETTER_PART_MEMBERS,
    IFF(d.D5_LETTER   AND NOT COALESCE(REGEXP_LIKE(r.TIT, '.*(미납|중단|감사).*'), FALSE), COALESCE(am.ACTIVE_CNT, 0), 0) as D5_LETTER_PART_CNT,
    IFF(d.D5_GIFT     AND NOT COALESCE(REGEXP_LIKE(r.TIT, '.*(미납|중단|감사).*'), FALSE), 1, 0) as D5_GIFT_PART_MEMBERS,
    IFF(d.D5_GIFT     AND NOT COALESCE(REGEXP_LIKE(r.TIT, '.*(미납|중단|감사).*'), FALSE), COALESCE(am.ACTIVE_CNT, 0), 0) as D5_GIFT_PART_CNT,
    IFF(d.D5_INCREASE AND NOT COALESCE(REGEXP_LIKE(r.TIT, '.*(미납|중단|감사).*'), FALSE), 1, 0) as D5_INCREASE_PART_MEMBERS,
    IFF(d.D5_INCREASE AND NOT COALESCE(REGEXP_LIKE(r.TIT, '.*(미납|중단|감사).*'), FALSE), COALESCE(am.ACTIVE_CNT, 0), 0) as D5_INCREASE_PART_CNT,
    IFF(d.D5_STOP     AND NOT COALESCE(REGEXP_LIKE(r.TIT, '.*(미납|중단|감사).*'), FALSE), 1, 0) as D5_STOP_MEMBERS,
    IFF(d.D5_STOP     AND NOT COALESCE(REGEXP_LIKE(r.TIT, '.*(미납|중단|감사).*'), FALSE), COALESCE(am.ACTIVE_CNT, 0), 0) as D5_STOP_CNT,
    -- [O183] #160 서비스(명) = 발송구분(대) 「회원서비스」 발송 대상 1/0 · #161 서비스(건) = 그 회원의 활동(건).
    IFF(sl.SEND_TYPE_L = '회원서비스', 1, 0)                           as SERVICE_MEMBERS,
    IFF(sl.SEND_TYPE_L = '회원서비스', COALESCE(am.ACTIVE_CNT, 0), 0)  as SERVICE_CNT,
    r.TIT                                          as SEND_TITLE,
    s.SNDNG_RST_CD                                as SEND_STATUS,
    -- 🗑 [2026-10-06 O202-C · 사용자 결정 처분 ①] SEND_STATUS2(전건 NULL 자리 컬럼) 제거.
    --   발송상태2 = 축B 통신사 도달결과 = SEND_RESULT_CD·SEND_RESULT_NAME(상태1 「발송완료」 → 「전달」 · 「에러」 → 실패사유).
    s.SEND_CHANNEL                                as SEND_TYPE,
    CAST(NULL AS BOOLEAN)                          as MAIL_RECEIVE_FLAG,
    CAST(NULL AS BOOLEAN)                          as MEMBER_STOP_FLAG,
    CASE WHEN r.SEND_GBN_TOP IS NULL THEN 0
         ELSE {{ gold_sk(['r.SEND_GBN_TOP', 'r.SEND_GBN_MID', 'r.SEND_GBN_BOT']) }} END as SEND_TYPE_SK,
    {{ gold_meta('CRM') }},
    s.SEND_STATUS_GROUP                           as SEND_STATUS_GROUP,
    s.SEND_STATUS_NAME                            as SEND_STATUS_NAME,
    s.SEND_RESULT_CD                              as SEND_RESULT_CD,
    s.SEND_RESULT_GROUP                           as SEND_RESULT_GROUP,
    s.SEND_RESULT_NAME                            as SEND_RESULT_NAME,
    -- 🆕 [2026-09-29 O188-F] 발송대상 최초·최종 브랜드(SND 전용 degen · 타 채널 NULL) — 원천 SND_MEMBER_LIST.
    --   🔴 공통브랜드(MM297)와 다른 체계(브랜드 마스터 TM_CM_BRND_MNG)다 — 같은 축으로 합치지 말 것.
    s.FRST_BRND_CD                                as FRST_BRND_CD,
    s.FRST_BRND_NM                                as FRST_BRND_NM,
    s.LST_BRND_CD                                 as LST_BRND_CD,
    s.LST_BRND_NM                                 as LST_BRND_NM,
    s.CURRENT_BRND                                as CURRENT_BRND,
    -- 🆕 [2026-09-30 O191-G · 2차-B GOLD 전파] SILVER CRM_SEND_MEMBER 승계(발송×회원 grain degen · 채널별 비해당 NULL).
    --   대체문자 = 알림톡 전용 · 결연KEY = 우편·SND · 관리번호 = 우편 · 나머지 5종 = SND 전용.
    s.ALTRTV_MSG_SNDNG_YN, s.RELATNSP_KEY, s.MNG_NO, s.MSG_KEY, s.CINFO,
    s.RESPONSED_YN, s.RESPONSED_DT, s.REAL_SEND_DT,
    -- 🆕 [2026-10-01 O196-D · DEC-58 #1] 발송 요청 차원 FK — 요청 속성은 DIM_SEND_REQUEST 에서 읽는다(degen 금지).
    --   🔴 [O196-E] 요청 미매칭(발송 대상에만 키가 있고 요청 마스터에 없음 · 📏 11,421행)도 0 으로 보낸다 — 고아 FK 금지.
    CASE WHEN r.SNDNG_KEY IS NULL THEN 0 ELSE {{ gold_sk(['r.SNDNG_KEY']) }} END as SEND_REQUEST_SK,
    -- 🆕 [2026-10-08 O213-E · 7차 Y3-E] SND 발송 시점 회원 스냅샷 4종(degen · 타 채널 NULL · FRST_BRND_* 와 같은 관례).
    s.SND_SPNSR_NM, s.SND_DSCNTC_RSN_NM, s.SND_CHILD_PROJECT_COUNTRY, s.SND_CHILD_WORKPLACE_NM
from s
left join req r on s.SNDNG_KEY = r.SNDNG_KEY
cross join open_window ow
left join d5 d        on d.MEMBER_DK = s.MBER_NO and d.SEND_DATE = s.SNDNG_DE::DATE
left join active_m am on am.MEMBER_DK = s.MBER_NO
                     and am.MONTH_KEY = TO_NUMBER(TO_CHAR(s.SNDNG_DE, 'YYYYMM'))
left join send_l sl   on sl.SEND_GBN_TOP = r.SEND_GBN_TOP
where s.MBER_NO is not null
