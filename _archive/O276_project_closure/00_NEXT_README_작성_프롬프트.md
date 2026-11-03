# README 작성 프롬프트 (저가 LLM 실행용 · O276-B)

> 이 파일 내용을 그대로 새 세션 첫 메시지로 붙여넣는다. 끝나면 이 파일은 `_archive/O276_project_closure/` 로 옮긴다.

---

이 워크스페이스는 종료된 GN_DW(Snowflake DW) 프로젝트의 참고 모델이다.
아래 **8개 폴더에 README 가 없다.** 각 폴더에 `00_README.md` 를 **새로 만든다.** 다른 일은 하지 않는다.

## 대상 (8건)

1. `00_guides/01_문서분할_규약_조각/`
2. `10_dbt_pipeline/macros/`
3. `10_dbt_pipeline/models/`
4. `10_dbt_pipeline/seeds/`
5. `10_dbt_pipeline/snapshots/`
6. `10_dbt_pipeline/tests/`
7. `85_실제 인수인계 문서/`
8. `scripts/golden/`

## 폴더마다 할 일

1. 그 폴더의 `00_FOLDER_INDEX.md`(자동 생성 파일 목록)를 `read` 로 읽는다.
2. 상위 폴더의 안내 파일을 읽는다:
   - 1 → `00_guides/00_README.md`
   - 2~6 → `10_dbt_pipeline/README.md`
   - 7 → 그 폴더의 `00_INDEX_산출물목록.md`
   - 8 → `scripts/README_운영도구.md`
3. 목록의 파일 중 **최대 3개**만 앞부분(`limit` 40줄)을 읽어 성격을 확인한다. 전부 읽지 마라.
4. `write` 툴로 `<폴더>/00_README.md` 를 만든다. 형식은 아래 그대로다.

```
<!-- LLM-METADATA
doc_role: 폴더 안내 — <폴더 경로>
created: <오늘 날짜 YYYY-MM-DD>
created_by: O276-B (README 일괄 작성)
related: 00_FOLDER_INDEX.md · <2번에서 읽은 상위 안내 파일>
END-METADATA -->

# <폴더 이름> — <한 줄 제목>

> 목적 = <이 폴더가 무엇을 담는지 1~2문장>.
> 파일 목록 = 같은 폴더 `00_FOLDER_INDEX.md`(자동 생성 · 손으로 고치지 않는다).

## 구성

| 하위 폴더·파일 묶음 | 내용 |
|---|---|
| <묶음 1> | <1줄> |

## 참고

- <상위 안내 파일과의 관계 · 주의사항 1~3줄>
```

## 규칙 (반드시 지킨다)

- 🔴 **이미 README 가 있으면 만들지 마라** — 폴더에 이름에 `readme` 가 들어간 파일이 있는지 먼저 확인한다.
- 🔴 다른 파일은 **수정·이동·삭제하지 않는다.** `00_FOLDER_INDEX.md` 도 고치지 않는다.
- 🔴 **파일 수·크기 같은 숫자를 README 에 적지 마라** — 색인 파일이 담당한다(적으면 낡는다).
- 🔴 읽지 않은 내용을 지어내지 마라. 모르면 「(확인 필요)」라고 쓴다.
- 한 줄은 1000자 이내. 표는 행마다 줄을 바꾼다.
- 7번(`85_실제 인수인계 문서/`)은 납품 문서다 — 「본문 수정 금지 · `80_…` 참조는 작성 당시 사실이며
  그 폴더는 `_archive/O276_project_closure/` 로 옮겨졌다」는 1줄을 `## 참고` 에 넣는다.
- 2~6(dbt)은 `GN_DW.OPS.DW_PIPELINE` 배포 소스다 — 「`.md` 는 dbt 실행에 영향 없음 · SQL/YAML 은 손대지 않는다」 1줄을 넣는다.
- 셸 명령은 `timeout 60` 과 `</dev/null` 을 붙인다. dbt 명령은 실행하지 않는다.

## 끝나면

1. 8개 경로를 한 번에 검사한다:
   `timeout 60 python3 scripts/line_len.py "<경로1>" "<경로2>" …` → `🟢 PASS` 확인(공백 있는 경로는 따옴표).
2. `python3 scripts/build_folder_index.py --apply` 를 다시 돌려 색인에 README 를 반영한다(백그라운드 · 수 분 소요).
3. 사용자에게 보고: 만든 파일 8개 경로 · 건너뛴 폴더와 이유 · PASS 여부. 단답형.
