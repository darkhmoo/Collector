<#
.SYNOPSIS
    Windows System Information Collector (Clean Code & Advanced Function Version)
.DESCRIPTION
    Collects configuration information from Windows servers and workstations for diagnostic and asset management purposes.
    Written in compliance with PowerShell Clean Code guidelines.
    
    Collection Categories:
    1. Hardware, 2. Network, 3. OSConfig, 4. Virtualization, 5. Services, 
    6. Performance, 7. Logs, 8. Security, 9. Inventory, 10. ActiveDirectory, 11. HighAvailability

.PARAMETER OutputFormat
    Specifies the output format (JSON, HTML, CSV, ALL). Default is HTML.
.PARAMETER EventLogFormat
    Specifies the output format for event logs (HTML, CSV). Default is HTML.
.PARAMETER Modules
    Specifies which modules to collect. Default is ALL.
.PARAMETER OutputPath
    Specifies the directory path where result files will be saved. Default is the script root.
.PARAMETER DebugMode
    Enables debug mode to collect detailed logs and performance data.
.PARAMETER Compress
    Enables automatic ZIP compression of result files. Default is Disabled ($false).
.PARAMETER Encrypt
    Enables AES-256 encryption for each individual report file. Requires user to input a key securely.
.PARAMETER ShowHelp
    Immediately opens the Usage Guide (USAGE_GUIDE.md) matching the system locale.
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [ValidateScript({
            $validFormats = @("JSON", "HTML", "CSV", "ALL")
            foreach ($format in $_) {
                if ($format.ToUpper() -notin $validFormats) {
                    throw "Invalid format '$format'. Valid formats are: JSON, HTML, CSV, ALL"
                }
            }
            return $true
        })]
    [string[]]$outputFormat = @("HTML"),

    [Parameter(Mandatory = $false)]
    [ValidateSet("HTML", "CSV")]
    [string]$eventLogFormat = "HTML",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Hardware", "Network", "OSConfig", "Inventory", "Virtualization", "Services", "Performance", "Logs", "Security", "ActiveDirectory", "HighAvailability", "ALL")]
    [string[]]$modules = "ALL",

    [Parameter(Mandatory = $false)]
    [ValidateScript({
            if (-not (Test-Path -Path $_ -PathType Container)) {
                # Directory creation is a side effect, handled by ShouldProcess later or during init
            }
            return $true
        })]
    [string]$outputPath = $PSScriptRoot,

    [Parameter(Mandatory = $false)]
    [switch]$Compress,

    [Parameter(Mandatory = $false)]
    [switch]$Encrypt,

    [Parameter(Mandatory = $false)]
    [switch]$debugMode,

    [Parameter(Mandatory = $false)]
    [switch]$parallel,

    [Parameter(Mandatory = $false)]
    [switch]$showHelp
)

<#
.SYNOPSIS
    Displays performance summary to the log stream.
#>
function Show-PerformanceSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$stepTimings,
        
        [Parameter(Mandatory = $true)]
        [long]$totalElapsedMs
    )

    if (-not $stepTimings) { return }

    $safeTotal = if ($totalElapsedMs -le 0) { 1 } else { $totalElapsedMs }
    $separator = ("=" * 80)
    $accumulatedMs = 0

    Write-Log -message "`n$separator" -color Cyan -level Debug
    Write-Log -message "PERFORMANCE SUMMARY (Clean Code Mode)" -color Cyan -level Debug
    Write-Log -message $separator -color Cyan -level Debug

    foreach ($timing in $stepTimings) {
        $accumulatedMs += $timing.DurationMs
        $percentage = [math]::Round(($timing.DurationMs / $safeTotal) * 100, 1)
        $barLength = [math]::Min([int]($percentage / 2), 50)
        $progressBar = ("#" * $barLength)
        if (-not $progressBar) { $progressBar = "-" }

        $colorCode = if ($percentage -gt 20) { "Yellow" } elseif ($percentage -gt 10) { "White" } else { "DarkGray" }
        Write-Log -message ("{0,-30} {1,8:N0}ms {2,5}% {3}" -f $timing.Name, $timing.DurationMs, $percentage, $progressBar) `
            -color $colorCode `
            -level Debug
    }

    Write-Log -message $separator -color Cyan -level Debug
    Write-Log -message ("{0,-30} {1,8:N0}ms {2,5}%" -f "TOTAL", $accumulatedMs, 100) -color Green -level Debug
    Write-Log -message $separator -color Cyan -level Debug

    if ($stepTimings.Count -gt 0 -and $stepTimings[0].PSObject.Properties.Name -contains "MemoryBefore") {
        $memStart = $stepTimings[0].MemoryBefore
        $memEnd = $stepTimings[-1].MemoryAfter
        $memDelta = $memEnd - $memStart
        Write-Log -message "`n[Memory] Start: ${memStart}MB, End: ${memEnd}MB, Delta: ${memDelta}MB" -color Magenta -level Debug
    }
}

