#!/usr/bin/env python3
"""O247 · 적용 완료 파일 이름 전환 + 참조 치환 (사용자 승인 2026-10-20).

1) 새 이름 파일 = 옛 내용 + 머리 1줄(적용 완료 표기) → 쓴 뒤 다시 읽어 바이트 검증
2) 옛 파일 → 같은 폴더의 _archive/ 로 이동(삭제 아님 · 이동 후 원위치 부재 · 목적지 해시 일치 확인)
3) 참조 치환 = 현재 문서 목록(REFS)만 · 옛 이름 → 새 이름 · 치환 건수 기록
   🔴 이력(01_세션이력) · 지난 인수인계 라벨 · _archive · _ENV csv 는 건드리지 않는다.
--apply 없이 돌리면 계획만 출력한다.
"""
import hashlib
import shutil
import sys
from pathlib import Path

W = Path("/workspace")
P = W / "85_실제 인수인계 문서"
STAMP = "2026-10-20 O247 · 개발계 IW20760 · GN_DW_ADMIN(선행 권한 ACCOUNTADMIN)"

RENAMES = [
    (W / "08_mornitoring/11_BRONZE_개인정보_마스킹정책_미실행.sql",
     W / "08_mornitoring/11_BRONZE_개인정보_마스킹정책_적용완료.sql",
     f"-- 🟢 적용 완료 — {STAMP} · 부착 12 컬럼 · ADMIN 원문 · DBT(보조 롤 끔) *** 확인 · 운영계는 같은 파일 [0]~[3] 실행"),
    (P / "10_실무자_인수인계/A2_권한조정_미실행.sql",
     P / "10_실무자_인수인계/A2_권한조정_적용완료.sql",
     f"-- 🟢 적용 완료 — {STAMP} · [1] VIEWER·SERVICE SELECT · [2] 90일 접근 0 확인 후 ANALYST OPS 회수 · 운영계는 [2] 앞 확인 SELECT 부터"),
    (P / "20_정식산출물/N01_DMF_적용_미실행.sql",
     P / "20_정식산출물/N01_DMF_적용완료.sql",
     f"-- 🟢 적용 완료 — {STAMP} · 136문장 OK(스케줄 1 · 스키마 2 · PK 62 · FK 71) · DR-31 2 간선은 위반 관측 대상"),
]
OLD_NEW = [(o.name, n.name) for o, n, _ in RENAMES]
REFS = [
    P / "00_INDEX_산출물목록.md",
    P / "10_실무자_인수인계/A1_운영자가이드.md",
    P / "10_실무자_인수인계/A2_롤별_접근권한_매트릭스.md",
    P / "10_실무자_인수인계/A2_롤별_접근권한_설계.csv",
    P / "10_실무자_인수인계/A8_미결이슈_인계목록.csv",
    P / "10_실무자_인수인계/A8_미결이슈_인계목록.md",
    P / "20_정식산출물/D03_환경구성서_RBAC매트릭스.md",
    P / "20_정식산출물/D10_운영매뉴얼.md",
    P / "20_정식산출물/N01_DMF_정의서.md",
    P / "20_정식산출물/N02_PII_정책정의서.md",
    P / "20_정식산출물/N02_정책_적용_미실행.sql",
    P / "99_다음세션_프롬프트.md",
    P / "_근거쿼리/N01_DMF_사전점검.sql",
    P / "_드리프트/드리프트_통합.md",
    P / "_드리프트/자기검토_보고서.md",
    P / "_ENV/운영계_반영_체크리스트.md",
    W / "08_mornitoring/00_README.md",
    W / "80_인수인계_프로젝트완료 및 유지보수용/00_재현프롬프트.md",
    W / "20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md",
]


def h(b):
    return hashlib.sha256(b).hexdigest()[:16]


def main(apply):
    for old, new, head in RENAMES:
        assert old.exists(), f"부재: {old}"
        src = old.read_bytes()
        body = src.decode("utf-8")
        out = (head + "\n" + body).encode("utf-8")
        arc = old.parent / "_archive" / old.name
        print(f"[RENAME] {old.relative_to(W)} → {new.name} · 옛 파일 → {arc.relative_to(W)}")
        if apply:
            new.write_bytes(out)
            assert new.read_bytes() == out, f"새 파일 검증 실패: {new}"
            arc.parent.mkdir(exist_ok=True)
            assert not arc.exists(), f"_archive 에 같은 이름 존재: {arc}"
            shutil.copyfile(old, arc)
            assert h(arc.read_bytes()) == h(src), f"보관 검증 실패: {arc}"
            old.unlink()
            assert not old.exists()
    total = 0
    for f in REFS:
        t = f.read_text(encoding="utf-8")
        n = sum(t.count(o) for o, _ in OLD_NEW)
        total += n
        print(f"[REF] {n:3d} · {f.relative_to(W)}")
        if apply and n:
            for o, nn in OLD_NEW:
                t = t.replace(o, nn)
            f.write_text(t, encoding="utf-8")
            assert all(f.read_text(encoding="utf-8").count(o) == 0 for o, _ in OLD_NEW), f"치환 잔여: {f}"
    print(f"참조 치환 합계 {total}건 · {'적용' if apply else '계획만'}")


if __name__ == "__main__":
    main("--apply" in sys.argv)
