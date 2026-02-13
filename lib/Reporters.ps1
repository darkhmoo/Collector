<#
.SYNOPSIS
    Reporters Loader
.DESCRIPTION
    Loads all reporter modules from the 'lib/reporters' directory.
#>

$reportersDir = Join-Path -Path $PSScriptRoot -ChildPath "reporters"

if (Test-Path $reportersDir) {
    $reporterFiles = Get-ChildItem -Path $reportersDir -Filter "*.ps1"
    foreach ($file in $reporterFiles) {
        try {
            . $file.FullName
            # Write-Log "Loaded reporter: $($file.Name)" -Color DarkGray -Level Debug
        }
        catch {
            Write-Error "Failed to load reporter '$($file.Name)': $_"
        }
    }
}
else {
    Write-Error "Reporters directory not found: $reportersDir"
}
