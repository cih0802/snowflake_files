<!-- LLM-METADATA
doc_id: HANDOFF_O0183_C
doc_role: 인수인계 — 세션 `O183-C` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-28
created_by: O183-C
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0183-C -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O183-C-0 🔴🔴 먼저 알아라 — 자기검토가 확정한 것

| # | 판정식 | 근거(실측 · 2026-09-28 · xf98254) |
|---|---|---|
| ㉠ | **날짜 기준 규칙은 정본 문구와 대조하고, 후보별 위반 건수를 잰 뒤 고른다** | 최초가입일 = 「최초 개발일」 단독 ⇒ 청구 있는데 JOIN_DATE NULL 675,370 · 납입개월수 > 후원기간 80,976 |
| ㉡ | **부재 경로는 에러 없이 분모를 0 으로 만든다** | `99_provided_definition`(부재) 참조 7곳 · `doc_line_length_gate` 1패턴 분모 0 |
| ㉢ | **원장 행 삽입 앵커는 행 전체(행 끝 `\|` 까지)** | 접두 앵커로 O181 꼬리가 O182 행에 붙었다(즉시 복구) |

---

### ▣ O183-C-1 🟢 이 단위가 끝낸 것

- 트랜스크립트 추출 + 근거 파일 `tmp/_o183_review_evidence.tsv`(도구호출 125건)
- **모델 정정(재빌드 대기)**: `FACT_MEMBER_MONTHLY.member_first` = LEAST(등록일·최초 개발일·첫 청구월) · `PAID_MONTHS` 가입 이후만 ·
  `FACT_MEMBER_EVENT.member_first_dev` 같은 식(첫 청구월 산식 = FMM billing 과 동일)
- 문안 동기화: 06_DDL · 배포 스크립트 COMMENT · SV 05_1·05_2 NEW_EXISTING 문안 · DEC-55 표 + §55-E
- 생성기 경로 결함 7곳 정정(`gen_metric_gold_mapping`·`gen_code_system_gates`·`gen_concept_diagram`·`add_column_comments`·
  `field_mapping_override`·`doc_line_length_gate`·`mirror_from_stage.sh`) · `05_지표GOLD매핑` 재생성(측정일 2026-09-28)
- 원장: O175·O175-B 은퇴 → O182(누락 대리)·O183 행 등재 · 허브 재발행 4종 PASS · 세션이력 §O183 rollover 등재

---

### ▣ O183-C-2 🟠 다음이 할 일

| # | 항목 | 착수 정보 |
|---|---|---|
| **1** | 🔴 **사용자 `dbt build`** | `--select FACT_MEMBER_EVENT+` (FMM·FSE·WIDE 포함) · 정지점 `R4-1` |
| **2** | 🔴 빌드 후 재측정 | ① 납입개월수 > 후원기간+1 = **0** 기대 ② 청구 있는데 JOIN_DATE NULL = 대폭 감소 기대 ③ 행수 불변 |
| **3** | 🔴 라이브 반영 | `15_O183_…배포.sql` [2] COMMENT(JOIN_DATE·FME NEW_EXISTING 문안 변경분) · SV 05_1·05_2 재배포(문안 변경) |
| **4** | 🟠 WARN 21 확인 | accepted_values(CMPGN_TYPE1_NM) 해소 |
| **5** | 🟠 현업 확인 후보 | `FRST_REGIST_DT` 의미(첫 청구보다 늦은 회원 71,325) · D5 발송유형 필터(DEC-33 ①) |

- `-O0183-A` ▣2·`-O0183-B` ▣2·`-O0182-A` ▣2·▣3 은 그대로 유효(원장 행·이력 항목 항목은 **이 단위에서 종결**).

_Co-authored with CoCo_
