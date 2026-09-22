<!-- LLM-METADATA
doc_id: HANDOFF_O0178_A
doc_role: 인수인계 — 세션 `O178-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-22
created_by: O178-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0178-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O178-A-0 🔴🔴 먼저 알아라 — 이 세션이 확정한 판정식

1. 🔴🔴 **「넘겨받은 프롬프트가 현행인가」를 먼저 재라.**
   이번에 받은 지시서는 **`O176-A`**(→O177 지시서)였고 `O177` 은 **이미 종결**돼 있었다.
   그 안의 기대값(`TOTAL 561→562`)도 낡아서, 그대로 믿었으면 **정상 상태를 이상으로** 판정했을 것이다.
   🟢 판정법 = **라벨 파일 최대값 + 이력 항목 실재**를 먼저 대조한다(`O172` 규격이 이미 제공한다).
   🔴 그리고 **「직전 세션이 잔여를 처리했다」고 가정하지 마라** — `O177` 은 `O176` 잔여 7건 중
   **1건(dbt 대사)만** 닫았고 나머지 6건은 그대로였다.

2. 🔴🔴 **「기대값과 1건 어긋남」을 반올림하지 마라.**
   `527/37` ↔ `526/38` 의 **1건** 차이가 **하류 8M행 소실**의 유일한 표면 증상이었다.
   🟢 차이를 **노드 단위**로 좁히면 원인이 나온다(WARN 1건 → `warn_ga4_load_gap` 30행 → 원인 규명).

3. 🔴🔴 **증분 파이프라인에서는 「배포 순서」가 데이터 범위를 결정한다.**
   재배포로 SILVER/GOLD 가 빈 상태가 된 뒤 **구 버전 빌드가 먼저** 돌아 3일치를 채웠고,
   신 버전 롤링 윈도우는 창에 원천이 없어 **정확하게 아무 일도 하지 않았다**(정상 no-op).
   ⇒ 🔴 **코드가 옳아도 데이터가 틀릴 수 있다.** 전량 TRUNCATE 시절에는 불가능했던 실패 모드다.

4. 🔴 **근거 없는 상수는 시한폭탄이다.** `cal_end 2035` 는 **인용 14곳 / 정의 0곳**이었고
   2036-01-01 부터 전 팩트를 `DATE_SK=0` 으로 보내는 절벽이었다.
   🟢 판정법 = **인용 수가 아니라 정의 수를 세라**(`id_collision_gate` 의 미정의 축과 같은 구조).

5. 🔴 **센티넬·클램프 설계는 「대칭성」으로 검산한다.**
   사용자가 *「9999 를 이상치로 버리면 1900 도 버려야 하지 않나」*로 내 제안(`cal_end` 만 확장)을
   개선했다 ⇒ `1945~2145`. 🟢 **범위 양끝을 따로 정당화하려 하면 한쪽이 임의값으로 남는다.**

6. 🔴 **결함 축을 기계화하면 대개 1건이 아니다** — `T2`(dry-run 부재)를 테스트 축으로 만들자
   같은 결함이 **13건**이었다(O176 은 1건만 봤다). 🟢 그때 판정을 「0건」으로 두면
   **항상 빨간 게이트**가 되어 무시된다(`P103-⑤`) ⇒ **기지목록 + 증가 0 + 목록 stale 역방향** 3축.
   🔴 **기지목록은 면제가 아니라 백로그다.**

7. 🔴 **쌍둥이를 찾아라.** `apply_table_comment_drift` 를 고칠 때 `apply_silver_comment_drift` 가
   **같은 결함**이었다(O176 은 GOLD 쪽만 봤다). `R1-6-17` 축이고 `O175-B` 가 이미 같은 처방을 남겼다.

8. 🔴 **「내가 약속한 검사가 도는가」의 짝 = 「내가 약속한 재잠금이 배포에 닿았는가」.**
   백필 슬롯을 다시 주석 처리한 뒤 **배포에 반영됐는지 쿼리이력으로 별도 검증**했다 —
   안 했으면 일일 배치가 **매일 33일을 재적재**했을 것이다(자체 적발).

### ▣ O178-A-1 🟢 이 세션이 끝낸 것

🔴 **상세 정본 = 이력 `§O178`**(원장 §1 `O178` 행은 색인이다).

| 항목 | 결과 |
|---|---|
| `O177` 정지점 종결 | `dbt build` **PASS 527 / WARN 37 / ERROR 0 / TOTAL 564** 사용자 실행 ⇒ **정본화 완료** |
| 🔴 GA4 체인 회귀 규명·복구 | 3일치(1,299,412) → **33일 10,332,737** · `FACT` **1,620,857** · `WARN_GA4_LOAD_GAP` 30 → **0행** |
| 캘린더 근거부재 시정 | `1991~2035` → **`1945~2145`** · `DIM_DATE` **73,415** · `DIM_MONTH` **2,413** · 인용 4곳 동시 갱신 |
| `D1` 원장 재균형 | 조각 **15 → 18**(`--fill 0.62`) · 여유 **2 B → 15,680 B** · 유실 0 |
| `T1` `new_tool.py` | `test_*` **거절 가드** 신설(출구 없는 상태 제거) |
| `T2` + 🆕 쌍둥이 | `apply_table_comment_drift` · `apply_silver_comment_drift` **둘 다** `argparse` + `--apply` dry-run |
| 음성 테스트 신설 | `test_mutating_tool_safety.py` **19단정**(축⑤ 회귀 실증 · 오염 후 원복 단정) ⇒ **42 → 43종** |
| `V2` 종결 | `SV_SERVICE` 거짓 grain 제거 · `CREATE OR ALTER` 재배포 · **GRANT 7건 보존** · `created_on` 불변 |
| `V1` 원인 좁힘 | ML 0행은 **적재기가 돌았는데 0행** — 외부 Python 소관(형제 테이블 91,423행 · 동일 배치) |
| PII 전제 확정 | 생년월일 = 원천 제공자가 **의도적 제외** ⇒ **적재분은 비민감**(사용자 제공) |

🔴 **확정위반 6건 · 판정약점 2건** 전건 이력 `§O178 ▣6` 에 열거했다. 요약 =
`R0-8-2`(파이프 뒤 rc 6건 · 🟢 판정 오염 0) · `R1-7-10`(`SESSION_LABEL=O177` 오표기) ·
`R1-4-3`(라벨 선점 누락 — 🔴 **3세션 연속**) · `R4-2`(잔여 등급 오류 · 사용자 적발) ·
`R1-7-1`(`write` 전체재작성 2건 · 사후 4축 이행) · `O176-A-4` 기재 함정(`grep --include`) 재답습 ·
`R2-8-4`(실측 전 단정 1건 · 사후 실증됨) · `J2`(SV 스키마 오조회 · 자체 적발).

### ▣ O178-A-2 🟠 다음이 할 일 — ㉠ 이 작업의 잔여

1. 🔴🔴 **최우선 = 재배포 런북에 「GA4 일자 수 확인」 단계를 넣어라.**
   `10_dbt_pipeline/deploy_dbt_project.sql` 에 그 단계가 **없다** — 그래서 이번 사고가 났다.
   🟢 넣을 것 = 재배포 직후 `SELECT COUNT(DISTINCT EVENT_DT) FROM GN_DW.SILVER.BIGQUERY_BASIC`
   (기대 = 원천 일자 수와 같다) + `SELECT COUNT(*) FROM GN_DW.OPS.WARN_GA4_LOAD_GAP`(기대 0).
   🔴 **일일 배치 Task 를 RESUME 하기 전에 이것을 넣어라** — 자동화되면 사고가 무인으로 반복된다.
   ⚠️ 현재 Task RESUME 상태를 **재라**(이번 세션은 확인하지 않았다 · `SHOW TASKS`).

2. 🔴 **`FACT_EVENT_ATTENDANCE.DATE_SK=0`** — 🔴🔴 [2026-09-22 O178-C 정정] 종전 기재 **162,888** 은 **재현되지 않는다** — 사용자가 `06_DDL`+`08_SILVER_테이블DDL` 전체 재실행 후 전량 재적재한 뒤 실측 = **50** 이고 문서20 §C 원 기재(`FEP.DATE_SK 50→0`)와 일치한다. 총행 **1,258,775** = 원천 `CRM_EVENT_PARTICIPATION` 과 **1:1**. 🔴 원인 미규명 — 후보 = GOLD 팩트 **5종**에 모델 리터럴 `pre_hook=TRUNCATE` 가 남아 있고 `gold_fact_purge` else 분기도 TRUNCATE 라 **hook 이 이중 실행**된다(`dbt_project.yml:239-244` 가 경고한 누적 구조) ⇒ 조사 대상. 종전 문안: 범위밖이 아니라
   `COALESCE(date_sk(PARTCPT_DT), date_sk(EVENT_START_DATE), 0)` 의 **양쪽 NULL** 이다.
   🔴 캘린더 확장으로 줄지 않는다. 규모가 커서 `WIDE_EVENT_PARTICIPATION` 날짜 집계가 이미
   부분집합일 수 있다 ⇒ 원천 NULL 분해가 선행이다.

3. 🟠 **`G1` `A4-W` 배선 6건**(`O176-A-2 #3` → `O177-A-2 #4` 2세션 승계) —
   1번이 `FACT_BIGQUERY_BEHAVIOR.CAMPAIGN_SK` ← `SILVER.BIGQUERY_EVENT.UTM_CAMPAIGN`(실재 확인).
   🔴🔴 **배선 후 전량 백필이 의무다** — 창 밖 과거 행은 센티넬로 남아 **에러 없이** 과거 지표가 틀린다.
   🟢 이번 세션이 ⓐ 백필을 **전량으로 실증**했으므로 절차는 확립됐다(`dbt_project.yml` vars 주석).
   🔴 `FACT_AD_*` 4건은 `Q10` 이름매칭 선행 · `A4-X` 8건은 배선 대상이 아니다(원천에 키 부재).

