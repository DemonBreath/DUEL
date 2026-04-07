. "$PSScriptRoot\common-godot.ps1"

$projectRoot = Resolve-ProjectRoot
$runDir = Ensure-RunDirectory
$logPath = Join-Path $runDir "server-live.log"
$godotExe = Resolve-GodotConsoleExe

if (Test-Path $logPath) {
    try {
        Remove-Item $logPath -Force -ErrorAction Stop
    } catch {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $logPath = Join-Path $runDir ("server-live-{0}.log" -f $timestamp)
    }
}

$process = Start-Process -FilePath $godotExe -ArgumentList @(
    "--headless",
    "--path", $projectRoot,
    "--log-file", $logPath
) -PassThru

Write-Output ("Server started. PID={0}" -f $process.Id)
Write-Output ("Log: {0}" -f $logPath)
