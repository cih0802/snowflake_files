# 07_O작업정리 3파일을 _archive/ 로 은퇴시킨 뒤 개별 삭제한다 (R1-7-7 · R1-7-10)
# Co-authored with CoCo
import os
import sys

sys.path.insert(0, "/workspace/scripts")
import snapshot_util  # noqa: E402

ROOT = "/workspace"
FOLDER = os.path.join(ROOT, "07_O작업정리")

# ① 삭제 직전 재나열 (os.listdir · 낡은 뷰 방지)
names = sorted(os.listdir(FOLDER))
print("① 삭제 직전 os.listdir = %d건: %s" % (len(names), names))

targets = [os.path.join(FOLDER, n) for n in names if os.path.isfile(os.path.join(FOLDER, n))]
if len(targets) != len(names):
    print("🔴 파일이 아닌 항목이 있다 — 중단한다")
    sys.exit(1)

# ② 은퇴본 스냅샷 (유일한 되돌리기 수단)
snaps = []
for p in targets:
    res = snapshot_util.snapshot(p, "retire-folder", label="O146",
                                 archive=snapshot_util.ARCHIVE)
    snap = res[0] if isinstance(res, tuple) else res
    snaps.append((p, snap))
    print("② 스냅샷 %s → %s" % (os.path.relpath(p, ROOT), snap))

# ③ 스냅샷 실재·바이트 동일 확인 후에만 개별 삭제
for p, snap in snaps:
    if snap is None or not os.path.exists(snap):
        print("🔴 스냅샷 부재 — 삭제하지 않는다: %s" % p)
        sys.exit(1)
    if os.path.getsize(snap) != os.path.getsize(p):
        print("🔴 스냅샷 바이트 불일치 — 삭제하지 않는다: %s" % p)
        sys.exit(1)

for p, _snap in snaps:
    os.remove(p)
    print("③ 개별 삭제 %s" % os.path.relpath(p, ROOT))

# ④ 폴더 자체 (빈 디렉터리) 제거 시도
left = os.listdir(FOLDER) if os.path.isdir(FOLDER) else []
print("④ 삭제 후 os.listdir = %d건 %s" % (len(left), left))
if os.path.isdir(FOLDER) and not left:
    try:
        os.rmdir(FOLDER)
        print("④ 빈 디렉터리 rmdir 성공")
    except OSError as e:
        print("④ rmdir 실패(스테이지 마운트에서는 정상일 수 있다): %s" % e)
print("④ 폴더 존재 여부 = %s" % os.path.isdir(FOLDER))
