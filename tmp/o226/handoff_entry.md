### ▣ O226-A-0 🔴 먼저 알아라

- O225-E 착수표 10건을 집행했다(①~⑩ · ⑧ eval 포함 · 사용자 일괄 승인 · ㉡ · 확정위반 2 · 유실 0).
- 라이브(xh20001) = Agent **MEMBER V$8**(롤백 V$6) · EXEC V$7 · MKT V$8(변경 없음) · build PASS 6(KPI·WIDE 4종 COMMENT 반영).
- 근거 파일 = `tmp/o226/`(01 WARN · 02 GAP · 08 eval · 10 COMMENT · 스모크 원문).

### ▣ O226-A-1 이번 단위 결과

| 순 | 결과 |
|---|---|
| ① | WARN 22 원인표 · 3묶음 실측(SND 결과코드 13종 · 행사 채널 `)` 2행 · KPI COMMENT) |
| ② | GAP 15 → 11 · 최초캠페인 SV 노출 · DGT 유형1·2·IRSD EXEMPT |
| ④⑤⑥ | §15-9 갱신 · SV 스모크 4종 일치 · 문서20 N-30 |
| ⑦ | MEMBER V$8 · R12·R13 확인 선행 · R14 직접 집계(스모크) |
| ⑧ | V3 AC EXEC 0.9048 · MEMBER 0.8723 · MKT 0.8807(+0.19) · V4 기준선 0.9524 · 0.8715 · 0.9764 |
| ⑨ | 요건 R MKT = V$8 기반영 확인 |
| ⑩ | C7 15 · C4 4 · C9 13 시정(라이브) · C3 622 계획 |

### ▣ O226-A-2 ㉠ 이 작업의 잔여

- ① 👤 IRSD 재확인 — 결정 「FME 증감 사건 신설」을 실측(FME DEV 2·3 과 같은 사건 · 이중계상)으로 보류했다 · 그래도 신설이면 착수.
- ② MEMBER R14 실행 변동(eval 0.33 · 스모크 직접) — 교차 집계 예외 판정을 「새 비율·효과 지표 이름이 없으면 분포 조회」로 조문 안 치환 후 재측정(V4 기준).
- ③ COMMENT C3 622 = `tmp/o226/10_comment_fix.md` 4단계(eval V4 기준선 대비 단계별).
- ④ 👤 문서20 N-30 회신(ERP 30코드 · DIGITAL_MAP 위치 · SND 결과코드 13종 · `)` 2행 · 캠페인 속성 2).

### ▣ O226-A-3 🟡 ㉡ 워크스페이스 백로그

- `12_agent개선과제/20_O21X_잔여작업_정리.md` 열림 4건(#12 · #14 · #17 · #19).
- 운영계 반영 미결 = O224 · O225 · O226(SV 3종 · 테이블 COMMENT 14 · MEMBER 스펙 · KPI config) → 런북 `18_O217_운영계_재현_런북.md` 단계 추가.
- campaign_axis_gate GAP 11 = 발송 스냅샷 5 · 소재 1 · 현업 3 · 후속 2(`tmp/o226/02_campaign_gap.md`).

### ▣ O226-A-4 ⚪ 결정 완료(재론 금지)

- 요건 R = MKT 에도 붙인다(사용자 · V$8 기반영).
- 최초캠페인 = DIM_MEMBER.FIRST_CAMPAIGN → DIM_CAMPAIGN BK 별칭 조인(SV_MEMBER_MONTHLY `first_campaign`) · 「그 달 후원 캠페인」과 별개 축.
- DGT 캠페인유형1·2 = 결합값 CMPGN_TYPE_BSN_NM 으로 제공(분리 노출 안 함).
