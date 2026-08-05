-- GN_DW 3단계: Semantic View DDL 정본 — SV_MEMBER_MONTHLY (회원 월 실적)
-- Co-authored with CoCo
-- ============================================================================
-- ▶ 이 파일의 위상  [2026-08-05 O37 분할]
--   대상 SV = **SV_MEMBER_MONTHLY**. 이 파일 하나로 **독립 실행**된다
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
   1. SV_MEMBER_MONTHLY (회원 Agent) — base FMM(월×회원)
      활성: 납입/청구 총액 · 공64 납부율 · 공80 미납회원 감소율 · 개발/중단 총건(A1)
   ===================================================================================== */
CREATE OR REPLACE SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_MONTHLY
  TABLES (
    fmm AS GN_DW.GOLD.FACT_MEMBER_MONTHLY
      PRIMARY KEY (MONTH_KEY, MEMBER_DK)
      WITH SYNONYMS ('회원 월별 실적', '월간 회원 팩트')
      COMMENT = '회원 월별 스냅샷 팩트(grain=월×회원, 실측 유일 → PK). 회비/개발/중단 월 롤업. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: 회비/청구 TM_PM_MBRFEE_ACMSLT(PAY_AMT·RQEST_AMT·PAY_STAT_CD)+TM_PM_DNTN_DTLS(PAY_AMT) · 개발 TM_MM_FDRM_MBER_DVLP_AMT(OCCRRNC_DE·SPNSR_AMT) · 중단 TM_MM_FDRM_MBER_SPNSR_DSCNTC · 증감 TM_MM_FDRM_MBER_IRSD(SPNSR_AMT·RDCAMT_YN) · SILVER=CRM_PAYMENT_BILLING·CRM_MEMBER_DEV·CRM_MEMBER_DISCONTINUE·CRM_MEMBER_AMT_CHANGE.',
    month AS GN_DW.SERVING.DIM_MONTH
      PRIMARY KEY (MONTH_KEY)
      WITH SYNONYMS ('월', '조회월', '기간')
      COMMENT = '월 차원(DIM_DATE 월 grain DISTINCT). fan-out 차단용 helper 뷰. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.',
    member AS GN_DW.SERVING.DIM_MEMBER_CURRENT
      PRIMARY KEY (MEMBER_DK)
      WITH SYNONYMS ('회원', '회원속성')
      COMMENT = '회원 현재 스냅샷(SCD2 IS_CURRENT). 불변/현재 속성 전용. fan-out 차단용 helper 뷰. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: TM_MM_FDRM_MBER_INFO(SEX·MBER_STAT_CD·RELATNSP_DIV_CD) ∪ TM_MM_ONCE_MBER_INFO(일시회원) + TH_MM_FDRM_MBER_STNG_DTLS(상태이력 SCD2) · SILVER=CRM_MEMBER.',
    -- [2026-08-04 O33] 미납사유 축. FMM.REASON_SK 는 배선돼 있었고 "적재 대기" 표기가 거짓이었다.
    --   🔴 단 이 SK 는 코드그룹 5종(PM002·PM018·PM032·PM033·PM019)에 걸쳐 있다 → REASON_TYPE 동반 노출 필수.
    reason AS GN_DW.GOLD.DIM_REASON
      PRIMARY KEY (REASON_SK)
      WITH SYNONYMS ('사유', '미납사유', '결제사유')
      COMMENT = '사유 차원. PK 유일(fan-out 0). 🔴코드그룹이 섞여 있다 — REASON_TYPE 으로 먼저 분리하지 않으면 서로 다른 코드체계를 한 축으로 합산하게 된다(O28 유형). [원천] 시스템=CRM · SILVER=CRM_CODE 파생.'
  )
  RELATIONSHIPS (
    fmm_to_month  AS fmm (MONTH_KEY) REFERENCES month,
    fmm_to_member AS fmm (MEMBER_DK) REFERENCES member,
    fmm_to_reason AS fmm (REASON_SK) REFERENCES reason
  )
  DIMENSIONS (
    month.MONTH_KEY   AS month.MONTH_KEY WITH SYNONYMS ('연월', '조회연월') COMMENT = 'YYYYMM 정수',
    month.CAL_YEAR    AS month.YEAR      WITH SYNONYMS ('연도', '년', '해') COMMENT = '조회 연도',
    month.CAL_MONTH   AS month.MONTH     WITH SYNONYMS ('월', '몇월')       COMMENT = '월(1~12)',
    month.CAL_QUARTER AS month.QUARTER   WITH SYNONYMS ('분기')            COMMENT = '분기(1~4)',
    member.GENDER_NAME   AS member.GENDER_NAME   WITH SYNONYMS ('성별')             COMMENT = '회원 성별 — 정본 공#130. 실제값 5종: ''남자''·''여자''·''기업''·''단체''·''기타''(코드사전 CM017 라벨). ⚠ 종전 코드값(''M''/''F''/''U'')을 노출했었다 — ''U''는 미상이 아니라 미상+법인+단체 혼합이었다(O26 교정)',
    member.SEX           AS member.SEX           WITH SYNONYMS ('성별코드')         COMMENT = '성별 원천코드(CM013). 이 차원의 실제값 8종: ''1''국내남·''2''국내여·''3''외국남·''4''외국여·''5''외국기타·''6''단체·''7''기업·''8''기타 (+미기재 NULL 421행). ⚠회원 마스터에 ''0''은 존재하지 않는다 — sentinel ''0''은 개발·증감 원천(CRM_MEMBER_DEV 9행·CRM_MEMBER_AMT_CHANGE 1행)에만 있으므로 이 차원에 ''0'' 조건을 걸면 0행이다. 라벨은 GENDER_NAME(분석)·SEX_NM(원천)',
    member.SEX_NM        AS member.SEX_NM        WITH SYNONYMS ('성별상세', '국내외국인') COMMENT = 'CM013 원천 라벨. 실제값 8종: ''국내(남자)''·''국내(여자)''·''외국인(남자)''·''외국인(여자)''·''외국인(기타)''·''단체''·''기업''·''기타''. 국내/외국인 구분이 필요할 때 쓴다',
    member.MEMBER_STATUS_NAME AS member.MEMBER_STATUS_NAME WITH SYNONYMS ('회원상태', '상태') COMMENT = '현재 회원상태 라벨(정본 공#132, MM010). 실제값: ''1활동회원''~''12후원중단'' 라벨. 과거월 조회 시에도 현재 기준',
    member.MBER_STAT_CD  AS member.MBER_STAT_CD  WITH SYNONYMS ('회원상태코드')     COMMENT = '회원상태 원천코드(MM010 1~12). 라벨은 MEMBER_STATUS_NAME',
    member.MEMBER_TYPE_NAME AS member.MEMBER_TYPE_NAME WITH SYNONYMS ('회원구분', '구분') COMMENT = '회원구분 라벨(MM018). 실제값 3종: ''개인''·''기업''·''단체''',
    member.MBER_DIV_CD   AS member.MBER_DIV_CD   WITH SYNONYMS ('회원구분코드')     COMMENT = '회원구분 원천코드(MM018 1개인·2기업·3단체). 라벨은 MEMBER_TYPE_NAME',
    fmm.HAS_BILLING      AS fmm.HAS_BILLING      WITH SYNONYMS ('결제출처여부', '결제원천 존재') COMMENT = 'TRUE=결제(billing) 원천 행이 존재하는 월×회원. 🔴**「회비만」 스코프가 아니다**(O40) — 기저 CTE 가 회비(TM_PM_MBRFEE_ACMSLT)와 **기부금(TM_PM_DNTN_DTLS)을 함께** 담으므로 TRUE 인 행에도 기부금이 섞여 있고, 청구가 없는 기부금 전용 월도 TRUE 다. 따라서 이 필터를 걸어도 **회비 납부율의 분자는 정화되지 않는다.** 회비 지표를 볼 때 행 범위를 좁히는 용도로만 쓰고, 「회비 기준」이라고 서술하지 말 것.',
    reason.UNPAID_REASON_TYPE AS reason.REASON_TYPE WITH SYNONYMS ('사유 코드체계', '사유그룹') COMMENT = '🔴사유 코드그룹(PM002·PM018·PM032·PM033·PM019). **사유별 분해 시 이 축을 먼저 걸거나 함께 GROUP BY 할 것** — 그룹이 다르면 같은 이름도 다른 의미다. 그룹 미분리 합산은 조용히 틀린다(O28 유형)',
    reason.UNPAID_REASON      AS reason.REASON_NAME WITH SYNONYMS ('미납사유', '사유', '결제실패사유') COMMENT = '사유 라벨. 🔴**미납/결제실패 행에만 배선**된다 — 정상 납입 행은 전건 ''(미매핑)''이므로 대부분이 (미매핑) 한 덩어리로 나온다. 따라서 미납 관련 지표(총미납금액·미납비중·미납회원수)와 함께 쓸 때만 의미가 있다. ⚠️반드시 UNPAID_REASON_TYPE 과 함께 볼 것',
    -- [2026-08-04 O33] 지역·연령대 노출. O27 이 DIM_MEMBER 에 as-of 배선을 완료했고 helper 뷰가 이미 보유한다
    --   → 배선 추가 없이 선언만으로 활성화. 종전 SV COMMENT 의 "비활성(적재 대기): 지역/연령대" 는 거짓이 됐다.
    member.MEMBER_REGION_AT_PLEDGE AS member.REGION WITH SYNONYMS ('지역', '약정시점 지역', '가입시점 지역', '시도') COMMENT = '🔴**약정(개발) 시점의** 회원 지역 라벨 — **현재 거주지가 아니다**(O34 확정). 정본 공#131 · 코드사전 CM018 약칭. 실제값: ''서울''·''경기''·''인천''·''강원''·''대전''·''대구''·''부산''·''광주''·''울산''·''세종''·''충남''·''충북''·''전남''·''전북''·''경남''·''경북''·''제주''·''기타''. 원천 = 개발약정 테이블의 지역코드이며 약정 당시 값이 그대로 굳는다 — 이후 이사해도 갱신되지 않는다. 코드는 DIM_MEMBER.AREA_CD. ⚠️''현재 거주지역별'' 질문에는 답할 수 없다 — 원천에 현재 주소 축이 없다. ⚠️개발약정이 없는 회원(주로 일시회원)은 NULL 이며 ''미상''이 아니라 원천 부재다',
    member.MEMBER_AGE_BAND_AT_PLEDGE AS member.AGE_BAND WITH SYNONYMS ('연령대', '약정시점 연령대', '가입시점 연령대') COMMENT = '🔴**약정(개발) 시점의** 회원 연령대 라벨 — **현재 나이가 아니다**(O34 확정). 코드사전 CM014. 실제값: ''10대 미만''·''10대''·''20대''·''30대''·''40대''·''50대''·''60대''·''70대''·''70대 이상''·''단체''·''기업''·''기타''. ✅라벨 매핑은 CM014 사전과 일치 검증됨(우리 쪽 결함 아님). ✅''10대 미만''이 최다인 것도 **실제이며 데이터 오류가 아니다** — 원인은 **편지쓰기대회 계열 캠페인**(희망편지쓰기대회·가족그림편지쓰기대회·세계시민교육편지)이다. 이 계열은 학교·부모 DB 를 통해 **아동 본인 명의로 후원 약정을 맺는 모집 이벤트**여서 20세 미만 비중이 그 외 캠페인보다 압도적으로 높다(개발사건 단위 실측·문서10 §19 참조). 따라서 *''왜 10대 미만이 많은가''* 라는 질문에는 **''특정 아동 모집 캠페인(편지쓰기대회 계열) 때문이며 약정 당시 연령 기준이다''** 라고 답하면 된다 — 결측·오류로 설명하지 말 것. 🔴그러나 이 값은 **약정 당시에 굳은 스냅샷**이라 오래된 회원일수록 실제 나이와 벌어진다 — 독립 원천(SND_MEMBER_LIST 연령대 라벨)과 회원 단위 대조 시 불일치가 **전부 노화 방향**이었고, 약정연도가 오래될수록 격차가 단조 증가했다. ⚠️**현재 연령대는 산출 불가**다 — BRONZE 전체에 생년월일 컬럼이 없다. 따라서 ''현재 연령별'' 질문에 이 축으로 답하지 말 것. ⚠️''단체''·''기업''은 나이가 아니라 법인 구분이므로 연령 추이에서 제외할 것 · 원천 부재 시 NULL'
  )
  METRICS (
    fmm.TOTAL_PAID_FEE   AS SUM(fmm.PAID_FEE)
      WITH SYNONYMS ('총수납액', '수납액', '납입총액') COMMENT = '납입 **총액**(원) = 회비 + 기부금. F(가산). 🔴**「납입회비」가 아니다**(O40) — 기저 `PAID_FEE` 는 회비(TM_PM_MBRFEE_ACMSLT)와 기부금(TM_PM_DNTN_DTLS)의 `PAY_AMT` 를 **모두** 합한 값이다. 🔴**납부율의 분자로 쓰지 말 것** — 기부금은 원천에 청구(`RQEST_AMT`) 컬럼이 아예 없어(전건 NULL) 분모 `TOTAL_BILLED_AMT` 에 구조적으로 들어갈 수 없다. 분자에만 더해지면 납부율이 과대해진다(2025 실측 8.32%p 과대). 회비만의 납입액은 **`TOTAL_PAID_FEE_BILLABLE`** 이다.',
    fmm.TOTAL_BILLED_AMT AS SUM(fmm.BILLED_AMT)
      WITH SYNONYMS ('청구금액', '청구액 총액') COMMENT = '청구금액 합계(원, 재청구 중복 포함). F(가산).',
    fmm.PAYMENT_RATE     AS SUM(fmm.PAID_FEE) / NULLIF(SUM(fmm.BILLED_AMT), 0) * 100
      WITH SYNONYMS ('수납율(총액기준)') COMMENT = '🔴**과대 지표 — 단독 인용 금지**(O40 · 2026-08-05 실측). 공64 납부율을 의도했으나 분자(`PAID_FEE`=회비+기부금)와 분모(`BILLED_AMT`=회비 청구만)의 **모집단이 일치하지 않는다.** 기부금은 원천에 청구 컬럼이 없어 분모에 들어갈 수 없으므로 값이 구조적으로 부풀려진다 — 2025 실측 **93.98%** 였으나 회비 기준 실제값은 **85.65%**(8.32%p 과대). 🔴사용자가 「납부율」을 물으면 이 metric 을 쓰지 말고 **`PAYMENT_RATE_FEE`(정본)** 를 쓸 것. 비율(N, 재집계 금지).',
    fmm.TOTAL_DEV_CNT    AS SUM(fmm.DEV_CNT)
      WITH SYNONYMS ('개발건', '개발 총건', '신규개발수') COMMENT = '개발(신규 후원) 건수 합계. F(가산). FME 월 롤업(A1).',
    fmm.TOTAL_STOP_CNT   AS SUM(fmm.STOP_CNT)
      WITH SYNONYMS ('중단건', '중단 총건', '해지건') COMMENT = '중단(해지) 건수 합계. F(가산). FME 월 롤업(A1).',
    fmm.UNPAID_MEMBERS_BOM AS COUNT(DISTINCT CASE WHEN fmm.UNPAID_FLAG_BOM THEN fmm.MEMBER_DK END)
      WITH SYNONYMS ('월초 미납회원수') COMMENT = '월초(BOM) 미납 회원 고유수. D(distinct). 다월 합산 금지.',
    fmm.UNPAID_MEMBERS_EOM AS COUNT(DISTINCT CASE WHEN fmm.UNPAID_FLAG_EOM THEN fmm.MEMBER_DK END)
      WITH SYNONYMS ('월말 미납회원수') COMMENT = '월말(EOM) 미납 회원 고유수. D(distinct). 다월 합산 금지.',
    fmm.UNPAID_REDUCTION_RATE AS
      (COUNT(DISTINCT CASE WHEN fmm.UNPAID_FLAG_BOM THEN fmm.MEMBER_DK END)
       - COUNT(DISTINCT CASE WHEN fmm.UNPAID_FLAG_EOM THEN fmm.MEMBER_DK END))
      / NULLIF(COUNT(DISTINCT CASE WHEN fmm.UNPAID_FLAG_BOM THEN fmm.MEMBER_DK END), 0) * 100
      WITH SYNONYMS ('미납회원 감소율') COMMENT = '공80 미납회원 감소율(%) = (월초미납−월말미납) ÷ 월초미납 ×100. 비율(N).',
    fmm.TOTAL_UNPAID_AMT AS SUM(fmm.BILLED_AMT) - SUM(fmm.PAID_FEE)
      WITH SYNONYMS ('미납액(차감식)') COMMENT = '🔴**과소 지표 — 단독 인용 금지**(O40 · 2026-08-05 실측). 「청구 − 납입」 차감식이라 분자에 섞인 **기부금이 미납을 상쇄**한다. 2025 실측 **12,335,580,090** 이었으나 정본 DEC-3 정의(`PAY_STAT_CD IN (''F'', NULL)` 인 청구액)로는 **29,251,314,636** — **2.37배 과소**이며 16.9억 원대가 아니라 **169억 원**이 누락된다. 🔴미납금액 질문에는 이 metric 을 쓰지 말고 **`TOTAL_UNPAID_AMT_DEC3`(정본)** 를 쓸 것. 미납 **회원수**는 `UNPAID_MEMBERS_BOM/EOM` 이 정상이다.',
    fmm.UNPAID_RATIO AS (SUM(fmm.BILLED_AMT) - SUM(fmm.PAID_FEE)) / NULLIF(SUM(fmm.BILLED_AMT), 0) * 100
      WITH SYNONYMS ('미납비중(차감식)') COMMENT = '🔴**과소 지표 — 단독 인용 금지**(O40). `TOTAL_UNPAID_AMT` 와 같은 차감식이라 기부금이 미납을 상쇄한다. 2025 실측 6.02% 였으나 정본 DEC-3 기준은 **14.29%** 다. 미납 비중 질문에는 **`UNPAID_RATIO_DEC3`(정본)** 를 쓸 것. 비율(N, 재집계 금지).',
    -- ── [2026-08-05 O40 §4] 정본 지표 — 분자·분모 모집단 일치 ────────────────────
    --   위 4종(TOTAL_PAID_FEE·PAYMENT_RATE·TOTAL_UNPAID_AMT·UNPAID_RATIO)은 결함 지표로 남겨두고
    --   (저장쿼리·문서 참조 보호) 자연어 표현은 아래 정본으로 라우팅한다(P79).
    fmm.TOTAL_PAID_FEE_BILLABLE AS SUM(fmm.PAID_FEE_BILLABLE)
      WITH SYNONYMS ('납입회비', '납입회비 총액', '회비 납입액', '수납회비', '회비 수납액')
      COMMENT = '납입회비(원) — **회비만**. F(가산). 정본 #69·70. 기부금은 제외된다(기부금은 원천에 청구 컬럼이 없어 납부율 분모에 들어갈 수 없다). 회비+기부금 총수납액은 TOTAL_PAID_FEE 다.',
    fmm.PAYMENT_RATE_FEE AS SUM(fmm.PAID_FEE_BILLABLE) / NULLIF(SUM(fmm.BILLED_AMT), 0) * 100
      WITH SYNONYMS ('납부율', '수납율', '회비 납부율', '납입률', '납부율(%)')
      COMMENT = '**공64 납부율(%) 정본** = 회비 납입액 ÷ 회비 청구액 ×100. 분자·분모가 모두 회비라 모집단이 일치한다. 비율(N, 재집계 금지). 🟢납부율을 묻는 질문에는 이 metric 을 쓴다(PAYMENT_RATE 는 기부금이 섞여 과대).',
    fmm.TOTAL_UNPAID_AMT_DEC3 AS SUM(fmm.UNPAID_BILLED_AMT)
      WITH SYNONYMS ('총미납금액', '미납금액', '미납액', '미납액 총액', '못 걷은 금액')
      COMMENT = '**총미납금액(원) 정본** — DEC-3 정의: 결제상태가 실패(F) 또는 NULL 인 청구액 합. F(가산). 🟢미납금액 질문에는 이 metric 을 쓴다(TOTAL_UNPAID_AMT 는 차감식이라 기부금이 미납을 상쇄해 과소). ⚠️미납은 회수될 수 있으므로 조회 시점 스냅샷이다.',
    fmm.UNPAID_RATIO_DEC3 AS SUM(fmm.UNPAID_BILLED_AMT) / NULLIF(SUM(fmm.BILLED_AMT), 0) * 100
      WITH SYNONYMS ('미납비중', '미납율', '미납률', '미납 비율')
      COMMENT = '**미납비중(%) 정본** = 미납 청구액 ÷ 회비 청구액 ×100. 비율(N, 재집계 금지). ⚠️`100 − 납부율` 과 정확히 같지 않다 — 부분납입 행이 있어 두 값은 서로 보완적이다(2025 실측 납부율 85.65% · 미납비중 14.29%).',
    fmm.AVG_PAID_FEE AS AVG(fmm.PAID_FEE)
      WITH SYNONYMS ('평균납입회비', '평균회비') COMMENT = '행(월×회원)당 평균 납입회비(원). HAS_BILLING=TRUE 전제 권장. PoC AVG_PAID 로직 이식.'
  )
  COMMENT = 'Phase-1 회원 월별 실적 SV(base FMM). [원천 요약] 원천시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM(회비 TM_PM_MBRFEE_ACMSLT·기부 TM_PM_DNTN_DTLS·개발 TM_MM_FDRM_MBER_DVLP_AMT·중단 TM_MM_FDRM_MBER_SPNSR_DSCNTC·증감 TM_MM_FDRM_MBER_IRSD·회원 TM_MM_FDRM_MBER_INFO) → SILVER(CRM_*) → GOLD(FMM). 테이블별 상세 원천은 각 테이블 COMMENT의 [원천] 절 참조. 활성: 납입/청구 총액·납부율(공64)·미납회원 감소율(공80)·개발/중단 총건·총미납금액·미납비중·평균납입회비. 시간=전체가능. 회비 지표는 HAS_BILLING=TRUE 전제 권장. 회원상태/성별/구분/지역/연령대는 현재 스냅샷 기준(과거월도 현재값). [2026-08-04 O33] 지역·연령대 활성화(O27 as-of 배선 완료 — 종전 "적재 대기" 표기는 거짓이었다). 🔴[O34 확정] 지역·연령대는 **약정(개발) 시점 스냅샷**이며 **현재 값이 아니다** — 차원명에 _AT_PLEDGE 를 붙였다. 현재 연령·현재 거주지는 **산출 불가**(BRONZE 에 생년월일·현주소 축이 없다). ''10대 미만'' 최다는 실제이며 **편지쓰기대회 계열 아동 모집 캠페인** 때문이다(오류가 아니다) — 질문받으면 그 이벤트 성격으로 설명할 것. 🔴단 이 SV 에는 캠페인 축이 없다 — **연령대 × 캠페인 교차는 SV_MEMBER_EVENT**(사건시점 축), **캠페인별 중단률·획득시점 회원특성은 SV_MEMBER_COHORT**(회원 grain)에서 한다. [2026-08-05 O37] 🔴 종전 이 자리의 「교차 확인 불가」 계열 표현은 회수됐다 — 두 SV 에 축이 실재하므로 "불가"로 답하지 말고 해당 SV 로 라우팅한다(P61). [O33] 미납사유 활성화 — 단 코드그룹 5종이 섞여 있어 UNPAID_REASON_TYPE 동반 필수이고 미납 지표와 함께 쓸 때만 의미가 있다. 비활성(적재 대기): 납입방식/후원사업별 분해, 활동/누계/미납 카운트 비율, 신규기존 분해. 🔴 **캠페인은 이 목록에서 제외**한다(2026-08-05 O37) — 이 SV 의 `FMM.CAMPAIGN_SK` 가 센티넬 단일값이라 여기서는 분해되지 않지만, **캠페인 분해 자체가 불가한 것은 아니다**: 개발/중단 건수는 `SV_MEMBER_EVENT`, 캠페인별 중단률·획득 코호트는 `SV_MEMBER_COHORT` 로 답한다. 🔴 이 목록은 축을 활성화할 때마다 회수 대상이다(P61 — 부정형 서술이 남으면 Agent 가 "불가"로 답한다). '
  AI_SQL_GENERATION '적용 조건: 질문에 기간(연/월)과 그룹(회원구분·성별·회원상태 등)이 모두 없을 때만. 이 경우 전체 기간 풀스캔을 피해 데이터에 실제 존재하는 최신 연월(MAX(연월)) 기준 직전 12개월로 한정하고(기준월은 CURRENT_DATE가 아니라 데이터 최신월 — 미래연월 데이터도 최신월로 인정), GROUP BY ROLLUP((연,월))로 월별 행 + 전체 총계 행을 함께 반환해 월별 추이와 총계를 동시에 제공한다. 납부율·미납비중 등 비율은 총계 행에서 SUM 기반으로 정확히 산출한다. 사용자가 기간/그룹을 지정하거나 합계·총액만 원하면 그 요청을 우선한다. ⚠**[O40 · 2026-08-05 해소] 납부율·미납금액은 정본 metric 을 쓴다.** 「납부율」=**`PAYMENT_RATE_FEE`** · 「납입회비」=**`TOTAL_PAID_FEE_BILLABLE`** · 「미납금액」=**`TOTAL_UNPAID_AMT_DEC3`** · 「미납비중」=**`UNPAID_RATIO_DEC3`**. 🔴구지표 `PAYMENT_RATE`(분자에 기부금 혼입 → 과대) · `TOTAL_UNPAID_AMT`/`UNPAID_RATIO`(차감식 → 과소) · `TOTAL_PAID_FEE`(회비+기부금 총수납액)는 **납부율·미납금액 답변에 쓰지 않는다.** `TOTAL_PAID_FEE` 는 「총수납액(회비+기부금)」을 명시적으로 물을 때만 쓰고 그때도 기부금 포함임을 밝힌다. (2) `HAS_BILLING=TRUE` 는 「회비만」 스코프가 **아니다** — 이 필터를 걸었다는 이유로 「회비 기준」이라고 서술하지 않는다. 회비 기준은 metric 선택으로 결정된다. ⚠**「마감·확정」이라고 단정하지 않는다.** 이 팩트는 적재 시점 **스냅샷**이다 — 지난 연도의 미납 청구가 이후에 납입되면 값이 바뀐다(2025년분 회비가 2026-07-01 까지 계속 납입된 것이 실측으로 확인됐다). 또 회비월 데이터는 **미래월까지 존재**한다. 따라서 특정 연도 실적을 답할 때 「이미 마감된 실측치」,「확정치」 같은 표현을 쓰지 말고 **「조회 시점 적재 기준」임을 명시**한다.';

