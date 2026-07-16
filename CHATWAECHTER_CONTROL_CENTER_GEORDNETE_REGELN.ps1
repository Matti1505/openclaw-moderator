
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms.DataVisualization

[System.Windows.Forms.Application]::EnableVisualStyles()

$ErrorActionPreference = "Stop"
$script:Folder = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:BaseWindows = Join-Path $script:Folder "data"
$script:LogDirWindows = Join-Path $script:BaseWindows "logs"
$script:StatusWindows = Join-Path $script:BaseWindows "auto_live_status.json"
$script:PidWindows = Join-Path $script:BaseWindows "auto_live_watcher.pid"
$script:ChatSendRequestWindows = Join-Path $script:BaseWindows "chat_send_request.json"
$script:ChatSendResultWindows = Join-Path $script:BaseWindows "chat_send_result.json"
$script:ManualSearchWindows = Join-Path $script:BaseWindows "manual_live_search.request"
$script:PauseWindows = Join-Path $script:BaseWindows "moderation_paused.flag"
$script:ModCommandWindows = Join-Path $script:BaseWindows "moderation_command.json"
$script:ModResultWindows = Join-Path $script:BaseWindows "moderation_command_result.json"
$script:NotesWindows = Join-Path $script:BaseWindows "user_notes.json"
$script:ReportsWindows = Join-Path $script:BaseWindows "reports"
$script:BackupsWindows = Join-Path $script:BaseWindows "backups"
$script:Distro = "OpenClawGateway"
$script:BaseLinux = "/home/openclaw/.openclaw/youtube"
$script:LogDirLinux = "$script:BaseLinux/logs"
$script:StatusLinux = "$script:BaseLinux/auto_live_status.json"
$script:CurrentMode = "all"
$script:CurrentRows = @()
$script:AllRows = @()
$script:FlaggedRows = @()
$script:HistoryFiles = @()
$script:SelectedHistory = $null
$script:RefreshSeconds = 2
$script:SearchIntervalSeconds = 45
$script:SearchCountdownSeconds = 45
$script:SearchProgress = 0.0
$script:ManualSearchRequestedAt = $null
$script:LastStatusState = ""
$script:WebView2Available = $false
$script:PlayerVideoId = ""
$webView2Folder = Join-Path $script:Folder "lib\webview2"
try {
    if (Test-Path -LiteralPath $webView2Folder) {
        $env:PATH = $webView2Folder + ";" + $env:PATH
        Add-Type -Path (Join-Path $webView2Folder "Microsoft.Web.WebView2.Core.dll")
        Add-Type -Path (Join-Path $webView2Folder "Microsoft.Web.WebView2.WinForms.dll")
        $script:WebView2Available = $true
    }
} catch {
    $script:WebView2Available = $false
}

# ---------- Farben ----------
$Colors = @{
    Window      = [System.Drawing.Color]::FromArgb(2, 10, 24)
    Sidebar     = [System.Drawing.Color]::FromArgb(3, 13, 29)
    Surface     = [System.Drawing.Color]::FromArgb(5, 20, 43)
    Surface2    = [System.Drawing.Color]::FromArgb(7, 28, 58)
    Surface3    = [System.Drawing.Color]::FromArgb(9, 38, 78)
    Border      = [System.Drawing.Color]::FromArgb(24, 79, 132)
    BorderSoft  = [System.Drawing.Color]::FromArgb(13, 51, 91)
    Cyan        = [System.Drawing.Color]::FromArgb(0, 174, 255)
    Cyan2       = [System.Drawing.Color]::FromArgb(28, 211, 255)
    Blue        = [System.Drawing.Color]::FromArgb(18, 119, 255)
    Red         = [System.Drawing.Color]::FromArgb(255, 45, 75)
    Orange      = [System.Drawing.Color]::FromArgb(255, 151, 31)
    Green       = [System.Drawing.Color]::FromArgb(87, 222, 74)
    Yellow      = [System.Drawing.Color]::FromArgb(255, 190, 0)
    Text        = [System.Drawing.Color]::FromArgb(231, 243, 255)
    Muted       = [System.Drawing.Color]::FromArgb(142, 171, 205)
    Dim         = [System.Drawing.Color]::FromArgb(82, 111, 147)
    Black       = [System.Drawing.Color]::FromArgb(1, 7, 16)
}

function New-Font([single]$Size, [System.Drawing.FontStyle]$Style = [System.Drawing.FontStyle]::Regular) {
    return New-Object System.Drawing.Font("Segoe UI", $Size, $Style)
}

function Assert-Control {
    param(
        $Control,
        [string]$Name
    )

    if ($null -eq $Control) {
        throw "$Name ist NULL."
    }

    if (-not ($Control -is [System.Windows.Forms.Control])) {
        $typeName = if ($null -ne $Control) {
            $Control.GetType().FullName
        } else {
            "NULL"
        }

        throw "$Name ist kein Windows-Forms-Steuerelement, sondern: $typeName"
    }

    return $Control
}

function New-Panel {
    param(
        [System.Drawing.Color]$BackColor = $Colors.Surface,
        [string]$Dock = "None"
    )
    $p = New-Object System.Windows.Forms.Panel
    $p.BackColor = $BackColor
    $p.Dock = $Dock
    return $p
}

function Set-CardBorder {
    param(
        [System.Windows.Forms.Control]$Control,
        [System.Drawing.Color]$Color = $Colors.Border,
        [int]$Thickness = 1
    )

    if ($null -eq $Control) {
        return
    }

    if ($Control -is [System.Windows.Forms.Panel]) {
        $Control.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    }
}

function New-Label {
    param(
        [string]$Text = "",
        [single]$Size = 10,
        [System.Drawing.Color]$Color = $Colors.Text,
        [System.Drawing.FontStyle]$Style = [System.Drawing.FontStyle]::Regular,
        [string]$Dock = "None",
        [System.Drawing.ContentAlignment]$Align = [System.Drawing.ContentAlignment]::MiddleLeft
    )
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text
    $l.ForeColor = $Color
    $l.BackColor = [System.Drawing.Color]::Transparent
    $l.Font = New-Font $Size $Style
    $l.Dock = $Dock
    $l.TextAlign = $Align
    return $l
}

function New-Button {
    param(
        [string]$Text,
        [System.Drawing.Color]$BackColor = $Colors.Surface2,
        [System.Drawing.Color]$ForeColor = $Colors.Text,
        [int]$Width = 120,
        [int]$Height = 36
    )
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Width = $Width
    $b.Height = $Height
    $b.FlatStyle = "Flat"
    $b.FlatAppearance.BorderSize = 1
    $b.FlatAppearance.BorderColor = $Colors.Border
    $b.BackColor = $BackColor
    $b.ForeColor = $ForeColor
    $b.Font = New-Font 9 ([System.Drawing.FontStyle]::Bold)
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $b
}

$script:EmojiDisplayFont = New-Object System.Drawing.Font("Segoe UI Emoji",10,[System.Drawing.FontStyle]::Regular)

function Get-UnicodeCodePoints([string]$Text) {
    $points = New-Object System.Collections.Generic.List[int]
    if ([string]::IsNullOrEmpty($Text)) { return @() }
    for ($index=0; $index -lt $Text.Length; $index++) {
        try {
            $point = [char]::ConvertToUtf32($Text,$index)
            [void]$points.Add($point)
            if ([char]::IsHighSurrogate($Text[$index])) { $index++ }
        } catch { }
    }
    return @($points)
}

function Test-EmojiOnlyText([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    if (-not [string]::IsNullOrWhiteSpace(([regex]::Replace($Text,'[^\p{L}\p{N}]','')))) { return $false }
    foreach($point in @(Get-UnicodeCodePoints $Text)) {
        if(($point -ge 0x1F000 -and $point -le 0x1FAFF) -or ($point -ge 0x2600 -and $point -le 0x27FF)){ return $true }
    }
    return $false
}

function Get-EmojiDisplayColor([string]$Text) {
    $points = @(Get-UnicodeCodePoints $Text)
    if($points -contains 0x1F499){ return [System.Drawing.Color]::FromArgb(80,180,255) }
    foreach($point in $points){
        if($point -in @(0x1F622,0x1F625,0x1F626,0x1F627,0x1F62D)){ return [System.Drawing.Color]::FromArgb(90,195,255) }
    }
    foreach($point in $points){
        if($point -eq 0x2764 -or ($point -ge 0x1F493 -and $point -le 0x1F49F)){ return [System.Drawing.Color]::FromArgb(255,92,125) }
    }
    foreach($point in $points){
        if(($point -ge 0x1F600 -and $point -le 0x1F64F) -or ($point -ge 0x1F44A -and $point -le 0x1F450)){ return [System.Drawing.Color]::FromArgb(255,205,75) }
    }
    return [System.Drawing.Color]::FromArgb(40,215,235)
}

function Enable-EmojiColoring([System.Windows.Forms.DataGridView]$Grid) {
    if($null -eq $Grid){ return }
    $Grid.Add_CellFormatting({
        param($sender,$eventArgs)
        try {
            if($eventArgs.RowIndex -lt 0 -or $eventArgs.ColumnIndex -lt 0){ return }
            if([string]$sender.Columns[$eventArgs.ColumnIndex].Name -ne "Nachricht"){ return }
            $value = [string]$eventArgs.Value
            if(Test-EmojiOnlyText $value){
                $eventArgs.CellStyle.ForeColor = Get-EmojiDisplayColor $value
                $eventArgs.CellStyle.SelectionForeColor = $eventArgs.CellStyle.ForeColor
                $eventArgs.CellStyle.Font = $script:EmojiDisplayFont
            }
        } catch { }
    })
}

function New-NavButton {
    param([string]$Text, [bool]$Active = $false)
    $b = @(New-Button $Text ($(if($Active){$Colors.Surface3}else{$Colors.Sidebar})) ($(if($Active){$Colors.Cyan2}else{$Colors.Text})) 170 42)[-1]
    $b = Assert-Control $b "b"
    $b.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $b.Padding = [System.Windows.Forms.Padding]::new(14,0,0,0)
    $b.FlatAppearance.BorderColor = $(if($Active){$Colors.Cyan}else{$Colors.Sidebar})
    return $b
}

function Invoke-WslCommand {
    param(
        [string[]]$Arguments,
        [string]$InputText = ""
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "wsl.exe"
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $argList = @("-d", $script:Distro, "--") + $Arguments
    $psi.Arguments = ($argList | ForEach-Object {
        if ($_ -match '\s|["]') {
            '"' + ($_ -replace '"', '\"') + '"'
        } else {
            $_
        }
    }) -join " "

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    try {
        if (-not $process.Start()) {
            throw "wsl.exe konnte nicht gestartet werden."
        }

        if (-not [string]::IsNullOrEmpty($InputText)) {
            $process.StandardInput.Write($InputText)
        }
        $process.StandardInput.Close()

        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            StdOut   = $stdout.TrimEnd()
            StdErr   = $stderr.TrimEnd()
        }
    }
    finally {
        $process.Dispose()
    }
}

function Invoke-WslText {
    param([string]$Command)

    $result = Invoke-WslCommand @("bash", "-lc", $Command)
    if ($result.ExitCode -ne 0) {
        throw "WSL/Bash-Fehler (" + $result.ExitCode + "): " + $result.StdErr
    }
    return $result.StdOut
}

function ConvertTo-BashSingleQuoted {
    param([string]$Value)
    return "'" + ($Value -replace "'", "'\''") + "'"
}

function Find-WslPython {
    $candidates = @(
        "$script:BaseLinux/venv/bin/python",
        "$script:BaseLinux/venv/bin/python3",
        "/usr/bin/python3",
        "/usr/local/bin/python3",
        "/usr/bin/python"
    )

    foreach ($candidate in $candidates) {
        $check = Invoke-WslCommand @("test", "-x", $candidate)
        if ($check.ExitCode -eq 0) {
            return $candidate
        }
    }

    return ""
}

function Install-And-StartWatcher {
    try {
        $localWatcher = Join-Path $script:Folder "AUTO_LIVE_CHATWAECHTER.py"
        $localRules = Join-Path $script:Folder "rules.json"

        if (-not (Test-Path -LiteralPath $localWatcher)) {
            throw "AUTO_LIVE_CHATWAECHTER.py fehlt."
        }
        if (-not (Test-Path -LiteralPath $localRules)) {
            throw "rules.json fehlt."
        }

        $mkdir = Invoke-WslCommand @("mkdir", "-p", $script:BaseLinux, $script:LogDirLinux)
        if ($mkdir.ExitCode -ne 0) {
            throw "WSL-Ordner konnten nicht angelegt werden: " + $mkdir.StdErr
        }

        # Dateien bytegenau per Base64 übertragen.
        # Python in WSL dekodiert die ASCII-Daten direkt in Binärdateien.
        $watcherB64 = [Convert]::ToBase64String(
            [System.IO.File]::ReadAllBytes($localWatcher)
        )
        $writeWatcher = Invoke-WslCommand @(
            "python3",
            "-c",
            "import base64,sys;open(sys.argv[1],'wb').write(base64.b64decode(sys.stdin.read()))",
            "$script:BaseLinux/auto_live_chatwaechter.py"
        ) $watcherB64

        if ($writeWatcher.ExitCode -ne 0) {
            throw "AUTO_LIVE_CHATWAECHTER.py konnte nicht bytegenau nach WSL kopiert werden: " +
                $writeWatcher.StdErr
        }

        $rulesB64 = [Convert]::ToBase64String(
            [System.IO.File]::ReadAllBytes($localRules)
        )
        $writeRules = Invoke-WslCommand @(
            "python3",
            "-c",
            "import base64,sys;open(sys.argv[1],'wb').write(base64.b64decode(sys.stdin.read()))",
            "$script:BaseLinux/rules.json"
        ) $rulesB64

        if ($writeRules.ExitCode -ne 0) {
            throw "rules.json konnte nicht bytegenau nach WSL kopiert werden: " +
                $writeRules.StdErr
        }

        [void](Invoke-WslCommand @(
            "chmod",
            "700",
            "$script:BaseLinux/auto_live_chatwaechter.py"
        ))

        $running = Invoke-WslCommand @(
            "pgrep",
            "-f",
            "$script:BaseLinux/auto_live_chatwaechter.py"
        )

        if (
            $running.ExitCode -eq 0 -and
            -not [string]::IsNullOrWhiteSpace($running.StdOut)
        ) {
            return $true
        }

        $pythonPath = Find-WslPython
        if ([string]::IsNullOrWhiteSpace($pythonPath)) {
            throw (
                "Es wurde kein Python in WSL gefunden. Geprüft wurden:`n" +
                "$script:BaseLinux/venv/bin/python`n" +
                "$script:BaseLinux/venv/bin/python3`n" +
                "/usr/bin/python3`n/usr/local/bin/python3`n/usr/bin/python"
            )
        }

        # Direkter Start mit dem tatsächlich gefundenen Python.
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "wsl.exe"
        $psi.Arguments = (
            "-d " + $script:Distro +
            " -- " +
            $pythonPath + " " +
            "$script:BaseLinux/auto_live_chatwaechter.py"
        )
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true

        $watcherProcess = New-Object System.Diagnostics.Process
        $watcherProcess.StartInfo = $psi

        if (-not $watcherProcess.Start()) {
            throw "wsl.exe konnte den Hintergrundwächter nicht starten."
        }

        Start-Sleep -Seconds 2

        $processCheck = Invoke-WslCommand @(
            "pgrep",
            "-f",
            "$script:BaseLinux/auto_live_chatwaechter.py"
        )

        $statusCheck = Invoke-WslCommand @(
            "test",
            "-f",
            $script:StatusLinux
        )

        if (
            $processCheck.ExitCode -ne 0 -and
            $statusCheck.ExitCode -ne 0
        ) {
            $stderr = $watcherProcess.StandardError.ReadToEnd()
            $stdout = $watcherProcess.StandardOutput.ReadToEnd()
            $details = ($stderr + "`n" + $stdout).Trim()

            if ([string]::IsNullOrWhiteSpace($details)) {
                $details = "Keine zusätzliche Python-Ausgabe vorhanden."
            }

            throw (
                "Der Python-Wächter wurde nicht aktiv.`n`n" +
                "Verwendetes Python: " + $pythonPath + "`n`n" +
                $details
            )
        }

        return $true
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Der Hintergrundwächter konnte nicht gestartet werden:`n`n" +
            $_.Exception.Message,
            "Chatwächter",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return $false
    }
}

function Read-Status {
    try {
        $json = Invoke-WslText "test -f $script:StatusLinux && cat $script:StatusLinux || true"
        if ([string]::IsNullOrWhiteSpace($json)) { return $null }
        return $json | ConvertFrom-Json
    } catch { return $null }
}

function Read-JsonlLinux {
    param([string]$LinuxPath)
    if ([string]::IsNullOrWhiteSpace($LinuxPath)) { return @() }
    try {
        $q = ConvertTo-BashSingleQuoted $LinuxPath
        $text = Invoke-WslText "test -f $q && tail -n 5000 $q || true"
        if ([string]::IsNullOrWhiteSpace($text)) { return @() }
        $result = @()
        foreach ($line in ($text -split "`r?`n")) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try { $result += ($line | ConvertFrom-Json) } catch {}
        }
        return @($result)
    } catch { return @() }
}

function Get-RoleText($Row) {
    if ($Row.isOwner) { return "Kanalinhaber" }
    if ($Row.isModerator) { return "Moderator" }
    if ($Row.isSponsor) { return "Mitglied" }
    return "Zuschauer"
}

function Get-ReasonText($Row) {
    $parts = @()
    foreach ($hit in @($Row.ruleHits)) {
        if ($hit.reason) { $parts += [string]$hit.reason }
    }
    if ($Row.deleted) {
        $parts += "BEI YOUTUBE GELÖSCHT"
    } elseif ($Row.deleteRequested -and $Row.deleteError) {
        $parts += "LÖSCHEN FEHLGESCHLAGEN"
    }
    if ($Row.banned -and [string]$Row.banType -eq "permanent") {
        $parts += "NUTZER DAUERHAFT BLOCKIERT"
    } elseif ($Row.banned -and [int]$Row.banDurationSeconds -gt 0) {
        $parts += "NUTZER " + [int]$Row.banDurationSeconds + " SEKUNDEN STUMM"
    } elseif ($Row.banRequested -and $Row.banError) {
        $parts += "SPERRE FEHLGESCHLAGEN: " + [string]$Row.banError
    }
    return ($parts -join "; ")
}

function Get-RuleName($Row) {
    $first = @($Row.ruleHits | Select-Object -First 1)
    if ($first.Count -eq 0) { return "—" }
    switch ([string]$first[0].rule) {
        "duplicate" { return "Wiederholung" }
        "flood" { return "Flood" }
        "uppercase" { return "Großschreibung" }
        "repeated_characters" { return "Zeichenfolge" }
        "link" { return "Links / Werbung" }
        "blocked_term" { return "Spam" }
        "insult" { return "Beleidigung" }
        "insult_evasion" { return "Umgangene Beleidigung" }
        "multiple_links" { return "Mehrere Links" }
        "advertising" { return "Werbung" }
        "contact_data" { return "Kontaktdaten" }
        "fraud" { return "Betrugsverdacht" }
        "mentions" { return "Erwähnungsspam" }
        "long_message" { return "Lange Nachricht" }
        "multiline" { return "Mehrzeiliger Spam" }
        "near_duplicate" { return "Ähnliche Wiederholung" }
        "private_data" { return "Private Daten" }
        "threats" { return "Drohung" }
        "hate_speech" { return "Hassrede" }
        "sexual_content" { return "Sexueller Inhalt" }
        "spoilers" { return "Spoiler" }
        "topic_filter" { return "Themenfilter" }
        "foreign_language" { return "Sprachfilter" }
        "repeat_offender" { return "Wiederholungstäter" }
        "spam_wave" { return "Spamwelle" }
        default { return [string]$first[0].rule }
    }
}

function Get-ActionText($Row) {
    if ($Row.banned -and [string]$Row.banType -eq "permanent") { return "Nutzer blockiert" }
    if ($Row.banned -and [int]$Row.banDurationSeconds -gt 0) { return "Stumm " + [int]$Row.banDurationSeconds + " Sekunden" }
    if ($Row.banRequested -and $Row.banError) { return "Sperre fehlgeschlagen" }
    if ($Row.deleted) { return "Gelöscht" }
    if ($Row.deleteRequested -and $Row.deleteError) { return "Löschen fehlgeschlagen" }
    if ($Row.flagged) { return "Hinweis" }
    return "—"
}

function Format-Time($Value) {
    if (-not $Value) { return "" }
    try {
        return ([datetimeoffset]::Parse([string]$Value)).ToLocalTime().ToString("HH:mm:ss")
    } catch { return [string]$Value }
}

function Get-FilteredRows {
    $rows = if ($script:CurrentMode -eq "flagged") { $script:FlaggedRows } elseif ($script:CurrentMode -eq "deleted") {
        @($script:AllRows | Where-Object { $_.deleted })
    } else { $script:AllRows }

    $query = $searchBox.Text.Trim().ToLowerInvariant()
    if ($query) {
        $rows = @($rows | Where-Object {
            $hay = (
                (Format-Time $(if($_.publishedAt){$_.publishedAt}else{$_.receivedAt})) + " " +
                [string]$_.authorName + " " +
                (Get-RoleText $_) + " " +
                [string]$_.text + " " +
                (Get-RuleName $_) + " " +
                (Get-ReasonText $_)
            ).ToLowerInvariant()
            $hay.Contains($query)
        })
    }
    return @($rows)
}

# ---------- Hauptfenster ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Chatwächter · Control Center 2026"
$form.WindowState = "Maximized"
$form.MinimumSize = [System.Drawing.Size]::new(1280,760)
$form.BackColor = $Colors.Window
$form.ForeColor = $Colors.Text
$form.Font = New-Font 9
$form.StartPosition = "CenterScreen"

$root = New-Object System.Windows.Forms.TableLayoutPanel
$root.Dock = "Fill"
$root.ColumnCount = 2
$root.RowCount = 1
$root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle("Absolute",200)))
$root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle("Percent",100)))
$form.Controls.Add($root)

# ---------- Sidebar ----------
$sidebar = New-Panel $Colors.Sidebar "Fill"
$sidebar.Padding = [System.Windows.Forms.Padding]::new(14,18,14,12)
Set-CardBorder $sidebar $Colors.BorderSoft 1
$root.Controls.Add($sidebar,0,0)

$sideLayout = New-Object System.Windows.Forms.TableLayoutPanel
$sideLayout.Dock = "Fill"
$sideLayout.RowCount = 5
$sideLayout.ColumnCount = 1
$sideLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Absolute",135)))
$sideLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Percent",100)))
$sideLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Absolute",84)))
$sideLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Absolute",68)))
$sideLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Absolute",28)))
$sidebar.Controls.Add($sideLayout)

$logoBox = New-Panel $Colors.Sidebar "Fill"
$logoShield = @(New-Label "◈" 42 $Colors.Cyan2 ([System.Drawing.FontStyle]::Bold) "Top" ([System.Drawing.ContentAlignment]::MiddleCenter))[-1]
    $logoShield = Assert-Control $logoShield "logoShield"
$logoShield.Height = 65
$logoName = @(New-Label "CHATWÄCHTER" 11 $Colors.Text ([System.Drawing.FontStyle]::Bold) "Top" ([System.Drawing.ContentAlignment]::MiddleCenter))[-1]
    $logoName = Assert-Control $logoName "logoName"
$logoName.Height = 26
$logoYear = @(New-Label "2026" 9 $Colors.Muted ([System.Drawing.FontStyle]::Regular) "Top" ([System.Drawing.ContentAlignment]::MiddleCenter))[-1]
    $logoYear = Assert-Control $logoYear "logoYear"
$logoBox.Controls.Add($logoYear)
$logoBox.Controls.Add($logoName)
$logoBox.Controls.Add($logoShield)
$sideLayout.Controls.Add($logoBox,0,0)

$navFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$navFlow.Dock = "Fill"
$navFlow.FlowDirection = "TopDown"
$navFlow.WrapContents = $false
$navFlow.AutoScroll = $true
$navFlow.Padding = [System.Windows.Forms.Padding]::new(0,6,0,0)
$navFlow.BackColor = $Colors.Sidebar
$script:NavButtons = @{}
$navEntries = @(
    @("dashboard","⌂   DASHBOARD",$true),
    @("live","⌁   LIVE MONITORING",$false),
    @("messages","▣   NACHRICHTEN",$false),
    @("rules","♢   REGELN",$false),
    @("moderators","♟   MODERATOREN",$false),
    @("channel","⚙   KANAL & EINSTELLUNGEN",$false),
    @("protocol","▤   PROTOKOLL",$false),
    @("statistics","▥   STATISTIKEN",$false),
    @("alarms","♧   ALARME",$false),
    @("bans","⊘   SPERREN",$false),
    @("tools","✦   WERKZEUGE",$false),
    @("system","▱   SYSTEM",$false)
)

