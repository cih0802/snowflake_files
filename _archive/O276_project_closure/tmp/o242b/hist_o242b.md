## O242-B 발견 결함 3건 시정: VQR 31건 한글 별칭·반올림 · CHURN 뷰 21 이동 · Agent ③ 정정·㉥·Q01 라우팅 → VERSION$8 · 🔴 계정 정지로 eval 미실행 (2026-10-18 · trialadmin(mn11232) · ㉡ · 사용자 승인 = 발견 3건 전부 · 계획 승인 · 확정위반 1)

- 착수 = 사용자 「발견한 문제점도 전부 승인 · 고쳐줘」 → 계획 승인(plan mode) 후 집행.
- ① VQR 31건(17파일) = 원 SQL 바깥 감싸기 · 한글명 = 필드 동의어·업무명 + 단위 · 비율·평균·확률만 ROUND(,2)::NUMBER(38,2).
  - dry-run 결함 0 → 적용(백업 `tmp/o242b/bak/`) → 임시 이름 SV 24종 생성 검증 PASS · FAIL 0 → 정본 배포 19파일 OK · 라이브 GET_DDL 샘플 3 TRUE · 잔여 결함 0.
- ② ML_CHURN_BY_CMPGN_CTGR_V 정의 58줄 + GRANT 3줄 25 → 21(ATTR 블록 앞) 이동 · 블록 해시 72187a3d2d16 동일 · 21 → 25 재실행 · 뷰 조회 ATTR 1,473,162 · CHURN 1,605,688.
- ③ EXEC LC 0.95→0.78 원인 = 평가자 판정문(D4·D1·M1·Q15)이 「analyst 문맥 → system_execute_sql」 정상 경로를 O241-T ③ 「직접 SQL 금지」 위반으로 감점.
  - ⇒ ③ 문구 정정(정상 경로 · 그 SQL 도 SV 규칙) · response ㉥ 이물 문자 점검(5→6가지) · MEMBER 「캠페인별 중단 예측 + 회원 특성」 → churn_campaign 1회.
  - 스펙 3종 YAML 파싱 OK · 배포 = Agent 3종 VERSION$8(default · 롤백 $7).
- 재평가 = S4 스모크 F1~F5 통과 · 🔴 native eval o242b = 시작 시 `000666 account suspended due to lack of payment method` ⇒ 미실행(과금 없음) · 메타데이터 조회만 가능.
- 🔴 확정위반 1 = 검증 대상 목록을 명령 치환으로 만들며 잡음 출력이 섞여 1차 검증이 파일명 오류로 즉시 종료(라이브 영향 0 · 명시 목록으로 재실행).
- 부수 = `py_compile` 이 마운트 `__pycache__` 쓰기에서 Errno 5 ⇒ `PYTHONDONTWRITEBYTECODE=1`.
- 33 배포순서 ④ · D0-1 · D1 · 문서실행순서 12행 갱신.

### 독해 기록(`R1-3-7-b`)

- `tmp/o242b/vqr_raw.txt` 1~93 · 도착 · `CLK_YOY_PCT` · `SNG_INSTANT`.
- `05_SV-Agent_ai/25_ML_CHURN_CMPGN_CTGR_DDL.sql` 1~76 · 177~198 · 도착 · `HAS_SPONSOR_PRED` · `고려인캠페인 활동회원 17,753`.
- `05_SV-Agent_ai/21_ML_SERVING_뷰_DDL.sql` 341~362 · 도착 · `ML_LTV_SCORE_V 폐기(O198)` · `[O241-M]`.
- read 미반환 0 · 재호출 0.
