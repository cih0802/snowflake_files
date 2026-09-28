<!-- LLM-METADATA
doc_id: HANDOFF_O0183_B
doc_role: 인수인계 — 세션 `O183-B` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-28
created_by: O183-B
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0183-B -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O183-B-0 🟢 이 단위가 끝낸 것 (O183-A 후속 · 라이브 반영 완료 · 2026-09-28 · xf98254)

- 사용자 `dbt build` = PASS 542 · WARN 22 · ERROR 0 · TOTAL 564
- [1] 재계측: 배선 대상 전 컬럼 채움 확인 · 행수 불변(FMM 행수 = 키 유일 수)
- [2] 라이브 COMMENT 13건 적용(FMM 12 · FME 1)
- [3] SV 4종 라이브 배포(`CREATE OR ALTER` · 소유자 GN_DW_ADMIN 유지 · GRANT 재확인)
- [4] `AGENT_MEMBER` VERSION$4 발행 → is_default=true(자동) · 롤백용 VERSION$3 보존
- [5] 스모크 3종 SV == 팩트 합계 일치(FMM 미납(건) · FSE D5 중단 · FEA 확정인원)

### ▣ O183-B-1 🟠 WARN 22건 분류 (= O182 기준선과 건수 동일 · O183 배선 컬럼에 걸린 테스트 0)

| 분류 | 건 | 처분 |
|---|---|---|
| 원천 참조무결성 고아(relationships) | 10 | 원천 품질 — 기지 고아 · 현업/원천 정정 대기 |
| 원천 NULL(not_null) | 6 | 원천 결손 — 예: 미납(F) 청구행 결과코드 NULL 1,135 |
| ERP 예산 grain·차수 병합 | 3 | DEC-44 현업 회신 대기(차수 중복계상) |
| BigQuery 적재 공백 | 1 | 입고 공백 감시(의도된 경보) |
| FEA PART_STATUS 오염값 `)` | 1 | 의도된 검출(O59-G) |
| CRM_CAMPAIGN.CMPGN_TYPE1_NM accepted_values | 1 | 🟢 **테스트가 낡았다** — 원천에 `전체사업` 실재 ⇒ 허용값 추가(`_crm_schema.yml`) · 다음 build 에서 WARN 21 기대 |

🔴 판정식 = WARN 은 「배선 미완」이 아니라 **severity: warn 으로 둔 원천 품질 감시**다. error 승격은 원천 정정 후.

### ▣ O183-B-2 🟠 다음이 할 일

- 다음 `dbt build` 에서 WARN 21 확인(accepted_values 1건 해소)
- `-O0183-A` ▣2 의 3~6 과 `-O0182-A` ▣2·▣3 은 그대로 유효
- FEA 누적 횟수 최대값이 큰 회원(1명 13개 행사 반복 참여 수천~만 행)은 원천 특성 — 반복형 이벤트 여부 현업 확인 후보

_Co-authored with CoCo_