foreach ($entry in $navEntries) {
    $btn = New-NavButton $entry[1] $entry[2]
    if ($null -eq $btn) { continue }

    $btn.Margin = [System.Windows.Forms.Padding]::new(0,0,0,5)
    $btn.Tag = [string]$entry[0]
    $script:NavButtons[[string]$entry[0]] = $btn

    $btn.Add_Click({
        param($sender, $eventArgs)
        if ($null -eq $sender) { return }

        try {
            switch ([string]$sender.Tag) {
                "dashboard"  { $form.Activate() }
                "live"       { Show-LiveDialog }
                "messages"   { Show-MessagesDialog }
                "rules"      { Show-RulesDialog }
                "moderators" { Show-ModeratorsDialog }
                "channel"    { Show-ChannelDialog }
                "protocol"   { Show-ProtocolDialog }
                "statistics" { Show-StatisticsDialog }
                "alarms"     { Show-AlarmsDialog }
                "bans"       { Show-BansDialog }
                "tools"      { Show-ToolsDialog }
                "system"     { Show-SystemDialog }
            }
        }
        catch {
            $navError = Join-Path $script:Folder "CHATWAECHTER_NAVIGATIONSFEHLER.txt"
            (
                "Zeit: " + (Get-Date).ToString("dd.MM.yyyy HH:mm:ss") + [Environment]::NewLine +
                "Menü: " + [string]$sender.Tag + [Environment]::NewLine +
                "Fehler: " + $_.Exception.Message + [Environment]::NewLine +
                "Datei: " + $_.InvocationInfo.ScriptName + [Environment]::NewLine +
                "Zeile: " + $_.InvocationInfo.ScriptLineNumber + [Environment]::NewLine +
                $_.ScriptStackTrace
            ) | Set-Content -LiteralPath $navError -Encoding UTF8

            [System.Windows.Forms.MessageBox]::Show(
                "Die Seite konnte nicht geöffnet werden.`n`n" +
                $_.Exception.Message +
                "`n`nDetails stehen in CHATWAECHTER_NAVIGATIONSFEHLER.txt.",
                "Chatwächter",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
        }
    })

    [void]$navFlow.Controls.Add($btn)
}
$sideLayout.Controls.Add($navFlow,0,1)

$channelCard = New-Panel $Colors.Surface "Fill"
$channelCard.Padding = [System.Windows.Forms.Padding]::new(12,8,12,8)
Set-CardBorder $channelCard $Colors.BorderSoft 1
$channelTitle = @(New-Label "KANAL" 8 $Colors.Muted ([System.Drawing.FontStyle]::Bold) "Top")[-1]
    $channelTitle = Assert-Control $channelTitle "channelTitle"
$channelName = @(New-Label "@DEIN_KANAL" 10 $Colors.Text ([System.Drawing.FontStyle]::Bold) "Top")[-1]
    $channelName = Assert-Control $channelName "channelName"
$channelState = @(New-Label "●  Status wird geladen" 9 $Colors.Green ([System.Drawing.FontStyle]::Regular) "Fill")[-1]
    $channelState = Assert-Control $channelState "channelState"
$channelCard.Controls.Add($channelState)
$channelCard.Controls.Add($channelName)
$channelCard.Controls.Add($channelTitle)
$sideLayout.Controls.Add($channelCard,0,2)

$modeCard = New-Panel $Colors.Surface "Fill"
$modeCard.Padding = [System.Windows.Forms.Padding]::new(12,8,12,8)
Set-CardBorder $modeCard $Colors.BorderSoft 1
$modeTitle = @(New-Label "MODUS" 8 $Colors.Muted ([System.Drawing.FontStyle]::Bold) "Top")[-1]
    $modeTitle = Assert-Control $modeTitle "modeTitle"
$modeValue = @(New-Label "AKTIVE MODERATION" 10 $Colors.Yellow ([System.Drawing.FontStyle]::Bold) "Fill")[-1]
    $modeValue = Assert-Control $modeValue "modeValue"
$modeCard.Controls.Add($modeValue)
$modeCard.Controls.Add($modeTitle)
$sideLayout.Controls.Add($modeCard,0,3)

$version = @(New-Label "CONTROL CENTER 2026" 8 $Colors.Dim ([System.Drawing.FontStyle]::Regular) "Fill" ([System.Drawing.ContentAlignment]::MiddleCenter))[-1]
    $version = Assert-Control $version "version"
$sideLayout.Controls.Add($version,0,4)

# ---------- Hauptbereich ----------
$main = New-Panel $Colors.Window "Fill"
$main.Padding = [System.Windows.Forms.Padding]::new(22,20,20,10)
$root.Controls.Add($main,1,0)

$mainLayout = New-Object System.Windows.Forms.TableLayoutPanel
$mainLayout.Dock = "Fill"
$mainLayout.ColumnCount = 1
$mainLayout.RowCount = 7
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Absolute",72)))
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Absolute",500)))
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Absolute",178)))
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Absolute",0)))
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Absolute",52)))
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Percent",100)))
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Absolute",40)))
$main.Controls.Add($mainLayout)

# Header
$header = New-Panel $Colors.Window "Fill"
$title = @(New-Label "CHATWÄCHTER · CONTROL CENTER" 20 $Colors.Text ([System.Drawing.FontStyle]::Bold))[-1]
    $title = Assert-Control $title "title"
$title.Location = [System.Drawing.Point]::new(0,0)
$title.Size = [System.Drawing.Size]::new(650,34)
$subtitle = @(New-Label "LIVE MONITORING · STREAM STATUS · CHAT ANALYSE" 9 $Colors.Cyan)[-1]
    $subtitle = Assert-Control $subtitle "subtitle"
$subtitle.Location = [System.Drawing.Point]::new(2,36)
$subtitle.Size = [System.Drawing.Size]::new(600,24)

$statusBox = New-Panel $Colors.Surface
$statusBox.Anchor = "Top,Right"
$statusBox.Size = [System.Drawing.Size]::new(228,48)
$statusBox.Location = [System.Drawing.Point]::new(900,0)
Set-CardBorder $statusBox $Colors.Border 1
$statusSmall = @(New-Label "STREAM STATUS" 8 $Colors.Muted ([System.Drawing.FontStyle]::Bold))[-1]
    $statusSmall = Assert-Control $statusSmall "statusSmall"
$statusSmall.Location = [System.Drawing.Point]::new(12,6)
$statusSmall.Size = [System.Drawing.Size]::new(100,16)
$statusMain = @(New-Label "OFFLINE" 10 $Colors.Text ([System.Drawing.FontStyle]::Bold))[-1]
    $statusMain = Assert-Control $statusMain "statusMain"
$statusMain.Location = [System.Drawing.Point]::new(116,5)
$statusMain.Size = [System.Drawing.Size]::new(96,25)
$statusDot = @(New-Label "●" 10 $Colors.Red ([System.Drawing.FontStyle]::Bold))[-1]
    $statusDot = Assert-Control $statusDot "statusDot"
$statusDot.Location = [System.Drawing.Point]::new(205,23)
$statusDot.Size = [System.Drawing.Size]::new(18,18)
$statusBox.Controls.AddRange(@($statusSmall,$statusMain,$statusDot))

$connBox = New-Panel $Colors.Surface
$connBox.Anchor = "Top,Right"
$connBox.Size = [System.Drawing.Size]::new(142,48)
$connBox.Location = [System.Drawing.Point]::new(1142,0)
Set-CardBorder $connBox $Colors.Border 1
$connSmall = @(New-Label "VERBINDUNG" 8 $Colors.Muted ([System.Drawing.FontStyle]::Bold))[-1]
    $connSmall = Assert-Control $connSmall "connSmall"
$connSmall.Location = [System.Drawing.Point]::new(10,5)
$connSmall.Size = [System.Drawing.Size]::new(90,16)
$connMain = @(New-Label "Getrennt" 9 $Colors.Red ([System.Drawing.FontStyle]::Bold))[-1]
    $connMain = Assert-Control $connMain "connMain"
$connMain.Location = [System.Drawing.Point]::new(10,22)
$connMain.Size = [System.Drawing.Size]::new(90,20)
$connIcon = @(New-Label "◔" 24 $Colors.Text ([System.Drawing.FontStyle]::Regular))[-1]
    $connIcon = Assert-Control $connIcon "connIcon"
$connIcon.Location = [System.Drawing.Point]::new(100,5)
$connIcon.Size = [System.Drawing.Size]::new(36,36)
$connBox.Controls.AddRange(@($connSmall,$connMain,$connIcon))

$header.Controls.AddRange(@($title,$subtitle,$statusBox,$connBox))
$header.Add_Resize({
    if ($null -ne $statusBox -and $null -ne $connBox) {
        $statusBox.Left = [Math]::Max(650, $header.ClientSize.Width - 390)
        $connBox.Left = [Math]::Max(890, $header.ClientSize.Width - 150)
    }
})
$mainLayout.Controls.Add($header,0,0)

# ---------- Große Livestream-Kachel ----------
$liveCard = New-Panel $Colors.Surface "Fill"
$liveCard.Margin = [System.Windows.Forms.Padding]::new(0,0,14,10)
$liveCard.Padding = [System.Windows.Forms.Padding]::new(12,10,12,10)
Set-CardBorder $liveCard $Colors.Border 1

$liveTitle = @(New-Label "LIVESTREAM" 10 $Colors.Text ([System.Drawing.FontStyle]::Bold))[-1]
    $liveTitle = Assert-Control $liveTitle "liveTitle"
$liveTitle.Location = [System.Drawing.Point]::new(14,8)
$liveTitle.Size = [System.Drawing.Size]::new(105,24)

$liveStreamName = @(New-Label "Kein Livestream aktiv" 13 $Colors.Text ([System.Drawing.FontStyle]::Bold))[-1]
    $liveStreamName = Assert-Control $liveStreamName "liveStreamName"
$liveStreamName.Location = [System.Drawing.Point]::new(130,8)
$liveStreamName.Size = [System.Drawing.Size]::new(420,28)

$liveStatusLabel = @(New-Label "OFFLINE" 10 $Colors.Red ([System.Drawing.FontStyle]::Bold))[-1]
    $liveStatusLabel = Assert-Control $liveStatusLabel "liveStatusLabel"
$liveStatusLabel.Location = [System.Drawing.Point]::new(560,9)
$liveStatusLabel.Size = [System.Drawing.Size]::new(120,24)

$liveUrlLabel = @(New-Label "" 8 $Colors.Muted)[-1]
    $liveUrlLabel = Assert-Control $liveUrlLabel "liveUrlLabel"
$liveUrlLabel.Location = [System.Drawing.Point]::new(14,96)
$liveUrlLabel.Size = [System.Drawing.Size]::new(520,22)
$liveUrlLabel.Visible = $false

$livePreviewHost = New-Panel $Colors.Black
$livePreviewHost.Anchor = "Top,Left"
$livePreviewHost.Location = [System.Drawing.Point]::new(14,52)
$livePreviewHost.Size = [System.Drawing.Size]::new(640,360)
Set-CardBorder $livePreviewHost $Colors.BorderSoft 1

$livePreviewPlaceholder = @(New-Label "Kein Livestream aktiv" 16 $Colors.Muted ([System.Drawing.FontStyle]::Bold) "Fill" ([System.Drawing.ContentAlignment]::MiddleCenter))[-1]
    $livePreviewPlaceholder = Assert-Control $livePreviewPlaceholder "livePreviewPlaceholder"
$livePreviewHost.Controls.Add($livePreviewPlaceholder)

$liveWebView = $null
if ($script:WebView2Available) {
    try {
        $liveWebView = New-Object Microsoft.Web.WebView2.WinForms.WebView2
        $liveWebView.Dock = [System.Windows.Forms.DockStyle]::Fill
        $liveWebView.Visible = $false
        $livePreviewHost.Controls.Add($liveWebView)
        $liveWebView.BringToFront()
    } catch {
        $liveWebView = $null
        $script:WebView2Available = $false
    }
}

function Get-RuleDisplayName([string]$RuleId) {
    if($RuleId.StartsWith("custom:")){return "Eigene Regel: "+$RuleId.Substring(7)}
    switch($RuleId){
        "duplicate" {"Wiederholung"}; "flood" {"Zu schnelles Schreiben (Flood)"}; "uppercase" {"Nur Großbuchstaben"}
        "repeated_characters" {"Zu viele gleiche Zeichen"}; "link" {"Link / Werbung"}; "blocked_term" {"Gesperrter Spam-Begriff"}
        "insult" {"Beleidigung"}; "insult_evasion" {"Umgangene Beleidigung"}; "emoji" {"Emoji-Spam"}
        "multiple_links" {"Mehrere Links"}; "advertising" {"Werbesatz"}; "contact_data" {"Kontaktdaten"}
        "fraud" {"Betrugsverdacht"}; "mentions" {"Zu viele Erwähnungen"}
        "long_message" {"Sehr lange Nachricht"}; "multiline" {"Mehrzeiliger Zeichenspam"}; "near_duplicate" {"Fast gleiche Wiederholung"}
        "private_data" {"Veröffentlichung privater Daten"}; "threats" {"Drohung"}; "hate_speech" {"Hassrede"}
        "sexual_content" {"Sexueller Inhalt"}; "spoilers" {"Spoiler-Regel"}; "topic_filter" {"Themenfilter"}
        "foreign_language" {"Fremdsprachenregel"}; "repeat_offender" {"Wiederholungstäter"}; "spam_wave" {"Spamwelle"}
        default {$RuleId}
    }
}

$liveChatHost = New-Panel $Colors.Surface2
$liveChatHost.Location = [System.Drawing.Point]::new(670,52)
$liveChatHost.Size = [System.Drawing.Size]::new(360,360)
$liveChatHost.Anchor = "Top,Right"
Set-CardBorder $liveChatHost $Colors.BorderSoft 1

$liveChatTitle = @(New-Label "●  YOUTUBE LIVECHAT" 10 $Colors.Text ([System.Drawing.FontStyle]::Bold) "Top")[-1]
$liveChatTitle.Height = 44
$liveChatTitle.BackColor = [System.Drawing.Color]::FromArgb(28,27,31)
$liveChatTitle.Padding = [System.Windows.Forms.Padding]::new(14,12,0,0)

$liveChatGrid = New-Object System.Windows.Forms.DataGridView
$liveChatGrid.Dock = "Fill"
$liveChatGrid.BackgroundColor = $Colors.Surface2
$liveChatGrid.BorderStyle = "None"
$liveChatGrid.GridColor = $Colors.BorderSoft
$liveChatGrid.EnableHeadersVisualStyles = $false
$liveChatGrid.ColumnHeadersVisible = $false
$liveChatGrid.ColumnHeadersDefaultCellStyle.BackColor = $Colors.Surface3
$liveChatGrid.ColumnHeadersDefaultCellStyle.ForeColor = $Colors.Muted
$liveChatGrid.DefaultCellStyle.BackColor = $Colors.Surface2
$liveChatGrid.DefaultCellStyle.ForeColor = $Colors.Text
$liveChatGrid.DefaultCellStyle.SelectionBackColor = $Colors.Surface3
$liveChatGrid.RowHeadersVisible = $false
$liveChatGrid.AllowUserToAddRows = $false
$liveChatGrid.AllowUserToDeleteRows = $false
$liveChatGrid.AllowUserToResizeRows = $false
$liveChatGrid.ReadOnly = $true
$liveChatGrid.SelectionMode = "FullRowSelect"
$liveChatGrid.AutoGenerateColumns = $false
$liveChatGrid.RowTemplate.Height = 38
$liveChatGrid.CellBorderStyle = "None"
$liveChatGrid.DefaultCellStyle.WrapMode = [System.Windows.Forms.DataGridViewTriState]::True
$liveChatGrid.DefaultCellStyle.Padding = [System.Windows.Forms.Padding]::new(4,3,4,3)
$chatTimeColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$chatTimeColumn.Name="Zeit";$chatTimeColumn.HeaderText="Zeit";$chatTimeColumn.Width=58
$chatUserColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$chatUserColumn.Name="Nutzer";$chatUserColumn.HeaderText="Nutzer";$chatUserColumn.Width=105
$chatTextColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$chatTextColumn.Name="Nachricht";$chatTextColumn.HeaderText="Nachricht";$chatTextColumn.AutoSizeMode="Fill"
[void]$liveChatGrid.Columns.Add($chatTimeColumn)
[void]$liveChatGrid.Columns.Add($chatUserColumn)
[void]$liveChatGrid.Columns.Add($chatTextColumn)
Enable-EmojiColoring $liveChatGrid

$chatComposer = New-Panel $Colors.Surface3
$chatComposer.Dock = "Bottom"
$chatComposer.Height = 52
$chatComposer.Padding = [System.Windows.Forms.Padding]::new(8,8,8,8)

$chatSendButton = @(New-Button "Senden" $Colors.Blue $Colors.Text 72 34)[-1]
$chatSendButton.Dock = "Right"
$chatSendButton.Enabled = $false

$chatEmojiButton = @(New-Button "☺" $Colors.Surface2 $Colors.Text 38 34)[-1]
$chatEmojiButton.Dock = "Right"
$chatEmojiButton.Enabled = $false
$chatEmojiButton.Font = New-Object System.Drawing.Font("Segoe UI Emoji",13)

$chatInput = New-Object System.Windows.Forms.TextBox
$chatInput.Dock = "Fill"
$chatInput.BackColor = $Colors.Surface2
$chatInput.ForeColor = $Colors.Text
$chatInput.BorderStyle = "FixedSingle"
$chatInput.Font = New-Object System.Drawing.Font("Segoe UI",10)
$chatInput.MaxLength = 200
$chatInput.Enabled = $false
$chatInput.AccessibleDescription = "Nachricht senden"

$chatComposer.Controls.Add($chatInput)
$chatComposer.Controls.Add($chatEmojiButton)
$chatComposer.Controls.Add($chatSendButton)

$chatWaitingLabel = @(New-Label "Der YouTube-Livechat wartet auf den Livestream.`n`nSobald der Stream startet, erscheinen hier Nachrichten,`ndas Schreibfeld und die vollständige Emoji-Auswahl." 10 $Colors.Muted ([System.Drawing.FontStyle]::Regular) "Fill" ([System.Drawing.ContentAlignment]::MiddleCenter))[-1]
$chatWaitingLabel.BackColor = [System.Drawing.Color]::FromArgb(24,24,27)
$chatWaitingLabel.Padding = [System.Windows.Forms.Padding]::new(18)

$liveChatHost.Controls.Add($liveChatGrid)
$liveChatHost.Controls.Add($chatWaitingLabel)
$liveChatHost.Controls.Add($chatComposer)
$liveChatHost.Controls.Add($liveChatTitle)
$liveChatTitle.BringToFront()
$chatComposer.BringToFront()

# Der offizielle YouTube-Livechat liefert die vollständige Emoji-Auswahl,
# Kanal-Emojis und das originale YouTube-Schreibfeld. Die native Ansicht
# darunter bleibt als Rückfalllösung erhalten.
$officialChatWebView = $null
if ($script:WebView2Available) {
    try {
        $officialChatWebView = New-Object Microsoft.Web.WebView2.WinForms.WebView2
        $officialChatWebView.Dock = [System.Windows.Forms.DockStyle]::Fill
        $officialChatWebView.Visible = $false
        $liveChatHost.Controls.Add($officialChatWebView)
        $officialChatWebView.BringToFront()
    } catch {
        $officialChatWebView = $null
    }
}

$openStreamButton = @(New-Button "Livestream öffnen" $Colors.Blue $Colors.Text 150 36)[-1]
    $openStreamButton = Assert-Control $openStreamButton "openStreamButton"
$openStreamButton.Location = [System.Drawing.Point]::new(690,5)
$openStreamButton.Enabled = $false

$liveCard.Controls.AddRange(@(
    $liveTitle,
    $liveStreamName,
    $liveStatusLabel,
    $liveUrlLabel,
    $openStreamButton,
    $livePreviewHost,
    $liveChatHost
))

$liveCard.Add_Resize({
    if ($null -ne $livePreviewHost) {
        $top = 42
        $availableHeight = [Math]::Max(180, $liveCard.ClientSize.Height - $top - 12)
        $contentWidth = [Math]::Max(700, $liveCard.ClientSize.Width - 28)
        $chatWidth = [Math]::Max(320,[int][Math]::Floor($contentWidth * 0.32))
        $availableWidth = [Math]::Max(320,$contentWidth - $chatWidth - 14)
        $playerWidth = [Math]::Min($availableWidth,[int][Math]::Floor($availableHeight * 16.0 / 9.0))
        $playerHeight = [int][Math]::Floor($playerWidth * 9.0 / 16.0)
        $livePreviewHost.Size = [System.Drawing.Size]::new($playerWidth,$playerHeight)
        $livePreviewHost.Left = 14
        $livePreviewHost.Top = $top
        $liveChatHost.Left = $livePreviewHost.Right + 14
        $liveChatHost.Top = $top
        $liveChatHost.Width = [Math]::Max(300,$liveCard.ClientSize.Width-$liveChatHost.Left-14)
        $liveChatHost.Height = $playerHeight
    }
})

$mainLayout.Controls.Add($liveCard,0,1)

$script:CurrentStreamUrl = ""
$script:CurrentVideoId = ""
$script:CurrentLiveChatId = ""
$script:PendingChatRequestId = ""
$script:OfficialChatVideoId = ""

function Set-LiveVideoPlayer([string]$VideoId) {
    if ($null -eq $liveWebView -or -not $script:WebView2Available) { return }
    if ([string]::IsNullOrWhiteSpace($VideoId)) {
        $liveWebView.Visible = $false
        $livePreviewPlaceholder.Visible = $true
        $script:PlayerVideoId = ""
        return
    }
    if ($script:PlayerVideoId -ne $VideoId) {
        $embedUrl = "https://www.youtube-nocookie.com/embed/" + [uri]::EscapeDataString($VideoId) + "?autoplay=0&playsinline=1&rel=0"
        try {
            $liveWebView.Source = [uri]$embedUrl
            $script:PlayerVideoId = $VideoId
        } catch {
            $livePreviewPlaceholder.Text = "Player konnte nicht geladen werden`nZum Öffnen klicken"
            return
        }
    }
    $livePreviewPlaceholder.Visible = $false
    $liveWebView.Visible = $true
    $liveWebView.BringToFront()
}

function Set-OfficialYouTubeChat([string]$VideoId) {
    if ($null -eq $officialChatWebView) {
        $chatWaitingLabel.Visible = [string]::IsNullOrWhiteSpace($VideoId)
        $liveChatGrid.Visible = -not $chatWaitingLabel.Visible
        $liveChatTitle.Visible = $true
        $chatComposer.Visible = $true
        return
    }

    if ([string]::IsNullOrWhiteSpace($VideoId)) {
        $officialChatWebView.Visible = $false
        $liveChatGrid.Visible = $false
        $chatWaitingLabel.Visible = $true
        $liveChatTitle.Visible = $true
        $chatComposer.Visible = $true
        $script:OfficialChatVideoId = ""
        return
    }

    if ($script:OfficialChatVideoId -ne $VideoId) {
        $chatUrl = "https://www.youtube.com/live_chat?v=" + [uri]::EscapeDataString($VideoId) + "&embed_domain=localhost&dark_theme=1"
        try {
            $officialChatWebView.Source = [uri]$chatUrl
            $script:OfficialChatVideoId = $VideoId
        } catch {
            $officialChatWebView.Visible = $false
            $chatWaitingLabel.Visible = $false
            $liveChatGrid.Visible = $true
            $liveChatTitle.Visible = $true
            $chatComposer.Visible = $true
            return
        }
    }

    $liveChatGrid.Visible = $false
    $chatWaitingLabel.Visible = $false
    $liveChatTitle.Visible = $false
    $chatComposer.Visible = $false
    $officialChatWebView.Visible = $true
    $officialChatWebView.BringToFront()
    if($null-ne $quickCheckPanel){$quickCheckPanel.BringToFront()}
}

function Render-LiveChatPreview {
    if ($null -eq $liveChatGrid) { return }
    $liveChatGrid.Rows.Clear()
    foreach ($row in @($script:AllRows | Select-Object -Last 100)) {
        $index = $liveChatGrid.Rows.Add(
            (Format-Time $(if($row.publishedAt){$row.publishedAt}else{$row.receivedAt})),
            [string]$row.authorName,
            [string]$row.text
        )
        $liveChatGrid.Rows[$index].Tag = $row
        if ($row.banned -or $row.deleted) {
            $liveChatGrid.Rows[$index].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(61,11,23)
        } elseif ($row.flagged) {
            $liveChatGrid.Rows[$index].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(65,45,5)
        }
    }
    if ($liveChatGrid.Rows.Count -gt 0) {
        $liveChatGrid.FirstDisplayedScrollingRowIndex = $liveChatGrid.Rows.Count - 1
    }
}

function Send-LiveChatMessage {
    $message = [string]$chatInput.Text
    if ([string]::IsNullOrWhiteSpace($message) -or [string]::IsNullOrWhiteSpace($script:CurrentLiveChatId)) { return }
    if ($message.Length -gt 200) {
        [System.Windows.Forms.MessageBox]::Show("Eine YouTube-Chatnachricht darf höchstens 200 Zeichen lang sein.","Livechat") | Out-Null
        return
    }

    $requestId = [guid]::NewGuid().ToString("N")
    $request = [ordered]@{ id=$requestId; message=$message.Trim(); createdAt=(Get-Date).ToString("o") }
    $temporaryFile = $script:ChatSendRequestWindows + ".tmp"
    $request | ConvertTo-Json | Set-Content -LiteralPath $temporaryFile -Encoding UTF8
    Move-Item -LiteralPath $temporaryFile -Destination $script:ChatSendRequestWindows -Force
    if (Test-Path -LiteralPath $script:ChatSendResultWindows) { Remove-Item -LiteralPath $script:ChatSendResultWindows -Force }
    $script:PendingChatRequestId = $requestId
    $chatInput.Enabled = $false
    $chatSendButton.Enabled = $false
    $chatSendButton.Text = "Sende …"
}

function Update-LiveChatSendResult {
    if ([string]::IsNullOrWhiteSpace($script:PendingChatRequestId)) { return }
    if (-not (Test-Path -LiteralPath $script:ChatSendResultWindows)) { return }
    try {
        $result = Get-Content -LiteralPath $script:ChatSendResultWindows -Raw -Encoding UTF8 | ConvertFrom-Json
        if ([string]$result.id -ne $script:PendingChatRequestId) { return }
        if ([bool]$result.ok) {
            $chatInput.Text = ""
            $chatSendButton.Text = "Gesendet"
        } else {
            $chatSendButton.Text = "Fehler"
            [System.Windows.Forms.MessageBox]::Show("Die Nachricht konnte nicht gesendet werden:`n`n" + [string]$result.message,"Livechat",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        }
        $script:PendingChatRequestId = ""
        $chatInput.Enabled = -not [string]::IsNullOrWhiteSpace($script:CurrentLiveChatId)
        $chatSendButton.Enabled = $chatInput.Enabled
        $resetSendCaption = New-Object System.Windows.Forms.Timer
        $resetSendCaption.Interval = 1400
        $resetSendCaption.Add_Tick({ param($sender,$eventArgs); $sender.Stop(); $sender.Dispose(); $chatSendButton.Text="Senden" })
        $resetSendCaption.Start()
    } catch { }
}

$chatSendButton.Add_Click({ Send-LiveChatMessage })
$chatInput.Add_KeyDown({
    param($sender,$eventArgs)
    if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        $eventArgs.SuppressKeyPress = $true
        Send-LiveChatMessage
    }
})

$livePreviewPlaceholder.Add_Click({
    if (-not [string]::IsNullOrWhiteSpace($script:CurrentStreamUrl)) {
        Start-Process $script:CurrentStreamUrl
    }
})

$openStreamButton.Add_Click({
    if (-not [string]::IsNullOrWhiteSpace($script:CurrentStreamUrl)) {
        Start-Process $script:CurrentStreamUrl
    }
})

# ---------- Helper für Karten ----------
function New-MetricCard {
    param([string]$Title, [System.Drawing.Color]$Accent)
    $card = New-Panel $Colors.Surface "Fill"
    $card.Margin = [System.Windows.Forms.Padding]::new(0,0,14,8)
    $card.Padding = [System.Windows.Forms.Padding]::new(14,10,14,10)
    Set-CardBorder $card $Colors.Border 1

    $t = @(New-Label $Title 10 $Colors.Text ([System.Drawing.FontStyle]::Regular))[-1]
    $t = Assert-Control $t "t"
    $t.Location = [System.Drawing.Point]::new(14,10)
    $t.Size = [System.Drawing.Size]::new(240,22)

    $glow = New-Panel $Accent
    $glow.Location = [System.Drawing.Point]::new(90,0)
    $glow.Size = [System.Drawing.Size]::new(80,2)

    $card.Controls.AddRange(@($t,$glow))
    return $card
}

function New-RingChart {
    param([System.Drawing.Color]$Color, [string]$CenterText, [string]$SubText)
    $chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
    $chart.BackColor = [System.Drawing.Color]::Transparent
    $chart.Size = [System.Drawing.Size]::new(150,130)
    $chart.Location = [System.Drawing.Point]::new(15,32)

    $area = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
    $area.BackColor = [System.Drawing.Color]::Transparent
    $area.Position.Auto = $false
    $area.Position.X = 4
    $area.Position.Y = 4
    $area.Position.Width = 92
    $area.Position.Height = 92
    $chart.ChartAreas.Add($area)

    $series = New-Object System.Windows.Forms.DataVisualization.Charting.Series
    $series.ChartType = "Doughnut"
    $series.IsValueShownAsLabel = $false
    $series.Points.AddXY("Wert",75) | Out-Null
    $series.Points.AddXY("Rest",25) | Out-Null
    $series.Points[0].Color = $Color
    $series.Points[1].Color = [System.Drawing.Color]::FromArgb(27,55,89)
    $series["DoughnutRadius"] = "72"
    $series["PieStartAngle"] = "270"
    $chart.Series.Add($series)

    $center = @(New-Label $CenterText 16 $Colors.Text ([System.Drawing.FontStyle]::Bold))[-1]
    $center = Assert-Control $center "center"
    $center.BackColor = [System.Drawing.Color]::Transparent
    $center.TextAlign = "MiddleCenter"
    $center.Location = [System.Drawing.Point]::new(39,72)
    $center.Size = [System.Drawing.Size]::new(102,28)

    $sub = @(New-Label $SubText 8 $Colors.Muted)[-1]
    $sub = Assert-Control $sub "sub"
    $sub.TextAlign = "MiddleCenter"
    $sub.Location = [System.Drawing.Point]::new(40,98)
    $sub.Size = [System.Drawing.Size]::new(100,18)

    return @($chart,$center,$sub)
}

# Row 1 metric cards
$cards1 = New-Object System.Windows.Forms.TableLayoutPanel
$cards1.Dock = "Fill"
$cards1.ColumnCount = 5
$cards1.RowCount = 1
for($i=0;$i -lt 5;$i++){ $cards1.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle("Percent",20))) }
$mainLayout.Controls.Add($cards1,0,2)

