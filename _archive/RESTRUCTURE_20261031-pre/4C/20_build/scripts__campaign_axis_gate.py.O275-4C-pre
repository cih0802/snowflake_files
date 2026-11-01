#!/usr/bin/env python3
"""BRONZE 캠페인 컬럼 → SILVER·GOLD·SV 배선 등재표 대조 · 미등재 FAIL · GAP 은 경고

🆕 [O225-C 신설 · `new_tool.py` 경유 ⇒ `gate_census` 등재 완료]
🔴 분류 = `JUDGE`. 이 분류의 계약을 지켜라(정본 = `scripts/gate_census.py`).
🔴 종료코드가 판정이다 — 위반이면 1, 통과면 0. 음성 테스트 = `scripts/test_campaign_axis_gate.py`(`R3-2`).

왜 있는가 (O225-B 사용자 지적)
  「bronze 에 있는 카테고리/차원은 전부 SV 까지」를 이전 세션에 작업했는데도 누락이 남았다.
  누락은 조용하다 — SV 가 없으면 Agent 가 「차원이 없다」고 답하고 아무 게이트도 울리지 않았다.
  ⇒ BRONZE 캠페인 컬럼 **전수**를 분모로 두고, 컬럼마다 상태를 하나 고르게 한다:
    · WIRED  = 끝까지 배선 — `checks` 의 (파일, 토큰)이 **전부 실재**해야 한다(아니면 FAIL · 배선 끊김)
    · GAP    = 미배선임을 알고 등재 — 사유 필수 · 🟠 경고로 매번 노출한다(조용히 묻히지 않게)
    · EXEMPT = 캠페인 축이 아님(키워드 오탐·코드사전·자유문·원천 전량 NULL) — 사유 필수
  분모(`BRONZE_SNAPSHOT`)에 있는데 등재가 없으면 FAIL · 등재만 있고 분모에 없으면 FAIL(낡은 행).

분모 갱신
  `BRONZE_SNAPSHOT` = 2026-10-14 O225-C xh20001 INFORMATION_SCHEMA 실측
  (`table_schema like 'BRONZE%'` · 컬럼명 CMPGN/CAMPAIGN/CONTENTS 또는 COMMENT 캠페인/콘텐츠구분).
  🔴 원천에 컬럼이 늘면 이 집합을 다시 떠서 갱신한다 — 이 게이트는 라이브를 보지 않는다(오프라인 판정).

사용법
  python3 scripts/campaign_axis_gate.py            # 판정(rc 0/1)
  python3 scripts/campaign_axis_gate.py --gaps     # GAP 목록만 출력(판정 동일)
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

M = '10_dbt_pipeline/models/'
SV = '05_SV-Agent_ai/'
F_DIM_CAMPAIGN = M + 'gold/dim/DIM_CAMPAIGN.sql'
F_FAP = M + 'gold/fact/FACT_AD_PERFORMANCE.sql'
F_SV_AD = SV + '05_07_SV_DDL_AD.sql'
F_MACRO = '10_dbt_pipeline/macros/billing_campaign_asof.sql'

BRONZE_SNAPSHOT = {
    'BRONZE_AGENCY.DGT_AD_CMPGN_DTLS.CMPGN_NM',
    'BRONZE_AGENCY.DGT_AD_CMPGN_DTLS.CMPGN_TYPE1_BSN_NM',
    'BRONZE_AGENCY.DGT_AD_CMPGN_DTLS.CMPGN_TYPE2_BSN_NM',
    'BRONZE_AGENCY.DGT_AD_CMPGN_DTLS.CMPGN_TYPE_BSN_NM',
    'BRONZE_AGENCY.DGT_AD_CMPGN_DTLS.UTM_CMPGN_NM',
    'BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS.CMPGN_CD',
    'BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS.CONTENTS_PUR_COST',
    'BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS.UPPER_CMPGN_CD',
    'BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.BSNS_CASE_DIV_NM',
    'BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.CMPGN_NM',
    'BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.CMPGN_TY_NM',
    'BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.DMST_OVSEA_DIV_NM',
    'BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.UPPER_CMPGN_NM',
    'BRONZE_CRM.SND_MEMBER_LIST.CMPGN_CD',
    'BRONZE_CRM.SND_MEMBER_LIST.CMPGN_NM',
    'BRONZE_CRM.SND_MEMBER_LIST.CURRENT_CMPGN',
    'BRONZE_CRM.SND_MEMBER_LIST.CURRENT_UPPER_CMPGN',
    'BRONZE_CRM.SND_MEMBER_LIST.FIRST_CMPGN',
    'BRONZE_CRM.SND_MEMBER_LIST.FIRST_UPPER_CMPGN',
    'BRONZE_CRM.SND_MEMBER_LIST.LAST_CMPGN',
    'BRONZE_CRM.SND_MEMBER_LIST.LAST_TOP_CMPGN',
    'BRONZE_CRM.SND_MEMBER_LIST.LAST_UPPER_CMPGN',
    'BRONZE_CRM.TC_MKTNG_DTL_CD.CD_ID',
    'BRONZE_CRM.TM_CM_CMPGN_MNG.CMPGN_CD',
    'BRONZE_CRM.TM_CM_CMPGN_MNG.CMPGN_CTGR_CD',
    'BRONZE_CRM.TM_CM_CMPGN_MNG.CMPGN_DC',
    'BRONZE_CRM.TM_CM_CMPGN_MNG.CMPGN_NM',
    'BRONZE_CRM.TM_CM_CMPGN_MNG.CMPGN_PRPT_YN',
    'BRONZE_CRM.TM_CM_CMPGN_MNG.CMPGN_STRT_DE',
    'BRONZE_CRM.TM_CM_CMPGN_MNG.CMPGN_TRGET_CD',
    'BRONZE_CRM.TM_CM_CMPGN_MNG.CMPGN_TYPE1_BSN',
    'BRONZE_CRM.TM_CM_CMPGN_MNG.CMPGN_TYPE2_BSN',
    'BRONZE_CRM.TM_CM_CMPGN_MNG.MKTG_CHANNEL',
    'BRONZE_CRM.TM_CM_CMPGN_MNG.MKTG_CMPGN_NM',
    'BRONZE_CRM.TM_CM_CMPGN_MNG.UPPER_CMPGN_CD',
    'BRONZE_CRM.TM_CM_CMPGN_MNG.UPPER_CMPGN_YN',
    'BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT.CMPGN_CD',
    'BRONZE_CRM.TM_MM_FDRM_MBER_INFO.CMPGN_CD',
    'BRONZE_CRM.TM_MM_FDRM_MBER_IRSD.CMPGN_CD',
    'BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR.CMPGN_CD',
    'BRONZE_CRM.TM_MS_CRMN.CRMN_PART_END_DE',
    'BRONZE_CRM.TM_MS_CRMN.CRMN_PART_STRT_DE',
    'BRONZE_CRM.TM_PM_DNTN_DTLS.ONCE_CMPGN_CD',
    'BRONZE_CRM.TM_PM_MBRFEE_ACMSLT.ONCE_CMPGN_CD',
    'BRONZE_ERP.EXPENSE_RESOLUTION.CONTENTS_DELIMITER',
}


def W(*checks):
    return {'status': 'WIRED', 'checks': list(checks), 'reason': ''}


def G(reason):
    return {'status': 'GAP', 'checks': [], 'reason': reason}


def X(reason):
    return {'status': 'EXEMPT', 'checks': [], 'reason': reason}


def camp_attr(gold_col):
    """DIM_CAMPAIGN 속성 = 모델 출력 + 발송 SV(05_04 · O225-C 세트)에 노출."""
    return W((F_DIM_CAMPAIGN, 'as ' + gold_col), (SV + '05_04_SV_DDL_SERVICE.sql', 'campaign.' + gold_col + ' AS'))


REGISTRY = {
    # ── 대행사 광고 ─────────────────────────────────────────────
    'BRONZE_AGENCY.DGT_AD_CMPGN_DTLS.CMPGN_NM': W((F_FAP, 'mk.MKTG_CAMPAIGN_NAME = p.CAMPAIGN_NM'), (F_SV_AD, 'ad_to_mktg')),
    'BRONZE_AGENCY.DGT_AD_CMPGN_DTLS.CMPGN_TYPE1_BSN_NM': X('[O226] CMPGN_TYPE_BSN_NM(SV_AD 배선)의 구성 성분 = TYPE1 || 공백 || TYPE2 (SILVER 실측 · 예외 = TYPE2 NULL 행) — 분리 노출 불요'),
    'BRONZE_AGENCY.DGT_AD_CMPGN_DTLS.CMPGN_TYPE2_BSN_NM': X('[O226] CMPGN_TYPE_BSN_NM(SV_AD 배선)의 구성 성분 = TYPE1 || 공백 || TYPE2 (SILVER 실측 · 예외 = TYPE2 NULL 행) — 분리 노출 불요'),
    'BRONZE_AGENCY.DGT_AD_CMPGN_DTLS.CMPGN_TYPE_BSN_NM': W((F_FAP, 'as CMPGN_TYPE_BSN_NM'), (F_SV_AD, '.CMPGN_TYPE_BSN_NM')),
    'BRONZE_AGENCY.DGT_AD_CMPGN_DTLS.UTM_CMPGN_NM': W((F_FAP, 'utm_pick'), (F_SV_AD, '.UTM_CMPGN_NM')),
    'BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS.CMPGN_CD': X('원천 전량 NULL(SILVER AGENCY_AD_ROW_REBRDC 2,111행 중 0 · O225-C 실측) — 입고 시 GAP 로 전환'),
    'BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS.CONTENTS_PUR_COST': X('키워드 오탐(콘텐츠구입비 = 비용 measure · FACT_AD_PERFORMANCE.CONTENTS_PUR_COST)'),
    'BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS.UPPER_CMPGN_CD': X('원천 전량 NULL(CMPGN_CD 와 같은 원천 행) — 입고 시 GAP 로 전환'),
    'BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.BSNS_CASE_DIV_NM': W((F_FAP, 'as BSNS_CASE_DIV_NM'), (F_SV_AD, '.BSNS_CASE_DIV_NM')),
    'BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.CMPGN_NM': W((F_FAP, 'p.CAMPAIGN_NM'), (F_SV_AD, 'ad_to_mktg')),
    'BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.CMPGN_TY_NM': G('소재유형으로만 쓰임(AGENCY_AD_CREATIVE) · 팩트 AD_CREATIVE_SK=0 이라 SV 미도달'),
    'BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.DMST_OVSEA_DIV_NM': W((F_FAP, 'as DMST_OVSEA_DIV_NM'), (F_SV_AD, '.DMST_OVSEA_DIV_NM')),
    'BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.UPPER_CMPGN_NM': G('SILVER 까지만 · 상위캠페인명(코드·이름 혼재) 보류 = 문서20 N-29 ⑥'),
    # ── CRM 발송(SND) ───────────────────────────────────────────
    'BRONZE_CRM.SND_MEMBER_LIST.CMPGN_CD': W((M + 'silver/crm/CRM_SEND_MEMBER.sql', 'AS SND_CMPGN_CD'),
                                            (M + 'gold/fact/FACT_MESSAGE_DISPATCH.sql', 'dc.CAMPAIGN_BK = s.SND_CMPGN_CD'),
                                            (SV + '05_04_SV_DDL_SERVICE.sql', 'fse_to_campaign')),
    'BRONZE_CRM.SND_MEMBER_LIST.CMPGN_NM': X('CMPGN_CD 의 라벨 — DIM_CAMPAIGN.CAMPAIGN_NAME 으로 제공(중복 degen 금지)'),
    'BRONZE_CRM.SND_MEMBER_LIST.CURRENT_CMPGN': W((M + 'gold/fact/FACT_MESSAGE_DISPATCH.sql', 's.SND_CURRENT_CMPGN'),
                                                 (SV + '05_04_SV_DDL_SERVICE.sql', 'fse.SND_CURRENT_CMPGN AS')),
    'BRONZE_CRM.SND_MEMBER_LIST.CURRENT_UPPER_CMPGN': G('발송 시점 회원 현재 상위캠페인 스냅샷 · 미배선(O225-C 범위 밖)'),
    'BRONZE_CRM.SND_MEMBER_LIST.FIRST_CMPGN': G('발송 시점 회원 최초 캠페인 스냅샷 · 미배선(회원 현재 최초 캠페인은 O226 에서 SV_MEMBER_MONTHLY 노출)'),
    'BRONZE_CRM.SND_MEMBER_LIST.FIRST_UPPER_CMPGN': G('발송 시점 회원 최초 상위캠페인 스냅샷 · 미배선'),
    'BRONZE_CRM.SND_MEMBER_LIST.LAST_CMPGN': W((M + 'gold/fact/FACT_MESSAGE_DISPATCH.sql', 's.SND_LAST_CMPGN'),
                                              (SV + '05_04_SV_DDL_SERVICE.sql', 'fse.SND_LAST_CMPGN AS')),
    'BRONZE_CRM.SND_MEMBER_LIST.LAST_TOP_CMPGN': G('발송 시점 회원 최종 최상위캠페인 스냅샷 · 미배선'),
    'BRONZE_CRM.SND_MEMBER_LIST.LAST_UPPER_CMPGN': G('발송 시점 회원 최종 상위캠페인 스냅샷 · 미배선'),
    'BRONZE_CRM.TC_MKTNG_DTL_CD.CD_ID': X('코드사전(C001·C002·U001) — DIM_CAMPAIGN 라벨(MKTG_CHANNEL_NM·MKTG_UTM_NM)의 원천'),
    # ── CRM 캠페인 마스터 → DIM_CAMPAIGN ────────────────────────
    'BRONZE_CRM.TM_CM_CMPGN_MNG.CMPGN_CD': W((F_DIM_CAMPAIGN, 'as CAMPAIGN_BK'), (SV + '05_02_SV_DDL_MEMBER_EVENT.sql', 'AS GN_DW.GOLD.DIM_CAMPAIGN')),
    'BRONZE_CRM.TM_CM_CMPGN_MNG.CMPGN_CTGR_CD': camp_attr('CAMPAIGN_TYPE'),
    'BRONZE_CRM.TM_CM_CMPGN_MNG.CMPGN_DC': X('캠페인설명 자유문 — 분석 차원 아님'),
    'BRONZE_CRM.TM_CM_CMPGN_MNG.CMPGN_NM': camp_attr('CAMPAIGN_NAME'),
    'BRONZE_CRM.TM_CM_CMPGN_MNG.CMPGN_PRPT_YN': G('GOLD DIM_CAMPAIGN 까지 · SV 미노출(값 의미 현업 미확인)'),
    'BRONZE_CRM.TM_CM_CMPGN_MNG.CMPGN_STRT_DE': camp_attr('CAMPAIGN_OPEN_DATE'),  # [O229] SV_SERVICE 노출(jw08094)
    'BRONZE_CRM.TM_CM_CMPGN_MNG.CMPGN_TRGET_CD': G('SILVER CRM_CAMPAIGN 까지만 · GOLD·SV 미배선(코드군 미확인)'),
    'BRONZE_CRM.TM_CM_CMPGN_MNG.CMPGN_TYPE1_BSN': camp_attr('DOMESTIC_OVERSEAS'),
    'BRONZE_CRM.TM_CM_CMPGN_MNG.CMPGN_TYPE2_BSN': camp_attr('BIZ_CASE_TYPE'),
    'BRONZE_CRM.TM_CM_CMPGN_MNG.MKTG_CHANNEL': camp_attr('MKTG_CHANNEL_NM'),
    'BRONZE_CRM.TM_CM_CMPGN_MNG.MKTG_CMPGN_NM': camp_attr('MARKETING_CAMPAIGN'),
    'BRONZE_CRM.TM_CM_CMPGN_MNG.UPPER_CMPGN_CD': camp_attr('PARENT_CAMPAIGN_NAME'),
    'BRONZE_CRM.TM_CM_CMPGN_MNG.UPPER_CMPGN_YN': camp_attr('IS_PARENT_CAMPAIGN_YN'),  # [O229-B] DIM_CAMPAIGN build 후 SV_SERVICE 노출
    # ── CRM 회원 사건·약정·회비 ─────────────────────────────────
    'BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT.CMPGN_CD': W((M + 'gold/fact/FACT_MEMBER_EVENT.sql', 'campaign_valid'),
                                                     (SV + '05_02_SV_DDL_MEMBER_EVENT.sql', 'AS GN_DW.GOLD.DIM_CAMPAIGN')),
    'BRONZE_CRM.TM_MM_FDRM_MBER_INFO.CMPGN_CD': W((M + 'gold/dim/DIM_MEMBER.sql', 'FIRST_CAMPAIGN'),
                                                 (SV + '05_01_SV_DDL_MEMBER_MONTHLY.sql', 'member_to_first_campaign')),  # [O226]
    'BRONZE_CRM.TM_MM_FDRM_MBER_IRSD.CMPGN_CD': X('[O226] 증감 사건은 FME DEV(DVLP_DIV_CD 2·3 · 원천 DVLP_AMT)와 같은 사건이다 — 캠페인 보유 IRSD 행의 회원·일자 일치 99.6% · 캠페인 코드 일치 97.1%(xh20001 실측) ⇒ 캠페인 축은 FME DEV 의 CAMPAIGN_SK 로 이미 SV 도달 · 별도 사건 신설은 이중계상'),
    'BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR.CMPGN_CD': W((F_MACRO, 'sp.CMPGN_CD'),
                                                  (SV + '05_01_SV_DDL_MEMBER_MONTHLY.sql', 'fmm_to_campaign'),
                                                  (SV + '05_19_SV_DDL_PAYMENT_BILLING_STATUS.sql', 'pbs_to_campaign')),
    'BRONZE_CRM.TM_MS_CRMN.CRMN_PART_END_DE': X('키워드 오탐(행사 참여 종료일 · COMMENT 의 「캠페인참여」)'),
    'BRONZE_CRM.TM_MS_CRMN.CRMN_PART_STRT_DE': X('키워드 오탐(행사 참여 시작일 · COMMENT 의 「캠페인참여」)'),
    'BRONZE_CRM.TM_PM_DNTN_DTLS.ONCE_CMPGN_CD': W((F_MACRO, 'ONCE_CMPGN_CD'), (SV + '05_19_SV_DDL_PAYMENT_BILLING_STATUS.sql', 'pbs_to_campaign')),
    'BRONZE_CRM.TM_PM_MBRFEE_ACMSLT.ONCE_CMPGN_CD': W((F_MACRO, 'ONCE_CMPGN_CD'), (SV + '05_19_SV_DDL_PAYMENT_BILLING_STATUS.sql', 'pbs_to_campaign')),
    # ── ERP ────────────────────────────────────────────────────
    'BRONZE_ERP.EXPENSE_RESOLUTION.CONTENTS_DELIMITER': W((M + 'gold/fact/FACT_EXPENSE_RESOLUTION.sql', 'cmk.CMPGN_CD = TRIM(e.CONTENTS_DELIMITER)'),
                                                         (SV + '05_23_SV_DDL_EXPENSE_RESOLUTION.sql', 'exp_to_mkc')),
}


def read_file(rel):
    p = os.path.join(ROOT, rel)
    if not os.path.isfile(p):
        return None
    return io.open(p, encoding='utf-8').read()


def judge(snapshot, registry, reader):
    """반환 = (violations, gaps). violations 가 비면 통과."""
    v, gaps = [], []
    for k in sorted(snapshot - set(registry)):
        v.append(('UNREGISTERED', k, '분모에 있는데 등재표에 없다 — WIRED/GAP/EXEMPT 중 하나로 등재하라'))
    for k in sorted(set(registry) - snapshot):
        v.append(('STALE', k, '등재표에만 있다 — 분모(BRONZE_SNAPSHOT)를 다시 떴는지 확인하라'))
    cache = {}
    for k in sorted(set(registry) & snapshot):
        e = registry[k]
        st = e.get('status')
        if st not in ('WIRED', 'GAP', 'EXEMPT'):
            v.append(('BAD_STATUS', k, repr(st)))
            continue
        if st in ('GAP', 'EXEMPT') and not e.get('reason', '').strip():
            v.append(('NO_REASON', k, st + ' 은 사유가 필수다'))
        if st == 'GAP':
            gaps.append((k, e['reason']))
        if st == 'WIRED':
            if not e.get('checks'):
                v.append(('NO_CHECKS', k, 'WIRED 는 (파일, 토큰) 근거가 필수다'))
            for rel, tok in e.get('checks', []):
                if rel not in cache:
                    cache[rel] = reader(rel)
                body = cache[rel]
                if body is None:
                    v.append(('MISSING_FILE', k, rel))
                elif tok not in body:
                    v.append(('BROKEN', k, '%s 에 토큰 없음: %s' % (rel, tok)))
    return v, gaps


def main(argv):
    v, gaps = judge(BRONZE_SNAPSHOT, REGISTRY, read_file)
    wired = sum(1 for k in REGISTRY if REGISTRY[k]['status'] == 'WIRED')
    exempt = sum(1 for k in REGISTRY if REGISTRY[k]['status'] == 'EXEMPT')
    if '--gaps' in argv or gaps:
        for k, r in gaps:
            print('🟠 GAP  %s — %s' % (k, r))
    for kind, k, msg in v:
        print('🔴 %s  %s — %s' % (kind, k, msg))
    print('분모 %d · WIRED %d · GAP %d · EXEMPT %d · 위반 %d' % (len(BRONZE_SNAPSHOT), wired, len(gaps), exempt, len(v)))
    if v:
        print('❌ FAIL')
        return 1
    print('✅ 게이트 통과 — 미등재·배선 끊김 0 (🟠 GAP %d 건은 알려진 미배선)' % len(gaps))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
