-- ============================================================================
-- 05_3_SV_DDL_MEMBER_COHORT.sql — Semantic View DDL 정본: SV_MEMBER_COHORT
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능(파일 간 순서 없음).
--   · 🔴 SV 의 규칙·주의는 SV COMMENT · AI_SQL_GENERATION 안에 있다(Agent 가 읽는 곳) — 이 주석에 두지 않는다.
--   · 공통 규약 = 05_0_SV_DDL.sql · 설계·실측 이력 = 05_SV_DDL_설계이력_부록.md
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_COHORT
  TABLES (
    fmc AS GN_DW.GOLD.FACT_MEMBER_COHORT
      PRIMARY KEY (MEMBER_DK)
      WITH SYNONYMS ('회원 코호트', '획득 코호트', '회원 이탈', '중단률')
      COMMENT = '회원 획득 코호트 및 캠페인별 12개월 고정 이탈률 분석 (base: GOLD.FACT_MEMBER_COHORT). [Grain: MEMBER_DK (1행=1회원)]. [활성 지표: 12개월 이탈률/유지기간/코호트]. [주의: 개발이력 보유 회원 한정(미보유 중단회원은 SV_MEMBER_EVENT 사용)]. [원천: GOLD.FACT_MEMBER_EVENT → FACT_MEMBER_COHORT].',
    acq_campaign AS GN_DW.GOLD.DIM_CAMPAIGN
      PRIMARY KEY (CAMPAIGN_SK)
      WITH SYNONYMS ('획득캠페인', '모집캠페인', '캠페인')
      COMMENT = '회원을 처음 데려온 캠페인. PK 유일이라 조인이 행수를 늘리지 않는다. 🔴 이 SV 에서 캠페인은 **획득(모집) 캠페인**이며 「중단 시점 캠페인」이 아니다 — 중단률의 분모(획득 회원)와 같은 축이어야 비율이 성립한다. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: TM_CM_CMPGN_MNG · SILVER=CRM_CAMPAIGN.',
    acq_date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('획득일', '약정일', '가입일자')
      COMMENT = '획득(최초 약정)일 차원. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.',
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
    acq_date.ACQ_DATE       AS acq_date.FULL_DATE  WITH SYNONYMS ('획득일', '약정일', '모집일', 'FULL_DATE', '날짜') COMMENT = '회원을 획득한 날(최초 신규 약정일). 🔴 이 SV 의 기간 필터는 **획득 시점** 기준이다 — "2024년"으로 물으면 「2024년에 획득한 회원의 이탈률」이 되며 「2024년에 이탈한 회원」이 아니다. 후자는 SV_MEMBER_EVENT 의 중단건을 쓴다',
    acq_date.ACQ_YEAR       AS acq_date.YEAR       WITH SYNONYMS ('획득연도', '가입연도', '모집연도') COMMENT = '획득 연도(코호트 연도)',
    acq_date.ACQ_MONTH      AS acq_date.MONTH      WITH SYNONYMS ('획득월') COMMENT = '획득 월(1~12)',
    fmc.ACQ_BASIS           AS fmc.ACQ_BASIS       WITH SYNONYMS ('획득근거', '코호트 판정근거') COMMENT = '획득 캠페인을 무엇으로 판정했는지. 실제값 2종: ''NEW''(개발구분 신규=MM015 코드1 사건으로 판정 — 대다수) / ''FALLBACK''(신규 사건이 없어 최초 개발 사건으로 대체 판정). 🔴 캠페인별 중단률을 비교할 때는 ''NEW'' 로 한정할 것을 권한다 — FALLBACK 은 획득 캠페인 신뢰도가 낮고, 극소수는 획득 근거가 ''후원중단''(코드5) 기록이라 「모집 캠페인」이라 부를 수 없다',
    fmc.ACQ_DVLP_DIV_CD     AS fmc.ACQ_DVLP_DIV_CD WITH SYNONYMS ('획득사건 개발구분코드') COMMENT = '획득으로 판정한 사건의 개발구분 원천코드(MM015). 실제값 5종 ''1''(신규)·''2''(증액)·''3''(감액)·''4''(재후원)·''5''(후원중단). ACQ_BASIS=''NEW'' 이면 항상 ''1'' 이고, ''2''~''5''는 전부 FALLBACK 이다',
    fmc.ACQ_AGE_BAND        AS fmc.ACQ_AGE_BAND    WITH SYNONYMS ('연령대', '나이대', '획득시점 연령대', '약정시점 연령대') COMMENT = '🔴**획득(최초 약정) 당시의** 회원 연령대 — **현재 나이가 아니다**. 코드사전 CM014. 실제값 12종: ''10대 미만''·''10대''·''20대''·''30대''·''40대''·''50대''·''60대''·''70대''·''70대 이상''·''단체''·''기업''·''기타''. ✅ ''10대 미만''이 상위인 것은 **데이터 오류가 아니다** — **편지쓰기대회 계열 캠페인**(희망편지쓰기대회·가족그림편지쓰기대회·세계시민교육편지)이 학교·부모 DB 를 통해 **아동 본인 명의로 약정을 맺는 모집 이벤트**이기 때문이다. 이 SV 에서 캠페인 축과 교차하면 그 편중을 직접 수치로 확인할 수 있다. 결측·기본값 오염으로 설명하지 말 것. ⚠️ 현재 연령은 BRONZE 에 생년월일 축이 없어 **산출 불가**(O34)',
    fmc.ACQ_AGE_CD          AS fmc.ACQ_AGE_CD      WITH SYNONYMS ('연령대코드') COMMENT = '획득시점 연령대 원천코드(CM014 1=10대 미만 2=10대 3=20대 4=30대 5=40대 6=50대 7=60대 8=70대 9=70대 이상 10=단체 11=기업 12=기타). 🔴 연속형 나이가 아니므로 평균·구간 재계산 금지. 라벨은 ACQ_AGE_BAND',
    fmc.ACQ_REGION          AS fmc.ACQ_REGION      WITH SYNONYMS ('지역', '시도', '획득시점 지역', '약정시점 지역') COMMENT = '🔴**획득(최초 약정) 당시의** 회원 지역 라벨 — **현재 거주지가 아니다**. 정본 공#131 · 코드사전 CM018 약칭. 실제값 18종: ''서울''·''경기''·''인천''·''강원''·''대전''·''대구''·''부산''·''광주''·''울산''·''세종''·''충남''·''충북''·''전남''·''전북''·''경남''·''경북''·''제주''·''기타''. ⚠️ 센티넬 코드 ''0''은 사전에 라벨이 없어 NULL 이다 — ''미상''으로 창작하지 말 것. ⚠️ ''현재 거주지역별'' 질문에는 답할 수 없다(BRONZE 에 현주소 축 없음, O34)',
    fmc.ACQ_AREA_CD         AS fmc.ACQ_AREA_CD     WITH SYNONYMS ('지역코드') COMMENT = '획득시점 지역 원천코드(CM018 + 라벨 없는 센티넬 ''0''). 라벨은 ACQ_REGION. 실제값 19종: ''0''·''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''·''9''·''10''·''11''·''12''·''13''·''14''·''15''·''16''·''17''·''18'' + NULL',
    fmc.ACQ_GENDER          AS fmc.ACQ_GENDER      WITH SYNONYMS ('성별', '획득시점 성별') COMMENT = '획득시점 성별 라벨(코드사전 CM013). 실제값 8종: ''국내(남자)''·''국내(여자)''·''외국인(남자)''·''외국인(여자)''·''외국인(기타)''·''단체''·''기업''·''기타''. ⚠️ SV_MEMBER_EVENT·SV_MEMBER_MONTHLY 의 회원 성별(GENDER_NAME, CM017 라벨: 남자·여자·기업·단체·기타)과 **코드체계가 다르다** — 두 축을 같은 성별로 합산하지 말 것. ⚠️ 센티넬 ''0''은 라벨이 없어 NULL',
    fmc.ACQ_SEX_CD          AS fmc.ACQ_SEX_CD      WITH SYNONYMS ('성별코드') COMMENT = '획득시점 성별 원천코드(CM013 1~8 + 라벨 없는 센티넬 ''0''). 라벨은 ACQ_GENDER. 실제값 9종: ''0''·''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''',
    fmc.FIRST_STOP_REASON   AS fmc.FIRST_STOP_REASON_NM WITH SYNONYMS ('중단사유', '이탈사유', '해지사유') COMMENT = '**최초 중단**의 사유 라벨(정본 MM005 단일 코드체계 — 혼입 없음). 실제값 예: ''개인(경제적)사유''·''장기미납''·''신규미납''·''다른곳지원''·''기타''·''명의변경''·''아동퇴소''·''회원항의''·''일시후원이었음''·''만18세아동퇴소''·''이중가입''·''사업장종결''·''약정후원''·''기업후원종료''·''은행자동납부해지''·''반송미납''. 🔴 **미중단 회원은 NULL** 이다 — 이 축으로 그루핑하면 미중단 회원이 NULL 한 덩어리로 모인다. 이탈자만 보려면 이탈 measure 와 함께 쓰거나 NULL 을 제외한다',
    fmc.IS_12M_OBSERVABLE   AS fmc.IS_12M_OBSERVABLE WITH SYNONYMS ('12개월 관측가능', '관측가능 여부') COMMENT = '획득 후 12개월이 데이터 최종 사건일 안에 들어오는가(TRUE/FALSE). 🔴 **12개월 이탈률의 분모 자격**이다. 최근 획득 회원은 아직 12개월이 지나지 않아 FALSE 이며, 이들을 분모에 넣으면 최근 캠페인의 이탈률이 실제보다 낮게 보인다',
    acq_campaign.CAMPAIGN_NAME        AS acq_campaign.CAMPAIGN_NAME        WITH SYNONYMS ('캠페인', '캠페인명', '획득캠페인명', '모집캠페인') COMMENT = '회원을 처음 데려온 캠페인명. 🔴**획득 캠페인**이다 — 이 축으로 중단률을 비교하면 「그 캠페인으로 모집한 회원이 얼마나 이탈했는가」가 된다. 개별 캠페인은 카디널리티가 매우 높으니 규모가 작은 캠페인의 비율은 불안정하다 — 관측 가능 회원 하한을 걸 것. 🔴🔴 ** 이 축만 「현재 시점」이다** — 위·아래 캠페인 속성 8종(카테고리·브랜드·상위캠페인·홍보방법·모집채널·국내해외·사업사례·마케팅캠페인)은 **획득 시점 동결값**(`fmc.ACQ_*` · DEC-43)인데 이 캠페인명만 `DIM_CAMPAIGN` **실시간 조인**이다(DEC-43 12속성 범위 밖 = 캠페인 자신의 이름이라 의도적 존치). ⇒ 캠페인이 나중에 개칭되면 **이름은 최신이고 분류는 과거**인 조합이 나올 수 있다. 🔴 이름과 분류를 같은 시점으로 단정해 답하지 말 것. 획득 시점 동결로 확장할지는 현업 확인 중이다(`20_현업확인_요청.md` N-9)',
    fmc.CAMPAIGN_TYPE        AS fmc.ACQ_CMPGN_CTGR_NM        WITH SYNONYMS ('캠페인카테고리', '캠페인유형', '주요캠페인', '캠페인 종류', '캠페인 분류') COMMENT = '캠페인 카테고리(정본 MM294 라벨) — 현업이 말하는 **''주요캠페인''** 축이다. 🔴적재 시점 동결값(구 acq_campaign.CAMPAIGN_TYPE 대체). 실제값 예: ''초등캠페인''·''국내사례캠페인''·''굿즈캠페인''·''해외캠페인''·''기타 영상광고''·''홈페이지(PC/모바일)''·''국내여아지원캠페인''·''그외 지역개발캠페인''·''희망TV''·''인바운드''·''대학생캠페인''·''가두캠페인''·''유아캠페인''·''청소년캠페인''·''교회캠페인''·''기존회원캠페인 및 기타''. 🔴 캠페인별 중단률 비교의 **1순위 축**이다(개별 캠페인명보다 표본이 안정적이다)',
    fmc.CAMPAIGN_BRAND       AS fmc.ACQ_BRAND                WITH SYNONYMS ('브랜드', '캠페인 브랜드') COMMENT = '획득 캠페인의 브랜드. 🔴적재 시점 동결값(구 acq_campaign.BRAND 대체)',
    fmc.PARENT_CAMPAIGN_NAME AS fmc.ACQ_PARENT_CAMPAIGN_NAME WITH SYNONYMS ('상위캠페인', '상위캠페인명', '캠페인 그룹') COMMENT = '획득 캠페인의 **상위캠페인명**(2026-08-05 O37 신설 — 종전에는 자기참조 코드만 있어 사람이 읽을 수 없었다). 🔴적재 시점 동결값(구 acq_campaign.PARENT_CAMPAIGN_NAME 대체). 캠페인을 묶어 보는 축이다. ⚠️ 상위가 없는 캠페인은 NULL 이며 ''(미매핑)''이 아니다. ⚠️ 캠페인 카테고리(CAMPAIGN_TYPE)와 다른 축이다',
    fmc.PROMO_METHOD_NAME    AS fmc.ACQ_PROMO_METHOD_NAME    WITH SYNONYMS ('홍보방법', '광고방법', '매체', '홍보수단') COMMENT = '획득 캠페인의 **홍보방법** 라벨(코드사전 CM008, 2026-08-05 O37 신설). 🔴적재 시점 동결값(구 acq_campaign.PROMO_METHOD_NAME 대체). 실제값 계열: ''PC배너광고(DA)''·''M배너광고(DA)''·''PC검색광고(SA)''·''M검색광고(SA)''·''TM''·''TS''·''PC캠페인-홈페이지''·''M캠페인-홈페이지''·''PC캠페인-홍보''·''M캠페인-홍보''·''온라인''·''오프라인''·''APP캠페인''·''M모바일앱''·''M페이스북광고''·''기존회원메일''·''PC기업공동캠페인''·''M기업 공동캠페인''·''기타''. 🔴 원천 `PR_MTH_CD` 는 **숫자 코드**이며 종전에는 라벨이 없어 이 축을 쓸 수 없었다 — 코드로 필터하면 Analyst 가 0행을 반환한다. 반드시 이 라벨 컬럼으로 필터·그루핑한다. ⚠️ 원천 코드가 없는 캠페인은 NULL 이며 ''(미매핑)''이 아니다. ⚠️ 모집 채널(CAMPAIGN_INFLOW_PATH)과 다른 축이다 — 이쪽은 광고·접촉 수단, 그쪽은 개발인입경로다',
    fmc.CAMPAIGN_INFLOW_PATH AS fmc.ACQ_MBER_INFLOW_PATH_NM   WITH SYNONYMS ('모집채널', '유입경로', '개발인입경로') COMMENT = '획득 캠페인의 **모집 채널**(정본 MM293 라벨). 🔴적재 시점 동결값(구 acq_campaign.INFLOW_PATH 대체). 실제값 12종: ''교육기관''·''기타 기업개발''·''뉴미디어''·''대면모금''·''디지털''·''방송''·''영상광고''·''오프라인''·''일시''·''재송출''·''지역개발''·''콜개발'' + NULL. 🔴🔴 **아래 라벨은 이 데이터에 존재하지 않으므로 필터에 쓰면 0행이 반환된다**: ''회원 온라인개발''·''회원 콜개발''·''기업''·''회원 기타''·''마케팅콜개발''·''회원 오프라인개발''·''직원개발''. 원천 라벨이 개칭됐으므로 ''회원 콜개발''은 ''콜개발'', ''회원 오프라인개발''은 ''오프라인'', ''기업''은 ''기타 기업개발'' 로 읽는다. ⚠️ 이 축은 채널이며 「주요캠페인」이 아니다 — 주요캠페인은 CAMPAIGN_TYPE 이다(2026-08-05 O37 에서 종전 오표기 회수). ⚠️ 회원 가입경로(회원 속성)와도 다른 축이다',
    fmc.DOMESTIC_OVERSEAS    AS fmc.ACQ_CMPGN_TYPE1_NM       WITH SYNONYMS ('국내해외', '국내외') COMMENT = '획득 캠페인의 국내/해외 구분(MM295). 🔴적재 시점 동결값(구 acq_campaign.DOMESTIC_OVERSEAS 대체). 실제값 4종: ''국내''·''해외''·''통합''·''전체사업'' + NULL. ⚠️ ''통합''과 ''전체사업''은 서로 다른 값이다 — 하나로 묶지 말고 원천 라벨 그대로 노출한다',
    fmc.BIZ_CASE_TYPE        AS fmc.ACQ_CMPGN_TYPE2_NM       WITH SYNONYMS ('사업사례구분', '사업/사례') COMMENT = '획득 캠페인의 사업/사례 구분(MM296). 🔴적재 시점 동결값(구 acq_campaign.BIZ_CASE_TYPE 대체). 실제값 4종: ''사례''·''사업''·''굿즈''·''기타''',
    fmc.MARKETING_CAMPAIGN   AS fmc.ACQ_MKTG_CMPGN_NM        WITH SYNONYMS ('마케팅캠페인', '마케팅 캠페인명') COMMENT = '획득 캠페인의 마케팅캠페인명. 🔴적재 시점 동결값(구 acq_campaign.MARKETING_CAMPAIGN 대체). 실제값 예: ''24년 이전컨텐츠''·''그외 지역개발캠페인''·''유어턴(통합A)''·''유어턴(통합B)''·''기존회원캠페인 및 기타''·''25년 이전컨텐츠(영상광고)''·''TS/TM''. 카디널리티가 높다',
    acq_org.ACQ_DEPARTMENT            AS acq_org.DEPARTMENT                WITH SYNONYMS ('획득부서', '가입부서', '모집부서', '획득 시점 부서') COMMENT = '🔴**획득(최초 약정) 시점의 실적부서명**(정본 #116). 개발실적보고의 「부서」와 **다른 축**이다 — 그쪽은 **사건 부서**(SV_MEMBER_EVENT.ORG_DEPARTMENT)이며 회원이 이후 다른 부서 실적으로 잡혀도 이 축은 변하지 않는다. ⚠️ 본부/지부는 ACQ_ORG_DIV_GROUP·ACQ_ORG_DIV 를 쓴다 — 부서명에서 상위 조직을 추측하지 말 것(팀·법인은 산출 불가 · CONF-4). 🔴 폐지된 과거 실적부서는 옛 부서명 그대로 나온다(현재 부서로 연결하지 않는다 · DEC-56). ⚠️ 획득 사건의 부서를 알 수 없는 회원은 ''(미매핑)''이다',
    acq_org.ACQ_ORG_DIV_GROUP         AS acq_org.ACMSLT_DIV_GROUP_NM       WITH SYNONYMS ('획득 본부지부구분', '가입 조직구분') COMMENT = '획득 시점 실적 본부/지부 **구분**(ZB 노드 · DEC-56). 실제값 8종: ''본부''·''지부''·''시도본부''·''지부외''·''지부(사복)''·''본부(사복)''·''협력시설''·''시도본부 및 중앙'' + NULL. ⚠️ ''협력시설''·''지부외''는 시설·기타 묶음이다(본부/지부 조직이 아니다). 사건 시점 축(SV_MEMBER_EVENT.ORG_DIV_GROUP)과 다르다',
    acq_org.ACQ_ORG_DIV               AS acq_org.ACMSLT_DIV_NM             WITH SYNONYMS ('획득 본부', '획득 지부', '가입 본부지부', '모집 본부지부') COMMENT = '획득 시점 실적 본부/지부 **단위명**(ZC 노드 · DEC-56). 🔴🔴 같은 이름이 여러 구분에 있다(예: 서울) — 반드시 ACQ_ORG_DIV_GROUP 과 함께 그룹핑한다. 도달 못 한 부서는 NULL',
    acq_org.ACQ_ORG_DIV_GROUP_CODE    AS acq_org.ACMSLT_DIV_GROUP_ID       WITH SYNONYMS ('획득 본부지부구분코드') COMMENT = '획득 시점 실적 본부/지부 구분 부서코드(ZB 접두). 🔴 본부/지부를 보여줄 때 이름과 코드를 함께 표시한다(현업 회신 41.3)',
    acq_org.ACQ_ORG_DIV_CODE          AS acq_org.ACMSLT_DIV_ID             WITH SYNONYMS ('획득 본부지부코드', '획득 지부코드') COMMENT = '획득 시점 실적 본부/지부 단위 부서코드(ZC 접두). 🔴 이름이 같아도 코드가 다르면 다른 조직 — 합치지 말고 코드로 나눠 보여준다(현업 회신 41.3)',
    acq_sponsorship.ACQ_SPONSORSHIP   AS acq_sponsorship.SPONSORSHIP_NAME  WITH SYNONYMS ('획득 후원사업', '가입 후원사업', '모집 후원사업', '후원사업(획득)') COMMENT = '🔴**획득 시점 후원사업명** — 그 회원을 데려온 사업이다(정본 #123). ⚠️ **회비를 낸 후원사업이 아니다**: 납입 대상 후원사업은 `SV_MEMBER_FEE` 의 SPONSORSHIP_NAME 이며, 한 회원이 여러 후원사업에 내므로 두 축의 값은 다르다. 회원 특성·이탈률 분석에는 이 축이 맞고, 회비 금액 분해에는 SV_MEMBER_FEE 가 맞다. ⚠️ 미매칭은 ''(미매핑)''',
    acq_campaign.ACQ_MKTG_CHANNEL_NM AS acq_campaign.MKTG_CHANNEL_NM WITH SYNONYMS ('마케팅채널', '획득 마케팅채널') COMMENT = '🆕 [O213] 획득 캠페인의 마케팅채널(원천 COMMENT = 마케팅 채널명 · C002) — 캠페인 마스터 현재값. 🔴 값 「-」는 원천 코드사전 C002 에 등록된 코드 6 의 라벨이다(결측 아님 · 근거 = 문서20 N-29 머리 실측) — 「채널 미지정 캠페인」으로 읽되 업무 의미는 원천 확인 대상이며, 채널별 순위에서는 「-」를 따로 밝힌다.',
    acq_sponsorship.ACQ_SPONSORSHIP_GROUP4_NAME AS acq_sponsorship.SPONSORSHIP_GROUP4_NAME WITH SYNONYMS ('후원사업 4그룹', '후원사업그룹') COMMENT = '🆕 [O213] 획득 후원사업 4그룹(국내/결연/해외프로젝트/기타 · CM003 라벨 접기 · 규칙 밖 라벨은 NULL).'
  )
  METRICS (
    fmc.TOTAL_ACQ_MEMBERS AS SUM(fmc.ACQ_MEMBERS)
      WITH SYNONYMS ('획득회원수', '모집회원수', '신규회원수') COMMENT = '획득 회원수. D(회원 grain이라 SUM 이 곧 distinct 회원수 — 이 팩트는 회원당 1행이므로 다기간 중복이 없다). 캠페인별 모집 규모.',
    fmc.CHURN_RATE_12M AS SUM(fmc.STOPPED_12M_MEMBERS) / NULLIF(SUM(fmc.OBSERVABLE_12M_MEMBERS), 0) * 100
      WITH SYNONYMS ('중단률', '이탈률', '12개월 이탈률', '12개월 중단률', '해지율', '이탈율')
      COMMENT = '🔴**캠페인별 중단률의 정본(단위 %)** = 획득 후 12개월 내 이탈 회원수 ÷ 12개월 관측 가능 회원수 ×100. 비율(N) — 재집계 금지, 분자·분모를 각각 집계한 뒤 나눈다. **왜 12개월 고정인가**: 누적 이탈률은 관측 기간에 지배되어(획득이 이를수록 높다) 실행 연도가 다른 캠페인을 비교하면 오래된 캠페인이 자동으로 「중단률 높음」이 된다 — 값이 정상인데 답이 틀리는 결함이다. 12개월로 고정하면 캠페인 간 공정 비교가 된다. 분모는 IS_12M_OBSERVABLE=TRUE 회원으로 자동 제한된다. 🔴 단위는 **퍼센트**다 — 값을 다시 ×100 하지 말 것(종전 분수 시절의 쿼리를 재사용하면 100배 과대해진다).',
    fmc.TOTAL_STOPPED_12M_MEMBERS AS SUM(fmc.STOPPED_12M_MEMBERS)
      WITH SYNONYMS ('12개월 이탈회원수', '12개월 중단회원수') COMMENT = '획득 후 12개월 내 이탈한 회원수(분자). F(가산). 🔴 관측 가능 회원에 한해서만 1 로 집계된다 — 분모는 반드시 TOTAL_OBSERVABLE_12M_MEMBERS 를 쓴다. TOTAL_ACQ_MEMBERS 로 나누면 과소추정된다.',
    fmc.TOTAL_OBSERVABLE_12M_MEMBERS AS SUM(fmc.OBSERVABLE_12M_MEMBERS)
      WITH SYNONYMS ('12개월 관측가능 회원수', '이탈률 분모') COMMENT = '12개월 이탈률의 **분모** 회원수. F(가산). 획득 후 12개월이 데이터 기간 안에 들어오는 회원만 센다.',
    fmc.STOPPED_MEMBERS_EVER AS SUM(fmc.STOPPED_MEMBERS)
      WITH SYNONYMS ('누적 이탈회원수', '전체 이탈회원수') COMMENT = '관측 기간 전체에서 한 번이라도 이탈한 회원수. F(가산). ⚠️ 이 값을 TOTAL_ACQ_MEMBERS 로 나눈 **누적 이탈률로 캠페인을 비교하지 말 것** — 획득 시점이 이를수록 관측 기간이 길어 구조적으로 높게 나온다(실측 확인). 캠페인 비교는 CHURN_RATE_12M 을 쓴다. 이 measure 는 「전체 기간 누적 이탈 규모」를 물을 때만 쓴다.',
    fmc.AVG_TENURE_DAYS AS AVG(fmc.TENURE_DAYS)
      WITH SYNONYMS ('평균 유지기간', '평균 유지일수', '평균 후원기간') COMMENT = '이탈 회원의 평균 유지기간(일) = 최초 중단일 − 획득일. N(비가산, 재집계 금지). 🔴 **이탈한 회원만** 모수다(미중단 회원은 유지기간이 NULL = 아직 끝나지 않은 관측이라 평균에서 제외된다). 따라서 이 값은 "이탈한 사람은 평균 며칠 유지했나"이며 **전체 회원의 평균 후원기간이 아니다** — 아직 유지 중인 회원이 많은 캠페인일수록 이 값만 보면 과소평가된다. 반드시 CHURN_RATE_12M 과 함께 해석한다.'
  )
  COMMENT = 'Phase-1 회원 획득 코호트 SV (base: GOLD.FACT_MEMBER_COHORT, grain: 회원 1행=1회원). 캠페인별 12개월 고정 이탈률(CHURN_RATE_12M, % 단위), 평균 유지기간(AVG_TENURE_DAYS), 획득 시점 회원속성 뷰. ⚠️ 중단 건수는 SV_MEMBER_EVENT, 중단률(%)은 본 뷰가 정본. 캠페인 비교 시 누적 이탈률이 아닌 12개월 고정 이탈률 사용 필수. 획득 부서/후원사업은 획득 시점 축임.'
  AI_SQL_GENERATION '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 이탈률 정본: 캠페인별 중단률/이탈률 질문은 CHURN_RATE_12M (% 단위) 사용. 누적 이탈률(STOPPED_MEMBERS_EVER/TOTAL_ACQ_MEMBERS)은 기간 편향이 발생하므로 캠페인 비교에 사용 금지. (2) 기간 필터: 연도/월 필터는 획득 시점 기준임. (3) 건수 vs 비율 분기: 중단 건수 질의는 SV_MEMBER_EVENT 로 라우팅. (4) 유지기간: AVG_TENURE_DAYS 는 이탈 회원만의 평균 유지일수이며 CHURN_RATE_12M 과 함께 제시. (5) 정렬: 비율 metric 정렬 시 ORDER BY ... DESC NULLS LAST 사용. (6) 획득 속성: ACQ_DEPARTMENT, ACQ_SPONSORSHIP 은 획득 시점 속성이며 납입 대상 회비는 SV_MEMBER_FEE 로 라우팅. ORDER BY 에는 SELECT 에서 정의한 별칭을 글자 그대로 쓴다(별칭 일부만 쓰면 invalid identifier). 「총납입회비」처럼 이 SV 에 없는 지표로 정렬·결합을 요구받으면 이 SV 에서 억지로 만들지 말고 SV_MEMBER_FEE 를 따로 호출해 표를 분리한다. 「최근 N개월」 기준일은 비상관 CTE 1개로 구하고 CROSS JOIN 한다.'
  AI_VERIFIED_QUERIES (
    vqr_o191_campaign_churn_top10 AS (
      QUESTION '캠페인별 평균 유지기간과 12개월 이탈률 상위 10곳'
      VERIFIED_BY '(DW = O191)'
      SQL 'SELECT acq_campaign.CAMPAIGN_NAME, SUM(fmc.ACQ_MEMBERS) AS TOTAL_ACQ_MEMBERS, AVG(fmc.TENURE_DAYS) AS AVG_TENURE_DAYS, SUM(fmc.STOPPED_12M_MEMBERS) / NULLIF(SUM(fmc.OBSERVABLE_12M_MEMBERS), 0) * 100 AS CHURN_RATE_12M FROM fmc LEFT JOIN acq_campaign ON fmc.ACQ_CAMPAIGN_SK = acq_campaign.CAMPAIGN_SK WHERE fmc.ACQ_BASIS = ''NEW'' GROUP BY acq_campaign.CAMPAIGN_NAME HAVING SUM(fmc.OBSERVABLE_12M_MEMBERS) >= 100 ORDER BY TOTAL_ACQ_MEMBERS DESC NULLS LAST LIMIT 10'
    )
  );

