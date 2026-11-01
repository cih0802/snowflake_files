I'll check the tools/functions used in the agents and inspect the role grants for `GN_DW_ANALYST` and `GN_DW_VIEWER`.I will search for any agent definitions or custom tools in the workspace to identify the exact objects, schemas, functions, or procedures involved.I will search inside `cortex_project` and `05_SV-Agent_ai` for the agent specifications and tool definitions.I will check the tools defined in the 3 agent specs (`AGENT_EXECUTIVE`, `AGENT_MARKETING`, `AGENT_MEMBER`).I will read lines around the tools in `AGENT_MEMBER/agent_spec.yaml` and `AGENT_EXECUTIVE/agent_spec.yaml` to see all tool specifications and custom tools (such as UDF/Stored Procedure / ML tools).I will check lines 231 to 400 of `AGENT_MEMBER/agent_spec.yaml` to see all ML tool specifications and custom tools.I will check lines 352 to 460 of `AGENT_MEMBER/agent_spec.yaml` to see all custom tools / generic tools.I will search for any other custom tools across all agent yaml files.I will check the RBAC setup and grants script `02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql` to see how `GN_DW_ANALYST` and `GN_DW_VIEWER` roles are configured.I will check the SERVING schema grants in `02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql` around line 210-250 or search for `GN_DW.SERVING`.I will read lines 210 to 260 of `02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql` to check SERVING schema grants.I will check where SERVING schema grants and AGENT / Semantic View grants are defined in `02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql`.I will read lines 560 to 620 of `02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql`.I will check `02_GN_DW_building/08_After_Deploy_DBT.sql` to verify the grants on SERVING, Semantic Views, and ML schema for `GN_DW_ANALYST` and `GN_DW_VIEWER`.I will check the SV and AGENT deployment scripts in `05_SV-Agent_ai` to verify what grants are actually issued when Agents / SVs are deployed.I will check `05_SV-Agent_ai/22_ML_SV_DDL.sql` and `05_SV-Agent_ai/09_1_AGENT_생성.sql` to see what grants are configured for ML Semantic Views and Agents.I will check the GRANT statements at the bottom of `05_SV-Agent_ai/22_ML_SV_DDL.sql` and `05_SV-Agent_ai/09_1_AGENT_생성.sql`.I will check `05_SV-Agent_ai/09_1_AGENT_생성.sql` to verify Agent permissions.I will check how `GN_DW.ML` schema and ML views / Semantic Views are granted to `GN_DW_ANALYST` and `GN_DW_VIEWER`.I will check `24_ML_REALTIME_SIMULATOR_DDL.sql` to verify permissions on `SV_ML_REALTIME_SIMULATOR` and `ML_REALTIME_SIMULATOR_V`.I will check the DDL for `24_ML_REALTIME_SIMULATOR_DDL.sql` around line 225-245.I have all the facts and permissions mapped out accurately. Now I can provide a clear, concise, and structured Korean response explaining the exact RBAC status for `GN_DW_ANALYST` and `GN_DW_VIEWER`.

Let's double-check:
1. `GN_DW_ANALYST`:
   - Agent 사용: `GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_* TO ROLE GN_DW_ANALYST` 부여됨.
   - 배치 ML 예측 툴 (`SV_ML_MEMBER_RISK`, `SV_ML_SPONSOR_RISK`, `SV_ML_FEE_FORECAST`, `SV_ML_FEATURE_IMPORTANCE`, `SV_ML_ONCE_CONVERSION` 등): Semantic View 및 베이스 서빙 뷰 (`ML_*_V`)에 `SELECT/REFERENCES` 권한 부여됨.
   - 실시간 ML 시뮬레이터 (`SV_ML_REALTIME_SIMULATOR`, `ML_REALTIME_SIMULATOR_V`, `SP_SIMULATE_CAMPAIGN_DVLP`): `GN_DW_ANALYST`에 `USAGE/SELECT` 부여됨.
   - 원천 ML 스키마(`GN_DW.ML`): `USAGE` 및 `SELECT` 권한 보유.
   👉 **`GN_DW_ANALYST`는 모든 예측 ML 도구를 정상 사용 가능합니다.**

2. `GN_DW_VIEWER`:
   - Agent 사용: `GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_* TO ROLE GN_DW_VIEWER` 부여됨.
   - 배치 ML 예측 툴 (회원/후원 위험, 회비 전망, 요인분석, 일시후원 전환 등): Semantic View 및 베이스 서빙 뷰(`ML_*_V`)에 `SELECT/REFERENCES` 권한 부여됨.
   - ⚠️ **실시간 ML 시뮬레이터(`analyst_ml_realtime_simulator`)**: `GN_DW.SERVING.SV_ML_REALTIME_SIMULATOR` 및 `ML_REALTIME_SIMULATOR_V`, `SP_SIMULATE_CAMPAIGN_DVLP`에 대한 `SELECT/USAGE`가 `ADMIN / ENGINEER / ANALYST`에게만 부여되어 있고, `GN_DW_VIEWER`에는 누락되어 있어 실시간 시뮬레이터 도구 호출 시 권한 오류가 발생할 수 있습니다.

Let's organize the response clearly.**`GN_DW_ANALYST`는 모든 예측 ML 도구를 사용할 수 있지만, `GN_DW_VIEWER`는 일부 도구(실시간 시뮬레이터)에 권한 추가가 필요합니다.**

---

### 1. 역할별 사용 가능 여부 요약

| 구분 | 도구 유형 및 대상 | `GN_DW_ANALYST` | `GN_DW_VIEWER` | 비고 |
| :--- | :--- | :---: | :---: | :--- |
| **Agent 3종** | `AGENT_MEMBER`<br>`AGENT_MARKETING`<br>`AGENT_EXECUTIVE` | **가능 (O)** | **가능 (O)** | `GRANT USAGE ON AGENT` 양쪽 모두 부여 완료 |
| **배치 ML 예측 도구** | • `analyst_ml_member_risk` (회원위험)<br>• `analyst_ml_sponsor_risk` (후원위험)<br>• `analyst_ml_fee_forecast` (회비전망)<br>• `analyst_ml_feature_importance` (피처기여도)<br>• `analyst_ml_once_conversion` (정기전환) | **가능 (O)** | **가능 (O)** | `GN_DW.SERVING.SV_ML_*` 및 `ML_*_V` 뷰에 양쪽 모두 `SELECT / REFERENCES` 부여 완료 |
| **실시간 ML 시뮬레이터** | • `analyst_ml_realtime_simulator`<br>(가상 광고비/예산 증감 시뮬레이션) | **가능 (O)** | **불가 (X)**<br>*(권한 누락)* | `SV_ML_REALTIME_SIMULATOR` 및 `ML_REALTIME_SIMULATOR_V`에 `VIEWER` 권한 미부여 |

---

### 2. `GN_DW_VIEWER` 사용을 위한 조치 방법

`GN_DW_VIEWER` 역할로도 실시간 ML 시뮬레이터 도구를 정상 실행하려면 아래 DDL을 실행하여 권한을 부여해야 합니다:

```sql
USE ROLE GN_DW_ADMIN;

-- 실시간 시뮬레이터 Serving 뷰 및 Semantic View 조회 권한 부여
GRANT SELECT ON VIEW GN_DW.SERVING.ML_REALTIME_SIMULATOR_V TO ROLE GN_DW_VIEWER;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_REALTIME_SIMULATOR TO ROLE GN_DW_VIEWER;
```
