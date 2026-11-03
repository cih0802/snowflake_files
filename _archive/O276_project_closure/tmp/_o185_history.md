
> #### 🟢 [2026-09-28 O185] GN_DW_DBT 전환 검증 + ENGINEER 축소 + FACT_AD_BROADCAST COMMENT 정정

- **분기** = `R4-4-2` ㉡ · 확정위반 **0** · 파괴 가능 연산 0(REVOKE 는 지시상 승인 범위 · SQL 선제시)
- **O184 build 실패 규명** = 실패 실행은 `EXECUTE DBT PROJECT` 가 **09-22 배포본**(role=ENGINEER · O182 이전 코드)을 돌린 것 —
  사용자가 재배포 후 parse·compile·build 전건 **GN_DW_DBT SUCCESS** · PASS 543 · WARN 21 · ERROR 0
- **ENGINEER 축소(라이브)** = GOLD DML ALL/FUTURE · GOLD CREATE VIEW · SILVER UPDATE ALL/FUTURE · OPS/audit CREATE TABLE ·
  DBT_PROJECT USAGE/MONITOR 회수 · 재조회 GOLD=SELECT 전용 · O181-B ▣2-7 GRANT UPDATE **부수 종결** · 07 RBAC D.9 [3]
- **COMMENT** = WIDE 뷰 DVLP 문안 build 로 반영 확인 · `FACT_AD_BROADCAST` DVLP 2컬럼(ADMIN DDL 테이블)은 build 대상 밖이라
  잔존 발견 ⇒ 06_DDL + 라이브 ALTER 동기화
- 문서20 열린 판정 `____` = **34**(J3 분모 재측정)
