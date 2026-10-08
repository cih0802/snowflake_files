-- ============================================================================
-- 05_1_SV_DDL_MEMBER_MONTHLY.sql — Semantic View DDL 정본: SV_MEMBER_MONTHLY
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능(파일 간 순서 없음).
--   · 🔴 SV 의 규칙·주의는 SV COMMENT · AI_SQL_GENERATION 안에 있다(Agent 가 읽는 곳) — 이 주석에 두지 않는다.
--   · 공통 규약 = 05_0_SV_DDL.sql · 설계·실측 이력 = 05_SV_DDL_설계이력_부록.md
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_MONTHLY
  TABLES (
    fmm AS GN_DW.GOLD.FACT_MEMBER_MONTHLY
      PRIMARY KEY (MONTH_KEY, MEMBER_DK)
      WITH SYNONYMS ('회원 월별 실적', '월간 회원 팩트')
      COMMENT = '회원 월별 스냅샷 지표 분석 (base: GOLD.FACT_MEMBER_MONTHLY). [Grain: 월 × 회원]. [활성 지표: 회비/청구/미납/개발/중단]. [주의: 집계필요 배분규칙필요 형제팩트중복 앵커_경합 이중계상 방지]. [원천: CRM → BRONZE_CRM → SILVER.CRM_PAYMENT_BILLING ∪ CRM_MEMBER_DEV/DISCONTINUE → GOLD.FACT_MEMBER_MONTHLY].',
    month AS GN_DW.GOLD.DIM_MONTH
      PRIMARY KEY (MONTH_KEY)
      WITH SYNONYMS ('월', '조회월', '기간')
      COMMENT = '월 차원(DIM_DATE 월 grain DISTINCT). fan-out 차단용 helper 뷰. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.',
    member AS GN_DW.GOLD.DIM_MEMBER
      PRIMARY KEY (MEMBER_DK)
      WITH SYNONYMS ('회원', '회원속성')
      COMMENT = '정규 회원 마스터 차원 (회원 1명 = 1행 · MEMBER_DK 유일). 🔴 IS_CURRENT 컬럼은 없다 — 상태 이력이 필요하면 DIM_MEMBER_STATUS_HISTORY 를 쓴다. 불변/현재 속성 전용. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM · SILVER=CRM_MEMBER · GOLD=DIM_MEMBER.',
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
    member.SEX           AS member.SEX           WITH SYNONYMS ('성별코드')         COMMENT = '성별 원천코드(CM013). 이 차원의 실제값 8종: ''1''국내남·''2''국내여·''3''외국남·''4''외국여·''5''외국기타·''6''단체·''7''기업·''8''기타 (+미기재 NULL). ⚠회원 마스터에 ''0''은 존재하지 않는다 — sentinel ''0''은 개발·증감 원천(CRM_MEMBER_DEV·CRM_MEMBER_AMT_CHANGE)에만 있으므로 이 차원에 ''0'' 조건을 걸면 0행이다. 라벨은 GENDER_NAME(분석)·SEX_NM(원천) · 미기재·sentinel 규모는 이슈원장 참조',
    member.SEX_NM        AS member.SEX_NM        WITH SYNONYMS ('성별상세', '국내외국인') COMMENT = 'CM013 원천 라벨. 실제값 8종: ''국내(남자)''·''국내(여자)''·''외국인(남자)''·''외국인(여자)''·''외국인(기타)''·''단체''·''기업''·''기타''. 국내/외국인 구분이 필요할 때 쓴다',
    member.MEMBER_STATUS_NAME AS member.MEMBER_STATUS_NAME WITH SYNONYMS ('회원상태', '상태') COMMENT = '현재 회원상태 라벨(정본 공#132, MM010). 실제값 13종: ''활동회원''·''신규미납1''·''신규미납2''·''신규미납3''·''신규미납4''·''신규미납5''·''장기미납1''·''장기미납2''·''장기미납3''·''장기미납4''·''장기미납5''·''후원중단''·''(해당없음)''. 🔴🔴 **라벨에 숫자 접두가 없다** — 상태 코드번호를 라벨 앞에 붙인 형태로 필터하면 **0행이 반환되는 무증상 오답**이다(경위는 원장 §O58-C). 숫자로 거르려면 MBER_STAT_CD 를 쓴다. ⚠️ ''(해당없음)''은 일시회원(ONCE)이며 정기후원 상태축이 **구조적으로 부재**한 것이다 — 결측이 아니다. 과거월 조회 시에도 현재 기준',
    member.MBER_STAT_CD  AS member.MBER_STAT_CD  WITH SYNONYMS ('회원상태코드')     COMMENT = '회원상태 원천코드(MM010). 실제값 = ''1''~''12'' 12종 + **NULL**(일시회원 · 라벨 ''(해당없음)''). ⚠️ NULL 을 빼면 일시회원이 조용히 탈락한다 — 전체 회원을 세려면 NULL 을 포함한다. 라벨은 MEMBER_STATUS_NAME(숫자 접두 없음). 실제값 12종: ''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''·''9''·''10''·''11''·''12'' + NULL',
    member.MEMBER_TYPE_NAME AS member.MEMBER_TYPE_NAME WITH SYNONYMS ('회원구분', '구분') COMMENT = '회원구분 라벨(MM018). 실제값 3종: ''개인''·''기업''·''단체''',
    member.MBER_DIV_CD   AS member.MBER_DIV_CD   WITH SYNONYMS ('회원구분코드')     COMMENT = '회원구분 원천코드(MM018 1개인·2기업·3단체). 라벨은 MEMBER_TYPE_NAME. 실제값 3종: ''1''·''2''·''3''',
    member.CHRCTR_RECPTN_YN AS member.CHRCTR_RECPTN_YN WITH SYNONYMS ('문자수신여부', '문자수신', 'SMS 수신동의') COMMENT = '회원 문자수신 여부(현재 마스터 스냅샷 · 과거월 조회도 현재값). 실제값 2종: ''Y''·''N'' + NULL. ⚠️ NULL 은 원천 미입력이며 ''N'' 으로 읽지 않는다',
    fmm.HAS_BILLING      AS fmm.HAS_BILLING      WITH SYNONYMS ('결제출처여부', '결제원천 존재') COMMENT = 'TRUE=결제(billing) 원천 행이 존재하는 월×회원. 🔴**「회비만」 스코프가 아니다**(O40) — 기저 CTE 가 회비(TM_PM_MBRFEE_ACMSLT)와 **기부금(TM_PM_DNTN_DTLS)을 함께** 담으므로 TRUE 인 행에도 기부금이 섞여 있고, 청구가 없는 기부금 전용 월도 TRUE 다. 따라서 이 필터를 걸어도 **회비 납부율의 분자는 정화되지 않는다.** 회비 지표를 볼 때 행 범위를 좁히는 용도로만 쓰고, 「회비 기준」이라고 서술하지 말 것.',
    reason.UNPAID_REASON_TYPE AS reason.REASON_TYPE WITH SYNONYMS ('사유 코드체계', '사유그룹') COMMENT = '🔴사유 코드그룹(PM002·PM018·PM032·PM033·PM019). **사유별 분해 시 이 축을 먼저 걸거나 함께 GROUP BY 할 것** — 그룹이 다르면 같은 이름도 다른 의미다. 그룹 미분리 합산은 조용히 틀린다(O28 유형)',
    reason.UNPAID_REASON      AS reason.REASON_NAME WITH SYNONYMS ('미납사유', '사유', '결제실패사유') COMMENT = '사유 라벨. 🔴**미납/결제실패 행에만 배선**된다 — 정상 납입 행은 전건 ''(미매핑)''이므로 대부분이 (미매핑) 한 덩어리로 나온다. 따라서 미납 관련 지표(총미납금액·미납비중·미납회원수)와 함께 쓸 때만 의미가 있다. ⚠️반드시 UNPAID_REASON_TYPE 과 함께 볼 것',
    fmm.NEW_EXISTING_FLAG AS fmm.NEW_EXISTING_FLAG WITH SYNONYMS ('신규기존구분', '신규/기존', '신규기존') COMMENT = '공#113 신규기존구분 — 조회년도에 최초가입한 회원이면 ''신규'', 그 이전이면 ''기존''. 실제값 2종: ''신규''·''기존'' + NULL(그 달까지 가입 기준일이 없는 회원·Unknown 월). 🔴 기준일은 회원 **최초가입일**(회원 등록일·최초 개발일·첫 청구월 중 가장 이른 날)이다(캠페인별 가입일이 아니다)',
    fmm.DEV_TYPE AS fmm.DEV_TYPE WITH SYNONYMS ('개발구분코드', '월 개발구분') COMMENT = '공#121 그 달 개발구분 원천코드(MM015). 실제값 3종: ''1''(신규)·''2''(증액)·''4''(재후원) + NULL. 🔴 그 달 개발 사건의 구분이 **하나로 확정될 때만** 채운다 — 여러 구분이 섞인 달·개발이 없는 달은 NULL 이다(대표값을 고르지 않는다). 증액·재후원 여부만 필요하면 INCREASE_FLAG·REDONATE_FLAG 를 쓴다',
    fmm.INCREASE_FLAG AS fmm.INCREASE_FLAG WITH SYNONYMS ('증액여부', '증액 발생') COMMENT = '공#33 그 달 증액 개발(MM015 ''2'') 사건이 있으면 TRUE',
    fmm.REDONATE_FLAG AS fmm.REDONATE_FLAG WITH SYNONYMS ('재후원여부', '재후원 발생') COMMENT = '공#34 그 달 재후원 개발(MM015 ''4'') 사건이 있으면 TRUE',
    fmm.AMOUNT_BAND1 AS fmm.AMOUNT_BAND1 WITH SYNONYMS ('후원금액대1', '5만원 단위 금액대') COMMENT = '공#72 조회년월 약정금액(활동 후원사업금액 합) 5만원 구간. 값 형식 = ''<하한>~<상한>만원 미만''(예: ''0~5만원 미만''·''5~10만원 미만''). 약정 없음 ⇒ NULL',
    fmm.AMOUNT_BAND2 AS fmm.AMOUNT_BAND2 WITH SYNONYMS ('후원금액대2', '1만원 단위 금액대') COMMENT = '공#73 조회년월 약정금액 1만원 구간. 값 형식 = ''<하한>~<상한>만원 미만''(예: ''3~4만원 미만''). 약정 없음 ⇒ NULL. ⚠️ 문자열 정렬은 숫자 순서가 아니다',
    fmm.PERIOD_BAND1 AS fmm.PERIOD_BAND1 WITH SYNONYMS ('후원기간대1', '5년 단위 기간대') COMMENT = '공#74 최초가입일~조회년월 기간 5년 구간. 값 형식 = ''<하한>~<상한>년 미만''(예: ''0~5년 미만''). 기준일 없음 ⇒ NULL',
    fmm.PERIOD_BAND2 AS fmm.PERIOD_BAND2 WITH SYNONYMS ('후원기간대2', '1년 단위 기간대') COMMENT = '공#75 최초가입일~조회년월 기간 1년 구간. 값 형식 = ''<하한>~<상한>년 미만''(예: ''2~3년 미만''). 기준일 없음 ⇒ NULL',
    member.REGION AS member.REGION WITH SYNONYMS ('지역', '약정시점 지역', '가입시점 지역', '시도') COMMENT = '🔴**약정(개발) 시점의** 회원 지역 라벨 — **현재 거주지가 아니다**(O34 확정). 정본 공#131 · 코드사전 CM018 약칭. 실제값: ''서울''·''경기''·''인천''·''강원''·''대전''·''대구''·''부산''·''광주''·''울산''·''세종''·''충남''·''충북''·''전남''·''전북''·''경남''·''경북''·''제주''·''기타''. 원천 = 개발약정 테이블의 지역코드이며 약정 당시 값이 그대로 굳는다 — 이후 이사해도 갱신되지 않는다. 코드는 DIM_MEMBER.AREA_CD. ⚠️''현재 거주지역별'' 질문에는 답할 수 없다 — 원천에 현재 주소 축이 없다. ⚠️개발약정이 없는 회원(주로 일시회원)은 NULL 이며 ''미상''이 아니라 원천 부재다',
    member.AGE_BAND AS member.AGE_BAND WITH SYNONYMS ('연령대', '약정시점 연령대', '가입시점 연령대') COMMENT = '🔴**약정(개발) 시점의** 회원 연령대 라벨 — **현재 나이가 아니다**(O34 확정). 코드사전 CM014. 실제값: ''10대 미만''·''10대''·''20대''·''30대''·''40대''·''50대''·''60대''·''70대''·''70대 이상''·''단체''·''기업''·''기타''. ✅라벨 매핑은 CM014 사전과 일치 검증됨(우리 쪽 결함 아님). ✅''10대 미만''이 최다인 것도 **실제이며 데이터 오류가 아니다** — 원인은 **편지쓰기대회 계열 캠페인**(희망편지쓰기대회·가족그림편지쓰기대회·세계시민교육편지)이다. 이 계열은 학교·부모 DB 를 통해 **아동 본인 명의로 후원 약정을 맺는 모집 이벤트**여서 20세 미만 비중이 그 외 캠페인보다 압도적으로 높다(개발사건 단위 실측·문서10 §19 참조). 따라서 *''왜 10대 미만이 많은가''* 라는 질문에는 **''특정 아동 모집 캠페인(편지쓰기대회 계열) 때문이며 약정 당시 연령 기준이다''** 라고 답하면 된다 — 결측·오류로 설명하지 말 것. 🔴그러나 이 값은 **약정 당시에 굳은 스냅샷**이라 오래된 회원일수록 실제 나이와 벌어진다 — 독립 원천(SND_MEMBER_LIST 연령대 라벨)과 회원 단위 대조 시 불일치가 **전부 노화 방향**이었고, 약정연도가 오래될수록 격차가 단조 증가했다. ⚠️**현재 연령대는 산출 불가**다 — BRONZE 전체에 생년월일 컬럼이 없다. 따라서 ''현재 연령별'' 질문에 이 축으로 답하지 말 것. ⚠️''단체''·''기업''은 나이가 아니라 법인 구분이므로 연령 추이에서 제외할 것 · 원천 부재 시 NULL',
    member.MEMBER_ENROLL_PATH_NAME AS member.ENROLL_PATH_NAME WITH SYNONYMS ('가입경로', '회원 가입경로') COMMENT = '🆕 [O213] 회원 가입경로(MM014 · REG·홈페이지·모바일웹·모바일앱·외주콜센터·CRM) — 회원 마스터 현재값. 일시회원은 (해당없음).',
    member.MEMBER_JOIN_CMMN_BRND_NM AS member.JOIN_CMMN_BRND_NM WITH SYNONYMS ('가입 공통브랜드', '회원 가입 공통브랜드') COMMENT = '🆕 [O213] 회원 가입 시 공통브랜드(MM297) — 회원 마스터 기준.'
  )
  METRICS (
    fmm.TOTAL_PAID_ALL   AS SUM(fmm.PAID_FEE)
      WITH SYNONYMS ('총수납액', '수납액', '납입총액') COMMENT = '납입 **총액**(원) = 회비 + 기부금. F(가산). 🔴**「납입회비」가 아니다**(O40) — 기저 `PAID_FEE` 는 회비(TM_PM_MBRFEE_ACMSLT)와 기부금(TM_PM_DNTN_DTLS)의 `PAY_AMT` 를 **모두** 합한 값이다. 🔴**납부율의 분자로 쓰지 말 것** — 기부금은 원천에 청구(`RQEST_AMT`) 컬럼이 아예 없어(전건 NULL) 분모 `TOTAL_BILLED_AMT` 에 구조적으로 들어갈 수 없다. 분자에만 더해지면 납부율이 과대해진다(과대 규모 실측치는 이슈원장 §O40 참조). 회비만의 납입액은 **`TOTAL_PAID_FEE_BILLABLE`** 이다. 🟢「총수납액(회비+기부금)」을 명시적으로 물을 때 이 metric 을 쓰고 그때도 기부금 포함임을 밝힌다. 🔴 종전 이름은 `TOTAL_PAID_FEE` 였다 — `_FEE` 가 「회비」로 오해되므로 형제 SV `SV_MEMBER_FEE.TOTAL_PAID_ALL` 과 **같은 이름으로 통일**했다(정의·값 불변).',
    fmm.TOTAL_BILLED_AMT AS SUM(fmm.BILLED_AMT)
      WITH SYNONYMS ('청구금액', '청구액 총액') COMMENT = '청구금액 합계(원, 재청구 중복 포함). F(가산).',
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
    fmm.TOTAL_PAID_FEE_BILLABLE AS SUM(fmm.PAID_FEE_BILLABLE)
      WITH SYNONYMS ('납입회비', '납입회비 총액', '회비 납입액', '수납회비', '회비 수납액')
      COMMENT = '납입회비(원) — **회비만**. F(가산). 정본 #69·70. 기부금은 제외된다(기부금은 원천에 청구 컬럼이 없어 납부율 분모에 들어갈 수 없다). 회비+기부금 총수납액은 `TOTAL_PAID_ALL` 이다(2026-08-10 이전 이름 = `TOTAL_PAID_FEE`).',
    fmm.PAYMENT_RATE_FEE AS SUM(fmm.PAID_FEE_BILLABLE) / NULLIF(SUM(fmm.BILLED_AMT), 0) * 100
      WITH SYNONYMS ('납부율', '수납율', '회비 납부율', '납입률', '납부율(%)')
      COMMENT = '**공64 납부율(%) 정본** = 회비 납입액 ÷ 회비 청구액 ×100. 분자·분모가 모두 회비라 모집단이 일치한다. 비율(N, 재집계 금지). 🟢납부율을 묻는 질문에는 이 metric 을 쓴다 — **유일한 납부율 정본**이다. 🔴 종전 공존했던 `PAYMENT_RATE`(기부금이 분자에 혼입돼 **100% 를 넘던** 지표)는 **SV 에서 제거**했다. 규모·실측치는 이슈원장 §O56-C 참조.',
    fmm.TOTAL_UNPAID_AMT AS SUM(fmm.UNPAID_BILLED_AMT)
      WITH SYNONYMS ('총미납금액', '미납금액', '미납액', '미납액 총액', '못 걷은 금액')
      COMMENT = '**총미납금액(원) 정본** — DEC-3 정의: 결제상태가 실패(F) 또는 NULL 인 청구액 합. F(가산). 🟢미납금액 질문에는 이 metric 을 쓴다. ⚠️미납은 회수될 수 있으므로 조회 시점 스냅샷이다. 🔴 종전 이름은 `TOTAL_UNPAID_AMT_DEC3` 였고 이 이름은 차감식(청구−납입)이 쓰고 있었다 — 차감식을 제거하고 정본이 이 이름을 **승격**했다. 형제 팩트 `SV_MEMBER_FEE.TOTAL_UNPAID_AMT` 와 **같은 이름·같은 식**이므로 전체 합계가 일치해야 한다(GATE-D).',
    fmm.UNPAID_RATIO AS SUM(fmm.UNPAID_BILLED_AMT) / NULLIF(SUM(fmm.BILLED_AMT), 0) * 100
      WITH SYNONYMS ('미납비중', '미납율', '미납률', '미납 비율')
      COMMENT = '**미납비중(%) 정본** = 미납 청구액 ÷ 회비 청구액 ×100. 비율(N, 재집계 금지). 단위는 **퍼센트**다 — 값을 다시 ×100 하지 말 것. ⚠️`100 − 납부율` 과 정확히 같지 않다 — 부분납입 행이 있어 두 값은 서로 보완적이다(연도별 실측치는 이슈원장 §O40 참조). 🔴 종전 이름은 `UNPAID_RATIO_DEC3` 였고 이 이름은 차감식(청구−납입)이 쓰고 있었다 — 그 차감식은 **음수가 나오던 폐기 지표**이며 제거했고 정본이 이 이름을 **승격**했다. 실측치는 이슈원장 §O55·§O56 참조. 형제 팩트 `SV_MEMBER_FEE.UNPAID_RATIO` 와 **같은 이름·같은 식·같은 단위**다(GATE-D).',
    fmm.AVG_PAID_FEE AS AVG(fmm.PAID_FEE)
      WITH SYNONYMS ('평균납입회비', '평균회비') COMMENT = '행(월×회원)당 평균 납입회비(원). HAS_BILLING=TRUE 전제 권장. PoC AVG_PAID 로직 이식.',
    fmm.ACTIVE_CNT_SUM AS SUM(fmm.ACTIVE_CNT)
      WITH SYNONYMS ('활동(건)', '월말활동회원(건)', '활동건') COMMENT = '공#157·#52 활동(건) = 월말 활동 회원의 약정금액 ÷ 10,000. 스톡 — 🔴 **한 달을 지정해** 조회한다(여러 달 합산은 연인원·연건이 된다).',
    fmm.ACTIVE_MEMBERS_SUM AS SUM(fmm.ACTIVE_MEMBERS)
      WITH SYNONYMS ('활동(명)', '월말활동회원', '활동회원수') COMMENT = '공#156·#51 활동(명) = 월말 활동 회원수. 스톡 — 🔴 한 달을 지정해 조회한다.',
    fmm.ACTIVE_CUM_CNT_SUM AS SUM(fmm.ACTIVE_CUM_CNT)
      WITH SYNONYMS ('활동누계(건)', '활동 누계 건') COMMENT = '공#159 활동누계(건) = 당해년도 1월~조회월 활동(건) 누계. 🔴 **조회월 하나를 지정**해야 한다 — 이미 누계라 여러 달을 더하면 이중 누계다.',
    fmm.ACTIVE_CUM_MEMBERS_SUM AS SUM(fmm.ACTIVE_CUM_MEMBERS)
      WITH SYNONYMS ('활동누계(명)', '활동 누계 명') COMMENT = '공#158 활동누계(명) = 당해년도 1월~조회월 활동(명) 누계(회원번호 개수 누계). 🔴 조회월 하나를 지정한다.',
    fmm.UNPAID_CNT_SUM AS SUM(fmm.UNPAID_CNT)
      WITH SYNONYMS ('미납(건)', '미납건') COMMENT = '공#36 미납(건) = 월말 미납 회원의 전체 약정금액 ÷ 10,000. 스톡 — 한 달을 지정한다. 미납 판정은 DEC-4(월말 미납 청구행 존재)와 같다.',
    fmm.UNPAID_RATE_CNT AS SUM(fmm.UNPAID_CNT) / NULLIF(SUM(fmm.ACTIVE_CNT), 0) * 100
      WITH SYNONYMS ('미납율(건 기준)', '공76 미납율') COMMENT = '공#76 미납율(%) **건 기준** = 미납(건) ÷ 활동(건) ×100. 비율(N). 🔴 금액 기준 미납비중(UNPAID_RATIO · 청구액 대비)과 분모가 다르다 — 사용자가 「건 기준」·「공76」·「활동 대비」를 명시할 때 이 metric 을 쓰고, 그 외 「미납율」은 기존 라우팅(UNPAID_RATIO)을 따르며 어느 기준인지 밝힌다.',
    fmm.STATUS_UNPAID_CNT_SUM AS SUM(fmm.STATUS_UNPAID_CNT)
      WITH SYNONYMS ('회원상태별 미납(건)', '미납회비(건)') COMMENT = '공#84 회원상태별 미납(건) = 미납회비금액 ÷ 10,000. MEMBER_STATUS_NAME(현재 상태)으로 분해해 쓴다. F(가산).',
    fmm.INCREASE_CNT_SUM AS SUM(fmm.INCREASE_CNT)
      WITH SYNONYMS ('증액(건)', '증액건') COMMENT = '공#151 증액(건) = 전월 대비 활동(건)이 증가한 회원의 증가분 합. F(가산). 🔴 신규 약정으로 늘어난 것도 포함된다(정본 문구 = 활동(건) 증가).',
    fmm.INCREASE_MEMBERS_SUM AS SUM(fmm.INCREASE_MEMBERS)
      WITH SYNONYMS ('증액(명)', '증액회원수') COMMENT = '공#150 증액(명) = 전월 대비 활동(건)이 증가한 회원수. 한 달 단위로 본다.',
    fmm.DECREASE_CNT_SUM AS SUM(fmm.DECREASE_CNT)
      WITH SYNONYMS ('감액(건)', '감액건') COMMENT = '공#38 감액(건) = 감액금액 ÷ 10,000. F(가산).',
    fmm.CHURN_CNT_SUM AS SUM(fmm.CHURN_CNT)
      WITH SYNONYMS ('이탈(건)', '이탈건') COMMENT = '신규#20 이탈(건) = (중단 약정금액 + 감액금액) ÷ 10,000. F(가산). 🔴 중단 사건 **건수**(TOTAL_STOP_CNT)와 단위가 다르다.',
    fmm.AVG_SPONSOR_MONTHS AS AVG(fmm.SPONSOR_MONTHS)
      WITH SYNONYMS ('평균 후원기간(개월)', '후원기간') COMMENT = '공#127 최초가입일~조회월 개월수의 평균. 한 달을 지정해 쓴다(회원별 값의 평균).',
    fmm.AVG_PAID_MONTHS AS AVG(fmm.PAID_MONTHS)
      WITH SYNONYMS ('평균 납입개월수', '납입개월수') COMMENT = '공#129 조회월까지 정기납입이 있었던 달 수의 평균. 한 달을 지정해 쓴다.',
    -- 🆕 [O201-C] 단월 정의가 확정된 비율 5종(정본 = 30_output_share/05_지표GOLD매핑.md:132~134·154~155)
    --   🔴 공45~47 은 SV_MEMBER_MONTHLY_KPI 소관(누계개발 모집단 집계) · 공54 는 O202 에서 사전 정의 그대로 신설.
    --   🆕 [O202] 분자 = STOP_AMT_CNT(#35 중단(건) = 금액 ÷ 10,000) — DEV_CNT 가 MSTR 금액 기준이 되어 사건 수(STOP_CNT)와 단위가 어긋났다.
    fmm.STOP_RATE_1 AS SUM(fmm.STOP_AMT_CNT) / NULLIF(SUM(fmm.DEV_CNT) + SUM(fmm.YEAR_START_ACTIVE_CNT), 0) * 100
      WITH SYNONYMS ('중단율1', '공54', '활동 대비 중단율') COMMENT = '공54 중단율1(%) = 중단(건) ÷ (개발(건) + 연도초활동회원(건)) ×100 — 지표 사전 정의 그대로(O202 현업 지시). 개발(건)은 그 달 값(누계 아님). 비율(N). 🔴 한 달을 지정한다.',
    fmm.STOP_RATE_2 AS SUM(fmm.STOP_AMT_CNT) / NULLIF(SUM(fmm.DEV_CNT), 0) * 100
      WITH SYNONYMS ('중단율2', '공55', '개발 대비 중단율') COMMENT = '공55 중단율2(%) = 중단(건) ÷ 개발(건) ×100. 비율(N). 🔴 한 달을 지정해 쓴다 · 다른 중단율(코호트 12개월 이탈률 = SV_MEMBER_COHORT)과 정의가 다르다.',
    fmm.STOP_RATE_NEW AS SUM(CASE WHEN fmm.NEW_EXISTING_FLAG = '신규' THEN fmm.STOP_AMT_CNT END)
        / NULLIF(SUM(CASE WHEN fmm.NEW_EXISTING_FLAG = '신규' THEN fmm.DEV_CNT + fmm.PREV_MONTH_END_ACTIVE_CNT END), 0) * 100
      WITH SYNONYMS ('신규 중단율', '공56') COMMENT = '공56 신규 중단율(%) = 중단(건)[신규] ÷ (개발(건)[신규] + 전월말 활동(건)[신규]) ×100. 비율(N). 🔴 한 달을 지정한다 · 신규/기존은 NEW_EXISTING_FLAG.',
    fmm.STOP_RATE_EXISTING AS SUM(CASE WHEN fmm.NEW_EXISTING_FLAG = '기존' THEN fmm.STOP_AMT_CNT END)
        / NULLIF(SUM(CASE WHEN fmm.NEW_EXISTING_FLAG = '기존' THEN fmm.DEV_CNT + fmm.PREV_MONTH_END_ACTIVE_CNT END), 0) * 100
      WITH SYNONYMS ('기존 중단율', '공57') COMMENT = '공57 기존 중단율(%) = 중단(건)[기존] ÷ (개발(건)[기존] + 전월말 활동(건)[기존]) ×100. 비율(N). 🔴 한 달을 지정한다.',
    fmm.UNPAID_RATE_NEW AS SUM(CASE WHEN fmm.NEW_EXISTING_FLAG = '신규' THEN fmm.UNPAID_CNT END)
        / NULLIF(SUM(CASE WHEN fmm.NEW_EXISTING_FLAG = '신규' THEN fmm.ACTIVE_CNT END), 0) * 100
      WITH SYNONYMS ('신규 미납율', '공77') COMMENT = '공77 신규 미납율(%) 건 기준 = 미납(건)[신규] ÷ 활동(건)[신규] ×100. 비율(N). 스톡 — 한 달을 지정한다.',
    fmm.UNPAID_RATE_EXISTING AS SUM(CASE WHEN fmm.NEW_EXISTING_FLAG = '기존' THEN fmm.UNPAID_CNT END)
        / NULLIF(SUM(CASE WHEN fmm.NEW_EXISTING_FLAG = '기존' THEN fmm.ACTIVE_CNT END), 0) * 100
      WITH SYNONYMS ('기존 미납율', '공78') COMMENT = '공78 기존 미납율(%) 건 기준 = 미납(건)[기존] ÷ 활동(건)[기존] ×100. 비율(N). 스톡 — 한 달을 지정한다.'
  )
  COMMENT = 'Phase-1 회원 월별 실적 SV (base: GOLD.FACT_MEMBER_MONTHLY, grain: 회원×월 1행). CRM 원천 기반 납입/청구 총액, 정본 납부율(PAYMENT_RATE_FEE), 미납회원 감소율, 총미납금액(TOTAL_UNPAID_AMT), 미납비중(UNPAID_RATIO), 평균납입회비 요약. ⚠️ 후원사업·납입방식·회비구분 세부 분해는 SV_MEMBER_FEE(회비 grain)를 사용하며, 두 뷰의 회비 measure 합산 금지(이중계상). 캠페인별/후원사업별 활동회원은 SV_MEMBER_SPONSOR_BIZ(약정 grain) 사용.'
  AI_SQL_GENERATION '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙:
(1) 지표 매핑: 납부율=PAYMENT_RATE_FEE (유일 정본), 납입회비(회비만)=TOTAL_PAID_FEE_BILLABLE, 총수납액(회비+기부금)=TOTAL_PAID_ALL, 총미납금액=TOTAL_UNPAID_AMT (DEC-3 정본), 미납비중(%)=UNPAID_RATIO.
(2) 기간 미지정 시: 데이터 최신 연월 기준 직전 12개월로 한정하며 GROUP BY ROLLUP((연,월)) 반환.
(3) 뷰 라우팅 및 이중계상 방지: 후원사업·납입방식·납입일별 회비 분해는 SV_MEMBER_FEE 로 라우팅. 두 뷰의 회비 measure 를 동일 표에 합산하지 말 것. 캠페인별/후원사업별 활동회원수는 SV_MEMBER_SPONSOR_BIZ 로 라우팅.
(4) 사건 연계: 중단(명) 등 사건 기준 지표는 SV_MEMBER_EVENT 를 회원·월로 사전집계하여 병기하며 주차 합계를 월로 더하지 않는다.
(5) 판정 라벨 [집계필요]: 월간 중단보고의 「중단(명)」은 이 뷰의 플래그 합이 아니라 SV_MEMBER_EVENT 의 중단 고유회원수로 답한다. 회원-월 요약과 사건 집계는 표를 분리하고 각 표의 grain 을 밝힌다.
(6) 판정 라벨 [형제팩트중복]: 납입방식·「납입(원)」은 이 뷰가 앵커가 아니다 — SV_MEMBER_FEE 를 앵커로 답하고 두 뷰를 한 표에 합치지 않는다.
(7) 판정 라벨 [배분규칙필요]: 발송·사건 grain 으로 이 뷰의 회원월 measure(개발/중단 건·명)를 요구받으면 SQL 을 만들지 않고 「배분(귀속) 규칙이 필요한 업무 판단 사안」이라고 답한다. 자기 grain(월×회원) 질의는 정상 답변한다.
(8) 스톡·누계 지표(ACTIVE_*·ACTIVE_CUM_*·UNPAID_CNT_SUM·AVG_SPONSOR_MONTHS·AVG_PAID_MONTHS)는 월별로 GROUP BY 하거나 조회월 하나로 필터한다 — 여러 달을 한 값으로 합산하지 않는다. 연간 값은 12월(또는 최신월) 값을 쓴다.
(9) 금액대·기간대(AMOUNT_BAND*·PERIOD_BAND*)는 문자열이라 정렬이 숫자 순서가 아니다 — 결과를 하한 숫자 기준으로 정렬해 제시한다.';

-- GRANT — SV 재배포(CREATE OR ALTER) 뒤에도 함께 실행
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_MONTHLY TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_MONTHLY TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_MONTHLY TO ROLE GN_DW_SERVICE;

USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 스모크(배포 확인 · 배포 러너는 실행하지 않는다)
SELECT (SELECT TOTAL_PAID_ALL FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY METRICS TOTAL_PAID_ALL)) AS sv_val,
       (SELECT SUM(PAID_FEE) FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY)                                        AS fact_val;
