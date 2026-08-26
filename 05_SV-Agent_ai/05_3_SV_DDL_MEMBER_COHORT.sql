-- GN_DW 3단계: Semantic View DDL 정본 — SV_MEMBER_COHORT (회원 획득 코호트 · 캠페인별 중단률)
-- Co-authored with CoCo
-- ============================================================================
-- ▶ 이 파일의 위상  [2026-08-05 O37 분할]
--   대상 SV = **SV_MEMBER_COHORT** — 이 파일 하나로 **독립 실행**된다(상세 = 아래 포인터).
--   🟢 [2026-08-10 OWN-1 해소] 이 파일은 `CREATE OR ALTER` 로 전환됐다 — **GRANT 도 소유권도 파괴하지 않는다**.
--      배경: 종전 `CREATE OR REPLACE` 는 owner 를 실행 역할로 리셋했고(GRANT 절은 소유권을 복구하지 않는다)
--      그 결과 이 SV 의 owner 가 `ACCOUNTADMIN` 으로 드리프트해 있었다.
--      조치 순서 = ① `GRANT OWNERSHIP … TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS` → ② `CREATE OR ALTER` 전환.
--      실측 판정: SV 9종 전건 owner=`GN_DW_ADMIN` 단일 · 소비 3역할 × REFERENCES/SELECT 보존 ·
--      소비 역할 세션 조회 6/6 성공 · `TOTAL_ACQ_MEMBERS` 1,585,949 불변.
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
   SV_MEMBER_COHORT (회원 Agent) — base FMC(회원 grain: 1행 = 1회원)
      정본 = 캠페인별 **중단률(이탈률)** · 유지기간 · 획득시점 회원특성
   -------------------------------------------------------------------------------------
   ▶ 왜 이 SV 가 신설됐나 (O37)
     Agent 가 *"캠페인 축은 개발 사건에만 배선돼 있고 중단 사건에는 캠페인 정보가 원천에 없다 —
     따라서 캠페인별 중단률은 구조적으로 산출 불가"* 라고 답했다. 원천 재스캔 결과 그 판정은
     틀렸다(개발원천 코드5 행이 캠페인을 전건 보유). 그러나 **캠페인을 노출하는 것만으로는
     중단률이 되지 않는다** — 실측으로 두 함정을 확인했고 이 SV 가 그것을 구조로 막는다.

     ① 중단 사건 자신의 캠페인은 **중단 시점** 캠페인이다. 신규 건수로 나누면 분자·분모의
        모집단이 달라 비율이 100% 를 넘는다(기존회원 대상 캠페인에서 실증). 비율이 아니다.
        → 분모를 **획득 코호트**(그 캠페인이 데려온 회원)로 잡아야 비율이 성립한다.
     ② 누적 이탈률은 **관측 기간**에 지배된다. 획득이 이를수록 누적 이탈률이 높아지는 단조
        관계가 실측됐다. 캠페인은 실행 연도가 다르므로 누적률로 비교하면 **오래된 캠페인이
        자동으로 「중단률 높음」**이 된다 — 값·매핑·채움률이 전부 정상이라 어떤 품질 테스트로도
        잡히지 않는 **의미 결함**이다(P60 계열).
        → **12개월 고정 이탈률**을 정본으로 삼고 분자를 관측 가능 코호트로 제한했다.

   ▶ 이 SV 의 grain 이 다른 회원 SV 와 다르다 (혼용 금지)
     · `SV_MEMBER_COHORT`(이 SV) = **회원 1행** — "그 캠페인으로 들어온 회원이 이탈했는가"
     · `SV_MEMBER_EVENT`         = 일×회원×사건 — "언제 무슨 사건이 몇 건 있었는가"
     · `SV_MEMBER_MONTHLY`       = 월×회원 — "그 달에 얼마 납입했는가"
     🔴 중단 **건수**는 `SV_MEMBER_EVENT`, 중단 **률**은 이 SV 다. 둘을 더하거나 나누지 않는다.

   ▶ fan-out 안전성 (R1)
     base 가 회원 grain·PK(MEMBER_DK) 유일이라 SCD2 증폭이 원천적으로 없다 →
     `DIM_MEMBER_CURRENT` helper 뷰가 불요하다. 획득 시점 회원속성을 팩트가 직접 보유하므로
     **현재 스냅샷 경유가 아니어서 P60(시점 왜곡)도 회피**된다.
     캠페인·날짜 차원은 PK 유일(fan-out 0 실측).
   ===================================================================================== */
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_COHORT
  TABLES (
    fmc AS GN_DW.GOLD.FACT_MEMBER_COHORT
      PRIMARY KEY (MEMBER_DK)
      WITH SYNONYMS ('회원 코호트', '획득 코호트', '회원 이탈', '중단률')
      COMMENT = '회원 획득 코호트 팩트(1행=1회원). 캠페인별 중단률·유지기간·획득시점 회원특성의 정본. 개발(약정) 이력이 있는 회원만 존재한다 — 개발 이력이 없는 중단회원은 획득 캠페인을 알 수 없어 미포함(그런 회원의 중단 총계는 SV_MEMBER_EVENT). [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: TM_MM_FDRM_MBER_DVLP_AMT(개발·CMPGN_CD·AGE·AREA_CD·SEX) + TM_MM_FDRM_MBER_SPNSR_DSCNTC(중단·DSCNTC_RSN_CD) · SILVER=CRM_MEMBER_DEV + CRM_MEMBER_DISCONTINUE · GOLD=FACT_MEMBER_EVENT → FACT_MEMBER_COHORT.',
    acq_campaign AS GN_DW.GOLD.DIM_CAMPAIGN
      PRIMARY KEY (CAMPAIGN_SK)
      WITH SYNONYMS ('획득캠페인', '모집캠페인', '캠페인')
      COMMENT = '회원을 처음 데려온 캠페인. PK 유일이라 조인이 행수를 늘리지 않는다. 🔴 이 SV 에서 캠페인은 **획득(모집) 캠페인**이며 「중단 시점 캠페인」이 아니다 — 중단률의 분모(획득 회원)와 같은 축이어야 비율이 성립한다. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: TM_CM_CMPGN_MNG · SILVER=CRM_CAMPAIGN.',
    acq_date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('획득일', '약정일', '가입일자')
      COMMENT = '획득(최초 약정)일 차원. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.',
    -- ── [2026-08-06 O45] 획득 조직·후원사업 축 ────────────────────────────────
    --   🔴 종전 SV COMMENT 는 *"비활성: 조직/후원사업별 분해(획득 사건에 조직·후원사업 축 미배선)"*
    --      라고 적고 있었다. O45 로 `FMC.ACQ_ORG_SK`·`ACQ_SPONSORSHIP_SK` 가 실배선되어 **거짓이 됐다** → 회수.
    --   ✅ 팬아웃 실측(2026-08-06): FMC 1,585,949 → 두 조인 모두 **행수 불변**. 두 차원 PK 유일 확인.
    acq_org AS GN_DW.GOLD.DIM_ORG
      PRIMARY KEY (ORG_SK)
      WITH SYNONYMS ('획득부서', '가입부서', '모집부서')
      COMMENT = '🔴**획득(최초 약정) 시점의 실적부서** 차원. 개발실적보고의 「부서」(=사건 부서, SV_MEMBER_EVENT.ORG_DEPARTMENT)와 **다른 축**이다 — 같은 라벨이 두 축이며 값이 다르다. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: TM_MM_FDRM_MBER_DVLP_AMT(ACMSLT_DEPT_CD) + TM_CM_DEPT_INFO · SILVER=CRM_MEMBER_DEV + CRM_ORG.',
    acq_sponsorship AS GN_DW.GOLD.DIM_SPONSORSHIP
      PRIMARY KEY (SPONSORSHIP_SK)
      WITH SYNONYMS ('획득 후원사업', '가입 후원사업', '모집 후원사업')
      COMMENT = '🔴**획득 시점 후원사업**(그 회원을 데려온 사업) 차원. 회비 **납입 대상** 후원사업(SV_MEMBER_FEE)과 **다른 축**이다 — 한 회원이 여러 후원사업에 내므로 두 축은 값이 다르다. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: TM_MM_FDRM_MBER_DVLP_AMT(SPNSR_BSNS_ID) + TM_CM_SPNSR_BSNS_INFO · SILVER=CRM_MEMBER_DEV + CRM_SPONSOR_BIZ.'
  )
  RELATIONSHIPS (
    fmc_to_acq_campaign AS fmc (ACQ_CAMPAIGN_SK) REFERENCES acq_campaign,
    fmc_to_acq_date     AS fmc (ACQ_DATE_SK)     REFERENCES acq_date,
    fmc_to_acq_org      AS fmc (ACQ_ORG_SK)      REFERENCES acq_org,
    fmc_to_acq_spb      AS fmc (ACQ_SPONSORSHIP_SK) REFERENCES acq_sponsorship
  )
  DIMENSIONS (
    -- ── 획득 시점(코호트 정의) 축 ──────────────────────────────────────────────
    acq_date.ACQ_DATE       AS acq_date.FULL_DATE  WITH SYNONYMS ('획득일', '약정일', '모집일') COMMENT = '회원을 획득한 날(최초 신규 약정일). 🔴 이 SV 의 기간 필터는 **획득 시점** 기준이다 — "2024년"으로 물으면 「2024년에 획득한 회원의 이탈률」이 되며 「2024년에 이탈한 회원」이 아니다. 후자는 SV_MEMBER_EVENT 의 중단건을 쓴다',
    acq_date.ACQ_YEAR       AS acq_date.YEAR       WITH SYNONYMS ('획득연도', '가입연도', '모집연도') COMMENT = '획득 연도(코호트 연도)',
    acq_date.ACQ_MONTH      AS acq_date.MONTH      WITH SYNONYMS ('획득월') COMMENT = '획득 월(1~12)',
    fmc.ACQ_BASIS           AS fmc.ACQ_BASIS       WITH SYNONYMS ('획득근거', '코호트 판정근거') COMMENT = '획득 캠페인을 무엇으로 판정했는지. 실제값 2종: ''NEW''(개발구분 신규=MM015 코드1 사건으로 판정 — 대다수) / ''FALLBACK''(신규 사건이 없어 최초 개발 사건으로 대체 판정). 🔴 캠페인별 중단률을 비교할 때는 ''NEW'' 로 한정할 것을 권한다 — FALLBACK 은 획득 캠페인 신뢰도가 낮고, 극소수는 획득 근거가 ''후원중단''(코드5) 기록이라 「모집 캠페인」이라 부를 수 없다',
    fmc.ACQ_DVLP_DIV_CD     AS fmc.ACQ_DVLP_DIV_CD WITH SYNONYMS ('획득사건 개발구분코드') COMMENT = '획득으로 판정한 사건의 개발구분 원천코드(MM015). 실제값 5종 ''1''(신규)·''2''(증액)·''3''(감액)·''4''(재후원)·''5''(후원중단). ACQ_BASIS=''NEW'' 이면 항상 ''1'' 이고, ''2''~''5''는 전부 FALLBACK 이다',
    -- ── 획득 시점 회원 특성 (🔴 현재 값이 아니다) ───────────────────────────────
    fmc.ACQ_AGE_BAND        AS fmc.ACQ_AGE_BAND    WITH SYNONYMS ('연령대', '나이대', '획득시점 연령대', '약정시점 연령대') COMMENT = '🔴**획득(최초 약정) 당시의** 회원 연령대 — **현재 나이가 아니다**. 코드사전 CM014. 실제값 12종: ''10대 미만''·''10대''·''20대''·''30대''·''40대''·''50대''·''60대''·''70대''·''70대 이상''·''단체''·''기업''·''기타''. ✅ ''10대 미만''이 상위인 것은 **데이터 오류가 아니다** — **편지쓰기대회 계열 캠페인**(희망편지쓰기대회·가족그림편지쓰기대회·세계시민교육편지)이 학교·부모 DB 를 통해 **아동 본인 명의로 약정을 맺는 모집 이벤트**이기 때문이다. 이 SV 에서 캠페인 축과 교차하면 그 편중을 직접 수치로 확인할 수 있다. 결측·기본값 오염으로 설명하지 말 것. ⚠️ 현재 연령은 BRONZE 에 생년월일 축이 없어 **산출 불가**(O34)',
    fmc.ACQ_AGE_CD          AS fmc.ACQ_AGE_CD      WITH SYNONYMS ('연령대코드') COMMENT = '획득시점 연령대 원천코드(CM014 1=10대 미만 2=10대 3=20대 4=30대 5=40대 6=50대 7=60대 8=70대 9=70대 이상 10=단체 11=기업 12=기타). 🔴 연속형 나이가 아니므로 평균·구간 재계산 금지. 라벨은 ACQ_AGE_BAND',
    fmc.ACQ_REGION          AS fmc.ACQ_REGION      WITH SYNONYMS ('지역', '시도', '획득시점 지역', '약정시점 지역') COMMENT = '🔴**획득(최초 약정) 당시의** 회원 지역 라벨 — **현재 거주지가 아니다**. 정본 공#131 · 코드사전 CM018 약칭. 실제값 18종: ''서울''·''경기''·''인천''·''강원''·''대전''·''대구''·''부산''·''광주''·''울산''·''세종''·''충남''·''충북''·''전남''·''전북''·''경남''·''경북''·''제주''·''기타''. ⚠️ 센티넬 코드 ''0''은 사전에 라벨이 없어 NULL 이다 — ''미상''으로 창작하지 말 것. ⚠️ ''현재 거주지역별'' 질문에는 답할 수 없다(BRONZE 에 현주소 축 없음, O34)',
    fmc.ACQ_AREA_CD         AS fmc.ACQ_AREA_CD     WITH SYNONYMS ('지역코드') COMMENT = '획득시점 지역 원천코드(CM018 + 라벨 없는 센티넬 ''0''). 라벨은 ACQ_REGION. 실제값 19종: ''0''·''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''·''9''·''10''·''11''·''12''·''13''·''14''·''15''·''16''·''17''·''18'' + NULL',
    fmc.ACQ_GENDER          AS fmc.ACQ_GENDER      WITH SYNONYMS ('성별', '획득시점 성별') COMMENT = '획득시점 성별 라벨(코드사전 CM013). 실제값 8종: ''국내(남자)''·''국내(여자)''·''외국인(남자)''·''외국인(여자)''·''외국인(기타)''·''단체''·''기업''·''기타''. ⚠️ SV_MEMBER_EVENT·SV_MEMBER_MONTHLY 의 회원 성별(GENDER_NAME, CM017 라벨: 남자·여자·기업·단체·기타)과 **코드체계가 다르다** — 두 축을 같은 성별로 합산하지 말 것. ⚠️ 센티넬 ''0''은 라벨이 없어 NULL',
    fmc.ACQ_SEX_CD          AS fmc.ACQ_SEX_CD      WITH SYNONYMS ('성별코드') COMMENT = '획득시점 성별 원천코드(CM013 1~8 + 라벨 없는 센티넬 ''0''). 라벨은 ACQ_GENDER. 실제값 9종: ''0''·''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''',
    -- ── 이탈 특성 ─────────────────────────────────────────────────────────────
    fmc.FIRST_STOP_REASON   AS fmc.FIRST_STOP_REASON_NM WITH SYNONYMS ('중단사유', '이탈사유', '해지사유') COMMENT = '**최초 중단**의 사유 라벨(정본 MM005 단일 코드체계 — 혼입 없음). 실제값 예: ''개인(경제적)사유''·''장기미납''·''신규미납''·''다른곳지원''·''기타''·''명의변경''·''아동퇴소''·''회원항의''·''일시후원이었음''·''만18세아동퇴소''·''이중가입''·''사업장종결''·''약정후원''·''기업후원종료''·''은행자동납부해지''·''반송미납''. 🔴 **미중단 회원은 NULL** 이다 — 이 축으로 그루핑하면 미중단 회원이 NULL 한 덩어리로 모인다. 이탈자만 보려면 이탈 measure 와 함께 쓰거나 NULL 을 제외한다',
    fmc.IS_12M_OBSERVABLE   AS fmc.IS_12M_OBSERVABLE WITH SYNONYMS ('12개월 관측가능', '관측가능 여부') COMMENT = '획득 후 12개월이 데이터 최종 사건일 안에 들어오는가(TRUE/FALSE). 🔴 **12개월 이탈률의 분모 자격**이다. 최근 획득 회원은 아직 12개월이 지나지 않아 FALSE 이며, 이들을 분모에 넣으면 최근 캠페인의 이탈률이 실제보다 낮게 보인다',
    -- ── 획득(모집) 캠페인 축 ────────────────────────────────────────────────────
    --   🔴 이 SV 에서 캠페인은 전부 **획득 캠페인**이다(중단 시점 캠페인이 아니다).
    --      중단률의 분모(획득 회원)와 같은 축이라 비율이 성립한다 — 이것이 O37 의 핵심이다.
    --   ✅ `PROMO_METHOD_NAME`(홍보방법 라벨, CM008) 2026-08-05 적재 확인 후 활성화.
    --   [DEC-43] 아래 8속성은 `acq_campaign`(`DIM_CAMPAIGN` 실시간 조인)이 아니라
    --     `fmc.ACQ_*`(SILVER CRM_MEMBER_DEV 적재 시점 동결값)에서 온다 — 캠페인 마스터가
    --     이후 정정돼도 과거 획득 회원의 캠페인 속성은 바뀌지 않는다(O99 설계부채 해소).
    acq_campaign.CAMPAIGN_NAME        AS acq_campaign.CAMPAIGN_NAME        WITH SYNONYMS ('캠페인', '캠페인명', '획득캠페인명', '모집캠페인') COMMENT = '회원을 처음 데려온 캠페인명. 🔴**획득 캠페인**이다 — 이 축으로 중단률을 비교하면 「그 캠페인으로 모집한 회원이 얼마나 이탈했는가」가 된다. 개별 캠페인은 카디널리티가 매우 높으니 규모가 작은 캠페인의 비율은 불안정하다 — 관측 가능 회원 하한을 걸 것. 🔴🔴 **[2026-08-26 O102] 이 축만 「현재 시점」이다** — 위·아래 캠페인 속성 8종(카테고리·브랜드·상위캠페인·홍보방법·모집채널·국내해외·사업사례·마케팅캠페인)은 **획득 시점 동결값**(`fmc.ACQ_*` · DEC-43)인데 이 캠페인명만 `DIM_CAMPAIGN` **실시간 조인**이다(DEC-43 12속성 범위 밖 = 캠페인 자신의 이름이라 의도적 존치). ⇒ 캠페인이 나중에 개칭되면 **이름은 최신이고 분류는 과거**인 조합이 나올 수 있다. 🔴 이름과 분류를 같은 시점으로 단정해 답하지 말 것. 획득 시점 동결로 확장할지는 현업 확인 중이다(`20_현업확인_요청.md` N-9)',
    fmc.CAMPAIGN_TYPE        AS fmc.ACQ_CMPGN_CTGR_NM        WITH SYNONYMS ('캠페인카테고리', '캠페인유형', '주요캠페인', '캠페인 종류', '캠페인 분류') COMMENT = '캠페인 카테고리(정본 MM294 라벨) — 현업이 말하는 **''주요캠페인''** 축이다. 🔴적재 시점 동결값(구 acq_campaign.CAMPAIGN_TYPE 대체). 실제값 예: ''초등캠페인''·''국내사례캠페인''·''굿즈캠페인''·''해외캠페인''·''기타 영상광고''·''홈페이지(PC/모바일)''·''국내여아지원캠페인''·''그외 지역개발캠페인''·''희망TV''·''인바운드''·''대학생캠페인''·''가두캠페인''·''유아캠페인''·''청소년캠페인''·''교회캠페인''·''기존회원캠페인 및 기타''. 🔴 캠페인별 중단률 비교의 **1순위 축**이다(개별 캠페인명보다 표본이 안정적이다)',
    fmc.CAMPAIGN_BRAND       AS fmc.ACQ_BRAND                WITH SYNONYMS ('브랜드', '캠페인 브랜드') COMMENT = '획득 캠페인의 브랜드. 🔴적재 시점 동결값(구 acq_campaign.BRAND 대체)',
    fmc.PARENT_CAMPAIGN_NAME AS fmc.ACQ_PARENT_CAMPAIGN_NAME WITH SYNONYMS ('상위캠페인', '상위캠페인명', '캠페인 그룹') COMMENT = '획득 캠페인의 **상위캠페인명**(2026-08-05 O37 신설 — 종전에는 자기참조 코드만 있어 사람이 읽을 수 없었다). 🔴적재 시점 동결값(구 acq_campaign.PARENT_CAMPAIGN_NAME 대체). 캠페인을 묶어 보는 축이다. ⚠️ 상위가 없는 캠페인은 NULL 이며 ''(미매핑)''이 아니다. ⚠️ 캠페인 카테고리(CAMPAIGN_TYPE)와 다른 축이다',
    fmc.PROMO_METHOD_NAME    AS fmc.ACQ_PROMO_METHOD_NAME    WITH SYNONYMS ('홍보방법', '광고방법', '매체', '홍보수단') COMMENT = '획득 캠페인의 **홍보방법** 라벨(코드사전 CM008, 2026-08-05 O37 신설). 🔴적재 시점 동결값(구 acq_campaign.PROMO_METHOD_NAME 대체). 실제값 계열: ''PC배너광고(DA)''·''M배너광고(DA)''·''PC검색광고(SA)''·''M검색광고(SA)''·''TM''·''TS''·''PC캠페인-홈페이지''·''M캠페인-홈페이지''·''PC캠페인-홍보''·''M캠페인-홍보''·''온라인''·''오프라인''·''APP캠페인''·''M모바일앱''·''M페이스북광고''·''기존회원메일''·''PC기업공동캠페인''·''M기업 공동캠페인''·''기타''. 🔴 원천 `PR_MTH_CD` 는 **숫자 코드**이며 종전에는 라벨이 없어 이 축을 쓸 수 없었다 — 코드로 필터하면 Analyst 가 0행을 반환한다. 반드시 이 라벨 컬럼으로 필터·그루핑한다. ⚠️ 원천 코드가 없는 캠페인은 NULL 이며 ''(미매핑)''이 아니다. ⚠️ 모집 채널(CAMPAIGN_INFLOW_PATH)과 다른 축이다 — 이쪽은 광고·접촉 수단, 그쪽은 개발인입경로다',
    fmc.CAMPAIGN_INFLOW_PATH AS fmc.ACQ_MBER_INFLOW_PATH_NM   WITH SYNONYMS ('모집채널', '유입경로', '개발인입경로') COMMENT = '획득 캠페인의 **모집 채널**(정본 MM293 라벨). 🔴적재 시점 동결값(구 acq_campaign.INFLOW_PATH 대체). 실제값 16종: ''디지털''·''회원 온라인개발''·''지역개발''·''영상광고''·''방송''·''교육기관''·''회원 콜개발''·''일시''·''기업''·''회원 기타''·''뉴미디어''·''재송출''·''마케팅콜개발''·''회원 오프라인개발''·''대면모금''·''직원개발''. ⚠️ 이 축은 채널이며 「주요캠페인」이 아니다 — 주요캠페인은 CAMPAIGN_TYPE 이다(2026-08-05 O37 에서 종전 오표기 회수). ⚠️ 회원 가입경로(회원 속성)와도 다른 축이다',
    fmc.DOMESTIC_OVERSEAS    AS fmc.ACQ_CMPGN_TYPE1_NM       WITH SYNONYMS ('국내해외', '국내외') COMMENT = '획득 캠페인의 국내/해외 구분(MM295). 🔴적재 시점 동결값(구 acq_campaign.DOMESTIC_OVERSEAS 대체). 실제값 3종: ''국내''·''해외''·''통합''',
    fmc.BIZ_CASE_TYPE        AS fmc.ACQ_CMPGN_TYPE2_NM       WITH SYNONYMS ('사업사례구분', '사업/사례') COMMENT = '획득 캠페인의 사업/사례 구분(MM296). 🔴적재 시점 동결값(구 acq_campaign.BIZ_CASE_TYPE 대체). 실제값 4종: ''사례''·''사업''·''굿즈''·''기타''',
    fmc.MARKETING_CAMPAIGN   AS fmc.ACQ_MKTG_CMPGN_NM        WITH SYNONYMS ('마케팅캠페인', '마케팅 캠페인명') COMMENT = '획득 캠페인의 마케팅캠페인명. 🔴적재 시점 동결값(구 acq_campaign.MARKETING_CAMPAIGN 대체). 실제값 예: ''24년 이전컨텐츠''·''그외 지역개발캠페인''·''유어턴(통합A)''·''유어턴(통합B)''·''기존회원캠페인 및 기타''·''25년 이전컨텐츠(영상광고)''·''TS/TM''. 카디널리티가 높다',
    -- ── [2026-08-06 O45] 획득 조직·후원사업 축 (종전 「비활성」 서술 회수) ──────────
    acq_org.ACQ_DEPARTMENT            AS acq_org.DEPARTMENT                WITH SYNONYMS ('획득부서', '가입부서', '모집부서', '획득 시점 부서') COMMENT = '🔴**획득(최초 약정) 시점의 실적부서명**(정본 #116). 개발실적보고의 「부서」와 **다른 축**이다 — 그쪽은 **사건 부서**(SV_MEMBER_EVENT.ORG_DEPARTMENT)이며 회원이 이후 다른 부서 실적으로 잡혀도 이 축은 변하지 않는다. ⚠️ 상위 조직(본부/지부·팀·법인)은 산출 불가(CONF-4) — 부서명에서 상위 조직을 추측하지 말 것. ⚠️ 획득 사건의 부서를 알 수 없는 회원은 ''(미매핑)''이다',
    acq_sponsorship.ACQ_SPONSORSHIP   AS acq_sponsorship.SPONSORSHIP_NAME  WITH SYNONYMS ('획득 후원사업', '가입 후원사업', '모집 후원사업', '후원사업(획득)') COMMENT = '🔴**획득 시점 후원사업명** — 그 회원을 데려온 사업이다(정본 #123). ⚠️ **회비를 낸 후원사업이 아니다**: 납입 대상 후원사업은 `SV_MEMBER_FEE` 의 SPONSORSHIP_NAME 이며, 한 회원이 여러 후원사업에 내므로 두 축의 값은 다르다. 회원 특성·이탈률 분석에는 이 축이 맞고, 회비 금액 분해에는 SV_MEMBER_FEE 가 맞다. ⚠️ 미매칭은 ''(미매핑)'''
  )
  METRICS (
    -- ── 규모 ──────────────────────────────────────────────────────────────────
    -- 🔴 metric 명은 원본 컬럼명과 **달라야 한다** — 같으면 metric 식 안의 `SUM(fmc.<이름>)` 이
    --   컬럼이 아니라 metric(이미 집계값)으로 해석돼 `Invalid metric definition` 으로 컴파일 실패한다
    --   (2026-08-05 실측: 초판이 metric 을 컬럼과 동명으로 선언해 실패). → TOTAL_ 접두로 분리한다.
    fmc.TOTAL_ACQ_MEMBERS AS SUM(fmc.ACQ_MEMBERS)
      WITH SYNONYMS ('획득회원수', '모집회원수', '신규회원수') COMMENT = '획득 회원수. D(회원 grain이라 SUM 이 곧 distinct 회원수 — 이 팩트는 회원당 1행이므로 다기간 중복이 없다). 캠페인별 모집 규모.',
    -- ── 🔴 중단률(정본) ────────────────────────────────────────────────────────
    -- 🔴 [2026-08-10 O52-A] 단위를 **percent 로 통일**했다(`×100` 부여). 종전에는 분수(0~1)였고
    --   프로젝트의 다른 비율 metric 은 전부 percent 였다(CTR·CVR·납부율·미납비중·집행율·달성율).
    --   Agent instruction 이 「비율=% 2자리」이고 orchestration 이 「중단률/이탈률 → analyst_member_cohort」로
    --   명시 라우팅하므로 **에러 없이 "0.20%" 라고 답하는 활성 경로**였다(정답 20.05% · AD-4/P19 무증상 오답).
    --   ⚠️ 아래 §검증 쿼리의 `* 100` 도 함께 제거했다 — 남겨두면 **10000배**가 된다(산식과 쿼리 이중 곱).
    fmc.CHURN_RATE_12M AS SUM(fmc.STOPPED_12M_MEMBERS) / NULLIF(SUM(fmc.OBSERVABLE_12M_MEMBERS), 0) * 100
      WITH SYNONYMS ('중단률', '이탈률', '12개월 이탈률', '12개월 중단률', '해지율', '이탈율')
      COMMENT = '🔴**캠페인별 중단률의 정본(단위 %)** = 획득 후 12개월 내 이탈 회원수 ÷ 12개월 관측 가능 회원수 ×100. 비율(N) — 재집계 금지, 분자·분모를 각각 집계한 뒤 나눈다. **왜 12개월 고정인가**: 누적 이탈률은 관측 기간에 지배되어(획득이 이를수록 높다) 실행 연도가 다른 캠페인을 비교하면 오래된 캠페인이 자동으로 「중단률 높음」이 된다 — 값이 정상인데 답이 틀리는 결함이다. 12개월로 고정하면 캠페인 간 공정 비교가 된다. 분모는 IS_12M_OBSERVABLE=TRUE 회원으로 자동 제한된다. 🔴[O52-A] 단위는 **퍼센트**다 — 값을 다시 ×100 하지 말 것(종전 분수 시절의 쿼리를 재사용하면 100배 과대해진다).',
    fmc.TOTAL_STOPPED_12M_MEMBERS AS SUM(fmc.STOPPED_12M_MEMBERS)
      WITH SYNONYMS ('12개월 이탈회원수', '12개월 중단회원수') COMMENT = '획득 후 12개월 내 이탈한 회원수(분자). F(가산). 🔴 관측 가능 회원에 한해서만 1 로 집계된다 — 분모는 반드시 TOTAL_OBSERVABLE_12M_MEMBERS 를 쓴다. TOTAL_ACQ_MEMBERS 로 나누면 과소추정된다.',
    fmc.TOTAL_OBSERVABLE_12M_MEMBERS AS SUM(fmc.OBSERVABLE_12M_MEMBERS)
      WITH SYNONYMS ('12개월 관측가능 회원수', '이탈률 분모') COMMENT = '12개월 이탈률의 **분모** 회원수. F(가산). 획득 후 12개월이 데이터 기간 안에 들어오는 회원만 센다.',
    -- ── 누적 이탈(비교용 금지 가드 포함) ─────────────────────────────────────────
    fmc.STOPPED_MEMBERS_EVER AS SUM(fmc.STOPPED_MEMBERS)
      WITH SYNONYMS ('누적 이탈회원수', '전체 이탈회원수') COMMENT = '관측 기간 전체에서 한 번이라도 이탈한 회원수. F(가산). ⚠️ 이 값을 TOTAL_ACQ_MEMBERS 로 나눈 **누적 이탈률로 캠페인을 비교하지 말 것** — 획득 시점이 이를수록 관측 기간이 길어 구조적으로 높게 나온다(실측 확인). 캠페인 비교는 CHURN_RATE_12M 을 쓴다. 이 measure 는 「전체 기간 누적 이탈 규모」를 물을 때만 쓴다.',
    -- ── 유지기간 ──────────────────────────────────────────────────────────────
    fmc.AVG_TENURE_DAYS AS AVG(fmc.TENURE_DAYS)
      WITH SYNONYMS ('평균 유지기간', '평균 유지일수', '평균 후원기간') COMMENT = '이탈 회원의 평균 유지기간(일) = 최초 중단일 − 획득일. N(비가산, 재집계 금지). 🔴 **이탈한 회원만** 모수다(미중단 회원은 유지기간이 NULL = 아직 끝나지 않은 관측이라 평균에서 제외된다). 따라서 이 값은 "이탈한 사람은 평균 며칠 유지했나"이며 **전체 회원의 평균 후원기간이 아니다** — 아직 유지 중인 회원이 많은 캠페인일수록 이 값만 보면 과소평가된다. 반드시 CHURN_RATE_12M 과 함께 해석한다.'
  )
  COMMENT = 'Phase-1 회원 획득 코호트 SV(base FMC, **회원 grain 1행=1회원**). 캠페인별 **중단률(이탈률)** · 유지기간 · 획득시점 회원특성의 정본. [원천 요약] 원천시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM(개발 TM_MM_FDRM_MBER_DVLP_AMT · 중단 TM_MM_FDRM_MBER_SPNSR_DSCNTC) → SILVER(CRM_MEMBER_DEV+CRM_MEMBER_DISCONTINUE) → GOLD(FACT_MEMBER_EVENT→FACT_MEMBER_COHORT). 테이블별 상세 원천은 각 테이블 COMMENT 의 [원천] 절 참조. 활성: 획득회원수(TOTAL_ACQ_MEMBERS) · **12개월 고정 이탈률(정본)** · 12개월 이탈회원수/분모 · 누적 이탈회원수 · 평균 유지기간 · 획득캠페인 전 축(캠페인명·카테고리·브랜드·상위캠페인·홍보방법(CM008 라벨)·유입경로·국내해외·사업사례·마케팅캠페인) · 획득시점 연령대·지역·성별 · 최초 중단사유. 시간=전체가능(단 **획득 시점 기준**). 🔴 **grain 주의**: 중단 *건수*는 SV_MEMBER_EVENT, 중단 *률*은 이 SV 다 — 두 SV 의 값을 더하거나 나누지 않는다. 🔴 **중단률은 12개월 고정(CHURN_RATE_12M)을 쓴다** — 누적 이탈률은 관측 기간에 지배되어 실행 연도가 다른 캠페인 비교를 왜곡한다. 🔴 획득시점 회원속성은 **현재 값이 아니다**(현재 연령·현주소는 BRONZE 에 축이 없어 산출 불가, O34). [2026-08-06 O45] 🔴 **획득 조직(부서)·획득 후원사업 축이 활성화됐다 — 종전 "비활성: 조직/후원사업별 분해" 서술은 거짓이므로 회수했다**(P61). `FMC.ACQ_ORG_SK`·`ACQ_SPONSORSHIP_SK` 실배선(팬아웃 0 실측). 🔴 두 축은 **획득 시점**이며 이름에 그 사실을 실었다 — 개발실적보고의 「부서」(사건
