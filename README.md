# Chatwächter

Windows-Anwendung zur Überwachung und Moderation von YouTube-Livechats.

## Installation

1. Python 3 installieren.
2. `python -m pip install -r requirements.txt` ausführen.
3. In Google Cloud einen OAuth-Client vom Typ **Desktop-App** anlegen und die heruntergeladene Datei `client_secret*.json` im Download-Ordner belassen.
4. `YOUTUBE_TOKEN_ERSTELLEN.cmd` ausführen.
5. `CHATWAECHTER_EXAKT_40_STARTEN.vbs` starten.

## Sicherheit

`token.json`, `client_secret*.json`, Chatprotokolle, Sicherungen und Laufzeitdaten dürfen niemals in ein öffentliches Repository hochgeladen werden. Die mitgelieferte `.gitignore` schließt diese Dateien aus.

## Regeln

Die Standardregeln stehen in `rules.json`. Vor einer automatischen Moderation sollten alle Regeln und Aktionen geprüft werden.
