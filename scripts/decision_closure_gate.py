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

# 🆕 🔴🔴 [2026-08-30 O124 신설 · 사용자 승인 「조치 취할 것」] **오탐 34건을 전량 규명해 판정식을 좁혔다.**
#   근거철 = `20_issue/_o124_evidence.md` §E1-1~E1-5 (원문 인용 + 좌표 · `R1-3-7-c`).
#   🔴 착수 시점 상태 = 미봉합 34건 전건이 오탐이었고, 그 결과 이 게이트는 **영구히 🟠** 였다
#     ⇒ `P130` 「항상 빨간 게이트는 무시된다」의 정확한 재현이다. 승계 판정도 「조치 대상 아님」이었다.
#   🔴 그러나 「조치 대상 아님」을 **사람이 매 세션 다시 판정하는 것**은 판정식의 대체물이 아니다.
#     ⇒ 오탐의 **기계적 원인**을 4축으로 분리해 판정에서 뺀다.
#
#   ── 축A. 종결어와 라벨이 **같은 괄호 스코프**에 있어야 한다 (오탐 15건)
#     실측 ㉠ `DEC-42` = `### 7-A. …결정 (2026-08-20 O96) — 연 grain 은 종결 …`
#            ⇒ 「종결」은 괄호 밖 · `O96` 은 괄호 안(**날짜 스탬프 = 세션 라벨**)이다.
#          ㉡ `DEC-43` = `**거짓이었다.** \`DEC42\` 는 **O96 이 이미 사용**한 라벨이다(… 부분 종결 …)`
#            ⇒ 「종결」은 괄호 **안**(다른 대상 `PLAN_BUDGET_YEAR`) · `O96` 은 괄호 **밖**이다.
#     🔴 두 건 다 **닫힌 대상이 아니라 결정을 발행·언급한 세션 라벨**을 대상으로 뽑았다.
#     🟢 대조군 = `DEC-41` 의 `\`O8\`(회원 다중후원 귀속 규칙)의 FMM 축이 닫힌다` 는
#        괄호를 제거해도 `O8` 과 「닫힌다」가 **같은 스코프**에 남는다 ⇒ **그대로 잡힌다**(재현율 보존).
#     ⚠️ **세션 라벨 사전(원장 §1 세션 행)을 쓰려던 초안은 폐기했다** — 실측에서 `O8` 이
#        「`O8` FMM 축 종결」이라는 **세션 행 표제**로 등재돼 있어 사전에 들어갔고,
#        그 사전을 쓰면 **유일한 진성 쌍이 조용히 꺼졌다**. 🔴 사전이 아니라 **문장 구조**로 판정한다.
#
#   ── 축B. 종결 선언은 ㉠ **확정된 결정 절**의 ㉡ **서술문**이어야 한다 (오탐 15건)
#     실측 `DEC-45` 절 제목 = `31. 🔴 결정 대기 — DEC-45: …` ⇒ **아직 확정되지 않았다**(닫은 것이 없다).
#     매칭된 줄은 **선택지 비교표의 표 행**이고 「`O8` … 센티넬 **해소 경로가 열린다**」 =
#     선택지 ② 를 채택하면 생길 **기대 효과**다 ⇒ 종결과 반대 방향이다.
#     🔴 표 행은 「비교·후보 나열」의 자리다 — 종결 선언의 자리가 아니다.
#
#   ── 축C. **적발표**의 행은 인용처가 아니다 (오탐 4건)
#     실측 `02_상태상세_대시보드_갱신형-008.md:127~130` 4행은 「stale 인용처를 적발해 적은 표」이고,
#     **같은 표의 :131 행이 이미 판정을 적어 두었다** —
#     「이 표는 「적발표」이고 stale 정본이 아니다 … 오탐이다. 🔴 **다시 추적하지 마라**」(O112).
#     🔴 문서에 판정을 적었는데 게이트가 계속 찍으면 **문서가 아니라 게이트가 틀린 것**이다.
#     ⇒ 표 블록이 스스로 「적발표 + (stale 정본이 아니다|오탐)」을 선언하면 그 블록 전체를 뺀다.
#
#   ── 축D. **허브 본문**은 인용처가 아니다 (O111 판정의 미완 적용)
#     O111 이 `GENERATED_ID_LINE` 으로 허브 「조각 선택표」의 `- ID:` 줄을 뺐다. 그런데
#     같은 선택표의 **표 행 형태**(`| 조각경로 | 1030~1326 | 297 | 26.5 | §O92 — … |`)는 그 정규식에
#     걸리지 않아 그대로 남았다(실측 `02_상태상세_대시보드_갱신형.md:46`).
#     🔴 근거는 O111 과 **동일**하다 = 허브는 `--republish` 가 통째로 다시 쓰므로
#     「병기해 닫을」 자리가 **원리적으로 없다**(`R3-9 ㉧`).
#     ⚠️ **관측 손실 0** — 허브 본문의 실체는 조각에 있고 조각은 분모에 남는다.
#
#   ── 축E. **세션 근거철**(`_o1NN_evidence.md`)은 인용처가 아니다
#     근거철은 원장 §0 유형 등재표에 **정적**으로 등재된다 — 「발행 후 갱신하지 않는다」가
#     그 문서의 **존재 조건**이다(그 세션의 관측 시점 기록이므로 고치면 근거가 아니게 된다).
#     ⇒ 「병기해 닫을」 자리가 원리적으로 없다(축D 와 같은 논리 · 이유만 다르다).
#     🔴 실측 = O124 가 `_o124_evidence.md` 에 오탐 34건의 **원문을 인용**했더니
#        그 인용 자체가 즉시 「미봉합 인용처 1건」으로 되돌아왔다(자기참조 루프).
#     ⚠️ 관례 의존을 명시한다 — 파일명 접두 `_` + `_evidence` 를 함께 요구한다(넓히지 않는다).
#
#   🔴🔴 **제외분을 버리지 않는다**(`O111 ㉢` 판정축·관측축 분리) — 축별 건수와 이유를
#     `[관측]` 버킷으로 함께 출력한다. 🔴 「0건」을 받으면 이 버킷을 먼저 보라(`O111 ㉠`).

