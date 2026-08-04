-- O28·O29 무증상 오답 차단 — COMMENT 전용 가드 (코드 변경 0 · dbt build 불요)
-- Co-authored with CoCo
-- ============================================================================
-- 대상 : GN_DW.GOLD.FACT_EVENT_PARTICIPATION (O28) · GN_DW.GOLD.FACT_AD_BROADCAST (O29)
-- 역할 : GN_DW_ADMIN
-- 근거 : 20_issue/10_진단_원인분석.md §14-H(O28) · §14-I(O29)
-- 측정일: 2026-08-04 (본 세션 전 항목 BRONZE 원천 직접 재실측 — 아래 §0)
--
-- 🟢 왜 COMMENT 만으로 급한가
--   COMMENT 는 Semantic View 의 `description` 으로 소비된다(문서10 §10-B). 지금 두 컬럼의
--   COMMENT 는 "참여상태"·"광고 초수" 라고만 말하므로 Cortex Analyst 가 무해해 보이는 SQL 을
--   생성하고 **0행 또는 틀린 단위**를 반환한다 — 에러도 경고도 없다(AD-4·P19 유형).
--   코드 수정·재빌드 없이 이 경로를 즉시 막는 것이 본 스크립트의 목적이다.
--
-- 🟢 왜 다음 빌드가 되돌리지 않는가 (검증 완료)
--   두 테이블 모두 `dbt_project.yml` gold.fact = incremental + append + pre-hook TRUNCATE 이고
--   **컬럼 COMMENT 를 세팅하는 post_hook 이 없다**. TRUNCATE 는 COMMENT 를 지우지 않는다.
--   (반면 WIDE 는 뷰이고 post_hook 이 COMMENT 소유주 → 물리만 고치면 되돌아간다. P33)
--   ⚠️ 단 구조 정본은 `03_top-down_gold/06_DDL.sql` 이므로 §3 에서 그 파일도 동기화한다(P33 DoD ②).
--
-- 🔴 이 스크립트가 하지 않는 것 (의도적)
--   · FEP 상태별 카운트 배선 → O28 코드체계 현업 회신(문서20 §I) 후에만 가능
--   · DURATION_SEC 값 교정 → SILVER 파싱 배선 + dbt build 필요(별건)
--   · 숫자 3종(30/60/90 ×10^6) µs 변환 → **추론이므로 현업 확인 전 금지**(P36)
-- ============================================================================