-- GRANT — SV 재배포(CREATE OR ALTER) 뒤에도 함께 실행
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_COHORT TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_COHORT TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_COHORT TO ROLE GN_DW_SERVICE;

USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 스모크(배포 확인 · 배포 러너는 실행하지 않는다)
SELECT (SELECT TOTAL_ACQ_MEMBERS FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_COHORT METRICS TOTAL_ACQ_MEMBERS)) AS sv_val,
       (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_MEMBER_COHORT) AS fact_val;

SELECT MAX(CHURN_RATE_12M) AS max_rate
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_MEMBER_COHORT
  DIMENSIONS fmc.CAMPAIGN_TYPE
  METRICS CHURN_RATE_12M
);

SELECT CAMPAIGN_TYPE, TOTAL_ACQ_MEMBERS, TOTAL_OBSERVABLE_12M_MEMBERS, TOTAL_STOPPED_12M_MEMBERS,
       ROUND(CHURN_RATE_12M, 2) AS CHURN_12M_PCT
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_MEMBER_COHORT
  DIMENSIONS fmc.CAMPAIGN_TYPE
  METRICS TOTAL_ACQ_MEMBERS, TOTAL_OBSERVABLE_12M_MEMBERS, TOTAL_STOPPED_12M_MEMBERS, CHURN_RATE_12M
)
WHERE TOTAL_OBSERVABLE_12M_MEMBERS >= 5000
ORDER BY CHURN_12M_PCT DESC NULLS LAST;

SELECT ACQ_AGE_BAND, TOTAL_ACQ_MEMBERS, ROUND(CHURN_RATE_12M, 2) AS CHURN_12M_PCT
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_MEMBER_COHORT
  DIMENSIONS fmc.ACQ_AGE_BAND
  METRICS TOTAL_ACQ_MEMBERS, CHURN_RATE_12M
)
ORDER BY TOTAL_ACQ_MEMBERS DESC NULLS LAST;

SELECT FIRST_STOP_REASON, TOTAL_ACQ_MEMBERS
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_MEMBER_COHORT
  DIMENSIONS fmc.FIRST_STOP_REASON
  METRICS TOTAL_ACQ_MEMBERS
)
ORDER BY TOTAL_ACQ_MEMBERS DESC NULLS LAST;
