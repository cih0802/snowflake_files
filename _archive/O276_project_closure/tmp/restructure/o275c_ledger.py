"""O275-C 원장 §1 O275 행 + 계획 §6 체크리스트 갱신(줄 인덱스 치환 · R1-7-8 · 스냅샷 선행)."""
import io, sys
sys.path.insert(0, '/workspace/scripts')
from snapshot_util import snapshot
L = '/workspace/20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md'
P = '/workspace/00_WORKSPACE_RESTRUCTURE_PLAN.md'
for f in (L, P):
    print(snapshot(f, 'pre-o275c', label='O275-C'))

lines = io.open(L, encoding='utf-8').read().split('\n')
i = 105
assert lines[i].startswith('| 🟡 **`O275`**'), lines[i][:40]
old_mid = ' · 잔여 = 4-D 스킬 재생성 · 잔존 재스캔 · 4-E · 인수인계 `99_NEXT_SESSION-O0275-A.md`·`-B.md` |'
assert lines[i].count(old_mid) == 1
new_mid = (' · 🆕 [O275-C] 4-D = init_ihcho 설치본 4종 정본과 동일(멱등 · verify PASS) · mstr-migration 옛 경로 9건 → MOVE_MAP'
           ' · 잔존 재스캔 = 80 예외 2 외 0(python·Grep 2축) · 음성 테스트 63/63 PASS'
           ' · 4-E = 상위 README 7 · `_archive` 색인 · 실행순서 진입점 README · WORKSPACE_MAP §0·§5 · tmp 삭제 후보 0(mtime 일괄 재기록 → 라벨 대체 판정)'
           ' · 소실 1 복원 확인(33,184 B) · 🟠 잔여 = 실행순서 4종 본문 옛 경로(80 사본 정합 · 치환 여부 사용자 결정)'
           ' · 인수인계 `99_NEXT_SESSION-O0275-A.md`·`-B.md`·`-C.md` |')
lines[i] = lines[i].replace(old_mid, new_mid)
lines[i] = lines[i].replace('| 🟡 **`O275`** — 문서정리 = 워크스페이스 목적별 재편(README 판정 4-A · MOVE_MAP 4-B · 그룹 이동 4-C)',
                            '| 🟡 **`O275`** — 문서정리 = 워크스페이스 목적별 재편(README 판정 4-A · MOVE_MAP 4-B · 그룹 이동 4-C · 🆕 4-D·4-E O275-C)', 1)
io.open(L, 'w', encoding='utf-8').write('\n'.join(lines))
assert io.open(L, encoding='utf-8').read().split('\n')[i] == lines[i]
print('ledger row len', len(lines[i]))

t = io.open(P, encoding='utf-8').read()
R = [
    ('- [ ] 4-D 스킬 재생성 + scripts 경로 갱신',
     '- [x] 4-D 스킬 재생성 + scripts 경로 갱신 (🆕 [O275-C] init_ihcho 4종 멱등 · verify PASS · mstr-migration 9건 치환)'),
    ('- [ ] 최종 검증 (잔존 경로 0건 · 2000자 · 게이트)',
     '- [x] 최종 검증 (🆕 [O275-C] 잔존 = 80 예외 2 외 0 · 음성 테스트 63/63 · 브리핑 게이트 · 선택 게이트는 사용자 확인 후)'),
    ('- [ ] 4-E README · WORKSPACE_MAP 갱신 · tmp 삭제 후보 목록',
     '- [x] 4-E README · WORKSPACE_MAP 갱신 · tmp 삭제 후보 목록 (🆕 [O275-C] 실행순서 4종 = 본문 병합 대신 진입점 README + MAP §5 · tmp 후보 0 = `tmp/restructure/TMP_DELETE_CANDIDATES_O275C.csv`)'),
]
for a, b in R:
    assert t.count(a) == 1, a
    t = t.replace(a, b)
io.open(P, 'w', encoding='utf-8').write(t)
assert io.open(P, encoding='utf-8').read() == t
print('plan OK')
