-- ============================================================================
-- 🔴 [APPLIED 2026-08-05 · 아카이브 이관 · 재실행 금지] — O41 판정
--   본 스크립트의 구조 변경은 **전량 정본 `03_top-down_gold/06_DDL.sql` 에 접혔다**.
--   물리 실측(2026-08-05 재구축 후, 정본 DDL 만 실행한 상태): `DIM_SEND_TYPE` 12컬럼 ·
--   `FSE.SEND_TYPE_SK` · `DIM_EVENT.RECRUIT_HEADCOUNT` · `FEP.PARTCPT_SEQ` ·
--   `DIM_GA_SOURCE.DEFAULT_CHANNEL_GROUP` 존재 / DROP 5컬럼 전건 소멸
--   → 정본 위치: `06_DDL.sql` 236·259·287·301~323·386·603·776·797·798·993~995
--
-- 🔴 **재실행이 정본을 되돌린다** — 아래 §1 의 `SEND_TYPE_L` COMMENT 는 **구버전**이다.
--   정본(`06_DDL.sql:314`)은 *"🔴정본 #133 과 불일치 — #133 6종 vs 실측 라벨 9종
--   (회원만족 MS052·회원서비스 MS054·회원 MS047+MS053)"* 경고를 담고 있으나
--   본 파일에는 그 경고가 없다. 실행하면 경고가 지워진다(P33 역방향).
--
-- 🟢 살아 있는 자산 = **§0 측정근거 · §6 검증쿼리 9종**. 재적재·build 후 검증에 그대로 쓸 수 있다.
--   ⚠️ 단 기대값은 2026-08-04 측정치다 — BRONZE 재적재본과 어긋나면 원인 규명 전 인용 금지(PROC-3 c).
-- ============================================================================

-- DEC-30 구조 변경 — DIM_SEND_TYPE 신설 · 중복축/오배치 컬럼 정리 · FEP degen key (ALTER 전용)
-- Co-authored with CoCo
-- ============================================================================
-- 역할  : GN_DW_ADMIN
-- 정본  : 20_issue/30_설계_의사결정.md §20 (DEC-30) · 진단 = 10_진단_원인분석.md §15-H·§16
-- 측정일: 2026-08-04 (전 항목 BRONZE/SILVER 직접 실측)
-- 순서  : 본 스크립트 §1~§5 실행 → **사용자 `dbt build`** → §6 검증
--
-- 🔴 `CREATE OR REPLACE TABLE` 금지(FK·GRANT 파괴). 기존 테이블은 `ALTER` 만 사용한다.
--    `DIM_SEND_TYPE` 은 **신규 객체**이므로 CREATE 가 정상이다(파괴 대상 없음).
--
-- 🔴 컬럼 DROP 이 포함된다 — 되돌리려면 `ALTER TABLE ... ADD COLUMN` + 재빌드가 필요하다.
--    DROP 대상은 전부 **전건 NULL 또는 전건 0**(미주입)임을 §0 에서 실측 확인했다 → 데이터 손실 0.
-- ============================================================================


