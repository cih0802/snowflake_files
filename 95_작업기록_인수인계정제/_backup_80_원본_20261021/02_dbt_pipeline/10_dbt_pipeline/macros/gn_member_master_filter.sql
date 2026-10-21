{#
  gn_member_master_filter — 회원 마스터 정본에 없는 「고아 회원」 행을 SILVER 정제 단계에서 제거한다.

  🔴 정본 결정 = [2026-09-22 O179 · 현업 회신] 이슈 B.
     *"이벤트나 캠페인 등을 삭제할 때 그 곳에 귀속된 회원들도 삭제되어야 하나 남은 데이터들이다.
       지금 회원 마스터 데이터를 정본으로 하고, 고아 회원에 대한 건은 SILVER 에서 데이터 정제 시 없앤다."*
     ⇒ 즉 이 술어는 **데이터 품질 보정이 아니라 업무 규칙**이다. 마스터가 정본이고 자식이 따른다.

  🔴 왜 INNER JOIN 이 아니라 semi-join(EXISTS)인가 (설계 판정 · O179):
     · INNER JOIN 은 마스터 키가 유일해야 팬아웃하지 않는다. 지금은 유일하지만(실측 아래)
       마스터가 이력화(SCD)되면 **조용히 행이 불어난다** ⇒ 구조적으로 막을 수 없다.
     · EXISTS 는 **정의상 행 수를 늘릴 수 없다**(반조인). 또 SELECT 목록을 건드리지 않으므로
       모델 diff 가 WHERE 한 줄이고, 컬럼 해석·별칭 충돌 위험이 0 이다.
     ⇒ 같은 결과를 내는 두 방법 중 **되돌릴 수 없는 사고를 못 내는 쪽**을 골랐다.

  🔴 이 술어는 NULL 키도 함께 제거한다 — 의도다.
     `EXISTS` 는 NULL 비교가 성립하지 않아 자연히 탈락한다. 「회원에 귀속되지 않는 행」은
     회신의 제거 대상에 포함된다(실측 = `CRM_SEND_MEMBER.MBER_NO IS NULL` 746행).
     🟠 만약 「NULL 은 남긴다」로 바뀌면 이 매크로가 아니라 **호출부에 OR 조건을 더하라** —
        매크로를 분기시키면 정의 지점이 둘이 된다(`R1-6-17`).

  🔴 마스터 = `SILVER.CRM_MEMBER.MEMBER_DK`(정기 7자리 ∪ 일시 `S`+8자리 통합 키).
     📏 실측 2026-09-22 · 계정 LK96056 = 1,785,299행 / NOT NULL 1,785,299 / distinct 1,785,299
        ⇒ **전건 유일·NOT NULL**(= `GOLD.DIM_MEMBER` 행수와 일치).
     🔴 이 수치를 인용하지 말고 재라(`R2-8-4`).

  📏 적용 시 제거 예상량(실측 2026-09-22 · 고아 회원 합 8,491명):
     · `CRM_SEND_MEMBER`         34,246행 (+ NULL 746) / 41,970,336
     · `CRM_EVENT_PARTICIPATION` 10,048행 / 1,258,775
     · `CRM_MEMBER_DEV`             271행 / 3,654,929
     · `CRM_MEMBER_SPONSOR_SPAN`    106행 / 2,201,801
     · `CRM_MEMBER_STATUS_HIST`      86행 / 7,644,228
     · `CRM_PAYMENT_METHOD`          39행 / 2,589,005
     · `CRM_MEMBER_DISCONTINUE`       1행 / 1,061,431
     · `CRM_MEMBER_RESPONSOR`         1행 / 118,199
     ⇒ 합 44,798행 + NULL 746 = 45,544행 (전체 약 61.6M 의 0.074%)
     🟢 고아 0 인 모델(`CRM_MEMBER_AMT_CHANGE`·`CRM_SPONSOR_RELATION`)에도 붙인다 —
        **지금 0 이라는 것은 앞으로도 0 이라는 뜻이 아니다**(회귀 방어).

  🔴 호출부는 이 매크로를 `WHERE`/`AND` 뒤에 그대로 쓴다:
       WHERE {{ gn_member_master_filter('b.MBER_NO') }}
     🔴 `CRM_MEMBER` 자신에게는 쓰지 마라(자기참조 순환).
     🟢 `ref()` 를 쓰므로 dbt 가 `CRM_MEMBER` 를 먼저 빌드하도록 의존성을 자동 인식한다.
#}
{% macro gn_member_master_filter(member_col) %}
EXISTS (
    SELECT 1
    FROM {{ ref('CRM_MEMBER') }} gn_mm
    WHERE gn_mm.MEMBER_DK = {{ member_col }}
  )
{%- endmacro %}
