#!/usr/bin/env python3
"""`init_ihcho` 스킬 빌더 — 정본 MD → `SKILL.md` 생성/갱신.

정본 본문 = `00_guides/03_init_ihcho_스킬_본문.md` 의
`<!-- SKILL-BODY-BEGIN -->` ~ `<!-- SKILL-BODY-END -->` 사이.
설명·불변식·개정 이력 = `00_guides/03_init_ihcho_스킬_정본.md`(§1~§5).

🔴 **왜 두 파일인가** = 본문만으로 36KB 라서 명세와 합치면 **조각 상한 40KB** 를 넘고,
   그러면 `read` 1회로 전량 확보가 안 된다(`doc_type_gate` 축3 이 실제로 잡았다).
   🔴 허브+조각 분할은 **마커를 갈라 이 추출을 깨뜨리므로** 쓰지 않는다.

🔴🔴 **왜 빌더를 두는가**
  종전에는 `SKILL.md` 가 **유일본**이었다. 그래서 ㉠ 개정 경위가 남지 않고(스킬 안에 세션 라벨을
  적는 방식으로 버텼다) ㉡ **형식 검증이 없었다**(500줄 상한·조문 집합·하드코딩 수치).
  ⇒ 정본을 문서로 옮기고, 스킬을 **산출물**로 만들면 둘 다 기계로 잡힌다.

🔴 **설계 계약**
  · **dry-run 기본.** `--apply` 로만 쓴다(`R4-4-3` 취지).
  · **스냅샷은 `snapshot_util` 만 경유**한다(`R1-7-10`) — 라벨은 인자로 받는다.
  · **`write` 로 새로 쓴다** — 대상은 **생성물**이므로 `R1-7-1`(부분 치환 기본)의 예외다.
    🔴 그래서 쓴 직후 **되읽어 바이트 동일을 단정**한다(「썼다」와 「닿았다」는 다르다 · O167).
  · 본문에 마커가 없거나 비면 **쓰지 않고 exit 1**(빈 스킬은 발동하지 않는다).

사용
  python3 scripts/build_init_ihcho_skill.py            # dry-run(차이만 보여준다)
  python3 scripts/build_init_ihcho_skill.py --check     # 같음(명시)
  python3 scripts/build_init_ihcho_skill.py --apply --label O167
"""
import argparse
import difflib
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))

#: 설명·불변식·개정 이력(사람이 읽는 명세)
SPEC = os.path.join(ROOT, '00_guides', '03_init_ihcho_스킬_정본.md')
#: 🔴 실제 추출 대상 = 본문 파일
BODY_DOC = os.path.join(ROOT, '00_guides', '03_init_ihcho_스킬_본문.md')
SKILL_DIR = os.path.join(ROOT, '.snowflake', 'cortex', 'skills', 'init_ihcho')
SKILL = os.path.join(SKILL_DIR, 'SKILL.md')

#: 🆕 [O167] 산출물 지도 = {산출물 경로: 정본 경로}.
#:   🔴 **왜 참조 파일을 따로 두는가** = 세션 종료 절차·유지 도구 표는 **종료·유지 시점에 찾아보는 것**이라
#:   세션 시작에 적재할 이유가 없다(본문 452 → 389줄). 🔴 **계약은 옮기지 않았다** —
#:   `R1-7-1`~`R1-7-10`(`I5`)와 `R3-9 ㉠`~`㉨`(`I6`)는 본문에 남는다(지연 로드하면 노출 담보가 깨진다).
ARTIFACTS = {
    SKILL: BODY_DOC,
    os.path.join(SKILL_DIR, 'references', 'session-end.md'):
        os.path.join(ROOT, '00_guides', '03_init_ihcho_스킬_참조_세션종료.md'),
}
BEGIN = '<!-- SKILL-BODY-BEGIN -->'
END = '<!-- SKILL-BODY-END -->'


