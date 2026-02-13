<#
.SYNOPSIS
    Windows Server System Information Collector (Refactored & Modularized)
.DESCRIPTION
    This script collects detailed configuration of Windows Server environment for diagnosis and asset management.
    
    [Collection Categories]
    1. Hardware & System
    2. Network
    3. OS & Configuration
    4. Service
    5. Performance
    6. Logs (Event Logs saved as separate files)
    7. Security
    8. High Availability

    [Requirements]
    - PowerShell 5.1 or higher
    - Run as Administrator
.NOTES
    Minimum PSVersion: 5.1
    Requires: Run as Administrator
#>

# 1. [Best Practice] Enforce Version at Script Engine Level
#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateScript({
            $validFormats = @("JSON", "HTML", "CSV", "ALL")
            foreach ($format in $_) {
                if ($format -notin $validFormats) {
                    throw "Invalid format '$format'. Valid formats are: JSON, HTML, CSV, ALL"
                }
            }
            return $true
        })]
    [string[]]$OutputFormat = @("HTML"),

    [Parameter(Mandatory = $false)]
    [ValidateSet("HTML", "CSV")]
    [string]$EventLogFormat = "HTML",

    [Parameter(Mandatory = $false)]
    [Switch]$DebugMode
)

# --- 1. Initialization & Input ---
$scriptStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$DebugLogFile = $null

if ($DebugMode) {
    $DebugLogFile = Join-Path -Path $PSScriptRoot -ChildPath "debug_log_$(Get-Date -Format 'yyyyMMddHHmmss').txt"
}

# --- 2. Load Libraries ---
try {
    . "$PSScriptRoot\lib\Common.ps1"
    . "$PSScriptRoot\lib\Collectors.ps1"
    . "$PSScriptRoot\lib\Reporters.ps1"
    . "$PSScriptRoot\lib\OutputManager.ps1"
}
catch {
    Write-Error "CRITICAL ERROR: Failed to load required libraries from 'lib' directory."
    exit 1
}

# --- 3. Pre-flight Checks ---
Assert-AdminPrivileges
Assert-Prerequisites
$mutex = Get-ScriptMutex

Write-Log "[Start] Starting System Environment Analysis (PSVer: $($PSVersionTable.PSVersion))..." -Color Cyan -Level Info
if ($DebugMode) { 
    Write-Log "[DEBUG] Debug Mode Enabled: Logging to $DebugLogFile" -Color Magenta -Level Info
    Write-Log "[DEBUG] Performance tracking enabled" -Color Magenta -Level Debug
}

# --- 4. Data Collection ---
# Track individual step timings
$script:StepTimings = @()

$auditReport = [PSCustomObject]@{
    Timestamp        = Get-Date
    ExecutionTime    = $null # Will be updated later
    Hardware         = Invoke-Collection "1/8 Hardware" { Get-HardwareInfo }
    Network          = Invoke-Collection "2/8 Network" { Get-NetworkInfo }
    OSConfig         = Invoke-Collection "3/8 OS & Config" { Get-OSConfig }
    Services         = Invoke-Collection "4/8 Services" { Get-ServiceInfo }
    Performance      = Invoke-Collection "5/8 Performance" { Get-PerformanceInfo }
    Logs             = Invoke-Collection "6/8 Logs" { Get-LogInfo }
    Security         = Invoke-Collection "7/8 Security" { Get-SecurityInfo }
    HighAvailability = Invoke-Collection "8/8 High Availability" { Get-HighAvailabilityInfo }
}

# Stop Timer
$scriptStopwatch.Stop()
$executionTime = $scriptStopwatch.Elapsed.ToString("hh\:mm\:ss\.fff")
$auditReport.ExecutionTime = $executionTime

Write-Log "`n[Complete] Data collection finished." -Color Green -Level Info
Write-Log "Total Execution Time: $executionTime" -Color Cyan -Level Info

# Display timing summary in debug mode
if ($DebugMode -and $script:StepTimings.Count -gt 0) {
    Write-Log "`n╔════════════════════════════════════════════════════════════════╗" -Color Cyan -Level Debug
    Write-Log "║              PERFORMANCE SUMMARY (Debug Mode)                 ║" -Color Cyan -Level Debug
    Write-Log "╠════════════════════════════════════════════════════════════════╣" -Color Cyan -Level Debug
    
    $totalMs = 0
    foreach ($timing in $script:StepTimings) {
        $totalMs += $timing.DurationMs
        $percentage = [math]::Round(($timing.DurationMs / $scriptStopwatch.ElapsedMilliseconds) * 100, 1)
        $bar = "█" * [math]::Min([int]($percentage / 2), 50)
        
        Write-Log ("║ {0,-30} {1,8:N0}ms {2,5}% {3}" -f $timing.Name, $timing.DurationMs, $percentage, $bar) `
            -Color $(if ($percentage -gt 20) { "Yellow" } elseif ($percentage -gt 10) { "White" } else { "DarkGray" }) -Level Debug
    }
    
    Write-Log "╠════════════════════════════════════════════════════════════════╣" -Color Cyan -Level Debug
    Write-Log ("║ {0,-30} {1,8:N0}ms {2,5}%" -f "TOTAL", $totalMs, 100) -Color Green -Level Debug
    Write-Log "╚════════════════════════════════════════════════════════════════╝" -Color Cyan -Level Debug
    
    # Memory summary
    if ($script:StepTimings[0].MemoryBefore) {
        $memStart = $script:StepTimings[0].MemoryBefore
        $memEnd = $script:StepTimings[-1].MemoryAfter
        $memDelta = $memEnd - $memStart
        
        Write-Log "`n[Memory] Start: ${memStart}MB, End: ${memEnd}MB, Delta: ${memDelta}MB" -Color Magenta -Level Debug
    }
}

# --- 5. Output Generation ---

# Handle "ALL" keyword - expand to all formats
if ($OutputFormat -contains "ALL") {
    $OutputFormat = @("JSON", "HTML", "CSV")
}

# Delegate output generation to OutputManager
Save-Results `
    -AuditReport $auditReport `
    -OutputFormat $OutputFormat `
    -EventLogFormat $EventLogFormat `
    -OutputDirectory $PSScriptRoot `
    -DebugMode $DebugMode

# Release Mutex
if ($mutex) { $mutex.ReleaseMutex(); $mutex.Dispose() }

return $auditReport