# --- INITIALIZATION ---
$scriptStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$script:DebugMode = [bool]$debugMode
$script:DebugLogFile = $null
$script:generatedFiles = @()
$script:StepTimings = @()

if ($script:DebugMode) {
    if ($PSCmdlet.ShouldProcess("Local System", "Enable Verbose Debug Logging")) {
        $script:DebugLogFile = Join-Path -Path $PSScriptRoot -ChildPath "debug_log_$(Get-Date -Format 'yyyyMMddHHmmss').txt"
    }
}

# Ensure Output Directory exists
if (-not (Test-Path -path $outputPath -pathType Container)) {
    if ($PSCmdlet.ShouldProcess($outputPath, "Create output directory")) {
        New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
    }
}

# Load Libraries
try {
    # Load core libraries first
    . (Join-Path $PSScriptRoot "lib\Classes.ps1")
    . (Join-Path $PSScriptRoot "lib\Common.ps1")
    . (Join-Path $PSScriptRoot "lib\Collectors.ps1")
    . (Join-Path $PSScriptRoot "lib\Reporters.ps1")
    . (Join-Path $PSScriptRoot "lib\OutputManager.ps1")
}
catch {
    Write-Error "CRITICAL: Failed to load libraries. $($_.Exception.Message)"
    exit 1
}

# --- MAIN EXECUTION ---
$globalMutex = $null

