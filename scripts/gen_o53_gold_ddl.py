#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
O53 — 로드맵 2단계: GOLD 최종형 4객체의 `06_DDL.sql` 블록 기계 생성.
Co-authored with CoCo

무엇을 하는가
  ① 기존 문안 64컬럼을 **dbt yml 에서 기계 이관**한다 (손 복사 금지 · P118).
       DIM_MEMBER_CURRENT 20 · DIM_MEMBER_ACQUISITION 25  ← models/gold/_gold_ready_schema.yml
       WIDE_DEV_ACHIEVEMENT 19                            ← models/gold/wide/_wide_schema.yml
  ② 신규 문안 8컬럼(DMC +4 · DIM_MONTH 4)과 감사컬럼 4×3 을 붙인다.
  ③ `CREATE OR REPLACE TABLE` 4블록 + spec.json 을 /tmp/o53_out/ 에 낸다.

왜 기계 생성인가
  🔴 뷰→테이블 전환은 컬럼 COMMENT 의 **정본 위치를 yml → 06_DDL 로 옮기는** 작업이다(사용자 결정).
     손 이관은 64컬럼 중 일부를 조용히 빠뜨린다 — O51-D 에서 실제로 겪었다(P118 비멱등 생성기).
  🔴 재구축(전체 DB 재생성) 시 `06_DDL.sql` 이 **replay 스크립트**가 되므로 이 파일이 COMMENT 의
     유일 복원 경로다. 여기서 빠진 문안은 재구축 후 영구 소실된다.

게이트 (하나라도 실패하면 파일을 쓰지 않고 종료)
  · 결손 0      — 선언 컬럼 전건에 문안이 있어야 한다
  · TODO 0      — 미완 마커 잔존 금지
  · 규칙7 0     — COMMENT 에 실측 수치(행수·%·배수) 금지. 코드값·지표번호는 화이트리스트로 제외(P114 오탐 방지)
  · 중복 0      — 같은 테이블에 같은 컬럼명 두 번 선언 금지
  · 이스케이프  — COMMENT 내 단일인용부호는 '' 로 이중화돼야 한다
