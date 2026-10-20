### ▣ O246-D-0 🔴 먼저 알아라

- `O246-D` = O246-C 승계(2026-10-19 · trialadmin(iw20760) · ㉡ 적용 · 확정위반 1 = 인수인계를 `write` 로 직접 작성 → `handoff_write.py` 로 재발행).
- 이번 단위 = O246-C ② D1 · ③ D2 · ⑤ 폴백 각주 패치 → Agent 3종 **VERSION$8**(롤백 = VERSION$7).
- 사용자 확인: ⑦ 개발계 dbt build 완료(GOLD.FACT_AD_PERFORMANCE·FACT_BUDGET·FACT_BUDGET_YEARLY 2026-10-19 02:53 갱신).
- 결과 정본 = `12_agent개선과제/20261019_현업요청사항및대응.md` § 7.

### ▣ O246-D-1 이번 단위 결과

| 항목 | 결과 |
|---|---|
| ② D1 | 원인 = 본문 「③ 상세」 작성 중 data_to_chart 호출 → 결과 뒤 answer 재개. 응답 ㉣ = ①·②·③ 각 1회 + 차트 선행 · orchestration 맨 앞 [O246-D 1회 출력](3종) |
| ③ D2 | orchestration 규칙 ④ 뒤 = 보완값 없는 축 미매칭 절반 이상이면 대체 축 재집계 함께 제시(3종) |
| ⑤ 폴백 각주 | SV_ML_MEMBER_RISK·CHURN_CAMPAIGN·SPONSOR_RISK ma 4차원 COMMENT·ma 표 COMMENT·지침 문구. GRANT 7건 복원 확인 |
| 백업 | spec = `tmp/o246d/*_agent_spec.yaml.beforeD` · SV = `tmp/o246/<SV>.ddl.beforeD.sql` |
| 게이트 | agent_tool_claim · sv_unit · agent_object_ref PASS |
| 배포 | VERSION$8 3종 · 스테이지 대조 OK(MEMBER 132,064 · EXECUTIVE 88,848 · MARKETING 113,392) |
| 운영계 SQL | `05_SV-Agent_ai/34_O246D_운영계반영_SV_ML_폴백각주.sql`(SV 3종 + GRANT) |
| 주의 | `tmp/o246d/patch_sv_d.py` 에는 GRANT 재부여가 없다(stage mount append 실패) — 재실행 시 GRANT 를 따로 실행 |

### ▣ O246-D-2 ㉠ 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 👤 VERSION$8 스모크 = 추정치 문장 · B1(③ 1회·태그 없음) · B3(대체 축) · R1(폴백 각주) | 👤 사용자 다음 단계 |
| ② | 👤 eval 하락 문항 분해 = MEM D3·R14·R15 · EXEC Q13 · EXEC TE | 👤 사용자 다음 단계 |
| ③ | 👤 운영계 반영 = `O246_운영계_작업프롬프트.md`(A+B) + `34_O246D_…sql` + Agent 3종 VERSION$8 spec · O245-B ① 합쳐 1회 | 👤 사용자 |
| ④ | 👤 ML 담당 확인 = 회비예측 카테고리 63·71 부재 · 일시(49) 포함 · 예측 지평 12 ↔ 6개월 | ML 담당 |

### ▣ O246-D-3 ㉡ 워크스페이스 백로그

| 순 | 작업 | 판정 |
|---|---|---|
| ⑧ | 👤 운영계 = 05_20·21·22·25 · Agent spec(O245-B) · 05_02·05_03 · 32 D1~D5 → 33 D0~D4 · O243 SV 3파일 | 👤 사용자 |
| ⑨ | 👤 O240 배포순서 30 D2 대사 · D5 스모크 5문항 | 👤 사용자 |
| ⑪ | 공66 DIM_PAYMENT.FEE_TYPE 전건 NULL(2026-10-19 실측 0/7) ⇒ 원천 주입 후 배선 | 운영계 원천 |
| ⑫ | 현업 확인 = 공11 「15개」 축 · 공147 공통캠페인 체계 | 현업 |
| ⑬ | 현업 A/B 채택(공#122 · 공#81 · 공91 · 공98 · G1 2건) → 비채택 안 회수 | 현업 → dbt |
| ⑭ | W5 영상 이름형 매핑 · 미매칭 41행 · 정의 7종 | 현업 |
| ⑮ | W6 재방송 캠페인코드 CRM 일치 0 · 상위캠페인코드 1:N 78행 | 현업 |
| ⑰ | 미납·활동 예측 모델 신설 | ML 담당 |
| ⑱ | 일시→정기 전환 × 캠페인카테고리·연령·지역·회원상태 = 원천 값 없음 | 운영계 원천 |

### ▣ O246-D-4 ⚪ 결정 완료(재론 금지)

- 공112 GA member id = CRM 회원번호와 동일 취급(현행 유지) · 사용자 승인 2026-10-19.
- O246-C ▣ -4 그대로(추정치 안내 문구 · O246-B 규칙 · 지혜님 회신 완료).
- ⑦ 개발계 dbt build 완료.
