"""O254 — 80·85 비운영 계정 로케이터 + init_ihcho 언급 제거 (`_archive/` 는 백업이라 제외).

사용: python3 scrub254.py [--dry]
- 계정: scrub_acct.ACC(운영계 ZL50263 제외) 를 clean80b.scrub2 로 제거.
- init_ihcho: 아래 EXACT 치환표(정확 문자열 · 기대 건수 assert) + 줄 삭제 규칙.
- 변경 파일은 쓰기 전 2회 해시가 같아야 하고, 원본을 BAK 에 복사한다(이미 있으면 덮지 않는다).
"""
import hashlib, io, os, re, shutil, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scrub_acct import ACC
from clean80b import scrub2

W = "/workspace/"
ROOTS = ["80_인수인계_프로젝트완료 및 유지보수용", "85_실제 인수인계 문서"]
BAK = W + "95_작업기록_인수인계정제/_backup_O254_원본_20261021/"
TEXT = (".md", ".csv", ".html", ".yml", ".yaml", ".txt")
ACC_RE = re.compile("(?<![A-Za-z0-9])(" + "|".join(ACC) + ")(?![0-9])", re.I)
# scrub_acct 의 `· 계정 X)` 규칙은 바깥 괄호의 `)` 까지 먹는다 ⇒ 닫는 괄호 앞 토큰은 먼저 지운다.
PRE = re.compile(r"\s*·\s*(?:개발계\s*|계정\s*)?\*{0,2}`?(?:" + "|".join(ACC) + r")`?\*{0,2}(?=\))", re.I)


def paren_bal(s):
    return [l.count("(") - l.count(")") for l in s.split("\n")]
IH = re.compile("init_ihcho", re.I)
I20 = "80_인수인계_프로젝트완료 및 유지보수용/07_운영런북_이슈/20_issue/"
IX = I20 + "00_INDEX_이슈원장_조각/00_INDEX_이슈원장-"
D50 = I20 + "50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-"
EXACT = [
    (IX + "002.md", "🟢 **매 세션 노출은 `init_ihcho` §1 G4 가 담보한다**", "🟢 **매 세션 노출은 세션 초기화 절차가 담보한다**", 1),
    (IX + "002.md", "🟢 **매 세션 노출은 `init_ihcho` §5-2 가 담보**", "🟢 **매 세션 노출은 세션 초기화 절차가 담보**", 1),
    (IX + "002.md", "(`init_ihcho` Step 0.7 의 O92-C 다이어트를 전 조문으로 확장)", "", 1),
    (I20 + "91_사고사례집.md", "`init_ihcho` Step 3 가 **무조건 STOP**", "세션 초기화 절차가 **무조건 STOP**", 1),
    (IX + "012.md", " · `init_ihcho/SKILL.md`", "", 4),
    (IX + "012.md", " + `init_ihcho` 개선", "", 1),
    (IX + "005.md", " · `00_guides/03_init_ihcho_스킬_본문.md`·`_참조_세션종료.md` · `.snowflake/cortex/skills/init_ihcho/`", "", 1),
    (IX + "005.md", " · `00_guides/03_init_ihcho_스킬_본문.md`", "", 1),
    (D50 + "019.md", "(`init_ihcho` 기재값과 일치)", "", 1),
    (D50 + "019.md", "`init_ihcho` Step 2 항목1 = ", "세션 초기화 절차 Step 2 항목1 = ", 1),
    (IX + "013.md", " · `init_ihcho` Step 1·2·3", "", 1),
    (IX + "017.md", " + `init_ihcho` Step 2 갱신", "", 1),
]
DROP = [
    re.compile(r"^> 원본 `[^`]*init_ihcho[^`]*` .*무변경 이관"),     # 91 사례집 출처 주석 5줄
    re.compile(r"^\| `00_guides/03_init_ihcho_"),                     # 원장 002 §0 유형표 4행
    re.compile(r"^\| 🟢 \*\*`O194`\*\* — init_ihcho 스킬"),            # 원장 004 O194 행(스킬 개정 단위)
]


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def targets():
    for r in ROOTS:
        for d, ds, fs in os.walk(W + r):
            ds[:] = [x for x in ds if x not in ("_archive", "__pycache__")]
            for f in fs:
                if f.lower().endswith(TEXT):
                    yield os.path.join(d, f)


def main(dry):
    plan = {}
    for p in targets():
        try:
            raw = io.open(p, encoding="utf-8").read()
        except UnicodeDecodeError:
            continue
        if ACC_RE.search(raw) or IH.search(raw):
            plan[p] = raw
    tot = [0, 0, 0, 0]
    for p, raw in sorted(plan.items()):
        rel = p[len(W):]
        new = scrub2(PRE.sub("", raw)) if not rel.endswith((".yml", ".yaml")) else raw
        for f, old, rep, n in EXACT:
            if f == rel:
                c = new.count(old)
                assert c == n, (rel, old, c)
                new = new.replace(old, rep)
        lines = new.split("\n")
        keep = [l for l in lines if not any(d.search(l) for d in DROP)]
        new = "\n".join(keep)
        b0 = paren_bal(raw if len(keep) == len(lines) else "\n".join(l for l in raw.split("\n") if not any(d.search(l) for d in DROP)))
        b1 = paren_bal(new)
        bad = [i + 1 for i, (x, y) in enumerate(zip(b0, b1)) if x != y] if len(b0) == len(b1) else ["줄수불일치"]
        if bad:
            print("  ⚠ 괄호 균형 변화 줄:", bad[:10])
        a0, a1 = len(ACC_RE.findall(raw)), len(ACC_RE.findall(new))
        i0, i1 = len(IH.findall(raw)), len(IH.findall(new))
        tot[0] += a0; tot[1] += a1; tot[2] += i0; tot[3] += i1
        print(f"{a0:3d}->{a1} acct · {i0:2d}->{i1} ih · drop {len(lines)-len(keep)} · {rel}")
        if dry or new == raw:
            continue
        h1 = sha(p); time.sleep(1); h2 = sha(p)
        assert h1 == h2, ("UNSTABLE", rel)
        b = BAK + rel
        if not os.path.exists(b):
            os.makedirs(os.path.dirname(b), exist_ok=True)
            shutil.copyfile(p, b)
            assert sha(b) == h1, rel
        io.open(p, "w", encoding="utf-8").write(new)
        assert io.open(p, encoding="utf-8").read() == new, rel
    print("files", len(plan), "acct", tot[0], "->", tot[1], "init_ihcho", tot[2], "->", tot[3])


if __name__ == "__main__":
    main("--dry" in sys.argv)
