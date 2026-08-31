# gen_gold_erd.py + gold_erd_coverage_gate.py 의 음성 테스트 — 정상 입력만으로는 0건인 결함을 잡는다.
# Co-authored with CoCo
#
# 왜 필요한가 (2026-08-31 O126 · 지침 R3-2 · R3-9 ⑥):
#   🔴 초판 ERD 는 **게이트도 문법검사도 전부 통과한 상태에서** DIM_MONTH 를 고립 섬으로 그렸다.
#   「Mermaid 문법 유효 38/38」과 「관계가 설계를 옳게 전달한다」는 **다른 판정**이다
#   (인수인계 CCCC1 = 「객체가 다 있다」와 「설계대로 작동한다」는 다른 판정이다).
#   ⇒ 이 테스트는 **오염 입력**(관계를 일부러 빼거나 분류를 지운 입력)으로 검출력을 단정한다.
#
# 축 목록 — 🔴 축 수를 문서에 적지 마라. 이 파일이 스스로 세어 출력한다(R3-9 ㉦).
#
# 실행: python3 scripts/test_gold_erd.py       (종료코드로 판정 · 파이프 뒤 $? 금지 · O120)

import os
import re
import sys
import importlib.util

ROOT = "/workspace"
sys.path.insert(0, os.path.join(ROOT, "scripts"))

PASS, FAIL = [], []


def check(axis, ok, detail=""):
    (PASS if ok else FAIL).append((axis, detail))
    print(f"  {'🟢' if ok else '🔴'} {axis}" + (f" — {detail}" if detail else ""))


def load(name):
    spec = importlib.util.spec_from_file_location(
        name, os.path.join(ROOT, "scripts", f"{name}.py"))
    mod = importlib.util.module_from_spec(spec)
    saved = sys.argv
    sys.argv = [name]
    try:
        spec.loader.exec_module(mod)
    finally:
        sys.argv = saved
    return mod


# ── 픽스처: 라이브 없이 도는 최소 모델 ──────────────────────────────────────
def fixture_models():
    return {
        "DIM_MONTH": {"pk": ["MONTH_KEY"], "fk": [], "columns": ["MONTH_KEY"],
                      "description": "", "pk_live": ["MONTH_KEY"]},
        "DIM_DATE": {"pk": ["DATE_SK"], "fk": [], "columns": ["DATE_SK"],
                     "description": "", "pk_live": ["DATE_SK"]},
        "FACT_BUDGET": {"pk": [], "fk": [], "columns": ["MONTH_KEY", "ORG_SK"],
                        "description": "", "pk_live": []},
    }