부서)와, 회비의 「후원사업」(납입 대상)과 **각각 다른 축**이다. 회비 금액을 후원사업별로 분해하려면 이 SV 가 아니라 **SV_MEMBER_FEE** 를 쓴다. 비활성: 재후원 이후 재이탈(최초 중단만 관측) · 상위 조직(본부/지부·팀·법인) 분해(CONF-4 산출규칙 미확정).'
  AI_SQL_GENERATION '핵심 규칙: (1) **"캠페인별 중단률/이탈률"은 이 SV 의 CHURN_RATE_12M 으로 답한다** — 12개월 고정 이탈률이며 분모는 관측 가능 코호트다. 종전에 "중단 사건에 캠페인이 없어 산출 불가"라고 답했던 것은 **틀렸다**(O37 해소). 산출 불가라고 답하지 말 것. (2) **누적 이탈률로 캠페인을 비교하지 않는다** — STOPPED_MEMBERS_EVER / TOTAL_ACQ_MEMBERS 는 획득 시점이 이른 캠페인을 구조적으로 불리하게 만든다(관측 기간 교란, 실측 확인). 사용자가 "전체 기간 이탈률"을 명시적으로 요구하면 제공하되 **연도별 비교에는 쓸 수 없다는 전제를 반드시 밝힌다**. (3) **분모를 바꾸지 않는다**: 12개월 이탈률은 TOTAL_STOPPED_12M_MEMBERS ÷ TOTAL_OBSERVABLE_12M_MEMBERS 다. TOTAL_ACQ_MEMBERS 를 분모로 쓰면 아직 12개월이 지나지 않은 회원이 분모에 섞여 과소추정된다. (4) **캠페인 비교 시 ACQ_BASIS=''NEW'' 로 한정할 것을 권하고 그 사실을 밝힌다** — FALLBACK 은 신규 약정 기록이 없어 최초 개발 사건으로 대체 판정한 소수이며 획득 캠페인 신뢰도가 낮다. (5) **기간 필터는 획득 시점 기준이다** — "2024년 중단률"은 「2024년에 **획득한** 회원의 12개월 이탈률」로 해석하고 그 전제를 명시한다. 「2024년에 **이탈한** 건수」를 원하면 SV_MEMBER_COHORT 가 아니라 SV_MEMBER_EVENT 의 중단건을 써야 한다고 안내한다. (6) **grain 혼용 금지**: 이 SV 는 회원 1행이므로 사건 건수를 세지 않는다. 중단 건수·개발 건수는 SV_MEMBER_EVENT 다. 두 SV 의 수치를 더하거나 나누지 않는다. (7) **획득시점 속성은 현재 값이 아니다**: ACQ_AGE_BAND·ACQ_REGION·ACQ_GENDER 는 최초
