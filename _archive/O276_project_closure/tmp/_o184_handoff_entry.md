### ▣ O184-A-0 🟢 이 단위가 끝낸 것 (2026-09-28 · xf98254)

- **J3 재판정** — O183-D ▣1 16건 전수 착수 전 실측 · 닫힘 4 · 재분류 2(① 3건 기발행 · `DEC-44` 는 집행 대기)
- **SV_AD 문안 정정 → 라이브** — VIDEO 개발건 실재(8,756행)로 「VIDEO 구조적 부재」 철회 · 시간대 표기 2형식 · 재방유형 `재송출`/`방송`
  · Agent **EXECUTIVE·MARKETING VERSION$4** 발행(is_default 자동 · V3 롤백 보존) · `_wide_schema.yml` DVLP 4줄(🔴 build 후 반영)
- **P66 철회** — `08_AGENT_spec.md:298` · `09_2` 모순 주석 종결(실측 VERSION$4 자동 default)
- **`GN_DW_DBT` 라이브 전환** — 롤 + GRANT(07 RBAC `D.9`) + 소유권 이관 23 + `profiles.yml` 3 target
- **문서20 `N-23`** — `FRST_REGIST_DT` 71,325 신규 · §E 「행사 2건」 재발행 · §M-4 EMAIL/MSG_AT·SND 분할

---

### ▣ O184-A-1 🟠 미처리 작업 — 파이프라인 순 × 중요도

| 순 | 계층 | 중요도 | 작업 | 상태(O184 J3) | 정본 |
|---|---|---|---|---|---|
| 1 | 원천·현업 | 🔴 | 문서20 `N-23` ①②③ · §N-13(⑭) · §D-2/§N-17(BLOCKING-2) · §L(DEC-33) 회신 | 발행 완료 · **회신 대기** | 문서20 `-010` |
| 2 | 원천·현업 | 🟠 | 열린 문항 잔여 27건 `J3` 실측(판정식 = `**판정**` 줄의 `____`) | 미착수 | `-O0181-B` ▣2-2 |
| 3 | 권한 | 🔴 | ① **사용자 `dbt build`** 로 GN_DW_DBT 전환 검증 ② PASS 후 배포본 `DW_PIPELINE` 재배포 ③ ENGINEER 축소 | 롤·이관·profiles **완료** · build 대기 | 07 RBAC `D.9` |
| 4 | 운영 | 🔴 | `--vars` 실험 A·B(사용자 `dbt compile`) + 런북 2곳 정정 | 미착수(dbt 정지점) | `-O0181-A` ▣6 |
| 5 | SILVER | 🔴 | CRM 사업목표 배선 설계(원천 290 · `CRM_BIZ_TARGET`·`FACT_TARGET_PROJECT` 0행 실측) | 미착수 | `-O0182-A` ▣2-5 |
| 6 | SILVER | 🟠 | AGENCY 신규 컬럼 GOLD 승격 여부 | 요건 대기 | `-O0182-A` ▣2-4 |
| 7 | GOLD | 🟠 | `DEC-44` 편성 차수 키 집행(현업 질문 아님 · 결정 확정) | 미착수 | 문서30 §30-I |
| 8 | GOLD | ⚪ | 공란 잔여(캠페인·납입방식 키·인입콜·조직 계층) | 원천·결정 대기 | DEC-55 §55-C |
| 9 | GOLD | 🟡 | ONCE_CONVERSION 일시회원 속성 축 | 미착수 | `-O0182-A` ▣2-7 |
| 10 | SV | 🟡 | 비율 지표 공45~47·54~57·77~78 · VIDEO 방송 개발단가 metric(현업 정의 후) | 정의 대기 | `-O0183-A` ▣2-4 |
| 11 | Agent | 🟠 | AGENT_MEMBER V4 라우팅 스모크 `nl_routing_smoke.py` — 🔴 **LLM 과금 → 별도 승인**(`R4-4-3`) | 승인 대기 | 신규 |
| 12 | 품질 | 🟠 | 다음 build 에서 WARN 21 확인 + `_wide_schema.yml` DVLP 문안 라이브 COMMENT 반영 확인 | build 대기 | `-O0183-B` ▣1 |
| 13 | 문서 | 🔴 | 원장 `-002` 여유 **629 B** · 해소로그 7,134 B · 문서20 `-001` **301줄(기존 초과 · rollover 게이트6 FAIL)** — 은퇴/재균형 🔴 승인 대상 | 승인 대기 | doc_type_gate |
| 14 | 문서 | ⚪ | W3 결정 대기 8건 · B2~B12 · `sv_code_label_gate` 재측정 조건 | 변동 없음 | `-O0181-A` ▣3 |

🟢 닫힘(O184) = 구 ⑦ VIDEO 도달 재측정(SV 문안이 수치 없이 이미 정합) · 구 ⑩ SV_AD·Agent 문안 · 구 ⑬ P66 · 구 ① 중 기발행 3건.

---

### ▣ O184-A-2 ⏸ dbt 정지점 — 사용자 실행 명령 (`R4-1`)

```
dbt build --project-dir 10_dbt_pipeline
```
· 판정 = ERROR 0 · WARN 21(CMPGN_TYPE1_NM 해소) · 🔴 권한 오류(`insufficient privileges`·`must have OWNERSHIP`)가 나오면
  즉시 롤백 = `profiles.yml` role 3곳 → `GN_DW_ENGINEER` + `D.9 [2]` 역방향 이관
· 이어서(선택) `--vars` 실험 A = `dbt compile --select BIGQUERY_BASIC --vars '{"bigquery_lookback_days": 999}' --project-dir 10_dbt_pipeline`

---

### ▣ O184-A-3 📋 다음 세션 복붙 프롬프트

```
@(skill:init_ihcho) 1. 브리핑 생성 후 인수인계 99_NEXT_SESSION-O0184-A.md ▣1 표를 정본으로 삼는다.
2. 표의 각 항목을 착수 전에 J3 실측으로 재판정한다(이미 닫힌 것은 닫힘으로 표기 · 정본 좌표도 실재를 확인한다).
3. 먼저 ▣2 의 dbt build 결과(사용자 붙여넣기)를 해석해 3·12행을 판정한다(FAIL 이면 롤백부터).
4. 파이프라인 순(원천→권한→SILVER→GOLD→SV→Agent→문서)으로, 같은 계층은 🔴→🟠→🟡→⚪ 순으로 진행한다.
   - 현업 회신이 필요한 것은 문서20 에 이미 있는지 먼저 grep 하고, 없는 것만 발행한다.
   - 권한 변경·라이브 DDL/SV/Agent 배포는 승인된 것으로 처리하되 SQL 을 먼저 보여주고 재조회로 확인한다.
   - LLM 과금(스모크)·은퇴/재균형은 별도 승인을 받는다(R4-4-3). dbt 명령은 제시 후 대기한다(R4-1).
5. 각 단위 종료 시 원장 행 · 세션이력 · 인수인계 라벨 파일을 갱신하고 게이트(gate_census --final · doc_census · index_row_gate · line_len)를 통과시킨다.
6. 끝나면 남은 작업을 같은 형식(파이프라인 순 × 중요도 표 + 복붙 프롬프트)으로 정리한다.
```

_Co-authored with CoCo_
