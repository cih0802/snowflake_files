#!/usr/bin/env python3
# 세션 트랜스크립트에서 실행 SQL·수정 파일·판정 문구를 추출해 자기검토 근거로 요약한다.
# Co-authored with CoCo
"""O145 자기검토용 트랜스크립트 추출기.

용도: `cortex conversations transcript --output=json <id>` 산출물에서
  ㉠ 실행한 SQL 문
  ㉡ 쓰기/수정한 파일 경로
  ㉢ bash 로 돌린 스크립트·게이트
  ㉣ 내가 발행한 「판정」 문구 후보
를 뽑아 사람이 검토할 수 있는 형태로 출력한다.

🔴 이 도구는 판정하지 않는다 — 판정 재료만 모은다(`R1-3-7-c` 근거 선행 기록).
"""
import json
import re
import sys
from pathlib import Path


def walk(node, out):
    """중첩 구조를 훑어 dict 를 전부 수집한다."""
    if isinstance(node, dict):
        out.append(node)
        for v in node.values():
            walk(v, out)
    elif isinstance(node, list):
        for v in node:
            walk(v, out)


def main(argv):
    if len(argv) < 2:
        print("사용법: python3 scripts/o145_transcript_audit.py <transcript.json>")
        return 2
    path = Path(argv[1])
    if not path.exists():
        print(f"🔴 파일 없음: {path}")
        return 2

    raw = path.read_text(encoding="utf-8", errors="replace")
    # 🔴 실측: `cortex conversations transcript --output=json` 은 JSON 배열이 아니라
    #    **JSONL**(줄마다 독립 JSON)을 낸다. 단일 json.loads 는 "Extra data" 로 실패한다.
    #    ⇒ 두 형태를 모두 받는다(단일 문서 → 실패 시 줄 단위).
    docs = []
    try:
        docs.append(json.loads(raw))
    except json.JSONDecodeError:
        bad = 0
        for line in raw.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                docs.append(json.loads(line))
            except json.JSONDecodeError:
                bad += 1
        if not docs:
            print("🔴 JSON/JSONL 둘 다 파싱 실패")
            return 2
        if bad:
            print(f"⚠️ 파싱 실패 줄 {bad}건 (건너뜀)")

    nodes = []
    for doc in docs:
        walk(doc, nodes)

    sqls = []
    files_written = []
    bash_cmds = []

    for nd in nodes:
        # 도구 입력은 name/input 또는 tool_name/parameters 형태로 온다.
        name = nd.get("name") or nd.get("tool_name") or ""
        inp = nd.get("input") or nd.get("parameters") or nd.get("arguments")
        if isinstance(inp, str):
            try:
                inp = json.loads(inp)
            except json.JSONDecodeError:
                inp = None
        if not isinstance(inp, dict):
            continue

        if "sql" in inp and isinstance(inp["sql"], str):
            sqls.append(inp["sql"].strip())
        if "command" in inp and isinstance(inp["command"], str):
            bash_cmds.append(inp["command"].strip())
        for key in ("file_path", "python_file_path"):
            if key in inp and isinstance(inp[key], str):
                files_written.append((name or "?", inp[key]))

    def uniq(seq):
        seen = set()
        out = []
        for item in seq:
            if item not in seen:
                seen.add(item)
                out.append(item)
        return out

    sqls = uniq(sqls)
    bash_cmds = uniq(bash_cmds)

    print("=" * 70)
    print(f"트랜스크립트 = {path}  ({len(raw):,} B · 노드 {len(nodes):,})")
    print("=" * 70)

    print(f"\n## 1. 실행 SQL — {len(sqls)}건\n")
    for i, sql in enumerate(sqls, 1):
        one = " ".join(sql.split())
        tgt = sorted(set(re.findall(r"(?:FROM|JOIN|INTO)\s+([A-Z0-9_]+\.[A-Z0-9_]+\.[A-Z0-9_]+)", sql, re.I)))
        print(f"[{i:02d}] {one[:150]}")
        if tgt:
            print(f"     대상: {', '.join(tgt)}")

    print(f"\n## 2. 파일 쓰기/수정 호출 — {len(files_written)}건\n")
    for tool, fp in files_written:
        print(f"  {tool:12s} {fp}")

    print(f"\n## 3. bash 명령 — {len(bash_cmds)}건 (스크립트 호출만 발췌)\n")
    script_pat = re.compile(r"(scripts/[\w.]+\.py|cortex\s+\w+|dbt\s+\w+|rm\b|md5sum)")
    for cmd in bash_cmds:
        hits = sorted(set(m.group(0) for m in script_pat.finditer(cmd)))
        if hits:
            print(f"  {' · '.join(hits)}")

    print("\n## 4. 위험 신호 자동 점검\n")
    joined = "\n".join(bash_cmds)

    # 🔴🔴 [2026-09-08 O144-F 시정] 아래 두 판정식이 **거짓 음성·거짓 양성**을 냈다.
    #   실측 = 이 도구를 세션 87365140(463 msgs) 트랜스크립트에 돌린 결과다.
    #
    # ㉠ heredoc 축(거짓 음성) — 종전 `"<<'EOF'" in joined` 은 **리터럴 `EOF` 만** 봤다.
    #    실제 사용은 `cat > /tmp/probe_main.py <<'PYEOF'` 였고 **1건을 놓쳐 🟢 로 보고**했다.
    #    ⇒ 구분자는 임의 식별자다. `<<` + 인용부호 + 식별자 형태를 정규식으로 본다.
    #    🔴 이것이 `O111 ㉠`(「0건」은 「없다」가 아니라 「판정식이 못 본다」)의 실물이다.
    #
    # ㉡ 파이프 뒤 rc 축(거짓 양성) — 종전 정규식은 파이프와 `$?` 사이에 **무엇이 와도**
    #    잡았다. 실측 5건 중 **2건이 오탐**이었다(`$?` 가 파이프가 아니라 그 뒤의
    #    **리다이렉트 실행** 뒤에 있었다: `... >/tmp/x.out 2>&1; echo "rc=$?"`).
    #    ⇒ 세미콜론 하나 안에서 **파이프로 끝난 직후**의 `$?` 만 위반으로 센다.
    #    🔴 정밀도를 올려도 **재현율을 깎지 않았다** — 실제 위반 3건은 그대로 잡힌다.
    QUOTED_HEREDOC = re.compile(r"<<\s*'[A-Za-z_][A-Za-z0-9_]*'")
    # 파이프로 끝난 세그먼트(다음 `;`·개행 전에 리다이렉트가 없는 것) 뒤의 `$?`
    PIPE_THEN_RC = re.compile(
        r"\|\s*(?:tail|head|grep|wc|sort|uniq)\b[^;\n>]*(?:;|\n)\s*[^;\n]*\$\?")

    checks = [
        ("rm -rf 사용", bool(re.search(r"rm\s+-rf", joined))),
        ("dbt 명령 에이전트 실행(R4-1 위반)",
         bool(re.search(r"\bdbt\s+(parse|compile|build|run|test)\b", joined))),
        ("파이프 뒤 rc 판독(R0-8-2 위반)", bool(PIPE_THEN_RC.search(joined))),
        ("awk length 사용(R1-5-4 금지)", bool(re.search(r"awk[^\n]*length\(", joined))),
        ("python3 -c 로 본문 작성(R1-7-9 위험)", bool(re.search(r"python3\s+-c", joined))),
        ("quoted heredoc 사용(R1-7-9 위험)", bool(QUOTED_HEREDOC.search(joined))),
    ]
    for label, hit in checks:
        print(f"  {'🔴' if hit else '🟢'} {label}: {'발견' if hit else '없음'}")

    # 🟢 [O144-F 신설] 적발 건수와 **실제 명령**을 함께 낸다 — 종전에는 있음/없음만 내서
    #    사람이 「어느 명령이 위반인지」를 따로 찾아야 했고, 그 과정에서 또 파이프 뒤 rc 를
    #    읽는 명령을 쓰게 됐다(실측). 🔴 판정은 여전히 사람이 한다(이 도구는 재료만 낸다).
    print("\n## 4-B. 적발 명령 원문 (판정은 사람이 한다)\n")
    for label, rx in (("파이프 뒤 rc", PIPE_THEN_RC),
                      ("quoted heredoc", QUOTED_HEREDOC),
                      ("rm -rf", re.compile(r"rm\s+-rf"))):
        hits = [c for c in bash_cmds if rx.search(c)]
        print(f"  [{label}] {len(hits)}건")
        for c in hits:
            print("     · " + " ".join(c.split())[:200])

    print(f"\n판정 재료 수집 완료 — SQL {len(sqls)} · 파일 {len(files_written)} · bash {len(bash_cmds)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
