## O226-A O225-E 통합 착수표 10건 집행 (2026-10-14 · xh20001 · ㉡ 적용 · 일괄 승인 · 확정위반 2)

- 착수 = 사용자 「작업 전부 승인」 · 라벨 = `id_collision_gate --next O` = O226(정의 196 · 참조 225) · 원장 §1 선점 등재 후 진행.
- ① dbt WARN = 전체 build(656) 기준 22건(O225-D 「5건」은 부분 build 118노드 분모) · 원인 실측 3묶음 = SND 결과코드 사전 미등재 13종(1,725,977행) · 행사 채널코드 `)` 2행(4 WARN) · KPI 뷰 COMMENT 누락 · 원문 `tmp/o226/01_dbt_warn_22.md`.
- KPI 뷰 = yml 등재만으로는 미반영(build WARN 1 잔존) · 원인 = `materialized='gn_view_commented'` 누락 ⇒ config 추가 후 build PASS 6 · 커버리지 경고 0 · 무주석 컬럼 0.
- ② campaign_axis_gate GAP 15 → 11 = 최초캠페인 SV_MEMBER_MONTHLY 노출(BK 조인 · 합계 945,321,724,538 일치) · DGT 유형1·2 EXEMPT(결합값 성분 232,415/232,418) · IRSD EXEMPT.
  · IRSD = 사용자 결정 「FME 증감 사건 신설」 ↔ 실측 = FME DEV(2·3)와 같은 사건(회원·일자 99.6% · 캠페인 97.1%) ⇒ 신설 시 이중계상 · 신설 보류 + 보고(👤 재확인 대기).
- ④ 작업계획 §15-9 확정 순서 반영(행수 최다 → 시작일 최근) · ⑤ SV 스모크 4종 합계 일치 · ⑥ 문서20 N-30 등재(5건).
- ⑦ MEMBER V$7 → V$8 = `[O217 정의 조회]` 조문 안 판정 순서 재작성(복합 지표 = 확인 선행) + 교차 집계 예외 · 스모크 R12·R13 확인 · R14 직접 3/3(2회).
- ⑨ 요건 R MKT = 라이브 V$8 기반영(O224-B) 확인 · 변경 없음.
- ⑩ COMMENT = C7 15(BRONZE 원천명 dbt source 실명 교체 · 라이브 ALTER GOLD 4 · SILVER 10 · WIDE 2 build) · C4 4(수치 삭제) · C9 13(KPI) · C3 622 = 계획(`tmp/o226/10_comment_fix.md`).
- ⑧ eval(6 run) = V3 AC EXEC 0.9205 → 0.9048 · MEMBER 0.8715 → 0.8723 · MKT 0.6900 → 0.8807 · V4 기준선 AC 0.9524 · 0.8715 · 0.9764 · 🟠 MEMBER R14 실행 변동(`tmp/o226/08_eval.md`).
- 확정위반 2(유실 0): `R1-7-8` 원장 행 앵커를 행 시작부로 잡아 O225 행과 합쳐짐 → 즉시 복구 · 행 게이트 PASS / `R1-7-2` 원장 행 재편집 직전 해시 2회 미확인.
- 라이브 변경(xh20001) = SV_MEMBER_MONTHLY · SV_MEMBER_EVENT · SV_MSTR_SPNSR_DVLP(+ MSTR 서빙 뷰 재생성) 재배포 · ML_SPONSOR_RISK_V COMMENT · 테이블 COMMENT 14 · Agent MEMBER V$7·V$8 · eval run 6 · DATA_AGENT_RUN 9회.

### 독해 기록(`R1-3-7-b`)

- `00_guides/00_작업지침_세션운영규칙.md` 1~304 · 도착 · `R0-8-4` · `R1-7-10` · `R4-4-4`.
- `20_issue/00_BRIEF.md` 1~151 · 도착 · `O0225-E` · `3,227,567` · `GAP 15`.
- `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0225-A/C/D/E.md` 전량 · 도착 · `utm_pick` · `1,104,308` · `WARN=5` · `O225-E-3`.
- `99_NEXT_SESSION-O0224-A.md` 17~54 · 도착 · `R12·R13` · `V$6`.
- `05_01_SV_DDL_MEMBER_MONTHLY.sql` 전량 · `FACT_AD_PERFORMANCE.sql` 전량 · `FACT_MEMBER_EVENT.sql` 전량 · 도착 · `fmm_to_campaign` · `utm_cand` · `mstr_b2c`.
- read 미반환 0 · 재호출 0.

_Co-authored with CoCo_
