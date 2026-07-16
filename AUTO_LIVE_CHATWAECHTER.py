# -*- coding: utf-8 -*-
#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import time
import traceback
import unicodedata
from collections import defaultdict, deque
from datetime import datetime, timezone
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

BASE = Path(os.environ.get("CHATWAECHTER_HOME", Path(__file__).resolve().parent / "data"))
TOKEN_FILE = BASE / "token.json"
LOG_DIR = BASE / "logs"
STATUS_FILE = BASE / "auto_live_status.json"
PID_FILE = BASE / "auto_live_watcher.pid"
RULES_FILE = BASE / "rules.json"
CHAT_SEND_REQUEST_FILE = BASE / "chat_send_request.json"
CHAT_SEND_RESULT_FILE = BASE / "chat_send_result.json"
MANUAL_SEARCH_FILE = BASE / "manual_live_search.request"
PAUSE_FILE = BASE / "moderation_paused.flag"
MOD_COMMAND_FILE = BASE / "moderation_command.json"
MOD_RESULT_FILE = BASE / "moderation_command_result.json"
REPORT_DIR = BASE / "reports"
SCHEDULE_FILE = BASE / "rule_schedule.json"

CHANNEL_HANDLE = "TobiundMatthias"
CHECK_INTERVAL_SECONDS = 45
RECENT_UPLOADS_TO_CHECK = 12

SCOPES = [
    "https://www.googleapis.com/auth/youtube.force-ssl",
    "https://www.googleapis.com/auth/youtube.readonly",
]

URL_RE = re.compile(r"https?://|www\.", re.I)
UPPER_RE = re.compile(r"[A-ZÄÖÜ]")
LETTER_RE = re.compile(r"[A-Za-zÄÖÜäöüß]")

EMOJI_RE = re.compile(
    "["
    "\U0001F1E6-\U0001F1FF"
    "\U0001F300-\U0001F5FF"
    "\U0001F600-\U0001F64F"
    "\U0001F680-\U0001F6FF"
    "\U0001F700-\U0001F77F"
    "\U0001F780-\U0001F7FF"
    "\U0001F800-\U0001F8FF"
    "\U0001F900-\U0001F9FF"
    "\U0001FA00-\U0001FAFF"
    "\u2600-\u26FF"
    "\u2700-\u27BF"
    "]",
    re.UNICODE,
)

DEFAULT_RULES = {
    "exempt_owner": True,
    "exempt_moderators": True,
    "emoji_rule_enabled": False,
    "emoji_rule": {"enabled": False, "max_count": 10, "action": "flag"},
    "custom_rules": [],
    "duplicate_message": {"enabled": False, "count": 4, "window_seconds": 90, "action": "flag"},
    "message_flood": {"enabled": False, "count": 6, "window_seconds": 12, "action": "flag"},
    "uppercase": {"enabled": True, "min_letters": 12, "min_ratio": 0.8, "action": "delete"},
    "repeated_characters": {"enabled": False, "minimum_run": 6, "action": "flag"},
    "links": {"enabled": False, "action": "flag"},
    "blocked_terms": {"enabled": False, "action": "flag", "terms": []},
    "insults": {"enabled": True, "action": "delete", "terms": ["idiot", "arschloch"]},
    "advanced": {
        "multiple_links": {"enabled": False, "count": 2, "action": "timeout_1800"},
        "advertising": {"enabled": False, "action": "timeout_1800", "terms": ["abonniert meinen kanal", "folgt mir", "schreibt mir privat", "link in meinem profil"]},
        "contact_data": {"enabled": False, "action": "flag"},
        "fraud": {"enabled": False, "action": "timeout_1800", "terms": ["gratis krypto", "crypto giveaway", "garantierte rendite", "investment opportunity", "youtube support", "youtube mitarbeiter"]},
        "mentions": {"enabled": False, "count": 4, "action": "timeout_300"},
        "long_message": {"enabled": False, "max_characters": 500, "action": "flag"},
        "multiline": {"enabled": False, "max_lines": 5, "action": "flag"},
        "near_duplicate": {"enabled": False, "ratio": 0.9, "action": "flag"},
        "private_data": {"enabled": False, "action": "delete"},
        "threats": {"enabled": False, "action": "timeout_1800", "terms": ["ich bring dich um", "ich töte dich", "du wirst sterben"]},
        "hate_speech": {"enabled": False, "action": "block", "terms": []},
        "sexual_content": {"enabled": False, "action": "timeout_1800", "terms": []},
        "spoilers": {"enabled": False, "action": "flag", "terms": []},
        "topic_filter": {"enabled": False, "action": "flag", "terms": []},
        "foreign_language": {"enabled": False, "action": "flag", "terms": []},
        "trusted_users": [],
        "repeat_offender": {"enabled": False, "expiry_seconds": 21600, "steps": ["flag", "timeout_300", "timeout_1800", "block"]},
        "spam_wave": {"enabled": False, "count": 10, "window_seconds": 30, "action": "timeout_1800"}
    },
}

