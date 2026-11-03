# O216-F — 감사 결함 시정: 라이브 스펙 안의 모순 문장 정리(도구 집합 무변경)
# ㉠ MKT 5곳 = 7차(O213 · SV_AD MEDIA_CHANNEL_NM·CMPGN_TYPE_BSN_NM 추가) 이후 거짓이 된 「매체 = 방송 계열만」「캠페인유형별 불가」
#    실측(CK24285 · WIDE_AD_COMBINED) = DIGITAL 매체 232,222/232,412 · 33종 · VIDEO 51종 · 재방송 22종 ·
#    캠페인유형 = DIGITAL 행만 9종(VIDEO·REBROADCAST NULL)
# ㉡ 3종 = O207 교차 규칙의 「MSTR 에 없는 축」 목록 → O216-C 9차가 대체한 정본과 일치시킨다(모순 제거)
# 방식 = o216d 와 같다(왕복 바이트 동일 선검증 · 해시 선확인 · 정확 문자열 1회 치환 · 도구 집합 assert)
# 사용: python3 tmp/o216f_agent_fix.py [--apply]
# Co-authored with CoCo
import hashlib, io, sys, yaml

B = '/workspace/cortex_project/agents/%s/agent_spec.yaml'
EXPECT = {'AGENT_MEMBER': 22, 'AGENT_EXECUTIVE': 12, 'AGENT_MARKETING': 20}
TAG = '[O216-F]'

O207_OLD = ('🔴 [O207 교차 규칙] MSTR 에 없는 축(캠페인카테고리·개발인입경로·국내해외·UTM·회비·발송·행사·코호트·GA·ML 예측)이나 '
            '개발 × 그 축 교차 질문은 기존 GN_DW 도구로 답하고 표 제목에 「GN_DW 기준」을 단다.')
O207_NEW = ('🔴 [O207 교차 규칙 · 🆕 O216-F 정정] MSTR 에 없는 **영역**(회비·납입·발송·행사·코호트·유지율·GA·광고비·예산·ML 예측·피처 중요도)이나 '
            '개발 × 그 영역 교차 질문은 기존 GN_DW 도구로 답하고 표 제목에 「GN_DW 기준」을 단다 '
            '(캠페인카테고리·개발인입경로·국내해외·UTM 은 MSTR 에 있는 축이다 — 축 목록 정본 = 아래 [O216-C 9차] MSTR 우선 라우팅).')

MKT = [
    # orchestration ③
    ('**매체별은 방송 계열만**, **캠페인 유형별은 불가**다.',
     '**매체별은 3원천 공통 가능**(디지털·영상·재방송 · `매체`), **캠페인유형별은 디지털 광고만 가능**하다(영상·재방송 행은 값 없음 · 🆕 O216-F 정정).'),
    # orchestration 라우팅 목록
    ('(🔴 소재별·개발캠페인별·초수·캠페인유형별은 불가 · 🔴 출처유형(디지털/방송/재방송) 필터를 함께 전달한다)',
     '(🔴 소재별 분해·개발캠페인별·초수는 불가 · 캠페인유형별은 디지털 한정(🆕 O216-F 정정) · 🔴 출처유형(디지털/방송/재방송) 필터를 함께 전달한다)'),
    # system (2 occurrences → identical sentence)
    ('- 🔴 **매체 축은 방송 계열만 실질적으로 있다** — 채널사 축은 방송·재방송에 채움이고 디지털 매체 축은\n  사실상 비어 있다. 「매체별」 질문에는 어느 계열 기준인지 밝히고, 디지털을 매체로 쪼개 달라는 요청에는\n  축이 비어 있음을 답한다(추정 분해 금지).',
     None),
    # tool description
    (' · **캠페인 유형/국내해외/사업사례별 광고 효율**(광고 팩트에 캠페인 축 미도달).',
     '. 🆕 [O216-F 정정] 캠페인유형(국내/해외 사례·사업)별 광고 효율은 **디지털 광고만 가능**하다(영상·재방송 행은 값 없음 · 7차 `캠페인유형` 축).'),
    ('🔴 **매체 축은 방송 계열(채널사)만 실질적으로 채워져 있고 디지털 매체 축은 사실상 비어 있다** — 「매체별」 질문에는 계열을 밝힌다.',
     '🆕 [O216-F 정정] **매체 축(`매체`)은 3원천 공통으로 채워져 있다**(디지털 33종·영상 51종·재방송 22종) — 「매체별」 질문에는 출처유형을 함께 밝힌다. 채널사 축은 방송·재방송 전용이다.'),
]


