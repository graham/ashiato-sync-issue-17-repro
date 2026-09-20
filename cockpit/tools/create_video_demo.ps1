## RENDER A SHORT CINEMATIC REEL OF ONE REAL, AI-FLOWN CRAFT.
##
##   powershell -ExecutionPolicy Bypass -File cockpit\tools\create_video_demo.ps1 -Kind cessna
##   ... -Kind fighter -Seconds 15 -Shots orbit,chase,flyby,hero -Finish fine -Time evening
##   ... -Kind cessna -Output C:\share\cessna.mp4 -Ffmpeg C:\tools\ffmpeg.exe
##   ... -Kind tomcat -Shots above,plan,quarter -SweepScript "1:68,5.5:20"   the wings, commanded as a handle does
##   ... -Kind tomcat -Parked -Shots tail,above -StickScript "1.5:1:0:0,4:0:0:0"   a parked craft, a scripted stick
##   ... -Kind cessna -Parked -NoPen -Shots quarter -StickScript "0:0:0:0:0.5:0,6:0:0:1:0:1"   taxiing, then a braked turn
##   ... -Kind savoia -Afloat -Shots tail -StickScript "2:1:0:0,7:-1:0:0"   a flying boat taxiing on the river
##   ... -Kind apache -Parked -Shots chin,gunner -HeadScript "1:60:0,4:-30:-10" -Fire "2.2:2.6"   the chin gun following
##       the gunner's look, late, and firing where it points (lane/apache)
##
## AVI is Godot's directly playable, dependency-free output. MP4 asks FFmpeg for H.264;
## pass -Ffmpeg or put ffmpeg on PATH. The scene prints RESULT= and quits itself because
## interrupting MovieWriter leaves an unfinished file.
param(
    [string]$Kind = "cessna",
    [ValidateRange(4, 60)][double]$Seconds = 24,
    [ValidateRange(1, 120)][int]$Fps = 30,
    [string[]]$Shots = @("orbit", "flyby"),
    [ValidateSet("plain", "fine")][string]$Finish = "fine",
    [ValidatePattern("^(day|evening|night|dawn|dusk|([01]?[0-9]|2[0-3]):[0-5][0-9])$")][string]$Time = "day",
    # WHICH LEVEL IT FILMS. Empty means the game's own default. Until 2026-09-19 this tool always
    # filmed the default level, so a new level could be built and never appear in a reel -- which is
    # the one thing a cinematic tool is for. `--world=<id>` is what boot itself reads.
    [string]$World = "",
    [string]$Output = "",
    [string]$Stills = "",
    [string]$Godot = "",
    [string]$Ffmpeg = "",
    [string]$SweepScript = "",
    [string]$StickScript = "",
    [string]$HeadScript = "",
    [string]$Fire = "",
    [string]$Boat = "",
    [double]$Lock = -1,
    [double]$Launch = -1,
    [switch]$Parked,
    [switch]$NoPen,
    [switch]$Afloat
)

$ErrorActionPreference = "Stop"
# `-Shots orbit,flyby` typed inside PowerShell arrives as an ARRAY, and a [string] parameter
# would join it with a space: the scene then refused "orbit flyby" as an unknown shot. Through
# `powershell -File` the same words arrive as one string. Accept both and pass one comma list.
$Shots = ($Shots | ForEach-Object { $_.Split(",") } | ForEach-Object { $_.Trim() } |
    Where-Object { $_ }) -join ","
$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
$cockpit = Join-Path $repo "cockpit"

# A linked worktree deliberately has no ignored `_tools` directory. The common Git dir
# points back to the primary checkout, whose editor and GDExtension build can be reused
# without writing a byte into that checkout.
$commonText = (& git -C $repo rev-parse --git-common-dir 2>$null | Select-Object -First 1)
$primary = $repo
if ($commonText) {
    $common = $commonText.Trim()
    if (-not [IO.Path]::IsPathRooted($common)) { $common = Join-Path $repo $common }
    $resolvedCommon = [IO.Path]::GetFullPath($common)
    if ((Split-Path -Leaf $resolvedCommon) -eq ".git") { $primary = Split-Path -Parent $resolvedCommon }
}

if (-not $Godot) {
    $candidates = @(
        (Join-Path $repo "_tools\godot-4.7.2-double\godot.windows.editor.double.x86_64.console.exe"),
        (Join-Path $primary "_tools\godot-4.7.2-double\godot.windows.editor.double.x86_64.console.exe"),
        (Join-Path $repo "_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"),
        (Join-Path $primary "_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe")
    )
    $Godot = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $Godot -or -not (Test-Path -LiteralPath $Godot)) {
    throw "No Godot editor found. Pass -Godot or run tools\bootstrap.ps1."
}

if (-not $Output) {
    $stamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
    $Output = Join-Path $repo "videos\$stamp-cockpit-$Kind-demo.avi"
}
$Output = [IO.Path]::GetFullPath($Output)
$extension = [IO.Path]::GetExtension($Output).ToLowerInvariant()
if ($extension -notin @(".avi", ".mp4")) { throw "Output must end in .avi or .mp4." }
$parent = Split-Path -Parent $Output
[IO.Directory]::CreateDirectory($parent) | Out-Null
if (-not $Stills) {
    $Stills = Join-Path $parent (([IO.Path]::GetFileNameWithoutExtension($Output)) + "-stills")
}
$Stills = [IO.Path]::GetFullPath($Stills)

