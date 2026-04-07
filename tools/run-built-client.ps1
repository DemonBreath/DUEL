. "$PSScriptRoot\common-godot.ps1"

$projectRoot = Resolve-ProjectRoot
$buildExe = Join-Path $projectRoot ".codex-run\build\Duel.exe"

if (-not (Test-Path $buildExe)) {
    throw "Built client not found at $buildExe. Run tools\export-debug.ps1 first."
}

$process = Start-Process -FilePath $buildExe -PassThru

Write-Output ("Built client started. PID={0}" -f $process.Id)
Write-Output ("Exe: {0}" -f $buildExe)
