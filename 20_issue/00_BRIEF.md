<!-- LLM-METADATA
doc_id: SESSION_BRIEF
doc_role: 세션 착수 브리핑 — 열린 작업·인수인계·게이트 상태의 **색인**(정본 아님)
project: GN_DW (굿네이버스)
created: 2026-08-28
created_by: O106
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

# 00_BRIEF — 세션 착수 브리핑 (자동 생성)

> 🔴🔴 **이 파일은 자동 생성물이다 — 여기에 내용을 쓰지 마라.**
> `python3 scripts/session_brief.py --write` 가 **통째로 다시 쓴다**
> ⇒ 손으로 적은 문장은 **조용히 사라진다**(허브와 같은 계약 · `R1-6` 축).
> 내용은 정본(원장 조각 · `99_NEXT` 조각 · 문서50 조각)에 쓰고 이 파일을 재생성한다.

> 🔴 **이 브리핑은 색인이고 정본이 아니다.** 각 항목은 **제목 + 상태 + 좌표**만 싣는다.
> 판정·수치를 인용하려면 **그 좌표를 `read` 해야 한다**(`R1-3-7` 「대체 근거 금지」).
> 🟢 대신 **무엇을 읽어야 하는지**가 여기 다 있다 ⇒ 전량 독해가 불필요해진다.

> 📏 생성 시각 기준 실측 = 아래 수치는 **전부 파일에서 센 것**이다(창작 0).

## 1. 열린 작업 — 착수표 (정본 = `99_NEXT_SESSION` 착수 순서)

> 판정 = 「순」 셀이 **취소선이 아닌 행**. 취소선(`~~⑨~~`)은 완료 관례다.

