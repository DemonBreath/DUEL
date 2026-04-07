param(
    [int]$X = 80,
    [int]$Y = 80,
    [string]$Resolution = "1600x900"
)

. "$PSScriptRoot\common-godot.ps1"

$projectRoot = Resolve-ProjectRoot
$runDir = Ensure-RunDirectory
$logPath = Join-Path $runDir "client-live.log"
$godotExe = Resolve-GodotGuiExe

if (Test-Path $logPath) {
    try {
        Remove-Item $logPath -Force -ErrorAction Stop
    } catch {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $logPath = Join-Path $runDir ("client-live-{0}.log" -f $timestamp)
    }
}

$process = Start-Process -FilePath $godotExe -ArgumentList @(
    "--path", $projectRoot,
    "--log-file", $logPath,
    "--windowed",
    "--position", "$X,$Y",
    "--resolution", $Resolution,
    "--",
    "--auto-advance-title",
    "--auto-join",
    "--server-ip=127.0.0.1",
    "--server-port=8910",
    "--player-name=Codex"
) -PassThru

Write-Output ("Client started. PID={0}" -f $process.Id)
Write-Output ("Log: {0}" -f $logPath)
