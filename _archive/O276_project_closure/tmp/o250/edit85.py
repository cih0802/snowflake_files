#!/usr/bin/env python3
"""O250-C · 85 서술 문서의 낡은 구조값(버전·도구·SV 수)을 SR61467 실측으로 교체. 앵커 1회 일치 검증 · 해시 2회 확인."""
import hashlib
import sys
import time
from pathlib import Path

B = Path("/workspace/85_실제 인수인계 문서")
VER = "[ENV] SR61467 = MEMBER VERSION$5 · EXECUTIVE VERSION$5 · MARKETING VERSION$6(O250-B) · IW20760 = VERSION$8"
EDITS = {
    "10_실무자_인수인계/A0_환경실사_baseline.md": [
        ("SERVING · 기본 버전 VERSION$8 |", f"SERVING · 기본 버전 {VER} |"),
    ],
    "10_실무자_인수인계/A5_Agent_SV_개발자가이드.md": [
        ("기본 버전 VERSION$8(롤백 기준 VERSION$7 · O246-D) |",
         f"기본 버전 {VER}(롤백 기준 = 그 직전 버전) |"),
        ("| Agent 기본 버전 | VERSION$8 × 3 | TBD(미검증) — O246-D ③ 운영계 반영 대기 |",
         "| Agent 기본 버전 | SR61467 = $5 / $5 / $6(MEMBER / EXECUTIVE / MARKETING) | TBD(미검증) — O250 운영계 반영 대기 |"),
        ("| SV | 40종 · 전부 `GN_DW.SERVING` · 소유 GN_DW_ADMIN · base = GOLD 28종 / SERVING 뷰 12종 |",
         "| SV | 전부 `GN_DW.SERVING` · 소유 GN_DW_ADMIN · base = GOLD / SERVING 뷰(개수·목록 = `D08_SV요약.csv` · 2026-10-21 SR61467 = 44 · GOLD 30 / SERVING 14) |"),
        ("| Agent 도구 | 18 / 29 / 29 = SV 17 / 28 / 28 + `search_biz_definition` 1 · 3종 합집합 = SV 40 전수 |",
         "| Agent 도구 | Cortex Analyst(SV) + `search_biz_definition` 1 · 3종 합집합 = SV 전수(개수 = `D09_Agent도구.csv` · 2026-10-21 = 19 / 32 / 32) |"),
        ("- 🔴 **Agent COMMENT 의 「소관 SV 14·25·24종」은 낡았다**(DR-03). 도구 수는 spec 에서 센다(§4 [5]).",
         "- 🟢 [O250-C] Agent COMMENT 는 수치 없이 조회 데이터 카테고리만 적는다(DR-03 해소). 도구 수는 spec 에서 센다(§4 [5])."),
        ("| spec 도구 수 = 18 / 29 / 29(현재) |", "| spec 도구 수 = `D09_Agent도구.csv` 로 확인(문서에 적지 않는다) |"),
    ],
    "20_정식산출물/D02_아키텍처정의서.md": [
        ('subgraph AG["Cortex Agent 3 (VERSION$8)"]', 'subgraph AG["Cortex Agent 3"]'),
        ("| 8 | Agent 3 생성 → 버전업 | ✅ VERSION$8 |", "| 8 | Agent 3 생성 → 버전업 | ✅ [ENV] SR61467 $5 / $5 / $6 · IW20760 $8 |"),
    ],
    "20_정식산출물/D10_운영매뉴얼.md": [
        ("모두 `VERSION$8` | TBD(미검증) |", "SR61467 = `VERSION$5`·`VERSION$5`·`VERSION$6`(IW20760 = `VERSION$8`) | TBD(미검증) |"),
    ],
    "10_실무자_인수인계/A2_롤별_접근권한_매트릭스.md": [
        ("- SV 40종 = ANALYST·VIEWER·SERVICE 에", "- SV 전부(목록 = `D08_SV요약.csv`) = ANALYST·VIEWER·SERVICE 에"),
    ],
    "20_정식산출물/D09_Agent명세서.md": [
        ("as_of: 2026-10-20 (IW20760 실측 · VERSION$8)", "as_of: 2026-10-21 (SR61467 실측 · O250-C 갱신 · 초판 2026-10-20 IW20760)"),
        ("본문 데이터 = `D09_Agent도구.csv`(76행 ·", "본문 데이터 = `D09_Agent도구.csv`(행 수는 파일에서 센다 ·"),
        ("| 기본 버전 | VERSION$8 (버전 8개 보존 · 롤백 기준 VERSION$7) | 같음 | 같음 |",
         "| 기본 버전 [ENV] SR61467 | VERSION$5(롤백 VERSION$4) | VERSION$6(롤백 VERSION$5) | VERSION$5(롤백 VERSION$4) |"),
        ("| 도구 | 18 = Cortex Analyst 17 + Cortex Search 1 | 29 = 28 + 1 | 29 = 28 + 1 |",
         "| 도구 | 19 = Cortex Analyst 18 + Cortex Search 1 | 32 = 31 + 1 | 32 = 31 + 1 |"),
        ("| 5,421 / 14,841 / 5,963 | 5,704 / 15,968 / 3,814 | 4,963 / 21,358 / 6,161 |",
         "| 5,421 / 15,429 / 5,963 | 5,704 / 16,817 / 3,976 | 4,963 / 22,273 / 6,161 |"),
        ("- 배선 SV 합집합 = 40 = SV 전수(D08).", "- 배선 SV 합집합 = SV 전수(D08 · 2026-10-21 SR61467 = 44)."),
        ("| SV_AD · SV_GA_* · SV_SEARCH_CONSOLE · SV_CAMPAIGN_* · SV_ML_INC_CAMPAIGN |",
         "| SV_AD · SV_AD_INFLOW_ALLOC · SV_GA_* · SV_SEARCH_CONSOLE · SV_CAMPAIGN_* · SV_ML_INC_CAMPAIGN · SV_ML_FEE_FORECAST_AXIS |"),
        ("| SV_MEMBER_* · SV_SERVICE · SV_EVENT_PARTICIPATION · SV_RELATION_ACTIVITY · SV_ML_MEMBER_RISK |",
         "| SV_MEMBER_* · SV_SERVICE · SV_EVENT_PARTICIPATION · SV_RELATION_ACTIVITY · SV_ML_MEMBER_RISK · SV_ML_FEE_FORECAST_AXIS |"),
        ("- 3종 공통 SV 7: SV_CAMPAIGN_CUM_STOP · SV_CAMPAIGN_MONTHLY · SV_ML_CHURN_CAMPAIGN · SV_ML_FEATURE_IMPORTANCE · SV_ML_MEMBER_PRED_BRIDGE · SV_ML_REALTIME_SIMULATOR · SV_MSTR_SPNSR_DVLP.",
         "- 3종 공통 SV 8: SV_CAMPAIGN_CUM_STOP · SV_CAMPAIGN_MONTHLY · SV_ML_CHURN_CAMPAIGN · SV_ML_FEATURE_IMPORTANCE · SV_ML_MEMBER_PRED_AXIS · SV_ML_MEMBER_PRED_BRIDGE · SV_ML_REALTIME_SIMULATOR · SV_MSTR_SPNSR_DVLP.\n"
         "- 🆕 [O250] 7축 예측 도구 = `analyst_ml_pred_axis`(SV_ML_MEMBER_PRED_AXIS · 3종) · `analyst_ml_fee_axis`(SV_ML_FEE_FORECAST_AXIS · MEMBER·MARKETING) — 증액·중단·미납·회비 예측을 신규기존·본부지부·후원사업·법인·공통브랜드·캠페인카테고리·마케팅캠페인명으로 나눈다."),
        ("| DR-03 | Agent COMMENT「소관 SV 14·25·24종」 | 17·28·28 | 다음 버전업 때 09_1 [5] 로 COMMENT 갱신 |",
         "| DR-03 | Agent COMMENT「소관 SV 14·25·24종」 | 17·28·28 | 🟢 O250-C 해소 = COMMENT 를 수치 없는 카테고리 문안으로 교체(09_1 [5] · SR61467 적용) |"),
        ("| DR-16 | 09_2 [0] 정적 목록 · [3] COMMENT「도구 15·26·25종」 | 도구 18·29·29 | 게이트(`sv_identifier_gate`)를 정본으로 |",
         "| DR-16 | 09_2 [0] 정적 목록 · [3] COMMENT「도구 15·26·25종」 | 도구 18·29·29 | 게이트(`sv_identifier_gate`)를 정본으로 · 🟢 O250-C = [3] COMMENT 수치 제거 · [0] 에 O250 5행 추가 |"),
    ],
}


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


bad = 0
for rel, pairs in EDITS.items():
    p = B / rel
    h = sha(p)
    time.sleep(1)
    if sha(p) != h:
        sys.exit(f"🔴 해시 불안정 {rel}")
    t = p.read_text(encoding="utf-8")
    for old, new in pairs:
        n = t.count(old)
        if n != 1:
            print(f"🔴 {rel}: 앵커 {n}회 — skip: {old[:60]}")
            bad += 1
            continue
        t = t.replace(old, new, 1)
    p.write_text(t, encoding="utf-8")
    ok = p.read_text(encoding="utf-8") == t
    print(("🟢" if ok else "🔴"), rel)
    bad += not ok
sys.exit(1 if bad else 0)
