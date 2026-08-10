-- GN_DW 3단계: Semantic View DDL — **분할 인덱스 + 전체 배포 검증 + 공통 규약 정본** (`05_0`)
-- Co-authored with CoCo
-- ============================================================================
-- 🔴🔴 이 파일에는 SEMANTIC VIEW 정의가 **없다**. 실행해도 SV 가 배포되지 않는다.
--     [2026-08-05 O37] SV 6종 정의를 SV 단위 파일로 **분할**했다. 아래 매핑표의 파일을 실행할 것.
--     ⚠️ 이 파일은 폐기 스텁이 아니다 — **전체 배포 검증 쿼리(실행 라인 있음)**와 **공통 규약 정본**을
--        담당한다. 종전 인용처(문서 다수)가 이 파일을 계속 가리켜도 유효하다.
--
-- ▶ 왜 분할했나
--   종전 단일 파일은 708행·85KB 였다. SV 하나를 고칠 때마다 파일 전체를 읽고 재작성해야 해서
--   **손대지 않은 SV 의 COMMENT 를 훼손할 경로**였다(O27→O30 · P58 과 같은 유형). 신규 SV 추가도
--   기존 파일 편집을 강제했다. SV 단위로 쪼개면 편집 반경이 대상 SV 로 국한되고,
--   신규 SV 추가는 **새 파일 1개 · 기존 파일 편집 0** 이 된다.
--
-- ▶ 분할 매핑 (실행 순서 의존 없음 — 각 파일이 완전 독립)
--   | 파일                                  | SV                       | 동봉 |
--   |---------------------------------------|--------------------------|------|
--   | **05_0_SV_DDL.sql (본 파일)**          | — (정의 없음)             | 인덱스 · 공통규약 · 전체 배포 검증 |
--   | 05_1_SV_DDL_MEMBER_MONTHLY.sql        | SV_MEMBER_MONTHLY        | GRANT 3 + 스모크 |
--   | 05_2_SV_DDL_MEMBER_EVENT.sql          | SV_MEMBER_EVENT          | GRANT 3 + 스모크 |
--   | 05_3_SV_DDL_MEMBER_COHORT.sql         | SV_MEMBER_COHORT         | GRANT 3 + 스모크 (2026-08-05 O37 신설·배포완료) |
--   | 05_4_SV_DDL_SERVICE.sql               | SV_SERVICE               | GRANT 3 + 스모크 |
--   | 05_5_SV_DDL_EVENT_PARTICIPATION.sql   | SV_EVENT_PARTICIPATION   | GRANT 3 |
--   | 05_6_SV_DDL_BUDGET.sql                | SV_BUDGET                | GRANT 3 |
--   | 05_7_SV_DDL_AD.sql                    | SV_AD                    | helper 뷰 FACT_AD_COMBINED + GRANT 3 + 스모크 |
--   | 05_8_SV_DDL_DEV_ACHIEVEMENT.sql       | SV_DEV_ACHIEVEMENT       | GRANT 3 + 스모크 (2026-08-05 O38 신설·배포완료) |
--
--   🔴 각 파일은 `USE ROLE`/`USE WAREHOUSE`/`USE SCHEMA` + SV 정의 + 자기 GRANT + 자기 스모크를
--      모두 포함한다 → **필요한 파일만 단독 실행**하면 된다. 파일 간 순서 규약이 없으므로
--      순서 문서가 stale 되는 실패 경로(P62)가 원천적으로 없다.
--   🔴 `05_7` 의 helper 뷰 `FACT_AD_COMBINED` 는 `SV_AD` 의 단일 base 다 → 독립 실행을 위해
--      의도적으로 같은 파일에 동봉했다. 이것이 유일한 교차 의존이었다.
--   ⚠️ 분할 검증(2026-08-05): 분할 전 `GET_DDL` 채취 → 분할 파일 실행 → 재채취 대조 결과
--      **SV 6종 정의 전부 byte-identical** · owner 통일 · GRANT 3역할 보존 실측.
--   🆕 **SV 7종**(2026-08-05 O37): `SV_MEMBER_COHORT` 신설 — **캠페인별 중단률(이탈률)의 정본**.
--   🆕 **SV 8종**(2026-08-05 O38): `SV_DEV_ACHIEVEMENT` 신설 — **회원개발 목표 대비 실적·달성율의 정본**
--      (마케팅 장표 「1. 개발현황(목표,실적)」 · 정본 지표 공#1·#2·#3). base = `GOLD.FACT_DEV_ACHIEVEMENT`.
--      🔴 이 SV 는 **단일 논리테이블**이라 SERVING helper 뷰에 의존하지 않는다(다른 SV 와 선행조건이 다르다).
--      종전 Agent 가 "중단 사건에 캠페인이 없어 산출 불가"라고 답했던 것을 해소했다.
--      🔴 중단 **건수**는 `SV_MEMBER_EVENT`, 중단 **률**은 `SV_MEMBER_COHORT` 다(grain 이 다르다 —
--         전자는 일×회원×사건, 후자는 회원 1행). 두 SV 의 값을 더하거나 나누지 않는다.
--      🔴 중단률은 **12개월 고정 이탈률**을 쓴다. 누적 이탈률은 관측 기간에 지배되어 실행 연도가
--         다른 캠페인 비교를 왜곡한다(획득연도만으로 단조 감소하는 것을 실측).
--      ⚠️ metric 명은 원본 컬럼명과 달라야 한다 — 같으면 metric 식의 `SUM(<이름>)` 이 컬럼이 아니라
--         metric 으로 해석돼 `Invalid metric definition` 으로 컴파일 실패한다(실측 확인 → `TOTAL_` 접두).
--
-- ▶ 선행 조건 (모든 05_* 파일 공통)
--   ① GOLD 적재 완료(`dbt build`)
--   ② **`02_GN_DW_building/08_After_Deploy_DBT.sql` §G** — SERVING helper 뷰
--      (`DIM_MONTH`·`DIM_MEMBER_CURRENT`). SV 가 논리테이블로 참조하므로 필수 선행.
--      ⚠ `02_SERVING_setup.sql`·`07_ENVIRONMENT_RBAC_setup.sql` 이 아니다(O36 실측 교정).
--   ⚠ 반드시 `GN_DW_ADMIN` 역할로 실행한다(ACCOUNTADMIN 이면 소유권 어긋남 · 복구 SQL = 아래 §8-11).
--
-- ▶ 실행 순서 (신규 계정 재현) — 🔴 정본 = `02_GN_DW_building/06_RUNBOOK.md` §11.2-C
--   07_ENVIRONMENT_RBAC_setup.sql → GOLD/SILVER DDL → dbt build
--   → 08_After_Deploy_DBT.sql §G(helper 뷰) → **05_1 ~ 05_8 (전부 또는 필요분)**
--   → 09_1_AGENT_생성.sql(껍데기) → 09_2_AGENT_버전업.sql(스펙 본문)
--   🔴 `09_2` 를 빼면 Agent 스펙이 `{"models":{"orchestration":"auto"}}` 로 남아 도구가 0개다.
--   ⛔ `13_SV_AD_배포_추가작업.sql`·`09_AGENT_spec_구현.sql`·`02_SERVING_setup.sql` 은 실행하지 않는다
--      (전부 DEPRECATED 포인터 스텁 · 실행 라인 0개).
-- ============================================================================


/* =====================================================================================
   §공통 규약 (정본) — 모든 05_* 파일이 이 규약을 따른다
   ===================================================================================== */
--
-- ▶ 가드레일 (위반 시 fan-out·가산성 오류)
--   R1 fan-out : 월팩트→GOLD.DIM_MONTH · 회원속성→GOLD.DIM_MEMBER_CURRENT ·
--                광고팩트→GOLD.WIDE_AD_COMBINED(AD_PERF_DK 1:1 pre-join).
--                🔴 [2026-08-10 O54] SERVING helper 3종 → GOLD 재배선 완료(DEC-34 §0.8-D · helper DROP 은 7단계).
--                raw DIM_DATE/DIM_MEMBER 직접조인, 위성 3종 다중조인 금지.
--   R5 가산성  : F(flow)=SUM / D=COUNT(DISTINCT MEMBER_DK)(다월 중복 방지) / 비율=분자·분모 각각 집계 후 division.
--   조인키 타입: MEMBER_DK=VARCHAR(캐스팅 금지) · MONTH_KEY/DATE_SK/*_SK=NUMBER · AD_PERF_DK=VARCHAR(32).
--   PRIMARY KEY: 실측 유일한 것만 선언(FMM·FBD·ad). FME/FSE/FEP는 선언 grain이 비유일 → PK 미선언.
--                기저 FACT는 관계의 다측이라 참조되지 않아 PK 불요 · 집계 무해.
--   비활성 지표: 원천 미적재분은 SV에서 아예 제외한다. 빈 metric은 0/NULL을 사실처럼 반환하므로 금지.
--                적재 완결 시 metric만 추가(구조 불변).
--
-- ▶ COMMENT 작성 규약 🔴
--   1) **수치를 넣지 않는다** — 행수·합계·커버리지%·건수·금액·적재기간을 COMMENT에 쓰지 않는다.
--      Agent(Cortex Analyst)가 COMMENT를 답변 근거로 인용하므로, 박아둔 수치는 적재량이 바뀌는 순간
--      Agent가 틀린 값을 사실로 말하게 된다(계정 재현 시 전 수치 불일치 실측 · 04 §6.9-(8)).
--      수치가 필요한 판정은 03 §8.5.1 근거 쿼리로 그때그때 실행해 확인한다.
--   2) `[원천]` 절은 **테이블·컬럼 이름만** 적는다 — 형식:
--      `[원천] 시스템=<원천시스템> · BRONZE=<DB.스키마.테이블(핵심컬럼)> · SILVER=<정제테이블>`
--      BRONZE 스키마 4종: GN_DW.BRONZE_CRM(eCRM·UMS) · GN_DW.BRONZE_ERP(예산원장) ·
--                        GN_DW.BRONZE_AGENCY(대행사 일별 리포트) · GN_DW.BRONZE_GA4(GA4 일별 샤드)
--      컬럼 단위 완전 매핑은 넣지 않는다(토큰 낭비·이중화) → 30_output_share/04_컬럼계보매핑.md로 안내.
--   3) 저카디널리티 코드 차원은 **실제 코드값을 열거**한다. 코드값이 틀리면 Analyst가 0행을 반환하는
--      무증상 오답이 된다(DEVICE_TYPE 사례 · 04 §6.9-(5)).
--   4) 원천이 바뀌면 04_컬럼계보매핑.md 재생성 후 본 파일의 `[원천]` 절을 동기화한다.
-- ============================================================================


/* =====================================================================================
   §전체 배포 검증 — SV 6종을 아우르는 검사 (개별 SV 스모크는 각 05_* 파일에 있다)
      🔴 판정은 **절대값이 아니라 불변식**으로 한다. 적재량은 계정·시점마다 다르므로
         관계식이 참인지만 본다. 기대 절대값을 문서에 박으면 재현 시 전항 오탐이 된다(04 §6.9-(8)).
   ===================================================================================== */
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- (8-10) 배포된 SV 구조 확인 — DDL 과 배포본 일치 검사
DESCRIBE SEMANTIC VIEW GN_DW.SERVING.SV_AD;
SELECT SEMANTIC_VIEW_NAME,
       (SELECT COUNT(*) FROM GN_DW.INFORMATION_SCHEMA.SEMANTIC_METRICS m
          WHERE m.SEMANTIC_VIEW_NAME = d.SEMANTIC_VIEW_NAME AND m.SEMANTIC_VIEW_SCHEMA = 'SERVING') AS metrics,
       COUNT(*) AS dims
FROM GN_DW.INFORMATION_SCHEMA.SEMANTIC_DIMENSIONS d
WHERE SEMANTIC_VIEW_SCHEMA = 'SERVING'
GROUP BY 1 ORDER BY 1;
--   판정: 6행. 각 SV 의 metric·dimension 수가 위 DDL 의 METRICS/DIMENSIONS 절 항목 수와 일치.
--   ⚠ 개수를 주석에 박지 않는다 — DDL 을 세는 것이 정본이다(04 §6.3 이 "dim 20" 으로 틀렸던 사례).

-- ─── 8-C. 배포 검증: 소유권·GRANT ──────────────────────────────────────────────────
-- (8-11) SV 6개 · owner 통일
SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.SERVING;
--   판정: 6행 전부 owner = GN_DW_ADMIN
--   ⚠ owner 가 ACCOUNTADMIN 이면 이 파일을 GN_DW_ADMIN 이 아닌 역할로 실행한 것이다. 복구:
--     USE ROLE ACCOUNTADMIN;
--     GRANT OWNERSHIP ON SEMANTIC VIEW GN_DW.SERVING.SV_AD TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS;
--     (helper 뷰 소유권 복구는 불요 — O54 로 SV_AD base 가 GOLD.WIDE_AD_COMBINED 로 옮겨졌다)

-- (8-12) SV_AD grant 3역할
SHOW GRANTS ON SEMANTIC VIEW GN_DW.SERVING.SV_AD;
--   판정: OWNERSHIP(GN_DW_ADMIN) + REFERENCES/SELECT × ANALYST·VIEWER·SERVICE

-- (8-13) ⛔ [2026-08-10 O54] **폐지** — SV_AD 의 base 가 `SERVING.FACT_AD_COMBINED`(helper) 에서
--   **`GOLD.WIDE_AD_COMBINED`**(dbt 소유 뷰)로 재배선됐다. helper 는 어떤 SV 도 참조하지 않는다.
--   ⬜ 물리 객체는 잔존 → 의존 참조 0 확인 후 로드맵 **7단계**에서 `SERVING` helper 3종과 함께 DROP.
--   GOLD 뷰의 소비 권한은 dbt FUTURE GRANT 소관이며 아래로 확인한다.
SHOW GRANTS ON VIEW GN_DW.GOLD.WIDE_AD_COMBINED;
--   판정: SELECT × ANALYST·VIEWER·SERVICE (소유자는 dbt 실행 역할)

--   ▶ Agent(AGENT_MEMBER·AGENT_OVERALL) 의 grant·CoWork SI 검증은 이 파일 소관이 아니다
--     → **09_1_AGENT_생성.sql [6] 검증절** 참조(구 `09_AGENT_spec_구현.sql [5]` — 그 파일은
--       [DEPRECATED 2026-07-31] 포인터 스텁이다. O36 교정).


-- ============================================================================
-- [분할 이력] 2026-08-05 O37
--   종전: 단일 `05_SV_DDL.sql(현 `_archive/05_SV_DDL_ORIGINAL_BACKUP_20260805.sql`)` 708행 — §1~6 SV 정의 · §7 GRANT 18줄 · §8 스모크/검증.
--   현재: SV 정의·GRANT·개별 스모크는 `05_1`~`05_7` 로 이관. 이 파일은 인덱스·공통규약·전체검증.
--   ⚠️ **파일명 변경(2026-08-05, 사용자)**: 인덱스 파일명이 `05_SV_DDL.sql` → **`05_0_SV_DDL.sql`**.
--      이 리네임으로 분할 직후 작성한 인용처가 즉시 stale 이 됐고 전수 회수했다 —
--      **리네임은 그 자체가 P62-B 사건이다**(정본 이름이 바뀌면 그것을 가리키던 모든 문서가 거짓이 된다).
--   ⚠️ 인용처 회수 규약(P62-B — 자기교정은 전파되지 않는다):
--      · **현재 정본을 가리키는 곳**은 성격별로 교정했다 —
--        인덱스·공통규약·전체검증 → `05_0_SV_DDL.sql` / SV 정의·배포 → `05_1`~`05_7_SV_DDL_*.sql`.
--        대상: `02_GN_DW_building/06_RUNBOOK.md`·`08_After_Deploy_DBT.sql`·`07_ENVIRONMENT_RBAC_setup.sql` ·
--        `10_dbt_pipeline/deploy_dbt_project.sql` · `99_NEXT_SESSION.md` ·
--        `05_SV-Agent_ai/` 의 `00_README`·`01_작업계획`·`04_SV_설계`·`06_검증쿼리_VQR`·`07_평가셋_eval`·
--        `08_AGENT_spec`·`09_1`·`09_2`·`12_paid_테스트_실행가이드`·`99_next_prompt`.
--      · **이력 서술**은 구 파일명을 남기고 아카이브 경로를 병기했다(사실 기록이므로 보존).
--        이슈문서(20_issue/00·10·30)의 언급도 이력이므로 손대지 않는다.
--      · DEPRECATED 스텁(`13_SV_AD_배포_추가작업.sql`·`09_AGENT_spec_구현.sql`)은 실행 대상이 아니라
--        회수하지 않았다(문서10 §20-G — 실행 금지 파일이다).
-- ============================================================================
