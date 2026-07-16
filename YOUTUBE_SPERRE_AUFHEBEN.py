#!/usr/bin/env python3
# -*- coding: utf-8 -*-
from __future__ import annotations

import sys
from pathlib import Path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

SCOPES = [
    "https://www.googleapis.com/auth/youtube.force-ssl",
    "https://www.googleapis.com/auth/youtube.readonly",
]


def main() -> int:
    if len(sys.argv) != 2 or not sys.argv[1].strip():
        print("Sperr-ID fehlt.", file=sys.stderr)
        return 2
    folder = Path(__file__).resolve().parent
    token_file = folder / "data" / "token.json"
    credentials = Credentials.from_authorized_user_file(str(token_file), SCOPES)
    if credentials.expired and credentials.refresh_token:
        credentials.refresh(Request())
        token_file.write_text(credentials.to_json(), encoding="utf-8")
    if not credentials.valid:
        raise RuntimeError("OAuth-Token ist ungültig.")
    youtube = build("youtube", "v3", credentials=credentials, cache_discovery=False)
    youtube.liveChatBans().delete(id=sys.argv[1].strip()).execute()
    print("Sperre erfolgreich aufgehoben.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