약정 당시 값이다. "현재 연령대별/거주지역별" 질문에는 산출 불가를 밝히고(BRONZE 에 생년월일·현주소 축 없음) 획득 시점 기준으로 답하되 전제를 명시한다. ACQ_GENDER 는 CM013 체계라 다른 SV 의 성별(CM017)과 코드체계가 다르다. (8) **평균 유지기간은 이탈자만의 평균이다** — 미중단 회원은 관측이 끝나지 않아 제외된다. 캠페인 비교 시 이 값만으로 "오래 유지된다"고 결론하지 말고 CHURN_RATE_12M 과 함께 제시한다. (9) 적용 조건(기간·그룹 모두 미지정 시): 전체 코호트를 대상으로 CHURN_RATE_12M 상위/하위를 함께 보여주고, **모집 규모가 작은 캠페인은 비율이 불안정하므로 TOTAL_ACQ_MEMBERS 하한(예: 관측 가능 회원 1,000명 이상)을 적용했음을 밝힌다**. (10) metric 정렬에는 `NULLS LAST` 를 명시한다 — 관측 가능 회원이 없어 비율이 NULL 인 캠페인이 상위를 점유하는 것을 막는다(04 §6.9-(7)). (11) **「부서」·「후원사업」은 반드시 어느 축인지 밝힌다**(O45): 이 SV 의 ACQ_DEPARTMENT·ACQ_SPONSORSHIP 은 **획득 시점** 축이다. 사용자가 「부서별 개발실적」을 물으면 이 SV 가 아니라 SV_MEMBER_EVENT(사건 부서)로 라우팅하고, 「후원사업별 회비·미납」을 물으면 **SV_MEMBER_FEE**(납입 대상 후원사업)로 라우팅한다. 🔴 같은 라벨이 두 축이므로 어느 축으로 답했는지 답변에 명시한다 — 밝히지 않으면 값이 맞아도 사용자가 틀린 결론을 얻는다(P76). (12) 🔴 **이 SV 와 SV_MEMBER_FEE 의 수치를 한 표에 합치지 않는다** — grain 이 회원 1행 vs 회비 상세 행이다.';