# 괄호 스코프 분해용 — 가장 안쪽 괄호부터 벗겨 낸다(전각·반각 모두).
PAREN_INNER = re.compile(r"[（(]([^（()）]*)[)）]")

# 「아직 확정되지 않은 결정」을 선언하는 절 제목.
#   🔴 `결정\s*전` 은 넣지 않는다 — 「결정 전환」·「결정 전건」에 오탐한다(제외는 좁게 잡는다).
UNDECIDED_HEAD = re.compile(r"결정\s*(?:대기|보류|미확정)")

# 「적발표」 자기선언 — 두 조건을 **모두** 함께 만족해야 한다(단어 하나로 넓히지 않는다).
CATCH_TABLE_NAME = re.compile(r"적발표")
CATCH_TABLE_WHY = re.compile(r"stale\s*정본이\s*아니|오탐")

# 세션 근거철 (축E) — 접두 `_` **그리고** `_evidence` 를 함께 요구한다(관례 의존을 좁게 고정).
EVIDENCE_FILE = re.compile(r"^_.*_evidence\.md$")

# 이슈 라벨 = 이 워크스페이스의 실제 표기 체계.
#   O8 / O91  · Q10 · B2 · G-5 · E-6 · DEC-40
#   🔴 `O8` 이 `O85` 에 걸리지 않도록 뒤 숫자를 배제한다.
ISSUE_LABEL = re.compile(r"\b(?:O\d{1,3}|Q\d{1,3}|B[1-9]|[A-Z]-\d{1,2})(?!\d)")

# 🆕 🔴 [2026-08-28 O111 · 인수 `§0-NNN ▣WWW ⑥` 의 남은 판단] 허브 「조각 선택표」의
#   `- ID: …` 줄은 **인용처가 아니다** — `split_doc.py --republish` 가 매번 통째로
#   다시 쓰는 **자동 생성물**이라 「병기해 닫을」 자리가 원리적으로 없다.
#   🔴 분모에 두면 경고가 **영구히 부풀고 고칠 방법이 없다**(`P130` 「항상 빨간 게이트」 축).
#   🟢 판단 = **제외**. 근거는 이 워크스페이스의 기존 계약과 동일하다
#     — 「허브는 자동 생성물이고 손으로 쓴 문장은 조용히 사라진다」(`R3-9 ㉧`).
#   ⚠️ 이것은 **관측 손실이 아니다** — 같은 ID 의 실제 인용처(표 행·서술문)는 조각에 그대로 있고
#     그쪽이 분모에 남는다(조각 선택표는 그 조각을 가리키는 색인일 뿐이다).
GENERATED_ID_LINE = re.compile(r"^\s*-\s*ID:\s")

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


