#!/usr/bin/env python3
"""O247 · 개발계 반영 후 문서 상태 갱신 — 정확 일치 치환(각 1회 · 아니면 중단). --apply 없으면 점검만."""
import sys
from pathlib import Path

P = Path("/workspace/85_실제 인수인계 문서")
D = "2026-10-20 개발계 적용"
EDITS = [
    (P / "_드리프트/드리프트_통합.md",
     "`A2_권한조정_적용완료.sql` [1] · 미실행)",
     f"`A2_권한조정_적용완료.sql` [1] · 🟢 {D} — SELECT = ADMIN·ENGINEER·ANALYST·VIEWER·SERVICE)"),
    (P / "_드리프트/드리프트_통합.md",
     "이미 부여된 계정은 `A2_권한조정_적용완료.sql` [2] · 미실행)",
     f"이미 부여된 계정은 `A2_권한조정_적용완료.sql` [2] · 🟢 {D} — 90일 접근 0 확인 후 회수 · OPS USAGE = ADMIN·ENGINEER·DBT)"),
    (P / "_드리프트/드리프트_통합.md",
     "원본 정본 = `08_mornitoring/11_BRONZE_개인정보_마스킹정책_적용완료.sql` · 승인 실행 대기",
     f"원본 정본 = `08_mornitoring/11_BRONZE_개인정보_마스킹정책_적용완료.sql` · 🟢 {D} — 부착 12 · DBT(보조 롤 끔) 전부 `***`"),
    (P / "_드리프트/드리프트_통합.md",
     "| 기록만 — 원인 미확인(A8-29) · N01 DMF 를 붙이면 이 2 간선이 즉시 위반 |",
     f"| 기록만 — 원인 미확인(A8-29) · 🟢 {D} = N01 DMF 전부 부착(사용자 결정) ⇒ 이 2 간선은 매일 08:00 KST 위반으로 관측된다 |"),
    (P / "_드리프트/드리프트_통합.md",
     "🟡 **코드 수정 완료 · 배포 대기**(2026-10-20 사용자 결정 = SILVER 삽입)",
     f"🟡 **코드 수정 · DDL · dbt 새 버전 완료({D} · 버전 `O247_DR25_CRM_HOLIDAY`) · 👤 dbt build 대기**(2026-10-20 사용자 결정 = SILVER 삽입)"),
    (P / "10_실무자_인수인계/A8_미결이슈_인계목록.md",
     "— `A2_권한조정_적용완료.sql` [1] 승인 실행 대기 |",
     f"— `A2_권한조정_적용완료.sql` [1] 🟢 {D} |"),
    (P / "10_실무자_인수인계/A8_미결이슈_인계목록.md",
     "운영계 90일 접근 확인 후 [2] 실행 |",
     f"🟢 {D}(개발계 90일 접근 0) · 운영계 90일 접근 확인 후 [2] 실행 |"),
    (P / "10_실무자_인수인계/A8_미결이슈_인계목록.md",
     "— `08_mornitoring/11_…_미실행.sql` 승인 실행 대기 |",
     f"— `08_mornitoring/11_…_적용완료.sql` 🟢 {D} |"),
    (P / "10_실무자_인수인계/A8_미결이슈_인계목록.md",
     "— 원본 `08_mornitoring/11_BRONZE_개인정보_마스킹정책_적용완료.sql` · 승인 실행 대기.",
     f"— 원본 `08_mornitoring/11_BRONZE_개인정보_마스킹정책_적용완료.sql` · 🟢 {D} · 운영계 실행 대기."),
    (P / "20_정식산출물/D14_인수인계서.md",
     "| 미실행 SQL(승인 대기) | `A2_권한조정` · `A3_CoCo_ANALYST_차단` · `N01_DMF_적용` · `N02_정책_적용` · `08_mornitoring/11_BRONZE_개인정보_마스킹정책` | 각 파일 머리 · A8 |",
     f"| SQL 반영 상태 | 🟢 {D} = `A2_권한조정_적용완료` · `N01_DMF_적용완료` · `08_mornitoring/11_…_적용완료` · N02 [2-B] · DR-25 DDL·dbt 새 버전 · ⬜ 미적용 = N02 [1][2](사용자 결정) · `A3_…_미실행`(운영계 연기) · 05·06 비용 가드(DR-32) | 각 파일 머리 · A8 |"),
    (P / "20_정식산출물/D14_인수인계서.md",
     "| 배포 대기(사용자 실행) | DR-25 `SILVER.CRM_HOLIDAY`(DDL → `dbt build -s CRM_HOLIDAY DIM_DATE` → 재배포) |",
     "| 배포 대기(사용자 실행) | DR-25 = 개발계 DDL·새 버전 완료 · 👤 `dbt build -s CRM_HOLIDAY DIM_DATE` |"),
    (P / "20_정식산출물/N02_정책_적용_미실행.sql",
     "-- N02 PII 마스킹 · 행 접근 정책 적용 SQL — 🔴 미실행(설계 산출물 · 실행은 사용자 승인 후 별도 세션)",
     f"-- N02 PII 마스킹 · 행 접근 정책 적용 SQL — 🟡 부분 적용: [2-B] BRONZE 12 컬럼 = 🟢 {D}(`08_mornitoring/11_…_적용완료.sql`) · [1][2] 이메일 = ⬜ 미적용(사용자 결정)"),
]


def main(apply):
    bad = 0
    for f, old, new in EDITS:
        n = f.read_text(encoding="utf-8").count(old)
        print(f"{'OK ' if n == 1 else 'BAD'} {n} · {f.name} · {old[:50]}")
        bad += n != 1
    if bad:
        sys.exit(f"🔴 일치 1회가 아닌 항목 {bad} — 중단")
    if apply:
        for f, old, new in EDITS:
            t = f.read_text(encoding="utf-8").replace(old, new)
            f.write_text(t, encoding="utf-8")
            assert f.read_text(encoding="utf-8").count(new) >= 1
        print(f"적용 {len(EDITS)}건")


if __name__ == "__main__":
    main("--apply" in sys.argv)
