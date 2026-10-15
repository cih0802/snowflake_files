<!-- LLM-METADATA
doc_id: HANDOFF_O0231_A
doc_role: 인수인계 — 세션 `O231-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-15
created_by: O231-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0231-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.** 현행 판정식 = 라벨 최대값 ⇒ 이 파일이 `O0230-A` 를 승계한다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다.

### ▣ O231-A-0 🔴 먼저 알아라

- 개발계 = jw08094 · 2026-10-15 · **운영계 반영 없음**(전건 👤 운영계 대기 · 런북 §7 ⑲ · §7-A 순서).
- 라이브(jw08094) = AGENT_MARKETING default **VERSION$8**(롤백 $6 · 🔴 **$7 은 반영 실패본 = $6 과 같은 스펙**) · AGENT_EXECUTIVE default **VERSION$7**(롤백 $6) · BIZ_DEFINITION_CORPUS 2,154행 · SEARCH_BIZ_DEFINITION REFRESH.
- 🔴 이 세션 중 샌드박스 `/workspace` 마운트가 끊겼다(`Untitled.sql` 만 보임 · stage 원본 정상). 우회 = `cortex ws cp` 로 `/tmp/ws` 미러 → 편집 → 업로드 · dbt 는 클라이언트 실행이라 **업로드 후** build.
- 🔴 Agent 스테이지는 **`COPY FILES … FROM 'snow://workspace/…'` 로만** 갱신한다 — snowpark PUT 직후 ADD VERSION 은 에러 없이 직전 스펙으로 버전을 만들었다(MKT $7). ADD VERSION 뒤 `SHOW VERSIONS` 의 `agent_spec` 문자열 대조 필수.

### ▣ O231-A-1 이번 단위 결과

| 순 | 결과 |
|---|---|
| ① 하드코딩 검토(O-HC) | FME `DEV_CNT_RAW`·`DEV_EXCL_REASON`(DEV_CNT 불변 · 해시 대조) · `macros/gn_biz_codes.sql`(코드 단일 정의 · 렌더 동일 · 7팩트 해시 불변) · 증액 42.1% 가 0 처리(회원월상계 72.6억·141,174건 최대) |
| ② 컬럼 순서 | FME 신규 2컬럼 06_DDL·모델 SELECT 를 라이브(맨 끝 58·59)에 맞춤 |
| ③ FMC 결정화 | 대표 획득건 정렬에 SPONSORSHIP_SK·ORG_SK·DVLP_DIV_CD·출력속성 HASH 추가 · build 2회 해시 동일(1628658369165474283) · FMSS 동률 0 |
| ④ WIDE·SV 노출 | WIDE_MEMBER_EVENT 2컬럼 · SV_MEMBER_EVENT `DEV_EXCL_REASON` 차원 + `TOTAL_DEV_CNT_RAW`·`TOTAL_DEV_EXCLUDED_CNT` · 스모크 사유 8행 |
| ⑤ BRONZE_BIGQUERY | RT-24 · MKT analyst_ad · 🆕 EXEC 2곳(지침·도구) = 「광고 SV 의 직접 원천이 아니다(운영계 프로시저 정제 → SILVER)」 |
| ⑥ LTV ②-a~c | FMC `OBS_TENURE_DAYS`·`OBS_TENURE_MONTHS`·`IS_STOPPED_OBS`(제외 20명 · 음수 0) · `GOLD.WIDE_MEMBER_COHORT_SURVIVAL`(KM · 5축 · vars `ltv_caps [36,60]`·`ltv_learn_start null`·`ltv_min_cell 500`) · SV_MEMBER_COHORT `surv` 테이블 + EXP_TENURE_36M·60M·SURVIVAL_12M/36M/60M·SURVIVAL_RATE · AVG_TENURE_DAYS = 「중단자 평균」 명확화 |
| ⑦ 검증 | 전체 표준 RMST **27.36 / 40.73**개월(사용자 결정 = 표준식) · O230 식 27.97/41.23 재현(1항 과대) · 24개월 코호트 인입경로 14.0~21.7(O230 14~22 일치) |
| ⑧ ②-d 비교표 | `12_agent개선과제/output/O231_LTV_현업비교표.md`·`.csv`(72행 · 상한 12·24·36·48·60 전부 · 현행 2종 · LTV · 1,000명 예시) |
| ⑨ 런북 | §7 ⑲ O231 행 · §7-A 「SV 배포 전 dbt build + 소유자 롤 컬럼 선반영」 7단계 · 스테이지 COPY FILES 규칙 |

### ▣ O231-A-2 ㉠ 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 👤 현업 LTV 회신(상한·학습기간·중단기준·셀최소·월회비) → vars 수정 → RT-14·RT-27·Agent LTV 지침 교체 | #32 회신 반영 |
| ② | 👤 현업 = 회원월상계 의도 여부 · 근거 없음 하드코딩 8건 | #33 회신 반영 |
| ③ | 👤 운영계 반영 = O230 잔여(VERSION$6·SV_AD 2차·#31) + O231 전건(런북 §7 ⑲ · §7-A) | 운영계 |
| ④ | 하드코딩 추천 잔여(개발계 가능) = 발송 제목 정규식·행사 상태 한글 라벨·ERP 'TOTAL' → 코드 기준 전환 또는 라벨 변경 warn 테스트 | 미착수 |

### ▣ O231-A-4 ⚪ 결정 완료(재론 금지)

- LTV 기대 유지개월 = **표준 RMST**(Σ_{m<τ} P(T ≥ m)) · 상한별 값을 전부 현업에 공유(사용자 O231).
- DEV_CNT(MSTR 정의)는 바꾸지 않는다 · 상계 전 값·사유는 별도 컬럼(사용자 O-HC).
- O230-A-4 결정 전건 유지(이중계상 방지로 원천 금액 0 금지 · 키워드 매핑 안 함 · 90_provided_definition 불변 · eval = 운영계).

_Co-authored with CoCo_
