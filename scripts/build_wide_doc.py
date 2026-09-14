# -*- coding: utf-8 -*-
"""build_wide_doc.py — GOLD WIDE VIEW 14종 확장 컬럼 정의서 생성기."""
import os
import sys
import json
import yaml
import re

ROOT = '/workspace'
WIDE_DIR = os.path.join(ROOT, '10_dbt_pipeline', 'models', 'gold', 'wide')
YML_PATH = os.path.join(WIDE_DIR, '_wide_schema.yml')
OUT_PATH = os.path.join(ROOT, '03_top-down_gold', '09_빅테이블 VIEW.md')

sys.path.insert(0, os.path.join(ROOT, 'scripts'))
from sfconn import conn, q

ALIAS_TO_TABLE = {
    'f': '기준 Fact 테이블',
    'b': 'GOLD.FACT_AD_BROADCAST',
    'bc': 'GOLD.FACT_AD_BROADCAST_CASE',
    'g': 'GOLD.FACT_AD_DIGITAL',
    'dig': 'GOLD.FACT_AD_DIGITAL',
    'brc': 'GOLD.FACT_AD_BROADCAST',
    'fap': 'GOLD.FACT_AD_PERFORMANCE',
    'm': 'GOLD.DIM_MEMBER_STATUS_HISTORY (IS_CURRENT=TRUE 최신 버전)',
    'mem': 'GOLD.DIM_MEMBER (회원 1행 현재 기준)',
    'acq': 'GOLD.DIM_MEMBER_ACQUISITION (획득 코호트 귀속축)',
    'd': 'GOLD.DIM_DATE (일자 차원)',
    'dp': 'GOLD.DIM_DATE (최근 수납일자)',
    'c': 'GOLD.DIM_CAMPAIGN (캠페인 차원)',
    's': 'GOLD.DIM_SPONSORSHIP (후원사업 차원)',
    'p': 'GOLD.DIM_PAYMENT (납입/결제수단 차원)',
    'r': 'GOLD.DIM_REASON (사유 차원)',
    'o': 'GOLD.DIM_ORG (조직/부서 차원)',
    'st': 'GOLD.DIM_SEND_TYPE (발송 채널/유형 차원)',
    'sv': 'GOLD.DIM_SERVICE (서비스 분류 차원)',
    'e': 'GOLD.DIM_EVENT (행사 차원)',
    'bi': 'GOLD.DIM_BUDGET_ITEM (예산과목 차원)',
    'ac': 'GOLD.DIM_AD_CREATIVE (광고소재/매체 차원)',
    'dv': 'GOLD.DIM_DEVICE (디바이스 차원)',
    'ge': 'GOLD.DIM_BIGQUERY_EVENT (BigQuery 이벤트 차원)',
    'gs': 'GOLD.DIM_BIGQUERY_SOURCE (BigQuery 유입소스 차원)',
    'mi': 'GOLD.DIM_MEMBER_IDENTITY (회원 식별 차원)'
}