-- 비활성(Phase-2/적재 후) — 구조 불변, 적재 완결 시 metric만 추가:
--   공45~47 활동율·공54~57 중단율·공76~78 미납율(ACTIVE/MONTH_END/YEAR_START_ACTIVE_CNT 미적재)
--   신12~29 캠페인/납입방식별 · 공79 후원사업별 (해당 FK 미적재)
--   공1~3 목표대비 (BRG_DEV_VS_TARGET 브리지 · 04 §8.1) · 공81 미납서비스 전환율 (GA identity 브리지 · P2)


/* =====================================================================================
   GRANT — Cortex Analyst 소비 권한 (docs: REFERENCES, SELECT 필요 · USAGE 아님)
      ANALYST 가 VIEWER 를 상속하나 명확성을 위해 3역할 모두 명시(02 §E 패턴).
      🔴 `CREATE OR REPLACE` 는 기존 GRANT 를 전부 삭제한다(OWNERSHIP 만 잔존) →
         이 파일을 재실행할 때 **아래 GRANT 를 반드시 함께 실행**한다.
         분할의 이점: GRANT 가 대상 SV 와 같은 파일에 있어 빠뜨릴 수 없다.
   ===================================================================================== */
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_MONTHLY TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_MONTHLY TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_MONTHLY TO ROLE GN_DW_SERVICE;


/* =====================================================================================
   스모크 검증 (배포 직후 실행) — 04 §0.1 DoD
      원리: `SEMANTIC_VIEW(...)` 집계 == 단일 FACT 직접 SUM 일치 → 조인 fan-out 0 검증.
      🔴 판정은 **절대값이 아니라 불변식**으로 한다. 적재량은 계정·시점마다 다르므로
         "sv_val == fact_val" 같은 관계식이 참인지만 본다. 기대 절대값을 문서에 박으면
         재현 시 전항 오탐이 된다(04 §6.9-(8)).
      ▶ SV 6종 전체를 아우르는 배포 검증(소유권·GRANT·구조 대조) = `05_0_SV_DDL.sql`
   ===================================================================================== */
USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- (8-1) SV_MEMBER_MONTHLY 납입회비 총액 == FMM 직접 SUM
SELECT (SELECT TOTAL_PAID_FEE FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY METRICS TOTAL_PAID_FEE)) AS sv_val,
       (SELECT SUM(PAID_FEE) FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY)                                        AS fact_val;
--   판정: sv_val == fact_val
