"""Export the original League badge checkpoint coordinates."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
result={}
for name in ["Route22_NorthEntrance","Route23"]:
    m=json.loads((root/"data/source/pokefirered/data/maps"/name/"map.json").read_text())
    result[m["id"]]=[[e["x"],e["y"],e["script"].split("EventScript_")[1].split("Badge")[0]] for e in m["coord_events"]]
(root/"assets/kanto/badge-checkpoints.json").write_text(json.dumps(result,indent=2)+"\n")