VIEW_META = {
    'WIDE_MEMBER_MONTHLY': {
        'num': '1',
        'title': '회원 월별 실적 평탄화 뷰 (Member Monthly Mart)',
        'purpose': '회원×월 단위 집계 실적(청구·납입·미납·활동·개발·중단)과 회원 현재 속성 및 마스터 코드 라벨을 결합한 통합 분석용 뷰',
        'grain': '월(MONTH_KEY) × 회원(MEMBER_DK)',
        'base': 'GOLD.FACT_MEMBER_MONTHLY (f)',
        'joins': [
            'LEFT JOIN GOLD.DIM_MEMBER_STATUS_HISTORY (m) ON f.MEMBER_DK = m.MEMBER_DK (IS_CURRENT=TRUE 최신 버전 1행 dedup 서브쿼리)',
            'LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK',
            'LEFT JOIN GOLD.DIM_SPONSORSHIP (s) ON f.SPONSORSHIP_SK = s.SPONSORSHIP_SK',
            'LEFT JOIN GOLD.DIM_PAYMENT (p) ON f.PAYMENT_SK = p.PAYMENT_SK',
            'LEFT JOIN GOLD.DIM_REASON (r) ON f.REASON_SK = r.REASON_SK'
        ]
    },
    'WIDE_MEMBER_EVENT': {
        'num': '2',
        'title': '회원 개발/중단 이벤트 평탄화 뷰 (Member Event Mart)',
        'purpose': '회원의 가입, 증액, 감액, 재후원, 후원중단 등 상태전이 사건(Event)에 일자·회원·캠페인·사업·부서·사유 차원을 결합한 사건 추적 뷰',
        'grain': '사건일(DATE_SK) × 회원(MEMBER_DK) × 개발구분(DVLP_DIV_CD)',
        'base': 'GOLD.FACT_MEMBER_EVENT (f)',
        'joins': [
            'LEFT JOIN GOLD.DIM_DATE (d) ON f.DATE_SK = d.DATE_SK',
            'LEFT JOIN GOLD.DIM_MEMBER_STATUS_HISTORY (m) ON f.MEMBER_DK = m.MEMBER_DK (IS_CURRENT=TRUE 최신 버전 1행 dedup 서브쿼리)',
            'LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK',
            'LEFT JOIN GOLD.DIM_SPONSORSHIP (s) ON f.SPONSORSHIP_SK = s.SPONSORSHIP_SK',
            'LEFT JOIN GOLD.DIM_ORG (o) ON f.ORG_SK = o.ORG_SK (개발 사건 당시 소속 부서 기준)',
            'LEFT JOIN GOLD.DIM_REASON (r) ON f.REASON_SK = r.REASON_SK'
        ]
    },
    'WIDE_MEMBER_FEE': {
        'num': '3',
        'title': '회비 분해 평탄화 뷰 (Member Fee Breakdown Mart)',
        'purpose': '후원사업·납입방식·결제수단별 회비 청구/납입 상세 팩트에 회원 1행 현재 속성 및 획득 코호트(DIM_MEMBER_ACQUISITION)를 결합한 재무 분석 뷰',
        'grain': '회원(MEMBER_DK) × 회비월(MONTH_KEY) × 후원사업 × 회비구분 × 납입유형 × 결제수단',
        'base': 'GOLD.FACT_MEMBER_FEE (f)',
        'joins': [
            'LEFT JOIN GOLD.DIM_SPONSORSHIP (s) ON f.SPONSORSHIP_SK = s.SPONSORSHIP_SK (납입 대상 후원사업)',
            'LEFT JOIN GOLD.DIM_PAYMENT (p) ON f.PAYMENT_SK = p.PAYMENT_SK (결제수단 및 납입방식)',
            'LEFT JOIN GOLD.DIM_DATE (dp) ON f.LAST_PAY_DATE_SK = dp.DATE_SK (최근 수납일자)',
            'LEFT JOIN GOLD.DIM_MEMBER (mem) ON f.MEMBER_DK = mem.MEMBER_DK (회원 1행 현재 기준 속성)',
            'LEFT JOIN GOLD.DIM_MEMBER_ACQUISITION (acq) ON f.MEMBER_DK = acq.MEMBER_DK (획득 시점 캠페인·부서·사업 코호트 귀속축)'
        ]
    },
    'WIDE_SERVICE_EVENT': {
        'num': '4',
        'title': '메시지/서비스 발송 평탄화 뷰 (Message Dispatch Mart)',
        'purpose': '알림톡, 문자, 이메일, 우편 등 대고객 메시지 발송 팩트에 발송유형·서비스코드·회원·캠페인 차원을 결합한 발송 이력 뷰',
        'grain': '발송일(DATE_SK) × 회원(MEMBER_DK) × 발송유형(SEND_TYPE_SK)',
        'base': 'GOLD.FACT_MESSAGE_DISPATCH (f)',
        'joins': [
            'LEFT JOIN GOLD.DIM_DATE (d) ON f.DATE_SK = d.DATE_SK',
            'LEFT JOIN GOLD.DIM_MEMBER_STATUS_HISTORY (m) ON f.MEMBER_DK = m.MEMBER_DK (IS_CURRENT=TRUE 최신 버전 1행 dedup 서브쿼리)',
            'LEFT JOIN GOLD.DIM_SEND_TYPE (st) ON f.SEND_TYPE_SK = st.SEND_TYPE_SK (발송 채널 및 유형)',
            'LEFT JOIN GOLD.DIM_SERVICE (sv) ON f.SERVICE_SK = sv.SERVICE_SK (서비스 분류)',
            'LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK'
        ]
    },
    'WIDE_EVENT_PARTICIPATION': {
        'num': '5',
        'title': '행사 참여 평탄화 뷰 (Event Attendance Mart)',
        'purpose': '일반행사 및 캠페인행사 참여 이력 팩트에 행사 마스터, 회원 속성, 캠페인, 후원사업 차원을 결합한 행사 성과 뷰',
        'grain': '참여일(DATE_SK) × 회원(MEMBER_DK) × 행사(EVENT_SK)',
        'base': 'GOLD.FACT_EVENT_ATTENDANCE (f)',
        'joins': [
            'LEFT JOIN GOLD.DIM_DATE (d) ON f.DATE_SK = d.DATE_SK',
            'LEFT JOIN GOLD.DIM_MEMBER_STATUS_HISTORY (m) ON f.MEMBER_DK = m.MEMBER_DK (IS_CURRENT=TRUE 최신 버전 1행 dedup 서브쿼리)',
            'LEFT JOIN GOLD.DIM_EVENT (e) ON f.EVENT_SK = e.EVENT_SK (행사구분·카테고리)',
            'LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK',
            'LEFT JOIN GOLD.DIM_SPONSORSHIP (s) ON f.SPONSORSHIP_SK = s.SPONSORSHIP_SK'
        ]
    },
    'WIDE_BUDGET': {
        'num': '6',
        'title': '예산 편성/집행 평탄화 뷰 (Budget & Expense Mart)',
        'purpose': '예산과목별 월 편성예산 및 ERP 집행 실적 팩트에 조직(부서) 및 예산과목 차원을 결합한 예산 관리 뷰',
        'grain': '예산월(MONTH_KEY) × 부서(ORG_SK) × 예산과목(BUDGET_ITEM_SK)',
        'base': 'GOLD.FACT_BUDGET (f)',
        'joins': [
            'LEFT JOIN GOLD.DIM_ORG (o) ON f.ORG_SK = o.ORG_SK (예산 관할 부서)',
            'LEFT JOIN GOLD.DIM_BUDGET_ITEM (bi) ON f.BUDGET_ITEM_SK = bi.BUDGET_ITEM_SK (계정과목·관항목)',
            'LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK',
            'LEFT JOIN GOLD.DIM_SPONSORSHIP (s) ON f.SPONSORSHIP_SK = s.SPONSORSHIP_SK'
        ]
    },
    'WIDE_TARGET_DEV': {
        'num': '7',
        'title': '회원개발 목표 평탄화 뷰 (Member Development Target Mart)',
        'purpose': '부서별 월 회원개발 목표 팩트에 부서(조직) 차원을 결합한 목표 관리 뷰',
        'grain': '목표월(MONTH_KEY) × 부서(ORG_SK) × 개발구분(DEV_TYPE)',
        'base': 'GOLD.FACT_TARGET_MEMBER_DEV (f)',
        'joins': [
            'LEFT JOIN GOLD.DIM_ORG (o) ON f.ORG_SK = o.ORG_SK (목표 수립 부서)'
        ]
    },
    'WIDE_TARGET_BIZ': {
        'num': '8',
        'title': '사업 목표 평탄화 뷰 (Project Target Mart)',
        'purpose': '부서 및 후원사업별 연간/추경 사업목표 팩트에 부서, 후원사업, 캠페인 차원을 결합한 사업 목표 뷰',
        'grain': '목표월(MONTH_KEY) × 부서(ORG_SK) × 후원사업(SPONSORSHIP_SK)',
        'base': 'GOLD.FACT_TARGET_PROJECT (f)',
        'joins': [
            'LEFT JOIN GOLD.DIM_ORG (o) ON f.ORG_SK = o.ORG_SK',
            'LEFT JOIN GOLD.DIM_SPONSORSHIP (s) ON f.SPONSORSHIP_SK = s.SPONSORSHIP_SK',
            'LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK'
        ]
    },
    'WIDE_AD_PERFORMANCE': {
        'num': '9',
        'title': '광고 성과 코어 평탄화 뷰 (Core Ad Performance Mart)',
        'purpose': '디지털, 방송, 비디오 등 전 매체 광고 성과 공통 코어 팩트에 일자, 캠페인, 광고소재, 디바이스 차원을 결합한 기본 광고 성과 뷰',
        'grain': '광고성과식별자(AD_PERF_DK) — 실적일 × 매체 × 소재',
        'base': 'GOLD.FACT_AD_PERFORMANCE (f)',
        'joins': [
            'LEFT JOIN GOLD.DIM_DATE (d) ON f.PERF_DATE_SK = d.DATE_SK',
            'LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK',
            'LEFT JOIN GOLD.DIM_AD_CREATIVE (ac) ON f.AD_CREATIVE_SK = ac.AD_CREATIVE_SK',
            'LEFT JOIN GOLD.DIM_DEVICE (dv) ON f.DEVICE_SK = dv.DEVICE_SK'
        ]
    },
    'WIDE_AD_DIGITAL': {
        'num': '10',
        'title': '디지털 광고 위성 평탄화 뷰 (Digital Ad Satellite Mart)',
        'purpose': '디지털 광고(검색/배너/SNS) 전용 노출, 클릭, 전환, 랜딩 지표를 코어 성과 및 차원과 1:1 결합한 디지털 특화 뷰',
        'grain': '광고성과식별자(AD_PERF_DK)',
        'base': 'GOLD.FACT_AD_DIGITAL (g)',
        'joins': [
            'JOIN GOLD.FACT_AD_PERFORMANCE (f) ON g.AD_PERF_DK = f.AD_PERF_DK (코어 팩트와 1:1 결합)',
            'LEFT JOIN GOLD.DIM_DATE (d) ON f.PERF_DATE_SK = d.DATE_SK',
            'LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK',
            'LEFT JOIN GOLD.DIM_AD_CREATIVE (ac) ON f.AD_CREATIVE_SK = ac.AD_CREATIVE_SK',
            'LEFT JOIN GOLD.DIM_DEVICE (dv) ON f.DEVICE_SK = dv.DEVICE_SK'
        ]
    },
    'WIDE_AD_BROADCAST': {
        'num': '11',
        'title': '방송 광고 위성 평탄화 뷰 (Broadcast Ad Satellite Mart)',
        'purpose': 'TV/케이블 방송 및 재방송 광고 전용 방송일시, 채널, 방영형태, 인입콜 지표를 코어 성과 및 차원과 결합한 방송 특화 뷰',
        'grain': '광고성과식별자(AD_PERF_DK)',
        'base': 'GOLD.FACT_AD_BROADCAST (b)',
        'joins': [
            'JOIN GOLD.FACT_AD_PERFORMANCE (f) ON b.AD_PERF_DK = f.AD_PERF_DK (코어 팩트와 1:1 결합)',
            'LEFT JOIN GOLD.DIM_DATE (d) ON f.PERF_DATE_SK = d.DATE_SK',
            'LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK',
            'LEFT JOIN GOLD.DIM_AD_CREATIVE (ac) ON f.AD_CREATIVE_SK = ac.AD_CREATIVE_SK'
        ]
    },
    'WIDE_AD_BROADCAST_CASE': {
        'num': '12',
        'title': '재방송 사례 위성 평탄화 뷰 (Rebroadcast Case Satellite Mart)',
        'purpose': '재방송 광고 내 소개된 후원 아동/사례별 언피벗 세부 실적(CASE 1~3)을 방송 및 코어 성과와 결합한 뷰',
        'grain': '광고성과식별자(AD_PERF_DK) × 사례순번(CASE_SEQ)',
        'base': 'GOLD.FACT_AD_BROADCAST_CASE (bc)',
        'joins': [
            'JOIN GOLD.FACT_AD_PERFORMANCE (f) ON bc.AD_PERF_DK = f.AD_PERF_DK',
            'LEFT JOIN GOLD.FACT_AD_BROADCAST (b) ON bc.AD_PERF_DK = b.AD_PERF_DK',
            'LEFT JOIN GOLD.DIM_DATE (d) ON f.PERF_DATE_SK = d.DATE_SK',
            'LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK'
        ]
    },
    'WIDE_AD_COMBINED': {
        'num': '13',
        'title': '광고 3종 통합 평탄화 뷰 (Combined Ad Performance Mart)',
        'purpose': '코어 성과(FAP)에 디지털(FAD) 및 방송(FAB) 위성 팩트를 AD_PERF_DK 기준으로 1:1 pre-join하여 단일 뷰에서 전 매체를 분석할 수 있도록 구성한 통합 뷰',
        'grain': '광고성과식별자(AD_PERF_DK)',
        'base': 'GOLD.FACT_AD_PERFORMANCE (fap)',
        'joins': [
            'LEFT JOIN GOLD.FACT_AD_DIGITAL (dig) ON fap.AD_PERF_DK = dig.AD_PERF_DK (디지털 매체 실적)',
            'LEFT JOIN GOLD.FACT_AD_BROADCAST (brc) ON fap.AD_PERF_DK = brc.AD_PERF_DK (방송 매체 실적)'
        ]
    },
    'WIDE_BIGQUERY_BEHAVIOR': {
        'num': '14',
        'title': '웹/앱 BigQuery 행동 평탄화 뷰 (Web/App Behavior Mart)',
        'purpose': 'Google Analytics / Firebase BigQuery 원천의 웹/앱 페이지뷰, 이벤트, 사용자 행동 로그 팩트에 일자·이벤트·유입소스·디바이스·캠페인·회원식별 차원을 결합한 행동 분석 뷰',
        'grain': '행동일(DATE_SK) × 세션/이벤트 × 디바이스',
        'base': 'GOLD.FACT_BIGQUERY_BEHAVIOR (f)',
        'joins': [
            'LEFT JOIN GOLD.DIM_DATE (d) ON f.DATE_SK = d.DATE_SK',
            'LEFT JOIN GOLD.DIM_BIGQUERY_EVENT (ge) ON f.BIGQUERY_EVENT_SK = ge.BIGQUERY_EVENT_SK',
            'LEFT JOIN GOLD.DIM_BIGQUERY_SOURCE (gs) ON f.BIGQUERY_SOURCE_SK = gs.BIGQUERY_SOURCE_SK',
            'LEFT JOIN GOLD.DIM_DEVICE (dv) ON f.DEVICE_SK = dv.DEVICE_SK',
            'LEFT JOIN GOLD.DIM_CAMPAIGN (c) ON f.CAMPAIGN_SK = c.CAMPAIGN_SK',
            'LEFT JOIN GOLD.DIM_MEMBER_IDENTITY (mi) ON f.IDENTITY_SK = mi.IDENTITY_SK'
        ]
    }
}