4. 🟠 **`MUTATES` 무플래그 기지목록 11건 처분** — `test_mutating_tool_safety.py` 의 `KNOWN_NO_FLAG`.
   🔴 **목록에서 이름을 빼는 것이 종결이다**(추가는 금지 · 고치면 stale 축이 FAIL 로 알려준다).
   🟢 분류 = 일회성 7건(은퇴 후보 `_o169_*`·`_o170_*`·`patch_o63*`·`o54_*`·`move_o63_*`) ·
   SV 배포 2건(`deploy_sv`·`deploy_ml_semantic_views` ⇒ `extract_sv_deploy` 경로로 통합 후보) ·
   분류 재판정 2건(`nl_routing_smoke`·`gen_o53_ad_combined`).

5. 🟠 **`ga4_lookback_days`(현재 3) 재검토 / 2단계 DISTINCT 차원 MERGE** — `O177-A-2 #3·#5` 승계.
   🔴 2단계는 **운영 일일 런 실측 선행**(3분이 문제가 아니면 이익 0).

6. 🟡 **경량 COMMENT 정정** = `AGE` COMMENT 「연령」 → 「연령대 코드(CM014)」 **3테이블**
   (`SND_MEMBER_LIST`·`TM_MM_FDRM_MBER_DVLP_AMT`·`TM_MM_FDRM_MBER_IRSD`) ·
   `SND_MEMBER_LIST.AGE` 코드형 `12` **8행** 혼입 · NULL **53.3%** 기재 ·
   `O34`(생년월일 축 부재) 인용처에 **PII 전제**를 함께 달아 재스캔을 막을 것.