-- ============================================================================
-- §0. DROP 안전성 실측 근거 (실행 불요 · 재현용)
-- ============================================================================
-- 🟢 DROP 대상 전건이 미주입이므로 값 손실이 없다(2026-08-04 실측):
--   · DIM_SERVICE.SEND_TYPE_L/M/S      : 11행 전건 NULL (채움 0 · distinct 0)
--   · DIM_AD_CREATIVE.DURATION_SEC     : 전건 NULL (모델이 CAST(NULL) 하드코딩)
--   · FACT_EVENT_PARTICIPATION.RECRUIT_CNT : 1,134,126행 전건 0
--
-- 🔴 `DIM_AD_CREATIVE.DURATION_SEC` DROP 의 결정적 근거 — 초수는 소재에 함수종속하지 않는다:
--     with v as (select TRIM(MATR_NM) creative,
--                       <HH:MM:SS→초> sec from GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS)
--     select count_if(sec_d=1), count_if(sec_d>1), max(sec_d)
--     from (select creative, count(distinct sec) sec_d from v group by all);
--   → 소재 41종 중 **단일 초수 22 · 복수 초수 19(최대 3종)** = 함수종속 **53.7% 뿐**
--   → 같은 소재가 30초·60초·90초 편집본으로 송출된다 ⇒ 초수는 **소재 속성이 아니라 방송 속성**이다.
--   ⇒ 정본 소재지 = `FACT_AD_BROADCAST.DURATION_SEC`(방송 grain) 확정. 차원 사본은 오배치.
--
-- 🔴 `FEP.RECRUIT_CNT` DROP 의 결정적 근거 — 참여 grain 에서 101배 과대계상:
--     행사 grain 참값 SUM = 4,513,184 vs 참여행마다 반복 시 SUM = 456,007,553 (**101.0배**)
--     최대 3,718 참여/행사 · 참여 0인 행사 58건
--   ⇒ 모집인원은 행사 속성 ⇒ `DIM_EVENT` 로 이관(§3).
--
-- 🟢 `DIM_SEND_TYPE` 신설의 결정적 근거 — 커버리지 분모가 잘못돼 있었다(P39):
--   DEC-28 §18-C 는 커버리지를 **0.106%(1,707/1,614,397 요청)** 로 적어 저가치로 판단했다.
--   그러나 소비 grain(발송×회원 = `FACT_SERVICE_EVENT`)에서 측정하면:
--     select count(*), count_if(r.SEND_GBN_TOP is not null) from CRM_SEND_MEMBER s
--     left join CRM_SEND_REQUEST r using(SNDNG_KEY) where s.MBER_NO is not null;
--   → **8,300,272 / 38,470,780 = 21.58%**
--   원인 = send-type 이 붙은 요청은 **평균 4,862.5명** 발송(없는 요청은 18.7명) → **260배 차이**.
--   ⇒ 요청 grain 분모는 이 축의 업무 가치를 **200배 과소평가**했다. 신설 정당.
--
-- 🟢 계층 키 구조 실측 — 라벨이 전체 경로에 함수종속한다:
--   TOP 12종 · MID 코드 16종이나 **MID 라벨 26종** → **MID 코드 단독은 모호**하다
--   (TOP,MID) 38쌍 = (TOP,MID,MID_NM) 38 · (TOP,MID,BOT) **65** = 라벨 결합 **65** · NULL 0
--   ⇒ 자연키 = **(TOP, MID, BOT) 3단 전체 경로**. 단일 레벨 키로는 차원을 만들 수 없다.
-- ============================================================================


