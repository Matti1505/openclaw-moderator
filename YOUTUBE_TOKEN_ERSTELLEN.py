#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Einmalige Google-Anmeldung für den Chatwächter."""

from __future__ import annotations

import json
import sys
from pathlib import Path

from google_auth_oauthlib.flow import InstalledAppFlow


SCOPES = [
    "https://www.googleapis.com/auth/youtube.force-ssl",
    "https://www.googleapis.com/auth/youtube.readonly",
]

FOLDER = Path(__file__).resolve().parent
DATA_DIR = FOLDER / "data"
TOKEN_FILE = DATA_DIR / "token.json"
DOWNLOADS = Path.home() / "Downloads"


def find_client_file() -> Path:
    candidates = sorted(DOWNLOADS.glob("client_secret*.json"))
    for candidate in candidates:
        if not candidate.is_file():
            continue
        try:
            payload = json.loads(candidate.read_text(encoding="utf-8"))
            if "installed" in payload:
                return candidate
        except (OSError, ValueError):
            continue
    raise FileNotFoundError(
        "Keine OAuth-Clientdatei vom Typ Desktop-App im Downloads-Ordner gefunden."
    )


def main() -> int:
    try:
        client_file = find_client_file()
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        print(f"OAuth-Client: {client_file}")
        print("Der Browser wird für die Google-Anmeldung geöffnet.")
        print("Bitte das Konto des YouTube-Kanals auswählen und den Zugriff erlauben.\n")

        flow = InstalledAppFlow.from_client_secrets_file(str(client_file), SCOPES)
        credentials = flow.run_local_server(
            host="localhost",
            port=0,
            authorization_prompt_message="Browser wird geöffnet: {url}",
            success_message="Anmeldung erfolgreich. Dieses Browserfenster kann geschlossen werden.",
            open_browser=True,
            access_type="offline",
            prompt="consent",
        )
        TOKEN_FILE.write_text(credentials.to_json(), encoding="utf-8")
        print(f"\nFERTIG: Token gespeichert unter:\n{TOKEN_FILE}")
        return 0
    except Exception as error:
        print(f"\nFEHLER: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
