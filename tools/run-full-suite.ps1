param(
    [int]$BasePort = 8940
)

$ErrorActionPreference = "Stop"

Write-Output "Running title smoke..."
powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "run-title-smoke.ps1")

Write-Output "Running forced round smoke (client win)..."
powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "run-smoke.ps1") -ServerPort $BasePort -RoundWinner client -PlayerName "SuiteClient"

Write-Output "Running forced round smoke (host win)..."
powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "run-smoke.ps1") -ServerPort ($BasePort + 1) -RoundWinner host -PlayerName "SuiteHost"

Write-Output "Running combat smoke..."
powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "run-combat-smoke.ps1") -ServerPort ($BasePort + 2) -PlayerName "SuiteCombat"

Write-Output "Running export smoke..."
powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "export-debug.ps1")

$buildDir = Join-Path (Split-Path $PSScriptRoot -Parent) ".codex-run\build"
$requiredFiles = @("Duel.exe", "Duel.pck")
foreach ($fileName in $requiredFiles) {
    $fullPath = Join-Path $buildDir $fileName
    if (-not (Test-Path $fullPath)) {
        throw "Missing build artifact: $fullPath"
    }
}

Write-Output "Full verification suite passed."
