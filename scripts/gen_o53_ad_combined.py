#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
O53 — `GOLD.WIDE_AD_COMBINED`(dbt 소유 GOLD 뷰) 모델 + yml columns[] 기계 생성.
Co-authored with CoCo

무엇을 만드는가
  광고 팩트 3종(FAP 코어 + FAD 디지털위성 + FAB 방송위성)을 `AD_PERF_DK` 로 1:1 pre-join 한
  **51컬럼 GOLD 뷰**. SV_AD 의 새 base 다(재배선은 O53 6단계).

왜 GOLD 뷰인가 (사용자 제약 3개를 동시에 만족하는 유일 형태)
  ① 데이터 중복 저장 불가        → 뷰(물리 저장 0)
  ② SV 는 GOLD 만 본다           → 스키마를 SERVING → GOLD 로 올린다
  ③ 다음 주 신설 코드 즉시 반영   → dbt 모델 1곳 수정 + ref() 위상정렬·리니지·build 게이트
  DEC-34 분류상 **③(팩트를 재구성 → ref() 필수)** 에 정확히 해당한다.
  ⚠️ 대가: SV_AD 가 「dbt build 없이는 배포 불가」 계열로 편입된다.

종전 대비 달라지는 것
  · 스키마 SERVING → GOLD · 소유주 SQL 스크립트(05_7_SV_DDL_AD.sql 내부) → dbt 모델
  · **방송 시간축 4컬럼 추가**(AD_START_TIME·AD_END_TIME·BROADCAST_DATE·PRG_START_TIME)
    → helper 뷰가 이 4컬럼을 빼고 있어 SV_AD 에서 방송 시각 축이 도달 불가였다.

문안: 신규 작성 0 — `06_DDL.sql` 의 세 팩트 인라인 COMMENT 를 파싱해 이관한다.
  · 이름이 바뀐 2컬럼(BRDC_AD_VIEW_RT_SRC·BRDC_CPC_SRC)은 접두 사유를 덧붙인다.
  · 방송 전용 컬럼에는 **디지털행 NULL = 원천 부재** 경고를 덧붙인다(P20 — 시간축 NULL 3분류).
  · 시간축 4컬럼에는 **VIDEO 전용 · REBRDC 구조적 부재** 를 덧붙인다(원장 §429 기지 사실).
