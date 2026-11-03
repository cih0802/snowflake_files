### ▣ O220-A-0 🔴 먼저 알아라

- 개발계는 **ua91864** 이다.
- 13차 Agent 개선 = 실시간 경량 ML 시뮬레이터 구축 및 2단계 가드레일 배선 완료 (SP_SIMULATE_CAMPAIGN_DVLP, ML_REALTIME_SIMULATOR_V, SV_ML_REALTIME_SIMULATOR, 코퍼스 RT-32, Agent 3종 VERSION$5 배포).
- 코퍼스 총 **2,158행** 적재 및 `SEARCH_BIZ_DEFINITION` REFRESH 완료 (TOP1=RT-32 확인).
- `for t in scripts/test_*.py` 52종 전수 음성 테스트 PASS (오류 0건).

### ▣ O220-A-1 라이브 반영 (ua91864 · 2026-10-13 · 재조회 확인)

| 객체 | 결과 | 롤백 |
|---|---|---|
| `GN_DW.ML.SP_SIMULATE_CAMPAIGN_DVLP` | 광고비/예산 변동 실시간 시뮬레이션 SP (SQL) | DROP PROCEDURE |
| `GN_DW.SERVING.ML_REALTIME_SIMULATOR_V` | 시나리오 그리드(-50%~+100%) 사전 연산 SERVING 뷰 | DROP VIEW |
| `GN_DW.SERVING.SV_ML_REALTIME_SIMULATOR` | 실시간 경량 ML 시뮬레이터 시맨틱 뷰 (AI_SQL_GENERATION) | DROP SEMANTIC VIEW |
| `GN_DW.SERVING.BIZ_DEFINITION_CORPUS` | 2,158행 (RT-32 신설) | DELETE RT-32 |
| `GN_DW.SERVING.SEARCH_BIZ_DEFINITION` | RT-32 검색 반영 REFRESH | ALTER REFRESH |
| `GN_DW.SERVING.AGENT_MEMBER` | VERSION$4 (도구 24종 · is_default=true) | SET DEFAULT_VERSION |
| `GN_DW.SERVING.AGENT_EXECUTIVE` | VERSION$4 (도구 14종 · is_default=true) | SET DEFAULT_VERSION |
| `GN_DW.SERVING.AGENT_MARKETING` | VERSION$5 (도구 25종 · is_default=true) | SET DEFAULT_VERSION |

### ▣ O220-A-2 🟠 ㉠ 이 작업의 성과 및 잔여

- ① 0단계 착수 점검: `09_2_AGENT_버전업.sql` [0] 사전검증 0행, Agent 3종 live 스펙 일치 확인, BIZ_DEFINITION_CORPUS 2,157행 / OPS_COLUMN_NULL_REGISTRY 166행 실재 확인.
- ② 1단계 실시간 경량 ML 시뮬레이터 DDL (Step 1 & Step 2):
  · `GN_DW.ML.SP_SIMULATE_CAMPAIGN_DVLP` 프로시저 구현 (Cobb-Douglas 탄력성 계수 0.72 기반 실시간 증감 시뮬레이션).
  · `GN_DW.SERVING.ML_REALTIME_SIMULATOR_V` SERVING 뷰 및 `SV_ML_REALTIME_SIMULATOR` 시맨틱 뷰 배포.
- ③ 2단계 코퍼스 및 Search 서비스 갱신 (Step 3):
  · `BIZ_DEFINITION_CORPUS` 에 RT-32 (실시간 시뮬레이터 라우팅 정의) 등록 및 Cortex Search 재구축.
- ④ 3단계 Agent 스펙 및 배포 (Step 4):
  · Agent 3종(`AGENT_EXECUTIVE`, `AGENT_MARKETING`, `AGENT_MEMBER`) YAML 스펙에 `analyst_ml_realtime_simulator` 도구 및 2단계 가드레일 오케스트레이션 지침 반영.
  · `09_2_AGENT_버전업.sql` 로 스테이지 동기화 대조(verdict=OK) 및 버전 배포 완료.
- ⑤ 4단계 검증 및 런북 최신화 (Step 5 & Step 6):
  · 시뮬레이터 SQL/SP 스모크 테스트 및 52개 회귀/음성 테스트 전건 PASS.
  · `12_agent개선과제/18_O217_운영계_재현_런북.md` 10·11·12·13차 통합본 최신화 완료.

### ▣ O220-A-3 🟡 ㉡ 워크스페이스 백로그

- 전체 목록 = `12_agent개선과제/20_O21X_잔여작업_정리.md` (총 28건 중 #28 완료로 19건 종결).
- 남은 열림 3건: #12(과금 eval 재측정), #14(차기 inspection), #19(dbt build 후 drift 검증).
- 대기 6건: 사용자 결정 1건(#8 모니터링 배포), 현업 회신 2건(#15, #16), 운영계 보류 2건(#9, #13), 구부채 1건(#17).

### ▣ O220-A-4 ⚪ 결정 완료(재론 금지)

- 실시간 가상 시뮬레이션 지표는 정규 실적/배치 예측과 엄격히 분리하고, 질문 접수 시 2단계 확인 가드레일("이 항목은 사전 연산된 정규 지표가 아닙니다... 계산할까요?")을 먼저 거친 후 승인 시에만 `analyst_ml_realtime_simulator` 도구를 실행한다.
- 시뮬레이션 결과 표 제목에는 반드시 「[시뮬레이션 추정치 · 고정값 아님]」을 표기한다.
