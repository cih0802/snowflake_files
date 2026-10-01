# init_ihcho 참조 — 새 문서·새 도구를 만들 때 (지침 `R1-6-18`)

> 🔴 **산출물이다** — 정본 = `00_guides/03_init_ihcho_스킬_본문.md` 의 `SKILL-REF` 마커 사이. 손으로 고치지 마라.

🟢 **먼저 판단하라** — 새 문서보다 기존 문서에 절을 추가하는 편이 낫지 않은가.

1. **원장 §0 유형 등재표에 한 줄 먼저 등재**(유형 + 근거 + 처리) — 빠뜨리면 `doc_type_gate` 즉시 FAIL.
   유형 값의 정본 = `doc_type_gate.KINDS`(개수를 적지 마라 · `R3-9 ㉦`).
   「항목은 꼬리로만 쌓이는데 판정 줄만 제자리 갱신」이면 `증분형`(판정식 = 은퇴로 건수가 줄어드는가).
2. `write` 툴로 생성 + **LLM-METADATA 헤더 필수**(`doc_id`·`doc_role`·`project`·`created`·`index`).
3. **상한 이내면 분할하지 않는다**.
4. **폴더 밖 문서면** `doc_type_gate.EXTRA_DOCS` · `doc_heading_gate.DOCS` ·
   `doc_line_length_gate.CANON` · `doc_census.SINGLES`(분할이면 `FAMILIES`)에 편입하고
   🔴 **기준선도 발행**한다(분모 편입과 골든 발행은 별개) ⇒
   `python3 scripts/doc_heading_gate.py --update-golden --reason "<사유>"`.
5. `doc_type_gate.py` + `line_len.py` + `doc_census.py` + `cortex ws ls` 로 확인.
6. 🔴 **게이트·생성기를 새로 만들면 음성 테스트를 같이 만든다**(`R3-2`) — 오염 기반 축 + 역방향 오탐 축 ·
   고치기 전 구현으로 돌리면 실패하는지 실증 · 축 수를 문서에 적지 마라.
   등재는 손으로 하지 않는다:
   · **영구 도구** ⇒ `python3 scripts/new_tool.py --name <이름> --bucket <분류> --axis "<축>"`(생성 + 등재 원자적)
   · **임시 계측기** ⇒ 파일명 **`_scratch_*.py`**(등재 면제) — `python3 scripts/gate_census.py --final` 이
     잔존을 FAIL 로 잡는다 ⇒ 지우거나 `--promote-scratch` 로 승격. 음성 축 = `scripts/test_tool_registration.py`.
