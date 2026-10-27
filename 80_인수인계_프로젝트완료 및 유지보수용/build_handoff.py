#!/usr/bin/env python3
"""인수인계 패키지 빌더.

워크스페이스 원천을 볼 수 없는 Snowflake 유지보수 담당자에게 넘길 파일을
이 폴더(80_인수인계_프로젝트완료 및 유지보수용) 아래 서브폴더로 복사하고
00_README.md / 00_INDEX.csv 를 생성한다. 원본은 읽기만 한다.

사용법 (워크스페이스 루트 기준):
  python3 "80_인수인계_프로젝트완료 및 유지보수용/build_handoff.py"           # dry-run (목록만)
  python3 "80_인수인계_프로젝트완료 및 유지보수용/build_handoff.py" --apply   # 실제 복사 + README/INDEX 생성

대상 추가/제외는 아래 MANIFEST 만 수정한다.
"""
import argparse
import csv
import fnmatch
import re
import shutil
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parent

# 공통 제외 (경로 세그먼트 또는 파일명 glob)
EXCLUDE = ["_archive", "__pycache__", "*.pyc", "target", "logs", ".user.yml",
           "profiles.yml", ".DS_Store",
           # 🆕 [2026-10-27] 계정별 원시 캡처 csv(30_output_share/_ENV · 290여 개) — 재구축에 불필요한 증거.
           #   판정 결과는 12_운영계_실측_<계정>.md 에 들어 있고, 원본은 워크스페이스 원천에 남는다.
           "_ENV"]

