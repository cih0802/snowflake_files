-- GN_DW 3단계: Semantic View DDL 정본 — SV_EVENT_PARTICIPATION (행사 참여)
-- Co-authored with CoCo
-- ============================================================================
-- ▶ 이 파일의 위상  [2026-08-05 O37 분할]
--   대상 SV = **SV_EVENT_PARTICIPATION**. 이 파일 하나로 **독립 실행**된다
--   (역할·웨어하우스·스키마 설정 + SV 정의 + GRANT + 스모크가 모두 들어 있다).
--   🔴 다른 `05_*_SV_DDL_*.sql` 과 **실행 순서 의존이 없다** — 필요한 파일만 단독 실행한다.
--   최초 세팅과 변경 반영이 같은 파일이다(통째로 재실행 · 별도 update 스크립트 없음).
--   `CREATE OR REPLACE` 가 GRANT 를 파괴하지만 GRANT 절이 같은 파일에 있어 자기완결적이다.
--
--   ⚠️ 종전에는 SV 6종이 단일 파일 `05_SV_DDL.sql(현 `_archive/05_SV_DDL_ORIGINAL_BACKUP_20260805.sql`)`(708행)에 있었다. SV 하나를 고칠 때마다
--      파일 전체를 재작성해야 해서 **손대지 않은 SV 의 COMMENT 를 훼손할 경로**였고
--      (O27→O30 · P58 과 같은 유형), 신규 SV 추가도 기존 파일 편집을 강제했다. → SV 단위로 분할.
--      `05_0_SV_DDL.sql` 은 **인덱스 + 전체 배포 검증**으로 전환됐다(SV 정의는 더 이상 없다).
--
-- ▶ 선행 조건 (이것만 만족하면 언제든 실행 가능)
--   ① GOLD 적재 완료(`dbt build`) — 이 SV 의 논리테이블 원천
--   ② **`02_GN_DW_building/08_After_Deploy_DBT.sql` §G** — SERVING helper 뷰
--      (`DIM_MONTH`·`DIM_MEMBER_CURRENT`). 이 파일이 논리테이블로 참조하므로 필수 선행.
--      ⚠ `02_SERVING_setup.sql`·`07_ENVIRONMENT_RBAC_setup.sql` 이 아니다(O36 실측 교정).
--   ⚠ 반드시 `GN_DW_ADMIN` 역할로 실행한다. ACCOUNTADMIN 으로 만들면 소유권이 어긋나 이후
--     재배포가 권한 오류로 막힌다(복구 SQL = `05_0_SV_DDL.sql` 전체검증 §8-11 주석).
--
-- ▶ 정본 근거 (수치·이력·판정 경위는 이 파일에 두지 않는다)
--   `04_SV_설계.md` §0.1 helper뷰 · §0.3 가산성 · §1~6 SV구조 · **§6.9 구조적 제약**
--   `03_SV_metric_배속.md` 지표별 분자/분모 직역 · **§8.5 미해결 + §8.5.1 근거 쿼리**
--   `01_SV-Agent 작업계획.md` §3 3단계 · 원칙10(fan-out) · R1·R5 가산성 · 원칙6 한글 synonyms
--   `05_0_SV_DDL.sql` 분할 인덱스 · 전체 배포 검증 · 공통 규약 전문
--
-- ▶ 가드레일 요약 (전문 = `05_0_SV_DDL.sql` §공통규약)
--   R1 fan-out : 월팩트→`SERVING.DIM_MONTH` · 회원속성→`SERVING.DIM_MEMBER_CURRENT` ·
--                광고팩트→`SERVING.FACT_AD_COMBINED`. raw `DIM_DATE`/`DIM_MEMBER` 직접조인 금지.
--   R5 가산성  : F(flow)=SUM / D=COUNT(DISTINCT MEMBER_DK) / 비율=분자·분모 각각 집계 후 division.
--   조인키 타입: `MEMBER_DK`=VARCHAR(캐스팅 금지) · `MONTH_KEY`/`DATE_SK`/`*_SK`=NUMBER.
--   PRIMARY KEY: 실측 유일한 것만 선언. 비유일 grain 은 PK 미선언.
--   비활성 지표: 원천 미적재분은 SV 에서 아예 제외한다(빈 metric 이 0/NULL 을 사실처럼 반환).
--   COMMENT 규약: 🔴 **수치를 넣지 않는다**(Agent 가 COMMENT 를 근거로 인용 → 적재량 변하면 거짓이 된다) ·
--                `[원천]` 절은 테이블·컬럼 이름만 · 저카디널리티 코드 차원은 **실제 코드값을 열거**.
-- ============================================================================

USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

/* =====================================================================================
   4. SV_EVENT_PARTICIPATION (회원 Agent) — base FEP(일×회원×행사)
      활성: 참여자수·참여건수·고유 참여회원수 · 행사명/종류/구분
   ===================================================================================== */
CREATE OR REPLACE SEMANTIC VIEW GN_DW.SERVING.SV_EVENT_PARTICIPATION
  TABLES (
    fep AS GN_DW.GOLD.FACT_EVENT_PARTICIPATION
      WITH SYNONYMS ('행사 참여', '이벤트 참여')
      COMMENT = '행사 참여 팩트. ⚠(DATE_SK,MEMBER_DK,EVENT_SK) 실측 비유일 → PK 미선언(기저 FACT·집계 무해). [원천] 시스템=CRM(eCRM 행사관리) · BRONZE=GN_DW.BRONZE_CRM: 참여상세 TD_MS_EVENT_PRTCPNT_DTL(MBER_NO·PARTCPT_STAT_CD·RCPMNY_AMT) ∪ TD_MS_CRMN_PRTCPNT(캠페인행사) · SILVER=CRM_EVENT_PARTICIPATION.',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '참여일')
      COMMENT = '일 차원. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.',
    event AS GN_DW.GOLD.DIM_EVENT
      PRIMARY KEY (EVENT_SK)
      WITH SYNONYMS ('행사', '이벤트')
      COMMENT = '행사 차원. EVENT_SK 고아분은 Unknown(SK=0)으로 라우팅되므로 행사명별 집계는 부분집합이다(이슈 E). [원천] 시스템=CRM(eCRM 행사관리) · BRONZE=GN_DW.BRONZE_CRM: TM_MS_EVENT(EVENT_NM·STRT_DE) ∪ TM_MS_CRMN(캠페인행사) · SILVER=CRM_EVENT.',
    member AS GN_DW.SERVING.DIM_MEMBER_CURRENT
      PRIMARY KEY (MEMBER_DK)
      WITH SYNONYMS ('회원')
      COMMENT = '회원 현재 스냅샷. fan-out 차단용 helper 뷰. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: TM_MM_FDRM_MBER_INFO ∪ TM_MM_ONCE_MBER_INFO + TH_MM_FDRM_MBER_STNG_DTLS · SILVER=CRM_MEMBER.'
  )
  RELATIONSHIPS (
    fep_to_date   AS fep (DATE_SK)   REFERENCES date,
    fep_to_event  AS fep (EVENT_SK)  REFERENCES event,
    fep_to_member AS fep (MEMBER_DK) REFERENCES member
  )
  DIMENSIONS (
    date.PART_DATE       AS date.FULL_DATE       WITH SYNONYMS ('참여일', '행사일', '일자') COMMENT = '참여일',
    date.CAL_YEAR        AS date.YEAR            WITH SYNONYMS ('연도', '년')  COMMENT = '연도',
    date.CAL_MONTH       AS date.MONTH           WITH SYNONYMS ('월')         COMMENT = '월(1~12)',
    event.EVENT_NAME     AS event.EVENT_NAME     WITH SYNONYMS ('행사명', '이벤트명') COMMENT = '행사명',
    event.EVENT_KIND     AS event.EVENT_KIND     WITH SYNONYMS ('행사종류', '온오프라인') COMMENT = '행사 종류(온라인/오프라인)',
    event.EVENT_CATEGORY AS event.EVENT_CATEGORY WITH SYNONYMS ('행사구분') COMMENT = '행사 구분',
    member.GENDER_NAME   AS member.GENDER_NAME   WITH SYNONYMS ('성별')     COMMENT = '회원 성별 — 정본 공#130. 실제값 5종: ''남자''·''여자''·''기업''·''단체''·''기타''(CM017 라벨). ⚠ 종전 코드값(''M''/''F''/''U'') 노출 → O26 교정',
    member.SEX           AS member.SEX           WITH SYNONYMS ('성별코드') COMMENT = '성별 원천코드(CM013). 이 차원의 실제값 8종 1~8 (+미기재 NULL). ⚠회원 마스터에 ''0''은 없다 — sentinel ''0''은 개발·증감 원천에만 존재하므로 ''0'' 조건은 0행. 라벨은 GENDER_NAME(분석)·SEX_NM(원천)',
    member.SEX_NM        AS member.SEX_NM        WITH SYNONYMS ('성별상세', '국내외국인') COMMENT = 'CM013 원천 라벨 8종(국내(남자)·외국인(여자)·단체·기업 등). 국내/외국인 구분용',
    member.MEMBER_STATUS_NAME AS member.MEMBER_STATUS_NAME WITH SYNONYMS ('회원상태') COMMENT = '현재 회원상태 라벨(공#132, MM010)',
    member.MBER_STAT_CD  AS member.MBER_STAT_CD  WITH SYNONYMS ('회원상태코드') COMMENT = '회원상태 원천코드(MM010 1~12)',
    member.MEMBER_TYPE_NAME AS member.MEMBER_TYPE_NAME WITH SYNONYMS ('회원구분') COMMENT = '회원구분 라벨(MM018): 개인·기업·단체',
    member.MBER_DIV_CD   AS member.MBER_DIV_CD   WITH SYNONYMS ('회원구분코드') COMMENT = '회원구분 원천코드(MM018)'
  )
  METRICS (
    fep.TOTAL_PARTICIPANTS AS SUM(fep.PARTICIPANT_CNT)
      WITH SYNONYMS ('참여자수', '참가자수') COMMENT = '참여자수 합계. F(가산).',
    fep.TOTAL_PARTICIPATE_CNT AS SUM(fep.PARTICIPATE_CNT)
      WITH SYNONYMS ('참여건수') COMMENT = '참여 건수 합계. F(가산).',
    fep.DISTINCT_PARTICIPANTS AS COUNT(DISTINCT fep.MEMBER_DK)
      WITH SYNONYMS ('고유 참여회원수') COMMENT = '고유 참여 회원수. D(distinct).'
  )
  COMMENT = 'Phase-1 행사 참여 SV(base FEP). [원천 요약] 원천시스템=CRM(eCRM 행사관리) · BRONZE=GN_DW.BRONZE_CRM(행사 TM_MS_EVENT∪TM_MS_CRMN · 참여 TD_MS_EVENT_PRTCPNT_DTL∪TD_MS_CRMN_PRTCPNT) → SILVER(CRM_EVENT+CRM_EVENT_PARTICIPATION) → GOLD(FEP). 테이블별 상세 원천은 각 테이블 COMMENT의 [원천] 절 참조. 활성: 참여자수·참여건수·고유 참여회원수, 행사명/종류/구분·참여일별. ⚠행사 미매칭분이 Unknown(EVENT_SK=0)으로 라우팅되므로 행사명별 집계는 부분집합이다 — 확정치로 단정 금지. 비활성(적재 대기): 모집/총원, 캠페인/후원사업별.'
  AI_SQL_GENERATION '적용 조건: 질문에 기간(연/월)과 그룹(행사종류·행사명·회원구분 등)이 모두 없을 때만. 이 경우 전체 기간 풀스캔을 피해 데이터에 실제 존재하는 최신 연월(MAX(연월)) 기준 직전 12개월로 한정하고(기준월은 CURRENT_DATE가 아니라 데이터 최신월 — 미래연월 데이터도 최신월로 인정), GROUP BY ROLLUP((연,월))로 월별 행 + 전체 총계 행을 함께 반환해 월별 추이와 총계를 동시에 제공한다. 행사명별 집계를 낼 때는 미매칭분이 Unknown으로 빠져 부분집합임을 답변에 명시한다. 사용자가 기간/그룹을 지정하거나 합계·총액만 원하면 그 요청을 우선한다.';


/* =====================================================================================
   GRANT — Cortex Analyst 소비 권한 (docs: REFERENCES, SELECT 필요 · USAGE 아님)
      ANALYST 가 VIEWER 를 상속하나 명확성을 위해 3역할 모두 명시(02 §E 패턴).
      🔴 `CREATE OR REPLACE` 는 기존 GRANT 를 전부 삭제한다(OWNERSHIP 만 잔존) →
         이 파일을 재실행할 때 **아래 GRANT 를 반드시 함께 실행**한다.
         분할의 이점: GRANT 가 대상 SV 와 같은 파일에 있어 빠뜨릴 수 없다.
   ===================================================================================== */
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_EVENT_PARTICIPATION TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_EVENT_PARTICIPATION TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_EVENT_PARTICIPATION TO ROLE GN_DW_SERVICE;
