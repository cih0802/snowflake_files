<!-- LLM-METADATA
doc_id: HANDOFF_O0267_A
doc_role: 인수인계 — 세션 `O267-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-28
created_by: O267-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0267-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O267-A-0 🔴 먼저 알아라

- `O267` = O266-D-1 착수표 ①②③ + O266-E-2 백로그 ①③ 집행(2026-10-28 · TRIALADMIN · ZS83821 개발계 · ㉡). A~E 중복 행은 D-1 + E-2 기준으로 통합했다.
- 🔴 운영계(ZL50263)는 여전히 기존 환경 갱신 43~55 미반영 — 현업은 운영계에서 테스트하므로 회신 발송은 반영 후가 맞다(사용자 몫).

### ▣ O267-A-1 결과

| 순 | 작업 | 결과 |
|---|---|---|
| ① | 회신문 2통 | `98_현업요청인수인계/20261028_김나경_알림톡열람_발송구분_회신.md` · `20261028_강지영_발송이력_알림톡클릭_회신.md` — 질문별 · 원리만 · 수치 0 · 「개발계/운영계」 0회(grep) · #160·#161 값 증가 공지 포함 |
| ② | 요청 목록 3종 | md·csv·xlsx 에 13~15행(`O265-1` 김나경 · `O265-2` 강지영 · `O266-1` 마케팅 1~4) · 3종 기계 대조 일치 · xlsx Sheet1 병합 셀 아래로 3행 이동 · 원본 셀 전수 대조 유실 0 · 도구 = `tmp/o267/add_list_rows.py`(멱등) |
| ③ | 템플릿 정보 질문 | `AGENT_MEMBER`(SV_SERVICE) — 템플릿 ID `AT006040` → `template_id` 필터 · 링크 `utm_campaign=25acpi_om_gift` → `utm_campaign` 필터 · 둘 다 `FACT_AT_GA_CLICK` · `days_from_send 0~5` · 원문 = `tmp/o267/agent_test/T1·T2` |
| ④ | §2.13 누락 6열 | `UPPER_CAMPAIGN_CD`·`UPPER_CAMPAIGN_NM`·`CMPGN_TYPE1_BSN_NM`·`CMPGN_TYPE2_BSN_NM`·`CMPGN_TY_NM`·`LAST_STMT_AMT`(라이브 COMMENT 원문) · `verify_wide_doc.py` rc=0(733열 · 불일치 0) |
| ⑤ | `test_rename_stale_gate.py` | timeout 600 · rc=0 · 축 17개 전건 통과(`tmp/o267/test_rename_stale_gate.out`) |

### ▣ O267-A-2 ㉠ 이 작업의 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 👤 운영계 반영 = 기존 환경 갱신 43~55 → `sv_enum_newvalue_gate --shard k/4` 4회 → Agent 재현 | 사용자 |
| ② | 👤 회신 발송 3통(김나경 · 강지영 · 마케팅) · 제작비 세세목 목록 요청 | 사용자 |
| ③ | 현업 회신 대기 = AT006038·AT006040 행운의 카드 여부 · 하위 페이지 포함 · 웹팀 리다이렉트 대상표 | 회신 대기 |
| ④ | 운영계 반영 후 `60_repeat_어카운트시작/13_운영계_반영_20261005이후.md` §13 에 43~55 행 | ① 후 |
| ⑤ | 🆕 `01_세션이력` O267 항목 롤오버 = `split_doc.py 20_issue/01_세션이력.md --rollover --entry-file tmp/o267/history_O267.md` | R4-4-3 승인 대기 |

### ▣ O267-A-3 🆕 새로 발견

- ③ 두 질문 모두 1차 `system_execute_sql` 이 오류 → 별칭을 바꿔 재실행해 성공. 그 사이 모델 중간 텍스트 「Use logical dimension names.」 가 최종 답변 앞에 붙어 노출됐다(원문 JSON 의 text 블록 · 소스 grep 0건). O266 4문항(AGENT_MARKETING)에는 없었다 ⇒ SV_SERVICE 의 `atclk` 논리 열 이름 사용 문제로 추정 — 미규명.
- ③ 같은 템플릿을 ID 로 물은 값과 utm 으로 물은 값이 다르다(T1 ↔ T2) — 템플릿 귀속(MANUAL 매핑) 범위와 utm 원값 범위가 다르기 때문으로 보이나 미대사.
- `/workspace` 마운트에서 openpyxl `wb.save()` 가 zip seek 미지원으로 실패하고 대상 파일을 손상시킨다 ⇒ `/tmp` 에 저장 후 복사(이번에 백업 복원 · 해시 원본 일치 확인).
- `현업요청인수인계목록.csv` 는 CP949 라 `line_len.py` 가 「UTF-8 손상」으로 FAIL 한다(원본도 동일 · 최대 488자).

### ▣ O267-A-4 ㉡ 워크스페이스 백로그

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 기지 실패 2종 결정(`test_mutating_tool_safety` · `test_pipeline_erd`) | 사용자 결정 |
| ② | A-3 의 중간 텍스트 노출 · T1↔T2 차이 규명(SV_SERVICE `atclk` 열 이름 · 매핑 범위) | 미착수 |
| ③ | `line_len.py` 의 CP949 csv 처리 방식 결정(면제 또는 인코딩 인자) | 미착수 |

_Co-authored with CoCo_
