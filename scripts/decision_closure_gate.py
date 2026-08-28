# 결정(DEC) 이 닫은 이슈 ID 를 인용하는 문서를 전수 검색해 「미봉합 인용처」를 경고한다.
# Co-authored with CoCo
#
# 배경 (2026-08-20 O92-B 자기검토 확정위반 ②):
#   `DEC-41` 로 `O8` 의 후원사업 축을 닫았는데, 그 결정을 **선행조건으로 인용한 정본 5곳**이
#   여전히 「미결」로 남아 있었다. 결정 문서만 쓰고 끝내면 원장 전체가 조용히 stale 이 된다.
#   🔴 기존 게이트에는 이 축이 아예 없었다 — 제목·행키·조문순서·용량 게이트는 전부 통과했다.
#
# 판정 방식:
#   ① `30_설계_의사결정-*.md` 의 `## N. … DEC-nn` 절을 훑어 **종결 선언 줄**을 찾는다
#      (종결|닫힌|닫혔|해소 가 있는 줄).
#   ② 그 줄에서 이슈 라벨(`O8`·`Q10`·`B2`·`G-5` 등)을 뽑는다 = 「이 결정이 닫은 대상」.
#   ③ `20_issue/` 전 문서에서 그 라벨을 인용하는 줄을 전수 검색한다.
#   ④ 그 줄이 **해당 `DEC` 라벨도 함께 언급**하면 봉합된 것으로 본다. 아니면 미봉합으로 보고한다.
#
# 🟠 등급 = 경고 전용(사용자 결정 2026-08-20). 종료 코드는 항상 0 이다.
#   근거 = **의도적으로 열린 인용처가 정상인 경우가 있다.** 실증: `O8` 의 본체는 캠페인 귀속이고
#   `DEC-41` 은 후원사업 축만 닫았으므로 캠페인 인용처의 「미결」 표기는 **옳다**.
#   ⇒ blocking 으로 만들면 정당한 상태를 억지로 닫게 만든다(`P103-⑤` 「항상 빨간 게이트는 무시된다」).
#
# 🔴 이 게이트는 「닫아라」가 아니라 「**보고 판단했는가**」를 묻는다. 목록을 읽고 각 인용처마다
#   ㉠ 병기해 닫는다 ㉡ 열린 이유를 그 자리에 적는다 — 둘 중 하나를 해야 한다. 무시는 답이 아니다.

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ISSUE = ROOT / "20_issue"

# 🔴🔴 [2026-08-28 O107-D] **분모를 형제 파일명에 의존시키지 않는다.**
#   종전 = `DECISION_GLOB = "30_설계_의사결정-*.md"` + `ISSUE.glob("*.md")` 두 곳이
#   **조각이 허브와 같은 폴더에 있다**는 전제를 갖고 있었다. 조각을 `--to-outdir` 로
#   폴더로 옮기면(`R1-6-21`) ㉠ 결정 정의 분모가 **0건**이 되고(실측: 현재 12건 → 0건)
#   ㉡ 인용처 분모에서 **폴더 조각 전량이 빠진다**(1단계 glob) ⇒ 게이트가 **조용히 통과**한다.
#   그것이 `P106`(분모가 좁은 게이트)의 정확한 재현이고, 이 게이트는 blocking 이 아니라
#   **경고 전용**이라 아무도 알아채지 못한다 — 가장 나쁜 조합이다.
# ⇒ **허브 폴더까지 1단계 하위를 함께 본다.** 형제·폴더 어느 배치에서도 같은 분모가 된다.
DECISION_STEM = "30_설계_의사결정"
DECISION_GLOB = DECISION_STEM + "-*.md"          # (호환 표기 · 실제 수집은 아래 함수가 한다)


def _md_files(stem_filter=None):
    """`20_issue/` 직속 + **1단계 하위 폴더**의 `.md` 를 모은다(정렬 · 중복 제거).

    🔴 `_archive`·`__pycache__` 는 제외한다. 하위 폴더를 보는 이유 = 조각 폴더
      (`*_조각/`)가 분모에서 빠지면 이 게이트가 **침묵**한다(위 주석 참조).
    """
    out = []
    for p in sorted(ISSUE.glob("*.md")):
        out.append(p)
    for d in sorted(x for x in ISSUE.iterdir() if x.is_dir()):
        if d.name in ("_archive", "__pycache__", "logs", "target"):
            continue
        out.extend(sorted(d.glob("*.md")))
    seen, uniq = set(), []
    for p in out:
        if p.resolve() in seen:
            continue
        seen.add(p.resolve())
        if stem_filter is None or p.name.startswith(stem_filter):
            uniq.append(p)
    return uniq

# 종결을 선언하는 어휘. 「닫지 않는다」 같은 부정문은 아래 NEGATIVE 로 걸러낸다.
CLOSE_WORDS = re.compile(r"종결|닫힌다|닫혔|닫았|해소")
NEGATIVE = re.compile(r"닫지\s*않|종결이\s*아니|해소가\s*아니|닫는\s*것은\s*아니")

# 이슈 라벨 = 이 워크스페이스의 실제 표기 체계.
#   O8 / O91  · Q10 · B2 · G-5 · E-6 · DEC-40
#   🔴 `O8` 이 `O85` 에 걸리지 않도록 뒤 숫자를 배제한다.
ISSUE_LABEL = re.compile(r"\b(?:O\d{1,3}|Q\d{1,3}|B[1-9]|[A-Z]-\d{1,2})(?!\d)")

