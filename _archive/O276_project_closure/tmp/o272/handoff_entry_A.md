## ▣ O272-A-0 🔴 먼저 알아라

- 신규 개발계 TQ68205(2026-10-30 · TRIALADMIN) = GN_DW 신규 구축 + 운영계 O271 잔여단계 A~G 리허설 완료.
- 구축 = `문서실행순서.md` 개발계 1~59 · 적재 80 테이블(A.1 (4) 불일치 0 · ML VARIANT 5종 OBJECT · SILVER ITEMS ARRAY).
- dbt = 사용자 실행(parse·compile·seed·build·범위 지정 build) · [3-3-a] 일자 34 = 34 = 34 = 34 · [3-3-b] 감시 3종 0행.
- MSTR 06 = 202401~202610 34개월 전건 OK · SV 45종 · Agent 3종 owner GN_DW_ADMIN · 48번 193문 성공.
- 운영계 대조 정본 = 사용자 이력 `999_temp.txt`(운영계 ZL50263 A~G 진행 기록 · 2026-10-30).

## ▣ O272-A-1 리허설 결과(개발계 TQ68205 ↔ 운영계 ZL50263)

| 단계 | 개발계 TQ68205 | 운영계 | 판정 |
|---|---|---|---|
| A 47 [D2] | mcc 17087303103.81 · fap 17087303103.8362 · 1121행 | 같음 | 일치 |
| B SV 4종 | 10 · 15 · 10 · 8 succeeded · 0 failed | 같음 | 일치 |
| C 잔존 SV·뷰 | 신규 구축에 부재 ⇒ DROP 불요 · GOLD·SERVING 109건 DIFF_RC=0 | DROP 후 109건 | 일치 |
| D Agent | MEMBER 31 · EXECUTIVE 17 · MARKETING 33(VERSION$4) | 31 · 19 · 33 | 🟠 EXECUTIVE 불일치 |
| E 코퍼스 | [0] 8행 · [1] 8행 · NOT_MARKETING 0 | 같음 | 일치 |
| F 게이트 | `--live` PASS 154객체 · 음성 PASS | 같음 | 일치 |
| G 앱 | GN_DW_APP_OWNER 생성(owner SECURITYADMIN) · Streamlit 0 | 14개 | 개발계 재현 불가 |

## ▣ O272-A-2 발견(문서·도구 반영 대기)

- ㉠ `scripts/run_sql_file.py` 가 접속 직후 `USE DATABASE GN_DW` 를 실행 ⇒ 신규 계정 1번에서 002043.
  - 처방(이번 집행) = 07 의 `CREATE DATABASE IF NOT EXISTS GN_DW` 1문을 선실행 후 재실행.
  - 후속 = 도구가 DB 부재 시 USE 를 건너뛰게 고치거나 `문서실행순서.md` 개발계 1번에 주석.
- ㉡ `문서실행순서.md` 개발계 1~59 에 48번이 없다 ⇒ 16번 `05_MSTR_SV_DDL.sql` stmt 7 이 002003(GN_DW_AR_SRC_COMMON 부재).
  - 처방(이번 집행) = 48번 [1](역할 생성)을 16 앞에 · 48번 전체([2]·[3])를 59 뒤에 실행.
  - 후속 = 개발계·운영계 순서표에 「15-1 = 48 [1]」·「60 = 48 전체」 추가.
- ㉢ OPS·SILVER managed access = 신규 구축 결과 NO(설계값) ⇒ 운영계 YES 는 구축 후 드리프트로 확정.
- ㉣ 51번 [3] 실패 경로 음성 테스트 = SANDBOX 임시 스키마에서 집행 · 해제 실패 시 FUTURE 2건 복원 · 성공 경로 NO · 2건 복원 · 임시 스키마 DROP.
- ㉤ D 의 AGENT_EXECUTIVE tool_spec 17(개발계) ≠ 19(운영계 보고) · 스펙 크기 81408 은 양쪽 같다.
  - 후속 = 운영계 `SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_EXECUTIVE` 의 default agent_spec 재조회.
- ㉥ 07 C_CONSUMER · 08_After_Deploy_DBT 마지막 문장 = 주석뿐인 꼬리 블록 ⇒ `run_sql_file` 이 000900 으로 1 failed 를 낸다(실제 실패 아님).

## ▣ O272-A-3 ㉠ 이 작업의 잔여

| 순 | 작업 | 정지점 |
|---|---|---|
| ① | 운영계 AGENT_EXECUTIVE tool_spec 재조회(㉤) | 운영계 |
| ② | 순서표 보강(㉡) · `run_sql_file.py` 신규 계정 대응(㉠) | 🔴 사용자 승인 |
| ③ | OPS·SILVER managed access 해제 여부(㉢ · 51번 방식) | 🔴 사용자 결정 |
| ④ | 50번 [2-b]·[3]~[5] · 배정표 「확정」 → 50번 [6] | 👤 운영계 · 사용자 |
| ⑤ | 신규 개발계 daily Task 는 생성·RESUME 상태(03 그대로) · 과금 확인 | 👤 사용자 |