# (서브폴더, 원본 경로 또는 glob(ROOT 기준), 설명)
# 디렉터리를 지정하면 하위 전체를 원래 구조대로 복사한다.
MANIFEST = [
    # 01 — 실행순서 문서 + 문서에 명시된 SQL 은 extract_run_order_sql() 로 자동 추가
    ("01_실행순서_배포SQL", "문서실행순서.md", "개발계·운영계 배포 실행순서 (정본)"),
    ("01_실행순서_배포SQL", "문서실행순서_llm실행.md", "🆕 O250-D 실행순서를 LLM 이 집행할 때의 방법·병렬화·예외·금지 사항"),
    ("01_실행순서_배포SQL", "문서실행순서_보조주석.md", "🆕 O250-D 실행순서 단계별 상세 주석·덧입히기 절차(문서실행순서.md 가 참조)"),
    ("01_실행순서_배포SQL", "12_agent개선과제/output/O217_biz_definition_corpus.csv",
     "26_ SQL 이 읽는 BIZ_DEFINITION 코퍼스 (실행순서 원래 경로 유지)"),
    ("01_실행순서_배포SQL", "05_SV-Agent_ai/00_SV_공통지시문.md",
     "🆕 O262 SV 공통 지시문 블록 정본(R-SV1~3) — sv_common_block_gate 가 SV 폴더에서 읽는다"),

    ("02_dbt_pipeline", "10_dbt_pipeline", "dbt 프로젝트 (models·macros·snapshots·tests·배포 SQL·운영 문서)"),

    ("03_MSTR_이관", "15_MSTR 이관 PoC", "MSTR 리포트 이관 PoC: 원본 DDL·Snowflake 적용 DDL·검증·tools"),

    ("04_SV_Agent_스펙", "cortex_project/cortex-project.yaml", "Cortex 프로젝트 설정"),
    ("04_SV_Agent_스펙", "cortex_project/agents", "09_2_AGENT_버전업.sql 이 읽는 Agent 정본 YAML 스펙"),
    ("04_SV_Agent_스펙", "tmp/o249/agent_deploy.py", "🆕 O249 Agent 1종씩 버전업 스크립트(spec 스테이지 복사 → 크기 대조 → ADD VERSION · 환경변수 AG)"),
    ("04_SV_Agent_스펙", "tmp/o250/deploy_agents.py", "🆕 O250 09_2 절차 집행기(pre = [0]·[0-B]·[0-C]·[1] · deploy = [2]·[3]·[5])"),
    ("04_SV_Agent_스펙", "tmp/o250/ca_check.py", "🆕 O250 7축 SV 확인 — Cortex Analyst 생성 SQL ↔ 직접 SQL 값 대조(GN_DW_ANALYST)"),

    ("05_RAG_지표사전", "12_agent개선과제/output/O217_biz_definition_corpus.csv",
     "RAG(Cortex Search SEARCH_BIZ_DEFINITION) 지표사전 코퍼스 CSV"),
    ("05_RAG_지표사전", "12_agent개선과제/tools/build_biz_definition_corpus.py", "코퍼스 CSV 재생성 스크립트"),
    ("05_RAG_지표사전", "12_agent개선과제/tools/O217_routing_curated.csv", "코퍼스 생성용 라우팅 큐레이션"),
    ("05_RAG_지표사전", "90_provided_definition/00_README.md", "현업 제공 정의 자료 안내"),
    ("05_RAG_지표사전", "90_provided_definition/0[1-7]_*", "지표사전·용어사전·보고서필드 인벤토리 원본"),
    ("05_RAG_지표사전", "90_provided_definition/*.csv", "지표·컬럼·테이블 정의, 조직도 등 원본 CSV"),

    ("06_일배치_모니터링", "11_일적재pipeline 구성", "일배치 TASK 스케줄·LOADER 권한"),
    ("06_일배치_모니터링", "08_mornitoring", "AI/웨어하우스 비용가드·알림·OPS 객체"),

    ("07_운영런북_이슈", "02_GN_DW_building/05_ARCHITECTURE.md", "아키텍처"),
    ("07_운영런북_이슈", "02_GN_DW_building/06_RUNBOOK.md", "운영 런북"),
    ("07_운영런북_이슈", "02_GN_DW_building/09_user login mfa리셋.sql", "사용자 MFA 리셋"),
    ("07_운영런북_이슈", "12_agent개선과제/18_O217_운영계_재현_런북.md", "기존 계정 덧입힘 런북(백업·diff·롤백)"),
    ("07_운영런북_이슈", "12_agent개선과제/18_O217_운영계_재현_검증.sql", "운영계 재현 검증 SQL"),
    ("07_운영런북_이슈", "PAID_재현_런북_*.md", "PAID 재현 런북"),
    ("07_운영런북_이슈", "20_issue/00_INDEX_이슈원장.md", "이슈 원장"),
    ("07_운영런북_이슈", "20_issue/00_INDEX_이슈원장_조각", "이슈 원장 (분할 조각)"),
    ("07_운영런북_이슈", "20_issue/50_dbt_파이프라인_미결조치.md", "dbt 파이프라인 미결 조치"),
    ("07_운영런북_이슈", "20_issue/50_dbt_파이프라인_미결조치_조각", "dbt 미결 조치 (분할 조각)"),
    ("07_운영런북_이슈", "20_issue/91_사고사례집.md", "사고 사례집"),
    ("07_운영런북_이슈", "20_issue/92_실측필요_후속작업.md", "실측 필요 후속작업"),

    ("08_현업공유_산출물", "30_output_share", "현업 공유 산출물 (활용가이드·인벤토리·계보·매핑)"),

    ("09_설계근거_참고", "05_SV-Agent_ai/08_AGENT_spec.md", "Agent 스펙 설계"),
    ("09_설계근거_참고", "05_SV-Agent_ai/09_0_AGENT_정의서.md", "Agent 정의서"),
    ("09_설계근거_참고", "05_SV-Agent_ai/11_거버넌스_운영.md", "SV/Agent 거버넌스 운영"),
    ("09_설계근거_참고", "05_SV-Agent_ai/AGENT_*.xlsx", "Agent 연결객체 메타데이터·원천계보"),
    ("09_설계근거_참고", "06_snapshot", "스냅샷 아키텍처·네이밍룰·구축 SQL"),
    ("09_설계근거_참고", "09_streamlit 권한 설정", "Streamlit 셀프서비스 권한"),
    ("09_설계근거_참고", "SECURITY.sql", "Git 자격증명 시크릿 갱신"),

    # 🆕 [O262] 운영 점검 도구 — 원본 이식성 수정(자기 폴더 기준 · sfconn 2경로) 후 편입. .py 는 hook 정제 대상이 아니다
    #   ⇒ 원본에 계정 값 0 을 편입 조건으로 한다(scrub_acct.ACC 스캔 · 재빌드 후 80 전체 재확인).
    ("10_운영도구_scripts", "scripts/README_운영도구.md", "접속·실행 순서·rc 0/1/2 의미"),
    ("10_운영도구_scripts", "scripts/sfconn.py", "접속 헬퍼(토큰 OAuth · 없으면 connections.toml · GN_DW_ROLE/GN_DW_WAREHOUSE)"),
    ("10_운영도구_scripts", "scripts/run_sql_file.py", "SQL 파일 문장 단위 실행기(첫 실패에서 멈춤)"),
    ("10_운영도구_scripts", "scripts/sv_enum_newvalue_gate.py", "SV COMMENT 열거 목록 밖 라이브 신규값 · 종수 표기 잔존 검사(라이브)"),
    ("10_운영도구_scripts", "scripts/sv_code_label_gate.py", "SV 코드↔라벨 표기 검사(라이브)"),
    ("10_운영도구_scripts", "scripts/sv_no_rollup_gate.py", "SV 지시문·VQR 소계/합계 행 유도 검사(소스)"),
    ("10_운영도구_scripts", "scripts/sv_common_block_gate.py", "SV 공통 지시문 블록 규칙 R-SV1~3 검사(소스+라이브)"),
]

