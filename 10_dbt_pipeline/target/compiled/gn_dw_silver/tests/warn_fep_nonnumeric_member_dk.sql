-- [2026-08-11 O59-H] `FACT_EVENT_PARTICIPATION.MEMBER_DK` 의 **비수치 회원키**를 관측한다.
-- Co-authored with CoCo
--
-- 🔴🔴🔴 왜 필요한가 (실측 경위 — 이 테스트의 1판이 훨씬 큰 것을 잡았다)
--   O28 오염(`)`) 을 추적하다 회원 축 고아를 세어 봤더니 **7,713종**이 나왔다. 그 중 **비수치 62종**의
--   값이 `bxss.me`·`@@XAsBY`·`../1377663`·`&lt;!--`·`&#39;""()`·`0526424*1` 이었다.
--   ⇒ **웹 취약점 스캐너 트래픽이 원천에 저장된 것**이다(원장 §O59-H).
--   `bxss.me` 는 Blind XSS 탐지용 공개 도메인이고 `@@`·`../`·인코딩 따옴표는 주입 프로브다.
--
-- 🔴 왜 「비수치」로 좁혔는가 (1판의 실패에서 배웠다)
--   1판은 **고아 전체**를 반환해 **7,713행**을 냈다. 그런 게이트는 **항상 빨갛고 곧 무시된다**(P103-⑤).
--   고아는 두 종류가 섞여 있다:
--     ① **비수치 = 구조적 오염**(스캐너 페이로드·`null` 문자열·`회원번호` 헤더값) → 이 테스트의 대상
--     ② **수치 고아 = 회원 마스터 미포함 참여자**(약 7,651종) → 성격이 다른 별건이며 원장 §O59-H ④ 에 등재
--   ⇒ 한 게이트에 두 성격을 섞으면 신호가 죽는다. 여기서는 ①만 본다.
--
-- 무엇이 문제인가
--   ⓐ 이 값들은 **GOLD 라이브**이고 회원 차원 조인에서 조용히 탈락하면서 총계에는 남는다(분모 불일치).
--   ⓑ 🟢 **[O59-I 실측 정정] Analyst 노출 경로는 없다.** SV 9종에 회원 식별자 DIMENSION 이 **0개**이고
--      `MEMBER_DK` 는 전부 `COUNT(DISTINCT …)` metric 내부에만 쓰인다(`SERVING` 에도 해당 컬럼 객체 0개).
--      ⇒ 초판 주석의 *"답변에 `bxss.me` 가 출력된다"* 는 **과대평가였다. 철회한다.**
--      남는 영향은 `COUNT(DISTINCT MEMBER_DK)` 계열 metric 6개의 **부풀림 33/407,223 = 0.008%**(무시 수준).
--   ⓒ 스캐너가 만든 행은 **실재하지 않는 참여 기록**이다 ⇒ 정정 대상이 아니라 **삭제 대상**이다.
--   ⓓ ⚠️ **「비수치」 자체는 비정상이 아니다** — 정규 회원의 **10%**(175,722건)가 `S`+8자리 체계다.
--      이 게이트가 유효한 것은 **비수치 ∧ 고아**로 좁혔기 때문이다. 어느 한쪽만으로는 배경 잡음에 묻힌다.
--
-- 왜 WARN 인가: 원천 보존 원칙(DEC-17-B)을 지키면서 **드러내기**만 한다. 삭제·치환은 원천 정정 사안이다.
--   ⚠️ 규모 수치는 여기 하드코딩하지 않는다(작업규칙 7) — 정본은 원장 §O59-H 다.
--
-- 판정: 반환 행이 있으면 WARN. 각 행 = 비수치 `MEMBER_DK` 1종 + 분류.
--   🔴 **0행이 되면** 원천에서 스캐너 트래픽이 제거된 것이므로 원장 §O59-H 를 닫는다.
--
-- 🔴 **Snowflake `REGEXP_LIKE` 는 전체 문자열 일치**다(부분 일치가 아니다). 1판이 `^[0-9]+[*+/-]` 로
--    `0526424*1` 을 놓쳐 `OTHER` 로 분류했다 — 뒤의 `1` 때문에 전체 일치가 깨진다.
--    ⇒ 부분 일치를 원하면 `.*` 를 붙인다. 앵커(`^`·`$`)는 불필요하다.
--    ⚠️ 이 오분류는 **조용하다**(행 수는 같고 분류만 틀린다) ⇒ 분류 게이트는 **분류별 건수**를 실측 대조한다.
--
-- 🆕 🔴🔴 [2026-08-29 O117] **분류별 건수를 실측했더니 이 게이트가 두 성격을 섞고 있었다**(위 「왜 비수치로 좁혔는가」가
--    스스로 금지한 것이다). 합 62 = 위 판정식 그대로 재현했고 보고값과 일치한다:
--      ALT_MEMBER_SCHEME **29** · SCANNER_CANARY_TOKEN 11 · SCANNER_SQL_PROBE 10 · SCANNER_HTML_INJECTION 4 ·
--      OTHER 3 · SCANNER_PATH_TRAVERSAL 2 · SCANNER_ARITHMETIC_PROBE 1 · SCANNER_SPECIAL_CHAR 1 · SCANNER_BLIND_XSS 1
--    ⇒ 🔴 **최대 계열이 스캐너가 아니다.** `ALT_MEMBER_SCHEME` 29종(46.8%)은 `S00023664` 같은 **정규 `S`+8자리 체계**이고
--      `SILVER.CRM_MEMBER` 에도 **0건**이다 ⇒ 성격상 위 분류 ②(**회원 마스터 미포함 = 탈퇴·삭제분 축**)이며
--      `BLOCKING-1`·문서50 §O116-3 ㉢ 과 **같은 축**이다. 비수치 필터가 ①만 남긴다는 전제가 여기서 깨진다
--      (`S`+8자리는 「비수치」이면서 「정상 체계」다 — 위 ⓓ 가 배경 잡음으로만 다룬 바로 그 값들이다).
--    · OTHER 3 의 실제 값 = `1793 568`(숫자 2개에 공백 혼입 · 길이 8) · `null`(문자열) · `회원번호`(헤더값).
--    ⇒ 🟢 스캐너 오염으로 확정할 수 있는 것은 **30종**이고 정규 체계 고아가 **29종**, 기타 오염이 **3종**이다.
--    🔴 **그렇다고 이 테스트를 좁히지 마라** — 좁히면 29종이 관측에서 사라진다. 처방은 「분해해서 보고」이고
--      정본이 그 분해를 보관한다(문서50 §O116-6 ㉢). 🔴 62 를 「스캐너 62건」으로 인용하면 과대 진술이다.