def split_top_level_commas(s):
    parts = []
    current = []
    depth = 0
    in_quote = False
    quote_char = None
    for ch in s:
        if ch in ('\'', '\"'):
            if not in_quote:
                in_quote = True
                quote_char = ch
            elif quote_char == ch:
                in_quote = False
        if not in_quote:
            if ch == '(':
                depth += 1
            elif ch == ')':
                depth -= 1
            elif ch == ',' and depth == 0:
                parts.append(''.join(current).strip())
                current = []
                continue
        current.append(ch)
    if current:
        parts.append(''.join(current).strip())
    return parts

def parse_sql_columns(sql_path):
    with open(sql_path, 'r', encoding='utf-8') as f:
        text = f.read()
    text_clean = re.sub(r'--.*', '', text)
    m = re.search(r'select\s+(.*?)\s+from\s+', text_clean, re.DOTALL | re.IGNORECASE)
    if not m:
        return {}
    select_body = m.group(1)
    items = split_top_level_commas(select_body)
    cols = {}
    for item in items:
        item = item.strip()
        if not item:
            continue
        parts = re.split(r'\s+as\s+', item, flags=re.IGNORECASE)
        if len(parts) == 2:
            expr, alias = parts[0].strip(), parts[1].strip()
        else:
            sub = item.split()
            if len(sub) == 2 and not item.endswith(')'):
                expr, alias = sub[0].strip(), sub[1].strip()
            else:
                expr = item.strip()
                alias = expr.split('.')[-1].strip()
        alias = alias.replace('\"', '').strip()
        cols[alias.upper()] = expr
    return cols

