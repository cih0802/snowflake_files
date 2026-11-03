## O209 — 5차 X4 가이드 Agent(안 A 안내형) (2026-10-07 · 개발계 ij48528 · ㉡ 적용 · 라벨 선점 · 확정위반 0)

- 착수: `id_collision_gate --next O` = O209(rc=0) → 원장 §1 선점 등재 · 브리핑 BRIEF_RC=0 · read 미반환 0 · 재호출 0.
- 독해 표본(R1-3-7-b): `00_작업계획.md` 389~521 = 「46/48」「USP_ASK_AGENT_POC」「0.5953」 · 코퍼스 1~50 = 「Q07」「R15」 · 라벨 파일 O208-A/B/C 전량.
- X4-0: 제3안 문서 확인(cortex search docs · Agent toolsets = 도구만 상속 · 지시문 미상속 · USAGE 없으면 무경고 누락) → 사용자 = 안 A.
- X4-1: 스펙 `12_agent개선과제/09_O209_AGENT_GUIDE_spec.yaml` · 생성 SQL `09_O209_AGENT_GUIDE_create.sql` · 러너 `tmp/o209_guide.py`.
- X4-2: 사용자 승인 → `GN_DW.SERVING.AGENT_GUIDE` 생성(소유 GN_DW_ADMIN · 도구 0).
- X4-3: 사용자 승인 48회 → 47/48 = 97.9% · ✕ Q07(정답 정의 모호) · 연월 보충 5건 · 지연 중앙 10.75초.
- X4-4: §11-9 기록 · X5 착수 조건 5항.
