"""[O165 Phase 1 보강] 축11 이 「고치기 전 코드」에서 반드시 실패하는가를 실증한다.

🔴 왜 필요한가 = 절차서 `11_O누적작업_점검_재현_절차.md` §0 「성공 판정식」:
  *"「고친 뒤 통과」가 아니라 「고치기 전 코드에서 반드시 실패하는 음성 테스트」가 있어야
    그 테스트가 결함을 본다는 증거가 된다"*
O165 는 시정 후 통과만 실증했으므로 이 스크립트로 **역방향**을 실증한다.

방법 = `session_brief.superseded` 를 **시정 전 구현**(취소선 단일 축)으로 되돌린 뒤
축11 의 핵심 단정 3건을 돌려 **전건 실패**를 확인한다. 파일은 고치지 않는다(런타임 패치).
"""
import sys

sys.path.insert(0, 'scripts')
import session_brief as sb  # noqa: E402

NESTED_ONLY = """
## ~~0-DDDD. 🔴🔴 [2026-08-31 O126 — ~~여기서 시작한다~~ · §0-EEEE 로 승계됐다]~~
### ▣ DDDD1 승계된 항목 — 뽑히면 안 된다
## 0-JJJJ. 🟢 [2026-09-16 O162 — ~~여기서 시작한다~~ · **§0-KKKK 로 승계됨**]
### ▣ JJJJ1 승계된 항목 — 뽑히면 안 된다
## 0-KKKK. 🟢 [2026-09-17 O163 — ~~여기서 시작한다~~ · **§0-LLLL 로 승계됨**]
### ▣ KKKK1 승계된 항목 — 뽑히면 안 된다
"""

NESTED = NESTED_ONLY + (
    '## 0-LLLL. 🔴🔴 [2026-09-16 O165 필독 — **여기서 시작한다.** §0-KKKK 는 승계됐다]\n'
    '### ▣ LLLL1 현행 항목\n')

ORPHAN = """
## 0-JJJJ. 🟢 [2026-09-16 O162 — ~~여기서 시작한다~~ · **§0-KKKK 로 승계됨**]
### ▣ JJJJ1 항목
## 0-KKKK. 🟢 [2026-09-17 O163 — ~~여기서 시작한다~~ · **§0-LLLL 로 승계됨**]
### ▣ KKKK1 항목
"""


def L(text):
    return [('SYNTH.md', i + 1, ln) for i, ln in enumerate(text.split('\n'))]


def probe(label):
    """축11 핵심 단정의 결과. 🔴 실사고 조건 = `NESTED_ONLY`(후속 절 부재)."""
    out = {}
    c1, _ = sb.current_handoff(L(NESTED_ONLY))
    out['중첩 절이 유일 후보여도 미선택'] = c1 is None
    cn, _ = sb.current_handoff(L(NESTED))
    out['후속 절이 있으면 그것이 현행'] = cn is not None and '0-LLLL' in cn['title']
    co, _ = sb.current_handoff(L(ORPHAN))
    out['예고만 하고 미작성 시 현행 0건'] = co is None
    print('[%s]' % label)
    for k, v in out.items():
        print('  %s %s' % ('PASS' if v else '🔴 FAIL', k))
    return out


# ── ① 현행(시정 후) 구현 ────────────────────────────────────────────────
after = probe('시정 후 (2축: 취소선 OR 승계 문구)')

# ── ② 시정 전 구현으로 되돌린다 = 취소선 단일 축 ─────────────────────────
#   🔴 원본 = `if START_PHRASE not in t or struck_out(t): continue`
#     ⇒ `superseded` 를 `struck_out` 으로 갈아끼우면 그 시점 코드와 동등하다.
sb.superseded = sb.struck_out
before = probe('시정 전 (1축: 취소선만 · O165 착수 시점 코드)')

print('')
regressed = [k for k in after if after[k] and not before[k]]
print('시정 후 통과 → 시정 전 실패로 뒤집힌 단정 = %d건' % len(regressed))
for k in regressed:
    print('  · %s' % k)

if len(regressed) < 1:
    print('🔴 실증 실패 — 축11 이 「고치기 전 코드」를 구별하지 못한다(테스트가 결함을 못 본다).')
    sys.exit(1)
#   🔴 [O165 자기시정 2회차] 초판 임계는 `< 2` 였다 — **직관으로 정한 값**이고 틀렸다.
#     축11 의 3단정 중 2건(「후속 절이 있으면 현행」·「예고만 하고 미작성 시 0건」)은 **오탐 방지 축**이라
#     설계상 시정 전·후 **둘 다 통과해야 한다**. 뒤집혀야 하는 것은 **결함 재현 축 1건**뿐이다.
#     ⇒ 판정식 #21(「등급도 판정식이다 — 실측으로 정하라」)의 임계값 판본이다.
print('🟢 실증 성공 — 결함 재현 축 %d건이 시정 전 코드에서 실패한다' % len(regressed))
print('   (나머지 2건은 오탐 방지 축이므로 시정 전·후 모두 통과가 정상이다).')
print('   ⇒ 절차서 §0 「성공 판정식」 충족.')
sys.exit(0)
