<!-- LLM-METADATA
doc_id: HANDOFF_O0213_E
doc_role: 인수인계 — 세션 `O213-E` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-08
created_by: O213-E
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0213-E -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## O213-E 인수인계 (Y3-C 라이브 · Y3-E 발송 축 dbt 정지점)

### ▣ O213-E-0 🔴 먼저 알아라 (2026-10-08 · nj58180 · ㉡ 적용 · 승인 일괄 · 확정위반 0)

- 🟢 Y3-C 라이브 = DIM_MEMBER +28 데이터 적재 확인 · SV 5종 44차원 배포 · 스모크 44/44.
- 🟢 Y3-E 물리 반영(ALTER · 데이터는 build 후) = SILVER `CRM_SEND_REQUEST` +2 · `CRM_SEND_MEMBER` +4 · GOLD `DIM_SEND_REQUEST` +9 · `FACT_MESSAGE_DISPATCH` +4.
- 🔴 SV_SERVICE 에 `DIM_SEND_REQUEST` 를 **새로 연결**한다(GOLD 기존 · SV 미연결이던 S3) — 블록 `tmp/o213_y3e_sv_blocks.sql` 은 생성기 범위 밖(edit 로 반영).
- 🔴 보류 3컬럼(문자 대상 후원구분·중단채널·결연중단유무 코드 혼재) = 문서20 N-29 ⑤.

### ▣ O213-E-1 🟠 남은 작업 — ㉠ 7차 잔여

| # | 할 일 | 비고 |
|---|---|---|
| 1 | 👤 dbt build(아래) → 신규 컬럼 비NULL 검증 → 05_4 에 TABLES·RELATIONSHIPS 블록 반영 → 생성기 14건 → 배포 → 스모크 | ⏸ 정지점 |
| 2 | 남은 도메인 = F GA4/검색 30 · K 조직/예산/목표 15 · G 광고 13 · J 결연 3 · I 행사 1(목록 = `OPS.O213_Y2_FINAL` L·P) | 다음 = F |
| 3 | 라벨 해소 잔여(행사 그룹 3 · 이전상태 · 약칭 코드) · S3 잔여 판정 | |
| 4 | Y4 Agent 도구 배선 → ADD VERSION · Y5 스모크 · Y6 eval · OPS 임시 객체 DROP | 마지막 |

- dbt 명령(사용자 실행): `dbt build --select CRM_SEND_REQUEST+ CRM_SEND_MEMBER+ --project-dir 10_dbt_pipeline`

### ▣ O213-E-2 ⚪ 결정 완료(재론 금지)

- O213-A~D 결정 전건 유지 + 아래 추가:
- 발송 요청 속성은 FACT 에 degen 하지 않고 DIM_SEND_REQUEST 를 SV 에 연결해 노출한다(DEC-58 유지).
- 문자 발송 시점 회원 스냅샷 4종은 FMD degen(SND 전용 · FRST_BRND 관례).
- 라벨 없는 숫자 코드(MSG_TYPE·REGULARLY·PERIODIC)는 노출하지 않는다.

_Co-authored with CoCo_
