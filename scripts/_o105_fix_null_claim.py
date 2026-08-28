# O105 자기적발 정정 — WIDE 전환 문안의 「NULL 의 뜻이 바뀐다」 주장을 실측 반증에 맞춰 고친다.
# Co-authored with CoCo
#
# 무엇이 틀렸나 (2026-08-28 O105 · 자기적발)
#   전환 문안에 *"종전 실시간 조인에서는 CAMPAIGN_SK=0 센티넬 조인으로 '(미매핑)' 이 나왔으므로
#   NULL 의 뜻이 바뀐 지점이다"* 라고 썼는데 **실측이 반증했다.**
#   전환 前 라이브 실측(STOP 행 1,038,262건) = 9축 전건 **이미 NULL** · `'(미매핑)'` **0건**.
#   원인 = `DIM_CAMPAIGN` 의 SK=0 시드 행이 **이름 컬럼(CAMPAIGN_NAME)만** `'(미매핑)'` 으로 채우고
#   나머지 속성 컬럼은 NULL 로 둔다(`R2-7-3` 표기 축 규약과 정합 · 식별 컬럼 `(미매핑)` / 속성 컬럼 NULL).
#   ⇒ 이 전환은 **NULL 의 의미를 바꾸지 않는다.** 내가 위험을 창작해 적은 것이고, 그것을 라이브에
#     실릴 COMMENT 에 넣는 것은 `R2-3`(미실측 단정) · `P212`(COMMENT 는 주장 발행) 위반이다.
#   🟢 실제로는 전환이 내가 적은 것보다 **더 안전하다** — 값도 NULL 의미도 변하지 않는다.
#
# 고칠 표면 3곳: ① 모델 주석 ② `_wide_schema.yml` 11 description ③ 세션이력 §O105 ▣F.
# R1-7-9: 백틱·따옴표가 본문에 있어 셸을 경유시키지 않고 파일로 만들어 실행한다.

import glob
import hashlib
import shutil

OLD_MODEL = (
    "    --   ⚠️ 중단(STOP) 행은 개발원천 컬럼이 없어 이 9축이 **전건 NULL** 이다(종전 실시간 조인에서는\n"
    "    --   CAMPAIGN_SK=0 센티넬 조인으로 '(미매핑)' 이 나왔다) ⇒ **NULL 의 뜻이 바뀐 유일한 지점**이다.\n"
)
NEW_MODEL = (
    "    --   🟢 **NULL 의 의미는 바뀌지 않는다**(전환 前 라이브 실측으로 확인) — 중단(STOP) 행에서 이 9축은\n"
    "    --   **전환 전에도 이미 전건 NULL** 이었고 `'(미매핑)'` 은 0건이었다. `DIM_CAMPAIGN` 의 SK=0 시드가\n"
    "    --   **이름 컬럼(CAMPAIGN_NAME)만** `'(미매핑)'` 으로 채우고 속성 컬럼은 NULL 로 두기 때문이다\n"
    "    --   (`R2-7-3` = 식별 컬럼 `(미매핑)` / 속성 컬럼 NULL). ⚠️ 초판 주석은 *「NULL 의 뜻이 바뀐다」*\n"
    "    --   고 적었는데 **실측 반증으로 철회**했다 — 규모·경위는 이슈원장 §O105. STOP 행 NULL 은\n"
    "    --   「개발원천에 그 컬럼이 없다」는 구조적 부재이며 0·'미상' 으로 대체 해석하지 않는다(`R2-7-1`).\n"
)

OLD_YML = (
    "⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 종전 실시간 조인에서는 "
    "센티넬 조인으로 '(미매핑)' 이 나왔으므로 **NULL 의 뜻이 바뀐 지점**이다(0·'미상' 으로 대체 해석 금지)."
)
NEW_YML = (
    "⚠️ 중단(STOP) 행은 개발원천에 이 컬럼이 없어 **NULL** 이다 — 이는 구조적 부재이며 0·'미상' 으로 "
    "대체 해석하지 않는다(`R2-7-1`). 🟢 **전환으로 NULL 의 의미가 바뀌지 않았다**(전환 前 라이브 실측 = "
    "STOP 행에서 이 축은 이미 전건 NULL · `'(미매핑)'` 0건 — `DIM_CAMPAIGN` SK=0 시드가 이름 컬럼만 "
    "채우기 때문 · `R2-7-3`)."
)

