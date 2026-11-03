<!-- LLM-METADATA
doc_id: O276_REFERENCE_CLEANUP_PLAN
doc_role: 프로젝트 종료 정리(O276) 이후 끊긴 경로 참조를 정리한 작업계획서 겸 결과 기록 — 완료 · 보관본
created: 2026-11-01
created_by: O276
related: _archive/O276_project_closure/CLOSURE_MOVE_MAP.csv · _archive/O276_project_closure/_refmatrix_pre.tsv · 00_WORKSPACE_MAP.md §0
status: 🟢 완료 · 보관(2026-11-02) — 1~3단계 완료 · O277 키트 레이아웃 변경(§10) 완료 · 잔여 0
END-METADATA -->

# 참조 정리 작업계획서 (O276)

## 0. 🆕 [2026-11-02 개정] 목표와 단계

> 🔴 종전 계획은 **폴더 정리(1단계)만** 잡혀 있었다. 사용자 목표 = 정리 **후** 다음 Snowflake 구축 프로젝트용 자산을 **추출**하는 것이다.
> ⇒ 「은퇴」 방침을 철회하고, 세션 운영 장치(스킬·지침·게이트)는 **추출 후보**로 다룬다.

| 단계 | 목표 | 산출물 | 상태 |
|---|---|---|---|
| 1 | 폴더별 정리 + 끊긴 참조 정리(§1~§4) | 이동 완료 · `ref_lines.tsv` · A 치환 적용 184파일 698행 · 각주 2건 | 🟢 완료(2026-11-02 · 사용자 승인 · 보류분 포함) |
| 2 | 재사용 자산 추출(§8) | `_reuse_kit/` 10그룹 216파일(복사 시점 · 🆕 최종 = 12그룹 + 루트 파일 4 · O277 반영 후 실측 = §10) · `00_INVENTORY.md` · `01_PLACEHOLDERS.md` · `apply_names.py` | 🟢 복사(해시 216/216) · 자리표시자 `{{DB}}` 538 · `{{ACCOUNT}}` 99(102파일 · 잔존 0 · py 89 구문 OK) · 세션 라벨·주석·`굿네이버스` 는 사용자 결정으로 유지 · 매크로 `gn_` 접두 제거 2종(참조 14건 동시 · `test_jinja_config_gate` 19/19) · 템플릿 수치 = 샘플 유지(`08_handover_templates/00_SAMPLE_NOTICE.md`) · 🟢 [2026-11-02] ① 경로 상수 = `03_session_tools/kit_paths.py` 일원화(47파일 · ROOT 정의 34 · `/workspace` 리터럴 32) ② 빈 원장 템플릿 = `11_project_template/`(유형 등재표 17행 · 착수표 · 이력 · 50·90·91) ③ init 빌드 일반화(`GUIDES_DIR`·`SKILL_DIR`) + 키트 아카이브 접두 제거 12파일 66건 → 조립 프로젝트에서 `kit_paths --check` PASS · `verify_init_ihcho_skill` 🟢 · 🟢 [2026-11-02] ⑥ 음성 테스트 = 이식 29 · 원 데이터 의존 10(`03_session_tools/00_TESTS.md`) · 키트 결함 4건 수정(`gate_census` 유령 95 · `audit_ddl_rule7`·`deploy_sv` 편입 · `doc_heading_gate` None 골든 · 브리핑 ⚪ 건너뜀) ⑦ 단독 반출 = 빈 루트 조립 + 이름 적용 → 게이트 🔴 0 · 🟢 원본 회귀 3건 복구 = `init_ihcho` 재빌드(I1·I8 → PASS) · 분할 허브 2종 `--republish`(SHA256 → PASS) |
| 3 | 검증 · 롤백 준비(§6) | 검증 1 = 5,462행 부재 0 · 검증 2 = 재스캔 잔존 0 · 사후 대조 ok 184 · bad 0 · 스냅샷 `_archive/O276_project_closure/_snap_refA/` | 🟢 |

- 🔴 **2단계 전까지 아무것도 은퇴·삭제하지 않는다** — `init_ihcho` · `mstr-migration` · `scripts/` 게이트는 현 위치·현 내용 유지.
- 삭제·복구 대상 목록 = §7.

