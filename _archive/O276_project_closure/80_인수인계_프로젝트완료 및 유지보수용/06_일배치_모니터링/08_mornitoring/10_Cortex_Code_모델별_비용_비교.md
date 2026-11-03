# 10. Cortex Code(CoCo) LLM 모델별 상대 비용 및 크레딧 소모 비교

Snowsight 및 CoCo(Cortex Code) 인터페이스의 모델 선택 목록에 제공되는 LLM 모델별 상대적 비용 티어 및 Snowflake 크레딧 소모율 매핑 문서입니다.

---

## 1. 모델별 비용 티어 및 상대 크레딧 소모율 비교표

Cortex Code 사용 시 비용은 토큰(Token) 처리량에 따른 **Snowflake 크레딧(Token Credits)**으로 과금됩니다.

| 모델명 | 비용 티어 | 상대 크레딧 소모율 | 모델 특성 및 권장 용도 |
| :--- | :---: | :---: | :--- |
| **Gemini Flash 3.8** | **최저가 (가장 저렴)** | ★☆☆☆☆ (1x) | 초경량·초고속 응답, 단순 SQL 작성, 간단한 코드 수정, 비용 최우선 작업 |
| **Claude Haiku 5.5** | **매우 저렴** | ★☆☆☆☆ (~1.5x - 2x) | 빠른 코드 탐색, 단일 스크립트 작성, 경량 어시스턴트 작업 |
| **Gemini 4 Argon** | **저렴 ~ 보통** | ★★☆☆☆ (~2x - 3x) | 구글 범용 효율 중심 모델, 준수한 SQL/코드 생성 및 다국어 처리 |
| **GLM 5.3** | **보통** | ★★☆☆☆ (~2x - 3x) | 다국어/범용 추론 가성비 모델 |
| **Kimi K3** | **보통** | ★★☆☆☆ (~3x) | 긴 컨텍스트(Long-context) 처리 및 비용 균형 모델 |
| **Claude Sonnet 5.5** | **중간 (표준 권장)** | ★★★☆☆ (~5x) | **가장 균형 잡힌 코딩·추론 성능**, 실무 개발 및 아키텍처 분석의 기본 표준 모델 |
| **Grok 4.7** | **높음** | ★★★★☆ (~10x) | 대규모 컨텍스트 분석 및 복잡한 추론 작업 |
| **OpenAI GPT 5.4** | **매우 높음** | ★★★★★ (~15x) | 고난도 시스템 설계, 다단계 로직 검증, 복잡한 문제 해결 |
| **Claude Opus 5.5** | **최고가 (가장 비쌈)** | ★★★★★ (~20x) | 최고 난이도 아키텍처 설계, 초고난도 디버깅 및 심층 추론 |

---

## 2. 작업 목적별 모델 선택 가이드

1. **비용 극대화 절감 / 단순 조회·수정:**
   - 추천: **Gemini Flash 3.8** 또는 **Claude Haiku 5.5**
   - 단순 SQL 포맷팅, 단일 테이블 조회 쿼리 작성, 간단한 버그 확인 시 최적

2. **일반 데이터 엔지니어링 / 파이프라인 개발 (가성비 최우수):**
   - 추천: **Claude Sonnet 5.5**
   - SQL 최적화, dbt 모델 작성, 스크립트 리팩토링 등 복잡도 대비 성공률이 가장 높아 기본 모델로 권장

3. **고난도 아키텍처 설계 / 심층 디버깅:**
   - 추천: **Claude Opus 5.5** 또는 **OpenAI GPT 5.4**
   - 다중 테이블 간 복잡한 비즈니스 로직 설계 및 장기 세션 트러블슈팅에 활용

---

## 3. 계정 내 모델별 실제 소모량 추적 쿼리

Snowsight 내 CoCo 사용 시 모델별 상세 토큰/크레딧 소모량은 `CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY` 뷰의 `TOKENS_GRANULAR` 및 `CREDITS_GRANULAR` 컬럼을 통해 확인할 수 있습니다.

```sql
-- 최근 7일간 모델별 크레딧 및 토큰 소모 상세 내역 조회
SELECT 
    REQUEST_ID,
    USAGE_TIME,
    USER_NAME,
    TOKEN_CREDITS,
    TOKENS,
    TOKENS_GRANULAR,
    CREDITS_GRANULAR
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
WHERE USAGE_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY USAGE_TIME DESC;
```