def paren_scopes(line):
    """줄을 「괄호 밖 잔여」 + 「각 괄호 안」 세그먼트 목록으로 분해한다 (축A).

    🔴 왜 스코프인가 = 종결어와 라벨이 **다른 스코프**에 있으면 그 라벨은 그 종결의
      대상이 아니다. 실측 오탐 2종(`DEC-42`·`DEC-43`)이 정확히 이 형태였다.
    안쪽 괄호부터 반복 제거하며 중첩도 처리한다(상한 6회 = 폭주 방지).
    """
    inner, cur = [], line
    for _ in range(6):
        found = PAREN_INNER.findall(cur)
        if not found:
            break
        inner.extend(found)
        cur = PAREN_INNER.sub(" ", cur)
    return [cur] + inner


def closed_targets(body, head=None, observed=None):
    """종결 선언 줄에서 이 결정이 닫은 이슈 라벨을 뽑는다.

    `head` = 그 결정 절의 제목(축B ㉠ 판정용 · 생략 가능 · 하위호환).
    `observed` = 제외분을 담을 list(축·이유·원문) · `None` 이면 수집하지 않는다.
    """
    found = {}
    # ── 축B ㉠: 아직 확정되지 않은 결정은 아무것도 닫지 않았다.
    if head and UNDECIDED_HEAD.search(head):
        if observed is not None:
            observed.append(("B1", "절이 미확정(`결정 대기/보류/미확정`)이다", head.strip()[:100]))
        return found
    for line in body:
        if not CLOSE_WORDS.search(line):
            continue
        if NEGATIVE.search(line):
            continue
        # ── 축B ㉡: 표 행은 선택지·비교의 자리다 — 종결 선언의 자리가 아니다.
        if line.lstrip().startswith("|"):
            if observed is not None and ISSUE_LABEL.search(line):
                observed.append(("B2", "종결어가 **표 행**에서 매칭됐다(선택지 비교표)", line.strip()[:100]))
            continue
        # ── 축A: 종결어와 라벨이 같은 괄호 스코프에 있어야 한다.
        for seg in paren_scopes(line):
            if not CLOSE_WORDS.search(seg) or NEGATIVE.search(seg):
                continue
            for label in ISSUE_LABEL.findall(seg):
                if label.startswith("DEC"):     # 결정 자신은 대상이 아니다.
                    continue
                found.setdefault(label, line.strip())
        if observed is not None:
            for label in ISSUE_LABEL.findall(line):
                if not label.startswith("DEC") and label not in found:
                    observed.append(("A", "종결어와 **다른 괄호 스코프**에 있다(세션 라벨·다른 대상)",
                                     "%s ◂ %s" % (label, line.strip()[:80])))
    return found


def hub_stems():
    """분할된 문서의 **허브** stem 집합 (축D) — `<stem>_조각/` 이 있으면 `<stem>.md` 는 허브다."""
    out = set()
    try:
        for d in ISSUE.iterdir():
            if d.is_dir() and d.name.endswith("_조각"):
                out.add(d.name[: -len("_조각")])
    except OSError:
        pass
    return out


def catch_table_lines(lines):
    """스스로 「적발표」임을 선언한 표 블록의 **1-based 줄 번호 집합** (축C).

    판정 = 연속된 `|` 줄 블록 안에 「적발표」 **그리고** 「stale 정본이 아니다|오탐」이
      함께 있는 줄이 하나라도 있으면 **그 블록 전체**가 적발표다.
    🔴 단어 하나로 넓히지 않는다 — 넓히면 진짜 stale 표까지 조용히 꺼진다.
    """
    marked = set()
    i, n = 0, len(lines)
    while i < n:
        if lines[i].lstrip().startswith("|"):
            j = i
            while j < n and lines[j].lstrip().startswith("|"):
                j += 1
            block = lines[i:j]
            if any(CATCH_TABLE_NAME.search(b) and CATCH_TABLE_WHY.search(b) for b in block):
                marked.update(range(i + 1, j + 1))
            i = j
        else:
            i += 1
    return marked