-- ============================================================================
-- §1. DIM_SEND_TYPE 신설 — 발송구분 대/중/소 (정본 지표 #133·#134·#135)
-- ============================================================================
-- 설계: 계층 3단을 **한 차원에 평탄화**(Kimball 표준). 65행 + 센티넬 1 = 66행 예상.
--   · grain = (SEND_GBN_TOP, SEND_GBN_MID, SEND_GBN_BOT) — 라벨 100% 함수종속(실측)
--   · DEC-25 준수: **코드는 BRONZE 원천명 · 라벨은 분석용어**로 병기한다
--   · `DIM_SERVICE` 는 건드리지 않으므로 `SERVICE_SK`(FSE 99.97% 적재)가 보존된다
CREATE TABLE IF NOT EXISTS GN_DW.GOLD.DIM_SEND_TYPE (
    SEND_TYPE_SK        NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '발송구분 대리키 (ETL 해시, PK)',
    SEND_TYPE_BK        VARCHAR         NOT NULL COMMENT '발송구분 업무키 = 대>중>소 코드 경로(자연키). ⚠️중분류 코드는 단독으로 모호하다(코드 16종 vs 라벨 26종) → 반드시 전체 경로로 식별한다',
    SEND_GBN_TOP        VARCHAR         COMMENT '발송구분 대 코드 raw ← CRM_SEND_REQUEST.SEND_GBN_TOP. ⚠️이 값은 코드가 아니라 CRM_CODE.CD_ID(코드그룹 ID) 자체다 — MS046 결연·MS047 회원·MS048 회비·MS049 서비스·MS050 사업보고 등 12종. 라벨=SEND_TYPE_L',
    SEND_TYPE_L         VARCHAR         COMMENT '발송구분(대) (#133) 분석 라벨 ← SEND_GBN_TOP_NM. 정본 값정의: 결연/회비/서비스/사업보고/참여/기타',
    SEND_GBN_MID        VARCHAR         COMMENT '발송구분 중 코드 raw ← SEND_GBN_MID. 🔴 코드 단독 사용 금지 — 실측 코드 16종에 라벨 26종이 대응한다(부모 그룹에 따라 의미가 달라짐). 반드시 (대,중) 쌍으로 해석',
    SEND_TYPE_M         VARCHAR         COMMENT '발송구분(중) (#134) 분석 라벨 ← SEND_GBN_MID_NM. 정본 값정의: 선물금/신규결연회원발송/회원서신/만18세아동종결/일반퇴소 등',
    SEND_GBN_BOT        VARCHAR         COMMENT '발송구분 소 코드 raw ← SEND_GBN_BOT (CRM_CODE.UPPER_CD_ID 계층 하위). 🔴 코드 단독 모호(코드 42종 vs 라벨 56종) → (대,중,소) 경로로 해석',
    SEND_TYPE_S         VARCHAR         COMMENT '발송구분(소) (#135) 분석 라벨 ← SEND_GBN_BOT_NM. 정본 값정의: 선물금접수확인/신규결연우편물(PF)/결연100일/서신접수확인/첫출금안내(사단) 등',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '발송구분 차원 — 대/중/소 3단 계층 평탄화 (정본 지표 #133·#134·#135). grain=(대,중,소) 코드 경로 65조합 + 센티넬. 🟢FACT_SERVICE_EVENT 소비 커버리지 실측 21.58%(8,300,272/38,470,780) — 요청 grain 0.106% 는 잘못된 분모다(P39). ⚠️DEC-28 §18-C 가 DIM_SERVICE grain 확장 대신 차원 분리를 택한 이유 = SERVICE_SK(FSE 99.97% 적재) 보존.';

-- 🔴 1-B. 소유권 정렬 — **반드시 실행할 것**
--   GOLD 전 테이블의 소유 역할은 `GN_DW_ADMIN` 이다. 그런데 세션 역할이 `ACCOUNTADMIN` 인 상태로
--   CREATE 하면 소유자가 `ACCOUNTADMIN` 이 되어 **다른 테이블과 어긋난다**(본 세션 실제 발생·자기검토에서 적발).
--   `INFORMATION_SCHEMA.TABLES.TABLE_OWNER` 로 확인 가능하다.
--   ⚠️ `COPY CURRENT GRANTS` 없이 넘기면 소비 역할(ANALYST·VIEWER·SERVICE)의 SELECT 가 날아간다.
GRANT OWNERSHIP ON TABLE GN_DW.GOLD.DIM_SEND_TYPE TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS;
-- 🟢 future grant 확인: 신규 GOLD 테이블은 GN_DW_ADMIN/ANALYST/ENGINEER/SERVICE/VIEWER 권한이
--    자동 부여된다(본 세션 실측 20건) → 수동 GRANT 불요.


-- ============================================================================
-- §2. FACT_SERVICE_EVENT — SEND_TYPE_SK FK 신설
-- ============================================================================
ALTER TABLE GN_DW.GOLD.FACT_SERVICE_EVENT
  ADD COLUMN IF NOT EXISTS SEND_TYPE_SK NUMBER(38,0)
  COMMENT '발송구분 (FK→DIM_SEND_TYPE). 🟢커버리지 실측 21.58%(8,300,272/38,470,780) — 발송요청에 구분값이 없으면 센티넬 0. ⚠️0 은 (미매핑)이며 "발송구분 없음"이 아니다';


-- ============================================================================
-- §3. DIM_EVENT — 모집인원 이관 (FEP 참여 grain → 행사 차원)
-- ============================================================================
ALTER TABLE GN_DW.GOLD.DIM_EVENT
  ADD COLUMN IF NOT EXISTS RECRUIT_HEADCOUNT NUMBER(38,0)
  COMMENT '모집인원 ← SILVER.CRM_EVENT.RCRIT_PSNNL_CO. 채움 3,361/3,786=88.8%·74종. 🔴행사 속성이므로 참여 팩트가 아니라 **행사 차원**이 정본이다 — 참여행마다 반복하면 SUM 이 101.0배 과대계상된다(행사 grain 참값 4,513,184 vs 참여 grain 456,007,553 · 최대 3,718참여/행사). ⚠️비가산 축이 아니라 **행사 단위 정원**이므로 행사 목록에서만 합산한다';


-- ============================================================================
-- §4. FACT_EVENT_PARTICIPATION — degenerate key 신설 + 오배치 measure DROP
-- ============================================================================
-- 4-A. 행 식별자(degenerate key) — A군 잔여 해소
--   실측: (EVENT_KEY, MEMBER_DK, PARTCPT_SEQ) 가 유일(1,134,126 = 행수)이나
--         (행사, 회원) 만으로는 802,298 ≠ 1,134,126 로 중복 → 행을 특정할 수 없었다.
ALTER TABLE GN_DW.GOLD.FACT_EVENT_PARTICIPATION
  ADD COLUMN IF NOT EXISTS PARTCPT_SEQ NUMBER(38,0)
  COMMENT 'degenerate key — 참여 일련번호 ← SILVER.CRM_EVENT_PARTICIPATION.PARTCPT_SEQ (채움 100%). 🔷(EVENT_SK, MEMBER_DK, PARTCPT_SEQ) 가 행을 유일 식별한다 — (행사,회원)만으로는 802,298 ≠ 1,134,126 로 중복된다. ⚠️전역 일련번호가 아니다((행사,SEQ) 조합 201,817 로 회원 간 중복) · ⚠️원천 품질 주의: 음수 20,844행(765행사·12,333회원) 및 INT_MIN(-2147483647) 1행 존재 → 정렬·범위 조건에 쓰지 말고 식별자로만 쓸 것';

-- 4-B. 🔴 RECRUIT_CNT DROP — §3 으로 이관 완료(참여 grain 함수종속 불성립)
ALTER TABLE GN_DW.GOLD.FACT_EVENT_PARTICIPATION DROP COLUMN IF EXISTS RECRUIT_CNT;


-- ============================================================================
-- §5. 중복축 DROP — 전건 미주입 확인 완료
-- ============================================================================
-- 5-A. DIM_AD_CREATIVE.DURATION_SEC — 방송 속성이 소재차원에 오배치(§0 실측: 함수종속 53.7%)
ALTER TABLE GN_DW.GOLD.DIM_AD_CREATIVE DROP COLUMN IF EXISTS DURATION_SEC;

-- 5-B. DIM_SERVICE.SEND_TYPE_L/M/S — DIM_SEND_TYPE 로 이관(정본 지표는 소멸하지 않는다)
--   ⚠️ DEC-28 §18-C 의 "DROP 금지" 는 **대체 소재지 없이 지우는 것**을 금지한 것이다.
--      §1 에서 정본 소재지를 만들었으므로 이 사본 3컬럼은 §18-D ① 중복축으로 확정된다.
ALTER TABLE GN_DW.GOLD.DIM_SERVICE DROP COLUMN IF EXISTS SEND_TYPE_L;
ALTER TABLE GN_DW.GOLD.DIM_SERVICE DROP COLUMN IF EXISTS SEND_TYPE_M;
ALTER TABLE GN_DW.GOLD.DIM_SERVICE DROP COLUMN IF EXISTS SEND_TYPE_S;


-- ============================================================================
-- §5-C. DIM_GA_SOURCE — GA4 표준 채널그룹 신설 (E군 배선후보)
-- ============================================================================
ALTER TABLE GN_DW.GOLD.DIM_GA_SOURCE
  ADD COLUMN IF NOT EXISTS DEFAULT_CHANNEL_GROUP VARCHAR
  COMMENT 'GA4 표준 채널그룹 ← SILVER.GA4_TRAFFIC_SOURCE.DEFAULT_CHANNEL_GROUP. 채움 2,167/2,167=100%·14종. grain (UTM_SOURCE,UTM_MEDIUM) 에 93.8% 함수종속(다중값 9/146·최대 4종)이라 MAX() 대표값 — 기존 UTM_CONTENT/TERM 과 동일 패턴. ⚠️`SOURCE_MEDIUM`(source/medium 이어붙인 파생 문자열)과 **다른 개념**이다 — 이쪽은 GA4 가 산정한 표준 채널 분류다';


-- ============================================================================
-- §6. 검증 (dbt build 이후 실행 · P33: 완료 판정은 INFORMATION_SCHEMA/실측)
-- ============================================================================

-- 6-1. 구조 반영 확인 (기대: 신설 3 = 🟢 · DROP 5 = 🟢)
select '신설 DIM_SEND_TYPE' as chk,
       case when count(*)=12 then '🟢 12컬럼' else '⚠️ '||count(*)||'컬럼' end as result
from GN_DW.INFORMATION_SCHEMA.COLUMNS where table_schema='GOLD' and table_name='DIM_SEND_TYPE'
union all
select '신설 FSE.SEND_TYPE_SK',
       case when count(*)=1 then '🟢' else '⚠️ 미반영' end
from GN_DW.INFORMATION_SCHEMA.COLUMNS
where table_schema='GOLD' and table_name='FACT_SERVICE_EVENT' and column_name='SEND_TYPE_SK'
union all
select '신설 DIM_EVENT.RECRUIT_HEADCOUNT',
       case when count(*)=1 then '🟢' else '⚠️ 미반영' end
from GN_DW.INFORMATION_SCHEMA.COLUMNS
where table_schema='GOLD' and table_name='DIM_EVENT' and column_name='RECRUIT_HEADCOUNT'
union all
select '신설 FEP.PARTCPT_SEQ',
       case when count(*)=1 then '🟢' else '⚠️ 미반영' end
from GN_DW.INFORMATION_SCHEMA.COLUMNS
where table_schema='GOLD' and table_name='FACT_EVENT_PARTICIPATION' and column_name='PARTCPT_SEQ'
union all
select 'DROP 확인 (기대 0건)',
       case when count(*)=0 then '🟢 전건 제거' else '⚠️ '||count(*)||'건 잔존' end
from GN_DW.INFORMATION_SCHEMA.COLUMNS
where table_schema='GOLD'
  and ( (table_name='DIM_AD_CREATIVE' and column_name='DURATION_SEC')
     or (table_name='DIM_SERVICE'     and column_name in ('SEND_TYPE_L','SEND_TYPE_M','SEND_TYPE_S'))
     or (table_name='FACT_EVENT_PARTICIPATION' and column_name='RECRUIT_CNT') );

-- 6-2. DIM_SEND_TYPE 적재 검증 (기대: 66행 = 65경로 + 센티넬 · SK 유일 · 라벨 100%)
select count(*) as rows_total,
       count(distinct SEND_TYPE_SK) as sk_distinct,
       count_if(SEND_TYPE_SK=0) as sentinel,
       count(SEND_TYPE_L) as l_hit, count(SEND_TYPE_M) as m_hit, count(SEND_TYPE_S) as s_hit,
       count(distinct SEND_TYPE_L) as l_d, count(distinct SEND_TYPE_M) as m_d, count(distinct SEND_TYPE_S) as s_d
from GN_DW.GOLD.DIM_SEND_TYPE;

-- 6-3. FSE 배선 검증 (기대: 행수 38,470,780 불변 · SEND_TYPE_SK 비센티넬 8,300,272 = 21.58%)
select count(*) as fse_rows,
       count_if(SEND_TYPE_SK <> 0) as sendtype_matched,
       round(100.0*count_if(SEND_TYPE_SK <> 0)/count(*),2) as pct,
       count_if(SEND_TYPE_SK is null) as null_sk_should_be_0
from GN_DW.GOLD.FACT_SERVICE_EVENT;

-- 6-4. 🔴 고아 검증 — FSE.SEND_TYPE_SK 가 차원에 전부 존재해야 한다 (기대: 0행)
select count(*) as orphan_send_type_sk
from GN_DW.GOLD.FACT_SERVICE_EVENT f
left join GN_DW.GOLD.DIM_SEND_TYPE d on d.SEND_TYPE_SK = f.SEND_TYPE_SK
where d.SEND_TYPE_SK is null;

-- 6-5. DIM_EVENT 모집인원 검증 (기대: 채움 3,361 · SUM 4,513,184 = 행사 grain 참값)
select count(*) as event_rows,
       count(RECRUIT_HEADCOUNT) as recruit_hit,
       sum(RECRUIT_HEADCOUNT) as recruit_sum,
       count(distinct RECRUIT_HEADCOUNT) as recruit_d
from GN_DW.GOLD.DIM_EVENT;

-- 6-6. FEP degen key 검증 (기대: 행수 1,134,126 불변 · 3키 조합 유일 = 행수)
select count(*) as rows_total,
       count(PARTCPT_SEQ) as seq_hit,
       count(distinct EVENT_SK||'|'||MEMBER_DK||'|'||PARTCPT_SEQ) as triple_distinct
from GN_DW.GOLD.FACT_EVENT_PARTICIPATION;

-- 6-7. O29 파싱 검증 (기대: 채움 33,890→ VIDEO 기준 93.1% · 값 집합 {30,60,90,120})
select DURATION_SEC, count(*) as cnt
from GN_DW.GOLD.FACT_AD_BROADCAST group by all order by DURATION_SEC nulls last;

-- 6-8. GA 채널그룹 배선 검증 (기대: 채움 100% · 14종 + 센티넬)
select count(*) as rows_total,
       count(DEFAULT_CHANNEL_GROUP) as dcg_hit,
       count(distinct DEFAULT_CHANNEL_GROUP) as dcg_d
from GN_DW.GOLD.DIM_GA_SOURCE;

-- 6-9. GRANT 확인 — 신규 테이블은 future grant 대상인지 확인 (기대: 권한 존재)
show grants on table GN_DW.GOLD.DIM_SEND_TYPE;
