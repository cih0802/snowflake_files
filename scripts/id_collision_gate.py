#!/usr/bin/env python3
"""ID 체계 충돌 게이트 (P220 의 집행 장치).

배경 — 왜 스크립트여야 하는가:
  §3-B 가 2026-07-31 에 *"신규 발급 시 grep 최대값 확인"* 을 재발방지로 세웠는데 **문장으로만 있어
  지켜지지 않았고**, 2026-08-12 O61 한 세션에서 `DEC-31`·`P214/P215`·세션라벨 `O60` 이 **3계열 동시**
  충돌했다. 문구는 게이트가 아니다(P105) ⇒ 기계 검사로 승격한다(P220).

판정 원칙 — **정밀도 우선. 실제 사고의 형태만 잡는다.**
  ID 는 문서 곳곳에서 참조되므로 단순 출현수로는 전부 「중복」이 된다.
  🔴 **초판(2026-08-12 O62)이 이 함정에 빠졌다** — 표 행 첫 셀에 ID 가 「포함」되면 정의로 셌더니
  인덱스 대시보드 행(`**D2 구조 처방 + store_failures(내부)**`)까지 `D-2` 정의로 오인해
  **오탐 60건**이 나왔다. 오탐은 게이트를 무력화한다(O59-D 선례) ⇒ 규칙을 아래 3중으로 좁혔다.

  1) **정확 일치** — 표 행 정의는 첫 셀의 **볼드 텍스트가 ID 그 자체**일 때만 인정한다.
     `**DEC-36**` ✅ / `**D2 구조 처방 …**` ❌ / `**3 해소 · 신설 1**` ❌
  2) **인덱스 제외** — `00_INDEX_이슈원장.md` 는 doc_role 이 *"전체 크로스워크"* 다.
     즉 그 문서의 ID 등장은 **참조**이지 정의가 아니다. 정의는 10·20·30·40·50·90 에 있다.
  3) **동일 문서 내 중복만 충돌** — 실제 사고가 정확히 이 형태였다.
     `DEC-31` 은 `30_설계_의사결정.md` **한 파일의 §21 과 §22** 에 중복 부여됐다.
     서로 다른 문서에 같은 ID 가 **참조**되는 것은 정상적인 크로스워크다(인덱스↔정본, 진단↔설계).

🔴 **[2026-08-12 O64 신설] 문서 간 「정의」 중복 축을 추가했다 — 위 3)이 사각을 만들었다.**
  O63 자기검토 2회차가 `P223` **정의문을 문서50·문서10 두 곳에** 남겼는데 이 게이트가 잡지 못했다.
  원인은 규칙 3)이 「동일 문서 내」로만 좁혀진 것이고, 그 좁힘 자체는 옳았다 —
  틀린 것은 **문서 간 축을 아예 만들지 않은 것**이다(참조 중복은 정상, **정의 중복은 정상이 아니다**).
  ⚠️ 두 축을 구분한다: 이 축이 세는 것은 `row`·`new` **정의 형태**이고 본문 참조는 세지 않는다.
  ⚠️ 강도 = **관측(warn)** 으로 시작한다 — 선례 관례가 「위반 0 을 먼저 실측한 뒤 blocking 으로 올린다」이고,
     이 축은 정의 형태가 두 문서에 정당하게 나뉠 수 있는지(요약 행 vs 정의 행) 실측 전이다.
     `--cross-strict` 를 주면 blocking 이다.

  ⚠️ **원문 토큰을 보존한다** — `P1`(우선순위 라벨)과 `P-1` 을 같은 것으로 정규화하면 안 된다.
     초판이 하이픈을 삽입해 두 계열을 뭉갰다.

DEF 로 인정하는 3형태 (실측으로 확정 · 2026-08-12):
  1) 표 행 정의   : 줄이 `|` 로 시작하고 **첫 셀의 볼드가 ID 와 정확히 일치**    예) `| ✅ **DEC-36**<br>… |`
  2) 신규 선언    : `🆕 **ID` …                                        예) `🆕 **P220: …**`
  3) 세션 이력 항목: `> #### … [YYYY-MM-DD ID] …`                       예) `> #### 🟡 [2026-08-11 O59-S] …`

부가 검사 — **미정의 번호**(참조는 있는데 DEF 가 없다).
  `P214` 가 정확히 이 상태로 O59-T 에서 유입돼 다음 세션이 정의를 역추적해야 했다.

승격 이력(D3 근거): `AGENCY_AD_PERFORMANCE.AD_DATE` warn→error 승격이 선례이며 관례는
  **「위반 0 을 먼저 실측한 뒤 blocking 으로 올린다」**(문서50 §496·531 · 이력 §325).
  ⇒ 그래서 `--observe` 로 먼저 관측하고, 충돌 0 을 확인한 뒤 기본 모드(blocking)로 쓴다.

사용:
  python3 scripts/id_collision_gate.py            # blocking — 충돌 시 exit 1
  python3 scripts/id_collision_gate.py --observe   # 관측만 — 항상 exit 0
  python3 scripts/id_collision_gate.py --next DEC  # 다음 발급 번호만 출력
"""
import re
import sys
from collections import defaultdict
from pathlib import Path

