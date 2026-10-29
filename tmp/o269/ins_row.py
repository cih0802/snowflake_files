import io, sys
p = "/workspace/20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md"
row = ("| 🟡 **`O269`** — 잔여 작업 전수 정리(20_issue·98·85·60·12 문서 대조) · 사용자 보고 반영"
       "(현업 회신 3통 발송 · 운영계 개발계 동일 반영 · T1 TASK_VIDEO 재개 결정 · T2·T3 daily build 정상) · "
       "잔여를 4분류(지금 · 운영계 수치 후 · 현업 회신 후 · 공지)로 재편 · 「지금」 묶음 집행 "
       "(2026-10-29 · TRIALADMIN · ZS83821 개발계 · ㉡ · 사용자 승인(이력 롤오버 등)) "
       "| 🟡 분류 완료 · 집행 결과 = 라벨 파일 | 1 | `99_NEXT_SESSION-O0269-A.md` · `tmp/o269/` |\n")
with io.open(p, encoding="utf-8") as f:
    lines = f.readlines()
anchor = 105  # 0-based index of the O268 row (line 106)
assert "`O268`" in lines[anchor], lines[anchor][:80]
assert "`O269`" not in "".join(lines)
lines.insert(anchor, row)
with io.open(p, "w", encoding="utf-8") as f:
    f.writelines(lines)
print("inserted", len(row), "chars")
