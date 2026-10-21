#!/usr/bin/env python3
"""O250-E · 문서실행순서_llm실행.md · _보조주석.md 를 05_27~05_30 정본 · 개발계 59 / 운영계 55 번호로 맞춘다(앵커 1회 검증)."""
import sys
from pathlib import Path

W = Path("/workspace")
E = {
    "문서실행순서_llm실행.md": [
        ("| 22 ~ 57 (SV·ML·Agent) | 약 3분 | — (🆕 [O250] 35_·36_ 추가로 55 → 57 · 실측은 55 시점) |",
         "| 22 ~ 59 (SV·ML·Agent) | 약 3분 | — (🆕 [O250-E] SV 정본 05_27~05_30 추가로 55 → 59 · 실측은 55 시점) |"),
        ("[합류] 레인 A 완료 후 22 ~ 57 진행 (레인 B 는 22~57 에 불필요 — 57 완료 후 레인 B 종료만 확인)",
         "[합류] 레인 A 완료 후 22 ~ 59 진행 (레인 B 는 22~59 에 불필요 — 59 완료 후 레인 B 종료만 확인)"),
        ("(운영계 번호로는 21 → 17, 19 → 15, 18 → 14, 20 → 16, 22~57 → 18~53.)",
         "(운영계 번호로는 21 → 17, 19 → 15, 18 → 14, 20 → 16, 22~59 → 18~55.)"),
        ("| A | 20 · 22 ~ 57 (37파일) | 16 · 18 ~ 53 | 약 4분 · 35/35 OK · FAIL 0 · SKIP 0(실측은 35파일 시점 · 🆕 O250 이후 37파일) |",
         "| A | 20 · 22 ~ 59 (39파일) | 16 · 18 ~ 55 | 약 4분 · 35/35 OK · FAIL 0 · SKIP 0(실측은 35파일 시점 · 🆕 O250-E 이후 39파일) |"),
        ("| 26 | `36_O250_ML예측_7축확장.sql` 문장 단위(뷰 2 → SV 2 → GRANT 12) · 끝의 스모크 2개로 판정 |",
         "| 26 | `36_O250_ML예측_7축확장.sql` 문장 단위(뷰 2 → SV 2 → GRANT 12) · 끝의 스모크 2개로 판정 · 🆕 [O250-E] 아직 안 돌린 환경은 같은 정의의 정본 = `21_` [O250] 절 → `05_29` → `05_30` |"),
    ],
    "문서실행순서_보조주석.md": [
        ("| 54 | `35_O249_SV_신설_광고비배분_개발사건코호트.sql` | 🆕 [O249] SV_AD_INFLOW_ALLOC(광고비 → 개발인입경로 배분 · MARKETING) · SV_MEMBER_EVENT_COHORT(회원 개발사건 × 경과월 · MEMBER) · 선행 = GOLD.FACT_AD_INFLOW_ALLOC · FACT_MEMBER_EVENT_COHORT(06_DDL·dbt build) · 🔴 09_2 전 필수 |",
         "| 54 | `05_27_SV_DDL_AD_INFLOW_ALLOC.sql` | 🆕 [O249 · O250-E 단독 정본] SV_AD_INFLOW_ALLOC(광고비 → 개발인입경로 배분 · MARKETING) · 선행 = GOLD.FACT_AD_INFLOW_ALLOC(06_DDL·dbt build) · 🔴 09_2 전 필수 · 원 배포 = 35_(이력) |\n"
         "| 55 | `05_28_SV_DDL_MEMBER_EVENT_COHORT.sql` | 🆕 [O249 · O250-E 단독 정본] SV_MEMBER_EVENT_COHORT(회원 개발사건 × 경과월 · MEMBER) · 선행 = GOLD.FACT_MEMBER_EVENT_COHORT(06_DDL·dbt build) · 🔴 09_2 전 필수 · 원 배포 = 35_(이력) |"),
        ("| 55 | `36_O250_ML예측_7축확장.sql` | 🆕 [O250] 뷰 ML_MEMBER_PRED_AXIS_V",
         "| 56 · 57 | `05_29_SV_DDL_ML_MEMBER_PRED_AXIS.sql` · `05_30_SV_DDL_ML_FEE_FORECAST_AXIS.sql` | 🆕 [O250 · O250-E 단독 정본 · 뷰 2종 = 48 `21_` [O250] 절 · 원 배포 = 36_(이력)] 뷰 ML_MEMBER_PRED_AXIS_V"),
        ("| 56 | `09_1_AGENT_생성.sql` |", "| 58 | `09_1_AGENT_생성.sql` |"),
        ("| 57 | `09_2_AGENT_버전업.sql` |", "| 59 | `09_2_AGENT_버전업.sql` |"),
        ("1. `36_O250_ML예측_7축확장.sql` 전체 → 끝의 스모크 2개(회원수 = ML_MEMBER_RISK_V · 배분 합 = 예측 합)",
         "1. `36_O250_ML예측_7축확장.sql` 전체 → 끝의 스모크 2개(회원수 = ML_MEMBER_RISK_V · 배분 합 = 예측 합) — 🆕 [O250-E] 같은 정의의 정본 = `21_` [O250] 절 → `05_29` → `05_30`(어느 쪽을 써도 결과 동일)"),
    ],
}
bad = 0
for f, pairs in E.items():
    p = W / f
    t = p.read_text(encoding="utf-8")
    for a, b in pairs:
        n = t.count(a)
        if n != 1:
            print(f"🔴 {f}: 앵커 {n}회 · {a[:60]}")
            bad += 1
            continue
        t = t.replace(a, b, 1)
    p.write_text(t, encoding="utf-8")
    print(("🟢" if p.read_text(encoding="utf-8") == t else "🔴"), f)
sys.exit(1 if bad else 0)
