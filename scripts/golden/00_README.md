<!-- LLM-METADATA
doc_role: 폴더 안내 — scripts/golden/
created: 2026-11-02
created_by: O276-B (README 일괄 작성)
related: 00_FOLDER_INDEX.md · scripts/README_운영도구.md
END-METADATA -->

# golden — 문서 무결성 검증용 골든 기준선(Baseline)

> 목적 = 문서 제목 구조, 인덱스 행 키, 스크립트 출력 결과 등 워크스페이스 문서 자동 검증 게이트 도구들이 사용하는 기준선 JSON 데이터들을 보관한다.
> 파일 목록 = 같은 폴더 `00_FOLDER_INDEX.md`(자동 생성 · 손으로 고치지 않는다).

## 구성

| 하위 폴더·파일 묶음 | 내용 |
|---|---|
| `doc_headings.json` | 문서별 유효 헤딩 계층 구조 골든 데이터 (`doc_heading_gate.py` 기준선) |
| `index_rows.json` | 원장 및 인덱스 표의 행 키 보존 검증용 골든 데이터 (`index_row_gate.py` 기준선) |
| `outputs.json` | 음성 테스트 및 스크립트 실행 결과 검증용 출력 기준선 |
| `rename_stale_baseline.json` | 파일 및 심볼 개명 감지용 기준선 데이터 |

## 참고

- 상위 운영 도구인 `scripts/` 내 게이트 스크립트들이 이 기준선 파일들과 비교하여 위반 여부를 판정한다.
- 기준선 갱신은 각 게이트 스크립트의 `--update-golden` 인자를 통해서만 제어되며 수동 수정은 지양한다.
