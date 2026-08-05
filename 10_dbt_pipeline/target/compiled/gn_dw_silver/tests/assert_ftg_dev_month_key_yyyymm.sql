-- [2026-08-05 O38] FACT_TARGET_DEV.MONTH_KEY 는 YYYYMM 6자리여야 한다.
-- Co-authored with CoCo
--
-- 왜 이 테스트가 필요한가: 종전 모델이 `TRY_TO_NUMBER(STDR_MT)` 로 월 번호(1~12)만 적재했고
--   `STDYY`(기준연)를 버렸다. 이 결함은 행수·SUM·not_null·참조무결성을 **전부 통과**했다 —
--   목표 합계가 원천과 정확히 일치했기 때문이다(연도만 뭉개져 재분배됐다).
--   결과적으로 "2026년 1월 목표"가 2012~2026년 1월 목표의 합으로 조용히 답해졌다.
--   값 검사가 아니라 **규약 검사**만이 이 유형을 잡는다.
--
-- 위반 조건: 0(Unknown 센티넬 라우팅)이 아니면서
--   ① 캘린더 범위(199101~203512) 밖 — 5자리 유령키·월 번호가 여기 걸린다
--   ② 월 부분이 01~12 가 아님
--
-- ⚠️ dbt_utils 미설치(trial EAI 불가)이므로 schema 테스트가 아니라 singular test 로 구현했다.
-- ⚠️ 범위 리터럴은 `dbt_project.yml` vars(cal_start·cal_end)와 연동해 하드코딩을 피한다.
--
-- 🔴 Jinja 태그에 **양방향 공백제거 마커(대시)를 쓰지 말 것** — 앞뒤 개행이 함께 지워져
--    뒤따르는 `select` 가 직전 `--` 주석 줄로 끌어올려지고 **통째로 주석 처리**된다.
--    2026-08-05 실측: build ERROR 1 · "syntax error unexpected 'MONTH_KEY'".
--    아래 set 블록처럼 마커 없는 기본 태그를 써서 개행을 보존한다.
--    ⚠️ 이 주석에 마커 문법을 그대로 적으면 Jinja 가 주석 안에서도 파싱해 "tag name expected" 로
--       컴파일이 깨진다(같은 세션에서 실측). 문법은 예시로 적지 않는다.




select
    MONTH_KEY,
    count(*) as VIOLATING_ROWS
from GN_DW.GOLD.FACT_TARGET_DEV
where MONTH_KEY <> 0
  and (
        MONTH_KEY not between 199101 and 203512
     or MOD(MONTH_KEY, 100) not between 1 and 12
      )
group by MONTH_KEY