OLD_HIST = (
    "> · ⚠️ **NULL 의 뜻이 바뀐 유일한 지점** = 중단(STOP) 행. 종전엔 `CAMPAIGN_SK=0` 센티넬 조인으로\n"
    ">   `'(미매핑)'` 이 나왔고 이제는 **NULL** 이다 ⇒ yml 문안에 명시했다(0·'미상' 대체 해석 금지 · `R2-7`).\n"
)
NEW_HIST = (
    "> · 🔴 **자기적발·철회 1** — 전환 문안에 *「중단(STOP) 행의 NULL 의 뜻이 바뀐다(종전 `'(미매핑)'`)」*\n"
    ">   고 적었으나 **실측이 반증**했다: 전환 前 라이브 STOP 행 **1,038,262**건에서 9축은 **이미 전건 NULL**\n"
    ">   이고 `'(미매핑)'` 은 **0건**이다(`'(미매핑)'` 은 `CAMPAIGN_NAME` 에만 붙는다 — `DIM_CAMPAIGN` SK=0\n"
    ">   시드가 **이름 컬럼만** 채우고 속성 컬럼은 NULL 로 두기 때문 · `R2-7-3`). ⇒ **이 전환은 NULL 의\n"
    ">   의미를 바꾸지 않는다**(내가 위험을 창작해 라이브 COMMENT 에 넣으려 한 것 = `R2-3`·`P212` 위반)\n"
    ">   ⇒ 모델 주석·yml 11 description·이 항목 **3표면 전건 정정**. 🟢 실제로는 전환이 더 안전하다.\n"
)


def patch(path, old, new, label, snap_suffix):
    raw = open(path, encoding="utf-8").read()
    n = raw.count(old)
    assert n >= 1, f"{label}: 대상 문안을 찾지 못했다 — 중단"
    snap = f"_archive/{path.split('/')[-1]}.O105-{snap_suffix}"
    shutil.copyfile(path, snap)
    out = raw.replace(old, new)
    open(path, "w", encoding="utf-8").write(out)
    over = [i + 1 for i, s in enumerate(out.split("\n")) if len(s) > 2000]
    print(f"{label}: 치환 {n}건 · {len(raw.encode())} -> {len(out.encode())}B · "
          f"SHA {hashlib.sha256(out.encode()).hexdigest()[:12]} · 2000자초과 {over} · 스냅샷 {snap}")
    assert not over
    assert old not in out, f"{label}: 구 문안 잔존 — 중단"
    return n


def main() -> None:
    total = 0
    total += patch("10_dbt_pipeline/models/gold/wide/WIDE_MEMBER_EVENT.sql",
                   OLD_MODEL, NEW_MODEL, "① 모델 주석", "fix-null-model")
    total += patch("10_dbt_pipeline/models/gold/wide/_wide_schema.yml",
                   OLD_YML, NEW_YML, "② yml description", "fix-null-yml")
    hist = sorted(glob.glob("20_issue/01_세션이력_조각/01_세션이력-0*.md"))[-1]
    total += patch(hist, OLD_HIST, NEW_HIST, f"③ 이력 {hist.split('/')[-1]}", "fix-null-hist")

    # 사후 검증: yaml 파싱 + SELECT↔yml 대조는 별도 게이트로 확인한다.
    import yaml
    d = yaml.safe_load(open("10_dbt_pipeline/models/gold/wide/_wide_schema.yml", encoding="utf-8"))
    mdl = [m for m in d["models"] if m["name"] == "WIDE_MEMBER_EVENT"][0]
    bad = [c["name"] for c in mdl["columns"] if "NULL 의 뜻이 바뀐" in c["description"]]
    fixed = sum(1 for c in mdl["columns"] if "NULL 의 의미가 바뀌지 않았다" in c["description"])
    print(f"\n총 치환 {total}건 · yaml OK 컬럼 {len(mdl['columns'])} · "
          f"구 주장 잔존 {bad} · 정정 문안 {fixed}컬럼")
    assert not bad and fixed == 11


if __name__ == "__main__":
    main()