-- ============================================================================
-- §0. 측정 근거 (2026-08-04 재실측 · 실행 불요 · 재현용 쿼리)
-- ============================================================================
-- 작업조건 #3(코멘트로 단정하지 말고 BRONZE 원천을 스캔) 준수. 아래는 본 세션이 실제로 돌린 쿼리다.
--
-- [O28-1] BRONZE 두 원천의 참여상태 도메인 — 한 컬럼이 아니라 애초에 두 테이블이다
--   select 'EVENT' src, PARTCPT_STAT_CD, count(*) from GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL group by all
--   union all
--   select 'CRMN', PARTCPT_STAT_CD, count(*) from GN_DW.BRONZE_CRM.TD_MS_CRMN_PRTCPNT group by all;
--   → CRMN : 4=96,603 · 2=43,845 · 1=6,295 · 5=3,347 · 3=1,932 · 6=79 · NULL 31   (소정수 1~6)
--   → EVENT: 110=906,052 · 130=24,360 · 150=13,228 · 170=11,500 · 190=9,230 · 210=7,418
--            · 140=847 · 120=38 · 180=32 · 220=32 · 200=16 · 160=7 · NULL 11,209 · ')' 2
--
-- [O28-2] EVENT 체계 = MS304 확정 (12/12 완전 일치)
--   select DTL_CD_ID, DTL_CD_NM from GN_DW.SILVER.CRM_CODE where CD_ID='MS304' order by SORT_ORDR;
--   → 110 Success · 120 Fail · 130 1_step_right · 140 1_step_fail · 150 2_step_right
--     · 160 2_step_fail · 170 3_step_right · 180 3_step_fail · 190 4_step_right
--     · 200 4_step_fail · 210 5_step_right · 220 5_step_fail
--   🔴 문서10 §14-H 서술 2건 정정: (a) 라벨 목록에 **`120=Fail` 이 누락**돼 있었다(11종으로 기술).
--      (b) "값 100~220" 은 부정확 — 실측 최소값은 **110**이며 사전에도 100 은 없다.
--
-- [O28-3] CRMN 소정수 1~6 은 대조로 확정 불가 — 판별력 0 을 수치로 확인
--   with g as (select CD_ID, count_if(DTL_CD_ID in ('1','2','3','4','5','6')) hit6, count(*) n
--              from GN_DW.SILVER.CRM_CODE group by CD_ID)
--   select count_if(hit6=6) superset, count_if(hit6=6 and n=6) exact, count(*) total from g;
--   → 전체 336 그룹 중 **1~6 을 전부 포함 118 그룹** · **도메인이 정확히 1~6 인 것 14 그룹**
--     (MS006 신청|참여|불참|대기|취소|대기(결제) 유력하나 MM290·MS004·MS025·MS028·MS065·RM003…
--      13개 후보와 구별 불가) → P29 3원 대조 적용 불가 2번째 사례. **현업 회신 필수**(문서20 §I).
--   ⚠️ 문서10 §14-H 는 "수십 개" 로 적었다 — 실측 118(포함)/14(정확)로 수치를 확정한다.
--
-- [O28-4] 🟢 신규 발견 — 체계 판별자는 `EVENT_SOURCE` 가 아니라 `EVENT_KEY` 접두다
--   문서10 §14-H 조치안 ②는 *"`PART_STATUS_SOURCE`(=`EVENT_SOURCE`) 병설"* 이라 적었으나
--   **`EVENT_SOURCE` 는 참여 테이블에 없다** — `SILVER.CRM_EVENT`(행사 마스터) 컬럼이다
--   (grep 실측: models/silver/crm/CRM_EVENT.sql:4 · GOLD 노출은 `DIM_EVENT.EVENT_KIND`).
--   즉 ②를 문면대로 하면 **마스터 조인이 필요**한데, 참여의 23.2% 가 고아라 조인이 실패한다:
--     select case when f.EVENT_SK=0 then '고아' else e.EVENT_KIND end, <체계>, count(*)
--     from GN_DW.GOLD.FACT_EVENT_PARTICIPATION f
--     left join GN_DW.GOLD.DIM_EVENT e on e.EVENT_SK=f.EVENT_SK group by all;
--     → CRMN  : 소정수 152,046 · NULL 31
--       EVENT : MS304 707,476 · NULL 10,960 · 오염 2
--       고아  : MS304 263,312 · 소정수 50 · NULL 249   ← 263,611행(23.2%) 에서 EVENT_KIND='(미매핑)'
--   🟢 반면 `EVENT_KEY` 접두는 **고아 포함 전건**을 가른다(교차오염 0):
--     select split_part(EVENT_KEY,'_',1), <체계>, count(*) from GN_DW.SILVER.CRM_EVENT_PARTICIPATION group by all;
--     → CRMN 접두: 소정수 152,096 · NULL 31            (다른 체계 0)
--       EVENT 접두: MS304 970,788 · NULL 11,209 · 오염 2 (다른 체계 0)
--   → 배선 시 판별자는 **`EVENT_KEY` 접두(조인 불요·고아 안전)** 를 쓴다. 아래 COMMENT 에 반영.
--
-- [O28-5] 🔴 오염값 ')' 은 SILVER 결함이 아니다 — BRONZE 에 이미 있다
--   select PARTCPT_STAT_CD, length(PARTCPT_STAT_CD), PARTCPT_DT
--   from GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL where PARTCPT_STAT_CD=')';
--   → 2행 · 길이 1 · EVENT_CD 118/153 · PARTCPT_DT 2024-02-14 정상 TIMESTAMP_NTZ
--     인접 컬럼(CHNNL 100 · PATH 200)도 정상 → **필드 밀림(field shift) 아님**
--   또한 같은 테이블 983,971행에 인용부호로 감싸인 값 **0건** → 적재 인용/구분자 파싱 결함 아님
--   🔴 문서10 §14-H 조치안 ③ *"SILVER 정제 파싱 결함 추적"* 은 **가설이 틀렸다**.
--      SILVER 는 `NULLIF(TRIM(...),'')` 로 원천을 충실히 통과시켰을 뿐이다(정상 동작).
--      → 원천 입력 오류이므로 (a) 현업 원천 정정 또는 (b) 센티넬 라우팅 결정 사안으로 재분류.
--
-- [O29-1] BRONZE 광고 초수 — 두 표기 혼재 실측
--   select AD_SEC, count(*) from GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS group by all;
--   → HH:MM:SS 32,739(96.6%) : 00:01:00=27,788 · 0:01:30=2,285 · 00:01:30=1,107
--                              · 00:02:00=1,082 · 0:00:30=477      → 초수 집합 {30,60,90,120}
--   → 숫자     1,151(3.4%)   : 60000000=700 · 90000000=411 · 30000000=40
--                                                              → ÷10^6 = {30,60,90}
--   → NULL 2,526 / 채움 33,890 / 전체 36,416 (93.1%)
--
-- [O29-2] GOLD 현재 적재 상태 — 살아남은 값이 틀렸다
--   select DURATION_SEC, count(*) from GN_DW.GOLD.FACT_AD_BROADCAST group by all;
--   → 60000000=700 · 90000000=411 · 30000000=40 · NULL 37,335   (채움 1,151)
--   ⚠️ **행수 드리프트 고지**: 본 세션 실측 `FACT_AD_BROADCAST` = **38,486행**.
--      문서(순서9-I/II·99_NEXT_SESSION)의 **37,886** 과 600행 차이가 있다. 그 값은 2026-07-28
--      측정치이며 본 세션에서 원인을 규명하지 않았다 → **어느 쪽도 근거로 쓰지 말고 재측정할 것**
--      (PROC-3 (c): 두 측정치가 어긋나면 원인 규명 전 채택 금지).
--
-- [O29-3] 커버리지 분모는 "개념이 존재하는 모집단" (P39)
--   초수 개념은 VIDEO 전용이다(REBRDC 원천에 초수 컬럼 없음).
--   → 현재 GOLD 유효 커버리지 = 1,151 / 36,416(BRONZE VIDEO) = **3.2%**
--   → HH:MM:SS 파싱만 해도 33,890 / 36,416 = **93.1%** 로 회복
--
-- [O29-4] 🟢 `TRY_TO_*` 전수 스캔 완료 (§14-I 조치 ⑤) — **O29 는 고립 결함이다**
--   모델 14파일 14용례를 전수 열거한 뒤, TEXT 원천 캐스팅 전건에 대해
--   "원천 non-null 인데 캐스팅 결과 NULL" 을 실측했다:
--     · VIDEO.AD_SEC   → DURATION_SEC : 채움 33,890 / **소실 32,739 (96.6%)** 🔴 = O29 본건
--     · VIDEO.CPC      → CPC_SRC      : 채움 34,097 / 소실 482  → 🟢 **양성(benign)**
--         소실값 전건이 `#DIV/0!`(엑셀 오류 문자열) 482행 → NULL 로 만드는 것이 **정상 동작**이다.
--         ⚠️ 대행사 원천이 엑셀 산출물임을 시사 → 신규 유입 시 오류문자열 재발 가능(관측 대상)
--     · ERP BDGT.YEAR  → BUDGET_YEAR  : 채움 6,336 / 소실 **0**
--     · CRM_EVENT.STRT_DE·END_DE      : 각 채움 3,785 / 소실 **0**
--     · CRM_MEMBER_DEV.OCCRRNC_DE     : 채움 3,594,843 / 소실 **0**
--     · CRM_MEMBER_DISCONTINUE.SPNSR_DSCNTC_DE : 채움 1,038,262 / 소실 **0**
--     · CRM_PAYMENT_BILLING.MBRFEE_MT : 채움 46,391,620 / 소실 **0**
--     · CRM_DEV_TARGET.STDR_MT        : 채움 25,344 / 소실 **0**
--   → **결론: 무성 소실은 `AD_SEC` 1건뿐이며 계열 확산이 아니다.** 나머지는 손실 0 또는 양성.
--     "동일 유형이 더 있을 것"이라는 우려는 실측으로 반증됐다(O20 `_YN` 전수스캔과 같은 결말).
--   ⚠️ **부수 발견(별건)**: `BRONZE_CRM.TD_MS_CRMN_PRTCPNT.PARTCPT_DATE` 는 **채움 0** 이다
--      (캐스팅 손실이 아니라 원천 자체가 전건 NULL). 캠페인행사 152,127행은 참여일이 없어
--      FEP `DATE_SK` 가 `COALESCE` 로 **행사시작일에 대체 귀속**된다 → 참여일 기반 시계열 분석 시
--      캠페인행사분은 실제 참여시점이 아니다. 미등재 항목이므로 §4 에서 신규 제기한다.
-- ============================================================================


