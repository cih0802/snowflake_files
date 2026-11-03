create or replace view WIDE_TARGET_BIZ(
	MONTH_KEY COMMENT '목표월 YYYYMM',
	CAL_YEAR COMMENT 'FLOOR(MONTH_KEY/100) — 연도',
	CAL_MONTH COMMENT 'MOD(MONTH_KEY,100) — 월',
	ANNUAL_GOAL_CNT COMMENT '당초 목표값(#152). 🔴 단위는 GOAL_TYPE_NM 에 따른다(건·명·원·비율) — 유형 필터 없이 합산 금지 · O190',
	SUPP_GOAL_CNT COMMENT '추경목표(건) (#153)',
	ANNUAL_CUM_GOAL_CNT COMMENT '연사업누계목표(건) (#154)',
	SUPP_CUM_GOAL_CNT COMMENT '추경누계목표(건) (#155)',
	DW_SOURCE_SYSTEM COMMENT '원천 시스템 식별',
	ORG_CORP COMMENT 'DIM_ORG.CORP — 법인 (#114). 🔴DIM_ORG 는 **SCD1**(DEC-2)이라 as-was 가 아니다 — 조직 개편 시 과거 사건에도 **현재 조직명**이 붙는다(조직 변경이력 원천·as-was 요구가 없어 SCD1 로 확정).',
	ORG_DIVISION COMMENT 'DIM_ORG.DIVISION — 본부/지부 (#115). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다.',
	ORG_DEPARTMENT COMMENT 'DIM_ORG.DEPARTMENT — 부서 (#116). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴「부서」는 축이 둘이다 — 이 컬럼은 **사건 부서**이고 획득 부서는 DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT 다(O34).',
	ORG_TEAM COMMENT 'DIM_ORG.TEAM — 팀. 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다.',
	SPONSORSHIP_BK COMMENT 'DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키',
	SPONSORSHIP_NAME COMMENT 'DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123)',
	CAMPAIGN_BK COMMENT 'DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키',
	CAMPAIGN_BRAND COMMENT 'DIM_CAMPAIGN.BRAND — 공통브랜드 (#117)',
	CAMPAIGN_NAME COMMENT 'DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120)',
	GOAL_TYPE_NM COMMENT '목표 지표 유형 원천 표기 그대로(O190 · 9종): 건 = 후원사업·회원개발 / 명 = 월말활동회원 / 원 = 정기회비 / 비율 = 후원사업활동율·신규기존활동율·후원사업납입율·신규기존납입율·신규기존누계납입율. 🔴 유형마다 단위가 달라 섞어 합산하지 말 것 · 후원사업과 회원개발은 같은 개발 목표의 다른 분해(문서20 N-24).',
	CPR_DIV_NM COMMENT '법인구분 (사단/사복) (O188).',
	ORG_PATH COMMENT 'O188-E 조직표 부서 경로(DIM_ORG.ORG_PATH · 활성 조직 트리 · 매칭 실패 행은 NULL).',
	SRC_TEAM_NM COMMENT 'O188-E 원천 팀명(TEAM_NM) 그대로 — 조직 차원 매칭 실패(동명·비조직명) 행도 이 값으로 구분된다.',
	SRC_SPONSOR_BIZ_NM COMMENT '원천 후원사업 표기 그대로 — 후원사업 유형 = 사업명 · 회원개발 유형 = 4그룹(국내/결연/해외프로젝트/기타) · O190.',
	NEW_OLD_DIV_NM COMMENT '신규/기존 구분 원천 표기. 🔴 비율 유형에는 소계 행(합계·신규합계)이 있다 — 신규/기존과 함께 합산하면 이중계상. 회원개발 유형은 NULL · O190.',
	ORG_DIV_NM COMMENT 'O188-E 조직구분(본부/지부/대면) — 원천 표기.',
	DTL_DIV_NM COMMENT '세부구분 원천 표기(채널 등 · 회원개발 유형만 · 그 외 NULL) · O190.'
) COMMENT='사업목표 팩트(FTG_B) 평탄화 — ORG·SPONSORSHIP·CAMPAIGN. 월 grain=MONTH_KEY. 🟢[2026-09-29 O188] 입고 배선(TM_CM_MBER_DVLP_GOAL_DIV). 🔴🔴 GOAL_TYPE_NM(9종 · 단위 상이 · O190)으로 반드시 필터 — 후원사업·회원개발은 같은 개발 목표의 다른 분해라 합산 금지(문서20 N-24).'
 as (
      -- WIDE_TARGET_BIZ: 사업목표 팩트(FTG_B) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.4)
-- Co-authored with CoCo
-- 🔧 [2026-08-07 O51-C] materialization 전환: view -> gn_view_commented.
--   깨진 post_hook(`ALTER VIEW ... ALTER COLUMN ... COMMENT` = Snowflake 에 없는 문법) 제거.
--   COMMENT 정본은 `_wide_schema.yml` 로 이관됨 — 뷰=description · 컬럼=columns[].description.
--   ⚠️ columns[] 는 SELECT 와 개수·순서가 일치해야 한다(INFORMATION_SCHEMA 순서로 기계 생성).


select
    f.MONTH_KEY,
    FLOOR(f.MONTH_KEY / 100) as CAL_YEAR,
    MOD(f.MONTH_KEY, 100)    as CAL_MONTH,
    f.ANNUAL_GOAL_CNT, f.SUPP_GOAL_CNT,
    f.ANNUAL_CUM_GOAL_CNT, f.SUPP_CUM_GOAL_CNT,
    f.DW_SOURCE_SYSTEM,
    o.CORP       as ORG_CORP,
    o.DIVISION   as ORG_DIVISION,
    o.DEPARTMENT as ORG_DEPARTMENT,
    o.TEAM       as ORG_TEAM,
    s.SPONSORSHIP_BK,
    s.SPONSORSHIP_NAME,
    c.CAMPAIGN_BK,
    c.BRAND      as CAMPAIGN_BRAND,
    c.CAMPAIGN_NAME,
    -- 🆕 [2026-09-29 O188] 이중계상 가드 전파 — 🔴 GOAL_TYPE_NM 으로 필터하지 않으면 합계가 약 2배(N-24)
    f.GOAL_TYPE_NM,
    f.CPR_DIV_NM,
    -- 🆕 [2026-09-29 O188-E] 조직 경로 + 원천 이름 degen 5축(SV_TARGET_BIZ 노출용 · yml columns 순서 동기)
    o.ORG_PATH,
    f.SRC_TEAM_NM,
    f.SRC_SPONSOR_BIZ_NM,
    f.NEW_OLD_DIV_NM,
    f.ORG_DIV_NM,
    f.DTL_DIV_NM
from GN_DW.GOLD.FACT_TARGET_PROJECT f
left join GN_DW.GOLD.DIM_ORG         o on f.ORG_SK = o.ORG_SK
left join GN_DW.GOLD.DIM_SPONSORSHIP s on f.SPONSORSHIP_SK = s.SPONSORSHIP_SK
left join GN_DW.GOLD.DIM_CAMPAIGN    c on f.CAMPAIGN_SK = c.CAMPAIGN_SK
    );