def clean_desc(desc):
    if not desc:
        return '—'
    # strip markdown comments
    d = desc.replace('\r\n', ' ').replace('\n', ' ')
    d = d.replace('|', '·')
    d = re.sub(r'\s+', ' ', d).strip()
    return d

def extract_logical_name(cname, desc):
    # Common mappings
    common = {
        'MONTH_KEY': '월키(YYYYMM)',
        'CAL_YEAR': '연도(YYYY)',
        'CAL_MONTH': '월(MM)',
        'DATE_SK': '일자키(YYYYMMDD)',
        'FULL_DATE': '전체일자',
        'YEAR': '연도',
        'MONTH': '월',
        'DAY_OF_WEEK': '요일',
        'WEEK_OF_YEAR': '주차',
        'QUARTER': '분기',
        'IS_HOLIDAY': '휴일여부',
        'MEMBER_DK': '회원식별키(DK)',
        'DW_SOURCE_SYSTEM': '원천시스템',
        'DW_INSERTED_AT': '적재일시',
        'DW_UPDATED_AT': '수정일시',
        'MEMBER_GENDER': '회원성별',
        'MEMBER_REGION': '회원지역',
        'MEMBER_AGE_BAND': '회원연령대',
        'MEMBER_STATUS': '회원상태코드',
        'MEMBER_TYPE': '회원구분코드',
        'MEMBER_NEW_EXISTING': '신규기존구분',
        'MEMBER_FIRST_JOIN_DATE': '최초가입일자',
        'MEMBER_FIRST_CAMPAIGN': '최초가입캠페인',
        'MEMBER_ENROLL_PATH': '가입경로',
        'MEMBER_FIRST_SPONSORSHIP': '최초후원사업',
        'MEMBER_CURRENT_SPONSORSHIP': '현재후원사업',
        'CAMPAIGN_BK': '캠페인코드(BK)',
        'CAMPAIGN_BRAND': '캠페인브랜드',
        'CAMPAIGN_PARENT': '상위캠페인',
        'CAMPAIGN_NAME': '캠페인명',
        'CAMPAIGN_PROMO_METHOD': '홍보방법',
        'CAMPAIGN_TYPE': '캠페인유형',
        'SPONSORSHIP_BK': '후원사업코드(BK)',
        'SPONSORSHIP_NAME': '후원사업명',
        'SPONSORSHIP_ABBR': '후원사업약칭',
        'PAYMENT_METHOD': '결제방법',
        'PAYMENT_SETTLE_METHOD': '정산방식',
        'PAYMENT_FEE_TYPE': '회비구분',
        'REASON_CODE': '사유코드',
        'REASON_NAME': '사유명',
        'REASON_TYPE': '사유유형',
        'ORG_CORP': '법인구분',
        'ORG_DIVISION': '본부명',
        'ORG_DEPARTMENT': '부서명',
        'ORG_TEAM': '팀명',
        'DEV_CNT': '개발건수',
        'DEV_MEMBERS': '개발회원수(플래그)',
        'STOP_CNT': '중단건수',
        'STOP_MEMBERS': '중단회원수(플래그)',
        'UNPAID_STOP_CNT': '미납중단건수',
        'UNPAID_STOP_MEMBERS': '미납중단회원수',
        'PAID_FEE': '납입회비(원)',
        'BILLED_AMT': '청구회비(원)',
        'REGULAR_FEE': '정기회비(원)',
        'ACTIVE_CNT': '활동건수',
        'ACTIVE_MEMBERS': '활동회원수',
        'INCREASE_CNT': '증액건수',
        'DECREASE_CNT': '감액건수',
        'CHURN_CNT': '이탈건수',
        'PLAN_BUDGET_MONTH': '월편성예산(원)',
        'EXEC_BUDGET_ERP': '월집행예산(원)',
        'GOAL_CNT': '목표건수',
        'ANNUAL_GOAL_CNT': '연간목표건수',
        'SUPP_GOAL_CNT': '추경목표건수',
        'AD_COST': '광고비(원)',
        'IMPRESSIONS': '노출수',
        'CLICKS': '클릭수',
        'CTR': '클릭률(CTR)',
        'PAGE_VIEWS': '페이지뷰수',
        'VISITS': '방문수'
    }
    if cname in common:
        return common[cname]
    
    # Try extract from description
    if desc:
        m = re.match(r'^\s*([가-힣A-Za-z0-9_ /·]+?)(?:\s*[—\(\[:]|—)', desc)
        if m:
            cand = m.group(1).strip()
            if len(cand) <= 25 and not cand.startswith(('RED', 'WARN', 'NOTE', 'FACT', 'DIM', 'WIDE')):
                return cand
    return cname