-- ============================================================================
-- §1. O28 — FACT_EVENT_PARTICIPATION COMMENT 가드
-- ============================================================================

-- 1-A. 🔴 핵심 — PART_STATUS 두 코드체계 경고
COMMENT ON COLUMN GN_DW.GOLD.FACT_EVENT_PARTICIPATION.PART_STATUS IS
'🔴 참여상태 — **한 컬럼에 서로 다른 코드체계 2개가 혼입**돼 있다(O28 · 2026-08-04 실측). 단일 도메인으로 다루면 집계가 조용히 틀린다.
[체계1] 일반행사 = MS304 코드 12종: 110=Success · 120=Fail · 130~220=N_step_right/N_step_fail(N=1~5). 실측 707,476행(고아 263,312 별도).
[체계2] 캠페인행사 = 소정수 1~6. 실측 152,046행. 🔴 각 값의 의미는 **미확정**(문서20 §I 현업 회신 대기) — 코드사전에서 1~6 을 포함하는 그룹이 118개라 대조로 좁혀지지 않는다.
[판별법] 두 체계를 가르는 정본 판별자는 SILVER `CRM_EVENT_PARTICIPATION.EVENT_KEY` 접두(`EVENT_`/`CRMN_`) 다 — 실측 교차오염 0. `DIM_EVENT.EVENT_KIND` 로도 갈리지만 참여 263,611행(23.2%)이 고아라 `(미매핑)` 이 되어 판별 불가.
[금지] 두 체계를 합산·GROUP BY 하지 말 것. 리포트는 행사종류별로 **항상 분리**한다.
[한글 라벨 없음] 값은 원천 코드 그대로이므로 `=''참여''` 같은 한글 비교는 **0행**을 반환한다(에러 없음).';

-- 1-B. 상태별 카운트 — 전건 0 이 "0명"이 아니라 "미배선"임을 명시
--      현 COMMENT('대기인원' 등)는 값이 실재하는 것처럼 읽혀 그대로 소비되면 "전부 0명"이라는
--      오답이 된다. 원인은 컬럼 탈락이 아니라 **O28 코드체계 미확정**이다(문서10 §14-H).
COMMENT ON COLUMN GN_DW.GOLD.FACT_EVENT_PARTICIPATION.RECRUIT_CNT IS
'모집인원 — 🔴 **전건 0 (미배선)**. 실측 2026-08-04: 비영 0 / 1,134,126행. 원천은 실재한다(SILVER `CRM_EVENT.RCRIT_PSNNL_CO` 채움 3,361/3,786=88.8%) → 행사차원 배속 판정 후 배선 대상. **0 을 "모집인원 0명"으로 읽지 말 것**.';