SUBFOLDER_DESC = {
    "01_실행순서_배포SQL": "문서실행순서.md 와 그 안의 SQL (원래 경로 유지 → 문서 경로 그대로 사용 가능)",
    "02_dbt_pipeline": "dbt 프로젝트 원본",
    "03_MSTR_이관": "MSTR 이관 PoC 전체",
    "04_SV_Agent_스펙": "Agent YAML 정본 (09_2 배포 필수)",
    "05_RAG_지표사전": "RAG 코퍼스 CSV · 원본 정의 · 재생성 도구",
    "06_일배치_모니터링": "일배치 TASK · 비용/알림 모니터링",
    "07_운영런북_이슈": "런북 · 이슈 원장 · 사고사례",
    "08_현업공유_산출물": "현업 공유 산출물",
    "09_설계근거_참고": "설계 근거 · 보안/권한 참고",
    "10_운영도구_scripts": "운영 점검 도구(SV 게이트 · SQL 실행기 · 접속 헬퍼) — README_운영도구.md 부터",
}

READ_ORDER = [
    "00_README.md → 00_INDEX.csv 로 전체 파악",
    "07_운영런북_이슈/02_GN_DW_building/05_ARCHITECTURE.md, 06_RUNBOOK.md",
    "01_실행순서_배포SQL/문서실행순서.md (배포/재구축 순서)",
    "06_일배치_모니터링 (일상 운영)",
    "07_운영런북_이슈/20_issue (미결 이슈)",
    "02~05 (수정 시 대상별 원본)",
]


# O256 빌드 훅 — 80 사본에만 적용하는 정제(원본은 개발 이력을 유지한다).
#   .sql = clean80(서명·표식·계정 값 · 주석만 · 코드 동일 assert) · `mstr DDL 원본/` 제외
#   .yml = `#` 주석의 계정 값만 · .md/.csv/.html/.txt = scrub254 규칙(비운영 계정 · init_ihcho)
# 운영계(ZL50263) 값은 남긴다. 도구 정본 = 95_작업기록_인수인계정제/tools/.
HOOK_TOOLS = ROOT / "95_작업기록_인수인계정제" / "tools"
HEADER_KEY = re.compile(r"(?m)^-- (Purpose|Target|Run order|Depends on|Issue)\s*: ")


