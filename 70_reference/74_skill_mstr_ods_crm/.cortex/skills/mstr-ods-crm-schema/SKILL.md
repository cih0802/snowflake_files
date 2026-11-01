---
name: mstr-ods-crm-schema
description: Use only when the user explicitly invokes $mstr-ods-crm-schema. Routes MSTR_ODS CRM analysis, validation, and Streamlit work to the governed Snowflake Workspace reference pack for GN_DW.BRONZE_CRM.
---

# MSTR ODS CRM Schema Router

이 스킬은 현재 사용자 메시지에 `$mstr-ods-crm-schema`가 명시된 경우에만 적용한다.

호출되지 않았다면 이 스킬의 테이블, JOIN, 지표, Snapshot 규칙을 다른 작업에 자동 적용하지 않는다.

활성화된 경우 다음 파일을 먼저 읽고 그 지시를 따른다.

```text
../../../snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/skills/mstr-ods-crm-schema/SKILL.md
```

참조 파일의 기준 루트는 다음이다.

```text
../../../snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/
```

참조 파일을 찾지 못하면 다른 MSTR_DW 또는 유사 파일로 대체하지 말고 `자료 필요`로 보고한다.
