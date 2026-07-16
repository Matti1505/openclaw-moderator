# -*- coding: utf-8 -*-
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import shutil
import sys
import zipfile
from collections import Counter
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "data"
RULES = DATA / "rules.json"
SCHEDULE = DATA / "rule_schedule.json"
BACKUPS = DATA / "backups"


PROFILE_OVERRIDES = {
    "Normal": {},
    "Familienfreundlich": {
        "emoji_rule": {"enabled": True, "max_count": 8, "action": "timeout_300"},
        "uppercase": {"enabled": True, "action": "timeout_300"},
        "advanced": {"sexual_content": {"enabled": True, "action": "timeout_1800"}, "private_data": {"enabled": True, "action": "delete"}},
    },
    "Streng": {
        "emoji_rule": {"enabled": True, "max_count": 6, "action": "timeout_300"},
        "duplicate_message": {"enabled": True, "count": 3, "action": "timeout_300"},
        "message_flood": {"enabled": True, "count": 5, "window_seconds": 12, "action": "timeout_300"},
        "links": {"enabled": True, "action": "delete"},
        "advanced": {"multiple_links": {"enabled": True, "count": 2, "action": "timeout_1800"}, "spam_wave": {"enabled": True, "count": 7, "window_seconds": 30, "action": "timeout_1800"}},
    },
    "Nur markieren": {"__mark_only__": True},
    "Spamwelle": {
        "duplicate_message": {"enabled": True, "count": 2, "window_seconds": 60, "action": "timeout_300"},
        "message_flood": {"enabled": True, "count": 4, "window_seconds": 12, "action": "timeout_300"},
        "advanced": {"spam_wave": {"enabled": True, "count": 5, "window_seconds": 30, "action": "timeout_1800"}},
    },
}


def deep_update(target, override):
    for key, value in override.items():
        if key == "__mark_only__":
            continue
        if isinstance(value, dict) and isinstance(target.get(key), dict):
            deep_update(target[key], value)
        else:
            target[key] = value


def mark_only(value):
    if isinstance(value, dict):
        for key, child in value.items():
            if key == "action":
                value[key] = "flag"
            else:
                mark_only(child)
    elif isinstance(value, list):
        for child in value:
            mark_only(child)


def load_rules():
    return json.loads(RULES.read_text(encoding="utf-8"))


def save_rules(data):
    text = json.dumps(data, ensure_ascii=False, indent=2)
    RULES.write_text(text, encoding="utf-8")
    (ROOT / "rules.json").write_text(text, encoding="utf-8")


def apply_profile(name):
    data = load_rules()
    override = PROFILE_OVERRIDES[name]
    if override.get("__mark_only__"):
        mark_only(data)
    else:
        deep_update(data, override)
    data["selected_profile"] = name
    save_rules(data)
    print(json.dumps({"ok": True, "profile": name}, ensure_ascii=False))


def backup():
    BACKUPS.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    target = BACKUPS / f"chatwaechter-sicherung-{stamp}.zip"
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in [ROOT / "rules.json", RULES, DATA / "rule_schedule.json", DATA / "user_notes.json"]:
            if path.exists(): archive.write(path, path.relative_to(ROOT))
        for path in (DATA / "logs").glob("*.jsonl"):
            archive.write(path, path.relative_to(ROOT))
        for path in (DATA / "reports").glob("*"):
            if path.is_file(): archive.write(path, path.relative_to(ROOT))
    # Höchstens 30 automatische Sicherungen behalten.
    old = sorted(BACKUPS.glob("chatwaechter-sicherung-*.zip"), key=lambda p: p.stat().st_mtime, reverse=True)
    for path in old[30:]: path.unlink(missing_ok=True)
    print(str(target))


def watcher_module():
    os.environ["CHATWAECHTER_HOME"] = str(DATA)
    spec = importlib.util.spec_from_file_location("chatwaechter_engine", ROOT / "AUTO_LIVE_CHATWAECHTER.py")
    module = importlib.util.module_from_spec(spec)
    assert spec.loader
    spec.loader.exec_module(module)
    return module


