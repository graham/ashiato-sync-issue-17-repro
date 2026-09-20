## PLAY THE GAME, IN A WINDOW OR IN THE HEADSET, ON THE DOUBLE-PRECISION ENGINE IT IS WRITTEN AGAINST.
##
##   powershell -ExecutionPolicy Bypass -File cockpit\tools\play.ps1                  # the world, sound on; V for the headset
##   powershell -ExecutionPolicy Bypass -File cockpit\tools\play.ps1 --level=menu     # anything after is the game's own flags
##   powershell -ExecutionPolicy Bypass -File cockpit\tools\play.ps1 -Stock           # the stock float32 editor instead
##   powershell -ExecutionPolicy Bypass -File cockpit\tools\play.ps1 -Editor          # open the project in the editor
##
## `cockpit\play.bat` and `cockpit\edit.bat` are the same two things for a double-click; both come here, so which
## binary is "the right one" is decided in this file and nowhere else.
##
## WHY A SCRIPT. The world is to grow to 30-70 km and the headset plays the precision=double build, which is not a
## download: it lives in `_tools\godot-4.7.2-double` (README.md, "The two engines"). Typing its path is how the stock
## editor gets launched by mistake, and the stock editor draws the far corner on a half-millimetre grid. So this picks the
## double editor, says which it used, and falls back to stock -- loudly -- only when the double one is not built.
##
## THE HEADSET. Start the PC VR runtime first (Virtual Desktop streaming to it), then press V in the game's window. The
## rig asks OpenXR for a session on that press, not at start-up; with no runtime it prints "[XR] OpenXR failed to start"
## and stays on the desktop, on either editor (tests/vr_fallback_shot.gd).
##
## SOUND IS ON HERE, `--audio`, because this is somebody playing; every suite and agent run leaves it off.
param(
    [switch]$Stock,
    [switch]$Editor,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest
)
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
$cockpit = Join-Path $root "cockpit"
$double = Join-Path $root "_tools\godot-4.7.2-double\godot.windows.editor.double.x86_64.exe"
$single = Join-Path $root "_tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
if ($Stock) {
    $godot = $single
    Write-Host "Stock float32 editor, as asked: $godot" -ForegroundColor Yellow
} elseif (Test-Path $double) {
    $godot = $double
    Write-Host "Double-precision editor: $godot"
} else {
    $godot = $single
    Write-Host "NO DOUBLE-PRECISION EDITOR at $double -- playing on the stock float32 one. Build it with tools\bootstrap.ps1 -Double." -ForegroundColor Red
}
if (-not (Test-Path $godot)) {
    Write-Host "No editor at $godot. Run tools\bootstrap.ps1 first." -ForegroundColor Red
    exit 1
}
if ($Editor) {
    & $godot --path $cockpit -e
    exit $LASTEXITCODE
}
$flags = @($Rest | Where-Object { $_ })
if (-not ($flags | Where-Object { $_ -like "--level=*" })) { $flags = @("--level=world") + $flags }
& $godot --path $cockpit -- --audio @flags
