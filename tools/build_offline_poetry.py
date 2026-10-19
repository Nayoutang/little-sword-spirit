"""Build bundled data only; the game never downloads poetry."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data/poetry"
mapping = {}
for row in (DATA / "TSCharacters.txt").read_text(encoding="utf-8").splitlines():
    if row and not row.startswith("#"):
        left, right = row.split("\t")
        mapping[left] = right.split()[0]

def simplify(text):
    return "".join(mapping.get(c, c) for c in text)

entries = {}
def collect(node):
    if isinstance(node, list):
        for item in node:
            collect(item)
    elif isinstance(node, dict):
        source = simplify(node.get("author", "") + "《" + node.get("title", node.get("chapter", "")) + "》")
        for paragraph in node.get("paragraphs", []):
            clauses = re.split(r"[，。！？；,!?;]", simplify(paragraph))
            clauses = [c.strip() for c in clauses if c.strip()]
            for i in range(0, len(clauses) - 1, 2):
                if all(3 <= len(c) <= 12 for c in clauses[i:i+2]):
                    line = "，".join(clauses[i:i+2])
                    entries.setdefault(line, {"line": line, "source": source})
        if "content" in node:
            collect(node["content"])

collect(json.loads((DATA / "tang300_original.json").read_text(encoding="utf-8-sig")))
collect(json.loads((DATA / "qianjia_original.json").read_text(encoding="utf-8-sig")))
# Match the game's authored sword-intent definitions, including its chosen variants.
definitions = (ROOT / "scripts/data/companion_card_database.gd").read_text(encoding="utf-8")
for line, source in re.findall(r'"poem": "([^"]+)", "source": "([^"]+)"', definitions):
    entries[line] = {"line": line, "source": source}
(DATA / "couplets.json").write_text(json.dumps(list(entries.values()), ensure_ascii=False, indent=2), encoding="utf-8")
(DATA / "traditional_map.json").write_text(json.dumps(mapping, ensure_ascii=False), encoding="utf-8")
print(f"Bundled {len(entries)} unique couplets, {len(mapping)} character mappings")
