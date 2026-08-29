# -*- coding: utf-8 -*-
"""[2026-08-18 O84] Agent 도구 설명 **주장 일치 게이트** — 같은 SV, 다른 말을 하지 않는가.

🔴 왜 필요한가(착수표 ⑱ C2 = O76-B 처방):
   이 워크스페이스는 **같은 SV 를 여러 Agent 가 중복 보유**한다(사용자 결정).
   그런데 도구 설명(`description`)은 **자동 전파되지 않는다** — 사람이 각 스펙을 따로 고친다.
   O76-B 실측 = 같은 SV 의 도구 설명이 유사도 **0.316** 까지 벌어져도 **아무 게이트도 잡지 않았다**.
   결과는 무증상 오답이다: 한 Agent 는 「캠페인별 분해 가능」, 다른 Agent 는 「불가」라고 답한다.

🔴 위험이 커졌다 — 마케팅 Agent 신설로 중복 보유가 늘었다(analyst_ad 등).
   ⇒ 「설명이 완전히 같아야 한다」가 아니라 **「가불가 주장이 서로 모순되지 않아야 한다」**를 본다.

판정 축 2개
  ① 🔴 **blocking · 가불가 모순** — 같은 SV 를 참조하는 도구 설명들에서
     **금지·불가 주장 토큰**을 뽑아, 한쪽이 「X 불가」라 하고 다른 쪽이 그 X 를
     **가능 주장**으로 쓰면 모순으로 잡는다. 이것이 실제 오답을 만드는 축이다.
  ② 🟠 **advisory · 문안 이격** — 같은 SV 도구 설명의 토큰 자카드 유사도.
     임계 미달을 보고하되 종료코드는 바꾸지 않는다(문안이 도메인별로 달라도 정상일 수 있다).

🔴 이 게이트는 **의미를 판정하지 않는다** — 「같은 개념을 반대로 말한다」의 표층 신호만 본다.
"""
import sys, os, re, glob, json, argparse
from itertools import combinations

ROOT = '/workspace'
# 🟢 [2026-08-29 O119-B] 축 ③ 의 판정식·예외를 **공유**한다(복제 0 · 근거는 축 ③ 주석).
sys.path.insert(0, os.path.join(ROOT, 'scripts'))
import sv_rule7_scan as _r7  # noqa: E402
AGENT_GLOB = os.path.join(ROOT, 'cortex_project/agents/*/agent_spec.yaml')
JACCARD_MIN = 0.45      # ② 임계. 근거 = O76-B 관측 0.316 이 「벌어졌다」로 판정된 사례라 그 위.

# ① 축의 개념 어휘. 「이 개념이 가능한가」를 두 Agent 가 반대로 말하면 오답이 된다.
# 🔴 개념은 **업무 축 이름**으로 좁힌다 — 일반 명사를 넣으면 오탐이 쏟아진다.
CONCEPTS = [
    '소재별', '개발캠페인', '마케팅캠페인', '캠페인별 중단', '캠페인별 분해',
    '부서별 중단', '부서별 목표', '일별 목표', '매체별 목표', '본부', '지부',
    '연령대', '지역별', '후원사업별', '납입방식', '전환콜', '개발단가',
]
NEG_CUES = ['불가', '금지', '없다', '부재', '아니다', '말 것', '미노출', '제외됐다', '산출 불가']
POS_CUES = ['가능', '활성', '산출된다', '답한다', '쓴다', '분해할 수 있다', '해소됐다', '정본']

# 🔴🔴 [2026-08-29 O119-B 신설 · 사용자 승인] **가산성 경고를 「축 불가」와 분리한다.**
#   경위: O119 가 줄바꿈 접기로 blocking 모순을 없앴으나 **부작용으로 두 스펙이 함께 `-1`(불가)** 이 됐다.
#     실제 문안은 「후원사업별 … 정본 도구다 · 분해 **가능하다**」이므로 그 판정은 **사실과 반대**다
#     ⇒ 모순은 사라졌지만 **거짓 음성**이 남았다(「모순 0」이 「올바르게 읽었다」가 아니다).
#   🔴 원인 = `SUM 금지`·`합산하지 말 것`·`비가산` 같은 **가산성 경고**가 NEG 단서에 걸린다.
#     그러나 「그 축으로 분해할 수 있다」와 「분해한 값을 더하지 마라」는 **양립하는 두 주장**이다
#     — 비가산 metric(`COUNT(DISTINCT …)`)에서는 **둘 다 참인 것이 정상**이다.
#   🟢 그래서 이 단서가 있으면 **NEG 로 세지 않는다**(가능/불가 판정에서 중립화한다).
#     🔴 문장에 다른 진짜 NEG 단서가 있으면 그것은 그대로 살아 있다 — 이 목록은
#        「가산성만 말하는 문장」을 중립화할 뿐이고 부정 감지 자체를 끄지 않는다.
#   🟢 집행 = `scripts/test_agent_tool_claim_gate.py` 축3·축8.
ADDITIVITY_CUES = [
    '비가산', 'SUM 금지', 'SUM 하지', '합산 금지', '합산하지', '더하지', '분모를 바꾸지',
    '같게 기대하지', '한 표에 합치지', '한 표로 합치지', '조인하지',
]