DOC_DIR = Path(__file__).resolve().parent.parent / '20_issue'

# 전 계열 (D4 = ㉯ 전계열 · 2026-08-12 사용자 결정).
# 인덱스 §2-F 「별계열 주의」 + 실측 출현을 근거로 열거한다. 새 계열을 만들면 여기에 추가한다.
SERIES = [
    'DEC',       # 설계 의사결정
    'P',         # 설계 원칙·교훈
    'O',         # 세션 라벨 / 오픈 이슈
    'Q',         # SILVER Q-이슈
    'AC',        # 수용기준
    'S',         # 프로파일링 태스크
    'G',         # 코드체계 관문측정
    'AD',        # 광고 SV 이슈
    'PRV',       # 소비계층 미결
    'BLOCKING',  # dbt 블로커
    'SVL',       # SV 레벨 이슈
    'OWN',       # 소유권 이슈
    'CONF',      # 단위·환산 규약
    'FTG',       # 사업목표
    'D',         # 설계 D 계열 (D1~D12)
    'E',         # 외부 원천 의존
    'C',         # 코드·정의 이슈
]

# 접미(`-A`·`-B`·`-S`)까지 ID 의 일부로 본다 — `O59-S` ≠ `O59` · `P24-B` ≠ `P24` · `DEC-17-A` ≠ `DEC-17`.
# 🔴 하이픈을 삽입하지 않는다 — 원문 그대로 써야 `P1`(우선순위 라벨)과 `P-1` 이 섞이지 않는다.
ID_RE = re.compile(
    r'\b((?:' + '|'.join(sorted(SERIES, key=len, reverse=True)) + r')-?\d+(?:-?[A-Z])*)\b'
)

# 인덱스는 doc_role 이 「전체 크로스워크」다 ⇒ 정의 스캔에서 제외한다(등장 = 참조).
# 🔴 [2026-08-13 O67] `02`·`03` 도 같은 이유로 제외한다 — O66 이 인덱스 장문 셀을 **무변경 이관**해
#   만든 문서이고(doc_role = 「원장 §1·§2 표의 장문 셀 이관부」) 그 안의 ID 등장은 **인덱스 셀의 사본**이다.
#   ⚠️ 이관 직후 이 게이트가 **blocking 실패**했다: `02:134,143` 의 `**P224**` 2회(= O64 셀 안에서 두 번
#   언급한 것)가 「동일 문서 내 정의 2회」로 잡히고, 문서 간 정의 중복이 **7 → 17건**으로 늘었다.
#   즉 「무변경 이관」이 내용은 안 바꿨지만 **게이트의 분모를 바꿨다**(P224 자신의 교훈 = 게이트를 볼 때는
#   그 게이트가 가진 「축」을 본다). 제외 후 기대치 = 동일 문서 내 0 · 문서 간 **7**(O64 실측치 재현).
#   🔴 최대값 산정은 영향받지 않는다 — 참조(REF) 축은 제외 파일도 계속 세므로 R1-4-2 의 과소 보고가 열리지 않는다.
DEF_EXCLUDE_FILES = {
    '00_INDEX_이슈원장.md',
    '02_상태상세_대시보드_갱신형.md',
    '03_이슈상세.md',
}
# [O64] 문서 간 정의 중복 축에서만 추가 제외 — 이력은 정본이 아니다(R1-3-6).
CROSS_EXCLUDE_FILES = {'01_세션이력.md'}

