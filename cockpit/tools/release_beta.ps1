## RELEASE A BETA BUILD: version, name, export, data, zip, changelog, blog post. One script, nothing by hand.
##
##   powershell -File cockpit\tools\release_beta.ps1 -Version 0.2.1                  the whole release
##   ... -Version 0.2.1 -DryRun                   build and zip and print the post, publish and commit nothing
##   ... -Version 0.2.1 -Name leaping-llama       choose the name instead of drawing one
##   ... -Version 0.2.1 -HostVoice                also package the ATC voice model (368 MB; only a host needs it)
##   ... -Version 0.0.1 -ExportOnly -OutDir <dir> only steps 1 to 4, into <dir>: a test build (tests/build_export.gd)
##   ... -Dev -OutDir <dir>                       a DEV build: no name, no version, the commit and time baked, so the
##                                                game says "dev . <commit> . <built>" (what tools/export.ps1 runs)
##
## THE DECISION: the user asked for it to be "totally done in the script", so every step a person would otherwise
## do is here, in order, and each one stops the release if it fails:
##   1. a release NAME, verb-animal ("leaping-llama"), unique against every name in cockpit/releases.md;
##   2. the VERSION written to project.godot's application/config/version;
##   3. an --import, then an EXPORT with the double editor, whose own templates folder (4.7.2.stable.double) is the
##      only one that can run a "Double Precision" project -- the stock template would export a game that cannot load
##      the double-precision library it ships with;
##      THE BUILD'S IDENTITY IS BAKED INTO THAT EXPORT (2026-09-18): the name, the commit, the branch and the time go
##      into project.godot as the `application/build/*` settings `BuildPlate` reads, for the export alone, and come out
##      again in a `finally` on every path -- a commit hash committed into project.godot would be wrong by the next
##      commit. So the game shows "0.2.1 leaping-llama . 3631368a . 2026-09-19" in the lower right and on the
##      clipboard's frame. The time is epoch seconds UTC (`build/time`), which the handshake compares so two players
##      are told which of them is behind and by how much (lane/buildtime, 2026-09-19);
##   4. the DATA the export cannot carry: the music (*.ogg from Desktop\auto_builds\data\music, else the workshop's
##      music/ folder, into music\ beside the exe, where RecordShelf looks) and, with -HostVoice,
##      the voice model and its library; and BUILD_INFO.txt, the same identity written out for a person, with what went
##      into the folder (it replaced VERSION.txt on 2026-09-18);
##   5. a ZIP of the folder, named cockpit-<version>-<name>-windows.zip, beside it in Desktop\auto_builds;
##   6. the CHANGES since the last release: the first-parent captions on main since the commit recorded in
##      releases.md. On main a lane arrives as one "merge lane/x: what the game now does" commit, so those captions
##      are already the list a player would want, and team-lead's own direct commits sit beside them;
##   7. a BLOG POST, titled with the version and the name, the changes as a list, and the zip attached;
##   8. a COMMIT of the version and the ledger line, and a local tag v<version>-<name>. Never a push: the user pushes.
##
## WHAT WENT WRONG BEFORE: nothing yet -- this is the first release through the script (2026-09-18). The one known limit
## is the blog: its asset route takes media types only, up to 19 MiB (blog_api.md), and a zip is neither. The script
## refuses to publish a post with no download rather than publish one that promises a file it could not attach.
param(
    [ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version = "",
    [string]$Name = "",
    [string]$Since = "",
    [switch]$HostVoice,
    [switch]$DryRun,
    # A TEST BUILD: name, bake, export, data and BUILD_INFO.txt into -OutDir, and nothing else -- no zip, no changes, no
    # post, no commit -- with project.godot put back byte for byte as it was found. What tests/build_export.gd drives.
    [switch]$ExportOnly,
    [string]$OutDir = "",
    # A DEV BUILD, which is an -ExportOnly with no release name and no version written: the one other way a build is made
    # here (tools/export.ps1 is a wrapper over this), so there is one export path and one bake.
    [switch]$Dev,
    # No music beside the exe: a suite's test build copies 87 MB to prove nothing it asks about.
    [switch]$NoMusic
)
$ErrorActionPreference = "Stop"
if ($Dev) { $ExportOnly = [switch]$true }
if (-not $Version -and -not $Dev) { throw "-Version X.Y.Z is needed for anything but a -Dev build." }
$project = Split-Path -Parent $PSScriptRoot
$repo = Split-Path -Parent $project
$ledger = Join-Path $project "releases.md"
$godot = Join-Path $repo "_tools\godot-4.7.2-double\godot.windows.editor.double.x86_64.console.exe"
$templates = Join-Path $env:APPDATA "Godot\export_templates\4.7.2.stable.double\windows_release_x86_64.exe"
$secret = "C:\Users\Graham\.config\godotgames\blog_api.md"
$blogMost = 19MB
# EVERY BUILD LIVES IN ONE PLACE the user chose, outside the repo: Desktop\auto_builds, one folder and one zip per release.
$builds = Join-Path ([Environment]::GetFolderPath("Desktop")) "auto_builds"
New-Item -ItemType Directory -Force -Path $builds | Out-Null
foreach ($need in @($godot, $templates)) { if (-not (Test-Path -LiteralPath $need)) { throw "Missing: $need" } }
if ($ExportOnly -and -not $OutDir) { throw "-ExportOnly needs -OutDir: a test build never goes into auto_builds." }
if (-not $DryRun -and -not $ExportOnly -and (& git -C $repo status --porcelain --untracked-files=no)) {
    throw "The tree has uncommitted changes to tracked files; a release is built from a commit. Commit or stash first."
}

# ---- 1. the name ------------------------------------------------------------------------------------------------
$used = @()
if (Test-Path -LiteralPath $ledger) {
    $used = Get-Content $ledger | Where-Object { $_ -match '^\|\s*\d+\.\d+\.\d+\s*\|' } |
        ForEach-Object { ($_ -split '\|')[2].Trim() }
}
$verbs = "leaping soaring gliding banking diving drifting hovering looping rolling climbing swooping darting " +
    "wheeling skimming cruising zooming spinning tumbling bounding prancing roaming humming whistling roaring"
$animals = "llama falcon heron otter puffin marten ibex osprey kestrel badger lynx gannet plover walrus tapir " +
    "wombat narwhal ocelot pelican cormorant petrel condor albatross gecko jackal meerkat okapi"
if ($Dev) {
    $Name = ""
} elseif ($Name) {
    if ($Name -notmatch '^[a-z]+-[a-z]+$') { throw "A release name is verb-animal in lower case, like leaping-llama." }
    if ($used -contains $Name) { throw "'$Name' has been used; releases.md lists every name." }
} else {
    $pool = foreach ($v in $verbs.Split(" ")) { foreach ($a in $animals.Split(" ")) {
        $n = "$v-$a"; if ($used -notcontains $n -and $v[0] -eq $a[0]) { $n } } }
    if (-not $pool) {
        $pool = foreach ($v in $verbs.Split(" ")) { foreach ($a in $animals.Split(" ")) {
            $n = "$v-$a"; if ($used -notcontains $n) { $n } } }
    }
    $Name = $pool | Get-Random
}
Write-Host $(if ($Dev) { "Dev build" } else { "Release $Version '$Name'" })

# ---- 6 (early, so a dry run shows it). the changes -----------------------------------------------------------------
if (-not $Since) {
    $last = @(Get-Content $ledger -ErrorAction SilentlyContinue | Where-Object { $_ -match '^\|\s*\d+\.\d+\.\d+\s*\|' })
    if ($last.Count -gt 0) { $Since = ($last[-1] -split '\|')[4].Trim() }
}
if (-not $Since -and -not $ExportOnly) { throw "No earlier release in releases.md: pass -Since <commit> for the first one." }
# A TEST OR DEV BUILD (-ExportOnly) lists no changes: it has no post to put them in.
$changes = @()
if (-not $ExportOnly) {
# WHAT A PLAYER GETS, read from all of history, not the first-parent line: on 2026-09-18 another session fast-forwarded
# main onto its own "Merge branch 'main' into lane/prowler2", and a first-parent walk then went down the Prowler lane
# and missed that evening's lane merges and team-lead's own commits. So: (a) every lane merge since the last release,
# by its caption ("merge <lane>[ step N]: what the game now does"), and (b) every other feat/fix/perf commit since, except
# those a captioned merge brought in, whose caption already says it. "merge main into" and "Merge branch" are skipped.
$seen = @{}
$rows = @()
$inside = @{}
foreach ($line in @(& git -C $repo log --merges --format="%H%x09%ct%x09%s" "$Since..HEAD")) {
    $sha, $when, $c = $line -split "`t", 3
    # A lane taking main in ("merge main into lane/x", "Merge branch 'main' into lane/x", "merge the step-2 base into
    # lane/x") is bookkeeping, not a change a player gets; only a lane arriving on main is.
    if ($c -cnotmatch '^merge ' -or $c -match '^[^:]*into lane/' -or $c -notmatch ':') { continue }
    $rows += [pscustomobject]@{ when = [long]$when; text = ($c -replace '^merge [^:]+:\s*', '') }
    foreach ($in in @(& git -C $repo rev-list "$sha^1..$sha^2")) { $inside[$in] = $true }
}
foreach ($line in @(& git -C $repo log --no-merges --format="%H%x09%ct%x09%s" "$Since..HEAD")) {
    $sha, $when, $c = $line -split "`t", 3
    if ($inside.ContainsKey($sha) -or $c -notmatch '^(feat|fix|perf)\(') { continue }
    $rows += [pscustomobject]@{ when = [long]$when; text = ($c -replace '^(feat|fix|perf)\([^)]*\):\s*', '') }
}
$changes = foreach ($r in ($rows | Sort-Object when)) {
    if ($seen.ContainsKey($r.text)) { continue }
    $seen[$r.text] = $true
    "- $($r.text)"
}
}

# A DRY RUN leaves project.godot exactly as it found it, even when a later step throws.
# AN EXPORT-ONLY RUN puts it back from the bytes it read, since a lane's project.godot may carry uncommitted work.
$settings = Join-Path $project "project.godot"
$settingsAsFound = [IO.File]::ReadAllBytes($settings)
if ($DryRun) { trap { & git -C $repo checkout -- (Join-Path $project "project.godot"); break } }
if ($ExportOnly) { trap { [IO.File]::WriteAllBytes($settings, $settingsAsFound); break } }

# ---- 2. the version ---------------------------------------------------------------------------------------------
$text = [IO.File]::ReadAllText($settings)
if (-not $Dev) {
# project.godot is CRLF on this machine, and .NET's multiline $ stops before the LF, not the CR, so each pattern
# allows the CR. Without it the first dry run wrote no version at all and nothing said so.
if ($text -match '(?m)^config/version=".*"\r?$') {
    $text = $text -replace '(?m)^config/version=".*"(\r?)$', "config/version=`"$Version`"`$1"
} else {
    $text = $text -replace '(?m)^(config/name=".*")(\r?)$', "`$1`$2`nconfig/version=`"$Version`"`$2"
}
if ($text -notmatch "(?m)^config/version=`"$([regex]::Escape($Version))`"") { throw "The version was not written to project.godot." }
[IO.File]::WriteAllText($settings, $text, (New-Object Text.UTF8Encoding $false))
}

# ---- 3. import and export -----------------------------------------------------------------------------------------
# THE IDENTITY, read once and used for the bake, BUILD_INFO.txt and the ledger alike.
$commit = (& git -C $repo rev-parse HEAD).Trim()
$branch = (& git -C $repo rev-parse --abbrev-ref HEAD).Trim()
# WHEN IT WAS BUILT, AS ONE NUMBER: epoch seconds UTC (2026-09-19, lane/buildtime). The game compares it with other
# builds over the wire and formats it where it shows it; BUILD_INFO.txt formats the same number below. It replaced a
# local "yyyy-MM-dd HH:mm" string, which no two machines could subtract.
$builtEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$builtUtc = [DateTimeOffset]::FromUnixTimeSeconds($builtEpoch).UtcDateTime
$builtAt = $builtUtc.ToString("yyyy-MM-dd HH:mm") + " UTC"
$builtDay = $builtUtc.ToString("yyyy-MM-dd")
# The keys are BuildPlate's NAME_SETTING, COMMIT_SETTING, BRANCH_SETTING and TIME_SETTING, in a section of their own at
# the end; tests/build_stamp.gd fails if this script stops naming any of them.
$baked = $text.TrimEnd() + "`r`n`r`n[application]`r`n`r`n" +
    "build/name=`"$Name`"`r`nbuild/commit=`"$commit`"`r`n" +
    "build/branch=`"$branch`"`r`nbuild/time=$builtEpoch`r`n"
$out = if ($ExportOnly) { $OutDir } else { Join-Path $builds "cockpit-$Version-$Name" }
if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Recurse -Force }
New-Item -ItemType Directory -Force -Path $out | Out-Null
$exe = Join-Path $out "Cockpit.exe"
$log = Join-Path $out "..\export-$(if ($Dev) { "dev" } else { $Version }).log"
try {
    Start-Process $godot -ArgumentList "--headless", "--import", "--path", "`"$project`"" -NoNewWindow -Wait `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    # BAKED AFTER THE IMPORT, so the editor that imports never sees a commit, and only the export carries one.
    [IO.File]::WriteAllText($settings, $baked, (New-Object Text.UTF8Encoding $false))
    Start-Process $godot -ArgumentList "--headless", "--xr-mode", "off", "--desktop-only", "--path", "`"$project`"",
        "--export-release", '"Windows Desktop"', "`"$exe`"" -NoNewWindow -Wait -RedirectStandardOutput $log -RedirectStandardError "$log.err"
} finally {
    # OUT AGAIN WHATEVER HAPPENED: the version stays (a release commits it), the commit never does.
    [IO.File]::WriteAllText($settings, $text, (New-Object Text.UTF8Encoding $false))
}
if ([IO.File]::ReadAllText($settings) -match '(?m)^build/') { throw "project.godot still carries the build identity." }
if (-not (Test-Path -LiteralPath $exe) -or -not (Test-Path -LiteralPath (Join-Path $out "Cockpit.pck"))) {
    throw "The export produced no Cockpit.exe and Cockpit.pck; see $log.err"
}

# ---- 4. the data --------------------------------------------------------------------------------------------------
# The music comes from auto_builds\data\music, the builds' own data folder the user asked for, and falls back to the
# workshop's music/ folder. It lands in music\ beside Cockpit.exe, the one place RecordShelf.folders looks in a build.
$music = Join-Path $builds "data\music"
if (-not (Test-Path -LiteralPath $music)) { $music = Join-Path $repo "music" }
$musicOut = Join-Path $out "music"
New-Item -ItemType Directory -Force -Path $musicOut | Out-Null
$tracks = @(if (-not $NoMusic) { Get-ChildItem -LiteralPath $music -Filter *.ogg -File -ErrorAction SilentlyContinue })
if ($tracks.Count -gt 0) { $tracks | Copy-Item -Destination $musicOut -Force }
if ($HostVoice) {
    $modelOut = Join-Path $out "kokoro\models"; $binOut = Join-Path $out "addons\kokoro_gd\bin"
    New-Item -ItemType Directory -Force -Path $modelOut, $binOut | Out-Null
    foreach ($n in "kokoro_fp32.onnx", "voices.bin", "lexicon.txt") {
        Copy-Item -LiteralPath (Join-Path $repo "kokoro-gd\models\$n") -Destination $modelOut -Force }
    foreach ($n in "kokoro_gd.gdextension", "libkokoro_gd.windows.x86_64.dll", "onnxruntime.dll") {
        Copy-Item -LiteralPath (Join-Path $project "addons\kokoro_gd\bin\$n") -Destination $binOut -Force }
}
# BUILD_INFO.txt: WHAT THIS FOLDER IS, for a person who has only the folder. The same values the game was baked with.
$says = if ($Dev) { "dev $([char]0x00B7) $($commit.Substring(0, 8)) $([char]0x00B7) $builtDay" } else {
    "$Version $Name $([char]0x00B7) $($commit.Substring(0, 8)) $([char]0x00B7) $builtDay" }
$info = @(
    $(if ($Dev) { "Cockpit dev build (not a release)" } else { "Cockpit $Version '$Name'" }),
    "",
    "version:     $(if ($Dev) { "none, a dev build" } else { $Version })",
    "name:        $(if ($Dev) { "none, a dev build" } else { $Name })",
    "commit:      $commit",
    "branch:      $branch",
    "built:       $builtAt (epoch $builtEpoch)",
    "engine:      Godot 4.7.2, double precision (export template 4.7.2.stable.double)",
    "exported by: $(Split-Path -Leaf $godot)",
    "music:       $(if ($tracks.Count -gt 0) { "included, $($tracks.Count) tracks" } else { "none" })",
    "host voice:  $(if ($HostVoice) { "included (the kokoro model and its library)" } else { "not included" })",
    "",
    "The game shows the same build in the lower right of the screen and on the clipboard's frame:",
    "  $says"
)
[IO.File]::WriteAllLines((Join-Path $out "BUILD_INFO.txt"), $info, (New-Object Text.UTF8Encoding $true))
if ($ExportOnly) {
    [IO.File]::WriteAllBytes($settings, $settingsAsFound)
    Write-Host "EXPORT ONLY: $exe; project.godot put back as it was found."
    exit 0
}

# ---- 5. the zip ---------------------------------------------------------------------------------------------------
$zip = Join-Path $builds "cockpit-$Version-$Name-windows.zip"
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -Path (Join-Path $out "*") -DestinationPath $zip -CompressionLevel Optimal
$size = (Get-Item -LiteralPath $zip).Length
Write-Host ("ZIP={0} ({1:N1} MiB, {2} music tracks{3})" -f $zip, ($size / 1MB), $tracks.Count, $(if ($HostVoice) { ", host voice" } else { "" }))

$title = "Beta $Version, $Name"
$body = "Cockpit **$Version**, codename **$Name**: a Windows beta build.`n`n{{DOWNLOAD}}`n`n" +
    "Unzip it anywhere and run ``Cockpit.exe``. Sound is off unless you start it with ``Cockpit.exe -- --audio``.`n`n" +
    "## What's changed since the last build`n`n" + ($changes -join "`n") + "`n"
if ($DryRun) {
    Write-Host "`n---- DRY RUN: the post that would be published ----`n# $title`n$body"
    & git -C $repo checkout -- (Join-Path $project "project.godot")
    Write-Host "DRY RUN: nothing published, committed or tagged; project.godot restored."
    exit 0
}

# ---- 7. the post ---------------------------------------------------------------------------------------------------
if ($size -gt $blogMost) {
    throw ("The zip is {0:N1} MiB and the blog takes at most 19 MiB, media types only. Nothing was published. " +
        "The build is at $zip.") -f ($size / 1MB)
}
$lines = Get-Content $secret
$url = ($lines | Where-Object { $_ -match '^\$env:BLOG_API_URL\s*=\s*"(.+)"' } | Select-Object -First 1) -replace '^\$env:BLOG_API_URL\s*=\s*"(.+)"$', '$1'
$key = ($lines | Where-Object { $_ -match '^\$env:BLOG_API_KEY\s*=\s*"(.+)"' } | Select-Object -First 1) -replace '^\$env:BLOG_API_KEY\s*=\s*"(.+)"$', '$1'
$auth = "Authorization: Bearer $key"
$utf8 = New-Object Text.UTF8Encoding $false
$req = Join-Path $out "..\release-post.json"
[IO.File]::WriteAllText($req, (@{ title = $title; body = "Draft."; tags = @("cockpit", "release", "beta"); visibility = "listed"; published = $false } | ConvertTo-Json), $utf8)
$post = (curl.exe -sS -X POST "$url/api/posts" -H $auth -H "Content-Type: application/json" --data-binary "@$req" | ConvertFrom-Json).post
if (-not $post.id) { throw "The blog did not create the post." }
$q = "filename=$([uri]::EscapeDataString([IO.Path]::GetFileName($zip)))&alt=$([uri]::EscapeDataString("$title for Windows"))"
$asset = (curl.exe -sS -X POST "$url/api/posts/$($post.id)/assets?$q" -H $auth -H "Content-Type: application/zip" --data-binary "@$zip" | ConvertFrom-Json).asset
if (-not $asset.markdown) { throw "The blog refused the zip; post $($post.id) is an unpublished draft." }
[IO.File]::WriteAllText($req, (@{ body = $body.Replace("{{DOWNLOAD}}", "**Download:** $($asset.markdown)"); published = $true } | ConvertTo-Json), $utf8)
$done = (curl.exe -sS -X PATCH "$url/api/posts/$($post.id)" -H $auth -H "Content-Type: application/json" --data-binary "@$req" | ConvertFrom-Json).post
Write-Host "POST $($done.slug) status=$($done.status)"

# ---- 8. the ledger, the commit and the tag --------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $ledger)) {
    Set-Content -LiteralPath $ledger -Encoding ascii -Value ("# Releases`n`nWritten by tools/release_beta.ps1. The last row's commit is where the next release's changes start.`n`n" +
        "| version | name | date | commit |`n|---|---|---|---|")
}
$head = & git -C $repo rev-parse --short HEAD
Add-Content -LiteralPath $ledger -Encoding ascii -Value "| $Version | $Name | $(Get-Date -Format yyyy-MM-dd) | $head |"
& git -C $repo add -- $settings $ledger
$msgFile = Join-Path $out "..\release-commit.txt"
[IO.File]::WriteAllText($msgFile, "chore(cockpit): release beta $Version, $Name`n`n$($changes.Count) changes since $Since; the zip is $([math]::Round($size / 1MB, 1)) MiB.`n", $utf8)
& git -C $repo commit -q -F $msgFile
& git -C $repo tag "v$Version-$Name"
Write-Host "Released $Version '$Name': committed and tagged v$Version-$Name (not pushed)."
