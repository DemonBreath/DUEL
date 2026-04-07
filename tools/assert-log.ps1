function Assert-LogContains {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string[]]$Patterns
    )

    if (-not (Test-Path $Path)) {
        throw "Log file not found: $Path"
    }

    $content = Get-Content $Path -Raw
    foreach ($pattern in $Patterns) {
        if ($content -notmatch [regex]::Escape($pattern)) {
            throw "Missing log marker '$pattern' in $Path"
        }
    }
}