DEF_TABLE_ROW = re.compile(r'^\s*\|([^|]*)\|')
DEF_NEW_DECL = re.compile(r'🆕\s*\*\*')
DEF_SESSION = re.compile(r'^\s*>\s*#{2,6}\s')
SESSION_DATE = re.compile(r'\[\d{4}-\d{2}-\d{2}\s+([A-Z]+-?\d+(?:-?[A-Z])*)\]')
# 볼드 안의 장식을 벗겨 ID 와 정확 비교하기 위한 패턴.
STRIP_DECOR = re.compile(r'(<br>.*$|[✅🔴🟢🟡🟠⚪⛔❌🆕⚠️~\s]+)')
# 🔴 백틱 코드 스팬은 **인용**이다 — 정의로 세면 안 된다.
#   실측 오탐: 문서50 이 *"O59-T 가 `🆕 **P214**.` 로 번호만 선언했다"* 를 서술한 두 줄이
#   P214 의 정의 2회로 잡혔다. 인용을 정의로 오인하면 「정의를 논한 문서」가 전부 충돌이 된다.
CODE_SPAN = re.compile(r'`[^`]*`')


def ids_in(text):
    return set(ID_RE.findall(text))


def bold_is_exact_id(cell):
    """첫 셀의 볼드 텍스트가 ID 그 자체인 경우에만 그 ID 를 돌려준다."""
    out = set()
    for bold in re.findall(r'\*\*([^*]+)\*\*', cell):
        token = STRIP_DECOR.sub('', bold)
        if token and ID_RE.fullmatch(token):
            out.add(token)
    return out


def classify(line):
    """이 줄이 정의하는 (ID, 형태) 집합을 돌려준다. 정의가 아니면 빈 집합.

    형태 = 'row'(표 행) · 'new'(🆕 선언) · 'session'(세션 이력 항목).
    🔴 'session' 은 **중복 검사 대상이 아니다** — 한 세션이 작업 단위별로 여러 항목을 쓰는 것이
      정상이기 때문이다(실측: `O56-B` 2항목 = `99_NEXT_SESSION.md:215` *"결정 대기 2건 — 둘 다
      집행 완료"* 로 의도 확인). 세션 라벨의 진짜 사고는 **다른 세션이 같은 라벨을 집는 것**이고,
      그것은 한 워크스페이스 스냅샷으로는 탐지할 수 없다 ⇒ 최대값 보고로만 돕는다.
    """
    line = CODE_SPAN.sub(' ', line)   # 인용은 정의가 아니다
    out = set()
    m = DEF_TABLE_ROW.match(line)
    if m:
        out |= {(i, 'row') for i in bold_is_exact_id(m.group(1))}
    if DEF_NEW_DECL.search(line):
        head = line.split('🆕', 1)[1][:80]
        # 🔴 `🆕 **P100 (…)** — §12 참조.` 는 **재인용**이다(실측 오탐).
        #   ⚠️ 단 「참조」가 들어 있으면 무조건 배제하면 **본문에 그 낱말을 쓴 선언까지 놓친다** —
        #   실측: `🆕 **P221: … 「인용·참조」를 구별해야 한다.**` 가 정의로 안 잡혔다(정의 수 176→175).
        #   ⇒ 배제 조건은 **줄 끝의 참조 포인터**(`… §12 참조.`)로 좁힌다.
        tail = line.split('🆕', 1)[1]
        is_pointer = re.search(r'(§[^§]{0,30})?참조\s*\.?\s*$', tail) is not None
        if not is_pointer:
            # `🆕 **P220: …**` — 볼드 시작부의 ID 만 인정한다.
            bm = re.search(r'\*\*([A-Z]+-?\d+(?:-?[A-Z])*)', head)
            if bm:
                out.add((bm.group(1), 'new'))
    if DEF_SESSION.match(line):
        for sm in SESSION_DATE.finditer(line):
            out |= {(i, 'session') for i in ids_in(sm.group(1))}
    return out


def series_of(_id):
    m = re.match(r'([A-Z]+)', _id)
    return m.group(1) if m else '?'