def load_tools():
    """스펙별 (agent, tool, sv, description) 을 뽑는다.

    🔴 yaml 파서를 쓰지 않는다 — 스펙에 이스케이프 결함이 있어도 게이트가 죽지 않아야 한다
       (O76-C A19 가 실제로 그랬다).
    🔴🔴 **[O84 자기검증에서 잡은 파서 결함]** 초판은 `description:` 뒤를 **다음 항목 시작 패턴의
       lookahead** 로 끊었다. 그래서 **각 스펙의 마지막 도구**는 뒤에 그 패턴이 없어 설명이
       **전건 누락**됐다(실측 desc_len=0 **3건** = MARKETING/analyst_member_fee ·
       MEMBER/analyst_ml_fee_forecast · OVERALL/analyst_ml_feature_importance).
       그 상태로 ① 은 6쌍만 검사하고 **PASS 를 냈다** = 거짓 PASS.
       ⇒ 이제 `- tool_spec:` **블록 단위로 잘라** 블록 끝까지를 설명으로 삼는다.
       ⇒ 교훈은 `P224` 그대로다: **게이트를 볼 때는 그 게이트의 축(분모)을 본다.**
    """
    out = []
    for p in sorted(glob.glob(AGENT_GLOB)):
        agent = os.path.basename(os.path.dirname(p))
        txt = open(p, encoding='utf-8').read()

        head = txt.split('tool_resources:', 1)[0]
        # tools: 이후를 '- tool_spec:' 경계로 분할한다(마지막 블록도 동일하게 처리된다).
        body = head.split('\ntools:', 1)
        descs = {}
        if len(body) > 1:
            for chunk in re.split(r'\n\s*-\s*tool_spec:', body[1])[1:]:
                nm = re.search(r'\bname:\s*([A-Za-z0-9_]+)', chunk)
                ds = re.search(r'\bdescription:\s*', chunk)
                if nm and ds:
                    descs[nm.group(1)] = chunk[ds.end():].strip()

        res = txt.split('tool_resources:', 1)
        svmap, tool = {}, None
        if len(res) > 1:
            for ln in res[1].splitlines():
                mm = re.match(r'^  ([A-Za-z_][A-Za-z0-9_]*):\s*$', ln)
                if mm:
                    tool = mm.group(1)
                mm = re.search(r'semantic_view:\s*([A-Za-z0-9_.]+)', ln)
                if mm and tool:
                    svmap[tool] = mm.group(1).split('.')[-1]

        for t, sv in svmap.items():
            d = descs.get(t, '')
            if not d:
                # 🔴 설명을 못 읽었다면 침묵하지 않는다 — 분모 누락은 거짓 PASS 를 만든다.
                print(f'  🔴 파서 경고 — {agent}/{t} 설명 미확보(분모 누락)', file=sys.stderr)
            out.append((agent, t, sv, d))
    return out


def tokens(s):
    s = re.sub(r'[^\w가-힣]+', ' ', s)
    return {w for w in s.split() if len(w) > 1}


