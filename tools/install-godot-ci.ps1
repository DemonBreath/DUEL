param(
    [string]$Version = "4.6.2",
    [string]$Status = "stable"
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$installRoot = Join-Path $projectRoot ".godot-ci\windows\$Version-$Status"
$downloadRoot = Join-Path $projectRoot ".godot-ci\downloads\$Version-$Status"
$templateVersion = "$Version.$Status"
$templateRoot = Join-Path $env:APPDATA "Godot\export_templates\$templateVersion"
$releaseRoot = "https://github.com/godotengine/godot-builds/releases/download/$Version-$Status"

$artifacts = @(
    @{
        Name = "gui"
        FileName = "Godot_v$Version-$Status_win64.exe.zip"
    },
    @{
        Name = "console"
        FileName = "Godot_v$Version-$Status_win64_console.exe.zip"
    },
    @{
        Name = "templates"
        FileName = "Godot_v$Version-$Status_export_templates.tpz"
    }
)

New-Item -ItemType Directory -Force -Path $installRoot | Out-Null
New-Item -ItemType Directory -Force -Path $downloadRoot | Out-Null
New-Item -ItemType Directory -Force -Path $templateRoot | Out-Null

foreach ($artifact in $artifacts) {
    $destination = Join-Path $downloadRoot $artifact.FileName
    if (-not (Test-Path $destination)) {
        $url = "$releaseRoot/$($artifact.FileName)"
        Write-Output ("Downloading {0}" -f $url)
        Invoke-WebRequest -Uri $url -OutFile $destination
    }
}

$guiZip = Join-Path $downloadRoot "Godot_v$Version-$Status_win64.exe.zip"
$consoleZip = Join-Path $downloadRoot "Godot_v$Version-$Status_win64_console.exe.zip"
Expand-Archive -Path $guiZip -DestinationPath $installRoot -Force
Expand-Archive -Path $consoleZip -DestinationPath $installRoot -Force

$templateArchive = Join-Path $downloadRoot "Godot_v$Version-$Status_export_templates.tpz"
$templateZip = Join-Path $downloadRoot "Godot_v$Version-$Status_export_templates.zip"
$templateExtractRoot = Join-Path $downloadRoot "export_templates"
Copy-Item -Path $templateArchive -Destination $templateZip -Force
if (Test-Path $templateExtractRoot) {
    Remove-Item -Recurse -Force $templateExtractRoot
}

Expand-Archive -Path $templateZip -DestinationPath $templateExtractRoot -Force

$templateSource = $templateExtractRoot
$nestedTemplateSource = Join-Path $templateExtractRoot "templates"
if (Test-Path $nestedTemplateSource) {
    $templateSource = $nestedTemplateSource
}

Copy-Item -Path (Join-Path $templateSource "*") -Destination $templateRoot -Recurse -Force

$consoleExe = Join-Path $installRoot "Godot_v$Version-$Status_win64_console.exe"
if (-not (Test-Path $consoleExe)) {
    throw "Godot console executable not found after install: $consoleExe"
}

if ($env:GITHUB_ENV) {
    Add-Content -Path $env:GITHUB_ENV -Value ("GODOT_PACKAGE_ROOT={0}" -f $installRoot)
}

$env:GODOT_PACKAGE_ROOT = $installRoot
Write-Output ("GODOT_PACKAGE_ROOT={0}" -f $installRoot)
Write-Output ("Export templates installed at {0}" -f $templateRoot)