"""
import io
import re
import sys

DDL = '/workspace/03_top-down_gold/06_DDL.sql'
OUT_SQL = '/workspace/10_dbt_pipeline/models/gold/wide/WIDE_AD_COMBINED.sql'
OUT_YML = '/tmp/o53_out/WIDE_AD_COMBINED.cols.yml'

CORE = ['AD_PERF_DK', 'PERF_DATE_SK', 'CAMPAIGN_SK', 'MKTG_CAMPAIGN_SK', 'AD_CREATIVE_SK',
        'DEVICE_SK', 'AD_COST', 'IMPRESSIONS', 'CLICKS', 'INBOUND_CALL', 'GA_CONV_MEMBERS',
        'GA_CONV_CNT', 'DAY_OF_WEEK', 'WEEK_OF_YEAR', 'AD_SOURCE_TYPE']
DIG = ['PAGE_TYPE', 'AD_GROUP_NM', 'GROUP_DIV', 'CREATIVE_TYPE', 'AD_TYPE_NM', 'READ_CNT',
       'MEDIA_POTENTIAL_CUST_CNT', 'CRM_DEV_CNT', 'CTR_SRC', 'CVR_SRC', 'CPC_SRC', 'CPM_SRC',
       'CPA_SRC', 'DEV_UNIT_PRICE_SRC', 'VTR_SRC']
# 방송 위성 — 시간축 4컬럼(★)은 helper 뷰에 없었던 O53 신규 노출분
BRC = ['TIME_BAND', 'CM_POSITION', 'RT_TYPE', 'AD_START_TIME', 'AD_END_TIME', 'BROADCAST_DATE',
       'PROGRAM_NM', 'CHANNEL_COMPANY', 'CHANNEL_COMPANY_TYPE', 'SPOT_TYPE', 'DURATION_SEC',
       'DAY_DIV', 'PRG_START_TIME', 'CTV_DIV', 'BRDC_DIV', 'AD_CNT', 'CONV_CALL_CNT',
       'DVLP_MEMBER_CNT', 'DVLP_CNT', 'AD_VIEW_RT_SRC', 'CPC_SRC']
NEW_TIME = ['AD_START_TIME', 'AD_END_TIME', 'BROADCAST_DATE', 'PRG_START_TIME']
RENAME = {'AD_VIEW_RT_SRC': 'BRDC_AD_VIEW_RT_SRC', 'CPC_SRC': 'BRDC_CPC_SRC'}

WARN_DIG = (" ⚠️[WIDE_AD_COMBINED] 디지털 원천 전용 컬럼이다 — 방송행(AD_SOURCE_TYPE 이 디지털이 아닌 행)은 "
            "**NULL 이며 그것은 결측이 아니라 원천 부재**다(위성 완전분할). 혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.")
WARN_BRC = (" ⚠️[WIDE_AD_COMBINED] 방송 원천 전용 컬럼이다 — 디지털행은 **NULL 이며 결측이 아니라 원천 부재**다. "
            "혼합 집계 전에 AD_SOURCE_TYPE 으로 스코프할 것.")
WARN_TIME = (" 🔴🔴[WIDE_AD_COMBINED] **VIDEO(본방송) 전용이다** — 재방송(REBRDC) 원천에는 이 컬럼이 "
             "**아예 없다**(BRONZE `REBRDC_AD_CMPGN_DTLS` 에 시각 컬럼 부재 · 보유 항목은 방송시간·방송월뿐). "
             "따라서 재방송행의 NULL 은 적재 지연이 아니라 **해당 없음**이다(P20 3분류). "
             "시각 기반 분석은 VIDEO 로 스코프하고, 재방송을 포함한 시간대 분석은 TIME_BAND 를 쓸 것. "
             "전용축 판정 근거 = 이슈원장 §429.")
WARN_RENAME = (" ⚠️[WIDE_AD_COMBINED] 디지털 위성에 동명 컬럼이 있어 **BRDC_ 접두**를 붙였다 — "
               "이 컬럼은 방송 원천값이다. 디지털 쪽 동명 컬럼과 같은 표에서 비교하지 말 것.")

# ── 규칙7 치환 (이관 전용) ────────────────────────────────────────────────────
# 🔴 [O53 적발] 기존 `06_DDL.sql` 팩트 COMMENT 에는 실측 수치가 박혀 있다 — 규칙7 위반이다.
#    전수(파싱 가능분 579컬럼) 기준 39건 · 15테이블. O51-D 는 규칙7 을 **뷰 문안에만** 적용했고
#    테이블 COMMENT 는 그 이전 작성분이라 미적용 상태였다(원장 §O53 에 등재 · 교정은 별건).
# ⇒ 본 생성기는 **이관하는 문안만** 규칙7 을 만족하도록 치환한다(O51-D-B 선례: 수치 → 원장 참조).
#    원본 06_DDL COMMENT 는 건드리지 않는다 — 39건 일괄 교정은 별도 검토가 필요한 작업이다.
RULE7_OVERRIDE = {
    'MKTG_CAMPAIGN_SK':
        "[O45] 마케팅캠페인 대리키 (FK→DIM_MARKETING_CAMPAIGN). 광고↔CRM 결합축. "
        "🔴미도달 행은 0(미매핑) 버킷이며 이 버킷을 「미집행」으로 읽지 말 것 — 도달률 실측은 이슈원장 §O45. "
        "🔴개발캠페인(CAMPAIGN_SK) grain 결합 금지 — 광고비가 대규모로 팬아웃한다(배수 실측 = 이슈원장 §O45).",
    'GA_CONV_MEMBERS':
        "GA전환수(명) — **DIGITAL 전용**. ⚠️O16 교정(2026-07-28): 종전에 REBRDC 개발회원수가 혼입돼 있었다 "
        "— 재방송 개발실적은 FACT_AD_BROADCAST.DVLP_MEMBER_CNT 로 이관했다. 혼입 규모 = 이슈원장 §O16.",
    'GA_CONV_CNT':
        "GA전환수(건/VU) — **DIGITAL 전용**. ⚠️O16 교정(2026-07-28): 종전에 REBRDC 개발건수가 혼입돼 있었고 "
        "그 비중이 과반이었다 → FACT_AD_BROADCAST.DVLP_CNT 로 이관. 혼입 규모 = 이슈원장 §O16. "
        "⚠️합계가 소수로 나오므로 건수가 아니다 — 어의 현업확인 잔여(O5).",
    'DURATION_SEC':
        "🔴 광고 초수 ← VIDEO.AD_SEC(TEXT→TRY_TO_NUMBER) [VIDEO 전용] — **현재 값 신뢰 금지(O29)**. "
        "적재값의 스케일이 「초」로 읽으면 맞지 않는다(µs 해석 유력하나 미확정·현업 확인 대기). "
        "원천 HH:MM:SS 형식 행이 캐스팅에서 무성 소실돼 유효 커버리지가 매우 낮다(파싱하면 대부분 회복) "
        "— 규모 실측은 이슈원장 §O29. REBRDC NULL 은 결손이 아니라 원천 부재.",
    'DVLP_MEMBER_CNT':
        "개발회원수 ← REBRDC.DVLP_MBER_CNT [REBRDC 전용]. ⚠️O16 이관: 종전에 코어 GA_CONV_MEMBERS 로 "
        "혼입돼 있었다(GA 전환이 아니라 재방송 개발실적). "
        "⚠️소수 척도를 유지하는 이유 = 원천에 0.5 단위 값이 실존해 정수 타입으로 내리면 반올림이 총합을 "
        "왜곡한다 — 해당 행·왜곡 규모는 이슈원장 §O16. 원천값 보존 우선.",
}


def parse_ddl_comments(table):
    """06_DDL.sql 의 CREATE 블록에서 컬럼명 → 인라인 COMMENT 를 뽑는다."""
    s = io.open(DDL, encoding='utf-8').read()
    i = s.index(f'CREATE OR REPLACE TABLE GN_DW.GOLD.{table} (')
    j = s.index(';', i)
    out = {}
    for line in s[i:j].split('\n'):
        m = re.match(r"\s+([A-Z0-9_]+)\s+\S+.*?COMMENT\s+'(.*)'\s*,?\s*(--.*)?$", line)
        if m:
            out[m.group(1)] = m.group(2).replace("''", "'")
    return out


def main():
    fap = parse_ddl_comments('FACT_AD_PERFORMANCE')
    dig = parse_ddl_comments('FACT_AD_DIGITAL')
    brc = parse_ddl_comments('FACT_AD_BROADCAST')

    cols = []          # (출력컬럼명, 원본표현, 문안)
    for c in CORE:
        assert c in fap, f'🔴 FAP 문안 결손: {c}'
        cols.append((c, f'fap.{c}', RULE7_OVERRIDE.get(c, fap[c])))
    for c in DIG:
        assert c in dig, f'🔴 FAD 문안 결손: {c}'
        cols.append((c, f'dig.{c}', RULE7_OVERRIDE.get(c, dig[c]) + WARN_DIG))
    for c in BRC:
        assert c in brc, f'🔴 FAB 문안 결손: {c}'
        out = RENAME.get(c, c)
        expr = f'brc.{c}' + (f'{"":<1}as {out}' if c in RENAME else '')
        d = RULE7_OVERRIDE.get(c, brc[c]) + (WARN_TIME if c in NEW_TIME else WARN_BRC)
        if c in RENAME:
            d += WARN_RENAME
        cols.append((out, expr, d))

    # ── 게이트 ────────────────────────────────────────────────────────────────
    names = [c[0] for c in cols]
    dup = sorted({n for n in names if names.count(n) > 1})
    miss = [n for n, _e, d in cols if not d.strip()]
    NUM = [re.compile(r'[0-9]{1,3}(,[0-9]{3})+'), re.compile(r'[0-9]+(\.[0-9]+)?%'),
           re.compile(r'[0-9]+(\.[0-9]+)?배')]
    WHITE = re.compile(r'#[0-9]+|(CM|MM|MS|PM|CONF|DEC|O|P|E|G|Q|AD|SVL|R)-?[0-9]+|[0-9]+0대|'
                       r'[0-9]+대|NUMBER\([0-9,]+\)|VARCHAR\([0-9]+\)|YYYYMM(DD)?')
    viol = [n for n, _e, d in cols if any(rx.search(WHITE.sub('', d)) for rx in NUM)]
    todo = [n for n, _e, d in cols if 'TODO' in d]
    print(f'컬럼 {len(cols)} (코어 {len(CORE)} + 디지털 {len(DIG)} + 방송 {len(BRC)}) '
          f'· 신규 노출 시간축 {len(NEW_TIME)} · 개명 {len(RENAME)}')
    print(f'게이트: 중복={len(dup)} 문안결손={len(miss)} 규칙7위반={len(viol)} TODO={len(todo)}')
    for label, items in (('중복', dup), ('문안 결손', miss), ('규칙7 위반', viol), ('TODO', todo)):
        if items:
            print(f'  🔴 {label}: {items}')
    if dup or miss or viol or todo or len(cols) != 51:
        sys.exit(f'🔴 게이트 실패 (컬럼 {len(cols)} ≠ 51)')

    # ── 모델 SQL ──────────────────────────────────────────────────────────────
    body = [io.open(__file__, encoding='utf-8').read().split('"""')[1].strip()]
    hdr = '\n'.join('-- ' + l if l.strip() else '--' for l in body[0].split('\n'))
    sql = [hdr,
           "--",
           "-- ⚠️ 컬럼 COMMENT 정본 = `_wide_schema.yml` columns[] (materialized='gn_view_commented').",
           "--   SELECT 컬럼·순서를 바꾸면 `scripts/gen_o53_ad_combined.py` 로 **동시 재생성**할 것 —",
           "--   Snowflake 는 CREATE VIEW 컬럼목록과 SELECT 개수·순서가 정확히 일치해야 한다.",
           "{{ config(",
           "    materialized='gn_view_commented',",
           "    tags=['gold_wide']",
           ") }}",
           "",
           "select"]
    for k, (_n, expr, _d) in enumerate(cols):
        if k == 0:
            sql.append('    -- ── 코어(FAP) — 3원천 공통 ──')
        if _n == DIG[0]:
            sql.append('    -- ── 디지털 위성(FAD) — 방송행은 NULL(원천 부재) ──')
        if _n == BRC[0]:
            sql.append('    -- ── 방송 위성(FAB) — 디지털행은 NULL(원천 부재) · 시간축 4컬럼은 VIDEO 전용 ──')
        sql.append(f'    {expr}' + (',' if k < len(cols) - 1 else ''))
    sql += ["from {{ ref('FACT_AD_PERFORMANCE') }} fap",
            "-- 위성은 AD_PERF_DK 로 원천유형별 완전분할이라 LEFT JOIN 이 행수를 늘리지 않는다(fan-out 0).",
            "--   1:N 위성인 FACT_AD_BROADCAST_CASE 는 **의도적으로 제외**한다 — 사례 수만큼 광고비가 복제된다.",
            "left join {{ ref('FACT_AD_DIGITAL') }}   dig on fap.AD_PERF_DK = dig.AD_PERF_DK",
            "left join {{ ref('FACT_AD_BROADCAST') }} brc on fap.AD_PERF_DK = brc.AD_PERF_DK",
            ""]
    io.open(OUT_SQL, 'w', encoding='utf-8').write('\n'.join(sql))

    # ── yml columns[] ─────────────────────────────────────────────────────────
    y = ['    columns:']
    for n, _e, d in cols:
        esc = d.replace('\\', '\\\\').replace('"', '\\"')
        y += [f'      - name: {n}', f'        description: "{esc}"']
    io.open(OUT_YML, 'w', encoding='utf-8').write('\n'.join(y) + '\n')

    print(f'\n✅ 생성: {OUT_SQL}')
    print(f'   yml columns[] = {OUT_YML} (51건 · _wide_schema.yml 삽입은 별도 단계)')


if __name__ == '__main__':
    main()
