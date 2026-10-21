import json
a = json.load(open("/tmp/base/target/manifest.json")); b = json.load(open("/workspace/10_dbt_pipeline/target/manifest.json"))
for n in ["AGENCY_AD_CREATIVE", "CRM_CAMPAIGN", "CRM_MEMBER", "CRM_RELATION_ACTIVITY", "CRM_SEND_REQUEST"]:
    k = "model.gn_dw_silver." + n
    x, y = a["nodes"][k], b["nodes"][k]
    print(n, x["original_file_path"])
    print("  base-only", sorted(set(map(tuple, x["sources"])) - set(map(tuple, y["sources"]))))
    print("  new-only ", sorted(set(map(tuple, y["sources"])) - set(map(tuple, x["sources"]))))