recent_by_author: dict[str, deque[tuple[float, str]]] = defaultdict(
    lambda: deque(maxlen=100)
)
seen_message_ids: set[str] = set()
offense_history: dict[str, deque[tuple[float, int]]] = defaultdict(lambda: deque(maxlen=100))
flagged_timestamps: deque[float] = deque(maxlen=500)
api_call_count = 0
spam_wave_active = False


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def write_status(state: str, **extra: Any) -> None:
    payload = {
        "state": state,
        "channelHandle": f"@{CHANNEL_HANDLE}",
        "updatedAt": utc_now(),
        **extra,
    }
    STATUS_FILE.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def load_rules() -> dict[str, Any]:
    data = json.loads(json.dumps(DEFAULT_RULES))
    if not RULES_FILE.exists():
        return data
    try:
        loaded = json.loads(RULES_FILE.read_text(encoding="utf-8"))
        for key, value in loaded.items():
            if isinstance(value, dict) and isinstance(data.get(key), dict):
                data[key].update(value)
            else:
                data[key] = value
    except Exception as exc:
        write_status("rules_error", error=f"rules.json konnte nicht gelesen werden: {exc}")
    try:
        if SCHEDULE_FILE.exists():
            schedule = json.loads(SCHEDULE_FILE.read_text(encoding="utf-8"))
            if schedule.get("enabled"):
                now_minutes = datetime.now().hour * 60 + datetime.now().minute
                start_h, start_m = map(int, str(schedule.get("start", "00:00")).split(":"))
                end_h, end_m = map(int, str(schedule.get("end", "23:59")).split(":"))
                start_minutes, end_minutes = start_h*60+start_m, end_h*60+end_m
                active = start_minutes <= now_minutes <= end_minutes if start_minutes <= end_minutes else (now_minutes >= start_minutes or now_minutes <= end_minutes)
                if active:
                    for key, value in dict(schedule.get("overrides", {})).items():
                        if isinstance(value, dict) and isinstance(data.get(key), dict):
                            data[key].update(value)
                        else:
                            data[key] = value
                    data["active_schedule_profile"] = schedule.get("profile", "Zeitprofil")
    except Exception:
        pass
    return data


def load_credentials() -> Credentials:
    if not TOKEN_FILE.exists():
        raise RuntimeError(f"OAuth-Token fehlt: {TOKEN_FILE}")

    creds = Credentials.from_authorized_user_file(str(TOKEN_FILE), SCOPES)
    if creds.expired and creds.refresh_token:
        creds.refresh(Request())
        TOKEN_FILE.write_text(creds.to_json(), encoding="utf-8")

    if not creds.valid:
        raise RuntimeError("YouTube-OAuth ist nicht mehr gültig.")

    return creds


def youtube_client():
    return build("youtube", "v3", credentials=load_credentials(), cache_discovery=False)


def resolve_channel_and_uploads(youtube) -> tuple[str, str]:
    global api_call_count
    api_call_count += 1
    response = youtube.channels().list(
        part="id,contentDetails,snippet",
        forHandle=CHANNEL_HANDLE,
        maxResults=1,
    ).execute()

    items = response.get("items", [])
    if not items:
        raise RuntimeError(f"Kanal @{CHANNEL_HANDLE} wurde nicht gefunden.")

    item = items[0]
    return item["id"], item["contentDetails"]["relatedPlaylists"]["uploads"]


def find_active_stream(youtube, uploads_playlist_id: str) -> dict[str, str] | None:
    global api_call_count
    api_call_count += 2
    playlist_response = youtube.playlistItems().list(
        part="contentDetails,snippet",
        playlistId=uploads_playlist_id,
        maxResults=RECENT_UPLOADS_TO_CHECK,
    ).execute()

    video_ids = [
        item.get("contentDetails", {}).get("videoId")
        for item in playlist_response.get("items", [])
    ]
    video_ids = [video_id for video_id in video_ids if video_id]
    if not video_ids:
        return None

    videos_response = youtube.videos().list(
        part="snippet,liveStreamingDetails",
        id=",".join(video_ids),
        maxResults=len(video_ids),
    ).execute()

    for item in videos_response.get("items", []):
        snippet = item.get("snippet", {})
        live = item.get("liveStreamingDetails", {})
        active_chat_id = live.get("activeLiveChatId")
        if (
            snippet.get("liveBroadcastContent") == "live"
            and active_chat_id
            and not live.get("actualEndTime")
        ):
            return {
                "videoId": item["id"],
                "liveChatId": active_chat_id,
                "title": snippet.get("title", "Livestream"),
                "url": f"https://www.youtube.com/watch?v={item['id']}",
            }
    return None


