# 운영계 요청 O269 — SV_AD 캠페인유형 값 목록 회수 + Agent 2문항 확인

> 실행 대상: 운영계(ZL50263) · 실행자: 저가형 LLM 또는 사용자 · 작성 = 개발계 O269 (2026-10-28)
> 🔴 **읽기 전용 요청이다.** DDL·DML·COMMENT 수정·SV 재배포·dbt 실행을 하지 마라.

---

## 0. LLM 에게 주는 프롬프트 (이 블록을 그대로 붙여넣는다)

```
너는 Snowflake 운영계(ZL50263)에서 조회만 하는 보조자다.
규칙:
1. 아래 §1 의 SQL 3개와 §2 의 명령 1개만 실행한다. 다른 SQL·DDL·DML·dbt 는 실행하지 않는다.
2. 결과는 요약하지 말고 행 전체를 그대로 붙여넣는다(NULL 은 NULL 로 적는다).
3. 오류가 나면 고치려 하지 말고 오류 원문을 그대로 적는다.
4. §3 표의 개발계 값과 운영계 값을 비교해
   「운영계에만 있는 값」·「개발계에만 있는 값」을 컬럼별로 나열한다.
5. §4 의 Agent 질문 2개는 사람이 Snowflake Intelligence 에서 직접 물어본 답변 원문을 받아 적는다.
6. 출력 형식은 §5 를 따른다.
```

---

## 1. SQL (읽기 전용)

### Q1. 실제 적재값 분포

```sql
SELECT 'CMPGN_TYPE_BSN_NM' AS col, CMPGN_TYPE_BSN_NM AS val, COUNT(*) AS n
FROM GN_DW.GOLD.WIDE_AD_COMBINED
GROUP BY 1, 2
UNION ALL
SELECT 'CMPGN_TYPE1_BSN_NM', CMPGN_TYPE1_BSN_NM, COUNT(*)
FROM GN_DW.GOLD.WIDE_AD_COMBINED
GROUP BY 1, 2
UNION ALL
SELECT 'CMPGN_TYPE2_BSN_NM', CMPGN_TYPE2_BSN_NM, COUNT(*)
FROM GN_DW.GOLD.WIDE_AD_COMBINED
GROUP BY 1, 2
ORDER BY 1, 3 DESC;
```

### Q2. 운영계 SV_AD 에 실제 배포된 COMMENT

```sql
DESCRIBE SEMANTIC VIEW GN_DW.SERVING.SV_AD;
```

```sql
SELECT "object_name", "property", "property_value"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "object_name" IN ('CMPGN_TYPE_BSN_NM', 'CMPGN_TYPE1_BSN_NM', 'CMPGN_TYPE2_BSN_NM')
  AND "property" = 'COMMENT';
```

### Q3. 원천 적재 시점 (새 값이 언제 들어왔는지)

```sql
SELECT CMPGN_TYPE_BSN_NM, MIN(BROADCAST_DATE) AS min_dt, MAX(BROADCAST_DATE) AS max_dt, COUNT(*) AS n
FROM GN_DW.GOLD.WIDE_AD_COMBINED
WHERE CMPGN_TYPE_BSN_NM IS NOT NULL
GROUP BY 1
ORDER BY 1;
```

> Q3 에서 `BROADCAST_DATE` 가 없다는 오류가 나면 오류 원문만 적고 넘어간다(고치지 않는다).

---

## 2. 게이트 원문 재출력

운영계 워크스페이스 루트에서 아래를 실행하고 **출력 전체**를 붙여넣는다.

```
timeout 300 python3 scripts/sv_code_label_gate.py </dev/null >/tmp/sv_code_label.out 2>&1; echo rc=$?
```

그 다음 `/tmp/sv_code_label.out` 내용 중 `SV_AD` 가 들어간 줄 **전부**를 그대로 적는다.

---

## 3. 개발계 기준값 (2026-10-28 · 개발계 실측)

| 컬럼 | 값 | 행수 |
|---|---|---|
| CMPGN_TYPE1_BSN_NM | 국내 | 120000 |
| CMPGN_TYPE1_BSN_NM | 해외 | 87052 |
| CMPGN_TYPE1_BSN_NM | NULL | 49364 |
| CMPGN_TYPE1_BSN_NM | 통합 | 24567 |
| CMPGN_TYPE1_BSN_NM | 전체 | 6902 |
| CMPGN_TYPE1_BSN_NM | 0 | 1342 |
| CMPGN_TYPE1_BSN_NM | - | 240 |
| CMPGN_TYPE1_BSN_NM | 전체사업 | 2 |
| CMPGN_TYPE2_BSN_NM | 사례 | 114076 |
| CMPGN_TYPE2_BSN_NM | 사업 | 52838 |
| CMPGN_TYPE2_BSN_NM | NULL | 50948 |
| CMPGN_TYPE2_BSN_NM | 굿즈 | 47040 |
| CMPGN_TYPE2_BSN_NM | 기타 | 22383 |
| CMPGN_TYPE2_BSN_NM | 통합 | 2184 |
| CMPGN_TYPE_BSN_NM | 국내 사례 | 68724 |
| CMPGN_TYPE_BSN_NM | 국내 사업 | 51276 |
| CMPGN_TYPE_BSN_NM | NULL | 49364 |
| CMPGN_TYPE_BSN_NM | 해외 사례 | 45352 |
| CMPGN_TYPE_BSN_NM | 해외 굿즈 | 40138 |
| CMPGN_TYPE_BSN_NM | 통합 기타 | 22383 |
| CMPGN_TYPE_BSN_NM | 전체 굿즈 | 6902 |
| CMPGN_TYPE_BSN_NM | 통합 통합 | 2184 |
| CMPGN_TYPE_BSN_NM | 해외 사업 | 1562 |
| CMPGN_TYPE_BSN_NM | 0 | 1342 |
| CMPGN_TYPE_BSN_NM | - | 240 |
| CMPGN_TYPE_BSN_NM | 전체사업 | 2 |

> 개발계 COMMENT 열거 = 위 값과 정확히 일치(개발계 게이트 위반 0).

---

## 4. Agent 2문항 (사람이 Snowflake Intelligence 에서 직접 질문)

대상 Agent = `AGENT_MARKETING`(없으면 `AGENT_MEMBER`) · 어느 Agent 로 물었는지 함께 적는다.

| # | 질문(그대로 입력) | 기대 |
|---|---|---|
| 1 | 알림톡 템플릿 AT006040 을 받은 회원 중 수신 후 5일 이내에 그 템플릿 링크를 클릭한 회원 수를 알려줘. | 답변 앞에 불필요한 중간 문장 없음 · 「그 템플릿 링크 클릭」 기준임을 안내 |
| 2 | 알림톡 링크 utm_campaign=25acpi_om_gift 를 클릭한 회원 수를 수신 후 5일 이내 기준으로 알려줘. | 「같은 링크를 쓴 다른 템플릿 수신자의 클릭도 포함」임을 안내 |

---

## 5. 회신 형식

```
[Q1] (결과 행 전체)
[Q2] (COMMENT 3행 원문)
[Q3] (결과 행 전체 또는 오류 원문)
[게이트] rc=<n> · SV_AD 줄 전체
[비교] 컬럼별 운영계에만 있는 값 / 개발계에만 있는 값
[Agent] 사용 Agent 명 · 질문1 답변 원문 · 질문2 답변 원문 · 기대 충족 여부(O/X)
```

_Co-authored with CoCo_