$cardMessages = New-MetricCard "NACHRICHTEN" $Colors.Cyan
$msgRing = New-RingChart $Colors.Cyan "0" "Gesamt"
$msgChart=$msgRing[0]; $msgValue=$msgRing[1]; $msgSub=$msgRing[2]
$cardMessages.Controls.AddRange(@($msgChart,$msgValue,$msgSub))
$cards1.Controls.Add($cardMessages,0,0)

$cardHits = New-MetricCard "REGEL-TREFFER" $Colors.Red
$hitRing = New-RingChart $Colors.Red "0" "Heute"
$hitChart=$hitRing[0]; $hitValue=$hitRing[1]; $hitSub=$hitRing[2]
$cardHits.Controls.AddRange(@($hitChart,$hitValue,$hitSub))
$hitLegend = @(New-Label "● Hoch          0`n● Mittel        0`n● Niedrig       0" 9 $Colors.Muted)[-1]
    $hitLegend = Assert-Control $hitLegend "hitLegend"
$hitLegend.Location = [System.Drawing.Point]::new(175,58)
$hitLegend.Size = [System.Drawing.Size]::new(135,80)
$cardHits.Controls.Add($hitLegend)
$cards1.Controls.Add($cardHits,1,0)

$cardViewer = New-MetricCard "AKTIVE ZUSCHAUER" $Colors.Blue
$viewRing = New-RingChart $Colors.Blue "—" "Aktuell"
$cardViewer.Controls.AddRange($viewRing)
$viewerInfo = @(New-Label "Keine Zuschauerzahl`nüber die Chat-API" 9 $Colors.Muted)[-1]
    $viewerInfo = Assert-Control $viewerInfo "viewerInfo"
$viewerInfo.Location = [System.Drawing.Point]::new(172,60)
$viewerInfo.Size = [System.Drawing.Size]::new(140,60)
$cardViewer.Controls.Add($viewerInfo)
$cards1.Controls.Add($cardViewer,2,0)

$cardProtection = New-MetricCard "STATUS" $Colors.Cyan2
$shield = @(New-Label "⬡" 48 $Colors.Cyan2 ([System.Drawing.FontStyle]::Bold))[-1]
    $shield = Assert-Control $shield "shield"
$shield.Location = [System.Drawing.Point]::new(26,52)
$shield.Size = [System.Drawing.Size]::new(76,76)
$protectTitle = @(New-Label "SCHUTZ AKTIV" 12 $Colors.Cyan2 ([System.Drawing.FontStyle]::Bold))[-1]
    $protectTitle = Assert-Control $protectTitle "protectTitle"
$protectTitle.Location = [System.Drawing.Point]::new(105,55)
$protectTitle.Size = [System.Drawing.Size]::new(210,28)
$protectText = @(New-Label "Chat überwacht`nRegeln aktiv" 9 $Colors.Muted)[-1]
    $protectText = Assert-Control $protectText "protectText"
$protectText.Location = [System.Drawing.Point]::new(107,88)
$protectText.Size = [System.Drawing.Size]::new(205,50)
$cardProtection.Controls.AddRange(@($shield,$protectTitle,$protectText))
$cards1.Controls.Add($cardProtection,3,0)

$cardEmergency = New-MetricCard "NOT-AUS" $Colors.Red
$emergencyState = @(New-Label "AUTOMATIK AKTIV" 12 $Colors.Green ([System.Drawing.FontStyle]::Bold))[-1]
$emergencyState.Location = [System.Drawing.Point]::new(122,52)
$emergencyState.Size = [System.Drawing.Size]::new(190,28)
$emergencyInfo = @(New-Label "Überwachung und Protokoll`nlaufen immer weiter" 8 $Colors.Muted)[-1]
$emergencyInfo.Location = [System.Drawing.Point]::new(122,82)
$emergencyInfo.Size = [System.Drawing.Size]::new(185,55)

$emergencyCircle = New-Object System.Windows.Forms.Label
$emergencyCircle.Location = [System.Drawing.Point]::new(18,45)
$emergencyCircle.Size = [System.Drawing.Size]::new(92,92)
$emergencyCircle.BackColor = $Colors.Red
$emergencyCircle.ForeColor = $Colors.Text
$emergencyCircle.Font = New-Font 16 ([System.Drawing.FontStyle]::Bold)
$emergencyCircle.Text = "STOP"
$emergencyCircle.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$emergencyCircle.Cursor = [System.Windows.Forms.Cursors]::Hand
$circlePath = New-Object System.Drawing.Drawing2D.GraphicsPath
$circlePath.AddEllipse(0,0,$emergencyCircle.Width-1,$emergencyCircle.Height-1)
$emergencyCircle.Region = New-Object System.Drawing.Region($circlePath)
$circlePath.Dispose()

function Update-EmergencyCard {
    $paused = Test-Path -LiteralPath $script:PauseWindows
    if($paused){
        $emergencyState.Text = "NOT-AUS AKTIV"
        $emergencyState.ForeColor = $Colors.Red
        $emergencyCircle.Text = "!"
        $emergencyCircle.BackColor = [System.Drawing.Color]::FromArgb(255,25,55)
        $emergencyInfo.Text = "Klicken zum`nWiedereinschalten"
        $protectTitle.Text = "NUR ÜBERWACHUNG"
        $protectTitle.ForeColor = $Colors.Yellow
        $protectText.Text = "Aktionen angehalten`nProtokollierung aktiv"
    } else {
        $emergencyState.Text = "AUTOMATIK AKTIV"
        $emergencyState.ForeColor = $Colors.Green
        $emergencyCircle.Text = "STOP"
        $emergencyCircle.BackColor = $Colors.Red
        $emergencyInfo.Text = "Überwachung und Protokoll`nlaufen immer weiter"
        $protectTitle.Text = "SCHUTZ AKTIV"
        $protectTitle.ForeColor = $Colors.Cyan2
        $protectText.Text = "Chat überwacht`nRegeln aktiv"
    }
}

$emergencyCircle.Add_Click({
    if(Test-Path -LiteralPath $script:PauseWindows){
        Remove-Item -LiteralPath $script:PauseWindows -Force
    } else {
        (Get-Date).ToString("o") | Set-Content -LiteralPath $script:PauseWindows -Encoding UTF8
    }
    Update-EmergencyCard
})
$script:EmergencyPulsePhase = $false
$emergencyPulseTimer = New-Object System.Windows.Forms.Timer
$emergencyPulseTimer.Interval = 550
$emergencyPulseTimer.Add_Tick({
    if(Test-Path -LiteralPath $script:PauseWindows){
        $script:EmergencyPulsePhase = -not $script:EmergencyPulsePhase
        $emergencyCircle.BackColor = $(if($script:EmergencyPulsePhase){[System.Drawing.Color]::FromArgb(255,20,45)}else{[System.Drawing.Color]::FromArgb(185,0,30)})
    }
})
$emergencyPulseTimer.Start()
$cardEmergency.Controls.AddRange(@($emergencyState,$emergencyInfo,$emergencyCircle))
$cards1.Controls.Add($cardEmergency,4,0)
Update-EmergencyCard

# ---------- Charts Row ----------
$cards2 = New-Object System.Windows.Forms.TableLayoutPanel
$cards2.Dock = "Fill"
$cards2.ColumnCount = 4
$cards2.RowCount = 1
for($i=0;$i -lt 4;$i++){ $cards2.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle("Percent",25))) }
$mainLayout.Controls.Add($cards2,0,3)

function New-ChartCard([string]$Title) {
    $card = New-MetricCard $Title $Colors.Cyan
    return $card
}

function New-BasicChart([string]$Type, [System.Drawing.Color]$Color) {
    $chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
    $chart.BackColor = [System.Drawing.Color]::Transparent
    $chart.Dock = "Bottom"
    $chart.Height = 165

    $area = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
    $area.BackColor = [System.Drawing.Color]::Transparent
    $area.AxisX.LabelStyle.ForeColor = $Colors.Muted
    $area.AxisY.LabelStyle.ForeColor = $Colors.Muted
    $area.AxisX.LineColor = $Colors.BorderSoft
    $area.AxisY.LineColor = $Colors.BorderSoft
    $area.AxisX.MajorGrid.LineColor = $Colors.BorderSoft
    $area.AxisY.MajorGrid.LineColor = $Colors.BorderSoft
    $area.AxisX.MajorTickMark.Enabled = $false
    $area.AxisY.MajorTickMark.Enabled = $false
    $chart.ChartAreas.Add($area)

    $series = New-Object System.Windows.Forms.DataVisualization.Charting.Series
    $series.ChartType = $Type
    $series.Color = $Color
    $series.BorderWidth = 2
    $series.IsValueShownAsLabel = $false
    $chart.Series.Add($series)
    return $chart
}

$historyCard = New-ChartCard "NACHRICHTENVERLAUF"
$msgHistoryChart = New-BasicChart "Column" $Colors.Blue
$historyCard.Controls.Add($msgHistoryChart)
$cards2.Controls.Add($historyCard,0,0)

$hitHistoryCard = New-ChartCard "REGEL-TREFFER VERLAUF"
$hitHistoryChart = New-BasicChart "Line" $Colors.Red
$hitHistoryChart.Series[0].BorderWidth = 2
$hitHistoryCard.Controls.Add($hitHistoryChart)
$cards2.Controls.Add($hitHistoryCard,1,0)

$rulesCard = New-ChartCard "TREFFER NACH REGEL"
$rulesPanel = New-Panel $Colors.Surface
$rulesPanel.Dock = "Bottom"
$rulesPanel.Height = 165
$rulesCard.Controls.Add($rulesPanel)
$ruleLabels = @{}
$ruleBars = @{}
$ruleNames = @("Wiederholung","Beleidigung","Links / Werbung","Großschreibung","Andere")
for($i=0;$i -lt $ruleNames.Count;$i++){
    $y=10 + $i*29
    $lab = @(New-Label $ruleNames[$i] 8 $Colors.Muted)[-1]
    $lab = Assert-Control $lab "lab"
    $lab.Location=[System.Drawing.Point]::new(8,$y)
    $lab.Size=[System.Drawing.Size]::new(92,20)
    $bg=New-Panel ([System.Drawing.Color]::FromArgb(14,38,68))
    $bg.Location=[System.Drawing.Point]::new(104,$y+3)
    $bg.Size=[System.Drawing.Size]::new(130,12)
    $bar=New-Panel $Colors.Red
    $bar.Location=[System.Drawing.Point]::new(104,$y+3)
    $bar.Size=[System.Drawing.Size]::new(1,12)
    $val = @(New-Label "0" 8 $Colors.Text)[-1]
    $val = Assert-Control $val "val"
    $val.Location=[System.Drawing.Point]::new(242,$y)
    $val.Size=[System.Drawing.Size]::new(52,20)
    $rulesPanel.Controls.AddRange(@($lab,$bg,$bar,$val))
    $ruleBars[$ruleNames[$i]]=$bar
    $ruleLabels[$ruleNames[$i]]=$val
}
$cards2.Controls.Add($rulesCard,2,0)

$deleteCard = New-ChartCard "LÖSCHUNGSQUOTE"
$deleteRing = New-RingChart $Colors.Cyan "0%" "Gelöscht"
$deleteChart=$deleteRing[0]; $deletePercent=$deleteRing[1]; $deleteSub=$deleteRing[2]
$deleteCard.Controls.AddRange(@($deleteChart,$deletePercent,$deleteSub))
$deleteInfo = @(New-Label "Gelöschte Nachrichten`n0`n`nGesamt Nachrichten`n0" 9 $Colors.Muted)[-1]
    $deleteInfo = Assert-Control $deleteInfo "deleteInfo"
$deleteInfo.Location = [System.Drawing.Point]::new(170,54)
$deleteInfo.Size = [System.Drawing.Size]::new(135,104)
$deleteCard.Controls.Add($deleteInfo)
$cards2.Controls.Add($deleteCard,3,0)

# ---------- Toolbar ----------
$toolbar = New-Panel $Colors.Window "Fill"
$mainLayout.Controls.Add($toolbar,0,4)

$searchBox = New-Object System.Windows.Forms.TextBox
$searchBox.BackColor = $Colors.Surface
$searchBox.ForeColor = $Colors.Text
$searchBox.BorderStyle = "FixedSingle"
$searchBox.Font = New-Font 9
$searchBox.Location = [System.Drawing.Point]::new(0,7)
$searchBox.Size = [System.Drawing.Size]::new(650,34)
$searchBox.Text = ""

$btnAll = @(New-Button "Alle" $Colors.Blue $Colors.Text 76 34)[-1]
    $btnAll = Assert-Control $btnAll "btnAll"
$btnHits = @(New-Button "Nur Treffer" $Colors.Surface2 $Colors.Text 105 34)[-1]
    $btnHits = Assert-Control $btnHits "btnHits"
$btnDeleted = @(New-Button "Gelöscht" $Colors.Surface2 $Colors.Text 90 34)[-1]
    $btnDeleted = Assert-Control $btnDeleted "btnDeleted"
$formatBox = New-Object System.Windows.Forms.ComboBox
$formatBox.DropDownStyle = "DropDownList"
$formatBox.Items.AddRange(@("PNG","PDF","CSV","JSON"))
$formatBox.SelectedIndex = 0
$formatBox.BackColor = $Colors.Surface
$formatBox.ForeColor = $Colors.Text
$formatBox.FlatStyle = "Flat"
$formatBox.Font = New-Font 9
$formatBox.Size = [System.Drawing.Size]::new(125,34)

$btnExport = @(New-Button "Exportieren  ⇩" $Colors.Blue $Colors.Text 126 34)[-1]
    $btnExport = Assert-Control $btnExport "btnExport"

$toolbar.Controls.AddRange(@($searchBox,$btnAll,$btnHits,$btnDeleted,$formatBox,$btnExport))
$toolbar.Add_Resize({
    if ($null -ne $btnExport -and $null -ne $formatBox -and $null -ne $searchBox) {
        $btnExport.Left = [Math]::Max(0, $toolbar.ClientSize.Width - 126)
        $formatBox.Left = [Math]::Max(0, $btnExport.Left - 135)
        $btnDeleted.Left = [Math]::Max(0, $formatBox.Left - 100)
        $btnHits.Left = [Math]::Max(0, $btnDeleted.Left - 115)
        $btnAll.Left = [Math]::Max(0, $btnHits.Left - 86)
        $btnAll.Top = 7
        $btnHits.Top = 7
        $btnDeleted.Top = 7
        $formatBox.Top = 7
        $btnExport.Top = 7
        $searchBox.Width = [Math]::Max(260, $btnAll.Left - 12)
    }
})

# ---------- Table area ----------
$tableHost = New-Panel $Colors.Surface "Fill"
$tableHost.Padding = New-Object System.Windows.Forms.Padding(0)
Set-CardBorder $tableHost $Colors.Border 1
$mainLayout.Controls.Add($tableHost,0,5)

$tableTabs = New-Object System.Windows.Forms.FlowLayoutPanel
$tableTabs.Dock = "Top"
$tableTabs.Height = 38
$tableTabs.FlowDirection = "LeftToRight"
$tableTabs.WrapContents = $false
$tableTabs.BackColor = $Colors.Window
$tableTabs.Padding = [System.Windows.Forms.Padding]::new(0,0,0,0)

$tabAll = @(New-Button "ALLE NACHRICHTEN" $Colors.Blue $Colors.Text 150 36)[-1]
    $tabAll = Assert-Control $tabAll "tabAll"
$tabHits = @(New-Button "NUR TREFFER" $Colors.Surface $Colors.Text 120 36)[-1]
    $tabHits = Assert-Control $tabHits "tabHits"
$tabDeleted = @(New-Button "GELÖSCHT" $Colors.Surface $Colors.Text 105 36)[-1]
    $tabDeleted = Assert-Control $tabDeleted "tabDeleted"
$tabArchive = @(New-Button "VORHERIGE CHATS" $Colors.Surface $Colors.Text 150 36)[-1]
    $tabArchive = Assert-Control $tabArchive "tabArchive"
$tableTabs.Controls.AddRange(@($tabAll,$tabHits,$tabDeleted,$tabArchive))
$tableHost.Controls.Add($tableTabs)

$grid = New-Object System.Windows.Forms.DataGridView
$grid.Dock = "Fill"
$grid.Top = 38
$grid.BackgroundColor = $Colors.Surface
$grid.BorderStyle = "None"
$grid.GridColor = $Colors.BorderSoft
$grid.EnableHeadersVisualStyles = $false
$grid.ColumnHeadersDefaultCellStyle.BackColor = $Colors.Surface2
$grid.ColumnHeadersDefaultCellStyle.ForeColor = $Colors.Muted
$grid.ColumnHeadersDefaultCellStyle.Font = New-Font 9 ([System.Drawing.FontStyle]::Bold)
$grid.ColumnHeadersHeight = 36
$grid.DefaultCellStyle.BackColor = $Colors.Surface
$grid.DefaultCellStyle.ForeColor = $Colors.Text
$grid.DefaultCellStyle.SelectionBackColor = $Colors.Surface3
$grid.DefaultCellStyle.SelectionForeColor = $Colors.Text
$grid.DefaultCellStyle.Font = New-Font 9
$grid.RowHeadersVisible = $false
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.AllowUserToResizeRows = $false
$grid.ReadOnly = $true
$grid.AutoSizeRowsMode = "None"
$grid.RowTemplate.Height = 36
$grid.SelectionMode = "FullRowSelect"
$grid.MultiSelect = $false
$grid.AutoGenerateColumns = $false

$columns = @(
    @("Zeit","Zeit",90),
    @("Nutzer","Nutzer",170),
    @("Rolle","Rolle",125),
    @("Nachricht","Nachricht",420),
    @("Regel","Regel",140),
    @("Aktion","Aktion",120),
    @("Begründung","Begründung",240)
)
foreach($spec in $columns){
    $col = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $col.Name=$spec[0]; $col.HeaderText=$spec[1]; $col.Width=$spec[2]
    if($spec[0] -in @("Nachricht","Begründung")) { $col.AutoSizeMode="Fill" }
    $grid.Columns.Add($col) | Out-Null
}
Enable-EmojiColoring $grid
$tableHost.Controls.Add($grid)
$grid.BringToFront()
$tableTabs.BringToFront()

# Schnelle Einzelprüfung direkt unter dem YouTube-Livechat.
$quickCheckPanel=New-Panel $Colors.Window "Bottom"
$quickCheckPanel.Height=88
$quickCheckPanel.Padding=[System.Windows.Forms.Padding]::new(8,4,8,6)
Set-CardBorder $quickCheckPanel $Colors.BorderSoft 1
$quickCheckTitle=@(New-Label "NACHRICHT PRÜFEN" 8 $Colors.Cyan2 ([System.Drawing.FontStyle]::Bold))[-1]
$quickCheckTitle.Location=[System.Drawing.Point]::new(8,3)
$quickCheckTitle.Size=[System.Drawing.Size]::new(180,20)
$quickCheckInput=New-Object System.Windows.Forms.TextBox
$quickCheckInput.BackColor=$Colors.Surface
$quickCheckInput.ForeColor=$Colors.Text
$quickCheckInput.BorderStyle="FixedSingle"
$quickCheckInput.Font=New-Font 9
$quickCheckInput.Location=[System.Drawing.Point]::new(8,25)
$quickCheckInput.Size=[System.Drawing.Size]::new(220,28)
$quickCheckInput.Text=""
$quickCheckButton=@(New-Button "Text prüfen" $Colors.Blue $Colors.Text 110 30)[-1]
$quickCheckButton.Location=[System.Drawing.Point]::new(238,24)
$quickCheckResult=@(New-Label "Doppelklick auf eine Chatnachricht übernimmt den Text hierher." 9 $Colors.Muted)[-1]
$quickCheckResult.Location=[System.Drawing.Point]::new(8,57)
$quickCheckResult.Size=[System.Drawing.Size]::new(330,23)
$quickCheckPanel.Controls.AddRange(@($quickCheckTitle,$quickCheckInput,$quickCheckButton,$quickCheckResult))
$quickCheckPanel.Add_Resize({$quickCheckButton.Left=[Math]::Max(130,$quickCheckPanel.ClientSize.Width-118);$quickCheckInput.Width=[Math]::Max(110,$quickCheckButton.Left-16);$quickCheckResult.Width=[Math]::Max(220,$quickCheckPanel.ClientSize.Width-18)})
$liveChatHost.Controls.Add($quickCheckPanel)
$quickCheckPanel.BringToFront()

$copyMessageToQuickCheck={param($sender,$eventArgs);if($eventArgs.RowIndex-ge 0){$source=$sender.Rows[$eventArgs.RowIndex].Tag;if($null-ne $source){$quickCheckInput.Text=[string]$source.text;$quickCheckInput.Focus();$quickCheckInput.SelectionStart=$quickCheckInput.TextLength;$quickCheckResult.Text="Nachricht übernommen. Jetzt auf Text prüfen klicken."}}}
$grid.Add_CellDoubleClick($copyMessageToQuickCheck)
$liveChatGrid.Add_CellDoubleClick($copyMessageToQuickCheck)

