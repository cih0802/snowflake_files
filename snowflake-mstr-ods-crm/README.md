# Snowflake CoCo MSTR_ODS CRM Workspace Pack

이 패키지는 Snowflake Workspace에서 `MSTR_DW`가 아닌 `MSTR_ODS/CRM` 원천을 기준으로 Streamlit, SQL, Semantic Layer를 만들기 위한 CoCo 참조 패키지다.

## Workspace 업로드

ZIP의 **내용 전체**를 Snowflake Workspace 최상위에 배치한다. ZIP 파일명을 가진 상위 폴더를 한 번 더 만들지 않는다.

```text
<Workspace 최상위>/
├── .cortex/skills/mstr-ods-crm-schema/SKILL.md
├── snowflake-mstr-ods-crm/
│   └── snowflake-coco-workspace-ods-v1/
├── README.md
└── DIRECTORY_TREE.md
```

`.cortex`가 `snowflake-mstr-ods-crm` 아래로 들어가면 프로젝트 스킬을 찾지 못할 수 있다. 반드시 Workspace 최상위에 둔다.

업로드 후 CoCo에서 `$$`를 입력해 `mstr-ods-crm-schema`가 목록에 나타나는지 확인한다. 보이지 않으면 `.cortex/skills/mstr-ods-crm-schema/SKILL.md`의 위치를 먼저 확인한다.

`.cortex/skills/mstr-ods-crm-schema/SKILL.md`는 `$mstr-ods-crm-schema` 호출을 화면에 보이는 Reference Pack으로 연결한다.

## 기본 호출

모든 ODS 기반 요청의 첫 줄에 다음을 입력한다.

```text
$mstr-ods-crm-schema
```

그 아래에는 개발 용어 없이 화면의 목적, 필요한 수치, 조회기간, 필터, 비교 기준을 자연어로 작성하면 된다.

기획자용 시작 문서:

```text
snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/07_PLANNER_GUIDE.md
```

## 실행 원천

- 허용 데이터베이스·스키마: `GN_DW.BRONZE_CRM`
- 허용 테이블: Reference에 등록된 50개 테이블
- 금지: MSTR_DW MART/DIM 직접 조회, 미등록 테이블의 임의 사용, 컬럼명이 같다는 이유만으로 수행하는 추정 JOIN

## 권장 사용 순서

1. 담당자가 이 패키지를 Workspace 최상위에 한 번 설치한다.
2. `$$`로 스킬 등록을 확인한다.
3. 기획자는 `07_PLANNER_GUIDE.md`의 예시를 복사한다.
4. 모든 ODS 요청의 첫 줄에 `$mstr-ods-crm-schema`를 입력한다.
5. CoCo가 제시한 업무 질문 최대 3개에 답한 뒤 구현을 요청한다.
6. CoCo가 대표 기간 검증 결과를 제시하기 전에는 완료로 승인하지 않는다.
