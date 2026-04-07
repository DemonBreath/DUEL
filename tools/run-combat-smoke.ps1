param(
    [int]$ServerPort = 8930,
    [string]$PlayerName = "CombatSmoke",
    [double]$ExitDelay = 1.0
)

. "$PSScriptRoot\common-godot.ps1"
. "$PSScriptRoot\assert-log.ps1"

$projectRoot = Resolve-ProjectRoot
$runDir = Ensure-RunDirectory
$godotConsoleExe = Resolve-GodotConsoleExe

$serverLog = Join-Path $runDir ("combat-server-{0}.log" -f $ServerPort)
$clientLog = Join-Path $runDir ("combat-client-{0}.log" -f $ServerPort)

foreach ($logPath in @($serverLog, $clientLog)) {
    if (Test-Path $logPath) {
        Remove-Item $logPath -Force -ErrorAction SilentlyContinue
    }
}

$serverProcess = Start-Process -FilePath $godotConsoleExe -ArgumentList @(
    "--headless",
    "--path", $projectRoot,
    "--log-file", $serverLog,
    "--",
    "--server-port=$ServerPort",
    "--test-skip-intro",
    "--smoke-combat"
) -PassThru

Start-Sleep -Seconds 3

try {
    & $godotConsoleExe --path $projectRoot --log-file $clientLog --quit-after 1800 -- `
        --smoke-combat `
        --server-ip=127.0.0.1 `
        --server-port=$ServerPort `
        --player-name=$PlayerName `
        --test-bot `
        --test-skip-intro `
        --smoke-exit-scene=round_over `
        --smoke-exit-delay=$ExitDelay `
        --expected-local-result=YOU_WIN

    $clientExitCode = $LASTEXITCODE
} finally {
    if ($serverProcess -and -not $serverProcess.HasExited) {
        Stop-Process -Id $serverProcess.Id -Force -ErrorAction SilentlyContinue
    }
}

Write-Output ("Combat smoke client exit code: {0}" -f $clientExitCode)
Write-Output ("Server log: {0}" -f $serverLog)
Write-Output ("Client log: {0}" -f $clientLog)

if ($clientExitCode -ne 0) {
    exit $clientExitCode
}

Assert-LogContains -Path $clientLog -Patterns @(
    "PLAYER TEST BOT | engaging",
    "SHOT FIRED | ammo now:",
    "GAMEUI | shot_hit received",
    "ARENA | ROUND RESULT: YOU WIN",
    "GAMEUI TEST | EXPECTED RESULT CONFIRMED: YOU WIN",
    "GAMEUI | SMOKE EXIT"
)

Assert-LogContains -Path $serverLog -Patterns @(
    "NETWORK | Hosting on port $ServerPort",
    "STATE CHANGE | Player_1 -> DEAD",
    "ARENA | MATCH STATE -> ROUND_OVER"
)

Write-Output "Combat smoke passed."
