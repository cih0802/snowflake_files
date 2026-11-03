# O246-D — Agent 3종 spec 보강: ② D1 재출력 방지(1회 출력) · ③ D2 대체 축 제시 · 사용자 승인 2026-10-19
import io, re, shutil, yaml
D = '/workspace/cortex_project/agents/'
AG = ['AGENT_MEMBER', 'AGENT_EXECUTIVE', 'AGENT_MARKETING']


def rx(t):
    # yaml 접힘 줄바꿈·이스케이프를 허용하는 공백 패턴
    return re.compile(r'(?:\s|\\)+'.join(re.escape(w) for w in t.split(' ')))


def sub1(s, old, new, tag):
    hits = list(rx(old).finditer(s))
    assert len(hits) == 1, (tag, len(hits))
    return s[:hits[0].start()] + new + s[hits[0].end():]


# ② D1 — 근거 tmp/o246/agent_test/B1.txt: 「③ **상」 작성 중 data_to_chart 호출 → 도구 결과 뒤 <answer> 재개 · ③ 2회
D1_OLD = '㉣ 「① 핵심 요약」 제목과 요약 블록은 답변 전체에 정확히 1회다(차트 생성 뒤 다시 쓰지 않는다).'
D1_NEW = ('㉣ 「① 핵심 요약」·「② 그래프」·「③ 상세」 제목과 블록은 답변 전체에 각각 정확히 1회다(차트 생성 뒤 다시 쓰지 않는다). '
          '🆕 [O246-D] 차트(data_to_chart)는 ① 을 쓰기 전에 만든다 — 본문 작성 중에 차트 도구를 부르지 않는다. '
          '도구 결과 뒤에는 이미 쓴 제목·문장을 이어 쓰지 않고, 답변을 처음부터 한 번만 쓴다.')
ORCH_1 = ('🔴 [O246-D 1회 출력] 데이터 조회·차트 생성(data_to_chart)을 모두 마친 다음 최종 답변을 한 번에 작성한다'
          '(본문 작성 중 도구를 다시 부르지 않는다 · 근거 = AGENT_MEMBER 스모크 B1 「③ 상세」 2회·태그 노출). ')

# ③ D2 — 근거 tmp/o246/agent_test/B3.txt: UTM (미매칭) 76.35% 공개만 · 대체 축 제안 없음
D2_OLD = '절반 미만이면 (미매칭)을 별도 행으로 둔다.'
D2_NEW = ('절반 미만이면 (미매칭)을 별도 행으로 둔다. '
          '🆕 [O246-D] 보완값이 없는 축(UTM 등 원천 값 보유가 낮은 축)에서 미매칭이 절반 이상이면 그 표는 참고로만 두고, '
          '값 보유가 높은 대체 축(유입경로·공통브랜드·마케팅캠페인명·마케팅채널)으로 같은 질문을 다시 집계해 함께 제시한다. '
          '각주에 원 축의 미매칭 비중과 대체 축을 쓴 이유를 한 문장으로 밝힌다.')

for a in AG:
    p = D + a + '/agent_spec.yaml'
    s = io.open(p, encoding='utf-8', newline='').read()
    shutil.copyfile(p, '/workspace/tmp/o246d/%s_agent_spec.yaml.beforeD' % a)
    s = sub1(s, D1_OLD, D1_NEW, a + ' D1')
    m = re.search(r"(  orchestration: ['\"])(🔴🔴 \[O246-B)", s)
    assert m, a + ' orch'
    s = s[:m.end(1)] + ORCH_1 + s[m.end(1):]
    s = sub1(s, D2_OLD, D2_NEW, a + ' D2')
    y = yaml.safe_load(s)
    ins = y['instructions']
    assert ins['orchestration'].startswith('🔴 [O246-D 1회 출력]'), a
    assert '[O246-D] 보완값이 없는 축' in ins['orchestration'], a
    assert '[O246-D] 차트(data_to_chart)' in ins['response'], a
    io.open(p, 'w', encoding='utf-8', newline='').write(s)
    print('OK', a, len(ins['orchestration']), len(ins['response']))
