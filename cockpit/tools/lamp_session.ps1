## TWO PLAYERS, TWO AIRCRAFT, ONE SIGNAL LAMP: a real session on this machine, photographed from the watcher's cockpit.
##
##   powershell -File cockpit\tools\lamp_session.ps1 -Out C:\somewhere
##   ... -Time night -Apart 1500 -Seconds 16
##
## A PICTURE HARNESS, AND THE PICTURES SAY SO. The HOST runs headless: once the joiner is flying it puts both players in a
## plane each, 600 m up and abreast `-Apart` metres (`SignalLampHarness --stage`), turns its desk view on the joiner and
## flashes its lamp with the desk's real keys -- A in red (dot, dash), a long green, two whites -- timed from the staging.
## With `-Tower` only the joiner is moved, passing over the host where it stands on the airfield: a tower signalling an
## aircraft, which is what these lamps are for. Both planes glide as it signals: with an opened throttle (`-Throttle`) the
## server fault S-2 (learnings/2026-09-18-lightgun.md) makes about one session in two lose a staged plane on the other
## machine, and this harness lives with that until it is fixed.
## The JOINER runs in a window, looks at the host, photographs its own lamp in its holster and held up, writes a picture
## every time the host's lamp changes, and `--reel` frames from inside the game, which FFmpeg (if it is on PATH) makes
## into an MP4 at their own timings.
##
## NEVER RECORDED FROM OUTSIDE THE GAME. FFmpeg's gdigrab sees a D3D12 window as grey, and a desktop duplication records
## whatever is on the screen there -- the first attempt recorded somebody else's window, and was deleted unwatched.
##
## THE GPU TOKEN: a `CAPTURE lightgun` line in C:\gg-wt\GPU_SLOT_HOLD while the window is up, removed after; it waits out a
## MEASUREMENT line first. Every process is found and stopped by this checkout's path on its command line, never by name:
## the console editor is a wrapper that returns before the child it starts (CLAUDE.md).
##
## Judge it by the pictures and by the LAMP lines in the logs; it prints where both are.
param(
    [string]$Out = "",
    [ValidateSet("day", "evening", "night")][string]$Time = "day",
    [ValidateRange(100, 5000)][int]$Apart = 1200,
    [ValidateRange(8, 60)][int]$Seconds = 16,
    [int]$Port = 48190,
    [switch]$Tower,
    [switch]$OwnLamp,
    [switch]$Seat,
    [switch]$Throttle
)

$ErrorActionPreference = "Stop"
$cockpit = Split-Path -Parent $PSScriptRoot
$repo = Split-Path -Parent $cockpit
$godot = Join-Path $repo "_tools\godot-4.7.2-double\godot.windows.editor.double.x86_64.console.exe"
if (-not (Test-Path $godot)) { $godot = Join-Path $repo "_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe" }
if (-not $Out) { $Out = Join-Path $env:TEMP "lamp_session_$Time" }
New-Item -ItemType Directory -Force $Out | Out-Null
Remove-Item (Join-Path $Out "*.png") -ErrorAction SilentlyContinue
Remove-Item (Join-Path $Out "reel") -Recurse -ErrorAction SilentlyContinue
$hostLog = Join-Path $Out "host.log"
$joinLog = Join-Path $Out "join.log"
$reel = Join-Path $Out "lamp-session-$Time$(if ($Tower) { '-tower' } else { '' }).mp4"
Remove-Item $reel -ErrorAction SilentlyContinue

# THE HOST'S SIGNAL, in seconds after it stages the joiner: A (dot dash) in red, a long green, two whites.
$flashes = "6:red:0.4,7:red:1.2,9:green:1.5,11.5:white:0.4,12.5:white:0.4"