멱등: 같은 입력이면 같은 출력(md5 고정). 재실행해 md5 가 바뀌면 생성기 결함이다.
"""
import io
import os
import re
import sys
import json
import hashlib

import yaml

ROOT = '/workspace'
GOLD_YML = f'{ROOT}/10_dbt_pipeline/models/gold/_gold_ready_schema.yml'
WIDE_YML = f'{ROOT}/10_dbt_pipeline/models/gold/wide/_wide_schema.yml'
OUT_DIR = '/tmp/o53_out'

# ── 감사컬럼 (06_DDL.sql 31테이블 전수 동일 · 실측 확인) ──────────────────────
AUDIT = [
    ('DW_SOURCE_SYSTEM', 'VARCHAR',       'NOT NULL', '원천 시스템 식별 (공통감사)'),
    ('DW_LOAD_TS',       'TIMESTAMP_NTZ', 'NOT NULL', '최초 적재 시각 (공통감사)'),
    ('DW_UPDATE_TS',     'TIMESTAMP_NTZ', '',         '최종 갱신 시각 (공통감사)'),
    ('DW_BATCH_ID',      'VARCHAR',       '',         '적재 배치 식별자 = dbt invocation_id (공통감사)'),
]
AUDIT_NAMES = {a[0] for a in AUDIT}

# ── 신규 문안 8건 ─────────────────────────────────────────────────────────────
#   🔴 BRONZE 배선 실측 근거 = models/gold/dim/DIM_MEMBER.sql §19~§62 · 원장 §O53.
#      네 컬럼 모두 「개발약정 시점 스냅샷」이고 SCD2 축이며 일시회원(ONCE)에는 원천이 없다.
#      이 사실을 문안에 넣지 않으면 소비 측이 「현재 거주지·현재 나이」로 읽는다(P15·P19 유형).
NEW_DESC = {
    'DIM_MEMBER_CURRENT': {
        'REGION': "지역명 — 코드그룹 **CM018** 약칭 라벨(정본 공#131). 코드 raw 는 DIM_MEMBER.AREA_CD. "
                  "🔴🔴**현재 거주지가 아니다** — 원천이 `CRM_MEMBER_DEV`(BRONZE `TM_MM_FDRM_MBER_DVLP_AMT.AREA_CD`)의 "
                  "**개발약정 시점 스냅샷**이다. 현주소 축은 BRONZE 에 없다(O34). "
                  "🔴**SCD2 축**이다 — 회원의 버전이 바뀌면 값이 달라질 수 있고, 본 뷰는 현재 버전 행의 값만 담는다. "
                  "🔴일시회원(MEMBER_TYPE='ONCE')은 개발약정 개념이 원천에 없어 **NULL** 이다 — 지역 분포는 "
                  "MEMBER_TYPE='FDRM' 으로 스코프할 것(ONCE 를 분모에 넣으면 채움률이 조용히 낮아진다 · P128). "
                  "⚠️센티넬 '0' 은 사전에 라벨이 없어 NULL 이며 '미상'으로 창작하지 않는다. "
                  "⚠️획득 시점 지역축(DIM_MEMBER_ACQUISITION.ACQ_REGION)과 같은 원천이나 축의 이름과 용도가 다르다.",
        'AGE_BAND': "연령대명 — 코드그룹 **CM014** 라벨. 코드 raw 는 DIM_MEMBER.AGE. "
                    "🔴🔴**연속형 나이가 아니다** — CM014 는 코드 12종('10대 미만'·'10대'~'70대'·'70대 이상'·단체·기업·기타)이며 "
                    "평균·구간 재계산을 하면 뜻이 깨진다. BRONZE `TM_MM_FDRM_MBER_DVLP_AMT.AGE` 의 원천 COMMENT '연령'은 오류다. "
                    "🔴🔴**현재 나이가 아니다** — `CRM_MEMBER_DEV` 의 **개발약정 시점 스냅샷**이고 BRONZE 에 생년월일 축이 없어 "
                    "시점정확 연령은 산출 불가다(O34). 🔴**SCD2 축**이다. "
                    "🔴일시회원(MEMBER_TYPE='ONCE')은 **NULL** — 연령 분포는 MEMBER_TYPE='FDRM' 으로 스코프할 것(P128). "
                    "🟢독립 교차검증으로 코드 해석이 확정됐다 — 단체 코드는 SEX 단체와, 기업 코드는 SEX 기업과 전건 일치한다. "
                    "⚠️사전 자체에 '70대'와 '70대 이상'이 의미 중복으로 공존한다.",
        'FIRST_SPONSORSHIP': "최초 후원사업 식별자 raw ← `CRM_MEMBER_DEV.SPNSR_BSNS_ID`(BRONZE `TM_MM_FDRM_MBER_DVLP_AMT`). "
                             "🔴**라벨이 아니라 사업 ID** 다 — 사업명이 필요하면 DIM_SPONSORSHIP 을 조인하거나 "
                             "DIM_MEMBER_ACQUISITION.ACQ_SPONSORSHIP_NAME 을 쓴다. "
                             "🔴🔴회비 **납입 대상** 후원사업(FACT_MEMBER_FEE.SPONSORSHIP_SK)과 **의미가 다르다** — "
                             "한 회원이 A 사업으로 가입한 뒤 B 사업에 낼 수 있다. "
                             "🔴일시회원(MEMBER_TYPE='ONCE')은 **NULL**(P128 스코프 주의). "
                             "⚠️최초 약정 기준이며 이후 사업 변경은 반영되지 않는다.",
        'LAST_STOP_DATE': "최종 중단일 ← `CRM_MEMBER_DISCONTINUE.STOP_DT`. "
                          "🔴**미중단 회원은 NULL** 이며 0 이나 특정 날짜로 채우지 않는다 — NULL 은 「아직 중단하지 않았다」는 1급 정보다(P21). "
                          "🔴**SCD2 축**이다 — 재후원·재중단이 있으면 버전마다 값이 다르고 본 뷰는 현재 버전 행의 값만 담는다. "
                          "🔴🔴**최초** 중단일이 아니다 — 최초 중단은 DIM_MEMBER_ACQUISITION.FIRST_STOP_DATE_SK 이고, "
                          "유지기간(TENURE_DAYS)의 분자는 그쪽이다. 두 축을 섞으면 재후원 회원의 유지기간이 조용히 늘어난다. "
                          "🔴일시회원(MEMBER_TYPE='ONCE')은 **NULL**(P128 스코프 주의). "
                          "⚠️중단 총계·중단 사유는 FACT_MEMBER_EVENT 를 쓴다 — 이 컬럼은 회원 단위 최종 상태다.",
    },
    'DIM_MONTH': {
        'MONTH_KEY': "월 conform 키 YYYYMM. 🔴🔴**월 팩트는 DIM_DATE 를 직접 조인하지 말고 이 차원을 쓴다** — "
                     "DIM_DATE 는 일 grain 이라 월팩트와 조인하면 월당 일수만큼 행이 증폭되고 금액·건수가 그 배수로 과대해진다"
                     "(SV 설계 원칙10·R1 fan-out 차단). 대상 팩트 = FACT_MEMBER_MONTHLY·FACT_BUDGET·FACT_TARGET_DEV·FACT_TARGET_BIZ. "
                     "🟢본 차원은 DIM_DATE 의 **월 축 사영**이므로 별도 원천이 없고 값이 갈라질 수 없다. "
                     "⚠️월키가 YYYYMM 규약을 벗어난 원천 행은 팩트에서 0 으로 라우팅된다 — 이 차원에는 그 멤버가 없다.",
        'YEAR': "연도 — MONTH_KEY 의 연 부분. DIM_DATE.YEAR 와 동일 정의. 🔴연 집계의 축이며 회계연도가 아니라 역년이다.",
        'MONTH': "월(1~12) — MONTH_KEY 의 월 부분. DIM_DATE.MONTH 와 동일 정의. "
                 "⚠️연을 가로질러 이 축만으로 집계하면 서로 다른 해의 같은 달이 합쳐진다 — 계절성 분석 외에는 MONTH_KEY 를 쓴다.",
        'QUARTER': "분기(1~4) — DIM_DATE.QUARTER 와 동일 정의. 역년 기준이다.",
    },
}

# ── 타입 (실측 기반 · 정본 DDL 이 의도한 폭을 선언한다) ───────────────────────
#   ⚠️ 뷰의 추론 타입을 그대로 베끼지 않는다 — 나눗셈·윈도우가 만든 폭(NUMBER(30,4) 등)은
#      의도가 아니라 계산 부산물이다. 팩트 measure 는 기존 목표팩트와 동일하게 NUMBER(18,4).
TYPES = {
    'DIM_MEMBER_CURRENT': {
        'MEMBER_SK': ('NUMBER(38,0)', 'NOT NULL'), 'MEMBER_DK': ('VARCHAR(10)', 'NOT NULL'),
        'MEMBER_TYPE': ('VARCHAR', ''), 'SEX': ('VARCHAR', ''), 'SEX_NM': ('VARCHAR', ''),
        'GENDER_NAME': ('VARCHAR', ''), 'MBER_STAT_CD': ('VARCHAR', ''),
        'MEMBER_STATUS_NAME': ('VARCHAR', ''), 'MEMBER_STATUS_GROUP': ('VARCHAR', ''),
        'MBER_DIV_CD': ('VARCHAR', ''), 'MEMBER_TYPE_NAME': ('VARCHAR', ''),
        'JOIN_PATH_CD': ('VARCHAR', ''), 'ENROLL_PATH_NAME': ('VARCHAR', ''),
        'FIRST_JOIN_DATE': ('DATE', ''), 'FIRST_CAMPAIGN': ('VARCHAR', ''),
        'REGION': ('VARCHAR', ''), 'AGE_BAND': ('VARCHAR', ''),
        'FIRST_SPONSORSHIP': ('VARCHAR', ''), 'LAST_STOP_DATE': ('DATE', ''),
        'EFFECTIVE_FROM': ('DATE', ''),
    },
    'DIM_MEMBER_ACQUISITION': {
        'MEMBER_DK': ('VARCHAR(10)', 'NOT NULL'),
        'ACQ_CAMPAIGN_SK': ('NUMBER(38,0)', ''), 'ACQ_ORG_SK': ('NUMBER(38,0)', ''),
        'ACQ_SPONSORSHIP_SK': ('NUMBER(38,0)', ''), 'ACQ_DATE_SK': ('NUMBER(8,0)', ''),
        'ACQ_BASIS': ('VARCHAR', ''), 'ACQ_DVLP_DIV_CD': ('VARCHAR', ''),
        'ACQ_AGE_CD': ('NUMBER(2,0)', ''), 'ACQ_AGE_BAND': ('VARCHAR', ''),
        'ACQ_AREA_CD': ('VARCHAR', ''), 'ACQ_REGION': ('VARCHAR', ''),
        'ACQ_SEX_CD': ('VARCHAR', ''), 'ACQ_GENDER': ('VARCHAR', ''),
        'ACQ_SPNSR_AMT': ('NUMBER(18,0)', ''), 'ACQ_BRAND': ('VARCHAR', ''),
        'ACQ_CAMPAIGN_NAME': ('VARCHAR', ''), 'ACQ_PARENT_CAMPAIGN_NAME': ('VARCHAR', ''),
        'ACQ_PROMO_METHOD_NAME': ('VARCHAR', ''), 'ACQ_MARKETING_CAMPAIGN': ('VARCHAR', ''),
        'ACQ_DEPARTMENT': ('VARCHAR', ''), 'ACQ_SPONSORSHIP_NAME': ('VARCHAR', ''),
        'FIRST_STOP_DATE_SK': ('NUMBER(8,0)', ''), 'FIRST_STOP_REASON_NM': ('VARCHAR', ''),
        'TENURE_DAYS': ('NUMBER(9,0)', ''), 'IS_12M_OBSERVABLE': ('BOOLEAN', ''),
    },
    'FACT_DEV_ACHIEVEMENT': {
        'MONTH_KEY': ('NUMBER(6,0)', 'NOT NULL'), 'CAL_YEAR': ('NUMBER(4,0)', ''),
        'CAL_MONTH': ('NUMBER(2,0)', ''), 'ORG_SK': ('NUMBER(38,0)', 'NOT NULL'),
        'ORG_DEPARTMENT': ('VARCHAR', ''), 'ORG_DIVISION': ('VARCHAR', ''),
        'ORG_TEAM': ('VARCHAR', ''), 'ORG_CORP': ('VARCHAR', ''),
        'DEV_TYPE': ('VARCHAR', 'NOT NULL'), 'DEV_TYPE_NAME': ('VARCHAR(100)', ''),
        'GOAL_CNT': ('NUMBER(18,4)', ''), 'ACTUAL_CNT': ('NUMBER(18,4)', ''),
        'GOAL_CNT_YTD': ('NUMBER(18,4)', ''), 'ACTUAL_CNT_YTD': ('NUMBER(18,4)', ''),
        'GOAL_CNT_YEAR': ('NUMBER(18,4)', ''), 'ACTUAL_CNT_YEAR': ('NUMBER(18,4)', ''),
        'HAS_GOAL_ROW': ('BOOLEAN', ''), 'HAS_POSITIVE_GOAL': ('BOOLEAN', ''),
        'HAS_ACTUAL': ('BOOLEAN', ''),
    },
    'DIM_MONTH': {
        'MONTH_KEY': ('NUMBER(6,0)', 'NOT NULL'), 'YEAR': ('NUMBER(4,0)', ''),
        'MONTH': ('NUMBER(2,0)', ''), 'QUARTER': ('NUMBER(1,0)', ''),
    },
}

# ── PRIMARY KEY (정보성 · Snowflake 는 강제하지 않는다) ───────────────────────
#   06_DDL.sql 관례: DIM 은 전건 PK 선언 · FACT 는 **grain 이 유일할 때만** 선언
#   (FACT_MEMBER_COHORT.MEMBER_DK · FACT_AD_* 가 그 선례. FME/FSE/FEP 는 grain 비유일이라 미선언).
#   🔴 FACT_DEV_ACHIEVEMENT 는 grain 유일성을 실측으로 확인한 뒤 선언한다 —
#      (MONTH_KEY, ORG_SK, DEV_TYPE) distinct = 전체 행수(원장 §O53).
PK = {
    'DIM_MONTH': ['MONTH_KEY'],
    'DIM_MEMBER_CURRENT': ['MEMBER_DK'],
    'DIM_MEMBER_ACQUISITION': ['MEMBER_DK'],
    'FACT_DEV_ACHIEVEMENT': ['MONTH_KEY', 'ORG_SK', 'DEV_TYPE'],
}

# ── 컬럼 순서 (정본) ──────────────────────────────────────────────────────────
#   🔴 이 순서가 dbt 모델 SELECT 순서의 정본이다. 바꾸면 양쪽을 동시에 재생성할 것.
#   🔴 DMC 신규 4컬럼은 기존 업무컬럼 뒤 · EFFECTIVE_FROM 앞에 **연속 블록**으로 넣는다
#      (연속 블록이라 DDL↔모델 대조에서 누락이 눈에 띈다).
ORDER = {
    'DIM_MEMBER_CURRENT': [
        'MEMBER_SK', 'MEMBER_DK', 'MEMBER_TYPE', 'SEX', 'SEX_NM', 'GENDER_NAME',
        'MBER_STAT_CD', 'MEMBER_STATUS_NAME', 'MEMBER_STATUS_GROUP', 'MBER_DIV_CD',
        'MEMBER_TYPE_NAME', 'JOIN_PATH_CD', 'ENROLL_PATH_NAME', 'FIRST_JOIN_DATE',
        'FIRST_CAMPAIGN',
        'REGION', 'AGE_BAND', 'FIRST_SPONSORSHIP', 'LAST_STOP_DATE',   # ← O53 신규 4
        'EFFECTIVE_FROM',
    ] + [a[0] for a in AUDIT],
    'DIM_MEMBER_ACQUISITION': [
        'MEMBER_DK', 'ACQ_CAMPAIGN_SK', 'ACQ_ORG_SK', 'ACQ_SPONSORSHIP_SK', 'ACQ_DATE_SK',
        'ACQ_BASIS', 'ACQ_DVLP_DIV_CD', 'ACQ_AGE_CD', 'ACQ_AGE_BAND', 'ACQ_AREA_CD',
        'ACQ_REGION', 'ACQ_SEX_CD', 'ACQ_GENDER', 'ACQ_SPNSR_AMT', 'ACQ_BRAND',
        'ACQ_CAMPAIGN_NAME', 'ACQ_PARENT_CAMPAIGN_NAME', 'ACQ_PROMO_METHOD_NAME',
        'ACQ_MARKETING_CAMPAIGN', 'ACQ_DEPARTMENT', 'ACQ_SPONSORSHIP_NAME',
        'FIRST_STOP_DATE_SK', 'FIRST_STOP_REASON_NM', 'TENURE_DAYS', 'IS_12M_OBSERVABLE',
    ] + [a[0] for a in AUDIT],
    'FACT_DEV_ACHIEVEMENT': [
        'MONTH_KEY', 'CAL_YEAR', 'CAL_MONTH', 'ORG_SK', 'ORG_DEPARTMENT', 'ORG_DIVISION',
        'ORG_TEAM', 'ORG_CORP', 'DEV_TYPE', 'DEV_TYPE_NAME', 'GOAL_CNT', 'ACTUAL_CNT',
        'GOAL_CNT_YTD', 'ACTUAL_CNT_YTD', 'GOAL_CNT_YEAR', 'ACTUAL_CNT_YEAR',
        'HAS_GOAL_ROW', 'HAS_POSITIVE_GOAL', 'HAS_ACTUAL',
    ] + [a[0] for a in AUDIT],
    'DIM_MONTH': ['MONTH_KEY', 'YEAR', 'MONTH', 'QUARTER'] + [a[0] for a in AUDIT],
}

# 문안 이관 출처 (yml 모델명 → 대상 테이블명)
SRC = {
    'DIM_MEMBER_CURRENT':     (GOLD_YML, 'DIM_MEMBER_CURRENT'),
    'DIM_MEMBER_ACQUISITION': (GOLD_YML, 'DIM_MEMBER_ACQUISITION'),
    'FACT_DEV_ACHIEVEMENT':   (WIDE_YML, 'WIDE_DEV_ACHIEVEMENT'),   # ← 개명
    'DIM_MONTH':              (None, None),                          # 전량 신규
}

# ── 테이블 COMMENT ────────────────────────────────────────────────────────────
#   DMC 의 종전 뷰 COMMENT 는 "전건 NULL 7컬럼 미노출(DEC-27 §17-C)" 을 근거로 들었으나
#   그 전제는 stale 이다(3컬럼은 DIM_MEMBER 에 부재 · 4컬럼은 채움) — DEC-28 §18-B 가 이미 정정했다.
TABLE_COMMENT = {
    'DIM_MEMBER_CURRENT':
        "🟢 GOLD 직접조회 분석가의 기본 진입점 — 회원 1명 = 1행. DIM_MEMBER 는 **SCD2 다버전**이므로 FACT 와 "
        "MEMBER_DK 직접 조인 시 팬아웃한다(단월·회비 측정에서 배수 과대 실측 — 규모는 이슈원장 §O51-D). "
        "과거 시점 상태가 필요할 때만 DIM_MEMBER 를 EFFECTIVE_FROM/EFFECTIVE_TO 로 시점조인할 것 — 예측·피처 생성은 "
        "이 시점조인이 정답이며 현재값을 과거 행에 붙이면 정답 누설이다. "
        "🔴 상태 기반 분포·이탈률·예측 모집단은 MEMBER_TYPE='FDRM' 으로 한정할 것(일시회원 ONCE 는 회원상태·가입경로 "
        "개념이 원천에 없고 REGION·AGE_BAND·FIRST_SPONSORSHIP·LAST_STOP_DATE 도 전건 NULL 이다). "
        "본 테이블은 DIM_MEMBER 의 순수 투영이며 라벨 정의는 DIM_MEMBER.sql 단일 소유. "
        "🔴 [O53] REGION·AGE_BAND·FIRST_SPONSORSHIP·LAST_STOP_DATE 를 노출한다 — 종전 미노출 근거였던 "
        "「전건 NULL 7컬럼」은 stale 이다(DEC-28 §18-B 가 이미 정정 · 3컬럼은 DIM_MEMBER 에 부재하고 4컬럼은 채워져 있다). "
        "⚠️네 컬럼 전부 **개발약정 시점 스냅샷**이고 SCD2 축이다 — 현재 거주지·현재 나이로 읽으면 틀린다. "
        "⚠️SERVING.DIM_MEMBER_CURRENT 와 동명이나 컬럼 집합이 다르다.",
    'DIM_MEMBER_ACQUISITION':
        "회원 획득(가입) 귀속 차원 — 1행=1회원. 원천 = FACT_MEMBER_COHORT(단일 정의 지점). "
        "🔴모든 ACQ_* 는 **획득 시점** 값이며 현재 속성이 아니다(현재 연령·현주소는 BRONZE 에 축이 없어 산출 불가·O34). "
        "🔴「부서」·「후원사업」은 같은 라벨로 두 축이 존재한다 — 사건 부서=FACT_MEMBER_EVENT.ORG_SK · "
        "납입 대상 후원사업=FACT_MEMBER_FEE.SPONSORSHIP_SK. "
        "🔴팩트와는 반드시 LEFT JOIN — 개발 사건이 없는 회원이 사라진다 — 🔴손실은 **회원 기준**으로 읽어야 한다"
        "(행 가중 비율은 손실을 축소해 보이게 한다 · 규모는 이슈원장 §O51-D-B). "
        "신설 경위(O45): FMM 의 CAMPAIGN_SK·SPONSORSHIP_SK 가 전건 센티넬인 것은 원천 부재가 아니라 "
        "**다중캠페인 후원의 귀속 규칙이 없어서**였고, 임의 귀속 대신 「획득 시점」이라는 명시된 규칙을 채택했다(O8 우회). "
        "🔴 [O53] 뷰 → 테이블 전환. 적재는 dbt(append + pre-hook TRUNCATE)가 하고 구조·COMMENT 는 06_DDL.sql 이 소유한다.",
    'FACT_DEV_ACHIEVEMENT':
        "회원개발 **목표 대비 실적** 월 conform 팩트 — FACT_TARGET_DEV(목표) × FACT_MEMBER_EVENT(실적) FULL OUTER. "
        "grain=MONTH_KEY×ORG_SK×DEV_TYPE. 마케팅 장표 「1. 개발현황(목표,실적)」의 정본이며 정본 지표 공#1(월 목표 달성율)·"
        "#2(누계)·#3(연)의 산출 base 다. "
        "🔴달성율 컬럼은 두지 않는다 — SUM(실적)/SUM(목표) 로 재계산할 것(행 단위 비율의 평균은 항상 틀린다). "
        "🔴달성율 분모·분자는 **HAS_POSITIVE_GOAL=TRUE**(=GOAL_CNT>0) 로 스코프해야 한다 — 목표 미편성분의 실적이 "
        "분자에 섞이면 조용히 과대해진다(P18·P63). "
        "⚠️**HAS_GOAL_ROW(목표 행 존재)로 스코프하면 안 된다**: 원천이 부서×월×개발구분 조합을 전량 행 생성하고 "
        "미편성분을 0 으로 채워 목표 행의 과반이 0 이므로, 그 행들의 실적이 분모 없이 분자에 들어가 비율이 폭증한다. "
        "⚠️_YTD·_YEAR 컬럼은 월에 대해 비가산 — 월을 가로질러 합산 금지. "
        "⚠️일별 실적은 WIDE_MEMBER_EVENT(일 grain) 소관 — 월 목표를 일자에 반복하면 이중계상된다. "
        "⚠️매체(브랜드2)별 목표는 원천에 없다(정본 마케팅 인벤토리 §1 「부서별 목표만 존재·매체별 목표 확인 불가」). "
        "🔴 [O53] 종전 이름 = GOLD.WIDE_DEV_ACHIEVEMENT(뷰). 팩트를 재구성하는 객체이므로 WIDE_ 접두가 아니라 "
        "FACT_ 로 개명하고 테이블화했다 — SV_DEV_ACHIEVEMENT 의 base 다.",
    'DIM_MONTH':
        "월 차원 — DIM_DATE 의 **월 축 사영**(1행 = 1개월). "
        "🔴🔴존재 이유는 **fan-out 차단**이다: 월 팩트(FACT_MEMBER_MONTHLY·FACT_BUDGET·FACT_TARGET_DEV·FACT_TARGET_BIZ)를 "
        "일 grain 인 DIM_DATE 에 직접 조인하면 월당 일수만큼 행이 증폭되고 금액·건수가 그 배수로 과대해진다"
        "(SV 설계 원칙10·R1). 월 팩트의 시간축은 **반드시 이 차원**을 쓴다. "
        "🟢DIM_DATE 파생이라 별도 원천이 없고 값이 갈라질 수 없다 — 캘린더 범위는 DIM_DATE 와 동일하다. "
        "🔴 [O53] 종전에는 SERVING.DIM_MONTH(helper 뷰)만 있었다. SV 가 GOLD 만 참조하도록 GOLD 로 올렸다 — "
        "SERVING helper 정리는 로드맵 7단계 소관이다.",
}


# ── 문안 이관 ─────────────────────────────────────────────────────────────────
def load_yml_desc(path, model):
    doc = yaml.safe_load(io.open(path, encoding='utf-8').read())
    for m in doc.get('models', []):
        if m.get('name') == model:
            return {c['name']: c['description'] for c in m.get('columns', [])}
    sys.exit(f"🔴 yml 에서 모델을 찾지 못했다: {model} @ {path}")


def build_desc(table):
    path, model = SRC[table]
    d = dict(load_yml_desc(path, model)) if path else {}
    d.update(NEW_DESC.get(table, {}))
    for name, _t, _n, cmt in AUDIT:
        d.setdefault(name, cmt)
    return d


# ── 게이트 ────────────────────────────────────────────────────────────────────
NUM = [re.compile(r'[0-9]{1,3}(,[0-9]{3})+'),        # 천단위 행수
       re.compile(r'[0-9]+(\.[0-9]+)?%'),            # 백분율
       re.compile(r'[0-9]+(\.[0-9]+)?배')]           # 배수
WHITE = re.compile(r'#[0-9]+|(CM|MM|MS|PM|CONF|DEC|O|P|E|G|Q|AD|SVL|R)-?[0-9]+|[0-9]+0대|'
                   r'[0-9]+대|NUMBER\([0-9,]+\)|VARCHAR\([0-9]+\)|YYYYMM(DD)?|[0-9]+M')


def gate(table, order, desc, label=None):
    fails = []
    name = label or table
    miss = [c for c in order if c not in desc or not str(desc[c]).strip()]
    todo = [c for c in order if c in desc and 'TODO' in str(desc[c])]
    dup = sorted({c for c in order if order.count(c) > 1})
    ghost = [c for c in desc if c not in order]
    viol = []
    for c in order:
        if c in desc and any(rx.search(WHITE.sub('', str(desc[c]))) for rx in NUM):
            viol.append(c)
    untyped = [c for c in order if c not in TYPES[table] and c not in AUDIT_NAMES]
    print(f"  {name:<30} 선언={len(order):>3} 문안={len([c for c in order if c in desc]):>3} "
          f"결손={len(miss)} TODO={len(todo)} 규칙7위반={len(viol)} 중복={len(dup)} 타입미정={len(untyped)} "
          f"미사용문안={len(ghost)}")
    for label, items in (('결손', miss), ('TODO 잔존', todo), ('규칙7 위반', viol),
                         ('중복 선언', dup), ('타입 미정', untyped)):
        if items:
            print(f"     🔴 {label}: {', '.join(items)}")
            fails.append(label)
    if ghost:
        print(f"     ⚪ 미사용(이관 대상 아님): {', '.join(sorted(ghost))}")
    return fails


# ── DDL 생성 ──────────────────────────────────────────────────────────────────
SECTION = {
    'DIM_MONTH':              'DIM 18: DIM_MONTH — 월 차원 (DIM_DATE 월 축 사영 · 월팩트 fan-out 차단)',
    'DIM_MEMBER_CURRENT':     'DIM 19: DIM_MEMBER_CURRENT — 회원 현재행 차원 (SCD2 IS_CURRENT 투영 · 분석가 기본 진입점)',
    'DIM_MEMBER_ACQUISITION': 'DIM 20: DIM_MEMBER_ACQUISITION — 회원 획득 귀속 차원 (1행 = 1회원)',
    'FACT_DEV_ACHIEVEMENT':   'FACT 15: FACT_DEV_ACHIEVEMENT — 회원개발 목표 대비 실적 (월 conform · 구 WIDE_DEV_ACHIEVEMENT)',
}


def esc(s):
    return str(s).replace("'", "''")


def emit_ddl(table, order, desc):
    typ = dict(TYPES[table])
    for name, t, n, _c in AUDIT:
        typ.setdefault(name, (t, n))
    pk = PK[table]
    composite = len(pk) > 1
    lines = [
        '-- ' + '=' * 76,
        f'-- {SECTION[table]}',
        '--   [2026-08-10 O53] 신설. 구조·COMMENT 소유주 = 본 파일 / 적재 = dbt(incremental append + pre-hook TRUNCATE).',
        '--   🔴 merge 금지: 완전 재산출 차원에 merge 를 쓰면 grain 이동 시 구 행이 잔존한다(문서50 §300 R1 · P131).',
        f'--   PK(정보성) = {", ".join(pk)}',
        '-- ' + '=' * 76,
        f'CREATE OR REPLACE TABLE GN_DW.GOLD.{table} (',
    ]
    width = max(len(c) for c in order)
    last = len(order) - 1
    for i, c in enumerate(order):
        t, nn = typ[c]
        if not composite and c in pk:
            nn = 'NOT NULL PRIMARY KEY'
        tail = ',' if (i < last or composite) else ''
        nnp = f'{nn} ' if nn else ''
        lines.append(f"    {c:<{width}} {t:<15} {nnp}COMMENT '{esc(desc[c])}'{tail}")
    if composite:
        lines.append(f"    PRIMARY KEY ({', '.join(pk)})")
    lines.append(f") COMMENT = '{esc(TABLE_COMMENT[table])}';")
    return '\n'.join(lines) + '\n'


def self_check():
    """게이트 탐지력 실증 (P106) — 「위반 0 통과」는 공집합 통과와 구별되지 않는다.
    일부러 결함을 심어 게이트가 잡는지 확인한다. 기대치와 다르면 실패."""
    print('게이트 자기검사 (P106 — 탐지력 실증)\n')
    base_order = ORDER['DIM_MONTH']
    base_desc = build_desc('DIM_MONTH')
    cases = [
        ('정상(대조군)',              base_order, base_desc,                                    []),
        ('결손 1건',                  base_order, {k: v for k, v in base_desc.items() if k != 'YEAR'}, ['결손']),
        ('빈 문안',                   base_order, {**base_desc, 'MONTH': '   '},                 ['결손']),
        ('TODO 잔존',                 base_order, {**base_desc, 'QUARTER': 'TODO 확인'},          ['TODO 잔존']),
        ('규칙7 — 천단위 행수',        base_order, {**base_desc, 'YEAR': '연도. 실측 1,763,065행'}, ['규칙7 위반']),
        ('규칙7 — 백분율',            base_order, {**base_desc, 'YEAR': '연도. 채움 98.68%'},      ['규칙7 위반']),
        ('규칙7 — 배수',              base_order, {**base_desc, 'YEAR': '연도. 조인 시 3.6배'},    ['규칙7 위반']),
        ('중복 선언',                 base_order + ['YEAR'], base_desc,                          ['중복 선언']),
        ('화이트리스트 오탐 없음(코드값)', base_order,
         {**base_desc, 'YEAR': '연도. 코드그룹 MM015 · 정본 공#121 · CM014 12종 · 70대 이상 · NUMBER(6,0) · YYYYMM'}, []),
    ]
    ok = 0
    for label, order, desc, expect in cases:
        got = sorted(set(gate('DIM_MONTH', order, desc, label=label)))
        exp = sorted(set(expect))
        # '중복 선언' 케이스는 결손/타입 판정에 영향이 없어야 한다
        hit = (got == exp)
        print(f"     기대={exp or '없음'} 실제={got or '없음'} → {'✅' if hit else '🔴'}\n")
        ok += hit
    print(f"자기검사 {ok}/{len(cases)} 일치")
    if ok != len(cases):
        sys.exit('🔴 게이트가 기대대로 탐지하지 못한다 — 게이트를 신뢰할 수 없다')


def main():
    if '--self-check' in sys.argv:
        self_check()
        return
    print('O53 GOLD DDL 생성기 — 사전검증(정본 yml 기준 · 산출물 생산 전)\n')
    print('게이트:')
    all_fails, blocks, spec = [], {}, {}
    for table in ('DIM_MONTH', 'DIM_MEMBER_CURRENT', 'DIM_MEMBER_ACQUISITION', 'FACT_DEV_ACHIEVEMENT'):
        order = ORDER[table]
        desc = build_desc(table)
        all_fails += gate(table, order, desc)
        blocks[table] = emit_ddl(table, order, desc)
        spec[table] = {'columns': order,
                       'types': {c: (dict(TYPES[table]).get(c) or
                                     next((t, n) for nm, t, n, _ in AUDIT if nm == c))[0]
                                 for c in order}}
    if all_fails:
        sys.exit('\n🔴 게이트 실패 — 파일을 쓰지 않고 중단한다')

    os.makedirs(OUT_DIR, exist_ok=True)
    for table, body in blocks.items():
        io.open(f'{OUT_DIR}/{table}.sql', 'w', encoding='utf-8').write(body)
    io.open(f'{OUT_DIR}/spec.json', 'w', encoding='utf-8').write(
        json.dumps(spec, ensure_ascii=False, indent=2, sort_keys=True))

    total = sum(len(ORDER[t]) for t in ORDER)
    print(f"\n✅ 게이트 통과 · 4블록 생성 (선언 컬럼 합계 {total})")
    print('   멱등 sha256(앞 16):')
    for table in sorted(blocks):
        # FIPS 모드에서 md5 가 막혀 있다 — sha256 을 쓴다(용도는 멱등 확인이라 알고리즘 무관).
        h = hashlib.sha256(blocks[table].encode('utf-8')).hexdigest()[:16]
        print(f"     {table:<24} {h}  ({len(ORDER[table])}컬럼)")
    print(f"\n   출력 = {OUT_DIR}/  (06_DDL.sql 삽입은 별도 단계)")


if __name__ == '__main__':
    main()
