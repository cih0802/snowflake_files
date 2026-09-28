#!/usr/bin/env python3
"""MUTATES 도구 공용 --apply 드라이런 가드(무플래그 집행 차단) — I2 처방

🆕 [2026-09-23 O181 신설 · `new_tool.py` 경유 ⇒ `gate_census` 등재 완료]
🔴 분류 = `LIB`. 단독 실행 대상이 아니다 — import 로만 쓴다.

🔴🔴 **왜 필요한가(I2 실측 경위)**
   `gate_census.MUTATES` 에 등재된 도구 **11건**이 「승인 대상」으로 선언돼 있으면서
   정작 **집행을 멈출 수단이 없었다**(`--apply` 계열 플래그 0건 · O180-B 실측).
   그중 **3건**(`_o169_sv_redeploy`·`_o170_reserve`·`_o170_handoff_append`)은
   `main()` 조차 없는 **최상위 실행**이라 `python3 <파일>` 만으로 즉시 집행됐다.
   ⇒ 🟢 판정식 = **「선언」과 「강제」는 다른 것이다**(`O180-B-0 ㉠` 의 도구판).

🟢 **계약**
   · `--apply` 가 `sys.argv` 에 없으면 **아무것도 하지 않고 rc=0 으로 종료**한다.
     🔴 rc=1 이 아닌 이유 = 드라이런은 **위반이 아니다**(`gate_census` 의 「사용법 exit 2」
     규약과도 충돌하지 않게 둔다). 실수 실행이 조용히 집행되는 것만 막는 것이 목적이다.
   · `--help` 도 같은 경로로 막힌다(플래그가 없으므로).
   · 🔴 **이 가드는 승인의 대체물이 아니다** — `R4-4-3` 승인은 여전히 사람이 준다.

🟢 **삽입 규약** — 진입점 **최상단**(라이브 접속·파일 쓰기 **이전**)에 둔다.
🔴 [O181-B 정정] **줄 수는 파일마다 다르다** — 종전 문안은 「3줄」이라고 단정했으나
   실제 삽입은 기존 import 상황에 좌우된다. 📏 실측(11곳 전건 · 2026-09-23) =
   **2줄 3건**(`os`·`sys.path` 가 이미 있는 파일) · **4줄 8건** ⇒ 🔴 **3줄은 한 건도 없다.**
   ⇒ 🟢 **세는 것은 줄이 아니라 순서다**: 아래 ㉠㉡㉢ 이 **부작용보다 앞**에 오면 된다.

```
㉠ 경로 확보 — 이미 `sys.path.insert(0, <scripts>)` 가 있으면 **생략한다**
   import os as _gos
   sys.path.insert(0, _gos.path.dirname(_gos.path.abspath(__file__)))
㉡ from mutating_guard import require_apply  # noqa: E402
㉢ require_apply(__file__, '<무엇을 집행하는가>')   # 🔴 `--apply` 없으면 드라이런 종료
```
🔴 `main()` 이 있는 도구는 ㉢ 을 **`main()` 첫 줄**에, 최상위 실행 도구는 **import 직후**에 둔다.
🔴 **인자를 위치로 받는 도구는 `--apply` 를 걸러내라** — `main(sys.argv[1:])` 형태는 플래그가
   **파일 인자로 섞인다**(실물 = `deploy_sv.py`). 🟢 판정식 = **가드를 더하면 인자 해석이 바뀐다.**
🟢 순서 단정은 기계가 한다 = `scripts/test_mutating_guard.py` 축④(호출이 쓰기·커서보다 앞).
"""
import os
import sys


def has_apply(argv=None):
    """집행 플래그가 주어졌는가 — 판정 정본은 이 함수 하나다(같은 것을 다르게 재지 않는다)."""
    return '--apply' in (sys.argv[1:] if argv is None else argv)


def require_apply(caller, purpose, argv=None):
    """`--apply` 가 없으면 **집행 전에** 드라이런 안내를 내고 rc=0 으로 종료한다.

    caller  = 호출 파일 경로(`__file__`) · purpose = 집행 내용 1줄.
    🔴 반환은 `--apply` 가 있을 때만 일어난다 ⇒ 호출부는 반환 이후를 집행 경로로 둔다.
    """
    if has_apply(argv):
        return True
    name = os.path.basename(str(caller))
    print('🟠 DRY-RUN — 아무것도 집행하지 않았다.')
    print('   도구   = %s  (gate_census 분류 = MUTATES · `R4-4-3` 승인 대상)' % name)
    print('   집행분 = %s' % purpose)
    print('   실행   = python3 scripts/%s --apply   ← 승인을 받은 뒤에만' % name)
    sys.exit(0)


def main():
    print(__doc__)
    return 0


if __name__ == '__main__':
    sys.exit(main())
