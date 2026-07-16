@echo off
chcp 65001 >nul
title Chatwaechter Control Center Diagnose
echo Chatwaechter Windows-Diagnose
echo Ordner: %~dp0
echo.
where python.exe >nul 2>&1 && (python.exe --version) || (
  where py.exe >nul 2>&1 && (py.exe -3 --version) || echo FEHLER: Python 3 wurde nicht gefunden.
)
if exist "%~dp0data\token.json" (echo OK: data\token.json vorhanden.) else echo HINWEIS: data\token.json fehlt.
echo.
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0CHATWAECHTER_CONTROL_CENTER_LAUNCHER.ps1"
echo.
echo Falls ein Fehler auftrat, steht er auch in CHATWAECHTER_STARTFEHLER.txt
pause
