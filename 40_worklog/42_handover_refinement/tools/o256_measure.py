"""O256 — 80 재빌드 사전 실측(읽기 전용 · 아무것도 쓰지 않는다).

사용: python3 o256_measure.py <결과 csv>
각 80 대상 파일을 3자 대조한다.
- src  = 워크스페이스 원본(build_handoff 가 복사할 바이트)
- cur  = 지금 80 사본
- sim  = 2층 처방 시뮬레이션 = hook(layer1(src))
         layer1 = .sql 에 clean80.clean (원본 1회 정제)
         hook   = 빌드 매회 = scrub254 규칙(계정 · init_ihcho) · .yml 은 주석만
판정: same(cur==src) · repro(cur==sim) · diff(그 밖) · new(80 에 없음)
"""
import csv, importlib.util, io, os, sys
T = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, T)
from clean80 import clean, strip_comments, SKIP as SQL_SKIP
from clean80b import clean_yml, strip_yml
import scrub254 as S

W = "/workspace/"
OUTD = W + "80_인수인계_프로젝트완료 및 유지보수용/"
spec = importlib.util.spec_from_file_location("bh", OUTD + "build_handoff.py")
bh = importlib.util.module_from_spec(spec); spec.loader.exec_module(bh)


def layer1(rel, text):
    if rel.endswith(".sql") and not any(k in rel for k in SQL_SKIP):
        new, _ = clean(text)
        assert strip_comments(new) == strip_comments(text), rel
        return new
    return text


def hook(rel80, text):
    if rel80.endswith((".yml", ".yaml")):
        new = clean_yml(text)
        assert strip_yml(new) == strip_yml(text), rel80
        return new
    if not rel80.lower().endswith(S.TEXT):
        return text
    new = S.scrub2(S.PRE.sub("", text))
    for f, old, rep, n in S.EXACT:
        if f == "80_인수인계_프로젝트완료 및 유지보수용/" + rel80:
            new = new.replace(old, rep)
    return "\n".join(l for l in new.split("\n") if not any(d.search(l) for d in S.DROP))


def main(out_csv):
    entries = bh.MANIFEST[:1] + bh.extract_run_order_sql() + bh.MANIFEST[1:]
    seen, rows = set(), []
    for sub, pat, _ in entries:
        for src, rel in bh.expand(pat):
            key = (sub, str(rel))
            if key in seen:
                continue
            seen.add(key)
            rel80 = f"{sub}/{rel}"
            sb = bh.run_order_text().encode() if str(rel) == bh.RUN_ORDER_DOC else src.read_bytes()
            dst = OUTD + rel80
            cb = open(dst, "rb").read() if os.path.exists(dst) else None
            try:
                st = sb.decode("utf-8")
                sim = hook(rel80, layer1(str(rel), st)).encode("utf-8")
            except UnicodeDecodeError:
                sim = sb
            if cb is None:
                k = "new"
            elif cb == sb:
                k = "same"
            elif cb == sim:
                k = "repro"
            else:
                k = "diff"
            rows.append((k, sub, str(rel), len(sb), -1 if cb is None else len(cb), len(sim)))
    with open(out_csv, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh); w.writerow(["kind", "sub", "rel", "src_B", "cur_B", "sim_B"]); w.writerows(rows)
    from collections import Counter
    print("total", len(rows), dict(Counter(r[0] for r in rows)))
    print("diff by sub", dict(Counter(r[1] for r in rows if r[0] == "diff")))


if __name__ == "__main__":
    main(sys.argv[1])