# 인용처 검색에서 제외하는 문서.
#   · 01_세션이력  = append-only 과거 기록이므로 소급 갱신 대상이 아니다(R1-3-6).
#   · 30_설계_의사결정 = 결정 정본 자신.
EXCLUDE_PREFIX = ("01_세션이력", "30_설계_의사결정")

MAX_SHOW_PER_ID = 6


def decision_sections():
    """(dec_label, 절 제목, [본문 줄]) 을 산출한다."""
    out = []
    for path in _md_files(DECISION_STEM + "-"):
        lines = path.read_text(encoding="utf-8").split("\n")
        cur_head = None
        cur_dec = None
        body = []
        for line in lines:
            if line.startswith("## "):
                if cur_dec:
                    out.append((cur_dec, cur_head, body, path.name))
                m = re.search(r"DEC-?(\d+)", line)
                cur_dec = f"DEC-{m.group(1)}" if m else None
                cur_head = line[3:].strip()
                body = []
            else:
                body.append(line)
        if cur_dec:
            out.append((cur_dec, cur_head, body, path.name))
    return out


def closed_targets(body):
    """종결 선언 줄에서 이 결정이 닫은 이슈 라벨을 뽑는다."""
    found = {}
    for line in body:
        if not CLOSE_WORDS.search(line):
            continue
        if NEGATIVE.search(line):
            continue
        for label in ISSUE_LABEL.findall(line):
            # 결정 자신·세션 라벨은 대상이 아니다.
            if label.startswith("DEC"):
                continue
            found.setdefault(label, line.strip())
    return found


def citations(label):
    """20_issue/ 에서 그 라벨을 인용하는 (파일, 행번호, 줄) 을 전수 수집한다."""
    pat = re.compile(r"\b" + re.escape(label) + r"(?!\d)")
    hits = []
    for path in _md_files():
        if path.name.startswith(EXCLUDE_PREFIX):
            continue
        try:
            lines = path.read_text(encoding="utf-8").split("\n")
        except Exception:
            continue
        for i, line in enumerate(lines, 1):
            if pat.search(line):
                hits.append((path.name, i, line))
    return hits


def main():
    secs = decision_sections()
    if not secs:
        print("[결정 봉합 게이트] 🔴 결정 절을 찾지 못했다 — 경로·패턴을 확인하라.")
        return 0

    print(f"[결정 봉합 게이트] 결정 절 {len(secs)}개 스캔 · 인용처 분모 = 20_issue/*.md")
    print(f"  제외 = {', '.join(EXCLUDE_PREFIX)} (append-only 이력 · 결정 정본 자신)")

    total_open = 0
    reported = 0
    for dec, head, body, src in secs:
        targets = closed_targets(body)
        if not targets:
            continue
        for label in sorted(targets):
            hits = citations(label)
            if not hits:
                continue
            unsealed = [h for h in hits if dec not in h[2]]
            sealed = len(hits) - len(unsealed)
            if not unsealed:
                print(f"  🟢 {dec} ▸ {label}: 인용처 {len(hits)}건 전건 봉합")
                continue
            # 🔴 신호 분리(O92-B 실측): 첫 실행에서 미봉합 26건이 나왔는데 대부분이 **서술문**이었다.
            #   상태 stale 은 거의 전부 **표 행**에 있다(원장 §1·§2·미결조치 표) ⇒ 표 행을 우선 버킷으로,
            #   서술문은 참고 버킷으로 분리한다. 분리하지 않으면 조치 대상이 서술문에 묻힌다.
            rows = [h for h in unsealed if h[2].lstrip().startswith("|")]
            prose = [h for h in unsealed if not h[2].lstrip().startswith("|")]
            total_open += len(rows)
            reported += 1
            print(f"  🟠 {dec} ▸ {label}: 인용처 {len(hits)}건 · 봉합 {sealed} · "
                  f"**미봉합 표행 {len(rows)}** · 서술문 {len(prose)}(참고)")
            print(f"       종결 선언 = {targets[label][:110]}")
            for name, ln, line in rows[:MAX_SHOW_PER_ID]:
                print(f"       🟠 {name}:{ln}  {line.strip()[:96]}")
            if len(rows) > MAX_SHOW_PER_ID:
                print(f"       🟠 … 외 {len(rows) - MAX_SHOW_PER_ID}건")
            for name, ln, line in prose[:2]:
                print(f"       ⚪ {name}:{ln}  {line.strip()[:88]}")
            if len(prose) > 2:
                print(f"       ⚪ … 외 {len(prose) - 2}건(서술문 · 조치 대상 아닐 수 있다)")

    print()
    if total_open == 0:
        print("🟢 미봉합 인용처 0건")
    else:
        print(f"🟠 미봉합 인용처 {total_open}건 · 대상 {reported}종 (경고 — blocking 아님)")
        print(" - 각 인용처마다 ㉠ 병기해 닫거나 ㉡ 열린 이유를 그 자리에 적어라.")
        print(" - 🔴 「의도적으로 열린 것」이면 그 사실을 인용처에 쓰면 이 경고가 근거를 갖는다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
