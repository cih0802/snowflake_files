#!/usr/bin/env python3
# O207-C — 답변 품질 · 미정의 지표 「계산할까요?」 규칙을 3 Agent response 선두에 추가 · 앵커 1회 강제 · 2000자 가드
# Co-authored with CoCo
import io, sys
import yaml

BASE = '/workspace/cortex_project/agents/%s/agent_spec.yaml'
MARK = '[O207-C 답변 품질]'
RULE = (
    "🔴🔴 " + MARK + " ① 답변은 한국어 본문만 쓴다 — 내부 판단·도구 선택 과정(영어 계획 문장 등)을 본문에 쓰지 않고, "
    "같은 내용을 두 번 출력하지 않는다. ② 개발·회원 수치 표의 제목 또는 첫 줄에 기준을 밝힌다 — "
    "MSTR 도구 결과는 「MSTR 기준」, 그 밖의 도구 결과는 「GN_DW 기준」. ③ 결론(핵심 수치 1~3개) → 표 → 산식·한계 순으로 쓴다.\n"
    "    🔴🔴 [O207-C 미정의 지표] 묻는 지표가 지표사전에 산식으로 정의돼 있지 않으면(예: 추경 회비예측 · 회비 시나리오(낙관/기본/비관) 같은 시뮬레이션) "
    "바로 계산하지 않는다 — 먼저 「이 지표는 사전에 정해진 산식이 없습니다. 제가 가정을 세워 계산하면 질문할 때마다 새로 연산하므로 "
    "값이 고정되지 않고 달라질 수 있습니다. 계산할까요?」라고 묻고, 쓸 가정(기준 기간·분모·산식)을 1~3줄로 제시한다. "
    "사용자가 계산을 요청하면 그 가정을 표 위에 적고 「Agent 계산값 · 고정값 아님」을 붙인다.\n"
    "    지표사전에 산식이 있는 지표(서비스별 증액율 = 증액 회원 ÷ 서비스 발송 성공 회원 × 100 · N개월 유지율 = N개월 시점 유지 회원 ÷ 대상 회원 × 100)는 "
    "그 산식을 따르고, 데이터가 산식을 정확히 지원하지 못하면(예: N개월 시점 판정 축 부재) 근사 방식을 밝히고 계산할지 묻는다.\n    ")


def once(s, old, new, label):
    n = s.count(old)
    if n != 1:
        sys.exit(f'🔴 {label}: 앵커 {n}회 (기대 1)')
    return s.replace(old, new, 1)


for a in ['AGENT_MEMBER', 'AGENT_MARKETING', 'AGENT_EXECUTIVE']:
    p = BASE % a
    s = io.open(p, encoding='utf-8').read()
    if MARK in s:
        print(a, 'skip'); continue
    s = once(s, "  response: '", "  response: '" + RULE, a)
    d = yaml.safe_load(s)
    assert MARK in d['instructions']['response'] and '[O207-C 미정의 지표]' in d['instructions']['response']
    ml = max(len(l) for l in s.splitlines())
    assert ml < 2000, (a, ml)
    io.open(p, 'w', encoding='utf-8').write(s)
    print(a, 'max_line=%d' % ml)
