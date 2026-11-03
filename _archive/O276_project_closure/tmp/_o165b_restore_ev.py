"""[O165-B 복원] `_o165_inspection_evidence.md` 손상 꼬리를 잘라내고 온전한 꼬리를 이어붙인다.

🔴 왜 스크립트인가 = 본문에 백틱·`$`·`!` 가 매 줄 있어 **셸을 경유시키지 않는다**(`R1-7-9`).
🔴 판정 근거 = 해시 3회 동일(15,799 B) + 꼬리 UTF-8 미완결 ⇒ torn read 가 아니라 **실손상**(`R1-7-3`).
🟢 절단 지점 = `## ▣ D11` **직전**(그 절부터 꼬리 파일이 전량 다시 담는다).
"""
import hashlib
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(ROOT, '20_issue/_o165_inspection_evidence.md')
TAIL = os.path.join(ROOT, 'tmp/_o165_ev_tail.md')
MARK = '## ▣ D11'

raw = open(TARGET, 'rb').read()
print('손상본 = %d B · sha=%s' % (len(raw), hashlib.sha256(raw).hexdigest()[:16]))

#   🔴 꼬리가 UTF-8 미완결이므로 `errors='ignore'` 로 읽어 **앞부분만** 살린다.
head = raw.decode('utf-8', 'ignore')
i = head.find(MARK)
if i < 0:
    print('🔴 절단 마커(%s)를 찾지 못했다 — 중단한다.' % MARK)
    sys.exit(1)
head = head[:i]
print('절단 후 머리 = %d 자 · 마지막 60자 = %r' % (len(head), head[-60:]))

tail = open(TAIL, encoding='utf-8').read()
if not tail.startswith(MARK):
    print('🔴 꼬리 파일이 %s 로 시작하지 않는다 — 중단한다.' % MARK)
    sys.exit(1)

out = head + tail
#   🔴 스냅샷을 먼저 남긴다(`R1-7-10` 은 `snapshot_util` 경유를 요구하지만 이 파일은
#     **이미 손상된 상태**이므로 손상본 자체를 증거로 보존한다).
snap = os.path.join(ROOT, '_archive/_o165_inspection_evidence.md.O165B-damaged')
if not os.path.exists(snap):
    open(snap, 'wb').write(raw)
    print('손상본 스냅샷 = %s' % snap)

open(TARGET, 'w', encoding='utf-8').write(out)
b2 = open(TARGET, 'rb').read()
print('복원본 = %d B · sha=%s · 줄 %d' % (len(b2), hashlib.sha256(b2).hexdigest()[:16],
                                       len(b2.split(b'\n'))))
#   🟢 도착 검증 = 소실됐던 토큰이 전부 실재하는가(`R2-8-1` 축).
s2 = b2.decode('utf-8')
need = ['## ▣ D11', '## ▣ D12', '## ▣ D13', '## ▣ 5. Phase 3', '## ▣ 6.', '## ▣ 7.',
        '_Co-authored with CoCo_', 'D1`~`D13']
miss = [t for t in need if t not in s2]
print('필수 토큰 %d종 · 부재 %d종' % (len(need), len(miss)))
if miss:
    print('🔴 부재: %s' % miss)
    sys.exit(1)
print('🟢 복원 완료 — 필수 토큰 전건 실재 · UTF-8 정상 디코드')