COMMENT ON COLUMN GN_DW.GOLD.FACT_EVENT_PARTICIPATION.TOTAL_CNT IS
'총인원 — 🔴 **전건 0 (미배선)**. 실측 2026-08-04: 비영 0 / 1,134,126행. 원인 = O28 참여상태 코드체계 미확정(문서20 §I 회신 대기). **0 을 실제 0명으로 읽지 말 것**. 참여 행수는 `PARTICIPANT_CNT` 를 쓴다.';

COMMENT ON COLUMN GN_DW.GOLD.FACT_EVENT_PARTICIPATION.WAIT_CNT IS
'대기인원 — 🔴 **전건 0 (미배선)**. 원인 = O28 참여상태 코드체계 미확정 → 상태→카운트 매핑을 만들 수 없다(문서10 §14-H · 문서20 §I). **0 을 실제 0명으로 읽지 말 것**.';

COMMENT ON COLUMN GN_DW.GOLD.FACT_EVENT_PARTICIPATION.CANCEL_CNT IS
'취소인원 — 🔴 **전건 0 (미배선)**. 원인 = O28 참여상태 코드체계 미확정(문서20 §I). **0 을 실제 0명으로 읽지 말 것**.';

COMMENT ON COLUMN GN_DW.GOLD.FACT_EVENT_PARTICIPATION.CONFIRM_CNT IS
'신청확정인원 — 🔴 **전건 0 (미배선)**. 원인 = O28 참여상태 코드체계 미확정(문서20 §I). **0 을 실제 0명으로 읽지 말 것**.';

COMMENT ON COLUMN GN_DW.GOLD.FACT_EVENT_PARTICIPATION.ABSENT_CNT IS
'불참인원 — 🔴 **전건 0 (미배선)**. 원인 = O28 참여상태 코드체계 미확정(문서20 §I). **0 을 실제 0명으로 읽지 말 것**.';