try {
    # Check for ShowHelp early
    if ($showHelp) {
        if (Get-Command Open-LocalizedDoc -ErrorAction SilentlyContinue) {
            Open-LocalizedDoc -docName "USAGE_GUIDE.md" -scriptRoot $PSScriptRoot
            return
        }
        else {
            Write-Error "Documentation helper (Open-LocalizedDoc) not loaded."
            return
        }
    }

    Assert-AdminPrivileges
    # 1. Mutex Ownership Check (Audit Fix: Ensure we only release if we own it)
    $globalMutex = $null
    try {
        $globalMutex = Get-ScriptMutex
    }
    catch {
        Write-Error $_
        exit 1
    }

    Write-Log -message "[Start] Analyzing system environment..." -color Cyan -level Info
    
    # 0.5 Encryption Key Setup (New: Exhaustive Audit Fix)
    $encryptionKey = $null
    if ($Encrypt) {
        Write-Log -message "[Secure] Encryption enabled. Please enter your secret key in the secure prompt." -color Magenta -level Info
        $encryptionKey = Read-Host "Enter encryption key" -AsSecureString
        if (-not $encryptionKey) {
            throw "Encryption key cannot be empty when -Encrypt is used."
        }
    }

    if ($script:DebugMode) {
        Write-Log -message "[DEBUG] Logging to $script:DebugLogFile" -color Magenta -level Info
    }

    # Data Collection Registry
    $isAll = "ALL" -in $modules
    
    $modulesToCollect = [ordered]@{}
    if ($isAll -or "Hardware" -in $modules) { $modulesToCollect["Hardware"] = { Get-HardwareInfo } }
    if ($isAll -or "Network" -in $modules) { $modulesToCollect["Network"] = { Get-NetworkInfo } }
    if ($isAll -or "OSConfig" -in $modules) { $modulesToCollect["OSConfig"] = { Get-OSConfig } }
    if ($isAll -or "Virtualization" -in $modules) { $modulesToCollect["Virtualization"] = { Get-VirtualizationInfo } }
    if ($isAll -or "Services" -in $modules) { $modulesToCollect["Services"] = { Get-ServiceInfo } }
    if ($isAll -or "Performance" -in $modules) { $modulesToCollect["Performance"] = { Get-PerformanceInfo } }
    if ($isAll -or "Logs" -in $modules) { $modulesToCollect["Logs"] = { Get-LogInfo } }
    if ($isAll -or "Security" -in $modules) { $modulesToCollect["Security"] = { Get-SecurityInfo } }
    if ($isAll -or "Inventory" -in $modules) { $modulesToCollect["Inventory"] = { Get-InventoryInfo } }
    if ($isAll -or "ActiveDirectory" -in $modules) { $modulesToCollect["ActiveDirectory"] = { Get-ActiveDirectoryInfo } }
    if ($isAll -or "HighAvailability" -in $modules) { $modulesToCollect["HighAvailability"] = { Get-HighAvailabilityInfo -WhatIf:$WhatIfPreference } }

    $totalCount = $modulesToCollect.Count
    $auditReport = [PSCustomObject]@{
        Timestamp     = Get-Date
        ExecutionTime = $null
    }

    if ($parallel) {
        # Parallel Execution
        $parallelTasks = @()
        $index = 1
        foreach ($key in $modulesToCollect.Keys) {
            $parallelTasks += [PSCustomObject]@{
                Key   = $key
                Name  = "$index/$totalCount $key"
                Block = $modulesToCollect[$key]
            }
            $index++
        }
        
        $parallelResults = Invoke-ParallelCollection -tasks $parallelTasks -scriptRoot $PSScriptRoot
        foreach ($key in $parallelResults.Keys) {
            $taskResult = $parallelResults[$key]
            
            # Unpack data and merge state
            if ($taskResult -is [PSCustomObject] -and $taskResult.PSObject.Properties.Name -contains "Data") {
                $auditReport | Add-Member -NotePropertyName $key -NotePropertyValue $taskResult.Data
                
                # Merge StepTimings
                if ($taskResult.StepTimings) {
                    $script:StepTimings += $taskResult.StepTimings
                }
                
                # Merge GeneratedFiles
                if ($taskResult.GeneratedFiles) {
                    foreach ($file in $taskResult.GeneratedFiles) {
                        if ($file -notin $script:generatedFiles) {
                            $script:generatedFiles += $file
                        }
                    }
                }
            }
            else {
                # Fallback for unexpected return format
                $auditReport | Add-Member -NotePropertyName $key -NotePropertyValue $taskResult
            }
        }
    }
    else {
        # Sequential Execution (Default)
        $index = 1
        foreach ($key in $modulesToCollect.Keys) {
            $taskName = "$index/$totalCount $key"
            $result = Invoke-Collection -taskName $taskName -collectionBlock $modulesToCollect[$key]
            $auditReport | Add-Member -NotePropertyName $key -NotePropertyValue $result
            $index++
        }
    }

    $scriptStopwatch.Stop()
    $formattedExecutionTime = $scriptStopwatch.Elapsed.ToString("hh\:mm\:ss\.fff")
    $auditReport.ExecutionTime = $formattedExecutionTime

    Write-Log -message "`n[Complete] Collection finished in $formattedExecutionTime" -color Green -level Info

    if ($script:DebugMode -and $script:StepTimings.Count -gt 0) {
        Show-PerformanceSummary -stepTimings $script:StepTimings -totalElapsedMs $scriptStopwatch.ElapsedMilliseconds
    }

    # --- OUTPUT GENERATION ---
    $finalOutputFormats = if ($outputFormat -contains "ALL") { @("JSON", "HTML", "CSV") } else { $outputFormat }
    $finalOutputFormats = $finalOutputFormats | ForEach-Object { $_.ToUpper() } | Select-Object -Unique

    Save-Results `
        -auditReport $auditReport `
        -outputFormat $finalOutputFormats `
        -eventLogFormat $eventLogFormat `
        -outputDirectory $outputPath `
        -isDebugMode $script:DebugMode `
        -zipResults $Compress `
        -encryptionKey $encryptionKey `
        -WhatIf:$WhatIfPreference

    return $auditReport
}
finally {
    if ($globalMutex) {
        try { $globalMutex.ReleaseMutex() } catch { Write-Warning "Mutex release warning: $_" }
        finally { $globalMutex.Dispose() }
    }
    # Final cleanup of memory
    [System.GC]::Collect()
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU9sQI22PggQfsBk2FBctBr19C
# AzGgggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
# AQsFADAkMSIwIAYDVQQDDBlDb2xsZWN0b3ItSW50ZXJuYWwtU2lnbmVyMB4XDTI2
# MDIxMzE2MzExMloXDTI3MDIxMzE2NTExMlowJDEiMCAGA1UEAwwZQ29sbGVjdG9y
# LUludGVybmFsLVNpZ25lcjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
# ANvUNS+3ZOqv6/Wjx4K6mUvzpMqoAAToxWCryus4grdBQG7zH2M/2en1b750HzGs
# Xhr2macyH+9rVzsYHYF5llyxw08XQ6X36vMbJEVoR+5KOf/zJrA2c480Rdc2m1BH
# BDNkhKC7/P4pCaYYi+sxe68Ind6KYjIIL8wRMFRy77FZRiL3iUINYK3yMEnSrkfK
# DVtAM26Urogj/zfmozn05f3q9nk7wnlSAzBFgYrqZ0LAClDEiqrN5W2S2Tz465uN
# jkLiBJ3R+fJf6duLybme+A6uqmmVRTukL8/uUB19fJw7lx1OfmIBoJQ0p6myy8hS
# Wz/kgKl2drA3emG4e6BpckECAwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeAMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBTAAzQigManKpFUSzB+/+hZM7g9AjAN
# BgkqhkiG9w0BAQsFAAOCAQEAA9jrmfv21FtuqvRvy4gz7aUuHI/o0dtaia/3QYKI
# Q04YkCTVMP63j/d2ISNM1Xwn8qnRBr93jO0hI+lpf9ELW2hnJwyaHqhJzQsBvBM6
# CowvqaPa+S9+9Hc7sY2aVGWcSXJwXcqy6pzkOHuzPouTk0hfsekRRivafQYH5Xeh
# Ui7+fQmPLrZmLQPOLx8mAMaLsPUYDAE8j99aa2ulg6KZYO7F0zy0Veqjs+8pSIIE
# V0H2+ApOKEbZP4NWUeaFq9vycZwURZPjYrNSckbJ5M9jTANbNaMs2ZAEZ+HrpPSt
# wvUWonVftmZpq3dJ2ClpXnDwUz/yYEJ1dzUT9YDZDDbOVzGCAdkwggHVAgEBMDgw
# JDEiMCAGA1UEAwwZQ29sbGVjdG9yLUludGVybmFsLVNpZ25lcgIQGWEUqQpfT6JP
# YbwYRk6SXjAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUjsORtQu1wnZEdXhFuueFH4cuOcswDQYJ
# KoZIhvcNAQEBBQAEggEAlJGJgS9R4PKoAg0BTIDH4uOmrKHMyctyeIMTGl4ChfJU
# so71ph/RANJ+/GnNVluqsIKaQeDgHHPLMKM/pdoUllkvmrt55nozaAPcitrYiERT
# gGwRo5/opoTE1cPhYSzkaRUd0/1PpyFYLDJ48hTKn7w4kWfi7OgJ0IQSPhl4/JJq
# riMK33LFotOt7czMe4vKsGXdMrrI10yp/wRmy4IU2Mr4HMfGWHBOtAyhrtyuaO1W
# 5OeUF1jttSdl6pUdK9f77WVvArvXKbN3RpA94TgEatBH7xFFg0H1mRA5/BQSwmBQ
# kN/xO95EwJ94S51pPbj+kCT1pvsrhbVNHzoTuI6f7w==
# SIG # End signature block
