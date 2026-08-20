select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      -- [2026-08-19 O87-B] `BIGQUERY_REFINED_DATA.ID_SCHEME = 'UNCLASSIFIED'` 를 관측한다.
-- Co-authored with CoCo
--
-- 🔴🔴 왜 필요한가 (실측 경위 — 이 게이트가 없어서 O87 이 틀린 수치를 승계했다)
--   O87 은 종전 문서(`40_입고대기_원천의존.md` · `90` §1-A)의 *"`user_id` 실측 **6종**"* 을
--   **검증 없이 그대로 승계**했다. O87-B 에서 전기간을 직접 실측하니 **7종**이었다.
--   누락돼 있던 것 = 리터럴 **`undefined`**(계정 `UA93987` · **293행 / 1 id** ·
--   `2024-03-25` ~ `2026-06-08` · 길이 9). 그것이 종전 집계에서 `ONCE_MBER_NO` 버킷에
--   흡수돼 그 버킷이 **293행 · 1 id 과대**였다(종전 194,763/16,907 → 실측 **194,470/16,906**).
--   ⇒ `undefined` 는 `'null'`(20행) 과 같은 **프런트엔드 오류값**이므로 `INVALID` 로 편입했다.
--
-- 🔴 왜 컬럼 테스트(`accepted_values`)로는 못 잡는가
--   `accepted_values` 목록에 `UNCLASSIFIED` 를 **허용값으로 넣어야** 한다 — 넣지 않으면
--   새 포맷 등장 시 그 테스트가 실패하는데, 그 실패는 「분류 누락」과 「허용 목록 미갱신」을
--   구분해 주지 못한다. 그래서 허용값으로 두고 **규모를 별도로 감시**한다.
--   ⇒ 이 파일이 조기경보의 **본체**다. `accepted_values` 는 오탈자 방어용 보조다.
--
-- 무엇이 문제인가
--   ⓐ `UNCLASSIFIED` 는 **CRM 조인 대상이 아니다** — `IDENTITY_MEMBER_XREF` 에서
--      `NOT_A_MEMBER_ID` 로 분류돼 채움률 분모 **밖**으로 나간다.
--      즉 새 포맷이 실제 회원번호 체계인데 여기 떨어지면 **회원이 조용히 익명으로 집계된다.**
--   ⓑ 반대로 오류값이면 분모 밖이 정답이다. **둘을 사람이 판별해야 하므로 드러내야 한다.**
--
-- 왜 WARN 인가: 원천 보존 원칙(`DEC-17-B`) — 새 값을 임의 분류하지 않고 **드러내기만** 한다.
--   ⚠️ 규모 수치는 여기 하드코딩하지 않는다(`R2-6`) — 정본은 `90` §1-B-실측이다.
--
-- 판정: 반환 행이 있으면 WARN. 각 행 = 미분류 값 1종 + 모양(숫자를 `N` 으로 치환) + 규모.
--   🔴 **현재 기대값은 0 행이다**(`undefined` 편입 후). 0 이 아니면 원천에 새 포맷이 생긴 것이다.
--   🟢 값 원문을 그대로 내지 않고 **모양**을 함께 내는 이유 = 회원 식별자일 수 있으므로
--      패턴 판별에 필요한 최소 정보만 노출한다(값 자체도 필요해 남기지만 건수가 소수임을 전제한다).



select
      ID_SCHEME                                         as ID_SCHEME
    , USER_ID                                           as BAD_USER_ID
    , length(USER_ID)                                   as ID_LEN
    , regexp_replace(USER_ID, '[0-9]', 'N')             as ID_SHAPE
    , count(*)                                          as ROWS_CNT
    , min(EVENT_DT)                                     as FIRST_DT
    , max(EVENT_DT)                                     as LAST_DT
from GN_DW.SILVER.BIGQUERY_REFINED_DATA
where ID_SCHEME = 'UNCLASSIFIED'
group by all
      
    ) dbt_internal_test