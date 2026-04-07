param(
    [double]$ExitDelay = 1.0
)

. "$PSScriptRoot\common-godot.ps1"
. "$PSScriptRoot\assert-log.ps1"

$projectRoot = Resolve-ProjectRoot
$runDir = Ensure-RunDirectory
$godotConsoleExe = Resolve-GodotConsoleExe
$logPath = Join-Path $runDir "title-smoke.log"

if (Test-Path $logPath) {
    Remove-Item $logPath -Force -ErrorAction SilentlyContinue
}

& $godotConsoleExe --path $projectRoot --log-file $logPath --quit-after 600 -- `
    --smoke `
    --smoke-exit-scene=title `
    --smoke-exit-delay=$ExitDelay

$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    exit $exitCode
}

Assert-LogContains -Path $logPath -Patterns @(
    "BOOT | LOADING CLIENT SCENE: res://title_screen.tscn",
    "TITLE READY",
    "TITLE | SMOKE EXIT"
)

Write-Output ("Title smoke passed. Log: {0}" -f $logPath)
