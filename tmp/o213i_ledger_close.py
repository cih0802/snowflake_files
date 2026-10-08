# O213-I 세션 마감 — 원장 §1 O213 행 1개를 마감 문안으로 교체(열 수 보존 · 1,900자 가드 · 해시 확인)
import hashlib, io, sys
P = '/workspace/20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md'
h = lambda: hashlib.sha256(open(P, 'rb').read()).hexdigest()
h0 = h(); assert h0 == h()
L = io.open(P, encoding='utf-8').read().split('\n')
idx = [i for i, l in enumerate(L) if l.startswith('| 🟡 **`O213`**')]
assert len(idx) == 1, idx
new = ('| 🟢 **`O213`** — 7차 = 전체 카테고리 축 GOLD/MSTR/SV 전수 배선 → Agent 배선 (2026-10-08 · nj58180 · ㉡ · 승인 일괄 · 단위 O213-A~I · '
       '확정위반 3 = R1-7-2 해시 미확인·병렬 apply·병렬 edit · 유실 0) | 🟢 **7차 종결** · Y0 기준선 · Y1 lineage NONE 373 · Y2 판정 · '
       'Y3 A~K 전 도메인 배선(B→K · H 갭 0 · Z 불필요) · 신규 GOLD 팩트 5·차원 1 · 신규 SV 5종(회비 청구 처리 · GA4 세션 · 서치콘솔 · GA4 인구통계 · 지출결의) · '
       '기존 SV 17종 신규 축 · **Agent 3종 VERSION$7**(도구 22·12·20 · 롤백 VERSION$6) · NL 10문항 최종 10/10 · AGENT_GUIDE 스펙 보존 이관 · '
       '➡️ 잔여(전량 회귀·eval·OPS 임시 객체 DROP·문서20 N-29 ①~⑧) = **8차 Agent 업데이트로 이월** | §13-1-5~9 · 이력 §O213-I | '
       '`12_agent개선과제/00_작업계획.md` · `99_NEXT_SESSION-O0213-J.md` |')
assert len(new) <= 1900 and new.count('|') == L[idx[0]].count('|'), (len(new), new.count('|'))
L[idx[0]] = new
out = '\n'.join(L)
if '--apply' in sys.argv:
    assert h() == h0
    io.open(P, 'w', encoding='utf-8', newline='').write(out); print('WROTE', len(new))
else:
    print('DRY', len(new))