$hold = "C:\gg-wt\GPU_SLOT_HOLD"
$started = Get-Date
while ((Test-Path $hold) -and ((Get-Content $hold) -match "^MEASUREMENT") -and ((Get-Date) - $started).TotalSeconds -lt 900) {
    Start-Sleep 5
}
$line = "CAPTURE lightgun $(Get-Date -Format s) two-aircraft lamp session, ~$($Seconds + 40) s"
Add-Content -Path $hold -Value $line -Encoding ascii
$match = "*$cockpit*--lamps=1*"
try {
    Start-Process -FilePath $godot -WindowStyle Minimized -RedirectStandardOutput $hostLog -RedirectStandardError "$hostLog.err" -ArgumentList @(
        "--headless", "--xr-mode", "off", "--desktop-only", "--path", $cockpit, "--",
        "--host=$Port", "--world=island", "--press-time=$Time", "--stage=$Apart", "--stage-tower=$(if ($Tower) { 1 } else { 0 })", "--stage-seat=$(if ($Seat) { 1 } else { 0 })", "--throttle=$(if ($Throttle) { 1 } else { 0 })",
        "--look-at-other=1", "--after-stage=1", "--place-lamp=0", "--flash=$flashes", "--lamps=1") | Out-Null
    Start-Sleep 3
    Start-Process -FilePath $godot -WindowStyle Minimized -RedirectStandardOutput $joinLog -RedirectStandardError "$joinLog.err" -ArgumentList @(
        "--xr-mode", "off", "--desktop-only", "--resolution", "1600x900", "--path", $cockpit, "--",
        "--join=127.0.0.1:$Port", "--look-at-other=1", "--own-lamp=$(if ($OwnLamp) { 1 } else { 0 })", "--throttle=$(if ($Throttle) { 1 } else { 0 })", "--shots=$Out", "--reel=$Seconds", "--lamps=1") | Out-Null
    $deadline = (Get-Date).AddSeconds(150)
    $stagedAt = $null
    while ((Get-Date) -lt $deadline) {
        if (-not $stagedAt -and (Get-Content $joinLog -ErrorAction SilentlyContinue | Select-String "LAMP_STAGED")) {
            $stagedAt = Get-Date
        }
        if ($stagedAt -and ((Get-Date) - $stagedAt).TotalSeconds -gt $Seconds + 3) { break }
        Start-Sleep 1
    }
} finally {
    Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like $match } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    $rest = @(Get-Content $hold -ErrorAction SilentlyContinue | Where-Object { $_ -ne $line })
    if ($rest.Count -gt 0) { Set-Content -Path $hold -Value $rest -Encoding ascii } else { Remove-Item $hold -ErrorAction SilentlyContinue }
}

"pictures: " + ((Get-ChildItem $Out -Filter *.png | ForEach-Object { $_.Name }) -join ", ")
Get-Content $joinLog -ErrorAction SilentlyContinue | Select-String "LAMP_STAGED|LAMP ms=.*mine=0|LAMP_FPS" | Select-Object -First 30
# THE REEL AT ITS OWN TIMINGS: each frame is named by its milliseconds since the staging, so a frame the game took late is
# shown for as long as it was on the screen rather than the video running fast.
$frames = @(Get-ChildItem (Join-Path $Out "reel") -Filter *.jpg -ErrorAction SilentlyContinue | Sort-Object { [int]$_.BaseName })
$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($ffmpeg -and $frames.Count -gt 10) {
    $list = New-Object System.Collections.Generic.List[string]
    $list.Add("ffconcat version 1.0")
    for ($i = 0; $i -lt $frames.Count; $i++) {
        $list.Add("file '$($frames[$i].FullName -replace '\\', '/')'")
        $next = if ($i + 1 -lt $frames.Count) { [int]$frames[$i + 1].BaseName } else { [int]$frames[$i].BaseName + 33 }
        $list.Add("duration $((($next - [int]$frames[$i].BaseName) / 1000.0).ToString([Globalization.CultureInfo]::InvariantCulture))")
    }
    $concat = Join-Path $Out "reel.ffconcat"
    [IO.File]::WriteAllLines($concat, $list)
    & $ffmpeg.Source -y -loglevel error -safe 0 -f concat -i $concat -vf "fps=30,format=yuv420p" -c:v libx264 -crf 20 $reel
    "reel: $reel from $($frames.Count) frames"
}