7. 🟠 `stage_mount_size_gate` **드리프트 8건** — 전건 `_archive`/무관 문서이고 **마운트=스테이지**,
   골든만 16 B 낡았다. 🔴 골든 재발행 시 `--reason` 에 8건 전량 규명 의무.

### ▣ O178-A-3 ⚪ 이 세션의 소관이 아닌 것 — ㉡ 워크스페이스 백로그

🔴 **`O176-A-3` 을 승계한다**(좌표 = `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0176-A.md:81`) —
단 아래는 이번에 **닫혔으니 다시 열지 마라**: `㉢ SV_SERVICE 거짓 grain` · `㉦ new_tool test_*` ·
`㉧ apply_table_comment_drift dry-run` · **원장 여유 부족**.

· 🔴 **현업 회신 대기** = `§N-13`(교체본 · 🔴 옛 `SER_NO 1..N` 문안으로 보내지 마라) · `§N-18`(GSC) ·
  `§N-17`(`FUNDRAISING_COST`) · `§M-2`(`SV_SERVICE.SUBTYPE`) · `§M-6`(`SEND_STATUS2`) · `Q10` ·
  `AGENCY_CONV_CNT` 어의 · 이슈 A/C/D. 🔴 **착수 전 실측하라**(`J3` — O166-D 가 3회 헛돌았다).