> 프로젝트 종료(2026-11-01)에 따라 세션 운영용 폴더를 `_archive/O276_project_closure/` 로 옮겼고, 재편 누락분 2개 폴더를 `20_build/` 에 편입했다.
> 이 문서는 **그 결과 끊긴 경로 문자열을 어떻게 정리할지**의 계획이다. (작성 시점 = 치환 전 · 🟢 2026-11-02 치환 적용 완료 = §4-3)

## 1. 이동 요약

| 옛 경로 | 새 경로 | 방식 |
|---|---|---|
| `80_인수인계_프로젝트완료 및 유지보수용/` | `_archive/O276_project_closure/80_인수인계_프로젝트완료 및 유지보수용/` | 이름 유지 |
| `20_issue/` | `_archive/O276_project_closure/20_issue/` | 이름 유지 |
| `99_NEXT_SESSION.md` · `99_NEXT_SESSION_조각/` | `_archive/O276_project_closure/` 아래 같은 이름 | 이름 유지 |
| `40_worklog/` | `_archive/O276_project_closure/40_worklog/` | 이름 유지 |
| `tmp/` · `999_temp.txt`(빈 파일) | `_archive/O276_project_closure/` 아래 같은 이름 | 이름 유지 |
| `00_WORKSPACE_RESTRUCTURE_PLAN.md` · `MOVE_MAP.csv` · `MOVE_MAP_files.csv` | `_archive/RESTRUCTURE_20261031-pre/` | 이름 유지 |
| `BRONZE_최종 인수인계 파일/` | `20_build/29_bronze_handover/` | 이름 정규화(파일 단위 대응표) |
| `09_STREAMLIT/` | `20_build/22_streamlit_apps/` | 앱 폴더명 = `<제목>_<ID>` · `__pycache__` 삭제 |

- 파일 단위 대응표 = `_archive/O276_project_closure/CLOSURE_MOVE_MAP.csv` (old_path, new_path, action, reason).
- 🆕 [O276-B · 2026-11-02] **이동 완료** — `o276_resume.py --from-0` dry-run = `already 5477 · to_move 0 · problems 0` · `tmp/` 958파일은 `COPY FILES` 후 SHA256 958/958 일치 확인 뒤 `REMOVE` · 빈 출발 폴더 5종 제거(실파일 0 확인 · `.folder` 239건).
- **치환 규칙(이름 유지분)**: 옛 경로 앞에 `_archive/O276_project_closure/` 를 붙인다. 재편 산출물 3종만 `_archive/RESTRUCTURE_20261031-pre/` 를 붙인다.
- **치환 규칙(정규화분)**: 대응표의 old_path → new_path 를 그대로 쓴다. 이동 전 실측에서 두 폴더를 참조하는 문서는 0건이다(§2).

## 2. 이동 전 참조 행렬 (실측 · 2026-11-01)

> 출처 = `_archive/O276_project_closure/_refmatrix_pre.tsv` (유지 폴더 2,830개 텍스트 파일 · 문자열 출현 횟수 / 파일 수).
> 대상 문자열 = 폴더명 접두(`20_issue/`, `99_NEXT_SESSION`, `tmp/` 등). 🔴 `tmp/` 는 다른 단어 일부(`/tmp/` 등 OS 경로)도 섞여 있어 **과대 계상**이다 — 치환 전 행 단위로 다시 거른다.

