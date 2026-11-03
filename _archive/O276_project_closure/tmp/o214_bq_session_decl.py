#!/usr/bin/env python3
"""O214 — range 모델 2종(SILVER.BIGQUERY_SESSION · GOLD.FACT_BIGQUERY_SESSION) 컬럼 COMMENT 정본 선언.

🔴 두 테이블은 **선생성 금지**(range 모델 · 테이블이 있으면 첫 run 이 롤링 창만 적재)
   ⇒ 선언은 `/* … */` 비실행 블록으로 둔다. comment_drift_gate 파서는 블록 안 선언도 읽으므로
     이 블록이 **파일 정본**이 되고, 라이브 반영은 apply_*_comment_drift.py(ALTER) 가 한다.
원값 열거 = 2026-10-08 라이브 DISTINCT 실측(SILVER.BIGQUERY_SESSION) · 수치·세션 태그 없음(05_0 규약 1·3·4).
사용: python3 tmp/o214_bq_session_decl.py [--apply]
Co-authored with CoCo
"""
import io
import sys

F1 = '첫 non-NULL 값(EVENT_TIMESTAMP 순 · 세션 진입 시점 값 · 세션 내 전 이벤트가 NULL 이면 NULL)'
ATTR = [
    ('PLATFORM', 'GA4 플랫폼(WEB) · ' + F1),
    ('DEVICE_CATEGORY', '기기 카테고리(mobile·desktop·tablet·smart tv) · ' + F1),
    ('DEVICE_OPERATING_SYSTEM', '운영체제 원값(Android·iOS·Windows·Macintosh·Linux·Chrome OS 등) · ' + F1),
    ('DEVICE_WEB_INFO_BROWSER', '브라우저 원값(Chrome·Android Webview·Edge·Samsung Internet·Safari 등) · ' + F1),
    ('DEVICE_LANGUAGE', '기기 언어 로캘 원값(ko-kr·ko·en-us 등) · ' + F1),
    ('DEVICE_MOBILE_BRAND_NAME', '기기 제조사 원값(Samsung·Apple 등) · ' + F1),
    ('DEVICE_WEB_INFO_HOSTNAME', '접속 호스트명 원값(www.goodneighbors.kr·m.goodneighbors.kr 등) · ' + F1),
    ('GEO_CONTINENT', '대륙(Asia·Americas·Europe·Oceania·Africa·(not set)) · (not set) = GA4 위치 미판정 원값 · ' + F1),
    ('GEO_SUB_CONTINENT', '하위 대륙 GA4 영문 원값(Eastern Asia 등 · (not set) 포함) · ' + F1),
    ('GEO_COUNTRY', '국가 GA4 영문 원값(South Korea 등) · ' + F1),
    ('GEO_METRO', '대도시권 GA4 원값((not set) 포함) · ' + F1),
    ('TS_SOURCE', '사용자 최초 유입 소스(traffic_source.source 원값 · google·(direct)·네이버M 등) · ' + F1),
    ('TS_MEDIUM', '사용자 최초 유입 매체(traffic_source.medium 원값 · cpc·organic·(none) 등) · ' + F1),
    ('CTS_MANUAL_MEDIUM', '수집 트래픽 수동 매체(collected_traffic_source.manual_medium = utm_medium 원값) · ' + F1),
    ('EP_MEDIUM', '이벤트 파라미터 medium 원값 · ' + F1),
    ('STSLC_CRC_DEFAULT_CHANNEL_GROUP',
     '세션 기본 채널 그룹(last click cross-channel · Display·Cross-network·Direct·Unassigned·Organic Search·'
     'Organic Social·Paid Search·Paid Other·Referral·Email·SMS·AI Assistant·Paid Social·Organic Video·'
     'Mobile Push Notifications) · ' + F1),
    ('STSLC_CRC_PRIMARY_CHANNEL_GROUP', '세션 주 채널 그룹(값 체계는 기본 채널 그룹과 같다) · ' + F1),
    ('STSLC_CRC_SOURCE_PLATFORM', '세션 소스 플랫폼(Manual·Google Ads·Meta Ads·Other Ads·Unlabeled) · ' + F1),
    ('STSLC_GAC_CAMPAIGN_NAME', 'Google Ads 캠페인명 원값(세션 last click) · ' + F1),
    ('STSLC_GAC_AD_GROUP_NAME', 'Google Ads 광고그룹명 원값((not set) 포함) · ' + F1),
    ('UP_MEMBER_TYPE', '회원유형 user_property 원값(비로그인·정기회원·일시회원·중단회원·앱회원·활동회원·정기후원·일시후원·후원중단) · '
     '🔴 GTM 미치환 변수명 원문(이중 중괄호로 감싼 값)은 수집 오류다(원값 보존) · ' + F1),
    ('UP_DONOR_TYPE', '후원자유형 user_property(개인·단체·기업) · ' + F1),
    ('UP_DONATION_TYPE', '후원유형 user_property 원값(신규후원·증액후원·증액·감액·재후원) · ' + F1),
    ('UP_BIZ_TYPE', '후원사업유형 user_property 원값(복수 사업은 | 로 이어진 한 문자열) · ' + F1),
    ('UP_LOGIN_STATUS', '로그인 여부 user_property(y·n) · 🔴 GTM 미치환 변수명 원문은 수집 오류다 · ' + F1),
    ('EP_PAYMENT_TYPE', '결제수단 이벤트 파라미터(신용카드·계좌이체·네이버페이) · ' + F1),
]
AUD = '(공통감사)'