# ---------- Footer ----------
$footer = New-Panel $Colors.Window "Fill"
$mainLayout.Controls.Add($footer,0,6)
$footerItems = @(
    @("SYSTEM STATUS","●  ONLINE",$Colors.Green),
    @("REGELN AKTIV","2",$Colors.Text),
    @("MODERATOREN ONLINE","—",$Colors.Text),
    @("DATENBANK","●  OK",$Colors.Green),
    @("UPTIME","—",$Colors.Text)
)
$x=0
$footerValues=@{}
foreach($item in $footerItems){
    $isModeratorBox = $item[0] -eq "MODERATOREN ONLINE"
    $boxWidth = $(if($isModeratorBox){240}else{190})
    $box=New-Panel $Colors.Surface
    $box.Location=[System.Drawing.Point]::new($x,4)
    $box.Size=[System.Drawing.Size]::new($boxWidth,30)
    Set-CardBorder $box $Colors.BorderSoft 1
    $lab = @(New-Label $item[0] 8 $Colors.Muted ([System.Drawing.FontStyle]::Bold))[-1]
    $lab = Assert-Control $lab "lab"
    $lab.Location=[System.Drawing.Point]::new(10,5)
    $lab.Size=[System.Drawing.Size]::new($(if($isModeratorBox){145}else{105}),18)
    $val = @(New-Label $item[1] 8 $item[2] ([System.Drawing.FontStyle]::Bold))[-1]
    $val = Assert-Control $val "val"
    $val.Location=[System.Drawing.Point]::new($(if($isModeratorBox){158}else{116}),5)
    $val.Size=[System.Drawing.Size]::new($(if($isModeratorBox){72}else{66}),18)
    $box.Controls.AddRange(@($lab,$val))
    $footer.Controls.Add($box)
    $footerValues[$item[0]]=$val
    $x+=($boxWidth+10)
}

$searchCountdownPanel = New-Panel $Colors.Surface
$searchCountdownPanel.Size = [System.Drawing.Size]::new(190,30)
$searchCountdownPanel.Anchor = "Top,Right"
Set-CardBorder $searchCountdownPanel $Colors.BorderSoft 1
$searchCountdownPanel.Add_Paint({
    param($sender,$eventArgs)
    $graphics = $eventArgs.Graphics
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $state = [string]$script:LastStatusState
    $isLive = $state -eq "connected"
    $isWaiting = $state -in @("waiting","starting")
    $color = $(if($isLive){$Colors.Green}elseif($isWaiting){$Colors.Yellow}else{$Colors.Red})
    $progress = $(if($isLive){1.0}elseif($isWaiting){[Math]::Max(0.0,[Math]::Min(1.0,[double]$script:SearchProgress))}else{0.0})

    $trackPen = New-Object System.Drawing.Pen($Colors.BorderSoft,3)
    $progressPen = New-Object System.Drawing.Pen($color,3)
    $progressPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $progressPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawEllipse($trackPen,8,5,20,20)
    if($progress -gt 0){ $graphics.DrawArc($progressPen,8,5,20,20,-90,[single](360*$progress)) }

    $caption = $(if($isLive){"LIVE"}elseif($isWaiting){"SUCHE IN  " + [int]$script:SearchCountdownSeconds + " s"}else{"SUCHE ANGEHALTEN"})
    $font = New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold)
    $brush = New-Object System.Drawing.SolidBrush($color)
    $graphics.DrawString($caption,$font,$brush,38,7)
    $brush.Dispose(); $font.Dispose(); $progressPen.Dispose(); $trackPen.Dispose()
})
$footer.Controls.Add($searchCountdownPanel)

$manualSearchButton = @(New-Button "Jetzt suchen" $Colors.Blue $Colors.Text 112 30)[-1]
$manualSearchButton.Anchor = "Top,Right"
$manualSearchButton.Enabled = $true
$manualSearchButton.Add_Click({
    try {
        (Get-Date).ToString("o") | Set-Content -LiteralPath $script:ManualSearchWindows -Encoding ASCII
        $script:ManualSearchRequestedAt = Get-Date
        $script:SearchCountdownSeconds = 0
        $script:SearchProgress = 1.0
        $manualSearchButton.Text = "Suche …"
        $manualSearchButton.Enabled = $false
        $searchCountdownPanel.Invalidate()
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Die manuelle Suche konnte nicht gestartet werden:`n`n" + $_.Exception.Message,"Livestream-Suche",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    }
})
$footer.Controls.Add($manualSearchButton)
$footer.Add_Resize({
    $searchCountdownPanel.Left = [Math]::Max(0,$footer.ClientSize.Width-$searchCountdownPanel.Width)
    $searchCountdownPanel.Top = 4
    $manualSearchButton.Left = [Math]::Max(0,$searchCountdownPanel.Left-$manualSearchButton.Width-8)
    $manualSearchButton.Top = 4
})

# ---------- Render ----------
function Update-Ring {
    param($Chart, [double]$Percent, [System.Drawing.Color]$Color)
    $p=[Math]::Max(0,[Math]::Min(100,$Percent))
    $Chart.Series[0].Points[0].YValues[0]=$p
    $Chart.Series[0].Points[1].YValues[0]=100-$p
    $Chart.Series[0].Points[0].Color=$Color
}

function Update-HistoryCharts {
    $msgHistoryChart.Series[0].Points.Clear()
    $hitHistoryChart.Series[0].Points.Clear()

    $buckets=@{}
    for($i=11;$i -ge 0;$i--){ $buckets[(Get-Date).AddMinutes(-5*$i).ToString("HH:mm")] = @(0,0) }

    foreach($r in $script:AllRows){
        try {
            $dt=([datetimeoffset]::Parse([string]$(if($r.publishedAt){$r.publishedAt}else{$r.receivedAt}))).ToLocalTime()
            $minute=[Math]::Floor($dt.Minute/5)*5
            $key=(Get-Date -Hour $dt.Hour -Minute $minute -Second 0).ToString("HH:mm")
            if($buckets.ContainsKey($key)){
                $arr=$buckets[$key]; $arr[0]++
                if($r.flagged){$arr[1]++}
                $buckets[$key]=$arr
            }
        } catch {}
    }

    foreach($key in $buckets.Keys){
        $msgHistoryChart.Series[0].Points.AddXY($key,$buckets[$key][0]) | Out-Null
        $hitHistoryChart.Series[0].Points.AddXY($key,$buckets[$key][1]) | Out-Null
    }
}

function Update-RuleBars {
    $counts=@{
        "Wiederholung"=0
        "Beleidigung"=0
        "Links / Werbung"=0
        "Großschreibung"=0
        "Andere"=0
    }
    foreach($r in $script:FlaggedRows){
        $name=Get-RuleName $r
        if($counts.ContainsKey($name)){ $counts[$name]++ } else { $counts["Andere"]++ }
    }
    $max=[Math]::Max(1,($counts.Values | Measure-Object -Maximum).Maximum)
    foreach($name in $counts.Keys){
        $value=$counts[$name]
        $ruleBars[$name].Width=[Math]::Max(1,[int](130*$value/$max))
        $ruleLabels[$name].Text=[string]$value
    }
}

function Render-Grid {
    $grid.Rows.Clear()
    $rows=Get-FilteredRows
    foreach($r in @($rows | Select-Object -Last 300 | Sort-Object @{Expression={try{[datetimeoffset]::Parse([string]$(if($_.publishedAt){$_.publishedAt}else{$_.receivedAt}))}catch{[datetimeoffset]::MinValue}};Descending=$true})){
        $idx=$grid.Rows.Add(
            (Format-Time $(if($r.publishedAt){$r.publishedAt}else{$r.receivedAt})),
            [string]$r.authorName,
            (Get-RoleText $r),
            [string]$r.text,
            (Get-RuleName $r),
            (Get-ActionText $r),
            (Get-ReasonText $r)
        )
        $row=$grid.Rows[$idx]
        $row.Tag=$r
        if($r.deleted){
            $row.DefaultCellStyle.BackColor=[System.Drawing.Color]::FromArgb(61,11,23)
            $row.Cells["Aktion"].Style.ForeColor=$Colors.Red
        } elseif($r.isModerator){
            $row.DefaultCellStyle.BackColor=[System.Drawing.Color]::FromArgb(11,42,72)
            $row.Cells["Rolle"].Style.ForeColor=$Colors.Green
        } elseif($r.isOwner){
            $row.DefaultCellStyle.BackColor=[System.Drawing.Color]::FromArgb(65,45,5)
        } elseif($r.isSponsor){
            $row.DefaultCellStyle.BackColor=[System.Drawing.Color]::FromArgb(10,49,35)
        } elseif($r.flagged){
            $row.DefaultCellStyle.BackColor=[System.Drawing.Color]::FromArgb(39,17,31)
            $row.Cells["Aktion"].Style.ForeColor=$Colors.Yellow
        }
    }
}

function Set-Mode([string]$Mode) {
    $script:CurrentMode=$Mode
    foreach($b in @($btnAll,$btnHits,$btnDeleted,$tabAll,$tabHits,$tabDeleted,$tabArchive)){
        $b.BackColor=$Colors.Surface
        $b.ForeColor=$Colors.Text
    }
    switch($Mode){
        "all" { $btnAll.BackColor=$Colors.Blue; $tabAll.BackColor=$Colors.Blue }
        "flagged" { $btnHits.BackColor=$Colors.Blue; $tabHits.BackColor=$Colors.Blue }
        "deleted" { $btnDeleted.BackColor=$Colors.Blue; $tabDeleted.BackColor=$Colors.Blue }
        "archive" { $tabArchive.BackColor=$Colors.Blue }
    }
    Render-Grid
}

function Refresh-Dashboard {
    $status=Read-Status
    if($status){
        $state=[string]$status.state
        $script:LastStatusState=$state
        $online=$state -eq "connected"
        $waiting=$state -in @("waiting", "starting")
        if($waiting -and (Test-Path -LiteralPath $script:StatusWindows)){
            $statusAge = [Math]::Max(0.0,((Get-Date)-(Get-Item -LiteralPath $script:StatusWindows).LastWriteTime).TotalSeconds)
            $elapsed = [Math]::Min([double]$script:SearchIntervalSeconds,$statusAge)
            $script:SearchCountdownSeconds = [Math]::Max(0,[Math]::Ceiling($script:SearchIntervalSeconds-$elapsed))
            $script:SearchProgress = $elapsed / $script:SearchIntervalSeconds
        } elseif($online) {
            $script:SearchCountdownSeconds = 0
            $script:SearchProgress = 1.0
        } else {
            $script:SearchCountdownSeconds = 0
            $script:SearchProgress = 0.0
        }

        if($online){
            $statusMain.Text="ONLINE"
            $statusDot.ForeColor=$Colors.Green
            $connMain.Text="Verbunden"
            $connMain.ForeColor=$Colors.Green
            $channelState.Text="●  Online"
            $channelState.ForeColor=$Colors.Green
            $footerValues["SYSTEM STATUS"].Text="●  ONLINE"
            $footerValues["SYSTEM STATUS"].ForeColor=$Colors.Green
        } elseif($waiting){
            $statusMain.Text="BEREIT"
            $statusDot.ForeColor=$Colors.Yellow
            $connMain.Text="Verbunden"
            $connMain.ForeColor=$Colors.Yellow
            $channelState.Text="●  Wartet auf Stream"
            $channelState.ForeColor=$Colors.Yellow
            $footerValues["SYSTEM STATUS"].Text="●  BEREIT"
            $footerValues["SYSTEM STATUS"].ForeColor=$Colors.Yellow
        } else {
            $statusMain.Text="OFFLINE"
            $statusDot.ForeColor=$Colors.Red
            $connMain.Text="Getrennt"
            $connMain.ForeColor=$Colors.Red
            $channelState.Text="●  Offline"
            $channelState.ForeColor=$Colors.Red
            $footerValues["SYSTEM STATUS"].Text="●  OFFLINE"
            $footerValues["SYSTEM STATUS"].ForeColor=$Colors.Red
        }

        if($null -ne $script:ManualSearchRequestedAt -and (Test-Path -LiteralPath $script:StatusWindows)){
            if((Get-Item -LiteralPath $script:StatusWindows).LastWriteTime -gt $script:ManualSearchRequestedAt){
                $script:ManualSearchRequestedAt = $null
                $manualSearchButton.Text = "Jetzt suchen"
            }
        }
        $manualSearchButton.Enabled = $waiting -and ($null -eq $script:ManualSearchRequestedAt)
        if(-not $waiting -and $null -eq $script:ManualSearchRequestedAt){ $manualSearchButton.Text = "Jetzt suchen" }

        $script:CurrentStreamUrl = [string]$status.url
        $script:CurrentVideoId = [string]$status.videoId
        $script:CurrentLiveChatId = [string]$status.liveChatId
        if ([string]::IsNullOrWhiteSpace($script:PendingChatRequestId)) {
            $canWriteChat = $online -and -not [string]::IsNullOrWhiteSpace($script:CurrentLiveChatId)
            $chatInput.Enabled = $canWriteChat
            $chatSendButton.Enabled = $canWriteChat
            if (-not $canWriteChat) { $chatSendButton.Text = "Senden" }
        }

        if ($online) {
            $liveStreamName.Text = $(if($status.title){[string]$status.title}else{"Livestream aktiv"})
            $liveStatusLabel.Text = "LIVE"
            $liveStatusLabel.ForeColor = $Colors.Green
            $liveUrlLabel.Text = [string]$status.url
            $openStreamButton.Enabled = -not [string]::IsNullOrWhiteSpace($script:CurrentStreamUrl)
            $livePreviewPlaceholder.Text = "LIVE`n" + $liveStreamName.Text + "`n`nZum Abspielen klicken"
            $livePreviewPlaceholder.ForeColor = $Colors.Cyan2
            $livePreviewPlaceholder.Cursor = [System.Windows.Forms.Cursors]::Hand
            Set-LiveVideoPlayer ([string]$status.videoId)
            Set-OfficialYouTubeChat ([string]$status.videoId)
        } else {
            $liveStreamName.Text = $(if($waiting){"Warte auf Livestream"}else{"Kein Livestream aktiv"})
            $liveStatusLabel.Text = $(if($waiting){"WARTET"}else{"OFFLINE"})
            $liveStatusLabel.ForeColor = $(if($waiting){$Colors.Yellow}else{$Colors.Red})
            $liveUrlLabel.Text = ""
            $openStreamButton.Enabled = $false
            $livePreviewPlaceholder.Text = $(if($waiting){"Warte auf Livestream"}else{"Kein Livestream aktiv"})
            $livePreviewPlaceholder.ForeColor = $(if($waiting){$Colors.Yellow}else{$Colors.Muted})
            $livePreviewPlaceholder.Cursor = [System.Windows.Forms.Cursors]::Default
            Set-LiveVideoPlayer ""
            Set-OfficialYouTubeChat ""
        }

        if($status.allLog){ $script:AllRows=Read-JsonlLinux ([string]$status.allLog) }
        if($status.flaggedLog){ $script:FlaggedRows=Read-JsonlLinux ([string]$status.flaggedLog) }
    }

    $allCount=$script:AllRows.Count
    $hitCount=$script:FlaggedRows.Count
    $deletedCount=@($script:AllRows | Where-Object {$_.deleted}).Count

    $msgValue.Text="{0:N0}" -f $allCount
    $hitValue.Text="{0:N0}" -f $hitCount
    $deletePct=if($allCount -gt 0){[Math]::Round(100*$deletedCount/$allCount,1)}else{0}
    $deletePercent.Text="$deletePct%"
    $deleteInfo.Text="Gelöschte Nachrichten`n$deletedCount`n`nGesamt Nachrichten`n$allCount"

    Update-Ring $msgChart ($(if($allCount -gt 0){75}else{0})) $Colors.Cyan
    Update-Ring $hitChart ($(if($allCount -gt 0){[Math]::Min(100,100*$hitCount/[Math]::Max(1,$allCount))}else{0})) $Colors.Red
    Update-Ring $deleteChart $deletePct $Colors.Cyan

    Update-HistoryCharts
    Update-RuleBars
    Render-Grid
    Render-LiveChatPreview
    Update-LiveChatSendResult
    Update-EmergencyCard
    $searchCountdownPanel.Invalidate()
}

function Export-Current {
    $rows=Get-FilteredRows
    $dialog=New-Object System.Windows.Forms.SaveFileDialog
    $fmt=[string]$formatBox.SelectedItem
    $stamp=(Get-Date).AddHours(-6).ToString("yyyyMMdd-HHmmss")
    switch($fmt){
        "CSV" {$dialog.Filter="CSV (*.csv)|*.csv";$dialog.FileName="Chatwaechter-$stamp.csv"}
        "JSON" {$dialog.Filter="JSON (*.json)|*.json";$dialog.FileName="Chatwaechter-$stamp.json"}
        "PDF" {$dialog.Filter="PDF (*.pdf)|*.pdf";$dialog.FileName="Chatwaechter-$stamp.pdf"}
        default {$dialog.Filter="PNG (*.png)|*.png";$dialog.FileName="Chatwaechter-$stamp.png"}
    }
    if($dialog.ShowDialog() -ne "OK"){return}

    if($fmt -eq "CSV"){
        $data=@()
        foreach($r in $rows){
            $data += [pscustomobject]@{
                Zeit=Format-Time $(if($r.publishedAt){$r.publishedAt}else{$r.receivedAt})
                Nutzer=$r.authorName
                Rolle=Get-RoleText $r
                Nachricht=$r.text
                Regel=Get-RuleName $r
                Aktion=Get-ActionText $r
                Begründung=Get-ReasonText $r
            }
        }
        $data | Export-Csv -NoTypeInformation -Delimiter ";" -Encoding UTF8 -Path $dialog.FileName
    } elseif($fmt -eq "JSON"){
        $rows | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -Path $dialog.FileName
    } else {
        # Bildschirmaufnahme des Dashboards; für PDF über Edge/Chrome-Druck ist der bestehende
        # Exportweg weiterhin im Paket dokumentiert. PNG wird direkt gespeichert.
        $bmp=New-Object System.Drawing.Bitmap($form.ClientSize.Width,$form.ClientSize.Height)
        $form.DrawToBitmap($bmp,([System.Drawing.Rectangle]::new(0,0,$bmp.Width,$bmp.Height)))
        if($fmt -eq "PNG"){
            $bmp.Save($dialog.FileName,[System.Drawing.Imaging.ImageFormat]::Png)
        } else {
            $temp=[IO.Path]::ChangeExtension($dialog.FileName,"png")
            $bmp.Save($temp,[System.Drawing.Imaging.ImageFormat]::Png)
            [System.Windows.Forms.MessageBox]::Show(
                "Das Dashboard wurde zunächst als PNG gespeichert:`n$temp`n`nPDF-Export benötigt Edge/Chrome und bleibt über den bisherigen Exportweg möglich.",
                "PDF-Hinweis"
            ) | Out-Null
        }
        $bmp.Dispose()
    }
}


function New-ToolDialog {
    param([string]$Title, [int]$Width = 920, [int]$Height = 650)

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = "Chatwächter · " + $Title
    $dialog.Size = [System.Drawing.Size]::new($Width,$Height)
    $dialog.StartPosition = "CenterParent"
    $dialog.BackColor = $Colors.Window
    $dialog.ForeColor = $Colors.Text
    $dialog.Font = New-Font 9
    return $dialog
}

function Add-DialogTitle {
    param(
        [System.Windows.Forms.Form]$Dialog,
        [string]$TitleText,
        [string]$SubtitleText = ""
    )

    if ($null -eq $Dialog) {
        throw "Dialog ist NULL."
    }

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = $TitleText
    $titleLabel.ForeColor = $Colors.Text
    $titleLabel.BackColor = [System.Drawing.Color]::Transparent
    $titleLabel.Font = New-Font 18 ([System.Drawing.FontStyle]::Bold)
    $titleLabel.Location = [System.Drawing.Point]::new(18,14)
    $titleLabel.Size = [System.Drawing.Size]::new(760,34)
    [void]$Dialog.Controls.Add($titleLabel)

    if (-not [string]::IsNullOrWhiteSpace($SubtitleText)) {
        $subtitleLabel = New-Object System.Windows.Forms.Label
        $subtitleLabel.Text = $SubtitleText
        $subtitleLabel.ForeColor = $Colors.Muted
        $subtitleLabel.BackColor = [System.Drawing.Color]::Transparent
        $subtitleLabel.Font = New-Font 9
        $subtitleLabel.Location = [System.Drawing.Point]::new(20,48)
        $subtitleLabel.Size = [System.Drawing.Size]::new(820,26)
        [void]$Dialog.Controls.Add($subtitleLabel)
    }
}

function Show-LiveDialog {
    $d = @(New-ToolDialog "Live Monitoring")[-1]
    $d = Assert-Control $d "Dialog"
    Add-DialogTitle $d "LIVE MONITORING" "Aktueller Streamstatus und direkter Zugriff"

    $status = Read-Status
    $text = if ($status) {
        "Status: " + [string]$status.state + "`n" +
        "Titel: " + [string]$status.title + "`n" +
        "Video-ID: " + [string]$status.videoId + "`n" +
        "URL: " + [string]$status.url + "`n" +
        "Nachrichten: " + [string]$status.messageCount
    } else {
        "Keine Statusdaten vorhanden."
    }

    $box = New-Object System.Windows.Forms.TextBox
    $box.Multiline = $true
    $box.ReadOnly = $true
    $box.BackColor = $Colors.Surface
    $box.ForeColor = $Colors.Text
    $box.Location = [System.Drawing.Point]::new(20,90)
    $box.Size = [System.Drawing.Size]::new(850,180)
    $box.Text = $text
    $d.Controls.Add($box)

    $open = @(New-Button "Livestream öffnen" $Colors.Blue $Colors.Text 170 40)[-1]
    $open = Assert-Control $open "open"
    $open.Location = [System.Drawing.Point]::new(20,290)
    $open.Enabled = ($status -and -not [string]::IsNullOrWhiteSpace([string]$status.url))
    $open.Add_Click({
        if ($status -and $status.url) { Start-Process ([string]$status.url) }
    })
    $d.Controls.Add($open)

    [void]$d.ShowDialog($form)
}

function Show-MessagesDialog {
    $d = @(New-ToolDialog "Nachrichten" 1100 720)[-1]
    $d = Assert-Control $d "Dialog"
    Add-DialogTitle $d "NACHRICHTEN" "Aktueller Chat"

    $g = New-Object System.Windows.Forms.DataGridView
    $g.Location = [System.Drawing.Point]::new(18,82)
    $g.Size = [System.Drawing.Size]::new(1045,570)
    $g.BackgroundColor = $Colors.Surface
    $g.ForeColor = $Colors.Text
    $g.GridColor = $Colors.BorderSoft
    $g.RowHeadersVisible = $false
    $g.AllowUserToAddRows = $false
    $g.ReadOnly = $true
    $g.AutoGenerateColumns = $false
    $g.EnableHeadersVisualStyles = $false
    $g.ColumnHeadersDefaultCellStyle.BackColor = $Colors.Surface2
    $g.ColumnHeadersDefaultCellStyle.ForeColor = $Colors.Muted
    $g.DefaultCellStyle.BackColor = $Colors.Surface
    $g.DefaultCellStyle.ForeColor = $Colors.Text

    foreach ($spec in @(
        @("Zeit","Zeit",90),@("Nutzer","Nutzer",160),@("Rolle","Rolle",110),
        @("Nachricht","Nachricht",420),@("Aktion","Aktion",120),@("Grund","Begründung",230)
    )) {
        $c = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $c.Name=$spec[0]; $c.HeaderText=$spec[1]; $c.Width=$spec[2]
        if ($spec[0] -in @("Nachricht","Grund")) { $c.AutoSizeMode="Fill" }
        [void]$g.Columns.Add($c)
    }
    Enable-EmojiColoring $g

    foreach ($r in @($script:AllRows | Select-Object -Last 1000)) {
        [void]$g.Rows.Add(
            (Format-Time $(if($r.publishedAt){$r.publishedAt}else{$r.receivedAt})),
            [string]$r.authorName,
            (Get-RoleText $r),
            [string]$r.text,
            (Get-ActionText $r),
            (Get-ReasonText $r)
        )
    }

    $d.Controls.Add($g)
    [void]$d.ShowDialog($form)
}


function Save-RulesObject {
    param(
        [object]$RulesObject,
        [string]$DialogTitle = "Regeln"
    )

    $path = Join-Path $script:Folder "rules.json"

    try {
        $json = $RulesObject | ConvertTo-Json -Depth 20
        $null = $json | ConvertFrom-Json
        [System.IO.File]::WriteAllText(
            $path,
            $json,
            (New-Object System.Text.UTF8Encoding($false))
        )

        $b64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($path))
        $result = Invoke-WslCommand @(
            "python3","-c",
            "import base64,sys;open(sys.argv[1],'wb').write(base64.b64decode(sys.stdin.read()))",
            "$script:BaseLinux/rules.json"
        ) $b64

        if ($result.ExitCode -ne 0) {
            throw (($result.StdErr + "`n" + $result.StdOut).Trim())
        }

        [System.Windows.Forms.MessageBox]::Show(
            "Gespeichert und nach WSL übertragen.",
            $DialogTitle,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null

        return $true
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Speichern fehlgeschlagen:`n`n" + $_.Exception.Message,
            $DialogTitle,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null

        return $false
    }
}

function Get-RulesObject {
    $path = Join-Path $script:Folder "rules.json"

    try {
        return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            mode = "active_moderation"
            exempt_owner = $true
            exempt_moderators = $true
            emoji_rule = [pscustomobject]@{
                enabled = $false
                max_count = 8
                action = "flag"
            }
            uppercase = [pscustomobject]@{
                enabled = $true
                min_letters = 12
                min_ratio = 0.8
                action = "delete"
            }
            insults = [pscustomobject]@{
                enabled = $true
                action = "delete"
                terms = @()
            }
            custom_rules = @()
        }
    }
}