def reset_engine(engine):
    engine.recent_by_author.clear(); engine.seen_message_ids.clear()
    engine.offense_history.clear(); engine.flagged_timestamps.clear(); engine.spam_wave_active = False


def simulate_text(text):
    engine = watcher_module(); reset_engine(engine)
    hits, delete_required, ban_action = engine.rule_hits("simulation-user", text, False, engine.load_rules())
    print(json.dumps({"text": text, "hits": hits, "delete": delete_required, "banAction": ban_action}, ensure_ascii=False, indent=2))


def simulate_log(path):
    engine = watcher_module(); reset_engine(engine); rules = engine.load_rules()
    total = hits_total = delete_total = ban_total = 0; rule_counts = Counter(); examples=[]; checked_messages=[]
    real_time = engine.time.time
    simulated_now = [real_time()]
    engine.time.time = lambda: simulated_now[0]
    try:
        with Path(path).open(encoding="utf-8") as handle:
            for line in handle:
                if not line.strip(): continue
                try: row = json.loads(line)
                except Exception: continue
                stamp = row.get("publishedAt") or row.get("receivedAt")
                if stamp:
                    try: simulated_now[0] = datetime.fromisoformat(str(stamp).replace("Z", "+00:00")).timestamp()
                    except (TypeError, ValueError): simulated_now[0] += 1.0
                else:
                    simulated_now[0] += 1.0
                total += 1
                hits, delete_required, ban_action = engine.rule_hits(str(row.get("authorChannelId", "simulation")), str(row.get("text", "")), bool(row.get("isOwner") or row.get("isModerator")), rules)
                if hits:
                    hits_total += 1
                    for hit in hits: rule_counts[str(hit.get("rule"))] += 1
                    if len(examples) < 30: examples.append({"author": row.get("authorName"), "text": row.get("text"), "rules": [h.get("rule") for h in hits]})
                delete_total += int(delete_required); ban_total += int(bool(ban_action))
                checked_messages.append({
                    "time": row.get("publishedAt") or row.get("receivedAt") or "",
                    "author": row.get("authorName") or "Unbekannt",
                    "text": row.get("text") or "",
                    "matched": bool(hits),
                    "rules": [str(hit.get("rule", "")) for hit in hits],
                    "reasons": [str(hit.get("reason", "")) for hit in hits],
                    "action": ban_action or ("delete" if delete_required else ("flag" if hits else "none")),
                })
    finally:
        engine.time.time = real_time
    result={"file":str(path),"messages":total,"wouldMatch":hits_total,"wouldDelete":delete_total,"wouldMuteOrBlock":ban_total,"topRules":rule_counts.most_common(20),"examples":examples,"checkedMessages":checked_messages}
    out=DATA/"simulation_result.json"; out.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding="utf-8")
    print(str(out))


def schedule(profile, start, end, enabled):
    override = PROFILE_OVERRIDES[profile]
    SCHEDULE.write_text(json.dumps({"enabled":enabled,"profile":profile,"start":start,"end":end,"overrides":override},ensure_ascii=False,indent=2),encoding="utf-8")
    print(str(SCHEDULE))


def main():
    parser=argparse.ArgumentParser(); sub=parser.add_subparsers(dest="command",required=True)
    sub.add_parser("backup")
    p=sub.add_parser("profile");p.add_argument("name",choices=PROFILE_OVERRIDES)
    p=sub.add_parser("simulate-text");p.add_argument("text")
    p=sub.add_parser("simulate-log");p.add_argument("path")
    p=sub.add_parser("schedule");p.add_argument("profile",choices=PROFILE_OVERRIDES);p.add_argument("start");p.add_argument("end");p.add_argument("--disabled",action="store_true")
    args=parser.parse_args()
    if args.command=="backup":backup()
    elif args.command=="profile":apply_profile(args.name)
    elif args.command=="simulate-text":simulate_text(args.text)
    elif args.command=="simulate-log":simulate_log(args.path)
    elif args.command=="schedule":schedule(args.profile,args.start,args.end,not args.disabled)
    return 0


if __name__=="__main__": raise SystemExit(main())
