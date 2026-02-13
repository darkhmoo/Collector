<#
.SYNOPSIS
    Collects Event Logs data.
.DESCRIPTION
    Retrieves recent event logs from System, Application, and Security logs.
    Returns a hashtable containing the events.
#>
function Get-EventLogs {
    $logData = @{}
    $logTypes = @('System', 'Application', 'Security')
    
    foreach ($logName in $logTypes) {
        try {
            Write-Log "  - Collecting $logName Log..." -Color Gray -Level Info
            
            # Performance optimization: Use -MaxEvents
            # Security: Only select necessary properties
            $events = Get-WinEvent -FilterHashtable @{
                LogName   = $logName
                Level     = 1, 2, 3
                StartTime = (Get-Date).AddDays(-7)
            } -MaxEvents 100 -ErrorAction SilentlyContinue | 
            Select-Object TimeCreated, Level, Id, ProviderName, Message
            
            if ($events) {
                $logData[$logName] = $events
                Write-Log "    ✓ Collected $($events.Count) events" -Color DarkGray -Level Debug
            }
            else {
                $logData[$logName] = @()
                Write-Log "    ! No events found" -Color Yellow -Level Warning
            }
        }
        catch {
            Write-Log "    ✗ Collection failed: $_" -Color Red -Level Error
            $logData[$logName] = "Error: $_"
        }
    }
    return $logData
}

<#
.SYNOPSIS
    Collects Windows Update related logs.
#>
function Get-WindowsUpdateInfo {
    Write-Log "  - Collecting Windows Update logs..." -Color Gray -Level Debug
    
    $wuInfo = [PSCustomObject]@{
        PendingXml = $null
        DismLog    = $null
        CbsLog     = $null
    }
    
    # Security: Use environment variable instead of hardcoded path
    $systemRoot = $env:SystemRoot
    if (-not $systemRoot) {
        Write-Log "    ! SystemRoot environment variable not found" -Color Yellow -Level Warning
        return $wuInfo
    }
    
    # Pending.xml
    $pendingPath = Join-Path $systemRoot 'SoftwareDistribution\ReportingEvents\Pending.xml'
    if ((Test-Path $pendingPath -PathType Leaf)) {
        try {
            Write-Log "    - Reading Pending.xml..." -Color DarkGray -Level Debug
            $wuInfo.PendingXml = Get-Content $pendingPath -Raw -ErrorAction Stop
            Write-Log "    ✓ Pending.xml collected" -Color DarkGray -Level Debug
        }
        catch {
            Write-Log "    ✗ Failed to read Pending.xml: $_" -Color Red -Level Error
        }
    }
    else {
        Write-Log "    ! Pending.xml not found" -Color DarkGray -Level Debug
    }
    
    # DISM log
    $dismPath = Join-Path $systemRoot 'Logs\DISM\dism.log'
    if ((Test-Path $dismPath -PathType Leaf)) {
        try {
            Write-Log "    - Reading dism.log..." -Color DarkGray -Level Debug
            # Security: Limit file size to prevent memory issues
            $dismFile = Get-Item $dismPath
            if ($dismFile.Length -gt 10MB) {
                Write-Log "    ! dism.log is large ($([math]::Round($dismFile.Length/1MB, 2))MB), reading last 10MB only" -Color Yellow -Level Warning
                $wuInfo.DismLog = Get-Content $dismPath -Tail 10000 -ErrorAction Stop | Out-String
            }
            else {
                $wuInfo.DismLog = Get-Content $dismPath -Raw -ErrorAction Stop
            }
            Write-Log "    ✓ dism.log collected" -Color DarkGray -Level Debug
        }
        catch {
            Write-Log "    ✗ Failed to read dism.log: $_" -Color Red -Level Error
        }
    }
    else {
        Write-Log "    ! dism.log not found" -Color DarkGray -Level Debug
    }
    
    # CBS log
    $cbsPath = Join-Path $systemRoot 'Logs\CBS\CBS.log'
    if ((Test-Path $cbsPath -PathType Leaf)) {
        try {
            Write-Log "    - Reading CBS.log..." -Color DarkGray -Level Debug
            # Security: Limit file size to prevent memory issues
            $cbsFile = Get-Item $cbsPath
            if ($cbsFile.Length -gt 10MB) {
                Write-Log "    ! CBS.log is large ($([math]::Round($cbsFile.Length/1MB, 2))MB), reading last 10MB only" -Color Yellow -Level Warning
                $wuInfo.CbsLog = Get-Content $cbsPath -Tail 10000 -ErrorAction Stop | Out-String
            }
            else {
                $wuInfo.CbsLog = Get-Content $cbsPath -Raw -ErrorAction Stop
            }
            Write-Log "    ✓ CBS.log collected" -Color DarkGray -Level Debug
        }
        catch {
            Write-Log "    ✗ Failed to read CBS.log: $_" -Color Red -Level Error
        }
    }
    else {
        Write-Log "    ! CBS.log not found" -Color DarkGray -Level Debug
    }
    
    return $wuInfo
}

<#
.SYNOPSIS
    Collects Event Logs and Log configuration.
#>
function Get-LogInfo {
    [PSCustomObject]@{
        EventLogConfig = Get-CimSafe -ClassName Win32_NTEventlogFile
        QuickFix       = Get-CimSafe -ClassName Win32_QuickFixEngineering
        EventLogs      = Get-EventLogs
        WindowsUpdate  = Get-WindowsUpdateInfo
    }
}
