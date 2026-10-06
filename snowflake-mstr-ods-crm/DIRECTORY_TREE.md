# MSTR_ODS CoCo Workspace 디렉토리 구조

## 설치 후 모습

```text
<Snowflake Workspace 최상위>/
├── .cortex/
│   └── skills/
│       └── mstr-ods-crm-schema/
│           └── SKILL.md                       # $ 호출용 라우터
├── snowflake-mstr-ods-crm/
│   └── snowflake-coco-workspace-ods-v1/
│       ├── SNOWFLAKE.md                       # Workspace 공통 실행 규칙
│       ├── 05_COCO_TASK_TEMPLATE.md           # 범용 요청서
│       ├── 06_REFERENCE_MANIFEST.yaml         # Reference 목록과 우선순위
│       ├── 07_PLANNER_GUIDE.md                # 기획자 메인 가이드
│       ├── 08_PROMPT_INDEX.md                 # 예시 프롬프트 색인
│       ├── skills/
│       │   └── mstr-ods-crm-schema/
│       │       └── SKILL.md                   # 실제 ODS 업무 지침
│       ├── references/
│       │   ├── common/                        # 승인 테이블·컬럼·JOIN·코드·검증
│       │   ├── examples/                      # 기획자 상황별 자연어 예시
│       │   ├── legacy_dw/                     # DW 자료 사용 제한 안내
│       │   └── reports/
│       │       └── CRM_SEND_PERFORMANCE/      # 발송성과 전용 계약·지표·UI·검증
│       └── scripts/
│           └── 01_PROFILE_SEND_KEY_CONTRACT.sql
├── README.md
└── DIRECTORY_TREE.md
```

## 폴더별 사용 주체

| 위치 | 주 사용자 | 용도 |
|---|---|---|
| `.cortex/skills/...` | CoCo | `$mstr-ods-crm-schema`를 발견하고 실제 지침으로 연결 |
| `07_PLANNER_GUIDE.md` | 기획자 | 개발 용어 없이 요청하는 방법 확인 |
| `05_COCO_TASK_TEMPLATE.md` | 기획자 | 신규·변경·검증·진단 공통 요청 작성 |
| `references/examples/` | 기획자 | 상황별 완성 프롬프트 복사 |
| `references/common/` | CoCo·데이터 담당자 | 승인 데이터와 안전한 JOIN·집계·보안 규칙 확인 |
| `references/reports/` | CoCo·기획자 | 특정 화면의 열·지표·UI·검증 계약 확인 |
| `scripts/` | 데이터 담당자·CoCo | 운영 적용 전 연결키 프로파일 수행 |

## 설치 확인

1. `.cortex`와 `snowflake-mstr-ods-crm`이 Workspace 최상위에서 서로 같은 깊이에 있는지 확인한다.
2. CoCo에서 `$$`를 입력한다.
3. 목록에서 `mstr-ods-crm-schema`를 확인한다.
4. 다음 시험 요청을 실행한다.

```text
$mstr-ods-crm-schema

구현하지 말고, 이 스킬이 참조하는 실행 데이터 범위와 기획자에게 묻지 말아야 할 기술 항목을 설명해주세요.
```

정상이라면 실행 원천을 `GN_DW.BRONZE_CRM`의 승인된 50개 테이블로 설명하고, 기획자에게 영문 테이블명·컬럼명·코드값·JOIN 키를 요구하지 않아야 한다.
