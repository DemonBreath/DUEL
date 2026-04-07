param(
    [int]$ServerPort = 8920,
    [string]$PlayerName = "CodexSmoke",
    [double]$ExitDelay = 2.0,
    [ValidateSet("client", "host")]
    [string]$RoundWinner = "client"
)

. "$PSScriptRoot\common-godot.ps1"
. "$PSScriptRoot\assert-log.ps1"

$projectRoot = Resolve-ProjectRoot
$runDir = Ensure-RunDirectory
$godotConsoleExe = Resolve-GodotConsoleExe

$serverLog = Join-Path $runDir ("smoke-server-{0}.log" -f $ServerPort)
$clientLog = Join-Path $runDir ("smoke-client-{0}.log" -f $ServerPort)

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
    "--test-round-winner=$RoundWinner",
    "--test-round-end-delay=1.0"
) -PassThru

Start-Sleep -Seconds 3

try {
    & $godotConsoleExe --path $projectRoot --log-file $clientLog --quit-after 1200 -- `
        --smoke `
        --server-ip=127.0.0.1 `
        --server-port=$ServerPort `
        --player-name=$PlayerName `
        --smoke-exit-delay=$ExitDelay `
        --expected-local-result=$(if ($RoundWinner -eq "client") { "YOU_WIN" } else { "YOU_LOSE" })

    $clientExitCode = $LASTEXITCODE
} finally {
    if ($serverProcess -and -not $serverProcess.HasExited) {
        Stop-Process -Id $serverProcess.Id -Force -ErrorAction SilentlyContinue
    }
}

Write-Output ("Smoke client exit code: {0}" -f $clientExitCode)
Write-Output ("Server log: {0}" -f $serverLog)
Write-Output ("Client log: {0}" -f $clientLog)

if ($clientExitCode -ne 0) {
    exit $clientExitCode
}

$expectedResult = if ($RoundWinner -eq "client") { "YOU WIN" } else { "YOU LOSE" }

Assert-LogContains -Path $clientLog -Patterns @(
    "MAIN MENU | CONNECTED",
    "ARENA | ROUND RESULT: $expectedResult",
    "GAMEUI TEST | EXPECTED RESULT CONFIRMED: $expectedResult",
    "GAMEUI | SMOKE EXIT"
)

Assert-LogContains -Path $serverLog -Patterns @(
    "NETWORK | Hosting on port $ServerPort",
    "ARENA | MATCH STATE -> ROUND_OVER"
)

Write-Output "Forced round smoke passed."
