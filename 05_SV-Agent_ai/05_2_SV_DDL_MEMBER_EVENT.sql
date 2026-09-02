-- GN_DW 3단계: Semantic View DDL 정본 — SV_MEMBER_EVENT (회원 상태전이 사건)
-- Co-authored with CoCo
-- ============================================================================
-- ▶ 이 파일의 위상  [2026-08-05 O37 분할]
--   대상 SV = **SV_MEMBER_EVENT** — 이 파일 하나로 **독립 실행**된다(상세 = 아래 포인터).
--
--   🔴 **파일 규약·선행 조건·정본 근거의 정본 = `05_0_SV_DDL.sql` §공통 규약** (2026-08-10 O55 DUP-1).
--      독립 실행 · 파일 간 순서 무관 · 재실행 반영 · `CREATE OR ALTER`(GRANT·소유권 보존) ·
--      분할 이력(O37) · 선행 조건은 `dbt build` **하나** · 실행 역할 `GN_DW_ADMIN`.
--      ⛔ 이 항목들을 이 파일에 다시 복제하지 말 것 — 그것이 P140(9중 중복)의 원인이었다.
--
-- ▶ 가드레일 요약 (전문 = `05_0_SV_DDL.sql` §공통규약)
--   R1 fan-out : 월팩트→`GOLD.DIM_MONTH` · 회원속성→`GOLD.DIM_MEMBER_CURRENT` ·
--                광고팩트→`GOLD.WIDE_AD_COMBINED`. raw `DIM_DATE`/`DIM_MEMBER` 직접조인 금지.
--                🔴 [2026-08-10 O54·O55] SERVING helper 3종 → GOLD 재배선 완료 후 **물리 DROP 완료**(DEC-34 §0.8-D).
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
   2. SV_MEMBER_EVENT (회원 Agent) — base FME(일×회원×상태전이)
      활성: 개발/중단 총건·고유회원수 · 사건일/주차
      ※ 유지기간·유지율·LTV(신4·6~8)는 가입↔중단 페어링이 필요해 Phase-1 산출 불가 → 04 §6.7
   ===================================================================================== */
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_EVENT
  TABLES (
    fme AS GN_DW.GOLD.FACT_MEMBER_EVENT
      WITH SYNONYMS ('회원 상태전이', '개발중단 사건')
      COMMENT = '회원 상태전이 사건 팩트. 1행=1개발/중단 사건. ⚠(DATE_SK,MEMBER_DK,EVENT_TYPE) 실측 비유일 → PK 미선언(기저 FACT·참조 안 됨·집계 무해). [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: 개발 TM_MM_FDRM_MBER_DVLP_AMT(OCCRRNC_DE·SPNSR_AMT·MBER_NO) · 중단 TM_MM_FDRM_MBER_SPNSR_DSCNTC(SPNSR_DSCNTC_DE·DSCNTC_RSN_CD·DSCNTC_PATH) · SILVER=CRM_MEMBER_DEV+CRM_MEMBER_DISCONTINUE.',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '일자', '사건일')
      COMMENT = '일 차원. [원천] ETL 생성(달력, 팩트 일자범위 기반) — 업무 원천 시스템 없음.',
    member AS GN_DW.GOLD.DIM_MEMBER_CURRENT
      PRIMARY KEY (MEMBER_DK)
      WITH SYNONYMS ('회원', '회원속성')
      COMMENT = '회원 현재 스냅샷. fan-out 차단용 helper 뷰. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: TM_MM_FDRM_MBER_INFO ∪ TM_MM_ONCE_MBER_INFO + TH_MM_FDRM_MBER_STNG_DTLS · SILVER=CRM_MEMBER.',
    -- [2026-08-04 O33] 캠페인 축 활성화. FME.CAMPAIGN_SK 는 이미 배선돼 있었고 종전 SV COMMENT 의
    --   "비활성(적재 대기): 캠페인별 분해" 가 거짓이었다. PK 유일(fan-out 0)·고아 0% 확인 후 노출.
    campaign AS GN_DW.GOLD.DIM_CAMPAIGN
      PRIMARY KEY (CAMPAIGN_SK)
      WITH SYNONYMS ('캠페인', '모금 캠페인')
      COMMENT = '캠페인 차원. PK 유일이라 조인이 행수를 늘리지 않는다. 🔴개발(DEV)행에만 배선된다 — 중단(STOP)행은 전건 ''(미매핑)''(SK=0)이다. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: TM_MM_CMPGN · SILVER=CRM_CAMPAIGN.',
    -- [2026-08-05 O38] 조직 축 활성화. GOLD FME.ORG_SK 를 실적부서(원천 ACMSLT_DEPT_CD)로 배선했고
    --   (종전 전건 센티넬 0), 기획실 요건 「부서별 × **일자별** 개발 건」(O10/Q7)이 이 SV 소관이다
    --   — 목표 대비 실적은 월 grain 이므로 SV_DEV_ACHIEVEMENT 가 담당한다.
    --   fan-out 0 사전 검증: DIM_ORG.ORG_SK PK 유일(1,315/1,315) · FME 고아 0.
    -- ── [2026-08-06 O45] 후원사업 축 ─────────────────────────────────────────
    --   🔴 종전 SV COMMENT 는 *"비활성(적재 대기): 후원사업별 분해"* 라고 적고 있었다. 그것은 **거짓이 됐다**.
    --      더 정확히 말하면 애초에 「적재 대기」가 아니었다 — `FME.SPONSORSHIP_SK` 는 `0` 하드코딩이었고
    --      원천 `SPNSR_BSNS_ID` 는 채움 100% · `DIM_SPONSORSHIP` 고아 0 이었다. **배선 누락**이다(P87).
    --      O8(다중귀속)에 묶여 「대기 중」으로 분류돼 6개월간 재검사되지 않았다 — 사건 grain 에서는
    --      후원사업이 하나로 확정되므로 귀속 규칙이 애초에 필요하지 않았다.
    --   ✅ 팬아웃 실측(2026-08-06): FME 4,633,105 → 조인 후 **행수 불변**. PK 유일 확인.
    sponsorship AS GN_DW.GOLD.DIM_SPONSORSHIP
      PRIMARY KEY (SPONSORSHIP_SK)
      WITH SYNONYMS ('후원사업', '사업')
      COMMENT = '사건의 후원사업 차원. PK 유일이라 조인이 행수를 늘리지 않는다. 🔴개발(DEV)행에만 배선된다 — 중단(STOP)행은 중단원천에 후원사업 컬럼이 없어 전건 ''(미매핑)''(SK=0)이다. ⚠️**회비 납입 대상 후원사업(SV_MEMBER_FEE)과 다른 축**이고, **획득 시점 후원사업(SV_MEMBER_COHORT)과도 다른 축**이다 — 세 축을 합산하지 말 것. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: TM_MM_FDRM_MBER_DVLP_AMT(SPNSR_BSNS_ID) + TM_CM_SPNSR_BSNS_INFO · SILVER=CRM_MEMBER_DEV + CRM_SPONSOR_BIZ.',
    org AS GN_DW.GOLD.DIM_ORG
      PRIMARY KEY (ORG_SK)
      WITH SYNONYMS ('조직', '부서', '실적부서')
      COMMENT = '조직 차원(SCD1, 부서 grain). PK 유일이라 조인이 행수를 늘리지 않는다. 🔴개발(DEV)행에만 배선된다 — 중단(STOP)행은 원천이 등록부서만 보유해 역할이 달라 전건 ''(미매핑)''(SK=0)이다(O38-B 결정 대기). [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: TM_CM_DEPT_MNG · SILVER=CRM_ORG.'
  )
  RELATIONSHIPS (
    fme_to_date     AS fme (DATE_SK)     REFERENCES date,
    fme_to_member   AS fme (MEMBER_DK)   REFERENCES member,
    fme_to_campaign AS fme (CAMPAIGN_SK) REFERENCES campaign,
    fme_to_org      AS fme (ORG_SK)      REFERENCES org,
    fme_to_spb      AS fme (SPONSORSHIP_SK) REFERENCES sponsorship
  )
  DIMENSIONS (
    -- [2026-08-06 O45] 후원사업 축 (종전 「비활성(적재 대기)」 서술 회수)
    sponsorship.SPONSORSHIP AS sponsorship.SPONSORSHIP_NAME
      WITH SYNONYMS ('후원사업', '후원사업명', '사업', '사업명')
      COMMENT = '사건의 후원사업명(정본 #123). 🔴**개발(DEV) 사건 전용** — 중단(STOP) 행은 중단원천에 후원사업 컬럼이 구조적으로 없어 전건 ''(미매핑)''이다. 「후원사업별 중단건」으로 읽으면 틀린다. ⚠️ **같은 라벨이 세 축이다**: ① 이 축 = **사건(개발) 시점** 후원사업 ② `SV_MEMBER_FEE` = **회비 납입 대상** 후원사업 ③ `SV_MEMBER_COHORT` = **획득 시점** 후원사업. 세 축의 값은 서로 다르며 합산·비교하면 조용히 틀린다 — 어느 축으로 답했는지 반드시 밝힌다. ⚠️ 목표(FACT_TARGET_DEV)에는 후원사업 축이 없어 **후원사업별 목표 대비 달성률은 불가**하다',
    -- [2026-08-05 O38] 부서 축. 장표·기획실 요건의 첫 축이다.
    --   🔴 상위 조직(본부/지부·팀·법인)은 CONF-4 로 전건 NULL 이라 노출하지 않는다 —
    --      노출하면 Analyst 가 "지부별로 보여줘"에 0행 무증상 오답을 낸다(§6.9-(5)·AD-4 유형).
    org.ORG_DEPARTMENT AS org.DEPARTMENT
      WITH SYNONYMS ('부서', '부서명', '실적부서', '담당부서')
      COMMENT = '부서명(정본 #116). 실적부서(원천 ACMSLT_DEPT_CD) 기준 귀속. 🔴개발(DEV) 사건 전용 — 중단(STOP) 행은 전건 ''(미매핑)''이므로 「부서별 중단건」으로 읽으면 틀린다. ⚠️본부/지부·팀·법인 단위는 산출 불가(CONF-4) — 부서 단위까지만 답하고 부서명에서 상위 조직을 추측하지 말 것. ⚠️부서별 **목표 대비 실적·달성율**은 이 SV 가 아니라 SV_DEV_ACHIEVEMENT(월 conform) 소관이다.',
    date.EVENT_DATE   AS date.FULL_DATE     WITH SYNONYMS ('사건일', '발생일', '일자') COMMENT = '상태전이 발생일',
    date.CAL_YEAR     AS date.YEAR          WITH SYNONYMS ('연도', '년')   COMMENT = '연도',
    date.CAL_MONTH    AS date.MONTH         WITH SYNONYMS ('월')          COMMENT = '월(1~12)',
    date.WEEK_OF_YEAR AS date.WEEK_OF_YEAR  WITH SYNONYMS ('주차', '주')   COMMENT = '연중 주차',
    date.DAY_OF_WEEK  AS date.DAY_OF_WEEK   WITH SYNONYMS ('요일')        COMMENT = '요일. 실제값 7종: ''Fri''·''Mon''·''Sat''·''Sun''·''Thu''·''Tue''·''Wed'' + NULL',
    fme.EVENT_TYPE    AS fme.EVENT_TYPE     WITH SYNONYMS ('원천계통', '사건원천') COMMENT = '원천 계통 구분. 실제값 2종뿐: ''DEV''(개발원천) / ''STOP''(중단원천). ⚠ 상태(신규·증액·감액·재후원·후원중단)는 이 컬럼이 아니라 DVLP_DIV_NM 을 쓴다 — O24. 종전 COMMENT 가 "개발/중단/증액/미납중단"이라 적혀 있어 ''증액'' 필터 생성 시 0행 무증상 오답이 가능했다(AD-4 유형)',
    fme.DVLP_DIV_NM   AS fme.DVLP_DIV_NM    WITH SYNONYMS ('개발구분', '상태구분', '증액감액구분', '개발구분명') COMMENT = '개발구분(정본 MM015). 실제값 5종: ''신규''·''증액''·''감액''·''재후원''·''후원중단''. 중단원천 행은 NULL. ⚠ ''후원중단''은 EVENT_TYPE=''STOP'' 과 동일 사건이 두 원천에 중복 존재 → 두 축 합산 금지(중복 규모는 이슈원장 §O24 참조 · 현업확인 대기)',
    fme.DVLP_DIV_CD   AS fme.DVLP_DIV_CD    WITH SYNONYMS ('개발구분코드') COMMENT = '개발구분 원천코드(1=신규 2=증액 3=감액 4=재후원 5=후원중단). 라벨은 DVLP_DIV_NM. 실제값 5종: ''1''·''2''·''3''·''4''·''5'' + NULL',
    fme.JOIN_DATE     AS fme.JOIN_DATE      WITH SYNONYMS ('가입일')      COMMENT = '회원 가입일(유지기간 산출 기준)',
    fme.STOP_DATE     AS fme.STOP_DATE      WITH SYNONYMS ('중단일', '해지일') COMMENT = '회원 중단일',
    -- [2026-08-04 O33] 중단사유·중단경로 축. FME 는 라벨 컬럼을 직접 보유하고 단일 코드그룹(MM005)이라
    --   DIM_REASON 조인 없이 안전하다(FMM 쪽 사유와 달리 코드체계 혼입 없음).
    fme.STOP_REASON_NAME  AS fme.STOP_REASON_NM  WITH SYNONYMS ('중단사유', '해지사유', '중단이유') COMMENT = '중단사유 라벨(정본 MM005 단일 코드체계 — 혼입 없음). 실제값 예: ''개인(경제적)사유''·''장기미납''·''신규미납''·''다른곳지원''·''명의변경''·''아동퇴소''·''회원항의''·''기타''. 🔴**중단(STOP) 사건 전용 축**이다 — 개발(DEV) 행은 원천에 사유가 없어 NULL 이다. 따라서 중단 지표(중단건·중단회원수)와 함께 쓸 것이며, 개발 지표와 교차하면 전건 NULL 로 뭉개진다',
    fme.STOP_CHANNEL_NAME AS fme.STOP_CHANNEL_NM WITH SYNONYMS ('중단경로', '해지경로', '중단채널') COMMENT = '중단 접수경로 라벨. 🔴중단(STOP) 사건 전용 — 개발 행은 NULL. 중단사유와 같은 원천 행에서 온다. 실제값 3종: ''CRM''·''홈페이지''·''SYSTEM'' + NULL',
    -- [2026-08-04 O35] 사건시점 연령대·지역 축. 🔴 아래 4개 차원 모두 **개발(DEV) 사건 전용**이다
    --   (중단 원천에는 연령·지역 컬럼이 구조적으로 없어 NULL). 이 SV 에는 캠페인 축이 함께 있으므로
    --   **연령대 × 캠페인 교차**가 여기서 성립한다 — SV_MEMBER_MONTHLY 로는 불가하다.
    fme.AGE_BAND_AT_EVENT AS fme.AGE_BAND_AT_EVENT WITH SYNONYMS ('연령대', '나이대', '사건시점 연령대', '약정시점 연령대', '개발시점 연령대') COMMENT = '🔴**개발약정(사건) 당시의** 회원 연령대 — **현재 나이가 아니다**. 코드사전 CM014. 실제값: ''10대 미만''·''10대''·''20대''·''30대''·''40대''·''50대''·''60대''·''70대''·''70대 이상''·''단체''·''기업''·''기타''. ✅라벨 매핑은 CM014 사전과 일치 검증됨. ✅''10대 미만''이 최다인 것도 **실제이며 데이터 오류가 아니다** — 원인은 **편지쓰기대회 계열 캠페인**(희망편지쓰기대회·가족그림편지쓰기대회·세계시민교육편지)이며 학교·부모 DB 를 통해 **아동 본인 명의로 후원 약정을 맺는 모집 이벤트**다. 🟢 **이 SV 에서 직접 확인할 수 있다** — 이 차원을 CAMPAIGN_NAME 과 교차하면 해당 계열의 ''10대 미만'' 비중이 그 외 캠페인보다 압도적으로 높은 것이 재현된다. 결측·기본값 오염으로 설명하지 말 것. ⚠️SV_MEMBER_MONTHLY 의 MEMBER_AGE_BAND_AT_PLEDGE 와 **다른 축**이다 — 그쪽은 회원 현재행이 담은 *최근* 약정 스냅샷이고 이 차원은 *그 사건* 당시 값이라 값이 다를 수 있다(사건시점이 정확하다). 🔴개발(DEV) 사건 전용 — 중단(STOP) 행은 원천에 컬럼이 없어 NULL 이며 ''미상''이 아니다',
    fme.AGE_CD_AT_EVENT   AS fme.AGE_AT_EVENT      WITH SYNONYMS ('연령대코드') COMMENT = '사건시점 연령대 원천코드(CM014 1=10대 미만 2=10대 3=20대 4=30대 5=40대 6=50대 7=60대 8=70대 9=70대 이상 10=단체 11=기업 12=기타). 🔴연속형 나이가 아니므로 평균·구간 재계산 금지. 라벨은 AGE_BAND_AT_EVENT. 개발(DEV) 사건 전용',
    fme.REGION_AT_EVENT   AS fme.REGION_AT_EVENT   WITH SYNONYMS ('지역', '시도', '사건시점 지역', '약정시점 지역') COMMENT = '🔴**개발약정(사건) 당시의** 회원 지역 라벨 — **현재 거주지가 아니다**. 정본 공#131 · 코드사전 CM018 약칭. 실제값: ''서울''·''경기''·''인천''·''강원''·''대전''·''대구''·''부산''·''광주''·''울산''·''세종''·''충남''·''충북''·''전남''·''전북''·''경남''·''경북''·''제주''·''기타''. ⚠️''현재 거주지역별'' 질문에는 답할 수 없다 — BRONZE 에 현주소 축이 없다(O34). ⚠️센티넬 코드 ''0''은 사전에 라벨이 없어 NULL 이다 — ''미상''으로 창작하지 말 것. ⚠️SV_MEMBER_MONTHLY 의 MEMBER_REGION_AT_PLEDGE(최근 약정 스냅샷)와 **다른 축**이며 이사 등으로 값이 다를 수 있다. 🔴개발(DEV) 사건 전용 — 중단 행은 NULL',
    fme.AREA_CD_AT_EVENT  AS fme.AREA_CD_AT_EVENT  WITH SYNONYMS ('지역코드') COMMENT = '사건시점 지역 원천코드(CM018 + 라벨 없는 센티넬 ''0''). 라벨은 REGION_AT_EVENT. 개발(DEV) 사건 전용. 실제값 19종: ''0''·''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''·''9''·''10''·''11''·''12''·''13''·''14''·''15''·''16''·''17''·''18'' + NULL',
    member.GENDER_NAME   AS member.GENDER_NAME   WITH SYNONYMS ('성별')     COMMENT = '회원 성별 — 정본 공#130. 실제값 5종: ''남자''·''여자''·''기업''·''단체''·''기타''(CM017 라벨). ⚠ 종전 코드값(''M''/''F''/''U'') 노출 → O26 교정',
    member.SEX           AS member.SEX           WITH SYNONYMS ('성별코드') COMMENT = '성별 원천코드(CM013). 이 차원의 실제값 8종 1~8 (+미기재 NULL). ⚠회원 마스터에 ''0''은 없다 — sentinel ''0''은 개발·증감 원천에만 존재하므로 ''0'' 조건은 0행. 라벨은 GENDER_NAME(분석)·SEX_NM(원천)',
    member.SEX_NM        AS member.SEX_NM        WITH SYNONYMS ('성별상세', '국내외국인') COMMENT = 'CM013 원천 라벨 8종(국내(남자)·외국인(여자)·단체·기업 등). 국내/외국인 구분용. 실제값 8종: ''기업''·''기타''·''단체''·''국내(남자)''·''국내(여자)''·''외국인(기타)''·''외국인(남자)''·''외국인(여자)'' + NULL',
    member.MEMBER_STATUS_NAME AS member.MEMBER_STATUS_NAME WITH SYNONYMS ('회원상태') COMMENT = '현재 회원상태 라벨(공#132, MM010). 실제값 13종: ''활동회원''·''신규미납1''·''신규미납2''·''신규미납3''·''신규미납4''·''신규미납5''·''장기미납1''·''장기미납2''·''장기미납3''·''장기미납4''·''장기미납5''·''후원중단''·''(해당없음)''. 🔴 **라벨에 숫자 접두가 없다** — 상태 코드번호를 라벨 앞에 붙인 형태로 필터하면 0행 무증상 오답이다(경위는 원장 §O58-C). ⚠️ ''(해당없음)''은 일시회원이며 정기후원 상태축의 **구조적 부재**다 — 결측이 아니다',
    member.MBER_STAT_CD  AS member.MBER_STAT_CD  WITH SYNONYMS ('회원상태코드') COMMENT = '회원상태 원천코드(MM010 1~12). 실제값 12종: ''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''·''9''·''10''·''11''·''12'' + NULL',
    member.MEMBER_TYPE_NAME AS member.MEMBER_TYPE_NAME WITH SYNONYMS ('회원구분') COMMENT = '회원구분 라벨(MM018): 개인·기업·단체. 실제값 3종: ''개인''·''기업''·''단체''',
    member.MBER_DIV_CD   AS member.MBER_DIV_CD   WITH SYNONYMS ('회원구분코드') COMMENT = '회원구분 원천코드(MM018). 실제값 3종: ''1''·''2''·''3''',
    -- [2026-08-04 O33] 캠페인 자체 속성. 🔴 아래 4개 차원 모두 **개발(DEV) 사건 전용**이다.
    campaign.CAMPAIGN_NAME      AS campaign.CAMPAIGN_NAME      WITH SYNONYMS ('캠페인', '캠페인명', '모금캠페인') COMMENT = '캠페인명. 🔴 이 SV 에서 캠페인은 **사건 자신의 캠페인**이다 — 개발(DEV) 행은 약정 캠페인, 개발원천 후원중단(DVLP_DIV_NM=''후원중단'') 행은 **중단 시점 캠페인**이다. ⚠️ 중단원천(EVENT_TYPE=''STOP'') 행은 원천에 캠페인이 없어 ''(미매핑)''으로 뭉개진다 → **중단 규모를 캠페인별로 볼 때는 TOTAL_STOP_CNT 가 아니라 TOTAL_CAMPAIGN_STOP_CNT 를 쓴다**(2026-08-05 O37). 🔴 **종전 이 자리에 있던 *"캠페인별 중단건은 답이 나오지 않는다"* 는 서술은 회수됐다** — 개발원천 코드5 행이 캠페인을 보유하므로 답이 나온다. 🔴 캠페인별 **중단률(비율)**은 이 SV 가 아니라 **SV_MEMBER_COHORT** 다(분모가 획득 회원수여야 비율이 성립한다)',
    campaign.CAMPAIGN_BRAND     AS campaign.BRAND              WITH SYNONYMS ('브랜드', '캠페인 브랜드') COMMENT = '캠페인 브랜드',
    campaign.PARENT_CAMPAIGN_NAME AS campaign.PARENT_CAMPAIGN_NAME WITH SYNONYMS ('상위캠페인', '상위캠페인명', '캠페인 그룹') COMMENT = '상위캠페인명(2026-08-05 O37 신설 — 종전에는 자기참조 코드만 있어 사람이 읽을 수 없었다). ⚠️ 상위가 없는 캠페인은 NULL 이며 ''(미매핑)''이 아니다. ⚠️ 캠페인 카테고리(CAMPAIGN_TYPE)와 다른 축이다',
    campaign.PROMO_METHOD_NAME  AS campaign.PROMO_METHOD_NAME  WITH SYNONYMS ('홍보방법', '광고방법', '매체', '홍보수단') COMMENT = '홍보방법 라벨(코드사전 CM008, 2026-08-05 O37 신설). 실제값 계열: ''PC배너광고(DA)''·''M배너광고(DA)''·''PC검색광고(SA)''·''M검색광고(SA)''·''TM''·''TS''·''PC캠페인-홈페이지''·''M캠페인-홈페이지''·''온라인''·''오프라인''·''APP캠페인''·''기존회원메일''·''기타''. 🔴 원천 `PR_MTH_CD` 는 숫자 코드이며 종전에는 라벨이 없어 이 축을 쓸 수 없었다 — 코드로 필터하면 0행이 반환된다. 반드시 이 라벨로 필터·그루핑한다. ⚠️ 유입경로와 다른 축이다',
    -- [2026-08-25 설계부채 해소] 회원 개발이력 비정규화 9속성(구 campaign.* 실시간 조인) →
    --   FME 자신의 `_AT_EVENT` 스냅샷 컬럼(SILVER CRM_MEMBER_DEV 적재 시점 동결값)으로 소스 전환.
    --   캠페인 마스터(CRM_CAMPAIGN/DIM_CAMPAIGN)가 이후 정정돼도 과거 개발이력 사건의 값은
    --   더 이상 바뀌지 않는다. 친화명(컬럼명·synonyms)은 기존과 동일하게 유지해 소비측 영향 없음.
    fme.CAMPAIGN_TYPE      AS fme.CMPGN_CTGR_NM_AT_EVENT      WITH SYNONYMS ('캠페인카테고리', '캠페인유형', '주요캠페인', '캠페인 종류') COMMENT = '캠페인 카테고리(MM294 라벨) — 현업이 말하는 **''주요캠페인''** 축이다. 🔴적재 시점 동결값(구 campaign.CAMPAIGN_TYPE 대체). 실제값 예: ''초등캠페인''·''국내사례캠페인''·''굿즈캠페인''·''해외캠페인''·''기타 영상광고''·''홈페이지(PC/모바일)''·''희망TV''·''인바운드''·''가두캠페인''·''대학생캠페인''. 개발(DEV) 사건 전용 — 중단(STOP) 행은 NULL',
    fme.CAMPAIGN_INFLOW_PATH AS fme.MBER_INFLOW_PATH_NM_AT_EVENT WITH SYNONYMS ('모집채널', '유입경로', '개발인입경로') COMMENT = '캠페인의 **모집 채널**(MM293 라벨). 🔴적재 시점 동결값(구 campaign.INFLOW_PATH 대체). ⚠️ 이 축은 채널이며 「주요캠페인」이 아니다 — 주요캠페인은 CAMPAIGN_TYPE 이다. ⚠️ 회원 가입경로(회원 속성)와도 다른 축이다. 개발(DEV) 사건 전용 — 중단(STOP) 행은 NULL',
    -- 🔴 [2026-08-29 O119] `DOMESTIC_OVERSEAS` 종수·열거를 라이브 실측으로 교체했다
    --   (`sv_code_label_gate` 축2 「종수 선언 불일치」). 종전 「3종」에 **`전체사업` 이 빠져 있었다.**
    --   형제 축 `SV_MEMBER_COHORT.DOMESTIC_OVERSEAS`(`ACQ_CMPGN_TYPE1_NM`)도 같은 결함이어서 함께 시정했다.
    --   🟠 **미시정 잔여(같은 파일)** = 바로 위 `CAMPAIGN_INFLOW_PATH` 는 열거가 아예 없다(게이트 🟠
    --      「열거 누락」). 그 축의 라이브 라벨 집합은 `SV_MEMBER_COHORT` 쪽과 동일하며 O119 가
    --      그쪽 열거를 실측으로 교체했다 ⇒ **여기에도 같은 열거를 넣는 것이 다음 후보**다.
    fme.DOMESTIC_OVERSEAS  AS fme.CMPGN_TYPE1_NM_AT_EVENT     WITH SYNONYMS ('국내해외', '국내외') COMMENT = '캠페인 국내/해외 구분(MM295). 🔴적재 시점 동결값(구 campaign.DOMESTIC_OVERSEAS 대체). 실제값 4종: ''국내''·''해외''·''통합''·''전체사업'' + NULL. ⚠️ ''통합''과 ''전체사업''은 서로 다른 값이다 — 하나로 묶지 말고 원천 라벨 그대로 노출한다. 개발(DEV) 사건 전용 — 중단(STOP) 행은 NULL',
    fme.BIZ_CASE_TYPE      AS fme.CMPGN_TYPE2_NM_AT_EVENT     WITH SYNONYMS ('사업사례구분', '사업/사례') COMMENT = '캠페인 사업/사례 구분(MM296). 🔴적재 시점 동결값(구 campaign.BIZ_CASE_TYPE 대체). 실제값 4종: ''사례''·''사업''·''굿즈''·''기타''. 개발(DEV) 사건 전용 — 중단(STOP) 행은 NULL',
    fme.MARKETING_CAMPAIGN AS fme.MKTG_CMPGN_NM_AT_EVENT      WITH SYNONYMS ('마케팅캠페인', '마케팅 캠페인명') COMMENT = '마케팅캠페인명. 🔴적재 시점 동결값(구 campaign.MARKETING_CAMPAIGN 대체). 카디널리티가 높다 — 부분 일치로 추측하지 말고 실제값을 조회해 확인한다. 개발(DEV) 사건 전용 — 중단(STOP) 행은 NULL',
    fme.CMMN_BRND_NM       AS fme.CMMN_BRND_NM_AT_EVENT       WITH SYNONYMS ('공통브랜드', '공통 브랜드') COMMENT = '공통브랜드 라벨(코드사전 MM297, 14종). 🔴적재 시점 동결값(구 campaign.CMMN_BRND_NM 대체). ⚠️라벨이 CAMPAIGN_INFLOW_PATH(MM293 개발인입경로)와 상당 중복되나 현업 확인상 별도 축으로 유지한다. 개발(DEV) 사건 전용 — 중단(STOP) 행은 NULL',
    fme.MKTG_UTM_NM        AS fme.MKTG_UTM_NM_AT_EVENT        WITH SYNONYMS ('UTM', 'UTM 라벨', '마케팅 UTM') COMMENT = 'UTM 라벨 — 코드사전이 아니라 원천 TM_CM_MKTNG_UTM(MK_UTM/MK_UTM_NM)과 연동된 값. 🔴적재 시점 동결값(구 campaign.MKTG_UTM_NM 대체). ⚠️원천 코드사전 매핑률이 낮아 다수 행이 NULL이다 — 결측이 아니라 미등재 코드다(채움 비율은 규칙7 상 여기 적지 않는다 · 조회로 확인하고 UTM별 분해가 부분집합임을 밝힐 것 · 규모는 이슈원장 §O105 참조). 개발(DEV) 사건 전용 — 중단(STOP) 행은 NULL',
    fme.SPNSR_DIV_NM       AS fme.SPNSR_DIV_NM_AT_EVENT       WITH SYNONYMS ('세부캠페인 후원구분', '캠페인 후원구분') COMMENT = '세부캠페인 후원구분 라벨(CM035): 정기후원/일시후원. 🔴적재 시점 동결값(구 campaign.SPNSR_DIV_NM 대체). ⚠️ SPONSORSHIP.SPONSORSHIP_DIV_NAME(후원사업 축 CM035)과 코드사전은 같지만 적용 대상이 다르다 — 이 축은 세부캠페인 단위 구분이다. 개발(DEV) 사건 전용 — 중단(STOP) 행은 NULL',
    fme.CPR_DIV_NM         AS fme.CPR_DIV_NM_AT_EVENT         WITH SYNONYMS ('세부캠페인 법인구분', '캠페인 법인구분') COMMENT = '세부캠페인 법인구분 라벨(CM019): 통합/사단/사복. 🔴적재 시점 동결값(구 campaign.CPR_DIV_NM 대체). 개발(DEV) 사건 전용 — 중단(STOP) 행은 NULL',
    -- [2026-08-05 O37] 사건시점 성별 — `_AT_EVENT` 계열. 개발원천이 사건행별 성별을 보유한다.
    fme.GENDER_AT_EVENT         AS fme.GENDER_AT_EVENT         WITH SYNONYMS ('사건시점 성별', '약정시점 성별') COMMENT = '**사건(개발약정) 시점** 성별 라벨(코드사전 CM013). 실제값 8종: ''국내(남자)''·''국내(여자)''·''외국인(남자)''·''외국인(여자)''·''외국인(기타)''·''단체''·''기업''·''기타''. 🔴 위 `member.GENDER_NAME`(회원 마스터 **현재 스냅샷** · CM017 계열)과 **코드체계가 다르다** — 두 축을 합산하지 말 것. 이 축이 사건 당시 정확값이다. 🔴 개발(DEV) 사건 전용(중단원천에 성별 컬럼 부재 → NULL). ⚠️ 사전 미등재 센티넬 ''0''은 라벨이 없어 NULL 이며 ''미상''으로 창작하지 않는다',
    fme.SEX_AT_EVENT            AS fme.SEX_AT_EVENT            WITH SYNONYMS ('사건시점 성별코드') COMMENT = '사건시점 성별 원천코드(CM013 1~8 + 라벨 없는 센티넬 ''0''). 라벨은 GENDER_AT_EVENT. 실제값 9종: ''0''·''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8'' + NULL'
  )
  METRICS (
    fme.TOTAL_DEV_CNT     AS SUM(fme.DEV_CNT)
      WITH SYNONYMS ('개발건', '개발 총건') COMMENT = '개발 건수 합계. F(가산). 정본 공#121 개발구분 = 신규·증액·재후원 한정(감액·후원중단 제외). ⚠ 2026-08-03 O24 교정 이전 값은 감액·후원중단까지 포함해 과대계상됐다(교정 전·후 값과 과대 비율은 이슈원장 §O24 참조) — 과거 리포트와 대조 시 주의.',
    fme.TOTAL_STOP_CNT    AS SUM(fme.STOP_CNT)
      WITH SYNONYMS ('중단건', '중단 총건', '해지건') COMMENT = '중단 건수 합계. F(가산). 중단원천(EVENT_TYPE=''STOP'') 기준. ⚠ DVLP_DIV_NM=''후원중단'' 행수와 더하지 말 것(동일 사건 중복, O24).',
    -- [2026-08-03 O24] 증액·감액 사건 measure 신설.
    --   🔴 명명 주의: 정본 공#150 증액(명)·#151 증액(건)·#38 감액(건)은 **월 마감 시 전월 대비 활동(건) 증감**
    --      = FMM 월말 스냅샷 비교 정의이고, 아래 metric 은 **사건 발생일 기준**이다. 두 정의는 값이 다르며
    --      어느 쪽을 정본으로 삼을지 **미확정**(O24 잔여) → 정본 지표번호를 자칭하지 않는 이름을 쓴다.
    --   금액 기준인 이유: 정본이 `(건)` = 금액÷10,000 으로 정의하므로(CONF-2) 행수로 세면 정의 파괴.
    fme.INCREASE_EVENT_AMT AS SUM(CASE WHEN fme.DVLP_DIV_NM = '증액' THEN fme.SPNSR_AMT END)
      WITH SYNONYMS ('증액금액', '증액 총액') COMMENT = '증액 사건 금액 합계(원). F(가산). 사건 발생일 기준 — 정본 공#150·#151(월말 스냅샷 대비)과 정의가 다르다(O24 미확정).',
    fme.DECREASE_EVENT_AMT AS SUM(CASE WHEN fme.DVLP_DIV_NM = '감액' THEN fme.SPNSR_AMT END)
      WITH SYNONYMS ('감액금액', '감액 총액') COMMENT = '감액 사건 금액 합계(원, **음수**). F(가산). 사건 발생일 기준 — 정본 공#38(감액(건)=금액÷10,000)과 단위·정의가 다르다(O24 미확정).',
    fme.INCREASE_MEMBER_COUNT AS COUNT(DISTINCT CASE WHEN fme.DVLP_DIV_NM = '증액' THEN fme.MEMBER_DK END)
      WITH SYNONYMS ('증액회원수') COMMENT = '증액 고유 회원수. D(distinct). 사건 기준.',
    fme.DECREASE_MEMBER_COUNT AS COUNT(DISTINCT CASE WHEN fme.DVLP_DIV_NM = '감액' THEN fme.MEMBER_DK END)
      WITH SYNONYMS ('감액회원수') COMMENT = '감액 고유 회원수. D(distinct). 사건 기준.',
    fme.DEV_MEMBER_COUNT  AS COUNT(DISTINCT CASE WHEN fme.DEV_CNT > 0 THEN fme.MEMBER_DK END)
      WITH SYNONYMS ('개발회원수', '신규 회원수') COMMENT = '개발 고유 회원수. D(distinct). 다기간도 중복 없음.',
    fme.STOP_MEMBER_COUNT AS COUNT(DISTINCT CASE WHEN fme.STOP_CNT > 0 THEN fme.MEMBER_DK END)
      WITH SYNONYMS ('중단회원수', '해지 회원수') COMMENT = '중단 고유 회원수. D(distinct).',
    -- [2026-08-05 O37] 캠페인 귀속 중단건. 개발원천 코드5(후원중단) 행 기준이며 그 행은 캠페인을
    --   보유하므로 **캠페인별 중단 사건 분해**가 성립한다. 종전 "산출 불가" 판정을 해소한다.
    fme.TOTAL_CAMPAIGN_STOP_CNT AS SUM(fme.CAMPAIGN_STOP_CNT)
      WITH SYNONYMS ('캠페인별 중단건', '캠페인 귀속 중단건', '캠페인별 해지건')
      COMMENT = '캠페인 귀속 중단(건) — 개발원천 후원중단 행 기준. F(가산). 🔴 **캠페인별 중단 규모를 볼 때 이 measure 를 쓴다**(TOTAL_STOP_CNT 는 중단원천 기준이라 캠페인이 전건 ''(미매핑)''이다). 🔴 **TOTAL_STOP_CNT 와 절대 합산 금지** — 같은 중단 사건이 두 원천에 중복 존재한다(O24). 🔴 **이 값을 개발건으로 나눠 「중단률」로 쓰지 말 것** — 이 행의 캠페인은 **중단 시점** 캠페인이라 신규 건수와 모집단이 달라 비율이 100%를 넘는다(실측). 캠페인별 중단률의 정본은 **SV_MEMBER_COHORT** 의 12개월 고정 이탈률이다.',
    fme.CAMPAIGN_STOP_MEMBER_COUNT AS COUNT(DISTINCT CASE WHEN fme.CAMPAIGN_STOP_CNT > 0 THEN fme.MEMBER_DK END)
      WITH SYNONYMS ('캠페인별 중단회원수') COMMENT = '캠페인 귀속 중단 고유 회원수. D(distinct). 위 TOTAL_CAMPAIGN_STOP_CNT 와 동일 모집단(개발원천 후원중단 행).'
    -- ⚠ AVG_RETENTION_MONTHS(신4 유지기간) 미노출: 개발행에 JOIN_DATE·중단행에 STOP_DATE가 서로 다른 행에
    --   있어 행별 DATEDIFF가 전건 NULL이고 LAST_STOP_DATE도 미적재 → 산출 불가. 근거·경위 = 04 §6.9-(2) 계열.
  )
  COMMENT = 'Phase-1 회원 상태전이 SV (base: GOLD.FACT_MEMBER_EVENT, grain: 회원×일 사건 1행). CRM 원천 기반 회원 개발 및 중단 사건, 신규/증액/감액/재후원/중단 5종 개발구분(DVLP_DIV_NM), 증감 금액, 캠페인별/부서별 실적 뷰. ⚠️ 캠페인별 중단은 TOTAL_CAMPAIGN_STOP_CNT 를 사용하며 TOTAL_STOP_CNT(중단원천)와 합산 금지. 캠페인별 중단률은 SV_MEMBER_COHORT(12개월 고정 이탈률) 사용. 부서별 목표대비 달성율은 SV_DEV_ACHIEVEMENT 사용.'
  AI_SQL_GENERATION '핵심 규칙: (1) 개발구분 필터: 증액·감액·신규·재후원·후원중단 질의는 EVENT_TYPE 이 아니라 DVLP_DIV_NM 으로 필터. (2) 중단 지표: 전체 중단 규모는 TOTAL_STOP_CNT, 캠페인별 중단 분해는 TOTAL_CAMPAIGN_STOP_CNT 사용 (두 지표 절대 합산 금지). 캠페인별 중단률은 SV_MEMBER_COHORT 로 라우팅. (3) 개발 지표: 개발 실적 건수는 TOTAL_DEV_CNT (신규·증액·재후원 합산) 사용. (4) 기간 미지정 시: 데이터 최신 연월 기준 직전 12개월로 한정하며 GROUP BY ROLLUP((연,월)) 반환. (5) 속성 시점: 연령대(AGE_BAND_AT_EVENT) 및 지역(REGION_AT_EVENT)은 개발 사건 시점 값이며 개발(DEV) 사건 전용. (6) 주간 실적: 주간 개발실적은 WEEK_OF_YEAR 와 CAL_YEAR 를 동반하여 조회하며 주간 목표 대비는 SV_DEV_ACHIEVEMENT 와 표를 분리하여 제시. (7) 홍보방법 필터: PROMO_METHOD_NAME 라벨 필터 사용.';