SILVER = (
    [('EVENT_DT', 'DATE', '세션 일자(원천 EVENT_DATE YYYYMMDD) · 자정을 넘는 세션은 일자별로 나뉜다.'),
     ('USER_PSEUDO_ID', 'VARCHAR(200)', 'GA4 가명 사용자 ID(브라우저·앱 단위 · 원천 user_pseudo_id).'),
     ('BIGQUERY_SESSION_ID', 'NUMBER', 'GA4 세션ID(EP_GA_SESSION_ID TRY_CAST) · 세션ID 결측 이벤트는 적재하지 않는다.'),
     ('BIGQUERY_SESSION_KEY', 'VARCHAR', '세션 자연키 = USER_PSEUDO_ID-EP_GA_SESSION_ID · 기간 세션수는 이 키의 COUNT(DISTINCT).'),
     ('BIGQUERY_SESSION_NUMBER', 'NUMBER', '사용자 기준 세션 순번(EP_GA_SESSION_NUMBER 최댓값).'),
     ('SESSION_START_TS', 'TIMESTAMP_NTZ', '그 일자 안 세션 첫 이벤트 시각(EVENT_TIMESTAMP 마이크로초 최솟값 → TIMESTAMP_NTZ).')]
    + [(c, 'VARCHAR', d + '.') for c, d in ATTR]
    + [('EVENT_CNT', 'NUMBER', '그 일자·세션의 이벤트 수(가산).'),
       ('PAGE_VIEW_CNT', 'NUMBER', 'page_view 이벤트 수(가산).'),
       ('IS_ENGAGED', 'BOOLEAN', 'GA4 참여 세션 여부(EP_SESSION_ENGAGED = 1 이벤트가 하나라도 있으면 TRUE).'),
       ('ENGAGEMENT_TIME_MSEC', 'NUMBER', '참여 시간 합계(밀리초 · EP_ENGAGEMENT_TIME_MSEC 합 · 가산).'),
       ('DW_SOURCE_SYSTEM', 'VARCHAR', '원천 시스템 식별 ' + AUD),
       ('DW_SOURCE_TABLE', 'VARCHAR', '원천 테이블 식별 ' + AUD),
       ('DW_LOAD_TS', 'TIMESTAMP_NTZ', '최초 적재 시각 ' + AUD),
       ('DW_UPDATE_TS', 'TIMESTAMP_NTZ', '최종 갱신 시각 ' + AUD),
       ('DW_BATCH_ID', 'VARCHAR', '적재 배치 식별자 ' + AUD + ' · 이 모델은 채우지 않아 NULL 이다.')]
)
S_TBL = ('GA4 세션 속성. [Grain: EVENT_DT × USER_PSEUDO_ID × BIGQUERY_SESSION_ID (자정 경계 세션은 일자별로 나뉜다)]. '
         '[주의: 속성 = 세션 첫 non-NULL 값 · 원값 보존 · range 재적재 · 선생성 금지]. '
         '[원천: GA4 → SILVER.BIGQUERY_REFINED_DATA].')

