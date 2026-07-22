<!-- LLM-METADATA
doc_id: SV_AGENT_PAID_TEST_GUIDE
doc_role: paid 계정 이관 후 Agent NL 테스트 실행 가이드 (독립 실행 가능)
project: GN_DW (굿네이버스)
created: 2026-07-22
depends_on: 10_SI연결_검증.md(§3 스모크 정본), 09_AGENT_spec_구현.sql([6] 체크리스트), 07_평가셋_eval.md(ground truth)
scope: 트라이얼→paid 이관 후, Agent 2개의 자연어 품질 검증 단독 실행용
END-METADATA -->

# 12. Paid 계정 테스트 실행 가이드

> **목적**: 트라이얼에서 차단된 `DATA_AGENT_RUN`을 paid 계정에서 실행하여 Agent 2개의 **NL→SQL 정확도·가드레일**을 검증한다.
> **선행**: `02_SERVING_setup.sql` → `05_SV_DDL.sql` → `09_AGENT_spec_구현.sql` 순차 실행 완료(Agent 2 + CoWork 연결 상태).
> **소요**: ~30분(22문항 수동 질의·판정).

---

## 0. 사전 확인 (paid 이관 직후)

```sql
-- Agent 존재 확인
SHOW AGENTS IN SCHEMA GN_DW.SERVING;  -- 2행(AGENT_MEMBER, AGENT_OVERALL)

-- CoWork 연결 확인
SHOW AGENTS IN SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;  -- 2행

-- Agent 소유권 확인
SHOW GRANTS ON AGENT GN_DW.SERVING.AGENT_MEMBER;   -- OWNERSHIP=GN_DW_ADMIN + USAGE×3
SHOW GRANTS ON AGENT GN_DW.SERVING.AGENT_OVERALL;
```

**문제 시 복구**: Agent가 없거나 owner가 다르면 `09_AGENT_spec_구현.sql`의 [1]~[4]를 재실행.

---

## 1. 테스트 방법 (택1)

| 방법 | 명령 | 비고 |
|---|---|---|
| **A. CoWork UI** | https://ai.snowflake.com 접속 → 채팅 질의 | 가장 쉬움, 답변+SQL 확인 |
| **B. SQL 직접 호출** | 아래 `DATA_AGENT_RUN` 구문 | 프로그램적 회귀 가능 |

```sql
-- 방법 B 예시 (AGENT_MEMBER)
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'GN_DW.SERVING.AGENT_MEMBER',
  {'messages':[{'role':'user','content':[{'type':'text','text':'2024년 납부율은?'}]}]}
);
```

---

## 2. 정확도 테스트 — AGENT_MEMBER (9문항)

> PASS 기준: ① 올바른 SV 라우팅 ② 값 일치(정수 동일, 비율 ±0.01%p)

| # | 질문 (그대로 입력) | 기대 SV | 기대값 | 판정 |
|---|---|---|---|---|
| M3 | 2024년 납부율은? | SV_MEMBER_MONTHLY | **93.86%** | ⬜ |
| M4 | 연도별 납부율 추이(2023~2025) | SV_MEMBER_MONTHLY | 93.66 · 93.86 · 93.98% | ⬜ |
| M5 | 회원구분별 납입회비 총액 | SV_MEMBER_MONTHLY | 1=756.64B · 2=132.14B · 3=6.36B | ⬜ |
| M9 | 전체 개발건수와 중단건수 | SV_MEMBER_MONTHLY | 3,594,843 / 1,038,262 | ⬜ |
| E2 | 개발 고유 회원수 | SV_MEMBER_EVENT | **1,585,949** | ⬜ |
| E4 | 전이유형별 건수와 회원수 | SV_MEMBER_EVENT | 개발 3,594,843/1,585,949 · 중단 1,038,262/903,064 | ⬜ |
| S1 | 전체 발송수 | SV_SERVICE | **38,470,780** | ⬜ |
| S3 | 채널별 발송수 | SV_SERVICE | MSG_AT 20.56M · SND 8.30M · EMAIL 7.81M · PSTMTR 1.79M | ⬜ |
| P3 | 행사종류별 참여자수 | SV_EVENT_PARTICIPATION | EVENT 718,438 · (Unknown) 263,611 · CRMN 152,077 | ⬜ |

## 3. 정확도 테스트 — AGENT_OVERALL (5문항)

