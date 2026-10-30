<!-- LLM-METADATA
doc_id: O272_PROD_LLM_PROMPT_MA_OFF
doc_role: 운영계(ZL50263) 저가형 LLM 새 세션 입력 프롬프트 — OPS·SILVER managed access 해제(52번) + Agent 도구 수 재조회
project: GN_DW (굿네이버스)
created: 2026-10-30
created_by: O272-B
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

# 운영계 LLM 새 세션 프롬프트 — O272 OPS·SILVER managed access 해제

> 사용법 = 「=== 프롬프트 시작 ===」부터 「=== 프롬프트 끝 ===」까지 복사해 **새 세션**에 붙여 넣는다.
> 근거 = 신규 개발계 TQ68205 재구축(2026-10-30) 결과 OPS·SILVER = NO(설계값) ⇒ 운영계 YES 는 드리프트 · 사용자 결정 = 51번 방식으로 해제.
> 개발계 사전 검증(TQ68205 · SANDBOX 임시 스키마) = 해제 실패 경로(YES 유지 · FUTURE 복원) · 성공 경로(NO · FUTURE 복원) · 재실행 멱등 · 특수 권한 8종 재부여 전건 성공.
> 참고 = 개발계 설계 상태의 FUTURE GRANT = SILVER 19건 · OPS 0건(운영계 건수는 다를 수 있다 — 기대값으로 쓰지 말고 백업 건수와 대조한다).

=== 프롬프트 시작 ===

너는 Snowflake 운영계(계정 ZL50263)의 작업 보조자다. 아래 단계를 **순서대로 하나씩** 한다. 모르면 멈추고 사람에게 물어라.

## 규칙

1. 한 단계가 끝나면 3줄 이내로 보고하고 「다음 단계 진행할까요?」라고 묻고 멈춘다. 「승인」·「진행」 전에는 다음으로 가지 않는다.
2. 이 프롬프트에 적힌 문장·스크립트만 실행한다. 그 밖의 GRANT·REVOKE·DROP·ALTER 는 하지 않는다.
3. dbt 명령은 실행하지 않는다. 파일 내용을 고치지 않는다.
4. 오류가 나면 재실행하지 말고 오류 원문을 보여주고 멈춘다.
5. 수치는 실행 결과 값만 쓴다. 「0건」은 정상 종료일 때만 「없다」로 보고한다(시간 초과·오류 = 「판정 불가」).
6. 🔴 이미 끝난 일을 다시 하지 마라 = 48번 · 49번 · 51번 · 47번 [D1]·[D2] · O271 프롬프트 단계 A~G.
7. 🔴 GOLD 는 이미 NO 다(51번) — 이 프롬프트는 GOLD 를 건드리지 않는다.

## 먼저 읽을 파일(처음부터 끝까지)

1. `05_SV-Agent_ai/52_FIX_PROD_MANAGED_ACCESS_OPS_SILVER_ZL50263.sql`
2. `05_SV-Agent_ai/05_22_SV_DDL_GA_DEMOGRAPHIC.sql` · `05_SV-Agent_ai/05_20_SV_DDL_GA_SESSION.sql`(단계 4-1)