function Ensure-RuleProperties {
    param([object]$Rules)

    if ($null -eq $Rules.PSObject.Properties["emoji_rule"]) {
        $Rules | Add-Member -NotePropertyName emoji_rule -NotePropertyValue ([pscustomobject]@{
            enabled = [bool]$Rules.emoji_rule_enabled
            max_count = 8
            action = "flag"
        })
    }

    if ($null -eq $Rules.PSObject.Properties["custom_rules"]) {
        $Rules | Add-Member -NotePropertyName custom_rules -NotePropertyValue @()
    }

    return $Rules
}

function Get-ActionChoices {
    return @("Nur markieren","Nachricht löschen","Stumm 5 Minuten","Stumm 10 Minuten","Stumm 30 Minuten","Stumm 1 Stunde","Stumm 24 Stunden","Nutzer dauerhaft blockieren")
}

function ConvertTo-ActionLabel([string]$Value) {
    switch ($Value) {
        "delete" { return "Nachricht löschen" }; "timeout_300" { return "Stumm 5 Minuten" }
        "timeout_600" { return "Stumm 10 Minuten" }; "timeout_1800" { return "Stumm 30 Minuten" }
        "timeout_3600" { return "Stumm 1 Stunde" }; "timeout_86400" { return "Stumm 24 Stunden" }
        "block" { return "Nutzer dauerhaft blockieren" }; default { return "Nur markieren" }
    }
}

function ConvertFrom-ActionLabel([string]$Value) {
    switch ($Value) {
        "Nachricht löschen" { return "delete" }; "Stumm 5 Minuten" { return "timeout_300" }
        "Stumm 10 Minuten" { return "timeout_600" }; "Stumm 30 Minuten" { return "timeout_1800" }
        "Stumm 1 Stunde" { return "timeout_3600" }; "Stumm 24 Stunden" { return "timeout_86400" }
        "Nutzer dauerhaft blockieren" { return "block" }; default { return "flag" }
    }
}

function New-RuleEditorDialog {
    param(
        [string]$Title,
        [string]$Subtitle,
        [int]$Width = 720,
        [int]$Height = 620
    )

    $dialog = @(New-ToolDialog $Title $Width $Height)[-1]
    $dialog = Assert-Control $dialog $Title
    Add-DialogTitle $dialog $Title.ToUpperInvariant() $Subtitle
    return $dialog
}

function Show-InsultsEditor {
    param([object]$Rules)

    $d = New-RuleEditorDialog "Beleidigungen" "Begriffe bearbeiten und separat speichern" 760 670

    $enabled = New-Object System.Windows.Forms.CheckBox
    $enabled.Text = "Regel aktiv"
    $enabled.Checked = [bool]$Rules.insults.enabled
    $enabled.ForeColor = $Colors.Text
    $enabled.BackColor = $Colors.Surface
    $enabled.Location = [System.Drawing.Point]::new(22,88)
    $enabled.AutoSize = $true

    $actionLabel = @(New-Label "Aktion" 10 $Colors.Muted)[-1]
    $actionLabel.Location = [System.Drawing.Point]::new(22,126)
    $actionLabel.AutoSize = $true

    $action = New-Object System.Windows.Forms.ComboBox
    $action.DropDownStyle = "DropDownList"
    [void]$action.Items.AddRange(@(Get-ActionChoices))
    $action.SelectedItem = ConvertTo-ActionLabel ([string]$Rules.insults.action)
    if ($action.SelectedIndex -lt 0) { $action.SelectedIndex = 0 }
    $action.Location = [System.Drawing.Point]::new(22,150)
    $action.Size = [System.Drawing.Size]::new(300,30)

    $hint = @(New-Label "Ein Begriff pro Zeile" 10 $Colors.Muted)[-1]
    $hint.Location = [System.Drawing.Point]::new(22,194)
    $hint.AutoSize = $true

    $terms = New-Object System.Windows.Forms.TextBox
    $terms.Multiline = $true
    $terms.ScrollBars = "Vertical"
    $terms.WordWrap = $false
    $terms.Font = New-Font 11
    $terms.BackColor = $Colors.Surface
    $terms.ForeColor = $Colors.Text
    $terms.Location = [System.Drawing.Point]::new(22,220)
    $terms.Size = [System.Drawing.Size]::new(700,340)
    $terms.Text = (@($Rules.insults.terms) -join "`r`n")

    $save = @(New-Button "Beleidigungen speichern" $Colors.Blue $Colors.Text 220 42)[-1]
    $save.Location = [System.Drawing.Point]::new(22,585)
    $save.Add_Click({
        $Rules.insults.enabled = [bool]$enabled.Checked
        $Rules.insults.action = ConvertFrom-ActionLabel ([string]$action.SelectedItem)
        $Rules.insults.terms = @(
            $terms.Lines |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
        )

        if (Save-RulesObject $Rules "Beleidigungen") {
            $d.Close()
        }
    })

    $d.Controls.AddRange(@($enabled,$actionLabel,$action,$hint,$terms,$save))
    [void]$d.ShowDialog($form)
}

function Show-EmojiEditor {
    param([object]$Rules)

    $d = New-RuleEditorDialog "Emoji-Regel" "Grenzwert und Aktion bearbeiten" 650 470

    $enabled = New-Object System.Windows.Forms.CheckBox
    $enabled.Text = "Emoji-Regel aktiv"
    $enabled.Checked = [bool]$Rules.emoji_rule.enabled
    $enabled.ForeColor = $Colors.Text
    $enabled.BackColor = $Colors.Surface
    $enabled.Location = [System.Drawing.Point]::new(22,95)
    $enabled.AutoSize = $true

    $countLabel = @(New-Label "Maximal erlaubte Emojis pro Nachricht" 10 $Colors.Muted)[-1]
    $countLabel.Location = [System.Drawing.Point]::new(22,145)
    $countLabel.AutoSize = $true

    $count = New-Object System.Windows.Forms.NumericUpDown
    $count.Minimum = 1
    $count.Maximum = 100
    $count.Value = [decimal]([Math]::Max(1,[int]$Rules.emoji_rule.max_count))
    $count.Location = [System.Drawing.Point]::new(22,172)
    $count.Size = [System.Drawing.Size]::new(140,30)

    $actionLabel = @(New-Label "Aktion bei Überschreitung" 10 $Colors.Muted)[-1]
    $actionLabel.Location = [System.Drawing.Point]::new(22,225)
    $actionLabel.AutoSize = $true

    $action = New-Object System.Windows.Forms.ComboBox
    $action.DropDownStyle = "DropDownList"
    [void]$action.Items.AddRange(@(Get-ActionChoices))
    $action.SelectedItem = ConvertTo-ActionLabel ([string]$Rules.emoji_rule.action)
    if ($action.SelectedIndex -lt 0) { $action.SelectedIndex = 0 }
    $action.Location = [System.Drawing.Point]::new(22,252)
    $action.Size = [System.Drawing.Size]::new(300,30)

    $save = @(New-Button "Emoji-Regel speichern" $Colors.Blue $Colors.Text 210 42)[-1]
    $save.Location = [System.Drawing.Point]::new(22,340)
    $save.Add_Click({
        $Rules.emoji_rule.enabled = [bool]$enabled.Checked
        $Rules.emoji_rule.max_count = [int]$count.Value
        $Rules.emoji_rule.action = ConvertFrom-ActionLabel ([string]$action.SelectedItem)
        $Rules.emoji_rule_enabled = [bool]$enabled.Checked

        if (Save-RulesObject $Rules "Emoji-Regel") {
            $d.Close()
        }
    })

    $d.Controls.AddRange(@($enabled,$countLabel,$count,$actionLabel,$action,$save))
    [void]$d.ShowDialog($form)
}

function Show-UppercaseEditor {
    param([object]$Rules)

    $d = New-RuleEditorDialog "Großschreibung" "Schwellenwerte und Aktion bearbeiten" 700 570

    $enabled = New-Object System.Windows.Forms.CheckBox
    $enabled.Text = "Großschreibungsregel aktiv"
    $enabled.Checked = [bool]$Rules.uppercase.enabled
    $enabled.ForeColor = $Colors.Text
    $enabled.BackColor = $Colors.Surface
    $enabled.Location = [System.Drawing.Point]::new(22,92)
    $enabled.AutoSize = $true

    $lettersLabel = @(New-Label "Mindestanzahl Buchstaben" 10 $Colors.Muted)[-1]
    $lettersLabel.Location = [System.Drawing.Point]::new(22,145)
    $lettersLabel.AutoSize = $true

    $letters = New-Object System.Windows.Forms.NumericUpDown
    $letters.Minimum = 1
    $letters.Maximum = 500
    $letters.Value = [decimal]([Math]::Max(1,[int]$Rules.uppercase.min_letters))
    $letters.Location = [System.Drawing.Point]::new(22,172)
    $letters.Size = [System.Drawing.Size]::new(150,30)

    $ratioLabel = @(New-Label "Anteil Großbuchstaben" 10 $Colors.Muted)[-1]
    $ratioLabel.Location = [System.Drawing.Point]::new(22,225)
    $ratioLabel.AutoSize = $true

    $ratio = New-Object System.Windows.Forms.NumericUpDown
    $ratio.Minimum = 10
    $ratio.Maximum = 100
    $ratio.Value = [decimal]([Math]::Round(([double]$Rules.uppercase.min_ratio * 100),0))
    $ratio.Location = [System.Drawing.Point]::new(22,252)
    $ratio.Size = [System.Drawing.Size]::new(150,30)

    $percentLabel = @(New-Label "Prozent" 10 $Colors.Muted)[-1]
    $percentLabel.Location = [System.Drawing.Point]::new(182,256)
    $percentLabel.AutoSize = $true

    $actionLabel = @(New-Label "Aktion" 10 $Colors.Muted)[-1]
    $actionLabel.Location = [System.Drawing.Point]::new(22,305)
    $actionLabel.AutoSize = $true

    $action = New-Object System.Windows.Forms.ComboBox
    $action.DropDownStyle = "DropDownList"
    [void]$action.Items.AddRange(@(Get-ActionChoices))
    $action.SelectedItem = ConvertTo-ActionLabel ([string]$Rules.uppercase.action)
    if ($action.SelectedIndex -lt 0) { $action.SelectedIndex = 0 }
    $action.Location = [System.Drawing.Point]::new(22,332)
    $action.Size = [System.Drawing.Size]::new(300,30)

    $save = @(New-Button "Großschreibung speichern" $Colors.Blue $Colors.Text 230 42)[-1]
    $save.Location = [System.Drawing.Point]::new(22,430)
    $save.Add_Click({
        $Rules.uppercase.enabled = [bool]$enabled.Checked
        $Rules.uppercase.min_letters = [int]$letters.Value
        $Rules.uppercase.min_ratio = [Math]::Round(([double]$ratio.Value / 100),2)
        $Rules.uppercase.action = ConvertFrom-ActionLabel ([string]$action.SelectedItem)

        if (Save-RulesObject $Rules "Großschreibung") {
            $d.Close()
        }
    })

    $d.Controls.AddRange(@(
        $enabled,$lettersLabel,$letters,$ratioLabel,$ratio,$percentLabel,
        $actionLabel,$action,$save
    ))
    [void]$d.ShowDialog($form)
}

function Show-AddRuleEditor {
    param([object]$Rules)

    $d = New-RuleEditorDialog "Regel hinzufügen" "Eigene Begriffsliste als neue Regel anlegen" 760 680

    $nameLabel = @(New-Label "Name der Regel" 10 $Colors.Muted)[-1]
    $nameLabel.Location = [System.Drawing.Point]::new(22,88)
    $nameLabel.AutoSize = $true

    $name = New-Object System.Windows.Forms.TextBox
    $name.Location = [System.Drawing.Point]::new(22,115)
    $name.Size = [System.Drawing.Size]::new(420,32)
    $name.Font = New-Font 11
    $name.BackColor = $Colors.Surface
    $name.ForeColor = $Colors.Text

    $actionLabel = @(New-Label "Aktion" 10 $Colors.Muted)[-1]
    $actionLabel.Location = [System.Drawing.Point]::new(22,165)
    $actionLabel.AutoSize = $true

    $action = New-Object System.Windows.Forms.ComboBox
    $action.DropDownStyle = "DropDownList"
    [void]$action.Items.AddRange(@(Get-ActionChoices))
    $action.SelectedIndex = 0
    $action.Location = [System.Drawing.Point]::new(22,192)
    $action.Size = [System.Drawing.Size]::new(300,30)

    $termsLabel = @(New-Label "Begriffe oder Textteile – ein Eintrag pro Zeile" 10 $Colors.Muted)[-1]
    $termsLabel.Location = [System.Drawing.Point]::new(22,242)
    $termsLabel.AutoSize = $true

    $terms = New-Object System.Windows.Forms.TextBox
    $terms.Multiline = $true
    $terms.ScrollBars = "Vertical"
    $terms.WordWrap = $false
    $terms.Location = [System.Drawing.Point]::new(22,270)
    $terms.Size = [System.Drawing.Size]::new(700,285)
    $terms.Font = New-Font 11
    $terms.BackColor = $Colors.Surface
    $terms.ForeColor = $Colors.Text

    $save = @(New-Button "Neue Regel speichern" $Colors.Blue $Colors.Text 210 42)[-1]
    $save.Location = [System.Drawing.Point]::new(22,585)
    $save.Add_Click({
        $ruleName = $name.Text.Trim()
        $ruleTerms = @(
            $terms.Lines |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
        )

        if ([string]::IsNullOrWhiteSpace($ruleName)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Bitte einen Namen für die Regel eingeben.",
                "Regel hinzufügen","OK","Warning"
            ) | Out-Null
            return
        }

        if ($ruleTerms.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "Bitte mindestens einen Begriff eintragen.",
                "Regel hinzufügen","OK","Warning"
            ) | Out-Null
            return
        }

        $existing = @($Rules.custom_rules)
        $newRule = [pscustomobject]@{
            name = $ruleName
            enabled = $true
            action = ConvertFrom-ActionLabel ([string]$action.SelectedItem)
            terms = $ruleTerms
        }

        $Rules.custom_rules = @($existing + $newRule)

        if (Save-RulesObject $Rules "Regel hinzufügen") {
            $d.Close()
        }
    })

    $d.Controls.AddRange(@(
        $nameLabel,$name,$actionLabel,$action,$termsLabel,$terms,$save
    ))
    [void]$d.ShowDialog($form)
}

function Show-AdvancedRulesDialog {
    param([object]$Rules)
    $d=@(New-ToolDialog "Erweiterte Regeln" 960 700)[-1];$d=Assert-Control $d "Dialog"
    Add-DialogTitle $d "ERWEITERTE REGELN" "Jede Regel direkt über die Checkbox aktivieren oder deaktivieren"
    $names=[ordered]@{
        multiple_links="Mehrere Links";advertising="Werbesätze";contact_data="Kontaktdaten";fraud="Betrugsbegriffe";mentions="Viele Erwähnungen";long_message="Sehr lange Nachrichten";multiline="Mehrzeiliger Zeichenspam";near_duplicate="Fast gleiche Wiederholungen";private_data="Private Daten";threats="Drohungen";hate_speech="Hassrede";sexual_content="Sexuelle Inhalte";spoilers="Spoiler-Regel";topic_filter="Themenfilter";foreign_language="Fremdsprachenregel";repeat_offender="Wiederholungstäter";spam_wave="Spamwellenmodus"
    }
    $advancedGrid=New-Object System.Windows.Forms.DataGridView;$advancedGrid.Location=[System.Drawing.Point]::new(20,85);$advancedGrid.Size=[System.Drawing.Size]::new(900,480);$advancedGrid.BackgroundColor=$Colors.Surface;$advancedGrid.BorderStyle="None";$advancedGrid.GridColor=$Colors.BorderSoft;$advancedGrid.EnableHeadersVisualStyles=$false;$advancedGrid.ColumnHeadersDefaultCellStyle.BackColor=$Colors.Surface2;$advancedGrid.ColumnHeadersDefaultCellStyle.ForeColor=$Colors.Text;$advancedGrid.DefaultCellStyle.BackColor=$Colors.Surface;$advancedGrid.DefaultCellStyle.ForeColor=$Colors.Text;$advancedGrid.DefaultCellStyle.SelectionBackColor=$Colors.Surface3;$advancedGrid.RowHeadersVisible=$false;$advancedGrid.AllowUserToAddRows=$false;$advancedGrid.SelectionMode="FullRowSelect";$advancedGrid.MultiSelect=$false;$advancedGrid.EditMode="EditOnEnter"
    $ruleColumn=New-Object System.Windows.Forms.DataGridViewTextBoxColumn;$ruleColumn.Name="Regel";$ruleColumn.HeaderText="Regel";$ruleColumn.Width=300;$ruleColumn.ReadOnly=$true;[void]$advancedGrid.Columns.Add($ruleColumn)
    $activeColumn=New-Object System.Windows.Forms.DataGridViewCheckBoxColumn;$activeColumn.Name="Aktiv";$activeColumn.HeaderText="Aktiv";$activeColumn.Width=70;$activeColumn.FlatStyle="Standard";[void]$advancedGrid.Columns.Add($activeColumn)
    $actionColumn=New-Object System.Windows.Forms.DataGridViewTextBoxColumn;$actionColumn.Name="Aktion";$actionColumn.HeaderText="Aktion";$actionColumn.Width=220;$actionColumn.ReadOnly=$true;[void]$advancedGrid.Columns.Add($actionColumn)
    $settingColumn=New-Object System.Windows.Forms.DataGridViewTextBoxColumn;$settingColumn.Name="Einstellung";$settingColumn.HeaderText="Einstellung";$settingColumn.Width=280;$settingColumn.ReadOnly=$true;[void]$advancedGrid.Columns.Add($settingColumn)
    foreach($key in $names.Keys){
        $cfg=$Rules.advanced.$key;if($null-eq $cfg){continue};$setting=""
        if($cfg.PSObject.Properties["count"]){$setting="Grenzwert: "+$cfg.count};if($cfg.PSObject.Properties["max_characters"]){$setting="Max. Zeichen: "+$cfg.max_characters};if($cfg.PSObject.Properties["max_lines"]){$setting="Max. Zeilen: "+$cfg.max_lines};if($cfg.PSObject.Properties["ratio"]){$setting="Ähnlichkeit: "+$cfg.ratio};if($cfg.PSObject.Properties["expiry_seconds"]){$setting="Verfall: "+[math]::Round([double]$cfg.expiry_seconds/3600,1)+" Stunden"}
        $action=if($cfg.PSObject.Properties["action"]){ConvertTo-ActionLabel ([string]$cfg.action)}elseif($cfg.PSObject.Properties["steps"]){"Eskalation bis Blockierung"}else{"—"}
        $idx=$advancedGrid.Rows.Add($names[$key],[bool]$cfg.enabled,$action,$setting);$advancedGrid.Rows[$idx].Tag=$key
    }
    $advancedGrid.Add_CurrentCellDirtyStateChanged({if($advancedGrid.IsCurrentCellDirty){$advancedGrid.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit)}})
    $save=@(New-Button "Erweiterte Regeln speichern" $Colors.Green $Colors.Black 240 42)[-1];$save.Location=[System.Drawing.Point]::new(20,585);$save.Add_Click({
        foreach($row in $advancedGrid.Rows){$key=[string]$row.Tag;if(-not[string]::IsNullOrWhiteSpace($key)-and $null-ne $Rules.advanced.$key){$Rules.advanced.$key.enabled=[bool]$row.Cells["Aktiv"].Value}}
        if(Save-RulesObject $Rules "Erweiterte Regeln"){$d.Close()}
    })
    $d.Controls.AddRange(@($advancedGrid,$save));[void]$d.ShowDialog($form)
}

function Show-RulesDialog {
    $d = @(New-ToolDialog "Regeln" 760 700)[-1]
    $d = Assert-Control $d "Dialog"
    Add-DialogTitle $d "REGELN" "Regel auswählen, bearbeiten und separat speichern"

    $rules = Ensure-RuleProperties (Get-RulesObject)

    $info = @(New-Label "Jede Regel besitzt eine eigene Bearbeitung und eine eigene Speichern-Schaltfläche." 10 $Colors.Muted)[-1]
    $info.Location = [System.Drawing.Point]::new(22,86)
    $info.AutoSize = $true
    $d.Controls.Add($info)

    $buttonWidth = 680
    $buttonHeight = 58
    $left = 22
    $top = 125
    $gap = 72

    $insults = @(New-Button "Beleidigungen bearbeiten" $Colors.Surface $Colors.Text $buttonWidth $buttonHeight)[-1]
    $insults.Location = [System.Drawing.Point]::new($left,$top)
    $insults.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $insults.Add_Click({ Show-InsultsEditor $rules })

    $emoji = @(New-Button "Emoji-Regel bearbeiten" $Colors.Surface $Colors.Text $buttonWidth $buttonHeight)[-1]
    $emoji.Location = [System.Drawing.Point]::new($left,($top + $gap))
    $emoji.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $emoji.Add_Click({ Show-EmojiEditor $rules })

    $uppercase = @(New-Button "Großschreibung bearbeiten" $Colors.Surface $Colors.Text $buttonWidth $buttonHeight)[-1]
    $uppercase.Location = [System.Drawing.Point]::new($left,($top + (2 * $gap)))
    $uppercase.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $uppercase.Add_Click({ Show-UppercaseEditor $rules })

    $advanced = @(New-Button "Erweiterte Regeln anzeigen" $Colors.Surface $Colors.Text $buttonWidth $buttonHeight)[-1]
    $advanced.Location = [System.Drawing.Point]::new($left,($top + (3 * $gap)))
    $advanced.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $advanced.Add_Click({ Show-AdvancedRulesDialog $rules })

    $addRule = @(New-Button "Regel hinzufügen" $Colors.Blue $Colors.Text $buttonWidth $buttonHeight)[-1]
    $addRule.Location = [System.Drawing.Point]::new($left,($top + (4 * $gap)))
    $addRule.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $addRule.Add_Click({ Show-AddRuleEditor $rules })

    $summary = @(New-Label (
        "Beleidigungen: " + @($rules.insults.terms).Count +
        " Begriffe    |    Eigene Regeln: " + @($rules.custom_rules).Count
    ) 10 $Colors.Muted)[-1]
    $summary.Location = [System.Drawing.Point]::new(22,510)
    $summary.AutoSize = $true

    $d.Controls.AddRange(@($insults,$emoji,$uppercase,$advanced,$addRule,$summary))
    [void]$d.ShowDialog($form)
}

function Show-ModeratorsDialog {
    $d = @(New-ToolDialog "Moderatoren")[-1]
    $d = Assert-Control $d "Dialog"
    Add-DialogTitle $d "MODERATOREN" "Im aktuellen Chat erkannte Rollen"

    $mods = @($script:AllRows | Where-Object {$_.isModerator -or $_.isOwner} | Group-Object authorChannelId | ForEach-Object {$_.Group | Select-Object -First 1})
    $list = New-Object System.Windows.Forms.ListBox
    $list.Location = [System.Drawing.Point]::new(20,85)
    $list.Size = [System.Drawing.Size]::new(850,480)
    $list.BackColor = $Colors.Surface
    $list.ForeColor = $Colors.Text

    if ($mods.Count -eq 0) {
        [void]$list.Items.Add("Noch keine Moderatoren oder Kanalinhaber erkannt.")
    } else {
        foreach ($m in $mods) {
            [void]$list.Items.Add(([string]$m.authorName + " · " + (Get-RoleText $m) + " · " + [string]$m.authorChannelId))
        }
    }
    $d.Controls.Add($list)
    [void]$d.ShowDialog($form)
}

function Show-ChannelDialog {
    $d = @(New-ToolDialog "Kanal & Einstellungen")[-1]
    $d = Assert-Control $d "Dialog"
    Add-DialogTitle $d "KANAL & EINSTELLUNGEN" "Verbindung und Pfade"

    $info = New-Object System.Windows.Forms.TextBox
    $info.Multiline = $true
    $info.ReadOnly = $true
    $info.BackColor = $Colors.Surface
    $info.ForeColor = $Colors.Text
    $info.Location = [System.Drawing.Point]::new(20,85)
    $info.Size = [System.Drawing.Size]::new(850,220)
    $info.Text =
        "Kanal: @DEIN_KANAL`n" +
        "Token: $script:BaseLinux/token.json`n" +
        "Status: $script:StatusLinux`n" +
        "Logs: $script:LogDirLinux`n" +
        "Regeln: $script:BaseLinux/rules.json"
    $d.Controls.Add($info)

    $test = @(New-Button "API testen" $Colors.Blue $Colors.Text 130 40)[-1]
    $test = Assert-Control $test "test"
    $test.Location = [System.Drawing.Point]::new(20,330)
    $test.Add_Click({
        [System.Windows.Forms.MessageBox]::Show(
            "Der API-Test erfolgt beim Start des Hintergrundwächters und über die Statusdatei.",
            "API","OK","Information"
        ) | Out-Null
    })

    $logs = @(New-Button "Logordner öffnen" $Colors.Surface2 $Colors.Text 160 40)[-1]
    $logs = Assert-Control $logs "logs"
    $logs.Location = [System.Drawing.Point]::new(165,330)
    $logs.Add_Click({
        Start-Process "explorer.exe" "\\wsl.localhost\$script:Distro\home\openclaw\.openclaw\youtube\logs"
    })

    $d.Controls.AddRange(@($test,$logs))
    [void]$d.ShowDialog($form)
}


