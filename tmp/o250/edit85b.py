#!/usr/bin/env python3
"""O250-C · 85 서술 문서 2차 — D08·D04·D06·N03 규모 수치 + 운영계 체크리스트 증분 범위(SR61467 재생성 결과 기준)."""
import hashlib
import sys
import time
from pathlib import Path

B = Path("/workspace/85_실제 인수인계 문서")
EDITS = {
    "20_정식산출물/D08_시맨틱뷰정의서.md": [
        ("as_of: 2026-10-20 (IW20760 실측)", "as_of: 2026-10-21 (SR61467 실측 · O250-C 재생성 · 초판 2026-10-20 IW20760)"),
        ("| `D08_SV요약.csv` | SV 40행 —", "| `D08_SV요약.csv` | SV 1행씩 —"),
        ("| `D08_SV메트릭.csv` | 메트릭 360행 —", "| `D08_SV메트릭.csv` | 메트릭 1행씩 —"),
        ("| 차원 상세 | `_ENV/<계정>/B1_Q07_1.csv`(854행) · 관계 = `B1_Q08_1.csv`(56행) |",
         "| 차원 상세 | `_ENV/<계정>/B1_Q07_1.csv` · 관계 = `B1_Q08_1.csv` |"),
        ("| SV | 40 (전부 `GN_DW.SERVING` · 소유 GN_DW_ADMIN) | — |", "| SV | 44 (전부 `GN_DW.SERVING` · 소유 GN_DW_ADMIN) | — |"),
        ("| 논리테이블 | 103 | 7 |", "| 논리테이블 | 108 | 7 |"),
        ("| 차원 | 854 | 77 (SV_SERVICE) |", "| 차원 | 896 | 77 (SV_SERVICE) |"),
        ("| 메트릭 | 360 | 38 (SV_MEMBER_MONTHLY) |", "| 메트릭 | 386 | 38 (SV_MEMBER_MONTHLY) |"),
        ("| 관계 | 56 | 6 |", "| 관계 | 57 | 6 |"),
        ("| VQR(검증 질의) | 43 · VQR 있는 SV 26 / 없는 SV 14 | 4 |", "| VQR(검증 질의) | 43 · VQR 있는 SV 26 / 없는 SV 18 | 4 |"),
        ("- base 스키마: GOLD 28 SV · SERVING 뷰 12 SV(ML 11 + MSTR 1).",
         "- 🔴 이 표의 수치는 2026-10-21 SR61467 값이다 — 개발로 바뀌므로 인용 전에 `D08_SV요약.csv` 를 다시 센다.\n"
         "- base 스키마: GOLD 30 SV · SERVING 뷰 14 SV(ML 13 + MSTR 1)."),
        ("- 메트릭 360건 전부 동의어와 COMMENT 가 있다(빈 값 0).", "- 메트릭 전부 동의어와 COMMENT 가 있다(빈 값 0 · 2026-10-20 IW20760 판정 · 🆕 O248~O250 신규 SV 4종도 같은 규칙으로 작성)."),
        ("| 광고 | SV_AD | EXECUTIVE·MARKETING |", "| 광고 | SV_AD · SV_AD_INFLOW_ALLOC(🆕 O249 광고비 → 개발인입경로 배분) | EXECUTIVE·MARKETING(INFLOW_ALLOC 은 MARKETING) |"),
        ("| ML 예측 | SV_ML_* 11 | Agent 별 상이(D09) |",
         "| 회원 개발사건 코호트 | SV_MEMBER_EVENT_COHORT(🆕 O249) | MEMBER |\n"
         "| ML 예측 | SV_ML_* 13 — 🆕 O250 = SV_ML_MEMBER_PRED_AXIS(증액·중단·미납 × 7축) · SV_ML_FEE_FORECAST_AXIS(회비 × 7축 배분 추정) | Agent 별 상이(D09) |"),
        ("- 배선 Agent 수: 3종 공통 7 SV · 2종 19 SV · 1종 14 SV. 미배선 SV 0.", "- 배선 Agent 수: 3종 공통 8 SV · 2종 20 SV · 1종 16 SV. 미배선 SV 0."),
        ("| S-1 | VQR 없는 SV 14 — SV_MEMBER_MONTHLY(메트릭 38 · 최다) · SV_MEMBER_MONTHLY_KPI · SV_ML_* 7 ·",
         "| S-1 | VQR 없는 SV 18 — SV_MEMBER_MONTHLY(메트릭 38 · 최다) · SV_MEMBER_MONTHLY_KPI · SV_ML_* 9 · SV_AD_INFLOW_ALLOC · SV_MEMBER_EVENT_COHORT ·"),
        ("| DR-03 | Agent COMMENT「소관 SV 14·25·24」 | 배선 17·28·28 | 기록만 |",
         "| DR-03 | Agent COMMENT「소관 SV 14·25·24」 | 배선 17·28·28 | 🟢 O250-C 해소(COMMENT = 수치 없는 카테고리 문안) |"),
    ],
    "20_정식산출물/D04_테이블컬럼정의서.md": [
        ("| `D04_테이블목록.csv` | 292행 —", "| `D04_테이블목록.csv` | 테이블 1행씩(2026-10-21 SR61467 = 285) —"),
    ],
    "20_정식산출물/D06_원천타깃매핑_계보.md": [
        ("본문 = `D06_테이블계보.csv`(644간선 ·", "본문 = `D06_테이블계보.csv`(2026-10-21 SR61467 재생성 = 659간선 ·"),
        ("| dbt ref | 274 |", "| dbt ref | 284 |"),
        ("| SV base | 103 |", "| SV base | 108 |"),
        ("| view dependency | 191 | `OBJECT_DEPENDENCIES` |",
         "| view dependency | 191 | `OBJECT_DEPENDENCIES`(🔴 ACCOUNT_USAGE 지연 · O250 신규 뷰 2종은 다음 재생성에 들어온다) |"),
    ],
    "20_정식산출물/N03_통합데이터사전.md": [
        ("· D06_테이블계보.csv (간선 644)", "· D06_테이블계보.csv (2026-10-21 SR61467 재생성 · 간선 659)"),
    ],
    "_ENV/운영계_반영_체크리스트.md": [
        ("「# 기존 환경 갱신」 1~19 | 각 파일 머리 | 각 파일 확인 SELECT |",
         "「# 기존 환경 갱신」 1~28(🆕 20~25 = O249 · 26~28 = O250 7축 예측·Agent 설명) | 각 파일 머리 | 각 파일 확인 SELECT · 36_ 끝 스모크 2개 |"),
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
            print(f"🔴 {rel}: 앵커 {n}회 — skip: {old[:70]}")
            bad += 1
            continue
        t = t.replace(old, new, 1)
    p.write_text(t, encoding="utf-8")
    ok = p.read_text(encoding="utf-8") == t
    print(("🟢" if ok else "🔴"), rel)
    bad += not ok
sys.exit(1 if bad else 0)
