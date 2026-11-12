"""Self-check for merge.py: python3 -I windows-terminal/test_merge.py"""
import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import merge  # noqa: E402

PATCH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "settings.patch.json")

jsonc = """{
    // a comment WT used to generate
    "$schema": "https://aka.ms/terminal-profiles-schema",
    "profiles": {
        "defaults": { "font": { "face": "Old", "weight": "bold" } },
        "list": [ { "guid": "{x}", "name": "Ubuntu" }, ],
    },
    "schemes": [ { "name": "SynthWave '84", "background": "#000000" }, { "name": "Campbell" } ]
}"""

with tempfile.TemporaryDirectory() as d:
    path = os.path.join(d, "settings.json")
    open(path, "w").write(jsonc)
    merge.main(path, PATCH)
    s = json.load(open(path))
    dflt = s["profiles"]["defaults"]
    assert dflt["font"] == {"face": "JetBrainsMono Nerd Font", "weight": "bold", "size": 11}, dflt
    assert dflt["colorScheme"] == "SynthWave '84" and dflt["opacity"] == 95
    assert s["profiles"]["list"] == [{"guid": "{x}", "name": "Ubuntu"}]
    names = [x["name"] for x in s["schemes"]]
    assert names.count("SynthWave '84") == 1 and "Campbell" in names, names
    assert [x for x in s["schemes"] if x["name"] == "SynthWave '84"][0]["background"] == "#111018"
    assert s["$schema"].startswith("https://")  # comment stripping must not eat URLs
    mtime = os.path.getmtime(path)
    merge.main(path, PATCH)  # second run: no change, no write
    assert os.path.getmtime(path) == mtime
print("merge.py ok")