function Convert-ImagePagesToPdf {
    param(
        [string[]]$JpegFiles,
        [string]$OutputPdf
    )

    if ($null -eq $JpegFiles -or $JpegFiles.Count -eq 0) {
        throw "Keine PDF-Seiten vorhanden."
    }

    $objects = New-Object System.Collections.Generic.List[byte[]]
    $pageIds = New-Object System.Collections.Generic.List[int]
    $contentIds = New-Object System.Collections.Generic.List[int]
    $imageIds = New-Object System.Collections.Generic.List[int]

    function Add-PdfObject {
        param([byte[]]$Bytes)
        $objects.Add($Bytes)
        return $objects.Count
    }

    $pageInfo = @()

    foreach ($jpeg in $JpegFiles) {
        $img = [System.Drawing.Image]::FromFile($jpeg)
        try {
            $width = $img.Width
            $height = $img.Height
        }
        finally {
            $img.Dispose()
        }

        $jpegBytes = [System.IO.File]::ReadAllBytes($jpeg)

        $imageHeader = [System.Text.Encoding]::ASCII.GetBytes(
            "<< /Type /XObject /Subtype /Image /Width $width /Height $height " +
            "/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode " +
            "/Length " + $jpegBytes.Length + " >>`nstream`n"
        )
        $imageFooter = [System.Text.Encoding]::ASCII.GetBytes("`nendstream")

        $imageObject = New-Object byte[] ($imageHeader.Length + $jpegBytes.Length + $imageFooter.Length)
        [Array]::Copy($imageHeader,0,$imageObject,0,$imageHeader.Length)
        [Array]::Copy($jpegBytes,0,$imageObject,$imageHeader.Length,$jpegBytes.Length)
        [Array]::Copy($imageFooter,0,$imageObject,$imageHeader.Length+$jpegBytes.Length,$imageFooter.Length)

        $imageId = Add-PdfObject $imageObject
        $imageIds.Add($imageId)

        $contentText = "q 842 0 0 595 0 0 cm /Im0 Do Q"
        $contentBytes = [System.Text.Encoding]::ASCII.GetBytes($contentText)
        $contentObject = [System.Text.Encoding]::ASCII.GetBytes(
            "<< /Length " + $contentBytes.Length + " >>`nstream`n" +
            $contentText + "`nendstream"
        )
        $contentId = Add-PdfObject $contentObject
        $contentIds.Add($contentId)

        $pageInfo += [pscustomobject]@{
            ImageId = $imageId
            ContentId = $contentId
        }
    }

    $pagesIdPlaceholder = $objects.Count + $pageInfo.Count + 1

    foreach ($info in $pageInfo) {
        $pageText =
            "<< /Type /Page /Parent $pagesIdPlaceholder 0 R " +
            "/MediaBox [0 0 842 595] " +
            "/Resources << /XObject << /Im0 " + $info.ImageId + " 0 R >> >> " +
            "/Contents " + $info.ContentId + " 0 R >>"
        $pageId = Add-PdfObject ([System.Text.Encoding]::ASCII.GetBytes($pageText))
        $pageIds.Add($pageId)
    }

    $kids = ($pageIds | ForEach-Object { "$_ 0 R" }) -join " "
    $pagesId = Add-PdfObject ([System.Text.Encoding]::ASCII.GetBytes(
        "<< /Type /Pages /Kids [$kids] /Count " + $pageIds.Count + " >>"
    ))

    if ($pagesId -ne $pagesIdPlaceholder) {
        throw "Interner PDF-Seitenverweis stimmt nicht."
    }

    $catalogId = Add-PdfObject ([System.Text.Encoding]::ASCII.GetBytes(
        "<< /Type /Catalog /Pages $pagesId 0 R >>"
    ))

    $stream = New-Object System.IO.MemoryStream
    try {
        $writer = New-Object System.IO.BinaryWriter($stream,[System.Text.Encoding]::ASCII,$true)
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes("%PDF-1.4`n%âãÏÓ`n"))

        $offsets = New-Object System.Collections.Generic.List[long]
        $offsets.Add(0)

        for ($i=0; $i -lt $objects.Count; $i++) {
            $offsets.Add($stream.Position)
            $writer.Write([System.Text.Encoding]::ASCII.GetBytes(($i+1).ToString() + " 0 obj`n"))
            $writer.Write($objects[$i])
            $writer.Write([System.Text.Encoding]::ASCII.GetBytes("`nendobj`n"))
        }

        $xref = $stream.Position
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes(
            "xref`n0 " + ($objects.Count + 1) + "`n"
        ))
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes("0000000000 65535 f `n"))

        for ($i=1; $i -lt $offsets.Count; $i++) {
            $writer.Write([System.Text.Encoding]::ASCII.GetBytes(
                $offsets[$i].ToString("0000000000") + " 00000 n `n"
            ))
        }

        $writer.Write([System.Text.Encoding]::ASCII.GetBytes(
            "trailer`n<< /Size " + ($objects.Count + 1) +
            " /Root $catalogId 0 R >>`nstartxref`n$xref`n%%EOF`n"
        ))
        $writer.Flush()

        [System.IO.File]::WriteAllBytes($OutputPdf,$stream.ToArray())
    }
    finally {
        $stream.Dispose()
    }
}