| 순 | 작업 | 정지점 | 정본 좌표 |
|---|---|---|---|
| ① | 테스트 2종(C-1 ②③) | run_sql_file.py 기본 dry-run + --ap… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:27` |
| ② | R95 반영 | Q01 → 05_07 캠페인유형 3열 열거 = 운영계 공통값… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:28` |
| ③ | 데분_2 | 제작비 = 콘텐츠구분자 기재분(현업 확정) 문안 · 06_D… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:29` |
| ④ | 데분_1㉡·6 | 최종 광고비 = 디지털 LAST_STMT_AMT + 영상 L… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:30` |
| ⑤ | 데분_4 | 80 = CEIL(관측 중 회원 평균 유지개월 79.13 ·… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:31` |
| ⑥ | 데분_7 | 영상광고 원천 DVLP_CNT = 2026-06~08 전 행… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:32` |
| ⑦ | 출처명 | Agent 표기 = 디지털 / 영상광고 / 방송(REBROA… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:33` |
| ⑧ | 데분_1㉠ | CRM 개발건 FACT_MEMBER_EVENT.MKTG_CM… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:34` |
| ⑨ | R96 | 85_실제 인수인계 문서/30_현업요청대응/_근거쿼리/R96… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:35` |
| ① | 👤 dbt 재배포 + build --select FACT_MKTG_CAMPAIGN_MONTHLY_COST → 47 [D2] 대사(개발계) | 사용자 실행 · 기대 = 2026 최종 광고비 디지털 145… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:41` |
| ② | 47 [D3] SV 4종 + [D4] Agent 재배포 → [D5] sv_code_label_gate 8조각 → Agent 재질문(데분_1·4·5·6·7·출처) | R4-4-3 · 개발계 → 운영계 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:42` |
| ③ | 👤 운영계 R96 실행 → 데분_5 원인 확정(제작비 기재 패턴·적재 시각 · 어제/오늘 SQL 차이) · daily FAILED 원문 | 운영계 회수 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:43` |
| ④ | 데분_1㉠ DEV_CNT_CRM 컬럼 추가 설계 | 🔴 현업 정의 1회 확인 = CRM 개발건수가 사건 수인지(… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:44` |
| ⑤ | 데분_7 처방 | 🔴 현업 확인 = 영상광고 「실제 마감값」 기준(MSTR D… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:45` |
| ⑥ | 방송 TOT_COST 2026-09·10 전 행 NULL(콜센터운영비 미입력 · 개발계) | 운영계 R96 Q10 으로 확인 → 현업 입력 요청 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:46` |
| ⑦ | SV_AD 에 최종 광고비 지표(WIDE_AD_COMBINED 에 TOT_COST 없음) | 필요 시 후속 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:47` |
| ⑧ | 80 패키지 재빌드(build_handoff.py) — run_sql_file 사본·README 사본 갱신 | 다음 정리 시 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:48` |
| ① | 현업 회신문(데분 2·3차) — 데분_4·6 반영 · 데분_5·7 원인 · 출처명 · ㉠④⑤ 질문 | ㉠①② 후 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:54` |
| ② | O269-A-3 현업 회신 대기 묶음 · A-4 공지 2건 | 그대로 유효 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:55` |
| ③ | C-5 ERP YEAR 처방 비교 = 운영계 0건으로 보류(재발 시 ㉰ 격리 모델) | 종결 후보 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:56` |
| ① | 데분_4 LTV | Agent = 표 1개 · 8열 고정(마케팅캠페인 · 개발단… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-B.md:26` |
| ② | 데분_1㉠ CRM 개발건 | DEV_CNT_CRM·NEW_DEV_CNT_CRM = FAC… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-B.md:27` |
| ③ | 원천 문제 응답 | Agent 공통 규칙 1줄(추정·보정·대체 금지 · 「원천 … | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-B.md:28` |
| ④ | 게이트 | YAML 파싱 OK · line_len PASS · sv_n… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-B.md:29` |
| ① | 👤 개발계 dbt 재배포 + 전체 build → 47 [D2] 대사 + CRM 개발 합(2026 ≈ 271,588) 확인 | 사용자 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-B.md:35` |
| ② | 47 [D3] SV 4종(05_31 · 05_07 · 05_04 · 05_05) + [D4] AGENT_MARKETING 재배포 → [D5] sv_code_label 8조각 → Agent 재질문 6문항(데분_1·2·4·6·7·출처) | build 후 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-B.md:36` |
| ③ | 운영계 일괄 = 47 [D1] ALTER → dbt 재배포·전체 build → [D2] → [D3]·[D4] · R96 실행 | 개발계 검증 후 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-B.md:37` |
| ④ | 현업 회신문 = 데분_5·7·방송 총비용 미입력 → 「원천 확인 요청」만 | ③ 후 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-B.md:38` |
| ① | 47 [D2] 대사 | 2026 최종 광고비 팩트 18,576,820,130.67 … | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-C.md:26` |
| ② | CRM ↔ MSTR 개발건 | 2026 합 둘 다 271,588.3484 · 캠페인×월 셀… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-C.md:27` |
| ③ | SV 재배포 | 05_31(9) · 05_07(14) · 05_04(9) ·… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-C.md:28` |
| ④ | Agent | deploy_agents.py pre(SV 부재 0 · 스펙… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-C.md:29` |
| ⑤ | Agent 재질문 3 | LTV = 8열 표 그대로 + 상한 80 안내 · 9월 캠페… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-C.md:30` |
| ⑥ | sv_code_label 8조각(0~7) | 대상 SV 4종 🔴·🟠 0 · 잔여 🔴 4 = SV_GA_S… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-C.md:31` |
| ① | 운영계 일괄 = 47 [D1] ALTER(5열) → dbt 재배포·전체 build → [D2] → 05_31·05_07·05_04·05_05 → deploy_agents.py pre·deploy → R96 실행 | 👤 운영계 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-C.md:37` |
| ② | Agent 답변 관찰 = LTV 표에서 단가 이상치 캠페인(위기가정(함께한끼) CRM 개발 12건)을 Agent 가 임의로 표에서 제외함 | 현업 피드백 시 규칙 보강 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-C.md:38` |
| ③ | 현업 회신문 = 데분_1·2·4·6 반영 · 데분_5·7·방송 총비용(09·10월) 「원천 확인 요청」 | 운영계 반영 후 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-C.md:39` |
| ① | 05_31 | CRM 지표 동의어 첫 항목 = 「CRM 기반 개발(건)」 … | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-D.md:26` |
| ② | Agent | response ③ 문안 = 캠페인별 비용 표만 CRM 기반… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-D.md:27` |
| ③ | 접근 요건 실측(소스 spec · lineage --suggest) | AGENCY 유래 SV = SV_AD · SV_AD_INFL… | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-D.md:28` |
| ① | 접근 통제 방식 결정(배선 수정 + SV 단위 GRANT 권장 · 마스킹은 혼합 테이블만) · 역할 4종(마케팅·회원·기획실 분석가 · 팀장 VIEWER) 설계 | 🔴 사용자 결정 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-D.md:34` |
| ② | AGENT_EXECUTIVE 에서 analyst_ad(SV_AD) 제거 | ① 결정 후 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-D.md:35` |
| ③ | ML 공용 SV(SV_ML_REALTIME_SIMULATOR · SV_ML_FEATURE_IMPORTANCE 등)의 AGENCY·ERP 피처 포함 여부 실측 | ① 결정 후 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-D.md:36` |
| ① | 계획서 W1 원천 분류표(리니지 · 객체+컬럼 2층) | 즉시 가능 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-E.md:27` |
| ② | W2 소수 컬럼 오염 객체 처리안 · W5 dbt 권한 유지 방식 | 🔴 사용자 결정 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-E.md:28` |
| ③ | W3 경영 Agent analyst_ad 제거 · W4 48_RBAC SQL · W6 개발계 검증 · W7 게이트 | 승인 단계별 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-E.md:29` |
| ④ | W8 운영계 사전 실측 R97(역할 사용자·서비스·Streamlit 권한 방식·보조 역할) | 운영계 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-E.md:30` |
| ① | O270-C-2 운영계 일괄 반영(47 [D1] → 전체 build → [D2] → SV 4종 → Agent → R96) | 👤 운영계 · 05_31 은 O270-D 판본 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-E.md:36` |
| ② | 현업 회신문(데분 2·3차 · 원천 확인 요청 3건) | 운영계 반영 후 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-E.md:37` |
| ③ | 운영계 daily 10-29 FACT_AD_PERFORMANCE FAILED 원문(R96 Q01) | 운영계 회수 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-E.md:38` |
| ④ | O269-A-3 현업 회신 대기 묶음 · A-4 공지 2건 | 그대로 유효 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-E.md:39` |

## 2. 직전 세션 인수인계 (현행 절만)

> 🔴 **현행 시작점** = `99_NEXT_SESSION-O0270-E.md`
> · 좌표 = `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-E.md:1`
> · 판정법 = **라벨 파일 최대값**(O번호 → 접미 길이 → 접미) · 정본 = `handoff_write.py`
> 🟢 **취소선 승계 표기를 읽지 않는다** — 현행성이 파일 시스템의 사실이다(`O172`).
> 🔴 조각(`99_NEXT_SESSION-0NN.md`)에 남은 `## 0-XXXX` 절은 **전부 승계된 것**이다.
> 🔴🔴 **이 세션은 단위 5개다 — 전부 읽어라**(접미가 다른 것은 승계가 아니라 형제다):
>   · `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md`
>   · `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-B.md`
>   · `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-C.md`
>   · `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-D.md`
>   · `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-E.md`
> · 라벨 파일 색인 = `99_NEXT_SESSION_조각/00_인수인계_색인.md`

| 항목 | 좌표 |
|---|---|
| ▣ O270-A-0 🔴 먼저 알아라 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:17` |
| ▣ O270-A-1 결과 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:23` |
| ▣ O270-A-2 ㉠ 이 작업의 잔여 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:37` |
| ▣ O270-A-3 ㉡ 워크스페이스 백로그 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-A.md:50` |
| ▣ O270-B-0 🔴 먼저 알아라 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-B.md:17` |
| ▣ O270-B-1 결과 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-B.md:22` |
| ▣ O270-B-2 ㉠ 이 작업의 잔여 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-B.md:31` |
| ▣ O270-C-0 🔴 먼저 알아라 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-C.md:17` |
| ▣ O270-C-1 결과(개발계) | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-C.md:22` |
| ▣ O270-C-2 ㉠ 이 작업의 잔여 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-C.md:33` |
| ▣ O270-D-0 🔴 먼저 알아라 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-D.md:17` |
| ▣ O270-D-1 결과 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-D.md:22` |
| ▣ O270-D-2 ㉠ 이 작업의 잔여 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-D.md:30` |
| ▣ O270-E-0 🔴 먼저 알아라 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-E.md:17` |
| ▣ O270-E-1 ㉠ 이 작업의 잔여 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-E.md:23` |
| ▣ O270-E-2 ㉡ 워크스페이스 백로그 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0270-E.md:32` |

## 3. dbt 미결조치 — 열린 절 (정본 = `50_dbt_파이프라인_미결조치`)

> 판정 = 절 제목 선두 이모지가 🔴/🟠/🟡. 🟢/✅ 는 제외한다.

| 절 | 좌표 |
|---|---|
| 🟡 O259-1 — 조직 폐기 판정 Silver 이관(DEC-64) · SV 소계 행 금지 (2026-10-23 O259 · 개발계 SR61467 적용 · 운영계 ZL50263 2026-10-26 반영 · 잔여 = 현업 공지) | `20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-024.md:269` |

## 4. 최근 세션 (정본 = 원장 §1 상태 대시보드)

| 라벨 | 표제 | 상태 | 좌표 |
|---|---|---|---|
| `O270` | 🟡 O270 — O269-C-4 집행 + 마케팅 피드백 3차(데분_5 제작비 변동 · 데분_6 원천별 광고비 컬럼 · 데분_7 영상 개발실적 · 출처명 재방송→방송) 분석·반영 … | 🟡 테스트 2종 rc=0(run_sql_file dry-run/--apply · ERD 기대 수 유도 → ERD … | `20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md:106` |
| `O269` | 🟡 O269 — 잔여 작업 전수 정리(20_issue·98·85·60·12 문서 대조) · 사용자 보고 반영(현업 회신 3통 발송 · 운영계 개발계 동일 반영 · T1 TASK_… | 🟡 분류 완료 · 집행 결과 = 라벨 파일 | `20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md:107` |
| `O268` | 🟡 O268 — 선택 게이트 조각 분해(sv_code_label_gate --shard k/8 · optional_gates 등록표) · 실패 5종 처방(COMMENT 37 동기… | 🟡 게이트 comment_drift·live_change·rename_stale·sv_unit·table_ddl_… | `20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md:108` |
| `O267` | 🟡 O267 — O266-D-1 착수표 ①②③ + O266-E-2 백로그 ①③ 집행: 김나경·강지영 회신문 2통 · 요청목록 3종 13~15행(O265-1·O265-2·O266-… | 🟢 회신 2통(수치·계정 표현 0) · 3종 일치 · AGENT_MEMBER 템플릿 ID → template_id… | `20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md:109` |
| `O266` | 🟡 O266 — 마케팅 Agent 피드백 1~4(디지털 최종정산금액 병기 · 마케팅캠페인×월 광고비·정산·제작비·MSTR 개발 결합 팩트·SV 신설 · 캠페인명 재시도 · LTV… | 🟡 개발계 기존 환경 갱신 45~55 전건 반영 · [D2] 일치(PK 중복 0 · 3,960행) · AGENT_… | `20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md:110` |
| `O265` | 🟡 O265 — 현업 문의 대응: 알림톡·이메일 발송구분(대/중/소) 배선 · 메시지 형식 분리 · 알림톡 GA 열람 A·B 2축 · A 템플릿 단위 우선순위(① 질문 시 템플릿… | 🟡 🆕 [O266] 개발계 전건 완료 — seed·build MAP_AT_GA_LINK+ · [D2-2] 일치(행… | `20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md:111` |

## 5. 문서군 규모 · 독해 예산 (실측)

| 문서 | 조각 | 총 바이트 | max B | 여유 B |
|---|---|---|---|---|
| `00_INDEX_이슈원장` | 19 | 510,654 | 38,253 | 2,707 🟠 |
| `01_세션이력` | 90 | 2,325,720 | 38,225 | 6,225 🟠 |
| `02_상태상세_대시보드_갱신형` | 8 | 112,272 | 28,139 | 12,821 |
| `03_이슈상세` | 2 | 50,391 | 27,796 | 13,164 |
| `10_진단_원인분석` | 20 | 383,546 | 27,121 | 13,839 |
| `20_현업확인_요청` | 10 | 212,634 | 35,532 | 5,428 🟠 |
| `30_설계_의사결정` | 17 | 312,741 | 27,122 | 13,838 |
| `50_dbt_파이프라인_미결조치` | 24 | 435,416 | 28,701 | 12,259 |
| `90_해소완료_로그` | 19 | 444,455 | 36,875 | 12,262 |
| `99_NEXT_SESSION` | 35 | 385,742 | 28,852 | 12,108 |
| `01_문서분할_규약` | 3 | 54,175 | 29,125 | 11,835 |
| `11_O누적작업_점검_재현_절차` | 2 | 38,683 | 18,632 | 22,328 |
| `00_작업지침_세션운영규칙` | — | 32,072 | 32,072 | 8,888 |
| `02_파일쓰기_안전규약` | — | 13,392 | 13,392 | 27,568 |
| `04_단계종료_게이트` | — | 10,149 | 10,149 | 30,811 |
| `03_init_ihcho_스킬_정본` | — | 9,464 | 9,464 | 31,496 |
| `03_init_ihcho_스킬_본문` | — | 24,288 | 24,288 | 16,672 |
| `03_init_ihcho_스킬_참조_세션종료` | — | 11,116 | 11,116 | 29,844 |
| `03_init_ihcho_스킬_개발이력` | — | 22,726 | 22,726 | 18,234 |
| `31_코드군_매핑등재부` | — | 14,891 | 14,891 | 26,069 |
| `32_컬럼개명표` | — | 30,169 | 30,169 | 10,791 |
| `40_입고대기_원천의존` | — | 25,033 | 25,033 | 15,927 |
| `91_사고사례집` | — | 20,859 | 20,859 | 20,101 |
| `92_실측필요_후속작업` | — | 4,061 | 4,061 | 36,899 |
| `00_BRIEF` | — | 19,556 | 19,556 | 21,404 |

> 전 문서군 = **3,364,926 자**. 🔴 **전량 독해는 물리적으로 불가능하다** ⇒
> 이 브리핑 + 지침만 읽고 착수하고, 필요한 조각을 좌표로 골라 읽는다.

## 6. 게이트 상태

| 게이트 | 판정 | 결론 |
|---|---|---|
| `doc_census` | ✅ | ✅ stale 0건 · 분할 분모 위반 0건 — 문서 기재와 도구 분모가 실측과 일치한다 |
| `doc_type_gate` | 🟡 | 🟡 통과(경고 1건 · 대상 항목 2건) |
| `clause_order_gate` | ✅ | ✅ 게이트 통과 — 조문 115개 · 역전 0 · 중복 0 (경고 0건) |
| `index_row_gate` | ✅ | ✅ 게이트 통과 — 행 유실 0 · 골든 대비 중복 증가 0 |
| `doc_heading_gate` | ✅ | ✅ 게이트 통과 — 제목 유실 0 |
| `doc_coord_gate` | 🟡 | ✅ 게이트 통과 — 경로가 깨진 좌표 0건 (경고 4건은 사람 판단) |
| `jinja_config_gate` | ✅ | ✅ 게이트 통과 — blocking 0건 |
| `agent_tool_claim_gate` | ✅ | 🟢 PASS — 가불가 모순 0건 · 스펙 규칙7 수치 혼입 0건 |
| `agent_object_ref_gate` | ✅ | 🟢 PASS — blocking 위반 0건 |
| `agent_source_lineage_gate` | ✅ | 🟢 PASS — blocking 0건 |
| `eval_expectation_gate` | ✅ | ✅ 위반 0 — 폐기값이 정답으로 쓰인 곳 없음(이력 주석은 면제) |
| `sv_identifier_gate` | ✅ | 🟢 PASS — blocking 위반 0건 |
| `null_reason_registry_gate` | ✅ | 🟢 PASS — NULL 사유 규격 검증 완료 |
| `campaign_axis_gate` | ✅ | ✅ 게이트 통과 — 미등재·배선 끊김 0 (🟠 GAP 9 건은 알려진 미배선) |
| `sv_no_rollup_gate` | ✅ | 🟢 PASS — 소계/합계 행 유도 0건 · 분모 36 파일 |
| `sv_enum_newvalue_gate 1/4` | 🔴 | 🔴 NEW: SV_EVENT_PARTICIPATION.EVENT_CATEGORY_NAME I'm your pen |
| `sv_enum_newvalue_gate 2/4` | ✅ | ✅ 게이트 통과 |
| `sv_enum_newvalue_gate 3/4` | ✅ | ✅ 게이트 통과 |
| `sv_enum_newvalue_gate 4/4` | ✅ | ✅ 게이트 통과 |

> 🔴 **게이트 전수 PASS 는 「지침 준수」의 증거가 아니다**(`R3-9`).
> 완료 보고 전에 **게이트가 보지 않는 축** ㉠~㉥ 를 자문한다.

| 손으로 적은 조각 수 stale | 0건 |
|---|---|

---

> 🔴 **재생성** = `python3 scripts/session_brief.py --write`
> 🔴 **이 파일을 손으로 고치지 마라** — 다음 생성에서 사라진다.

_Co-authored with CoCo_
