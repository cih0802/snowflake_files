# -*- coding: utf-8 -*-
"""[2026-10-14 O225-C] `campaign_axis_gate` 음성 테스트 — **잡아야 할 것을 잡는가** (`R3-2`).

🔴 왜 필요한가: 이 게이트는 처음 돌린 순간 PASS 였다. PASS 만으로는 「누락이 없다」와
   「내 판정식이 못 본다」를 가를 수 없다 ⇒ 축마다 일부러 오염시켜 FAIL 을 단정한다.
   축1 = 이 게이트가 생긴 이유 그대로다 — BRONZE 에 새 캠페인 컬럼이 생겼는데 아무도 등재하지 않았다.
🟢 라이브·파일 접속 없이 돈다 — 분모·등재표·파일 내용을 주입한다.
"""
import sys
import os
import copy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import campaign_axis_gate as G

FAIL = []


def check(name, cond):
    print(('🟢 ' if cond else '🔴 ') + name)
    if not cond:
        FAIL.append(name)


def kinds(v):
    return {x[0] for x in v}


def real_reader(rel):
    return G.read_file(rel)


# 축0 — 기준선: 현재 정본은 통과해야 한다(역방향 오탐 축)
v, gaps = G.judge(G.BRONZE_SNAPSHOT, G.REGISTRY, real_reader)
check('축0 현 정본 위반 0', v == [])
check('축0 GAP 은 위반이 아니라 경고로만 나온다', len(gaps) > 0 and 'GAP' not in kinds(v))

# 축1 — 분모에 새 컬럼이 생겼는데 미등재 ⇒ UNREGISTERED
snap = set(G.BRONZE_SNAPSHOT) | {'BRONZE_CRM.TM_NEW.CMPGN_X'}
v, _ = G.judge(snap, G.REGISTRY, real_reader)
check('축1 미등재 BRONZE 컬럼 → UNREGISTERED', 'UNREGISTERED' in kinds(v))

# 축2 — 등재표에만 남은 낡은 행 ⇒ STALE
reg = copy.deepcopy(G.REGISTRY)
reg['BRONZE_CRM.TM_GONE.CMPGN_Y'] = G.X('test')
v, _ = G.judge(G.BRONZE_SNAPSHOT, reg, real_reader)
check('축2 분모에 없는 등재 → STALE', 'STALE' in kinds(v))

# 축3 — WIRED 인데 파일에서 토큰이 사라짐(배선 끊김) ⇒ BROKEN
target = 'BRONZE_ERP.EXPENSE_RESOLUTION.CONTENTS_DELIMITER'
rel, tok = G.REGISTRY[target]['checks'][-1]


def broken_reader(r):
    body = G.read_file(r)
    if r == rel and body is not None:
        return body.replace(tok, '')
    return body


v, _ = G.judge(G.BRONZE_SNAPSHOT, G.REGISTRY, broken_reader)
check('축3 SV 관계 토큰 삭제 → BROKEN', ('BROKEN', target) in {(x[0], x[1]) for x in v})

# 축4 — 근거 파일이 없어짐 ⇒ MISSING_FILE
v, _ = G.judge(G.BRONZE_SNAPSHOT, G.REGISTRY, lambda r: None if r == rel else G.read_file(r))
check('축4 근거 파일 부재 → MISSING_FILE', 'MISSING_FILE' in kinds(v))

# 축5 — 사유 없는 GAP/EXEMPT ⇒ NO_REASON (사유가 「알려진 미배선」의 계약이다)
reg = copy.deepcopy(G.REGISTRY)
k_gap = next(k for k in reg if reg[k]['status'] == 'GAP')
reg[k_gap]['reason'] = '  '
v, _ = G.judge(G.BRONZE_SNAPSHOT, reg, real_reader)
check('축5 사유 없는 GAP → NO_REASON', 'NO_REASON' in kinds(v))

# 축6 — 근거 없는 WIRED(체크 0) ⇒ NO_CHECKS (「끝까지 배선」 자기신고 금지)
reg = copy.deepcopy(G.REGISTRY)
reg[target]['checks'] = []
v, _ = G.judge(G.BRONZE_SNAPSHOT, reg, real_reader)
check('축6 체크 없는 WIRED → NO_CHECKS', 'NO_CHECKS' in kinds(v))

# 축7 — 상태 오타 ⇒ BAD_STATUS
reg = copy.deepcopy(G.REGISTRY)
reg[target]['status'] = 'WIRE'
v, _ = G.judge(G.BRONZE_SNAPSHOT, reg, real_reader)
check('축7 상태 오타 → BAD_STATUS', 'BAD_STATUS' in kinds(v))

print('FAIL %d' % len(FAIL))
sys.exit(1 if FAIL else 0)
