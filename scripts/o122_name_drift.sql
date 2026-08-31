-- BRONZE→SILVER→GOLD 컬럼명 드리프트 census — 라이브 메타데이터 기준(텍스트 파싱 아님).
-- Co-authored with CoCo
--
-- 🔴🔴 [2026-08-30 O122] 이 파일이 컬럼명 규약 판정의 **분모 정본**이다.
--   `scripts/alias_census.py`(텍스트 파싱)는 **보조 축**으로만 쓴다 — 이유는 아래 「왜 두 축인가」.
--
-- ── 왜 두 축인가 (실측으로 드러난 텍스트 파싱의 한계) ──────────────────────────
--   텍스트 축은 「별칭이 명시된 SELECT 항목」만 센다 ⇒ 아래를 **구조적으로 못 본다**:
--     ⓐ `select *` 로 흘러간 컬럼 (CTE 경유 · 별칭 없음)
--     ⓑ 여러 줄 CASE/함수의 중간 줄
--     ⓒ 상류 `UNION ALL`/`JOIN` 에서 이미 로직이 들어간 뒤의 bare 참조
--   실측 대비(2026-08-30):
--     · 텍스트 축 = SILVER 비-GA4 이명 **15건**
--     · 이 SQL 축 = SILVER 비-GA4 원천 동명 부재 **169건**(CRM 77 · AGENCY 75 · ERP 17)
--   🔴 그리고 이 축이 텍스트 축이 **놓친 실제 위반 2건**을 잡았다:
--     `ERP_BUDGET_ITEM.BUDGET_UNIT_NM`      ← 원천 `BDGT_UNIT_NM`
--     `ERP_BUDGET_ITEM.INCOME_EXPENSE_DIV`  ← 원천 `INCOME_EXPS_DIV_NM`
--   ⇒ 「텍스트 축 0건」을 「위반 없음」으로 읽지 마라. 그것은 판정식이 못 본 것이다.
--
-- ── 🔴 이 축이 판정하지 못하는 것 (과대 방향) ────────────────────────────────
--   「원천에 동명이 없다」 ≠ 「규약 위반이다」. 아래는 전부 정당하게 이름이 다르다:
--     · 파생키(`*_DK`/`*_SK` · MD5·SK 매핑)          → 분류 L
--     · 언피벗·집계·계산 산출물(`MONTH_KEY`·`*_TOT_*`) → 분류 L
--     · 코드→라벨 사전 조인(`DEC-25 15-A`)            → 분류 L
--     · 평탄화 충돌 회피 접두(`DEC-12` · WIDE)         → 분류 X
--   ⇒ 169건은 **삼중 분류(P/L/X)의 분모**이고 작업량이 아니다. 계보 확인은 사람이 한다.
--
-- ── ⚠️ BRONZE_BIGQUERY 함정 (내가 한 번 오독했다) ─────────────────────────────
--   `BRONZE_BIGQUERY` 는 스키마는 존재하지만 **테이블이 0개**다(`DEC-39`: Python 프로시저가
--   `SILVER.BIGQUERY_REFINED_DATA` 를 직접 채우고 BRONZE 를 경유하지 않는다).
--   ⇒ GA4 계열을 `BRONZE_BIGQUERY` 에 매핑하면 **동명 일치율이 0% 로 나오는데 그것은 개명 증거가
--     아니라 빈 스키마 artifact 다.** GA4 축의 원천은 `SILVER.BIGQUERY_REFINED_DATA` 다(§B).
--   🟢 교정 후 실측 = `SILVER_BASE` 112컬럼 중 동명 24(21.4%) · 부재 88 ⇒ GA4 개명은 **실재**한다
--     (`EP_`·`STSLC_*` 접두 제거 + 파생). 앞서 본 0% 와 이 88 을 혼동하지 말 것.
--
-- ── ⚠️ SILVER→SILVER 브리지는 BRONZE 매핑이 성립하지 않는다 (O122 자기적발) ──────
--   `IDENTITY_MEMBER_XREF`(실측 14컬럼)는 `GA4_IDENTITY` 와 CRM 을 잇는 **계층 내 브리지**다
--   (`DEC-37` 이 허용한 SILVER→SILVER 파생) ⇒ 어느 BRONZE 스키마에도 대응되지 않는다.
--   🔴 이 파일 초판이 그것을 `UNMAPPED` 로 흘려 **분모 밖에 뒀다**(9컬럼으로 집계됨).
--   ⇒ `BRIDGE` 로 명시 분류하고 원천명 판정 대상에서 제외한다(비교할 원천이 없다).
--     단 브리지의 **키 컬럼명**은 양쪽 계보와 맞아야 하므로 사람이 따로 본다.
--
-- ── 🆕 ⚠️ 미입고 스캐폴드 함정 (2026-08-30 O123 자기적발) ──────────────────────
--   `CRM_BIZ_TARGET` 은 `source()` 를 **아예 참조하지 않는다** — 전 컬럼이 `CAST(NULL AS …)` 이고
--   말미가 `WHERE 1=0` 인 **스키마 전용 빈 모델**이다(원천 미입고 · `E-6`).
--   ⇒ 🔴 비교할 원천명이 **존재하지 않으므로** 「원천 동명 부재 9건」이 위반을 뜻하지 않는다.
--   🔴 이 파일 초판이 `EXTERNAL_PYTHON`·`BRIDGE` 를 「비교 대상이 없다」로 제외하면서
--     **같은 성격의 세 번째 축을 빠뜨렸다** ⇒ `UNSOURCED` 로 명시 분류하고 판정에서 제외한다.
--   🟢 교정 후 판정 가능 분모 = 169 − 9 = **160**(CRM 68 · AGENCY 75 · ERP 17).
--   🔴 원천이 입고되면 이 9컬럼을 재판정한다 ⇒ 그때 이 목록에서 빼라.
--   🟢 판정 결과 정본 = `20_issue/32_컬럼개명표.md`(계보 26건 전건 P/L/X 라벨).
--
-- 실행 = GN_DW 에 USAGE 있는 역할이면 된다(메타데이터 조회만 · 데이터 스캔 0).