/* =====================================================================================
   GRANT — Cortex Analyst 소비 권한 (docs: REFERENCES, SELECT 필요 · USAGE 아님)
      ANALYST 가 VIEWER 를 상속하나 명확성을 위해 3역할 모두 명시(02 §E 패턴).
      🟢 [2026-08-10 O54] 본문이 `CREATE OR ALTER` 이므로 **기존 GRANT 는 보존**된다 →
         아래 GRANT 는 멱등 재확인이다. 🔴 판정은 소유자 세션이 아니라 **소비 역할 세션**으로
         한다(P126) — 검사기 = `scripts/sv_unit_gate.py`.
         분할의 이점: GRANT 가 대상 SV 와 같은 파일에 있어 빠뜨릴 수 없다.
   ===================================================================================== */
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_EVENT TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_EVENT TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_EVENT TO ROLE GN_DW_SERVICE;


/* =====================================================================================
   스모크 검증 (배포 직후 실행) — 04 §0.1 DoD
      원리: `SEMANTIC_VIEW(...)` 집계 == 단일 FACT 직접 SUM 일치 → 조인 fan-out 0 검증.
      🔴 판정은 **절대값이 아니라 불변식**으로 한다. 적재량은 계정·시점마다 다르므로
         "sv_val == fact_val" 같은 관계식이 참인지만 본다. 기대 절대값을 문서에 박으면
         재현 시 전항 오탐이 된다(04 §6.9-(8)).
      ▶ SV 9종 전체를 아우르는 배포 검증(소유권·GRANT·구조 대조·base 스키마) = `05_0_SV_DDL.sql`
   ===================================================================================== */
USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- (8-3) 차원 조인 스모크: 회원 성별별 개발건 (O26: GENDER→GENDER_NAME 라벨 노출)
SELECT * FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_MEMBER_EVENT
  DIMENSIONS member.GENDER_NAME
  METRICS TOTAL_DEV_CNT
) ORDER BY 1;
