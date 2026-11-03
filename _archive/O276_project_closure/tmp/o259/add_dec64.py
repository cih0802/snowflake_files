"""DEC-64 절을 30_설계_의사결정-017.md 말미에 추가(해시 대조 · 되읽기)."""
import hashlib, sys
P = "/workspace/20_issue/30_설계_의사결정_조각/30_설계_의사결정-017.md"
raw = open(P, "rb").read()
t = raw.decode("utf-8")
if "DEC-64" in t:
    sys.exit("already")
add = """
## 🟢 DEC-64 — 조직 「폐기」 정의 = 활성 트리 기준 단일화 · 판정 규칙 Silver 이관 (2026-10-23 O259 · TRIALADMIN(SR61467) · 사용자 승인 「전부 승인」)

> 🔒 라벨 = `id_collision_gate --next DEC` 실측 「정의 36 · 참조 63 ⇒ DEC64」.
> 배경 = Silver 를 읽는 소비자(Streamlit)가 정제 전 트리를 본다 · `USE_YN` 과 활성 트리 두 축이 어긋난다(하위 N·상위 Y 279건 · 하위 Y·상위 N 33건).
> 근거 실측 = `tmp/o259/evidence.md` E3·E5.

### 64-A. 결정

| # | 항목 | 결정 |
|---|---|---|
| 1 | 폐기 정의 | **활성 트리(O188-E) 하나** — 자기와 모든 상위가 `USE_YN='Y'` 이고 `LAST_UPDT_DT` 유효 · `USE_YN` 은 원천 속성으로만 보존 |
| 2 | 규칙 위치 | `SILVER.CRM_ORG_CLEAN`(상태·사유·활성 경로) · `SILVER.CRM_ORG_SUCCESSION`(DEC-63 귀속 규칙) 이 정본 · GOLD 2종은 SK 만 붙인다 |
| 3 | 화면 선택 | `SILVER.V_ORG_PICKER`(ACTIVE 만 · 상위부서 → 팀) |
| 4 | DEC-63 과의 관계 | 귀속 규칙·우선순위 **무변경**(위치만 이동) · 상위부서 귀속 컬럼 추가(Silver 전용) |
| 5 | seed | `ORG_SUCCESSION_MANUAL` 은 GOLD 스키마 유지(권한·적재 경로 무변경) |

### 64-B. 근거

- 📏 개발계 SR61467 2026-10-23 = 신구 `DIM_ORG`·`DIM_ORG_SUCCESSION` MINUS 양방향 0 · ACTIVE 223 · 사유 SELF_USE_YN 764 · SELF_LAST_UPDT 260 · UPPER_RETIRED 67 · picker 폐기 0 · 👤 build PASS=35.
- 현 GOLD 규칙과 같은 정의라 이 결정으로 바뀌는 행은 0 이다.

### 64-C. 하지 마라

- `USE_YN` 단독으로 폐기를 판정하기 — 상위 폐기 전파(UPPER_RETIRED)를 놓친다.
- 판정 규칙을 GOLD 에 다시 복제하기 — 「같은 것을 다르게 재는 지점」(`R3-9 ㉡`)이 된다.
- `V_ORG_PICKER` 를 dbt 모델로 옮기기 — SILVER pre-hook(TRUNCATE)이 뷰에서 실패한다.
"""
out = t.rstrip("\n") + "\n" + add
if hashlib.sha256(open(P, "rb").read()).digest() != hashlib.sha256(raw).digest():
    sys.exit("ABORT hash")
open(P, "wb").write(out.encode("utf-8"))
assert open(P, "rb").read() == out.encode("utf-8")
print("OK", len(out.encode()))