def hook(rel80: str, data: bytes) -> bytes:
    sys.path.insert(0, str(HOOK_TOOLS))
    import clean80, clean80b, scrub254 as S
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return data
    low = rel80.lower()
    if low.endswith(".sql"):
        if any(k in rel80 for k in clean80.SKIP):
            return data
        new = clean80.clean(text)[0]
        assert clean80.strip_comments(new) == clean80.strip_comments(text), rel80
        # clean80 이 연속 공백을 접어 O256 표준 헤더의 키 정렬이 깨진다 ⇒ 헤더 7줄만 정렬을 복원한다.
        head, sep, rest = new.partition("\n" + "-- " + "=" * 77 + "\n")
        if head.startswith("-- " + "=" * 77) and sep:
            head = HEADER_KEY.sub(lambda m: f"-- {m.group(1):<11}: ", head)
            new = head + sep + rest
    elif low.endswith((".yml", ".yaml")):
        new = clean80b.clean_yml(text)
        assert clean80b.strip_yml(new) == clean80b.strip_yml(text), rel80
    elif low.endswith(S.TEXT):
        new = S.scrub2(S.PRE.sub("", text))
        for f, old, rep, _ in S.EXACT:
            if f == f"{OUT.name}/{rel80}":
                new = new.replace(old, rep)
        new = "\n".join(l for l in new.split("\n") if not any(d.search(l) for d in S.DROP))
        # EXACT 표가 만들어진 뒤 생긴 언급(예: O254 원장 행)도 80 에는 남기지 않는다.
        new = S.IH.sub("세션 초기화 스킬", new)
    else:
        return data
    return new.encode("utf-8")


def excluded(rel: Path) -> bool:
    return any(fnmatch.fnmatch(p, pat) for p in rel.parts for pat in EXCLUDE)


# 문서실행순서.md 중 인수인계에 넣을 절(「# 」 제목). 그 밖의 절(예: 개발계 · 50_handoff 데이터 이관)은 사본에서 뺀다.
# 2026-10-20 사용자 결정(O247): 인수인계 문서에는 운영계 순서만 남긴다. 절을 추가하면 여기에 제목을 더한다.
RUN_ORDER_DOC = "문서실행순서.md"
RUN_ORDER_SKIP_SECTIONS = ["개발계"]
# 번호 줄: "12. /경로.sql" · "16. 🆕 [O245] /경로.sql — 설명" 처럼 번호와 경로 사이에 '/' 없는 표기가 와도 잡는다.
RUN_ORDER_LINE = re.compile(r"^\s*\d+\.\s*[^/\n]*?/(\S.*?\.sql)")


def run_order_text():
    """인수인계 대상 절만 남긴 문서실행순서 본문 — 첫 「# 」 제목 앞 머리말은 유지한다."""
    out, keep = [], True
    for line in (ROOT / RUN_ORDER_DOC).read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            keep = line[2:].strip() not in RUN_ORDER_SKIP_SECTIONS
        if keep:
            out.append(line)
    return "\n".join(out) + "\n"


def extract_run_order_sql():
    paths, unmatched = set(), []
    for line in run_order_text().splitlines():
        m = RUN_ORDER_LINE.match(line)
        if m:
            paths.add(m.group(1).strip())
        elif re.match(r"^\s*\d+\.", line) and ".sql" in line:
            unmatched.append(line.strip()[:120])
    for u in unmatched:  # 경로가 줄 안에 '/…sql' 형태로 없는 번호 줄 — 다른 줄에서 이미 잡혔는지 사람이 확인한다
        print(f"[WARN] 실행순서 번호 줄에서 경로를 못 읽음: {u}")
    return [("01_실행순서_배포SQL", p, "문서실행순서.md 명시 SQL") for p in sorted(paths)]


