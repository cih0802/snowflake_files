-- GN_DW 3단계: Semantic View DDL 정본 — SV_EVENT_PARTICIPATION (행사 참여)
-- Co-authored with CoCo
-- ============================================================================
-- ▶ 이 파일의 위상  [2026-08-05 O37 분할]
--   대상 SV = **SV_EVENT_PARTICIPATION** — 이 파일 하나로 **독립 실행**된다(상세 = 아래 포인터).
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
   4. SV_EVENT_PARTICIPATION (회원 Agent) — base FEP(일×회원×행사)
      활성: 참여자수·참여건수·고유 참여회원수 · 행사명/종류/구분
   ===================================================================================== */
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_EVENT_PARTICIPATION
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
    member AS GN_DW.GOLD.DIM_MEMBER_CURRENT
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
    event.EVENT_KIND     AS event.EVENT_KIND     WITH SYNONYMS ('행사종류코드', '행사계통코드') COMMENT = '행사 종류 **원천 판별자 코드**. 실제값 2종 + NULL: ''CRMN''·''EVENT'' · NULL(행사 마스터 미매핑). 🔴 이 값은 업무 분류가 아니라 **행사 마스터가 두 원천의 결합이라는 사실**을 나타낸다 — ''EVENT''=일반행사 원천 · ''CRMN''=캠페인행사 원천. ✅ **사람이 읽는 라벨은 EVENT_KIND_NAME 축을 쓴다**(''일반행사''·''캠페인행사''·''(미매핑)''). 🔴 이 코드축으로 답하지 말고 라벨축으로 답할 것 — 현업은 코드를 모른다. ⚠️ 위 2종 외의 값으로 필터하면 0행이다',
    event.EVENT_KIND_NAME AS event.EVENT_KIND_NAME WITH SYNONYMS ('행사종류', '행사구분계통') COMMENT = '행사 종류 라벨 — **현업 응답용 정본 축**이다. 실제값 3종: ''일반행사''·''캠페인행사''·''(미매핑)''. 🔴 이 라벨은 원천 계통을 뜻한다(일반행사 마스터 / 캠페인행사 마스터) — 온·오프라인 구분이 아니다. ⚠️ ''(미매핑)''은 참여 행이 행사 마스터에 붙지 않은 경우이며 비중이 작지 않다 — 이 축으로 분해하면 그 덩어리를 함께 밝힌다',
    fep.PART_EVENT_KIND AS fep.EVENT_KIND WITH SYNONYMS ('원천계열코드', '참여원천코드') COMMENT = '원천 계열 판별 **코드 — 팩트 자체 보유**(행사 마스터 조인과 무관). 실제값 2종: ''CRMN''·''EVENT''. 🔴 차원축 EVENT_KIND 와 값은 같지만 **결손이 없다** — 차원축은 행사 미매칭 구간이 ''(미매핑)'' 이라 계열을 알려주지 못한다. ✅ 라벨은 PART_EVENT_KIND_NAME 축을 쓴다(현업 답변에 코드를 내지 말 것). ⚠️ 위 2종 외의 값으로 필터하면 0행이다',
    fep.PART_EVENT_KIND_NAME AS fep.EVENT_KIND_NAME WITH SYNONYMS ('원천계열', '참여원천', '행사계열') COMMENT = '원천 계열 판별 **라벨 — 계열 분해의 정본 축이다**. 실제값 2종: ''일반행사''·''캠페인행사''. 🔴🔴 **코드·라벨 축이 원천별로 갈리는 문제(참여상태·경로·채널)를 분해할 때는 차원축 EVENT_KIND_NAME 이 아니라 이 축을 동반한다** — 이 축은 팩트가 원천 분기로 보유해 **전건 값을 가지며 ''(미매핑)'' 사각지대가 없다.  차원축은 행사 마스터에 매칭된 행만 계열을 알려주므로 미매칭 구간에서 무력하다. 🔴 이 라벨은 원천 계통을 뜻한다(일반행사 원천 / 캠페인행사 원천) — 온·오프라인 구분이 아니다. ⚠️ 행사명·행사구분 등 **차원 속성별 분해는 여전히 부분집합**이다(미매칭분은 Unknown 으로 라우팅) — 계열이 확정되는 것과 행사가 확정되는 것은 다르다',
    event.EVENT_CATEGORY AS event.EVENT_CATEGORY WITH SYNONYMS ('행사구분코드') COMMENT = '행사 구분 **원천 코드**(라벨 아님). 🔴🔴 **두 원천의 코드체계가 한 컬럼에 혼재한다** — **일반행사(EVENT) = 백 단위**(''100''~''500'' · 코드군 MS286) · **캠페인행사(CRMN) = 한/두 자리**(''1''~''16'' · 코드군 MS002). 따라서 **PART_EVENT_KIND_NAME 과 함께 보지 않으면 서로 다른 체계를 한 표에 섞는다.** ✅ **사람이 읽는 라벨은 EVENT_CATEGORY_NAME 축을 쓴다**(DEC-35 R1 — 두 코드군 모두 등급 B 확정). ⚠️ 센티넬 행(''(미매핑)'')은 코드가 없어 라벨도 NULL 이다 — 결측이 아니라 조인 대상 부재다. 실제값 19종: ''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''·''9''·''12''·''13''·''14''·''15''·''16''·''100''·''200''·''300''·''400''·''500'' + NULL',
    event.EVENT_CATEGORY_NAME AS event.EVENT_CATEGORY_NAME WITH SYNONYMS ('행사구분', '행사구분명', '행사종류구분') COMMENT = '행사 구분 **라벨 — 현업 응답용 정본 축**이다. 「행사 구분별」 질문은 이 축으로 답한다. 실제값 19종 — 일반행사 계열(코드군 MS286): 온라인·앱전용·회지·리플렛·오프라인 / 캠페인행사 계열(코드군 MS002): 국내사업장방문·해외사업장방문·좋은이웃콘서트·굿멤버스데이(본부)·굿멤버스데이(지부)·굿모닝·문화서비스·문화서비스_전시·문화서비스_서적·문화서비스_공연·기업제휴·특성화회원조직·I''m your pen·기타. ⚠️ 값에 아포스트로피가 포함된 라벨(I''m your pen)이 있어 따옴표 열거 규약 대신 **종수 선언 + 나열**로 적는다 — 종수는 게이트가 실측과 대조한다. 🔴🔴 **라벨공간이 원천별로 갈린다** — 두 코드군의 라벨이 한 축에 섞여 있으므로 이 축으로 분해할 때는 **PART_EVENT_KIND_NAME 을 동반**해 어느 계통인지 밝힌다. ⚠️ 센티넬 행은 라벨 NULL 이다(코드 자체가 없다)',
    fep.PART_STATUS AS fep.PART_STATUS WITH SYNONYMS ('참여상태코드') COMMENT = '참여 상태 **원천 코드**(라벨 아님). 🔴🔴 **두 원천의 코드체계가 혼재한다** — 일반행사(EVENT) = 백 단위(''110''~''220'' · 코드군 MS304) · 캠페인행사(CRMN) = 한 자리(''1''~''6'' · 코드군 MS006) ⇒ **PART_EVENT_KIND_NAME 동반 필수**. 🔴 **두 원천은 「참여」의 정의가 다르다** — MS304 는 **다단계 이벤트의 단계 통과 여부**이고 MS006 은 신청/참여/불참이다. 합산하면 정의가 혼입된다. ✅ 라벨은 PART_STATUS_NAME 축을 쓴다(DEC-35 R1). ⚠️ ''`)`'' 는 **원천 입력 오류(오염값)** 이며 라벨을 붙이지 않는다 — 정상 코드로 취급하지 말 것(원장 §O59-G). 실제값 19종: '')''·''1''·''2''·''3''·''4''·''5''·''6''·''110''·''120''·''130''·''140''·''150''·''160''·''170''·''180''·''190''·''200''·''210''·''220'' + NULL',
    fep.PART_STATUS_NAME AS fep.PART_STATUS_NAME WITH SYNONYMS ('참여상태', '참여상태명') COMMENT = '참여 상태 **라벨 — 현업 응답용 정본 축**이다. 실제값 18종: ''Success''·''Fail''·''1_step_right''·''1_step_fail''·''2_step_right''·''2_step_fail''·''3_step_right''·''3_step_fail''·''4_step_right''·''4_step_fail''·''5_step_right''·''5_step_fail''·''신청''·''참여''·''불참''·''대기''·''취소''·''대기(결제)'' + NULL. 🔴🔴 **라벨공간이 원천별로 갈린다 — 영문 라벨과 한글 라벨이 섞여 있다**: 영문 계열(Success·Fail·n_step_*)은 **일반행사(MS304)**, 한글 계열(신청·참여·불참·대기·취소·대기(결제))은 **캠페인행사(MS006)** 다. ⇒ 「참여 상태별」로 분해하면 **한 의미가 두 라벨로 갈라진다**(예: 참여 성공이 ''Success'' 와 ''참여'' 로 나뉜다) — **PART_EVENT_KIND_NAME 을 반드시 동반**하고 두 계열을 합산하지 말 것. 🔴 두 원천은 참여의 정의 자체가 다르다(단계 통과 vs 신청/참여). ⚠️ MS304 라벨이 **사전에 영문으로 등재**돼 있어 그대로 노출한다 — 한글 표기는 현업 회신 대기(문서20 §M-1). ⚠️ NULL 은 오염값·센티넬처럼 사전에 없는 코드 행이다(라벨 창작 금지)',
    fep.PART_PATH AS fep.PART_PATH WITH SYNONYMS ('참여경로코드', '신청경로코드') COMMENT = '참여·신청 경로 **원천 코드**(라벨 아님). 🔴 **두 체계 혼재** — 일반행사 = 백 단위(코드군 MS303 · 원천 컬럼 참여경로) · 캠페인행사 = 한 자리(코드군 MS004 · 원천 컬럼 **신청경로**) ⇒ **PART_EVENT_KIND_NAME 동반 필수**. ✅ 라벨은 PART_PATH_NAME 축을 쓴다. ⚠️ ''`)`'' 는 오염값이며 라벨 없음(원장 §O59-G). 실제값 13종: '')''·''1''·''2''·''3''·''4''·''5''·''6''·''100''·''200''·''300''·''500''·''600''·''700'' + NULL',
    fep.PART_PATH_NAME AS fep.PART_PATH_NAME WITH SYNONYMS ('참여경로', '신청경로') COMMENT = '참여·신청 경로 **라벨 — 현업 응답용 정본 축**이다. 실제값 12종: ''webmail''·''homepage''·''출석''·''텍스트''·''독자의견''·''독자이벤트''·''홈페이지''·''상담센터''·''초대''·''이메일''·''모바일웹''·''APP'' + NULL. 🔴🔴 **같은 의미가 두 라벨로 갈라져 있다** — ''homepage''(일반행사 MS303)와 ''홈페이지''(캠페인행사 MS004)가 **동시에 존재**한다. 사전 라벨이 원천별로 다르게 등재된 결과이며 우리가 통합 라벨을 만들면 **라벨 창작**이 된다(DEC-17-B) ⇒ 통합하지 않는다. ⇒ 「참여경로별」로 분해하면 **한 의미가 두 행으로 갈라지므로 PART_EVENT_KIND_NAME 을 반드시 동반**하고, 두 계열을 하나로 합쳐 답하려면 **합쳤다는 사실과 대응 관계를 명시**한다. ⚠️ 오염값·사전 미등재 행은 라벨 NULL 이다',
    fep.PART_CHANNEL AS fep.PART_CHANNEL WITH SYNONYMS ('참여채널코드') COMMENT = '참여 채널 **원천 코드**(라벨 아님) — **일반행사 계열만 값을 갖는다**(코드군 MS302). 🟢 **캠페인행사 원천에는 채널 컬럼이 아예 없다**(원천 스캔: 캠페인행사 분기의 채널 non-null **0건**) ⇒ 그 참여 행의 NULL 은 **구조적 부재**다. 🔴🔴 **그러나 NULL 전부를 구조적 부재로 읽지 말 것** — 일반행사 계열에도 NULL 이 **소수** 있고(오염값 행 + 원천 미입력 행) 그쪽은 **결측**이다. NULL 을 해석할 때는 계열을 먼저 가른다. ✅ 라벨은 PART_CHANNEL_NAME 축을 쓴다. ⚠️ ''`)`'' 는 오염값이며 라벨 없음(원장 §O59-G). 실제값 9종: '')''·''100''·''200''·''300''·''400''·''500''·''600''·''700''·''800'' + NULL',
    fep.PART_CHANNEL_NAME AS fep.PART_CHANNEL_NAME WITH SYNONYMS ('참여채널', '참여기기') COMMENT = '참여 채널 **라벨 — 현업 응답용 정본 축**이다(코드군 MS302 · 단일 체계이므로 이 축은 라벨공간이 갈리지 않는다). 실제값 8종: ''PC''·''mobile web''·''APP''·''회지(온라인)''·''회지(오프라인)''·''SNS''·''문자''·''행사'' + NULL. 🔴 **NULL 은 두 가지가 섞여 있다 — 하나로 설명하지 말 것**: ㉠ **캠페인행사 참여 행 전량**은 원천에 채널 컬럼이 없어 NULL 이다(**구조적 부재** · 원천 스캔으로 확인) ㉡ **일반행사 계열의 소수 행**도 NULL 이며 그쪽은 **결측 또는 오염값**이다. ⇒ 이 축으로 분해하면 **캠페인행사 전량이 NULL 버킷에 모이므로 계열을 동반해 그 사실을 밝히고**, 남는 NULL 을 「전부 캠페인행사」라고 단정하지 않는다. ⚠️ 참여 경로(PART_PATH_NAME)와 다른 축이다 — 채널은 기기·매체, 경로는 참여 형태다',
    member.GENDER_NAME   AS member.GENDER_NAME   WITH SYNONYMS ('성별')     COMMENT = '회원 성별 — 정본 공#130. 실제값 5종: ''남자''·''여자''·''기업''·''단체''·''기타''(CM017 라벨). ⚠ 종전 코드값(''M''/''F''/''U'') 노출 → O26 교정',
    member.SEX           AS member.SEX           WITH SYNONYMS ('성별코드') COMMENT = '성별 원천코드(CM013). 이 차원의 실제값 8종 1~8 (+미기재 NULL). ⚠회원 마스터에 ''0''은 없다 — sentinel ''0''은 개발·증감 원천에만 존재하므로 ''0'' 조건은 0행. 라벨은 GENDER_NAME(분석)·SEX_NM(원천)',
    member.SEX_NM        AS member.SEX_NM        WITH SYNONYMS ('성별상세', '국내외국인') COMMENT = 'CM013 원천 라벨 8종(국내(남자)·외국인(여자)·단체·기업 등). 국내/외국인 구분용. 실제값 8종: ''기업''·''기타''·''단체''·''국내(남자)''·''국내(여자)''·''외국인(기타)''·''외국인(남자)''·''외국인(여자)'' + NULL',
    member.MEMBER_STATUS_NAME AS member.MEMBER_STATUS_NAME WITH SYNONYMS ('회원상태') COMMENT = '현재 회원상태 라벨(공#132, MM010). 실제값 13종: ''활동회원''·''신규미납1''·''신규미납2''·''신규미납3''·''신규미납4''·''신규미납5''·''장기미납1''·''장기미납2''·''장기미납3''·''장기미납4''·''장기미납5''·''후원중단''·''(해당없음)''. 🔴 **라벨에 숫자 접두가 없다** — 상태 코드번호를 라벨 앞에 붙인 형태로 필터하면 0행 무증상 오답이다(경위는 원장 §O58-C). ⚠️ ''(해당없음)''은 일시회원이며 정기후원 상태축의 **구조적 부재**다 — 결측이 아니다',
    member.MBER_STAT_CD  AS member.MBER_STAT_CD  WITH SYNONYMS ('회원상태코드') COMMENT = '회원상태 원천코드(MM010 1~12). 실제값 12종: ''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''·''9''·''10''·''11''·''12'' + NULL',
    member.MEMBER_TYPE_NAME AS member.MEMBER_TYPE_NAME WITH SYNONYMS ('회원구분') COMMENT = '회원구분 라벨(MM018): 개인·기업·단체. 실제값 3종: ''개인''·''기업''·''단체''',
    member.MBER_DIV_CD   AS member.MBER_DIV_CD   WITH SYNONYMS ('회원구분코드') COMMENT = '회원구분 원천코드(MM018). 실제값 3종: ''1''·''2''·''3'''
  )
  METRICS (
    fep.TOTAL_PARTICIPANTS AS SUM(fep.PARTICIPANT_CNT)
      WITH SYNONYMS ('참여자수', '참가자수') COMMENT = '참여자수 합계. F(가산).',
    fep.TOTAL_PARTICIPATE_CNT AS SUM(fep.PARTICIPATE_CNT)
      WITH SYNONYMS ('참여건수') COMMENT = '참여 건수 합계. F(가산).',
    fep.DISTINCT_PARTICIPANTS AS COUNT(DISTINCT fep.MEMBER_DK)
      WITH SYNONYMS ('고유 참여회원수') COMMENT = '고유 참여 회원수. D(distinct).'
  )
  COMMENT = 'Phase-1 행사 참여 SV (base: GOLD.FACT_EVENT_PARTICIPATION, grain: 행사참여 1행). CRM 일반행사/캠페인행사 참여 건수, 고유 참여회원수(DISTINCT_PARTICIPANTS), 행사구분/참여상태/경로/채널 라벨 뷰. ⚠️ 일반행사(EVENT)와 캠페인행사(CRMN)의 코드군이 상이하므로 계열 판별자 PART_EVENT_KIND_NAME 동반 필수. 행사 미매칭분은 Unknown(0)으로 처리되어 행사명 집계는 부분집합임.'
  AI_SQL_GENERATION '핵심 규칙: (1) 라벨축 사용: 행사구분(EVENT_CATEGORY_NAME), 참여상태(PART_STATUS_NAME), 참여경로(PART_PATH_NAME), 참여채널(PART_CHANNEL_NAME) 사용. (2) 계열 동반: 원천별 코드체계 분리를 위해 항상 팩트 보유 축인 PART_EVENT_KIND_NAME 을 동반하여 그루핑 (차원축 EVENT_KIND_NAME 사용 금지). (3) 기간 미지정 시: 데이터 최신 연월 기준 직전 12개월로 한정하며 GROUP BY ROLLUP((연,월)) 반환. (4) 원천 차이: 일반행사(다단계 통과)와 캠페인행사(신청/참여/불참)는 참여 정의가 다르므로 합산 참여율 생성 금지. (5) 채널 NULL: 캠페인행사는 원천 채널 컬럼 부재로 전량 NULL임을 명시.';


/* =====================================================================================
   GRANT — Cortex Analyst 소비 권한 (docs: REFERENCES, SELECT 필요 · USAGE 아님)
      ANALYST 가 VIEWER 를 상속하나 명확성을 위해 3역할 모두 명시(02 §E 패턴).
      🟢 [2026-08-10 O54] 본문이 `CREATE OR ALTER` 이므로 **기존 GRANT 는 보존**된다 →
         아래 GRANT 는 멱등 재확인이다. 🔴 판정은 소유자 세션이 아니라 **소비 역할 세션**으로
         한다(P126) — 검사기 = `scripts/sv_unit_gate.py`.
         분할의 이점: GRANT 가 대상 SV 와 같은 파일에 있어 빠뜨릴 수 없다.
   ===================================================================================== */
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_EVENT_PARTICIPATION TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_EVENT_PARTICIPATION TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_EVENT_PARTICIPATION TO ROLE GN_DW_SERVICE;