· 🔴 **`V1` `ML_RST_DATA_SPNSR_CHURN_12M` 0행** = 외부 적재기 소관. 물을 것 =
  적재 실패인가 / 표본 설계인가 / `SV_ML_SPONSOR_RISK` 를 비활성할 것인가(라이브 전건 0 을 반환 중).
· 🟠 §4 밖 미결 결정 2건 = **개명 런북 3안**(`O174-B-3`) · **스킬 본문 분할**(여유 5,592 B).
· 🟠 `decision_closure_gate` 미봉합 2건(`DEC-41 ▸ O8` · `90_해소완료_로그-010.md:178,180`).
· 🟠 `O167` 이력 항목 부재 · `DEC-44` 붕괴 재현 실패 · `_o169_evidence.md:387` 오기 ·
  정보량0 잔여 분해(ㄴ85·ㄹ53) · 미정의 `P` 334종 + 절제목형 인정 축 개선 · 로드맵 10 문서화.
· 🔴 **착수표 ⑭·⑩ 무변경** — `J3` 로 착수 전에 재라.

### ▣ O178-A-4 🔴 환경 함정 (이번에 실제로 밟은 것)

· 🔴🔴 **Snowsight 에서 `EXECUTE DBT PROJECT` 로 돌린 빌드는 `target/` 에 artifact 를 남기지 않는다.**
  마운트의 `target/run_results.json` 은 **이전 CLI 빌드 것**이라 `generated_at` 이 낡아 있다
  ⇒ 사용자 빌드 결과는 **`logs/dbt.log` 가 아니라 라이브(OPS 테이블·행수·쿼리이력)로** 대사하라.
· 🔴🔴 **`INFORMATION_SCHEMA.QUERY_HISTORY` 가 이번 규명의 결정적 축이었다** —
  렌더된 DELETE 술어를 보면 **어느 버전이 돌았는지**가 그대로 나온다. 🟢 dbt 를 돌리지 않고도
  「무엇이 실행됐는가」를 잴 수 있는 유일한 경로다. ⚠️ `ROWS_DELETED` 컬럼은 **없다**(`ROWS_PRODUCED`).
· 🔴 **BusyBox `grep` 에 `--include` 가 없다** — `O176-A-4` 에 적혀 있는데 또 밟았다 ⇒ **Grep 툴**을 쓰라.
· 🔴 **`edit` 툴의 `replace_all` 이 동일 장문 줄 2곳에서 듣지 않았다**(「multiple times」로 거절) ⇒
  🟢 **python 줄 인덱스 치환**으로 우회했다(`R1-7-8` 이 이미 권하는 경로) · 백틱 포함이라 `_scratch_` 파일 경유.
