<!-- LLM-METADATA
doc_id: REUSE_KIT_README
doc_role: 재사용 키트 설치 안내 — 새 프로젝트 루트 배치 규약 · 이름 적용 · 점검
created: 2026-11-02
END-METADATA -->

# _reuse_kit — 새 Snowflake 구축 프로젝트용 재사용 키트

> 원 프로젝트(GN_DW · O276 종료)의 지침·스킬·도구·골격을 **복사 + 일반화**한 것이다. 원본은 무변경.
> 목록 = `00_INVENTORY.md` · 자리표시자 = `01_PLACEHOLDERS.md`(`{{DB}}` · `{{ACCOUNT}}`).

## 1. 설치 — 새 프로젝트 루트 배치

| 키트 폴더 | 새 프로젝트 위치 | 비고 |
|---|---|---|
| `11_project_template/` 의 내용 | `<루트>/` | 빈 이슈 원장 · 착수표 · `99_NEXT_SESSION_조각/` · `_archive/` |
| `01_agent_rules/` 의 내용 | `<루트>/00_guides/` | 작업 지침 · 분할·쓰기 규약 · 단계종료 게이트 |
| `02_skill_init/*.md` | `<루트>/00_guides/` | init 스킬 정본 4종 |
| `02_skill_init/*.py` · `03_session_tools/*` · `07_ops_tools/*.py` | `<루트>/scripts/` | 🔴 `kit_paths.py` 와 **같은 폴더**여야 import 된다 |
| `02_skill_init/init_ihcho/` | `<루트>/.snowflake/cortex/skills/init_ihcho/` | 빌더 산출물(손으로 고치지 않는다) |
| `04_methodology/` · `05_build_skeleton/` · `06_dbt_macros/` · `08_handover_templates/` · `09_skill_mstr/` · `10_streamlit/` | 필요한 곳 | 참고·골격(위치 자유) · dbt 매크로는 `<dbt>/macros/` |

## 2. 이름 적용 · 점검

```
python3 _reuse_kit/apply_names.py --set DB=NEW_DW --set ACCOUNT=ab12345 --apply   # 설치 전 1회
python3 scripts/split_doc.py 00_guides/01_문서분할_규약.md --republish --label INIT  # 🔴 이름 적용이 조각 본문을 바꾼다 ⇒ 허브 SHA256 재발행
python3 scripts/kit_paths.py --check                 # 관례 레이아웃 실재(필수 6종)
python3 scripts/verify_init_ihcho_skill.py           # 스킬 정본 ↔ 산출물
python3 scripts/index_row_gate.py --update-golden --reason "최초 설치"   # 골든 기준선 발행(최초 1회)
python3 scripts/doc_heading_gate.py --update-golden
python3 scripts/session_brief.py --write             # 첫 브리핑 · 게이트 ⚪ = 미설치/전제 부재(건너뜀)
```

- 테스트 = `03_session_tools/00_TESTS.md`(이식 가능 29 · 원 프로젝트 데이터 의존 10 — 의존분 FAIL 은 정상).
- 🟢 단독 반출 실측(2026-11-02) = 이 절차대로 빈 루트에 조립 → 브리핑 게이트 ✅ 6 · 🟡 1(원 프로젝트 문서 참조 경고) · ⚪ 12 · 🔴 0.

- 루트를 바꿔 실행 = 환경변수 `KIT_ROOT=<루트>`. 폴더 이름을 바꾸려면 `kit_paths.py` 상수 + 도구 본문 문자열을 **함께** 고친다.
- 스킬 본문을 고쳤으면 `python3 scripts/build_init_ihcho_skill.py --apply`(스킬을 손으로 고치지 않는다).

## 3. 일반화 이력(2026-11-02)

- `GN_DW` → `{{DB}}` · 계정 로케이터 → `{{ACCOUNT}}`(세션 라벨 `O##` · 주석 · `굿네이버스` 문구는 유지).
- dbt 매크로 `gn_` 접두 제거 2종(`no_structural_alter` · `view_commented`).
- 도구 루트 = `kit_paths.ROOT` 일원화(47파일) · 원 프로젝트 아카이브 경로 접두(`_archive/O276_project_closure/`) 제거 12파일.
- 템플릿 본문 수치 = 원 프로젝트 샘플(`08_handover_templates/00_SAMPLE_NOTICE.md`).