/* =====================================================================================
   GRANT — Cortex Analyst 소비 권한 (docs: REFERENCES, SELECT 필요 · USAGE 아님)
      ANALYST 가 VIEWER 를 상속하나 명확성을 위해 3역할 모두 명시(02 §E 패턴).
      🟢 [2026-08-12 O61 · R1-3 전량독해에서 적발·교정] 이 파일 본문은 `CREATE OR ALTER` 다(line 65) ⇒
         **GRANT 는 파괴되지 않으므로 아래는 멱등 재확인**이다. 🔴 종전 이 자리의
         *"`CREATE OR REPLACE` 는 기존 GRANT 를 전부 삭제한다 → 재실행 시 반드시 함께 실행"* 은
         **폐기된 규약을 인용한 stale 주석**이었고 같은 파일 헤더(line 7 OWN-1 해소)와 모순됐다.
         ⛔ 단 `CREATE OR REPLACE` 로 **되돌리지는 말 것** — 그러면 GRANT 파괴 + owner 리셋이 재발한다(P125).
   ===================================================================================== */
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_COHORT TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_COHORT TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_COHORT TO ROLE GN_DW_SERVICE;


/* =====================================================================================
   스모크 검증 (배포 직후 실행)
      🔴 판정은 **절대값이 아니라 불변식**으로 한다(04 §6.9-(8)).
      ▶ SV 9종 전체를 아우르는 배포 검증 = `05_0_SV_DDL.sql`
   ===================================================================================== */
USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- (C-1) fan-out 0: SV 획득회원수 == 팩트 직접 COUNT (회원 grain 이라 정확히 일치해야 한다)
SELECT (SELECT TOTAL_ACQ_MEMBERS FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_COHORT METRICS TOTAL_ACQ_MEMBERS)) AS sv_val,
       (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_MEMBER_COHORT) AS fact_val;
--   판정: sv_val == fact_val (불일치 = 차원 조인 fan-out)

-- (C-2) 🔴 이탈률 상한 불변식: 어떤 캠페인 카테고리에서도 12개월 이탈률이 100% 를 넘지 않는다.
--       종전 「사건 기준」 산식이 100% 를 넘겼던 지점이며 이 SV 의 설계 목적 자체다.
--       🔴 [O52-A] 단위가 percent 로 바뀌었으므로 판정 상한도 1.0 → 100 으로 고쳤다.
SELECT MAX(CHURN_RATE_12M) AS max_rate
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_MEMBER_COHORT
  DIMENSIONS fmc.CAMPAIGN_TYPE
  METRICS CHURN_RATE_12M
);
--   판정: max_rate <= 100

-- (C-3) 본래 목표 재현: 캠페인 카테고리별 12개월 중단률 상위/하위 비교
--       (모집 규모 하한을 걸어 소표본 노이즈를 배제 — AI_SQL_GENERATION 규칙(9)와 동일 원칙)
--       🔴 [O52-A] metric 이 이미 percent 다 — 종전의 `* 100` 을 제거했다(남기면 10000배).
SELECT CAMPAIGN_TYPE, TOTAL_ACQ_MEMBERS, TOTAL_OBSERVABLE_12M_MEMBERS, TOTAL_STOPPED_12M_MEMBERS,
       ROUND(CHURN_RATE_12M, 2) AS CHURN_12M_PCT
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_MEMBER_COHORT
  DIMENSIONS fmc.CAMPAIGN_TYPE
  METRICS TOTAL_ACQ_MEMBERS, TOTAL_OBSERVABLE_12M_MEMBERS, TOTAL_STOPPED_12M_MEMBERS, CHURN_RATE_12M
)
WHERE TOTAL_OBSERVABLE_12M_MEMBERS >= 5000
ORDER BY CHURN_12M_PCT DESC NULLS LAST;
--   판정: 상위·하위 스프레드가 유의미하게 벌어지고 전 행 <= 100
--   ⚠ FILTER 절에 별칭 컬럼을 쓸 수 없어 바깥 WHERE 로 거른다(04 §6.9-(6))

-- (C-4) 획득시점 회원특성 × 캠페인 교차 (O35 계열 검증 — 한 SV 안에서 성립하는지)
--       🔴 [O52-A] `* 100` 제거(metric 이 percent).
SELECT ACQ_AGE_BAND, TOTAL_ACQ_MEMBERS, ROUND(CHURN_RATE_12M, 2) AS CHURN_12M_PCT
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_MEMBER_COHORT
  DIMENSIONS fmc.ACQ_AGE_BAND
  METRICS TOTAL_ACQ_MEMBERS, CHURN_RATE_12M
)
ORDER BY TOTAL_ACQ_MEMBERS DESC NULLS LAST;

-- (C-5) 이탈 사유 분해 (미중단 NULL 이 한 덩어리로 나오는지 = COMMENT 경고의 실증)
SELECT FIRST_STOP_REASON, TOTAL_ACQ_MEMBERS
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_MEMBER_COHORT
  DIMENSIONS fmc.FIRST_STOP_REASON
  METRICS TOTAL_ACQ_MEMBERS
)
ORDER BY TOTAL_ACQ_MEMBERS DESC NULLS LAST;
--   판정: NULL 행이 미중단 회원 규모로 존재해야 정상(오류 아님)
