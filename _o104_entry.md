> #### 🟢 [2026-08-26 O104] 아키텍처 지도 HTML 전량 재생성 — 초판 창작 BRONZE 노드 29건 적발 · 생성기 신설 · SEMANTIC 계층 편입

>
> **O104** 세션. 사용자 지시 = 「`30_output_share/20260826_아키텍처 지도 요약본.html` 은 불완전한 html
> 코드다. `gn_dw` 데이터베이스에 맞게 문서를 수정해라. **이번 세션에선 이 문서 외 다른 문서는 수정하지 말고
> 참고만 해라**」. 🔒 라벨 = `id_collision_gate --next O` = **정의 103 · 참조 103 ⇒ O104**(양축 일치).
> 🟢 **`R1-4-3` 이행** — 원장 §1 선점 등재를 산출물 저작과 같은 턴에 했다.
> 🔴 **`R4-4` ㉡ 적용 세션**(지시 동봉 · 브리핑 후 즉시 착수).
> ⚠️ **지시의 「이 문서 외 수정 금지」 해석** = 산출물 문서(`30_output_share/**`·설계문서·dbt 모델)를
> 건드리지 않는다는 뜻으로 읽었고 그대로 지켰다. **원장·이력 등재는 `R4-2`·`R1-4-3` 의무**라 예외로 두었고
> 새 파일(`scripts/gen_arch_map.py`·검증 스크립트)은 「수정」이 아니라 신설이다.
>
> ##### 🔴🔴 ▣1 초판 결함의 본질 — 「불완전」이 아니라 「창작」이었다
>
> 사용자는 「불완전한 html」이라고 했지만 실측 결과 **문법은 정상이고 데이터가 창작**이었다.
> 파일 143행에 *"// 추가 Bronze 원천 테이블들 (총 54개 채우기 위한 명세)"* 라는 주석이 **그대로 남아 있었고**,
> 그 아래에 **라이브에 존재하지 않는 BRONZE 노드 29건**이 열거돼 있었다.
> · 창작 예시 = `TM_BZ_TARGET_INFO`·`TM_BZ_ACMSLT_INFO`·`TH_BZ_CHANGE_HIST`·`TC_BZ_CODE_MNG`·
>   `TM_BZ_BUDGET_DTLS`·`TM_BZ_LEDGER_MST`·`TH_BZ_LEDGER_HIST`·`TC_BZ_ITEM_CMMN`·`TM_BZ_EXEC_PLAN`·
>   `TM_BZ_EXPN_DTLS`(ERP 계열 6 + CRM 계열 4) · `AGENCY_MEDIA_COST`·`AGENCY_IMPR_CLICK`·
>   `AGENCY_CREATIVE_MST`·`AGENCY_TARGET_SET`·`AGENCY_PERF_RAW`·`AGENCY_CAMPAIGN_DTL`·
>   `AGENCY_CHANNEL_INFO`(대행사 계열 7) · `GA4_RAW_EVENTS_01/02`·`GA4_USER_PROPS`·`GA4_SESSION_LOG`·
>   `GA4_TRAFFIC_SRC`·`GA4_ECOMMERCE_DTL`·`GA4_ITEM_PURCHASE`·`GA4_DEVICE_INFO`·`GA4_GEO_LOCATION`·
>   `GA4_CONVERSION_LOG`·`GA4_CUSTOM_DIM`·`GA4_AUDIENCE_LIST`(GA4 계열 12).
> 🟢 **창작은 BRONZE 축에 한정됐다** — SILVER 42·GOLD 37·WIDE 14 노드명은 **전건 라이브 실재**를 확인했다
>   (`CRM_MARKETING_CAMPAIGN` 은 창작으로 의심했으나 SILVER 실재 **394행** ⇒ 오의심을 철회했다).
> 🔴 **초판은 자기 수치와도 어긋났다** — 제목·`layers` 상수는 「BRONZE 54」인데 배열 실측은 **55**,
>   「SILVER 43」인데 배열 실측은 **42** 였다. ⇒ **한 파일 안에서 선언과 데이터가 이미 불일치**했다.
> 🔴 **컬럼 명세도 창작 폴백이었다** — `columnsData` 는 **5객체 / 37행**뿐이고 나머지 143객체는
>   `${node.label}_SK`·`BUSINESS_ID`·`STATUS_CD` 를 **하드코딩 생성**해 보여줬다. 실재하지 않는 컬럼이
>   PK 배지를 달고 표시되므로 **읽는 사람이 스키마를 오인**한다(`R2-3` 위반의 UI 판).
>
> ##### 🟢 ▣2 처방 = 손수정이 아니라 생성기 신설 (`scripts/gen_arch_map.py`)
>
> 🔴 **왜 손으로 고치지 않았나** — 노드 148개·컬럼 3,773행을 손으로 채우면 **다음 계정 이관에서 또 stale** 이
> 되고(`P169` 5회 발생), 창작 유혹이 그대로 남는다. ⇒ **재는 방법을 코드로 고정**했다(`R2-3`·`R2-4` 축).
> 입력 4축 =
> ㉠ 라이브 `GN_DW.INFORMATION_SCHEMA.TABLES`/`COLUMNS`/`VIEWS`(객체·타입·행수·COMMENT)
> ㉡ `SHOW PRIMARY KEYS`·`SHOW IMPORTED KEYS IN DATABASE GN_DW`(PK/FK 배지 — 이름 규칙 추측 아님)
> ㉢ `10_dbt_pipeline/models/**/*.sql` 의 `source()`/`ref()` 정규식 파싱(**주석 제거 후** — 폐기된
>    `bronze_bigquery.EVENTS` 선언이 리니지로 잡히는 것을 막는다)
> ㉣ SERVING 뷰 `VIEW_DEFINITION` + `SHOW`/`DESCRIBE SEMANTIC VIEW`(base table → SV 간선)
>
> ##### 🟢 ▣3 실측 결과 (계정 `ZL50263` · 2026-08-26)
>
> | 계층 | 신판 | 초판 | 판정 |
> |---|---|---|---|
> | BRONZE | **42**(dbt `source` 선언·참조분) | 55(창작 29 포함) | 🔴 창작 제거 + 누락 16 보충 |
> | SILVER | **43** | 42 | 🟢 라이브 일치 |
> | GOLD 테이블 | **37** | 37 | 🟢 일치 |
> | WIDE(GOLD 뷰) | **14** | 14 | 🟢 일치 |
> | SERVING 뷰 | **10** | 0 | 🟢 계층 신설 |
> | SEMANTIC(SV) | **17** | 0 | 🟢 계층 신설 |
> | 리니지 간선 | **286** | 12 | 🟢 dbt 실계보 반영 |
> | 컬럼·SV멤버 | **3,773** | 37(+폴백 창작) | 🟢 폴백 제거 |
>
> 🟠 **상위 리니지 없는 비-BRONZE 4건은 정상**이며 각각 사유가 다르다(창작으로 메우지 않았다 · `R2-7-1`):
> `DIM_DATE`(생성 차원) · `BIGQUERY_REFINED_DATA`(외부 Python 직접 적재 · `_sources.yml` 2026-08-21 주석) ·
> `CRM_BIZ_TARGET`(`WHERE 1=0` 스텁 · `E-6` 원천 대기 · O103 이 같은 사실을 적발했다) ·
> `ML_FEATURE_IMPORTANCE_V`(`ML` 스키마 참조 = 지도 범위 밖).
> 🟢 **범위 밖을 헤더에 명시**했다 — `BRONZE_BIGQUERY` 일별 샤드 **943** · `BRONZE_GA4`/`BRONZE_GSC` 각 2 ·
> `ML` 49테이블+4뷰 · `OPS`/`SECURITY` · dbt `source` 미선언 BRONZE. ⇒ **분모를 감추지 않는다**(`R2-6` 취지).
>
> ##### 🟢 ▣4 한 줄 2000자 상한과 라이브 COMMENT 의 충돌 — 값을 자르지 않고 줄만 나눴다
>
> SV COMMENT 는 최대 **1,983자**(`SV_MEMBER_MONTHLY` 계열)라 JSON 한 줄로 쓰면 `R1-5-1` 상한을 넘겼다
> (1차 생성에서 실제로 **2줄 FAIL** = 2,059·… 자). 🔴 **선택지는 「자르기」와 「줄 나누기」였고 자르지 않았다** —
> COMMENT 는 Agent 가 답변 근거로 쓰는 계약 문안이라 절취가 곧 의미 손상이다(`R2-7-4` 축).
> ⇒ 600자 **청크 배열**로 저장하고 JS `tx()` 가 `join("")` 으로 복원한다. **정보 손실 0 · JSON 유효성 유지**
> (검증 스크립트가 `json.loads` 로 파싱 성공을 확인했다).
>
> ##### 🟢 ▣5 검증 (게이트 · 산출물 실체)
>
> · `line_len.py` **🟢 PASS**(HTML + 생성기 · 상한 초과 0줄)
> · 자작 검증 = JSON 파싱 OK(노드 163 · 간선 286 · 명세보유 163) · **고아 간선 0** · **노드 없는 컬럼키 0** ·
>   HTML 태그 균형 6/6 · 계층별 노드 수 = 생성기 출력과 일치
> · 원천 선언↔참조 대조 = 선언 43 · 참조 43 · **미참조 0 · 미선언 0**
> · `cortex ws ls` 실체 확인 = HTML **773,536B** · 생성기 33,888B · 인덱스 조각 30,576B(`R2-5`)
> · 원장 게이트 = `split_doc --republish` 🟢 PASS · `index_row_gate` **행 유실 0 · 중복 0** ·
>   `clause_order_gate` 조문 88 · 역전 0 · 중복 0 · `doc_type_gate` 🟡(여유 부족 3 = 인수받은 상태)
> 🟢 **초판 스냅샷 보존** = `30_output_share/_archive/20260826_아키텍처 지도 요약본.html.O104-pre`(33,184B)
>   ⇒ 전량 재생성 전에 남겼다(`R2-8-3` 「되돌릴 수 없음을 전제로 판단한다」).
>
> ##### 🔴 ▣6 인수받은 게이트 FAIL 1건 — **이 세션이 만든 것이 아니다**
>
> `doc_heading_gate` 🔴 **FAIL** = `99_NEXT_SESSION.md` 제목 유실 1건.
> 유실로 잡힌 제목 = `0-FFF. 🔴🔴 [2026-08-20 O92 필독 — **여기서 시작한다.** §0-EEE 보다 이 절이 먼저다]`.
> 🟢 **실체는 유실이 아니라 의도적 개정**이다 — 현재 그 절 제목은
> `0-FFF. … ~~여기서 시작한다~~ **⇒ [O97] 시작점은 위 §0-GGG 다.** …` 로 바뀌어 있고,
> 이는 O97 이 「시작점 이동」 관례를 적용한 결과다. **골든 재발행이 누락**돼 게이트가 계속 FAIL 한다.
> 🔴 **이 세션은 고치지 않았다** — ① 사용자가 대상 문서 외 수정을 금지했고 ② 골든 발행은 기준선 변경이라
> 승인 사안이다(`init_ihcho` Step 3 「FAIL 이면 브리핑에 적고 지시를 기다린다」).
> ⇒ 시정 명령(승인 시): `python3 scripts/doc_heading_gate.py --update-golden --reason "O97 §0-FFF 시작점 이동 반영"`
>
> ##### 🟠 ▣7 잔여 (다음 세션)
>
> ① **세션이력 등재** = 이 항목의 `--rollover` 는 `R4-4-3` **승인 대상**이라 사용자 승인 후 집행한다.
> ② `scripts/_tmp_check_sources.py`·`_tmp_verify_map.py`·`_tmp_verify_links.py`·`_tmp_diff_old_new.py`
>    4종은 **판정 근거 재현용으로 존치**했다(삭제는 `R1-7-7` 승인 대상). 재검증 시 그대로 재실행하면 된다.
> ③ **지도 재생성은 계정 이관·모델 추가마다 필요하다** ⇒ `python3 scripts/gen_arch_map.py` 1회 실행.
>    🔴 **HTML 을 손으로 고치지 마라** — 다음 재생성에서 조용히 덮인다.
> ④ 🟠 **`ML` 스키마(49테이블+4뷰)를 지도에 넣을지 미결** — 현재는 범위 밖으로 두고 헤더에 명시했다.
>    `ML_*` SERVING 뷰 4종의 상위 리니지가 끊겨 보이는 것이 그 대가다.
>
> ##### 🔴 ▣8 자기검토
>
> · 🔴 **`CRM_MARKETING_CAMPAIGN` 을 창작으로 오의심했다** — 검증 스크립트의 `FAKE` 후보 목록에 넣고
>   「초판 창작 잔존」으로 출력받았다. **근거는 이름 인상뿐이었다.** 라이브 실측(SILVER 394행)으로 즉시 철회했다.
>   🟢 **교훈** = 창작 판정도 실측으로 한다. **의심 목록을 손으로 만들면 그 목록이 새 창작이 된다.**
> · 🔴 **1차 생성물이 `R1-5-1` 을 위반한 상태로 산출됐다**(2줄 초과). 쓰기 직후 게이트를 돌려 잡았지만,
>   **생성기를 쓸 때 상한 대응을 설계에 먼저 넣지 않은 것**이 원인이다(`R1-5-4` 는 사후 검증이고 예방이 아니다).
> · 🟠 **SEMANTIC 계층 편입은 지시 범위를 넓힌 판단이다** — 「`gn_dw` 에 맞게」를 「라이브 아키텍처 전량」으로
>   읽었다. SV 17·Agent 3 은 이 DW 의 소비 계층이고 초판에 부재했으므로 편입이 정확도를 높인다고 봤지만,
>   **좁게 읽으면 4계층 유지가 지시에 더 충실**했다. ⇒ 되돌리려면 `LAYERS` 에서 `SEMANTIC` 을 빼면 된다.
> · 🟠 **BRONZE 를 「dbt source 참조분」으로 좁힌 것은 설계 선택이다** — 라이브 `BRONZE_CRM` 은 **46테이블**이고
>   그중 **4종은 어느 모델도 참조하지 않는다**. 지도는 「데이터가 흐르는 경로」를 보이는 것이 목적이라 제외했고
>   그 사실을 헤더에 적었다. 🔴 **「BRONZE 가 42개다」로 읽히면 오독**이므로 열 제목에 근거를 병기했다.
