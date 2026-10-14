-- O228 C3 SV 재배포(COMMENT 문안만 변경 · CREATE OR ALTER) · 생성 = tmp/o228/gen_deploy_sql.py
-- 👤 GN_DW_ADMIN 으로 전체 실행(Run All) · 끝나면 에이전트가 deploy_c3_sv.py verify 로 대조
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_ETL_WH;
USE SCHEMA GN_DW.SERVING;

-- SV_MEMBER_MONTHLY ← 05_01_SV_DDL_MEMBER_MONTHLY.sql
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
      COMMENT = '사유 차원. PK 유일(fan-out 0). 🔴코드그룹이 섞여 있다 — REASON_TYPE 으로 먼저 분리하지 않으면 서로 다른 코드체계를 한 축으로 합산하게 된다(유형). [원천] 시스템=CRM · SILVER=CRM_CODE 파생.',
    -- 🆕 [2026-10-14 O225-C] 그 달 후원 캠페인(단일 월만 · 다중 월 = (미매핑) + IS_MULTI_CAMPAIGN)
    campaign AS GN_DW.GOLD.DIM_CAMPAIGN
      PRIMARY KEY (CAMPAIGN_SK)
      WITH SYNONYMS ('캠페인', '후원 캠페인', '그 달 캠페인')
      COMMENT = '캠페인 차원(PK 유일 · fan-out 0). 회원×월의 「그 달 후원 캠페인」이 하나일 때만 연결된다 — 여러 캠페인을 후원한 달(IS_MULTI_CAMPAIGN=TRUE)과 회비 행이 없는 달은 (미매핑). [원천] BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR.CMPGN_CD · TM_PM_*.ONCE_CMPGN_CD → TM_CM_CMPGN_MNG.',
    -- 🆕 [2026-10-14 O226 · campaign_axis_gate GAP] 회원 최초 캠페인(DIM_MEMBER.FIRST_CAMPAIGN = 캠페인 코드) — 같은 마스터를 별칭으로 한 번 더 붙인다
    first_campaign AS GN_DW.GOLD.DIM_CAMPAIGN
      PRIMARY KEY (CAMPAIGN_BK)
      WITH SYNONYMS ('최초 캠페인', '가입 캠페인')
      COMMENT = '회원 최초 캠페인 차원(DIM_CAMPAIGN 을 캠페인 코드 CAMPAIGN_BK 로 조인 · BK 유일 · fan-out 0). 회원 마스터의 현재값이며 월과 무관하다 — 「그 달 후원 캠페인」(campaign)과 다른 축이다. [원천] BRONZE_CRM.TM_MM_FDRM_MBER_INFO.CMPGN_CD → TM_CM_CMPGN_MNG.'
  )
  RELATIONSHIPS (
    fmm_to_month  AS fmm (MONTH_KEY) REFERENCES month,
    fmm_to_member AS fmm (MEMBER_DK) REFERENCES member,
    fmm_to_reason AS fmm (REASON_SK) REFERENCES reason,
    fmm_to_campaign AS fmm (CAMPAIGN_SK) REFERENCES campaign,
    member_to_first_campaign AS member (FIRST_CAMPAIGN) REFERENCES first_campaign
  )
  DIMENSIONS (
    month.MONTH_KEY   AS month.MONTH_KEY WITH SYNONYMS ('연월', '조회연월') COMMENT = 'YYYYMM 정수',
    month.CAL_YEAR    AS month.YEAR      WITH SYNONYMS ('연도', '년', '해') COMMENT = '조회 연도',
    month.CAL_MONTH   AS month.MONTH     WITH SYNONYMS ('월', '몇월')       COMMENT = '월(1~12)',
    month.CAL_QUARTER AS month.QUARTER   WITH SYNONYMS ('분기')            COMMENT = '분기(1~4)',
    member.GENDER_NAME   AS member.GENDER_NAME   WITH SYNONYMS ('성별')             COMMENT = '회원 성별 — 정본 공#130. 실제값 5종: ''남자''·''여자''·''기업''·''단체''·''기타''(코드사전 CM017 라벨).',
    member.SEX           AS member.SEX           WITH SYNONYMS ('성별코드')         COMMENT = '성별 원천코드(CM013). 이 차원의 실제값 8종: ''1''국내남·''2''국내여·''3''외국남·''4''외국여·''5''외국기타·''6''단체·''7''기업·''8''기타 (+미기재 NULL). ⚠회원 마스터에 ''0''은 존재하지 않는다 — sentinel ''0''은 개발·증감 원천(CRM_MEMBER_DEV·CRM_MEMBER_AMT_CHANGE)에만 있으므로 이 차원에 ''0'' 조건을 걸면 0행이다. 라벨은 GENDER_NAME(분석)·SEX_NM(원천) · 미기재·sentinel',
    member.SEX_NM        AS member.SEX_NM        WITH SYNONYMS ('성별상세', '국내외국인') COMMENT = 'CM013 원천 라벨. 실제값 8종: ''국내(남자)''·''국내(여자)''·''외국인(남자)''·''외국인(여자)''·''외국인(기타)''·''단체''·''기업''·''기타''. 국내/외국인 구분이 필요할 때 쓴다',
    member.MEMBER_STATUS_NAME AS member.MEMBER_STATUS_NAME WITH SYNONYMS ('회원상태', '상태') COMMENT = '현재 회원상태 라벨(정본 공#132, MM010). 실제값 13종: ''활동회원''·''신규미납1''·''신규미납2''·''신규미납3''·''신규미납4''·''신규미납5''·''장기미납1''·''장기미납2''·''장기미납3''·''장기미납4''·''장기미납5''·''후원중단''·''(해당없음)''. 🔴🔴 **라벨에 숫자 접두가 없다** — 상태 코드번호를 라벨 앞에 붙인 형태로 필터하면 **0행이 반환되는 무증상 오답**이다. 숫자로 거르려면 MBER_STAT_CD 를 쓴다. ⚠️ ''(해당없음)''은 일시회원(ONCE)이며 정기후원 상태축이 **구조적으로 부재**한 것이다 — 결측이 아니다. 과거월 조회 시에도 현재 기준',
    member.MBER_STAT_CD  AS member.MBER_STAT_CD  WITH SYNONYMS ('회원상태코드')     COMMENT = '회원상태 원천코드(MM010). 실제값 = ''1''~''12'' 12종 + **NULL**(일시회원 · 라벨 ''(해당없음)''). ⚠️ NULL 을 빼면 일시회원이 조용히 탈락한다 — 전체 회원을 세려면 NULL 을 포함한다. 라벨은 MEMBER_STATUS_NAME(숫자 접두 없음). 실제값 12종: ''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''·''9''·''10''·''11''·''12'' + NULL',
    member.MEMBER_TYPE_NAME AS member.MEMBER_TYPE_NAME WITH SYNONYMS ('회원구분', '구분') COMMENT = '회원구분 라벨(MM018). 실제값 3종: ''개인''·''기업''·''단체''',
    member.MBER_DIV_CD   AS member.MBER_DIV_CD   WITH SYNONYMS ('회원구분코드')     COMMENT = '회원구분 원천코드(MM018 1개인·2기업·3단체). 라벨은 MEMBER_TYPE_NAME. 실제값 3종: ''1''·''2''·''3''',
    member.CHRCTR_RECPTN_YN AS member.CHRCTR_RECPTN_YN WITH SYNONYMS ('문자수신여부', '문자수신', 'SMS 수신동의') COMMENT = '회원 문자수신 여부(현재 마스터 스냅샷 · 과거월 조회도 현재값). 실제값 2종: ''Y''·''N'' + NULL. ⚠️ NULL 은 원천 미입력이며 ''N'' 으로 읽지 않는다',
    fmm.HAS_BILLING      AS fmm.HAS_BILLING      WITH SYNONYMS ('결제출처여부', '결제원천 존재') COMMENT = 'TRUE=결제(billing) 원천 행이 존재하는 월×회원. 🔴**「회비만」 스코프가 아니다** — 기저 CTE 가 회비(TM_PM_MBRFEE_ACMSLT)와 **기부금(TM_PM_DNTN_DTLS)을 함께** 담으므로 TRUE 인 행에도 기부금이 섞여 있고, 청구가 없는 기부금 전용 월도 TRUE 다. 따라서 이 필터를 걸어도 **회비 납부율의 분자는 정화되지 않는다.** 회비 지표를 볼 때 행 범위를 좁히는 용도로만 쓰고, 「회비 기준」이라고 서술하지 말 것.',
    reason.UNPAID_REASON_TYPE AS reason.REASON_TYPE WITH SYNONYMS ('사유 코드체계', '사유그룹') COMMENT = '🔴사유 코드그룹(PM002·PM018·PM032·PM033·PM019). **사유별 분해 시 이 축을 먼저 걸거나 함께 GROUP BY 할 것** — 그룹이 다르면 같은 이름도 다른 의미다. 그룹 미분리 합산은 조용히 틀린다(유형)',
    reason.UNPAID_REASON      AS reason.REASON_NAME WITH SYNONYMS ('미납사유', '사유', '결제실패사유') COMMENT = '사유 라벨. 🔴**미납/결제실패 행에만 배선**된다 — 정상 납입 행은 전건 ''(미매핑)''이므로 대부분이 (미매핑) 한 덩어리로 나온다. 따라서 미납 관련 지표(총미납금액·미납비중·미납회원수)와 함께 쓸 때만 의미가 있다. ⚠️반드시 UNPAID_REASON_TYPE 과 함께 볼 것',
    fmm.NEW_EXISTING_FLAG AS fmm.NEW_EXISTING_FLAG WITH SYNONYMS ('신규기존구분', '신규/기존', '신규기존') COMMENT = '공#113 신규기존구분 — 조회년도에 최초가입한 회원이면 ''신규'', 그 이전이면 ''기존''. 실제값 2종: ''신규''·''기존'' + NULL(그 달까지 가입 기준일이 없는 회원·Unknown 월). 🔴 기준일은 회원 **최초가입일**(회원 등록일·최초 개발일·첫 청구월 중 가장 이른 날)이다(캠페인별 가입일이 아니다)',
    fmm.DEV_TYPE AS fmm.DEV_TYPE WITH SYNONYMS ('개발구분코드', '월 개발구분') COMMENT = '공#121 그 달 개발구분 원천코드(MM015). 실제값 3종: ''1''(신규)·''2''(증액)·''4''(재후원) + NULL. 🔴 그 달 개발 사건의 구분이 **하나로 확정될 때만** 채운다 — 여러 구분이 섞인 달·개발이 없는 달은 NULL 이다(대표값을 고르지 않는다). 증액·재후원 여부만 필요하면 INCREASE_FLAG·REDONATE_FLAG 를 쓴다',
    fmm.INCREASE_FLAG AS fmm.INCREASE_FLAG WITH SYNONYMS ('증액여부', '증액 발생') COMMENT = '공#33 그 달 증액 개발(MM015 ''2'') 사건이 있으면 TRUE',
    fmm.REDONATE_FLAG AS fmm.REDONATE_FLAG WITH SYNONYMS ('재후원여부', '재후원 발생') COMMENT = '공#34 그 달 재후원 개발(MM015 ''4'') 사건이 있으면 TRUE',
    fmm.AMOUNT_BAND1 AS fmm.AMOUNT_BAND1 WITH SYNONYMS ('후원금액대1', '5만원 단위 금액대') COMMENT = '공#72 조회년월 약정금액(활동 후원사업금액 합) 5만원 구간. 값 형식 = ''<하한>~<상한>만원 미만''(예: ''0~5만원 미만''·''5~10만원 미만''). 약정 없음 ⇒ NULL',
    fmm.AMOUNT_BAND2 AS fmm.AMOUNT_BAND2 WITH SYNONYMS ('후원금액대2', '1만원 단위 금액대') COMMENT = '공#73 조회년월 약정금액 1만원 구간. 값 형식 = ''<하한>~<상한>만원 미만''(예: ''3~4만원 미만''). 약정 없음 ⇒ NULL. ⚠️ 문자열 정렬은 숫자 순서가 아니다',
    fmm.PERIOD_BAND1 AS fmm.PERIOD_BAND1 WITH SYNONYMS ('후원기간대1', '5년 단위 기간대') COMMENT = '공#74 최초가입일~조회년월 기간 5년 구간. 값 형식 = ''<하한>~<상한>년 미만''(예: ''0~5년 미만''). 기준일 없음 ⇒ NULL',
    fmm.PERIOD_BAND2 AS fmm.PERIOD_BAND2 WITH SYNONYMS ('후원기간대2', '1년 단위 기간대') COMMENT = '공#75 최초가입일~조회년월 기간 1년 구간. 값 형식 = ''<하한>~<상한>년 미만''(예: ''2~3년 미만''). 기준일 없음 ⇒ NULL',
    member.REGION AS member.REGION WITH SYNONYMS ('지역', '약정시점 지역', '가입시점 지역', '시도') COMMENT = '🔴**약정(개발) 시점의** 회원 지역 라벨 — **현재 거주지가 아니다**(확정). 정본 공#131 · 코드사전 CM018 약칭. 실제값: ''서울''·''경기''·''인천''·''강원''·''대전''·''대구''·''부산''·''광주''·''울산''·''세종''·''충남''·''충북''·''전남''·''전북''·''경남''·''경북''·''제주''·''기타''. 원천 = 개발약정 테이블의 지역코드이며 약정 당시 값이 그대로 굳는다 — 이후 이사해도 갱신되지 않는다. 코드는 DIM_MEMBER.AREA_CD. ⚠️''현재 거주지역별'' 질문에는 답할 수 없다 — 원천에 현재 주소 축이 없다. ⚠️개발약정이 없는 회원(주로 일시회원)은 NULL 이며 ''미상''이 아니라 원천 부재다',
    member.AGE_BAND AS member.AGE_BAND WITH SYNONYMS ('연령대', '약정시점 연령대', '가입시점 연령대') COMMENT = '🔴**약정(개발) 시점의** 회원 연령대 라벨 — **현재 나이가 아니다**(확정). 코드사전 CM014. 실제값: ''10대 미만''·''10대''·''20대''·''30대''·''40대''·''50대''·''60대''·''70대''·''70대 이상''·''단체''·''기업''·''기타''. ✅라벨 매핑은 CM014 사전과 일치 검증됨(우리 쪽 결함 아님). ✅''10대 미만''이 최다인 것도 **실제이며 데이터 오류가 아니다** — 원인은 **편지쓰기대회 계열 캠페인**(희망편지쓰기대회·가족그림편지쓰기대회·세계시민교육편지)이다. 이 계열은 학교·부모 DB 를 통해 **아동 본인 명의로 후원 약정을 맺는 모집 이벤트**여서 20세 미만 비중이 그 외 캠페인보다 압도적으로 높다(개발사건 단위 실측). 따라서 *''왜 10대 미만이 많은가''* 라는 질문에는 **''특정 아동 모집 캠페인(편지쓰기대회 계열) 때문이며 약정 당시 연령 기준이다''** 라고 답하면 된다 — 결측·오류로 설명하지 말 것. 🔴그러나 이 값은 **약정 당시에 굳은 스냅샷**이라 오래된 회원일수록 실제 나이와 벌어진다 — 독립 원천(SND_MEMBER_LIST 연령대 라벨)과 회원 단위 대조 시 불일치가 **전부 노화 방향**이었고, 약정연도가 오래될수록 격차가 단조 증가했다. ⚠️**현재 연령대는 산출 불가**다 — BRONZE 전체에 생년월일 컬럼이 없다. 따라서 ''현재 연령별'' 질문에 이 축으로 답하지 말 것. ⚠️''단체''·''기업''은 나이가 아니라 법인 구분이므로 연령 추이에서 제외할 것 · 원천 부재 시 NULL',
    member.MEMBER_ENROLL_PATH_NAME AS member.ENROLL_PATH_NAME WITH SYNONYMS ('가입경로', '회원 가입경로') COMMENT = '회원 가입경로(MM014 · REG·홈페이지·모바일웹·모바일앱·외주콜센터·CRM) — 회원 마스터 현재값. 일시회원은 (해당없음).',
    member.MEMBER_JOIN_CMMN_BRND_NM AS member.JOIN_CMMN_BRND_NM WITH SYNONYMS ('가입 공통브랜드', '회원 가입 공통브랜드') COMMENT = '회원 가입 시 공통브랜드(MM297) — 회원 마스터 기준.',
    member.MEMBER_RELATNSP_DIV_NAME AS member.RELATNSP_DIV_NAME WITH SYNONYMS ('결연구분', '결연/비결연') COMMENT = '결연구분(MM019 · 결연회원·비결연회원·혼합회원·중단회원) — 회원 마스터 현재값. 일시회원은 NULL(원천 개념 없음).',
    member.MEMBER_SPECL_MNG_NAME AS member.SPECL_MNG_NAME WITH SYNONYMS ('특별관리', '회원 특별관리', '특별관리 구분') COMMENT = '회원 특별관리 구분(MM012 · 일반·더네이버스클럽·더네이버스아너스클럽·평생회원·홍보대사·이사회·블랙리스트·테스트회원 등) — 대부분 「일반」. 🔴 테스트회원 포함 여부를 답변에 밝힌다.',
    member.MEMBER_FIRST_SPONSORSHIP_NAME AS member.FIRST_SPONSORSHIP_NAME WITH SYNONYMS ('최초후원사업', '최초 후원사업') COMMENT = '회원의 최초 후원사업명(회원 마스터 · DIM_SPONSORSHIP 매칭 100%).',
    member.MEMBER_MOBLPHON_STAT_NAME AS member.MOBLPHON_STAT_NAME WITH SYNONYMS ('휴대폰상태', '휴대폰 상태', '연락처 상태') COMMENT = '휴대폰 상태(MM008 · 정상·결번·타인번호) — 회원 마스터 현재값.',
    member.MEMBER_EMAIL_STAT_NAME AS member.EMAIL_STAT_NAME WITH SYNONYMS ('이메일상태', '이메일 상태') COMMENT = '이메일 상태(MM009 · 정상·계정없음·도메인오류) — 원천 코드 0 은 사전에 없어 NULL.',
    member.MEMBER_TSTM_DIV_NAME AS member.TSTM_DIV_NAME WITH SYNONYMS ('TM/TS 거절', '전화 거절구분', 'TM 거절') COMMENT = 'TM/TS 거절구분(MS026 · TM 거절·TS 거절·TMTS거절). 🔴 원천 코드 0(대다수 회원)은 사전에 없어 NULL — 「거절 없음」으로 단정하지 않는다.',
    member.MEMBER_SPECL_MNG2_NAME AS member.SPECL_MNG2_NAME WITH SYNONYMS ('특별관리2', '특별관리 구분2') COMMENT = '회원 특별관리 구분2(MM012) — 값이 있는 회원은 소수다.',
    member.MEMBER_SLRCLD_LRR_NAME AS member.SLRCLD_LRR_NAME WITH SYNONYMS ('생일 양력/음력', '양음력') COMMENT = '생일 양력/음력(CM029 · 양력·음력·불명확).',
    member.MEMBER_REL_NAME AS member.REL_NAME WITH SYNONYMS ('일시회원 관계') COMMENT = '일시회원 관계(CM009 · 본인·부모·배우자·대표자·기업담당자 등). 정기회원은 NULL(원천 개념 없음).',
    -- 🆕 [2026-10-14 O225-C] 그 달 후원 캠페인 속성(단일 캠페인 월만 값 · 다중 월 = (미매핑))
    campaign.CAMPAIGN_NAME AS campaign.CAMPAIGN_NAME WITH SYNONYMS ('캠페인명', '그 달 후원 캠페인', '캠페인') COMMENT = '그 달 후원 캠페인명. 🔴 한 달에 여러 캠페인을 후원한 회원은 (미매핑) — IS_MULTI_CAMPAIGN 으로 구분한다.',
    campaign.CAMPAIGN_TYPE AS campaign.CAMPAIGN_TYPE WITH SYNONYMS ('캠페인 카테고리', '주요캠페인', '캠페인유형') COMMENT = '캠페인 카테고리(MM294 라벨).',
    campaign.DOMESTIC_OVERSEAS AS campaign.DOMESTIC_OVERSEAS WITH SYNONYMS ('국내해외', '국내/해외') COMMENT = '캠페인유형 국내/통합/해외(MM295).',
    campaign.BIZ_CASE_TYPE AS campaign.BIZ_CASE_TYPE WITH SYNONYMS ('사업사례', '사업/사례') COMMENT = '캠페인유형 굿즈/기타/사례/사업(MM296).',
    campaign.INFLOW_PATH AS campaign.INFLOW_PATH WITH SYNONYMS ('인입경로', '회원인입', '개발인입경로') COMMENT = '캠페인 개발인입경로(MM293).',
    campaign.MARKETING_CAMPAIGN AS campaign.MARKETING_CAMPAIGN WITH SYNONYMS ('마케팅캠페인', '마케팅캠페인명') COMMENT = '마케팅캠페인명.',
    campaign.MKTG_CHANNEL_NM AS campaign.MKTG_CHANNEL_NM WITH SYNONYMS ('마케팅채널', '캠페인 채널') COMMENT = '캠페인 마케팅 채널명(TC_MKTNG_DTL_CD C002).',
    campaign.MKTG_UTM_NM AS campaign.MKTG_UTM_NM WITH SYNONYMS ('UTM', 'UTM 캠페인') COMMENT = '캠페인 UTM 라벨(TC_MKTNG_DTL_CD U001).',
    campaign.PARENT_CAMPAIGN_NAME AS campaign.PARENT_CAMPAIGN_NAME WITH SYNONYMS ('상위캠페인', '상위캠페인명') COMMENT = '상위캠페인명. 상위가 없으면 NULL.',
    fmm.IS_MULTI_CAMPAIGN AS fmm.IS_MULTI_CAMPAIGN WITH SYNONYMS ('다중 캠페인 여부', '여러 캠페인 후원') COMMENT = '그 달 여러 캠페인을 후원했는가(TRUE = 캠페인 축 (미매핑)의 사유). 회비 행이 없는 달은 FALSE.',
    -- 🆕 [2026-10-14 O226] 회원 최초 캠페인 축(DIM_MEMBER.FIRST_CAMPAIGN → DIM_CAMPAIGN BK)
    member.FIRST_CAMPAIGN AS member.FIRST_CAMPAIGN WITH SYNONYMS ('최초캠페인코드', '최초 캠페인 코드') COMMENT = '공#29 회원 최초캠페인 원천코드(회원 마스터 현재값). 라벨은 FIRST_CAMPAIGN_NAME. 원천에 값이 없는 회원은 NULL.',
    first_campaign.FIRST_CAMPAIGN_NAME AS first_campaign.CAMPAIGN_NAME WITH SYNONYMS ('최초캠페인', '최초 캠페인', '가입 캠페인', '최초 가입 캠페인') COMMENT = '공#29 회원 최초캠페인명. 🔴 월과 무관한 회원 속성이다 — 「그 달 후원 캠페인」(CAMPAIGN_NAME)과 섞지 않는다. 최초캠페인 코드가 없는 회원은 NULL.',
    first_campaign.FIRST_CAMPAIGN_TYPE AS first_campaign.CAMPAIGN_TYPE WITH SYNONYMS ('최초캠페인 카테고리', '최초 캠페인유형') COMMENT = '최초캠페인의 카테고리(MM294 라벨).',
    first_campaign.FIRST_MARKETING_CAMPAIGN AS first_campaign.MARKETING_CAMPAIGN WITH SYNONYMS ('최초 마케팅캠페인') COMMENT = '최초캠페인의 마케팅캠페인명.'
  )
  METRICS (
    fmm.TOTAL_PAID_ALL   AS SUM(fmm.PAID_FEE)
      WITH SYNONYMS ('총수납액', '수납액', '납입총액') COMMENT = '납입 **총액**(원) = 회비 + 기부금. F(가산). 🔴**「납입회비」가 아니다** — 기저 `PAID_FEE` 는 회비(TM_PM_MBRFEE_ACMSLT)와 기부금(TM_PM_DNTN_DTLS)의 `PAY_AMT` 를 **모두** 합한 값이다. 🔴**납부율의 분자로 쓰지 말 것** — 기부금은 원천에 청구(`RQEST_AMT`) 컬럼이 아예 없어(전건 NULL) 분모 `TOTAL_BILLED_AMT` 에 구조적으로 들어갈 수 없다. 분자에만 더해지면 납부율이 과대해진다(과대. 회비만의 납입액은 **`TOTAL_PAID_FEE_BILLABLE`** 이다. 🟢「총수납액(회비+기부금)」을 명시적으로 물을 때 이 metric 을 쓰고 그때도 기부금 포함임을 밝힌다. 형제 SV `SV_MEMBER_FEE.TOTAL_PAID_ALL` 과 같은 이름·같은 정의다.',
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
      COMMENT = '**공64 납부율(%) 정본** = 회비 납입액 ÷ 회비 청구액 ×100. 분자·분모가 모두 회비라 모집단이 일치한다. 비율(N, 재집계 금지). 🟢납부율을 묻는 질문에는 이 metric 을 쓴다 — **유일한 납부율 정본**이다.',
    fmm.TOTAL_UNPAID_AMT AS SUM(fmm.UNPAID_BILLED_AMT)
      WITH SYNONYMS ('총미납금액', '미납금액', '미납액', '미납액 총액', '못 걷은 금액')
      COMMENT = '**총미납금액(원) 정본** — 정의: 결제상태가 실패(F) 또는 NULL 인 청구액 합. F(가산). 🟢미납금액 질문에는 이 metric 을 쓴다. ⚠️미납은 회수될 수 있으므로 조회 시점 스냅샷이다. 형제 팩트 `SV_MEMBER_FEE.TOTAL_UNPAID_AMT` 와 **같은 이름·같은 식**이므로 전체 합계가 일치해야 한다.',
    fmm.UNPAID_RATIO AS SUM(fmm.UNPAID_BILLED_AMT) / NULLIF(SUM(fmm.BILLED_AMT), 0) * 100
      WITH SYNONYMS ('미납비중', '미납율', '미납률', '미납 비율')
      COMMENT = '**미납비중(%) 정본** = 미납 청구액 ÷ 회비 청구액 ×100. 비율(N, 재집계 금지). 단위는 **퍼센트**다 — 값을 다시 ×100 하지 말 것. ⚠️`100 − 납부율` 과 정확히 같지 않다 — 부분납입 행이 있어 두 값은 서로 보완적이다. 형제 팩트 `SV_MEMBER_FEE.UNPAID_RATIO` 와 **같은 이름·같은 식·같은 단위**다.',
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
      WITH SYNONYMS ('미납(건)', '미납건') COMMENT = '공#36 미납(건) = 월말 미납 회원의 전체 약정금액 ÷ 10,000. 스톡 — 한 달을 지정한다. 미납 판정은 (월말 미납 청구행 존재)와 같다.',
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
      WITH SYNONYMS ('중단율1', '공54', '활동 대비 중단율') COMMENT = '공54 중단율1(%) = 중단(건) ÷ (개발(건) + 연도초활동회원(건)) ×100 — 지표 사전 정의 그대로(현업 지시). 개발(건)은 그 달 값(누계 아님). 비율(N). 🔴 한 달을 지정한다.',
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
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙:
(1) 지표 매핑: 납부율=PAYMENT_RATE_FEE (유일 정본), 납입회비(회비만)=TOTAL_PAID_FEE_BILLABLE, 총수납액(회비+기부금)=TOTAL_PAID_ALL, 총미납금액=TOTAL_UNPAID_AMT (DEC-3 정본), 미납비중(%)=UNPAID_RATIO.
(2) 기간 미지정 시: 데이터 최신 연월 기준 직전 12개월로 한정하며 GROUP BY ROLLUP((연,월)) 반환.
(3) 뷰 라우팅 및 이중계상 방지: 후원사업·납입방식·납입일별 회비 분해는 SV_MEMBER_FEE 로 라우팅. 두 뷰의 회비 measure 를 동일 표에 합산하지 말 것. 캠페인별/후원사업별 활동회원수는 SV_MEMBER_SPONSOR_BIZ 로 라우팅. 🆕 [O225-C] 이 뷰의 campaign 차원은 「그 달 후원 캠페인」이 하나인 회원×월만 연결된다 — 다중 캠페인 월은 (미매핑)이므로 캠페인별 회비 금액(청구·납입·미납)의 정확한 합계는 SV_PAYMENT_BILLING_STATUS(청구 행 단위 귀속)로 답하고, 이 뷰로 캠페인별 값을 낼 때는 (미매핑) 행과 IS_MULTI_CAMPAIGN 비중을 함께 밝힌다.
(4) 사건 연계: 중단(명) 등 사건 기준 지표는 SV_MEMBER_EVENT 를 회원·월로 사전집계하여 병기하며 주차 합계를 월로 더하지 않는다.
(5) 판정 라벨 [집계필요]: 월간 중단보고의 「중단(명)」은 이 뷰의 플래그 합이 아니라 SV_MEMBER_EVENT 의 중단 고유회원수로 답한다. 회원-월 요약과 사건 집계는 표를 분리하고 각 표의 grain 을 밝힌다.
(6) 판정 라벨 [형제팩트중복]: 납입방식·「납입(원)」은 이 뷰가 앵커가 아니다 — SV_MEMBER_FEE 를 앵커로 답하고 두 뷰를 한 표에 합치지 않는다.
(7) 판정 라벨 [배분규칙필요]: 발송·사건 grain 으로 이 뷰의 회원월 measure(개발/중단 건·명)를 요구받으면 SQL 을 만들지 않고 「배분(귀속) 규칙이 필요한 업무 판단 사안」이라고 답한다. 자기 grain(월×회원) 질의는 정상 답변한다.
(8) 스톡·누계 지표(ACTIVE_*·ACTIVE_CUM_*·UNPAID_CNT_SUM·AVG_SPONSOR_MONTHS·AVG_PAID_MONTHS)는 월별로 GROUP BY 하거나 조회월 하나로 필터한다 — 여러 달을 한 값으로 합산하지 않는다. 연간 값은 12월(또는 최신월) 값을 쓴다.
(9) 금액대·기간대(AMOUNT_BAND*·PERIOD_BAND*)는 문자열이라 정렬이 숫자 순서가 아니다 — 결과를 하한 숫자 기준으로 정렬해 제시한다.';

-- SV_MEMBER_EVENT ← 05_02_SV_DDL_MEMBER_EVENT.sql
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_EVENT
  TABLES (
    fme AS GN_DW.GOLD.FACT_MEMBER_EVENT
      WITH SYNONYMS ('회원 상태전이', '개발중단 사건', '생애주기 사건')
      COMMENT = '회원 생애주기 상태전이 사건 분석 (base: GOLD.FACT_MEMBER_EVENT). [Grain: 사건일 × 회원 × 전이유형]. [활성 지표: 개발(신규/증액/재후원)/중단 건수·금액]. [주의: 집계필요 배분규칙필요 앵커_경합 방지]. [원천: CRM → BRONZE_CRM → SILVER.CRM_MEMBER_DEV ∪ CRM_MEMBER_DISCONTINUE → GOLD.FACT_MEMBER_EVENT].',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '일자', '사건일')
      COMMENT = '일 차원. [원천] ETL 생성(달력, 팩트 일자범위 기반) — 업무 원천 시스템 없음.',
    member AS GN_DW.GOLD.DIM_MEMBER
      PRIMARY KEY (MEMBER_DK)
      WITH SYNONYMS ('회원', '회원속성')
      COMMENT = '정규 회원 마스터 차원 (회원 1명 = 1행 · MEMBER_DK 유일). 🔴 IS_CURRENT 컬럼은 없다 — 상태 이력이 필요하면 DIM_MEMBER_STATUS_HISTORY 를 쓴다. 불변/현재 속성 전용. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM · SILVER=CRM_MEMBER · GOLD=DIM_MEMBER.',
    campaign AS GN_DW.GOLD.DIM_CAMPAIGN
      PRIMARY KEY (CAMPAIGN_SK)
      WITH SYNONYMS ('캠페인', '모금 캠페인')
      COMMENT = '캠페인 차원. PK 유일이라 조인이 행수를 늘리지 않는다. 🔴개발(DEV)행에만 배선된다 — 중단(STOP)행은 전건 ''(미매핑)''(SK=0)이다. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: TM_MM_CMPGN · SILVER=CRM_CAMPAIGN.',
    sponsorship AS GN_DW.GOLD.DIM_SPONSORSHIP
      PRIMARY KEY (SPONSORSHIP_SK)
      WITH SYNONYMS ('후원사업', '사업')
      COMMENT = '사건의 후원사업 차원. PK 유일이라 조인이 행수를 늘리지 않는다. 🟢 개발(DEV)행 전건 · 중단(STOP)행 대부분 배선 — 중단행은 **끊은 사업**이다(일부 미배선행은 ''(미매핑)''). 데려온(획득) 사업은 acq 축으로 병기한다(L-2). ⚠️**회비 납입 대상 후원사업(SV_MEMBER_FEE)과 다른 축**이고, **획득 시점 후원사업(SV_MEMBER_COHORT)과도 다른 축**이다 — 세 축을 합산하지 말 것. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: TM_MM_FDRM_MBER_DVLP_AMT(SPNSR_BSNS_ID) + TM_CM_SPNSR_BSNS_INFO · SILVER=CRM_MEMBER_DEV + CRM_SPONSOR_BIZ.',
    acq AS GN_DW.GOLD.DIM_MEMBER_ACQUISITION
      PRIMARY KEY (MEMBER_DK)
      WITH SYNONYMS ('획득', '가입 시점')
      COMMENT = '회원 획득(최초 가입) 시점 차원 — 회원당 한 행. 사건 시점 축과 다르다(합산 금지). [원천] CRM → GOLD.DIM_MEMBER_ACQUISITION.',
    org AS GN_DW.GOLD.DIM_ORG
      PRIMARY KEY (ORG_SK)
      WITH SYNONYMS ('조직', '부서', '실적부서')
      COMMENT = '조직 차원(SCD1, 부서 grain). PK 유일이라 조인이 행수를 늘리지 않는다. 🔴개발(DEV)행에만 배선된다 — 중단(STOP)행은 원천이 등록부서만 보유해 역할이 달라 전건 ''(미매핑)''(SK=0)이다(결정 대기). [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM: TM_CM_DEPT_INFO · SILVER=CRM_ORG.'
  )
  RELATIONSHIPS (
    fme_to_date     AS fme (DATE_SK)     REFERENCES date,
    fme_to_member   AS fme (MEMBER_DK)   REFERENCES member,
    fme_to_campaign AS fme (CAMPAIGN_SK) REFERENCES campaign,
    fme_to_org      AS fme (ORG_SK)      REFERENCES org,
    fme_to_spb      AS fme (SPONSORSHIP_SK) REFERENCES sponsorship,
    fme_to_acq      AS fme (MEMBER_DK) REFERENCES acq
  )
  DIMENSIONS (
    sponsorship.SPONSORSHIP AS sponsorship.SPONSORSHIP_NAME
      WITH SYNONYMS ('후원사업', '후원사업명', '사업', '사업명')
      COMMENT = '사건의 후원사업명(정본 #123). 개발 행 = 개발한 사업 · 🟢 중단 행 = **끊은 사업**(중단 보고 기본 축 · 사용자 결정 L-2) — 일부 미배선 중단행은 ''(미매핑)''. 데려온 사업은 ACQ_SPONSORSHIP 으로 나란히 보인다(두 축 합계는 다르다 · 합산 금지). ⚠️ **같은 라벨이 세 축이다**: ① 이 축 = **사건(개발) 시점** 후원사업 ② `SV_MEMBER_FEE` = **회비 납입 대상** 후원사업 ③ `SV_MEMBER_COHORT` = **획득 시점** 후원사업. 세 축의 값은 서로 다르며 합산·비교하면 조용히 틀린다 — 어느 축으로 답했는지 반드시 밝힌다. ⚠️ 목표(FACT_TARGET_MEMBER_DEV)에는 후원사업 축이 없어 **후원사업별 목표 대비 달성률은 불가**하다',
    sponsorship.SPONSORSHIP_CPR_DIV_NM AS sponsorship.CPR_DIV_NM
      WITH SYNONYMS ('법인', '법인구분', '사단법인', '사회복지법인', '사단', '사복', '후원사업 법인구분')
      COMMENT = '🟢 **법인 질의의 기본 축** — 사건 후원사업의 법인구분(CM019 · 사용자 결정 = MSTR 기준). 실제값 = ''사단''(사단법인)·''사복''(사회복지법인) · 코드사전 같은 레벨에 ''통합''도 있으나 현재 후원사업에는 없다. 「사단법인 ○○팀」 같은 법인 조건은 **이 축으로 건다**. 🔴 세부캠페인 법인(CPR_DIV_NM)과 다른 축이다 — 그 축으로 답하면 MSTR 과 크게 어긋난다. ⚠️ 중단(STOP) 미배선 행은 NULL.',
    acq.ACQ_SPONSORSHIP AS acq.ACQ_SPONSORSHIP_NAME
      WITH SYNONYMS ('데려온 사업', '가입 후원사업', '획득 후원사업')
      COMMENT = '회원을 처음 가입시킨(획득) 후원사업 — L-2 병기 축. 중단 보고의 기본은 SPONSORSHIP(끊은 사업)이고 이 축은 나란히 보여준다. 🔴 두 축의 합계는 서로 다르며 더하거나 비교 기준을 섞지 않는다 · 획득 정보가 없는 회원은 NULL.',
    org.ORG_DEPARTMENT AS org.DEPARTMENT
      WITH SYNONYMS ('부서', '부서명', '실적부서', '담당부서')
      COMMENT = '부서명(정본 #116). 실적부서(원천 ACMSLT_DEPT_CD) 기준 귀속. 🔴개발(DEV) 사건 전용 — 중단(STOP) 행은 전건 ''(미매핑)''이므로 「부서별 중단건」으로 읽으면 틀린다. ⚠️본부/지부는 ORG_DIV_GROUP·ORG_DIV 를 쓴다 — 부서명에서 상위 조직을 추측하지 말 것. 팀·법인 단위는 산출 불가. 🔴 폐지된 과거 실적부서는 **옛 부서명 그대로** 나온다(현재 부서로 연결하지 않는다). ⚠️부서별 **목표 대비 실적·달성율**은 이 SV 가 아니라 SV_DEV_ACHIEVEMENT(월 conform) 소관이다.',
    org.ORG_DIV_GROUP AS org.ACMSLT_DIV_GROUP_NM
      WITH SYNONYMS ('본부지부구분', '본부/지부 구분', '조직구분', '실적 구분')
      COMMENT = '실적 본부/지부 **구분**(실적트리 부서코드 접두 ZB 노드). 실제값 8종: ''본부''·''지부''·''시도본부''·''지부외''·''지부(사복)''·''본부(사복)''·''협력시설''·''시도본부 및 중앙'' + NULL(미도달). 🟢 **협력시설(보육원·재활원 등)은 대부분 ''협력시설''·''지부외'' 아래에 있다** — 두 값은 본부/지부 조직이 아닌 시설·기타 묶음이므로 「본부/지부 실적」 질의에서는 따로 표시한다(⚠️ ''지부외''에는 시설이 아닌 부서도 섞여 있고 시설 일부는 다른 구분 아래에 있다 — 시설 전수로 단정하지 말 것). 🔴 개발(DEV) 사건 전용(ORG_DEPARTMENT 와 같은 제약).',
    org.ORG_DIV AS org.ACMSLT_DIV_NM
      WITH SYNONYMS ('본부', '지부', '본부지부', '본부/지부', '실적지부')
      COMMENT = '실적 본부/지부 **단위명**(실적트리 부서코드 접두 ZC 노드 · · 예: 서울·경기1·대구경북·나눔마케팅본부). 🔴🔴 **같은 이름이 여러 구분에 있다**(예: 서울 = 지부·시도본부·지부외) — 반드시 ORG_DIV_GROUP 과 함께 그룹핑한다(이름만으로 합치면 서로 다른 조직이 섞인다). 도달 못 한 부서는 NULL. 🔴 개발(DEV) 사건 전용.',
    org.ORG_DIV_GROUP_CODE AS org.ACMSLT_DIV_GROUP_ID
      WITH SYNONYMS ('본부지부구분코드', '조직구분코드')
      COMMENT = '실적 본부/지부 구분 **부서코드**(ZB 접두 · 예: ZB000002). ORG_DIV_GROUP 과 1:1 — 🔴 본부/지부를 보여줄 때는 이름과 코드를 **함께** 표시한다(현업 회신 41.3).',
    org.ORG_DIV_CODE AS org.ACMSLT_DIV_ID
      WITH SYNONYMS ('본부지부코드', '지부코드', '본부코드')
      COMMENT = '실적 본부/지부 단위 **부서코드**(ZC 접두 · 예: ZC000019). 🔴 같은 이름(ORG_DIV)이라도 코드가 다르면 **다른 조직**이다 — 합치지 말고 코드로 나눠 보여준다(현업 회신 41.3). 이름과 코드를 함께 표시한다.',
    org.IS_ACTIVE_ORG AS org.IS_ACTIVE_ORG
      WITH SYNONYMS ('현재 조직', '활성 조직', '현행 조직도')
      COMMENT = '현재 조직도(조직표 gni_실적부서.csv · 조직도_20260914.csv) 소속 여부(TRUE/FALSE). 🟢 **실적 집계는 이 필터 없이 전체**가 기본이다(과거·협력시설 부서의 실적도 실적이다) — 사용자가 「현재 조직 기준」을 명시할 때만 TRUE 로 거른다.',
    org.ORG_PATH AS org.ORG_PATH
      WITH SYNONYMS ('조직 경로', '부서 경로')
      COMMENT = '조직도 부서 경로(조직 계통 UPPER_DEPT_ID · 루트 제외). 🔴 **실적 계통이 아니다** — 실적 본부/지부는 ORG_DIV_GROUP·ORG_DIV 를 쓴다(두 계통은 다르다). 현재 조직이 아니면 NULL 일 수 있다.',
    date.EVENT_DATE   AS date.FULL_DATE     WITH SYNONYMS ('사건일', '발생일', '일자', '날짜') COMMENT = '상태전이 발생일',
    date.FULL_DATE AS date.FULL_DATE  COMMENT = '달력 날짜(DIM_DATE.FULL_DATE) — EVENT_DATE 와 같은 값이다(Analyst 가 추측하는 식별자를 실재화). 둘 중 하나만 쓴다.',
    date.CAL_YEAR     AS date.YEAR          WITH SYNONYMS ('연도', '년')   COMMENT = '연도',
    date.CAL_MONTH    AS date.MONTH         WITH SYNONYMS ('월')          COMMENT = '월(1~12)',
    date.YEAR AS date.YEAR    COMMENT = '연도(DIM_DATE.YEAR) — CAL_YEAR 와 같은 값(Analyst 가 추측하는 식별자를 실재화). 둘 중 하나만 쓴다.',
    date.MONTH AS date.MONTH  COMMENT = '월(DIM_DATE.MONTH) — CAL_MONTH 와 같은 값(추측 식별자 실재화). 둘 중 하나만 쓴다.',
    date.WEEK_OF_YEAR AS date.WEEK_OF_YEAR  WITH SYNONYMS ('주차', '주')   COMMENT = '연중 주차',
    date.DAY_OF_WEEK  AS date.DAY_OF_WEEK   WITH SYNONYMS ('요일')        COMMENT = '요일 코드. 실제값 7종: ''0''(일요일)·''1''(월요일)·''2''(화요일)·''3''(수요일)·''4''(목요일)·''5''(금요일)·''6''(토요일). NULL 없음. 🔴요일 이름(영문 약칭·한글)으로 필터하지 말 것 — 저장값은 숫자 코드다. ⚠️코드 ''0''(일요일)에는 달력 시드 행이 섞여 있어 일요일 집계가 그만큼 과대다 — 규모는 정본 문서를 참조하고 이 값으로 일요일 지표를 단정하지 말 것',
    fme.EVENT_TYPE    AS fme.EVENT_TYPE     WITH SYNONYMS ('원천계통', '사건원천') COMMENT = '원천 계통 구분. 실제값 2종뿐: ''DEV''(개발원천) / ''STOP''(중단원천). ⚠ 상태(신규·증액·감액·재후원·후원중단)는 이 컬럼이 아니라 DVLP_DIV_NM 을 쓴다 — ''증액'' 등 상태값으로 이 컬럼을 필터하면 0행이 반환된다.',
    fme.DVLP_DIV_NM   AS fme.DVLP_DIV_NM    WITH SYNONYMS ('개발구분', '상태구분', '증액감액구분', '개발구분명') COMMENT = '개발구분(정본 MM015). 실제값 5종: ''신규''·''증액''·''감액''·''재후원''·''후원중단''. 중단원천 행은 NULL. ⚠ ''후원중단''은 EVENT_TYPE=''STOP'' 과 동일 사건이 두 원천에 중복 존재 → 두 축 합산 금지(중복',
    fme.DVLP_DIV_CD   AS fme.DVLP_DIV_CD    WITH SYNONYMS ('개발구분코드') COMMENT = '개발구분 원천코드(1=신규 2=증액 3=감액 4=재후원 5=후원중단). 라벨은 DVLP_DIV_NM. 실제값 5종: ''1''·''2''·''3''·''4''·''5'' + NULL',
    fme.JOIN_DATE     AS fme.JOIN_DATE      WITH SYNONYMS ('사건 가입일')      COMMENT = '사건 행의 가입일(원천 그대로). 🔴🔴 **회원 최초 가입일이 아니다** — 개발원천 「후원중단」 행은 이 값이 사건일(=중단일)이고, 중단원천(STOP) 행은 전건 NULL 이다. 「가입연도별·가입일 기준」 질문에는 이 컬럼을 쓰지 말고 member.FIRST_JOIN_DATE · member.FIRST_JOIN_YEAR 를 쓴다',
    fme.STOP_DATE     AS fme.STOP_DATE      WITH SYNONYMS ('중단일', '해지일') COMMENT = '회원 중단일. 중단원천(STOP) 행은 사건일과 같고, 개발원천 「후원중단」 행은 NULL 이다(그 행의 중단일은 사건일 date.EVENT_DATE 로 본다)',
    member.FIRST_JOIN_DATE AS member.FIRST_JOIN_DATE WITH SYNONYMS ('가입일', '최초가입일', '회원 가입일') COMMENT = '회원 최초가입일 = 회원번호 생성일(정본 공#28 · 회원 마스터 현재값). 중단·개발 양쪽 행에 채워진다(2026-06 중단 행 100%). 「가입연도별」 분해의 정본 축',
    member.FIRST_JOIN_YEAR AS YEAR(member.FIRST_JOIN_DATE) WITH SYNONYMS ('가입연도', '가입년도', '최초가입연도') COMMENT = '회원 최초가입 연도(FIRST_JOIN_DATE 의 연도). 「중단회원 가입연도별」 질문은 이 축과 중단 고유회원수로 답한다',
    fme.NEW_EXISTING_FLAG AS fme.NEW_EXISTING_FLAG WITH SYNONYMS ('신규기존구분', '신규/기존', '신규기존') COMMENT = ' 공#113 신규기존구분 — 사건 연도가 회원 최초가입 연도(회원 등록일·최초 개발일·첫 청구월 중 가장 이른 날)와 같으면 ''신규'', 이후면 ''기존''. 실제값 2종: ''신규''·''기존'' + NULL(기준일이 없는 회원). 🔴 공56·57 신규/기존 중단율의 분해 축이다 — 중단(STOP)·개발(DEV) 양쪽에 채워진다',
    fme.STOP_REASON_NM  AS fme.STOP_REASON_NM  WITH SYNONYMS ('중단사유', '해지사유', '중단이유') COMMENT = '중단사유 라벨(정본 MM005 단일 코드체계 — 혼입 없음). 실제값 예: ''개인(경제적)사유''·''장기미납''·''신규미납''·''다른곳지원''·''명의변경''·''아동퇴소''·''회원항의''·''기타''. 🔴**중단(STOP) 사건 전용 축**이다 — 개발(DEV) 행은 원천에 사유가 없어 NULL 이다. 따라서 중단 지표(중단건·중단회원수)와 함께 쓸 것이며, 개발 지표와 교차하면 전건 NULL 로 뭉개진다',
    fme.STOP_CHANNEL_NM AS fme.STOP_CHANNEL_NM WITH SYNONYMS ('중단경로', '해지경로', '중단채널') COMMENT = '중단 접수경로 라벨. 🔴중단(STOP) 사건 전용 — 개발 행은 NULL. 중단사유와 같은 원천 행에서 온다. 실제값 3종: ''CRM''·''홈페이지''·''SYSTEM'' + NULL',
    fme.AGE_BAND_AT_EVENT AS fme.AGE_BAND_AT_EVENT WITH SYNONYMS ('연령대', '나이대', '사건시점 연령대', '약정시점 연령대', '개발시점 연령대') COMMENT = '🔴**개발약정(사건) 당시의** 회원 연령대 — **현재 나이가 아니다**. 코드사전 CM014. 실제값: ''10대 미만''·''10대''·''20대''·''30대''·''40대''·''50대''·''60대''·''70대''·''70대 이상''·''단체''·''기업''·''기타''. ✅라벨 매핑은 CM014 사전과 일치 검증됨. ✅''10대 미만''이 최다인 것도 **실제이며 데이터 오류가 아니다** — 원인은 **편지쓰기대회 계열 캠페인**(희망편지쓰기대회·가족그림편지쓰기대회·세계시민교육편지)이며 학교·부모 DB 를 통해 **아동 본인 명의로 후원 약정을 맺는 모집 이벤트**다. 🟢 **이 SV 에서 직접 확인할 수 있다** — 이 차원을 CAMPAIGN_NAME 과 교차하면 해당 계열의 ''10대 미만'' 비중이 그 외 캠페인보다 압도적으로 높은 것이 재현된다. 결측·기본값 오염으로 설명하지 말 것. ⚠️SV_MEMBER_MONTHLY 의 MEMBER_REGION_AT_PLEDGE 와 **다른 축**이다 — 그쪽은 회원 현재행이 담은 *최근* 약정 스냅샷이고 이 차원은 *그 사건* 당시 값이라 값이 다를 수 있다(사건시점이 정확하다). 🔴개발(DEV) 사건 전용 — 중단(STOP) 행은 원천에 컬럼이 없어 NULL 이며 ''미상''이 아니다',
    fme.AGE_AT_EVENT      AS fme.AGE_AT_EVENT      WITH SYNONYMS ('연령대코드') COMMENT = '사건시점 연령대 원천코드(CM014 1=10대 미만 2=10대 3=20대 4=30대 5=40대 6=50대 7=60대 8=70대 9=70대 이상 10=단체 11=기업 12=기타). 🔴연속형 나이가 아니므로 평균·구간 재계산 금지. 라벨은 AGE_BAND_AT_EVENT. 개발(DEV) 사건 전용',
    fme.REGION_AT_EVENT   AS fme.REGION_AT_EVENT   WITH SYNONYMS ('지역', '시도', '사건시점 지역', '약정시점 지역') COMMENT = '🔴**개발약정(사건) 당시의** 회원 지역 라벨 — **현재 거주지가 아니다**. 정본 공#131 · 코드사전 CM018 약칭. 실제값: ''서울''·''경기''·''인천''·''강원''·''대전''·''대구''·''부산''·''광주''·''울산''·''세종''·''충남''·''충북''·''전남''·''전북''·''경남''·''경북''·''제주''·''기타''. ⚠️''현재 거주지역별'' 질문에는 답할 수 없다 — BRONZE 에 현주소 축이 없다. ⚠️센티넬 코드 ''0''은 사전에 라벨이 없어 NULL 이다 — ''미상''으로 창작하지 말 것. ⚠️SV_MEMBER_MONTHLY 의 MEMBER_REGION_AT_PLEDGE(최근 약정 스냅샷)와 **다른 축**이며 이사 등으로 값이 다를 수 있다. 🔴개발(DEV) 사건 전용 — 중단 행은 NULL',
    fme.AREA_CD_AT_EVENT  AS fme.AREA_CD_AT_EVENT  WITH SYNONYMS ('지역코드') COMMENT = '사건시점 지역 원천코드(CM018 + 라벨 없는 센티넬 ''0''). 라벨은 REGION_AT_EVENT. 개발(DEV) 사건 전용. 실제값 19종: ''0''·''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''·''9''·''10''·''11''·''12''·''13''·''14''·''15''·''16''·''17''·''18'' + NULL',
    member.GENDER_NAME   AS member.GENDER_NAME   WITH SYNONYMS ('성별')     COMMENT = '회원 성별 — 정본 공#130. 실제값 5종: ''남자''·''여자''·''기업''·''단체''·''기타''(CM017 라벨).',
    member.SEX           AS member.SEX           WITH SYNONYMS ('성별코드') COMMENT = '성별 원천코드(CM013). 이 차원의 실제값 8종 1~8 (+미기재 NULL). ⚠회원 마스터에 ''0''은 없다 — sentinel ''0''은 개발·증감 원천에만 존재하므로 ''0'' 조건은 0행. 라벨은 GENDER_NAME(분석)·SEX_NM(원천)',
    member.SEX_NM        AS member.SEX_NM        WITH SYNONYMS ('성별상세', '국내외국인') COMMENT = 'CM013 원천 라벨 8종(국내(남자)·외국인(여자)·단체·기업 등). 국내/외국인 구분용. 실제값 8종: ''기업''·''기타''·''단체''·''국내(남자)''·''국내(여자)''·''외국인(기타)''·''외국인(남자)''·''외국인(여자)'' + NULL',
    member.MEMBER_STATUS_NAME AS member.MEMBER_STATUS_NAME WITH SYNONYMS ('회원상태') COMMENT = '현재 회원상태 라벨(공#132, MM010). 실제값 13종: ''활동회원''·''신규미납1''·''신규미납2''·''신규미납3''·''신규미납4''·''신규미납5''·''장기미납1''·''장기미납2''·''장기미납3''·''장기미납4''·''장기미납5''·''후원중단''·''(해당없음)''. 🔴 **라벨에 숫자 접두가 없다** — 상태 코드번호를 라벨 앞에 붙인 형태로 필터하면 0행 무증상 오답이다. ⚠️ ''(해당없음)''은 일시회원이며 정기후원 상태축의 **구조적 부재**다 — 결측이 아니다',
    member.MBER_STAT_CD  AS member.MBER_STAT_CD  WITH SYNONYMS ('회원상태코드') COMMENT = '회원상태 원천코드(MM010 1~12). 실제값 12종: ''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''·''9''·''10''·''11''·''12'' + NULL',
    member.MEMBER_TYPE_NAME AS member.MEMBER_TYPE_NAME WITH SYNONYMS ('회원구분') COMMENT = '회원구분 라벨(MM018): 개인·기업·단체. 실제값 3종: ''개인''·''기업''·''단체''',
    member.MBER_DIV_CD   AS member.MBER_DIV_CD   WITH SYNONYMS ('회원구분코드') COMMENT = '회원구분 원천코드(MM018). 실제값 3종: ''1''·''2''·''3''',
    member.CHRCTR_RECPTN_YN AS member.CHRCTR_RECPTN_YN WITH SYNONYMS ('문자수신여부', '문자수신', 'SMS 수신동의') COMMENT = '회원 문자수신 여부(현재 마스터 스냅샷 · 사건 시점 값이 아니다). 실제값 2종: ''Y''·''N'' + NULL. 🔴 과거 사건을 이 축으로 나누면 「사건 당시 수신 상태」가 아니라 **현재 상태**로 나뉜다 — 그 전제를 밝힌다. ⚠️ NULL 은 원천 미입력이며 ''N'' 으로 읽지 않는다',
    campaign.CAMPAIGN_NAME      AS campaign.CAMPAIGN_NAME      WITH SYNONYMS ('캠페인', '캠페인명', '모금캠페인') COMMENT = '캠페인명. 🔴 이 SV 에서 캠페인은 **사건 자신의 캠페인**이다 — 개발(DEV) 행은 약정 캠페인, 개발원천 후원중단(DVLP_DIV_NM=''후원중단'') 행은 **중단 시점 캠페인**이다. ⚠️ 중단원천(EVENT_TYPE=''STOP'') 행은 원천에 캠페인이 없어 ''(미매핑)''으로 뭉개진다 → **중단 규모를 캠페인별로 볼 때는 TOTAL_STOP_CNT 가 아니라 TOTAL_CAMPAIGN_STOP_CNT 를 쓴다**(2026-08-05). 🟢 개발원천 후원중단 행은 캠페인을 보유하므로 캠페인별 중단건을 답할 수 있다. 🔴 캠페인별 **중단률(비율)**은 이 SV 가 아니라 **SV_MEMBER_COHORT** 다(분모가 획득 회원수여야 비율이 성립한다)',
    campaign.CAMPAIGN_BRAND     AS campaign.BRAND              WITH SYNONYMS ('브랜드', '브랜드명', '캠페인 브랜드') COMMENT = '캠페인 브랜드명(원천 COMMENT = 브랜드). [원천 컬럼명 원칙] 「브랜드」는 이 축이다 — 「공통브랜드」를 말할 때만 CMMN_BRND_NM 을 쓴다',
    campaign.PARENT_CAMPAIGN_NAME AS campaign.PARENT_CAMPAIGN_NAME WITH SYNONYMS ('상위캠페인', '상위캠페인명', '캠페인 그룹') COMMENT = '상위캠페인명. ⚠️ 상위가 없는 캠페인은 NULL 이며 ''(미매핑)''이 아니다. ⚠️ 캠페인 카테고리(CAMPAIGN_TYPE)와 다른 축이다',
    campaign.PROMO_METHOD_NAME  AS campaign.PROMO_METHOD_NAME  WITH SYNONYMS ('홍보방법', '광고방법', '매체', '홍보수단') COMMENT = '홍보방법 라벨(코드사전 CM008, 2026-08-05 신설). 실제값 계열: ''PC배너광고(DA)''·''M배너광고(DA)''·''PC검색광고(SA)''·''M검색광고(SA)''·''TM''·''TS''·''PC캠페인-홈페이지''·''M캠페인-홈페이지''·''온라인''·''오프라인''·''APP캠페인''·''기존회원메일''·''기타''. 🔴 원천 `PR_MTH_CD` 는 숫자 코드이다 — 코드로 필터하면 0행이 반환된다. 반드시 이 라벨로 필터·그루핑한다. ⚠️ 유입경로와 다른 축이다',
    fme.CAMPAIGN_TYPE      AS fme.CMPGN_CTGR_NM_AT_EVENT      WITH SYNONYMS ('캠페인카테고리', '주요캠페인', '캠페인 종류', '캠페인 소분류') COMMENT = '캠페인 카테고리(MM294 라벨) — 현업이 말하는 **''주요캠페인''** 축이다. 「캠페인카테고리」·「주요캠페인」을 명시할 때만 쓴다 — 「캠페인유형」은 DOMESTIC_OVERSEAS · 「캠페인유형2」는 BIZ_CASE_TYPE 이다. 🔴적재 시점 동결값(구 campaign.CAMPAIGN_TYPE 대체). 실제값 예: ''초등캠페인''·''국내사례캠페인''·''굿즈캠페인''·''해외캠페인''·''기타 영상광고''·''홈페이지(PC/모바일)''·''희망TV''·''인바운드''·''가두캠페인''·''대학생캠페인''. 개발(DEV) 사건 전용 — 중단(STOP) 행은 NULL. 🟢 **캠페인카테고리별 중단**은 중단원천(STOP 행)이 아니라 개발원천 후원중단 행으로 답한다 = 중단(명) CAMPAIGN_STOP_MEMBER_COUNT · 중단(건) TOTAL_CAMPAIGN_STOP_CNT ⇒ 「축 없음」으로 답하지 않는다',
    fme.CAMPAIGN_INFLOW_PATH AS fme.MBER_INFLOW_PATH_NM_AT_EVENT WITH SYNONYMS ('개발인입경로', '인입경로', '개발 인입경로', '모집채널', '유입경로') COMMENT = '**개발인입경로**(MM293 라벨 · 캠페인의 모집 채널). 「개발인입경로」·「인입경로」 질문의 축이다. 🔴적재 시점 동결값(구 campaign.INFLOW_PATH 대체). 실제값 12종: ''교육기관''·''기타 기업개발''·''뉴미디어''·''대면모금''·''디지털''·''방송''·''영상광고''·''오프라인''·''일시''·''재송출''·''지역개발''·''콜개발'' + NULL. ⚠️ 이 축은 채널이며 「주요캠페인」이 아니다 — 주요캠페인은 CAMPAIGN_TYPE 이다. ⚠️ 회원 가입경로(회원 속성)와도 다른 축이다. 개발(DEV) 사건 전용 — 중단(STOP) 행은 NULL',
    fme.DOMESTIC_OVERSEAS  AS fme.CMPGN_TYPE1_NM_AT_EVENT     WITH SYNONYMS ('캠페인유형', '캠페인 유형', '캠페인유형(국내/해외)', '국내해외', '국내외') COMMENT = '**캠페인유형**(원천 COMMENT = 캠페인유형(국내/해외) · MM295) — 「캠페인유형」 질문의 축이다. 🔴적재 시점 동결값(구 campaign.DOMESTIC_OVERSEAS 대체). 실제값 4종: ''국내''·''해외''·''통합''·''전체사업'' + NULL. ⚠️ ''통합''과 ''전체사업''은 서로 다른 값이다 — 하나로 묶지 말고 원천 라벨 그대로 노출한다. 개발(DEV) 사건 전용 — 중단(STOP) 행은 NULL',
    fme.BIZ_CASE_TYPE      AS fme.CMPGN_TYPE2_NM_AT_EVENT     WITH SYNONYMS ('캠페인유형2', '캠페인유형(사업/사례)', '사업사례구분', '사업/사례') COMMENT = '**캠페인유형2**(원천 COMMENT = 캠페인유형(사업/사례) · MM296) — 「캠페인유형2」 질문의 축이다. 「캠페인유형」은 DOMESTIC_OVERSEAS(국내/해외)다. 캠페인 사업/사례 구분. 🔴적재 시점 동결값(구 campaign.BIZ_CASE_TYPE 대체). 실제값 4종: ''사례''·''사업''·''굿즈''·''기타''. 개발(DEV) 사건 전용 — 중단(STOP) 행은 NULL',
    fme.MARKETING_CAMPAIGN AS fme.MKTG_CMPGN_NM_AT_EVENT      WITH SYNONYMS ('마케팅캠페인', '마케팅 캠페인명') COMMENT = '마케팅캠페인명. 🔴적재 시점 동결값(구 campaign.MARKETING_CAMPAIGN 대체). 카디널리티가 높다 — 부분 일치로 추측하지 말고 실제값을 조회해 확인한다. 개발(DEV) 사건 전용 — 중단(STOP) 행은 NULL',
    fme.CMMN_BRND_NM       AS fme.CMMN_BRND_NM_AT_EVENT       WITH SYNONYMS ('공통브랜드', '공통 브랜드') COMMENT = '공통브랜드 라벨(코드사전 MM297). 「공통브랜드」를 말할 때 쓴다(「브랜드」는 CAMPAIGN_BRAND). 🔴적재 시점 동결값(구 campaign.CMMN_BRND_NM 대체). 실제값 16종: ''교육기관''·''기업''·''뉴미디어''·''대면모금''·''디지털''·''마케팅콜개발''·''방송''·''영상광고''·''재송출''·''지역개발''·''직원개발''·''콜개발''·''회원 기타''·''회원 오프라인개발''·''회원 온라인개발''·''회원 콜개발'' + NULL. ⚠️라벨이 CAMPAIGN_INFLOW_PATH(MM293 개발인입경로)와 상당 중복되나 현업 확인상 별도 축으로 유지한다. 🔴두 축의 열거가 겹쳐 보이더라도 값 집합은 다르다 — 한쪽 목록으로 다른 쪽을 필터하지 말 것. 개발(DEV) 사건 전용 — 중단(STOP) 행은 NULL',
    fme.MKTG_UTM_NM        AS fme.MKTG_UTM_NM_AT_EVENT        WITH SYNONYMS ('UTM', 'UTM 라벨', '마케팅 UTM') COMMENT = 'UTM 라벨 — 코드사전이 아니라 원천 TM_CM_MKTNG_UTM(MK_UTM/MK_UTM_NM)과 연동된 값. 🔴적재 시점 동결값(구 campaign.MKTG_UTM_NM 대체). ⚠️원천 코드사전 매핑률이 낮아 다수 행이 NULL이다 — 결측이 아니라 미등재 코드다(채움 비율은 규칙7 상 여기 적지 않는다 · 조회로 확인하고 UTM별 분해가 부분집합임을 밝힐 것 ·. 개발(DEV) 사건 전용 — 중단(STOP) 행은 NULL',
    fme.SPNSR_DIV_NM       AS fme.SPNSR_DIV_NM_AT_EVENT       WITH SYNONYMS ('세부캠페인 후원구분', '캠페인 후원구분') COMMENT = '세부캠페인 후원구분 라벨(CM035). 🔴적재 시점 동결값(구 campaign.SPNSR_DIV_NM 대체). 실제값 2종: ''정기후원''·''일시후원'' + NULL. ⚠️ SPONSORSHIP.SPONSORSHIP_DIV_NAME(후원사업 축 CM035)과 코드사전은 같지만 적용 대상이 다르다 — 이 축은 세부캠페인 단위 구분이다. 개발(DEV) 사건 전용 — 중단(STOP) 행은 NULL',
    fme.CPR_DIV_NM         AS fme.CPR_DIV_NM_AT_EVENT         WITH SYNONYMS ('세부캠페인 법인구분', '캠페인 법인구분') COMMENT = '**세부캠페인** 법인구분 라벨(CM019). 🔴적재 시점 동결값(구 campaign.CPR_DIV_NM 대체). 실제값 3종: ''통합''·''사단''·''사복'' + NULL. 🔴 「법인·사단법인·사복」 질의의 기본 축이 **아니다** — 법인 조건은 SPONSORSHIP_CPR_DIV_NM(후원사업 법인 · MSTR 기준)으로 건다. 이 축은 사용자가 「캠페인 법인」을 명시할 때만 쓴다. ⚠️ ''통합''은 사단·사복에 속하지 않는 별도 값이다. 개발(DEV) 사건 전용 — 중단(STOP) 행은 NULL',
    fme.GENDER_AT_EVENT         AS fme.GENDER_AT_EVENT         WITH SYNONYMS ('사건시점 성별', '약정시점 성별') COMMENT = '**사건(개발약정) 시점** 성별 라벨(코드사전 CM013). 실제값 8종: ''국내(남자)''·''국내(여자)''·''외국인(남자)''·''외국인(여자)''·''외국인(기타)''·''단체''·''기업''·''기타''. 🔴 위 `member.GENDER_NAME`(회원 마스터 **현재 스냅샷** · CM017 계열)과 **코드체계가 다르다** — 두 축을 합산하지 말 것. 이 축이 사건 당시 정확값이다. 🔴 개발(DEV) 사건 전용(중단원천에 성별 컬럼 부재 → NULL). ⚠️ 사전 미등재 센티넬 ''0''은 라벨이 없어 NULL 이며 ''미상''으로 창작하지 않는다',
    fme.SEX_AT_EVENT            AS fme.SEX_AT_EVENT            WITH SYNONYMS ('사건시점 성별코드') COMMENT = '사건시점 성별 원천코드(CM013 1~8 + 라벨 없는 센티넬 ''0''). 라벨은 GENDER_AT_EVENT. 실제값 9종: ''0''·''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8'' + NULL',
    fme.MKTG_CHANNEL_NM_AT_EVENT AS fme.MKTG_CHANNEL_NM_AT_EVENT
      WITH SYNONYMS ('마케팅채널', '마케팅 채널', '캠페인 채널')
      COMMENT = '마케팅채널명(원천 COMMENT = 마케팅 채널명 · C002) — 사건 시점 동결값. 🔴 개발인입경로(MM293)와 다른 축이다. 🔴 값 「-」는 원천 코드사전 C002 에 등록된 코드 6 의 라벨이다(결측 아님 · 근거 = 문서20 N-29 머리 실측) — 「채널 미지정 캠페인」으로 읽되 업무 의미는 원천 확인 대상이며, 채널별 순위에서는 「-」를 따로 밝힌다.',
    member.MEMBER_ENROLL_PATH_NAME AS member.ENROLL_PATH_NAME
      WITH SYNONYMS ('가입경로', '회원 가입경로')
      COMMENT = '회원 가입경로(MM014 · REG·홈페이지·모바일웹·모바일앱·외주콜센터·CRM) — 회원 마스터 현재값. 일시회원은 (해당없음). 🔴 개발인입경로(캠페인 모집채널)와 다른 축이다.',
    member.MEMBER_JOIN_CMMN_BRND_NM AS member.JOIN_CMMN_BRND_NM
      WITH SYNONYMS ('가입 공통브랜드', '회원 가입 공통브랜드')
      COMMENT = '회원 가입 시 공통브랜드(MM297) — 회원 마스터 기준. 🔴 「공통브랜드」(사건 캠페인 기준 CMMN_BRND_NM_AT_EVENT)와 다른 축이다 — 「가입 공통브랜드」를 명시할 때만 쓴다.',
    member.MEMBER_RELATNSP_DIV_NAME AS member.RELATNSP_DIV_NAME
      WITH SYNONYMS ('결연구분', '결연/비결연')
      COMMENT = '결연구분(MM019 · 결연회원·비결연회원·혼합회원·중단회원) — 회원 마스터 현재값. 일시회원은 NULL(원천 개념 없음).',
    member.MEMBER_SPECL_MNG_NAME AS member.SPECL_MNG_NAME
      WITH SYNONYMS ('특별관리', '회원 특별관리', '특별관리 구분')
      COMMENT = '회원 특별관리 구분(MM012 · 일반·더네이버스클럽·더네이버스아너스클럽·평생회원·홍보대사·이사회·블랙리스트·테스트회원 등) — 대부분 「일반」. 🔴 테스트회원 포함 여부를 답변에 밝힌다.',
    member.MEMBER_FIRST_SPONSORSHIP_NAME AS member.FIRST_SPONSORSHIP_NAME
      WITH SYNONYMS ('최초후원사업', '최초 후원사업')
      COMMENT = '회원의 최초 후원사업명(회원 마스터 · DIM_SPONSORSHIP 매칭 100%).',
    member.MEMBER_MOBLPHON_STAT_NAME AS member.MOBLPHON_STAT_NAME
      WITH SYNONYMS ('휴대폰상태', '휴대폰 상태', '연락처 상태')
      COMMENT = '휴대폰 상태(MM008 · 정상·결번·타인번호) — 회원 마스터 현재값.',
    member.MEMBER_EMAIL_STAT_NAME AS member.EMAIL_STAT_NAME
      WITH SYNONYMS ('이메일상태', '이메일 상태')
      COMMENT = '이메일 상태(MM009 · 정상·계정없음·도메인오류) — 원천 코드 0 은 사전에 없어 NULL.',
    member.MEMBER_TSTM_DIV_NAME AS member.TSTM_DIV_NAME
      WITH SYNONYMS ('TM/TS 거절', '전화 거절구분', 'TM 거절')
      COMMENT = 'TM/TS 거절구분(MS026 · TM 거절·TS 거절·TMTS거절). 🔴 원천 코드 0(대다수 회원)은 사전에 없어 NULL — 「거절 없음」으로 단정하지 않는다.'
  )
  METRICS (
    fme.TOTAL_DEV_CNT     AS SUM(fme.DEV_CNT)
      WITH SYNONYMS ('개발건', '개발 총건', '개발(건)') COMMENT = '개발(건) 합계 = **MSTR 정의**(사용자 결정): 신규·재후원·증액의 MSTR 인정금액 ÷ 10,000(소수 발생). 신규·재후원 = 미중단 후원사업·후원사업×월 합>0 · 증액 = 감액 상계 순증액. F(가산). 🟢 2026-07 전사 MSTR 리포트와 일치(실측). 🔴 GN_DW.MSTR(AGENT_MSTR) 값과 한 표에서 합산 금지.',
    fme.TOTAL_STOP_CNT    AS SUM(fme.STOP_CNT)
      WITH SYNONYMS ('중단건', '중단 총건', '해지건') COMMENT = '중단 건수 합계. F(가산). 중단원천(EVENT_TYPE=''STOP'') 기준. ⚠ DVLP_DIV_NM=''후원중단'' 행수와 더하지 말 것(동일 사건 중복).',
    fme.INCREASE_EVENT_AMT AS SUM(CASE WHEN fme.DVLP_DIV_NM = '증액' THEN fme.SPNSR_AMT END)
      WITH SYNONYMS ('증액금액', '증액 총액') COMMENT = '증액 사건 금액 합계(원). F(가산). 사건 발생일 기준 — 정본 공#150·#151(월말 스냅샷 대비)과 정의가 다르다(미확정).',
    fme.DECREASE_EVENT_AMT AS SUM(CASE WHEN fme.DVLP_DIV_NM = '감액' THEN fme.SPNSR_AMT END)
      WITH SYNONYMS ('감액금액', '감액 총액') COMMENT = '감액 사건 금액 합계(원, **음수**). F(가산). 사건 발생일 기준 — 정본 공#38(감액(건)=금액÷10,000)과 단위·정의가 다르다(미확정).',
    fme.INCREASE_MEMBER_COUNT AS COUNT(DISTINCT CASE WHEN fme.DVLP_DIV_NM = '증액' THEN fme.MEMBER_DK END)
      WITH SYNONYMS ('증액회원수') COMMENT = '증액 고유 회원수. D(distinct). 사건 기준.',
    fme.DECREASE_MEMBER_COUNT AS COUNT(DISTINCT CASE WHEN fme.DVLP_DIV_NM = '감액' THEN fme.MEMBER_DK END)
      WITH SYNONYMS ('감액회원수') COMMENT = '감액 고유 회원수. D(distinct). 사건 기준.',
    fme.DEV_MEMBER_COUNT  AS COUNT(DISTINCT CASE WHEN fme.DEV_MEMBERS = 1 THEN fme.MEMBER_DK END)
      WITH SYNONYMS ('개발회원수', '신규 회원수', '개발(명)') COMMENT = '개발(명) = MSTR 개발 인정 행을 가진 고유 회원수(MSTR 정의). D(distinct). 다기간도 중복 없음.',
    fme.STOP_MEMBER_COUNT AS COUNT(DISTINCT CASE WHEN fme.STOP_CNT > 0 THEN fme.MEMBER_DK END)
      WITH SYNONYMS ('중단회원수', '해지 회원수') COMMENT = '중단 고유 회원수. D(distinct).',
    fme.TOTAL_CAMPAIGN_STOP_CNT AS SUM(fme.CAMPAIGN_STOP_CNT)
      WITH SYNONYMS ('캠페인별 중단건', '캠페인 귀속 중단건', '캠페인별 해지건')
      COMMENT = '캠페인 귀속 중단(건) — 개발원천 후원중단 행 기준. F(가산). 🔴 **캠페인별 중단 규모를 볼 때 이 measure 를 쓴다**(TOTAL_STOP_CNT 는 중단원천 기준이라 캠페인이 전건 ''(미매핑)''이다). 🔴 **TOTAL_STOP_CNT 와 절대 합산 금지** — 같은 중단 사건이 두 원천에 중복 존재한다. 🔴 **이 값을 개발건으로 나눠 「중단률」로 쓰지 말 것** — 이 행의 캠페인은 **중단 시점** 캠페인이라 신규 건수와 모집단이 달라 비율이 100%를 넘는다(실측). 캠페인별 중단률의 정본은 **SV_MEMBER_COHORT** 의 12개월 고정 이탈률이다.',
    fme.CAMPAIGN_STOP_MEMBER_COUNT AS COUNT(DISTINCT CASE WHEN fme.CAMPAIGN_STOP_CNT > 0 THEN fme.MEMBER_DK END)
      WITH SYNONYMS ('캠페인별 중단회원수') COMMENT = '캠페인 귀속 중단 고유 회원수. D(distinct). 위 TOTAL_CAMPAIGN_STOP_CNT 와 동일 모집단(개발원천 후원중단 행).'
  )
  COMMENT = 'Phase-1 회원 상태전이 사건 분석 (base: GOLD.FACT_MEMBER_EVENT). [Grain: 회원 × 일 × 사건 1행]. [활성 지표: 개발건수/개발회원수/중단건수/증감금액, 개발구분 5종(신규/증액/감액/재후원/중단)]. [주의: 캠페인별 중단은 TOTAL_CAMPAIGN_STOP_CNT 사용(TOTAL_STOP_CNT 와 합산 금지), 캠페인별 중단률은 SV_MEMBER_COHORT(12개월 고정 이탈률), 부서별 목표대비 달성률은 SV_DEV_ACHIEVEMENT 사용]. [원천: CRM → BRONZE_CRM → SILVER.CRM_MEMBER_DEV/CRM_MEMBER_DISCONTINUE → GOLD.FACT_MEMBER_EVENT].'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 개발구분 필터: 증액·감액·신규·재후원·후원중단 질의는 EVENT_TYPE 이 아니라 DVLP_DIV_NM 으로 필터. (2) 중단 지표: 전체 중단 규모는 TOTAL_STOP_CNT, 캠페인별 중단 분해는 TOTAL_CAMPAIGN_STOP_CNT 사용 (두 지표 절대 합산 금지). 캠페인별 중단률은 SV_MEMBER_COHORT 로 라우팅. (3) 개발 지표: 개발 실적 건수는 TOTAL_DEV_CNT (신규·증액·재후원 합산) 사용. (4) 기간 미지정 시: 데이터 최신 연월 기준 직전 12개월로 한정하며 GROUP BY ROLLUP((연,월)) 반환. (5) 속성 시점: 연령대(AGE_BAND_AT_EVENT) 및 지역(REGION_AT_EVENT)은 개발 사건 시점 값이며 개발(DEV) 사건 전용. (6) 주간 실적: 주간 개발실적은 WEEK_OF_YEAR 와 CAL_YEAR 를 동반하여 조회하며 주간 목표 대비는 SV_DEV_ACHIEVEMENT 와 표를 분리하여 제시. (7) 홍보방법 필터: PROMO_METHOD_NAME 라벨 필터 사용. (8) 판정 라벨 [집계필요]: 월간 중단보고의 「중단(명)」은 STOP_MEMBERS 합이 아니라 중단 고유회원수(COUNT DISTINCT MEMBER_DK)로 답하고 「명 ≠ 플래그 합」임을 밝힌다. 주차별 「명」을 월로 더하지 않는다(주차 distinct 합 > 월 distinct). (9) 판정 라벨 [앵커_경합]: 개발실적보고 주간 섹션은 이 뷰 단독으로 답하지 않는다 — 월 목표·달성율은 SV_DEV_ACHIEVEMENT, 회비는 SV_MEMBER_FEE 를 각각 호출해 표를 분리하고 표마다 grain 을 밝힌다. 주간 목표는 원천 부재이므로 만들지 않는다. (10) [O202] 법인 축: 「법인·사단법인·사단·사복」 조건은 sponsorship.SPONSORSHIP_CPR_DIV_NM(후원사업 법인 · MSTR 기준)으로 건다(fme JOIN sponsorship ON fme.SPONSORSHIP_SK = sponsorship.SPONSORSHIP_SK) — 세부캠페인 법인(fme.CPR_DIV_NM)은 사용자가 「캠페인 법인」을 명시할 때만 쓴다. 개발(명)은 DEV_MEMBERS = 1 인 회원의 COUNT DISTINCT 다(DEV_CNT > 0 으로 세지 않는다).
(기준시점 규칙) 「최근 N개월」·기간 미지정 질의의 기준일은 **비상관 CTE 1개**(SELECT MAX(date.FULL_DATE) AS md FROM fme JOIN date ON fme.DATE_SK = date.DATE_SK)로 구하고 CROSS JOIN 한다. 스칼라 서브쿼리·상관 서브쿼리로 기준일을 구하지 않는다. 🔴 사건일은 fme 에 컬럼으로 없다 — fme.EVENT_DATE 를 쓰지 말고 date.FULL_DATE(fme.DATE_SK 조인)로만 건다. CTE 안에서 그 CTE 의 FROM 에 없는 별칭을 쓰지 않는다. 🔴 **차원은 논리 이름(DIMENSIONS 좌변)으로 참조한다** — 물리 컬럼명(DEPARTMENT·ACMSLT_DIV_*·CPR_DIV_NM_AT_EVENT·CMPGN_CTGR_NM_AT_EVENT·SPNSR_DIV_NM_AT_EVENT 등 _AT_EVENT 계열)을 CTE 컬럼으로 쓰면 invalid identifier 다 ⇒ ORG_DEPARTMENT·ORG_DIV_GROUP·ORG_DIV·CPR_DIV_NM·CAMPAIGN_TYPE·SPNSR_DIV_NM 을 쓴다. 🔴 **소속 테이블을 지킨다** — 캠페인 마스터 속성(CAMPAIGN_NAME·CAMPAIGN_BRAND·PARENT_CAMPAIGN_NAME·PROMO_METHOD_NAME)은 **campaign.** 이고 fme 에 없다(fme.PARENT_CAMPAIGN_NAME 은 invalid identifier) ⇒ fme JOIN campaign ON fme.CAMPAIGN_SK = campaign.CAMPAIGN_SK. 적재 시점 동결 속성(CAMPAIGN_TYPE·DOMESTIC_OVERSEAS·BIZ_CASE_TYPE·MARKETING_CAMPAIGN·CPR_DIV_NM 등)은 fme. 이다. ORDER BY 에는 SELECT 별칭을 글자 그대로 쓴다. (예측) 「다음 달 중단·개발을 예측해줘」는 이 SV 가 **실적 SV** 라 모델 예측이 없다 — 🔴 이 SV 로 예측치를 만들지 않는다(직전 월 평균·추세 연장 등 추정값도 만들지 않는다). 예측이 없다는 사실을 밝히고, 이 SV 로 볼 수 있는 실적(지표·축·최신월)을 안내한 뒤 실적을 먼저 보겠는지 되묻는다. 어떤 예측 도구로 보낼지는 Agent 의 라우팅 소관이며 이 SV 가 정하지 않는다.'
  AI_VERIFIED_QUERIES (
    vqr_o191_last12m_dev_div AS (
      QUESTION '최근 12개월 개발구분별 건수와 고유 회원수'
      VERIFIED_BY '(DW = O191)'
      SQL 'WITH mx AS (SELECT MAX(date.FULL_DATE) AS md FROM fme JOIN date ON fme.DATE_SK = date.DATE_SK) SELECT fme.DVLP_DIV_NM, COUNT(*) AS EVENT_ROWS, COUNT(DISTINCT fme.MEMBER_DK) AS DISTINCT_MEMBERS FROM fme JOIN date ON fme.DATE_SK = date.DATE_SK CROSS JOIN mx WHERE fme.DVLP_DIV_NM IS NOT NULL AND date.FULL_DATE > DATEADD(MONTH, -12, mx.md) AND date.FULL_DATE <= mx.md GROUP BY fme.DVLP_DIV_NM ORDER BY EVENT_ROWS DESC NULLS LAST'
    ),
    vqr_o191_dept_corp_month_dev AS (
      QUESTION '2026년 사단법인 매체운영팀 7월 회원개발 실적 명/건'
      VERIFIED_BY '(DW = O202 · 후원사업 법인 · MSTR 5,989명/11,956.2055건 일치)'
      SQL 'SELECT org.ORG_DEPARTMENT, sponsorship.SPONSORSHIP_CPR_DIV_NM, COUNT(DISTINCT CASE WHEN fme.DEV_MEMBERS = 1 THEN fme.MEMBER_DK END) AS DEV_MEMBER_COUNT, SUM(fme.DEV_CNT) AS TOTAL_DEV_CNT FROM fme JOIN org ON fme.ORG_SK = org.ORG_SK JOIN sponsorship ON fme.SPONSORSHIP_SK = sponsorship.SPONSORSHIP_SK JOIN date ON fme.DATE_SK = date.DATE_SK WHERE org.ORG_DEPARTMENT = ''매체운영팀'' AND sponsorship.SPONSORSHIP_CPR_DIV_NM = ''사단'' AND date.YEAR = 2026 AND date.MONTH = 7 GROUP BY org.ORG_DEPARTMENT, sponsorship.SPONSORSHIP_CPR_DIV_NM'
    ),
    vqr_o191_category_stop_month AS (
      QUESTION '캠페인카테고리별 2026년 1~6월 월별 중단명과 중단건'
      VERIFIED_BY '(DW = O191)'
      SQL 'SELECT fme.CAMPAIGN_TYPE, date.MONTH, COUNT(DISTINCT CASE WHEN fme.CAMPAIGN_STOP_CNT > 0 THEN fme.MEMBER_DK END) AS CAMPAIGN_STOP_MEMBER_COUNT, SUM(fme.CAMPAIGN_STOP_CNT) AS TOTAL_CAMPAIGN_STOP_CNT FROM fme JOIN date ON fme.DATE_SK = date.DATE_SK WHERE date.YEAR = 2026 AND date.MONTH BETWEEN 1 AND 6 AND fme.CAMPAIGN_STOP_CNT > 0 GROUP BY fme.CAMPAIGN_TYPE, date.MONTH ORDER BY fme.CAMPAIGN_TYPE, date.MONTH'
    ),
    vqr_o191_div_code_members AS (
      QUESTION '본부/지부별 2026년 개발 고유 회원수를 코드와 함께'
      VERIFIED_BY '(DW = O191)'
      SQL 'SELECT org.ORG_DIV_GROUP, org.ORG_DIV_GROUP_CODE, org.ORG_DIV, org.ORG_DIV_CODE, COUNT(DISTINCT CASE WHEN fme.DEV_MEMBERS = 1 THEN fme.MEMBER_DK END) AS DEV_MEMBER_COUNT FROM fme JOIN org ON fme.ORG_SK = org.ORG_SK JOIN date ON fme.DATE_SK = date.DATE_SK WHERE date.YEAR = 2026 GROUP BY org.ORG_DIV_GROUP, org.ORG_DIV_GROUP_CODE, org.ORG_DIV, org.ORG_DIV_CODE ORDER BY DEV_MEMBER_COUNT DESC NULLS LAST'
    )
  );

-- SV_MEMBER_COHORT ← 05_03_SV_DDL_MEMBER_COHORT.sql
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
    fmc.ACQ_AGE_BAND        AS fmc.ACQ_AGE_BAND    WITH SYNONYMS ('연령대', '나이대', '획득시점 연령대', '약정시점 연령대') COMMENT = '🔴**획득(최초 약정) 당시의** 회원 연령대 — **현재 나이가 아니다**. 코드사전 CM014. 실제값 12종: ''10대 미만''·''10대''·''20대''·''30대''·''40대''·''50대''·''60대''·''70대''·''70대 이상''·''단체''·''기업''·''기타''. ✅ ''10대 미만''이 상위인 것은 **데이터 오류가 아니다** — **편지쓰기대회 계열 캠페인**(희망편지쓰기대회·가족그림편지쓰기대회·세계시민교육편지)이 학교·부모 DB 를 통해 **아동 본인 명의로 약정을 맺는 모집 이벤트**이기 때문이다. 이 SV 에서 캠페인 축과 교차하면 그 편중을 직접 수치로 확인할 수 있다. 결측·기본값 오염으로 설명하지 말 것. ⚠️ 현재 연령은 BRONZE 에 생년월일 축이 없어 **산출 불가**',
    fmc.ACQ_AGE_CD          AS fmc.ACQ_AGE_CD      WITH SYNONYMS ('연령대코드') COMMENT = '획득시점 연령대 원천코드(CM014 1=10대 미만 2=10대 3=20대 4=30대 5=40대 6=50대 7=60대 8=70대 9=70대 이상 10=단체 11=기업 12=기타). 🔴 연속형 나이가 아니므로 평균·구간 재계산 금지. 라벨은 ACQ_AGE_BAND',
    fmc.ACQ_REGION          AS fmc.ACQ_REGION      WITH SYNONYMS ('지역', '시도', '획득시점 지역', '약정시점 지역') COMMENT = '🔴**획득(최초 약정) 당시의** 회원 지역 라벨 — **현재 거주지가 아니다**. 정본 공#131 · 코드사전 CM018 약칭. 실제값 18종: ''서울''·''경기''·''인천''·''강원''·''대전''·''대구''·''부산''·''광주''·''울산''·''세종''·''충남''·''충북''·''전남''·''전북''·''경남''·''경북''·''제주''·''기타''. ⚠️ 센티넬 코드 ''0''은 사전에 라벨이 없어 NULL 이다 — ''미상''으로 창작하지 말 것. ⚠️ ''현재 거주지역별'' 질문에는 답할 수 없다(BRONZE 에 현주소 축 없음)',
    fmc.ACQ_AREA_CD         AS fmc.ACQ_AREA_CD     WITH SYNONYMS ('지역코드') COMMENT = '획득시점 지역 원천코드(CM018 + 라벨 없는 센티넬 ''0''). 라벨은 ACQ_REGION. 실제값 19종: ''0''·''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''·''9''·''10''·''11''·''12''·''13''·''14''·''15''·''16''·''17''·''18'' + NULL',
    fmc.ACQ_GENDER          AS fmc.ACQ_GENDER      WITH SYNONYMS ('성별', '획득시점 성별') COMMENT = '획득시점 성별 라벨(코드사전 CM013). 실제값 8종: ''국내(남자)''·''국내(여자)''·''외국인(남자)''·''외국인(여자)''·''외국인(기타)''·''단체''·''기업''·''기타''. ⚠️ SV_MEMBER_EVENT·SV_MEMBER_MONTHLY 의 회원 성별(GENDER_NAME, CM017 라벨: 남자·여자·기업·단체·기타)과 **코드체계가 다르다** — 두 축을 같은 성별로 합산하지 말 것. ⚠️ 센티넬 ''0''은 라벨이 없어 NULL',
    fmc.ACQ_SEX_CD          AS fmc.ACQ_SEX_CD      WITH SYNONYMS ('성별코드') COMMENT = '획득시점 성별 원천코드(CM013 1~8 + 라벨 없는 센티넬 ''0''). 라벨은 ACQ_GENDER. 실제값 9종: ''0''·''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''',
    fmc.FIRST_STOP_REASON   AS fmc.FIRST_STOP_REASON_NM WITH SYNONYMS ('중단사유', '이탈사유', '해지사유') COMMENT = '**최초 중단**의 사유 라벨(정본 MM005 단일 코드체계 — 혼입 없음). 실제값 예: ''개인(경제적)사유''·''장기미납''·''신규미납''·''다른곳지원''·''기타''·''명의변경''·''아동퇴소''·''회원항의''·''일시후원이었음''·''만18세아동퇴소''·''이중가입''·''사업장종결''·''약정후원''·''기업후원종료''·''은행자동납부해지''·''반송미납''. 🔴 **미중단 회원은 NULL** 이다 — 이 축으로 그루핑하면 미중단 회원이 NULL 한 덩어리로 모인다. 이탈자만 보려면 이탈 measure 와 함께 쓰거나 NULL 을 제외한다',
    fmc.IS_12M_OBSERVABLE   AS fmc.IS_12M_OBSERVABLE WITH SYNONYMS ('12개월 관측가능', '관측가능 여부') COMMENT = '획득 후 12개월이 데이터 최종 사건일 안에 들어오는가(TRUE/FALSE). 🔴 **12개월 이탈률의 분모 자격**이다. 최근 획득 회원은 아직 12개월이 지나지 않아 FALSE 이며, 이들을 분모에 넣으면 최근 캠페인의 이탈률이 실제보다 낮게 보인다',
    acq_campaign.CAMPAIGN_NAME        AS acq_campaign.CAMPAIGN_NAME        WITH SYNONYMS ('캠페인', '캠페인명', '획득캠페인명', '모집캠페인') COMMENT = '회원을 처음 데려온 캠페인명. 🔴**획득 캠페인**이다 — 이 축으로 중단률을 비교하면 「그 캠페인으로 모집한 회원이 얼마나 이탈했는가」가 된다. 개별 캠페인은 카디널리티가 매우 높으니 규모가 작은 캠페인의 비율은 불안정하다 — 관측 가능 회원 하한을 걸 것. 🟢 캠페인명과 분류 속성 8종(카테고리·브랜드·상위캠페인·홍보방법·모집채널·국내해외·사업사례·마케팅캠페인)은 **같은 시점의 값**(최신 캠페인 마스터)이다 — 이력 보관을 하지 않으므로 캠페인이 개칭·재분류되면 과거 획득 회원도 새 이름·새 분류로 함께 보인다. 「획득 당시 이름」을 따로 답할 수 없다고 밝힐 것',
    fmc.CAMPAIGN_TYPE        AS fmc.ACQ_CMPGN_CTGR_NM        WITH SYNONYMS ('캠페인카테고리', '캠페인유형', '주요캠페인', '캠페인 종류', '캠페인 분류') COMMENT = '캠페인 카테고리(정본 MM294 라벨) — 현업이 말하는 **''주요캠페인''** 축이다. 🔴적재 시점 동결값(구 acq_campaign.CAMPAIGN_TYPE 대체). 실제값 예: ''초등캠페인''·''국내사례캠페인''·''굿즈캠페인''·''해외캠페인''·''기타 영상광고''·''홈페이지(PC/모바일)''·''국내여아지원캠페인''·''그외 지역개발캠페인''·''희망TV''·''인바운드''·''대학생캠페인''·''가두캠페인''·''유아캠페인''·''청소년캠페인''·''교회캠페인''·''기존회원캠페인 및 기타''. 🔴 캠페인별 중단률 비교의 **1순위 축**이다(개별 캠페인명보다 표본이 안정적이다)',
    fmc.CAMPAIGN_BRAND       AS fmc.ACQ_BRAND                WITH SYNONYMS ('브랜드', '캠페인 브랜드') COMMENT = '획득 캠페인의 브랜드. 🔴적재 시점 동결값(구 acq_campaign.BRAND 대체)',
    fmc.PARENT_CAMPAIGN_NAME AS fmc.ACQ_PARENT_CAMPAIGN_NAME WITH SYNONYMS ('상위캠페인', '상위캠페인명', '캠페인 그룹') COMMENT = '획득 캠페인의 **상위캠페인명**. 🔴적재 시점 동결값(구 acq_campaign.PARENT_CAMPAIGN_NAME 대체). 캠페인을 묶어 보는 축이다. ⚠️ 상위가 없는 캠페인은 NULL 이며 ''(미매핑)''이 아니다. ⚠️ 캠페인 카테고리(CAMPAIGN_TYPE)와 다른 축이다',
    fmc.PROMO_METHOD_NAME    AS fmc.ACQ_PROMO_METHOD_NAME    WITH SYNONYMS ('홍보방법', '광고방법', '매체', '홍보수단') COMMENT = '획득 캠페인의 **홍보방법** 라벨(코드사전 CM008, 2026-08-05 신설). 🔴적재 시점 동결값(구 acq_campaign.PROMO_METHOD_NAME 대체). 실제값 계열: ''PC배너광고(DA)''·''M배너광고(DA)''·''PC검색광고(SA)''·''M검색광고(SA)''·''TM''·''TS''·''PC캠페인-홈페이지''·''M캠페인-홈페이지''·''PC캠페인-홍보''·''M캠페인-홍보''·''온라인''·''오프라인''·''APP캠페인''·''M모바일앱''·''M페이스북광고''·''기존회원메일''·''PC기업공동캠페인''·''M기업 공동캠페인''·''기타''. 🔴 원천 `PR_MTH_CD` 는 **숫자 코드**이다 — 코드로 필터하면 Analyst 가 0행을 반환한다. 반드시 이 라벨 컬럼으로 필터·그루핑한다. ⚠️ 원천 코드가 없는 캠페인은 NULL 이며 ''(미매핑)''이 아니다. ⚠️ 모집 채널(CAMPAIGN_INFLOW_PATH)과 다른 축이다 — 이쪽은 광고·접촉 수단, 그쪽은 개발인입경로다',
    fmc.CAMPAIGN_INFLOW_PATH AS fmc.ACQ_MBER_INFLOW_PATH_NM   WITH SYNONYMS ('모집채널', '유입경로', '개발인입경로') COMMENT = '획득 캠페인의 **모집 채널**(정본 MM293 라벨). 🔴적재 시점 동결값(구 acq_campaign.INFLOW_PATH 대체). 실제값 12종: ''교육기관''·''기타 기업개발''·''뉴미디어''·''대면모금''·''디지털''·''방송''·''영상광고''·''오프라인''·''일시''·''재송출''·''지역개발''·''콜개발'' + NULL. 🔴🔴 **아래 라벨은 이 데이터에 존재하지 않으므로 필터에 쓰면 0행이 반환된다**: ''회원 온라인개발''·''회원 콜개발''·''기업''·''회원 기타''·''마케팅콜개발''·''회원 오프라인개발''·''직원개발''. 원천 라벨이 개칭됐으므로 ''회원 콜개발''은 ''콜개발'', ''회원 오프라인개발''은 ''오프라인'', ''기업''은 ''기타 기업개발'' 로 읽는다. ⚠️ 이 축은 채널이며 「주요캠페인」이 아니다 — 주요캠페인은 CAMPAIGN_TYPE 이다. ⚠️ 회원 가입경로(회원 속성)와도 다른 축이다',
    fmc.DOMESTIC_OVERSEAS    AS fmc.ACQ_CMPGN_TYPE1_NM       WITH SYNONYMS ('국내해외', '국내외') COMMENT = '획득 캠페인의 국내/해외 구분(MM295). 🔴적재 시점 동결값(구 acq_campaign.DOMESTIC_OVERSEAS 대체). 실제값 4종: ''국내''·''해외''·''통합''·''전체사업'' + NULL. ⚠️ ''통합''과 ''전체사업''은 서로 다른 값이다 — 하나로 묶지 말고 원천 라벨 그대로 노출한다',
    fmc.BIZ_CASE_TYPE        AS fmc.ACQ_CMPGN_TYPE2_NM       WITH SYNONYMS ('사업사례구분', '사업/사례') COMMENT = '획득 캠페인의 사업/사례 구분(MM296). 🔴적재 시점 동결값(구 acq_campaign.BIZ_CASE_TYPE 대체). 실제값 4종: ''사례''·''사업''·''굿즈''·''기타''',
    fmc.MARKETING_CAMPAIGN   AS fmc.ACQ_MKTG_CMPGN_NM        WITH SYNONYMS ('마케팅캠페인', '마케팅 캠페인명') COMMENT = '획득 캠페인의 마케팅캠페인명. 🔴적재 시점 동결값(구 acq_campaign.MARKETING_CAMPAIGN 대체). 실제값 예: ''24년 이전컨텐츠''·''그외 지역개발캠페인''·''유어턴(통합A)''·''유어턴(통합B)''·''기존회원캠페인 및 기타''·''25년 이전컨텐츠(영상광고)''·''TS/TM''. 카디널리티가 높다',
    acq_org.ACQ_DEPARTMENT            AS acq_org.DEPARTMENT                WITH SYNONYMS ('획득부서', '가입부서', '모집부서', '획득 시점 부서') COMMENT = '🔴**획득(최초 약정) 시점의 실적부서명**(정본 #116). 개발실적보고의 「부서」와 **다른 축**이다 — 그쪽은 **사건 부서**(SV_MEMBER_EVENT.ORG_DEPARTMENT)이며 회원이 이후 다른 부서 실적으로 잡혀도 이 축은 변하지 않는다. ⚠️ 본부/지부는 ACQ_ORG_DIV_GROUP·ACQ_ORG_DIV 를 쓴다 — 부서명에서 상위 조직을 추측하지 말 것(팀·법인은 산출 불가). 🔴 폐지된 과거 실적부서는 옛 부서명 그대로 나온다(현재 부서로 연결하지 않는다). ⚠️ 획득 사건의 부서를 알 수 없는 회원은 ''(미매핑)''이다',
    acq_org.ACQ_ORG_DIV_GROUP         AS acq_org.ACMSLT_DIV_GROUP_NM       WITH SYNONYMS ('획득 본부지부구분', '가입 조직구분') COMMENT = '획득 시점 실적 본부/지부 **구분**(ZB 노드). 실제값 8종: ''본부''·''지부''·''시도본부''·''지부외''·''지부(사복)''·''본부(사복)''·''협력시설''·''시도본부 및 중앙'' + NULL. ⚠️ ''협력시설''·''지부외''는 시설·기타 묶음이다(본부/지부 조직이 아니다). 사건 시점 축(SV_MEMBER_EVENT.ORG_DIV_GROUP)과 다르다',
    acq_org.ACQ_ORG_DIV               AS acq_org.ACMSLT_DIV_NM             WITH SYNONYMS ('획득 본부', '획득 지부', '가입 본부지부', '모집 본부지부') COMMENT = '획득 시점 실적 본부/지부 **단위명**(ZC 노드). 🔴🔴 같은 이름이 여러 구분에 있다(예: 서울) — 반드시 ACQ_ORG_DIV_GROUP 과 함께 그룹핑한다. 도달 못 한 부서는 NULL',
    acq_org.ACQ_ORG_DIV_GROUP_CODE    AS acq_org.ACMSLT_DIV_GROUP_ID       WITH SYNONYMS ('획득 본부지부구분코드') COMMENT = '획득 시점 실적 본부/지부 구분 부서코드(ZB 접두). 🔴 본부/지부를 보여줄 때 이름과 코드를 함께 표시한다(현업 회신 41.3)',
    acq_org.ACQ_ORG_DIV_CODE          AS acq_org.ACMSLT_DIV_ID             WITH SYNONYMS ('획득 본부지부코드', '획득 지부코드') COMMENT = '획득 시점 실적 본부/지부 단위 부서코드(ZC 접두). 🔴 이름이 같아도 코드가 다르면 다른 조직 — 합치지 말고 코드로 나눠 보여준다(현업 회신 41.3)',
    acq_sponsorship.ACQ_SPONSORSHIP   AS acq_sponsorship.SPONSORSHIP_NAME  WITH SYNONYMS ('획득 후원사업', '가입 후원사업', '모집 후원사업', '후원사업(획득)') COMMENT = '🔴**획득 시점 후원사업명** — 그 회원을 데려온 사업이다(정본 #123). ⚠️ **회비를 낸 후원사업이 아니다**: 납입 대상 후원사업은 `SV_MEMBER_FEE` 의 SPONSORSHIP_NAME 이며, 한 회원이 여러 후원사업에 내므로 두 축의 값은 다르다. 회원 특성·이탈률 분석에는 이 축이 맞고, 회비 금액 분해에는 SV_MEMBER_FEE 가 맞다. ⚠️ 미매칭은 ''(미매핑)''',
    acq_campaign.ACQ_MKTG_CHANNEL_NM AS acq_campaign.MKTG_CHANNEL_NM WITH SYNONYMS ('마케팅채널', '획득 마케팅채널') COMMENT = '획득 캠페인의 마케팅채널(원천 COMMENT = 마케팅 채널명 · C002) — 캠페인 마스터 현재값. 🔴 값 「-」는 원천 코드사전 C002 에 등록된 코드 6 의 라벨이다(결측 아님 · 근거 = 문서20 N-29 머리 실측) — 「채널 미지정 캠페인」으로 읽되 업무 의미는 원천 확인 대상이며, 채널별 순위에서는 「-」를 따로 밝힌다.',
    acq_sponsorship.ACQ_SPONSORSHIP_GROUP4_NAME AS acq_sponsorship.SPONSORSHIP_GROUP4_NAME WITH SYNONYMS ('후원사업 4그룹', '후원사업그룹') COMMENT = '획득 후원사업 4그룹(국내/결연/해외프로젝트/기타 · CM003 라벨 접기 · 규칙 밖 라벨은 NULL).'
  )
  METRICS (
    fmc.TOTAL_ACQ_MEMBERS AS SUM(fmc.ACQ_MEMBERS)
      WITH SYNONYMS ('획득회원수', '모집회원수', '신규회원수') COMMENT = '획득 회원수. D(회원 grain이라 SUM 이 곧 distinct 회원수 — 이 팩트는 회원당 1행이므로 다기간 중복이 없다). 캠페인별 모집 규모.',
    fmc.CHURN_RATE_12M AS SUM(fmc.STOPPED_12M_MEMBERS) / NULLIF(SUM(fmc.OBSERVABLE_12M_MEMBERS), 0) * 100
      WITH SYNONYMS ('중단률', '이탈률', '12개월 이탈률', '12개월 중단률', '해지율', '이탈율')
      COMMENT = '🔴**캠페인별 중단률의 정본(단위 %)** = 획득 후 12개월 내 이탈 회원수 ÷ 12개월 관측 가능 회원수 ×100. 비율(N) — 재집계 금지, 분자·분모를 각각 집계한 뒤 나눈다. **왜 12개월 고정인가**: 누적 이탈률은 관측 기간에 지배되어(획득이 이를수록 높다) 실행 연도가 다른 캠페인을 비교하면 오래된 캠페인이 자동으로 「중단률 높음」이 된다 — 값이 정상인데 답이 틀리는 결함이다. 12개월로 고정하면 캠페인 간 공정 비교가 된다. 분모는 IS_12M_OBSERVABLE=TRUE 회원으로 자동 제한된다. 🔴 단위는 **퍼센트**다 — 값을 다시 ×100 하지 말 것.',
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
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 이탈률 정본: 캠페인별 중단률/이탈률 질문은 CHURN_RATE_12M (% 단위) 사용. 누적 이탈률(STOPPED_MEMBERS_EVER/TOTAL_ACQ_MEMBERS)은 기간 편향이 발생하므로 캠페인 비교에 사용 금지. (2) 기간 필터: 연도/월 필터는 획득 시점 기준임. (3) 건수 vs 비율 분기: 중단 건수 질의는 SV_MEMBER_EVENT 로 라우팅. (4) 유지기간: AVG_TENURE_DAYS 는 이탈 회원만의 평균 유지일수이며 CHURN_RATE_12M 과 함께 제시. (5) 정렬: 비율 metric 정렬 시 ORDER BY ... DESC NULLS LAST 사용. (6) 획득 속성: ACQ_DEPARTMENT, ACQ_SPONSORSHIP 은 획득 시점 속성이며 납입 대상 회비는 SV_MEMBER_FEE 로 라우팅. ORDER BY 에는 SELECT 에서 정의한 별칭을 글자 그대로 쓴다(별칭 일부만 쓰면 invalid identifier). 「총납입회비」처럼 이 SV 에 없는 지표로 정렬·결합을 요구받으면 이 SV 에서 억지로 만들지 말고 SV_MEMBER_FEE 를 따로 호출해 표를 분리한다. 「최근 N개월」 기준일은 비상관 CTE 1개로 구하고 CROSS JOIN 한다.'
  AI_VERIFIED_QUERIES (
    vqr_o191_campaign_churn_top10 AS (
      QUESTION '캠페인별 평균 유지기간과 12개월 이탈률 상위 10곳'
      VERIFIED_BY '(DW = O191)'
      SQL 'SELECT acq_campaign.CAMPAIGN_NAME, SUM(fmc.ACQ_MEMBERS) AS TOTAL_ACQ_MEMBERS, AVG(fmc.TENURE_DAYS) AS AVG_TENURE_DAYS, SUM(fmc.STOPPED_12M_MEMBERS) / NULLIF(SUM(fmc.OBSERVABLE_12M_MEMBERS), 0) * 100 AS CHURN_RATE_12M FROM fmc LEFT JOIN acq_campaign ON fmc.ACQ_CAMPAIGN_SK = acq_campaign.CAMPAIGN_SK WHERE fmc.ACQ_BASIS = ''NEW'' GROUP BY acq_campaign.CAMPAIGN_NAME HAVING SUM(fmc.OBSERVABLE_12M_MEMBERS) >= 100 ORDER BY TOTAL_ACQ_MEMBERS DESC NULLS LAST LIMIT 10'
    )
  );

-- SV_SERVICE ← 05_04_SV_DDL_SERVICE.sql
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_SERVICE
  TABLES (
    fse AS GN_DW.GOLD.FACT_MESSAGE_DISPATCH
      WITH SYNONYMS ('발송', '서비스 발송', '문자메일 발송', '메시지 발송')
      COMMENT = '메시지 발송 성과 및 고객 접점 서비스 분석 (base: GOLD.FACT_MESSAGE_DISPATCH). [Grain: 발송일 × 회원 × 서비스]. [활성 지표: 발송/성공/실패/오픈수, WIDE_BIGQUERY_BEHAVIOR]. [주의: 배분규칙필요 앵커_경합 방지 · 캠페인 축 = 문자(SND) 발송 캠페인만 배선(원천 SND_MEMBER_LIST.CMPGN_CD) — 이메일·알림톡·우편은 원천에 캠페인 키가 없어 (미매핑)(구조적 부재) ⇒ 「캠페인별 발송」은 SND 기준임을 밝힌다]. [원천: CRM → BRONZE_CRM → SILVER.CRM_SEND_MEMBER/REQUEST → GOLD.FACT_MESSAGE_DISPATCH].',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '발송일')
      COMMENT = '일 차원. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.',
    service AS GN_DW.GOLD.DIM_SERVICE
      PRIMARY KEY (SERVICE_SK)
      WITH SYNONYMS ('서비스', '서비스구분', '발송채널')
      COMMENT = '서비스 차원(A3 SERVICE_SK). 미매칭=Unknown(SK=0). [원천] 시스템=CRM(UMS) · BRONZE=GN_DW.BRONZE_CRM.SND_REQ_MST(SEND_GBN_TOP/MID/BOT 대·중·소분류 코드) · SILVER=CRM_SEND_REQUEST.',
    member AS GN_DW.GOLD.DIM_MEMBER
      PRIMARY KEY (MEMBER_DK)
      WITH SYNONYMS ('회원')
      COMMENT = '정규 회원 마스터 차원 (회원 1명 = 1행 · MEMBER_DK 유일). 🔴 IS_CURRENT 컬럼은 없다 — 상태 이력이 필요하면 DIM_MEMBER_STATUS_HISTORY 를 쓴다. 불변/현재 속성 전용. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM · SILVER=CRM_MEMBER · GOLD=DIM_MEMBER.',
    req AS GN_DW.GOLD.DIM_SEND_REQUEST
      PRIMARY KEY (SEND_REQUEST_SK)
      WITH SYNONYMS ('발송 요청', '발송 요청 차원')
      COMMENT = '발송 요청 차원(요청당 한 행). 메시지구분(MS010)·발송시간구분(MS267)·우편처리상태(MS061)·법인유형(CM019)·분할발송유형. [원천] 시스템=CRM(UMS) · BRONZE=GN_DW.BRONZE_CRM.SND_REQ_MST · SILVER=CRM_SEND_REQUEST · GOLD=DIM_SEND_REQUEST.',
    -- 🆕 [2026-10-14 O225-C] 발송 캠페인 축(SND 채널만 값 · 그 외 채널 = (미매핑) SK=0)
    campaign AS GN_DW.GOLD.DIM_CAMPAIGN
      PRIMARY KEY (CAMPAIGN_SK)
      WITH SYNONYMS ('캠페인', '발송 캠페인')
      COMMENT = '캠페인 차원(PK 유일 · fan-out 0). 🔴 문자(SND) 발송만 캠페인코드가 있다 — 이메일·알림톡·우편은 전건 (미매핑). [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM.SND_MEMBER_LIST.CMPGN_CD → TM_CM_CMPGN_MNG · SILVER=CRM_CAMPAIGN.'
  )
  RELATIONSHIPS (
    fse_to_date    AS fse (DATE_SK)    REFERENCES date,
    fse_to_service AS fse (SERVICE_SK) REFERENCES service,
    fse_to_member  AS fse (MEMBER_DK)  REFERENCES member,
    fse_to_req     AS fse (SEND_REQUEST_SK) REFERENCES req,
    fse_to_campaign AS fse (CAMPAIGN_SK) REFERENCES campaign
  )
  DIMENSIONS (
    date.SEND_DATE  AS date.FULL_DATE  WITH SYNONYMS ('발송일', '일자', '날짜') COMMENT = '발송일',
    date.FULL_DATE AS date.FULL_DATE  COMMENT = '달력 날짜(DIM_DATE.FULL_DATE) — SEND_DATE 와 같은 값이다(Analyst 가 추측하는 식별자를 실재화). 둘 중 하나만 쓴다.',
    date.CAL_YEAR   AS date.YEAR       WITH SYNONYMS ('연도', '년')     COMMENT = '연도',
    date.CAL_MONTH  AS date.MONTH      WITH SYNONYMS ('월')            COMMENT = '월(1~12)',
    date.YEAR AS date.YEAR    COMMENT = '연도(DIM_DATE.YEAR) — CAL_YEAR 와 같은 값(Analyst 가 추측하는 식별자를 실재화). 둘 중 하나만 쓴다.',
    date.MONTH AS date.MONTH  COMMENT = '월(DIM_DATE.MONTH) — CAL_MONTH 와 같은 값(추측 식별자 실재화). 둘 중 하나만 쓴다.',
    service.SUBTYPE AS service.SUBTYPE WITH SYNONYMS ('서비스유형', '발송소분류') COMMENT = '서비스 subtype. ⚠️ **라벨이 아니라 원천 숫자 코드**다 — 실제값 5종: ''0''·''1''·''2''·''3''·''(미매핑)'' + NULL. 🔴🔴 **CHANNEL 과 함께 보지 않으면 서로 다른 체계를 섞는다** — 이 컬럼도 `SEND_STATUS` 와 **같은 구조적 결함**이다: 채널별로 도메인이 다르다(EMAIL ''0''·''1''·''2''+NULL / MSG_AT ''0''·''1'' / PSTMTR ''1''·''2''·''3'' / SND 는 NULL). 같은 ''1'' 이 채널에 따라 다른 것을 뜻하므로 이 축 단독 그루핑·필터는 오답이다. 🔴 **라벨은 만들지 않았다 — 코드군을 특정할 수 없어서다**(채널별 도메인이 2~3종뿐이라 사전 후보가 과다하고, 의미가 맞는 그룹이 없다 · 등급 D). 의미를 창작하지 말고 **코드값 그대로 + 채널 동반**으로 제시하고 라벨 부재를 밝힌다(현업 확인 =)',
    service.CHANNEL AS service.CHANNEL WITH SYNONYMS ('채널', '발송채널') COMMENT = '발송 채널. 실제값 5종: ''MSG_AT''·''SND''·''EMAIL''·''PSTMTR''·''(미매핑)''. 🔴🔴 **위 5종 외의 값은 이 축에 존재하지 않는다** — 다른 값으로 필터하면 0행 무증상 오답이다. ⚠️ ''(미매핑)''은 원천 채널코드가 사전에 없는 행이다',
    fse.SEND_STATUS AS fse.SEND_STATUS WITH SYNONYMS ('발송상태코드') COMMENT = '발송 상태 **축A 원천 코드**(라벨 아님). 🔴🔴 **반드시 CHANNEL 과 함께 볼 것 — 채널마다 코드체계가 다르다.** BRONZE 원천 대조 결과 이 컬럼은 채널별로 **서로 다른 원천 컬럼**을 받는다: EMAIL 계열은 ''0''·''1'' · MSG_AT 계열은 ''2''·''3''·''4'' · SND 계열은 ''Y''·''N'' · PSTMTR 계열은 **원천에 결과코드 컬럼이 아예 없어 전건 NULL**(결측이 아니라 구조적 부재). 🔴 따라서 CHANNEL 없이 이 축만 그루핑하면 **서로 다른 체계를 한 표에 섞는다.** ✅ **사람이 읽는 라벨은 SEND_STATUS_NAME 축을 쓴다**(R1 — 현업은 코드를 모른다). 🟢 통신사 도달 결과는 **축B**(SEND_RESULT_CD·SEND_RESULT_GROUP·SEND_RESULT_NAME)가 따로 담으며 그쪽은 채널 간 conformed 다. 실제값 7종: ''0''·''1''·''2''·''3''·''4''·''N''·''Y'' + NULL',
    fse.SEND_STATUS_NAME AS fse.SEND_STATUS_NAME WITH SYNONYMS ('발송상태', '발송상태명') COMMENT = '발송 상태 **축A 라벨 — 현업 응답용 정본 축**이다(코드군 MS282 · 원천 교차로 의미 확정). 실제값 3종: ''발송완료''·''에러''·''예약취소'' + NULL. 🔴🔴 **NULL 은 결측이 아니다** — 라벨은 **MSG_AT 계열만** 채워진다: EMAIL·SND 는 코드값만 있고 **사전에 라벨 문자열이 없어 의도적 NULL** 이며(「성공/실패」는 원천 교차로 얻은 우리 해석이라 라벨로 창작하지 않는다 · 현업 확인 =), PSTMTR 은 원천 자체가 없다. ⇒ 이 축으로 분해할 때는 **NULL 덩어리를 함께 밝히고 CHANNEL 을 동반**한다. 🔴 **성공/실패 판정은 MSG_AT 한정으로만 가능**하며 전 채널 성공률로 단정하지 말 것',
    fse.SEND_RESULT_CD AS fse.SEND_RESULT_CD WITH SYNONYMS ('통신사결과코드', '전송실패코드') COMMENT = '**축B 통신사 결과 코드 raw**(MSG_AT 전송실패코드 · SND 수신결과상태). 🟢 **축A 와 달리 conformed 다** — 두 채널이 같은 코드공간을 공유하므로 채널이 늘어도 코드체계가 유지된다. 라벨은 SEND_RESULT_NAME · 코드군은 SEND_RESULT_GROUP 을 쓴다(복합키 = 코드군 + 코드). ⚠️ 카디널리티가 커 열거하지 않는다 — 특정 사유를 찾으려면 라벨축이나 코드군축을 먼저 쓴다. ⚠️ **운영 코드사전에도 없는 통신사 코드가 실재**한다 ⇒ 그 행은 라벨 NULL 이며 센티넬을 창작하지 않는다(사전 갱신 요청 =)',
    fse.SEND_RESULT_GROUP AS fse.SEND_RESULT_GROUP WITH SYNONYMS ('통신사결과코드군', '메시지타입코드군') COMMENT = '**축B 코드군 ID** — 사전 MS283 이 정의한 4그룹이며 **메시지 타입 판별자**다. 실제값 4종: ''MS056''·''MS057''·''MS058''·''MS059'' + NULL(축B 코드가 없는 행). MS056=공통 · MS057=알림톡 · MS058=SMS · MS059=MMS. 🟢 이 값은 리터럴 지정이 아니라 **사전 조인 결과에서 얻는다**(코드값이 4그룹에 걸쳐 중복 없음). 🔴 축B 코드를 필터할 때 이 축을 동반하면 오조인이 구조로 차단된다',
    fse.SEND_RESULT_NAME AS fse.SEND_RESULT_NAME WITH SYNONYMS ('통신사결과', '전송실패사유', '발송결과사유') COMMENT = '**축B 라벨 — 통신사가 반환한 도달 결과 사유**(사전 MS056~MS059). ⚠️ 카디널리티가 커 열거하지 않는다 — 「전달」이 도달 성공이고 나머지는 실패 사유다(타임아웃·전화번호 오류·템플릿 없음 등). 🔴🔴 **축A(SEND_STATUS_NAME) 와 의미가 다르다** — 축A 는 **우리 발송 시스템의 상태**(발송완료/에러/예약취소), 축B 는 **통신사 도달 결과**다. 한 표에 섞거나 합산하지 말고 어느 축으로 답했는지 밝힌다. 🔴 코드는 있으나 **사전에 라벨이 없는 행은 NULL** 이다 — 도달률·실패율의 분모를 낼 때 그 덩어리를 함께 밝힌다',
    fse.ALTRTV_MSG_SNDNG_YN AS fse.ALTRTV_MSG_SNDNG_YN WITH SYNONYMS ('대체문자', '대체문자 발송여부', '알림톡 대체발송') COMMENT = '대체문자 발송 여부 — **알림톡(CHANNEL=''MSG_AT'') 전용** 원천 값이다. 실제값 1종: ''Y'' + NULL. 🔴 다른 채널(EMAIL·SND·PSTMTR)은 원천에 이 컬럼이 없어 전건 NULL 이다(구조적 부재) ⇒ 반드시 CHANNEL=''MSG_AT'' 로 한정한다. 🔴 원천에 ''N'' 값이 없다 — MSG_AT 의 NULL 을 「대체문자 미발송」으로 단정하지 말고 「Y 표기 없음」으로 표현한다',
    fse.SEND_TITLE AS fse.SEND_TITLE WITH SYNONYMS ('발송제목', '발송명', '메시지 제목', '알림톡 제목', '캠페인 메시지명') COMMENT = '발송 제목(발송요청 원천 제목 · 자유 텍스트). 🔴 고유값이 수만 종인 자유 텍스트다 — 「행운의 카드」처럼 이름으로 물으면 **ILIKE ''%행운%카드%''** 처럼 부분일치로 필터하고 정확일치를 가정하지 않는다. 일치한 제목 목록을 함께 보여준다. ⚠️ 제목이 없는 발송은 NULL 이다(원천 미입력). 🔴 캠페인 축이 아니다 — 제목으로 캠페인을 추정하지 않는다',
    fse.RESPONSED_YN AS fse.RESPONSED_YN WITH SYNONYMS ('확인여부', '발송확인여부', '수신확인') COMMENT = '발송 확인 여부 — **문자(CHANNEL=''SND'') 전용** 원천 값이다. 실제값 2종: ''Y''·''N'' + NULL. 🔴 다른 채널은 원천에 컬럼이 없어 전건 NULL(구조적 부재) ⇒ CHANNEL=''SND'' 로 한정한다. 🔴🔴 **오픈(링크 클릭 · TOTAL_OPEN_MEMBERS)과 다른 축이다** — 확인여부를 오픈·클릭으로 바꿔 말하거나 두 값을 합산·비교해 하나의 반응률로 만들지 말 것. ⚠️ SND 에도 값이 없는 소수 행은 NULL 이다',
    member.CHRCTR_RECPTN_YN AS member.CHRCTR_RECPTN_YN WITH SYNONYMS ('문자수신여부', '문자수신', 'SMS 수신동의') COMMENT = '회원 문자수신 여부(현재 마스터 스냅샷 · 발송 시점 값이 아니다). 실제값 2종: ''Y''·''N'' + NULL. 🔴 과거 발송을 이 축으로 나누면 「발송 당시 수신 상태」가 아니라 **현재 상태**로 나뉜다 — 그 전제를 밝힌다. ⚠️ NULL 은 원천 미입력이며 ''N'' 으로 읽지 않는다',
    member.GENDER_NAME   AS member.GENDER_NAME   WITH SYNONYMS ('성별')     COMMENT = '회원 성별 — 정본 공#130. 실제값 5종: ''남자''·''여자''·''기업''·''단체''·''기타''(CM017 라벨).',
    member.SEX           AS member.SEX           WITH SYNONYMS ('성별코드') COMMENT = '성별 원천코드(CM013). 이 차원의 실제값 8종 1~8 (+미기재 NULL). ⚠회원 마스터에 ''0''은 없다 — sentinel ''0''은 개발·증감 원천에만 존재하므로 ''0'' 조건은 0행. 라벨은 GENDER_NAME(분석)·SEX_NM(원천)',
    member.SEX_NM        AS member.SEX_NM        WITH SYNONYMS ('성별상세', '국내외국인') COMMENT = 'CM013 원천 라벨 8종(국내(남자)·외국인(여자)·단체·기업 등). 국내/외국인 구분용. 실제값 8종: ''기업''·''기타''·''단체''·''국내(남자)''·''국내(여자)''·''외국인(기타)''·''외국인(남자)''·''외국인(여자)'' + NULL',
    member.MEMBER_STATUS_NAME AS member.MEMBER_STATUS_NAME WITH SYNONYMS ('회원상태') COMMENT = '현재 회원상태 라벨(공#132, MM010). 실제값 13종: ''활동회원''·''신규미납1''·''신규미납2''·''신규미납3''·''신규미납4''·''신규미납5''·''장기미납1''·''장기미납2''·''장기미납3''·''장기미납4''·''장기미납5''·''후원중단''·''(해당없음)''. 🔴 **라벨에 숫자 접두가 없다** — 상태 코드번호를 라벨 앞에 붙인 형태로 필터하면 0행 무증상 오답이다. ⚠️ ''(해당없음)''은 일시회원이며 정기후원 상태축의 **구조적 부재**다 — 결측이 아니다',
    member.MBER_STAT_CD  AS member.MBER_STAT_CD  WITH SYNONYMS ('회원상태코드') COMMENT = '회원상태 원천코드(MM010 1~12). 실제값 12종: ''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''·''9''·''10''·''11''·''12'' + NULL',
    member.MEMBER_TYPE_NAME AS member.MEMBER_TYPE_NAME WITH SYNONYMS ('회원구분') COMMENT = '회원구분 라벨(MM018): 개인·기업·단체. 실제값 3종: ''개인''·''기업''·''단체''',
    member.MBER_DIV_CD   AS member.MBER_DIV_CD   WITH SYNONYMS ('회원구분코드') COMMENT = '회원구분 원천코드(MM018). 실제값 3종: ''1''·''2''·''3''',
    member.MEMBER_ENROLL_PATH_NAME AS member.ENROLL_PATH_NAME WITH SYNONYMS ('가입경로', '회원 가입경로') COMMENT = '회원 가입경로(MM014) — 회원 마스터 현재값. 일시회원은 (해당없음).',
    member.MEMBER_JOIN_CMMN_BRND_NM AS member.JOIN_CMMN_BRND_NM WITH SYNONYMS ('가입 공통브랜드', '회원 가입 공통브랜드') COMMENT = '회원 가입 시 공통브랜드(MM297) — 회원 마스터 기준.',
    fse.FRST_BRND_NM AS fse.FRST_BRND_NM WITH SYNONYMS ('최초 브랜드', '발송 시점 최초 브랜드') COMMENT = '발송 시점 회원의 최초 브랜드명(원천 SND_MEMBER_LIST · 발송 원천 스냅샷).',
    fse.LST_BRND_NM AS fse.LST_BRND_NM WITH SYNONYMS ('최종 브랜드', '발송 시점 최종 브랜드') COMMENT = '발송 시점 회원의 최종 브랜드명(원천 SND_MEMBER_LIST · 발송 원천 스냅샷).',
    fse.SEND_TYPE AS fse.SEND_TYPE WITH SYNONYMS ('발송채널 원천구분', '발송 원천') COMMENT = '발송 원천 계열(EMAIL·PSTMTR(우편)·MSG_AT(알림톡)·SND(문자)). 🔴 채널(CHANNEL) 라벨과 같은 축의 원천 코드다 — 채널 질문은 채널 차원을 먼저 쓴다.',
    member.MEMBER_RELATNSP_DIV_NAME AS member.RELATNSP_DIV_NAME WITH SYNONYMS ('결연구분', '결연/비결연') COMMENT = '결연구분(MM019 · 결연회원·비결연회원·혼합회원·중단회원) — 회원 마스터 현재값. 일시회원은 NULL(원천 개념 없음).',
    member.MEMBER_SPECL_MNG_NAME AS member.SPECL_MNG_NAME WITH SYNONYMS ('특별관리', '회원 특별관리', '특별관리 구분') COMMENT = '회원 특별관리 구분(MM012 · 일반·더네이버스클럽·더네이버스아너스클럽·평생회원·홍보대사·이사회·블랙리스트·테스트회원 등) — 대부분 「일반」. 🔴 테스트회원 포함 여부를 답변에 밝힌다.',
    member.MEMBER_FIRST_SPONSORSHIP_NAME AS member.FIRST_SPONSORSHIP_NAME WITH SYNONYMS ('최초후원사업', '최초 후원사업') COMMENT = '회원의 최초 후원사업명(회원 마스터 · DIM_SPONSORSHIP 매칭 100%).',
    member.MEMBER_MOBLPHON_STAT_NAME AS member.MOBLPHON_STAT_NAME WITH SYNONYMS ('휴대폰상태', '휴대폰 상태', '연락처 상태') COMMENT = '휴대폰 상태(MM008 · 정상·결번·타인번호) — 회원 마스터 현재값.',
    member.MEMBER_EMAIL_STAT_NAME AS member.EMAIL_STAT_NAME WITH SYNONYMS ('이메일상태', '이메일 상태') COMMENT = '이메일 상태(MM009 · 정상·계정없음·도메인오류) — 원천 코드 0 은 사전에 없어 NULL.',
    member.MEMBER_TSTM_DIV_NAME AS member.TSTM_DIV_NAME WITH SYNONYMS ('TM/TS 거절', '전화 거절구분', 'TM 거절') COMMENT = 'TM/TS 거절구분(MS026 · TM 거절·TS 거절·TMTS거절). 🔴 원천 코드 0(대다수 회원)은 사전에 없어 NULL — 「거절 없음」으로 단정하지 않는다.',
    member.MEMBER_ETC_CTTPC_STAT_NAME AS member.ETC_CTTPC_STAT_NAME WITH SYNONYMS ('기타연락처 상태') COMMENT = '기타연락처 상태(MM008 · 정상·결번·타인번호).',
    member.MEMBER_EMAIL_RECV_REFUSE_YN AS member.EMAIL_RECV_REFUSE_YN WITH SYNONYMS ('이메일 수신거부 수신', '이메일 수신항목 수신거부') COMMENT = '이메일 수신 항목에 「수신거부」(MS028 코드 1)가 있는가(TRUE/FALSE). 원천 구 체계 값(Y·N·0)·미입력 회원은 NULL — 「수신 동의 회원 수」는 TRUE 만 센다.',
    member.MEMBER_EMAIL_RECV_REGULAR_YN AS member.EMAIL_RECV_REGULAR_YN WITH SYNONYMS ('이메일 정기우편물 수신', '이메일 수신항목 정기우편물') COMMENT = '이메일 수신 항목에 「정기우편물」(MS028 코드 2)가 있는가(TRUE/FALSE). 원천 구 체계 값(Y·N·0)·미입력 회원은 NULL — 「수신 동의 회원 수」는 TRUE 만 센다.',
    member.MEMBER_EMAIL_RECV_RELATION_YN AS member.EMAIL_RECV_RELATION_YN WITH SYNONYMS ('이메일 결연이메일 수신', '이메일 수신항목 결연이메일') COMMENT = '이메일 수신 항목에 「결연이메일」(MS028 코드 3)가 있는가(TRUE/FALSE). 원천 구 체계 값(Y·N·0)·미입력 회원은 NULL — 「수신 동의 회원 수」는 TRUE 만 센다.',
    member.MEMBER_EMAIL_RECV_THANKS_YN AS member.EMAIL_RECV_THANKS_YN WITH SYNONYMS ('이메일 감사서비스 수신', '이메일 수신항목 감사서비스') COMMENT = '이메일 수신 항목에 「감사서비스」(MS028 코드 4)가 있는가(TRUE/FALSE). 원천 구 체계 값(Y·N·0)·미입력 회원은 NULL — 「수신 동의 회원 수」는 TRUE 만 센다.',
    member.MEMBER_EMAIL_RECV_WEBZINE_YN AS member.EMAIL_RECV_WEBZINE_YN WITH SYNONYMS ('이메일 웹진 수신', '이메일 수신항목 웹진') COMMENT = '이메일 수신 항목에 「웹진」(MS028 코드 5)가 있는가(TRUE/FALSE). 원천 구 체계 값(Y·N·0)·미입력 회원은 NULL — 「수신 동의 회원 수」는 TRUE 만 센다.',
    member.MEMBER_EMAIL_RECV_DEV_YN AS member.EMAIL_RECV_DEV_YN WITH SYNONYMS ('이메일 개발이메일 수신', '이메일 수신항목 개발이메일') COMMENT = '이메일 수신 항목에 「개발이메일」(MS028 코드 6)가 있는가(TRUE/FALSE). 원천 구 체계 값(Y·N·0)·미입력 회원은 NULL — 「수신 동의 회원 수」는 TRUE 만 센다.',
    member.MEMBER_POST_RECV_REFUSE_YN AS member.POST_RECV_REFUSE_YN WITH SYNONYMS ('우편물 수신거부 수신', '우편물 수신항목 수신거부') COMMENT = '우편물 수신 항목에 「수신거부」(MS027 코드 1)가 있는가(TRUE/FALSE). 원천 구 체계 값(Y·N·0)·미입력 회원은 NULL — 「수신 동의 회원 수」는 TRUE 만 센다.',
    member.MEMBER_POST_RECV_REGULAR_YN AS member.POST_RECV_REGULAR_YN WITH SYNONYMS ('우편물 정기우편 수신', '우편물 수신항목 정기우편') COMMENT = '우편물 수신 항목에 「정기우편」(MS027 코드 2)가 있는가(TRUE/FALSE). 원천 구 체계 값(Y·N·0)·미입력 회원은 NULL — 「수신 동의 회원 수」는 TRUE 만 센다.',
    member.MEMBER_POST_RECV_RELATION_YN AS member.POST_RECV_RELATION_YN WITH SYNONYMS ('우편물 결연우편 수신', '우편물 수신항목 결연우편') COMMENT = '우편물 수신 항목에 「결연우편」(MS027 코드 3)가 있는가(TRUE/FALSE). 원천 구 체계 값(Y·N·0)·미입력 회원은 NULL — 「수신 동의 회원 수」는 TRUE 만 센다.',
    member.MEMBER_POST_RECV_NEW_THANKS_YN AS member.POST_RECV_NEW_THANKS_YN WITH SYNONYMS ('우편물 신규/감사 우편 수신', '우편물 수신항목 신규/감사 우편') COMMENT = '우편물 수신 항목에 「신규/감사 우편」(MS027 코드 4)가 있는가(TRUE/FALSE). 원천 구 체계 값(Y·N·0)·미입력 회원은 NULL — 「수신 동의 회원 수」는 TRUE 만 센다.',
    req.REQ_SEND_GBN_TOP_NM AS req.SEND_GBN_TOP_NM WITH SYNONYMS ('발송 카테고리(대)', '발송구분 대분류', '발송 대분류') COMMENT = '발송 카테고리 대분류(회원서비스·결연·회비·회원·참여·사업보고·회원만족·기타 등) — 문자(SND) 요청에 값이 있다. 이메일·알림톡·우편 요청은 NULL(원천 개념 없음).',
    req.REQ_SEND_GBN_MID_NM AS req.SEND_GBN_MID_NM WITH SYNONYMS ('발송 카테고리(중)', '발송구분 중분류', '발송 중분류') COMMENT = '발송 카테고리 중분류(예: 신규결연회원발송·아동답신·기부금영수증·결제오류·장기회원감사서비스) — 문자(SND) 요청 전용.',
    req.REQ_SEND_GBN_BOT_NM AS req.SEND_GBN_BOT_NM WITH SYNONYMS ('발송 카테고리(소)', '발송구분 소분류', '발송 소분류') COMMENT = '발송 카테고리 소분류 — 문자(SND) 요청 전용.',
    req.REQ_MSG_DIV_NAME AS req.MSG_DIV_NAME WITH SYNONYMS ('메시지 구분', 'SMS/LMS/MMS', '문자 종류') COMMENT = '메시지 구분(MS010 · SMS·LMS·MMS·알림톡) — 알림톡(MSG_AT) 요청 전용 · 타 채널 NULL.',
    req.REQ_SNDNG_TIME_DIV_NAME AS req.SNDNG_TIME_DIV_NAME WITH SYNONYMS ('발송 시간 구분', '즉시/예약/분할') COMMENT = '발송 시간 구분(MS267 · 즉시발송·분할발송·예약발송) — 알림톡 요청 전용.',
    req.REQ_PSTMTR_PRCS_STAT_NAME AS req.PSTMTR_PRCS_STAT_NAME WITH SYNONYMS ('우편물 처리상태', '우편 발송완료 여부') COMMENT = '우편물 처리상태(MS061 · 발송대기·발송완료) — 우편(PSTMTR) 요청 전용.',
    req.REQ_RE_SNDNG_YN AS req.RE_SNDNG_YN WITH SYNONYMS ('재발송 여부', '재발신 여부') COMMENT = '재발신 여부(Y/N) — 우편 요청 전용.',
    req.REQ_LQY_YN AS req.LQY_YN WITH SYNONYMS ('대량발송 여부', '대량 여부') COMMENT = '대량 발송 여부(Y/N) — 우편 요청 전용.',
    req.REQ_CORP_TYPE_NAME AS req.CORP_TYPE_NAME WITH SYNONYMS ('발송 법인구분', '요청 법인') COMMENT = '발송 요청 법인구분(CM019 · 사단·사복) — 문자(SND) 요청 일부에만 값(대다수 NULL).',
    req.REQ_SEND_SPLIT_TYPE AS req.SEND_SPLIT_TYPE WITH SYNONYMS ('문자 분할 방식', '일괄/분할') COMMENT = '문자 발송 분할 방식 원천값(once = 일괄 · divide = 분할) — 문자(SND) 요청 전용.',
    fse.SND_SPNSR_NM AS fse.SND_SPNSR_NM WITH SYNONYMS ('발송 시점 후원사업', '발송 당시 후원사업') COMMENT = '문자(SND) 발송 시점 수신 회원의 후원사업명(원천 발송 스냅샷) — 타 채널 NULL. 현재 후원사업과 다를 수 있다.',
    fse.SND_DSCNTC_RSN_NM AS fse.SND_DSCNTC_RSN_NM WITH SYNONYMS ('발송 시점 중단사유', '발송 당시 중단사유') COMMENT = '문자(SND) 발송 시점 수신 회원의 중단사유명(중단 이력 회원만 값 · 원천 스냅샷) — 타 채널 NULL.',
    fse.SND_CHILD_PROJECT_COUNTRY AS fse.SND_CHILD_PROJECT_COUNTRY WITH SYNONYMS ('결연아동 사업국', '신규 결연아동 국가') COMMENT = '문자(SND) 발송 시점 신규 결연아동 사업국(방글라데시·우간다·에티오피아 등) — 결연 안내 발송 분석용 · 타 채널 NULL.',
    fse.SND_CHILD_WORKPLACE_NM AS fse.SND_CHILD_WORKPLACE_NM WITH SYNONYMS ('결연아동 사업장', '신규 결연아동 사업장') COMMENT = '문자(SND) 발송 시점 신규 결연아동 사업장명 — 타 채널 NULL.',
    -- 🆕 [2026-10-14 O225-C] 발송 캠페인 속성(DIM_CAMPAIGN) + SND 회원 최종·현재 캠페인코드
    campaign.CAMPAIGN_NAME AS campaign.CAMPAIGN_NAME WITH SYNONYMS ('캠페인명', '발송 캠페인', '캠페인') COMMENT = '문자(SND) 발송 캠페인명. 타 채널 = (미매핑)(원천에 캠페인코드 없음).',
    campaign.CAMPAIGN_TYPE AS campaign.CAMPAIGN_TYPE WITH SYNONYMS ('캠페인 카테고리', '주요캠페인', '캠페인유형') COMMENT = '캠페인 카테고리(MM294 라벨).',
    campaign.DOMESTIC_OVERSEAS AS campaign.DOMESTIC_OVERSEAS WITH SYNONYMS ('국내해외', '국내/해외') COMMENT = '캠페인유형 국내/통합/해외(MM295).',
    campaign.BIZ_CASE_TYPE AS campaign.BIZ_CASE_TYPE WITH SYNONYMS ('사업사례', '사업/사례') COMMENT = '캠페인유형 굿즈/기타/사례/사업(MM296).',
    campaign.INFLOW_PATH AS campaign.INFLOW_PATH WITH SYNONYMS ('인입경로', '회원인입', '개발인입경로') COMMENT = '캠페인 개발인입경로(MM293).',
    campaign.MARKETING_CAMPAIGN AS campaign.MARKETING_CAMPAIGN WITH SYNONYMS ('마케팅캠페인', '마케팅캠페인명') COMMENT = '마케팅캠페인명.',
    campaign.MKTG_CHANNEL_NM AS campaign.MKTG_CHANNEL_NM WITH SYNONYMS ('마케팅채널', '캠페인 채널') COMMENT = '캠페인 마케팅 채널명(TC_MKTNG_DTL_CD C002). 발송 채널(CHANNEL)과 다른 축이다.',
    campaign.MKTG_UTM_NM AS campaign.MKTG_UTM_NM WITH SYNONYMS ('UTM', 'UTM 캠페인') COMMENT = '캠페인 UTM 라벨(TC_MKTNG_DTL_CD U001).',
    campaign.PARENT_CAMPAIGN_NAME AS campaign.PARENT_CAMPAIGN_NAME WITH SYNONYMS ('상위캠페인', '상위캠페인명') COMMENT = '상위캠페인명. 상위가 없으면 NULL.',
    campaign.PROMO_METHOD_NAME AS campaign.PROMO_METHOD_NAME WITH SYNONYMS ('홍보방법') COMMENT = '홍보방법명(CM008).',
    campaign.CMMN_BRND_NM AS campaign.CMMN_BRND_NM WITH SYNONYMS ('공통브랜드') COMMENT = '공통브랜드명(MM297).',
    campaign.CPR_DIV_NM AS campaign.CPR_DIV_NM WITH SYNONYMS ('캠페인 법인구분') COMMENT = '캠페인 법인구분명(CM019).',
    campaign.SPNSR_DIV_NM AS campaign.SPNSR_DIV_NM WITH SYNONYMS ('캠페인 후원구분') COMMENT = '캠페인 후원구분명(CM035 정기/일시).',
    fse.SND_LAST_CMPGN AS fse.SND_LAST_CMPGN WITH SYNONYMS ('발송 시점 최종캠페인코드') COMMENT = '문자(SND) 발송 시점 수신 회원의 최종 캠페인코드(코드값 · 라벨은 캠페인 SV 로) — 타 채널 NULL.',
    fse.SND_CURRENT_CMPGN AS fse.SND_CURRENT_CMPGN WITH SYNONYMS ('발송 시점 현재캠페인코드') COMMENT = '문자(SND) 발송 시점 수신 회원의 현재 캠페인코드(코드값) — 타 채널 NULL.'
  )
  METRICS (
    fse.TOTAL_SEND_MEMBERS AS SUM(fse.SEND_MEMBERS)
      WITH SYNONYMS ('발송수', '발송 건수', '발송건', '발송 횟수')
      COMMENT = '발송 **건수** 합계. F(가산). 🔴**회원수가 아니다** — 같은 회원에게 여러 번 발송되면 그만큼 중복 계수된다. 회원 「명」 수를 묻는 질문(발송 회원수·수신 대상 몇 명)에는 이 metric 을 쓰지 말고 DISTINCT_SEND_MEMBERS 를 쓴다. ⚠️metric 명에 MEMBERS 가 들어간 것은 기저 컬럼명(SEND_MEMBERS) 을 따른 역사적 잔재이며 의미는 건수다.',
    fse.DISTINCT_SEND_MEMBERS AS COUNT(DISTINCT fse.MEMBER_DK)
      WITH SYNONYMS ('발송 회원수', '발송 고유회원수', '발송(명)', '발송명', '수신 대상 회원수', '수신자수', '몇 명에게 발송')
      COMMENT = '발송 대상 **고유 회원수(명)**. D(distinct) — 🔴가산 금지: 월별로 뽑아 합산하면 여러 달 수신한 회원이 중복된다. 기간을 바꾸면 반드시 재집계할 것. 정본 「발송(명)」이 이 metric 이다(발송 건수는 TOTAL_SEND_MEMBERS).',
    fse.D5_LETTER_MEMBERS AS SUM(fse.D5_LETTER_PART_MEMBERS)
      WITH SYNONYMS ('발송후 5일 서신참여(명)', 'D5 서신참여') COMMENT = '공#139 발송 다음날(D+1)~+5일 안에 서신 접수가 있는 발송 대상 수(중복 포함). F(가산).',
    fse.D5_LETTER_CNT AS SUM(fse.D5_LETTER_PART_CNT)
      WITH SYNONYMS ('발송후 5일 서신참여(건)') COMMENT = '공#140 위 매칭 회원의 활동(건) 합. F(가산).',
    fse.D5_GIFT_MEMBERS AS SUM(fse.D5_GIFT_PART_MEMBERS)
      WITH SYNONYMS ('발송후 5일 선물금참여(명)', 'D5 선물금참여') COMMENT = '공#141 발송 다음날(D+1)~+5일 안에 선물금 참여가 있는 발송 대상 수(중복 포함). ⚠️ 선물금 원천에 접수일이 없어 선물금 발송일로 매칭한다. F(가산).',
    fse.D5_GIFT_CNT AS SUM(fse.D5_GIFT_PART_CNT)
      WITH SYNONYMS ('발송후 5일 선물금참여(건)') COMMENT = '공#142 위 매칭 회원의 활동(건) 합. F(가산).',
    fse.D5_INCREASE_MEMBERS AS SUM(fse.D5_INCREASE_PART_MEMBERS)
      WITH SYNONYMS ('발송후 5일 증액참여(명)', 'D5 증액') COMMENT = '공#143 발송 다음날(D+1)~+5일 안에 증액 개발(MM015 ''2'')이 있는 발송 대상 수(중복 포함). F(가산).',
    fse.D5_INCREASE_CNT AS SUM(fse.D5_INCREASE_PART_CNT)
      WITH SYNONYMS ('발송후 5일 증액참여(건)') COMMENT = '공#144 위 매칭 회원의 활동(건) 합. F(가산).',
    fse.D5_STOP_MEMBERS_SUM AS SUM(fse.D5_STOP_MEMBERS)
      WITH SYNONYMS ('발송후 5일 중단(명)', 'D5 중단') COMMENT = '공#145 발송 다음날(D+1)~+5일 안에 후원중단이 있는 발송 대상 수(중복 포함). F(가산). 🔴 인과가 아니라 시간 창 매칭이다.',
    fse.D5_STOP_CNT_SUM AS SUM(fse.D5_STOP_CNT)
      WITH SYNONYMS ('발송후 5일 중단(건)') COMMENT = '공#146 위 매칭 회원의 활동(건) 합. F(가산).',
    fse.D5_STOP_DISTINCT_MEMBERS AS COUNT(DISTINCT CASE WHEN fse.D5_STOP_MEMBERS > 0 THEN fse.MEMBER_DK END)
      WITH SYNONYMS ('발송후 5일 중단 고유회원수', '발송 후 5일 내 중단한 회원 수', 'D5 중단 회원수')
      COMMENT = '발송 다음날(D+1)~+5일 안에 후원중단이 있는 **고유 회원수(명)**. D(distinct · 가산 금지). 「몇 명이 중단했나」 질문은 이 지표, 발송 행 기준 중복 포함 수는 D5_STOP_MEMBERS_SUM. 🔴 인과가 아니라 시간 창 매칭이다.',
    fse.SERVICE_MEMBERS_SUM AS SUM(fse.SERVICE_MEMBERS)
      WITH SYNONYMS ('서비스(명)', '회원서비스 발송(명)') COMMENT = '공#160 발송구분(대) 「회원서비스」 발송 대상 수(발송 행 기준 · 중복 포함). 고유 회원수가 필요하면 DISTINCT_SEND_MEMBERS 에 같은 조건을 건다. ⚠️ 발송구분이 없는 발송은 포함되지 않는다.',
    fse.SERVICE_CNT_SUM AS SUM(fse.SERVICE_CNT)
      WITH SYNONYMS ('서비스(건)') COMMENT = '공#161 「회원서비스」 발송 대상 회원의 활동(건) 합(약정금액 ÷ 10,000). F(가산).',
    fse.TOTAL_OPEN_MEMBERS AS SUM(fse.OPEN_MEMBERS)
      WITH SYNONYMS ('오픈수', '오픈(명)', '링크 클릭수', '문자 클릭수', '클릭(명)')
      COMMENT = '문자 오픈 수 = **링크 클릭**(현업 회신 44). 발송 행별 0/1 플래그 합이라 중복 포함이다(고유 회원은 DISTINCT_SEND_MEMBERS 에 조건을 건다). 🔴 **문자(SND) 채널에만 값이 있다** — 다른 채널은 오픈 원천이 없어 NULL 이다(0 이 아니다) ⇒ 오픈율 분모는 SND 발송으로만 잡고 CHANNEL=''SND'' 를 반드시 건다. F(가산).',
    fse.OPEN_RATE_SND AS SUM(fse.OPEN_MEMBERS) / NULLIF(SUM(CASE WHEN fse.OPEN_MEMBERS IS NOT NULL THEN fse.SEND_MEMBERS END), 0) * 100
      WITH SYNONYMS ('오픈율', '클릭률', '링크 클릭률', '문자 오픈율')
      COMMENT = '문자 오픈율(%) = 링크 클릭 ÷ 오픈 기록이 있는 발송(SND) ×100(현업 회신 44). 비율(N · 재집계 금지). 🔴 SND 전용 — 다른 채널 발송은 분모에서 빠진다(오픈 원천 부재).'
  )
  COMMENT = '메시지 발송 성과 및 고객 접점 서비스 분석 (base: GOLD.FACT_MESSAGE_DISPATCH). [Grain: 발송일 × 회원 × 서비스]. [활성 지표: 발송/성공/실패/오픈수, WIDE_BIGQUERY_BEHAVIOR]. [주의: 배분규칙필요 앵커_경합 방지 · 캠페인 축 = 문자(SND) 발송 캠페인만 배선(원천 SND_MEMBER_LIST.CMPGN_CD) — 이메일·알림톡·우편은 원천에 캠페인 키가 없어 (미매핑)(구조적 부재) ⇒ 「캠페인별 발송」은 SND 기준임을 밝힌다]. [원천: CRM → BRONZE_CRM → SILVER.CRM_SEND_MEMBER/REQUEST → GOLD.FACT_MESSAGE_DISPATCH].'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 건수 vs 회원수: 발송 건수는 TOTAL_SEND_MEMBERS, 수신 회원수(명)는 DISTINCT_SEND_MEMBERS (distinct) 사용. (2) 상태 라벨 분기: 발송상태 질의는 SEND_STATUS_NAME(시스템 상태) 또는 SEND_RESULT_NAME(통신사 도달결과)을 사용하며 두 축을 혼합 합산하지 않음. (3) 채널 동반 필터: SEND_STATUS 는 채널별 코드체계가 상이하므로 CHANNEL 조건을 동반할 것. (4) 기간 미지정 시: 데이터 최신 연월 기준 직전 12개월로 한정하며 GROUP BY ROLLUP((연,월)) 반환. (5) 교차 불가: 발송 앵커 개발실적/중단 결합 요청은 배분 규칙 부재로 SQL 생성 불가 사유 안내. 단 정본 「발송(+5일차)」 지표(D5_* metric: 서신·선물금·증액·중단)는 정의된 시간창 매칭이므로 그 metric 으로 답한다(인과가 아니라 D+1~D+5 창 매칭이며 발송 당일은 처리 통보 역인과 때문에 제외됨을 밝힌다 · DEC-33). (6) 판정 라벨 [배분규칙필요]: 발송 grain 으로 회비·회원월 measure(개발/중단 건·명, 납입방식)를 요구받으면 도구를 억지로 고르지 않고 「배분(귀속) 규칙이 필요한 업무 판단 사안」이라고 답한다 — SQL 을 만들지 않으며 「데이터가 없다」로도 답하지 않는다(데이터는 있고 귀속 규칙이 없다). (7) 판정 라벨 [앵커_경합]: 개발실적보고 3-x 섹션은 이 뷰와 다른 팩트가 경합하므로 하나를 골라 섹션 전체를 답하지 않는다 — 각 팩트를 따로 호출해 표를 분리하고 표마다 grain 을 밝힌다. (기준시점 규칙) 「최근 N개월」·기간 미지정 질의의 기준 시점은 **비상관 CTE 1개**에서 그 CTE 의 FROM 에 쓴 이름으로만 MAX 를 구하고 본 쿼리에 CROSS JOIN 한다. 스칼라 서브쿼리·상관 서브쿼리·ORDER BY … LIMIT/OFFSET 서브쿼리로 기준 시점을 구하지 않는다. CTE 안에서 그 CTE 의 FROM 에 없는 별칭을 쓰지 않는다. 날짜 조건은 DIMENSIONS 에 선언된 날짜 차원(date.FULL_DATE · 월키 MONTH_KEY)으로만 걸고 팩트에 없는 날짜 컬럼을 팩트 별칭에 붙이지 않는다. metric 이름을 컬럼처럼 참조하지 말고 metric 정의식(SUM(원천컬럼))으로 집계한다. ORDER BY 에는 SELECT 에서 정의한 별칭을 글자 그대로 쓴다. (🆕 O206 서비스명 매핑) 「○○서비스」처럼 서비스(카테고리) 이름으로 물으면, 이 SV 에는 원천 서비스 카테고리 축이 없으므로 fse.SEND_TITLE 부분일치로 매핑하고 답변에 「상위 카테고리 정의에 없어 발송 제목으로 매핑했다(매핑한 제목 패턴: …)」를 반드시 밝힌다. 선넘는좋은일 즉시·개별화 신규(사단)·행운의 카드·장기회원 서비스 4종의 수신 회원 분석은 서비스코드 기준 판정이 있는 서비스 수신 코호트 SV 소관이다. (🆕 O225-C 캠페인 축) 발송 캠페인별 질문은 campaign 차원으로 묶는다 — 캠페인코드는 문자(SND) 발송에만 있으므로 결과에 「(미매핑)」(이메일·알림톡·우편 + 코드 미기재 SND)을 ROLLUP 과 함께 표시하고 「문자(SND) 발송 기준」이라고 밝힌다.'
  AI_VERIFIED_QUERIES (
    vqr_monthly_send_members AS (
      QUESTION '월별 발송 대상 회원수'
      VERIFIED_BY '(DW = O190)'
      SQL 'SELECT date.YEAR, date.MONTH, SUM(fse.SEND_MEMBERS) AS TOTAL_SEND_MEMBERS FROM fse LEFT JOIN date ON fse.DATE_SK = date.DATE_SK GROUP BY date.YEAR, date.MONTH ORDER BY date.YEAR, date.MONTH'
    ),
    vqr_o191_last6m_d5 AS (
      QUESTION '최근 6개월 월별 발송 후 5일 내 증액·중단 매칭 회원수'
      VERIFIED_BY '(DW = O191)'
      SQL 'WITH mx AS (SELECT MAX(date.FULL_DATE) AS md FROM fse JOIN date ON fse.DATE_SK = date.DATE_SK) SELECT date.YEAR, date.MONTH, SUM(fse.D5_INCREASE_PART_MEMBERS) AS D5_INCREASE_MEMBERS, SUM(fse.D5_STOP_MEMBERS) AS D5_STOP_MEMBERS_SUM FROM fse JOIN date ON fse.DATE_SK = date.DATE_SK CROSS JOIN mx WHERE date.FULL_DATE > DATEADD(MONTH, -6, mx.md) AND date.FULL_DATE <= mx.md GROUP BY date.YEAR, date.MONTH ORDER BY date.YEAR, date.MONTH'
    ),
    vqr_o203_title_d5_stop AS (
      QUESTION '2025년 9월 행운의 카드 알림톡 발송 회원 중 발송 후 5일 내 중단한 회원 수'
      VERIFIED_BY '(DW = O203 · 기대 30명)'
      SQL 'SELECT COUNT(DISTINCT CASE WHEN fse.D5_STOP_MEMBERS > 0 THEN fse.MEMBER_DK END) AS D5_STOP_DISTINCT_MEMBERS, COUNT(DISTINCT fse.MEMBER_DK) AS DISTINCT_SEND_MEMBERS FROM fse JOIN date ON fse.DATE_SK = date.DATE_SK JOIN service ON fse.SERVICE_SK = service.SERVICE_SK WHERE fse.SEND_TITLE ILIKE ''%행운%카드%'' AND service.CHANNEL = ''MSG_AT'' AND date.YEAR = 2025 AND date.MONTH = 9'
    )
  );

-- SV_EVENT_PARTICIPATION ← 05_05_SV_DDL_EVENT_PARTICIPATION.sql
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_EVENT_PARTICIPATION
  TABLES (
    fep AS GN_DW.GOLD.FACT_EVENT_ATTENDANCE
      WITH SYNONYMS ('행사 참여', '이벤트 참여', '행사 출석')
      COMMENT = '행사/이벤트 신청 및 참석 성과 분석 (base: GOLD.FACT_EVENT_ATTENDANCE). [Grain: 행사일 × 회원 × 행사]. [활성 지표: 모집/신청/대기/취소/참석 인원수]. [주의: 일반/캠페인 행사별 상태코드 구분 집계]. [원천: CRM → BRONZE_CRM → SILVER.CRM_EVENT_PARTICIPATION → GOLD.FACT_EVENT_ATTENDANCE].',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '참여일')
      COMMENT = '일 차원. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.',
    event AS GN_DW.GOLD.DIM_EVENT
      PRIMARY KEY (EVENT_SK)
      WITH SYNONYMS ('행사', '이벤트')
      COMMENT = '행사 차원. EVENT_SK 고아분은 Unknown(SK=0)으로 라우팅되므로 행사명별 집계는 부분집합이다(이슈 E). [원천] 시스템=CRM(eCRM 행사관리) · BRONZE=GN_DW.BRONZE_CRM: TM_MS_EVENT(EVENT_NM·STRT_DE) ∪ TM_MS_CRMN(캠페인행사) · SILVER=CRM_EVENT.',
    member AS GN_DW.GOLD.DIM_MEMBER
      PRIMARY KEY (MEMBER_DK)
      WITH SYNONYMS ('회원')
      COMMENT = '정규 회원 마스터 차원 (회원 1명 = 1행 · MEMBER_DK 유일). 🔴 IS_CURRENT 컬럼은 없다 — 상태 이력이 필요하면 DIM_MEMBER_STATUS_HISTORY 를 쓴다. 불변/현재 속성 전용. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM · SILVER=CRM_MEMBER · GOLD=DIM_MEMBER.'
  )
  RELATIONSHIPS (
    fep_to_date   AS fep (DATE_SK)   REFERENCES date,
    fep_to_event  AS fep (EVENT_SK)  REFERENCES event,
    fep_to_member AS fep (MEMBER_DK) REFERENCES member
  )
  DIMENSIONS (
    date.PART_DATE       AS date.FULL_DATE       WITH SYNONYMS ('참여일', '행사일', '일자', '날짜') COMMENT = '참여일',
    date.FULL_DATE AS date.FULL_DATE  COMMENT = '달력 날짜(DIM_DATE.FULL_DATE) — PART_DATE 와 같은 값이다(Analyst 가 추측하는 식별자를 실재화). 둘 중 하나만 쓴다.',
    date.CAL_YEAR        AS date.YEAR            WITH SYNONYMS ('연도', '년')  COMMENT = '연도',
    date.CAL_MONTH       AS date.MONTH           WITH SYNONYMS ('월')         COMMENT = '월(1~12)',
    date.YEAR AS date.YEAR    COMMENT = '연도(DIM_DATE.YEAR) — CAL_YEAR 와 같은 값(Analyst 가 추측하는 식별자를 실재화). 둘 중 하나만 쓴다.',
    date.MONTH AS date.MONTH  COMMENT = '월(DIM_DATE.MONTH) — CAL_MONTH 와 같은 값(추측 식별자 실재화). 둘 중 하나만 쓴다.',
    event.EVENT_NAME     AS event.EVENT_NAME     WITH SYNONYMS ('행사명', '이벤트명') COMMENT = '행사명',
    event.EVENT_KIND     AS event.EVENT_KIND     WITH SYNONYMS ('행사종류코드', '행사계통코드') COMMENT = '행사 종류 **원천 판별자 코드**. 실제값 2종 + NULL: ''CRMN''·''EVENT'' · NULL(행사 마스터 미매핑). 🔴 이 값은 업무 분류가 아니라 **행사 마스터가 두 원천의 결합이라는 사실**을 나타낸다 — ''EVENT''=일반행사 원천 · ''CRMN''=캠페인행사 원천. ✅ **사람이 읽는 라벨은 EVENT_KIND_NAME 축을 쓴다**(''일반행사''·''캠페인행사''·''(미매핑)''). 🔴 이 코드축으로 답하지 말고 라벨축으로 답할 것 — 현업은 코드를 모른다. ⚠️ 위 2종 외의 값으로 필터하면 0행이다',
    event.EVENT_KIND_NAME AS event.EVENT_KIND_NAME WITH SYNONYMS ('행사종류', '행사구분계통') COMMENT = '행사 종류 라벨 — **현업 응답용 정본 축**이다. 실제값 3종: ''일반행사''·''캠페인행사''·''(미매핑)''. 🔴 이 라벨은 원천 계통을 뜻한다(일반행사 마스터 / 캠페인행사 마스터) — 온·오프라인 구분이 아니다. ⚠️ ''(미매핑)''은 참여 행이 행사 마스터에 붙지 않은 경우이며 비중이 작지 않다 — 이 축으로 분해하면 그 덩어리를 함께 밝힌다',
    fep.PART_EVENT_KIND AS fep.EVENT_KIND WITH SYNONYMS ('원천계열코드', '참여원천코드') COMMENT = '원천 계열 판별 **코드 — 팩트 자체 보유**(행사 마스터 조인과 무관). 실제값 2종: ''CRMN''·''EVENT''. 🔴 차원축 EVENT_KIND 와 값은 같지만 **결손이 없다** — 차원축은 행사 미매칭 구간이 ''(미매핑)'' 이라 계열을 알려주지 못한다. ✅ 라벨은 PART_EVENT_KIND_NAME 축을 쓴다(현업 답변에 코드를 내지 말 것). ⚠️ 위 2종 외의 값으로 필터하면 0행이다',
    fep.PART_EVENT_KIND_NAME AS fep.EVENT_KIND_NAME WITH SYNONYMS ('원천계열', '참여원천', '행사계열') COMMENT = '원천 계열 판별 **라벨 — 계열 분해의 정본 축이다**. 실제값 2종: ''일반행사''·''캠페인행사''. 🔴🔴 **코드·라벨 축이 원천별로 갈리는 문제(참여상태·경로·채널)를 분해할 때는 차원축 EVENT_KIND_NAME 이 아니라 이 축을 동반한다** — 이 축은 팩트가 원천 분기로 보유해 **전건 값을 가지며 ''(미매핑)'' 사각지대가 없다.  차원축은 행사 마스터에 매칭된 행만 계열을 알려주므로 미매칭 구간에서 무력하다. 🔴 이 라벨은 원천 계통을 뜻한다(일반행사 원천 / 캠페인행사 원천) — 온·오프라인 구분이 아니다. ⚠️ 행사명·행사구분 등 **차원 속성별 분해는 여전히 부분집합**이다(미매칭분은 Unknown 으로 라우팅) — 계열이 확정되는 것과 행사가 확정되는 것은 다르다',
    event.EVENT_CATEGORY AS event.EVENT_CATEGORY WITH SYNONYMS ('행사구분코드') COMMENT = '행사 구분 **원천 코드**(라벨 아님). 🔴🔴 **두 원천의 코드체계가 한 컬럼에 혼재한다** — **일반행사(EVENT) = 백 단위**(''100''~''500'' · 코드군 MS286) · **캠페인행사(CRMN) = 한/두 자리**(''1''~''16'' · 코드군 MS002). 따라서 **PART_EVENT_KIND_NAME 과 함께 보지 않으면 서로 다른 체계를 한 표에 섞는다.** ✅ **사람이 읽는 라벨은 EVENT_CATEGORY_NAME 축을 쓴다**(R1 — 두 코드군 모두 등급 B 확정). ⚠️ 센티넬 행(''(미매핑)'')은 코드가 없어 라벨도 NULL 이다 — 결측이 아니라 조인 대상 부재다. 실제값 19종: ''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''·''9''·''12''·''13''·''14''·''15''·''16''·''100''·''200''·''300''·''400''·''500'' + NULL',
    event.EVENT_CATEGORY_NAME AS event.EVENT_CATEGORY_NAME WITH SYNONYMS ('행사구분', '행사구분명', '행사종류구분') COMMENT = '행사 구분 **라벨 — 현업 응답용 정본 축**이다. 「행사 구분별」 질문은 이 축으로 답한다. 실제값 19종 — 일반행사 계열(코드군 MS286): 온라인·앱전용·회지·리플렛·오프라인 / 캠페인행사 계열(코드군 MS002): 국내사업장방문·해외사업장방문·좋은이웃콘서트·굿멤버스데이(본부)·굿멤버스데이(지부)·굿모닝·문화서비스·문화서비스_전시·문화서비스_서적·문화서비스_공연·기업제휴·특성화회원조직·I''m your pen·기타. ⚠️ 값에 아포스트로피가 포함된 라벨(I''m your pen)이 있어 따옴표 열거 규약 대신 **종수 선언 + 나열**로 적는다 — 종수는 게이트가 실측과 대조한다. 🔴🔴 **라벨공간이 원천별로 갈린다** — 두 코드군의 라벨이 한 축에 섞여 있으므로 이 축으로 분해할 때는 **PART_EVENT_KIND_NAME 을 동반**해 어느 계통인지 밝힌다. ⚠️ 센티넬 행은 라벨 NULL 이다(코드 자체가 없다)',
    fep.PART_STATUS AS fep.PART_STATUS WITH SYNONYMS ('참여상태코드') COMMENT = '참여 상태 **원천 코드**(라벨 아님). 🔴🔴 **두 원천의 코드체계가 혼재한다** — 일반행사(EVENT) = 백 단위(''110''~''220'' · 코드군 MS304) · 캠페인행사(CRMN) = 한 자리(''1''~''6'' · 코드군 MS006) ⇒ **PART_EVENT_KIND_NAME 동반 필수**. 🔴 **두 원천은 「참여」의 정의가 다르다** — MS304 는 **다단계 이벤트의 단계 통과 여부**이고 MS006 은 신청/참여/불참이다. 합산하면 정의가 혼입된다. ✅ 라벨은 PART_STATUS_NAME 축을 쓴다(R1). ⚠️ ''`)`'' 는 **원천 입력 오류(오염값)** 이며 라벨을 붙이지 않는다 — 정상 코드로 취급하지 말 것. 실제값 19종: '')''·''1''·''2''·''3''·''4''·''5''·''6''·''110''·''120''·''130''·''140''·''150''·''160''·''170''·''180''·''190''·''200''·''210''·''220'' + NULL',
    fep.PART_STATUS_NAME AS fep.PART_STATUS_NAME WITH SYNONYMS ('참여상태', '참여상태명') COMMENT = '참여 상태 **라벨 — 현업 응답용 정본 축**이다. 실제값 18종: ''Success''·''Fail''·''1_step_right''·''1_step_fail''·''2_step_right''·''2_step_fail''·''3_step_right''·''3_step_fail''·''4_step_right''·''4_step_fail''·''5_step_right''·''5_step_fail''·''신청''·''참여''·''불참''·''대기''·''취소''·''대기(결제)'' + NULL. 🔴🔴 **라벨공간이 원천별로 갈린다 — 영문 라벨과 한글 라벨이 섞여 있다**: 영문 계열(Success·Fail·n_step_*)은 **일반행사(MS304)**, 한글 계열(신청·참여·불참·대기·취소·대기(결제))은 **캠페인행사(MS006)** 다. ⇒ 「참여 상태별」로 분해하면 **한 의미가 두 라벨로 갈라진다**(예: 참여 성공이 ''Success'' 와 ''참여'' 로 나뉜다) — **PART_EVENT_KIND_NAME 을 반드시 동반**하고 두 계열을 합산하지 말 것. 🔴 두 원천은 참여의 정의 자체가 다르다(단계 통과 vs 신청/참여). ⚠️ MS304 라벨이 **사전에 영문으로 등재**돼 있어 그대로 노출한다 — 한글 표기는 현업 회신 대기. ⚠️ NULL 은 오염값·센티넬처럼 사전에 없는 코드 행이다(라벨 창작 금지)',
    fep.PART_PATH AS fep.PART_PATH WITH SYNONYMS ('참여경로코드', '신청경로코드') COMMENT = '참여·신청 경로 **원천 코드**(라벨 아님). 🔴 **두 체계 혼재** — 일반행사 = 백 단위(코드군 MS303 · 원천 컬럼 참여경로) · 캠페인행사 = 한 자리(코드군 MS004 · 원천 컬럼 **신청경로**) ⇒ **PART_EVENT_KIND_NAME 동반 필수**. ✅ 라벨은 PART_PATH_NAME 축을 쓴다. ⚠️ ''`)`'' 는 오염값이며 라벨 없음. 실제값 13종: '')''·''1''·''2''·''3''·''4''·''5''·''6''·''100''·''200''·''300''·''500''·''600''·''700'' + NULL',
    fep.PART_PATH_NAME AS fep.PART_PATH_NAME WITH SYNONYMS ('참여경로', '신청경로') COMMENT = '참여·신청 경로 **라벨 — 현업 응답용 정본 축**이다. 실제값 12종: ''webmail''·''homepage''·''출석''·''텍스트''·''독자의견''·''독자이벤트''·''홈페이지''·''상담센터''·''초대''·''이메일''·''모바일웹''·''APP'' + NULL. 🔴🔴 **같은 의미가 두 라벨로 갈라져 있다** — ''homepage''(일반행사 MS303)와 ''홈페이지''(캠페인행사 MS004)가 **동시에 존재**한다. 사전 라벨이 원천별로 다르게 등재된 결과이며 우리가 통합 라벨을 만들면 **라벨 창작**이 된다 ⇒ 통합하지 않는다. ⇒ 「참여경로별」로 분해하면 **한 의미가 두 행으로 갈라지므로 PART_EVENT_KIND_NAME 을 반드시 동반**하고, 두 계열을 하나로 합쳐 답하려면 **합쳤다는 사실과 대응 관계를 명시**한다. ⚠️ 오염값·사전 미등재 행은 라벨 NULL 이다',
    fep.PART_CHANNEL AS fep.PART_CHANNEL WITH SYNONYMS ('참여채널코드') COMMENT = '참여 채널 **원천 코드**(라벨 아님) — **일반행사 계열만 값을 갖는다**(코드군 MS302). 🟢 **캠페인행사 원천에는 채널 컬럼이 아예 없다**(원천 스캔: 캠페인행사 분기의 채널 non-null **0건**) ⇒ 그 참여 행의 NULL 은 **구조적 부재**다. 🔴🔴 **그러나 NULL 전부를 구조적 부재로 읽지 말 것** — 일반행사 계열에도 NULL 이 **소수** 있고(오염값 행 + 원천 미입력 행) 그쪽은 **결측**이다. NULL 을 해석할 때는 계열을 먼저 가른다. ✅ 라벨은 PART_CHANNEL_NAME 축을 쓴다. ⚠️ ''`)`'' 는 오염값이며 라벨 없음. 실제값 9종: '')''·''100''·''200''·''300''·''400''·''500''·''600''·''700''·''800'' + NULL',
    fep.PART_CHANNEL_NAME AS fep.PART_CHANNEL_NAME WITH SYNONYMS ('참여채널', '참여기기') COMMENT = '참여 채널 **라벨 — 현업 응답용 정본 축**이다(코드군 MS302 · 단일 체계이므로 이 축은 라벨공간이 갈리지 않는다). 실제값 8종: ''PC''·''mobile web''·''APP''·''회지(온라인)''·''회지(오프라인)''·''SNS''·''문자''·''행사'' + NULL. 🔴 **NULL 은 두 가지가 섞여 있다 — 하나로 설명하지 말 것**: ㉠ **캠페인행사 참여 행 전량**은 원천에 채널 컬럼이 없어 NULL 이다(**구조적 부재** · 원천 스캔으로 확인) ㉡ **일반행사 계열의 소수 행**도 NULL 이며 그쪽은 **결측 또는 오염값**이다. ⇒ 이 축으로 분해하면 **캠페인행사 전량이 NULL 버킷에 모이므로 계열을 동반해 그 사실을 밝히고**, 남는 NULL 을 「전부 캠페인행사」라고 단정하지 않는다. ⚠️ 참여 경로(PART_PATH_NAME)와 다른 축이다 — 채널은 기기·매체, 경로는 참여 형태다',
    fep.SELF_PART_FLAG AS fep.SELF_PART_FLAG WITH SYNONYMS ('본인참여', '본인참여여부', '본인 참여') COMMENT = '본인참여 여부 — 캠페인행사 신청의 자기참여코드(MS060)에서 파생: ''1''(본인만)·''2''(함께) ⇒ TRUE · ''0''(동반자만) ⇒ FALSE. 🔴 **캠페인행사 전용**이다 — 일반행사 원천에는 자기참여 컬럼이 없어 일반행사 행은 전건 NULL 이다(결측이 아니라 구조적 부재) ⇒ 이 축으로 분해할 때는 PART_EVENT_KIND_NAME 을 동반하고 NULL 을 「본인 미참여」로 읽지 않는다. ⚠️ 캠페인행사에도 코드가 비어 있는 소수 행은 NULL 이다',
    fep.SELF_PARTCPT_CD AS fep.SELF_PARTCPT_CD WITH SYNONYMS ('자기참여코드', '본인참여코드', '참여형태코드') COMMENT = '자기참여 **원천 코드**(코드군 MS060 · 캠페인행사 전용). 실제값 3종: ''0''·''1''·''2'' + NULL. 사전 라벨: ''0''=동반자만 · ''1''=본인만 · ''2''=함께. 🔴 일반행사 행은 전건 NULL(구조적 부재). 여부만 필요하면 SELF_PART_FLAG 를 쓴다',
    event.CRMN_PLACE_NM AS event.CRMN_PLACE_NM WITH SYNONYMS ('행사장소', '장소', '행사장소명') COMMENT = '행사장소명 — 캠페인행사 마스터(TM_MS_CRMN) 전용 속성. 🔴 일반행사 마스터에는 장소 컬럼이 없어 일반행사는 전건 NULL 이다(구조적 부재). ⚠️ 캠페인행사도 장소를 입력한 행사만 값을 가진다 ⇒ 장소별 집계는 부분집합이며 NULL 덩어리를 함께 밝힌다(채움 비율은 조회로 확인한다)',
    member.CHRCTR_RECPTN_YN AS member.CHRCTR_RECPTN_YN WITH SYNONYMS ('문자수신여부', '문자수신', 'SMS 수신동의') COMMENT = '회원 문자수신 여부(현재 마스터 스냅샷 · 참여 시점 값이 아니다). 실제값 2종: ''Y''·''N'' + NULL. ⚠️ NULL 은 원천 미입력이며 ''N'' 으로 읽지 않는다',
    member.GENDER_NAME   AS member.GENDER_NAME   WITH SYNONYMS ('성별')     COMMENT = '회원 성별 — 정본 공#130. 실제값 5종: ''남자''·''여자''·''기업''·''단체''·''기타''(CM017 라벨).',
    member.SEX           AS member.SEX           WITH SYNONYMS ('성별코드') COMMENT = '성별 원천코드(CM013). 이 차원의 실제값 8종 1~8 (+미기재 NULL). ⚠회원 마스터에 ''0''은 없다 — sentinel ''0''은 개발·증감 원천에만 존재하므로 ''0'' 조건은 0행. 라벨은 GENDER_NAME(분석)·SEX_NM(원천)',
    member.SEX_NM        AS member.SEX_NM        WITH SYNONYMS ('성별상세', '국내외국인') COMMENT = 'CM013 원천 라벨 8종(국내(남자)·외국인(여자)·단체·기업 등). 국내/외국인 구분용. 실제값 8종: ''기업''·''기타''·''단체''·''국내(남자)''·''국내(여자)''·''외국인(기타)''·''외국인(남자)''·''외국인(여자)'' + NULL',
    member.MEMBER_STATUS_NAME AS member.MEMBER_STATUS_NAME WITH SYNONYMS ('회원상태') COMMENT = '현재 회원상태 라벨(공#132, MM010). 실제값 13종: ''활동회원''·''신규미납1''·''신규미납2''·''신규미납3''·''신규미납4''·''신규미납5''·''장기미납1''·''장기미납2''·''장기미납3''·''장기미납4''·''장기미납5''·''후원중단''·''(해당없음)''. 🔴 **라벨에 숫자 접두가 없다** — 상태 코드번호를 라벨 앞에 붙인 형태로 필터하면 0행 무증상 오답이다. ⚠️ ''(해당없음)''은 일시회원이며 정기후원 상태축의 **구조적 부재**다 — 결측이 아니다',
    member.MBER_STAT_CD  AS member.MBER_STAT_CD  WITH SYNONYMS ('회원상태코드') COMMENT = '회원상태 원천코드(MM010 1~12). 실제값 12종: ''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''·''9''·''10''·''11''·''12'' + NULL',
    member.MEMBER_TYPE_NAME AS member.MEMBER_TYPE_NAME WITH SYNONYMS ('회원구분') COMMENT = '회원구분 라벨(MM018): 개인·기업·단체. 실제값 3종: ''개인''·''기업''·''단체''',
    member.MBER_DIV_CD   AS member.MBER_DIV_CD   WITH SYNONYMS ('회원구분코드') COMMENT = '회원구분 원천코드(MM018). 실제값 3종: ''1''·''2''·''3''',
    member.MEMBER_ENROLL_PATH_NAME AS member.ENROLL_PATH_NAME WITH SYNONYMS ('가입경로', '회원 가입경로') COMMENT = '회원 가입경로(MM014) — 회원 마스터 현재값. 일시회원은 (해당없음).',
    member.MEMBER_RELATNSP_DIV_NAME AS member.RELATNSP_DIV_NAME WITH SYNONYMS ('결연구분', '결연/비결연') COMMENT = '결연구분(MM019 · 결연회원·비결연회원·혼합회원·중단회원) — 회원 마스터 현재값. 일시회원은 NULL(원천 개념 없음).',
    member.MEMBER_SPECL_MNG_NAME AS member.SPECL_MNG_NAME WITH SYNONYMS ('특별관리', '회원 특별관리', '특별관리 구분') COMMENT = '회원 특별관리 구분(MM012 · 일반·더네이버스클럽·더네이버스아너스클럽·평생회원·홍보대사·이사회·블랙리스트·테스트회원 등) — 대부분 「일반」. 🔴 테스트회원 포함 여부를 답변에 밝힌다.',
    member.MEMBER_FIRST_SPONSORSHIP_NAME AS member.FIRST_SPONSORSHIP_NAME WITH SYNONYMS ('최초후원사업', '최초 후원사업') COMMENT = '회원의 최초 후원사업명(회원 마스터 · DIM_SPONSORSHIP 매칭 100%).',
    member.MEMBER_MOBLPHON_STAT_NAME AS member.MOBLPHON_STAT_NAME WITH SYNONYMS ('휴대폰상태', '휴대폰 상태', '연락처 상태') COMMENT = '휴대폰 상태(MM008 · 정상·결번·타인번호) — 회원 마스터 현재값.',
    member.MEMBER_EMAIL_STAT_NAME AS member.EMAIL_STAT_NAME WITH SYNONYMS ('이메일상태', '이메일 상태') COMMENT = '이메일 상태(MM009 · 정상·계정없음·도메인오류) — 원천 코드 0 은 사전에 없어 NULL.',
    member.MEMBER_TSTM_DIV_NAME AS member.TSTM_DIV_NAME WITH SYNONYMS ('TM/TS 거절', '전화 거절구분', 'TM 거절') COMMENT = 'TM/TS 거절구분(MS026 · TM 거절·TS 거절·TMTS거절). 🔴 원천 코드 0(대다수 회원)은 사전에 없어 NULL — 「거절 없음」으로 단정하지 않는다.',
    event.EVENT_PART_USE_YN AS event.PART_USE_YN WITH SYNONYMS ('참여신청 사용여부', '온라인 참여신청') COMMENT = '행사의 참여신청 기능 사용 여부 Y/N 원값(캠페인행사 전용 · 일반행사 NULL = 원천 개념 없음).'
  )
  METRICS (
    fep.TOTAL_PARTICIPANTS AS SUM(fep.PARTICIPANT_CNT)
      WITH SYNONYMS ('참여자수', '참가자수') COMMENT = '참여자수 합계. F(가산).',
    fep.TOTAL_PARTICIPATE_CNT AS SUM(fep.PARTICIPATE_CNT)
      WITH SYNONYMS ('참여건수') COMMENT = '참여 건수 합계. F(가산).',
    fep.DISTINCT_PARTICIPANTS AS COUNT(DISTINCT fep.MEMBER_DK)
      WITH SYNONYMS ('고유 참여회원수') COMMENT = '고유 참여 회원수. D(distinct).',
    fep.TOTAL_CONFIRM_CNT AS SUM(fep.CONFIRM_CNT)
      WITH SYNONYMS ('신청확정인원', '확정인원') COMMENT = '신청확정인원 합계 — 캠페인행사(MS006) 신청 중 대기·취소가 아닌 확정 상태(신청·참여·불참). 🔴 일반행사(MS304 다단계) 행은 0 이다(확정 개념 없음) — PART_EVENT_KIND_NAME 동반. F(가산).',
    fep.AVG_PARTICIPATION_TIMES AS AVG(fep.PARTICIPATION_TIMES)
      WITH SYNONYMS ('평균 참여횟수', '참여횟수') COMMENT = '그 신청 시점까지 회원의 누적 참여 횟수(참여·Success)의 평균. 🔴 행마다 누적값이라 SUM 하지 말 것 — 회원별 최종 누적은 MAX_PARTICIPATION_TIMES.',
    fep.MAX_PARTICIPATION_TIMES AS MAX(fep.PARTICIPATION_TIMES)
      WITH SYNONYMS ('최대 참여횟수') COMMENT = '누적 참여 횟수의 최댓값(회원으로 GROUP BY 하면 그 회원의 기간 내 최종 누적).',
    fep.MAX_CUM_APPLY_TIMES AS MAX(fep.CUM_APPLY_TIMES)
      WITH SYNONYMS ('누적신청 횟수', '최대 누적신청') COMMENT = '누적 신청 횟수(상태 무관)의 최댓값. 회원으로 GROUP BY 해 쓴다.',
    fep.MAX_WAIT_TIMES AS MAX(fep.WAIT_TIMES)
      WITH SYNONYMS ('대기횟수') COMMENT = '누적 대기 횟수의 최댓값. 회원으로 GROUP BY 해 쓴다.',
    fep.MAX_ABSENT_TIMES AS MAX(fep.ABSENT_TIMES)
      WITH SYNONYMS ('불참횟수') COMMENT = '누적 불참 횟수의 최댓값. 회원으로 GROUP BY 해 쓴다.',
    fep.TOTAL_COMPANION_CNT AS SUM(fep.ACMPNY_PARTCPT_CO)
      WITH SYNONYMS ('동반참여수', '동반인원', '동반수') COMMENT = '동반참여수 합계(신청 행의 원천 동반참여수 합). F(가산). 🔴 **캠페인행사 전용** — 일반행사 행은 원천에 컬럼이 없어 NULL 이다(합계에서 빠진다) ⇒ PART_EVENT_KIND_NAME 을 동반한다. 🔴 참여자수(TOTAL_PARTICIPANTS)와 더해 「총 인원」을 만들지 말 것 — 신청자 본인이 포함되는지 원천 정의가 확인되지 않았다(본인참여 형태는 SELF_PARTCPT_CD 로 구분한다)'
  )
  COMMENT = 'Phase-1 행사 참여 SV (base: GOLD.FACT_EVENT_ATTENDANCE, grain: 행사참여 1행). CRM 일반행사/캠페인행사 참여 건수, 고유 참여회원수(DISTINCT_PARTICIPANTS), 행사구분/참여상태/경로/채널 라벨 뷰. ⚠️ 일반행사(EVENT)와 캠페인행사(CRMN)의 코드군이 상이하므로 계열 판별자 PART_EVENT_KIND_NAME 동반 필수. 행사 미매칭분은 Unknown(0)으로 처리되어 행사명 집계는 부분집합임.'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 라벨축 사용: 행사구분(EVENT_CATEGORY_NAME), 참여상태(PART_STATUS_NAME), 참여경로(PART_PATH_NAME), 참여채널(PART_CHANNEL_NAME) 사용. (2) 계열 동반: 원천별 코드체계 분리를 위해 항상 팩트 보유 축인 PART_EVENT_KIND_NAME 을 동반하여 그루핑 (차원축 EVENT_KIND_NAME 사용 금지). (3) 기간 미지정 시: 데이터 최신 연월 기준 직전 12개월로 한정하며 GROUP BY ROLLUP((연,월)) 반환. (4) 원천 차이: 일반행사(다단계 통과)와 캠페인행사(신청/참여/불참)는 참여 정의가 다르므로 합산 참여율 생성 금지. (5) 채널 NULL: 캠페인행사는 원천 채널 컬럼 부재로 전량 NULL임을 명시. metric 이름(TOTAL_PARTICIPANTS 등)을 fep 컬럼처럼 참조하지 않는다 — 참여자수는 SUM(fep.PARTICIPANT_CNT), 고유 참여회원수는 COUNT(DISTINCT fep.MEMBER_DK) 로 집계한다. 「최근 N개월」 기준일은 비상관 CTE 1개(SELECT MAX(date.FULL_DATE) FROM fep JOIN date ON fep.DATE_SK = date.DATE_SK)로 구하고 CROSS JOIN 한다. ORDER BY 에는 SELECT 별칭을 글자 그대로 쓴다. (🆕 O206 유사 매핑) 원천 행사구분 이름과 다른 이름으로 물으면(예: 「문화이벤트」·「온라인 이벤트」) 가장 가까운 원천 구분으로 매핑하고 답변에 「정의가 되지 않아 유사한 값으로 매핑했다」를 밝힌다: 「문화이벤트」 = 캠페인행사 중 event.EVENT_CATEGORY_NAME IN (문화서비스·문화서비스_전시·문화서비스_서적·문화서비스_공연) · 「온라인 이벤트」 = 일반행사 중 event.EVENT_CATEGORY_NAME = 온라인. 매핑에 쓴 원천 구분명을 결과에 함께 보인다.'
  AI_VERIFIED_QUERIES (
    vqr_o191_kind_status AS (
      QUESTION '행사종류별 참여자수와 참여상태별 분포'
      VERIFIED_BY '(DW = O191)'
      SQL 'SELECT fep.PART_EVENT_KIND_NAME, fep.PART_STATUS_NAME, SUM(fep.PARTICIPANT_CNT) AS TOTAL_PARTICIPANTS, COUNT(DISTINCT fep.MEMBER_DK) AS DISTINCT_PARTICIPANTS FROM fep GROUP BY fep.PART_EVENT_KIND_NAME, fep.PART_STATUS_NAME ORDER BY fep.PART_EVENT_KIND_NAME, TOTAL_PARTICIPANTS DESC NULLS LAST'
    )
  );

-- SV_BUDGET ← 05_06_SV_DDL_BUDGET.sql
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET
  TABLES (
    fbd AS GN_DW.GOLD.FACT_BUDGET
      PRIMARY KEY (MONTH_KEY, BUDGET_ITEM_SK, DVLP_INBOUND_PATH)
      WITH SYNONYMS ('예산', '예산 집행')
      COMMENT = '예산 편성 및 집행 실적 분석 (base: GOLD.FACT_BUDGET). [Grain: 월 × 부서 × 예산과목]. [활성 지표: 편성예산/집행예산/집행률(%)]. [주의: 월 집행액을 더해 연 총액으로 쓰지 말 것 — 연 예산 정본은 GOLD.FACT_BUDGET_YEARLY 이나 어떤 Semantic View 에도 미배선이므로 이 SV 로 연 총액 질의에 답하지 않는다]. [원천: ERP → BRONZE_ERP → SILVER.ERP_BUDGET → GOLD.FACT_BUDGET].',
    month AS GN_DW.GOLD.DIM_MONTH
      PRIMARY KEY (MONTH_KEY)
      WITH SYNONYMS ('월', '예산월')
      COMMENT = '월 차원. fan-out 차단용 helper 뷰. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.',
    item AS GN_DW.GOLD.DIM_BUDGET_ITEM
      PRIMARY KEY (BUDGET_ITEM_SK)
      WITH SYNONYMS ('세세목', '예산항목')
      COMMENT = '예산 세세목 차원. [원천] 시스템=ERP · BRONZE=GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER(JANG_NM~SUBDTL_ITEM_NM 장·관·항·목·세목·세세목 계층 + BDGT_UNIT_NM 예산단위) — DISTINCT 마스터화·MD5 대리키 · SILVER=ERP_BUDGET_ITEM.'
  )
  RELATIONSHIPS (
    fbd_to_month AS fbd (MONTH_KEY)      REFERENCES month,
    fbd_to_item  AS fbd (BUDGET_ITEM_SK) REFERENCES item
  )
  DIMENSIONS (
    month.MONTH_KEY  AS month.MONTH_KEY WITH SYNONYMS ('예산연월', '연월') COMMENT = 'YYYYMM 정수',
    month.CAL_YEAR   AS month.YEAR      WITH SYNONYMS ('연도', '년')      COMMENT = '연도',
    month.CAL_MONTH  AS month.MONTH     WITH SYNONYMS ('월')             COMMENT = '월(1~12)',
    item.BUDGET_ITEM_NAME AS item.BUDGET_ITEM_NAME WITH SYNONYMS ('세세목명', '예산항목명') COMMENT = '예산 세세목명',
    item.BUDGET_CATEGORY  AS item.BUDGET_CATEGORY  WITH SYNONYMS ('예산구분', '예산카테고리') COMMENT = '예산 구분. 실제값 1종: ''지출'' + NULL. 🔴 **''수입''은 이 데이터에 존재하지 않는다** — ''수입'' 으로 필터하면 0행이 반환되므로 「수입 예산」 질문에 이 축으로 답하지 말 것. 🟢 사유는 실측으로 확인됐다: **적재된 예산 원장의 장(章) 계정이 전부 비용(지출) 계정**이므로 이 데이터에는 지출 예산만 있다. 🔴 다만 「ERP 원본에 수입 예산이 있는데 업로드 범위에서 빠진 것인지」는 **확인 전**이다 ⇒ 「조직에 수입 예산이 없다」로 확대해 답하지 말고 **「적재된 예산 데이터에는 지출만 있다」**로 답한다(추정치 생성 금지). ⚠️ 이 축은 사실상 단일값이라 그루핑 축으로서의 정보량이 없다',
    item.BDGT_UNIT_NM AS item.BDGT_UNIT_NM WITH SYNONYMS ('예산단위', '예산 팀', '예산 부서', '예산단위명')
      COMMENT = '예산단위명(ERP 표기 그대로 · 세세목 1:1). 실측 값 6종 = 데이터분석센터 · 마케팅기획1팀 · 마케팅기획2팀 · 매체운영팀 · 사회복지법인예산 · 콘텐츠기획팀. 🔴 CRM 조직(DIM_ORG)과 다른 체계다 — 부서·팀 이름이 CRM 조직명과 같아 보여도 같은 조직으로 단정하지 말 것. 🔴 목록에 없는 팀(예: 「컬쳐콘텐츠팀」)을 물으면 0 으로 답하지 말고 「현재 데이터에서 조회되지 않고 <조회되는 유사 예산단위>가 조회된다」고 밝힌 뒤 그 예산단위의 수치를 제시한다(같은 조직이라 단정하지 않는다 · 유사 항목이 없으면 위 6종을 제시).',
    fbd.DVLP_INBOUND_PATH AS fbd.DVLP_INBOUND_PATH WITH SYNONYMS ('개발인입경로', '개발 유입경로', '인입경로', '유입경로', '개발경로')
      COMMENT = '개발 유입경로(ERP 원장 그대로). 실측 값 7종 = 디지털 · 방송 · 재송출 · 영상광고 · 뉴미디어 · 모금시스템 · 콜개발. 🔴 NULL = 원장에 경로가 기재되지 않은 예산(대부분 집행 0) — 「미분류」 같은 이름을 지어내지 말고 「경로 미기재」로 표기한다. 🔴 CRM 회원 가입경로(JOIN_PATH)와 다른 축이다.',
    item.ITEM_JANG_NM AS item.JANG_NM WITH SYNONYMS ('장', '예산 장') COMMENT = '예산 과목 계층 최상위 「장」(원값 = 모금비·사업비·사회복지법인예산·일반관리비 · ERP 원장). 장 > 관 > 항 > 목 > 세목 > 세세목 순으로 좁아진다.',
    item.ITEM_KWAN_NM AS item.KWAN_NM WITH SYNONYMS ('관', '예산 관') COMMENT = '예산 과목 계층 「관」(원값 = 국내사업비·나눔문화연구사업·모금비·사회복지법인예산·일반관리비·해외사업비).',
    item.ITEM_HANG_NM AS item.HANG_NM WITH SYNONYMS ('항', '예산 항') COMMENT = '예산 과목 계층 「항」(원값 = 국내아동권리지원사업·기획및연수인력사업·나눔문화연구사업·모금관리비·사무국운영사업·사회복지법인예산·해외기획사업·해외아동권리지원및지역개발사업·회원관리비).',
    item.ITEM_FUND_SOURCE_NM AS item.FUND_SOURCE_NM WITH SYNONYMS ('재원', '예산 재원') COMMENT = '예산 재원명(원값 = 국내지정·법인전입·비지정일반·사회복지법인예산·이월국내지정·이월비지정일반·이자수익·잡수익 · ERP 원장).'
  )
  METRICS (
    fbd.TOTAL_PLAN_BUDGET AS SUM(fbd.PLAN_BUDGET_MONTH)
      WITH SYNONYMS ('편성예산', '월 편성예산', '예산 편성액') COMMENT = '월 편성예산 합계(원). F(가산).',
    fbd.TOTAL_EXEC_BUDGET AS SUM(fbd.EXEC_BUDGET_ERP)
      WITH SYNONYMS ('집행예산', 'ERP 집행액', '예산 집행액') COMMENT = 'ERP 집행예산 합계(원). F(가산).',
    fbd.EXEC_RATE AS SUM(fbd.EXEC_BUDGET_ERP) / NULLIF(SUM(fbd.PLAN_BUDGET_MONTH), 0) * 100
      WITH SYNONYMS ('집행율', '예산 집행율') COMMENT = '집행율(%) = 집행예산 ÷ 편성예산 ×100. 비율(N). ⚠편성은 12개월 전량이지만 집행은 적재된 월까지만 존재하므로, 집행 미적재 월을 분모에 넣으면 집행율이 구조적으로 낮게 나온다 — 스코프 정합 규칙은 AI_SQL_GENERATION 참조.',
    fbd.DIRECT_FUNDRAISING_COST_1 AS SUM(fbd.EXEC_DIRECT_MNYRS_1)
      WITH SYNONYMS ('직접모금비1', '직접모금비 1', '모금성비용1')
      COMMENT = '직접모금비1(원) — 원장 플래그 직접모금비1(DIRECT_MNYRS_YN_1)=Y 인 원장행의 집행액 합. F(가산). 🔴 **화면·답변에는 「직접모금비1」 이름 그대로 표시한다**(현업 회신 42) — 「모금성비용」 하나로 부르지 말고 직접모금비2 와 나란히 보여준다. ⚠️ 두 값은 포함관계가 아니다(행 단위로 1 이 2 보다 큰 행이 있다) ⇒ 차이를 「1 을 뺀 나머지」로 해석하지 말 것.',
    fbd.DIRECT_FUNDRAISING_COST_2 AS SUM(fbd.EXEC_DIRECT_MNYRS_2)
      WITH SYNONYMS ('직접모금비2', '직접모금비 2', '모금성비용2')
      COMMENT = '직접모금비2(원) — 원장 플래그 직접모금비2(DIRECT_MNYRS_YN_2)=Y 인 원장행의 집행액 합. F(가산). 🔴 「직접모금비2」 이름 그대로 표시한다(현업 회신 42). ⚠️ 이 플래그는 사실상 전 원장행이 Y 라 합계가 집행예산(TOTAL_EXEC_BUDGET)과 거의 같다 — 「모금비가 전체 집행과 같다」로 해석하지 말고 플래그 정의가 넓다는 사실을 함께 밝힌다.'
  )
  COMMENT = 'Phase-1 예산 SV (base: GOLD.FACT_BUDGET, grain: 월×세세목 1행). ERP 예산 원장 기반 월별 편성예산(TOTAL_PLAN_BUDGET), 집행예산(TOTAL_EXEC_BUDGET), 집행율(EXEC_RATE, %) 및 세세목별 집계 뷰. ⚠️ 광고비는 본 뷰에 없으며 SV_AD 소관. 수입 예산은 적재 원천에 부재하며 지출 예산만 포함됨.'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 지표 매핑: 편성예산=TOTAL_PLAN_BUDGET, 집행예산=TOTAL_EXEC_BUDGET, 집행율=EXEC_RATE (%). (2) 집행율 산정: 집행예산이 적재된 월까지만 편성을 분모에 포함하여 산정(집행 미적재 월 분모 제외). (3) 기간 미지정 시: 데이터 최신 연월 기준 직전 12개월로 한정하며 GROUP BY ROLLUP((연,월)) 반환. (4) 예산구분: BUDGET_CATEGORY 는 ''지출'' 단일 계정이므로 ''수입'' 필터 사용 금지. (5) 2024년 편성 결손 가드: 2024년은 원천 예산 원장에 월별 편성 배분이 없고 연 총액만 있어 월 편성예산이 0 으로 집계되므로, 다년 집행율 산정 시 YEAR >= 2025 를 적용하거나 연도별로 표를 분리하여 제시하고 2024년 월별 집행율은 산출 불가로 답한다. 🆕 [O203] 2024 **연 편성예산·연 집행율**은 연 예산 SV(SV_BUDGET_YEARLY · 연 grain)에 있다 — 그 SV 를 쓰라고 안내하고 이 SV 와 한 표에 합산하지 않는다. (기준시점 규칙) 「최근 N개월」·기간 미지정 질의의 기준 월은 **비상관 CTE 1개**(SELECT MAX(fbd.MONTH_KEY) FROM fbd)로 구하고 CROSS JOIN 한다. ORDER BY … LIMIT/OFFSET 서브쿼리·스칼라 서브쿼리로 기준 월을 구하지 않는다(미지원 서브쿼리 오류). 월 경계는 TO_DATE(TO_VARCHAR(MONTH_KEY), ''YYYYMM'') 로 날짜화해 DATEADD 한다. ORDER BY 에는 SELECT 별칭을 글자 그대로 쓴다. (모금성비용) 「모금성비용·직접모금비」 질의는 DIRECT_FUNDRAISING_COST_1·_2 를 **둘 다** 「직접모금비1」「직접모금비2」 이름으로 나란히 보여주고 하나를 골라 단정하지 않는다.'
  AI_VERIFIED_QUERIES (
    vqr_monthly_plan_exec AS (
      QUESTION '월별 편성예산과 집행예산'
      VERIFIED_BY '(DW = O190)'
      SQL 'SELECT month.CAL_YEAR, month.CAL_MONTH, SUM(fbd.PLAN_BUDGET_MONTH) AS TOTAL_PLAN_BUDGET, SUM(fbd.EXEC_BUDGET_ERP) AS TOTAL_EXEC_BUDGET FROM fbd LEFT JOIN month ON fbd.MONTH_KEY = month.MONTH_KEY GROUP BY month.CAL_YEAR, month.CAL_MONTH ORDER BY month.CAL_YEAR, month.CAL_MONTH'
    ),
    vqr_o191_last12m_by_item AS (
      QUESTION '최근 12개월 예산구분별·세세목별 편성예산과 집행예산'
      VERIFIED_BY '(DW = O191)'
      SQL 'WITH mx AS (SELECT MAX(fbd.MONTH_KEY) AS mk FROM fbd) SELECT item.BUDGET_CATEGORY, item.BUDGET_ITEM_NAME, SUM(fbd.PLAN_BUDGET_MONTH) AS TOTAL_PLAN_BUDGET, SUM(fbd.EXEC_BUDGET_ERP) AS TOTAL_EXEC_BUDGET FROM fbd JOIN item ON fbd.BUDGET_ITEM_SK = item.BUDGET_ITEM_SK CROSS JOIN mx WHERE fbd.MONTH_KEY > TO_NUMBER(TO_CHAR(DATEADD(MONTH, -12, TO_DATE(TO_VARCHAR(mx.mk), ''YYYYMM'')), ''YYYYMM'')) AND fbd.MONTH_KEY <= mx.mk GROUP BY item.BUDGET_CATEGORY, item.BUDGET_ITEM_NAME ORDER BY TOTAL_PLAN_BUDGET DESC NULLS LAST'
    )
  );

-- SV_AD ← 05_07_SV_DDL_AD.sql
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_AD
  TABLES (
    ad AS GN_DW.GOLD.WIDE_AD_COMBINED
      PRIMARY KEY (AD_PERF_DK)
      WITH SYNONYMS ('광고 실적', '광고 성과', '매체 실적')
      COMMENT = '온-오프라인 광고 성과 통합 분석 (base: GOLD.WIDE_AD_COMBINED). [Grain: 집행일 × 캠페인 × 소재 × 디바이스]. [활성 지표: 광고비/노출/클릭/전환/CTR/CVR/CPC/CPM/ROAS]. [주의: _SRC 접미 비율 지표 단순 재합산 금지]. [원천: AGENCY 3소스 + GA4 → SILVER.AGENCY_AD_* → GOLD.WIDE_AD_COMBINED].',
    device AS GN_DW.GOLD.DIM_DEVICE
      PRIMARY KEY (DEVICE_SK)
      WITH SYNONYMS ('기기', '디바이스', '매체기기')
      COMMENT = '기기(디바이스) 차원. [원천] 시스템=GA4(BigQuery→Snowflake) · BRONZE=GN_DW.BRONZE_BIGQUERY.EVENTS(device.category) · SILVER=GA4_DEVICE. 방송 행은 기기 개념이 없어 (해당없음).',
    mktg AS GN_DW.GOLD.DIM_MARKETING_CAMPAIGN
      PRIMARY KEY (MKTG_CAMPAIGN_SK)
      WITH SYNONYMS ('마케팅캠페인', '캠페인')
      COMMENT = '마케팅캠페인 conformed 차원 — 광고(대행사) ↔ 개발실적(CRM)을 잇는 **유일한 결합축**이다. PK 유일이라 조인이 행수를 늘리지 않는다(실측: FAP 조인 후 행수 불변). 🔴 개발캠페인(DIM_CAMPAIGN) grain 으로 내려가면 광고비가 복제된다 — 결합은 이 grain 에서만 한다. [원천] 시스템=CRM(eCRM) 마스터 + 대행사 리포트의 캠페인명 이름매칭 · BRONZE=GN_DW.BRONZE_CRM: TM_CM_MKTNG_CMPGN_MNG · SILVER=CRM_MARKETING_CAMPAIGN.',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '실적일')
      COMMENT = '일 차원. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.'
  )
  RELATIONSHIPS (
    ad_to_date   AS ad (PERF_DATE_SK) REFERENCES date (DATE_SK),
    ad_to_device AS ad (DEVICE_SK)    REFERENCES device,
    ad_to_mktg   AS ad (MKTG_CAMPAIGN_SK) REFERENCES mktg
  )
  DIMENSIONS (
    mktg.MARKETING_CAMPAIGN AS mktg.MKTG_CAMPAIGN_NAME
      WITH SYNONYMS ('마케팅캠페인', '마케팅 캠페인명', '캠페인', '캠페인명')
      COMMENT = '마케팅캠페인명 — 광고와 CRM 개발실적을 잇는 **유일한 결합축**이다. 🔴 광고행 전체가 이 축에 도달하지는 않는다 — 미도달분은 ''(미매핑)'' 한 덩어리이므로 **이 축으로 그루핑한 광고비 합계는 전체 광고비보다 작다**. 총계를 물으면 축 없이 답하고, 캠페인별로 물으면 미매핑 버킷의 존재를 함께 밝힌다. ⚠️ **개발캠페인(개별 캠페인명)별 분해는 여전히 불가**하다 — 한 마케팅캠페인에 개발캠페인이 다수 매달려 있어 광고비를 내리면 그 배수로 복제된다(현업 배분 규칙 필요). ⚠️ **소재(광고 소재)별 분해도 불가**하다(소재 연결키 부재). 🔴 **도달률은 출처유형마다 크게 다르다** — 디지털은 상당 부분 도달하지만 방송(VIDEO)은 원천 마케팅캠페인명 컬럼 소멸로 일부만 도달하고 재방송(REBROADCAST)은 도달하지 않는다 ⇒ 방송·재방송을 이 축으로 분해하지 말고, 캠페인별 질문에는 AD_SOURCE_TYPE 별 도달 비중을 조회해 함께 밝힌다',
    mktg.DEV_CAMPAIGN_CNT   AS mktg.DEV_CAMPAIGN_CNT
      WITH SYNONYMS ('개발캠페인 수', '팬아웃 배수')
      COMMENT = '🔴**팬아웃 경고축**: 이 마케팅캠페인에 매달린 개발캠페인 수. 1 보다 크면 개발캠페인 단위로 광고비를 내릴 때 그 배수만큼 복제된다 — 이 값을 근거로 「개발캠페인별 ROI 는 배분 규칙 없이는 불가」라고 답한다',
    -- 🆕 [2026-10-14 O225-C] 마케팅캠페인 속성 3종(광고비 분해용 · 인입경로·채널·카테고리는 의도적으로 없다)
    mktg.MKTG_UTM_NM AS mktg.MKTG_UTM_NM
      WITH SYNONYMS ('UTM', 'UTM 캠페인', '마케팅캠페인 UTM')
      COMMENT = '마케팅캠페인의 UTM 라벨(CRM 마케팅 코드 U001 · 마케팅캠페인당 1개). 광고비를 UTM 별로 나눌 때 쓴다. 대행사 원천의 UTM 태그(UTM_CMPGN_NM)와는 다른 축이다(그쪽은 광고행 원값).',
    mktg.DOMESTIC_OVERSEAS AS mktg.DOMESTIC_OVERSEAS
      WITH SYNONYMS ('국내해외', '국내/해외', '캠페인 국내해외')
      COMMENT = '마케팅캠페인 국내/통합/해외(MM295). 🔴 한 마케팅캠페인 아래 값이 갈리면(소수 · 실측은) 매핑 행수 최다 값을 대표로 쓴다 — DOMESTIC_OVERSEAS_IS_MULTI=TRUE 비중을 함께 밝힌다.',
    mktg.DOMESTIC_OVERSEAS_IS_MULTI AS mktg.DOMESTIC_OVERSEAS_IS_MULTI
      WITH SYNONYMS ('국내해외 대표값 여부')
      COMMENT = 'TRUE = 국내/해외 값이 여럿이라 대표값을 쓴 마케팅캠페인.',
    mktg.BIZ_CASE_TYPE AS mktg.BIZ_CASE_TYPE
      WITH SYNONYMS ('사업사례', '사업/사례', '캠페인 사업사례')
      COMMENT = '마케팅캠페인 굿즈/기타/사례/사업(MM296). 🔴 한 마케팅캠페인 아래 값이 갈리면 매핑 행수 최다 값을 대표로 쓴다 — BIZ_CASE_TYPE_IS_MULTI=TRUE 비중을 함께 밝힌다.',
    mktg.BIZ_CASE_TYPE_IS_MULTI AS mktg.BIZ_CASE_TYPE_IS_MULTI
      WITH SYNONYMS ('사업사례 대표값 여부')
      COMMENT = 'TRUE = 사업/사례 값이 여럿이라 대표값을 쓴 마케팅캠페인.',
    date.PERF_DATE    AS date.FULL_DATE  WITH SYNONYMS ('실적일', '광고일', '일자', '날짜') COMMENT = '광고 실적 발생일',
    date.FULL_DATE AS date.FULL_DATE  COMMENT = '달력 날짜(DIM_DATE.FULL_DATE) — PERF_DATE 와 같은 값이다(Analyst 가 추측하는 식별자를 실재화). 둘 중 하나만 쓴다.',
    date.CAL_YEAR     AS date.YEAR       WITH SYNONYMS ('연도', '년')   COMMENT = '연도',
    date.CAL_MONTH    AS date.MONTH      WITH SYNONYMS ('월')          COMMENT = '월(1~12)',
    date.YEAR AS date.YEAR    COMMENT = '연도(DIM_DATE.YEAR) — CAL_YEAR 와 같은 값(Analyst 가 추측하는 식별자를 실재화). 둘 중 하나만 쓴다.',
    date.MONTH AS date.MONTH  COMMENT = '월(DIM_DATE.MONTH) — CAL_MONTH 와 같은 값(추측 식별자 실재화). 둘 중 하나만 쓴다.',
    date.CAL_QUARTER  AS date.QUARTER    WITH SYNONYMS ('분기')        COMMENT = '분기(1~4)',
    ad.AD_SOURCE_TYPE AS ad.AD_SOURCE_TYPE WITH SYNONYMS ('출처유형', '광고출처', '매체구분') COMMENT = '광고 출처유형. 코드값: ''DIGITAL'' · ''VIDEO''(방송 본방) · ''REBROADCAST''(재방송). 디지털/방송 measure 필터 필수. 실제값 3종: ''VIDEO''·''DIGITAL''·''REBROADCAST''',
    ad.DAY_OF_WEEK    AS ad.DAY_OF_WEEK    WITH SYNONYMS ('요일')   COMMENT = '요일. 실제값 7종: ''Fri''·''Mon''·''Sat''·''Sun''·''Thu''·''Tue''·''Wed''',
    ad.WEEK_OF_YEAR   AS ad.WEEK_OF_YEAR   WITH SYNONYMS ('주차')   COMMENT = '연중 주차',
    device.DEVICE_TYPE       AS device.DEVICE_TYPE       WITH SYNONYMS ('기기유형', '디바이스유형', '모바일', 'PC') COMMENT = '기기 유형. 실제 코드값: ''M''=모바일(GA4 mobile/tablet 통합) · ''PC''=데스크톱 · ''(해당없음)''=방송광고(기기 개념 없음) · ''(unknown)''=매핑 실패 센티넬. ⚠필터 시 ''MOBILE''/''TABLET'' 아님 — 모바일은 ''M''.',
    device.DEVICE_SCOPE_DESC AS device.DEVICE_SCOPE_DESC WITH SYNONYMS ('기기범위') COMMENT = '기기 범위 설명(예: 모바일(GA4 device.category=mobile/tablet)).',
    ad.AD_TYPE_NM     AS ad.AD_TYPE_NM     WITH SYNONYMS ('광고유형', '광고타입') COMMENT = '디지털 광고유형(검색/디스플레이 등). AD_SOURCE_TYPE=DIGITAL 전용. 값 목록은 이 컬럼을 SELECT DISTINCT 로 조회한다(열거를 여기 박지 않는다).',
    ad.CREATIVE_TYPE  AS ad.CREATIVE_TYPE  WITH SYNONYMS ('소재유형', '크리에이티브유형') COMMENT = '크리에이티브 유형. 디지털 전용. 원천에 일부 행만 채워져 있어 부분집합이다. 실제값 5종: ''기타''·''영상''·''이미지''·''키워드''·''해당없음'' + NULL. ⚠️ ''해당없음''은 원천이 넣은 값이며 NULL 과 다르다(합치지 않는다)',
    ad.PAGE_TYPE      AS ad.PAGE_TYPE      WITH SYNONYMS ('페이지유형', '랜딩유형') COMMENT = '랜딩 페이지 유형. 디지털 전용. 값 목록은 이 컬럼을 SELECT DISTINCT 로 조회한다(열거를 여기 박지 않는다). ⚠️ ''전체'' 값이 섞여 있고 **그 의미(랜딩 유형인지 대행사 리포트의 묶음 표기인지)는 원천 확인 전**이다 — 유형별 분해에 쓰되 그 사실을 밝히고, 의미를 추측해 설명하지 말 것. 🟢 집계행(총계 중복)은 아니다 — 광고비 합계가 전체와 겹치지 않음을 실측 확인했다',
    ad.AD_GROUP_NM    AS ad.AD_GROUP_NM    WITH SYNONYMS ('광고그룹', '그룹명') COMMENT = '광고 그룹명. 디지털 전용. 고카디널리티이며 원천 재적재로 값이 바뀐다 ⇒ 값 목록은 이 컬럼을 SELECT DISTINCT 로 조회한다(열거를 여기 박지 않는다).',
    ad.CHANNEL_COMPANY AS ad.CHANNEL_COMPANY WITH SYNONYMS ('채널사', '방송사', '매체사') COMMENT = '방송 채널사. VIDEO/REBROADCAST 전용. ⚠광고비 기준 정렬 시 광고비가 없는 채널사가 섞이므로 NULLS LAST 를 명시할 것.',
    ad.TIME_BAND       AS ad.TIME_BAND       WITH SYNONYMS ('시간대', '광고시간대') COMMENT = '방송 시간대. 방송 전용. ⚠️ 표기 형식이 원천마다 다르다 — VIDEO 는 ''N시대'' 구간 라벨, REBROADCAST 는 ''HH:MM:SS'' 시각이다(원천 재편) ⇒ 두 출처를 섞어 이 축으로 그루핑하지 말고 AD_SOURCE_TYPE 으로 먼저 나눈다.',
    ad.PROGRAM_NM      AS ad.PROGRAM_NM      WITH SYNONYMS ('프로그램', '프로그램명', '방송프로그램') COMMENT = '방송 프로그램명(고카디널리티 — Cortex Search 백킹 후보). 방송 전용.',
    ad.SPOT_TYPE       AS ad.SPOT_TYPE       WITH SYNONYMS ('스팟유형', '광고위치') COMMENT = '스팟 유형(전CM/중CM/후CM/SB). 방송 전용. 실제값 4종: ''CA''·''PR''·''SP''·''TJ'' + NULL',
    ad.CM_POSITION     AS ad.CM_POSITION     WITH SYNONYMS ('CM위치', '광고순서') COMMENT = 'CM 내 위치. 방송 전용. 실제값 16종: ''`''(🔴 **오염값** — 백틱 1문자이며 정상 CM 위치가 아니다. 이 값으로 필터하지 말 것 ··''st''·''E-2nd''·''E-3rd''·''th''·''E-5th''·''E-6th''·''E-7th''·''T-1st''·''T-2nd''·''T-3rd''·''T-4th''·''T-5th''·''T-6th''·''T-7th''·''middle'' + NULL',
    ad.RT_TYPE         AS ad.RT_TYPE         WITH SYNONYMS ('재방유형', '방송유형구분') COMMENT = '본방/재방 유형. REBROADCAST 전용(VIDEO 는 전건 NULL). 실제값 2종: ''재송출''·''방송'' + NULL',
    ad.DURATION_SEC    AS ad.DURATION_SEC    WITH SYNONYMS ('초수', '광고초수', '영상초수', '광고길이', '초') COMMENT = '방송 광고 영상 초수(초 단위, 요구사항 #22). 방송(VIDEO/REBROADCAST) 전용. 실제값: 15·20·30·60 등 + NULL.',
    ad.BRDC_DIV AS ad.BRDC_DIV
      WITH SYNONYMS ('방송구분', '본방/재방')
      COMMENT = '방송구분(레귤러·본방송·재방송·삼방송·보상송출·송출오류) — 🔴 REBROADCAST 전용 · 디지털행은 NULL(원천 부재) ⇒ 출처유형 REBROADCAST 로 고정해 쓴다.',
    ad.CHANNEL_COMPANY_TYPE AS ad.CHANNEL_COMPANY_TYPE
      WITH SYNONYMS ('채널사유형', '방송사 유형')
      COMMENT = '채널사유형(지상파·종편·케이블·CTV·YOUTUBETV·퍼포머셜·TEADS·기타·미확인) — 🔴 VIDEO 전용 · 디지털행은 NULL ⇒ 출처유형 VIDEO 로 고정해 쓴다.',
    ad.CTV_DIV AS ad.CTV_DIV
      WITH SYNONYMS ('CTV구분', 'TV/CTV')
      COMMENT = 'CTV구분(TV·CTV·기타·미확인) — 🔴 VIDEO 전용 · 디지털행은 NULL.',
    ad.DAY_DIV AS ad.DAY_DIV
      WITH SYNONYMS ('요일구분', '주중/주말')
      COMMENT = '요일구분(주중·토·일) — 🔴 VIDEO 전용 · 디지털행은 NULL.',
    ad.MEDIA_CHANNEL_NM AS ad.MEDIA_CHANNEL_NM
      WITH SYNONYMS ('매체', '매체명', '광고 매체', '매체별')
      COMMENT = '매체/채널명 원값(YOUTUBE·META·NBRAND·EBS·GDN·MMT 등) — 디지털·영상·재방송 3원천 공통. 「매체별 광고비·성과」 질문의 1순위 축. ⚠️방송 채널사만 보려면 CHANNEL_COMPANY.',
    ad.CREATIVE_NM AS ad.CREATIVE_NM
      WITH SYNONYMS ('소재명', '광고 소재', '소재')
      COMMENT = '소재명(디지털 MATR · 영상 MATR_NM · 재방송은 방송명). 원천별 의미가 달라 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프한다.',
    ad.COST_TYPE AS ad.COST_TYPE
      WITH SYNONYMS ('비용유형', '광고비 산정 기준')
      COMMENT = '비용유형 GA(디지털)·집행(영상)·편성(재방송) 3값 — 광고비 산정 기준이 원천별로 다르다는 표시(AD_SOURCE_TYPE 과 사실상 1:1).',
    ad.BDGT_SOURCE_NM AS ad.BDGT_SOURCE_NM
      WITH SYNONYMS ('예산출처', '법인(사단/사복)', '예산 법인')
      COMMENT = '예산출처 사단·사복·통합 원값(디지털·영상). 🔴재방송은 원천 개념 없음 = NULL(결측 아님).',
    ad.MATR_TY_NM AS ad.MATR_TY_NM
      WITH SYNONYMS ('소재유형(디지털·영상)', '영상/이미지')
      COMMENT = '소재유형 원값(영상·이미지 등 · 디지털·영상). 재방송 NULL(원천 부재). ⚠️CREATIVE_TYPE 은 디지털 전용 같은 원천값 — 영상까지 보려면 이 축.',
    ad.CMPGN_TYPE_BSN_NM AS ad.CMPGN_TYPE_BSN_NM
      WITH SYNONYMS ('캠페인유형', '사업유형', '국내/해외 사례')
      COMMENT = '캠페인유형(사업) 원값 6종: 국내 사례·국내 사업·해외 사례·해외 굿즈·통합 기타·통합 통합 [디지털 전용 · 방송 NULL].',
    ad.UTM_CMPGN_NM AS ad.UTM_CMPGN_NM
      WITH SYNONYMS ('UTM 캠페인', 'UTM 태그')
      COMMENT = 'UTM 캠페인 태그 원값(turn24b·children2406 등) [디지털 전용].',
    ad.BSNS_CASE_DIV_NM AS ad.BSNS_CASE_DIV_NM
      WITH SYNONYMS ('사업/사례 구분', '영상 소재 구분')
      COMMENT = '사업/사례 구분 원값 사례·굿즈·사업·기타 [영상 전용 · 그 밖 NULL].',
    ad.CM AS ad.CM
      WITH SYNONYMS ('CM 구분', '전CM/중CM/후CM')
      COMMENT = 'CM 구분 원값 전CM·중CM·후CM·전SPOT CM·후SPOT CM [영상 전용]. ⚠️CM_POSITION(CM 위치)과 다른 원천 컬럼.',
    ad.DMST_OVSEA_DIV_NM AS ad.DMST_OVSEA_DIV_NM
      WITH SYNONYMS ('국내/해외', '국내해외 구분')
      COMMENT = '국내/해외 구분 원값 국내·해외·통합 [영상 전용 · 그 밖 NULL].'
  )
  METRICS (
    ad.TOTAL_AD_COST   AS SUM(ad.AD_COST)
      WITH SYNONYMS ('광고비', '광고비 총액', '매체비') COMMENT = '광고비 합계(원). F(가산). 디지털+방송 합산 가능.',
    ad.TOTAL_IMPRESSIONS AS SUM(ad.IMPRESSIONS)
      WITH SYNONYMS ('노출수', '노출', '임프레션') COMMENT = '노출수 합계. F(가산). 디지털 전용(방송은 NULL).',
    ad.TOTAL_CLICKS AS SUM(ad.CLICKS)
      WITH SYNONYMS ('클릭수', '클릭') COMMENT = '클릭수 합계. F(가산). 디지털 전용(방송은 NULL).',
    ad.TOTAL_INBOUND_CALL AS SUM(ad.INBOUND_CALL)
      WITH SYNONYMS ('인바운드콜', '전화문의', '콜수') COMMENT = '인바운드 전화 건수 합계. F(가산). 방송 전용(디지털은 NULL) — VIDEO·REBROADCAST 모두 존재.',
    ad.TOTAL_AGENCY_CONV_MEMBERS AS SUM(ad.AGENCY_CONV_MEMBERS)
      WITH SYNONYMS ('대행사전환회원', '전환회원수', '대행사전환') COMMENT = '대행사 전환 회원수 합계. F(가산). 디지털 전용.',
    ad.CTR AS SUM(ad.CLICKS) / NULLIF(SUM(ad.IMPRESSIONS), 0) * 100
      WITH SYNONYMS ('클릭률', 'CTR') COMMENT = '공9 CTR(%) = 클릭수 ÷ 노출수 ×100. 비율(N). 디지털 전용.',
    ad.CVR AS SUM(ad.AGENCY_CONV_MEMBERS) / NULLIF(SUM(ad.CLICKS), 0) * 100
      WITH SYNONYMS ('전환율', 'CVR') COMMENT = '공10 CVR(%) = 대행사전환회원 ÷ 클릭수 ×100. 비율(N). 디지털 전용.',
    ad.TOTAL_CRM_DEV_CNT AS SUM(ad.CRM_DEV_CNT)
      WITH SYNONYMS ('CRM개발건', 'CRM 개발건수', '디지털개발건') COMMENT = 'CRM 개발건수 합계(디지털). F(가산). ⚠원천에 비정수(소수) 값이 섞여 있어 기여도 배분값일 가능성이 있다 → "건수"로 정수 단정 금지(어의 미확정). ⚠원천이 개발건수 제공을 중단하고 단가를 직접 제공하는 포맷으로 바뀐 시점 이후는 미적재다 — 적재 구간은 데이터에서 확인할 것. 🔴 원천 CRM_DEV_CNT 가 비어 있으면 이 지표는 NULL 이다 — NULL 을 0·추정치로 바꾸지 말고 「원천 미적재로 산출 불가」라고 답한다.',
    ad.DEV_UNIT_PRICE AS SUM(CASE WHEN ad.CRM_DEV_CNT IS NOT NULL THEN ad.AD_COST END) / NULLIF(SUM(ad.CRM_DEV_CNT), 0)
      WITH SYNONYMS ('개발단가', 'CPA', '건당 광고비') COMMENT = '공7 디지털 개발단가(원) = 광고비 ÷ CRM개발건. 비율(N). DIGITAL 전용. 분자를 개발건수 적재행으로 정합(미적재행 광고비 제외). ⚠원천 포맷 변경 이후 구간은 개발건수가 없어 산출 불가(NULL) — 산출 가능한 최신 구간은 데이터에서 확인할 것. 🔴 분모 CRM_DEV_CNT 가 비어 있으면 전 구간 NULL 이다 — 다른 단가로 대체하지 말고 「원천 미적재로 산출 불가」라고 답하며 대안으로 GA 개발단가(공8)를 별도 지표로 안내한다.',
    ad.GA_DEV_UNIT_PRICE AS SUM(CASE WHEN ad.AGENCY_CONV_CNT IS NOT NULL THEN ad.AD_COST END) / NULLIF(SUM(ad.AGENCY_CONV_CNT), 0)
      WITH SYNONYMS ('GA 개발단가', 'GA CPA', 'GA 건당 광고비', '공8') COMMENT = '공8 GA 개발단가(원) = GA 광고비 ÷ GA 개발(건). 분모 = 대행사 리포트의 GA 전환(건). 비율(N). DIGITAL 전용(방송은 분모가 없어 NULL). 분자를 분모 적재행으로 정합. ⚠소수 전환값을 반올림하지 않는다. ⚠GA4 이벤트(BigQuery) 기반 후원건과는 규모가 다르다 — 이 지표의 분모는 대행사 보고값이다.',
    ad.GA_DEV_CNT AS SUM(ad.AGENCY_CONV_CNT)
      WITH SYNONYMS ('GA 개발(건)', 'GA 개발건수', '일별리포트 개발건수', '일별리포트 개발(건)', 'GA 전환(건)') COMMENT = '일별리포트(대행사 디지털 리포트) GA 개발(건) 합계 = 공8 GA 개발단가의 분모. F(가산). DIGITAL 전용(방송 NULL). 「GA·일별리포트」를 명시한 개발건수 질문에 쓴다(사용자 결정 A) — 명시가 없으면 MSTR 개발(건) 소관이다. ⚠소수 값이 섞여 있어 정수 건수로 단정하지 않는다. 🔴 MSTR 개발(건)·CRM 개발건과 한 표에서 합산·비교하지 않는다. 매체(META 등)별은 MEDIA_CHANNEL_NM 축.',
    ad.TOTAL_READ_CNT AS SUM(ad.READ_CNT)
      WITH SYNONYMS ('조회수', '열람수', '읽기수') COMMENT = '콘텐츠 조회수 합계(디지털). F(가산).',
    ad.TOTAL_MEDIA_POTENTIAL AS SUM(ad.MEDIA_POTENTIAL_CUST_CNT)
      WITH SYNONYMS ('매체잠재고객수', '잠재고객') COMMENT = '매체 잠재고객수 합계(디지털). F(가산). 🔴 원천 MEDIA_POTENTIAL_CUST_CNT 가 비어 있으면 NULL 이다 — 0·추정치로 답하지 말고 「원천 미적재로 산출 불가」라고 답한다.',
    ad.TOTAL_AD_CNT AS SUM(ad.AD_CNT)
      WITH SYNONYMS ('방송횟수', '광고집행횟수', '편성횟수') COMMENT = '방송 광고 집행 횟수 합계. F(가산). VIDEO/REBROADCAST 전용.',
    ad.TOTAL_DVLP_CNT AS SUM(ad.DVLP_CNT)
      WITH SYNONYMS ('재방송개발건', '방송개발건', '방송 개발회원건수') COMMENT = '방송 개발건수 합계(대행사 보고). F(가산). VIDEO·REBROADCAST 전용(디지털은 NULL). 🔴 VIDEO 도 개발건을 보고한다(일부 행만 채워짐 · 미보고 행은 NULL). ⚠️ 두 대행사 리포트의 개발 정의가 같은지는 원천 확인 전이다 ⇒ 합계를 물으면 AD_SOURCE_TYPE 별로 나눠 함께 보여준다.',
    ad.TOTAL_DVLP_MEMBER_CNT AS SUM(ad.DVLP_MEMBER_CNT)
      WITH SYNONYMS ('재방송개발회원', '방송개발회원', '방송 개발회원수') COMMENT = '방송 개발회원수 합계(대행사 보고). F(가산). VIDEO·REBROADCAST 전용 — VIDEO 는 일부 행만 채워짐.',
    ad.REBRDC_DEV_UNIT_PRICE AS SUM(CASE WHEN ad.DVLP_CNT IS NOT NULL THEN ad.AD_COST END) / NULLIF(SUM(ad.DVLP_CNT), 0)
      WITH SYNONYMS ('재방송 개발단가', '재방송 CPA', '재방송 건당 광고비') COMMENT = '재방송 개발단가(원) — 참고 지표(공8 아님 · 공8 은 GA_DEV_UNIT_PRICE) = 재방송 광고비 ÷ 재방송 개발건. 비율(N). **REBROADCAST 전용**(방송 전체 단가가 아님 · VIDEO 단가는 이 metric 의 범위 밖). 분자를 개발건수 적재행으로 정합. ⚠`AD_SOURCE_TYPE=''REBROADCAST''` 필터 전제 — VIDEO 혼합 시 과대계상된다.'
  )
  COMMENT = 'Phase-1 광고 실적 SV (base: GOLD.WIDE_AD_COMBINED). 대행사(디지털/방송) 일별 리포트 및 GA4 기반 광고비, 노출, 클릭, 전환, 방송실적 통합 뷰. ⚠️ 디지털/방송 measure는 상호배타적이며, 광고비만 전체 합산 가능. 마케팅캠페인(MKTG_CAMPAIGN_NAME) 축으로 분해 가능(소재별/개별캠페인별 분해 불가). 예산(SV_BUDGET) 및 회원개발실적(SV_MEMBER_EVENT)과의 교차 집계는 불가.'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 출처 필터: 노출·클릭·CTR·CVR·CRM개발건·개발단가(공7)·조회수·잠재고객 질의는 AD_SOURCE_TYPE=''DIGITAL'' 자동 추가. 인바운드콜·방송횟수·방송 개발건수·방송 개발회원수는 AD_SOURCE_TYPE IN (''VIDEO'',''REBROADCAST'') 추가하고 개발건수는 출처별로 나눠 반환. GA 개발단가(공8)·GA 개발(건)(GA_DEV_CNT)은 AD_SOURCE_TYPE=''DIGITAL'' 추가. 재방송 개발단가(참고 · 공8 아님)는 AD_SOURCE_TYPE=''REBROADCAST'' 추가. 광고비만 전체 합산 허용. (2) 기간 미지정 시: 최신 데이터 연월 기준 직전 12개월로 한정하며 GROUP BY ROLLUP((연,월)) 반환. (3) 캠페인 분해: MARKETING_CAMPAIGN 축으로 그루핑하며 ''(미매핑)'' 버킷 존재로 캠페인별 합계 < 전체 합계임을 명시. 소재별 및 개별 개발캠페인별 ROI/단가는 생성 거부 및 사유 안내. (4) 기기 필터: 모바일은 DEVICE_TYPE=''M'', 데스크톱은 ''PC''. 방송은 ''(해당없음)''. (5) 정렬: 방송 차원 광고비 기준 정렬 시 ORDER BY ... DESC NULLS LAST 사용. (기준시점 규칙) 「최근 N주·N개월」·기간 미지정 질의의 기준 시점은 **비상관 CTE 1개**에서 그 CTE 의 FROM 에 쓴 이름으로만 MAX 를 구하고 본 쿼리에 CROSS JOIN 한다. 스칼라·상관 서브쿼리로 기준 시점을 구하지 않는다. 광고 성과일은 ad 에 없다 — date.FULL_DATE(ad.PERF_DATE_SK = date.DATE_SK 조인)로만 건다(ad.PERF_DATE 는 없다). metric 이름을 컬럼처럼 참조하지 말고 정의식으로 집계한다. ORDER BY 에는 SELECT 별칭을 글자 그대로 쓴다. (전년대비) 전년 대비는 월(또는 주) 집계 CTE 를 만든 뒤 **그 CTE 를 연도-1 로 자기조인**한다(LAG 는 빠진 월이 있으면 어긋난다). 디지털 광고는 2024-01 부터 적재돼 있으므로 「전년 데이터 없음」으로 답하지 않는다. 광고와 개발실적의 전년 대비를 함께 물으면 이 SV(광고)와 SV_MEMBER_EVENT(개발)를 **각각 호출해 월 단위로 나란히** 보여주고, 한 SQL 로 조인하지 않는다(교차 집계 불가). (소속 테이블) 마케팅캠페인 축은 **mktg.MARKETING_CAMPAIGN** 이다 — ad 테이블에 없다(ad.MARKETING_CAMPAIGN 은 invalid identifier) ⇒ ad JOIN mktg ON ad.MKTG_CAMPAIGN_SK = mktg.MKTG_CAMPAIGN_SK 로 붙인다. 기기 축은 device.*, 날짜 축은 date.* 소속이다. (🆕 O225-C 캠페인 속성 분해) 광고비는 마케팅캠페인 단위로만 붙어 있다 — UTM(MKTG_UTM_NM)·국내/해외·사업/사례별로는 이 SV 로 나눈다(국내/해외·사업/사례는 대표값이므로 *_IS_MULTI 비중을 밝힌다). 🔴 캠페인 인입경로·마케팅채널·캠페인 카테고리별 광고비는 이 SV 로 내지 않는다 — 마케팅캠페인 하나 아래 값이 갈리는 비중이 커서(실측은 이슈원장 §O225) 대표값이 왜곡된다. 그 축의 성과(개발·회비)는 회원 측 SV(SV_MEMBER_EVENT·SV_MEMBER_FEE·SV_PAYMENT_BILLING_STATUS)로 안내한다.'
  AI_VERIFIED_QUERIES (
    vqr_ad_cost_by_source AS (
      QUESTION '출처유형별 광고비 합계'
      VERIFIED_BY '(DW = O190)'
      SQL 'SELECT ad.AD_SOURCE_TYPE, SUM(ad.AD_COST) AS TOTAL_AD_COST FROM ad GROUP BY ad.AD_SOURCE_TYPE ORDER BY TOTAL_AD_COST DESC NULLS LAST'
    ),
    vqr_o191_digital_weekly_ctr AS (
      QUESTION '최근 8주 디지털 광고 주차별 노출·클릭·CTR'
      VERIFIED_BY '(DW = O191)'
      SQL 'WITH mx AS (SELECT MAX(date.FULL_DATE) AS md FROM ad JOIN date ON ad.PERF_DATE_SK = date.DATE_SK WHERE ad.AD_SOURCE_TYPE = ''DIGITAL'') SELECT date.YEAR, ad.WEEK_OF_YEAR, SUM(ad.IMPRESSIONS) AS TOTAL_IMPRESSIONS, SUM(ad.CLICKS) AS TOTAL_CLICKS, SUM(ad.CLICKS) / NULLIF(SUM(ad.IMPRESSIONS), 0) * 100 AS CTR FROM ad JOIN date ON ad.PERF_DATE_SK = date.DATE_SK CROSS JOIN mx WHERE ad.AD_SOURCE_TYPE = ''DIGITAL'' AND date.FULL_DATE > DATEADD(WEEK, -8, mx.md) GROUP BY date.YEAR, ad.WEEK_OF_YEAR ORDER BY date.YEAR, ad.WEEK_OF_YEAR'
    ),
    vqr_o191_digital_monthly_yoy AS (
      QUESTION '디지털 광고 월별 노출·클릭·광고비 전년 동월 대비'
      VERIFIED_BY '(DW = O191)'
      SQL 'WITH m AS (SELECT date.YEAR AS YR, date.MONTH AS MN, SUM(ad.IMPRESSIONS) AS IMP, SUM(ad.CLICKS) AS CLK, SUM(ad.AD_COST) AS COST FROM ad JOIN date ON ad.PERF_DATE_SK = date.DATE_SK WHERE ad.AD_SOURCE_TYPE = ''DIGITAL'' GROUP BY date.YEAR, date.MONTH) SELECT c.YR, c.MN, c.IMP, p.IMP AS IMP_PREV_YEAR, c.CLK, p.CLK AS CLK_PREV_YEAR, c.COST, p.COST AS COST_PREV_YEAR, (c.CLK - p.CLK) / NULLIF(p.CLK, 0) * 100 AS CLK_YOY_PCT, (c.COST - p.COST) / NULLIF(p.COST, 0) * 100 AS COST_YOY_PCT FROM m c LEFT JOIN m p ON p.YR = c.YR - 1 AND p.MN = c.MN ORDER BY c.YR, c.MN'
    )
  );

-- SV_DEV_ACHIEVEMENT ← 05_08_SV_DDL_DEV_ACHIEVEMENT.sql
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_DEV_ACHIEVEMENT
  TABLES (
    achv AS GN_DW.GOLD.FACT_MEMBER_DEV_ACHIEVEMENT
      PRIMARY KEY (MONTH_KEY, ORG_SK, DEV_TYPE)
      WITH SYNONYMS ('개발목표', '개발실적', '목표대비실적', '개발현황')
      COMMENT = '회원개발 부문 목표 대비 실적 달성률 분석 (base: GOLD.FACT_MEMBER_DEV_ACHIEVEMENT). [Grain: 월 × 부서 × 개발구분]. [활성 지표: 월/연 목표건수, 실적건수, 달성률(%)]. [주의: 앵커_경합 방지, 달성률은 GOAL_CNT>0 스코프 필수]. [원천: GOLD.FACT_TARGET_MEMBER_DEV × FACT_MEMBER_EVENT].'
  )
  DIMENSIONS (
    achv.MONTH_KEY AS achv.MONTH_KEY
      WITH SYNONYMS ('연월', '목표월', '기준연월', '실적월')
      COMMENT = 'YYYYMM 정수. 목표와 실적의 공통 월 축.',
    achv.CAL_YEAR AS achv.CAL_YEAR
      WITH SYNONYMS ('연도', '년', '목표연도')
      COMMENT = '연도. 연 목표·연 실적(정본 공#3)은 이 축으로 그룹하면 산출된다 — 별도 metric 이 필요 없다.',
    achv.CAL_MONTH AS achv.CAL_MONTH
      WITH SYNONYMS ('월')
      COMMENT = '월(1~12). 누계(정본 공#2)는 이 값에 범위 조건(1~기준월)을 걸어 산출한다.',
    achv.ORG_DEPARTMENT AS achv.ORG_DEPARTMENT
      WITH SYNONYMS ('부서', '부서명', '실적부서', '담당부서')
      COMMENT = '부서명(정본 #116). 장표의 첫 축이다. 실적측은 실적부서(원천 ACMSLT_DEPT_CD) 기준으로 귀속된다. 값 ''(미매핑)''은 부서코드가 조직 마스터에 없는 소수 행이다. ⚠️본부/지부·팀·법인 축은 이 SV 에 없다 — 산출규칙 미확정이라 값이 존재하지 않으며, 요청받으면 부서 단위까지만 가능하다고 답할 것(추정 금지). ⚠️조직 개편으로 목표만 편성되고 실적은 다른 부서로 귀속된 부서가 존재한다 — 달성율이 0 에 가까운 부서를 「실적 부진」으로 단정하지 말고 해당 연도에 실적이 아예 없는지 확인할 것. 🔴부서 목표 규모의 편차가 매우 크다 — 월 한 자리 수 목표인 소규모 센터와 수천 건 목표인 부서가 같은 축에 있다. **달성율 순위·「최우수 부서」 판정에는 반드시 TOTAL_GOAL_CNT 를 함께 제시**하고, 목표 규모가 극소한 부서를 단독 1위로 결론하지 말 것. 소규모 부서는 실적 몇 건으로 달성율이 100% 를 넘으며 이는 스코프 결함이 아니라 실제 초과 달성이다.',
    achv.DEV_TYPE AS achv.DEV_TYPE
      WITH SYNONYMS ('개발구분코드')
      COMMENT = '개발구분 코드 raw. 실제값은 1(신규)·2(증액)·4(재후원) 세 가지뿐이다 — 정본 공#121 개발 정의와 일치한다. 라벨은 DEV_TYPE_NAME. ⚠️감액(3)·후원중단(5)은 개발이 아니므로 목표·실적 양쪽에 없다. 실제값 3종: ''1''·''2''·''4''',
    achv.DEV_TYPE_NAME AS achv.DEV_TYPE_NAME
      WITH SYNONYMS ('개발구분', '개발구분명', '개발유형')
      COMMENT = '개발구분명(CRM 코드사전 MM015 라벨) — 신규/증액/재후원. 코드는 DEV_TYPE. 🔴목표 편성은 개발구분별로 관행이 크게 다르다 — 증액·재후원은 최근 연도에 목표가 0 으로 등록돼 있어 그 기간 달성율이 산출되지 않는다(현업 확인 대기). 구분별 달성율을 비교할 때 이 비대칭을 함께 밝힐 것. 실제값 3종: ''신규''·''증액''·''재후원''',
    achv.HAS_POSITIVE_GOAL AS achv.HAS_POSITIVE_GOAL
      WITH SYNONYMS ('목표편성여부', '목표있음', '목표편성')
      COMMENT = 'TRUE=해당 월×부서×구분에 **0 보다 큰 목표가 편성**돼 있다. 🔴달성율 metric 이 이 조건으로 분자를 이미 스코프하므로 사용자가 따로 필터할 필요는 없다. 「목표가 편성된 부서만」 같은 요청에 이 축을 쓴다. ⚠️CRM 에 목표 0 으로 등록된 행이 다수 있어 「목표 행이 존재한다」와 「목표가 편성됐다」는 다르다 — 이 축은 후자다.',
    achv.HAS_ACTUAL AS achv.HAS_ACTUAL
      WITH SYNONYMS ('실적발생여부', '실적있음')
      COMMENT = 'TRUE=해당 월×부서×구분에 개발 실적이 발생했다. FALSE 는 목표만 편성된 월이며 **아직 오지 않은 미래월도 포함**한다 — 「미달」로 단정하지 말 것.'
  )
  METRICS (
    achv.TOTAL_GOAL_CNT AS SUM(achv.GOAL_CNT)
      WITH SYNONYMS ('월 목표', '개발목표', '회원개발목표', '목표건수', '연 목표', '누계 목표')
      COMMENT = '회원개발목표(건) 합계. F(가산). 🟢단월 필터=월 목표 · 1월~기준월 필터=누계 목표 · 연 그룹=연 목표 — **하나의 metric 이 세 지표를 모두 답한다**(별도 누계·연 metric 이 없는 이유다).',
    achv.TOTAL_ACTUAL_CNT AS SUM(achv.ACTUAL_CNT)
      WITH SYNONYMS ('월 실적', '개발실적', '개발건', '개발건수', '연 실적', '누계 실적')
      COMMENT = '개발실적(건) 합계 — 정본 공#121 개발(신규·증액·재후원) 기준. F(가산). ⚠️여기에는 **목표가 편성되지 않은 부서·월의 실적도 포함**된다. 그래서 이 값을 TOTAL_GOAL_CNT 로 직접 나누면 달성율이 과대해진다 — 달성율은 반드시 ACHIEVEMENT_RATE 를 쓸 것.',
    achv.TOTAL_ACTUAL_CNT_ON_GOAL AS SUM(CASE WHEN achv.GOAL_CNT > 0 THEN achv.ACTUAL_CNT END)
      WITH SYNONYMS ('목표편성분 실적', '달성율 분자')
      COMMENT = '목표가 편성된(GOAL_CNT>0) 월×부서×구분의 개발실적(건). F(가산). ACHIEVEMENT_RATE 의 **분자**다 — 달성율을 검산하고 싶을 때 TOTAL_GOAL_CNT 와 함께 쓴다. TOTAL_ACTUAL_CNT 보다 작다(목표 미편성분 제외).',
    achv.ACHIEVEMENT_RATE AS SUM(CASE WHEN achv.GOAL_CNT > 0 THEN achv.ACTUAL_CNT END) / NULLIF(SUM(achv.GOAL_CNT), 0) * 100
      WITH SYNONYMS ('목표 달성율', '달성율', '목표대비 개발', '월 목표 달성율', '누계 목표 달성율', '연 목표 달성율', '목표달성률')
      COMMENT = '목표 달성율(%) = 개발실적 ÷ 회원개발목표 ×100. 비율(N) — 상위 집계 시 분자·분모를 각각 합산해 재계산한다. 정본 공#1(월)·#2(누계)·#3(연)을 **동일 식**으로 답한다: 기간 필터만 바꾼다. 🔴**분자가 목표 편성분(GOAL_CNT>0)으로 스코프돼 있다** — 목표가 0 인 행의 실적이 분자에 들어가면 분모 없이 비율이 폭증하기 때문에 식에 못박았다. ⚠️따라서 TOTAL_ACTUAL_CNT ÷ TOTAL_GOAL_CNT 와 값이 다르다(그쪽이 과대). 손으로 검산하려면 TOTAL_ACTUAL_CNT_ON_GOAL ÷ TOTAL_GOAL_CNT 를 쓸 것.'
  )
  COMMENT = '회원개발 부문 목표 대비 실적 달성률 분석 (base: GOLD.FACT_MEMBER_DEV_ACHIEVEMENT). [Grain: 월 × 부서 × 개발구분]. [활성 지표: 월/연 목표건수, 실적건수, 달성률(%)]. [주의: 앵커_경합 방지, 달성률은 GOAL_CNT>0 스코프 필수]. [원천: GOLD.FACT_TARGET_MEMBER_DEV × FACT_MEMBER_EVENT].'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 시간 스코프: 월 목표/실적/달성율은 단일 연월 필터, 누계는 당해 연도 1월~기준월 필터, 연간은 연도 필터 적용 (별도 누계 metric 불필요). (2) 달성율 정본: 달성율은 항상 ACHIEVEMENT_RATE (%) 사용 (TOTAL_ACTUAL_CNT ÷ TOTAL_GOAL_CNT 직접 계산 금지). (3) 목표 0 처리: 목표 편성 부서 한정 시 HAS_POSITIVE_GOAL=TRUE 사용. (4) 주간 분기: 주간 개발실적은 SV_MEMBER_EVENT 로 라우팅하며, 주간 목표는 원천 부재로 산출 불가. (5) 판정 라벨 [앵커_경합]: 개발실적보고 주간 섹션은 경합 팩트가 동수이므로 하나를 골라 섹션 전체를 답하지 않는다 — 이 뷰(월 목표·달성율)와 SV_MEMBER_EVENT(주간 실적)·SV_MEMBER_FEE(회비)를 각각 호출해 연·월 축에서 병기하고 표마다 grain 을 밝힌다. 주간 목표 수치를 창작하지 않는다.'
  AI_VERIFIED_QUERIES (
    vqr_dept_achievement AS (
      QUESTION '2025년 부서별 목표·실적·달성율'
      VERIFIED_BY '(DW = O190)'
      SQL 'SELECT achv.ORG_DEPARTMENT, SUM(achv.GOAL_CNT) AS TOTAL_GOAL_CNT, SUM(achv.ACTUAL_CNT) AS TOTAL_ACTUAL_CNT, SUM(CASE WHEN achv.GOAL_CNT > 0 THEN achv.ACTUAL_CNT END) / NULLIF(SUM(achv.GOAL_CNT), 0) * 100 AS ACHIEVEMENT_RATE FROM achv WHERE achv.CAL_YEAR = 2025 AND achv.HAS_POSITIVE_GOAL GROUP BY achv.ORG_DEPARTMENT ORDER BY ACHIEVEMENT_RATE DESC NULLS LAST'
    ),
    vqr_monthly_goal_actual AS (
      QUESTION '월별 개발 목표와 실적'
      VERIFIED_BY '(DW = O190)'
      SQL 'SELECT achv.CAL_YEAR, achv.CAL_MONTH, SUM(achv.GOAL_CNT) AS TOTAL_GOAL_CNT, SUM(achv.ACTUAL_CNT) AS TOTAL_ACTUAL_CNT FROM achv GROUP BY achv.CAL_YEAR, achv.CAL_MONTH ORDER BY achv.CAL_YEAR, achv.CAL_MONTH'
    )
  );

-- SV_MEMBER_FEE ← 05_09_SV_DDL_MEMBER_FEE.sql
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_FEE
  TABLES (
    fee AS GN_DW.GOLD.WIDE_MEMBER_FEE
      WITH SYNONYMS ('회비', '회비 분해', '납입 상세', '후원사업별 회비')
      COMMENT = '회비 세부 분해 및 납입/미납 정밀 분석 (base: GOLD.WIDE_MEMBER_FEE). [Grain: 회원 × 회비월 × 사업 × 납입방식 × 결제수단]. [활성 지표: 청구액/납입액/미납액/수납률(%)]. [주의: 배분규칙필요 형제팩트중복 앵커_경합 이중계상 방지(SV_MEMBER_MONTHLY와 합산 금지)]. [원천: CRM → SILVER.CRM_PAYMENT_BILLING → GOLD.FACT_MEMBER_FEE].'
  )
  DIMENSIONS (
    fee.MONTH_KEY        AS fee.MONTH_KEY   WITH SYNONYMS ('회비월', '기준년월', '연월') COMMENT = '회비월 YYYYMM. 🔴청구·납입의 귀속 월이며 실제 납입일과 다를 수 있다 — 납입 **일자**는 LAST_PAY_DATE 를 쓴다. 회비월이 무효면 납입월로 폴백하고 둘 다 무효면 0(Unknown월)이다. 6자리 정수 YYYYMM 이라 출력하면 천단위 쉼표가 붙는다 — 결과·차트에 월을 보일 때는 MONTH_LABEL(''2026-01'')을 쓴다(필터·정렬은 이 키)',
    fee.MONTH_LABEL      AS IFF(fee.MONTH_KEY > 0, LEFT(TO_VARCHAR(fee.MONTH_KEY), 4) || '-' || RIGHT(TO_VARCHAR(fee.MONTH_KEY), 2), NULL) WITH SYNONYMS ('회비월(표시)', '회비 연월', '월 표시') COMMENT = '회비월 표시 라벨(YYYY-MM 문자열 · 예: 2026-01). 월별 결과의 행 라벨·차트 x축에 쓴다. Unknown월(0)은 NULL',
    fee.CAL_YEAR         AS fee.CAL_YEAR    WITH SYNONYMS ('연도', '년') COMMENT = '회비 연도',
    fee.CAL_MONTH        AS fee.CAL_MONTH   WITH SYNONYMS ('월') COMMENT = '회비 월(1~12)',
    fee.LAST_PAY_DATE    AS fee.LAST_PAY_DATE WITH SYNONYMS ('납입일', '기준일(납입일)', '최종납입일') COMMENT = '해당 조합의 **최종 납입일**. 🔴시점 축이며 합계가 아니다. `SV_MEMBER_MONTHLY` 는 월 팩트라 일자 분해가 불가하므로 「기준일(납입일)」 요구는 이 SV 에서만 답한다. ⚠️여러 번 납입한 조합은 마지막 납입일만 남는다 — 납입 횟수·일별 추이를 이 축으로 세지 말 것',
    fee.SPONSORSHIP      AS fee.SPONSORSHIP_NAME WITH SYNONYMS ('후원사업', '후원사업명', '납입 후원사업', '사업') COMMENT = '🔴**납입 대상** 후원사업명(정본 #123) — 그 회비가 어느 사업으로 들어갔는가다. ⚠️**획득 시점 후원사업과 다른 축**이다: 그 회원을 데려온 사업은 `SV_MEMBER_COHORT` 의 획득 후원사업(또는 이 SV 의 ACQ_SPONSORSHIP)이며, 한 회원이 여러 후원사업에 내므로 두 축의 값이 다르다. ⚠️개발 사건의 후원사업(`SV_MEMBER_EVENT`)과도 또 다른 축이다 — 세 축을 합산하지 말고 어느 축으로 답했는지 밝힌다. ⚠️미매칭은 ''(미매핑)''',
    fee.FEE_DIV          AS fee.FEE_DIV_NAME WITH SYNONYMS ('회비구분', '회비 종류') COMMENT = '회비구분명(정본 PM010). 실제값 4종: ''정기''·''선물금''·''일시''·''긴급구호''. 🔴**기부금 행은 원천이 NULL** 이다 — 결측이 아니라 「해당없음」이며 ''미상''으로 창작하지 말 것. 기부금을 보려면 PAYMENT_TYPE 을 쓴다',
    fee.FEE_DIV_CD       AS fee.FEE_DIV_CD  WITH SYNONYMS ('회비구분코드') COMMENT = '회비구분 원천코드(PM010: E=정기 · G=선물금 · I=일시 · U=긴급구호). 라벨은 FEE_DIV. 실제값 4종: ''E''·''G''·''I''·''U'' + NULL',
    fee.PAYMENT_TYPE     AS fee.PAYMENT_TYPE WITH SYNONYMS ('납입유형', '회비/기부금 구분') COMMENT = '납입유형. 실제값 2종: ''회비''·''기부금''. 🔴**납부율·미납 분석은 회비만으로 스코프해야 한다** — 기부금은 원천에 청구액(RQEST_AMT)이 전건 NULL 이라 분모에 들어갈 수 없다. 정본 납부율 metric 은 이 스코프를 이미 반영하고 있다',
    fee.PAYMENT_METHOD   AS fee.PAYMENT_METHOD_NAME WITH SYNONYMS ('납입방식', '결제수단', '결제방식', '수납방법') COMMENT = '결제수단 라벨. 실제값 6종: ''자동이체''·''신용카드''·''네이버페이''·''회비통장''·''OCR''·''휴대폰''. 🔴**라벨 커버리지가 100% 가 아니다** — 원천 결제수단 코드 11종 중 5종은 코드그룹이 특정되지 않아 ''(미매핑)''으로 모인다(현업 확인 대상). 따라서 **결제수단별 합계는 전체 합계보다 작다** — 총계는 이 축 없이 답한다. 원본 코드는 SETLE_CD 로 확인한다. ⚠️CRM_CODE 에서 11종을 덮는 그룹이 여럿 나왔으나 전부 의미 무관(간사/질병/취미…)이어서 **추측하지 않았다**(숫자 코드 우연 일치)',
    fee.SETLE_CD         AS fee.SETLE_CD    WITH SYNONYMS ('결제수단코드', '수납코드') COMMENT = 'degen: 결제수단 **원본 코드**. 라벨이 없는 5종을 잃지 않기 위해 보존한다 — ''(미매핑)'' 버킷의 정체를 이 축으로 확인할 수 있다. 🔴코드값 자체의 업무 의미는 현업 미확인이므로 **코드로 의미를 추정해 답하지 말 것**. 실제값 11종: ''1''·''2''·''3''·''4''·''5''·''6''·''7''·''8''·''10''·''12''·''13'' + NULL',
    fee.UNPAID_FLAG      AS fee.UNPAID_FLAG WITH SYNONYMS ('미납여부') COMMENT = '해당 조합에 미납 청구행이 하나라도 있는가(TRUE/FALSE). ⚠️**회원 단위 미납 여부가 아니다** — 회원 월말 미납 여부는 `SV_MEMBER_MONTHLY` 의 UNPAID_FLAG_EOM 이다',
    fee.MEMBER_STATUS    AS fee.MEMBER_STATUS_NAME WITH SYNONYMS ('회원상태') COMMENT = '회원상태 라벨(MM010). 🔴**현재 스냅샷**이다 — 과거 회비월 행에도 현재 상태가 붙는다. 실제값 13종: ''활동회원''·''후원중단''·''신규미납1''·''신규미납2''·''신규미납3''·''신규미납4''·''신규미납5''·''장기미납1''·''장기미납2''·''장기미납3''·''장기미납4''·''장기미납5''·''(해당없음)'' + NULL',
    fee.MEMBER_TYPE      AS fee.MEMBER_TYPE_NAME   WITH SYNONYMS ('회원구분') COMMENT = '회원구분 라벨(MM018). 실제값 3종: ''개인''·''기업''·''단체''. 🔴현재 스냅샷',
    fee.MEMBER_GENDER    AS fee.GENDER_NAME        WITH SYNONYMS ('성별') COMMENT = '회원 성별 라벨(CM017). 실제값 5종: ''남자''·''여자''·''기타''·''단체''·''기업''. 🔴현재 스냅샷. ⚠️`SV_MEMBER_COHORT` 의 획득시점 성별(CM013)과 **코드체계가 다르다** — 합산 금지',
    fee.ACQ_BRAND        AS fee.ACQ_BRAND        WITH SYNONYMS ('브랜드', '획득 브랜드', '최초브랜드') COMMENT = '🔴**획득 시점** 캠페인의 공통브랜드. 회비를 획득 캠페인별로 볼 때 쓴다(캠페인별 LTV 계열). 현재 속성이 아니다',
    fee.ACQ_CAMPAIGN     AS fee.ACQ_CAMPAIGN_NAME WITH SYNONYMS ('캠페인', '캠페인명', '가입캠페인', '획득캠페인') COMMENT = '🔴**획득 시점** 캠페인명. `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 는 다중귀속 규칙 미확정으로 센티넬이라 회원-월 팩트로는 캠페인 분해가 안 되지만, **획득 시점이라는 명시 규칙**으로 이 축이 성립한다. 카디널리티가 높으니 규모가 작은 캠페인의 비율은 불안정하다',
    fee.ACQ_PARENT_CAMPAIGN AS fee.ACQ_PARENT_CAMPAIGN_NAME WITH SYNONYMS ('상위캠페인') COMMENT = '획득 캠페인의 상위캠페인명. 상위가 없으면 NULL 이며 ''(미매핑)''이 아니다',
    fee.ACQ_PROMO_METHOD AS fee.ACQ_PROMO_METHOD_NAME WITH SYNONYMS ('홍보방법', '광고방법') COMMENT = '획득 캠페인의 홍보방법 라벨(CM008). 🔴원천 코드는 숫자라 코드로 필터하면 0행이 된다 — 반드시 이 라벨로 필터한다',
    fee.ACQ_MARKETING_CAMPAIGN AS fee.ACQ_MARKETING_CAMPAIGN WITH SYNONYMS ('마케팅캠페인') COMMENT = '획득 캠페인의 마케팅캠페인명(광고↔CRM conformed 축). 광고비와 대응시킬 때 이 축을 쓴다 — 단 광고비 자체는 `SV_AD` 소관이며 두 SV 를 조인할 수 없다(각각 조회해 표를 분리한다)',
    fee.ACQ_DEPARTMENT   AS fee.ACQ_DEPARTMENT   WITH SYNONYMS ('부서', '가입부서', '획득부서') COMMENT = '🔴**획득 시점 부서명**. ⚠️개발실적보고의 「부서」는 **사건 부서**(`SV_MEMBER_EVENT.ORG_DEPARTMENT`)이며 **다른 축**이다 — 같은 라벨, 다른 값. 연간분석(회비)의 부서가 이 축이다. ⚠️상위 조직(본부/지부·팀·법인)은 산출 불가',
    fee.ACQ_SPONSORSHIP  AS fee.ACQ_SPONSORSHIP_NAME WITH SYNONYMS ('획득 후원사업', '가입 후원사업') COMMENT = '🔴**획득 시점** 후원사업명(그 회원을 데려온 사업). ⚠️이 SV 의 SPONSORSHIP(=납입 대상)과 **다른 축**이다 — 회비가 들어간 사업과 회원을 데려온 사업은 다를 수 있다',
    fee.ACQ_AGE_BAND     AS fee.ACQ_AGE_BAND     WITH SYNONYMS ('연령대', '나이대') COMMENT = '🔴**획득 시점** 연령대(CM014) — **현재 나이가 아니다**(현재 연령은 BRONZE 에 생년월일이 없어 산출 불가). ''10대 미만''이 많은 것은 오류가 아니며 편지쓰기대회 계열 아동 모집 캠페인 때문이다 — 결측·오염으로 설명하지 말 것. ⚠️''단체''·''기업''은 나이가 아니라 법인 구분이므로 연령 추이에서 제외한다. 실제값 12종: ''기업''·''기타''·''단체''·''10대''·''20대''·''30대''·''40대''·''50대''·''60대''·''70대''·''10대 미만''·''70대 이상'' + NULL',
    fee.ACQ_REGION       AS fee.ACQ_REGION       WITH SYNONYMS ('지역', '시도') COMMENT = '🔴**획득 시점** 지역(CM018 약칭) — **현재 거주지가 아니다**. 센티넬은 라벨이 없어 NULL 이며 ''미상''으로 창작하지 않는다. 실제값 18종: ''강원''·''경기''·''경남''·''경북''·''광주''·''기타''·''대구''·''대전''·''부산''·''서울''·''세종''·''울산''·''인천''·''전남''·''전북''·''제주''·''충남''·''충북'' + NULL',
    -- [2026-10-07 O205] 획득 캠페인 분류 8축(DIM_MEMBER_ACQUISITION 동결값 · WIDE_MEMBER_FEE 에 노출)
    fee.ACQ_CAMPAIGN_TYPE AS fee.ACQ_CAMPAIGN_TYPE WITH SYNONYMS ('캠페인카테고리', '주요캠페인', '캠페인 카테고리', '캠페인카테고리 구분') COMMENT = '🔴**획득 시점** 캠페인카테고리(=주요캠페인). 「캠페인카테고리별 납입회비·회비흐름」은 이 축으로 답한다. ⚠️`SV_MEMBER_EVENT` 의 캠페인카테고리는 **사건 시점**이라 다른 축이다. 🔴ML 회비 예측(`SV_ML_FEE_FORECAST`)의 캠페인카테고리와 이름이 같아도 실적·예측을 한 표에 합산하지 않는다',
    fee.ACQ_INFLOW_PATH  AS fee.ACQ_INFLOW_PATH  WITH SYNONYMS ('개발인입경로', '인입경로', '유입경로', '회원인입경로') COMMENT = '🔴**획득 시점** 개발인입경로(MM293 라벨). 적재 시점 동결값',
    fee.ACQ_DOMESTIC_OVERSEAS AS fee.ACQ_DOMESTIC_OVERSEAS WITH SYNONYMS ('국내해외', '국내/해외') COMMENT = '🔴**획득 시점** 캠페인 국내해외 구분. 적재 시점 동결값. ⚠️납입 대상 후원사업의 국내·해외 분류(SPONSORSHIP)와 다른 축이다',
    fee.ACQ_BIZ_CASE_TYPE AS fee.ACQ_BIZ_CASE_TYPE WITH SYNONYMS ('사업사례', '사업사례구분') COMMENT = '🔴**획득 시점** 캠페인 사업사례구분. 적재 시점 동결값',
    fee.ACQ_CMMN_BRAND   AS fee.ACQ_CMMN_BRND_NM WITH SYNONYMS ('공통브랜드', '공동브랜드') COMMENT = '🔴**획득 시점** 공통브랜드(MM297). ⚠️ACQ_BRAND(캠페인 브랜드)와 다른 축이다 — 「공통브랜드」를 물으면 이 축을 쓴다',
    fee.ACQ_UTM          AS fee.ACQ_MKTG_UTM_NM  WITH SYNONYMS ('UTM', 'utm') COMMENT = '🔴**획득 시점** UTM 라벨. ⚠️채움이 낮다(코드사전 미등재분 NULL · 결측이 아니라 미등재) — UTM 별 합계는 전체보다 작으므로 부분집합임을 밝히고 채움 비율은 조회로 확인한다',
    fee.ACQ_SPNSR_DIV    AS fee.ACQ_SPNSR_DIV_NM WITH SYNONYMS ('후원구분', '세부캠페인 후원구분', '정기일시구분(캠페인)') COMMENT = '🔴**획득 세부캠페인** 후원구분(CM035 정기후원/일시후원). ⚠️회비구분(FEE_DIV)·납입유형과 다른 축이다',
    fee.ACQ_CPR_DIV      AS fee.ACQ_CPR_DIV_NM   WITH SYNONYMS ('법인구분', '세부캠페인 법인구분', '법인', '사단법인', '사복', '사회복지법인', '사단', '법인명') COMMENT = '🔴**획득 세부캠페인** 법인구분(CM019 통합/사단/사복). 🔴조직 계층 법인(산출 불가)과 다른 축이다 — 「사단 회원 회비」·「사단법인 회비」는 이 축(ACQ_CPR_DIV = ''사단'')으로 답하고 캠페인 법인구분 기준임을 밝힌다'
  )
  METRICS (
    fee.TOTAL_BILLED_AMT AS SUM(fee.BILLED_AMT)
      WITH SYNONYMS ('청구액', '청구회비', '청구', '총청구액')
      COMMENT = '청구액(원) 합계 = SUM(RQEST_AMT) · 정본 #71. F(가산). 🔴재청구 중복을 포함한다 — 정본 #71 비고가 「청구회비금액: 재청구 중복 포함」을 명시하므로 이것이 정본 정의다. 🔴`SV_MEMBER_MONTHLY` 의 청구액과 **같은 원천**이므로 두 SV 의 값을 더하지 말 것 — 전체 합계는 두 SV 가 일치해야 한다.',
    fee.TOTAL_PAID_FEE_BILLABLE AS SUM(fee.PAID_FEE_BILLABLE)
      WITH SYNONYMS ('납입회비', '회비 납입액', '수납회비')
      COMMENT = '**회비** 납입액(원) 합계 — 납부율 분자 **정본**. F(가산). 기부금을 제외한다.',
    fee.TOTAL_PAID_ALL AS SUM(fee.PAID_FEE)
      WITH SYNONYMS ('총수납액')
      COMMENT = '납입 총액(원) = 회비 + **기부금**. F(가산). 🔴**납부율 분자로 쓰지 말 것** — 기부금은 청구액이 없어 분모에 못 들어가므로 비율이 100% 를 넘는다(실사고). 「총수납액(회비+기부금)」을 명시적으로 물을 때만 쓰고 그때도 기부금 포함임을 밝힌다.',
    fee.TOTAL_UNPAID_AMT AS SUM(fee.UNPAID_BILLED_AMT)
      WITH SYNONYMS ('미납금액', '총미납금액', '미납액')
      COMMENT = '미납 청구액(원) 합계 — **정본**(결제상태 실패 F 또는 NULL 인 청구액). F(가산). 🔴「청구−납입」 차감식이 아니다(차감식은 기부금이 미납을 상쇄해 음수가 나온다). ⚠️**조회 시점 스냅샷**이다 — 과거 연도 미납이 이후에 납입되면 값이 바뀐다. 「마감·확정」이라 단정하지 말 것.',
    fee.PAYMENT_RATE_FEE AS SUM(fee.PAID_FEE_BILLABLE) / NULLIF(SUM(fee.BILLED_AMT), 0) * 100
      WITH SYNONYMS ('납부율', '납입율', '수납율')
      COMMENT = '납부율(**%**) = **회비** 납입액 ÷ **회비** 청구액 ×100. N(비가산 — 분자·분모를 각각 집계한 뒤 나눈다). 🔴분자·분모가 모두 회비라 모집단이 일치한다. `TOTAL_PAID_ALL` 을 분자로 바꾸면 기부금이 섞여 **100% 를 넘는다** — 에서 실제로 그 상태가 배포된 적이 있다. ⚠️기간 스코프 없이 답하지 말 것 — 미납이 이후 납입되는 구조라 최근 기간은 낮게 보인다. 🔴 단위는 **퍼센트**다 — 값을 다시 ×100 하지 말 것. `SV_MEMBER_MONTHLY.PAYMENT_RATE_FEE`(공64 정본)와 **같은 단위**이므로 전체 합계는 두 SV 가 일치해야 한다.',
    fee.UNPAID_RATIO AS SUM(fee.UNPAID_BILLED_AMT) / NULLIF(SUM(fee.BILLED_AMT), 0) * 100
      WITH SYNONYMS ('미납비중', '미납율', '미납률')
      COMMENT = '미납비중(**%**) = 미납 청구액 ÷ 회비 청구액 ×100. N(비가산). 정본 분자. 🔴 단위는 **퍼센트**다 — 값을 다시 ×100 하지 말 것. `SV_MEMBER_MONTHLY.UNPAID_RATIO` 와 **같은 이름·같은 식·같은 단위**이며 전체 합계가 일치해야 한다(실측 일치 확인).',
    fee.DISTINCT_PAYING_MEMBERS AS COUNT(DISTINCT fee.MEMBER_DK)
      WITH SYNONYMS ('납입 회원수', '회비 회원수', '납입(명)')
      COMMENT = '**고유 회원수(명)** = COUNT(DISTINCT 회원). N(비가산 — 기간·축을 가로질러 더하면 중복된다). 🔴이 팩트는 회원당 여러 행이므로 **행 수를 「명」으로 쓰면 크게 과대**해진다(`*_MEMBERS` 계열 함정과 같은 유형). 「납입 회원수」 질문은 반드시 이 metric 으로 답한다.',
    fee.TOTAL_BILLING_ROWS AS SUM(fee.BILLING_ROWS)
      WITH SYNONYMS ('청구행수', '원천 회비행수')
      COMMENT = '집계된 원천 회비행 수. F(가산). 🔴**금액도 「건수」도 아니다** — 정본 `(건)` 은 금액÷10,000 규약이므로 이 값을 「건」이라 부르면 정의가 깨진다. 재청구 시도 강도를 볼 때만 쓴다.'
  )
  COMMENT = 'Phase-1 회비 분해 SV (base: GOLD.WIDE_MEMBER_FEE, grain: 회원×회비월×후원사업×회비구분×납입유형×결제수단). 후원사업, 납입방식(결제수단), 회비구분, 납입일별 회비 청구/납입/미납 정본 뷰. ⚠️ 회원-월 요약(SV_MEMBER_MONTHLY)과 동일 표 합산 금지(이중계상). 후원사업은 납입 대상 후원사업 기준임.'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 이중계상 방지: SV_MEMBER_MONTHLY 와 본 뷰의 measure 를 한 표에 합산하지 말 것(표 분리). (2) 납부율: 납부율=PAYMENT_RATE_FEE (회비만 기준, %), 총수납액(회비+기부금)=TOTAL_PAID_ALL. (3) 회원수: 납입 회원수는 DISTINCT_PAYING_MEMBERS (distinct) 사용. (4) 기간 미지정 시: 데이터 최신 연월 기준 직전 12개월로 한정하며 GROUP BY ROLLUP((연,월)) 반환. (5) 후원사업 분기: 본 뷰의 SPONSORSHIP 은 납입 대상 후원사업이며, 개발 사건 시점은 SV_MEMBER_EVENT, 획득 시점은 SV_MEMBER_COHORT 로 라우팅. (6) 정렬: 비율 metric 정렬 시 ORDER BY ... DESC NULLS LAST 사용. (7) 판정 라벨 [형제팩트중복]: 「납입(원)」·납입방식별 금액은 이 뷰를 앵커로 답한다. SV_MEMBER_MONTHLY 와 한 표에 합치지 않고 표를 분리하며 각 표의 grain 을 밝힌다. (8) 판정 라벨 [배분규칙필요]: 발송·사건 grain 으로 이 뷰의 회비 measure 를 요구받으면 SQL 을 만들지 않고 「배분(귀속) 규칙이 필요한 업무 판단 사안」이라고 답한다. 회비 measure 를 자기 grain(회원×회비월×후원사업)에서 묻는 질의는 정상 답변한다. (기준시점 규칙) 「최근 N개월」·기간 미지정 질의의 기준 월은 **비상관 CTE 1개**(SELECT MAX(fee.MONTH_KEY) AS mk FROM fee)로 구하고 본 쿼리를 FROM fee CROSS JOIN 그 CTE 로 쓴다 — 본 쿼리 FROM 에서 fee 를 빼지 않는다. 후원사업은 **논리 차원 fee.SPONSORSHIP**, 납입방식은 **fee.PAYMENT_METHOD** 이다(🔴 종전 이 자리의 「fee.SPONSORSHIP 은 없다」는 **거꾸로 쓴 오기**였다 — 물리 컬럼명 SPONSORSHIP_NAME·PAYMENT_METHOD_NAME 을 CTE 컬럼으로 쓰지 말고 논리 차원명을 쓴다). 월 경계는 TO_DATE(TO_VARCHAR(MONTH_KEY), ''YYYYMM'') 로 날짜화해 DATEADD 한다. 월별 결과를 낼 때 출력 월 컬럼은 MONTH_LABEL(문자 ''YYYY-MM'') 로 낸다 — MONTH_KEY(6자리 정수 YYYYMM)를 그대로 출력하면 천단위 쉼표가 붙어 보인다(정렬은 MONTH_KEY 또는 MONTH_LABEL 문자 순서). ORDER BY 에는 SELECT 별칭을 글자 그대로 쓴다.'
  AI_VERIFIED_QUERIES (
    vqr_o191_last12m_by_sponsorship AS (
      QUESTION '최근 12개월 후원사업별·납입방식별 회비 청구액과 납부율'
      VERIFIED_BY '(DW = O191)'
      SQL 'WITH mx AS (SELECT MAX(fee.MONTH_KEY) AS mk FROM fee) SELECT fee.SPONSORSHIP, fee.PAYMENT_METHOD, SUM(fee.BILLED_AMT) AS TOTAL_BILLED_AMT, SUM(fee.PAID_FEE_BILLABLE) / NULLIF(SUM(fee.BILLED_AMT), 0) * 100 AS PAYMENT_RATE_FEE FROM fee CROSS JOIN mx WHERE fee.MONTH_KEY > TO_NUMBER(TO_CHAR(DATEADD(MONTH, -12, TO_DATE(TO_VARCHAR(mx.mk), ''YYYYMM'')), ''YYYYMM'')) AND fee.MONTH_KEY <= mx.mk GROUP BY fee.SPONSORSHIP, fee.PAYMENT_METHOD ORDER BY TOTAL_BILLED_AMT DESC NULLS LAST'
    ),
    vqr_o223_sadan_member_fee AS (
      QUESTION '사단법인 연도별 회비 납입액과 청구액 및 납부율'
      VERIFIED_BY '(DW = O223)'
      SQL 'SELECT fee.CAL_YEAR, fee.ACQ_CPR_DIV, SUM(fee.BILLED_AMT) AS TOTAL_BILLED_AMT, SUM(fee.PAID_FEE_BILLABLE) AS TOTAL_PAID_FEE_BILLABLE, SUM(fee.PAID_FEE_BILLABLE) / NULLIF(SUM(fee.BILLED_AMT), 0) * 100 AS PAYMENT_RATE_FEE FROM fee WHERE fee.ACQ_CPR_DIV = ''사단'' GROUP BY fee.CAL_YEAR, fee.ACQ_CPR_DIV ORDER BY fee.CAL_YEAR DESC'
    )
  );

-- SV_MEMBER_SPONSOR_BIZ ← 05_10_SV_DDL_MEMBER_SPONSOR_BIZ.sql
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ
  TABLES (
    fmsb AS GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN
      WITH SYNONYMS ('회원 후원약정', '캠페인별 활동회원', '후원사업별 활동회원')
      COMMENT = '회원×후원약정 기간 및 캠페인/사업별 활동회원 분석 (base: GOLD.FACT_MEMBER_SPONSORSHIP_SPAN). [Grain: 회원 × 후원약정번호]. [활성 지표: 약정 활동회원수]. [주의: 전체 활동회원수 정본은 SV_MEMBER_MONTHLY 사용]. [원천: CRM → SILVER.CRM_MEMBER_SPONSOR_SPAN → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN].',
    sponsorship AS GN_DW.GOLD.DIM_SPONSORSHIP
      PRIMARY KEY (SPONSORSHIP_SK)
      WITH SYNONYMS ('후원사업 차원')
      COMMENT = '후원사업 마스터. PK 유일이라 조인이 행수를 늘리지 않는다.',
    campaign AS GN_DW.GOLD.DIM_CAMPAIGN
      PRIMARY KEY (CAMPAIGN_SK)
      WITH SYNONYMS ('캠페인 차원')
      COMMENT = '캠페인 마스터. PK 유일이라 조인이 행수를 늘리지 않는다.'
  )
  RELATIONSHIPS (
    fmsb_to_sponsorship AS fmsb (SPONSORSHIP_SK) REFERENCES sponsorship,
    fmsb_to_campaign    AS fmsb (CAMPAIGN_SK)    REFERENCES campaign
  )
  DIMENSIONS (
    fmsb.MEMBER_DK        AS fmsb.MEMBER_DK    WITH SYNONYMS ('회원번호') COMMENT = '회원 (불변키)',
    fmsb.SPNSR_BSNS_NO    AS fmsb.SPNSR_BSNS_NO WITH SYNONYMS ('후원사업번호', '약정번호') COMMENT = '회원별 후원약정 일련번호. 🔴단독 유일키 아니다 — 공동후원 쌍(부부 등)이 2개 회원에 공유되는 사례가 실재한다. 분류축이 아니다(분류는 SPONSORSHIP 축)',
    sponsorship.SPONSORSHIP AS sponsorship.SPONSORSHIP_NAME WITH SYNONYMS ('후원사업', '후원사업명', '사업') COMMENT = '후원사업명(마스터). 미매핑 없음(전건 매칭 실측 확인)',
    sponsorship.SPONSORSHIP_DIV AS sponsorship.SPONSORSHIP_DIV_NAME WITH SYNONYMS ('정기일시구분') COMMENT = '정기후원/일시후원 구분(CM035). 실제값 2종: ''정기후원''·''일시후원''.',
    sponsorship.SPONSORSHIP_ABBR_CATEGORY AS sponsorship.SPONSORSHIP_GROUP_NAME WITH SYNONYMS ('후원사업 약칭', '후원사업 카테고리') COMMENT = '후원사업 약칭 그룹(CM003). 실제값 6종: ''결연''·''국내''·''기타''·''북한''·''해외''·''해외구호''.',
    campaign.CAMPAIGN     AS campaign.CAMPAIGN_NAME WITH SYNONYMS ('캠페인', '캠페인명') COMMENT = '대표캠페인명. 판정 규칙 = CRM_MEMBER_DEV 사건 중 ①신규사건이 있으면 그 신규사건 ②없으면 최초사건(동률 0 확인). 사건 자체가 없는 약정은 "(미매핑)"(0). ⚠️단일 회원-grain 캠페인 분해(FACT_MEMBER_MONTHLY 기준)와는 다른 축이다 — 이 SV 는 약정grain 이라 값이 다르게 나올 수 있다',
    fmsb.ACQ_CMPGN_CTGR_NM AS fmsb.ACQ_CMPGN_CTGR_NM WITH SYNONYMS ('캠페인 카테고리', '주요캠페인') COMMENT = '대표캠페인 카테고리 라벨(MM294). 🔴적재 시점 동결값(구 campaign.CAMPAIGN_TYPE 대체)',
    fmsb.IS_MULTI_CAMPAIGN AS fmsb.IS_MULTI_CAMPAIGN WITH SYNONYMS ('다중캠페인 여부') COMMENT = '참고용 투명성 플래그 — 이 SPNSR_BSNS_NO 의 전체 사건에서 캠페인이 2개 이상이었는지. 대표캠페인 채택 규칙과는 별개. 🟢실측상 극소수이며 최대 2개다9 참조)',
    fmsb.START_MONTH_KEY  AS fmsb.START_MONTH_KEY WITH SYNONYMS ('활동개시월') COMMENT = '활동 개시 월키 YYYYMM. 특정월 as-of 활동 판정 시 이 축과 DSCNTC_MONTH_KEY 를 함께 WHERE 절로 비교한다(AI_SQL_GENERATION 참조)',
    fmsb.DSCNTC_MONTH_KEY AS fmsb.DSCNTC_MONTH_KEY WITH SYNONYMS ('중단월') COMMENT = '중단 월키 YYYYMM. 🔴NULL=미중단(현재까지 활동)이며 결측이 아니다',
    campaign.CAMPAIGN_MKTG_CHANNEL_NM AS campaign.MKTG_CHANNEL_NM WITH SYNONYMS ('마케팅채널', '캠페인 마케팅채널') COMMENT = '캠페인 마케팅채널(원천 COMMENT = 마케팅 채널명 · C002) — 캠페인 마스터 현재값. 🔴 값 「-」는 원천 코드사전 C002 에 등록된 코드 6 의 라벨이다(결측 아님 · 근거 = 문서20 N-29 머리 실측) — 「채널 미지정 캠페인」으로 읽되 업무 의미는 원천 확인 대상이며, 채널별 순위에서는 「-」를 따로 밝힌다.',
    fmsb.SPNSR_JOIN_PATH_NM AS fmsb.SPNSR_JOIN_PATH_NM WITH SYNONYMS ('후원 가입경로', '가입경로') COMMENT = '후원(약정) 단위 가입경로(MM014 · REG·홈페이지·모바일웹·모바일앱·외주콜센터·CRM).',
    sponsorship.SPONSORSHIP_GROUP4_NAME AS sponsorship.SPONSORSHIP_GROUP4_NAME WITH SYNONYMS ('후원사업 4그룹', '후원사업그룹') COMMENT = '후원사업 4그룹(국내/결연/해외프로젝트/기타 · CM003 라벨 접기 · 규칙 밖 라벨은 NULL).'
  )
  METRICS (
    fmsb.CURRENTLY_ACTIVE_MEMBERS AS COUNT(DISTINCT IFF(fmsb.DSCNTC_MONTH_KEY IS NULL, fmsb.MEMBER_DK, NULL))
      WITH SYNONYMS ('지금 활동회원수', '현재 활동회원')
      COMMENT = '**지금 시점** 활동회원수(명) = 미중단 약정을 보유한 고유회원. N(비가산). 🔴전체 활동회원수 정본은 SV_MEMBER_MONTHLY.ACTIVE_MEMBERS 다 — 이 metric 을 캠페인·후원사업으로 GROUP BY 하면 한 회원이 여러 축에 중복 집계될 수 있어 **합계가 전체보다 클 수 있다**(다중 후원 정상 현상). 특정 과거월 as-of 는 이 metric 이 아니라 START_MONTH_KEY·DSCNTC_MONTH_KEY 원시축으로 직접 WHERE 를 구성한다.',
    fmsb.TOTAL_REGISTRATIONS AS COUNT(*)
      WITH SYNONYMS ('약정건수', '등록건수')
      COMMENT = '약정(SPNSR_BSNS_NO) 행수. F(가산). 🔴"명"이 아니다 — 회원당 여러 약정을 가질 수 있다',
    fmsb.DISTINCT_MEMBERS AS COUNT(DISTINCT fmsb.MEMBER_DK)
      WITH SYNONYMS ('고유회원수', '약정보유회원수')
      COMMENT = '활동여부 무관, 이 팩트에 약정이 하나라도 있는 고유 회원수(명). N(비가산)',
    fmsb.CURRENTLY_ACTIVE_SPNSR_AMT AS SUM(IFF(fmsb.DSCNTC_MONTH_KEY IS NULL, fmsb.SPNSR_AMT, 0))
      WITH SYNONYMS ('지금 활동 약정금액', '현재 활동 후원금액')
      COMMENT = '**지금 시점** 미중단 약정의 SPNSR_AMT 합(원). F(가산). 🔴정본 (건) 표기로 바꾸려면 이 값을 만원 단위로 환산한다(규약) — 이 SV 는 원단위로 노출하고 환산은 소비 시 명시한다.',
    fmsb.TOTAL_SPNSR_AMT AS SUM(fmsb.SPNSR_AMT)
      WITH SYNONYMS ('약정금액 총계')
      COMMENT = '활동여부 무관 SPNSR_AMT 합(원). F(가산)'
  )
  COMMENT = '회원×후원약정 기간 및 캠페인/사업별 활동회원 분석 (base: GOLD.FACT_MEMBER_SPONSORSHIP_SPAN). [Grain: 회원 × 후원약정번호]. [활성 지표: 약정 활동회원수]. [주의: 전체 활동회원수 정본은 SV_MEMBER_MONTHLY 사용]. [원천: CRM → SILVER.CRM_MEMBER_SPONSOR_SPAN → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN].'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 활동회원 총계 vs 분해: 전체 활동회원수 총계는 SV_MEMBER_MONTHLY 로 라우팅. 캠페인별/후원사업별 분해 시에만 본 뷰의 CURRENTLY_ACTIVE_MEMBERS 사용. (2) 다중후원 안내: 캠페인/후원사업별 합계 > 전체 활동회원수(다중 후원 정상 현상)임을 명시. (3) 특정 과거월 as-of: 과거 특정월 활동 판정은 START_MONTH_KEY <= 월 AND (DSCNTC_MONTH_KEY IS NULL OR DSCNTC_MONTH_KEY > 월) 조건으로 직접 구성. (4) 회원 식별: 회원 식별은 항상 MEMBER_DK 기준.'
  AI_VERIFIED_QUERIES (
    vqr_active_by_sponsorship AS (
      QUESTION '후원사업별 지금 활동회원 수'
      VERIFIED_BY '(DW = O190)'
      SQL 'SELECT sponsorship.SPONSORSHIP, COUNT(DISTINCT IFF(fmsb.DSCNTC_MONTH_KEY IS NULL, fmsb.MEMBER_DK, NULL)) AS CURRENTLY_ACTIVE_MEMBERS FROM fmsb LEFT JOIN sponsorship ON fmsb.SPONSORSHIP_SK = sponsorship.SPONSORSHIP_SK GROUP BY sponsorship.SPONSORSHIP ORDER BY CURRENTLY_ACTIVE_MEMBERS DESC NULLS LAST'
    )
  );

-- SV_RELATION_ACTIVITY ← 05_12_SV_DDL_RELATION_ACTIVITY.sql
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_RELATION_ACTIVITY
  TABLES (
    fra AS GN_DW.GOLD.FACT_RELATION_ACTIVITY
      PRIMARY KEY (ACTIVITY_KEY)
      WITH SYNONYMS ('결연활동', '서신', '선물금', '결연 서신', '아동 선물금')
      COMMENT = '결연활동 팩트(서신·선물금). [Grain: 활동 1행]. [원천: CRM(eCRM) → BRONZE_CRM.TM_RM_RELATNSP_LETTER_INFO·TM_RM_RELATNSP_GFTMNEY_INFO → SILVER.CRM_RELATION_ACTIVITY → GOLD.FACT_RELATION_ACTIVITY].',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '활동일')
      COMMENT = '일 차원. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.',
    member AS GN_DW.GOLD.DIM_MEMBER
      PRIMARY KEY (MEMBER_DK)
      WITH SYNONYMS ('회원', '결연 후원자')
      COMMENT = '정규 회원 마스터 차원(회원 1명 = 1행). 결연키 → 결연 마스터로 찾은 후원 회원이다. [원천] 시스템=CRM(eCRM) · SILVER=CRM_MEMBER · GOLD=DIM_MEMBER.',
    rel AS GN_DW.GOLD.DIM_RELATIONSHIP
      PRIMARY KEY (RELATNSP_KEY)
      WITH SYNONYMS ('결연', '결연 마스터', '결연 상태')
      COMMENT = '결연 차원(결연당 한 행). 결연 중단 여부·중단(종료) 사유·결연 시작/중단일. [원천] CRM(eCRM) → SILVER.CRM_SPONSOR_RELATION → GOLD.DIM_RELATIONSHIP. 🔴 중단사유 라벨 코드군(MM002)은 커버리지로 특정 — 현업 확인 중.'
  )
  RELATIONSHIPS (
    fra_to_date   AS fra (DATE_SK)   REFERENCES date,
    fra_to_member AS fra (MEMBER_DK) REFERENCES member,
    fra_to_rel    AS fra (RELATNSP_KEY) REFERENCES rel
  )
  DIMENSIONS (
    date.ACTIVITY_DATE AS date.FULL_DATE WITH SYNONYMS ('활동일', '접수일', '일자', '날짜') COMMENT = '활동일 — 서신은 접수일 · 선물금은 원천에 접수일이 없어 발송일이다. ⚠️ 일자가 없거나 달력 범위 밖인 행은 Unknown(0)으로 라우팅되어 날짜 축 집계에서 빠진다',
    date.FULL_DATE AS date.FULL_DATE COMMENT = '달력 날짜(DIM_DATE.FULL_DATE) — ACTIVITY_DATE 와 같은 값이다(Analyst 가 추측하는 식별자를 실재화). 둘 중 하나만 쓴다.',
    date.YEAR  AS date.YEAR  WITH SYNONYMS ('연도', '년') COMMENT = '연도',
    date.MONTH AS date.MONTH WITH SYNONYMS ('월')        COMMENT = '월(1~12)',
    fra.ACTIVITY_TYPE AS fra.ACTIVITY_TYPE WITH SYNONYMS ('활동유형', '결연활동유형') COMMENT = '활동 유형 — **계열 분해의 정본 축**이다. 실제값 2종: ''서신''·''선물금''. 🔴 두 계열은 속성이 다르다(서신 계열 속성은 선물금 행에서 NULL · 선물금 계열 속성은 서신 행에서 NULL) ⇒ 계열 속성으로 분해할 때는 이 축을 동반한다',
    fra.LETTER_DIV_CD AS fra.LETTER_DIV_CD WITH SYNONYMS ('서신구분코드') COMMENT = '서신 구분 **원천 코드**(라벨 미배선 · 코드군 미확정). 실제값 3종: 1·5·9 + NULL. 🔴 라벨을 추측하지 말 것 — 현업에 코드 의미를 물어야 한다',
    fra.LETTER_STAT_CD AS fra.LETTER_STAT_CD WITH SYNONYMS ('편지상태코드', '서신상태코드') COMMENT = '편지 상태 **원천 코드**(서신 계열 · 라벨 미배선). 실제값 2종: 2·3 + NULL. 🔴 라벨 추측 금지 · 선물금 행은 NULL(구조적 부재)',
    fra.ONLINE_POST_WRITNG_YN AS fra.ONLINE_POST_WRITNG_YN WITH SYNONYMS ('온라인우편작성여부', '온라인 작성') COMMENT = '온라인 우편 작성 여부(서신 계열). 실제값 2종: ''0''·''1'' + NULL. ⚠️ 원천이 Y/N 이 아니라 0/1 이다 · 선물금 행은 NULL',
    fra.GFT_DIV_CD AS fra.GFT_DIV_CD WITH SYNONYMS ('선물구분코드') COMMENT = '선물 구분 **원천 코드**(선물금 계열 · 라벨 미배선). 실제값 7종: ''0''·''1''·''2''·''3''·''4''·''5''·''6'' + NULL. 🔴 라벨 추측 금지 · 서신 행은 NULL',
    fra.TRNSFER_YN AS fra.TRNSFER_YN WITH SYNONYMS ('이관여부') COMMENT = '이관 여부(선물금 계열). 실제값 3종: ''0''·''1''·''2'' + NULL. 🔴 여부 컬럼이지만 3값이다 — 2 의 뜻은 원천 미확정(창작 금지)',
    member.GENDER_NAME AS member.GENDER_NAME WITH SYNONYMS ('성별') COMMENT = '회원 성별 — 정본 공#130. 실제값 5종: ''남자''·''여자''·''기업''·''단체''·''기타''(CM017 라벨)',
    member.MEMBER_STATUS_NAME AS member.MEMBER_STATUS_NAME WITH SYNONYMS ('회원상태') COMMENT = '현재 회원상태 라벨(MM010 · 현재 마스터 스냅샷 · 활동 시점 값이 아니다). 실제값 13종: ''활동회원''·''신규미납1''·''신규미납2''·''신규미납3''·''신규미납4''·''신규미납5''·''장기미납1''·''장기미납2''·''장기미납3''·''장기미납4''·''장기미납5''·''후원중단''·''(해당없음)''',
    member.MEMBER_ENROLL_PATH_NAME AS member.ENROLL_PATH_NAME WITH SYNONYMS ('가입경로', '회원 가입경로') COMMENT = '회원 가입경로(MM014) — 회원 마스터 현재값. 일시회원은 (해당없음).',
    member.MEMBER_RELATNSP_DIV_NAME AS member.RELATNSP_DIV_NAME WITH SYNONYMS ('결연구분', '결연/비결연') COMMENT = '결연구분(MM019 · 결연회원·비결연회원·혼합회원·중단회원) — 회원 마스터 현재값. 일시회원은 NULL(원천 개념 없음).',
    member.MEMBER_SPECL_MNG_NAME AS member.SPECL_MNG_NAME WITH SYNONYMS ('특별관리', '회원 특별관리', '특별관리 구분') COMMENT = '회원 특별관리 구분(MM012 · 일반·더네이버스클럽·더네이버스아너스클럽·평생회원·홍보대사·이사회·블랙리스트·테스트회원 등) — 대부분 「일반」. 🔴 테스트회원 포함 여부를 답변에 밝힌다.',
    member.MEMBER_FIRST_SPONSORSHIP_NAME AS member.FIRST_SPONSORSHIP_NAME WITH SYNONYMS ('최초후원사업', '최초 후원사업') COMMENT = '회원의 최초 후원사업명(회원 마스터 · DIM_SPONSORSHIP 매칭 100%).',
    member.MEMBER_MOBLPHON_STAT_NAME AS member.MOBLPHON_STAT_NAME WITH SYNONYMS ('휴대폰상태', '휴대폰 상태', '연락처 상태') COMMENT = '휴대폰 상태(MM008 · 정상·결번·타인번호) — 회원 마스터 현재값.',
    member.MEMBER_EMAIL_STAT_NAME AS member.EMAIL_STAT_NAME WITH SYNONYMS ('이메일상태', '이메일 상태') COMMENT = '이메일 상태(MM009 · 정상·계정없음·도메인오류) — 원천 코드 0 은 사전에 없어 NULL.',
    member.MEMBER_TSTM_DIV_NAME AS member.TSTM_DIV_NAME WITH SYNONYMS ('TM/TS 거절', '전화 거절구분', 'TM 거절') COMMENT = 'TM/TS 거절구분(MS026 · TM 거절·TS 거절·TMTS거절). 🔴 원천 코드 0(대다수 회원)은 사전에 없어 NULL — 「거절 없음」으로 단정하지 않는다.',
    fra.SETLE_BANK_NAME AS fra.SETLE_BANK_NAME WITH SYNONYMS ('선물금 정산은행', '정산은행', '입금은행') COMMENT = '선물금 정산은행명(PM039 자동이체 은행코드 라벨 · 우리은행·국민은행·신한은행 등). 선물금 계열 전용 — 서신 행은 NULL(구조적 부재).',
    rel.REL_IS_DISCONTINUED AS rel.IS_DISCONTINUED WITH SYNONYMS ('결연 중단 여부', '결연중단', '중단된 결연') COMMENT = '결연 중단 여부 Y/N(원천 0/1 파생 · 현재값). 「중단된 결연의 서신·선물금」 질문에 쓴다.',
    rel.REL_DSCNTC_RSN_NAME AS rel.RELATNSP_DSCNTC_RSN_NAME WITH SYNONYMS ('결연 중단사유', '결연 종료사유', '아동교체 사유') COMMENT = '결연 중단(종료) 사유명(MM002 라벨 · 후원중단·18세종결교체·아동퇴소교체·개인사유(감액) 등 · 현재값). 🔴 코드군은 커버리지로 특정했다(현업 확인 중) — 답할 때 「사유 라벨은 확인 중」이라고 밝힌다. 진행 중 결연은 NULL.',
    rel.REL_DSCNTC_RSN_CD AS rel.RELATNSP_DSCNTC_RSN_CD WITH SYNONYMS ('결연 중단사유코드') COMMENT = '결연 중단 사유 원천 코드(MM002). 라벨 없는 코드를 구분할 때 쓴다.'
  )
  METRICS (
    fra.TOTAL_ACTIVITY_CNT AS SUM(fra.ACTIVITY_CNT)
      WITH SYNONYMS ('활동건수', '서신건수', '선물금건수', '결연활동(건)') COMMENT = '결연활동(건) 합계. F(가산). 서신·선물금을 나누려면 ACTIVITY_TYPE 으로 그룹핑한다.',
    fra.DISTINCT_ACTIVITY_MEMBERS AS COUNT(DISTINCT fra.MEMBER_DK)
      WITH SYNONYMS ('활동 회원수', '참여 회원수', '결연활동(명)') COMMENT = '결연활동 고유 회원수(명). D(distinct). 🔴 월·유형별 회원수를 더해 기간 회원수를 만들지 말 것(중복). ⚠️ 결연 마스터에 매칭되지 않은 고아 결연 행은 회원이 NULL 이라 세지 않는다',
    fra.TOTAL_GIFT_AMT AS SUM(fra.GFTMNEY)
      WITH SYNONYMS ('선물금', '선물금액', '선물금(원)') COMMENT = '선물금 합계(원). F(가산). 🔴 선물금 행만 값이 있다(서신 행은 NULL) · 미화금액(GFTMNEY_DOLLAR_AMT)은 문자열 원천이라 합산하지 않는다'
  )
  COMMENT = '결연활동 SV (base: GOLD.FACT_RELATION_ACTIVITY · grain = 서신/선물금 활동 1행). 결연 후원자의 서신 접수·선물금 전달 건수, 고유 회원수, 선물금(원). ⚠️ 서신과 선물금은 계열 속성이 다르므로 ACTIVITY_TYPE 동반. 코드 속성은 라벨 미배선(코드군 미확정)이다. 발송(서비스) 실적과는 별도 팩트이며 합산하지 않는다.'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 계열 동반: 서신·선물금 계열 속성(LETTER_*, GFT_DIV_CD, TRNSFER_YN)으로 분해할 때는 ACTIVITY_TYPE 을 함께 그룹핑한다. (2) 건수 vs 회원수: 건수는 SUM(fra.ACTIVITY_CNT), 회원수(명)는 COUNT(DISTINCT fra.MEMBER_DK) 로 집계하고 월별 회원수를 더하지 않는다. (3) 선물금(원)은 SUM(fra.GFTMNEY) — 선물금 행만 값이 있다. (4) 코드 라벨 미배선: 코드값을 그대로 보여주고 라벨을 추측하지 않는다. (5) 기간 미지정 시: 데이터 최신 연월 기준 직전 12개월로 한정하고 그 기간을 밝힌다. 「최근 N개월」 기준일은 비상관 CTE 1개(SELECT MAX(date.FULL_DATE) FROM fra JOIN date ON fra.DATE_SK = date.DATE_SK)로 구하고 CROSS JOIN 한다. (6) metric 이름(TOTAL_ACTIVITY_CNT 등)을 fra 컬럼처럼 참조하지 않는다. (7) 발송 실적(SV_SERVICE)과 한 쿼리로 조인·합산하지 않는다 — 필요하면 표를 분리한다. ORDER BY 에는 SELECT 별칭을 글자 그대로 쓴다.'
  AI_VERIFIED_QUERIES (
    vqr_o196_type_month AS (
      QUESTION '활동유형별 월별 결연활동 건수와 회원수, 선물금'
      VERIFIED_BY '(DW = O196-E)'
      SQL 'SELECT date.YEAR, date.MONTH, fra.ACTIVITY_TYPE, SUM(fra.ACTIVITY_CNT) AS TOTAL_ACTIVITY_CNT, COUNT(DISTINCT fra.MEMBER_DK) AS DISTINCT_ACTIVITY_MEMBERS, SUM(fra.GFTMNEY) AS TOTAL_GIFT_AMT FROM fra JOIN date ON fra.DATE_SK = date.DATE_SK GROUP BY date.YEAR, date.MONTH, fra.ACTIVITY_TYPE ORDER BY date.YEAR, date.MONTH, fra.ACTIVITY_TYPE'
    )
  );

-- SV_MEMBER_MONTHLY_KPI ← 05_14_SV_DDL_MEMBER_MONTHLY_KPI.sql
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_MONTHLY_KPI
  TABLES (
    kpi AS GN_DW.GOLD.WIDE_MEMBER_MONTHLY_KPI
      WITH SYNONYMS ('회원 활동율', '활동율 집계')
      COMMENT = '회원 월 지표 모집단 집계(grain = 월 × 신규기존). 🔴 행이 회원이 아니다 — 회원 속성으로 분해하지 않는다. 누계개발(건) = 당해년도 1월~조회월 개발(건) 합계(사용자 확정 2026-10-03).'
  )
  DIMENSIONS (
    kpi.MONTH_KEY AS kpi.MONTH_KEY WITH SYNONYMS ('연월', '조회연월') COMMENT = 'YYYYMM 정수 · 🔴 비율 지표는 한 달을 지정해 쓴다',
    kpi.CAL_YEAR  AS kpi.CAL_YEAR  WITH SYNONYMS ('연도', '년') COMMENT = '연도(YYYY)',
    kpi.NEW_EXISTING_FLAG AS kpi.NEW_EXISTING_FLAG WITH SYNONYMS ('신규기존구분', '신규/기존') COMMENT = '신규기존구분(공113) — 그 달 회원 행의 구분'
  )
  METRICS (
    kpi.DEV_CUM_AMT_CNT_SUM AS SUM(kpi.DEV_CUM_AMT_CNT)
      WITH SYNONYMS ('누계개발(건)', '누계개발건', '당해년 누계개발') COMMENT = '누계개발(건) = 당해년도 1월~조회월의 개발(건) 합계 · 개발(건) = **MSTR 정의**: 신규·재후원·증액 MSTR 인정금액 ÷ 10,000(활동(건)과 같은 단위). 🔴 한 달을 지정한다(누계라 여러 달을 더하지 않는다).',
    kpi.DEV_CUM_EVENT_CNT_SUM AS SUM(kpi.DEV_CUM_CNT)
      WITH SYNONYMS ('누계개발 회원월 경유') COMMENT = '참고 — 같은 MSTR 개발(건)을 회원 월 팩트(FMM) 경유로 누적한 값(이후 정의 동일 · 신규기존 판정 경로만 다르다). 🔴 활동율 계산에는 DEV_CUM_AMT_CNT_SUM 을 쓴다.',
    kpi.ACTIVE_RATE AS SUM(kpi.MONTH_END_ACTIVE_CNT) / NULLIF(SUM(kpi.YEAR_START_ACTIVE_CNT) + SUM(kpi.DEV_CUM_AMT_CNT), 0) * 100
      WITH SYNONYMS ('활동율', '공45', '전체회원 활동율') COMMENT = '공45 활동율(%) = 월말활동(건) ÷ (연도초활동(건) + 누계개발(건)) ×100. 비율(N). 🔴 한 달을 지정한다.',
    kpi.ACTIVE_RATE_NEW AS SUM(CASE WHEN kpi.NEW_EXISTING_FLAG = '신규' THEN kpi.DEV_CUM_AMT_CNT END)
        / NULLIF(SUM(CASE WHEN kpi.NEW_EXISTING_FLAG = '신규' THEN kpi.ACTIVE_CNT END), 0) * 100
      WITH SYNONYMS ('신규 활동율', '공46') COMMENT = '공46 신규 활동율(%) = 누계개발(건)[신규] ÷ 활동(건)[신규] ×100 — **지표 사전 원문 그대로**. 🟢 원래 계산식이 맞다(현업 확인) · 🔴 **100% 를 넘는 값이 정상이다**(현업 확인) — 100% 초과를 오류·이상치로 설명하지 않는다. 비율(N). 🔴 한 달을 지정한다.',
    kpi.ACTIVE_RATE_EXISTING AS SUM(CASE WHEN kpi.NEW_EXISTING_FLAG = '기존' THEN kpi.ACTIVE_CNT END)
        / NULLIF(SUM(CASE WHEN kpi.NEW_EXISTING_FLAG = '기존' THEN kpi.DEV_CUM_AMT_CNT + kpi.YEAR_START_ACTIVE_CNT END), 0) * 100
      WITH SYNONYMS ('기존 활동율', '공47') COMMENT = '공47 기존 활동율(%) = 활동(건)[기존] ÷ (누계개발(건)[기존] + 연도초활동(건)[기존]) ×100. 비율(N). 🔴 한 달을 지정한다.'
  )
  COMMENT = '회원 활동율(공45·46·47) SV (base: GOLD.WIDE_MEMBER_MONTHLY_KPI · grain = 월 × 신규기존). 누계개발(건) = 당해년도 1월~조회월 개발(건) 합계. 🔴 회원 월 실적 상세(회비·미납 등)는 SV_MEMBER_MONTHLY 소관이며 두 SV 수치를 한 표에서 합산하지 않는다.'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.';

-- SV_GA_BEHAVIOR ← 05_15_SV_DDL_GA_BEHAVIOR.sql
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_GA_BEHAVIOR
  TABLES (
    fbq AS GN_DW.GOLD.FACT_BIGQUERY_BEHAVIOR
      WITH SYNONYMS ('GA', 'GA4', '웹 행동', '앱 행동', '방문 행동', '홈페이지 행동')
      COMMENT = '웹·앱 사용자 행동 팩트(GA4). [Grain: 일 × 식별자 × 이벤트 × 트래픽소스 × 기기 × 페이지]. [원천: GA4 → BigQuery → 외부 Python 적재 → GN_DW.SILVER.BIGQUERY_REFINED_DATA → SILVER.BIGQUERY_EVENT 등 → GOLD.FACT_BIGQUERY_BEHAVIOR · BRONZE_BIGQUERY 는 비어 있다]. 🔴 CRM 회비·개발 실적과 원천이 다르다(GA4 ↔ CRM) — 한 표에 합산·비율 계산하지 않는다.',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '방문일')
      COMMENT = '일 차원. [원천] ETL 생성(달력).',
    evt AS GN_DW.GOLD.DIM_BIGQUERY_EVENT
      PRIMARY KEY (BIGQUERY_EVENT_SK)
      WITH SYNONYMS ('이벤트', 'GA 이벤트')
      COMMENT = 'GA4 이벤트 분류 차원(카테고리·액션·라벨). [원천] SILVER.BIGQUERY_REFINED_DATA → SILVER.BIGQUERY_EVENT_DIM.',
    src AS GN_DW.GOLD.DIM_BIGQUERY_SOURCE
      PRIMARY KEY (BIGQUERY_SOURCE_SK)
      WITH SYNONYMS ('유입경로', '트래픽소스', '유입채널')
      COMMENT = 'GA4 트래픽 소스 차원(채널그룹·소스/매체·UTM). [원천] SILVER.BIGQUERY_REFINED_DATA → SILVER.BIGQUERY_TRAFFIC_SOURCE.',
    dev AS GN_DW.GOLD.DIM_DEVICE
      PRIMARY KEY (DEVICE_SK)
      WITH SYNONYMS ('기기', '디바이스')
      COMMENT = '기기 차원. [원천] SILVER.BIGQUERY_REFINED_DATA → SILVER.BIGQUERY_DEVICE.'
  )
  RELATIONSHIPS (
    fbq_to_date AS fbq (DATE_SK)           REFERENCES date,
    fbq_to_evt  AS fbq (BIGQUERY_EVENT_SK) REFERENCES evt,
    fbq_to_src  AS fbq (BIGQUERY_SOURCE_SK) REFERENCES src,
    fbq_to_dev  AS fbq (DEVICE_SK)         REFERENCES dev
  )
  DIMENSIONS (
    date.VISIT_DATE AS date.FULL_DATE WITH SYNONYMS ('방문일', '일자', '날짜') COMMENT = '행동 발생일',
    date.YEAR  AS date.YEAR  WITH SYNONYMS ('연도', '년') COMMENT = '연도',
    date.MONTH AS date.MONTH WITH SYNONYMS ('월') COMMENT = '월(1~12)',
    date.WEEK_OF_YEAR AS date.WEEK_OF_YEAR WITH SYNONYMS ('주차') COMMENT = '연중 주차',
    evt.EVENT_CATEGORY AS evt.EVENT_CATEGORY WITH SYNONYMS ('이벤트 카테고리', '이벤트구분') COMMENT = 'GA4 이벤트 카테고리. 주요값 예: ''donor_action''·''나의후원''·''캠페인스크롤깊이''·''후원창''·''header''·''메뉴''·''캠페인버튼클릭''. 🔴 NULL = 페이지뷰 행(카테고리 없음)이며 결측이 아니다 — 페이지뷰는 TOTAL_PAGE_VIEWS 로 센다',
    evt.EVENT_ACTION AS evt.EVENT_ACTION WITH SYNONYMS ('이벤트 액션') COMMENT = 'GA4 이벤트 액션(자유 텍스트 · 카디널리티 큼) — 이름으로 물으면 ILIKE 부분일치로 필터한다',
    evt.EVENT_LABEL AS evt.EVENT_LABEL WITH SYNONYMS ('이벤트 라벨') COMMENT = 'GA4 이벤트 라벨(자유 텍스트 · 카디널리티 큼) — ILIKE 부분일치로 필터한다',
    src.DEFAULT_CHANNEL_GROUP AS src.DEFAULT_CHANNEL_GROUP WITH SYNONYMS ('채널그룹', '유입채널', 'GA 채널') COMMENT = 'GA4 기본 채널그룹. 실제값 16종 예: ''Unassigned''·''Display''·''Organic Social''·''Organic Search''·''Paid Search''·''Paid Other''·''Paid Video''·''Referral''·''Email''·''SMS''. ⚠️ ''Unassigned''가 행의 큰 비중을 차지한다(비율은 조회로 확인) — 채널 분포를 낼 때 함께 밝힌다',
    src.SOURCE_MEDIUM AS src.SOURCE_MEDIUM WITH SYNONYMS ('소스/매체', '소스매체') COMMENT = 'GA4 소스/매체(예: google / cpc)',
    src.UTM_SOURCE AS src.UTM_SOURCE WITH SYNONYMS ('UTM 소스') COMMENT = 'UTM source',
    src.UTM_MEDIUM AS src.UTM_MEDIUM WITH SYNONYMS ('UTM 매체') COMMENT = 'UTM medium',
    fbq.UTM_CAMPAIGN AS fbq.UTM_CAMPAIGN WITH SYNONYMS ('UTM 캠페인', 'GA 캠페인') COMMENT = 'UTM campaign(자유 텍스트). 🔴 CRM 캠페인 코드와 다른 체계다 — CRM 캠페인으로 바꿔 말하지 않는다',
    dev.DEVICE_TYPE AS dev.DEVICE_TYPE WITH SYNONYMS ('기기유형', '디바이스유형') COMMENT = '기기 유형(PC·모바일 등)',
    fbq.PAGE_PATH AS fbq.PAGE_PATH WITH SYNONYMS ('페이지', '페이지 경로', 'URL 경로') COMMENT = '페이지 경로(고유값이 매우 많은 자유 텍스트). 특정 페이지는 ILIKE 부분일치로 필터한다. 「유입/전환/중간 페이지」 같은 퍼널 단계 라벨은 원천에 없다 — 창작하지 않는다',
    src.UTM_CONTENT AS src.UTM_CONTENT WITH SYNONYMS ('UTM 콘텐츠', '광고 콘텐츠') COMMENT = '세션 수동 광고 콘텐츠(utm_content · #103).',
    src.UTM_TERM AS src.UTM_TERM WITH SYNONYMS ('UTM 검색어', '검색어') COMMENT = '세션 수동 검색어(utm_term · #104).'
  )
  METRICS (
    fbq.TOTAL_EVENT_CNT AS SUM(fbq.EVENT_CNT)
      WITH SYNONYMS ('이벤트수', '이벤트 건수', '클릭수')
      COMMENT = '이벤트 발생 건수 합계. F(가산) — 이벤트·채널·페이지 어느 축으로도 더할 수 있다.',
    fbq.TOTAL_PAGE_VIEWS AS SUM(fbq.VIEW_CNT)
      WITH SYNONYMS ('페이지뷰', '조회수', 'PV')
      COMMENT = '페이지뷰 합계. F(가산). 페이지뷰 행(EVENT_CATEGORY NULL)에만 값이 있다 — 다른 이벤트로 필터하면 0 이다.',
    fbq.IDENTIFIED_VISITORS AS COUNT(DISTINCT CASE WHEN fbq.IDENTITY_SK > 0 THEN fbq.IDENTITY_SK END)
      WITH SYNONYMS ('식별 방문자수', '로그인 방문자수', '회원 방문자수')
      COMMENT = '로그인 등으로 식별된 고유 방문자 수(명). D(distinct · 가산 금지). 🔴 비식별 방문자(전체 행의 일부 · 비중은 조회로 확인)는 빠진다 — 전체 방문자 수가 아니다. 식별자는 CRM 회원과 연결되지만 이 SV 에서 CRM 실적과 결합하지 않는다.',
    fbq.EVENT_SESSIONS AS SUM(fbq.SESSION_CNT)
      WITH SYNONYMS ('세션수(이벤트 기준)')
      COMMENT = '🔴🔴 이벤트 단위 세션 수 — 같은 세션이 이벤트마다 반복 집계된다(실측 키 중복 다수 · 규모는 파일 머리 주석). **EVENT_CATEGORY 를 하나로 고정했을 때만** 쓴다. 여러 이벤트를 합친 「총 세션」·「총 방문」으로 답하지 않는다.',
    fbq.AVG_ENGAGEMENT_RATE AS AVG(fbq.ENGAGEMENT_RATE)
      WITH SYNONYMS ('참여율')
      COMMENT = '행 단위 참여율의 단순 평균(가중치 없음 · 참고치). 비율(N) — 재합산 금지.'
  )
  COMMENT = 'GA4 웹·앱 행동 SV. 이벤트·페이지뷰·식별 방문자·채널 분석용. [원천: GA4 → GN_DW.SILVER.BIGQUERY_REFINED_DATA(외부 Python 적재) → GOLD.FACT_BIGQUERY_BEHAVIOR]. 🔴 개인 단위 예측(방문자 전환 예측·재방문 예측)·퍼널 단계 라벨·신규 사용자(first_visit) 구분은 없다 — 집계만 제공한다. 🔴 GA 원천은 추가되지 않는다 ⇒ 그런 질문에는 문구를 그대로 「현재 GA 데이터로는 답변할 수 없습니다. 자세한 내용은 IT부서에 문의 바랍니다.」 로 안내하고, 추가 적재·추후 제공·약속 관련 표현을 덧붙이지 않는다.'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 건수는 TOTAL_EVENT_CNT(가산), 페이지 조회는 TOTAL_PAGE_VIEWS, 사람 수는 IDENTIFIED_VISITORS(식별자만 · distinct). (2) EVENT_SESSIONS 는 EVENT_CATEGORY 를 하나로 고정할 때만 쓰고, 여러 이벤트의 세션을 더해 총 세션으로 답하지 않는다. (3) 기간 미지정 시 데이터 최신월 기준 직전 3개월로 한정한다. 기준 시점은 비상관 CTE 1개(SELECT MAX(date.FULL_DATE) FROM fbq JOIN date ON fbq.DATE_SK = date.DATE_SK)로 구하고 CROSS JOIN 한다. (4) 채널 분포에는 Unassigned 를 함께 보여준다. (5) PAGE_PATH·EVENT_ACTION·EVENT_LABEL·UTM_CAMPAIGN 은 자유 텍스트이므로 ILIKE 부분일치로 필터한다. (6) CRM 실적(개발·회비)과 교차 계산하지 않는다. (7) ORDER BY 에는 SELECT 별칭을 그대로 쓴다.'
  AI_VERIFIED_QUERIES (
    vqr_o203_channel_3m AS (
      QUESTION '최근 3개월 GA 채널그룹별 이벤트수와 식별 방문자수'
      VERIFIED_BY '(DW = O203)'
      SQL 'WITH mx AS (SELECT MAX(date.FULL_DATE) AS md FROM fbq JOIN date ON fbq.DATE_SK = date.DATE_SK) SELECT src.DEFAULT_CHANNEL_GROUP, SUM(fbq.EVENT_CNT) AS TOTAL_EVENT_CNT, COUNT(DISTINCT CASE WHEN fbq.IDENTITY_SK > 0 THEN fbq.IDENTITY_SK END) AS IDENTIFIED_VISITORS FROM fbq JOIN date ON fbq.DATE_SK = date.DATE_SK JOIN src ON fbq.BIGQUERY_SOURCE_SK = src.BIGQUERY_SOURCE_SK CROSS JOIN mx WHERE date.FULL_DATE > DATEADD(MONTH, -3, mx.md) GROUP BY src.DEFAULT_CHANNEL_GROUP ORDER BY TOTAL_EVENT_CNT DESC'
    ),
    vqr_o203_donation_window AS (
      QUESTION '후원창 이벤트가 많이 발생한 페이지 상위 10개'
      VERIFIED_BY '(DW = O203)'
      SQL 'SELECT fbq.PAGE_PATH, SUM(fbq.EVENT_CNT) AS TOTAL_EVENT_CNT, COUNT(DISTINCT CASE WHEN fbq.IDENTITY_SK > 0 THEN fbq.IDENTITY_SK END) AS IDENTIFIED_VISITORS FROM fbq JOIN evt ON fbq.BIGQUERY_EVENT_SK = evt.BIGQUERY_EVENT_SK WHERE evt.EVENT_CATEGORY = ''후원창'' GROUP BY fbq.PAGE_PATH ORDER BY TOTAL_EVENT_CNT DESC LIMIT 10'
    )
  );

-- SV_BUDGET_YEARLY ← 05_16_SV_DDL_BUDGET_YEARLY.sql
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_BUDGET_YEARLY
  TABLES (
    fby AS GN_DW.GOLD.FACT_BUDGET_YEARLY
      WITH SYNONYMS ('연 예산', '연간 예산', '연 편성예산')
      COMMENT = '연 예산 편성·집행 팩트(base: GOLD.FACT_BUDGET_YEARLY). [Grain: 연 × 부서 × 예산과목 × 예산절차]. 🟢 2024 연 편성예산은 이 SV 에만 있다(월 예산 SV 의 2024 월 편성은 0). [원천: ERP → GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER → SILVER.ERP_BUDGET_YEARLY → GOLD.FACT_BUDGET_YEARLY].',
    item AS GN_DW.GOLD.DIM_BUDGET_ITEM
      PRIMARY KEY (BUDGET_ITEM_SK)
      WITH SYNONYMS ('세세목', '예산항목')
      COMMENT = '예산 세세목 차원. [원천] ERP · BRONZE_ERP.BDGT_ACMSLT_LEDGER — DISTINCT 마스터.'
  )
  RELATIONSHIPS (
    fby_to_item AS fby (BUDGET_ITEM_SK) REFERENCES item
  )
  DIMENSIONS (
    fby.BUDGET_YEAR AS fby.BUDGET_YEAR WITH SYNONYMS ('예산연도', '연도', '년') COMMENT = '예산 연도. 실제값 3종: 2024·2025·2026',
    fby.BUDGET_PROCEDURE AS fby.BUDGET_PROCEDURE WITH SYNONYMS ('예산절차', '예산 단계') COMMENT = '예산 절차. 실제값: 2024·2025 = ''추가경정'' · 2026 = ''연사업''. 🔴 연도마다 절차가 다르다 — 연도 비교 시 함께 밝힌다',
    item.BUDGET_ITEM_NAME AS item.BUDGET_ITEM_NAME WITH SYNONYMS ('세세목명', '예산항목명') COMMENT = '예산 세세목명',
    item.BDGT_UNIT_NM AS item.BDGT_UNIT_NM WITH SYNONYMS ('예산단위', '예산 팀', '예산 부서', '예산단위명') COMMENT = '예산단위명(ERP 표기 그대로)',
    item.ITEM_JANG_NM AS item.JANG_NM WITH SYNONYMS ('장', '예산 장') COMMENT = '예산 과목 계층 최상위 「장」(원값 = 모금비·사업비·사회복지법인예산·일반관리비 · ERP 원장). 장 > 관 > 항 > 목 > 세목 > 세세목 순으로 좁아진다.',
    item.ITEM_KWAN_NM AS item.KWAN_NM WITH SYNONYMS ('관', '예산 관') COMMENT = '예산 과목 계층 「관」(원값 = 국내사업비·나눔문화연구사업·모금비·사회복지법인예산·일반관리비·해외사업비).',
    item.ITEM_HANG_NM AS item.HANG_NM WITH SYNONYMS ('항', '예산 항') COMMENT = '예산 과목 계층 「항」(원값 = 국내아동권리지원사업·기획및연수인력사업·나눔문화연구사업·모금관리비·사무국운영사업·사회복지법인예산·해외기획사업·해외아동권리지원및지역개발사업·회원관리비).',
    item.ITEM_FUND_SOURCE_NM AS item.FUND_SOURCE_NM WITH SYNONYMS ('재원', '예산 재원') COMMENT = '예산 재원명(원값 = 국내지정·법인전입·비지정일반·사회복지법인예산·이월국내지정·이월비지정일반·이자수익·잡수익 · ERP 원장).'
  )
  METRICS (
    fby.TOTAL_PLAN_BUDGET_YEAR AS SUM(fby.PLAN_BUDGET_YEAR)
      WITH SYNONYMS ('연 편성예산', '연간 편성예산', '연 예산') COMMENT = '연 편성예산 합계(원). F(가산 · 연도 간 합산은 의미 없음 — 연도를 고정한다).',
    fby.TOTAL_EXEC_BUDGET_YEAR AS SUM(fby.EXEC_BUDGET_YEAR)
      WITH SYNONYMS ('연 집행예산', '연간 집행액') COMMENT = '연 집행예산 합계(원). 🔴 진행 중 연도(2026)는 적재된 월까지의 누계다 — 연말 확정값이 아니다.',
    fby.EXEC_RATE_YEAR AS SUM(fby.EXEC_BUDGET_YEAR) / NULLIF(SUM(fby.PLAN_BUDGET_YEAR), 0) * 100
      WITH SYNONYMS ('연 집행율', '연간 집행율') COMMENT = '연 집행율(%) = 연 집행 ÷ 연 편성 ×100. 비율(N · 재합산 금지). 🔴 진행 중 연도는 연간 편성 대비 누계라 구조적으로 낮다 — 그 사실을 밝힌다.'
  )
  COMMENT = '연 예산 SV. 「2024 연 편성예산」·「연도별 편성 대비 집행」 질문용. 월별 편성·집행·세세목 추이는 SV_BUDGET(월 grain)이다. 🔴 두 SV 의 수치를 한 표에 합산하지 않는다.'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 연 편성=TOTAL_PLAN_BUDGET_YEAR, 연 집행=TOTAL_EXEC_BUDGET_YEAR, 연 집행율=EXEC_RATE_YEAR(%). (2) 연도(BUDGET_YEAR)를 반드시 GROUP BY 하거나 고정한다 — 여러 연도를 하나로 합산하지 않는다. (3) 결과에 예산절차(BUDGET_PROCEDURE)를 함께 보여준다. (4) 2026 은 진행 중 연도이므로 집행·집행율이 부분 연도임을 밝힌다. (5) ORDER BY 에는 SELECT 별칭을 그대로 쓴다.'
  AI_VERIFIED_QUERIES (
    vqr_o203_yearly_plan_exec AS (
      QUESTION '연도별 편성예산과 집행예산, 집행율'
      VERIFIED_BY '(DW = O203 · 2024 편성 20,494,617,159원)'
      SQL 'SELECT fby.BUDGET_YEAR, fby.BUDGET_PROCEDURE, SUM(fby.PLAN_BUDGET_YEAR) AS TOTAL_PLAN_BUDGET_YEAR, SUM(fby.EXEC_BUDGET_YEAR) AS TOTAL_EXEC_BUDGET_YEAR, SUM(fby.EXEC_BUDGET_YEAR) / NULLIF(SUM(fby.PLAN_BUDGET_YEAR), 0) * 100 AS EXEC_RATE_YEAR FROM fby GROUP BY fby.BUDGET_YEAR, fby.BUDGET_PROCEDURE ORDER BY fby.BUDGET_YEAR'
    )
  );

-- SV_MEMBER_STATUS_ASOF ← 05_17_SV_DDL_MEMBER_STATUS_ASOF.sql
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_STATUS_ASOF
  TABLES (
    msh AS GN_DW.GOLD.DIM_MEMBER_STATUS_HISTORY
      PRIMARY KEY (MEMBER_SK)
      WITH SYNONYMS ('회원상태 이력', '과거 회원상태', '상태 이력')
      COMMENT = '회원 상태 이력(SCD2 · 1행 = 회원 × 상태 유효구간). 「특정 과거 시점의 회원상태 분포」 질문용. [원천: CRM(eCRM) → BRONZE_CRM.TM_MM_FDRM_MBER_INFO·TH_MM_FDRM_MBER_STNG_DTLS → SILVER.CRM_MEMBER_STATUS_HIST → GOLD.DIM_MEMBER_STATUS_HISTORY]. 🔴 반드시 기준일 하나로 as-of 조건을 건다 — 조건 없이 세면 같은 회원의 여러 상태 버전이 모두 세어진다.'
  )
  DIMENSIONS (
    msh.EFFECTIVE_FROM AS msh.EFFECTIVE_FROM WITH SYNONYMS ('상태 시작일', '유효 시작일') COMMENT = '이 상태가 시작된 날. as-of 조건 = EFFECTIVE_FROM <= 기준일',
    msh.EFFECTIVE_TO AS msh.EFFECTIVE_TO WITH SYNONYMS ('상태 종료일', '유효 종료일') COMMENT = '이 상태가 끝난 날(다음 상태 시작일과 같은 날 · NULL = 현재 상태). 🔴 as-of 조건 = (EFFECTIVE_TO > 기준일 OR EFFECTIVE_TO IS NULL) — 「>=」 를 쓰면 경계일에 회원이 중복된다',
    msh.IS_CURRENT AS msh.IS_CURRENT WITH SYNONYMS ('현재 상태 여부') COMMENT = '현재 유효 행 여부(회원당 TRUE 단일 행). 「지금」 질문은 이것으로 거른다',
    msh.MEMBER_STATUS_NAME AS msh.MEMBER_STATUS_NAME WITH SYNONYMS ('회원상태', '상태') COMMENT = '회원상태 라벨(MM010). 실제값 13종: ''활동회원''·''후원중단''·''신규미납1~5''·''장기미납1~5''·''(해당없음)''(일시회원). 🔴 이 라벨의 「활동회원」은 월실적 KPI 활동회원(월말 활동 약정 보유)과 정의가 다르다 — 두 수치를 비교·대체하지 않는다',
    msh.MEMBER_STATUS_GROUP AS msh.MEMBER_STATUS_GROUP WITH SYNONYMS ('회원상태 그룹', '상태 그룹') COMMENT = '회원상태 상위 그룹',
    msh.PREV_MEMBER_STATUS_NAME AS msh.PREV_MEMBER_STATUS_NAME WITH SYNONYMS ('직전 회원상태', '이전 상태') COMMENT = '이 상태 직전의 회원상태 라벨(상태 전환 분석용)',
    msh.MEMBER_TYPE_NAME AS msh.MEMBER_TYPE_NAME WITH SYNONYMS ('회원구분') COMMENT = '회원구분 라벨(개인·기업·단체)',
    msh.GENDER_NAME AS msh.GENDER_NAME WITH SYNONYMS ('성별') COMMENT = '성별 라벨',
    msh.FIRST_JOIN_DATE AS msh.FIRST_JOIN_DATE WITH SYNONYMS ('최초가입일', '가입일') COMMENT = '회원 최초가입일',
    msh.FIRST_JOIN_YEAR AS YEAR(msh.FIRST_JOIN_DATE) WITH SYNONYMS ('가입연도') COMMENT = '회원 최초가입 연도',
    msh.ENROLL_PATH_NAME AS msh.ENROLL_PATH_NAME WITH SYNONYMS ('가입경로', '회원 가입경로') COMMENT = '회원 가입경로(MM014) — 상태이력 기준. 일시회원은 (해당없음).'
  )
  METRICS (
    msh.MEMBER_COUNT AS COUNT(DISTINCT msh.MEMBER_DK)
      WITH SYNONYMS ('회원수', '회원 수', '명')
      COMMENT = '고유 회원수(명). D(distinct). 🔴 as-of 조건(기준일 1개)을 건 상태에서만 의미가 있다.'
  )
  COMMENT = '과거 시점 회원상태 SV. 「2025년 6월 말 기준 회원상태별 회원수」처럼 기준일을 정한 질문에 쓴다. 월별 활동회원 KPI·회비·개발 실적은 다른 SV 소관이며 한 표에 합산하지 않는다.'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 반드시 기준일 하나를 정해 WHERE msh.EFFECTIVE_FROM <= 기준일 AND (msh.EFFECTIVE_TO > 기준일 OR msh.EFFECTIVE_TO IS NULL) 를 건다. 「○월 말」은 그 달 말일을 기준일로 쓴다. (2) 「지금·현재」는 msh.IS_CURRENT = TRUE 로 거른다. (3) 회원수는 COUNT(DISTINCT msh.MEMBER_DK) 만 쓴다. (4) 여러 기준일을 비교하면 기준일별로 따로 집계해 나란히 보여주고 더하지 않는다. (5) ORDER BY 에는 SELECT 별칭을 그대로 쓴다.'
  AI_VERIFIED_QUERIES (
    vqr_o203_status_asof AS (
      QUESTION '2026년 6월 말 기준 회원상태별 회원수'
      VERIFIED_BY '(DW = O203 · 활동회원 681,134 · 후원중단 854,378)'
      SQL 'SELECT msh.MEMBER_STATUS_NAME, COUNT(DISTINCT msh.MEMBER_DK) AS MEMBER_COUNT FROM msh WHERE msh.EFFECTIVE_FROM <= ''2026-06-30'' AND (msh.EFFECTIVE_TO > ''2026-06-30'' OR msh.EFFECTIVE_TO IS NULL) GROUP BY msh.MEMBER_STATUS_NAME ORDER BY MEMBER_COUNT DESC'
    )
  );

-- SV_MEMBER_SERVICE_COHORT ← 05_18_SV_DDL_MEMBER_SERVICE_COHORT.sql
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SERVICE_COHORT
  TABLES (
    svc AS GN_DW.GOLD.WIDE_MEMBER_SERVICE_COHORT
      WITH SYNONYMS ('서비스 수신 코호트', '알림톡 수신 회원', '서비스 수신 회원', '수신 미수신 비교')
      COMMENT = '서비스 수신 코호트(grain = 회원 × 서비스그룹 × 수신연도 · 미수신은 연도 NULL 단일 행). 발송·획득 코호트·중단·행사참여를 회원 단위로 미리 결합했다. [원천: CRM(eCRM·UMS) → BRONZE_CRM(TM_MS_MSG_AT_SNDNG · TC_CMMN_DTL_CD 서비스코드 MS049 · TM_MS_AT_TMPLAT_MNG 템플릿) → GOLD.FACT_MESSAGE_DISPATCH·DIM_SEND_REQUEST·DIM_MEMBER_ACQUISITION·FACT_MEMBER_EVENT·FACT_EVENT_ATTENDANCE → GOLD.WIDE_MEMBER_SERVICE_COHORT]. 🟢 서비스그룹 = 서비스코드(원천 서비스 카테고리) 우선 · 카테고리가 없으면 발송 제목 매핑.'
  )
  DIMENSIONS (
    svc.SERVICE_GROUP_CD AS svc.SERVICE_GROUP_CD WITH SYNONYMS ('서비스그룹코드') COMMENT = '서비스그룹 코드. 실제값 4종: ''SNG_INSTANT''(선넘는좋은일 신규 즉시 · 개별화서비스신규(사단)의 선넘는좋은일 즉시 알림톡)·''PERSONAL_NEW_SADAN''(개별화 신규 사단)·''LUCKY_CARD''(행운의 카드)·''LONGTERM_THANKS''(장기회원 서비스). 🔴 반드시 하나로 고정한다',
    svc.SERVICE_GROUP_NAME AS svc.SERVICE_GROUP_NAME WITH SYNONYMS ('서비스그룹', '서비스명', '알림톡 서비스') COMMENT = '서비스그룹 이름. 실제값 4종: ''선넘는좋은일 신규 즉시''·''개별화 신규(사단)''·''행운의 카드''·''장기회원 서비스''',
    svc.MATCH_BASIS AS svc.MATCH_BASIS WITH SYNONYMS ('매핑근거', '판정근거') COMMENT = '그 수신 행이 서비스그룹에 든 근거. 실제값 3종: ''서비스코드''(원천 서비스 카테고리 · 발송코드 MS049 상위코드) · ''발송제목''(카테고리가 없어 제목으로 매핑) · ''서비스코드+발송제목''. 미수신 행은 NULL',
    svc.SVC_CATEGORY_NAMES AS svc.SVC_CATEGORY_NAMES WITH SYNONYMS ('원천 서비스분류', '서비스 카테고리') COMMENT = '그 연도 수신 발송의 원천 서비스 카테고리명(발송코드 MS049 상위코드명 · 여러 개면 · 로 이음). 발송제목으로만 매핑된 행은 NULL',
    svc.CHRG_DEPT_NAMES AS svc.CHRG_DEPT_NAMES WITH SYNONYMS ('담당부서', '발송 담당부서', '서비스 실적부서') COMMENT = '그 연도 수신 발송의 알림톡·메일 템플릿 담당부서명(여러 개면 · 로 이음). 🔴 처리자→부서 마스터는 원천에 없어 템플릿 담당부서로 대신한다 — 템플릿이 없는 발송은 NULL',
    svc.RECEIVED_SADAN_FLAG AS svc.RECEIVED_SADAN_FLAG WITH SYNONYMS ('사단 수신', '사단법인 발송 수신') COMMENT = '그 연도 사단 법인 발송을 1회 이상 받았는가. 법인 = 서비스코드명의 (사단)/(사복)/(통합) → 없으면 템플릿 법인구분(CM019)',
    svc.RECEIVED_SABOK_FLAG AS svc.RECEIVED_SABOK_FLAG WITH SYNONYMS ('사복 수신', '사회복지법인 발송 수신') COMMENT = '그 연도 사복 법인 발송 수신 여부(판정 규칙은 사단과 같다)',
    svc.RECEIVED_TONGHAP_FLAG AS svc.RECEIVED_TONGHAP_FLAG WITH SYNONYMS ('통합 수신', '통합 법인 발송 수신') COMMENT = '그 연도 통합 법인 발송 수신 여부(판정 규칙은 사단과 같다)',
    svc.RECEIVE_YEAR AS svc.RECEIVE_YEAR WITH SYNONYMS ('수신연도', '발송연도') COMMENT = '수신연도. 미수신 행은 NULL',
    svc.RECEIVED_FLAG AS svc.RECEIVED_FLAG WITH SYNONYMS ('수신여부', '수신 여부', '받은 회원') COMMENT = 'TRUE = 그 그룹 수신 · FALSE = 획득 코호트 회원 중 미수신',
    svc.FIRST_RECEIVE_DATE AS svc.FIRST_RECEIVE_DATE WITH SYNONYMS ('첫 수신일', '수신일') COMMENT = '그 연도 첫 수신일',
    svc.D5_STOP_FLAG AS svc.D5_STOP_FLAG WITH SYNONYMS ('5일 내 중단', '발송 후 5일 이내 중단') COMMENT = '발송 다음날~+5일(D+1~D+5) 중단 매칭 여부. 🔴 인과가 아니라 시간창 매칭',
    svc.D5_INCREASE_FLAG AS svc.D5_INCREASE_FLAG WITH SYNONYMS ('5일 내 증액') COMMENT = 'D+1~D+5 증액 매칭 여부. 🔴 시간창 매칭',
    svc.D5_STOP_REASON AS svc.D5_STOP_REASON WITH SYNONYMS ('중단사유') COMMENT = 'D+1~D+5 첫 중단 사건의 중단사유',
    svc.D5_STOP_CHANNEL AS svc.D5_STOP_CHANNEL WITH SYNONYMS ('중단경로') COMMENT = 'D+1~D+5 첫 중단 사건의 중단경로',
    svc.D5_STOP_SPONSORSHIP AS svc.D5_STOP_SPONSORSHIP WITH SYNONYMS ('중단 후원사업', '후원사업') COMMENT = 'D+1~D+5 첫 중단 사건이 끊은 후원사업',
    svc.ACQ_DATE AS svc.ACQ_DATE WITH SYNONYMS ('가입일', '획득일') COMMENT = '획득(가입) 일자 — 「○월부터 ○월까지 가입한 회원」은 이 축으로 거른다',
    svc.ACQ_YEAR AS svc.ACQ_YEAR WITH SYNONYMS ('가입연도') COMMENT = '획득 연도',
    svc.ACQ_MONTH_KEY AS svc.ACQ_MONTH_KEY WITH SYNONYMS ('가입연월', '가입월') COMMENT = '획득 연월(YYYYMM 정수) — 대조군 후보 「같은 가입월 미수신 회원」을 만들 때 고정한다',
    svc.ACQ_CAMPAIGN_NAME AS svc.ACQ_CAMPAIGN_NAME WITH SYNONYMS ('가입캠페인', '캠페인명') COMMENT = '획득 캠페인명',
    svc.ACQ_PARENT_CAMPAIGN_NAME AS svc.ACQ_PARENT_CAMPAIGN_NAME WITH SYNONYMS ('상위캠페인', '가입 상위캠페인') COMMENT = '획득 상위캠페인명. 🔴 「선넘는좋은일 캠페인으로 가입」은 ILIKE ''%선넘는좋은일%'' 로 이 축을 거른다(캠페인명에는 없다)',
    svc.ACQ_CAMPAIGN_TYPE AS svc.ACQ_CAMPAIGN_TYPE WITH SYNONYMS ('캠페인카테고리', '주요캠페인') COMMENT = '획득 캠페인카테고리',
    svc.ACQ_INFLOW_PATH AS svc.ACQ_INFLOW_PATH WITH SYNONYMS ('개발인입경로', '인입경로') COMMENT = '획득 개발인입경로',
    svc.ACQ_CPR_DIV_NM AS svc.ACQ_CPR_DIV_NM WITH SYNONYMS ('가입 법인구분', '획득 법인구분') COMMENT = '획득 세부캠페인 법인구분(통합/사단/사복). 🔴 발송(서비스) 법인이 아니다 — 서비스 법인은 RECEIVED_SADAN_FLAG·RECEIVED_SABOK_FLAG·RECEIVED_TONGHAP_FLAG',
    svc.ACQ_SPONSORSHIP_NAME AS svc.ACQ_SPONSORSHIP_NAME WITH SYNONYMS ('가입 후원사업', '획득 후원사업') COMMENT = '획득 후원사업',
    svc.ACQ_AGE_BAND AS svc.ACQ_AGE_BAND WITH SYNONYMS ('연령대') COMMENT = '획득 시점 연령대 — 현재 나이가 아니다',
    svc.ACQ_REGION AS svc.ACQ_REGION WITH SYNONYMS ('지역') COMMENT = '획득 시점 지역 — 현재 거주지가 아니다',
    svc.ACQ_GENDER AS svc.ACQ_GENDER WITH SYNONYMS ('성별') COMMENT = '획득 시점 성별',
    svc.EVER_STOPPED_FLAG AS svc.EVER_STOPPED_FLAG WITH SYNONYMS ('중단 이력') COMMENT = '최초 중단 이력 여부'
  )
  METRICS (
    svc.MEMBER_COUNT AS COUNT(DISTINCT svc.MEMBER_DK)
      WITH SYNONYMS ('회원수', '명')
      COMMENT = '고유 회원수(명). 🔴 서비스그룹 하나로 고정한 상태에서 쓴다.',
    svc.GENERAL_EVENT_PART_MEMBERS AS COUNT(DISTINCT IFF(svc.GENERAL_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL))
      WITH SYNONYMS ('일반행사 참여 회원수', '이벤트 전체 참여 회원수')
      COMMENT = '일반행사(EVENT 원천 · 온라인·앱전용·회지·리플렛·오프라인 전 구분) 참여 기록이 있는 고유 회원수.',
    svc.GENERAL_EVENT_PART_RATE AS DIV0(COUNT(DISTINCT IFF(svc.GENERAL_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL)), COUNT(DISTINCT svc.MEMBER_DK)) * 100
      WITH SYNONYMS ('일반행사 참여율', '이벤트 전체 참여율')
      COMMENT = '일반행사 참여율(%) = 참여 회원 ÷ 회원. N(비가산).',
    svc.CAMPAIGN_EVENT_PART_MEMBERS AS COUNT(DISTINCT IFF(svc.CAMPAIGN_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL))
      WITH SYNONYMS ('캠페인행사 참여 회원수')
      COMMENT = '캠페인행사(CRMN 원천 · 전 행사구분) 참여 기록이 있는 고유 회원수.',
    svc.CAMPAIGN_EVENT_PART_RATE AS DIV0(COUNT(DISTINCT IFF(svc.CAMPAIGN_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL)), COUNT(DISTINCT svc.MEMBER_DK)) * 100
      WITH SYNONYMS ('캠페인행사 참여율')
      COMMENT = '캠페인행사 참여율(%). N(비가산).',
    svc.CULTURE_EVENT_PART_MEMBERS AS COUNT(DISTINCT IFF(svc.CULTURE_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL))
      WITH SYNONYMS ('문화이벤트 참여 회원수', '문화서비스 참여 회원수')
      COMMENT = '캠페인행사 중 원천 행사구분(MS002)이 문화서비스·문화서비스_전시·서적·공연인 행사 참여 고유 회원수. 🔴 「문화이벤트」라는 이름의 원천 코드는 없다 — 유사 값(문화서비스 계열)으로 매핑했음을 답변에 밝힌다.',
    svc.CULTURE_EVENT_PART_RATE AS DIV0(COUNT(DISTINCT IFF(svc.CULTURE_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL)), COUNT(DISTINCT svc.MEMBER_DK)) * 100
      WITH SYNONYMS ('문화이벤트 참여율', '문화서비스 참여율')
      COMMENT = '문화서비스 계열 캠페인행사 참여율(%). N(비가산).',
    svc.ONLINE_EVENT_PART_MEMBERS AS COUNT(DISTINCT IFF(svc.ONLINE_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL))
      WITH SYNONYMS ('온라인 이벤트 참여 회원수')
      COMMENT = '일반행사 중 원천 이벤트구분(MS286)이 온라인(100)인 이벤트 참여 고유 회원수. 🔴 「온라인 이벤트」 = 원천 구분 「온라인」으로 매핑했다(앱전용·회지·리플렛·오프라인은 제외).',
    svc.ONLINE_EVENT_PART_RATE AS DIV0(COUNT(DISTINCT IFF(svc.ONLINE_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL)), COUNT(DISTINCT svc.MEMBER_DK)) * 100
      WITH SYNONYMS ('온라인 이벤트 참여율')
      COMMENT = '온라인 구분 일반행사 참여율(%). N(비가산).',
    svc.AVG_GENERAL_EVENT_PART_ROWS AS AVG(svc.GENERAL_EVENT_PART_ROWS)
      WITH SYNONYMS ('평균 이벤트 참여횟수', '1인당 참여횟수')
      COMMENT = '행당 평균 일반행사 참여 기록 수. 🔴 수신연도를 고정한 상태에서 쓴다(연도별 행 중복).',
    svc.AVG_GENERAL_EVENT_PART_ROWS_AFTER AS AVG(svc.GENERAL_EVENT_PART_ROWS_AFTER)
      WITH SYNONYMS ('수신 후 평균 참여횟수')
      COMMENT = '첫 수신일 이후 평균 일반행사 참여 기록 수(수신 행만 · 미수신은 NULL 이라 제외된다).',
    svc.D5_STOP_MEMBERS AS COUNT(DISTINCT IFF(svc.D5_STOP_FLAG, svc.MEMBER_DK, NULL))
      WITH SYNONYMS ('5일 내 중단 회원수')
      COMMENT = 'D+1~D+5 중단 매칭 고유 회원수(시간창 매칭 · 인과 아님).',
    svc.AVG_TENURE_DAYS AS AVG(svc.TENURE_DAYS)
      WITH SYNONYMS ('이탈 회원 평균 유지기간', '중단 회원 평균 유지일수')
      COMMENT = '🔴 **이탈(최초 중단)한 회원만**의 평균 유지기간(일) = 최초 중단일 − 획득일(SV_MEMBER_COHORT 와 같은 정의). 미중단 회원은 NULL 이라 빠진다 ⇒ 「수신회원 평균 후원유지기간」으로 쓰지 않는다 — 그 질문은 AVG_SPONSOR_DAYS_TO_DATE 를 쓴다. 🔴 수신연도를 고정한 상태에서 쓴다.',
    svc.AVG_SPONSOR_DAYS_TO_DATE AS AVG(COALESCE(svc.TENURE_DAYS, DATEDIFF('day', svc.ACQ_DATE, CURRENT_DATE())))
      WITH SYNONYMS ('평균 후원유지기간', '평균 유지기간(일)', '평균 후원기간')
      COMMENT = '수신회원 평균 후원유지기간(일) — 중단 회원은 획득일 → 최초 중단일, 미중단 회원은 획득일 → 오늘. 「후원유지기간」 질문의 기본 지표다. ⚠️ 미중단 회원은 아직 진행 중인 기간이라 관측 시점에 따라 값이 늘어난다(조회일을 밝힌다). 🔴 수신연도를 고정한 상태에서 쓴다.',
    svc.EVER_STOPPED_RATE AS DIV0(COUNT(DISTINCT IFF(svc.EVER_STOPPED_FLAG, svc.MEMBER_DK, NULL)), COUNT(DISTINCT svc.MEMBER_DK)) * 100
      WITH SYNONYMS ('중단 이력 비율', '누적 중단 비율')
      COMMENT = '최초 중단 이력이 있는 회원 비율(%) · 관측 기간 무보정 누적값 — 캠페인별 이탈률 정본(12개월 고정)은 SV_MEMBER_COHORT 다. N(비가산).',
    svc.AVG_ACQ_SPNSR_AMT AS AVG(svc.ACQ_SPNSR_AMT)
      WITH SYNONYMS ('평균 후원금액', '평균 약정금액')
      COMMENT = '획득 시점 평균 약정 후원금액(원).',
    svc.AVG_D5_STOP_SPONSOR_DAYS AS AVG(svc.D5_STOP_SPONSOR_DAYS)
      WITH SYNONYMS ('중단 회원 평균 후원기간')
      COMMENT = 'D5 중단 회원의 평균 후원기간(일 · 획득일 → D5 중단일). 🔴 중단 사건 원천에는 후원금액이 없다 — 중단 회원의 후원금액은 AVG_ACQ_SPNSR_AMT(획득 시점 약정금액)로 답하고 그 전제를 밝힌다.'
  )
  COMMENT = '서비스 수신 코호트 SV. 「서비스 수신/미수신 회원의 이벤트 참여율 비교」·「발송 후 5일 이내 중단한 회원의 가입캠페인·중단사유·후원금액·연령대·후원사업·후원기간」·「연도별 수신회원 유지기간·참여횟수」에 쓴다. 🔴 수신·미수신 차이는 인과(서비스 효과)가 아니다.'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 반드시 svc.SERVICE_GROUP_CD 를 하나로 고정한다. (2) 연도별 질문은 svc.RECEIVE_YEAR 로 고정하고, 수신/미수신 비교는 svc.RECEIVED_FLAG 로 나눈다(미수신은 RECEIVE_YEAR 가 NULL 이므로 연도 조건을 걸면 사라진다 — 미수신 비교가 필요하면 연도 조건을 RECEIVED_FLAG = TRUE 쪽에만 건다). (3) 회원수·참여율은 반드시 COUNT(DISTINCT svc.MEMBER_DK) 기반 지표를 쓴다. (4) 「선넘는좋은일 캠페인으로 가입」은 svc.ACQ_PARENT_CAMPAIGN_NAME ILIKE ''%선넘는좋은일%'', 가입기간은 svc.ACQ_DATE 로 거른다. (5) 「온라인 이벤트」 = ONLINE_EVENT_PART_* 지표(일반행사 중 원천 이벤트구분 「온라인」), 「문화이벤트」 = CULTURE_EVENT_PART_* 지표(캠페인행사 중 원천 행사구분 「문화서비스」 계열)로 답한다 — 원천에 같은 이름의 코드가 없어 정의가 되지 않았으므로 「유사한 원천 값(온라인 / 문화서비스·전시·서적·공연)으로 매핑했다」고 답변에 반드시 밝힌다. 「이벤트 전체」를 물으면 GENERAL_EVENT_PART_*·CAMPAIGN_EVENT_PART_* 를 쓴다. (6) 「효과가 높다/낮다」를 인과로 단정하지 않는다 — 지표 차이로만 표현한다. (7) 「오픈」 조건은 이 SV 에 없다(알림톡 오픈 원천 부재) — 수신 기준으로 답하고 그 사실을 밝힌다. (8) 🔴 「수신 회원」·「발송 후 5일 내 중단」·「수신회원 유지기간·참여횟수」 질문은 반드시 svc.RECEIVED_FLAG = TRUE 로 거른다 — 거르지 않으면 미수신(획득 코호트 전체) 회원이 모수에 섞인다. 수신 회원수를 말할 때는 이 조건을 건 값만 쓴다.
  (9) 🆕 [O206] 서비스 법인(사단·사복·통합)은 RECEIVED_SADAN_FLAG·RECEIVED_SABOK_FLAG·RECEIVED_TONGHAP_FLAG = TRUE 로 거른다(법인 = 서비스코드명의 법인 표기 → 없으면 알림톡 템플릿 법인구분). 「(사단)」 질문은 RECEIVED_SADAN_FLAG 로 답하고, 법인 플래그가 모두 FALSE 인 수신(템플릿·코드가 없는 발송)이 있으면 「법인 미판별」로 따로 밝힌다. 서비스 담당부서는 CHRG_DEPT_NAMES(템플릿 담당부서)로 답한다. 획득 세부캠페인 법인구분(svc.ACQ_CPR_DIV_NM)은 발송 법인과 다른 축이므로 대신 쓰지 않는다. (10) 「후원유지기간」은 AVG_SPONSOR_DAYS_TO_DATE 로 답한다 — AVG_TENURE_DAYS 는 이탈 회원만의 평균이다. (11) 연도 간 지표가 달라진 원인(구성 변화 등)을 말하려면 그 분해(연령대·가입연도 등)를 실제로 조회해 보여준 뒤에만 말하고, 조회하지 않은 원인을 단정하지 않는다. (12) 🆕 [O206] 결과에 MATCH_BASIS(매핑근거)를 함께 GROUP BY 해 보여준다 — 🔴 [O206-C] 수신 회원 지표를 내는 모든 쿼리(연도별·연령대별 등 분해 포함)에 MATCH_BASIS 를 GROUP BY 열로 넣거나, 넣지 않으면 별도 쿼리로 MATCH_BASIS 별 회원수를 함께 반환한다(생략 금지) — 「발송제목」 근거 행이 있으면 「원천 상위 카테고리(서비스코드) 정의에 없어 발송 제목으로 매핑했다」고 답변에 명시한다. (13) 🆕 [O206] 대조군은 원천·DW 에 정의가 없다 — 「서비스 효과」·「대조군 대비」를 물으면 먼저 「정의된 대조군이 없다」고 답하고, 대조군 후보를 제시한다: ① 같은 가입월(ACQ_MONTH_KEY) 미수신 회원 ② 같은 가입캠페인(ACQ_CAMPAIGN_NAME·ACQ_PARENT_CAMPAIGN_NAME) 미수신 회원 ③ 같은 후원사업(ACQ_SPONSORSHIP_NAME)·가입 법인구분 미수신 회원 ④ 같은 연령대 미수신 회원. 사용자가 후보를 고르면 그 축을 고정해 RECEIVED_FLAG 로 나눠 비교하되 인과로 단정하지 않는다.'
  AI_VERIFIED_QUERIES (
    vqr_o205_sng_part AS (
      QUESTION '선넘는좋은일 캠페인으로 2026년 1월부터 9월까지 가입한 회원 중 선넘는좋은일 즉시 알림톡 수신/미수신 회원의 온라인 이벤트·문화이벤트 참여율 비교'
      VERIFIED_BY '(DW = O205 원천 직접 집계 · 기대값은 파일 머리 주석)'
      SQL 'SELECT svc.RECEIVED_FLAG, COUNT(DISTINCT svc.MEMBER_DK) AS MEMBER_COUNT, DIV0(COUNT(DISTINCT IFF(svc.GENERAL_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL)), COUNT(DISTINCT svc.MEMBER_DK)) * 100 AS GENERAL_EVENT_PART_RATE, DIV0(COUNT(DISTINCT IFF(svc.CAMPAIGN_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL)), COUNT(DISTINCT svc.MEMBER_DK)) * 100 AS CAMPAIGN_EVENT_PART_RATE FROM svc WHERE svc.SERVICE_GROUP_CD = ''SNG_INSTANT'' AND svc.ACQ_PARENT_CAMPAIGN_NAME ILIKE ''%선넘는좋은일%'' AND svc.ACQ_DATE BETWEEN ''2026-01-01'' AND ''2026-09-30'' GROUP BY svc.RECEIVED_FLAG ORDER BY svc.RECEIVED_FLAG'
    )
  );

-- SV_PAYMENT_BILLING_STATUS ← 05_19_SV_DDL_PAYMENT_BILLING_STATUS.sql
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_PAYMENT_BILLING_STATUS
  TABLES (
    pbs AS GN_DW.GOLD.FACT_PAYMENT_BILLING_STATUS
      WITH SYNONYMS ('회비 청구 처리', '청구 처리 현황', '청구 상태')
      COMMENT = '회비 청구 처리 상태 팩트(1행 = 월 × 후원사업 × 회비구분 × 납입유형 × 청구구분 × 처리상태 × 환급사유). 「청구구분별 청구 건수」「처리상태별 청구액」「환급사유별 건수」 질문용. [원천: CRM(eCRM) → BRONZE_CRM.TM_PM_MBRFEE_ACMSLT·TM_PM_DNTN_DTLS → SILVER.CRM_PAYMENT_BILLING → GOLD.FACT_PAYMENT_BILLING_STATUS]. 🔴 회원 축이 없다 — 회원 단위 회비는 SV_MEMBER_FEE·SV_MEMBER_MONTHLY 소관이며 한 표에 합산하지 않는다.',
    sponsorship AS GN_DW.GOLD.DIM_SPONSORSHIP
      PRIMARY KEY (SPONSORSHIP_SK)
      WITH SYNONYMS ('후원사업')
      COMMENT = '후원사업 차원(납입 대상 후원사업).',
    -- 🆕 [2026-10-14 O225-C] 그 달 후원 캠페인 축
    campaign AS GN_DW.GOLD.DIM_CAMPAIGN
      PRIMARY KEY (CAMPAIGN_SK)
      WITH SYNONYMS ('캠페인', '후원 캠페인')
      COMMENT = '캠페인 차원(PK 유일 · fan-out 0). 청구 행의 캠페인 = 일시후원 캠페인코드 · 정기는 청구월에 유효한 후원 기간의 캠페인. SK=0 = (미매핑). [원천] BRONZE_CRM.TM_PM_MBRFEE_ACMSLT·TM_PM_DNTN_DTLS.ONCE_CMPGN_CD · TM_MM_FDRM_MBER_SPNSR.CMPGN_CD → TM_CM_CMPGN_MNG.'
  )
  RELATIONSHIPS (
    pbs_to_sponsorship AS pbs (SPONSORSHIP_SK) REFERENCES sponsorship,
    pbs_to_campaign AS pbs (CAMPAIGN_SK) REFERENCES campaign
  )
  DIMENSIONS (
    pbs.MONTH_KEY AS pbs.MONTH_KEY WITH SYNONYMS ('회비월', '기준월', '연월') COMMENT = '회비월 YYYYMM(정수 · 회비월 우선 · 납입월 폴백 · 0 = Unknown월).',
    pbs.MONTH_LABEL AS CASE WHEN pbs.MONTH_KEY > 0 THEN TO_CHAR(FLOOR(pbs.MONTH_KEY / 100)) || '-' || LPAD(TO_CHAR(MOD(pbs.MONTH_KEY, 100)), 2, '0') END WITH SYNONYMS ('회비월 표시', '월') COMMENT = '회비월 표시용 문자열 YYYY-MM(회비월 라벨 규칙 · 0 = Unknown월은 NULL). 답변 표에는 이 값을 쓴다.',
    pbs.FEE_DIV_NAME AS pbs.FEE_DIV_NAME WITH SYNONYMS ('회비구분', '정기/선물금/일시/긴급구호') COMMENT = '회비구분(PM010 · 정기·선물금·일시·긴급구호). 기부금 행은 NULL(원천에 회비구분 개념 없음).',
    pbs.PAYMENT_TYPE AS pbs.PAYMENT_TYPE WITH SYNONYMS ('납입유형', '회비/기부금') COMMENT = '납입유형(회비 · 기부금).',
    pbs.RQEST_DIV_CD AS pbs.RQEST_DIV_CD WITH SYNONYMS ('청구구분코드') COMMENT = '청구구분 원천 코드(PM024). 라벨 없는 코드 Y 를 구분할 때 쓴다.',
    pbs.RQEST_DIV_NAME AS pbs.RQEST_DIV_NAME WITH SYNONYMS ('청구구분', '청구 구분', '정기청구/개별청구') COMMENT = '청구구분(PM024 · 정기청구·OCR신규·개별청구). 🔴 원천 코드 Y 는 코드사전에 없어 라벨이 NULL 이다(현업 확인 대상) — 「청구구분별」 표에는 NULL 행을 「코드 Y」로 따로 밝힌다.',
    pbs.PRCS_STAT_CD AS pbs.PRCS_STAT_CD WITH SYNONYMS ('처리상태코드') COMMENT = '회비 처리상태 원천 코드(PM013). 라벨 없는 코드 F 를 구분할 때 쓴다.',
    pbs.PRCS_STAT_NAME AS pbs.PRCS_STAT_NAME WITH SYNONYMS ('처리상태', '회비 처리상태', '청구/완료') COMMENT = '회비 처리상태(PM013 · 청구·완료). 🔴 원천 코드 F 는 코드사전에 없어 라벨이 NULL 이다(현업 확인 대상) — 의미를 추정하지 않는다.',
    pbs.RETUN_RSN_NAME AS pbs.RETUN_RSN_NAME WITH SYNONYMS ('환급사유', '환불사유', '반환사유') COMMENT = '환급사유(PM042 · 11종 · 예: 청구 후 후원중단·회원 오신청·회비이중납부·회원요청). 환급이 아닌 청구행은 NULL(개념 없음) — 환급사유 질문은 값이 있는 행으로 한정한다.',
    sponsorship.SPONSORSHIP AS sponsorship.SPONSORSHIP_NAME WITH SYNONYMS ('후원사업', '후원사업명') COMMENT = '납입 대상 후원사업명.',
    -- 🆕 [2026-10-14 O225-C] 그 달 후원 캠페인 속성(DIM_CAMPAIGN)
    campaign.CAMPAIGN_NAME AS campaign.CAMPAIGN_NAME WITH SYNONYMS ('캠페인명', '후원 캠페인', '캠페인') COMMENT = '그 달 후원 캠페인명(일시 = 일시후원 캠페인 · 정기 = 청구월에 유효한 후원 기간의 캠페인). (미매핑) = 캠페인 미귀속.',
    campaign.CAMPAIGN_TYPE AS campaign.CAMPAIGN_TYPE WITH SYNONYMS ('캠페인 카테고리', '주요캠페인', '캠페인유형') COMMENT = '캠페인 카테고리(MM294 라벨).',
    campaign.DOMESTIC_OVERSEAS AS campaign.DOMESTIC_OVERSEAS WITH SYNONYMS ('국내해외', '국내/해외') COMMENT = '캠페인유형 국내/통합/해외(MM295).',
    campaign.BIZ_CASE_TYPE AS campaign.BIZ_CASE_TYPE WITH SYNONYMS ('사업사례', '사업/사례') COMMENT = '캠페인유형 굿즈/기타/사례/사업(MM296).',
    campaign.INFLOW_PATH AS campaign.INFLOW_PATH WITH SYNONYMS ('인입경로', '회원인입', '개발인입경로') COMMENT = '캠페인 개발인입경로(MM293).',
    campaign.MARKETING_CAMPAIGN AS campaign.MARKETING_CAMPAIGN WITH SYNONYMS ('마케팅캠페인', '마케팅캠페인명') COMMENT = '마케팅캠페인명.',
    campaign.MKTG_CHANNEL_NM AS campaign.MKTG_CHANNEL_NM WITH SYNONYMS ('마케팅채널', '캠페인 채널') COMMENT = '캠페인 마케팅 채널명(TC_MKTNG_DTL_CD C002).',
    campaign.MKTG_UTM_NM AS campaign.MKTG_UTM_NM WITH SYNONYMS ('UTM', 'UTM 캠페인') COMMENT = '캠페인 UTM 라벨(TC_MKTNG_DTL_CD U001).',
    campaign.PARENT_CAMPAIGN_NAME AS campaign.PARENT_CAMPAIGN_NAME WITH SYNONYMS ('상위캠페인', '상위캠페인명') COMMENT = '상위캠페인명. 상위가 없으면 NULL.',
    campaign.PROMO_METHOD_NAME AS campaign.PROMO_METHOD_NAME WITH SYNONYMS ('홍보방법') COMMENT = '홍보방법명(CM008).',
    campaign.CMMN_BRND_NM AS campaign.CMMN_BRND_NM WITH SYNONYMS ('공통브랜드') COMMENT = '공통브랜드명(MM297).',
    campaign.CPR_DIV_NM AS campaign.CPR_DIV_NM WITH SYNONYMS ('캠페인 법인구분') COMMENT = '캠페인 법인구분명(CM019).',
    campaign.SPNSR_DIV_NM AS campaign.SPNSR_DIV_NM WITH SYNONYMS ('캠페인 후원구분') COMMENT = '캠페인 후원구분명(CM035 정기/일시).'
  )
  METRICS (
    pbs.BILLING_ROW_CNT AS SUM(pbs.BILLING_ROWS)
      WITH SYNONYMS ('청구(건)', '청구 건수', '청구건')
      COMMENT = '청구행 수 합(건). F(가산).',
    pbs.BILLED_AMT_SUM AS SUM(pbs.BILLED_AMT)
      WITH SYNONYMS ('청구액(원)', '청구금액', '청구액')
      COMMENT = '청구액 합(원). F(가산) · FACT_MEMBER_FEE 의 청구액과 같은 식.',
    pbs.PAID_FEE_SUM AS SUM(pbs.PAID_FEE)
      WITH SYNONYMS ('납입액(원)', '납입금액', '납입액')
      COMMENT = '납입 총액(원) = 회비 + 기부금. F(가산).',
    pbs.UNPAID_AMT_SUM AS SUM(pbs.UNPAID_BILLED_AMT)
      WITH SYNONYMS ('미납액(원)', '미납 청구액', '미납액')
      COMMENT = '미납 청구액(원) = 결제상태 실패 또는 미기록인 청구액. F(가산).',
    pbs.BILLED_MEMBER_MAX AS MAX(pbs.BILLED_MEMBERS)
      WITH SYNONYMS ('청구 회원수(조합 최대)')
      COMMENT = '🔴 참고용 — 팩트 행(조합)마다 센 고유 회원수의 최대값이다. 고유 회원수는 조합을 넘어 더할 수 없으므로 「몇 명에게 청구했나」 질문은 SV_MEMBER_FEE 로 답한다.'
  )
  COMMENT = '회비 청구 처리 상태 SV. 「청구구분·처리상태·환급사유별 청구 건수·금액」 질문에 쓴다. 활성: 청구(건)·청구액·납입액·미납액 · 회비월/회비구분/납입유형/청구구분/처리상태/환급사유/후원사업/캠페인(그 달 후원 캠페인) 축. 🔴 회원 단위 질문·고유 회원수는 SV_MEMBER_FEE 소관이며 이 SV 와 한 표에 합산하지 않는다(같은 원천 · 다른 grain). 비활성: 청구결과·처리결과(코드 사전 불일치 · 현업 확인 대상).'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "청구액(원)" · "청구(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. [O206-C 합계 규칙] 답변에 쓸 합계·총계는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행을 반환한다.
  핵심 규칙: (1) 회비월 미지정 시 데이터에 존재하는 최신 회비월 하나로 한정하고 밝힌다(MONTH_KEY = 0 Unknown월 제외). (2) 회비월은 MONTH_LABEL(YYYY-MM)로 표시한다. (3) 청구구분·처리상태 라벨이 NULL 인 행은 원천 코드(RQEST_DIV_CD · PRCS_STAT_CD)를 함께 반환해 「코드 Y」「코드 F」로 밝히고 의미를 추정하지 않는다. (4) 환급사유 질문은 RETUN_RSN_NAME IS NOT NULL 로 한정한다. (5) 고유 회원수를 묻는 질문에는 이 SV 로 답하지 않는다 — SV_MEMBER_FEE 로 안내한다. (6) [O225-C] 캠페인별 회비(청구·납입·미납)는 이 SV 의 campaign 차원으로 답한다 — 캠페인 = 그 달 후원 캠페인(일시 = 일시후원 캠페인 · 정기 = 청구월에 유효한 후원 기간의 캠페인)이고 금액은 청구 행 단위로 정확히 귀속된다. 결과에 (미매핑) 금액을 ROLLUP 과 함께 표시한다.'
  AI_VERIFIED_QUERIES (
    vqr_o213_rqest_div AS (
      QUESTION '2026년 8월 회비 청구구분별 청구 건수와 청구액'
      VERIFIED_BY '(O213 · 원천 직접 집계 대조 · 정기청구 922,963건 17,497,729,843원 · 코드 Y 2,375건 · OCR신규 634건 · 개별청구 84건)'
      SQL 'SELECT pbs.RQEST_DIV_NAME AS "청구구분", pbs.RQEST_DIV_CD AS "청구구분코드", SUM(pbs.BILLING_ROWS) AS "청구(건)", SUM(pbs.BILLED_AMT) AS "청구액(원)" FROM pbs WHERE pbs.MONTH_KEY = 202608 GROUP BY ROLLUP(pbs.RQEST_DIV_NAME, pbs.RQEST_DIV_CD) ORDER BY 3 DESC NULLS FIRST'
    )
  );

-- SV_MSTR_SPNSR_DVLP ← 05_MSTR_SV_DDL.sql
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MSTR_SPNSR_DVLP
  TABLES (
    md AS GN_DW.SERVING.MSTR_SPNSR_DVLP_V
      WITH SYNONYMS ('MSTR 개발', 'MSTR 후원개발', 'MSTR 리포트', '정기회원 후원개발')
      COMMENT = 'MSTR 정기회원 후원개발 리포트 (base: SERVING.MSTR_SPNSR_DVLP_V). [Grain: 개발 팩트 1행]. [활성 지표: MSTR 개발(건)·개발(명)·후원금액]. [주의: MSTR 기준 정의, GN_DW 지표와 합산 금지, 개발(명) 비가산]. [원천: BRONZE_CRM → GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM(MSTR 이관 로직) → SERVING.MSTR_SPNSR_DVLP_V].',
    gl AS GN_DW.SERVING.MSTR_DVLP_GOAL_V
      WITH SYNONYMS ('MSTR 개발 목표', '개발 목표', '목표 달성')
      COMMENT = 'MSTR 개발 목표·실적 (base: SERVING.MSTR_DVLP_GOAL_V). [Grain: 실적부서 × 기준년월 × 개발구분]. [활성 지표: 월 목표(건)·실적(건)·달성률]. [주의: 실질 목표는 신규만 · md 테이블과 조인하지 않는다].',
    ye AS GN_DW.SERVING.MSTR_DVLP_YE_TREND_V
      WITH SYNONYMS ('연도말 개발 예측', '연말 개발 전망', '연도말 추세')
      COMMENT = 'MSTR 연도말 개발 추세 참고치 (base: SERVING.MSTR_DVLP_YE_TREND_V). [Grain: 실적부서 × 기준연도 × 개발구분]. [활성 지표: 연 목표·마감월 실적·추세 참고치·목표 대비 %]. [주의: 모델 예측 아님 · 직전 3개 마감월 평균 기반].',
    yb AS GN_DW.SERVING.MSTR_DVLP_YE_TREND_BSNS_V
      WITH SYNONYMS ('후원사업별 연도말 개발 예측', '후원사업별 연말 전망')
      COMMENT = 'MSTR 후원사업2 별 연도말 개발 추세 참고치 (base: SERVING.MSTR_DVLP_YE_TREND_BSNS_V). [Grain: 후원사업2 × 기준연도 × 개발구분]. [주의: 모델 예측 아님 · 후원사업 축에는 목표가 없다].'
  )
  DIMENSIONS (
    md.STRD_MT AS md.STRD_MT
      WITH SYNONYMS ('기준년월', '기준월')
      COMMENT = '기준년월(YYYYMM 문자열). 🔴 적재 범위는 조회해서 확인한다(열거하지 않는다).',
    md.STRD_DE AS md.STRD_DE
      WITH SYNONYMS ('기준일자', '발생일자')
      COMMENT = '발생일자(YYYYMMDD 문자열).',
    md.DVLP_DIV_CD AS md.DVLP_DIV_CD
      WITH SYNONYMS ('개발구분코드')
      COMMENT = 'MSTR 개발구분코드. 라벨은 DVLP_DIV_NM.',
    md.DVLP_DIV_NM AS md.DVLP_DIV_NM
      WITH SYNONYMS ('개발구분')
      COMMENT = 'MSTR 개발구분명(신규/증액/감액/재후원/후원중단). 🔴 MSTR 「개발」 리포트 기본 범위는 신규·증액·재후원이다.',
    md.CPR_DIV_NM AS md.CPR_DIV_NM
      WITH SYNONYMS ('법인', '법인구분')
      COMMENT = '법인구분명(MSTR 표기).',
    md.DEPT4_NM AS md.DEPT4_NM
      WITH SYNONYMS ('구분_팀', '부서4')
      COMMENT = 'MSTR 실적부서4(리포트 「구분_팀」).',
    md.DEPT3_NM AS md.DEPT3_NM
      WITH SYNONYMS ('본부/지부', '부서3')
      COMMENT = 'MSTR 실적부서3(리포트 「본부/지부」).',
    md.DEPT2_NM AS md.DEPT2_NM
      WITH SYNONYMS ('팀/지부', '부서2')
      COMMENT = 'MSTR 실적부서2(리포트 「팀/지부」).',
    md.DEPT_NM AS md.DEPT_NM
      WITH SYNONYMS ('부서', '실적부서')
      COMMENT = 'MSTR 실적부서명(리포트 「부서」). 🔴 GN_DW 부서 차원과 같은 조직이라 단정하지 않는다.',
    md.BRND_NM AS md.BRND_NM
      WITH SYNONYMS ('브랜드', '브랜드명', '세부 브랜드', 'CRM 브랜드')
      COMMENT = '브랜드명(원천 COMMENT = 브랜드 · 60여 종). [원천 컬럼명 원칙] 「브랜드」는 이 축이다 — 「공통브랜드」를 말할 때만 CMMN_BRND_NM 을 쓴다.',
    md.UPPER_CMPGN_NM AS md.UPPER_CMPGN_NM
      WITH SYNONYMS ('상위캠페인')
      COMMENT = '상위캠페인명.',
    md.CMPGN_CD AS md.CMPGN_CD
      WITH SYNONYMS ('캠페인코드', 'CP')
      COMMENT = '캠페인코드(리포트 「CP」).',
    md.CMPGN_NM AS md.CMPGN_NM
      WITH SYNONYMS ('캠페인')
      COMMENT = '캠페인명.',
    md.PR_MTH_NM AS md.PR_MTH_NM
      WITH SYNONYMS ('홍보방법')
      COMMENT = '홍보방법명.',
    md.SPNSR_BSNS_NM AS md.SPNSR_BSNS_NM
      WITH SYNONYMS ('후원사업')
      COMMENT = '후원사업명.',
    md.SPNSR_BSNS2_NM AS md.SPNSR_BSNS2_NM
      WITH SYNONYMS ('후원사업2')
      COMMENT = 'MSTR 후원사업2(재분류 그룹 · 리포트 「후원사업2」).',
    md.SEX_NM AS md.SEX_NM
      WITH SYNONYMS ('성별')
      COMMENT = '성별명(MSTR 표기).',
    md.AGE_TERM_NM AS md.AGE_TERM_NM
      WITH SYNONYMS ('연령대')
      COMMENT = '연령대명(MSTR 구간).',
    md.NEW_OLD_DIV_NM AS md.NEW_OLD_DIV_NM
      WITH SYNONYMS ('신규기존구분', '신규/기존', '신규 기존')
      COMMENT = 'MSTR 신규기존구분명. 실제값: ''신규''·''기존''(코드 99 = ''없음''). 🔴 MSTR 원천이 개발 건마다 판정해 둔 값이다 — 가입일로 다시 계산하지 않는다(MSTR 에는 가입일 컬럼이 없다).',
    md.MBER_NO AS md.MBER_NO
      WITH SYNONYMS ('회원번호')
      COMMENT = '회원번호. 개발(명) 중복제거 전용 — 회원 목록 질의에는 쓰지 않는다.',
    md.SPNSR_TERM_NM AS md.SPNSR_TERM_NM
      WITH SYNONYMS ('후원기간대', '후원기간')
      COMMENT = '후원기간대(CM016 · 1년 미만/1~5년/5~10년/10년 이상 · 첫 후원일 → 발생일).',
    md.SPNSR_TERM2_NM AS md.SPNSR_TERM2_NM
      WITH SYNONYMS ('후원기간대2', '후원기간 1년 단위')
      COMMENT = '후원기간대2(DMMM08 · 1년 단위 11구간).',
    md.SPNSR_AMT_NM AS md.SPNSR_AMT_NM
      WITH SYNONYMS ('후원금액범위', '후원금액대')
      COMMENT = '후원금액범위(CM012 · 원천 판정값). 🔴 그 행 후원금액의 구간이 아니다 — 개발금액 구간은 후원금액대2 를 쓴다.',
    md.SPNSR_AMT2_NM AS md.SPNSR_AMT2_NM
      WITH SYNONYMS ('후원금액대2', '개발금액대')
      COMMENT = '후원금액대2(DMMM09 · 1만원 단위 · 후원사업별 최초 정상 개발건 금액 기준 · 「없음」 = 매칭 없음).',
    md.SETLE_NM AS md.SETLE_NM
      WITH SYNONYMS ('결제수단', '결제방법', '납입방법')
      COMMENT = '결제수단(PM040 · 자동이체·신용카드·휴대폰·네이버페이 등).',
    md.MBER_DIV_NM AS md.MBER_DIV_NM
      WITH SYNONYMS ('회원구분', '개인/기업/단체')
      COMMENT = '회원구분(MM018 · 개인·기업·단체).',
    md.AREA_NM AS md.AREA_NM
      WITH SYNONYMS ('지역', '시도')
      COMMENT = '시도(CM011). 🔴 「기타」가 큰 비중을 차지한다 · 라벨 없는 코드는 NULL.',
    md.SPNSR_BSNS_ABRV_NM AS md.SPNSR_BSNS_ABRV_NM
      WITH SYNONYMS ('후원약칭', '국내/해외/결연')
      COMMENT = '후원약칭(CM003 · 국내·결연·해외·해외구호·북한 등).',
    md.CANCL_RDCAMT_RSN_NM AS md.CANCL_RDCAMT_RSN_NM
      WITH SYNONYMS ('중단사유', '감액사유', '중단·감액 사유')
      COMMENT = '중단·감액 사유. 🔴 개발구분 후원중단 = 후원중단사유(MM005) · 감액 = 후원사업취소사유(MM002) · 그 외 개발구분은 NULL(개념 없음). 사유 질문은 개발구분을 후원중단 또는 감액 하나로 고정한다.',
    md.PRE_CMPGN_NM AS md.PRE_CMPGN_NM
      WITH SYNONYMS ('직전캠페인', '이전 캠페인')
      COMMENT = '직전캠페인(재후원 전 마지막 캠페인). 🔴 재후원·금액>0 행에만 값이 있다.',
    md.CMMN_BRND_NM AS md.CMMN_BRND_NM
      WITH SYNONYMS ('공통브랜드', '공통 브랜드')
      COMMENT = '공통브랜드(MM297 · 예: 디지털·교육기관·지역개발·대면모금·영상광고·재송출·방송). 「공통브랜드」를 말할 때 쓴다(「브랜드」는 BRND_NM). 캠페인 마스터 현재값.',
    md.DVLP_INFLOW_PATH_NM AS md.DVLP_INFLOW_PATH_NM
      WITH SYNONYMS ('개발인입경로', '인입경로', '개발 인입경로', '모집채널')
      COMMENT = '개발인입경로(MM293 · 12종 · 예: 디지털·방송·대면모금·교육기관·지역개발·콜개발·영상광고·재송출). 캠페인 마스터 현재값. 🔴 공통브랜드와 라벨이 겹쳐 보여도 다른 축이다 — 한쪽 값으로 다른 쪽을 필터하지 않는다.',
    md.CMPGN_TYPE2_NM AS md.CMPGN_TYPE2_NM
      WITH SYNONYMS ('캠페인유형2', '캠페인유형(사업/사례)', '사업사례구분', '사업/사례')
      COMMENT = '캠페인유형2(원천 COMMENT = 캠페인유형(사업/사례) · MM296 · 4종 = 사례·사업·굿즈·기타). 「캠페인유형2」·「사업/사례」를 말할 때 쓴다 — 「캠페인유형」은 CMPGN_TYPE1_NM(국내/해외)이다. 캠페인 마스터 현재값.',
    md.CMPGN_CTGR_NM AS md.CMPGN_CTGR_NM
      WITH SYNONYMS ('캠페인카테고리', '주요캠페인', '캠페인 카테고리', '캠페인 소분류')
      COMMENT = '캠페인카테고리(MM294 · 세부 40여 종 · 예: 초등캠페인·국내사례캠페인·해외캠페인·희망TV). 「캠페인카테고리」「주요캠페인」을 명시할 때만 쓴다. 🔴 캠페인유형2 의 엄격한 하위가 아니다(한 카테고리가 여러 유형2 에 걸친다).',
    md.CMPGN_TYPE1_NM AS md.CMPGN_TYPE1_NM
      WITH SYNONYMS ('캠페인유형', '캠페인 유형', '캠페인유형(국내/해외)', '국내해외', '국내/해외')
      COMMENT = '캠페인유형(원천 COMMENT = 캠페인유형(국내/해외) · MM295 · 국내·해외·통합 등). 「캠페인유형」을 말할 때 쓴다(「캠페인유형2」는 사업/사례 CMPGN_TYPE2_NM). 캠페인 마스터 현재값.',
    md.MK_CMPGN_NM AS md.MK_CMPGN_NM
      WITH SYNONYMS ('마케팅캠페인', '마케팅 캠페인', '나마본캠페인')
      COMMENT = '마케팅캠페인(원천 COMMENT = 마케팅 캠페인명 · C001 · 500여 종). 「마케팅캠페인」을 말할 때 쓴다(「캠페인」은 CMPGN_NM 개발캠페인). 캠페인 마스터 현재값.',
    md.MKTG_UTM_NM AS md.MKTG_UTM_NM
      WITH SYNONYMS ('UTM', '마케팅 UTM', '유입 UTM')
      COMMENT = '마케팅 UTM(원천 COMMENT = 마케팅 UTM 라벨 · U001). 🔴 일부 캠페인에만 값이 있다 — NULL 은 UTM 미등록 캠페인이며 「UTM별」 합계는 전체보다 작다(총계는 축 없이 답한다).',
    md.MKTG_CHANNEL_NM AS md.MKTG_CHANNEL_NM
      WITH SYNONYMS ('마케팅채널', '마케팅 채널', '캠페인 채널')
      COMMENT = '마케팅채널(원천 COMMENT = 마케팅 채널명 · C002 · 100여 종). 캠페인 마스터 현재값. 🔴 개발인입경로(MM293)와 다른 축이다. 🔴 값 「-」는 원천 코드사전 C002 에 등록된 코드 6 의 라벨이다(결측 아님 · 2026-10-08 실측) — 「채널 미지정 캠페인」으로 읽되 업무 의미는 원천 확인 대상이며, 채널별 순위에서는 「-」를 따로 밝힌다.',
    md.SPNSR_DIV_NM AS md.SPNSR_DIV_NM
      WITH SYNONYMS ('후원구분', '정기/일시')
      COMMENT = '후원구분(원천 COMMENT = 후원구분명 · CM035 · 정기후원/일시후원). 캠페인 마스터 기준(캠페인이 정기·일시 중 어디에 쓰이는지)이다.',
    gl.STRD_MT AS gl.STRD_MT
      WITH SYNONYMS ('목표 기준년월')
      COMMENT = '목표·실적 기준년월(YYYYMM).',
    gl.STRD_YY AS gl.STRD_YY
      WITH SYNONYMS ('목표 기준연도')
      COMMENT = '목표·실적 기준연도(YYYY).',
    gl.DVLP_DIV_CD AS gl.DVLP_DIV_CD
      WITH SYNONYMS ('목표 개발구분코드')
      COMMENT = '개발구분코드(1 = 신규).',
    gl.DVLP_DIV_NM AS gl.DVLP_DIV_NM
      WITH SYNONYMS ('목표 개발구분')
      COMMENT = '개발구분. 🔴 실질 목표는 신규만 있다 — 목표 질문은 신규로 고정한다.',
    gl.DEPT4_NM AS gl.DEPT4_NM
      WITH SYNONYMS ('목표 구분_팀')
      COMMENT = '실적부서4(구분_팀).',
    gl.DEPT3_NM AS gl.DEPT3_NM
      WITH SYNONYMS ('목표 본부/지부')
      COMMENT = '실적부서3(본부/지부).',
    gl.DEPT2_NM AS gl.DEPT2_NM
      WITH SYNONYMS ('목표 팀/지부')
      COMMENT = '실적부서2(팀/지부).',
    gl.DEPT_NM AS gl.DEPT_NM
      WITH SYNONYMS ('목표 부서')
      COMMENT = '실적부서명(목표 등록 단위).',
    gl.CLOSED_MONTH_YN AS gl.CLOSED_MONTH_YN
      WITH SYNONYMS ('마감월 여부')
      COMMENT = 'Y = 마감월 · N = 진행 중인 최신 기준월 또는 미래 월(부분 실적).',
    ye.STRD_YY AS ye.STRD_YY
      WITH SYNONYMS ('전망 기준연도')
      COMMENT = '연도말 추세 참고치 기준연도(YYYY).',
    ye.AS_OF_MT AS ye.AS_OF_MT
      WITH SYNONYMS ('산출 기준월')
      COMMENT = '산출 기준 최신 기준년월(진행 중 · 부분 실적).',
    ye.DVLP_DIV_CD AS ye.DVLP_DIV_CD
      WITH SYNONYMS ('전망 개발구분코드')
      COMMENT = '개발구분코드(1 = 신규).',
    ye.DVLP_DIV_NM AS ye.DVLP_DIV_NM
      WITH SYNONYMS ('전망 개발구분')
      COMMENT = '개발구분. 🔴 목표 대비 % 는 신규에만 의미가 있다.',
    ye.DEPT4_NM AS ye.DEPT4_NM
      WITH SYNONYMS ('전망 구분_팀')
      COMMENT = '실적부서4(구분_팀).',
    ye.DEPT3_NM AS ye.DEPT3_NM
      WITH SYNONYMS ('전망 본부/지부')
      COMMENT = '실적부서3(본부/지부).',
    ye.DEPT2_NM AS ye.DEPT2_NM
      WITH SYNONYMS ('전망 팀/지부')
      COMMENT = '실적부서2(팀/지부).',
    ye.DEPT_NM AS ye.DEPT_NM
      WITH SYNONYMS ('전망 부서')
      COMMENT = '실적부서명.',
    yb.STRD_YY AS yb.STRD_YY
      WITH SYNONYMS ('후원사업 전망 기준연도')
      COMMENT = '기준연도(YYYY).',
    yb.AS_OF_MT AS yb.AS_OF_MT
      WITH SYNONYMS ('후원사업 전망 산출 기준월')
      COMMENT = '산출 기준 최신 기준년월(진행 중).',
    yb.DVLP_DIV_CD AS yb.DVLP_DIV_CD
      WITH SYNONYMS ('후원사업 전망 개발구분코드')
      COMMENT = '개발구분코드(1 = 신규).',
    yb.DVLP_DIV_NM AS yb.DVLP_DIV_NM
      WITH SYNONYMS ('후원사업 전망 개발구분')
      COMMENT = '개발구분.',
    yb.SPNSR_BSNS2_NM AS yb.SPNSR_BSNS2_NM
      WITH SYNONYMS ('전망 후원사업2', '후원사업별 전망')
      COMMENT = '후원사업2(MSTR 재분류).'
  )
  METRICS (
    md.MSTR_DVLP_CNT AS ROUND(SUM(md.SPNSR_AMT_CNT), 4)
      WITH SYNONYMS ('개발(건)', 'MSTR 개발건', '개발 건수')
      COMMENT = 'MSTR 개발(건) = 후원금액 ÷ 10,000 의 합(소수 4자리). 🔴 GN_DW 개발건수(사건 건수)와 정의가 다르다.',
    md.MSTR_DVLP_MEMBERS AS COUNT(DISTINCT md.MBER_NO)
      WITH SYNONYMS ('개발(명)', 'MSTR 개발 회원수', '개발 명')
      COMMENT = 'MSTR 개발(명) = 회원번호 중복제거. 🔴 비가산 — 하위 그룹 값을 더해 상위 값을 만들지 않는다.',
    md.MSTR_SPNSR_AMT AS SUM(md.SPNSR_AMT)
      WITH SYNONYMS ('후원금액', '개발 금액')
      COMMENT = '후원금액 합계(원). 감액·후원중단 구분은 음수다.',
    md.MSTR_ROW_CNT AS SUM(md.DVLP_CNT)
      WITH SYNONYMS ('개발 행수', '원천 건수')
      COMMENT = '원천 개발구분건수 합계(행 단위). MSTR 리포트 「개발(건)」이 아니다.',
    gl.GOAL_DVLP_CNT AS SUM(gl.GOAL_CNT)
      WITH SYNONYMS ('개발 목표(건)', '목표(건)', '월 목표')
      COMMENT = 'MSTR 개발 목표(건) 합. 🔴 실질 목표는 신규만 있다.',
    gl.GOAL_ACT_CNT AS ROUND(SUM(gl.ACT_CNT), 4)
      WITH SYNONYMS ('목표 대비 실적(건)', '실적(건)')
      COMMENT = '목표와 같은 키(부서×월×개발구분)의 MSTR 개발(건) 실적 합(소수 4자리).',
    gl.GOAL_ACHV_RATE AS ROUND(DIV0(SUM(IFF(gl.GOAL_CNT > 0, gl.ACT_CNT, 0)), SUM(gl.GOAL_CNT)) * 100, 1)
      WITH SYNONYMS ('목표 달성률(%)', '달성률', '달성율')
      COMMENT = '목표 달성률(%) = 목표가 있는 부서·월 실적 ÷ 목표 × 100(소수 1자리). 🔴 목표 없는 부서 실적은 분자에서 뺀다.',
    ye.YE_GOAL_CNT AS SUM(ye.YY_GOAL_CNT)
      WITH SYNONYMS ('연 개발 목표(건)', '연간 목표')
      COMMENT = '연 개발 목표(건) = 월 목표 합.',
    ye.YE_CLOSED_ACT_CNT AS ROUND(SUM(ye.CLOSED_ACT_CNT), 4)
      WITH SYNONYMS ('마감월 누적 실적(건)', '연누적 실적')
      COMMENT = '그 해 마감월 MSTR 개발(건) 실적 합.',
    ye.YE_CUR_MONTH_ACT_CNT AS ROUND(SUM(ye.CUR_MONTH_ACT_CNT), 4)
      WITH SYNONYMS ('진행 월 부분 실적(건)')
      COMMENT = '진행 중 최신 기준월의 부분 실적(참고 · 추세 산식에 쓰지 않는다).',
    ye.YE_LAST3_AVG_CNT AS ROUND(SUM(ye.LAST3_AVG_CNT), 4)
      WITH SYNONYMS ('직전 3개월 평균(건)')
      COMMENT = '직전 3개 마감월 월평균 실적(건 · 현재 연도만).',
    ye.YE_TREND_DVLP_CNT AS ROUND(SUM(ye.YE_TREND_CNT), 4)
      WITH SYNONYMS ('연도말 개발 추세 참고치(건)', '연도말 예측(건)', '연말 전망(건)')
      COMMENT = '연도말 개발 추세 참고치(건) = 마감월 실적 + 남은 월 × 직전 3개월 평균. 🔴🔴 모델 예측이 아니다 — 답변에 「추세 참고치(모델 예측 아님)」를 밝힌다.',
    ye.YE_TREND_GOAL_RATE AS ROUND(DIV0(SUM(IFF(ye.YY_GOAL_CNT > 0, ye.YE_TREND_CNT, 0)), SUM(ye.YY_GOAL_CNT)) * 100, 1)
      WITH SYNONYMS ('연 목표 대비 추세(%)', '연말 달성 전망(%)')
      COMMENT = '연 목표 대비 추세 참고치(%) = 목표가 있는 부서의 추세 참고치 ÷ 연 목표 × 100(소수 1자리).',
    yb.YB_CLOSED_ACT_CNT AS ROUND(SUM(yb.CLOSED_ACT_CNT), 4)
      WITH SYNONYMS ('후원사업 마감월 누적 실적(건)')
      COMMENT = '후원사업2 별 그 해 마감월 MSTR 개발(건) 실적 합.',
    yb.YB_LAST3_AVG_CNT AS ROUND(SUM(yb.LAST3_AVG_CNT), 4)
      WITH SYNONYMS ('후원사업 직전 3개월 평균(건)')
      COMMENT = '후원사업2 별 직전 3개 마감월 월평균 실적(건).',
    yb.YB_TREND_DVLP_CNT AS ROUND(SUM(yb.YE_TREND_CNT), 4)
      WITH SYNONYMS ('후원사업 연도말 개발 추세 참고치(건)', '후원사업별 연도말 예측(건)')
      COMMENT = '후원사업2 별 연도말 개발 추세 참고치(건). 🔴 모델 예측이 아니다 · 목표 없음.'
  )
  COMMENT = 'MSTR 정기회원 후원개발 SV(MSTR 1차 이관). base=SERVING.MSTR_SPNSR_DVLP_V. 🔴🔴 **MSTR 기준 정의다** — GN_DW 회원 SV(SV_MEMBER_EVENT 등)의 개발건수·회원수와 정의가 달라 같은 표에 합산·차감하지 않는다. 🔴🔴 **MSTR 개발(건) = 후원금액 ÷ 10,000** 이다(사건 건수가 아니다). 🔴 개발(명)은 중복제거라 비가산이다. 🔴 MSTR 「개발」 리포트의 기본 범위는 개발구분 신규·증액·재후원이다 — 감액·후원중단을 섞지 않는다. 🔴 적재 기준월은 PoC 범위로 제한돼 있다 — 조회로 확인한다. 활성: 개발(건)·개발(명)·후원금액 · 기준년월/기준일자/개발구분/법인/부서4·3·2·부서/브랜드/상위캠페인/캠페인/홍보방법/후원사업/후원사업2/성별/연령대/신규기존구분 축 · 후원기간대·후원기간대2·후원금액범위·후원금액대2·결제수단·회원구분·시도·후원약칭·중단/감액 사유·직전캠페인 축 · 공통브랜드·개발인입경로·캠페인유형(국내/해외)·캠페인유형2(사업/사례)·캠페인카테고리 축(캠페인 마스터 현재값) · 마케팅캠페인·마케팅 UTM·마케팅채널·후원구분 축(캠페인 마스터 현재값) · 목표(gl: 월 목표·실적·달성률) · 연도말 추세 참고치(ye: 부서 · yb: 후원사업2 · 모델 예측 아님). 🔴 md·gl·ye·yb 네 테이블은 서로 조인하지 않는다(관계 없음 · 질문마다 한 테이블만 쓴다).'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 🔴🔴 **개발구분 미지정 시 MSTR 개발 리포트 범위인 신규·증액·재후원(DVLP_DIV_CD IN (''1'',''2'',''4''))으로 한정하고 그 사실을 밝힌다.** 감액·후원중단은 사용자가 명시할 때만 포함하며 개발과 합산하지 않는다. (2) 🔴🔴 **「개발(건)」은 MSTR_DVLP_CNT(후원금액÷10,000 합)다** — 행 수(COUNT)나 MSTR_ROW_CNT 로 바꾸지 않는다. 답변에 「MSTR 기준」임을 밝힌다. (3) 🔴 **개발(명)은 COUNT(DISTINCT md.MBER_NO)로 그 그룹에서 직접 센다** — 하위 그룹 합으로 만들지 않는다. (4) 🔴 **기준년월 미지정 시 데이터에 존재하는 최신 기준년월 하나로 한정하고 밝힌다.** (5) 🔴 **GN_DW 지표와 섞지 않는다.** (6) **금액은 원 단위다.** (7) 적용 조건(그룹 미지정 시): 최신 기준년월 + 신규·증액·재후원으로 한정해 개발구분별 개발(건)·개발(명)·후원금액을 반환한다. (8) 🔴 metric 이름을 md 컬럼처럼 참조하지 않는다 — 정의식(ROUND(SUM(md.SPNSR_AMT_CNT), 4) 등)으로 집계한다. (9) 🆕 [O206-D] 개발(건)은 소수 4자리로 반올림해 낸다 — ROUND(SUM(md.SPNSR_AMT_CNT), 4). (10) 🆕 [O206-D] 「신규/기존」 구분은 md.NEW_OLD_DIV_NM 으로 그룹·필터한다 — 가입일이 없다고 산출 불가로 답하지 않는다.
  🆕 [O207 규칙] (11) 🔴🔴 **md·gl·ye·yb 는 서로 조인하지 않는다** — 개발 실적의 축 분해(후원기간대·결제수단·시도·사유 등)는 md, 목표·달성률은 gl, 부서별·전사 연도말 예측·전망은 ye, 후원사업별 연도말 예측·전망은 yb(목표 없음) 하나만 쓴다. (12) 🔴🔴 **목표는 gl·ye 로만 낸다** — 실질 목표는 신규만 있으므로 목표·달성률·연도말 전망 질문은 개발구분 신규(DVLP_DIV_CD = ''1'')로 고정하고 그 사실을 밝힌다. (13) 🔴🔴 **ye 의 연도말 값은 「추세 참고치(모델 예측 아님)」다** — 산식(마감월 실적 + 남은 월 × 직전 3개 마감월 평균)과 산출 기준월(ye.AS_OF_MT)을 함께 반환하고, 연도 미지정 시 ye.AS_OF_MT 가 속한 연도로 한정한다. 진행 중인 최신 기준월(gl.CLOSED_MONTH_YN = ''N'')의 실적은 부분 실적이라 달성률 비교에서 따로 밝힌다. 🆕 [O207-C] 누계·연간 달성률은 마감월(gl.CLOSED_MONTH_YN = ''Y'')만으로 계산한다 — 미래 월 목표와 부분 실적을 함께 더하면 달성률이 낮게 왜곡된다. (14) 🔴 중단·감액 사유(md.CANCL_RDCAMT_RSN_NM)는 개발구분을 후원중단 또는 감액 하나로 고정해 묻는다 — 두 개발구분의 사유 코드 체계가 다르다. (15) 🔴 후원금액범위(md.SPNSR_AMT_NM)는 원천 판정값이다 — 「개발금액 구간」 질문은 후원금액대2(md.SPNSR_AMT2_NM)로 답한다. (16) 🔴 부서별 질문에서 목표 없는 부서는 달성률을 만들지 않고 「목표 미등록」으로 밝힌다. 🆕 [O212 분류 축 · 대분류 우선] (17) 🔴🔴 🆕 [O212-B 원천 컬럼명 원칙] 질문의 분류 이름은 원천 컬럼 COMMENT 의 한글 이름 그대로 축에 대응한다 — 「브랜드」 = md.BRND_NM · 「공통브랜드」 = md.CMMN_BRND_NM · 「캠페인유형」 = md.CMPGN_TYPE1_NM(국내/해외) · 「캠페인유형2」 = md.CMPGN_TYPE2_NM(사업/사례) · 「캠페인카테고리」·「주요캠페인」 = md.CMPGN_CTGR_NM · 「개발인입경로」·「인입경로」 = md.DVLP_INFLOW_PATH_NM. 묻지 않은 분류 축을 함께 GROUP BY 하지 않는다. (18) 🔴 네 분류 축은 캠페인 마스터 현재값이다 — 축 이름에 「공통브랜드」 등 업무명을 그대로 별칭으로 쓴다. (19) 「마케팅캠페인」 = md.MK_CMPGN_NM · 「UTM」 = md.MKTG_UTM_NM · 「마케팅채널」 = md.MKTG_CHANNEL_NM · 「후원구분」 = md.SPNSR_DIV_NM(모두 캠페인 마스터 현재값). 🔴 UTM 은 일부 캠페인에만 값이 있다 — UTM별 표를 낼 때 NULL 버킷을 함께 보여주고 전체 합계는 축 없이 따로 낸다.'
  AI_VERIFIED_QUERIES (
    vqr_o207_ye_trend_dept4 AS (
      QUESTION '구분_팀별 올해 연도말 신규 개발 예측(목표 대비)'
      VERIFIED_BY '(O207 · 원천 직접 집계 대조 · 2026 신규 전사 참고치 250,243.3201건 / 목표 352,702건 = 70.9% · 산출 기준월 202610)'
      SQL 'SELECT ye.DEPT4_NM AS "전망 구분_팀", MAX(ye.AS_OF_MT) AS "산출 기준월", SUM(ye.YY_GOAL_CNT) AS "연 개발 목표(건)", ROUND(SUM(ye.CLOSED_ACT_CNT), 4) AS "마감월 누적 실적(건)", ROUND(SUM(ye.LAST3_AVG_CNT), 4) AS "직전 3개월 평균(건)", ROUND(SUM(ye.YE_TREND_CNT), 4) AS "연도말 개발 추세 참고치(건)", ROUND(DIV0(SUM(IFF(ye.YY_GOAL_CNT > 0, ye.YE_TREND_CNT, 0)), SUM(ye.YY_GOAL_CNT)) * 100, 1) AS "연 목표 대비 추세(%)" FROM ye WHERE ye.DVLP_DIV_CD = ''1'' AND ye.STRD_YY = LEFT(ye.AS_OF_MT, 4) GROUP BY ROLLUP(ye.DEPT4_NM) ORDER BY 6 DESC NULLS FIRST'
    ),
    vqr_o207_goal_month AS (
      QUESTION '올해 마감월까지 월별 신규 개발 목표와 실적, 달성률'
      VERIFIED_BY '(O207 · 2026-01 달성률 93.3% · 2026-09 76.5% · 마감월 누계 70.1% 원천 대조 · O207-C 마감월 한정 교정)'
      SQL 'SELECT gl.STRD_MT AS "목표 기준년월", SUM(gl.GOAL_CNT) AS "개발 목표(건)", ROUND(SUM(gl.ACT_CNT), 4) AS "목표 대비 실적(건)", ROUND(DIV0(SUM(IFF(gl.GOAL_CNT > 0, gl.ACT_CNT, 0)), SUM(gl.GOAL_CNT)) * 100, 1) AS "목표 달성률(%)" FROM gl WHERE gl.DVLP_DIV_CD = ''1'' AND gl.CLOSED_MONTH_YN = ''Y'' AND gl.STRD_YY = (SELECT LEFT(MAX(STRD_MT), 4) FROM gl WHERE CLOSED_MONTH_YN = ''Y'') GROUP BY ROLLUP(gl.STRD_MT) ORDER BY 1 NULLS LAST'
    ),
    vqr_o207_stop_reason AS (
      QUESTION '최신 기준월 후원중단 사유별 개발(건)·개발(명)'
      VERIFIED_BY '(O207 · 사유 = MM005 · 후원중단 한정)'
      SQL 'SELECT md.CANCL_RDCAMT_RSN_NM AS "중단사유", ROUND(SUM(md.SPNSR_AMT_CNT), 4) AS "개발(건)", COUNT(DISTINCT md.MBER_NO) AS "개발(명)" FROM md WHERE md.DVLP_DIV_CD = ''5'' AND md.STRD_MT = (SELECT MAX(STRD_MT) FROM md) GROUP BY md.CANCL_RDCAMT_RSN_NM ORDER BY 2'
    )
  );

-- SV_ML_LTV_FORECAST ← 22_ML_SV_DDL.sql
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_LTV_FORECAST
  TABLES (
    lf AS GN_DW.SERVING.ML_LTV_FORECAST_V
      PRIMARY KEY (STDR_MT, LTV_TYPE, SERIES_CD, TS)
      WITH SYNONYMS ('LTV 예측', '생애가치 예측', '후원 LTV 예측', '채널별 후원금액 예측')
      COMMENT = '마케팅채널·캠페인 LTV 월별 시계열 예측 분석 (base: SERVING.ML_LTV_FORECAST_V). [Grain: 기준월 × LTV유형 × 계열 × 예측월]. [활성 지표: 예측 금액(원)]. [주의: 마케팅채널 회원평균 후원금액과 캠페인 월간 후원금액 분리]. [원천: ML LTV모델 2종 → SERVING.ML_LTV_FORECAST_V].'
  )
  DIMENSIONS (
    lf.STDR_MT AS lf.STDR_MT
      WITH SYNONYMS ('기준월', '예측 기준월')
      COMMENT = '모델 실행 기준월(YYYYMM). 여러 기준월 합산 금지. 🔴 실제값은 열거하지 않는다(실행할 때마다 늘어난다) — 조회해서 확인한다.',
    lf.LTV_TYPE AS lf.LTV_TYPE
      WITH SYNONYMS ('LTV 유형', 'LTV 구분')
      COMMENT = 'LTV 유형. 실제값: ''MKTG_CHANNEL_AVG_MEMBER''(마케팅채널 회원평균 후원금액)·''CMPGN_TOTAL''(캠페인 월간 후원금액). 🔴🔴 **반드시 하나로 고정한다** — 하나는 1인당 평균이고 하나는 총액이라 자리수가 크게 다르고, 계열 축(마케팅채널 ↔ 캠페인)도 다르다.',
    lf.LTV_TYPE_NAME AS lf.LTV_TYPE_NAME
      WITH SYNONYMS ('LTV 유형명')
      COMMENT = 'LTV 유형 라벨. 실제값 2종: ''마케팅채널 회원평균 후원금액''·''캠페인 월간 후원금액''.',
    lf.SERIES_CD AS lf.SERIES_CD
      WITH SYNONYMS ('계열코드', '마케팅채널코드', '캠페인코드')
      COMMENT = 'degen: 계열 코드. 🔴LTV유형에 따라 마케팅채널 코드(MKTG_CHANNEL) 또는 캠페인코드(CMPGN_CD)다 — 유형 없이 해석하지 말 것.',
    lf.SERIES_NAME AS lf.SERIES_NAME
      WITH SYNONYMS ('계열명', '마케팅채널', '채널명', '캠페인명')
      COMMENT = '계열 라벨(마케팅채널명 / 캠페인명 · 캠페인 마스터). 🟢 이 SV 에서는 라벨 미도달이 없다(2026-10-02 실측).',
    lf.TS AS lf.TS
      WITH SYNONYMS ('예측월', '예측 시점')
      COMMENT = '예측 대상 월(월 시작일). 기준월과 다르다.'
  )
  METRICS (
    lf.AVG_FORECAST_LTV AS AVG(lf.FORECAST)
      WITH SYNONYMS ('평균 LTV 예측', 'LTV 예측치')
      COMMENT = '예측값 평균(원). 🔴LTV유형을 고정한 상태에서만 의미가 있다. 회원평균 유형에서는 「회원 1인당 평균의 평균」이므로 회원수 가중이 아니다.',
    lf.TOTAL_FORECAST_LTV AS SUM(lf.FORECAST)
      WITH SYNONYMS ('LTV 예측 합계', '예측 후원금액 합계')
      COMMENT = '예측값 합계(원). 🔴🔴 **회원평균 유형(MKTG_CHANNEL_AVG_MEMBER)에서는 합산하지 않는다** — 1인당 평균을 더한 값은 업무 의미가 없다. 총액 유형(CMPGN_TOTAL)에서만 합산한다.',
    lf.FORECAST_LOWER AS AVG(lf.LOWER_BOUND)
      WITH SYNONYMS ('LTV 예측 하한')
      COMMENT = '95% 신뢰구간 하한 평균(원).',
    lf.FORECAST_UPPER AS AVG(lf.UPPER_BOUND)
      WITH SYNONYMS ('LTV 예측 상한')
      COMMENT = '95% 신뢰구간 상한 평균(원).',
    lf.FORECAST_MONTHS AS COUNT(DISTINCT lf.TS)
      WITH SYNONYMS ('예측 개월수')
      COMMENT = '예측 대상 개월 수.',
    lf.SERIES_COUNT AS COUNT(DISTINCT lf.SERIES_CD)
      WITH SYNONYMS ('계열 수', '채널 수', '캠페인 수')
      COMMENT = '예측 대상 계열 수.'
  )
  COMMENT = 'ML LTV 월별 예측 SV(2종). base=SERVING.ML_LTV_FORECAST_V. 🔴🔴 예측치이며 실적이 아니다. 🔴 머신러닝은 테스트 단계이며 모델·구조가 교체될 수 있다. 🔴🔴 **LTV_TYPE 을 반드시 하나로 고정한다** — ''MKTG_CHANNEL_AVG_MEMBER''는 마케팅채널의 **회원 1인당 평균 후원금액** 예측이고 ''CMPGN_TOTAL''은 캠페인의 **월간 후원금액 총액** 예측이다. 두 유형은 의미·자리수·계열 축이 달라 합산·순위 비교를 함께 하면 반드시 틀린다. ⚠️ **원천 표기와 데이터가 다르다** — 원천은 두 테이블 모두 계열 컬럼을 MKTG_CHANNEL(채널)로 이름 붙였으나 CMPGN_TOTAL 쪽 값은 캠페인코드다 ⇒ 「채널별」 질문은 MKTG_CHANNEL_AVG_MEMBER 로, 「캠페인별 후원금액 예측」은 CMPGN_TOTAL 로 답한다(원천 확인 중). 🔴 회원평균 유형을 합산하지 않는다. 활성: 예측 평균/합계·신뢰구간·예측개월수·계열수 · LTV유형/계열/예측월 축. 비활성: 회원 단위 LTV(원천 grain 이 계열) · 계열당 LTV 스코어(원천 폐기) · 실적 대비 정확도.'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 🔴🔴 **LTV_TYPE 을 WHERE 로 하나 고정한다.** 두 유형을 한 표에 섞지 않는다 — 하나는 1인당 평균, 하나는 총액이며 계열 축이 다르다. 「채널별/마케팅채널별 (회원평균) 후원금액·LTV」는 ''MKTG_CHANNEL_AVG_MEMBER'', 「캠페인별 후원금액 예측」은 ''CMPGN_TOTAL'' 이다. 어느 쪽인지 불분명하면 사용자에게 확인하거나 두 표로 나눠 각 정의를 밝힌다. (2) 🔴🔴 **회원평균 유형에서 TOTAL_FORECAST_LTV(합계)를 쓰지 않는다** — 1인당 평균을 더한 값은 의미가 없다. 그 유형에서는 AVG_FORECAST_LTV 를 쓴다. (3) 🔴 **기준월을 여러 개 합산하지 않는다** — 미지정 시 최신 기준월 하나로 한정하고 밝힌다. (4) 🔴 **예측치임과 테스트 단계임을 밝힌다.** (5) **단위는 원이다.** 개발금액 예측(만원)과 합산하지 않는다. (6) 🔴 **「LTV 스코어·과거 누적 LTV·상위캠페인 LTV」를 물으면 SQL 을 만들지 않는다** — 원천 폐기로 제공하지 않는다고 답하고 이 SV 의 월별 예측을 대안으로 안내한다. (7) 적용 조건(기준월·유형 미지정 시): 최신 기준월 + LTV_TYPE=''MKTG_CHANNEL_AVG_MEMBER'' 로 한정해 계열별 평균 예측 상위를 반환하고, 다른 유형이 있음을 안내한다.'
  AI_VERIFIED_QUERIES (
    vqr_o198_top_channel_avg AS (
      QUESTION '마케팅채널별 회원평균 후원금액 예측 상위 10(최신 기준월)'
      VERIFIED_BY '(DW = O198)'
      SQL 'SELECT lf.SERIES_NAME, AVG(lf.FORECAST) AS AVG_FORECAST_LTV FROM lf WHERE lf.LTV_TYPE = ''MKTG_CHANNEL_AVG_MEMBER'' AND lf.STDR_MT = (SELECT MAX(lf.STDR_MT) FROM lf) GROUP BY lf.SERIES_NAME ORDER BY AVG_FORECAST_LTV DESC NULLS LAST LIMIT 10'
    )
  );

-- SV_ML_ONCE_CONVERSION ← 22_ML_SV_DDL.sql
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_ONCE_CONVERSION
  TABLES (
    oc AS GN_DW.SERVING.ML_ONCE_CONVERSION_V
      PRIMARY KEY (STDR_MT, ONCE_MBER_NO)
      WITH SYNONYMS ('정기전환 예측', '일시후원 전환 예측', '정기후원 전환 가능성', '일시회원 전환')
      COMMENT = '일시후원회원의 정기후원 전환 ML 예측 분석 (base: SERVING.ML_ONCE_CONVERSION_V). [Grain: 기준월 × 일시후원회원(원천 다중 예측행 포함)]. [활성 지표: 전환확률·모델 전환분류 회원수]. [주의: 예측치이며 실적 아님, 회원당 여러 예측행]. [원천: ML 전환예측 결과 → SERVING.ML_ONCE_CONVERSION_V].'
  )
  DIMENSIONS (
    oc.STDR_MT AS oc.STDR_MT
      WITH SYNONYMS ('기준월', '예측 기준월', '모델 실행월')
      COMMENT = '모델 실행 기준월(YYYYMM 문자열). 다른 ML SV 와 같은 의미다. 🔴 여러 기준월 합산 금지. 🔴 실제값은 열거하지 않는다(실행할 때마다 늘어난다) — 조회해서 확인한다.',
    oc.STDR_MONTH_KEY AS oc.STDR_MONTH_KEY
      WITH SYNONYMS ('기준연월')
      COMMENT = '기준연월(YYYYMM 정수). 연·월 필터에 쓴다.',
    oc.ONCE_MBER_NO AS oc.ONCE_MBER_NO
      WITH SYNONYMS ('일시후원회원번호', '일시회원번호', '일시회원')
      COMMENT = '일시후원회원번호. 🔴정기회원 회원번호(MBER_NO)와 다른 번호체계다 — 다른 회원 SV 와 조인·대조하지 않는다. 회원수는 이 축의 중복제거로 센다.',
    oc.CONVERT_CLASS AS oc.CONVERT_CLASS
      WITH SYNONYMS ('전환 예측 판정', '전환 클래스')
      COMMENT = '정기후원 전환 예측의 모델 기본 판정. 실제값 2종: ''0''(비전환 예측)·''1''(전환 예측). 🔴모델 기본 임계(0.5)의 판정이며 업무 판정선은 미확정이다 ⇒ 「전환할 회원」이라 단정하지 말고 「모델이 전환으로 분류한 회원」으로 답한다.',
    oc.PREDICTION_HAS_ERROR AS oc.PREDICTION_HAS_ERROR
      WITH SYNONYMS ('예측 오류 여부')
      COMMENT = 'TRUE=모델 산출 로그에 오류가 기록됐다. 품질 점검용.',
    oc.SEX_NAME AS oc.SEX_NAME
      WITH SYNONYMS ('성별', '일시회원 성별')
      COMMENT = '일시회원 성별 라벨(코드사전 CM013 — 내국/외국인 구분 포함). 🔴 현재 회원 마스터 값이며 가입 시점 값이 아니다. 라벨이 없는 회원은 NULL.',
    oc.MEMBER_DIV_NAME AS oc.MEMBER_DIV_NAME
      WITH SYNONYMS ('회원구분', '개인/단체', '일시회원 구분')
      COMMENT = '일시회원 회원구분 라벨(개인·단체·기업 등). 🔴 현재 회원 마스터 값이다. 값 목록은 SELECT DISTINCT 로 조회한다.',
    oc.REGIST_DEPT_NAME AS oc.REGIST_DEPT_NAME
      WITH SYNONYMS ('등록부서', '일시회원 등록부서', '부서')
      COMMENT = '일시회원을 등록한 부서명(조직 차원 DEPARTMENT). 🔴 등록 부서이며 실적부서·귀속부서가 아니다 — 부서 목표·실적과 대조하지 않는다.'
  )
  METRICS (
    oc.PREDICTED_ONCE_MEMBERS AS COUNT(DISTINCT oc.ONCE_MBER_NO)
      WITH SYNONYMS ('예측 대상 일시회원수', '일시회원수')
      COMMENT = '예측 대상 일시후원회원수(중복제거). 🔴전체 일시후원회원수가 아니다 — 이 SV 의 모집단이다. 비율을 낼 때 분모로 쓰고 그 사실을 밝힌다.',
    oc.MODEL_CONVERT_MEMBERS AS COUNT(DISTINCT CASE WHEN oc.CONVERT_CLASS = '1' THEN oc.ONCE_MBER_NO END)
      WITH SYNONYMS ('모델 전환분류 회원수', '전환 예측 회원수')
      COMMENT = '모델이 정기후원 전환으로 분류한 일시회원수(중복제거 · 예측행 중 하나라도 전환이면 포함). 🔴실제 전환 회원수가 아니다.',
    oc.AVG_CONVERT_PROB AS AVG(oc.CONVERT_PROB)
      WITH SYNONYMS ('평균 전환확률', '전환확률')
      COMMENT = '정기후원 전환 예측확률 평균(0~1). 🔴합산하지 않는다. 🔴회원당 다중 예측행이 섞인 행 가중 평균이다.',
    oc.MAX_CONVERT_PROB AS MAX(oc.CONVERT_PROB)
      WITH SYNONYMS ('최대 전환확률')
      COMMENT = '전환확률 최대값. 전환 가능성 상위 회원 정렬에 쓴다.'
  )
  COMMENT = 'ML 일시후원회원 정기후원 전환 예측 SV. base=SERVING.ML_ONCE_CONVERSION_V. 🔴🔴 원천이 같은 기준월에 회원당 **여러 개의 서로 다른 예측행**을 담고 있다 — 원천에 **실행 시각·실행순번 컬럼이 없어 어느 행이 최신인지 판별할 수 없다**(현업 결정 45 의 「최신만 남기고 실행순번 추가」는 집행 불가 ⇒ **현행 유지로 확정** · #1). 따라서 행 수 기반 수치와 **확률 평균은 여러 실행이 섞인 값**이다 — 회원 수는 반드시 중복제거 지표로 답하고 그 사실을 밝힌다. 🔴🔴 예측치이며 실적이 아니다 — 실제 정기 전환 실적과 같은 표에 합산하지 않는다. 🔴 머신러닝은 테스트 단계이며 모델·구조가 교체될 수 있다. 🔴 **STDR_MT 는 모델 실행 기준월이다**. 관측월·가입월·가입경과월 축은 없다. 기준월 미지정 시 최신 기준월 하나로 한정한다. 🔴 예측 지평(몇 개월 안에 전환)을 숫자로 발행하지 않는다 — 원천 테이블 설명은 6개월이나 원천 프로시저가 인도되지 않아 정의를 확인할 수 없다. 🔴 일시회원번호는 정기회원번호와 체계가 달라 다른 회원 SV 와 조인하지 않는다. 🔴 업무 판정선은 미확정이다. 활성: 예측 대상 일시회원수·모델 전환분류 회원수·전환확률 평균/최대 · 기준월/판정 축 · 성별·회원구분·등록부서(현재 마스터 스냅샷). 비활성: 가입월·관측월·가입경과월 축(원천 교체로 폐기) · 실제 전환 실적 대비 정확도 · 가입경로 축 · 전환 후 약정금액.'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "연 편성예산(원)" · "집행율(%)" · "개발(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. ORDER BY·GROUP BY 에는 원래 식 또는 순번을 쓴다(한글 별칭을 쓸 때는 큰따옴표 그대로). 이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다. [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. 중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.
  핵심 규칙: (1) 🔴🔴 **예측과 실적을 한 표에 합산하지 않는다.** (2) 🔴 **기준월(STDR_MT)을 여러 개 합산하지 않는다** — 미지정 시 최신 기준월(MAX(STDR_MT)) 하나로 한정하고 그 기준월을 밝힌다. (3) 🔴🔴 **회원수는 PREDICTED_ONCE_MEMBERS·MODEL_CONVERT_MEMBERS(중복제거)를 쓴다** — 원천에 회원당 여러 예측행이 있어 COUNT(*) 는 과대다. (4) 🔴 **가입월·관측월·가입 후 경과월별 분해를 물으면 SQL 을 만들지 않는다** — 원천 구조 교체로 해당 축이 없다고 답하고, 성별·회원구분·등록부서별 분해를 대안으로 안내한다. (5) 🔴 **「전환할 회원」이라 단정하지 않는다** — 「모델이 전환으로 분류한 회원」으로 표현하고, 사용자가 확률 기준을 지정하면 그 기준을 밝힌다. (6) 🔴 **예측 지평(몇 개월 안에)을 숫자로 답하지 않는다.** (7) **확률은 평균·최대만 쓴다.** 평균은 다중 예측행이 섞인 값임을 밝힌다. (8) **비율의 분모는 PREDICTED_ONCE_MEMBERS 이며 전체 일시후원회원이 아님을 밝힌다.** (9) **답변에 예측치임과 테스트 단계임을 밝힌다.** (10) 적용 조건(기간·그룹 미지정 시): 최신 기준월로 한정해 예측 대상 일시회원수·모델 전환분류 회원수·평균 전환확률을 반환하고, 회원구분·등록부서별 분해가 가능함을 안내한다. (11) 🔴 metric 이름(MODEL_CONVERT_MEMBERS·PREDICTED_ONCE_MEMBERS·AVG_CONVERT_PROB)을 oc 컬럼처럼 참조하지 않는다 — 정의식(COUNT(DISTINCT CASE WHEN oc.CONVERT_CLASS = ''1'' THEN oc.ONCE_MBER_NO END) 등)으로 집계한다.'
  AI_VERIFIED_QUERIES (
    vqr_o198_once_member_div AS (
      QUESTION '회원구분별 모델 전환분류 회원수와 예측 대상 일시회원수, 평균 전환확률(최신 기준월)'
      VERIFIED_BY '(DW = O198)'
      SQL 'SELECT oc.MEMBER_DIV_NAME, COUNT(DISTINCT CASE WHEN oc.CONVERT_CLASS = ''1'' THEN oc.ONCE_MBER_NO END) AS MODEL_CONVERT_MEMBERS, COUNT(DISTINCT oc.ONCE_MBER_NO) AS PREDICTED_ONCE_MEMBERS, AVG(oc.CONVERT_PROB) AS AVG_CONVERT_PROB FROM oc WHERE oc.STDR_MT = (SELECT MAX(oc.STDR_MT) FROM oc) GROUP BY oc.MEMBER_DIV_NAME ORDER BY PREDICTED_ONCE_MEMBERS DESC'
    )
  );

-- SV_ML_INC_CAMPAIGN ← 23_ML_INC_MKTG_CMPGN_DDL.sql
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_INC_CAMPAIGN
  TABLES (
    ic AS GN_DW.SERVING.ML_INC_BY_MKTG_CMPGN_V
      PRIMARY KEY (STDR_MT, MBER_NO)
      WITH SYNONYMS ('증액 예측 캠페인', '캠페인별 증액 예측', '마케팅캠페인 증액 예측')
      COMMENT = 'ML 회원 증액 예측을 MSTR 마케팅캠페인에 귀속한 표(base: SERVING.ML_INC_BY_MKTG_CMPGN_V). [Grain: 기준월 × 회원]. [귀속: 기준월이 속한 해 1월~기준월 MSTR 개발(신규·증액·재후원) 중 최근 1건의 마케팅캠페인]. [원천: ML 증액 예측 → SERVING.ML_MEMBER_RISK_V · MSTR 이관 → SERVING.MSTR_SPNSR_DVLP_V].'
  )
  DIMENSIONS (
    ic.STDR_MT AS ic.STDR_MT
      WITH SYNONYMS ('기준월', '예측 기준월', '모델 실행월')
      COMMENT = '모델 실행 기준월(YYYYMM 문자열). 🔴 여러 기준월을 합산하지 않는다 — 미지정 시 최신 기준월 하나로 한정한다. 실제값은 조회로 확인한다.',
    ic.MBER_NO AS ic.MBER_NO
      WITH SYNONYMS ('회원번호', '회원')
      COMMENT = '회원번호. 회원수는 이 축의 중복제거로 센다.',
    ic.MK_CMPGN_NM AS ic.MK_CMPGN_NM
      WITH SYNONYMS ('마케팅캠페인', '마케팅캠페인명', '마케팅 캠페인')
      COMMENT = '회원에 귀속한 마케팅캠페인명(MSTR 개발 이력 기준 · 회원당 1개). 🔴 NULL 은 두 가지다 — IS_LINKED = FALSE 이면 그 해 MSTR 개발 이력이 없어 귀속할 수 없는 회원, IS_LINKED = TRUE 이면 귀속한 개발행의 캠페인에 마케팅캠페인 값이 없는 회원이다. 둘 다 캠페인 순위에서 빼고 회원수를 따로 밝힌다.',
    ic.CMMN_BRND_NM AS ic.CMMN_BRND_NM
      WITH SYNONYMS ('공통브랜드')
      COMMENT = '귀속 개발행의 공통브랜드(캠페인 마스터 현재값).',
    ic.MKTG_CHANNEL_NM AS ic.MKTG_CHANNEL_NM
      WITH SYNONYMS ('마케팅채널')
      COMMENT = '귀속 개발행의 마케팅채널(캠페인 마스터 현재값).',
    ic.CMPGN_CTGR_NM AS ic.CMPGN_CTGR_NM
      WITH SYNONYMS ('캠페인카테고리', '주요캠페인')
      COMMENT = '귀속 개발행의 캠페인카테고리(캠페인 마스터 현재값).',
    ic.ATTR_DVLP_DIV_NM AS ic.ATTR_DVLP_DIV_NM
      WITH SYNONYMS ('귀속 개발구분')
      COMMENT = '귀속에 쓴 개발행의 개발구분(신규·증액·재후원).',
    ic.ATTR_STRD_MT AS ic.ATTR_STRD_MT
      WITH SYNONYMS ('귀속 개발월')
      COMMENT = '귀속에 쓴 개발행의 MSTR 기준년월(YYYYMM).',
    ic.INC_CLASS AS ic.INC_CLASS
      WITH SYNONYMS ('증액 예측 판정')
      COMMENT = '모델 기본 임계(0.5) 판정. 실제값 2종: ''0''·''1''. 🔴 ''1'' 회원이 극소수라 캠페인 비교에 쓰지 않는다 — 비교는 기대 증액 회원수·평균 증액확률로 한다.',
    ic.IS_LINKED AS ic.IS_LINKED
      WITH SYNONYMS ('캠페인 귀속 여부')
      COMMENT = 'TRUE = 마케팅캠페인에 귀속된 예측 회원. 분모를 밝힐 때 쓴다.'
  )
  METRICS (
    ic.PREDICTED_MEMBERS AS COUNT(DISTINCT ic.MBER_NO)
      WITH SYNONYMS ('예측 대상 회원수')
      COMMENT = '증액 예측 대상 회원수(명 · 중복제거). 전체 회원수가 아니다.',
    ic.EXPECTED_INC_MEMBERS AS SUM(ic.INC_PROB)
      WITH SYNONYMS ('기대 증액 회원수', '예상 증액 회원수')
      COMMENT = '모델 기대 증액 회원수(명) = 증액확률의 합. 회원 grain 이라 캠페인별 값은 더해도 된다(같은 기준월 안). 🔴 「10월 증액 건수」가 아니다 — 모델 예측 기간 안에 증액할 것으로 기대되는 회원 수다.',
    ic.AVG_INC_PROB AS AVG(ic.INC_PROB)
      WITH SYNONYMS ('평균 증액확률', '증액확률')
      COMMENT = '증액확률 평균(0~1 · 표기는 %로). 회원 수가 적은 캠페인은 값이 흔들린다 — 예측 대상 회원수와 함께 보인다.',
    ic.MODEL_INC_MEMBERS AS COUNT(DISTINCT CASE WHEN ic.INC_CLASS = '1' THEN ic.MBER_NO END)
      WITH SYNONYMS ('모델 증액분류 회원수')
      COMMENT = '모델이 증액으로 분류한 회원수(명). 극소수다.'
  )
  COMMENT = 'ML 증액 예측 × 마케팅캠페인 SV. base=SERVING.ML_INC_BY_MKTG_CMPGN_V. 「증액이 높을 것으로 예상되는 마케팅캠페인·공통브랜드·마케팅채널·캠페인카테고리」 질문에 쓴다. 🔴🔴 머신러닝 예측치이며 실적이 아니다 — MSTR 증액 실적(SV_MSTR_SPNSR_DVLP)과 같은 표에 합산하지 않고 표를 나눈다. 🔴 머신러닝은 테스트 단계다. 🔴🔴 예측은 회원 단위 증액확률이다 — 캠페인 값은 그 캠페인에 귀속한 회원들의 확률을 모은 것이고 「N월 증액 건수」 예측이 아니다. 🔴 귀속은 Agent 데이터 규칙이다(그 해 MSTR 최근 개발 1건의 마케팅캠페인) · 모델이 캠페인을 학습한 것이 아니다. 🔴 귀속 불가 회원(MK_CMPGN_NM NULL)은 순위에서 빼고 그 회원수를 따로 밝힌다. 활성: 예측 대상 회원수·기대 증액 회원수·평균 증액확률·모델 증액분류 회원수 · 기준월·마케팅캠페인·공통브랜드·마케팅채널·캠페인카테고리 축. 비활성: 증액 금액 예측(원천에 없음) · 월별 증액 건수 예측(원천에 없음).'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥에서 쓰는 차원은 그 CTE 의 SELECT 목록에 먼저 넣는다. (다) 날짜 필터는 이 시맨틱 뷰에 선언된 차원 이름만 쓴다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다(WITH SYNONYMS 첫 항목 · 단위 괄호). 영문 식별자를 출력 컬럼명으로 남기지 않는다.
  핵심 규칙: (1) 기준월 미지정 시 최신 기준월(MAX(ic.STDR_MT)) 하나로 한정하고 밝힌다 — 비상관 CTE 로 구해 CROSS JOIN 한다. (2) 「증액이 높을 캠페인 상위 N」 = ic.MK_CMPGN_NM IS NOT NULL 로 한정하고 마케팅캠페인별 SUM(ic.INC_PROB) 내림차순 상위 N 을 반환한다. 열 = 마케팅캠페인 · 예측 대상 회원수 COUNT(DISTINCT ic.MBER_NO) · 기대 증액 회원수 ROUND(SUM(ic.INC_PROB),1) · 평균 증액확률(%) ROUND(AVG(ic.INC_PROB)*100,2) · 구성비(%) = 그 캠페인 SUM(INC_PROB) ÷ 귀속 회원 전체 SUM(INC_PROB) × 100(소수 2자리 · 분모는 SQL 로 구한다). (3) 귀속 불가 회원수(ic.MK_CMPGN_NM IS NULL 의 COUNT DISTINCT)와 전체 예측 대상 회원수를 별도 행 또는 별도 쿼리로 함께 반환한다. (4) 평균 증액확률 순위를 요청받으면 예측 대상 회원 100명 이상 캠페인으로 한정하고 그 하한을 밝힌다. (5) 공통브랜드·마케팅채널·캠페인카테고리별도 같은 방식이다. (6) 🔴 실적 SV 와 조인하지 않는다.';

-- SV_ML_CHURN_CAMPAIGN ← 25_ML_CHURN_CMPGN_CTGR_DDL.sql
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_CHURN_CAMPAIGN
  TABLES (
    cc AS GN_DW.SERVING.ML_CHURN_BY_CMPGN_CTGR_V
      WITH SYNONYMS ('중단 예측 캠페인', '캠페인카테고리별 중단 위험 회원', '중단 위험 회원 캠페인 매칭')
      COMMENT = 'ML 중단 예측을 기준월 말 활동 후원 캠페인카테고리에 미리 결합한 표(base: SERVING.ML_CHURN_BY_CMPGN_CTGR_V). [Grain: 기준월 × 회원 × 캠페인카테고리]. [주의: 회원당 여러 행 · 회원수 중복제거]. [원천: GN_DW.ML → SERVING.ML_MEMBER_RISK_V · SERVING.ML_SPONSOR_RISK_V · CRM → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN].'
  )
  DIMENSIONS (
    cc.STDR_MT AS cc.STDR_MT
      WITH SYNONYMS ('기준월', '예측 기준월', '활동 기준월')
      COMMENT = '모델 실행 기준월(YYYYMM 문자열) = 활동 판정 기준월. 🔴 여러 기준월을 합산하지 않는다 — 미지정 시 최신 기준월 하나로 한정한다.',
    cc.MBER_NO AS cc.MBER_NO
      WITH SYNONYMS ('회원번호', '회원')
      COMMENT = '회원번호. 회원수는 이 축의 중복제거로 센다.',
    cc.CMPGN_CTGR_NM AS cc.CMPGN_CTGR_NM
      WITH SYNONYMS ('캠페인카테고리', '캠페인 카테고리', '주요캠페인')
      COMMENT = '기준월 말 활동 중인 후원약정의 캠페인카테고리(MM294 · 적재 시점 동결값). 예: 고려인캠페인. 실제값은 조회로 확인한다.',
    cc.HAS_MEMBER_PRED AS cc.HAS_MEMBER_PRED
      WITH SYNONYMS ('회원 단위 예측 대상 여부')
      COMMENT = 'TRUE = 회원 단위 중단 예측 대상 회원. 🔴 회원 단위 모델은 활동회원 일부만 예측한다 — 분모를 밝힐 때 쓴다.',
    cc.MEMBER_CHURN_GRADE AS cc.MEMBER_CHURN_GRADE
      WITH SYNONYMS ('중단위험 등급', '회원 중단위험 등급', '중단 가능성 등급')
      COMMENT = '회원 단위 중단위험 등급. 실제값 3종: ''고위험''·''주의''·''일반''. NULL = 회원 단위 예측 대상 아님(결측이 아니다).',
    cc.MEMBER_CHURN_CLASS AS cc.MEMBER_CHURN_CLASS
      WITH SYNONYMS ('회원 중단 예측 판정')
      COMMENT = '회원 단위 모델 판정. 실제값 2종: ''0''·''1''. NULL = 회원 단위 예측 대상 아님.',
    cc.HAS_SPONSOR_PRED AS cc.HAS_SPONSOR_PRED
      WITH SYNONYMS ('후원건 예측 대상 여부')
      COMMENT = 'TRUE = 이 카테고리 후원건이 후원건 단위 이탈 예측 대상.',
    cc.SPONSOR_CHURN_GRADE AS cc.SPONSOR_CHURN_GRADE
      WITH SYNONYMS ('후원건 이탈위험 등급', '캠페인 후원 이탈위험 등급')
      COMMENT = '이 카테고리 후원건 중 가장 높은 이탈위험 등급. 실제값 3종: ''고위험''·''주의''·''일반''. NULL = 후원건 예측 대상 아님.',
    cc.ACTIVE_SPNSR_CNT AS cc.ACTIVE_SPNSR_CNT
      WITH SYNONYMS ('활동 약정 수', '후원 중인 약정 수')
      COMMENT = '그 회원이 이 캠페인카테고리로 기준월 말 활동 중인 약정 수(건). 행마다 이미 집계된 값이다 — 명단에는 이 값을 그대로 쓰고 COUNT 로 다시 세지 않는다.'
  )
  METRICS (
    cc.ACTIVE_MEMBERS AS COUNT(DISTINCT cc.MBER_NO)
      WITH SYNONYMS ('활동회원수', '후원 중인 회원수')
      COMMENT = '기준월 말 활동 중인 고유 회원수(명 · 중복제거). 🔴 카테고리별 값을 더하면 다중 후원 회원이 중복된다.',
    cc.MEMBER_HIGH_RISK_MEMBERS AS COUNT(DISTINCT CASE WHEN cc.MEMBER_CHURN_GRADE = '고위험' THEN cc.MBER_NO END)
      WITH SYNONYMS ('중단 고위험 회원수', '중단 가능성 높은 회원수')
      COMMENT = '회원 단위 중단위험 등급이 고위험인 활동회원수(명 · 중복제거).',
    cc.MEMBER_PRED_MEMBERS AS COUNT(DISTINCT CASE WHEN cc.HAS_MEMBER_PRED THEN cc.MBER_NO END)
      WITH SYNONYMS ('회원 단위 예측 대상 회원수')
      COMMENT = '회원 단위 중단 예측 대상인 활동회원수(명 · 중복제거). 고위험 비율의 분모.',
    cc.SPONSOR_HIGH_RISK_MEMBERS AS COUNT(DISTINCT CASE WHEN cc.SPONSOR_HIGH_CNT > 0 THEN cc.MBER_NO END)
      WITH SYNONYMS ('후원건 고위험 회원수')
      COMMENT = '이 카테고리 후원건 중 고위험 후원건이 1건 이상인 활동회원수(명 · 중복제거).',
    cc.AVG_MEMBER_CHURN_PROB AS AVG(cc.MEMBER_CHURN_PROB)
      WITH SYNONYMS ('평균 중단확률')
      COMMENT = '회원 단위 중단확률 평균(0~1 · 표기는 %로 ×100). 회원당 여러 카테고리 행이 있으면 같은 회원 확률이 중복 반영된다 — 카테고리 하나로 거른 뒤 쓴다.'
  )
  COMMENT = 'ML 중단 예측 × 활동 후원 캠페인카테고리 SV. base=SERVING.ML_CHURN_BY_CMPGN_CTGR_V. [Grain: 기준월 × 회원 × 캠페인카테고리]. 「N월 활동회원 중 중단 가능성 높은 회원 중 ○○캠페인(카테고리) 후원 회원 · 회원번호 명단·수」 질문에 쓴다. [활성 지표: 활동회원수 · 중단 고위험 회원수 · 회원 단위 예측 대상 회원수 · 후원건 고위험 회원수 · 평균 중단확률]. [주의: 머신러닝 예측치이며 실적이 아니다 · 회원 단위 모델은 활동회원 일부만 예측한다 · 회원 단위 등급과 후원건 단위 등급은 서로 다른 모델이다 · 실적 SV 와 같은 표에 합산하지 않는다]. [원천: GN_DW.ML → SERVING.ML_MEMBER_RISK_V · SERVING.ML_SPONSOR_RISK_V · CRM → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN].'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥에서 쓰는 차원은 그 CTE 의 SELECT 목록에 먼저 넣는다. (다) 날짜 필터는 이 시맨틱 뷰에 선언된 차원 이름만 쓴다.
  [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다(WITH SYNONYMS 첫 항목 · 단위 괄호). 영문 식별자를 출력 컬럼명으로 남기지 않는다.
  핵심 규칙: (1) 기준월 미지정 시 최신 기준월(MAX(cc.STDR_MT)) 하나로 한정하고 밝힌다. (2) 「중단 가능성 높은 회원」의 기본 = 회원 단위 등급 cc.MEMBER_CHURN_GRADE = ''고위험''. 질문이 「그 캠페인 후원의 이탈 위험」을 물으면 cc.SPONSOR_HIGH_CNT > 0 을 쓴다 — 어느 기준인지 표 제목에 밝힌다. (3) 캠페인카테고리는 cc.CMPGN_CTGR_NM = ''<값>'' 으로 거른다. (4) 명단 요청 = 회원번호 · 회원 중단확률(%) ROUND(cc.MEMBER_CHURN_PROB*100,2) · 회원 중단위험 등급 · 후원건 이탈위험 등급 · 활동 약정 수 cc.ACTIVE_SPNSR_CNT(값 그대로 · COUNT 금지) 를 회원번호 중복 없이 반환하고 중단확률 내림차순으로 정렬한다. (5) 명단과 함께 같은 기준월·카테고리의 활동회원수 · 회원 단위 예측 대상 회원수 · 고위험 회원수를 분모로 반환한다 — 🔴 분모 집계에는 등급 조건(MEMBER_CHURN_GRADE = ''고위험'')을 WHERE 에 넣지 않고 COUNT(DISTINCT CASE WHEN …) 로만 건다(WHERE 에 넣으면 활동회원수·예측 대상이 고위험 수와 같아지는 오류). 명단 CTE 에만 등급 조건을 둔다. (6) 🔴 실적 SV 와 조인하지 않는다.'
  AI_VERIFIED_QUERIES (
    vqr_o224_korean_high_risk_list AS (
      QUESTION '26년 9월 활동회원 중 중단가능성 높은 회원 중 고려인캠페인 후원 회원번호 명단'
      VERIFIED_BY '(DW = O224)'
      SQL 'WITH base AS (SELECT cc.MBER_NO, cc.MEMBER_CHURN_PROB, cc.MEMBER_CHURN_GRADE, cc.SPONSOR_CHURN_GRADE, cc.ACTIVE_SPNSR_CNT, cc.HAS_MEMBER_PRED FROM cc WHERE cc.STDR_MT = ''202609'' AND cc.CMPGN_CTGR_NM = ''고려인캠페인''), denom AS (SELECT COUNT(DISTINCT MBER_NO) AS ACT, COUNT(DISTINCT CASE WHEN HAS_MEMBER_PRED THEN MBER_NO END) AS PRED, COUNT(DISTINCT CASE WHEN MEMBER_CHURN_GRADE = ''고위험'' THEN MBER_NO END) AS HIGH FROM base) SELECT b.MBER_NO AS "회원번호", ROUND(b.MEMBER_CHURN_PROB * 100, 2) AS "회원 중단확률(%)", b.MEMBER_CHURN_GRADE AS "회원 중단위험 등급", b.SPONSOR_CHURN_GRADE AS "후원건 이탈위험 등급", b.ACTIVE_SPNSR_CNT AS "활동 약정 수(건)", d.ACT AS "활동회원수(명)", d.PRED AS "회원 단위 예측 대상 회원수(명)", d.HIGH AS "중단 고위험 회원수(명)" FROM base b CROSS JOIN denom d WHERE b.MEMBER_CHURN_GRADE = ''고위험'' ORDER BY b.MEMBER_CHURN_PROB DESC NULLS LAST LIMIT 100'
    ),
    vqr_o224_korean_high_risk AS (
      QUESTION '26년 9월 활동회원 중 중단가능성이 높은 회원 중 캠페인카테고리 고려인캠페인을 후원중인 회원 수'
      VERIFIED_BY '(DW = O224)'
      SQL 'SELECT cc.STDR_MT AS "기준월", COUNT(DISTINCT cc.MBER_NO) AS "활동회원수(명)", COUNT(DISTINCT CASE WHEN cc.HAS_MEMBER_PRED THEN cc.MBER_NO END) AS "회원 단위 예측 대상 회원수(명)", COUNT(DISTINCT CASE WHEN cc.MEMBER_CHURN_GRADE = ''고위험'' THEN cc.MBER_NO END) AS "중단 고위험 회원수(명)", COUNT(DISTINCT CASE WHEN cc.SPONSOR_HIGH_CNT > 0 THEN cc.MBER_NO END) AS "후원건 고위험 회원수(명)" FROM cc WHERE cc.STDR_MT = ''202609'' AND cc.CMPGN_CTGR_NM = ''고려인캠페인'' GROUP BY cc.STDR_MT'
    )
  );

