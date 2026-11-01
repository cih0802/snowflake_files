#!/usr/bin/env python3
"""SV DDL 파일에서 **배포 문장만** 추출한다 (2026-08-13 O67).

왜 파일 전체를 실행하지 않는가:
  `05_*_SV_DDL_*.sql` 은 배포문 + GRANT + **스모크 검증 SELECT** 가 한 파일에 있다.
  스모크는 배포 후 판정용이고 실행 순서·웨어하우스가 달라(`GN_DW_ANALYTICS_WH`) 배포와 섞으면
  실패 원인을 가릴 수 있다 ⇒ 배포 단계에서는 **`CREATE OR ALTER SEMANTIC VIEW` + `GRANT` 만** 낸다.
  ⛔ `CREATE OR REPLACE` 로 바꾸지 않는다 — GRANT·소유권을 파괴한다(P125).

🆕 🔴 **[2026-09-21 O175] 다중 SV 파일 대응 — `--name` 을 받는다.**
  종전 구현은 **파일당 첫 SV 만** 뽑았다(행 시작 첫 적중 → 첫 `AI_SQL_GENERATION` 까지).
  그런데 `05_SV-Agent_ai/22_ML_SV_DDL.sql` 은 **SV 7종**을 담고 있어 2번째 이후를 배포할 수 없었다
  (O175 가 `SV_ML_SPONSOR_RISK` 를 배포해야 해서 이 한계에 걸렸다).
  🟢 `--name` 없이 호출하면 **종전 동작(첫 SV)** 그대로다 — 기존 호출부가 깨지지 않는다.

계약:
  · 원본은 읽기만 한다.
  · 추출은 **문자 단위 부분 문자열**이며 문안을 재작성하지 않는다(자동 생성물 손편집 금지 계열).
  · 추출 결과에 `CREATE OR REPLACE` 가 있으면 즉시 실패한다(가드).
  · GRANT 는 **그 SV 것만** 딸려 나간다(`--name` 지정 시).
"""
import re
import sys
from pathlib import Path

HEAD = "USE ROLE GN_DW_ADMIN;\nUSE WAREHOUSE GN_DW_DEV_WH;\nUSE SCHEMA GN_DW.SERVING;\n\n"


def extract(path: Path, sv_name: str | None = None) -> str:
    text = path.read_text(encoding='utf-8')
    # 🔴 [O67 자기적발] `text.index('CREATE OR ALTER SEMANTIC VIEW')` 로 찾으면 **헤더 주석**이 걸린다 —
    #   `05_8` 헤더가 *"`CREATE OR ALTER SEMANTIC VIEW` 로 재배포할 것"* 이라 적고 있어 시작점이 5행으로
    #   잡히고 문장이 잘렸다(가드가 `CREATE OR REPLACE` 를 검출해 배포 전에 멈췄다).
    #   ⇒ **행 시작(anchored)** 으로만 찾는다. 주석은 `--` 로 시작하므로 걸리지 않는다.
    pat = re.compile(r'^CREATE OR ALTER SEMANTIC VIEW\s+(\S+)', re.M)
    m0 = None
    if sv_name is None:
        m0 = pat.search(text)                      # 종전 동작 = 첫 SV
    else:
        for m in pat.finditer(text):               # 🆕 [O175] 이름으로 고른다
            if m.group(1).endswith(sv_name):
                m0 = m
                break
    if not m0:
        want = sv_name or '행 시작 CREATE OR ALTER SEMANTIC VIEW'
        raise SystemExit(f'{path.name}: {want} 를 찾지 못했다')
    start = m0.start()
    # 배포문은 `AI_SQL_GENERATION '...';` 로 끝난다 — 그 종료 세미콜론까지 자른다.
    m = re.compile(r"AI_SQL_GENERATION\s+'", re.S).search(text, start)
    if not m:
        raise SystemExit(f'{path.name}: AI_SQL_GENERATION 절을 찾지 못했다')
    i = m.end()
    # SQL 리터럴 안의 '' 는 이스케이프된 따옴표다 — 홑따옴표 하나가 나올 때가 종료다.
    while True:
        j = text.index("'", i)
        if text[j + 1:j + 2] == "'":
            i = j + 2
            continue
        break
    end = text.index(';', j) + 1
    ddl = text[start:end]
    grants = [ln for ln in text.splitlines() if ln.startswith('GRANT REFERENCES, SELECT ON SEMANTIC VIEW')]
    if sv_name is not None:
        # 🔴 GRANT 행 형태 = `GRANT REFERENCES, SELECT ON SEMANTIC VIEW <FQN> TO ROLE <R>;`
        #   ⇒ `rstrip(';').split()` 에서 FQN 은 **[-4]** 다([-3] 은 `TO` · O175 초판이 여기서 틀려
        #      GRANT 0건을 내고 조용히 통과할 뻔했다).
        grants = [ln for ln in grants if ln.rstrip(';').split()[-4].endswith(sv_name)]
    if 'CREATE OR REPLACE' in ddl:
        raise SystemExit(f'{path.name}: CREATE OR REPLACE 검출 — 배포 중단(P125)')
    return HEAD + ddl + '\n\n' + '\n'.join(grants) + '\n'


def main():
    outdir = Path.home() / 'deploy_o67'
    outdir.mkdir(exist_ok=True)
    args = sys.argv[1:]
    names = []
    if '--name' in args:                            # 🆕 [O175] `--name A --name B` 다중 허용
        rest = []
        k = 0
        while k < len(args):
            if args[k] == '--name':
                if k + 1 >= len(args):
                    raise SystemExit('--name 에 SV 이름이 없다')
                names.append(args[k + 1])
                k += 2
                continue
            rest.append(args[k])
            k += 1
        args = rest
    for arg in args:
        src = Path(arg)
        for sv in (names or [None]):
            body = extract(src, sv)
            stem = (sv or src.stem)
            dst = outdir / (stem + '.deploy.sql')
            dst.write_text(body, encoding='utf-8')
            print(f'{src.name}[{sv or "첫 SV"}]: {len(body)}자 · '
                  f'GRANT {body.count("GRANT REFERENCES")}건 → {dst}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