def extract_body(spec_path=BODY_DOC):
    """본문 정본에서 산출물 본문을 뽑는다. 마커 줄은 포함하지 않는다."""
    if not os.path.isfile(spec_path):
        raise SystemExit(f'🔴 정본 부재: {spec_path}')
    text = io.open(spec_path, encoding='utf-8').read()
    if text.count(BEGIN) != 1 or text.count(END) != 1:
        raise SystemExit(f'🔴 마커가 정확히 1쌍이 아니다(BEGIN {text.count(BEGIN)} · END {text.count(END)}) '
                         f'— 판정식이 불안정해지므로 쓰지 않는다.')
    body = text.split(BEGIN, 1)[1].split(END, 1)[0]
    body = body.strip('\n') + '\n'          # 마커 인접 빈 줄 정규화 · 파일 끝 개행 1개
    if len(body.strip()) < 200:
        raise SystemExit('🔴 본문이 비었거나 너무 짧다 — 빈 스킬은 발동하지 않는다.')
    return body


def build_one(art, canon, apply_, label):
    """산출물 1종을 정본에서 만든다. 반환 = (변경 있었나, rc)."""
    rel = os.path.relpath(art, ROOT)
    body = extract_body(canon)
    cur = io.open(art, encoding='utf-8').read() if os.path.isfile(art) else ''
    print(f'\n▣ {rel}')
    print(f'   정본 = {os.path.relpath(canon, ROOT)} · {len(body.splitlines())}줄 · {len(body.encode())} B')
    print(f'   현행 = {len(cur.splitlines())}줄 · {len(cur.encode())} B' if cur else '   현행 = 부재(신규 생성)')
    if cur == body:
        print('   🟢 이미 동일 — 쓸 것이 없다(멱등).')
        return False, 0

    diff = list(difflib.unified_diff(cur.splitlines(True), body.splitlines(True),
                                     fromfile=f'{rel}(현행)', tofile='정본(마커 사이)', n=1))
    add = sum(1 for x in diff if x.startswith('+') and not x.startswith('+++'))
    rem = sum(1 for x in diff if x.startswith('-') and not x.startswith('---'))
    print(f'   차이 = 추가 {add}줄 · 삭제 {rem}줄')
    for line in diff[:30]:
        print('      ' + line.rstrip('\n')[:150])
    if len(diff) > 30:
        print(f'      … (차이 {len(diff)}줄 중 30줄만 표시)')
    if not apply_:
        return True, 0

    # 🔴 R1-7-10: 스냅샷은 헬퍼만 경유한다(신규 파일은 스냅샷 대상이 없다).
    if cur:
        from snapshot_util import snapshot
        sp, state = snapshot(art, 'prebuild', label=(label or None))
        print(f'   스냅샷 = {os.path.relpath(sp, ROOT)} ({state})')

    os.makedirs(os.path.dirname(art), exist_ok=True)
    io.open(art, 'w', encoding='utf-8').write(body)

    # 🔴 되읽어 도달을 단정한다(O167 판정식 = 「썼다」와 「닿았다」는 다르다).
    back = io.open(art, encoding='utf-8').read()
    if back != body:
        print(f'   🔴 FAIL — 쓴 뒤 되읽은 내용이 다르다(기대 {len(body.encode())} B · 실제 {len(back.encode())} B). '
              f'마운트 동기화 지연일 수 있으니 수 초 뒤 verify 로 재판정하라.')
        return True, 1
    print(f'   ✅ APPLIED — {len(body.splitlines())}줄 · {len(body.encode())} B · 되읽기 동일')
    return True, 0


def main():
    ap = argparse.ArgumentParser(prog='build_init_ihcho_skill.py')
    ap.add_argument('--apply', action='store_true', help='실제로 산출물을 쓴다(기본 dry-run)')
    ap.add_argument('--check', action='store_true', help='dry-run 명시(기본과 같다)')
    ap.add_argument('--label', default='', help='스냅샷 라벨(예: O167). 없으면 SESSION_LABEL → UNLABELED')
    a = ap.parse_args()

    changed = rc = 0
    for art, canon in ARTIFACTS.items():
        ch, r = build_one(art, canon, a.apply, a.label)
        changed += int(ch)
        rc = rc or r
    print('')
    if rc:
        return rc
    if not changed:
        print(f'🟢 산출물 {len(ARTIFACTS)}종 전건 정본과 동일 — 쓸 것이 없다.')
        return 0
    if not a.apply:
        print(f'🟠 DRY-RUN — 변경 대상 {changed}종. 집행하려면 `--apply` 를 붙여라.')
        return 0
    print(f'✅ 산출물 {changed}종 갱신 완료 · 🔴 다음: python3 scripts/verify_init_ihcho_skill.py')
    return 0


if __name__ == '__main__':
    sys.exit(main())
