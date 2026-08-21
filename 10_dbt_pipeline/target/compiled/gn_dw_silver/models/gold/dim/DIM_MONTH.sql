-- DIM_MONTH: 월 차원 (DIM_DATE 의 월 축 사영) [2026-08-10 O53 신설]
-- Co-authored with CoCo
--
-- 🔴 왜 필요한가 (fan-out 차단)
--   월 팩트(FACT_MEMBER_MONTHLY·FACT_BUDGET·FACT_TARGET_DEV·FACT_TARGET_BIZ)의 시간축은 `MONTH_KEY` 다.
--   그런데 `DIM_DATE` 는 **일 grain**(캘린더 전량)이라 월팩트를 거기에 직접 조인하면 한 달이 그 달의
--   일수만큼 복제된다 — 금액·건수가 조용히 28~31배로 부푼다. 에러도 경고도 없다.
--   ⇒ 월 축 전용 차원을 두고 월팩트는 **반드시 이쪽**으로 조인한다(SV 설계 원칙10·R1).
--
-- 🔴 왜 GOLD 인가 (종전에는 SERVING 에만 있었다)
--   `SERVING.DIM_MONTH` helper 뷰가 같은 일을 하고 있었으나, SV 가 GOLD 만 참조하도록 계층을 정리했다
--   (DEC-34 · 사용자 결정 2026-08-10). SERVING helper 3종 정리는 로드맵 7단계 소관이다.
--
-- ⚠️ 정의를 여기서 만들지 않는다 — `DIM_DATE` 의 사영일 뿐이다. 연·월·분기 산식을 이 모델에서
--   다시 계산하면 두 차원이 갈라진다(P85). `DIM_DATE` 의 컬럼을 그대로 가져온다.
--
-- ⚠️ 구조·COMMENT 소유주 = `03_top-down_gold/06_DDL.sql`(생성기 `scripts/gen_o53_gold_ddl.py`).
--   SELECT 컬럼·순서를 바꾸면 그 블록을 동시에 재생성할 것.
--
-- ⚠️ 머티리얼라이제이션 = `incremental` + `append` + `pre_hook TRUNCATE`.
--   완전 재산출 차원이라 merge 를 쓰면 캘린더 범위 축소 시 구 월이 잔존한다(문서50 §300 R1 · P131).


select
    MONTH_KEY,
    YEAR,
    MONTH,
    QUARTER,
    'DW'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '57be0253-4fb4-4b86-9e2e-7ed1d1292984'                    AS DW_BATCH_ID
from GN_DW.GOLD.DIM_DATE
group by MONTH_KEY, YEAR, MONTH, QUARTER