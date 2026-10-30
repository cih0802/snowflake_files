#!/usr/bin/env python3
"""rbac_source_gate 음성 테스트(`R3-2` · O270-F). 판정 함수에 오염을 주입해 FAIL 을, 정상 입력으로 PASS 를 확인한다.
축 = A1 배선 오염 · A2 DDL 오배정/누락 · A3 라이브 오배정/누락 · 역방향 오탐(정상 입력 0건) · 실제 저장소 PASS."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rbac_source_gate as g  # noqa: E402

CLS = {'SERVING.SV_AD': 'AGENCY', 'SERVING.SV_BUDGET': 'ERP', 'SERVING.SV_MEMBER_MONTHLY': 'COMMON',
       'SERVING.SV_MKTG_CAMPAIGN_COST': 'AGENCY+ERP', 'GOLD.WIDE_AD_COMBINED': 'AGENCY', 'GOLD.FACT_MEMBER_MONTHLY': 'COMMON'}
fails = 0


def expect(name, got, want_violation):
    global fails
    ok = (len(got) > 0) == want_violation
    fails += not ok
    print(('🟢' if ok else '🔴'), name, '위반', len(got), got[:2])


# A1
expect('A1 정상(마케팅 전 원천)', g.check_wiring({'AGENT_MARKETING': ['SV_AD', 'SV_MKTG_CAMPAIGN_COST', 'SV_BUDGET']}, CLS), False)
expect('A1 경영 + SV_AD 오염', g.check_wiring({'AGENT_EXECUTIVE': ['SV_BUDGET', 'SV_AD']}, CLS), True)
expect('A1 경영 + 혼합 SV 오염', g.check_wiring({'AGENT_EXECUTIVE': ['SV_MKTG_CAMPAIGN_COST']}, CLS), True)
expect('A1 회원 + ERP 오염', g.check_wiring({'AGENT_MEMBER': ['SV_MEMBER_MONTHLY', 'SV_BUDGET']}, CLS), True)
expect('A1 분류표 미등재 SV', g.check_wiring({'AGENT_MEMBER': ['SV_NEW']}, CLS), True)
# A2
good = [('SV_AD', 'GN_DW_AR_SRC_AGENCY'), ('SV_BUDGET', 'GN_DW_AR_SRC_ERP'),
        ('SV_MEMBER_MONTHLY', 'GN_DW_AR_SRC_COMMON'), ('SV_MKTG_CAMPAIGN_COST', 'GN_DW_AR_SRC_AGENCY_ERP')]
expect('A2 정상', g.check_ddl(good, CLS), False)
expect('A2 AGENCY SV 를 COMMON 에 배정', g.check_ddl(good + [('SV_AD', 'GN_DW_AR_SRC_COMMON')], CLS), True)
expect('A2 GRANT 줄 누락', g.check_ddl(good[1:], CLS), True)
# A3
lg = [('GN_DW_AR_SRC_AGENCY', 'GOLD.WIDE_AD_COMBINED'), ('GN_DW_AR_SRC_COMMON', 'GOLD.FACT_MEMBER_MONTHLY')]
objs = {'GOLD.WIDE_AD_COMBINED', 'GOLD.FACT_MEMBER_MONTHLY'}
expect('A3 정상', g.check_live(lg, CLS, objs), False)
expect('A3 공통 역할에 AGENCY 객체', g.check_live(lg + [('GN_DW_AR_SRC_COMMON', 'GOLD.WIDE_AD_COMBINED')], CLS, objs), True)
expect('A3 재빌드로 GRANT 소실', g.check_live(lg[1:], CLS, objs), True)
expect('A3 라이브 부재 객체는 누락 아님(역방향)', g.check_live(lg, CLS, objs), False)
# [O271-A] 운영계 전용 미분류 뷰 4개(분류표 밖 · GRANT 없음)는 위반이 아니다(역방향 · ZL50263 1단계)
prod_extra = {'SERVING.DIM_MEMBER_CURRENT', 'SERVING.DIM_MONTH', 'SERVING.FACT_AD_COMBINED', 'SERVING.ML_LTV_SCORE_V'}
expect('A3 분류표 밖 라이브 객체 · GRANT 없음 = 위반 아님(운영계 4뷰)', g.check_live(lg, CLS, objs | prod_extra), False)
expect('A3 분류표 밖 라이브 객체에 GRANT = 위반', g.check_live(lg + [('GN_DW_AR_SRC_AGENCY', 'SERVING.FACT_AD_COMBINED')],
                                                     CLS, objs | prod_extra), True)
# 실제 저장소(파일 축) — 현재 상태는 PASS 여야 한다
rc = g.main([])
fails += rc != 0
print(('🟢' if rc == 0 else '🔴'), '실저장소 A1·A2 rc =', rc)
print('🟢 PASS — 음성 테스트 전건' if not fails else '🔴 FAIL — %d건' % fails)
sys.exit(1 if fails else 0)
