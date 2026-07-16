@echo off
chcp 65001 >nul
title YouTube-Token für Chatwächter erstellen
cd /d "%~dp0"
echo YouTube-Token für den Chatwächter
echo ==================================
echo.
python "%~dp0YOUTUBE_TOKEN_ERSTELLEN.py"
echo.
if errorlevel 1 (
  echo Die Anmeldung ist fehlgeschlagen. Bitte die Fehlermeldung oben prüfen.
) else (
  echo Der Token wurde erfolgreich erstellt.
)
echo.
pause