def main():
    print("=== gen_gold_erd / gold_erd_coverage_gate 음성 테스트 ===\n")
    g = load("gen_gold_erd")
    gate = load("gold_erd_coverage_gate")

    # ── 축1: 관계선 연산자가 출처별로 갈라지는가 ──────────────────────────
    print("[축1] rel_op — 논리 관계는 점선이어야 한다")
    check("축1-a 선언 FK = 실선", g.rel_op("both") == "||--o{", g.rel_op("both"))
    check("축1-b live = 실선", g.rel_op("live") == "||--o{", g.rel_op("live"))
    check("축1-c yaml = 실선", g.rel_op("yaml") == "||--o{", g.rel_op("yaml"))
    check("축1-d logical = 점선", g.rel_op("logical") == "||..o{", g.rel_op("logical"))
    check("축1-e src 미지정도 실선으로 안전 기본",
          g.rel_op(None) == "||--o{", g.rel_op(None))

    # ── 축2: 오염 — 논리 관계를 빼면 DIM_MONTH 가 고립되는가 ──────────────
    #   🔴 이것이 초판의 실제 결함이다. 검출력을 여기서 단정한다.
    print("\n[축2] 오염 입력 — 논리 관계 없이 그리면 DIM_MONTH 가 고립된다(초판 재현)")
    m_bad = fixture_models()
    erd_bad = g.build_full_erd(m_bad)
    isolated = "DIM_MONTH" not in re.sub(r"^\s*DIM_MONTH \{.*?^\s*\}", "",
                                        erd_bad, flags=re.S | re.M)
    rel_bad = re.findall(r"DIM_MONTH \|\|[-.]{2}o\{", erd_bad)
    check("축2-a 오염 입력에서 DIM_MONTH 관계선 0 (결함 재현 성공)",
          len(rel_bad) == 0, f"관계선 {len(rel_bad)}")

    # ── 축3: 논리 관계를 병합하면 관계선이 생기는가 ───────────────────────
    print("\n[축3] 복구 — 논리 관계 병합 후 DIM_MONTH 관계선이 생긴다")
    m_ok = fixture_models()
    m_ok, ls = g.merge_logical_fk(
        m_ok, [("FACT_BUDGET", "MONTH_KEY"), ("FACT_BUDGET", "ORG_SK")],
        {"DIM_MONTH": ["MONTH_KEY"], "DIM_DATE": ["DATE_SK"]})
    erd_ok = g.build_full_erd(m_ok)
    rel_ok = re.findall(r"DIM_MONTH \|\|\.\.o\{ FACT_BUDGET", erd_ok)
    check("축3-a MONTH_KEY 논리 관계 1건 추가", ls["logical_added"] == 1,
          f"added={ls['logical_added']}")
    check("축3-b DIM_MONTH → FACT_BUDGET 점선 관계선 생성", len(rel_ok) == 1,
          f"점선 {len(rel_ok)}")
    check("축3-c ORG_SK 는 미분류로 보고된다(분류부에 없다)",
          ("FACT_BUDGET", "ORG_SK") in ls["unclassified"],
          str(ls["unclassified"]))

    # ── 축4: 미분류 고립이 있으면 생성이 중단되는가 ───────────────────────
    #   🔴 「경고만 내고 그려버리면」 초판과 같은 결과가 된다 ⇒ blocking 이어야 한다.
    print("\n[축4] 미분류 고립은 blocking 이어야 한다(경고로 흘리면 안 된다)")
    src = open(os.path.join(ROOT, "scripts", "gen_gold_erd.py"), encoding="utf-8").read()
    has_block = re.search(r'if lstats\["unclassified"\]:[\s\S]{0,600}?return 1', src)
    check("축4-a main() 이 미분류 고립에서 return 1 한다", bool(has_block))
    check("축4-b __main__ 이 sys.exit(main()) 로 종료코드를 전달한다",
          "sys.exit(main())" in src)

    # ── 축5: 분류 규칙이 한 곳에만 있는가 (R3-9 ㉡ 이중 정의 금지) ────────
    print("\n[축5] 규칙 단일 정본 — 생성기가 규칙을 복사하지 않았는가")
    check("축5-a 생성기가 게이트를 import 한다",
          "import gold_erd_coverage_gate" in src)
    check("축5-b 생성기에 LOGICAL_FK 정의가 없다(복사 금지)",
          not re.search(r"^LOGICAL_FK\s*=", src, re.M))
    check("축5-c 생성기에 KNOWN_ORPHANS 정의가 없다(복사 금지)",
          not re.search(r"^KNOWN_ORPHANS\s*=", src, re.M))

    # ── 축6: --yaml-only 가 전량판을 덮지 않는가 ──────────────────────────
    print("\n[축6] --yaml-only 산출물이 전량판 경로를 덮지 않는다")
    check("축6-a 별도 출력 경로가 정의돼 있다", hasattr(g, "OUT_HTML_YAML"))
    check("축6-b 두 경로가 다르다", g.OUT_HTML != g.OUT_HTML_YAML,
          os.path.basename(g.OUT_HTML_YAML))
    check("축6-c main() 이 플래그로 경로를 가른다",
          "OUT_HTML_YAML if YAML_ONLY else OUT_HTML" in src)

    # ── 축7: 분류부의 CONFORM 은 전부 LOGICAL_FK 대상이 있는가 ────────────
    #   🔴 CONFORM 이라 적고 대상을 안 적으면 「분류했는데 ERD 에 안 그려지는」 침묵이 된다.
    #   🆕 [2026-08-31 O128] 판정을 `logical_target()` 경유로 바꿨다 — 종전 `k[1] not in LOGICAL_FK`
    #     는 **컬럼 전역 키만 봤다** ⇒ O128 이 넣은 테이블 한정 규칙 7건을 전부 「누락」으로 오탐했다.
    #     🟢 이 오탐이 실제로 발생해 적발됐다(정상 입력만으로는 0건인 결함 · `R3-2` 의 실물).
    print("\n[축7] CONFORM 분류는 반드시 LOGICAL_FK 대상을 가진다")
    orphan_conform = [k for k, v in gate.KNOWN_ORPHANS.items() if v[0] == "CONFORM"]
    missing = [k for k in orphan_conform if gate.logical_target(k[0], k[1]) is None]
    check("축7-a CONFORM 전건이 LOGICAL_FK 에 대상을 가진다", not missing,
          f"CONFORM {len(orphan_conform)} · 대상 누락 {len(missing)} {missing}")
    # 🆕 축7-b — 전역 규칙(`("*", col)`)은 반드시 **컬럼 전역 대상**을 가져야 한다.
    #   🔴 전역 분류에 테이블 한정 대상만 주면 다른 테이블에서 조용히 미분류가 된다.
    star_conform = [k for k in orphan_conform if k[0] == "*"]
    star_missing = [k for k in star_conform if k[1] not in gate.LOGICAL_FK]
    check("축7-b 전역 CONFORM 은 컬럼 전역 대상을 가진다", not star_missing,
          f"전역 CONFORM {len(star_conform)} · 누락 {len(star_missing)} {star_missing}")

    # ── 축8: Mermaid 타입 정규화 (괄호·쉼표는 문법 위반) ──────────────────
    print("\n[축8] Mermaid 타입 정규화 — 괄호·쉼표가 남으면 렌더가 깨진다")
    check("축8-a NUMBER(6,0) 정규화", "(" not in g._mm_type("NUMBER(6,0)")
          and "," not in g._mm_type("NUMBER(6,0)"), g._mm_type("NUMBER(6,0)"))
    check("축8-b VARCHAR(16777216) 정규화", "(" not in g._mm_type("VARCHAR(16777216)"),
          g._mm_type("VARCHAR(16777216)"))
    check("축8-c 꼬리 밑줄 제거", not g._mm_type("NUMBER(8,0)").endswith("_"),
          g._mm_type("NUMBER(8,0)"))

    # ── 축9: 산출물에 실제로 DIM_MONTH 관계가 있는가 (회귀 가드) ──────────
    print("\n[축9] 산출물 회귀 가드 — 발행된 HTML 에 DIM_MONTH 관계가 실재한다")
    if os.path.exists(g.OUT_HTML):
        h = open(g.OUT_HTML, encoding="utf-8").read()
        mo = re.search(r'<section id="overview">(.*?)</section>', h, re.S)
        n = len(re.findall(r"DIM_MONTH \|\|\.\.o\{", mo.group(1))) if mo else 0
        check("축9-a 전체 ERD 에 DIM_MONTH 점선 관계가 1건 이상", n >= 1,
              f"점선 {n}건")
        sec = re.search(r'<section id="DIM_MONTH">(.*?)</section>', h, re.S)
        refs = re.findall(r"<li><code>(FACT_\w+\.\w+)</code></li>",
                          sec.group(1)) if sec else []
        check("축9-b DIM_MONTH 섹션에 역참조 팩트가 1건 이상", len(refs) >= 1,
              f"{len(refs)}건 {refs[:3]}")
        check("축9-c logical 배지가 산출물에 실재한다", 'class="b logical"' in h)
        check("축9-d CDN 실패 폴백이 산출물에 실재한다", "id='mmfail'" in h or 'id="mmfail"' in h)
    else:
        check("축9 산출물 미존재 — 먼저 gen_gold_erd.py 를 실행하라", False, g.OUT_HTML)

    # ── 축10: 산출물 회전 — 기존 HTML 을 덮지 않고 보관하는가 ─────────────
    #   🔴 [O126] 이 축이 없으면 「보관했다」를 코드 읽기로만 믿게 된다.
    #      실제 파일을 만들어 회전시키고 **원본 바이트가 보존되는지** 단정한다.
    print("\n[축10] 산출물 회전 — 기존 판본을 덮지 않고 `_archive/` 에 보관한다")
    import tempfile
    import shutil
    from snapshot_util import dated_snapshot_name, snapshot, SnapshotError

    tmp = tempfile.mkdtemp(prefix="erdrot_")
    try:
        art = os.path.join(tmp, "OUT.html")
        arch = os.path.join(tmp, "_archive")
        v1 = "<html>생성 2026-08-30 09:00 · v1</html>"
        open(art, "w", encoding="utf-8").write(v1)

        # 축10-a: 선언 축으로 날짜를 읽는가 (mtime 이 아니라)
        d, axis = g.artifact_date(art)
        check("축10-a 선언된 생성일을 읽는다", (d, axis) == ("20260830", "선언"),
              f"{d} / {axis}")

        # 축10-b: 이름이 확장자를 보존하는가
        nm = dated_snapshot_name(art, d)
        check("축10-b 회전 이름이 .html 확장자를 보존한다",
              nm == "OUT_20260830.html", nm)

        # 축10-c: 보관 후 원본 바이트가 그대로 남는가
        snap, st = snapshot(art, "prerun", label="TEST", archive=arch,
                            name=nm, keep_ext=True, quiet=True)
        check("축10-c 보관본 바이트가 원본과 동일",
              open(snap, encoding="utf-8").read() == v1, st)

        # 축10-d: 같은 날 다른 내용 → 덮지 않고 확장자 앞에 접미
        v2 = "<html>생성 2026-08-30 18:00 · v2</html>"
        open(art, "w", encoding="utf-8").write(v2)
        snap2, st2 = snapshot(art, "prerun", label="TEST", archive=arch,
                              name=dated_snapshot_name(art, "20260830"),
                              keep_ext=True, quiet=True)
        check("축10-d 충돌 시 접미가 확장자 앞에 붙는다",
              os.path.basename(snap2) == "OUT_20260830_2.html" and st2 == "suffixed",
              os.path.basename(snap2))
        check("축10-e 🔴 첫 보관본이 덮이지 않았다",
              open(snap, encoding="utf-8").read() == v1)

        # 축10-f: 바이트 동일 재보관은 파일을 늘리지 않는다(멱등)
        before = len(os.listdir(arch))
        snap3, st3 = snapshot(art, "prerun", label="TEST", archive=arch,
                              name=dated_snapshot_name(art, "20260830"),
                              keep_ext=True, quiet=True)
        check("축10-f 멱등 — 동일 내용은 파일 수를 늘리지 않는다",
              st3 == "reused" and len(os.listdir(arch)) == before,
              f"{st3} · {before}→{len(os.listdir(arch))}")

        # 축10-g: 기존 파일이 없으면 회전을 건너뛴다(예외를 던지지 않는다)
        check("축10-g 산출물 미존재 시 None 을 돌려준다",
              g.rotate_previous(os.path.join(tmp, "NOPE.html")) is None)

    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # ── 축11: 회전이 snapshot_util 을 경유하는가 (R1-7-10 우회 금지) ───────
    #   🔴 [O126 복구] 이 축은 축12·축13 을 삽입할 때 앵커가 짧아 **한 번 지워졌다**
    #      (`R1-7-8` 「앵커는 직전 줄까지 포함하라」의 이 세션 두 번째 재발) ⇒ 즉시 복구했다.
    print("\n[축11] `R1-7-10` — 회전이 snapshot_util 을 경유하고 경로를 조립하지 않는다")
    code = "\n".join(ln for ln in src.split("\n") if not ln.lstrip().startswith("#"))
    check("축11-a snapshot_util 을 import 한다", "from snapshot_util import" in code)
    check("축11-b 보관 경로를 직접 조립하지 않는다(shutil.copy 없음)",
          "shutil.copy" not in code and "shutil.move" not in code)
    check("축11-c 라벨 산식을 재구현하지 않는다(resolve_label 경유)",
          "SESSION_LABEL" not in code,
          "환경변수 직독 없음" if "SESSION_LABEL" not in code else "🔴 직독 발견")
    check("축11-d 회전이 write 보다 먼저 온다",
          src.index("rotate_previous(out_path") < src.index("f.write(html)"))

    # ── 축12: 개정 ② — 실질 변경이 없으면 회전하지 않는다 ─────────────────
    #   🔴🔴 [O126 개정 ②] `snapshot_util` 의 「바이트 동일 재사용」 멱등은 이 산출물에
    #      **원리적으로 듣지 않았다** — HTML 이 생성 시각을 본문에 박아 내용이 같아도
    #      바이트가 항상 다르다. 실측 = 검증용 3판본의 차이가 생성 시각 한 줄뿐이었다.
    #      ⇒ 이 축이 「돌린 횟수」가 아니라 **「실제로 바뀐 횟수」**만큼 쌓임을 단정한다.
    print("\n[축12] 개정 ② — 생성 시각만 다르면 회전을 생략한다")
    tmp2 = tempfile.mkdtemp(prefix="erdnochg_")
    try:
        art = os.path.join(tmp2, "OUT.html")
        arch = os.path.join(tmp2, "_archive", "_rolling")
        base = "<html><div>생성 %s · 계정 K · 총 관계 70</div><p>body</p></html>"
        open(art, "w", encoding="utf-8").write(base % "2026-08-30 09:00")

        # 축12-a: 정규화가 생성 시각만 지우고 나머지는 남기는가
        n1 = g.normalize_for_compare(base % "2026-08-30 09:00")
        n2 = g.normalize_for_compare(base % "2026-08-31 23:59")
        check("축12-a 생성 시각이 달라도 정규화 결과는 같다", n1 == n2)
        check("축12-b 🔴 계정·관계수는 지우지 않는다(실질 변경을 놓치면 안 된다)",
              "계정 K" in n1 and "총 관계 70" in n1)

        # 축12-c: 시각만 다른 새 HTML → 회전 생략
        rot = g.rotate_previous(art, new_html=base % "2026-08-31 23:59",
                                archive=arch)
        check("축12-c 시각만 다르면 'unchanged' 를 돌려준다",
              rot is not None and rot[0] == "unchanged", str(rot and rot[0]))
        check("축12-d 🔴 보관 파일이 생기지 않았다", not os.path.isdir(arch))

        # 축12-e: 실질 변경이 있으면 회전한다
        rot2 = g.rotate_previous(
            art, new_html=base.replace("총 관계 70", "총 관계 71") % "2026-08-30 09:00",
            label="TEST", archive=arch)
        check("축12-e 실질 변경이 있으면 보관한다",
              rot2 is not None and rot2[0] != "unchanged", str(rot2 and rot2[0]))

        # 축12-f: new_html 미지정이면 무조건 회전(비교 대상이 없으므로 안전측)
        rot3 = g.rotate_previous(art, label="TEST", archive=arch)
        check("축12-f new_html 없으면 무조건 보관한다(안전측)",
              rot3 is not None and rot3[0] != "unchanged", str(rot3 and rot3[0]))

        # 축12-g 🔴🔴 오염 가드 — 보관본이 **임시 경로 안에** 있어야 한다
        #   [O126 자기시정] 초판 축12 는 `archive` 를 넘기지 않아 실 `_archive/_rolling/` 에
        #   `OUT_20260830.html` 을 만들었다. **테스트는 전건 통과했고 오염은 판정에 없었다.**
        #   ⇒ 이 축이 「내가 쓴 곳이 내가 의도한 곳인가」를 단정한다.
        for tag, r in (("e", rot2), ("f", rot3)):
            check(f"축12-g({tag}) 🔴 보관본이 임시 경로 안에 있다(실 _archive 오염 0)",
                  os.path.realpath(r[0]).startswith(os.path.realpath(tmp2)),
                  os.path.relpath(r[0], ROOT))
    finally:
        shutil.rmtree(tmp2, ignore_errors=True)

    # ── 축13: 개정 ① — 롤링 백업이 `_rolling/` 하위로 격리돼 있다 ──────────
    print("\n[축13] 개정 ① — 롤링 백업이 `_archive/_rolling/` 으로 격리된다")
    check("축13-a ARCHIVE_DIR 이 `_rolling` 하위다",
          os.path.basename(g.ARCHIVE_DIR) == "_rolling", g.ARCHIVE_DIR)
    check("축13-b 날짜 폴더 관례(`_archive/` 최상위)와 층이 다르다",
          os.path.basename(os.path.dirname(g.ARCHIVE_DIR)) == "_archive")
    live_arch = os.path.join(ROOT, "30_output_share", "_archive")
    if os.path.isdir(live_arch):
        stray = [f for f in os.listdir(live_arch)
                 if f.startswith("GOLD_ERD") and f.endswith(".html")]
        check("축13-c `_archive/` 최상위에 롤링 파일이 남아 있지 않다",
              not stray, f"잔존 {len(stray)}건 {stray[:2]}")
    live_roll = os.path.join(live_arch, "_rolling")
    if os.path.isdir(live_roll):
        # 🔴 [O126] 실 `_rolling/` 에는 **이 산출물의 판본만** 있어야 한다.
        #   테스트 픽스처 이름(`OUT_`)이 여기 보이면 오염이다 — 축12-g 가 막지만
        #   과거 실행이 남긴 잔재는 이 축이 잡는다(같은 것을 다르게 재는 두 지점).
        junk = [f for f in os.listdir(live_roll)
                if not f.startswith("GOLD_ERD_")]
        check("축13-d 🔴 실 `_rolling/` 에 테스트 잔재가 없다",
              not junk, f"잔재 {len(junk)}건 {junk[:3]}")

    # ── 결과 ──────────────────────────────────────────────────────────────
    total = len(PASS) + len(FAIL)
    print(f"\n{'='*60}")
    print(f"단정 {total}건 · 🟢 통과 {len(PASS)} · 🔴 실패 {len(FAIL)}")
    if FAIL:
        print("\n🔴 실패 목록:")
        for a, d in FAIL:
            print(f"  · {a} — {d}")
        return 1
    print("🟢 ALL PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
