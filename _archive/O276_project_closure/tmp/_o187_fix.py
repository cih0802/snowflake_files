import io
subs = {
 '10_dbt_pipeline/02_dbt_parse_compile_build.sql': [
  ("종전 「조용히 무시된다」(O177)는 **오진**이었고,\n--       실제 원인 = 콜론 뒤 공백 없는 YAML 표기(`{bigquery_dt_ranges:[...]}` → 키 하나로 파싱)로 판정한다(macro 헤더).",
   "종전 「조용히 무시된다」(O177)는 **실행 경로 한정 사실**이었다 —\n--       실패 = Snowsight **Workspaces dbt 클라이언트**(공백 절단·인용부호 제거 · `dbt_project.yml:97`) · 성공 = **`EXECUTE DBT PROJECT` ARGS**."),
  ("⇒ 쓸 때는 **JSON 형태**를 쓴다", "⇒ 쓸 때는 **`EXECUTE DBT PROJECT` 경로 + JSON 형태**를 쓴다(Workspaces 클라이언트에서는 여전히 쓰지 않는다)"),
 ],
 '11_일적재pipeline 구성/00_개요_및_실행순서.md': [
  ("종전 「애초에 동작하지 않았다 · 조용히 무시된다」(O179)는 **오진**이다. 실제 원인 = 콜론 뒤 공백 없는 YAML 표기.",
   "단 **`EXECUTE DBT PROJECT` 경로에서만** — 종전 실패(O179)는 Workspaces dbt 클라이언트 경로였다(공백 절단·인용부호 제거)."),
 ],
 '10_dbt_pipeline/macros/bigquery_range_predicate.sql': [
  ("**[2026-09-28 O187 정정] `--vars` 는 전달된다 — 종전 「이 환경에서 동작하지 않는다」는 오진이었다.**",
   "**[2026-09-28 O187 정정] `--vars` 는 `EXECUTE DBT PROJECT` 경로에서 전달된다 — 종전 실패는 Workspaces 클라이언트 경로다.**"),
  ("⇒ 종전 실패의 원인은 전달이 아니라 **이 표기**였다(아래 줄의 기존 관찰과 일치).",
   "⇒ Workspaces 클라이언트 경로의 실패 3형태는 `dbt_project.yml:97~105` 가 정본이다(공백 절단·인용부호 제거·이 표기)."),
 ],
}
for p, pairs in subs.items():
    t = io.open(p, encoding='utf-8').read()
    for a, b in pairs:
        assert t.count(a) == 1, (p, a[:40]); t = t.replace(a, b)
    io.open(p, 'w', encoding='utf-8', newline='').write(t); print('ok', p)
P='10_dbt_pipeline/dbt_project.yml'; t=io.open(P,encoding='utf-8').read()
a="  #      ⇒ 오버라이드는 **파일에 적는 것만 신뢰할 수 있다.** `--vars` 로 지시하는 문서를 쓰지 마라.\n"
assert t.count(a)==1
t=t.replace(a, a+"  #   🟢 [2026-09-28 O187] 위 3형태는 **Workspaces dbt 클라이언트 경로 한정**이다 — `EXECUTE DBT PROJECT … ARGS='compile … --vars ''{\"bigquery_lookback_days\": 999}'''`\n  #      는 JSON·YAML 두 형태 모두 **전달됐다**(창 하한 20240103 = 실행일 − 999일 · xf98254). 리스트 var 는 미실측.\n")
io.open(P,'w',encoding='utf-8',newline='').write(t); print('ok', P)
