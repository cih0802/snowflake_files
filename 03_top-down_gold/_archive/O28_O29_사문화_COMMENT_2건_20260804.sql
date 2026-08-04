-- ============================================================================
-- [사문화 아카이브] O28_O29_COMMENT_GUARD.sql 에서 제거된 COMMENT 문 (2026-08-04)
-- ============================================================================
-- 제거 사유: 대상 컬럼이 **DEC-30 에서 DROP** 됐다. `COMMENT ON COLUMN` 은 존재하지
--   않는 컬럼에 실패하므로, 남겨두면 O28_O29 스크립트 전체가 재실행 불가가 된다.
--   (2026-08-04 O30 검토에서 실측 확인 — 재실행 시 이 2건에서 ERROR)
--
--   ① FACT_EVENT_PARTICIPATION.RECRUIT_CNT
--        DEC-30 판정 = 모집인원은 **행사 속성**이므로 팩트에서 DROP,
--        정소재지 = DIM_EVENT.RECRUIT_HEADCOUNT (DEC30_STRUCTURE_ALTER.sql)
--   ② DIM_AD_CREATIVE.DURATION_SEC
--        DEC-30 판정 = 초수는 **소재 속성이 아니다**(오배치 중복축) → DROP,
--        정소재지 = FACT_AD_BROADCAST.DURATION_SEC (방송 grain)
--        ※ FACT_AD_BROADCAST.DURATION_SEC 의 O29 가드는 **살아 있다**(정본 06_DDL.sql)
--   ③ (뷰) WIDE_EVENT_PARTICIPATION.RECRUIT_CNT — ① 파생. 뷰에서도 컬럼이 사라졌다.
--
-- 🔴 되살리지 말 것. 컬럼을 다시 만들 결정이 나면 DEC-30 판정부터 뒤집어야 한다.
-- 원본 정본 = 03_top-down_gold/O28_O29_COMMENT_GUARD.sql · 판정 = 문서30 DEC-30
-- ============================================================================

-- [FEP.RECRUIT_CNT]
-- 1-B. 상태별 카운트 — 전건 0 이 "0명"이 아니라 "미배선"임을 명시
--      현 COMMENT('대기인원' 등)는 값이 실재하는 것처럼 읽혀 그대로 소비되면 "전부 0명"이라는
--      오답이 된다. 원인은 컬럼 탈락이 아니라 **O28 코드체계 미확정**이다(문서10 §14-H).
COMMENT ON COLUMN GN_DW.GOLD.FACT_EVENT_PARTICIPATION.RECRUIT_CNT IS
'모집인원 — 🔴 **전건 0 (미배선)**. 실측 2026-08-04: 비영 0 / 1,134,126행. 원천은 실재한다(SILVER `CRM_EVENT.RCRIT_PSNNL_CO` 채움 3,361/3,786=88.8%) → 행사차원 배속 판정 후 배선 대상. **0 을 "모집인원 0명"으로 읽지 말 것**.';

-- [DIM_AD_CREATIVE.DURATION_SEC]
-- 부수: 같은 축이 소재차원에도 (전건 NULL 로) 존재한다 — 중복축이다
--   ⚠️ 물리 COMMENT 는 `'초수(#22)'` 이고 *"원천 부재"* 는 **모델 파일 주석**(DIM_AD_CREATIVE.sql:5·25)에
--      있다. 즉 물리 COMMENT 자체가 거짓을 말한 것은 아니나, 지표번호만 있어 **전건 NULL 임을
--      알 수 없다** → 소비자는 조회 가능한 축으로 오인한다.
COMMENT ON COLUMN GN_DW.GOLD.DIM_AD_CREATIVE.DURATION_SEC IS
'초수(#22) — 🔴 **전건 NULL · 중복축 (O29)**. 모델이 `CAST(NULL AS NUMBER(9,0))` 하드코딩이다. 조회·조인하지 말 것.
🔴 모델 주석의 *"원천 부재(초수)"* 는 **거짓**이다 — 원천은 실재한다(SILVER `AGENCY_AD_CREATIVE.AD_SEC_NM` VIDEO 1,217/1,279=95.2% · BRONZE `VIDEO_AD_CMPGN_DTLS.AD_SEC` 33,890/36,416=93.1%). P14 위반 사례.
🔴 그러나 **채움이 정답이 아니다** — 같은 축이 `FACT_AD_BROADCAST.DURATION_SEC` 에 이미 배선돼 있다(§18-D ① 같은 역할 컬럼 우선). 판정은 **중복축 DROP 또는 소재차원 정본 통합**이며 결정 대기다.';

-- [WIDE_EVENT_PARTICIPATION.RECRUIT_CNT] (ALTER VIEW 다중컬럼문에서 절 단위로 제거)
-- COLUMN RECRUIT_CNT COMMENT '모집인원 — 🔴 전건 0(미배선). 원천 실재(`CRM_EVENT.RCRIT_PSNNL_CO` 88.8%). 0 을 실측값으로 읽지 말 것',
