import io, re, sys
sys.path.insert(0, "/workspace/scripts")
import sv_code_label_gate as g
cases = [
    ("/workspace/05_SV-Agent_ai/05_05_SV_DDL_EVENT_PARTICIPATION.sql", "event.EVENT_CATEGORY_NAME AS", 19),
    ("/workspace/05_SV-Agent_ai/05_04_SV_DDL_SERVICE.sql", "fse.GA_CLICK_MAP_SRC AS", 4),
]
live = {
    "EVENT_CATEGORY_NAME": {"I'm your pen", "국내사업장방문", "굿멤버스데이(본부)", "굿멤버스데이(지부)", "굿모닝",
        "기업제휴", "기타", "리플렛", "문화서비스", "문화서비스_공연", "문화서비스_서적", "문화서비스_전시",
        "앱전용", "오프라인", "온라인", "좋은이웃콘서트", "특성화회원조직", "해외사업장방문", "회지"},
    "GA_CLICK_MAP_SRC": {"DIRECT", "INFER", "MANUAL", "NONE"},
}
for path, key, _ in cases:
    line = [l for l in io.open(path, encoding="utf-8") if key in l][0]
    body = re.search(r"COMMENT = '(.*)',\s*$", line).group(1).replace("''", "'")
    col = key.split(".")[1].split()[0]
    vals, cnt = g.enumerated_values(body, col)
    ghost = vals - live[col]
    miss = live[col] - vals
    print(col, "열거", len(vals), "· 실측에 없는 값(코드값 부재)", sorted(ghost), "· 열거 밖 실측값", sorted(miss))