def stance(desc, concept):
    """설명 안에서 그 개념에 대한 태도를 -1(불가)/+1(가능)/0(무언급) 로 읽는다.

    🔴 문장 단위로 본다 — 문서 전체에 '불가' 가 있다는 사실은 그 개념의 태도가 아니다.

    🔴🔴 **[2026-08-29 O119 신설 · 오탐 1건 제거] YAML 의 물리적 줄바꿈은 문장 경계가 아니다.**
       경위: 이 게이트가 `SV_MEMBER_SPONSOR_BIZ` 「후원사업별」에서 **blocking 모순 1건**을 냈고
       `AGENT_MARKETING`(불가) ↔ `AGENT_MEMBER`(가능) 로 갈렸다. 판정 근거 문장을 재현하니
       **두 스펙의 문안이 실질적으로 같았다** — 둘 다 첫 등장 문장에서 *"정본 도구다 … 분해 가능하다"*
       라고 **가능**을 명시하고, 둘 다 뒤에 *"후원사업별 합계는 … N 비가산, SUM 금지"* 라는
       **가산성 경고**를 달고 있었다.
       ⇒ 판정이 갈린 유일한 원인은 **YAML 줄바꿈이 어디에 떨어졌는가**였다:
         · `AGENT_MARKETING` = `SUM 금지`·`말 것` 이 「후원사업별」과 **같은 물리 줄**에 있었다 ⇒ -1
         · `AGENT_MEMBER`   = 줄바꿈이 `전체 활동회원수보다` 뒤에 떨어져 그 단서가 **문장에서 빠졌다** ⇒ 0
       🔴 이 게이트는 의도적으로 yaml 파서를 쓰지 않으므로(위 `load_tools` 근거) 물리적 줄바꿈이
          문자열에 그대로 남는다 ⇒ **줄바꿈을 접지 않으면 판정이 「서식」에 좌우된다.**
       🟢 그래서 문장 분해 **전에** 「줄바꿈 + 들여쓰기」를 공백으로 접는다(YAML folding 과 같은 효과).
          이제 같은 문안은 wrap 위치와 무관하게 **같은 판정**을 받는다.
       🔴 **생산물(Agent 스펙)은 고치지 않았다** — 고치면 유효한 가드(비가산 metric 을 SUM 하지 말라)를
          파서 인공물 때문에 약화시키는 일이 된다. 결함은 판정식 쪽에 있었다(`R3-9` · `▣XXX6 ㉦`).
       ⚠️ ~~**남은 한계(의도적)**: 접은 뒤 두 스펙은 **함께 -1** 이 된다 ⇒ 모순은 사라지지만
          「가산성 경고」와 「축 자체가 불가」를 이 함수는 여전히 구별하지 못한다.~~
       🟢🟢 **[2026-08-29 O119-B 해소 · 사용자 승인] `ADDITIVITY_CUES` 로 분리했다** —
          「SUM 금지·비가산」만 말하는 문장은 이제 **NEG 로 세지 않는다**(위 목록 근거 참조).
          🔴 **왜 필요했나** = 접기만으로는 「모순 0」을 얻는 대신 **두 스펙이 함께 「불가」로 읽히는
          거짓 음성**이 남았다. 실제 문안은 「분해 가능하다」이므로 그 판정은 사실과 반대였다
          ⇒ 🔴 **판정식 = 「모순 0」은 「올바르게 읽었다」가 아니다**(`R3-9` 축의 또 다른 얼굴).
       🟢 집행 = `scripts/test_agent_tool_claim_gate.py` 축1·축2(wrap 불변성·오탐 재현) +
          **축8**(가산성 분리 · 진짜 부정 보존).
    """
    # 🔴 물리적 줄바꿈을 접는다 — 이 한 줄이 위 오탐의 시정 전부다.
    desc = re.sub(r'\n[ \t]+', ' ', desc)
    st = 0
    for sent in re.split(r'(?<=[.。·\n])', desc):
        if concept not in sent:
            continue
        neg = any(c in sent for c in NEG_CUES)
        pos = any(c in sent for c in POS_CUES)
        # 🔴🔴 [2026-08-29 O119-B] **가산성만 말하는 문장은 「불가」가 아니다.**
        #   `SUM 금지`·`비가산` 은 「그 축으로 분해할 수 있다」와 양립한다 ⇒ NEG 를 중립화한다.
        #   🔴 단 다른 NEG 단서가 **가산성 단서와 무관하게** 남아 있으면 그것은 살린다 —
        #      판정 = 「NEG 단서 전부가 가산성 문맥에서 온 것인가」다(부정 감지를 끄지 않는다).
        if neg and any(c in sent for c in ADDITIVITY_CUES):
            residual = [c for c in NEG_CUES if c in sent and not _from_additivity(sent, c)]
            neg = bool(residual)
        if neg and not pos:
            return -1
        if pos and not neg:
            st = 1
    return st


def _from_additivity(sent, neg_cue):
    """그 NEG 단서의 **모든 등장 위치**가 가산성 경고 문맥 안인가.

    🔴 위치 기반으로 판정한다 — 「문장에 가산성 단서가 있다」만으로 NEG 를 통째로 지우면
       가산성 경고와 진짜 부정이 같은 문장에 있을 때 진짜 부정을 잃는다(그것이 O119 의 실패 유형이다).
    판정 = 그 NEG 단서 등장 위치가 어떤 가산성 단서의 근방(앞뒤 24자) 안에 있는가.
    """
    WIN = 24
    spans = []
    for cue in ADDITIVITY_CUES:
        start = 0
        while True:
            i = sent.find(cue, start)
            if i < 0:
                break
            spans.append((i - WIN, i + len(cue) + WIN))
            start = i + 1
    if not spans:
        return False
    start = 0
    while True:
        i = sent.find(neg_cue, start)
        if i < 0:
            return True          # 등장 전건이 근방 안이었다
        if not any(a <= i <= b for a, b in spans):
            return False         # 근방 밖 등장이 있다 ⇒ 진짜 부정이 남아 있다
        start = i + 1