def num_of(_id):
    m = re.search(r'(\d+)', _id)
    return int(m.group(1)) if m else None


def main():
    argv = sys.argv[1:]
    observe = '--observe' in argv
    cross_strict = '--cross-strict' in argv
    want = argv[argv.index('--next') + 1].upper() if '--next' in argv else None

    defs = defaultdict(list)   # (file, id) -> [lineno]   ← 중복 검사용(세션 형태 제외)
    all_ids = set()            # 최대값 산정용(세션 형태 포함)
    refs = defaultdict(int)    # id -> count
    files = sorted(DOC_DIR.glob('*.md'))
    for f in files:
        for i, line in enumerate(f.read_text(encoding='utf-8').splitlines(), 1):
            if f.name not in DEF_EXCLUDE_FILES:
                # 🔴 [O64] 한 줄이 두 형태로 잡히면 **같은 ID 를 두 번 세면 안 된다.**
                #   실측 오탐: `| 🆕 **P224** | …` 표 행은 'row'(첫 셀 볼드 = ID)와 'new'(🆕 **ID)에
                #   **동시에** 걸려 한 줄이 정의 2회로 보고됐다 — 게이트 실패를 스스로 만드는 형태다.
                #   ⇒ 줄 단위로 ID 를 유일화하고, 형태는 우선순위 row > new > session 로 하나만 남긴다.
                per_line = {}
                for _id, kind in classify(line):
                    rank = {'row': 0, 'new': 1, 'session': 2}[kind]
                    if _id not in per_line or rank < per_line[_id][0]:
                        per_line[_id] = (rank, kind)
                for _id, (_r, kind) in per_line.items():
                    all_ids.add(_id)
                    if kind != 'session':
                        defs[(f.name, _id)].append(i)
            for _id in ids_in(line):
                refs[_id] += 1

    # 최대값 산정 — 두 기준을 **함께** 낸다. 어느 하나만 쓰면 양방향으로 틀린다.
    #   · 정의(DEF) 기준만  ⇒ **과소 보고**. 실측: `DEC-37`·`O61` 이 실재하는데 36·59 로 나왔다
    #     (정의 형태를 안 남긴 ID 가 있다 — O61 은 세션 이력 항목을 아직 안 썼다).
    #     과소 보고는 **다음 세션이 이미 쓰인 번호를 재발급**하게 만든다 = P220 이 막으려던 그 사고다.
    #   · 참조(REF) 기준만  ⇒ **과대 보고**. 실측: `S316331`·`D329` 는 본문 수치였다.
    #   ⇒ 발급은 보수적으로 **둘 중 큰 값 +1**, 그리고 두 값의 **차이를 미정의 번호 경보**로 쓴다.
    #   ⚠️ 1글자 계열(`D`·`S`·`C`·`E`·`G`)은 본문 숫자와 형태가 겹치므로 REF 최대값을 그대로 믿지 말 것.
    PLAUSIBLE_MAX = 999   # 실사용 최대는 P220 (3자리) — 4자리 이상은 본문 수치다
    defined_ids = all_ids

    def maxima(s):
        d = [num_of(i) for i in defined_ids if series_of(i) == s and num_of(i) is not None]
        r = [num_of(i) for i in refs
             if series_of(i) == s and num_of(i) is not None and num_of(i) <= PLAUSIBLE_MAX]
        return (max(d) if d else 0), (max(r) if r else 0)

    if want:
        dmx, rmx = maxima(want)
        print(f'{want} 최대 = 정의 {dmx} · 참조 {rmx} ⇒ 다음 발급 = {want}{max(dmx, rmx) + 1}')
        return 0

    print(f'[ID 충돌 게이트] 문서 {len(files)}개 · 계열 {len(SERIES)}종 · '
          f'정의된 식별자 {len(defined_ids)}개 / 참조 {len(refs)}개')
    print(f'  정의 스캔 제외(크로스워크 문서): {", ".join(sorted(DEF_EXCLUDE_FILES))}')

    dup = {k: v for k, v in defs.items() if len(v) > 1}
    for (fname, _id), lines in sorted(dup.items()):
        print(f'  🔴 **{_id}** 동일 문서 내 정의 {len(lines)}회 — {fname}:{", ".join(map(str, lines))}')
    print(f'  ⇒ 동일 문서 내 정의 중복 {len(dup)}건')

    # [O64] 문서 간 정의 중복 축 — 규칙 3)이 만든 사각(P223 이 두 문서에 정의됐는데 안 잡혔다).
    # ⚠️ 이 축에서만 이력 파일을 제외한다 — `01_세션이력.md` 는 정본이 아니라 append-only 이력이고(R1-3-6)
    #   거기 실린 `🆕 **P###**` 은 그 세션이 무엇을 세웠는지의 **서술**이다. 「정의 소유」로 셀 수 없다.
    #   🔴 단 최대값 산정(all_ids)에서는 **빼지 않는다** — 이력은 「그 번호가 이미 쓰였다」는 증거이고
    #      빼면 `O` 계열이 63→59 로 과소 보고돼 R1-4-2 가 막으려던 재발급 사고가 돌아온다.
    by_id = defaultdict(dict)
    for (fname, _id), lines in defs.items():
        if fname in CROSS_EXCLUDE_FILES:
            continue
        by_id[_id][fname] = lines
    cross = {i: fl for i, fl in by_id.items() if len(fl) > 1}
    print(f'\n  [문서 간 정의 중복 · {"blocking" if cross_strict else "관측"}]'
          f' — 제외: {", ".join(sorted(CROSS_EXCLUDE_FILES))}')
    for _id in sorted(cross, key=lambda x: (series_of(x), num_of(x) or 0)):
        where = ' · '.join(f'{f}:{",".join(map(str, ln))}' for f, ln in sorted(cross[_id].items()))
        print(f'    🟠 **{_id}** 정의 형태가 {len(cross[_id])}개 문서에 — {where}')
    print(f'    ⇒ 문서 간 정의 중복 {len(cross)}건'
          f'{"" if cross else " (정의 소유 문서가 ID 마다 하나다)"}')
    if cross and not cross_strict:
        print('    ⚠️ 관측 모드다. 🔴 **이 축은 「정의 소유 문서」 규약이 없으면 blocking 으로 못 올린다** —')
        print('       실측 잔여는 요약표 인용을 정의 형태와 구별할 수 없는 것들이다(예: 문서10 이 `상세는 … 요약:`')
        print('       머리말 아래 `| **DEC-8** | …` 표를 두는 형태). 규약 결정 후 승격할 것(원장 §O64 미결).')

    # ⚠️ 경보는 **충돌 실적이 있는 3계열**로 좁힌다. 전 계열에 켜면 17개 중 12개가 떠서
    #   그 자체가 무력화 패턴이 된다 — 나머지 계열은 「정의 형태를 내가 등록하지 않았다」는
    #   커버리지 공백이지 결함이 아니다(예: `### BLOCKING-5` 제목형).
    CORE_SERIES = {'DEC', 'P', 'O'}
    print('\n  계열별 최대·다음 발급 (정의 / 참조):')
    for s in SERIES:
        dmx, rmx = maxima(s)
        if not (dmx or rmx):
            continue
        if rmx > dmx and s in CORE_SERIES:
            flag = '  ⚠️ 정의<참조 = 정의 형태 없는 번호 존재'
        elif dmx == 0:
            flag = '  ⚪ 정의 형태 미등록 계열 — 참조 기준 참고치'
        else:
            flag = ''
        print(f'    {s:<9} 정의 {dmx:>4} · 참조 {rmx:>4} · 다음 {s}{max(dmx, rmx) + 1}{flag}')

    if dup and not observe:
        print('\n🔴 게이트 실패 — 한 문서가 같은 ID 를 두 번 정의했다.'
              ' 선례(§3-B)대로 **후행분을 재번호**하고 크로스워크를 남긴다.')
        return 1
    if cross and cross_strict and not observe:
        print('\n🔴 게이트 실패 — 같은 ID 를 두 문서가 정의했다.'
              ' 정의는 한 문서가 소유하고 나머지는 참조형으로 내린다.')
        return 1
    print('\n' + ('⚪ 관측 모드 — exit 0' if observe else '✅ 게이트 통과 — 동일 문서 내 정의 중복 0'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
