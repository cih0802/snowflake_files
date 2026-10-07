## O207-C — 사용자 지시 6건 처리 + 세션 비판적 자기검토 (2026-10-07 · ㉡ 적용 · 승인 일괄)

- 독해(R1-3-7-b): `00_BRIEF.md`(재생성 BRIEF_RC=0 · 현행 O207-A) · `10_MSTR_일일적재_dbt연동_준비.md` 105/105(토큰 §3 C안 · §4-3 TSK_RUN_MSTR_DAILY) · `04_sp_script.sql` 700-860·960-1023(토큰 `:730` WHERE STRD_MT · `:1016` SUM 호출) · 문서20 `-010` 228-242(토큰 N-28 ①②③) · 지침 = 동일 대화 내 전량 독해본(304줄 · 해시 미변경 전제 · 재독해 생략을 명시) · read 미반환 0.
- ① 일일 적재 확정: dbt Task AFTER 권고(고정 07:30 대안) · `07_MSTR_일일적재_TASK.sql` 신설 · 스텁 2분기 실행 검증 · 근거 = 일 배치 DELETE 기준월 한정(라이브 GET_DDL) · 1개 월 ≈ 23초.
- ② 연도말 예측 테이블 = 없음(SILVER 목표·실적만 · ML 금액만) ⇒ 현행 유지.
- ③ AGENT_MSTR DROP(스펙 `_archive/agent_spec.yaml.O207-C-retire-agent-mstr`) · 대체 스모크 M1~M3 MSTR 도구 PASS.
- ④ MSTR 우선 라우팅 = 이미 구현(W5 12/12).
- ⑤ 품질 규칙 `[O207-C 답변 품질]` · ⑥ `[O207-C 미정의 지표]`(계산할까요 · 고정값 아님) · 🔴 N-28 ③ 유지율·증액율은 사전 정의 있음(정정) · 「추경 회비예측」 동의어 제거.
- 라이브 = AGENT_MEMBER VERSION$10 · MKT·EXEC VERSION$9 · SV_MSTR_SPNSR_DVLP · SV_MBRFEE_PRDT_ACTL 재배포.
- 자기검토 S1~S11(`00_작업계획.md` §10-8): 프로시저 좌표 오인용(_INIT) · 후원금액대2 서술 · VQR 합계 왜곡(53.6% → 마감월 70.1%) · A안 문구 4곳 잔존(J5) · N-28 ③ 사전 미대조 · 추경 라우팅 우회 · 아키텍처 지도 stale(재생성) · 🔴 O207 확정위반 1(R1-7-2) 원장 정정 · 음성 테스트 3종 부재 · 06 라벨 과대 보고 · 판정식 문형 약점.
- 게이트 = sv_rule7_scan · sv_identifier_gate · agent_object_ref_gate · agent_source_lineage_gate · agent_tool_claim_gate 전부 PASS.

_Co-authored with CoCo_
