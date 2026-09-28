<!-- LLM-METADATA
doc_id: HANDOFF_O0183_D
doc_role: 인수인계 — 세션 `O183-D` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-28
created_by: O183-D
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0183-D -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O183-D-0 🟢 이 단위가 끝낸 것 (2026-09-28 · xf98254)

- 사용자 `dbt build --select FACT_MEMBER_EVENT+` = PASS 92 · WARN 1 · ERROR 0 · TOTAL 93
- 재측정: 납입개월수 > 후원기간 **80,976 → 0** · 청구 있는데 JOIN_DATE NULL **675,370 → 0** · 행수 불변(FMM 41,508,824 = 키 유일 · FME 4,716,088 · FSE 41,935,344)
- 라이브 COMMENT 2건(FMM.JOIN_DATE · FME.NEW_EXISTING_FLAG) · SV 2종(SV_MEMBER_MONTHLY·SV_MEMBER_EVENT) 재배포 · 스모크 SV==팩트
- 1회성 배포 스크립트 이관 = `05_SV-Agent_ai/_archive/15_O183_GOLD공란채움_배포.sql`(A·B·C 라벨 파일의 옛 경로는 이력이므로 고치지 않는다)
- DDL 정본: `03_top-down_gold/06_DDL.sql` = O183 COMMENT 반영 완료 · `04_silver_design/08_SILVER_테이블DDL` = SILVER 구조 변경 없음(무변경이 정답)

---

### ▣ O183-D-1 🟠 미처리 작업 — 파이프라인 순 × 중요도

| 순 | 계층 | 중요도 | 작업 | 정본 |
|---|---|---|---|---|
| 1 | 원천·현업 | 🔴 | 현업 회신 묶음: `FRST_REGIST_DT` 의미(첫 청구보다 늦은 회원 71,325) · D5 발송유형(DEC-33 ①) · ⑭ 다중사업 · DEC-44 ERP 차수 · BLOCKING-2 | DEC-55 §55-B·E · 문서20 |
| 2 | 원천·현업 | 🟠 | 열린 문항 잔여 27건 `J3` 실측 · §E 재발행 · §M-4 분할 발행 | `-O0181-B` ▣2-2~4 |
| 3 | 권한(dbt) | 🔴 | `GN_DW_DBT` 전용 롤 신설 → profiles 전환 → ENGINEER 축소 | `-O0182-A` ▣6 |
| 4 | 운영 | 🔴 | `--vars` 판별 실험 A·B(사용자 실행) + 런북 2곳 정정 | `-O0181-A` ▣6 |
| 5 | SILVER | 🔴 | CRM 신규 3종 배선 설계(사업목표 290행 → `CRM_BIZ_TARGET`·`FACT_TARGET_PROJECT`) | `-O0182-A` ▣2-5 |
| 6 | SILVER | 🟠 | AGENCY 신규 컬럼 GOLD 승격 여부(DGT·REBRDC·VIDEO) | `-O0182-A` ▣2-4 |
| 7 | GOLD | 🟠 | VIDEO 캠페인 축 도달률 재측정 | `-O0182-A` ▣2-3 |
| 8 | GOLD | ⚪ | 공란 잔여(캠페인·납입방식 키·인입콜·조직 계층 등) — 원천·결정 도착 시 | DEC-55 §55-C |
| 9 | GOLD | 🟡 | ONCE_CONVERSION 잔여(일시회원 속성 축) | `-O0182-A` ▣2-7 |
| 10 | SV | 🔴 | SV_AD·AGENT_EXECUTIVE·AGENT_MARKETING 문안 정정(원천 재편으로 거짓이 된 서술) | `-O0182-A` ▣2-2 |
| 11 | SV | 🟡 | 비율 지표 공45~47·54~57·77~78(분모 조합 정의 후 metric 추가) | `-O0183-A` ▣2-4 |
| 12 | Agent | 🟠 | AGENT_MEMBER VERSION$4 신규 metric 자연어 라우팅 스모크(`nl_routing_smoke.py`) | 신규 |
| 13 | Agent | 🟡 | `cortex-project.yaml` 24행 P66 기재 철회(ADD VERSION 은 자동 default) | `-O0182-A` ▣2-6 |
| 14 | 품질 | 🟠 | 다음 전체 build 에서 WARN 21 확인(CMPGN_TYPE1_NM 해소) · 잔여 원천 품질 WARN 추적 | `-O0183-B` ▣1 |
| 15 | 문서 | 🟠 | 여유 경고: 원장 `-002` 1,065 B · 해소로그 꼬리 7,134 B(<20%) — 꼬리 신설/롤오버 | doc_type_gate |
| 16 | 문서 | ⚪ | W3 결정 대기 8건 · B2~B12 · `sv_code_label_gate` 재측정 조건 | `-O0181-A` ▣3 · `-O0181-B` ▣2-6 |

---

### ▣ O183-D-2 📋 다음 세션 복붙 프롬프트

```
@(skill:init_ihcho) 1. 브리핑 생성 후 인수인계 99_NEXT_SESSION-O0183-D.md ▣1 표를 정본으로 삼는다(A·B·C·D 전건 읽기).
2. 표의 각 항목을 착수 전에 J3 실측으로 재판정한다(이미 닫힌 것은 닫힘으로 표기).
3. 파이프라인 순(원천→권한→SILVER→GOLD→SV→Agent→문서)으로, 같은 계층은 🔴→🟠→🟡→⚪ 순으로 진행한다.
   - 현업 회신이 필요한 것(1·2)은 질의 문안만 문서20 에 발행하고 다음 항목으로 넘어간다.
   - 권한 변경(3)·라이브 DDL/SV/Agent 배포는 승인된 것으로 처리하되 SQL 을 먼저 보여주고 실행 결과를 재조회로 확인한다.
   - dbt 명령은 실행하지 말고 명령을 제시한 뒤 대기한다(R4-1).
4. 각 단위 종료 시 원장 행 · 세션이력 · 인수인계 라벨 파일을 갱신하고 게이트(gate_census --final · doc_census · index_row_gate · line_len)를 통과시킨다.
5. 끝나면 남은 작업을 같은 형식(파이프라인 순 × 중요도 표 + 복붙 프롬프트)으로 정리한다.
```

_Co-authored with CoCo_
