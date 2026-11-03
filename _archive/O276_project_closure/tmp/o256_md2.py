import difflib, sys
P = "80_인수인계_프로젝트완료 및 유지보수용/"
for a, b in [("11_일적재pipeline 구성/00_개요_및_실행순서.md", P + "06_일배치_모니터링/11_일적재pipeline 구성/00_개요_및_실행순서.md"),
             ("12_agent개선과제/18_O217_운영계_재현_런북.md", P + "07_운영런북_이슈/12_agent개선과제/18_O217_운영계_재현_런북.md")]:
    x = open(a, encoding="utf-8").read().split("\n"); y = open(b, encoding="utf-8").read().split("\n")
    print("==", a)
    for l in difflib.unified_diff(x, y, n=0, lineterm=""):
        if l[:1] in "+-" and l[:3] not in ("+++", "---"):
            print(l[:260])
