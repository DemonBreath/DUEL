. "$PSScriptRoot\common-godot.ps1"

$projectRoot = Resolve-ProjectRoot
$runDir = Ensure-RunDirectory
$buildDir = Join-Path $runDir "build"
$godotExe = Resolve-GodotConsoleExe

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

& $godotExe --path $projectRoot --export-debug "Windows Desktop" (Join-Path $buildDir "Duel.exe")
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Output ("Export complete: {0}" -f $buildDir)