def h(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()


def sub_all(obj, old, new, cnt):
    if isinstance(obj, dict):
        for k in obj:
            obj[k] = sub_all(obj[k], old, new, cnt)
    elif isinstance(obj, list):
        for i in range(len(obj)):
            obj[i] = sub_all(obj[i], old, new, cnt)
    elif isinstance(obj, str) and old in obj:
        cnt[0] += obj.count(old)
        return obj.replace(old, new)
    return obj


for a in EXPECT:
    p = B % a
    h0 = h(p); assert h0 == h(p), a + ' 해시 불안정'
    t = io.open(p, encoding='utf-8').read()
    d = yaml.safe_load(t)
    assert yaml.safe_dump(d, allow_unicode=True, sort_keys=False, width=200) == t, a + ' 왕복 불일치'
    if TAG in yaml.safe_dump(d, allow_unicode=True):
        print(a, 'skip(이미 적용)'); continue
    n = [0]; d = sub_all(d, O207_OLD, O207_NEW, n); assert n[0] == 1, (a, 'O207', n[0])
    log = [f'O207 1']
    # GOLD 개발 도구 설명의 같은 낡은 축 목록(0~N 곳)
    n = [0]
    d = sub_all(d, 'MSTR 에 없는 축(캠페인카테고리·개발인입경로 등)과 교차 분석용 보조',
                'MSTR 에 없는 영역(회비·발송·행사·코호트·GA 등 · 🆕 O216-F 정정)과의 교차 분석용 보조', n)
    log.append(f'도구설명 {n[0]}')
    if a == 'AGENT_MARKETING':
        sys_old = MKT[2][0]
        sys_new = ('- 🆕 [O216-F 정정] **매체 축(`매체`)은 디지털·영상·재방송 3원천 공통으로 채워져 있다** — 「매체별」 질문에는 출처유형(디지털/영상/재방송)을 '
                   '함께 밝히고 출처를 섞어 순위를 매기지 않는다. 채널사 축은 방송·재방송 전용이다.')
        for old, new in [MKT[0], MKT[1], (sys_old, sys_new), MKT[3], MKT[4]]:
            n = [0]; d = sub_all(d, old, new, n)
            assert n[0] >= 1, (a, old[:30], n[0]); log.append(f'{old[:12]}… {n[0]}')
    out = yaml.safe_dump(d, allow_unicode=True, sort_keys=False, width=200)
    d2 = yaml.safe_load(out)
    tools2 = [x['tool_spec']['name'] for x in d2['tools']]
    assert len(tools2) == EXPECT[a] and set(tools2) == set(d2['tool_resources']), a + ' 도구 집합 변동'
    s2 = yaml.safe_dump(d2, allow_unicode=True, width=10 ** 9)  # 🔴 줄바꿈 없는 덤프로 잔존 판정(접힘 오탐 방지)
    for bad in ('MSTR 에 없는 축(캠페인카테고리', '사실상 비어', '방송 계열만', '캠페인 유형별은 불가', '캠페인유형별은 불가'):
        assert bad not in s2, (a, '잔존', bad)
    print(f'{a}: tools {len(tools2)} (무변경) · ' + ' · '.join(log) + f' · bytes {len(t.encode())}→{len(out.encode())}')
    if '--apply' in sys.argv:
        assert h(p) == h0, a + ' 편집 중 변경됨'
        io.open(p, 'w', encoding='utf-8', newline='').write(out)
        print('  WROTE', h(p)[:12])
print('mode =', 'APPLY' if '--apply' in sys.argv else 'DRY-RUN')