$movie = $Output
if ($extension -eq ".mp4") {
    if (-not $Ffmpeg) {
        $command = Get-Command ffmpeg -ErrorAction SilentlyContinue
        if ($command) { $Ffmpeg = $command.Source }
    }
    if (-not $Ffmpeg -and $env:LOCALAPPDATA) {
        # WinGet's package directory is not added to an already-running shell's PATH. Prefer
        # its stable package family and select the newest installed FFmpeg when there is one.
        $wingetPackages = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
        if (Test-Path -LiteralPath $wingetPackages) {
            $Ffmpeg = Get-ChildItem -Path $wingetPackages -Filter "ffmpeg.exe" -File -Recurse `
                -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match "Gyan\.FFmpeg" } |
                Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
        }
    }
    if (-not $Ffmpeg -or -not (Test-Path -LiteralPath $Ffmpeg)) {
        throw "MP4 needs FFmpeg. Pass -Ffmpeg <ffmpeg.exe>, put it on PATH, or use an .avi output."
    }
    $movie = Join-Path $parent (".{0}.godot-capture.avi" -f [IO.Path]::GetFileNameWithoutExtension($Output))
}

Write-Host "Godot: $Godot"
Write-Host "Craft: $Kind; shots: $Shots; $Seconds seconds at $Fps fps"
Write-Host "Movie: $Output"
$deadlineFrames = [int][Math]::Ceiling(($Seconds + 45.0) * $Fps)
$arguments = @(
    "--xr-mode", "off", "--desktop-only", "--path", $cockpit,
    "--resolution", "1280x720", "--write-movie", $movie, "--fixed-fps", "$Fps",
    "--quit-after", "$deadlineFrames",
    "res://tests/craft_video_demo.tscn", "--",
    "--level=fly", "--kind=$Kind", "--seconds=$Seconds", "--shots=$Shots",
    "--finish=$Finish", "--time=$Time", "--stills=$Stills"
)
if ($SweepScript) { $arguments += "--sweep-script=$SweepScript" }
if ($StickScript) { $arguments += "--stick-script=$StickScript" }
if ($HeadScript) { $arguments += "--head-script=$HeadScript" }
if ($Fire) { $arguments += "--fire=$Fire" }
# THE HELLFIRE REEL (lane/apache step 4): a patrol boat on the stage's river at "x:z", and LOCK and LAUNCH pressed by
# the seated hand at those seconds. See craft_video_demo.gd's argument list.
if ($Boat) { $arguments += "--boat=$Boat" }
if ($Lock -ge 0) { $arguments += "--lock=$Lock" }
if ($Launch -ge 0) { $arguments += "--launch=$Launch" }
if ($Parked) { $arguments += "--parked=1" }
# A REEL THAT FIRES STANDS ITS CRAFT OUTSIDE THE PEN: the pen's walls are collision two centimetres off the craft, and
# every round the AH-64's chin gun fired burst on them at the muzzle (lane/apache, 2026-09-18). See `bench.gd`, `pen`.
if ($Parked -and ($Fire -or $Launch -ge 0 -or $NoPen)) { $arguments += "--pen=0" }
# AND A REEL THAT TAXIS: the pen is two centimetres off the craft, so an aeroplane asked to roll drives straight into
# it (lane/flightcore, the ground-handling reels). `-NoPen` is for a script that moves the craft under its own power.
if ($Afloat) { $arguments += "--afloat=1" }
if ($World) { $arguments += "--world=$World" }
# Windows PowerShell promotes a native program's stderr to NativeCommandError. Godot writes
# harmless shutdown warnings there even after RESULT=PASS, so keep collecting and judge the
# run by the scene's explicit verdict, as every cockpit harness does.
$savedPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$lines = @(& $Godot @arguments 2>&1 | ForEach-Object { Write-Host $_; "$_" })
$ErrorActionPreference = $savedPreference
if (-not ($lines -match '^RESULT=PASS$')) {
    throw "Godot did not report RESULT=PASS; the movie was not accepted."
}
if (-not (Test-Path -LiteralPath $movie) -or (Get-Item -LiteralPath $movie).Length -eq 0) {
    throw "Godot reported success but did not write a non-empty movie at $movie."
}

if ($extension -eq ".mp4") {
    # H.264/AAC in an MP4, 8-bit 4:2:0 and an avc1 tag: the conservative intersection of
    # current Chrome, Firefox, Safari and Edge. Fast-start puts the index before the media
    # so a page can begin playback before the whole file has downloaded.
    # FFmpeg warns on stderr even when it succeeds -- "Guessed Channel Layout: stereo" for
    # Godot's PCM track -- and under "Stop" Windows PowerShell turns that line into a
    # terminating error, which killed all thirteen encodes of the first fleet run mid-write
    # and left thirteen empty MP4s. Judge it by its exit code and a non-empty file instead,
    # exactly as the Godot run above is judged by RESULT=.
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $Ffmpeg -hide_banner -loglevel warning -y -i $movie -c:v libx264 -preset medium -crf 20 `
        -profile:v high -level:v 4.0 -pix_fmt yuv420p -tag:v avc1 -movflags +faststart `
        -c:a aac -b:a 160k $Output 2>&1 | ForEach-Object { Write-Host "$_" }
    $encoded = $LASTEXITCODE
    $ErrorActionPreference = $savedPreference
    if ($encoded -ne 0 -or -not (Test-Path -LiteralPath $Output) -or (Get-Item -LiteralPath $Output).Length -eq 0) {
        throw "FFmpeg did not produce $Output; the intermediate AVI remains at $movie."
    }
    Remove-Item -LiteralPath $movie
}

$written = Get-Item -LiteralPath $Output
Write-Host ("VIDEO={0} ({1:N1} MiB)" -f $written.FullName, ($written.Length / 1MB)) -ForegroundColor Green