| 참조 대상 | 합계(회 / 파일) | 주요 출발지 (회 / 파일) |
|---|---|---|
| `20_issue/` | 881 / 223 | 60_share 298/46 · scripts 294/41 · 10_design 54/27 · 10_dbt_pipeline 47/16 · 00_guides 46/10 · 30_operate 42/35 · 23_sv_agent 28/17 · 85 25/13 · 21_env_rbac 18/5 · .snowflake 16/4 |
| `99_NEXT_SESSION` | 581 / 92 | scripts 421/32 · 30_operate 47/22 · 00_guides 26/5 · 60_share 26/6 · 85 22/12 · 23_sv_agent 10/6 · .snowflake 9/3 |
| `tmp/` | 438 / 154 | 30_operate 224/59 · scripts 102/48 · 85 33/17 · 50_handover 22/5 · 00_WORKSPACE_MAP 19/1 |
| `80_인수인계_프로젝트완료` | 106 / 43 | 85 95/38 · 50_handover 7/4 · 00_WORKSPACE_MAP 4/1 |
| `40_worklog` | 36 / 11 | scripts 11/3 · 00_WORKSPACE_MAP 11/1 · 50_handover 8/2 · 85 5/4 |
| `MOVE_MAP` · `00_WORKSPACE_RESTRUCTURE_PLAN` | 34 / 21 | 각 폴더 `00_README.md`(O275 생성) |
| `999_temp` | 1 / 1 | 00_WORKSPACE_MAP |
| `BRONZE_최종` · `09_STREAMLIT` | 0 / 0 | — |

## 3. 분류와 처리 방침

### A. 치환 대상 — 유지 문서의 안내용 링크
- 각 폴더 `00_README.md`(O275 생성분)의 `MOVE_MAP*.csv` 참조 → `_archive/RESTRUCTURE_20261031-pre/`.
- `00_WORKSPACE_MAP.md` §0 표: O276 에서 갱신 완료(§1~§3 은 조사 기록이라 손대지 않는다).
- `50_handover/`, `30_operate/`, `10_design/`, `20_build/*`, `60_share/` 의 md 에서 `20_issue/…` · `40_worklog/…` · `80_…/` 를 **근거 링크로** 쓴 행.
  - 방식: 경로 앞에 `_archive/O276_project_closure/` 를 붙인다. 문장은 바꾸지 않는다.

### B. 치환 금지 — 원문 보존
- `_archive/` 내부 전부(스냅샷 · 원문 보존 원칙).
- `85_실제 인수인계 문서/` 본문(납품 산출물 · `source_docs` 가 80번을 가리키는 것은 **작성 당시 사실**이다). 대신 `85_…/00_INDEX_산출물목록.md` 머리에 「80번 → `_archive/O276_project_closure/` 이동」 1줄 각주만 더한다.
- `10_dbt_pipeline/` 의 SQL·YAML 주석(16개 파일 · 예: `models/gold/fact/FACT_MEMBER_MONTHLY.sql` 의 `20_issue/30_설계_의사결정.md` DEC-41/55). 🔴 실행·배포에는 영향이 없다(주석만 · 확인 완료). 바꾸면 `GN_DW.OPS.DW_PIPELINE` 재배포 시 diff 만 커진다 ⇒ **치환하지 않고** `10_dbt_pipeline/README.md` 에 「`20_issue/` = `_archive/O276_project_closure/20_issue/`」 대응 1줄만 둔다.

### C. 도구·스킬의 하드코딩 경로 — 🆕 [2026-11-02 개정] 은퇴 철회 · 추출 후보(§8)
- `scripts/` 게이트·도구(대표): `doc_census.py` · `doc_line_length_gate.py` · `doc_heading_gate.py` · `doc_coord_gate.py` · `doc_type_gate.py` · `decision_closure_gate.py` · `session_brief.py` · `split_doc.py` · `retire_sections.py` · `handoff_ddl_gate.py` · `handoff_write.py` 와 그 `test_*.py`.
  - 이 프로젝트에서는 대상(`20_issue/` 등)이 아카이브로 가서 **실행 시 「파일 없음」이 정상**이다(2026-11-02 실측 = `session_brief.py` rc=1 · `20_issue/00_INDEX_이슈원장.md` 부재).
  - 방침: **이 위치에서는 수정하지 않는다.** 2단계에서 `_reuse_kit/` 로 **복사**하고 경로 상수를 설정값(루트·이슈 폴더명)으로 뽑아 일반화한다.
  - ~~`scripts/README_운영도구.md` 에 은퇴 절 추가~~ → 「재사용 후보 · 현 프로젝트에서는 대상 부재」 안내로 정정(2026-11-02).
