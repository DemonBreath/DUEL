function Resolve-GodotPackageRoot {
    $envPath = $env:GODOT_PACKAGE_ROOT
    if ($envPath -and (Test-Path $envPath)) {
        return $envPath
    }

    $packageRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
    if (Test-Path $packageRoot) {
        return $packageRoot
    }

    throw "Godot package root not found. Set GODOT_PACKAGE_ROOT or install Godot Engine via winget."
}

function Resolve-GodotGuiExe {
    $packageRoot = Resolve-GodotPackageRoot
    $exePath = Join-Path $packageRoot "Godot_v4.6.2-stable_win64.exe"
    if (Test-Path $exePath) {
        return $exePath
    }

    throw "Godot GUI executable not found at $exePath"
}

function Resolve-GodotConsoleExe {
    $packageRoot = Resolve-GodotPackageRoot
    $exePath = Join-Path $packageRoot "Godot_v4.6.2-stable_win64_console.exe"
    if (Test-Path $exePath) {
        return $exePath
    }

    throw "Godot console executable not found at $exePath"
}

function Resolve-ProjectRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Ensure-RunDirectory {
    $runDir = Join-Path (Resolve-ProjectRoot) ".codex-run"
    New-Item -ItemType Directory -Force -Path $runDir | Out-Null
    return $runDir
}
