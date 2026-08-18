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
    """
    st = 0
    for sent in re.split(r'(?<=[.。·\n])', desc):
        if concept not in sent:
            continue
        neg = any(c in sent for c in NEG_CUES)
        pos = any(c in sent for c in POS_CUES)
        if neg and not pos:
            return -1
        if pos and not neg:
            st = 1
    return st


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

    print('=' * 72)
    if fail:
        print(f'🔴 FAIL — blocking 모순 {len(fail)}건')
        for f in fail:
            print('  ' + f)
        return 1
    print('🟢 PASS — 가불가 모순 0건')
    return 0


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('-v', '--verbose', action='store_true')
    sys.exit(run(ap.parse_args().verbose))