def role_from_author(author: dict[str, Any]) -> str:
    roles = []
    if author.get("isChatOwner"):
        roles.append("Kanalinhaber")
    if author.get("isChatModerator"):
        roles.append("Moderator")
    if author.get("isChatSponsor"):
        roles.append("Mitglied")
    return ", ".join(roles) or "Zuschauer"


def contains_term(text: str, terms: list[str]) -> str | None:
    for term in terms:
        value = str(term).strip()
        if not value:
            continue
        # Nur vollständige Wörter bzw. Ausdrücke erkennen. So löst z. B.
        # "Wicht" nicht innerhalb von "wichtig" und "Affe" nicht in
        # "Kaffee" aus.
        pattern = r"(?<!\w)" + re.escape(value) + r"(?!\w)"
        if re.search(pattern, text, re.IGNORECASE):
            return term
    return None


def normalized_for_evasion(text: str) -> str:
    value = unicodedata.normalize("NFKD", text.casefold())
    value = value.translate(str.maketrans({"0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t"}))
    return "".join(ch for ch in value if ch.isalnum())


def add_hit(hits, rule: str, reason: str, action: str) -> None:
    if not any(hit.get("rule") == rule for hit in hits):
        hits.append({"rule": rule, "reason": reason, "action": action})


def rule_hits(author_channel_id: str, text: str, exempt: bool, rules: dict[str, Any]):
    global spam_wave_active
    if exempt:
        # Immer dieselbe dreiteilige Rückgabe liefern. Andernfalls brechen
        # Simulation und Live-Wächter bei Inhaber-/Moderatornachrichten ab.
        return [], False, ""

    now = time.time()
    normalized = " ".join(text.casefold().split())
    history = recent_by_author[author_channel_id]
    hits: list[dict[str, str]] = []
    delete_required = False

    dup = rules["duplicate_message"]
    if dup.get("enabled") and normalized:
        same_before = sum(
            1 for ts, previous in history
            if now - ts <= float(dup.get("window_seconds", 90))
            and previous == normalized
        )
        # count=4 means the fourth occurrence is marked.
        if same_before + 1 >= int(dup.get("count", 4)):
            hits.append({
                "rule": "duplicate",
                "reason": "Gleiche Frage oder gleicher Text viermal gestellt",
                "action": str(dup.get("action", "flag")),
            })

    flood = rules["message_flood"]
    if flood.get("enabled"):
        count_before = sum(
            1 for ts, _ in history
            if now - ts <= float(flood.get("window_seconds", 12))
        )
        if count_before + 1 >= int(flood.get("count", 6)):
            hits.append({
                "rule": "flood",
                "reason": "Mindestens sechs Nachrichten in zwölf Sekunden",
                "action": str(flood.get("action", "flag")),
            })

    upper = rules["uppercase"]
    letters = LETTER_RE.findall(text)
    uppercase = UPPER_RE.findall(text)
    if (
        upper.get("enabled")
        and len(letters) >= int(upper.get("min_letters", 12))
        and len(uppercase) / max(len(letters), 1) >= float(upper.get("min_ratio", 0.8))
    ):
        action = str(upper.get("action", "delete"))
        hits.append({
            "rule": "uppercase",
            "reason": "Überwiegend Großbuchstaben",
            "action": action,
        })
        delete_required = delete_required or action == "delete"

    repeated = rules["repeated_characters"]
    run = int(repeated.get("minimum_run", 10))
    if repeated.get("enabled") and re.search(r"(.)\1{" + str(max(run - 1, 1)) + r",}", text, re.S):
        hits.append({
            "rule": "repeated_characters",
            "reason": f"Mindestens {run} gleiche Zeichen hintereinander",
            "action": str(repeated.get("action", "flag")),
        })

    link = rules["links"]
    if link.get("enabled") and URL_RE.search(text):
        hits.append({
            "rule": "link",
            "reason": "Link erkannt",
            "action": str(link.get("action", "flag")),
        })

    blocked = rules["blocked_terms"]
    if blocked.get("enabled"):
        matched = contains_term(text, list(blocked.get("terms", [])))
        if matched:
            hits.append({
                "rule": "blocked_term",
                "reason": f"Blockierter Werbe- oder Spambegriff: {matched}",
                "action": str(blocked.get("action", "flag")),
            })

    insults = rules["insults"]
    if insults.get("enabled"):
        matched = contains_term(text, list(insults.get("terms", [])))
        if matched:
            action = str(insults.get("action", "delete"))
            hits.append({
                "rule": "insult",
                "reason": f"Beleidigung erkannt: {matched}",
                "action": action,
            })
            delete_required = delete_required or action == "delete"


    emoji_rule = rules.get("emoji_rule", {})
    if emoji_rule.get("enabled"):
        emoji_count = len(EMOJI_RE.findall(text))
        max_count = int(emoji_rule.get("max_count", 8))
        if emoji_count > max_count:
            action = str(emoji_rule.get("action", "flag"))
            hits.append({
                "rule": "emoji",
                "reason": f"Zu viele Emojis: {emoji_count}, erlaubt sind {max_count}",
                "action": action,
            })
            delete_required = delete_required or action == "delete"

    for custom_rule in list(rules.get("custom_rules", [])):
        if not isinstance(custom_rule, dict) or not custom_rule.get("enabled", True):
            continue
        matched = contains_term(text, list(custom_rule.get("terms", [])))
        if matched:
            action = str(custom_rule.get("action", "flag"))
            rule_name = str(custom_rule.get("name", "Eigene Regel"))
            hits.append({
                "rule": f"custom:{rule_name}",
                "reason": f"{rule_name}: {matched}",
                "action": action,
            })
            delete_required = delete_required or action == "delete"

    advanced = rules.get("advanced", {})
    trusted = {str(value).casefold() for value in advanced.get("trusted_users", [])}
    is_trusted = author_channel_id.casefold() in trusted

    link_matches = re.findall(r"(?:https?://|www\.)\S+", text, re.I)
    cfg = advanced.get("multiple_links", {})
    if cfg.get("enabled") and len(link_matches) >= int(cfg.get("count", 2)) and not is_trusted:
        add_hit(hits, "multiple_links", f"Mehrere Links erkannt: {len(link_matches)}", str(cfg.get("action", "timeout_1800")))

    for key, label in (("advertising", "Werbesatz"), ("fraud", "Betrugsverdacht"), ("threats", "Drohung"), ("hate_speech", "Hassrede"), ("sexual_content", "Sexueller Inhalt"), ("spoilers", "Spoiler"), ("topic_filter", "Themenfilter"), ("foreign_language", "Sprachfilter")):
        cfg = advanced.get(key, {})
        if not cfg.get("enabled"):
            continue
        matched = contains_term(text, list(cfg.get("terms", [])))
        if matched and (not is_trusted or key in {"threats", "hate_speech", "sexual_content"}):
            add_hit(hits, key, f"{label}: {matched}", str(cfg.get("action", "flag")))

    cfg = advanced.get("contact_data", {})
    contact_match = re.search(r"\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b|discord(?:\.gg|\.com/invite)/\S+|(?:t\.me|wa\.me)/\S+", text, re.I)
    if cfg.get("enabled") and contact_match and not is_trusted:
        add_hit(hits, "contact_data", "Kontaktdaten oder Einladungslink erkannt", str(cfg.get("action", "flag")))

    cfg = advanced.get("private_data", {})
    phone_match = re.search(r"(?<!\d)(?:\+?\d[\s()./-]*){9,15}(?!\d)", text)
    if cfg.get("enabled") and phone_match:
        add_hit(hits, "private_data", "Mögliche Telefonnummer erkannt", str(cfg.get("action", "delete")))

    cfg = advanced.get("mentions", {})
    mention_count = len(re.findall(r"(?<!\w)@[\w.-]+", text))
    if cfg.get("enabled") and mention_count >= int(cfg.get("count", 4)) and not is_trusted:
        add_hit(hits, "mentions", f"Zu viele Erwähnungen: {mention_count}", str(cfg.get("action", "timeout_300")))

    cfg = advanced.get("long_message", {})
    if cfg.get("enabled") and len(text) > int(cfg.get("max_characters", 500)) and not is_trusted:
        add_hit(hits, "long_message", f"Sehr lange Nachricht: {len(text)} Zeichen", str(cfg.get("action", "flag")))

    cfg = advanced.get("multiline", {})
    line_count = len(text.splitlines())
    if cfg.get("enabled") and line_count > int(cfg.get("max_lines", 5)) and not is_trusted:
        add_hit(hits, "multiline", f"Mehrzeiliger Zeichenspam: {line_count} Zeilen", str(cfg.get("action", "flag")))

    cfg = advanced.get("near_duplicate", {})
    if cfg.get("enabled") and normalized and not is_trusted:
        ratio_limit = float(cfg.get("ratio", 0.9))
        for ts, previous in history:
            if now - ts <= 90 and previous != normalized and SequenceMatcher(None, previous, normalized).ratio() >= ratio_limit:
                add_hit(hits, "near_duplicate", "Fast identische Nachricht wiederholt", str(cfg.get("action", "flag")))
                break

    evasion_text = normalized_for_evasion(text)
    insult_terms = list(rules.get("insults", {}).get("terms", []))
    for term in insult_terms:
        normalized_term = normalized_for_evasion(str(term))
        if len(normalized_term) >= 4 and normalized_term in evasion_text and str(term).casefold() not in text.casefold():
            add_hit(hits, "insult_evasion", f"Umgangene Beleidigung erkannt: {term}", str(rules.get("insults", {}).get("action", "timeout_600")))
            break

    if hits:
        flagged_timestamps.append(now)
        points = 3 if any(hit.get("rule") in {"threats", "hate_speech", "private_data"} for hit in hits) else 1
        repeat = advanced.get("repeat_offender", {})
        if repeat.get("enabled") and author_channel_id and not is_trusted:
            expiry = float(repeat.get("expiry_seconds", 21600))
            events = offense_history[author_channel_id]
            while events and now - events[0][0] > expiry:
                events.popleft()
            events.append((now, points))
            steps = list(repeat.get("steps", ["flag", "timeout_300", "timeout_1800", "block"]))
            action = str(steps[min(len(events) - 1, len(steps) - 1)]) if steps else "flag"
            if len(events) > 1:
                add_hit(hits, "repeat_offender", f"Wiederholungstäter: Verstoß {len(events)}, Punkte {sum(value for _, value in events)}", action)

        wave = advanced.get("spam_wave", {})
        if wave.get("enabled"):
            wave_window = float(wave.get("window_seconds", 30))
            recent_flags = sum(1 for timestamp in flagged_timestamps if now - timestamp <= wave_window)
            if recent_flags >= int(wave.get("count", 10)) and not is_trusted:
                spam_wave_active = True
                add_hit(hits, "spam_wave", f"Spamwelle erkannt: {recent_flags} Treffer", str(wave.get("action", "timeout_1800")))
            elif recent_flags < max(2, int(wave.get("count", 10)) // 2):
                spam_wave_active = False

    delete_required = delete_required or any(str(hit.get("action")) == "delete" for hit in hits)

    history.append((now, normalized))
    actions = [str(hit.get("action", "flag")) for hit in hits]
    ban_action = ""
    if "block" in actions:
        ban_action = "block"
    else:
        timeout_actions = []
        for action in actions:
            if action.startswith("timeout_"):
                try:
                    timeout_actions.append((int(action.split("_", 1)[1]), action))
                except (TypeError, ValueError):
                    pass
        if timeout_actions:
            ban_action = max(timeout_actions)[1]
    return hits, delete_required, ban_action


def message_text(snippet: dict[str, Any]) -> str:
    details = snippet.get("textMessageDetails", {})
    return str(details.get("messageText") or snippet.get("displayMessage", ""))


def append_jsonl(path: Path, row: dict[str, Any]) -> None:
    with path.open("a", encoding="utf-8") as file:
        file.write(json.dumps(row, ensure_ascii=False) + "\n")


def delete_message(youtube, message_id: str) -> tuple[bool, str]:
    global api_call_count
    api_call_count += 1
    try:
        youtube.liveChatMessages().delete(id=message_id).execute()
        return True, ""
    except HttpError as exc:
        status = getattr(exc.resp, "status", "unbekannt")
        return False, f"YouTube API HTTP {status}: {exc}"
    except Exception as exc:
        return False, str(exc)


def ban_user(
    youtube, live_chat_id: str, author_channel_id: str, action: str
) -> tuple[bool, str, str, int]:
    global api_call_count
    api_call_count += 1
    ban_type = "permanent" if action == "block" else "temporary"
    duration = 0
    snippet: dict[str, Any] = {
        "liveChatId": live_chat_id,
        "type": ban_type,
        "bannedUserDetails": {"channelId": author_channel_id},
    }
    if ban_type == "temporary":
        try:
            duration = int(action.split("_", 1)[1])
        except (IndexError, ValueError):
            duration = 300
        snippet["banDurationSeconds"] = duration
    try:
        response = youtube.liveChatBans().insert(
            part="snippet", body={"snippet": snippet}
        ).execute()
        return True, str(response.get("id", "")), "", duration
    except HttpError as exc:
        status = getattr(exc.resp, "status", "unbekannt")
        return False, "", f"YouTube API HTTP {status}: {exc}", duration
    except Exception as exc:
        return False, "", str(exc), duration


def process_moderation_command(youtube, live_chat_id: str) -> None:
    if not MOD_COMMAND_FILE.exists():
        return
    command_id = ""
    try:
        command = json.loads(MOD_COMMAND_FILE.read_text(encoding="utf-8-sig"))
        command_id = str(command.get("id", ""))
        action = str(command.get("action", ""))
        message_id = str(command.get("messageId", ""))
        author_channel_id = str(command.get("authorChannelId", ""))
        if PAUSE_FILE.exists():
            raise RuntimeError("Not-Aus ist aktiv. Manuelle Aktion wurde nicht ausgeführt.")
        if action == "delete":
            if not message_id:
                raise ValueError("Nachrichten-ID fehlt.")
            ok, error = delete_message(youtube, message_id)
            result = {"id": command_id, "ok": ok, "action": action, "error": error}
        elif action == "block" or action.startswith("timeout_"):
            if not author_channel_id:
                raise ValueError("Nutzer-Kanal-ID fehlt.")
            ok, ban_id, error, duration = ban_user(youtube, live_chat_id, author_channel_id, action)
            result = {"id": command_id, "ok": ok, "action": action, "banId": ban_id, "duration": duration, "error": error}
        else:
            raise ValueError(f"Unbekannte Aktion: {action}")
    except Exception as exc:
        result = {"id": command_id, "ok": False, "error": str(exc)}
    MOD_RESULT_FILE.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    MOD_COMMAND_FILE.unlink(missing_ok=True)


def write_end_report(stream: dict[str, str], all_log: Path, flagged_log: Path) -> None:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    users: dict[str, int] = defaultdict(int)
    rules_count: dict[str, int] = defaultdict(int)
    total = deleted = banned = 0
    if all_log.exists():
        for line in all_log.read_text(encoding="utf-8").splitlines():
            try:
                row = json.loads(line)
            except Exception:
                continue
            total += 1
            users[str(row.get("authorName", "Unbekannt"))] += 1
            deleted += int(bool(row.get("deleted")))
            banned += int(bool(row.get("banned")))
            for hit in row.get("ruleHits", []):
                rules_count[str(hit.get("rule", "Andere"))] += 1
    report = {
        "createdAt": utc_now(), "videoId": stream.get("videoId"), "title": stream.get("title"),
        "url": stream.get("url"), "messages": total, "ruleHits": sum(rules_count.values()),
        "deleted": deleted, "banned": banned,
        "topUsers": sorted(users.items(), key=lambda item: item[1], reverse=True)[:15],
        "topRules": sorted(rules_count.items(), key=lambda item: item[1], reverse=True)[:15],
    }
    stem = all_log.name.replace("-all_messages.jsonl", "-abschlussbericht")
    (REPORT_DIR / f"{stem}.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    try:
        import sys
        bundled = Path(__file__).resolve().parent / "lib" / "manual_pdf"
        if bundled.exists():
            sys.path.insert(0, str(bundled))
        from reportlab.lib.pagesizes import A4
        from reportlab.pdfgen import canvas
        pdf = canvas.Canvas(str(REPORT_DIR / f"{stem}.pdf"), pagesize=A4)
        width, height = A4
        pdf.setFillColorRGB(0.03, 0.16, 0.27); pdf.rect(0, height-110, width, 110, fill=1, stroke=0)
        pdf.setFillColorRGB(1,1,1); pdf.setFont("Helvetica-Bold", 20); pdf.drawString(45, height-55, "Chatwächter · Stream-Abschlussbericht")
        pdf.setFont("Helvetica", 10); pdf.drawString(45, height-78, str(stream.get("title", "Livestream"))[:85])
        y = height-145; pdf.setFillColorRGB(0.08,0.16,0.24); pdf.setFont("Helvetica-Bold", 12)
        for label, value in (("Nachrichten", total), ("Regel-Treffer", sum(rules_count.values())), ("Gelöscht", deleted), ("Sperren", banned)):
            pdf.drawString(45, y, f"{label}: {value}"); y -= 22
        y -= 10; pdf.drawString(45, y, "Häufigste Regeln"); y -= 18; pdf.setFont("Helvetica", 9)
        for name, count in report["topRules"][:10]: pdf.drawString(55, y, f"{name}: {count}"); y -= 15
        y -= 8; pdf.setFont("Helvetica-Bold", 12); pdf.drawString(45, y, "Aktivste Nutzer"); y -= 18; pdf.setFont("Helvetica", 9)
        for name, count in report["topUsers"][:10]: pdf.drawString(55, y, f"{name[:55]}: {count}"); y -= 15
        pdf.save()
    except Exception as exc:
        report["pdfError"] = str(exc)
        (REPORT_DIR / f"{stem}.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")


def log_messages(
    youtube, live_chat_id: str, items, all_log: Path, flagged_log: Path, rules
) -> int:
    written = 0
    moderation_paused = PAUSE_FILE.exists()

    for item in items:
        message_id = item.get("id")
        if not message_id or message_id in seen_message_ids:
            continue
        seen_message_ids.add(message_id)

        snippet = item.get("snippet", {})
        author = item.get("authorDetails", {})
        text = message_text(snippet)
        if not text.strip():
            continue

        is_owner = bool(author.get("isChatOwner"))
        is_moderator = bool(author.get("isChatModerator"))
        is_sponsor = bool(author.get("isChatSponsor"))
        author_channel_id = str(author.get("channelId", ""))

        exempt = (
            (is_owner and bool(rules.get("exempt_owner", True)))
            or (is_moderator and bool(rules.get("exempt_moderators", True)))
        )

        hits, delete_required, ban_action = rule_hits(
            author_channel_id, text, exempt=exempt, rules=rules
        )

        deleted = False
        delete_error = ""
        deleted_at = ""
        ban_requested = bool(ban_action)
        banned = False
        ban_id = ""
        ban_error = ""
        ban_duration_seconds = 0
        ban_type = "permanent" if ban_action == "block" else ("temporary" if ban_action else "")

        # Die Nachricht wird vor dem lokalen Schreiben geprüft, aber das Ergebnis
        # wird in jedem Fall vollständig lokal protokolliert.
        if delete_required and not moderation_paused:
            deleted, delete_error = delete_message(youtube, message_id)
            if deleted:
                deleted_at = utc_now()

        if ban_requested and not moderation_paused:
            banned, ban_id, ban_error, ban_duration_seconds = ban_user(
                youtube, live_chat_id, author_channel_id, ban_action
            )

        row = {
            "messageId": message_id,
            "publishedAt": snippet.get("publishedAt"),
            "receivedAt": utc_now(),
            "authorName": author.get("displayName", ""),
            "authorChannelId": author_channel_id,
            "profileImageUrl": author.get("profileImageUrl", ""),
            "text": text,
            "isOwner": is_owner,
            "isModerator": is_moderator,
            "isSponsor": is_sponsor,
            "role": role_from_author(author),
            "flagged": bool(hits),
            "ruleHits": hits,
            "deleteRequested": delete_required,
            "deleted": deleted,
            "deletedAt": deleted_at,
            "deleteError": delete_error,
            "banRequested": ban_requested,
            "banAction": ban_action,
            "banType": ban_type,
            "banDurationSeconds": ban_duration_seconds,
            "banned": banned,
            "banId": ban_id,
            "banError": ban_error,
            "moderationPaused": moderation_paused,
            "actionText": (
                ("NUTZER DAUERHAFT BLOCKIERT" if ban_type == "permanent" else f"NUTZER {ban_duration_seconds} SEKUNDEN STUMM")
                if banned
                else ("SPERRE FEHLGESCHLAGEN" if ban_requested else ("BEI YOUTUBE GELÖSCHT" if deleted else ("LÖSCHEN FEHLGESCHLAGEN" if delete_required else "")))
            ),
        }

        if moderation_paused and (delete_required or ban_requested):
            row["actionText"] = "AKTION DURCH NOT-AUS ANGEHALTEN"

        append_jsonl(all_log, row)
        if hits:
            append_jsonl(flagged_log, row)
        written += 1

    return written


def monitor_live_chat(youtube, stream: dict[str, str]) -> None:
    global api_call_count
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    rules = load_rules()
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    all_log = LOG_DIR / f"{stamp}-{stream['videoId']}-all_messages.jsonl"
    flagged_log = LOG_DIR / f"{stamp}-{stream['videoId']}-flagged_messages.jsonl"

    page_token = None
    total = 0
    deleted_total = 0

    def process_chat_send_request() -> None:
        global api_call_count
        if not CHAT_SEND_REQUEST_FILE.exists():
            return
        request_id = ""
        try:
            request = json.loads(CHAT_SEND_REQUEST_FILE.read_text(encoding="utf-8-sig"))
            request_id = str(request.get("id", ""))
            message = str(request.get("message", "")).strip()
            if not message:
                raise ValueError("Die Nachricht ist leer.")
            if len(message) > 200:
                raise ValueError("YouTube erlaubt höchstens 200 Zeichen pro Chatnachricht.")
            youtube.liveChatMessages().insert(
                part="snippet",
                body={
                    "snippet": {
                        "liveChatId": stream["liveChatId"],
                        "type": "textMessageEvent",
                        "textMessageDetails": {"messageText": message},
                    }
                },
            ).execute()
            api_call_count += 1
            result = {"id": request_id, "ok": True, "message": "Nachricht gesendet."}
        except Exception as error:
            result = {"id": request_id, "ok": False, "message": str(error)}
        CHAT_SEND_RESULT_FILE.write_text(
            json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        CHAT_SEND_REQUEST_FILE.unlink(missing_ok=True)

    while True:
        process_chat_send_request()
        process_moderation_command(youtube, stream["liveChatId"])
        write_status(
            "connected",
            title=stream["title"],
            videoId=stream["videoId"],
            liveChatId=stream["liveChatId"],
            url=stream["url"],
            allLog=str(all_log),
            flaggedLog=str(flagged_log),
            messageCount=total,
            deletedCount=deleted_total,
            moderationMode="active",
            moderationPaused=PAUSE_FILE.exists(),
            spamWaveActive=spam_wave_active,
            apiCalls=api_call_count,
            watcherHeartbeat=utc_now(),
        )

        try:
            api_call_count += 1
            response = youtube.liveChatMessages().list(
                liveChatId=stream["liveChatId"],
                part="id,snippet,authorDetails",
                maxResults=200,
                pageToken=page_token,
            ).execute()
        except HttpError as error:
            status = getattr(error.resp, "status", None)
            if status in {403, 404}:
                write_status(
                    "stream_ended",
                    title=stream["title"],
                    videoId=stream["videoId"],
                    url=stream["url"],
                    messageCount=total,
                    deletedCount=deleted_total,
                    allLog=str(all_log),
                    flaggedLog=str(flagged_log),
                )
                write_end_report(stream, all_log, flagged_log)
                return
            raise

        # Änderungen aus dem Control Center ohne Neustart übernehmen.
        rules = load_rules()
        before = total
        total += log_messages(
            youtube, stream["liveChatId"], response.get("items", []), all_log, flagged_log, rules
        )

        # Gelöschte Zahl aus den neu geschriebenen Datensätzen ableiten.
        if total > before and all_log.exists():
            try:
                recent_lines = all_log.read_text(encoding="utf-8").splitlines()[-(total-before):]
                deleted_total += sum(
                    1 for line in recent_lines if json.loads(line).get("deleted")
                )
            except Exception:
                pass

        page_token = response.get("nextPageToken")
        interval_ms = int(response.get("pollingIntervalMillis", 5000))
        time.sleep(max(interval_ms / 1000.0, 1.0))


def main() -> int:
    BASE.mkdir(parents=True, exist_ok=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    PID_FILE.write_text(str(os.getpid()), encoding="ascii")

    try:
        write_status("starting", moderationMode="active")
        youtube = youtube_client()
        channel_id, uploads_id = resolve_channel_and_uploads(youtube)

        while True:
            try:
                write_status(
                    "waiting",
                    channelId=channel_id,
                    uploadsPlaylistId=uploads_id,
                    message="Warte auf Livestream",
                    videoId="",
                    liveChatId="",
                    url="",
                    title="",
                    allLog="",
                    flaggedLog="",
                    messageCount=0,
                    deletedCount=0,
                    moderationMode="active",
                    moderationPaused=PAUSE_FILE.exists(),
                    spamWaveActive=spam_wave_active,
                    apiCalls=api_call_count,
                    watcherHeartbeat=utc_now(),
                )

                stream = find_active_stream(youtube, uploads_id)
                if stream:
                    monitor_live_chat(youtube, stream)
                    youtube = youtube_client()

                # Normalerweise alle 45 Sekunden suchen. Das Control Center kann
                # diese Wartezeit über eine kleine Signaldatei sofort abbrechen.
                wait_started = time.monotonic()
                while time.monotonic() - wait_started < CHECK_INTERVAL_SECONDS:
                    if MANUAL_SEARCH_FILE.exists():
                        MANUAL_SEARCH_FILE.unlink(missing_ok=True)
                        break
                    time.sleep(0.5)

            except HttpError as error:
                status = getattr(error.resp, "status", None)
                write_status(
                    "api_error",
                    error=f"YouTube API HTTP {status}: {error}",
                    moderationMode="active",
                )
                time.sleep(120)

            except Exception as error:
                write_status(
                    "error",
                    error=str(error),
                    traceback=traceback.format_exc(),
                    moderationMode="active",
                )
                time.sleep(60)
    finally:
        PID_FILE.unlink(missing_ok=True)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