· 🔴 `SHOW SEMANTIC VIEWS ... IN SCHEMA GN_DW.GOLD` → **0건**. SV 는 **`GN_DW.SERVING`** 에 있다(`J2`).
· 🟢 `cortex conversations transcript` 는 **JSONL**(줄마다 1 JSON)이다 — `json.load` 는 실패한다.
  🟢🟢 그 안에 **`tool_use` 블록이 그대로 실려 있다** ⇒ 자기검토를 **문장 회상이 아니라 도구 호출 전수**로
  할 수 있다(이번에 77건을 축별로 셌다). 🔴 단 **직전 턴까지만** 담긴다(현재 턴 호출은 없다).
· 🟢 `cortex ws ls <경로>` 는 기대한 출력을 주지 않았다 ⇒ 스테이지 실체는 **`LIST 'snow://…'`** 로 확인.
  🟢 스테이지 크기는 **16 B 패딩**된다(30,857 → 30,864) — 불일치로 오판하지 마라.

### ▣ O178-A-5 📏 종료 기준선 (2026-09-22 · 계정 `LK96056` · 🔴 인용하지 말고 재라)

· dbt build **PASS 527 / WARN 37 / ERROR 0 / TOTAL 564** · 음성 테스트 **43종 rc=0**
· `BASIC`·`EVENT` **10,332,737 / 33일**(2024-01-29~2026-09-14) · `FACT_BIGQUERY_BEHAVIOR` **1,620,857**
· `DIM_DATE` **73,414 + Unknown 1**(1945-01-01~2145-12-31) · `DIM_MONTH` **2,413**
· `OPS` 9테이블 · 감시 4종 **전부 0행**(`WARN_GA4_LOAD_GAP` 30 → 0)
· `FACT_MEMBER_EVENT.DATE_SK=0` **90**(1900-01-01 88 + 9999-12-31 2 · 확장 후에도 탐지 유지)
· 🔴 `FACT_EVENT_ATTENDANCE.DATE_SK=0` **50**(재적재 후 실측) — 🔴🔴 [2026-09-22 O178-C 정정] 종전 기재 **162,888** 은 **재현되지 않는다** — 사용자가 `06_DDL`+`08_SILVER_테이블DDL` 전체 재실행 후 전량 재적재한 뒤 실측 = **50** 이고 문서20 §C 원 기재(`FEP.DATE_SK 50→0`)와 일치한다. 총행 **1,258,775** = 원천 `CRM_EVENT_PARTICIPATION` 과 **1:1**. 🔴 원인 미규명 — 후보 = GOLD 팩트 **5종**에 모델 리터럴 `pre_hook=TRUNCATE` 가 남아 있고 `gold_fact_purge` else 분기도 TRUNCATE 라 **hook 이 이중 실행**된다(`dbt_project.yml:239-244` 가 경고한 누적 구조) ⇒ 조사 대상.
· `FACT_MESSAGE_DISPATCH` **41,969,590** · `CAMPAIGN_SK=0` **전건** · distinct **1**
· `BIGQUERY_IDENTITY` 고아 **234행 / 206키**(= 기지 WARN 37 중 BIGQUERY 하위트리 유일 건)
· `ML` 16테이블 — 🔴 `ML_RST_DATA_SPNSR_CHURN_12M` **0행**(형제 `MBER_CHURN_12M` 91,423)
· 원장 조각 **18** · 최소 여유 **15,680 B** · `gate_census` 미분류 0 · 유령 0 · 임시계측기 0
· `dbt_schema_lint` **3,228 단정 rc=0** · `index_row_gate` rc=0 · `line_len` PASS
· `SV` **17종** · `SV_SERVICE` GRANT **7건 보존** · `id_collision_gate` `O` 정의·참조 **177** ⇒ 다음 **O179**
· 🟠 `stage_mount_size_gate` 드리프트 **8건**(전건 무관 문서 · 마운트=스테이지 · 골든 16 B stale)
· 🔴 **BRONZE_CRM 에 생년월일 컬럼 0건**(`GN_DW` 전 스키마 0건 · `O34` 기확정) — 재스캔하지 마라

_Co-authored with CoCo_

_Co-authored with CoCo_
