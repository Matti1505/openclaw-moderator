CHATWÄCHTER CONTROL CENTER – GEORDNETE REGELVERWALTUNG

Neu:
- Schaltfläche „Beleidigungen bearbeiten“
- eigene Speichern-Schaltfläche im Beleidigungseditor
- Schaltfläche „Emoji-Regel bearbeiten“
- Emoji-Grenzwert, Aktivierung und Aktion separat speicherbar
- Schaltfläche „Großschreibung bearbeiten“
- Mindestbuchstaben, Prozentwert und Aktion separat speicherbar
- Schaltfläche „Regel hinzufügen“
- eigene Regeln mit Name, Begriffsliste und Aktion anlegbar
- alle Änderungen werden in rules.json gespeichert und nach WSL übertragen
- Emoji-Regel und eigene Regeln werden vom Python-Wächter tatsächlich ausgewertet
- PDF-Export bleibt auf maximal 40 Nachrichten je Seite begrenzt

Start:
CHATWAECHTER_EXAKT_40_STARTEN.vbs

WINDOWS-VORAUSSETZUNGEN:
- Python 3 installieren und beim Setup "Add python.exe to PATH" aktivieren
- danach in einer Eingabeaufforderung ausführen:
  python -m pip install google-api-python-client google-auth google-auth-oauthlib
- den YouTube-OAuth-Token als data\token.json ablegen

Diagnose bei Problemen:
CHATWAECHTER_CONTROL_CENTER_DIAGNOSE.cmd

Status, Regeln und Protokolle liegen lokal im Unterordner data.
WSL wird nicht mehr benötigt.
