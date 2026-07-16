$ErrorActionPreference = 'Stop'

$appFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$starter = Join-Path $appFolder 'CHATWAECHTER_EXAKT_40_STARTEN.vbs'
if (-not (Test-Path -LiteralPath $starter)) {
    throw "Startdatei nicht gefunden: $starter"
}

$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop 'Chatwaechter.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "$env:SystemRoot\System32\wscript.exe"
$shortcut.Arguments = '"' + $starter + '"'
$shortcut.WorkingDirectory = $appFolder
$shortcut.Description = 'Chatwaechter Control Center starten'
$shortcut.IconLocation = "$env:SystemRoot\System32\imageres.dll,77"
$shortcut.Save()

Write-Host ''
Write-Host 'Fertig: Das Desktop-Symbol Chatwaechter wurde erstellt.' -ForegroundColor Green
Write-Host 'Ab jetzt startet ein Doppelklick das gesamte Control Center.'
Read-Host 'Zum Schliessen Enter druecken'