-- 1-C. 참여 횟수 3종 + 누적 — 원천은 `PARTCPT_SEQ` 이며 상태체계와 무관하게 산출 가능
--      (문서10 §14-G #1: SEQ 는 카운트 원천이 아니라 **행 식별자**이고, *_TIMES 3종만 SEQ 소관)
COMMENT ON COLUMN GN_DW.GOLD.FACT_EVENT_PARTICIPATION.PARTICIPATION_TIMES IS
'참여횟수 — 🔴 **전건 0 (미배선)**. 원천 `CRM_EVENT_PARTICIPATION.PARTCPT_SEQ` 채움 100%(1,134,126) 실재. 🟢 O28 코드체계와 **무관하게 산출 가능**(회신 대기 불요) — 실측 (행사,회원) 쌍 802,298 vs 행수 1,134,126 이므로 331,828행이 반복 참여다. **0 을 실제 0회로 읽지 말 것**.';

COMMENT ON COLUMN GN_DW.GOLD.FACT_EVENT_PARTICIPATION.WAIT_TIMES IS
'대기횟수 — 🔴 **전건 0 (미배선)**. 상태 기반이므로 O28 코드체계 확정 후 산출(문서20 §I). **0 을 실제 0회로 읽지 말 것**.';

COMMENT ON COLUMN GN_DW.GOLD.FACT_EVENT_PARTICIPATION.ABSENT_TIMES IS
'불참횟수 — 🔴 **전건 0 (미배선)**. 상태 기반이므로 O28 코드체계 확정 후 산출(문서20 §I). **0 을 실제 0회로 읽지 말 것**.';

COMMENT ON COLUMN GN_DW.GOLD.FACT_EVENT_PARTICIPATION.CUM_APPLY_TIMES IS
'누적신청 횟수 — 🔴 **전건 0 (미배선)**. `PARTCPT_SEQ` 기반 산출 가능(O28 무관). **0 을 실제 0회로 읽지 말 것**.';

-- 1-D. 하드코딩 상수 1 — "집계된 값"이 아님을 명시
COMMENT ON COLUMN GN_DW.GOLD.FACT_EVENT_PARTICIPATION.PARTICIPATE_CNT IS
'참여인원 — ⚠️ **행당 상수 1 하드코딩**(집계 결과가 아니다). 실측 2026-08-04: 1,134,126행 전건 1. 상태와 무관하게 1 이므로 **취소·불참 행까지 "참여"로 계상된다** → 상태별 분해는 O28 확정 후. 순수 행수 용도로만 쓸 것.';

COMMENT ON COLUMN GN_DW.GOLD.FACT_EVENT_PARTICIPATION.PARTICIPANT_CNT IS
'참여자수 — ⚠️ **행당 상수 1**(=참여 행수). 실측 전건 1. 회원 중복이 제거되지 않으므로 "몇 명"이 필요하면 `COUNT(DISTINCT MEMBER_DK)` 를 쓸 것 — 실측 (행사,회원) 쌍 802,298 < 행수 1,134,126.';

-- 1-E. 전건 NULL degen 2종
COMMENT ON COLUMN GN_DW.GOLD.FACT_EVENT_PARTICIPATION.SELF_PART_FLAG IS
'본인참여 — 🔴 **전건 NULL (미배선)**. 모델이 `CAST(NULL AS BOOLEAN)` 하드코딩. 원천 대응 컬럼 미확정 → 수요 판정 대기(E군).';

COMMENT ON COLUMN GN_DW.GOLD.FACT_EVENT_PARTICIPATION.INCREASE_FLAG IS
'증액여부 — 🔴 **전건 NULL (미배선)**. 모델이 `CAST(NULL AS BOOLEAN)` 하드코딩. 증액은 개발구분 축(MM015 코드2)이라 정소재지는 `FACT_MEMBER_EVENT.DVLP_DIV_CD` 다 → 본 컬럼 중복축 정리 후보.';

-- 1-F. 센티넬 0 하드코딩 FK 2종 — O8 게이트
COMMENT ON COLUMN GN_DW.GOLD.FACT_EVENT_PARTICIPATION.CAMPAIGN_SK IS
'분석축(캠페인) — 🔴 **전건 0 하드코딩(미배선)**. 차단 사유 = **O8 다중 캠페인 귀속 규칙 현업 미회신**. 규칙 없이 조인하면 fan-out 이 발생한다(FME 기준 다중캠페인 7.98%·단일 회원-월 최대 60개). 0 은 `(미매핑)` 센티넬이며 "캠페인 없음"이 아니다.';

COMMENT ON COLUMN GN_DW.GOLD.FACT_EVENT_PARTICIPATION.SPONSORSHIP_SK IS
'분석축(후원사업) — 🔴 **전건 0 하드코딩(미배선)**. 차단 사유 = O8 동일 게이트(문서20 §G). 0 은 `(미매핑)` 센티넬이며 "후원사업 없음"이 아니다.';

-- 1-G. 테이블 COMMENT — 소비 진입점에서 먼저 경고
COMMENT ON TABLE GN_DW.GOLD.FACT_EVENT_PARTICIPATION IS
'행사 참여 팩트 (DATE_SK × MEMBER_DK × EVENT_SK) · 1,134,126행(2026-08-04 실측).
🔴 **O28 경고**: `PART_STATUS` 에 코드체계 2개(일반행사 MS304 / 캠페인행사 소정수 1~6)가 혼입돼 있다. 행사종류를 분리하지 않은 집계는 조용히 틀린다.
🔴 **미주입 14컬럼**: 상태·모집 카운트 6 + 횟수 4 + degen NULL 2 + FK 센티넬 2 가 전건 0/NULL 이다. **0 을 실측값으로 읽지 말 것** — 컬럼별 COMMENT 에 사유를 명시했다.
🟡 **grain 주의**: 행 식별자(degenerate key)가 없다. 유일 조합은 (EVENT_KEY, MEMBER_DK, PARTCPT_SEQ) 이며 (행사,회원) 만으로는 802,298 ≠ 1,134,126 로 중복된다.
⚠️ **고아 23.2%**: EVENT_SK=0 이 263,611행(기지 이슈 O-E, 행사 마스터 스냅샷 누락). 행사 속성 조인 시 유실된다.';


-- ============================================================================
-- §2. O29 — FACT_AD_BROADCAST.DURATION_SEC 단위 경고
-- ============================================================================
-- 🔴 현재 적재값이 **틀렸다**. 컬럼명은 "초"인데 값은 30,000,000~90,000,000 이다.
--    분석가·Analyst 는 이를 "3천만 초"(약 347일)로 읽는다 — 이미 소비 가능한 라이브 오답이다.
COMMENT ON COLUMN GN_DW.GOLD.FACT_AD_BROADCAST.DURATION_SEC IS
'🔴 **광고 초수 — 현재 값은 신뢰하지 말 것 (O29 · 2026-08-04 실측)**. 컬럼명은 "초"이나 적재값은 30,000,000 / 60,000,000 / 90,000,000 이다. **"3천만 초"로 읽으면 오답** — 원천 표기 단위가 미확정이며 µs(÷10^6 → 30·60·90초) 해석이 유력하나 **아직 추론이다**(현업 확인 대기).
🔴 **96.6% 무성 소실**: 원천 `BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.AD_SEC`(TEXT) 33,890행 중 HH:MM:SS 표기 **32,739행(96.6%)** 이 SILVER 의 TEXT→NUMBER 캐스팅에서 NULL 이 됐다. `TRY_TO_NUMBER` 는 에러 없이 NULL 을 만들어 행수·not_null·참조무결성 어느 테스트에도 걸리지 않았다(P27). 살아남은 1,151행(3.4%)이 위의 단위 미확정 숫자다.
📊 **커버리지(분모=개념 존재 모집단 VIDEO 36,416, P39)**: 현재 유효 **3.2%**(1,151). HH:MM:SS 파싱 배선 시 **93.1%**(33,890)로 회복 가능 — 두 표기의 초수 집합이 HH:MM:SS {30,60,90,120} · 숫자 {30,60,90}(×10^6) 로 정합한다.
⚠️ [VIDEO 전용] REBRDC 원천에는 초수 컬럼이 **구조적으로 없다** → REBRDC 행의 NULL 은 결손이 아니다(AD-1 유형 오판 주의).
→ 조치 순서 = 본 경고 → SILVER HH:MM:SS 파싱(무추론·즉시 가능) → 숫자 3종 현업 확인 후 변환(확인 전 NULL 유지가 현 상태보다 안전) → `DIM_AD_CREATIVE.DURATION_SEC` 중복축 정리.';

-- 부수: 같은 축이 소재차원에도 (전건 NULL 로) 존재한다 — 중복축이다
--   ⚠️ 물리 COMMENT 는 `'초수(#22)'` 이고 *"원천 부재"* 는 **모델 파일 주석**(DIM_AD_CREATIVE.sql:5·25)에
--      있다. 즉 물리 COMMENT 자체가 거짓을 말한 것은 아니나, 지표번호만 있어 **전건 NULL 임을
--      알 수 없다** → 소비자는 조회 가능한 축으로 오인한다.
COMMENT ON COLUMN GN_DW.GOLD.DIM_AD_CREATIVE.DURATION_SEC IS
'초수(#22) — 🔴 **전건 NULL · 중복축 (O29)**. 모델이 `CAST(NULL AS NUMBER(9,0))` 하드코딩이다. 조회·조인하지 말 것.
🔴 모델 주석의 *"원천 부재(초수)"* 는 **거짓**이다 — 원천은 실재한다(SILVER `AGENCY_AD_CREATIVE.AD_SEC_NM` VIDEO 1,217/1,279=95.2% · BRONZE `VIDEO_AD_CMPGN_DTLS.AD_SEC` 33,890/36,416=93.1%). P14 위반 사례.
🔴 그러나 **채움이 정답이 아니다** — 같은 축이 `FACT_AD_BROADCAST.DURATION_SEC` 에 이미 배선돼 있다(§18-D ① 같은 역할 컬럼 우선). 판정은 **중복축 DROP 또는 소재차원 정본 통합**이며 결정 대기다.';


-- ============================================================================
-- §2-B. 🔴 WIDE 소비뷰 — 즉시 반영 + **모델 post_hook 동시 수정 필수**
-- ============================================================================
-- 🔴 왜 별도 절인가: WIDE 는 VIEW 이고 컬럼 COMMENT 소유주가 **모델 post_hook** 이다.
--    아래 ALTER 만 실행하면 **다음 dbt build 가 되돌린다**(P33 ②). 따라서
--    `models/gold/wide/WIDE_EVENT_PARTICIPATION.sql`·`WIDE_AD_BROADCAST.sql` 의 post_hook 도
--    같은 문구로 수정했다(본 세션 반영 완료). 아래는 **build 전까지의 즉시 보호**다.
-- 🔴 WIDE 가 더 중요하다: 분석가·SV 가 실제로 보는 계층이 WIDE 다.
--    99_NEXT_SESSION §3 은 FACT COMMENT 만 지목했고 **WIDE 노출을 누락**했다(본 세션 발견).

ALTER VIEW GN_DW.GOLD.WIDE_EVENT_PARTICIPATION ALTER
  COLUMN PART_STATUS COMMENT '🔴 참여상태 — **코드체계 2개 혼입**(O28). 일반행사=MS304(110=Success·120=Fail·130~220=N_step_right/fail) 707,476행 / 캠페인행사=소정수 1~6 152,046행(의미 미확정·문서20 §I). 판별자=`EVENT_KIND`(단 고아 23.2% 는 `(미매핑)`). **두 체계 합산·GROUP BY 금지** · 한글 비교(=''참여'')는 0행 반환',
  COLUMN EVENT_KIND COMMENT 'DIM_EVENT.EVENT_KIND — 🔴 행사종류 코드 raw(`EVENT`=일반행사 / `CRMN`=캠페인행사). ⚠️종전 COMMENT *"온라인/오프라인"* 은 **거짓**이었다(실측 도메인 EVENT 376·CRMN 3,410·NULL 1) → `=''온라인''` 은 0행 반환. 라벨=`EVENT_KIND_NAME`. 🔷 이 컬럼이 `PART_STATUS` 코드체계 판별자다',
  COLUMN RECRUIT_CNT COMMENT '모집인원 — 🔴 전건 0(미배선). 원천 실재(`CRM_EVENT.RCRIT_PSNNL_CO` 88.8%). 0 을 실측값으로 읽지 말 것',
  COLUMN TOTAL_CNT COMMENT '총인원 — 🔴 전건 0(미배선). 원인=O28 코드체계 미확정. 0 을 실측값으로 읽지 말 것',
  COLUMN WAIT_CNT COMMENT '대기인원 — 🔴 전건 0(미배선). 원인=O28 코드체계 미확정. 0 을 실측값으로 읽지 말 것',
  COLUMN CANCEL_CNT COMMENT '취소인원 — 🔴 전건 0(미배선). 원인=O28 코드체계 미확정. 0 을 실측값으로 읽지 말 것',
  COLUMN CONFIRM_CNT COMMENT '신청확정인원 — 🔴 전건 0(미배선). 원인=O28 코드체계 미확정. 0 을 실측값으로 읽지 말 것',
  COLUMN ABSENT_CNT COMMENT '불참인원 — 🔴 전건 0(미배선). 원인=O28 코드체계 미확정. 0 을 실측값으로 읽지 말 것',
  COLUMN PARTICIPATE_CNT COMMENT '참여인원 — ⚠️ 행당 상수 1 하드코딩(집계 아님). 취소·불참 행도 1 이므로 상태별 분해 불가',
  COLUMN PARTICIPANT_CNT COMMENT '참여자수 — ⚠️ 행당 상수 1(=행수). 회원 중복 미제거 → "몇 명"은 `COUNT(DISTINCT MEMBER_DK)` 사용((행사,회원) 802,298 < 행수 1,134,126)',
  COLUMN PARTICIPATION_TIMES COMMENT '참여횟수 — 🔴 전건 0(미배선). 🟢 원천 `PARTCPT_SEQ` 100% 채움이고 O28 과 무관하게 산출 가능',
  COLUMN WAIT_TIMES COMMENT '대기횟수 — 🔴 전건 0(미배선). O28 확정 후 산출',
  COLUMN ABSENT_TIMES COMMENT '불참횟수 — 🔴 전건 0(미배선). O28 확정 후 산출',
  COLUMN CUM_APPLY_TIMES COMMENT '누적신청횟수 — 🔴 전건 0(미배선). `PARTCPT_SEQ` 기반 산출 가능(O28 무관)',
  COLUMN SELF_PART_FLAG COMMENT '본인참여여부 — 🔴 전건 NULL(미배선). 원천 대응 미확정',
  COLUMN INCREASE_FLAG COMMENT '증액여부 — 🔴 전건 NULL(미배선). 증액 정소재지는 `FACT_MEMBER_EVENT.DVLP_DIV_CD`(MM015 코드2)';

ALTER VIEW GN_DW.GOLD.WIDE_AD_BROADCAST ALTER
  COLUMN DURATION_SEC COMMENT '🔴 광고 초수 (VIDEO 전용) — **현재 값을 신뢰하지 말 것**(O29). 적재값이 30,000,000/60,000,000/90,000,000 이라 "초"로 읽으면 오답이다(µs 해석 유력하나 미확정·현업 확인 대기). 또한 원천 HH:MM:SS 표기 **32,739행(96.6%)이 TRY_TO_NUMBER 캐스팅에서 무성 소실**됐다 → 유효 커버리지 1,151/36,416=3.2%(파싱 시 93.1% 회복). REBRDC 의 NULL 은 결손이 아니라 원천 부재';


-- ============================================================================
-- §3. 검증 — 반영 확인 (P33: 완료 판정은 문서가 아니라 INFORMATION_SCHEMA 스캔)
-- ============================================================================

-- 3-1. O28 경고가 실제로 박혔는가 (기대: 17행 전부 🟢)
select column_name,
       case when comment ilike '%O28%' or comment ilike '%미배선%' or comment ilike '%하드코딩%'
            then '🟢 가드 반영' else '⚠️ 미반영' end as guard,
       left(comment, 80) as comment_head
from GN_DW.INFORMATION_SCHEMA.COLUMNS
where table_schema='GOLD' and table_name='FACT_EVENT_PARTICIPATION'
  and column_name in ('PART_STATUS','RECRUIT_CNT','TOTAL_CNT','WAIT_CNT','CANCEL_CNT','CONFIRM_CNT',
                      'ABSENT_CNT','PARTICIPATION_TIMES','WAIT_TIMES','ABSENT_TIMES','CUM_APPLY_TIMES',
                      'PARTICIPATE_CNT','PARTICIPANT_CNT','SELF_PART_FLAG','INCREASE_FLAG',
                      'CAMPAIGN_SK','SPONSORSHIP_SK')
order by column_name;

-- 3-2. O29 단위 경고 반영 확인 (기대: 3행 — FACT·DIM·WIDE 전부 🟢)
select table_schema, table_name, column_name,
       case when comment ilike '%O29%' then '🟢 가드 반영' else '⚠️ 미반영' end as guard
from GN_DW.INFORMATION_SCHEMA.COLUMNS
where table_schema in ('GOLD','SERVING') and column_name='DURATION_SEC'
order by table_schema, table_name;

-- 3-3. 🔴 거짓 경고문 회수 확인 (P33 ③) — 기대: **0행**
--      WIDE 의 `EVENT_KIND` = *"온라인/오프라인"* 은 실측상 거짓이었다(EVENT/CRMN).
select table_schema, table_name, column_name, left(comment,80) as comment_head
from GN_DW.INFORMATION_SCHEMA.COLUMNS
where table_schema in ('GOLD','SERVING','SILVER') and comment ilike '%온라인%'
order by table_schema, table_name;

-- 3-4. WIDE 소비뷰 가드 반영 확인 (기대: 16행 전부 🟢)
select table_name, column_name,
       case when comment ilike '%O28%' or comment ilike '%미배선%' or comment ilike '%상수 1%'
                 or comment ilike '%행사종류%'
            then '🟢 가드 반영' else '⚠️ 미반영 — build 가 되돌렸는지 확인' end as guard
from GN_DW.INFORMATION_SCHEMA.COLUMNS
where table_schema='GOLD' and table_name='WIDE_EVENT_PARTICIPATION'
  and column_name in ('PART_STATUS','EVENT_KIND','RECRUIT_CNT','TOTAL_CNT','WAIT_CNT','CANCEL_CNT',
                      'CONFIRM_CNT','ABSENT_CNT','PARTICIPATE_CNT','PARTICIPANT_CNT',
                      'PARTICIPATION_TIMES','WAIT_TIMES','ABSENT_TIMES','CUM_APPLY_TIMES',
                      'SELF_PART_FLAG','INCREASE_FLAG')
order by column_name;

-- 3-5. ⚠️ SERVING 계층 잔여 확인 — `FACT_AD_COMBINED.DURATION_SEC` COMMENT 는 **NULL** 이다
--      이 뷰는 SV_AD 가 소비하는 helper 이며 소유주가 `05_SV-Agent_ai/` 스크립트다
--      → **사용자 실행 범위**이므로 본 스크립트에서 건드리지 않는다(§4 에 잔여로 등재).
select table_name, column_name,
       coalesce(comment,'🔴 COMMENT 없음 — SV description 공백') as comment_state
from GN_DW.INFORMATION_SCHEMA.COLUMNS
where table_schema='SERVING' and table_name='FACT_AD_COMBINED' and column_name='DURATION_SEC';

-- 3-6. 두 체계 혼입 기준선 재확인 (배선 전 · 기대: 8행)
select case when f.EVENT_SK = 0 then '고아(EVENT_SK=0)' else e.EVENT_KIND end as event_kind,
       case when f.PART_STATUS is null then 'NULL'
            when f.PART_STATUS in ('1','2','3','4','5','6') then '소정수 1~6 (CRMN)'
            when f.PART_STATUS in ('110','120','130','140','150','160','170','180','190','200','210','220')
                 then 'MS304 (EVENT)'
            else '오염값 <'||f.PART_STATUS||'>' end as code_system,
       count(*) as cnt
from GN_DW.GOLD.FACT_EVENT_PARTICIPATION f
left join GN_DW.GOLD.DIM_EVENT e on e.EVENT_SK = f.EVENT_SK
group by all
order by event_kind, cnt desc;

-- 3-5. O29 기준선 재확인 (배선 전 · 기대: 1,151 채움 · 3종 값)
select DURATION_SEC, count(*) as cnt
from GN_DW.GOLD.FACT_AD_BROADCAST
group by all
order by cnt desc;


-- ============================================================================
-- §4. 잔여 — 본 스크립트 범위 밖 (사용자 실행 또는 결정 필요)
-- ============================================================================
-- | # | 항목 | 왜 여기서 안 했는가 |
-- |---|---|---|
-- | 1 | `models/gold/wide/WIDE_EVENT_PARTICIPATION.sql`·`WIDE_AD_BROADCAST.sql` post_hook 수정 반영 | ✅ 파일은 본 세션 수정 완료. **다음 `dbt build` 에서 물리 확정**된다(그 전까지는 §2-B ALTER 가 보호) |
-- | 2 | `SERVING.FACT_AD_COMBINED.DURATION_SEC` COMMENT 공백 | 소유주 = `05_SV-Agent_ai/` (SV helper). **사용자 실행 범위** — SV 재배포 시 O29 경고 삽입 필요 |
-- | 3 | SV `SV_EVENT_PARTICIPATION` 의 참여상태 차원 COMMENT | 소유주 = `05_SV_DDL.sql`. **사용자 실행 범위** · `CREATE OR REPLACE SEMANTIC VIEW` 가 GRANT 파괴 → §7 GRANT 재실행 필수 |
-- | 4 | O28 소정수 1~6 의미 확정 → FEP 카운트 5종 배선 | 🔴 **현업 회신 필수**(문서20 §I). 대조 판별력 0 실측(118 그룹) — 추정 배선은 결손 창작 |
-- | 5 | O29 SILVER HH:MM:SS 파싱 배선 (96.6% 회복) | 🟢 무추론·즉시 가능하나 **모델 수정 + dbt build** 필요 → 사용자 build 순서 대기 |
-- | 6 | O29 숫자 3종(30/60/90 ×10^6) µs 변환 | 🔴 **현업 확인 필수**. 확인 전 NULL 이 현 상태(틀린 값)보다 안전 |
-- | 7 | `DIM_AD_CREATIVE.DURATION_SEC` 중복축 DROP vs 통합 | 🟠 **사용자 결정 대기**(§18-D ①) |
-- | 8 | 오염값 `)` 2행 처리 | 🔴 **BRONZE 원천 입력 오류로 재분류**(SILVER 결함 아님 — §0 [O28-5]). 현업 원천 정정 또는 센티넬 라우팅 결정 |
-- | 9 | 🆕 CRMN 참여일 전건 NULL → FEP `DATE_SK` 가 행사시작일로 대체 귀속 | ⬜ **신규 제기**(§0 [O29-4] 부수). 참여일 기반 시계열에서 캠페인행사 152,127행은 실참여시점이 아니다 |
-- | 10 | 🆕 `FACT_AD_BROADCAST` 행수 38,486 vs 문서 37,886 | ⬜ **신규 제기**. 원인 미규명 → 재측정 전 인용 금지(PROC-3 (c)) |
-- ============================================================================
