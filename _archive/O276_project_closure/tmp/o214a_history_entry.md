### §O214-A — 7차 COMMENT 규약 검토·시정 + 내부 잔여 집행(OPS DROP · NL 회귀 · eval · _archive 정리) (2026-10-08 · nj58180 · ㉡ 적용 · 승인 일괄 + R4-4-3 4건 별도 승인 · 확정위반 2)

- **검토 기준** = `05_0_SV_DDL.sql` COMMENT 규약 1(수치 금지)·2(원천 이름만)·3(저카디널리티 코드 열거)·4(세션 태그 금지) + 지침 R2-6·R2-7.
  · 대상 = INFORMATION_SCHEMA LAST_ALTERED 2026-10-08 인 SILVER·GOLD·SERVING 69객체 + SERVING SV 22종(라이브 스캔 · 파일 스캔 두 축).
- **발견(7차 신설분)** = 세션 태그 `O213` = 컬럼 34 · 테이블레벨 4 · SV 항목 111 · 개수 표기 `N종` = 예산 과목 4 · 지출결의 3 · 환급사유 1 ·
  빈 컬럼 COMMENT = BIGQUERY_SESSION 41/41 · FACT_BIGQUERY_SESSION 35/40 · 지출결의 2테이블 40(파일엔 있음 · 라이브 유실 = drift 42).
  · 기존 게이트는 `N종`·세션 태그를 보지 않는다(rule7 은 건·행·원·% 축) ⇒ 이번 검출은 라이브 SQL 스캔이 근거다.
- **시정** = `tmp/o214_comment_fix.py`(파일 156줄 · 접두 `🆕 [O213…]`·`SV(🆕 O213…)` 제거 · 원값 열거) ·
  `tmp/o214_bq_session_decl.py`(06·08 비실행 선언 블록 · 원값 = 라이브 DISTINCT 실측) · `tmp/o214_fee_rule7_fix.py` ·
  apply_table/silver_comment_drift `--apply`(GOLD 79 · SILVER 73) · 테이블레벨 ALTER 4 · MSTR 뷰 `ALTER VIEW … ALTER COLUMN … COMMENT` 4 ·
  SV 19종 재배포(`tmp/o214_sv_deploy.py` · 차원 수 불변).
  · 사후 = 라이브 O213 태그 0(SV·테이블·컬럼) · 7차 빈 COMMENT 0 · drift 0 · rule7 0 · 음성 테스트 전건 PASS(`test_sv_rule7_scan` O213 잔존 FAIL 해소).
- **OPS DROP** = O213_* 7표 · 프로시저 5(소유 ACCOUNTADMIN) · 보존 `tmp/o214_ops_backup/`(행수 7/7 · DDL 5) · 잔존 0.
- **NL 회귀** = 49문항 · 1차 실행이 샌드박스 재시작으로 33문항 후 중단(/tmp 로그 소실) → 재개 러너로 16문항만 추가 호출 · 49/49 · 중간 오류 1 ≤ 기준선 1 ⇒ PASS.
- **eval v3_0** = `o214_executive_v3_ds2` · `o214_member_v3` · `o214_marketing_v3_ds2`(VERSION$7 · 채점 실패 0) ·
  AC 0.7614 · 0.7685 · 0.7857 ↔ O211-B(VERSION$3) 0.9052 · 0.8462 · 0.9293 · TSA 0.6905 · 0.35 · 0.6543 ↔ 0.811 · 0.4731 · 0.8807.
  · 분해 `tmp/o214_eval_regress.tsv` = EXEC 회비 예측 도구 미호출 · 개발건수 축 질문의 MSTR SV 쏠림 · MKT 무도구 정답 문항 analyst_ad 직행.
  · 🔴 VERSION$6 eval 부재 ⇒ 6차·7차 기여 미분리.
- **_archive** = UNLABELED 255 중 229 개별 삭제 · 🔴 마운트 `os.remove` 가 **접두 삭제**로 동작해 보존 대상 4 소실 → workspace `VERSION$8` 에서 `COPY FILES` 복원 · 두 축 26/26.
- **확정위반 2** = R1-7-9(quoted heredoc 로 스크립트 복제) · R1-7-7(접두 삭제 부수 소실 · 복원).
- 인수인계 = `99_NEXT_SESSION-O0214-A.md`.
