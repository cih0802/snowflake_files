<!-- LLM-METADATA
doc_id: HANDOFF_O0213_D
doc_role: 인수인계 — 세션 `O213-D` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-08
created_by: O213-D
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0213-D -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## O213-D 인수인계 (Y3-C 회원 속성 축 · dbt 정지점)

### ▣ O213-D-0 🔴 먼저 알아라 (2026-10-08 · nj58180 · ㉡ 적용 · 승인 일괄 · 확정위반 1)

- 🟢 정본 = `12_agent개선과제/00_작업계획.md` §13-1-6.
- 🟢 물리 반영(ALTER 완료 · 데이터는 build 후):
  · `SILVER.CRM_MEMBER` + `SPECL_MNG_CD2` · `SLRCLD_LRR_CD` COMMENT 정정(급여공제 → 양력음력).
  · `GOLD.DIM_MEMBER` + 28컬럼(결연구분 · 특별관리 1·2 · 최초후원사업명 · 휴대폰/기타연락처/이메일 상태 · TM/TS 거절 2 · 관계 · 양음력 · 수신 플래그 10).
- 🟢 모델 = `models/silver/crm/CRM_MEMBER.sql` · `models/gold/dim/DIM_MEMBER.sql` · DDL 정본 08 · 06 갱신.
- 🔴 SV 배선은 아직 하지 않았다 — 명세 `tmp/o213_y3c_sv_spec.tsv` 44건(dry-run 충돌 0) · build 후 생성기로 정본 쓰기 + 배포.
- 🔴 확정위반 1 = R1-7-9(heredoc 경유 명세 생성 · 빈 실행 · 영향 0).

### ▣ O213-D-1 🟠 남은 작업 — ㉠ 7차 잔여

| # | 할 일 | 비고 |
|---|---|---|
| 1 | 👤 dbt build(아래) → 신규 컬럼 비NULL 건수 검증 → SV 5종 배선(아래 명령) → 스모크 | ⏸ 정지점 |
| 2 | Y3-E·F·G·J·K dbt 적재(목록 = `GN_DW.OPS.O213_Y2_FINAL` 의 L·P · C·D 완료분 제외) | 다음 = E(발송) |
| 3 | 라벨 해소 잔여(행사 그룹 3 · 이전상태 · 약칭 코드) · S3 147건 판정 | O213-B-1 #3·#4 |
| 4 | Y4 Agent 도구 배선(SV_PAYMENT_BILLING_STATUS + 새 차원) → ADD VERSION | AGENT_MEMBER 우선 |
| 5 | Y5 스모크 · Y6 eval(과금) · OPS 임시 객체 DROP | 마지막 |

- dbt 명령(사용자 실행): `dbt build --select CRM_MEMBER+ --project-dir 10_dbt_pipeline`
  · 🔴 `+` 하류 = DIM_MEMBER 와 그 하류 WIDE·FACT 를 함께 다시 만든다(DIM_MEMBER 는 TRUNCATE+append).
- build 후 배선: `python3 tmp/o213_y3_sv_gen.py --spec /workspace/tmp/o213_y3c_sv_spec.tsv --apply` →
  `python3 tmp/o213_y3_deploy.py SV_MEMBER_EVENT SV_MEMBER_MONTHLY SV_SERVICE SV_EVENT_PARTICIPATION SV_RELATION_ACTIVITY`.

### ▣ O213-D-2 ⚪ 결정 완료(재론 금지)

- O213-A·B·C 결정 전건 유지 + 아래 추가:
- 특별관리(MM012)는 회원 세그먼트다 — 배선한다(O213-B 「운영 플래그 제외」 철회).
- 수신동의(복수 선택)는 항목별 BOOLEAN 으로 편다 · 구 체계 Y·N·0 은 NULL.
- 수신 플래그 10종은 SV_SERVICE 에만 · 특별관리2·양음력·관계는 SV_MEMBER_MONTHLY 에만 둔다(동의어 과밀 방지).

_Co-authored with CoCo_