- `.snowflake/cortex/skills/init_ihcho/`(SKILL.md · references/doc-map.md · session-end.md): 세션 시작 시 `20_issue/` · `99_NEXT_SESSION.md` 를 읽는다 ⇒ 지금 실행하면 「파일 없음」.
  - 방침: **은퇴·제거하지 않는다.** 정본 = `00_guides/03_init_ihcho_스킬_본문.md`(SKILL.md 는 빌드 산출물) ⇒ 2단계에서 정본과 빌드기를 함께 추출한다.
  - 이 프로젝트 안에서는 그대로 둔다(아카이브 열람 세션은 Step 2 FAIL 을 보고만 하면 된다).
- `.snowflake/cortex/skills/mstr-migration/SKILL.md`: `20_issue/` · `tmp/` 참조 = 근거 링크 ⇒ A 방식으로 치환 · 2단계 추출 후보(MSTR 이관 절차 일반화).

## 4. 실행 순서

1. 🟢 [2026-11-02] 행 단위 재추출: `_refmatrix_pre.tsv` 의 파일 목록에서 대상 문자열을 포함한 **행**을 뽑아 `ref_lines.tsv`(파일 · 줄번호 · 원문) 생성. `tmp/` 는 앞 문자가 `/`·영숫자인 경우(OS 경로 등)를 제외한다. → 410파일 · 1,628행(도구 = `o276_reflines.py`).
2. 🟢 분류 기입: 각 행에 A/B/C 를 단다(§3 규칙 · 폴더 기준 자동 + 예외 수동). → A 711 · B 238 · C 679 · 🟡 보류 = 코드 파일(sql·py·yaml) 47행 · `00_guides` 63행 · `70_reference`·`90_provided_definition` 6행(🟢 2026-11-02 사용자 승인 = A 로 편입).
3. 🟢 A 치환 dry-run → diff 검토 → 사용자 승인 → 적용. 적용 전 원본은 `scripts/snapshot_util.py` 로 `_archive/` 에 스냅샷. → dry-run = 147파일 · 592행(`replace_A.diff` · 부재 경로 25건 = `replace_A_dead.tsv` · 공백 포함 파일명 절단·원래 예정 경로) · 🟢 [2026-11-02 승인 · 적용] 보류분 포함 184파일 698행 · 스냅샷 `_snap_refA/`(원 경로 구조) · 사후 대조 ok 181 + 재실행 3 · 절단 0.
4. 🟢 B 각주 2건(85번 INDEX · dbt README) 추가.
5. ~~C 은퇴 표기(scripts README · init_ihcho)~~ → 🆕 철회 · 2단계(§8) 추출로 대체.
6. 🟢 검증(§6). → 검증 1 🟢 · 검증 2 🟢(재스캔 변경 0).
7. 🟢 2단계 재사용 자산 추출(§8) — 8-2 의 1~6 전부 완료(복사 · 승인 · 일반화 · 잔존 검사 · 음성 테스트 · 단독 반출) · 결과 = §0 표 2행 · §9-1.

## 5. 새 프로젝트 재사용 가이드 (참고 모델 관점)

- 그대로 쓸 것: `00_guides/`(작업 지침·규약) · `50_handover/53_followup_project/`(RBAC·dbt·SV/Agent·모니터링 골격) · `85_실제 인수인계 문서/`(산출물 템플릿 A0~A8 · D01~D14 · N01~N08).
- 근거를 찾을 때: 결정 = `_archive/O276_project_closure/20_issue/30_설계_의사결정.md`(DEC-nn) · 미결/해소 = 같은 폴더 `00_INDEX_이슈원장.md` · `90_해소완료_로그.md` · 사고 = `91_사고사례집.md`.
- 세션 운영 장치(허브·조각·게이트)를 다시 쓸 때: `scripts/` 의 경로 상수를 새 루트 기준으로 바꾸고 `init_ihcho` 스킬을 새로 빌드한다.

## 6. 검증 · 롤백

- 검증 1: `CLOSURE_MOVE_MAP.csv` 의 모든 new_path 존재 · old_path 부재 (delete 행 제외).
- 검증 2: A 분류 행 재스캔 시 옛 경로 잔존 0. B·C 는 잔존이 정상이다(의도적 비치환).
- 롤백: 이동 = 대응표 역순 `mv`(new → old) · 치환 = 3단계 스냅샷 복원.

