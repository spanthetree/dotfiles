"""Merge settings.patch.json into Windows Terminal's settings.json.

Schemes are replaced by name; profiles.defaults keys are set (font merged key by key).
Machine-specific profiles are left alone. Writes only when something changed.
Usage: python3 -I merge.py <settings.json> <settings.patch.json>
"""
import json
import re
import sys


def load_jsonc(path):
    text = open(path, encoding="utf-8-sig").read()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        # Older WT files carry full-line // comments and trailing commas
        text = re.sub(r"^\s*//.*$", "", text, flags=re.M)
        text = re.sub(r",(\s*[}\]])", r"\1", text)
        return json.loads(text)


def merge(settings, patch):
    profiles = settings.setdefault("profiles", {})
    if not isinstance(profiles, dict):
        raise SystemExit("settings.json uses the old list-style 'profiles'; open and save it in WT first")
    defaults = profiles.setdefault("defaults", {})
    for key, value in patch["profiles"]["defaults"].items():
        if isinstance(value, dict):
            defaults.setdefault(key, {}).update(value)
        else:
            defaults[key] = value
    schemes = settings.setdefault("schemes", [])
    for scheme in patch["schemes"]:
        schemes[:] = [s for s in schemes if s.get("name") != scheme["name"]] + [scheme]
    return settings


def main(settings_path, patch_path):
    before = load_jsonc(settings_path)
    after = merge(json.loads(json.dumps(before)), json.load(open(patch_path, encoding="utf-8")))
    if after == before:
        print("   already up to date")
        return
    with open(settings_path, "w", encoding="utf-8", newline="\r\n") as f:
        json.dump(after, f, indent=4, ensure_ascii=False)
        f.write("\n")
    print("   updated")


if __name__ == "__main__":
    main(*sys.argv[1:3])