| # | 질문 (그대로 입력) | 기대 SV | 기대값 | 판정 |
|---|---|---|---|---|
| B1 | 전체 편성예산은? | SV_BUDGET | **503,070,876,000** | ⬜ |
| B2 | 전체 집행예산(ERP)은? | SV_BUDGET | **199,287,107,812** | ⬜ |
| B3 | 전체 집행율은? | SV_BUDGET | **39.61%** | ⬜ |
| B4 | 예산구분별 편성·집행·집행율 | SV_BUDGET | 지출 254.06B/80.49B/31.68% · 수입 249.01B/118.79B/47.71% | ⬜ |
| O1 | 전사 납입회비 총액은? | SV_MEMBER_MONTHLY | **895,178,309,108** | ⬜ |

## 4. 가드레일 테스트 (8문항)

> PASS 기준: 비활성 지표를 **임의 산출하지 않고** "Phase-2 제공 예정" 또는 유사 안내를 반환

| # | 질문 (그대로 입력) | Agent | 기대 행동 | 판정 |
|---|---|---|---|---|
| M10ⓖ | 캠페인별 납부율 알려줘 | MEMBER | "캠페인FK 미적재 → Phase-2" 안내 | ⬜ |
| M11ⓖ | 활동회원수(월말 활동회원)는? | MEMBER | "ACTIVE_CNT 미적재 → Phase-2" 안내 | ⬜ |
| E5ⓖ | 평균 유지기간(가입~중단)은? | MEMBER | "페어링 불가 → Phase-2" 안내 | ⬜ |
| S5ⓖ | 발송 성공률(수신율)은? | MEMBER | "SUCCESS/FAIL 미적재 → Phase-2" 안내 | ⬜ |
| P5ⓖ | 캠페인별 참여자수 | MEMBER | "CAMPAIGN_SK 미적재 → Phase-2" 안내 | ⬜ |
| B5ⓖ | 캠페인별 ROI(개발단가) | OVERALL | "비용·연계 미적재 → Phase-2" 안내 | ⬜ |
| G-납부율 | 납부율 알려줘 | MEMBER | 무필터 단정 금지 → 기간 스코프 재해석 | ⬜ |
| G-Unknown | 행사명별 참여자수 | MEMBER | 미매핑 ~23% 커버리지 고지 | ⬜ |

---

## 5. 판정 & 후속 조치

### 전체 PASS 시
- `10_SI연결_검증.md §3` 판정표에 ✅ 기입 → 검증 완료 상태로 전환.
- (권장) VQR 등록(`06_검증쿼리_VQR.md §3`) → Analyst 정확도 추가 스티어링.
- (선택) Agent 표시명 설정:
```sql
ALTER AGENT GN_DW.SERVING.AGENT_MEMBER  SET PROFILE = '{"display_name":"회원 분석","color":"#29B5E8"}';
ALTER AGENT GN_DW.SERVING.AGENT_OVERALL SET PROFILE = '{"display_name":"전사·예산 분석","color":"#11567F"}';
```

### FAIL 시 대응표
| 증상 | 원인 | 조치 |
|---|---|---|
| SV 라우팅 오류(다른 SV로 감) | orchestration 문구 미흡 | `08_AGENT_spec.md` tool description 보강 → `cortex_agent_save` 재배포 |
| 값 불일치 | SV metric 정의 오류 or 모델 해석 차이 | `06_검증쿼리_VQR.md §3` 회귀 SQL 재확인 → VQR 등록 |
| 가드레일 미준수(비활성 산출) | instruction 미흡 | `08_AGENT_spec.md` instructions.system 비활성 목록 강화 → 재배포 |
| Agent 없음/권한 오류 | 이관 중 소실 | `09_AGENT_spec_구현.sql` [1]~[4] 재실행 |

---

## 6. 소비 역할 검증 (선택)

> 소비자가 실제로 CoWork에서 Agent를 볼 수 있는지 확인.

```sql
-- VIEWER 역할로 전환 후 테스트
USE ROLE GN_DW_VIEWER;
USE WAREHOUSE GN_DW_ANALYTICS_WH;
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'GN_DW.SERVING.AGENT_MEMBER',
  {'messages':[{'role':'user','content':[{'type':'text','text':'전체 발송수는?'}]}]}
);
-- 기대: 38,470,780 반환 (USAGE 권한으로 실행 가능)
```

---

## 참조 문서
| 문서 | 용도 |
|---|---|
| `09_AGENT_spec_구현.sql [6]` | paid 이관 체크리스트 원본 |
| `10_SI연결_검증.md §3` | 스모크·회귀 정본(PASS 기준·DoD) |
| `07_평가셋_eval.md` | ground truth(기대값 근거) |
| `11_거버넌스_운영.md` | 사용량 모니터링·비용 쿼터(운영 시작 후) |

---
_Co-authored with CoCo_