## 7. 🆕 [2026-11-02] 삭제·은퇴 항목과 복구 후보

> 실측 = `CLOSURE_MOVE_MAP.csv` 5,477행 = archive 5,345 · move 117 · **delete 15**. 원본은 사용자가 별도 보관 중.

| 구분 | 대상 | 건수 | 복구 필요 | 사유 |
|---|---|---|---|---|
| 삭제 | `09_STREAMLIT/*/__pycache__/*.pyc` | 15 | ❌ 불필요 | 바이트코드 · 실행 시 재생성 |
| 삭제 | 빈 출발 폴더 마커 `.folder` | 239 | ❌ 불필요 | 실파일 0 확인 후 제거 · 내용 없음 |
| 이동 후 원본 제거 | `tmp/` 958파일 | 958 | ❌ 불필요 | `COPY FILES` + SHA256 958/958 일치 후 `REMOVE` · 아카이브에 실재 |
| 아카이브(삭제 아님) | 기획실대시보드 구버전 `AE4O8Q2VQMKWF5KV` 6파일 | 6 | 🟡 선택 | `20_build/22_streamlit_apps/_archive/` 에 있음 · Streamlit 템플릿으로 추출 가능 |
| 아카이브(삭제 아님) | `연목표 데이터화 copy.sql` | 1 | ❌ | 원본과 다른 초안 · `20_build/29_bronze_handover/_archive/` |
| 은퇴 | 없음 | 0 | — | `init_ihcho` · `mstr-migration` · `scripts/` 게이트 모두 **무변경**(README 안내 1절 = 「재사용 후보」로 정정 완료) |

⇒ **원본 보관분에서 복구할 항목 = 0건.** 재사용 자산은 전부 워크스페이스(현 위치 또는 `_archive/`)에 실재한다.

## 8. 🆕 [2026-11-02] 2단계 — 재사용 자산 추출 계획

> 목표 = 다음 Snowflake 구축 프로젝트에 **그대로 복사해 쓸 수 있는 키트**. 원칙 = 원본은 두고 **복사 + 일반화**(굿네이버스 고유 값 제거).
> 출력 = 루트 `_reuse_kit/`(신설) · 목록 = `_reuse_kit/00_INVENTORY.md`(원본 경로 · 키트 경로 · 일반화 내역).

### 8-1. 후보 목록(1차 · 실재 확인 2026-11-02)

| 키트 폴더 | 원본 | 일반화 작업 |
|---|---|---|
| `01_agent_rules/` | `00_guides/00_작업지침_세션운영규칙.md` · `01_문서분할_규약.md`(+조각) · `02_파일쓰기_안전규약.md` · `04_단계종료_게이트.md` | 프로젝트 라벨·사고 사례 좌표(`91_…` §Cnn) 를 「사례집 참조」로 · 우선순위 문구의 `20_issue/` 를 설정값으로 |
| `02_skill_init/` | `00_guides/03_init_ihcho_스킬_본문.md`·`정본.md`·`참조_세션종료.md`·`개발이력.md` + `.snowflake/cortex/skills/init_ihcho/` + 빌드기 | 스킬명 변경 여부 · 경로 상수 · 빌드 절차 README |
| `03_session_tools/` | `scripts/` 세션 운영 게이트(§3-C 목록) + `line_len.py` · `snapshot_util.py` · `id_collision_gate.py` · `test_*.py` | 경로 상수를 `config` 1곳으로 · 빈 이슈 원장 템플릿(`20_issue/00_INDEX_이슈원장.md` 골격 · §0 유형 등재표) 동봉 |
| `04_methodology/` | `00_guides/01_데이터설계…킴볼`·`02_모던 엔터프라이즈…`·`04_YAGNI_…` · 인증 가이드 2종 | 굿네이버스 전용 `03_…설계 가이드` 는 제외 또는 익명화 |
| `05_build_skeleton/` | `50_handover/53_followup_project/`(RBAC·dbt·SV/Agent 작성규칙·모니터링 SQL·인수인계 규약) | DB·역할명을 자리표시자로 |
| `06_dbt_macros/` | `10_dbt_pipeline/macros/` 중 범용(`generate_schema_name` · `gn_no_structural_alter` · `gn_view_commented` · purge 계열) | `gn_` 접두·업무코드 매크로(`gn_biz_codes` 등) 제외 |
| `07_ops_tools/` | `scripts/` 운영도구(`sfconn.py` · `run_sql_file.py` · `sv_*_gate.py`) | 기본 역할·웨어하우스명 설정값화 |
| `08_handover_templates/` | `85_실제 인수인계 문서/` 산출물 골격(A0~A8 · D01~D14 · N01~N08) + 생성기 | 본문 수치 제거 · 목차·메타 헤더만 |
| `09_skill_mstr/` | `.snowflake/cortex/skills/mstr-migration/` · `70_reference/73_…`·`74_…` | GN_DW 고유명 자리표시자화 |
| `10_streamlit/` (선택) | `20_build/22_streamlit_apps/` · `27_streamlit_auth/` | 인증 패턴만 · 대시보드 본문 제외 |

