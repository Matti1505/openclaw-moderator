Add-Type -AssemblyName System.Windows.Forms
$ErrorActionPreference = "Stop"

$folder = Split-Path -Parent $MyInvocation.MyCommand.Path
$mainScript = Join-Path $folder "CHATWAECHTER_CONTROL_CENTER_GEORDNETE_REGELN.ps1"
$logFile = Join-Path $folder "CHATWAECHTER_STARTFEHLER.txt"

try {
    if (-not (Test-Path -LiteralPath $mainScript)) {
        throw "Die Datei CHATWAECHTER_CONTROL_CENTER_GEORDNETE_REGELN.ps1 fehlt."
    }

    & $mainScript
}
catch {
    $details = @(
        "Zeit: " + (Get-Date).ToString("dd.MM.yyyy HH:mm:ss")
        "Fehler: " + $_.Exception.Message
        "Datei: " + $_.InvocationInfo.ScriptName
        "Zeile: " + $_.InvocationInfo.ScriptLineNumber
        ""
        $_.ScriptStackTrace
    ) -join [Environment]::NewLine

    $details | Set-Content -LiteralPath $logFile -Encoding UTF8

    [System.Windows.Forms.MessageBox]::Show(
        "Das Dashboard konnte nicht gestartet werden.`n`n" +
        $_.Exception.Message +
        "`n`nEin Fehlerprotokoll wurde gespeichert:`n" + $logFile,
        "Chatwächter – Startfehler",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}