> 🔴 사람이 먼저 할 일 = 개발계 O272-C 판 5개 파일을 운영계 워크스페이스로 옮긴다(덮어쓰기):
> `05_SV-Agent_ai/52_FIX_PROD_MANAGED_ACCESS_OPS_SILVER_ZL50263.sql` · `05_22_SV_DDL_GA_DEMOGRAPHIC.sql` · `05_20_SV_DDL_GA_SESSION.sql` ·
> `scripts/run_sql_file.py`(주석뿐 문장 건너뜀) · `scripts/sv_enum_newvalue_gate.py`(아포스트로피 값 오탐 제거 — 없으면 단계 4-1 조각 0/4 가 「I'm your pen」을 NEW 로 낸다)

읽은 뒤 「읽음: 3개 파일」이라고 보고하고 멈춘다.

## 단계 1 — 진단(읽기 전용)

- 52번 파일의 `[1]` SELECT 1문만 실행한다(ACCOUNTADMIN).
- 4행(GOLD · OPS · SERVING · SILVER)의 IS_MANAGED_ACCESS 를 그대로 보고한다.
- OPS·SILVER 가 이미 NO 면 「해제 불요」로 보고하고 단계 4 로 간다.

## 단계 2 — OPS 해제

- 52번 파일의 `[2]` 블록(`EXECUTE IMMEDIATE $$ … $$;` 1문)만 실행한다.
- 반환값 1줄을 그대로 보고한다. 기대 = `GN_DW.OPS DONE — 백업 n건`.
- `ABORT` 로 시작하면 멈춘다(FUTURE 는 블록이 이미 복원했다 · 고치려 하지 마라).

## 단계 3 — SILVER 해제

- 52번 파일의 `[3]` 블록 1문만 실행한다.
- 반환값 1줄을 그대로 보고한다. 기대 = `GN_DW.SILVER DONE — 백업 n건`.
- `ABORT` 로 시작하면 멈춘다.

## 단계 4 — 확인

- 52번 파일의 `[4-확인 a]` · `[4-확인 b]`(SELECT 1문 + SHOW 2문) · `[4-확인 c]` 를 순서대로 실행한다.
- 기대 = a 0행 · b 백업 건수 = 각 SHOW 행 수 · c 4행 전부 NO.
- 하나라도 다르면 결과 원문을 보여주고 멈춘다.

## 단계 4-1 — 🆕 [O272-C] SV 2종 재배포(COMMENT 값 목록 보강 · Agent 재버전 불요)

- 순서대로 1파일씩 실행한다. 각 파일 실행 후 출력 마지막 줄을 보고한다.
  ```
  python3 scripts/run_sql_file.py 05_SV-Agent_ai/05_22_SV_DDL_GA_DEMOGRAPHIC.sql --apply
  python3 scripts/run_sql_file.py 05_SV-Agent_ai/05_20_SV_DDL_GA_SESSION.sql --apply
  ```
- 기대 = 각 `10 succeeded, 0 failed`(개발계 TQ68205 실측). 실패 문장이 있으면 다음 파일로 가지 말고 멈춘다.
- 이어서 게이트 2조각을 실행한다. 기대 = 둘 다 마지막 줄 직전에 `NEW 0` · 종료코드 0.
  ```
  python3 scripts/sv_enum_newvalue_gate.py --shard 0/4
  python3 scripts/sv_enum_newvalue_gate.py --shard 1/4
  ```
- NEW 가 0 이 아니면 그 줄(SV · 차원 · 값)을 전부 보여주고 멈춘다(고치지 마라 — 운영계에만 있는 값일 수 있다).

## 단계 5 — 경영 Agent 도구 수 재조회(읽기 전용)

- 아래 2문을 실행한다(GN_DW_ADMIN).
  ```
  SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_EXECUTIVE;
  SELECT "name", "is_default",
         REGEXP_COUNT("agent_spec", 'tool_spec') AS TOOL_SPEC_CNT
  FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
  ORDER BY "created_on" DESC;
  ```
- default 버전의 이름과 TOOL_SPEC_CNT 를 그대로 보고한다.
- 개발계 TQ68205 값 = VERSION$4 · 17 · 종전 운영계 보고 = 19 ⇒ 두 값 중 어느 것과 같은지만 적는다(고치지 마라).

## 마지막 보고 형식

```
운영계 O272 managed access 해제 결과(ZL50263 · <날짜>)
1 진단(전): GOLD <값> · OPS <값> · SERVING <값> · SILVER <값>
2 OPS: <반환값>
3 SILVER: <반환값>
4 확인: 오류 <n>행 · OPS 백업 <n> = FUTURE <n> · SILVER 백업 <n> = FUTURE <n> · 4스키마 NO <예/아니오>
4-1 SV: 05_22 <성공/실패> · 05_20 <성공/실패> · enum 0/4 NEW <n> · 1/4 NEW <n>
5 AGENT_EXECUTIVE: default <버전> · tool_spec <n>
남은 일: <1~3줄>
```

=== 프롬프트 끝 ===

## 운영계 실행 결과(2026-10-30 · 사용자 제공) · 🆕 O273-A·E·F

| 단계 | 결과 | 후속 |
|---|---|---|
| 1 진단(전) | GOLD NO · OPS YES · SERVING NO · SILVER YES | — |
| 2·3 해제 | OPS DONE 백업 0 · SILVER DONE 백업 24 | — |
| 4 확인 | 오류 0 · 백업 = FUTURE(0 = 0 · 24 = 24) · 4스키마 NO | — |
| 4-1 SV | 05_22 · 05_20 각 10/10 · 조각 0/4 NEW 0 · **1/4 NEW 2** | O273-A(아래) |
| 5 Agent | EXECUTIVE default VERSION$20 · tool_spec 19 | O273-B(아래) |

- **O273-A — enum 신규값 2건(운영계에만 있는 값)**
  - `SV_GA_SESSION.DEVICE_OPERATING_SYSTEM` = `Firefox OS`·`Fuchsia`·`Win32` → `05_20` COMMENT 목록에 추가.
  - 같은 차원의 Android 빌드 지문 2건(`samsung/…:user/release-keys`)과 `EP_PAYMENT_TYPE` 빈 문자열 `''` → 게이트에서 대조 제외(`scripts/sv_enum_newvalue_gate.py` · 음성 테스트 3건 추가).
  - 개발계 재배포 10/10 · 게이트 4조각 NEW 0 · 운영계 재배포 10/10 · 1/4 NEW 0(사용자 보고).
- **O273-B — 경영 Agent default 고정**
  - 🔴 단계 5 의 기대 「개발계 VERSION$4 · 17」 은 **정답(O270 W3 = analyst_ad·시뮬레이터 제거)** 이었다. 운영계 19 는 드리프트다.
  - 원인(운영계 실측) = default 가 VERSION$20 에 고정돼 `ADD VERSION` 으로 만든 $21·$22·$23 이 default 가 되지 않았다(에러 없음).
  - 처방 = `05_SV-Agent_ai/53_FIX_PROD_AGENT_EXECUTIVE_DEFAULT_ZL50263.sql` [2] → `DONE — default = VERSION$23 (도구 17)`.
  - 재발 방지 = `tmp/o250/deploy_agents.py deploy` [5] 가 「default = 최신 명명 버전」 아니면 rc 1 · `09_2` [3] 주석 정정.
- **O273-C — 문서 정리** = `09_2` [0] 필수 목록의 EXECUTIVE–SV_AD·SV_ML_REALTIME_SIMULATOR 주석 처리 · `08_AGENT_spec.md` O270 정정.
- 남은 일 = `O272_롤전환_작업순서.md` 참고(운영계 O270 단계 6 게이트 재실행 · 사용자 배정 등).

_Co-authored with CoCo_