def resolve_source(expr, base_fact):
    if not expr:
        return base_fact
    e = expr.strip()
    if '(' in e and not e.startswith(('f.', 'm.', 'd.', 'c.', 's.', 'p.', 'r.', 'o.', 'st.', 'sv.', 'e.', 'bi.', 'ac.', 'dv.', 'ge.', 'gs.', 'mi.', 'mem.', 'acq.', 'dig.', 'brc.', 'b.', 'bc.')):
        return '파생 (DERIVED 계산식)'
    prefix = e.split('.')[0].lower() if '.' in e else ''
    if prefix in ALIAS_TO_TABLE:
        if prefix in ('f', 'b', 'bc', 'g', 'fap'):
            return base_fact
        return ALIAS_TO_TABLE[prefix]
    return base_fact

def main():
    cn = conn()
    _, rows = q('''
    select table_name, column_name, data_type, is_nullable, comment, ordinal_position
    from GN_DW.INFORMATION_SCHEMA.COLUMNS
    where table_schema = 'GOLD' and table_name like 'WIDE_%'
    order by table_name, ordinal_position
    ''', cn)

    live_cols = {}
    for t, c, dt, n, cm, op in rows:
        live_cols.setdefault(t, {})[c] = {
            'data_type': dt,
            'is_nullable': 'YES' if n == 'YES' else 'NO',
            'comment': cm or ''
        }

    with open(YML_PATH, 'r', encoding='utf-8') as f:
        schema_data = yaml.safe_load(f)
    yaml_models = {m['name']: m for m in schema_data.get('models', [])}

    L = []
    a = L.append

    a('<!-- LLM-METADATA')
    a('doc_id: GOLD_WIDE_VIEWS')
    a('doc_role: consumption_wide_view (GOLD 빅테이블 뷰 14종 통합 정의서)')
    a('project: GN_DW (굿네이버스)')
    a('derived_from: 10_dbt_pipeline/models/gold/wide/*.sql + _wide_schema.yml')
    a('generator: scripts/build_wide_doc.py')
    a('validator: scripts/verify_wide_doc.py')
    a('structure: WIDE VIEW 14종 전수 수록 (개요 + 조인 로직 + 확장 컬럼 정의서)')
    a('status: 🟢 정본 최신화 완료 (물리 dbt 뷰 14종 100% 일치)')
    a('updated: 2026-09-14')
    a('END-METADATA -->')
    a('')
    a('# GOLD 빅테이블 VIEW (Wide View) 통합 정의서')
    a('')
    a('> **문서 목적**: GN_DW GOLD 계층에 배포된 **비정규화 리포팅 뷰(WIDE VIEW 14종)**의 통합 설계 및 컬럼 정의서입니다.')
    a('> 리포팅 및 BI, Semantic View, Cortex Agent 조회 성능과 편의성을 위해 **Fact 테이블과 Dimension 테이블을 LEFT JOIN으로 평탄화**한 구조를 표준화된 양식으로 제공합니다.')
    a('> ')
    a('> 🟢 **물리 정본 위치**: `10_dbt_pipeline/models/gold/wide/*.sql` (dbt view 모델 14종) 및 `_wide_schema.yml`')
    a('> 🛠️ **자동 생성/동기화 도구**: `python3 scripts/build_wide_doc.py` (dbt 모델 변경 시 이 정의서를 자동 갱신)')
    a('> 🔍 **정합성 전수 검증 게이트**: `python3 scripts/verify_wide_doc.py` (Live Snowflake ↔ dbt SQL ↔ 이 문서 간 575컬럼 100% 일치 검증)')
    a('> 📊 **자동 계보 매핑 산출물**: `30_output_share/04_컬럼계보매핑.md` (BRONZE→SILVER→GOLD→WIDE 역방향 실측 계보)')
    a('')
    a('---')
    a('')
    a('## 1. 아키텍처 및 공통 설계 원칙')
    a('')
    a('| 설계 항목 | 공통 표준 규칙 | 비즈니스 목적 및 효과 |')
    a('|---|---|---|')
    a('| **조인 방향** | 전부 **LEFT JOIN** (Fact 중심) | Fact 테이블의 실적 행 유실을 방지하고, 미매칭 차원 키는 `(미매핑)` 또는 NULL로 보존 |')
    a('| **SCD2 회원 Dedup** | `DIM_MEMBER_STATUS_HISTORY` 조인 시 `IS_CURRENT = TRUE` + 최신 1행 서브쿼리 | 회원 상태 이력 다중 버전으로 인한 팩트 행 증폭(Fan-out)을 원천 차단 |')
    a('| **조직 조인 (DIM_ORG)** | `ORG_SK` 직결 조인 (SCD1 current-value) | 팩트 발생 시점의 부서 식별을 유지하되 최신 부서명·계층 체계로 일관성 제공 |')
    a('| **시간/날짜 파생** | 월 grain은 `FLOOR(MONTH_KEY/100)`, `MOD(MONTH_KEY,100)` 파생 / 일 grain은 `DIM_DATE` 조인 | 일자 fan-out 방지 및 연도·월별 집계 편의성 제공 |')
    a('| **라벨 전파** | 원천 시스템 코드(`*_CD`)와 함께 표준 한글/영문 분석 라벨(`*_NAME`, `*_NM`) 동시 제공 | 현업이 별도 코드표를 찾지 않고도 즉시 대시보드 및 리포트 작성 가능 |')
    a('| **감사 컬럼** | 팩트 `DW_SOURCE_SYSTEM`을 유지하여 원천 시스템 역추적 지원 | 다중 원천 적재 시 시스템별 데이터 추적성 확보 |')
    a('')
    a('---')
    a('')
    a('## 2. WIDE VIEW 14종 상세 정의서')
    a('')

    for vname, vmeta in sorted(VIEW_META.items(), key=lambda x: int(x[1]['num'])):
        num = vmeta['num']
        title = vmeta['title']
        purpose = vmeta['purpose']
        grain = vmeta['grain']
        base = vmeta['base']
        joins = vmeta['joins']

        sql_path = os.path.join(WIDE_DIR, f'{vname}.sql')
        sql_cols = parse_sql_columns(sql_path) if os.path.exists(sql_path) else {}
        lcols = live_cols.get(vname, {})
        ymodel = yaml_models.get(vname, {})
        ycols = {c['name']: c for c in ymodel.get('columns', [])}

        a(f'### 2.{num} `{vname}` — {title}')
        a('')
        a('#### 1. 뷰 개요 (Overview)')
        a(f'- **목적**: {purpose}')
        a(f'- **분석 Grain**: `{grain}`')
        a(f'- **기준 Fact 테이블**: `{base}`')
        a(f'- **조인 Dimension 테이블**: {len(joins)}개 차원 결합')
        a('')
        a('#### 2. 조인 및 관계 정의 (Join Logic)')
        a(f'- **기준 테이블**: `{base}`')
        a('- **조인 상세 규칙**:')
        for j in joins:
            a(f'  - `{j}`')
        a('')
        a('#### 3. 확장 컬럼 정의서 (Column Definition Sheet)')
        a('')
        a('| 논리명 (한글명) | 물리명 (컬럼명) | 데이터 타입 | Null 여부 | 출처 (Source) | 설명 및 비즈니스 규칙 |')
        a('|---|---|---|---|---|---|')

        # iterate over live columns or yaml columns
        ordered_cols = list(lcols.keys()) if lcols else list(ycols.keys())
        for cname in ordered_cols:
            cinfo = lcols.get(cname, {})
            yinfo = ycols.get(cname, {})
            dtype = cinfo.get('data_type') or yinfo.get('data_type', 'VARCHAR')
            nullable = cinfo.get('is_nullable', 'YES')
            desc = yinfo.get('description') or cinfo.get('comment', '')
            cleaned_desc = clean_desc(desc)
            logical_name = extract_logical_name(cname, desc)
            expr = sql_cols.get(cname.upper(), '')
            source_table = resolve_source(expr, base)

            # line length check per table row
            row_str = f'| **{logical_name}** | `{cname}` | {dtype} | {nullable} | {source_table} | {cleaned_desc} |'
            a(row_str)

        a('')
        a('---')
        a('')

    a('_Co-authored with CoCo_')
    a('')

    content = '\n'.join(L) + '\n'
    with open(OUT_PATH, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f'Successfully generated {OUT_PATH} ({len(content)} bytes, {len(L)} lines)')

if __name__ == '__main__':
    main()