-- ─────────────────────────────────────────────────────────────────────────────
-- §A. SILVER ← BRONZE : 스키마별 동명 일치율
--   판정 = SILVER 컬럼명이 매핑된 BRONZE 스키마에 **같은 이름으로 존재하는가**.
--   ⚠️ 테이블 단위가 아니라 **스키마 단위** 존재 여부다(모델이 여러 원천을 조인하므로 의도적).
-- ─────────────────────────────────────────────────────────────────────────────
WITH silver_cols AS (
    SELECT table_name,
           column_name,
           CASE
               -- 🔴 순서 주의: `UNSOURCED`·`BRIDGE` 판정을 접두 패턴보다 **먼저** 둔다.
               --   `CRM_BIZ_TARGET` 은 `CRM%` 에 걸리므로 뒤에 두면 **도달 불가 분기**가 된다
               --   (O123 이 실제로 그 실수를 한 번 냈다 — 즉시 시정).
               WHEN table_name = 'CRM_BIZ_TARGET'       THEN 'UNSOURCED'
               WHEN table_name = 'IDENTITY_MEMBER_XREF' THEN 'BRIDGE'
               WHEN table_name LIKE 'CRM%'      THEN 'BRONZE_CRM'
               WHEN table_name LIKE 'ERP%'      THEN 'BRONZE_ERP'
               WHEN table_name LIKE 'AGENCY%'   THEN 'BRONZE_AGENCY'
               WHEN table_name LIKE 'GA4%'      THEN 'SILVER_BASE'
               WHEN table_name LIKE 'BIGQUERY%' THEN 'EXTERNAL_PYTHON'
               ELSE 'UNMAPPED'
           END AS src_scope
    FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
    WHERE table_schema = 'SILVER'
      AND column_name NOT LIKE 'DW\_%'      -- 프로젝트 표준 메타 컬럼(원천 무관)
),
bronze_names AS (
    SELECT DISTINCT table_schema, column_name
    FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
    WHERE table_schema LIKE 'BRONZE%'
),
base_names AS (      -- GA4 계열의 실제 원천
    SELECT DISTINCT column_name
    FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
    WHERE table_schema = 'SILVER'
      AND table_name = 'BIGQUERY_REFINED_DATA'
)
SELECT s.src_scope,
       COUNT(*)                                        AS silver_cols,
       COUNT(COALESCE(b.column_name, g.column_name))    AS name_found,
       COUNT(*) - COUNT(COALESCE(b.column_name, g.column_name)) AS name_absent,
       ROUND(100.0 * COUNT(COALESCE(b.column_name, g.column_name)) / COUNT(*), 1) AS pct_found
FROM silver_cols s
LEFT JOIN bronze_names b
       ON b.table_schema = s.src_scope
      AND b.column_name  = s.column_name
LEFT JOIN base_names g
       ON s.src_scope    = 'SILVER_BASE'
      AND g.column_name  = s.column_name
GROUP BY s.src_scope
ORDER BY s.src_scope;