def expand(pattern: str):
    """pattern → [(원본 절대경로, ROOT 기준 상대경로)]"""
    hits = sorted(ROOT.glob(pattern)) if any(c in pattern for c in "*?[") else [ROOT / pattern]
    files = []
    for h in hits:
        if not h.exists():
            continue
        if h.is_dir():
            for f in sorted(h.rglob("*")):
                rel = f.relative_to(ROOT)
                if f.is_file() and not excluded(rel):
                    files.append((f, rel))
        else:
            rel = h.relative_to(ROOT)
            if not excluded(rel):
                files.append((h, rel))
    return files


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="실제 복사 및 README/INDEX 생성")
    args = ap.parse_args()

    entries = MANIFEST[:1] + extract_run_order_sql() + MANIFEST[1:]
    rows, missing, seen = [], [], set()
    for sub, pat, desc in entries:
        files = expand(pat)
        if not files:
            missing.append(pat)
            continue
        for src, rel in files:
            key = (sub, rel)
            if key in seen:
                continue
            seen.add(key)
            rows.append({"서브폴더": sub, "파일경로": str(rel), "파일명": rel.name,
                         "설명": desc, "원본경로": str(rel), "크기(byte)": src.stat().st_size,
                         "_src": src})

    for r in rows:
        print(f"[{'COPY' if args.apply else 'PLAN'}] {r['서브폴더']}/{r['파일경로']}")
        # 문서실행순서.md 는 원본을 그대로 쓰지 않고 인수인계 대상 절만 남긴 본문을 쓴다(RUN_ORDER_SKIP_SECTIONS).
        body = run_order_text().encode("utf-8") if r["파일경로"] == RUN_ORDER_DOC else None
        if body is not None:
            r["크기(byte)"] = len(body)
        if args.apply:
            dst = OUT / r["서브폴더"] / r["파일경로"]
            dst.parent.mkdir(parents=True, exist_ok=True)
            data = hook(f"{r['서브폴더']}/{r['파일경로']}", body if body is not None else r["_src"].read_bytes())
            r["크기(byte)"] = len(data)
            if dst.exists():
                if dst.stat().st_size == len(data) and dst.read_bytes() == data:
                    continue  # 동일 파일 — 재실행 시 재개(stage 마운트 쓰기가 느림)
                print(f"  overwrite: {dst.relative_to(OUT)}")
            dst.write_bytes(data)

    if args.apply:
        write_index(rows)
        write_readme(rows)

    print(f"\n파일 {len(rows)}개 / MISSING {len(missing)}개")
    for m in missing:
        print(f"[MISSING] {m}")
    return 1 if missing else 0


def write_index(rows):
    cols = ["서브폴더", "파일경로", "파일명", "설명", "원본경로", "크기(byte)"]
    with open(OUT / "00_INDEX.csv", "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def write_readme(rows):
    L = ["# 인수인계 — 프로젝트 완료 및 유지보수용", "",
         "워크스페이스 원천 없이 이 폴더만으로 GN_DW(Snowflake) 를 재구축·운영할 수 있도록 구성했다.",
         "전체 파일 목록 = `00_INDEX.csv`. 재생성 = `build_handoff.py --apply`.",
         "SQL 파일 머리 = 표준 헤더(Purpose · Target · Run order · Depends on · Issue). "
         "사본은 빌드 때 주석만 정제한다(실행 코드는 원본과 같다).", "",
         "## 읽는 순서", ""]
    L += [f"{i}. {s}" for i, s in enumerate(READ_ORDER, 1)]
    L += ["", "## 인수인계 대상", "", "| 서브폴더 | 내용 | 파일 수 |", "|---|---|---|"]
    for sub, d in SUBFOLDER_DESC.items():
        L.append(f"| {sub} | {d} | {sum(r['서브폴더'] == sub for r in rows)} |")
    L += ["", "## 권장 추가 사유 (지정 대상 외)", "",
          "- 04 Agent YAML: 09_2_AGENT_버전업.sql 이 읽는 정본 — 없으면 Agent 배포 불가",
          "- 05 지표사전 원본·재생성 도구: 정의 변경 시 코퍼스 CSV 재생성 필요",
          "- 06 일배치·모니터링: 일상 운영의 주 대상(TASK·비용가드·알림)",
          "- 07 런북·이슈: 장애 대응·미결 이슈 맥락",
          "- 09 설계근거·보안: 변경 판단 근거, Streamlit 권한, Git 시크릿 갱신",
          "", "## 파일 목록 (서브폴더별)"]
    for sub in SUBFOLDER_DESC:
        L += ["", f"### {sub}", "", "| 파일 | 설명 |", "|---|---|"]
        L += [f"| {r['파일경로']} | {r['설명']} |" for r in rows if r["서브폴더"] == sub]
    (OUT / "00_README.md").write_text("\n".join(L) + "\n", encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
