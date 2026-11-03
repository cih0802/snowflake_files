import io, re, sys, yaml
for ag in sys.argv[1:]:
    loc = yaml.safe_load(io.open(f'/workspace/cortex_project/agents/{ag}/agent_spec.yaml', encoding='utf-8'))
    o = loc['instructions']['orchestration']
    for m in re.finditer(r'사전에 정해진 산식|산식이 없|계산할까요|미정의 지표', o):
        print(ag, m.start(), '|', o[max(0, m.start()-500):m.start()+400].replace('\n', ' '))
        print('---')