-- ─────────────────────────────────────────────────────────────────────────────
-- §B. 원천 동명 부재 컬럼 전량 목록 (P/L/X 분류 작업 대상)
--   `kind` 는 **힌트**다 — 최종 분류는 계보를 보고 사람이 정한다.
-- ─────────────────────────────────────────────────────────────────────────────
WITH silver_cols AS (
    SELECT table_name,
           column_name,
           CASE
               -- 🔴 순서 주의 = §A 와 동일하다(접두 패턴보다 먼저). 두 곳을 함께 고쳐라.
               WHEN table_name = 'CRM_BIZ_TARGET'       THEN 'UNSOURCED'
               WHEN table_name = 'IDENTITY_MEMBER_XREF' THEN 'BRIDGE'
               WHEN table_name LIKE 'CRM%'      THEN 'BRONZE_CRM'
               WHEN table_name LIKE 'ERP%'      THEN 'BRONZE_ERP'
               WHEN table_name LIKE 'AGENCY%'   THEN 'BRONZE_AGENCY'
               WHEN table_name LIKE 'GA4%'      THEN 'SILVER_BASE'
               WHEN table_name LIKE 'BIGQUERY%' THEN 'EXTERNAL_PYTHON'
               ELSE 'UNMAPPED'
           END AS src_scope
    FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
    WHERE table_schema = 'SILVER'
      AND column_name NOT LIKE 'DW\_%'
),
bronze_names AS (
    SELECT DISTINCT table_schema, column_name
    FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
    WHERE table_schema LIKE 'BRONZE%'
),
base_names AS (
    SELECT DISTINCT column_name
    FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
    WHERE table_schema = 'SILVER'
      AND table_name = 'BIGQUERY_REFINED_DATA'
)
SELECT s.src_scope,
       s.table_name,
       s.column_name,
       CASE
           WHEN s.column_name LIKE '%\_DK' OR s.column_name LIKE '%\_SK' THEN 'L(파생키)'
           WHEN s.column_name LIKE '%\_TOT\_%' OR s.column_name LIKE 'MONTH\_%' THEN 'L(집계·언피벗 후보)'
           WHEN s.column_name LIKE '%\_NM' OR s.column_name LIKE '%\_NAME' THEN 'L(라벨 후보)'
           ELSE 'P?(원천명 복원 후보)'
       END AS kind_hint
FROM silver_cols s
LEFT JOIN bronze_names b
       ON b.table_schema = s.src_scope AND b.column_name = s.column_name
LEFT JOIN base_names g
       ON s.src_scope = 'SILVER_BASE' AND g.column_name = s.column_name
WHERE b.column_name IS NULL
  AND g.column_name IS NULL
  AND s.src_scope NOT IN ('EXTERNAL_PYTHON', 'BRIDGE', 'UNSOURCED')
  -- 제외 사유가 서로 다르다(지침 R2-8 「제외 규칙은 근거가 성립하는 축에만」):
  --   EXTERNAL_PYTHON = 원천이 DW 밖(외부 Python 적재) ⇒ 비교 대상이 없다
  --   BRIDGE          = SILVER→SILVER 계층 내 파생(DEC-37) ⇒ 대응 BRONZE 스키마가 없다
  --   🆕 UNSOURCED    = `source()` 미참조 빈 스캐폴드(`WHERE 1=0` · 원천 미입고 E-6)
  --                     ⇒ 비교할 원천명이 **존재하지 않는다**(2026-08-30 O123 신설 · 9컬럼)
  -- 🔴 세 축 모두 「위반이 아니라 비교 불가」다 — 제외를 「통과」로 읽지 마라.
ORDER BY s.src_scope, s.table_name, s.column_name;

-- ─────────────────────────────────────────────────────────────────────────────
-- §C. GOLD ← SILVER : 동명 일치율
--   GOLD 는 분석 용어 계층이라 이명이 **정상**인 비율이 높다 ⇒ 이 수치는 위반율이 아니다.
--   용도 = 개명 지점이 SILVER↔GOLD 경계에 몰려 있는지 확인(규약 「개명 지점 1곳 고정」 검증).
-- ─────────────────────────────────────────────────────────────────────────────
WITH gold_cols AS (
    SELECT table_name, column_name
    FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
    WHERE table_schema = 'GOLD'
      AND column_name NOT LIKE 'DW\_%'
),
silver_names AS (
    SELECT DISTINCT column_name
    FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
    WHERE table_schema = 'SILVER'
)
SELECT CASE
           WHEN g.table_name LIKE 'WIDE\_%' THEN 'WIDE(뷰·분류 X)'
           WHEN g.table_name LIKE 'DIM\_%'  THEN 'DIM'
           WHEN g.table_name LIKE 'FACT\_%' THEN 'FACT'
           ELSE 'other'
       END AS gold_kind,
       COUNT(*)                                     AS gold_cols,
       COUNT(s.column_name)                         AS name_found_in_silver,
       COUNT(*) - COUNT(s.column_name)              AS name_absent,
       ROUND(100.0 * COUNT(s.column_name) / COUNT(*), 1) AS pct_found
FROM gold_cols g
LEFT JOIN silver_names s
       ON s.column_name = g.column_name
GROUP BY 1
ORDER BY 1;