### 8-2. 절차

1. 후보별 파일 전수 목록 + SHA256 → `00_INVENTORY.md` 초안(읽기 전용 · 사용자 검토).
2. 사용자 확정(포함/제외 · 키트 이름 · 스킬명 유지 여부).
3. 복사(`COPY FILES` 또는 python 복사 + 해시 대조) → 일반화 편집(키트 안에서만 · 원본 무변경).
4. 고유어 잔존 검사(`GN_DW` · `굿네이버스` · 계정 로케이터 · `O###` 라벨) = 0 또는 의도 잔존 목록화.
5. 도구 음성 테스트(빈 템플릿 원장에서 `session_brief.py` rc=0 · `line_len.py` PASS).
6. 키트 단독 반출 확인(`_reuse_kit/` 만 새 워크스페이스에 두고 스킬 Step 0~2 통과).

## 9. 🆕 [2026-11-02 O276-C] 세션 종료 · 인수인계

> 🔴 세션 운영 정본(원장·이력·라벨 파일)은 `_archive/O276_project_closure/` 로 이동했다 ⇒ 종료 도구(`handoff_write` 등)를
> 실행하면 루트에 옛 폴더를 다시 만든다. **이 절이 O276-C 의 인수인계 정본이다**(종료 도구는 실행하지 않았다).

### 9-1. 이번 세션 결과

| 단위 | 결과 | 근거 |
|---|---|---|
| 1단계 참조 정리 | 🟢 184파일 698행 치환 · 잔존 0 · 사후 대조 ok 184 | §0 · `_snap_refA/` · `verify3_A.out` |
| 2단계 재사용 키트 | 🟢 `_reuse_kit/` 12그룹 · 단독 반출 게이트 🔴 0 | `_reuse_kit/00_README.md` · `00_TESTS.md` |
| 원본 회귀 복구 | 🟢 `init_ihcho` 재빌드 · 분할 허브 2종 재발행 | `_archive/*.O276-C-prebuild` · `*-prehub` |
| 도구(일회성) | `o276_*.py` 9종 = `_archive/O276_project_closure/` | 재실행 = 멱등(키트 README 는 경로로 제외) |

### 9-2. 사고 · 확정위반 (`R4-4-4` 기록)

- 🔴 같은 파일 병렬 `edit` 3회(`R1-7-2`) — 되읽기로 유실 0 확인.
- 🔴 키트 `08_handover_templates/00_README.md` 덮어씀 → 원본에서 복원 · 안내문은 `00_SAMPLE_NOTICE.md`.
- 🔴 키트 `01_문서분할_규약-003.md` 마운트·스테이지 소실(원인 미확정 · 마운트 전량 쓰기 실패 추정) → 조립 사본에서 `cortex ws cp` 로 복원 · 키트 231/231 실재.
- 🟠 분할 허브 재발행 1건 라벨 누락(`UNLABELED-prehub` · `R1-7-10`).
- 🟠 원본 `doc_heading_gate` FAIL = `20_issue/` 이동에 따른 정상 결과(시정 대상 아님).
- 🟢 지시 동봉 진행(`R4-4-2` ㉡) · 파괴 가능 작업(치환 적용 · 재빌드)은 전부 사용자 승인 후 집행.

