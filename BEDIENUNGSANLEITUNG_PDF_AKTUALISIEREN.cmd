@echo off
setlocal
set "ROOT=%~dp0"
set "PYTHON=python"
set "PDFLIB=%ROOT%lib\manual_pdf"
set "PYTHONPATH=%PDFLIB%"
"%PYTHON%" -c "import reportlab" >nul 2>&1
if errorlevel 1 (
  echo Der PDF-Baustein wird einmalig installiert ...
  "%PYTHON%" -m pip install --disable-pip-version-check --target "%PDFLIB%" reportlab
  if errorlevel 1 (
    echo Installation fehlgeschlagen.
    pause
    exit /b 1
  )
)
"%PYTHON%" "%ROOT%BEDIENUNGSANLEITUNG_PDF_ERSTELLEN.py"
if errorlevel 1 (
  echo Die PDF konnte nicht erstellt werden.
  pause
  exit /b 1
)
echo.
echo FERTIG: %ROOT%CHATWAECHTER_BEDIENUNGSANLEITUNG.pdf
pause