with orphan as (

    select distinct f.MEMBER_DK
    from GN_DW.GOLD.FACT_EVENT_PARTICIPATION f
    left join GN_DW.GOLD.DIM_MEMBER d
           on d.MEMBER_DK = f.MEMBER_DK
    where f.MEMBER_DK is not null
      and d.MEMBER_DK is null
      and not regexp_like(f.MEMBER_DK, '^[0-9]+$')

)

select
      o.MEMBER_DK                                                  as BAD_MEMBER_DK
    , case
        when o.MEMBER_DK ilike '%bxss%'                            then 'SCANNER_BLIND_XSS'
        when o.MEMBER_DK like '@@%'                                then 'SCANNER_SQL_PROBE'
        when o.MEMBER_DK like '../%' or o.MEMBER_DK like '%..%'    then 'SCANNER_PATH_TRAVERSAL'
        when o.MEMBER_DK like '%&#%' or o.MEMBER_DK like '%&lt;%'
          or o.MEMBER_DK like '%<%'  or o.MEMBER_DK like '%''%'    then 'SCANNER_HTML_INJECTION'
        when regexp_like(o.MEMBER_DK, '[0-9]+[*+/-].*')            then 'SCANNER_ARITHMETIC_PROBE'
        when length(o.MEMBER_DK) = 1                               then 'SCANNER_SPECIAL_CHAR'
        when regexp_like(o.MEMBER_DK, 'S[0-9]{8}')                 then 'ALT_MEMBER_SCHEME'
        when regexp_like(o.MEMBER_DK, '[0-9A-Za-z]{8,9}')          then 'SCANNER_CANARY_TOKEN'
        else 'OTHER'
      end                                                          as CLASSIFICATION
from orphan o