### 9-3. 다음이 할 일

- ㉠ **이 작업의 잔여** = 없음. 🔴 키트를 반출할 때는 **스테이지 기준**으로 가져간다(마운트는 지연될 수 있다).
- ㉡ **새 프로젝트 백로그(키트 사용 시)** = `00_TESTS.md` §1 데이터 의존 테스트 10종 픽스처 교체 · `굿네이버스` 문구·세션 라벨 정리 여부 결정.

## 10. 🆕 [2026-11-02 O277] 키트 레이아웃 = `01_project_control/` · 문서 종결

| 단위 | 결과 | 근거 |
|---|---|---|
| 키트 레이아웃 | 세션 운영물(`20_issue/` · `99_NEXT_SESSION*` · `40_worklog/`) → `01_project_control/` 단일 폴더 · `kit_paths.PC_DIR` 신설 | `_reuse_kit/00_README.md` §4 |
| 경로 치환 | 42파일 284행(도구 · 테스트 · 지침 · init 스킬 정본/산출물 · `09_skill_mstr`) · 제외 = 납품 템플릿 샘플 · 개발이력(각주) · `00_INVENTORY.md` | 같은 곳 |
| 분모·픽스처 보정 | `doc_type_gate` · `classify_doc_type` · `decision_closure_gate` 3건 · `test_handoff_write` 1건 | 같은 곳 |
| 표준 번호표 | 최상위 번호표 · `01_project_control` 규약 · 원 구조 → 표준 대응표 | `_reuse_kit/11_project_template/00_표준_폴더번호표.md` |
| 검증 | 빈 루트 조립 · 테스트 35종 rc = 기준선과 동일(24 통과 · 회귀 0) · 반영 56파일 해시 일치 · 스테이지 실재 | `_reuse_kit/03_session_tools/00_TESTS.md` |
| 롤백 | 변경 전 키트 파일 63건(변경 56 · 삭제 7) | `_archive/O277_kit_pc_pre/` |
| 키트 규모(최종) | 12그룹 + 루트 파일 4 | 실측 |

- 🟢 **이 문서의 용도는 끝났다** — 1~3단계와 O277 모두 잔여 0. 보관 위치 = `_archive/O276_project_closure/00_REFERENCE_CLEANUP_PLAN.md`.
- 루트 부산물 `sv_enum_newvalue_{0..3}of4.csv`(헤더만) = `_archive/O276_project_closure/tmp/` 로 이동돼 있음(2026-11-02 확인).

### 10-1. 🆕 [2026-11-03 O277-B] 후속 정리

- 키트 무결성 = 마운트 ↔ 스테이지 239/239 · `__pycache__/*.pyc` 1건 삭제 · 반출본 = `_archive/O277_reuse_kit_export/_reuse_kit_20261103.zip`(239항목 · testzip OK).
  🔴 `cortex ws cp <폴더>/` 는 하위 폴더 구조를 평탄화한다(239 → 219) ⇒ **폴더째 반출은 zip 으로** · 단일 파일 대조는 `cortex ws cp` 로 가능.
- 키트 과거 기록 13곳 원복(O277 치환 과잉) · 테스트 보정 3종 → 39종 중 통과 31 · 데이터 의존 8 · 브리핑 게이트 🔴 0(골든 발행 후).
- `10_dbt_pipeline/` md 4종 26행 = `_archive/O276_project_closure/20_issue/` 로 치환(원본 `_archive/O277_dbt_md_pre/`).
- O275 대응표 2,665행 · O276 대응표 5,477행 스테이지 대조 = **손실 0**(`999_temp.txt` 는 O276 에서 보관 · 0바이트).
- 임시 파일 규칙 = 지침 `R0-8-5` · init 스킬 Step 0·G1 = `/workspace/tmp/` · `.gitignore` 에 `./tmp/`(원본·키트 모두 · 스킬 재빌드 verify 🟢 · `clause_order_gate` 🟢).
- 재현 도구 = 이 폴더 `o277_kit_assemble.py` · `o277_kit_pc_replace.py`(재작성 · 원 결과 42파일 284행 재현 확인).
- 새 환경 백로그 = `_reuse_kit/00_README.md` §6.
