<#
.SYNOPSIS
    Windows Server System Information Collector (Refactored and Modularized)
.DESCRIPTION
    Collects Windows Server configuration details for diagnostics and asset management.

    Collection categories:
    1. Hardware and System
    2. Network
    3. OS and Configuration
    4. Service
    5. Performance
    6. Logs (event logs are exported to separate files)
    7. Security
    8. High Availability

    Requirements:
    - PowerShell 5.1+
    - Run as Administrator
#>

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
    [switch]$DebugMode
)

function Show-PerformanceSummary {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$StepTimings,
        [Parameter(Mandatory = $true)]
        [long]$TotalElapsedMs
    )

    if (-not $StepTimings) { return }

    $safeTotal = if ($TotalElapsedMs -le 0) { 1 } else { $TotalElapsedMs }
    $line = ("=" * 80)
    $totalMs = 0

    Write-Log "`n$line" -Color Cyan -Level Debug
    Write-Log "PERFORMANCE SUMMARY (Debug Mode)" -Color Cyan -Level Debug
    Write-Log $line -Color Cyan -Level Debug

    foreach ($timing in $StepTimings) {
        $totalMs += $timing.DurationMs
        $percentage = [math]::Round(($timing.DurationMs / $safeTotal) * 100, 1)
        $barLength = [math]::Min([int]($percentage / 2), 50)
        $bar = ("#" * $barLength)
        if (-not $bar) { $bar = "-" }

        Write-Log ("{0,-30} {1,8:N0}ms {2,5}% {3}" -f $timing.Name, $timing.DurationMs, $percentage, $bar) `
            -Color $(if ($percentage -gt 20) { "Yellow" } elseif ($percentage -gt 10) { "White" } else { "DarkGray" }) `
            -Level Debug
    }

    Write-Log $line -Color Cyan -Level Debug
    Write-Log ("{0,-30} {1,8:N0}ms {2,5}%" -f "TOTAL", $totalMs, 100) -Color Green -Level Debug
    Write-Log $line -Color Cyan -Level Debug

    if ($StepTimings.Count -gt 0 -and $StepTimings[0].PSObject.Properties.Name -contains "MemoryBefore") {
        $memStart = $StepTimings[0].MemoryBefore
        $memEnd = $StepTimings[-1].MemoryAfter
        $memDelta = $memEnd - $memStart
        Write-Log "`n[Memory] Start: ${memStart}MB, End: ${memEnd}MB, Delta: ${memDelta}MB" -Color Magenta -Level Debug
    }
}

# --- 1. Initialization ---
$scriptStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$script:DebugMode = [bool]$DebugMode
$script:DebugLogFile = $null
$script:generatedFiles = @()
$script:StepTimings = @()

if ($script:DebugMode) {
    $script:DebugLogFile = Join-Path -Path $PSScriptRoot -ChildPath "debug_log_$(Get-Date -Format 'yyyyMMddHHmmss').txt"
}

# --- 2. Load Libraries ---
try {
    . "$PSScriptRoot\lib\Common.ps1"
    . "$PSScriptRoot\lib\Collectors.ps1"
    . "$PSScriptRoot\lib\Reporters.ps1"
    . "$PSScriptRoot\lib\OutputManager.ps1"
}
catch {
    Write-Error "CRITICAL ERROR: Failed to load required libraries from 'lib' directory. $($_.Exception.Message)"
    exit 1
}

# --- 3. Pre-flight Checks and Execution ---
$mutex = $null

try {
    Assert-AdminPrivileges
    Assert-Prerequisites
    $mutex = Get-ScriptMutex

    Write-Log "[Start] Starting System Environment Analysis (PSVer: $($PSVersionTable.PSVersion))..." -Color Cyan -Level Info
    if ($script:DebugMode) {
        Write-Log "[DEBUG] Debug Mode Enabled: Logging to $script:DebugLogFile" -Color Magenta -Level Info
        Write-Log "[DEBUG] Performance tracking enabled" -Color Magenta -Level Debug
    }

    # --- 4. Data Collection ---
    $auditReport = [PSCustomObject]@{
        Timestamp        = Get-Date
        ExecutionTime    = $null
        Hardware         = Invoke-Collection "1/8 Hardware" { Get-HardwareInfo }
        Network          = Invoke-Collection "2/8 Network" { Get-NetworkInfo }
        OSConfig         = Invoke-Collection "3/8 OS and Config" { Get-OSConfig }
        Services         = Invoke-Collection "4/8 Services" { Get-ServiceInfo }
        Performance      = Invoke-Collection "5/8 Performance" { Get-PerformanceInfo }
        Logs             = Invoke-Collection "6/8 Logs" { Get-LogInfo }
        Security         = Invoke-Collection "7/8 Security" { Get-SecurityInfo }
        HighAvailability = Invoke-Collection "8/8 High Availability" { Get-HighAvailabilityInfo }
    }

    $scriptStopwatch.Stop()
    $executionTime = $scriptStopwatch.Elapsed.ToString("hh\:mm\:ss\.fff")
    $auditReport.ExecutionTime = $executionTime

    Write-Log "`n[Complete] Data collection finished." -Color Green -Level Info
    Write-Log "Total Execution Time: $executionTime" -Color Cyan -Level Info

    if ($script:DebugMode -and $script:StepTimings.Count -gt 0) {
        Show-PerformanceSummary -StepTimings $script:StepTimings -TotalElapsedMs $scriptStopwatch.ElapsedMilliseconds
    }

    # --- 5. Output Generation ---
    if ($OutputFormat -contains "ALL") {
        $OutputFormat = @("JSON", "HTML", "CSV")
    }
    $OutputFormat = $OutputFormat | ForEach-Object { $_.ToUpperInvariant() } | Select-Object -Unique

    Save-Results `
        -AuditReport $auditReport `
        -OutputFormat $OutputFormat `
        -EventLogFormat $EventLogFormat `
        -OutputDirectory $PSScriptRoot `
        -DebugMode $script:DebugMode

    return $auditReport
}
finally {
    if ($mutex) {
        try {
            $mutex.ReleaseMutex()
        }
        catch {
            Write-Log "[Warning] Failed to release mutex cleanly: $_" -Color Yellow -Level Warning
        }
        finally {
            $mutex.Dispose()
        }
    }
}