GOLD = (
    [('DATE_SK', 'NUMBER(8,0)', '세션 일자 YYYYMMDD(FK→DIM_DATE · 0 = Unknown).'),
     ('IDENTITY_SK', 'NUMBER', 'FK→DIM_MEMBER_IDENTITY · 0 = 미매칭(회원 연계가 없는 방문자 · SK=0 시드 멤버).'),
     ('BIGQUERY_SESSION_KEY', 'VARCHAR', '세션 자연키 = USER_PSEUDO_ID-GA_SESSION_ID · 기간 세션수는 이 키의 COUNT(DISTINCT)(자정 경계 세션은 일자별 행).'),
     ('USER_PSEUDO_ID', 'VARCHAR', 'GA4 가명 사용자 ID [SILVER.BIGQUERY_SESSION 승계].'),
     ('BIGQUERY_SESSION_NUMBER', 'NUMBER', '사용자 기준 세션 순번 [SILVER.BIGQUERY_SESSION 승계].'),
     ('SESSION_START_TS', 'TIMESTAMP_NTZ', '그 일자 안 세션 첫 이벤트 시각 [SILVER.BIGQUERY_SESSION 승계].')]
    + [(c, 'VARCHAR', d + ' [SILVER.BIGQUERY_SESSION 승계].') for c, d in ATTR]
    + [('EVENT_CNT', 'NUMBER', '그 일자·세션의 이벤트 수(가산).'),
       ('PAGE_VIEW_CNT', 'NUMBER', 'page_view 이벤트 수(가산).'),
       ('ENGAGED_FLAG', 'NUMBER', 'GA4 참여 세션 1/0(SILVER IS_ENGAGED 파생 · 참여 세션수 = SUM).'),
       ('ENGAGEMENT_TIME_MSEC', 'NUMBER', '참여 시간 합계(밀리초 · 가산).'),
       ('DW_SOURCE_SYSTEM', 'VARCHAR', '원천 시스템 식별 ' + AUD),
       ('DW_LOAD_TS', 'TIMESTAMP_NTZ', '최초 적재 시각 ' + AUD),
       ('DW_UPDATE_TS', 'TIMESTAMP_NTZ', '최종 갱신 시각 ' + AUD),
       ('DW_BATCH_ID', 'VARCHAR', '적재 배치 식별자 = dbt invocation_id ' + AUD)]
)
G_TBL = ('GA4 세션 팩트. [Grain: DATE_SK × BIGQUERY_SESSION_KEY]. '
         '[주의: FACT_BIGQUERY_BEHAVIOR 와 같은 원천 다른 Grain, 합산 금지 · 세션수는 COUNT(DISTINCT BIGQUERY_SESSION_KEY) · 선생성 금지]. '
         '[원천: GA4 → SILVER.BIGQUERY_SESSION].')


def block(fq, cols, tcm):
    q = lambda s: s.replace("'", "''")
    w = max(len(c) for c, _, _ in cols) + 2
    out = ['/* ── 비실행 선언(COMMENT 정본 전용) — 이 블록을 실행하지 마라: range 모델은 선생성 금지 ──',
           f'CREATE OR REPLACE TABLE {fq} (']
    for i, (c, t, d) in enumerate(cols):
        sep = ',' if i < len(cols) - 1 else ''
        out.append(f"    {c.ljust(w)}{t.ljust(16)}COMMENT '{q(d)}'{sep}")
    out.append(f") COMMENT = '{q(tcm)}';")
    out.append('── 비실행 선언 끝 */')
    return '\n'.join(out) + '\n'


TARGETS = [
    ('/workspace/04_silver_design/08_SILVER_테이블DDL_20260714.sql',
     '--      ⇒ 첫 build 가 CTAS 로 전량 생성 · 컬럼 COMMENT 는 build 후 ALTER(§13-1-8).\n'
     '-- ============================================================================\n',
     block('GN_DW.SILVER.BIGQUERY_SESSION', SILVER, S_TBL)),
    ('/workspace/03_top-down_gold/06_DDL.sql',
     '--      첫 build CTAS 전량 생성 후 COMMENT ALTER(계획서 §13-1-8).\n',
     block('GN_DW.GOLD.FACT_BIGQUERY_SESSION', GOLD, G_TBL)),
]

if __name__ == '__main__':
    for f, anchor, blk in TARGETS:
        src = io.open(f, encoding='utf-8').read()
        if 'BIGQUERY_SESSION (' in src and '비실행 선언(COMMENT 정본 전용)' in src and blk.split('\n')[1] in src:
            print('이미 반영', f)
            continue
        n = src.count(anchor)
        print(n, f)
        if n != 1:
            sys.exit('앵커 불일치 — 중단')
        if '--apply' in sys.argv:
            io.open(f, 'w', encoding='utf-8', newline='').write(src.replace(anchor, anchor + blk))
            print('APPLY', f)