function Export-ProtocolPdfWithColorEmoji {
    param(
        [array]$Rows,
        [string]$OutputPdf
    )

    $edge = $null
    foreach ($candidate in @(
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
    )) {
        if (Test-Path -LiteralPath $candidate) {
            $edge = $candidate
            break
        }
    }

    if (-not $edge) {
        throw "Edge oder Chrome wurde nicht gefunden."
    }

    $tempRoot = Join-Path $env:TEMP ("chatwaechter-pdf-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempRoot | Out-Null

    try {
        $rowsPerPage = 40
        $pages = New-Object System.Collections.ArrayList

        if ($Rows.Count -eq 0) {
            [void]$pages.Add(@())
        }
        else {
            for ($start = 0; $start -lt $Rows.Count; $start += $rowsPerPage) {
                $pageRowsList = New-Object System.Collections.Generic.List[object]
                $lastIndex = [Math]::Min($start + $rowsPerPage - 1, $Rows.Count - 1)

                for ($rowIndex = $start; $rowIndex -le $lastIndex; $rowIndex++) {
                    $pageRowsList.Add($Rows[$rowIndex])
                }

                # Harte Begrenzung: niemals mehr als 40 Datensätze je Seite.
                $pageArray = @($pageRowsList.ToArray() | Select-Object -First 40)
                [void]$pages.Add($pageArray)
            }
        }

        $jpegFiles = @()
        $pageNumber = 0

        foreach ($pageRows in $pages) {
            $pageRows = @($pageRows | Select-Object -First 40)
            $pageNumber++
            $htmlFile = Join-Path $tempRoot ("page-" + $pageNumber.ToString("000") + ".html")
            $pngFile = Join-Path $tempRoot ("page-" + $pageNumber.ToString("000") + ".png")
            $jpgFile = Join-Path $tempRoot ("page-" + $pageNumber.ToString("000") + ".jpg")

            $bodyRows = ""
            foreach ($r in $pageRows) {
                $time = Format-Time $(if($r.publishedAt){$r.publishedAt}else{$r.receivedAt})
                $bodyRows += "<tr>" +
                    "<td>" + [System.Web.HttpUtility]::HtmlEncode($time) + "</td>" +
                    "<td>" + [System.Web.HttpUtility]::HtmlEncode([string]$r.authorName) + "</td>" +
                    "<td>" + [System.Web.HttpUtility]::HtmlEncode((Get-RoleText $r)) + "</td>" +
                    "<td class='message'>" + [System.Web.HttpUtility]::HtmlEncode([string]$r.text) + "</td>" +
                    "<td>" + [System.Web.HttpUtility]::HtmlEncode((Get-RuleName $r)) + "</td>" +
                    "<td>" + [System.Web.HttpUtility]::HtmlEncode((Get-ActionText $r)) + "</td>" +
                    "<td class='reason'>" + [System.Web.HttpUtility]::HtmlEncode((Get-ReasonText $r)) + "</td>" +
                    "</tr>"
            }

            $html = @"
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<style>
html,body{margin:0;padding:0;background:white;color:#101820}
body{font-family:"Segoe UI","Segoe UI Emoji","Noto Color Emoji",Arial,sans-serif}
.page{width:1600px;height:1200px;box-sizing:border-box;padding:18px 24px 24px 24px;overflow:hidden}
h1{font-size:22px;margin:0 0 10px 0}
table{width:100%;border-collapse:collapse;table-layout:fixed;font-size:10px}
th{background:#163b65;color:white;padding:3px 4px;border:1px solid #b8c4d1;line-height:1.0}
td{padding:2px 4px;border:1px solid #c7d0da;vertical-align:top;word-wrap:break-word;overflow-wrap:anywhere;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;line-height:1.0;height:18px;max-height:18px}
tr:nth-child(even){background:#f4f7fa}
th:nth-child(1){width:7%}
th:nth-child(2){width:13%}
th:nth-child(3){width:9%}
th:nth-child(4){width:31%}
th:nth-child(5){width:10%}
th:nth-child(6){width:10%}
th:nth-child(7){width:20%}
.message,.reason{line-height:1.0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
</style>
</head>
<body>
<div class="page">
<h1>Chatwächter-Protokoll</h1>
<table>
<thead>
<tr>
<th>Zeit</th><th>Nutzer</th><th>Rolle</th><th>Nachricht</th><th>Regel</th><th>Aktion</th><th>Begründung</th>
</tr>
</thead>
<tbody>$bodyRows</tbody>
</table>
</div>
</body>
</html>
"@

            [System.IO.File]::WriteAllText($htmlFile,$html,[System.Text.Encoding]::UTF8)
            $url = ([Uri]$htmlFile).AbsoluteUri

            & $edge --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --window-size=1600,1200 --screenshot="$pngFile" $url | Out-Null

            if (-not (Test-Path -LiteralPath $pngFile)) {
                throw "Seite $pageNumber konnte nicht als Bild erzeugt werden."
            }

            $bitmap = [System.Drawing.Bitmap]::FromFile($pngFile)
            try {
                $white = New-Object System.Drawing.Bitmap($bitmap.Width,$bitmap.Height)
                $graphics = [System.Drawing.Graphics]::FromImage($white)
                try {
                    $graphics.Clear([System.Drawing.Color]::White)
                    $graphics.DrawImage($bitmap,0,0,$bitmap.Width,$bitmap.Height)
                }
                finally {
                    $graphics.Dispose()
                }

                $white.Save($jpgFile,[System.Drawing.Imaging.ImageFormat]::Jpeg)
                $white.Dispose()
            }
            finally {
                $bitmap.Dispose()
            }

            $jpegFiles += $jpgFile
        }

        Convert-ImagePagesToPdf $jpegFiles $OutputPdf
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Show-ProtocolDialog {
    $d = @(New-ToolDialog "Protokoll" 1220 820)[-1]
    $d = Assert-Control $d "Dialog"
    Add-DialogTitle $d "VERGANGENE LIVESTREAMS" "Livestream auswählen, Nachrichten öffnen, Treffer und Löschungen filtern und exportieren"

    $split = New-Object System.Windows.Forms.SplitContainer
    $split.Location = [System.Drawing.Point]::new(18,82)
    $split.Size = [System.Drawing.Size]::new(1165,650)
    $split.Orientation = [System.Windows.Forms.Orientation]::Horizontal
    $split.SplitterDistance = 240
    $split.BackColor = $Colors.Window
    $d.Controls.Add($split)

    # Obere Übersicht
    $overview = New-Object System.Windows.Forms.DataGridView
    $overview.Dock = "Fill"
    $overview.BackgroundColor = $Colors.Surface
    $overview.ForeColor = $Colors.Text
    $overview.GridColor = $Colors.BorderSoft
    $overview.RowHeadersVisible = $false
    $overview.AllowUserToAddRows = $false
    $overview.AllowUserToDeleteRows = $false
    $overview.ReadOnly = $true
    $overview.SelectionMode = "FullRowSelect"
    $overview.MultiSelect = $false
    $overview.EnableHeadersVisualStyles = $false
    $overview.ColumnHeadersDefaultCellStyle.BackColor = $Colors.Surface2
    $overview.ColumnHeadersDefaultCellStyle.ForeColor = $Colors.Muted
    $overview.DefaultCellStyle.BackColor = $Colors.Surface
    $overview.DefaultCellStyle.ForeColor = $Colors.Text
    $overview.DefaultCellStyle.SelectionBackColor = $Colors.Surface3
    $overview.DefaultCellStyle.SelectionForeColor = $Colors.Text
    $overview.AutoGenerateColumns = $false

    foreach ($spec in @(
        @("Datei","Livestream-Protokoll",460),
        @("Datum","Datum",145),
        @("VideoId","Video-ID",160),
        @("Nachrichten","Nachrichten",95),
        @("Treffer","Treffer",75),
        @("Geloescht","Gelöscht",75)
    )) {
        $columnObject = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $columnObject.Name = $spec[0]
        $columnObject.HeaderText = $spec[1]
        $columnObject.Width = $spec[2]
        if ($spec[0] -eq "Datei") { $columnObject.AutoSizeMode = "Fill" }
        [void]$overview.Columns.Add($columnObject)
    }

    $split.Panel1.Controls.Add($overview)

    # Unterer Bereich
    $detailHost = New-Panel $Colors.Surface "Fill"
    $split.Panel2.Controls.Add($detailHost)

    $toolbar = New-Object System.Windows.Forms.FlowLayoutPanel
    $toolbar.Dock = "Top"
    $toolbar.Height = 44
    $toolbar.BackColor = $Colors.Window
    $toolbar.FlowDirection = "LeftToRight"
    $toolbar.WrapContents = $false

    $btnAll = @(New-Button "Normaler Chat" $Colors.Blue $Colors.Text 140 36)[-1]
    $btnAll = Assert-Control $btnAll "btnAll"
    $btnHits = @(New-Button "Nur Treffer" $Colors.Surface2 $Colors.Text 120 36)[-1]
    $btnHits = Assert-Control $btnHits "btnHits"
    $btnDeleted = @(New-Button "Nur Löschungen" $Colors.Surface2 $Colors.Text 140 36)[-1]
    $btnDeleted = Assert-Control $btnDeleted "btnDeleted"
    $btnOpen = @(New-Button "Auswahl öffnen" $Colors.Surface2 $Colors.Text 140 36)[-1]
    $btnOpen = Assert-Control $btnOpen "btnOpen"

    $format = New-Object System.Windows.Forms.ComboBox
    $format.DropDownStyle = "DropDownList"
    [void]$format.Items.AddRange(@("CSV","JSON","PDF"))
    $format.SelectedIndex = 0
    $format.Width = 90
    $format.Height = 36
    $format.BackColor = $Colors.Surface2
    $format.ForeColor = $Colors.Text

    $btnExport = @(New-Button "Exportieren" $Colors.Blue $Colors.Text 125 36)[-1]
    $btnExport = Assert-Control $btnExport "btnExport"

    $toolbar.Controls.AddRange(@(
        $btnAll,
        $btnHits,
        $btnDeleted,
        $btnOpen,
        $format,
        $btnExport
    ))
    $detailHost.Controls.Add($toolbar)

    $detailGrid = New-Object System.Windows.Forms.DataGridView
    $detailGrid.Dock = "Fill"
    $detailGrid.BackgroundColor = $Colors.Surface
    $detailGrid.ForeColor = $Colors.Text
    $detailGrid.GridColor = $Colors.BorderSoft
    $detailGrid.RowHeadersVisible = $false
    $detailGrid.AllowUserToAddRows = $false
    $detailGrid.AllowUserToDeleteRows = $false
    $detailGrid.ReadOnly = $true
    $detailGrid.SelectionMode = "FullRowSelect"
    $detailGrid.MultiSelect = $false
    $detailGrid.EnableHeadersVisualStyles = $false
    $detailGrid.ColumnHeadersDefaultCellStyle.BackColor = $Colors.Surface2
    $detailGrid.ColumnHeadersDefaultCellStyle.ForeColor = $Colors.Muted
    $detailGrid.DefaultCellStyle.BackColor = $Colors.Surface
    $detailGrid.DefaultCellStyle.ForeColor = $Colors.Text
    $detailGrid.DefaultCellStyle.SelectionBackColor = $Colors.Surface3
    $detailGrid.DefaultCellStyle.SelectionForeColor = $Colors.Text
    $detailGrid.AutoGenerateColumns = $false

    foreach ($spec in @(
        @("Zeit","Zeit",90),
        @("Nutzer","Nutzer",165),
        @("Rolle","Rolle",115),
        @("Nachricht","Nachricht",420),
        @("Regel","Regel",135),
        @("Aktion","Aktion",120),
        @("Grund","Begründung",240)
    )) {
        $columnObject = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $columnObject.Name = $spec[0]
        $columnObject.HeaderText = $spec[1]
        $columnObject.Width = $spec[2]
        if ($spec[0] -in @("Nachricht","Grund")) { $columnObject.AutoSizeMode = "Fill" }
        [void]$detailGrid.Columns.Add($columnObject)
    }
    Enable-EmojiColoring $detailGrid

    $detailHost.Controls.Add($detailGrid)
    $detailGrid.BringToFront()
    $toolbar.BringToFront()

    $script:ProtocolSelected = $null
    $script:ProtocolMode = "all"
    $script:ProtocolRows = @()

    function Get-ProtocolFiles {
        try {
            $pythonCode = @'
from pathlib import Path
import json
import re
import datetime
import sys

log_dir = Path(sys.argv[1])
result = []

for path in log_dir.glob("*-all_messages.jsonl"):
    name = path.name
    video_id = ""
    stamp = ""

    match = re.match(r"^(\d{8}-\d{6})-([A-Za-z0-9_-]+)-all_messages\.jsonl$", name)
    if match:
        stamp, video_id = match.group(1), match.group(2)
    else:
        match = re.match(r"^([A-Za-z0-9_-]+)-(\d{8}-\d{6})-all_messages\.jsonl$", name)
        if match:
            video_id, stamp = match.group(1), match.group(2)

    count_all = 0
    count_deleted = 0

    try:
        with path.open("r", encoding="utf-8") as handle:
            for line in handle:
                if not line.strip():
                    continue

                count_all += 1

                try:
                    row = json.loads(line)
                    if row.get("deleted"):
                        count_deleted += 1
                except Exception:
                    pass
    except Exception:
        pass

    flagged_path = path.with_name(
        name.replace("-all_messages.jsonl", "-flagged_messages.jsonl")
    )

    count_hits = 0
    if flagged_path.exists():
        try:
            with flagged_path.open("r", encoding="utf-8") as handle:
                count_hits = sum(1 for line in handle if line.strip())
        except Exception:
            pass

    if stamp:
        try:
            parsed = datetime.datetime.strptime(stamp, "%Y%m%d-%H%M%S")
            date_text = parsed.strftime("%d.%m.%Y %H:%M:%S")
        except Exception:
            date_text = stamp
    else:
        date_text = datetime.datetime.fromtimestamp(
            path.stat().st_mtime
        ).strftime("%d.%m.%Y %H:%M:%S")

    result.append({
        "file": name,
        "date": date_text,
        "videoId": video_id,
        "messages": count_all,
        "hits": count_hits,
        "deleted": count_deleted,
        "allLog": str(path),
        "flaggedLog": str(flagged_path) if flagged_path.exists() else "",
        "mtime": path.stat().st_mtime,
    })

result.sort(key=lambda item: item["mtime"], reverse=True)
print(json.dumps(result, ensure_ascii=False))
'@

            if (-not (Test-Path -LiteralPath $script:LogDirWindows)) { return @() }
            $result = @()
            foreach ($path in (Get-ChildItem -LiteralPath $script:LogDirWindows -Filter "*-all_messages.jsonl" -File -ErrorAction SilentlyContinue)) {
                $stamp=""; $videoId=""
                if ($path.Name -match '^(\d{8}-\d{6})-([A-Za-z0-9_-]+)-all_messages\.jsonl$') {
                    $stamp=$Matches[1]; $videoId=$Matches[2]
                } else {
                    $videoId=$path.BaseName -replace '-all_messages$',''
                }
                $flaggedName=$path.Name -replace '-all_messages\.jsonl$','-flagged_messages.jsonl'
                $flaggedPath=Join-Path $script:LogDirWindows $flaggedName
                $allLines=@(Get-Content -LiteralPath $path.FullName -Encoding UTF8 -ErrorAction SilentlyContinue | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})
                $deleted=0
                foreach($line in $allLines){try{if(($line|ConvertFrom-Json).deleted){$deleted++}}catch{}}
                $hits=if(Test-Path -LiteralPath $flaggedPath){@(Get-Content -LiteralPath $flaggedPath -Encoding UTF8|Where-Object{-not[string]::IsNullOrWhiteSpace($_)}).Count}else{0}
                $dateText=$path.LastWriteTime.ToString('dd.MM.yyyy HH:mm:ss')
                if($stamp){try{$dateText=[datetime]::ParseExact($stamp,'yyyyMMdd-HHmmss',$null).ToString('dd.MM.yyyy HH:mm:ss')}catch{}}
                $result += [pscustomobject]@{file=$path.Name;date=$dateText;videoId=$videoId;messages=$allLines.Count;hits=$hits;deleted=$deleted;allLog=$path.FullName;flaggedLog=$(if(Test-Path -LiteralPath $flaggedPath){$flaggedPath}else{""});mtime=$path.LastWriteTime.Ticks}
            }
            return @($result | Sort-Object mtime -Descending)
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Die Protokollübersicht konnte nicht geladen werden:`n`n" +
                $_.Exception.Message,
                "Protokoll",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null

            return @()
        }
    }

    function Render-ProtocolRows {
        $detailGrid.Rows.Clear()

        foreach ($r in @($script:ProtocolRows | Sort-Object @{
            Expression = {
                try {
                    [datetimeoffset]::Parse([string]$(if($_.publishedAt){$_.publishedAt}else{$_.receivedAt}))
                }
                catch {
                    [datetimeoffset]::MinValue
                }
            }
            Descending = $true
        })) {
            $idx = $detailGrid.Rows.Add(
                (Format-Time $(if($r.publishedAt){$r.publishedAt}else{$r.receivedAt})),
                [string]$r.authorName,
                (Get-RoleText $r),
                [string]$r.text,
                (Get-RuleName $r),
                (Get-ActionText $r),
                (Get-ReasonText $r)
            )

            if ($r.deleted) {
                $detailGrid.Rows[$idx].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(61,11,23)
                $detailGrid.Rows[$idx].Cells["Aktion"].Style.ForeColor = $Colors.Red
            }
            elseif ($r.flagged) {
                $detailGrid.Rows[$idx].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(39,17,31)
                $detailGrid.Rows[$idx].Cells["Aktion"].Style.ForeColor = $Colors.Yellow
            }
            elseif ($r.isModerator) {
                $detailGrid.Rows[$idx].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(11,42,72)
            }
        }
    }

    function Load-ProtocolSelection {
        if ($null -eq $script:ProtocolSelected) {
            $script:ProtocolRows = @()
            Render-ProtocolRows
            return
        }

        if ($script:ProtocolMode -eq "hits") {
            $path = [string]$script:ProtocolSelected.flaggedLog
        }
        else {
            $path = [string]$script:ProtocolSelected.allLog
        }

        if ([string]::IsNullOrWhiteSpace($path)) {
            $rows = @()
        }
        else {
            $rows = @(Read-JsonlLinux $path)
        }

        if ($script:ProtocolMode -eq "deleted") {
            $rows = @($rows | Where-Object { $_.deleted })
        }

        $script:ProtocolRows = @($rows)
        Render-ProtocolRows
    }

    $items = @(Get-ProtocolFiles)
    foreach ($item in $items) {
        $idx = $overview.Rows.Add(
            [string]$item.file,
            [string]$item.date,
            [string]$item.videoId,
            [string]$item.messages,
            [string]$item.hits,
            [string]$item.deleted
        )
        $overview.Rows[$idx].Tag = $item
    }

    $overview.Add_CellDoubleClick({
        param($sender,$e)
        if ($e.RowIndex -ge 0) {
            $overview.Rows[$e.RowIndex].Selected = $true
            $script:ProtocolSelected = $overview.Rows[$e.RowIndex].Tag
            Load-ProtocolSelection
        }
    })

    $overview.Add_SelectionChanged({
        if ($overview.SelectedRows.Count -gt 0) {
            $script:ProtocolSelected = $overview.SelectedRows[0].Tag
            Load-ProtocolSelection
        }
    })

    $btnOpen.Add_Click({
        if ($overview.SelectedRows.Count -gt 0) {
            $script:ProtocolSelected = $overview.SelectedRows[0].Tag
            Load-ProtocolSelection
        }
    })

    $btnAll.Add_Click({
        $script:ProtocolMode = "all"
        $btnAll.BackColor = $Colors.Blue
        $btnHits.BackColor = $Colors.Surface2
        $btnDeleted.BackColor = $Colors.Surface2
        Load-ProtocolSelection
    })

    $btnHits.Add_Click({
        $script:ProtocolMode = "hits"
        $btnAll.BackColor = $Colors.Surface2
        $btnHits.BackColor = $Colors.Blue
        $btnDeleted.BackColor = $Colors.Surface2
        Load-ProtocolSelection
    })

    $btnDeleted.Add_Click({
        $script:ProtocolMode = "deleted"
        $btnAll.BackColor = $Colors.Surface2
        $btnHits.BackColor = $Colors.Surface2
        $btnDeleted.BackColor = $Colors.Blue
        Load-ProtocolSelection
    })

    $btnExport.Add_Click({
        if ($null -eq $script:ProtocolSelected) {
            [System.Windows.Forms.MessageBox]::Show(
                "Bitte zuerst einen Livestream auswählen.",
                "Export","OK","Information"
            ) | Out-Null
            return
        }

        $fmt = [string]$format.SelectedItem
        $dialog = New-Object System.Windows.Forms.SaveFileDialog
        $video = [string]$script:ProtocolSelected.videoId
        if ([string]::IsNullOrWhiteSpace($video)) { $video = "Livestream" }

        switch ($fmt) {
            "CSV" {
                $dialog.Filter = "CSV (*.csv)|*.csv"
                $dialog.FileName = "Chatwaechter-$video.csv"
            }
            "JSON" {
                $dialog.Filter = "JSON (*.json)|*.json"
                $dialog.FileName = "Chatwaechter-$video.json"
            }
            "PDF" {
                $dialog.Filter = "PDF (*.pdf)|*.pdf"
                $dialog.FileName = "Chatwaechter-$video-40-pro-Seite.pdf"
            }
        }

        if ($dialog.ShowDialog() -ne "OK") { return }

        if ($fmt -eq "CSV") {
            $exportRows = foreach ($r in $script:ProtocolRows) {
                [pscustomobject]@{
                    Zeit = Format-Time $(if($r.publishedAt){$r.publishedAt}else{$r.receivedAt})
                    Nutzer = [string]$r.authorName
                    Rolle = Get-RoleText $r
                    Nachricht = [string]$r.text
                    Regel = Get-RuleName $r
                    Aktion = Get-ActionText $r
                    Begründung = Get-ReasonText $r
                }
            }
            $exportRows | Export-Csv -LiteralPath $dialog.FileName -Delimiter ";" -NoTypeInformation -Encoding UTF8
        }
        elseif ($fmt -eq "JSON") {
            $script:ProtocolRows | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $dialog.FileName -Encoding UTF8
        }
        else {
            try {
                Export-ProtocolPdfWithColorEmoji $script:ProtocolRows $dialog.FileName

                if (-not (Test-Path -LiteralPath $dialog.FileName)) {
                    throw "Die PDF-Datei wurde nicht erstellt."
                }
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show(
                    "PDF-Export fehlgeschlagen:`n`n" + $_.Exception.Message,
                    "PDF-Export",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null
                return
            }
        }

        [System.Windows.Forms.MessageBox]::Show(
            "Export abgeschlossen.",
            "Export","OK","Information"
        ) | Out-Null
    })

    if ($overview.Rows.Count -gt 0) {
        $overview.Rows[0].Selected = $true
        $overview.CurrentCell = $overview.Rows[0].Cells[0]
    }

    [void]$d.ShowDialog($form)
}

function Show-StatisticsDialog {
    $d = @(New-ToolDialog "Statistiken")[-1]
    $d = Assert-Control $d "Dialog"
    Add-DialogTitle $d "STATISTIKEN" "Aktueller Livestream"

    $all = $script:AllRows.Count
    $hits = $script:FlaggedRows.Count
    $deleted = @($script:AllRows | Where-Object {$_.deleted}).Count
    $rate = if($all -gt 0){[Math]::Round(100*$hits/$all,1)}else{0}

    $l = @(New-Label ("Nachrichten: $all`nRegel-Treffer: $hits`nGelöscht: $deleted`nTrefferquote: $rate Prozent") 14 $Colors.Text ([System.Drawing.FontStyle]::Bold))[-1]
    $l = Assert-Control $l "l"
    $l.Location = [System.Drawing.Point]::new(30,100)
    $l.Size = [System.Drawing.Size]::new(600,180)
    $d.Controls.Add($l)
    [void]$d.ShowDialog($form)
}

function Show-AlarmsDialog {
    $d = @(New-ToolDialog "Alarme")[-1]
    $d = Assert-Control $d "Dialog"
    Add-DialogTitle $d "ALARME" "Fehlgeschlagene Löschungen und Fehler"

    $failed = @($script:AllRows | Where-Object {($_.deleteRequested -and -not $_.deleted) -or ($_.banRequested -and -not $_.banned)})
    $list = New-Object System.Windows.Forms.ListBox
    $list.Location = [System.Drawing.Point]::new(20,85)
    $list.Size = [System.Drawing.Size]::new(850,470)
    $list.BackColor = $Colors.Surface
    $list.ForeColor = $Colors.Text

    if ($failed.Count -eq 0) {
        [void]$list.Items.Add("Keine aktuellen Alarme.")
    } else {
        foreach ($r in $failed) {
            $errorText = if($r.banRequested -and -not $r.banned){[string]$r.banError}else{[string]$r.deleteError}
            [void]$list.Items.Add(([string]$r.authorName + " · " + $errorText))
        }
    }
    $d.Controls.Add($list)
    [void]$d.ShowDialog($form)
}

function Show-SystemDialog {
    $d = @(New-ToolDialog "System")[-1]
    $d = Assert-Control $d "Dialog"
    Add-DialogTitle $d "SYSTEM" "WSL, Python und Hintergrundwächter"

    $python = Find-WslPython
    $probe = Invoke-WslCommand @("uname","-a")
    $status = Read-Status

    $box = New-Object System.Windows.Forms.TextBox
    $box.Multiline = $true
    $box.ReadOnly = $true
    $box.BackColor = $Colors.Surface
    $box.ForeColor = $Colors.Text
    $box.Location = [System.Drawing.Point]::new(20,85)
    $box.Size = [System.Drawing.Size]::new(850,300)
    $box.Text =
        "WSL: " + $probe.StdOut + "`n`n" +
        "Python: " + $python + "`n`n" +
        "Status: " + $(if($status){[string]$status.state}else{"keine Statusdatei"}) + "`n" +
        "Statusdatei: " + $script:StatusLinux
    $d.Controls.Add($box)

    $restart = @(New-Button "Wächter neu starten" $Colors.Blue $Colors.Text 180 40)[-1]
    $restart = Assert-Control $restart "restart"
    $restart.Location = [System.Drawing.Point]::new(20,410)
    $restart.Add_Click({
        [void](Invoke-WslCommand @("pkill","-f","$script:BaseLinux/auto_live_chatwaechter.py"))
        Start-Sleep -Milliseconds 500
        Install-And-StartWatcher | Out-Null
    })

    $d.Controls.Add($restart)
    [void]$d.ShowDialog($form)
}

# ---------- Nativer Windows-Betrieb (ersetzt die frühere WSL-Schicht) ----------
function Find-WslPython {
    $local = Join-Path $script:Folder ".venv\Scripts\python.exe"
    if (Test-Path -LiteralPath $local -PathType Leaf) { return $local }
    $python313 = Join-Path $env:LOCALAPPDATA "Programs\Python\Python313\python.exe"
    if (Test-Path -LiteralPath $python313 -PathType Leaf) { return $python313 }
    $pythonRoot = Join-Path $env:LOCALAPPDATA "Programs\Python"
    if (Test-Path -LiteralPath $pythonRoot -PathType Container) {
        $installed = Get-ChildItem -LiteralPath $pythonRoot -Directory -Filter "Python3*" -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            ForEach-Object { Join-Path $_.FullName "python.exe" } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
            Select-Object -First 1
        if ($installed) { return [string]$installed }
    }
    foreach ($name in @("python.exe", "python3.exe")) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $command) { return $command.Source }
    }
    $py = Get-Command "py.exe" -ErrorAction SilentlyContinue
    if ($null -ne $py) { return $py.Source }
    return ""
}

function Get-WatcherProcess {
    if (-not (Test-Path -LiteralPath $script:PidWindows)) { return $null }
    try { $pidValue=[int](Get-Content -LiteralPath $script:PidWindows -Raw).Trim(); return Get-Process -Id $pidValue -ErrorAction SilentlyContinue } catch { return $null }
}

function Install-And-StartWatcher {
    try {
        $watcher=Join-Path $script:Folder "AUTO_LIVE_CHATWAECHTER.py"; $rules=Join-Path $script:Folder "rules.json"
        if(-not(Test-Path -LiteralPath $watcher)){throw "AUTO_LIVE_CHATWAECHTER.py fehlt."}; if(-not(Test-Path -LiteralPath $rules)){throw "rules.json fehlt."}
        New-Item -ItemType Directory -Force -Path $script:BaseWindows,$script:LogDirWindows | Out-Null
        Copy-Item -LiteralPath $rules -Destination (Join-Path $script:BaseWindows "rules.json") -Force
        if($null-ne(Get-WatcherProcess)){return $true}
        $python=Find-WslPython
        if([string]::IsNullOrWhiteSpace($python)){throw "Python 3 wurde nicht gefunden. Installieren Sie Python 3 und aktivieren Sie 'Add python.exe to PATH'."}
        $token=Join-Path $script:BaseWindows "token.json"; if(-not(Test-Path -LiteralPath $token -PathType Leaf)){throw "Der YouTube-OAuth-Token fehlt: $token"}
        $args=@(); if([IO.Path]::GetFileName($python)-ieq "py.exe"){$args+="-3"}; $args+=('"'+$watcher+'"')
        $env:CHATWAECHTER_HOME=$script:BaseWindows
        $stdoutLog=Join-Path $script:BaseWindows "watcher_stdout.txt"; $stderrLog=Join-Path $script:BaseWindows "watcher_stderr.txt"
        Remove-Item -LiteralPath $stdoutLog,$stderrLog -Force -ErrorAction SilentlyContinue
        $process=Start-Process -FilePath $python -ArgumentList $args -WorkingDirectory $script:Folder -WindowStyle Hidden -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog -PassThru
        Start-Sleep -Seconds 2
        if($process.HasExited){
            $details=""
            if(Test-Path -LiteralPath $stderrLog){$details=(Get-Content -LiteralPath $stderrLog -Raw -Encoding UTF8).Trim()}
            if([string]::IsNullOrWhiteSpace($details)-and(Test-Path -LiteralPath $stdoutLog)){$details=(Get-Content -LiteralPath $stdoutLog -Raw -Encoding UTF8).Trim()}
            if([string]::IsNullOrWhiteSpace($details)){$details="Keine Python-Fehlerausgabe vorhanden."}
            throw "Der Python-Wächter wurde sofort beendet:`n`n$details"
        }
        return $true
    } catch { [System.Windows.Forms.MessageBox]::Show("Der Hintergrundwächter konnte nicht gestartet werden:`n`n"+$_.Exception.Message,"Chatwächter","OK","Warning")|Out-Null; return $false }
}

function Read-Status {
    try { if(-not(Test-Path -LiteralPath $script:StatusWindows)){return $null}; return Get-Content -LiteralPath $script:StatusWindows -Raw -Encoding UTF8|ConvertFrom-Json } catch { return $null }
}

function Read-JsonlLinux {
    param([string]$LinuxPath)
    if([string]::IsNullOrWhiteSpace($LinuxPath)-or-not(Test-Path -LiteralPath $LinuxPath)){return @()}; $result=@()
    try { foreach($line in(Get-Content -LiteralPath $LinuxPath -Encoding UTF8 -Tail 5000)){if(-not[string]::IsNullOrWhiteSpace($line)){try{$result+=($line|ConvertFrom-Json)}catch{}}} } catch{}; return @($result)
}

function Save-RulesObject {
    param([object]$RulesObject,[string]$DialogTitle="Regeln")
    try { $json=$RulesObject|ConvertTo-Json -Depth 20; $null=$json|ConvertFrom-Json; $utf8=New-Object System.Text.UTF8Encoding($false); [IO.File]::WriteAllText((Join-Path $script:Folder "rules.json"),$json,$utf8); New-Item -ItemType Directory -Force -Path $script:BaseWindows|Out-Null; [IO.File]::WriteAllText((Join-Path $script:BaseWindows "rules.json"),$json,$utf8); [System.Windows.Forms.MessageBox]::Show("Gespeichert.",$DialogTitle,"OK","Information")|Out-Null; return $true } catch { [System.Windows.Forms.MessageBox]::Show("Speichern fehlgeschlagen:`n`n"+$_.Exception.Message,$DialogTitle,"OK","Error")|Out-Null; return $false }
}

function Show-ChannelDialog {
    $d=@(New-ToolDialog "Kanal & Einstellungen")[-1];$d=Assert-Control $d "Dialog";Add-DialogTitle $d "KANAL & EINSTELLUNGEN" "Verbindung und lokale Pfade"
    $info=New-Object System.Windows.Forms.TextBox;$info.Multiline=$true;$info.ReadOnly=$true;$info.BackColor=$Colors.Surface;$info.ForeColor=$Colors.Text;$info.Location=[System.Drawing.Point]::new(20,85);$info.Size=[System.Drawing.Size]::new(850,220)
    $info.Lines=@("Kanal: @DEIN_KANAL","Token: "+(Join-Path $script:BaseWindows "token.json"),"Status: "+$script:StatusWindows,"Logs: "+$script:LogDirWindows,"Regeln: "+(Join-Path $script:BaseWindows "rules.json"));$d.Controls.Add($info)
    $test=@(New-Button "API testen" $Colors.Blue $Colors.Text 130 40)[-1];$test.Location=[System.Drawing.Point]::new(20,330);$test.Add_Click({
        $started=Install-And-StartWatcher
        Start-Sleep -Milliseconds 500
        $status=Read-Status
        if($started -and $null-ne $status){
            $state=[string]$status.state
            $resultText=switch($state){"connected"{"API verbunden – Livestream aktiv"};"waiting"{"API verbunden – warte auf Livestream"};"starting"{"API-Anmeldung erfolgreich – Wächter startet"};default{"API erreichbar – Status: "+$state}}
            $updated=if($status.updatedAt){try{([datetimeoffset]::Parse([string]$status.updatedAt)).ToLocalTime().ToString("dd.MM.yyyy HH:mm:ss")}catch{[string]$status.updatedAt}}else{"unbekannt"}
            [System.Windows.Forms.MessageBox]::Show($resultText+"`r`n`r`nKanal: @DEIN_KANAL`r`nLetzte Aktualisierung: "+$updated,"YouTube-API-Test","OK","Information")|Out-Null
        } else {
            [System.Windows.Forms.MessageBox]::Show("Der API-Test ist fehlgeschlagen. Bitte Systemstatus und watcher_stderr.txt prüfen.","YouTube-API-Test","OK","Error")|Out-Null
        }
    })
    $logs=@(New-Button "Logordner öffnen" $Colors.Surface2 $Colors.Text 160 40)[-1];$logs.Location=[System.Drawing.Point]::new(165,330);$logs.Add_Click({New-Item -ItemType Directory -Force -Path $script:LogDirWindows|Out-Null;Start-Process "explorer.exe" $script:LogDirWindows})
    $d.Controls.AddRange(@($test,$logs));[void]$d.ShowDialog($form)
}

function Show-BansDialog {
    $d=@(New-ToolDialog "Sperren verwalten")[-1];$d=Assert-Control $d "Dialog"
    Add-DialogTitle $d "DAUERHAFTE SPERREN" "Automatische Blockierungen dieses laufenden Chats rückgängig machen"
    $banRows=@($script:AllRows|Where-Object{$_.banned -and [string]$_.banType -eq "permanent" -and -not [string]::IsNullOrWhiteSpace([string]$_.banId)}|Group-Object banId|ForEach-Object{$_.Group|Select-Object -First 1})
    $list=New-Object System.Windows.Forms.ListBox;$list.Location=[System.Drawing.Point]::new(20,85);$list.Size=[System.Drawing.Size]::new(850,420);$list.BackColor=$Colors.Surface;$list.ForeColor=$Colors.Text
    foreach($row in $banRows){[void]$list.Items.Add(([string]$row.authorName+" · "+(Format-Time $(if($row.publishedAt){$row.publishedAt}else{$row.receivedAt}))+" · "+[string]$row.text))}
    if($banRows.Count -eq 0){[void]$list.Items.Add("Keine rückgängig machbare dauerhafte Sperre im aktuellen Protokoll.");$list.Enabled=$false}
    $undo=@(New-Button "Ausgewählte Sperre aufheben" $Colors.Blue $Colors.Text 260 42)[-1];$undo.Location=[System.Drawing.Point]::new(20,525);$undo.Enabled=$banRows.Count -gt 0
    $undo.Add_Click({
        if($list.SelectedIndex -lt 0 -or $list.SelectedIndex -ge $banRows.Count){[System.Windows.Forms.MessageBox]::Show("Bitte zuerst eine Sperre auswählen.","Sperren","OK","Information")|Out-Null;return}
        $row=$banRows[$list.SelectedIndex];$python=Find-WslPython;$helper=Join-Path $script:Folder "YOUTUBE_SPERRE_AUFHEBEN.py"
        try{
            if([string]::IsNullOrWhiteSpace($python)){throw "Python wurde nicht gefunden."};if(-not(Test-Path -LiteralPath $helper)){throw "YOUTUBE_SPERRE_AUFHEBEN.py fehlt."}
            $psi=New-Object System.Diagnostics.ProcessStartInfo;$psi.FileName=$python;$prefix=if([IO.Path]::GetFileName($python)-ieq "py.exe"){"-3 "}else{""};$psi.Arguments=$prefix+'"'+$helper+'" "'+[string]$row.banId+'"';$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
            $proc=New-Object System.Diagnostics.Process;$proc.StartInfo=$psi;[void]$proc.Start();$stdout=$proc.StandardOutput.ReadToEnd();$stderr=$proc.StandardError.ReadToEnd();$proc.WaitForExit()
            if($proc.ExitCode -ne 0){throw (($stderr+"`n"+$stdout).Trim())}
            $row.banned=$false;$row|Add-Member -NotePropertyName banRevoked -NotePropertyValue $true -Force
            $list.Items.RemoveAt($list.SelectedIndex);[System.Windows.Forms.MessageBox]::Show("Die Sperre wurde bei YouTube aufgehoben.","Sperren","OK","Information")|Out-Null
        }catch{[System.Windows.Forms.MessageBox]::Show("Sperre konnte nicht aufgehoben werden:`n`n"+$_.Exception.Message,"Sperren","OK","Error")|Out-Null}
    })
    $d.Controls.AddRange(@($list,$undo));[void]$d.ShowDialog($form)
}

function Show-SystemDialog {
    $d=@(New-ToolDialog "System")[-1]; $d=Assert-Control $d "Dialog"; Add-DialogTitle $d "SYSTEM" "Windows, Python und Hintergrundwächter"
    $python=Find-WslPython; $status=Read-Status; $running=$null-ne(Get-WatcherProcess); $box=New-Object System.Windows.Forms.TextBox
    $box.Multiline=$true;$box.ReadOnly=$true;$box.BackColor=$Colors.Surface;$box.ForeColor=$Colors.Text;$box.Location=[System.Drawing.Point]::new(20,85);$box.Size=[System.Drawing.Size]::new(850,300)
    $box.Text="Betriebssystem: Windows`n`nPython: "+$(if($python){$python}else{"nicht gefunden"})+"`nWächter: "+$(if($running){"läuft"}else{"nicht aktiv"})+"`nStatus: "+$(if($status){[string]$status.state}else{"keine Statusdatei"})+"`nStatusdatei: "+$script:StatusWindows; $d.Controls.Add($box)
    $restart=@(New-Button "Wächter neu starten" $Colors.Blue $Colors.Text 180 40)[-1];$restart.Location=[System.Drawing.Point]::new(20,410);$restart.Add_Click({
        $restart.Enabled=$false
        try{
            $old=Get-WatcherProcess
            if($null-ne $old){Stop-Process -Id $old.Id -Force -ErrorAction Stop;try{$old.WaitForExit(3000)}catch{};Start-Sleep -Milliseconds 300}
            Remove-Item -LiteralPath $script:PidWindows -Force -ErrorAction SilentlyContinue
            $started=Install-And-StartWatcher
            $newProcess=Get-WatcherProcess;$newStatus=Read-Status
            if(-not $started -or $null-eq $newProcess){throw "Der neue Wächterprozess wurde nicht gefunden."}
            $box.Text="Betriebssystem: Windows`r`n`r`nPython: "+(Find-WslPython)+"`r`nWächter: läuft`r`nPID: "+$newProcess.Id+"`r`nStartzeit: "+$newProcess.StartTime.ToString("dd.MM.yyyy HH:mm:ss")+"`r`nStatus: "+$(if($newStatus){[string]$newStatus.state}else{"wird erstellt"})+"`r`nStatusdatei: "+$script:StatusWindows
            [System.Windows.Forms.MessageBox]::Show("Der Wächter wurde erfolgreich neu gestartet.`r`n`r`nNeue PID: "+$newProcess.Id+"`r`nStartzeit: "+$newProcess.StartTime.ToString("HH:mm:ss"),"Chatwächter","OK","Information")|Out-Null
        }catch{[System.Windows.Forms.MessageBox]::Show("Neustart fehlgeschlagen:`r`n`r`n"+$_.Exception.Message,"Chatwächter","OK","Error")|Out-Null}
        finally{$restart.Enabled=$true}
    });$d.Controls.Add($restart);[void]$d.ShowDialog($form)
}

function Invoke-ChatwaechterTool([string[]]$Arguments) {
    $python=Find-WslPython
    $helper=Join-Path $script:Folder "CHATWAECHTER_WERKZEUGE.py"
    if([string]::IsNullOrWhiteSpace($python)){throw "Python wurde nicht gefunden."}
    if(-not(Test-Path -LiteralPath $helper)){throw "CHATWAECHTER_WERKZEUGE.py fehlt."}
    $invokeArgs=@()
    if([IO.Path]::GetFileName($python)-ieq "py.exe"){$invokeArgs+="-3"}
    $invokeArgs+=$helper;$invokeArgs+=$Arguments
    $result=& $python @invokeArgs 2>&1 | Out-String
    if($LASTEXITCODE -ne 0){throw $result.Trim()}
    return $result.Trim()
}

function Format-SingleTestResult([string]$JsonText) {
    $data=$JsonText|ConvertFrom-Json
    $hits=@($data.hits)
    if($hits.Count-eq 0){return "KEIN TREFFER · Keine Aktion"}
    $rules=(@($hits | ForEach-Object { Get-RuleDisplayName ([string]$_.rule) }) -join ", ")
    $action=$(if($data.delete){"Nachricht löschen"}elseif($data.banAction){[string]$data.banAction}else{"Nur markieren"})
    return "TREFFER · Regel: $rules · Vorschau: $action (keine echte YouTube-Aktion)"
}

$quickCheckButton.Add_Click({
    try {
        $textToTest=[string]$quickCheckInput.Text
        if([string]::IsNullOrWhiteSpace($textToTest)){$quickCheckResult.ForeColor=$Colors.Yellow;$quickCheckResult.Text="Bitte eine Nachricht eingeben oder im Chat doppelt anklicken.";return}
        $quickCheckResult.ForeColor=$Colors.Muted
        $quickCheckResult.Text="Text wird geprüft ..."
        $quickCheckResult.Refresh()
        $quickCheckResult.Text=Format-SingleTestResult (Invoke-ChatwaechterTool @("simulate-text",$textToTest))
        $quickCheckResult.ForeColor=$(if($quickCheckResult.Text.StartsWith("TREFFER")){$Colors.Red}else{$Colors.Green})
    } catch {$quickCheckResult.ForeColor=$Colors.Red;$quickCheckResult.Text=$_.Exception.Message}
})

function Send-ManualModerationCommand($ChatRow,[string]$Action) {
    if($null-eq $ChatRow){return}
    if(Test-Path -LiteralPath $script:PauseWindows){[System.Windows.Forms.MessageBox]::Show("Not-Aus ist aktiv. Manuelle Aktionen sind gesperrt.","Moderation","OK","Warning")|Out-Null;return}
    if([string]::IsNullOrWhiteSpace([string]$script:CurrentLiveChatId)){[System.Windows.Forms.MessageBox]::Show("Manuelle YouTube-Aktionen sind nur während eines aktiven Livestreams möglich.","Moderation","OK","Information")|Out-Null;return}
    $id=[guid]::NewGuid().ToString("N")
    $command=[ordered]@{id=$id;action=$Action;messageId=[string]$ChatRow.messageId;authorChannelId=[string]$ChatRow.authorChannelId;authorName=[string]$ChatRow.authorName;createdAt=(Get-Date).ToString("o")}
    $tmp=$script:ModCommandWindows+".tmp";$command|ConvertTo-Json|Set-Content -LiteralPath $tmp -Encoding UTF8;Move-Item -LiteralPath $tmp -Destination $script:ModCommandWindows -Force
    Remove-Item -LiteralPath $script:ModResultWindows -Force -ErrorAction SilentlyContinue
    [System.Windows.Forms.MessageBox]::Show("Aktion wurde an den Wächter übergeben.","Moderation","OK","Information")|Out-Null
}

function Add-TrustedUser($ChatRow) {
    if($null-eq $ChatRow -or [string]::IsNullOrWhiteSpace([string]$ChatRow.authorChannelId)){return}
    $rules=Get-RulesObject;$rules=Ensure-RuleProperties $rules
    if($null-eq $rules.advanced.PSObject.Properties["trusted_users"]){$rules.advanced|Add-Member -NotePropertyName trusted_users -NotePropertyValue @()}
    $values=@($rules.advanced.trusted_users)
    if([string]$ChatRow.authorChannelId -notin $values){$rules.advanced.trusted_users=@($values+[string]$ChatRow.authorChannelId);[void](Save-RulesObject $rules "Vertrauensliste")}
}

function Get-UserNotesObject {
    try{if(Test-Path -LiteralPath $script:NotesWindows){$object=Get-Content -LiteralPath $script:NotesWindows -Raw -Encoding UTF8|ConvertFrom-Json;$hash=@{};foreach($property in $object.PSObject.Properties){$hash[$property.Name]=[string]$property.Value};return $hash}}catch{}
    return @{}
}

function Show-UserDossierDialog($ChatRow) {
    if($null-eq $ChatRow){return}
    $d=@(New-ToolDialog "Nutzerakte" 980 700)[-1];$d=Assert-Control $d "Dialog";Add-DialogTitle $d ("NUTZERAKTE · "+[string]$ChatRow.authorName) ([string]$ChatRow.authorChannelId)
    $history=@($script:AllRows|Where-Object{[string]$_.authorChannelId -eq [string]$ChatRow.authorChannelId})
    $summary=@(New-Label ("Nachrichten: "+$history.Count+"   |   Treffer: "+@($history|Where-Object{$_.flagged}).Count+"   |   Gelöscht: "+@($history|Where-Object{$_.deleted}).Count+"   |   Sperren: "+@($history|Where-Object{$_.banned}).Count) 10 $Colors.Text ([System.Drawing.FontStyle]::Bold))[-1];$summary.Location=[System.Drawing.Point]::new(20,78);$summary.Size=[System.Drawing.Size]::new(920,28)
    $list=New-Object System.Windows.Forms.ListBox;$list.Location=[System.Drawing.Point]::new(20,112);$list.Size=[System.Drawing.Size]::new(920,380);$list.BackColor=$Colors.Surface;$list.ForeColor=$Colors.Text
    foreach($row in $history){[void]$list.Items.Add((Format-Time $(if($row.publishedAt){$row.publishedAt}else{$row.receivedAt}))+" · "+(Get-ActionText $row)+" · "+[string]$row.text)}
    $notes=Get-UserNotesObject;$key=[string]$ChatRow.authorChannelId
    $note=New-Object System.Windows.Forms.TextBox;$note.Multiline=$true;$note.Location=[System.Drawing.Point]::new(20,515);$note.Size=[System.Drawing.Size]::new(740,95);$note.BackColor=$Colors.Surface;$note.ForeColor=$Colors.Text;$note.Text=$(if($notes.ContainsKey($key)){[string]$notes[$key]}else{""})
    $save=@(New-Button "Notiz speichern" $Colors.Blue $Colors.Text 160 42)[-1];$save.Location=[System.Drawing.Point]::new(780,515);$save.Add_Click({$all=Get-UserNotesObject;$all[$key]=$note.Text;New-Item -ItemType Directory -Path $script:BaseWindows -Force|Out-Null;$all|ConvertTo-Json|Set-Content -LiteralPath $script:NotesWindows -Encoding UTF8;[System.Windows.Forms.MessageBox]::Show("Notiz gespeichert.","Nutzerakte")|Out-Null})
    $d.Controls.AddRange(@($summary,$list,$note,$save));[void]$d.ShowDialog($form)
}

function Enable-ModerationContextMenu([System.Windows.Forms.DataGridView]$TargetGrid) {
    $menu=New-Object System.Windows.Forms.ContextMenuStrip
    $gridRef=$TargetGrid
    foreach($entry in @(@("Nachricht löschen","delete"),@("5 Minuten stumm","timeout_300"),@("10 Minuten stumm","timeout_600"),@("30 Minuten stumm","timeout_1800"),@("1 Stunde stumm","timeout_3600"),@("24 Stunden stumm","timeout_86400"),@("Dauerhaft blockieren","block"))){
        $item=$menu.Items.Add($entry[0]);$item.Tag=$entry[1];$item.Add_Click(({param($sender,$eventArgs);Send-ManualModerationCommand $gridRef.CurrentRow.Tag ([string]$sender.Tag)}).GetNewClosure())
    }
    [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $dossier=$menu.Items.Add("Nutzerakte öffnen");$dossier.Add_Click(({Show-UserDossierDialog $gridRef.CurrentRow.Tag}).GetNewClosure())
    $trust=$menu.Items.Add("Zur Vertrauensliste hinzufügen");$trust.Add_Click(({Add-TrustedUser $gridRef.CurrentRow.Tag}).GetNewClosure())
    $TargetGrid.ContextMenuStrip=$menu
    $TargetGrid.Add_MouseDown({param($sender,$eventArgs);if($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Right){$hit=$sender.HitTest($eventArgs.X,$eventArgs.Y);if($hit.RowIndex -ge 0){$sender.CurrentCell=$sender.Rows[$hit.RowIndex].Cells[[Math]::Max(0,$hit.ColumnIndex)]}}})
}

function Ensure-DailyBackup {
    try{New-Item -ItemType Directory -Path $script:BackupsWindows -Force|Out-Null;$today=(Get-Date).ToString("yyyyMMdd");if(-not(Get-ChildItem -LiteralPath $script:BackupsWindows -Filter "chatwaechter-sicherung-$today-*.zip" -ErrorAction SilentlyContinue)){[void](Invoke-ChatwaechterTool @("backup"))}}catch{}
}

function Format-SimulationResult([string]$Path) {
    $data=Get-Content -LiteralPath $Path -Raw -Encoding UTF8|ConvertFrom-Json
    $builder=New-Object System.Text.StringBuilder
    [void]$builder.AppendLine("SIMULATION ABGESCHLOSSEN")
    [void]$builder.AppendLine("Datei: "+[IO.Path]::GetFileName([string]$data.file))
    [void]$builder.AppendLine("Geprüfte Nachrichten: "+$data.messages+"   |   Treffer: "+$data.wouldMatch+"   |   Löschungen: "+$data.wouldDelete+"   |   Stumm/Block: "+$data.wouldMuteOrBlock)
    [void]$builder.AppendLine(('-'*105))
    foreach($row in @($data.checkedMessages)){
        $time=$(if($row.time){Format-Time ([string]$row.time)}else{"--:--:--"})
        $state=$(if($row.matched){"TREFFER"}else{"OK"})
        $rules=$(if(@($row.rules).Count){@($row.rules)-join", "}else{"—"})
        $action=switch([string]$row.action){"delete"{"Löschen"};"flag"{"Markieren"};"block"{"Dauerhaft blockieren"};"none"{"Keine"};default{if(([string]$row.action).StartsWith("timeout_")){"Stumm ("+(([string]$row.action)-replace'^timeout_','')+" Sekunden)"}else{[string]$row.action}}}
        [void]$builder.AppendLine("[$state]  $time  "+[string]$row.author+": "+[string]$row.text)
        if($row.matched){[void]$builder.AppendLine("         Regel: $rules   |   Aktion: $action")}
    }
    return $builder.ToString()
}

function Show-SimulationTable([string]$Path,[System.Windows.Forms.DataGridView]$Grid,[System.Windows.Forms.Label]$Summary) {
    $data=Get-Content -LiteralPath $Path -Raw -Encoding UTF8|ConvertFrom-Json
    $Summary.Text="Geprüft: "+$data.messages+"   |   Treffer: "+$data.wouldMatch+"   |   Löschungen: "+$data.wouldDelete+"   |   Stumm/Block: "+$data.wouldMuteOrBlock
    $Grid.SuspendLayout()
    try {
        $Grid.Rows.Clear()
        foreach($row in @($data.checkedMessages)){
            $date="";$time=""
            if($row.time){try{$stamp=[DateTimeOffset]::Parse([string]$row.time).ToLocalTime();$date=$stamp.ToString("dd.MM.yyyy");$time=$stamp.ToString("HH:mm:ss")}catch{$time=[string]$row.time}}
            $status=$(if($row.matched){"TREFFER"}else{"OK"})
            $rules=$(if(@($row.rules).Count){@($row.rules|ForEach-Object{Get-RuleDisplayName ([string]$_)})-join", "}else{"—"})
            $action=switch([string]$row.action){"delete"{"Löschen"};"flag"{"Markieren"};"block"{"Dauerhaft blockieren"};"none"{"Keine"};default{if(([string]$row.action).StartsWith("timeout_")){"Stumm "+(([string]$row.action)-replace'^timeout_','')+" Sek."}else{[string]$row.action}}}
            $index=$Grid.Rows.Add($date,$time,[string]$row.author,[string]$row.text,$status,$rules,$action)
            $Grid.Rows[$index].Cells[3].ToolTipText=[string]$row.text
            $Grid.Rows[$index].Cells[5].ToolTipText=$rules
            if($row.matched){$Grid.Rows[$index].DefaultCellStyle.BackColor=[System.Drawing.Color]::FromArgb(72,20,34);$Grid.Rows[$index].DefaultCellStyle.ForeColor=[System.Drawing.Color]::White}else{$Grid.Rows[$index].DefaultCellStyle.ForeColor=$Colors.Text}
        }
    } finally {$Grid.ResumeLayout()}
}

function Show-ToolsDialog {
    $d=@(New-ToolDialog "Werkzeuge" 1220 790)[-1];$d=Assert-Control $d "Dialog";Add-DialogTitle $d "WERKZEUGE & SICHERHEIT" "Testen, prüfen, steuern und dokumentieren"
    $tabs=New-Object System.Windows.Forms.TabControl;$tabs.Location=[System.Drawing.Point]::new(18,78);$tabs.Size=[System.Drawing.Size]::new(1165,650)
    foreach($name in @("Sicherheit","Simulation","Prüfliste","Nutzer & Notizen","Profile & Zeit")){[void]$tabs.TabPages.Add($name);$tabs.TabPages[$tabs.TabPages.Count-1].BackColor=$Colors.Window;$tabs.TabPages[$tabs.TabPages.Count-1].ForeColor=$Colors.Text}

    $security=$tabs.TabPages[0]
    $paused=Test-Path -LiteralPath $script:PauseWindows
    $stop=@(New-Button $(if($paused){"AUTOMATIK WIEDER EINSCHALTEN"}else{"NOT-AUS · AKTIONEN STOPPEN"}) $(if($paused){$Colors.Green}else{$Colors.Red}) $Colors.Text 290 48)[-1];$stop.Location=[System.Drawing.Point]::new(22,25)
    $stateLabel=@(New-Label "" 11 $Colors.Text ([System.Drawing.FontStyle]::Bold))[-1];$stateLabel.Location=[System.Drawing.Point]::new(22,90);$stateLabel.Size=[System.Drawing.Size]::new(1080,100)
    $refreshState={ $status=Read-Status;$age=$(if(Test-Path -LiteralPath $script:StatusWindows){[int]((Get-Date)-(Get-Item -LiteralPath $script:StatusWindows).LastWriteTime).TotalSeconds}else{-1});$stateLabel.Text="Automatische Aktionen: "+$(if(Test-Path -LiteralPath $script:PauseWindows){"ANGEHALTEN"}else{"AKTIV"})+"`nWächterstatus: "+$(if($status){[string]$status.state}else{"unbekannt"})+" · letzter Herzschlag vor "+$age+" Sekunden`nAPI-Aufrufe seit Start: "+$(if($status){[string]$status.apiCalls}else{"—"})+" · Spamwellenmodus: "+$(if($status.spamWaveActive){"AKTIV"}else{"normal"}) }
    & $refreshState
    $stop.Add_Click({if(Test-Path -LiteralPath $script:PauseWindows){Remove-Item -LiteralPath $script:PauseWindows -Force;$stop.Text="NOT-AUS · AKTIONEN STOPPEN";$stop.BackColor=$Colors.Red}else{(Get-Date).ToString("o")|Set-Content -LiteralPath $script:PauseWindows;$stop.Text="AUTOMATIK WIEDER EINSCHALTEN";$stop.BackColor=$Colors.Green};& $refreshState})
    $backup=@(New-Button "Jetzt sichern" $Colors.Blue $Colors.Text 150 40)[-1];$backup.Location=[System.Drawing.Point]::new(22,215);$backup.Add_Click({try{$path=Invoke-ChatwaechterTool @("backup");[System.Windows.Forms.MessageBox]::Show("Sicherung erstellt:`n"+$path,"Sicherung")|Out-Null}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,"Sicherung")|Out-Null}})
    $openBackups=@(New-Button "Sicherungen öffnen" $Colors.Surface2 $Colors.Text 170 40)[-1];$openBackups.Location=[System.Drawing.Point]::new(185,215);$openBackups.Add_Click({New-Item -ItemType Directory -Path $script:BackupsWindows -Force|Out-Null;Start-Process explorer.exe $script:BackupsWindows})
    $reports=@(New-Button "Abschlussberichte öffnen" $Colors.Surface2 $Colors.Text 200 40)[-1];$reports.Location=[System.Drawing.Point]::new(368,215);$reports.Add_Click({New-Item -ItemType Directory -Path $script:ReportsWindows -Force|Out-Null;Start-Process explorer.exe $script:ReportsWindows})
    $undo=@(New-Button "Rückgängig-Zentrale" $Colors.Surface2 $Colors.Text 190 40)[-1];$undo.Location=[System.Drawing.Point]::new(581,215);$undo.Add_Click({Show-BansDialog})
    $security.Controls.AddRange(@($stop,$stateLabel,$backup,$openBackups,$reports,$undo))

    $simulation=$tabs.TabPages[1]
    $old=@(New-Button "Alten Chat testen" $Colors.Blue $Colors.Text 180 40)[-1];$old.Location=[System.Drawing.Point]::new(22,22)
    $result=New-Object System.Windows.Forms.RichTextBox;$result.ReadOnly=$true;$result.WordWrap=$false;$result.ScrollBars="Both";$result.Location=[System.Drawing.Point]::new(22,78);$result.Size=[System.Drawing.Size]::new(1090,455);$result.BackColor=$Colors.Surface;$result.ForeColor=$Colors.Text;$result.Font=New-Font 9;$result.Text="Hier kann ein vollständiger alter Chat ohne echte YouTube-Aktionen geprüft werden."
    $simSummary=@(New-Label "" 10 $Colors.Text ([System.Drawing.FontStyle]::Bold))[-1];$simSummary.Location=[System.Drawing.Point]::new(220,25);$simSummary.Size=[System.Drawing.Size]::new(890,28);$simSummary.Visible=$false
    $simGrid=New-Object System.Windows.Forms.DataGridView;$simGrid.Location=[System.Drawing.Point]::new(22,78);$simGrid.Size=[System.Drawing.Size]::new(1090,455);$simGrid.BackgroundColor=$Colors.Surface;$simGrid.ForeColor=$Colors.Text;$simGrid.GridColor=$Colors.Border;$simGrid.BorderStyle="FixedSingle";$simGrid.RowHeadersVisible=$false;$simGrid.AllowUserToAddRows=$false;$simGrid.ReadOnly=$true;$simGrid.AutoGenerateColumns=$false;$simGrid.SelectionMode="FullRowSelect";$simGrid.Visible=$false;$simGrid.EnableHeadersVisualStyles=$false
    $simGrid.DefaultCellStyle.BackColor=$Colors.Surface
    $simGrid.DefaultCellStyle.ForeColor=$Colors.Text
    $simGrid.DefaultCellStyle.SelectionBackColor=[System.Drawing.Color]::FromArgb(22,105,180)
    $simGrid.DefaultCellStyle.SelectionForeColor=[System.Drawing.Color]::White
    $simGrid.AlternatingRowsDefaultCellStyle.BackColor=[System.Drawing.Color]::FromArgb(8,31,57)
    $simGrid.AlternatingRowsDefaultCellStyle.ForeColor=$Colors.Text
    $simGrid.ColumnHeadersDefaultCellStyle.BackColor=[System.Drawing.Color]::FromArgb(13,45,78)
    $simGrid.ColumnHeadersDefaultCellStyle.ForeColor=[System.Drawing.Color]::White
    $simGrid.ColumnHeadersDefaultCellStyle.SelectionBackColor=[System.Drawing.Color]::FromArgb(13,45,78)
    $simGrid.ColumnHeadersDefaultCellStyle.SelectionForeColor=[System.Drawing.Color]::White
    foreach($spec in @(@("Datum",88),@("Uhrzeit",75),@("Name",165),@("Nachricht",330),@("Status",80),@("Regel",230),@("Aktion",115))){$column=New-Object System.Windows.Forms.DataGridViewTextBoxColumn;$column.Name=$spec[0];$column.HeaderText=$spec[0];$column.Width=$spec[1];if($spec[0]-eq"Nachricht"){$column.AutoSizeMode="Fill"};[void]$simGrid.Columns.Add($column)}
    $old.Add_Click({$dlg=New-Object System.Windows.Forms.OpenFileDialog;$dlg.InitialDirectory=$script:LogDirWindows;$dlg.Filter="Chatprotokoll|*-all_messages.jsonl";if($dlg.ShowDialog()-eq"OK"){try{$result.Visible=$true;$simGrid.Visible=$false;$simSummary.Visible=$false;$result.Text="Der alte Chat wird vollständig geprüft. Bitte warten ...";$result.Refresh();$path=Invoke-ChatwaechterTool @("simulate-log",$dlg.FileName);Show-SimulationTable $path $simGrid $simSummary;$result.Visible=$false;$simSummary.Visible=$true;$simGrid.Visible=$true}catch{$result.Visible=$true;$simGrid.Visible=$false;$simSummary.Visible=$false;$result.Text=$_.Exception.Message}}})
    $simulation.Controls.AddRange(@($old,$result,$simSummary,$simGrid))

    $review=$tabs.TabPages[2];$reviewGrid=New-Object System.Windows.Forms.DataGridView;$reviewGrid.Location=[System.Drawing.Point]::new(15,20);$reviewGrid.Size=[System.Drawing.Size]::new(1110,550);$reviewGrid.BackgroundColor=$Colors.Surface;$reviewGrid.ForeColor=$Colors.Text;$reviewGrid.RowHeadersVisible=$false;$reviewGrid.AllowUserToAddRows=$false;$reviewGrid.ReadOnly=$true;$reviewGrid.AutoGenerateColumns=$false
    foreach($spec in @(@("Zeit",90),@("Nutzer",170),@("Nachricht",520),@("Regel",250))){$c=New-Object System.Windows.Forms.DataGridViewTextBoxColumn;$c.Name=$spec[0];$c.HeaderText=$spec[0];$c.Width=$spec[1];if($spec[0]-eq"Nachricht"){$c.AutoSizeMode="Fill"};[void]$reviewGrid.Columns.Add($c)}
    foreach($row in @($script:FlaggedRows|Select-Object -Last 500)){$i=$reviewGrid.Rows.Add((Format-Time $(if($row.publishedAt){$row.publishedAt}else{$row.receivedAt})),[string]$row.authorName,[string]$row.text,(Get-RuleName $row));$reviewGrid.Rows[$i].Tag=$row}
    Enable-ModerationContextMenu $reviewGrid
    $ignore=@(New-Button "Auswahl als geprüft entfernen" $Colors.Surface2 $Colors.Text 240 38)[-1];$ignore.Location=[System.Drawing.Point]::new(15,580);$ignore.Add_Click({if($reviewGrid.CurrentRow){$reviewGrid.Rows.Remove($reviewGrid.CurrentRow)}})
    $review.Controls.AddRange(@($reviewGrid,$ignore))

    $usersTab=$tabs.TabPages[3];$users=@($script:AllRows|Where-Object{-not[string]::IsNullOrWhiteSpace([string]$_.authorChannelId)}|Group-Object authorChannelId|ForEach-Object{$_.Group|Select-Object -First 1}|Sort-Object authorName)
    $userList=New-Object System.Windows.Forms.ListBox;$userList.Location=[System.Drawing.Point]::new(20,25);$userList.Size=[System.Drawing.Size]::new(430,520);$userList.BackColor=$Colors.Surface;$userList.ForeColor=$Colors.Text;foreach($u in $users){[void]$userList.Items.Add(([string]$u.authorName+" · "+[string]$u.authorChannelId))}
    $openUser=@(New-Button "Nutzerakte öffnen" $Colors.Blue $Colors.Text 170 42)[-1];$openUser.Location=[System.Drawing.Point]::new(480,25);$openUser.Add_Click({if($userList.SelectedIndex-ge 0){Show-UserDossierDialog $users[$userList.SelectedIndex]}})
    $usersTab.Controls.AddRange(@($userList,$openUser))

    $profiles=$tabs.TabPages[4];$profileBox=New-Object System.Windows.Forms.ComboBox;$profileBox.Items.AddRange(@("Normal","Familienfreundlich","Streng","Nur markieren","Spamwelle"));$profileBox.SelectedIndex=0;$profileBox.Location=[System.Drawing.Point]::new(22,30);$profileBox.Size=[System.Drawing.Size]::new(240,32)
    $apply=@(New-Button "Profil anwenden" $Colors.Blue $Colors.Text 160 38)[-1];$apply.Location=[System.Drawing.Point]::new(280,27);$apply.Add_Click({try{[void](Invoke-ChatwaechterTool @("profile",[string]$profileBox.SelectedItem));[System.Windows.Forms.MessageBox]::Show("Profil wurde gespeichert und wird ohne Neustart übernommen.","Profile")|Out-Null}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,"Profile")|Out-Null}})
    $start=New-Object System.Windows.Forms.MaskedTextBox;$start.Mask="00:00";$start.Text="20:00";$start.Location=[System.Drawing.Point]::new(22,115);$start.Width=80
    $end=New-Object System.Windows.Forms.MaskedTextBox;$end.Mask="00:00";$end.Text="23:59";$end.Location=[System.Drawing.Point]::new(120,115);$end.Width=80
    $schedule=@(New-Button "Zeitprofil speichern" $Colors.Surface2 $Colors.Text 190 38)[-1];$schedule.Location=[System.Drawing.Point]::new(220,110);$schedule.Add_Click({try{[void](Invoke-ChatwaechterTool @("schedule",[string]$profileBox.SelectedItem,$start.Text,$end.Text));[System.Windows.Forms.MessageBox]::Show("Zeitprofil gespeichert: "+$start.Text+" bis "+$end.Text,"Zeitprofil")|Out-Null}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,"Zeitprofil")|Out-Null}})
    $profiles.Controls.AddRange(@($profileBox,$apply,$start,$end,$schedule))

    $d.Controls.Add($tabs);[void]$d.ShowDialog($form)
}

Enable-ModerationContextMenu $grid
Enable-ModerationContextMenu $liveChatGrid

# Events
$btnAll.Add_Click({Set-Mode "all"})
$btnHits.Add_Click({Set-Mode "flagged"})
$btnDeleted.Add_Click({Set-Mode "deleted"})
$tabAll.Add_Click({Set-Mode "all"})
$tabHits.Add_Click({Set-Mode "flagged"})
$tabDeleted.Add_Click({Set-Mode "deleted"})
$tabArchive.Add_Click({Set-Mode "archive"})
$searchBox.Add_TextChanged({Render-Grid})
$btnExport.Add_Click({Export-Current})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $script:RefreshSeconds * 1000
$timer.Add_Tick({
    param($sender, $eventArgs)

    try {
        Refresh-Dashboard
    }
    catch {
        $timerError = Join-Path $script:Folder "CHATWAECHTER_TIMERFEHLER.txt"
        (
            "Zeit: " + (Get-Date).ToString("dd.MM.yyyy HH:mm:ss") + [Environment]::NewLine +
            "Fehler beim Aktualisieren: " + $_.Exception.Message + [Environment]::NewLine +
            "Datei: " + $_.InvocationInfo.ScriptName + [Environment]::NewLine +
            "Zeile: " + $_.InvocationInfo.ScriptLineNumber + [Environment]::NewLine +
            $_.ScriptStackTrace
        ) | Set-Content -LiteralPath $timerError -Encoding UTF8

        if ($null -ne $sender) {
            $sender.Stop()
        }

        [System.Windows.Forms.MessageBox]::Show(
            "Die automatische Aktualisierung wurde angehalten.`n`n" +
            $_.Exception.Message +
            "`n`nDetails stehen in CHATWAECHTER_TIMERFEHLER.txt.",
            "Chatwächter – Aktualisierungsfehler",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
    }
})

$form.Add_Shown({
    $form.Activate()
    Ensure-DailyBackup

    if ($null -ne $timer) {
        $timer.Start()
    }

    $startupTimer = New-Object System.Windows.Forms.Timer
    $startupTimer.Interval = 300
    $startupTimer.Add_Tick({
        param($sender, $eventArgs)

        try {
            if ($null -ne $sender) {
                $sender.Stop()
            }

            Install-And-StartWatcher | Out-Null
            Refresh-Dashboard
        }
        catch {
            $startupError = Join-Path $script:Folder "CHATWAECHTER_TIMERFEHLER.txt"
            (
                "Zeit: " + (Get-Date).ToString("dd.MM.yyyy HH:mm:ss") + [Environment]::NewLine +
                "Fehler beim Start-Timer: " + $_.Exception.Message + [Environment]::NewLine +
                "Zeile: " + $_.InvocationInfo.ScriptLineNumber
            ) | Set-Content -LiteralPath $startupError -Encoding UTF8
        }
        finally {
            if ($null -ne $sender) {
                $sender.Dispose()
            }
        }
    })
    $startupTimer.Start()
})



# ---------- Sichere Formularanzeige ----------
if ($null -eq $form -or -not ($form -is [System.Windows.Forms.Form])) {
    [System.Windows.Forms.MessageBox]::Show(
        "Das Hauptfenster wurde nicht korrekt erstellt.",
        "Chatwächter – kritischer Fehler",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null

    return
}

$form.Add_FormClosing({
    try {
        if ($null -ne $timer) {
            $timer.Stop()
            $timer.Dispose()
        }
    }
    catch {
        # Beim Schließen keine zusätzliche Fehlermeldung erzeugen.
    }
})

try {
    [void]$form.ShowDialog()
}
catch {
    $details =
        "Zeit: " + (Get-Date).ToString("dd.MM.yyyy HH:mm:ss") +
        "`r`nFehler: " + $_.Exception.Message +
        "`r`nZeile: " + $_.InvocationInfo.ScriptLineNumber +
        "`r`nDatei: " + $_.InvocationInfo.ScriptName +
        "`r`n`r`nStack:`r`n" + $_.ScriptStackTrace

    $errorFile = Join-Path $script:Folder "CHATWAECHTER_STARTFEHLER.txt"
    $details | Set-Content -LiteralPath $errorFile -Encoding UTF8

    [System.Windows.Forms.MessageBox]::Show(
        "Das Dashboard konnte nicht geöffnet werden.`r`n`r`n" +
        $_.Exception.Message +
        "`r`n`r`nDetails wurden gespeichert in:`r`n" +
        $errorFile,
        "Chatwächter – Startfehler",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}


