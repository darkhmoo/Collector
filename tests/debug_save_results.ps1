# Debug Script for Save-Results
$ErrorActionPreference = "Stop"

Write-Host "DEBUG: Starting Save-Results Test" -ForegroundColor Magenta

# 1. Define paths (Relative to tests directory)
$scriptRoot = Split-Path -Parent $PSScriptRoot
$libPath = Join-Path $scriptRoot "lib"
$outputPath = Join-Path $scriptRoot "result"

if (-not (Test-Path -Path $outputPath -PathType Container)) {
    New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
}

Write-Host "DEBUG: Script Root: $scriptRoot"
Write-Host "DEBUG: Output Path: $outputPath"

# 2. Load Libraries
try {
    . (Join-Path $libPath "Common.ps1")
    . (Join-Path $libPath "OutputManager.ps1")
    . (Join-Path $libPath "Reporters.ps1") # For Export-EventLogFiles and ConvertTo-HtmlReport logic
    # Also need to load EventLogReporter if separate, but Reporters.ps1 usually loads them.
    # Let's check Reporters.ps1 content later if needed. Assuming it loads sub-reporters.
    # Actually, verify if Reporters.ps1 loads EventLogReporter.ps1
    $eventLogReporterPath = Join-Path $libPath "reporters\EventLogReporter.ps1"
    if (Test-Path $eventLogReporterPath) {
        . $eventLogReporterPath
    }
    
    # Also load HtmlReporter if it exists
    $htmlReporterPath = Join-Path $libPath "reporters\HtmlReporter.ps1"
    if (Test-Path $htmlReporterPath) {
        . $htmlReporterPath
    }

    Write-Host "DEBUG: Libraries Loaded Successfully" -ForegroundColor Green
}
catch {
    Write-Error "DEBUG: Failed to load libraries: $_"
    exit 1
}

# 3. Create Dummy Data
$dummyReport = [PSCustomObject]@{
    ExecutionTime = "00:00:01"
    Info          = @{
        Hostname = "DEBUG-HOST"
        OS       = "Debug OS"
    }
    Logs          = @{
        EventLogs = @{} # Empty for now
    }
}

# 4. Attempt Save
Write-Host "DEBUG: Calling Save-Results..." -ForegroundColor Cyan
try {
    Save-Results `
        -auditReport $dummyReport `
        -outputFormat @("HTML", "JSON") `
        -eventLogFormat "HTML" `
        -outputDirectory $outputPath `
        -isDebugMode $true `
        -zipResults $false `
        -encryptionKey $null 
        
    Write-Host "DEBUG: Save-Results Completed" -ForegroundColor Green
}
catch {
    Write-Error "DEBUG: Save-Results Failed: $_"
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}

# 5. Check Files
Write-Host "DEBUG: Checking for files..."
$files = Get-ChildItem -Path $outputPath -Filter "result_*.html"
if ($files) {
    Write-Host "SUCCESS: Found $($files.Count) HTML files." -ForegroundColor Green
    $files | Select-Object Name, LastWriteTime
}
else {
    Write-Host "FAILURE: No HTML files found." -ForegroundColor Red
}