def run(verbose=False):
    tools = load_tools()
    by_sv = {}
    for agent, tool, sv, desc in tools:
        by_sv.setdefault(sv, []).append((agent, tool, desc))

    dup = {sv: v for sv, v in by_sv.items() if len(v) > 1}
    print('=' * 72)
    print(f'중복 보유 SV {len(dup)}종 / 전체 참조 SV {len(by_sv)}종 · 도구 {len(tools)}건')
    for sv, v in sorted(dup.items()):
        print(f'  · {sv}: ' + ' + '.join(f'{a}/{t}' for a, t, _ in v))

    fail, advis = [], []
    print('=' * 72)
    print('① 가불가 모순 (blocking)')
    print('=' * 72)
    checked = 0
    for sv, v in sorted(dup.items()):
        for (a1, t1, d1), (a2, t2, d2) in combinations(v, 2):
            for c in CONCEPTS:
                s1, s2 = stance(d1, c), stance(d2, c)
                if s1 and s2:
                    checked += 1
                    if s1 != s2:
                        hi = f'{a1}({"가능" if s1 > 0 else "불가"}) ↔ {a2}({"가능" if s2 > 0 else "불가"})'
                        fail.append(f'① {sv} 「{c}」 주장 모순 — {hi}')
    print(f'  양쪽이 태도를 밝힌 (SV×개념) 쌍 {checked}건 검사')

    print('=' * 72)
    print('② 문안 이격 (advisory)')
    print('=' * 72)
    for sv, v in sorted(dup.items()):
        for (a1, t1, d1), (a2, t2, d2) in combinations(v, 2):
            x, y = tokens(d1), tokens(d2)
            j = len(x & y) / len(x | y) if (x | y) else 1.0
            if j < JACCARD_MIN:
                advis.append(f'② {sv} 유사도 {j:.3f} — {a1}/{t1} ↔ {a2}/{t2}')
    print(f'  임계 {JACCARD_MIN} 미달 {len(advis)}건')
    for a in advis:
        print('    · ' + a)

    # 🔴🔴 [2026-08-29 O119-B 신설 · 축 ③] **Agent 스펙 description 의 규칙7(COMMENT 수치 금지) 검사.**
    #   🔴 왜 여기인가 = 이 표면은 **어느 게이트 분모에도 없었다.** `sv_unit_gate`·`sv_rule7_scan` 은
    #     SV COMMENT 만, `audit_ddl_rule7` 은 GOLD/SILVER DDL 만 본다. 그런데 Agent 스펙 description 은
    #     **Cortex Analyst 가 도구 선택 근거로 읽는 문안**이라 stale 수치의 오답 파급이 SV COMMENT 와 동급이다
    #     ⇒ `P194` 형제 표면. 🟢 이 게이트가 이미 description 을 파싱하므로(`load_tools`) 여기가 자연스러운 집.
    #   🟢 판정식·예외는 **복제하지 않고 공유한다** = `sv_rule7_scan.violations`(= `audit_ddl_rule7.NUM`
    #     + `sv_unit_gate.NUM_EXEMPT`). 세 게이트가 한 벌을 쓰므로 다시 어긋나지 않는다(`R3-9 ㉡`).
    #   🔴 **blocking 이다** — O119-B 착수 시 8건이었고 판정해 보니 **진짜 1건**(`+18.5%` 과대율) +
    #     **오탐 7건**(grain 정의 어순 2종 · 만원↔원 환산 배수)이었다. 진짜를 제거하고 예외를 넓혀 **0** 이
    #     됐으므로 기준선 없이 0 을 요구할 수 있다(기준선을 두면 오탐을 부채로 등재하게 된다).
    print('=' * 72)
    print('③ 스펙 description 규칙7 수치 혼입 (blocking · O119-B 신설)')
    print('=' * 72)
    r7 = []
    for agent, tool, _sv, desc in tools:
        for name, tok, _pos in _r7.violations(desc):
            r7.append(f'③ {agent}/{tool} [{name}] {tok!r}')
    print(f'  검사 {len(tools)}건 · 위반 {len(r7)}건')
    for x in r7:
        print('    · ' + x)
    fail.extend(r7)

    print('=' * 72)
    if fail:
        print(f'🔴 FAIL — blocking {len(fail)}건')
        for f in fail:
            print('  ' + f)
        print('  🔴 ③ 은 판정 전에 그 토큰이 **실측치인가 정의·관례인가**를 가려라 —')
        print('     정의·관례이면 `sv_unit_gate.NUM_EXEMPT`(3게이트 공유)에 예외를 추가한다.')
        return 1
    print('🟢 PASS — 가불가 모순 0건 · 스펙 규칙7 수치 혼입 0건')
    return 0


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('-v', '--verbose', action='store_true')
    sys.exit(run(ap.parse_args().verbose))
