# N07-03 · Semantic View · Cortex Agent 작성 규칙

> doc_id: N07 · as_of: 2026-10-20 · 원본 = GN_DW `05_SV-Agent_ai/` · `85_…/A5_Agent_SV_개발자가이드.md` · DEC-49 · DEC-52

## 1. Semantic View

| 규칙 | 이유 |
|---|---|
| SV 1개 = 파일 1개(`05_<nn>_SV_DDL_<주제>.sql`) · 파일 끝에 GRANT 블록 | SV 는 FUTURE GRANT 가 없다 — 파일을 다시 돌리면 권한까지 복구된다 |
| `CREATE OR ALTER SEMANTIC VIEW` · `CREATE OR REPLACE` 금지 | REPLACE 는 GRANT 를 지운다 |
| base 는 GOLD(또는 SERVING 뷰)만 | 소비 계층이 하위 계층을 직접 보지 않게 |
| metric 이름 = 업무 용어 · synonym 에 현업 표현 · COMMENT 에 단위·분모·주의 | Agent 가 이름과 설명으로 도구를 고른다 |
| 「건」과 「명」을 다른 metric 으로 | 플래그 합을 「명」으로 오독하는 사고가 가장 흔했다 |
| 비율 metric 은 분자·분모를 같은 모집단으로 · 기간 스코프 필수 | 기간 없는 비율은 왜곡된다 |
| VQR(검증 질의)은 자주 묻는 질문만 · 별칭은 한글 · 반올림 명시 | VQR 은 그대로 답으로 쓰인다 |
| 값이 아직 없는 컬럼은 SV 에 노출하지 않는다(빈 틀 금지) | `0` 을 실적으로 읽는다 |

### COMMENT 4블록 (DEC-52)

```
[Grain] 회원 × 월
[지표] 회비 납입액 ÷ 회비 청구액 × 100 (기부금 제외)
[주의] 기간을 지정하지 않으면 전 기간 비율이다
[원천] <원천 시스템>.<원천 테이블>
```

## 2. Cortex Agent

| 규칙 | 이유 |
|---|---|
| 정본 = `cortex_project/agents/<AGENT>/agent_spec.yaml` | 화면에서 고친 내용은 다음 배포에 사라진다 |
| 최초 = 껍데기 생성(소유·USAGE·CoWork 등록) → 본문 = `ALTER AGENT … ADD VERSION FROM @stage` | `CREATE OR REPLACE AGENT` 는 버전을 지운다 · 껍데기만 두면 도구 0개 |
| 🔴 참조할 SV 를 **모두 만든 뒤** 버전을 올린다 | 없는 SV 를 가리킨 도구는 죽은 채로 버전이 굳는다 |
| 버전업 전에 현재 기본 버전 번호를 기록 | 롤백 = `ALTER AGENT … SET DEFAULT_VERSION = 'VERSION$n'` |
| 응답 규칙(추정치 표기 · 데이터 없음 문구 · 대체 축 제안)은 instruction 에 | SV 로는 강제되지 않는다 |
| COMMENT 에 「소관 SV n종」처럼 수를 적지 않는다 | spec 이 바뀌면 바로 낡는다 — 수는 spec 을 파싱해 센다 |
| 버전업 후 스모크 질문 3~5개(사람이 CoWork 화면에서) | 자동 eval 은 과금 · 승인 후 |

## 3. 지표 사전(RAG)

- 현업 지표 정의 원문 → 정제 csv → Cortex Search 서비스. 원문이 바뀌면 csv 를 생성기로 다시 만든다(손으로 고치지 않는다).
- 원문 항목 수와 코퍼스 항목 수를 등식으로 검증한다 — 빠진 항목이 생기면 원인을 기록한다(GN_DW DR-27).

_Co-authored with CoCo_