def citations(label, observed=None):
    """20_issue/ 에서 그 라벨을 인용하는 (파일, 행번호, 줄) 을 전수 수집한다.

    제외 = `EXCLUDE_PREFIX` · `GENERATED_ID_LINE`(O111) · **허브 본문**(축D) ·
           **적발표 블록**(축C). 제외분은 `observed` 에 축·이유와 함께 담는다.
    """
    pat = re.compile(r"\b" + re.escape(label) + r"(?!\d)")
    hubs = hub_stems()
    hits = []
    for path in _md_files():
        if path.name.startswith(EXCLUDE_PREFIX):
            continue
        try:
            lines = path.read_text(encoding="utf-8").split("\n")
        except Exception:
            continue
        # ── 축E: 세션 근거철은 정적 발행물이다 — 병기할 자리가 없다(자기참조 루프 차단).
        if EVIDENCE_FILE.match(path.name):
            if observed is not None:
                n_hit = sum(1 for line in lines if pat.search(line))
                if n_hit:
                    observed.append(("E", "세션 근거철(정적 발행물 · 발행 후 갱신하지 않는다)",
                                     "%s (%d줄)" % (path.name, n_hit)))
            continue
        # ── 축D: 허브 본문은 자동 생성물이다 — 병기할 자리가 없다.
        if path.stem in hubs:
            if observed is not None:
                for i, line in enumerate(lines, 1):
                    if pat.search(line) and not GENERATED_ID_LINE.match(line):
                        observed.append(("D", "허브 본문(자동 생성물 · `--republish` 가 다시 쓴다)",
                                         "%s:%d" % (path.name, i)))
            continue
        marked = catch_table_lines(lines)
        for i, line in enumerate(lines, 1):
            if GENERATED_ID_LINE.match(line):
                continue
            if not pat.search(line):
                continue
            if i in marked:
                if observed is not None:
                    observed.append(("C", "적발표 블록(그 표가 스스로 「stale 정본이 아니다」를 선언)",
                                     "%s:%d" % (path.name, i)))
                continue
            hits.append((path.name, i, line))
    return hits


def main():
    secs = decision_sections()
    if not secs:
        print("[결정 봉합 게이트] 🔴 결정 절을 찾지 못했다 — 경로·패턴을 확인하라.")
        return 0

    print(f"[결정 봉합 게이트] 결정 절 {len(secs)}개 스캔 · 인용처 분모 = 20_issue/*.md")
    print(f"  제외 = {', '.join(EXCLUDE_PREFIX)} (append-only 이력 · 결정 정본 자신)")
    print("  🆕 [O124] 판정 제외 축 = A 괄호스코프 · B 미확정절/표행 · C 적발표 · D 허브 · E 근거철")

    total_open = 0
    reported = 0
    observed = []                       # 🆕 [O124] 관측 축 — 제외분을 버리지 않는다.
    for dec, head, body, src in secs:
        targets = closed_targets(body, head=head, observed=observed)
        if not targets:
            continue
        for label in sorted(targets):
            hits = citations(label, observed=observed)
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
    # ── 🆕 [2026-08-30 O124] 관측 축 (`O111 ㉢` 판정축·관측축 분리)
    #   🔴 제외한 것을 **버리지 않는다.** 「미봉합 0건」이 판정식이 못 보는 결과일 수 있으므로
    #     이 버킷이 그 반증 자료가 된다(`O111 ㉠` 「0건은 없다가 아닐 수 있다」).
    if observed:
        buckets = {}
        for axis, why, sample in observed:
            buckets.setdefault((axis, why), []).append(sample)
        print("[관측] 판정에서 제외한 것 — 🔴 판정 건수가 아니다(위반으로 인용하지 마라)")
        for (axis, why), samples in sorted(buckets.items()):
            print(f"  ⚪ 축{axis} {len(samples)}건 — {why}")
            for s in samples[:2]:
                print(f"       · {s[:100]}")
            if len(samples) > 2:
                print(f"       · … 외 {len(samples) - 2}건")
        print("  🔴 이 축들의 근거 = `scripts/decision_closure_gate.py` 축A~축E 주석 +")
        print("     `20_issue/_o124_evidence.md` §E1 (원문 인용 + 좌표).")
        print()

    if total_open == 0:
        print("🟢 미봉합 인용처 0건")
        print(" - 🔴 「0건」을 그대로 믿지 마라(`O111 ㉠`) — 위 [관측] 버킷이 제외 축과 건수를 보여 준다.")
    else:
        print(f"🟠 미봉합 인용처 {total_open}건 · 대상 {reported}종 (경고 — blocking 아님)")
        print(" - 각 인용처마다 ㉠ 병기해 닫거나 ㉡ 열린 이유를 그 자리에 적어라.")
        print(" - 🔴 「의도적으로 열린 것」이면 그 사실을 인용처에 쓰면 이 경고가 근거를 갖는다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
