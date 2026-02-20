<#
.SYNOPSIS
    Event Logs and System Logs Collector (Class-based)
#>

<#
.SYNOPSIS
    Collects Event Logs data.
#>
function Get-EventLogs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 365)]
        [int]$LookbackDays = 7
    )

    $eventLogsData = @{}
    $logFolders = @(
        'System',
        'Application',
        'Security',
        'Setup',
        'Microsoft-Windows-Winlogon/Operational',
        'Microsoft-Windows-GroupPolicy/Operational',
        'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational',
        'Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational',
        'Microsoft-Windows-Diagnostics-Performance/Operational'
    )
    $criticalOnlyLogs = @('System', 'Application')
    $unfilteredLogs = @(
        'Setup',
        'Microsoft-Windows-Winlogon/Operational',
        'Microsoft-Windows-GroupPolicy/Operational',
        'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational',
        'Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational',
        'Microsoft-Windows-Diagnostics-Performance/Operational'
    )
    $lookbackMilliseconds = [int64]$LookbackDays * 24 * 60 * 60 * 1000
    $isAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).
        IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    foreach ($logName in $logFolders) {
        try {
            Write-Log -message "  - Collecting $logName Log..." -color Gray -Level Info

            if ($logName -eq 'Security') {
                if (-not $isAdmin) {
                    $securityError = "Access denied to Security log. Run PowerShell as Administrator."
                    Write-Log -message "  ! $securityError" -color Yellow -level Warning
                    $eventLogsData[$logName] = "Error: $securityError"
                    continue
                }
            }

            # Check channel availability/status first to avoid hard failures on optional channels.
            try {
                $logInfo = Get-WinEvent -ListLog $logName -ErrorAction Stop
                if (-not $logInfo.IsEnabled) {
                    Write-Log -message "  - $logName is disabled. Skipping." -color DarkGray -level Debug
                    $eventLogsData[$logName] = @()
                    continue
                }

                if ($logInfo.FileSize -gt 1GB) {
                    Write-Log -message "  ! Warning: $logName log file is very large ($([math]::Round($logInfo.FileSize / 1GB, 2)) GB). Limiting event count to 50 for performance." -color Yellow -level Warning
                    $maxEvents = 50
                }
                else {
                    $maxEvents = 100
                }
            }
            catch {
                $listErrorText = $_.Exception.Message
                Write-Log -message "  - $logName channel unavailable or inaccessible: $listErrorText" -color DarkGray -level Debug
                $eventLogsData[$logName] = @()
                continue
            }

            if ($unfilteredLogs -contains $logName) {
                $recentEvents = Get-WinEvent -LogName $logName -MaxEvents $maxEvents -ErrorAction Stop | 
                Select-Object TimeCreated, Level, Id, ProviderName, Message, Keywords
            }
            elseif ($criticalOnlyLogs -contains $logName) {
                $xmlFilter = @"
<QueryList>
  <Query Id="0" Path="$logName">
    <Select Path="$logName">*[System[(Level=1 or Level=2 or Level=3) and TimeCreated[timediff(@SystemTime) &lt;= $lookbackMilliseconds]]]</Select>
  </Query>
</QueryList>
"@
                $recentEvents = Get-WinEvent -FilterXml $xmlFilter -MaxEvents $maxEvents -ErrorAction Stop | 
                Select-Object TimeCreated, Level, Id, ProviderName, Message, Keywords
            }
            else {
                $xmlFilter = @"
<QueryList>
  <Query Id="0" Path="$logName">
    <Select Path="$logName">*[System[TimeCreated[timediff(@SystemTime) &lt;= $lookbackMilliseconds]]]</Select>
  </Query>
</QueryList>
"@
                $recentEvents = Get-WinEvent -FilterXml $xmlFilter -MaxEvents $maxEvents -ErrorAction Stop | 
                Select-Object TimeCreated, Level, Id, ProviderName, Message, Keywords
            }
            
            if ($recentEvents) {
                $eventLogsData[$logName] = $recentEvents
            }
            else { $eventLogsData[$logName] = @() }
        }
        catch {
            $errorText = $_.Exception.Message
            if ($errorText -like "*No events were found that match the specified selection criteria*") {
                Write-Log -message "  - No matching events found in $logName log for the selected window." -color DarkGray -level Debug
                $eventLogsData[$logName] = @()
            }
            else {
                Write-Log -message "  ! Failed to collect $logName log: $errorText" -color Yellow -level Warning
                $eventLogsData[$logName] = "Error: $errorText"
            }
        }
    }
    return $eventLogsData
}

<#
.SYNOPSIS
    Collects Windows Update related logs.
#>
function Get-WindowsUpdateInfo {
    [CmdletBinding()]
    param()

    $updateLogs = [PSCustomObject]@{ PendingXml = $null; DismLog = $null; CbsLog = $null }
    $systemRootPath = $env:SystemRoot
    if (-not $systemRootPath) { return $updateLogs }
    
    # Pending.xml
    $pendingXmlPath = Join-Path -Path $systemRootPath -ChildPath 'SoftwareDistribution\ReportingEvents\Pending.xml'
    if (Test-Path -Path $pendingXmlPath -PathType Leaf) {
        try { $updateLogs.PendingXml = Get-Content -Path $pendingXmlPath -Raw -Encoding UTF8 -ErrorAction Stop } catch {}
    }
    # DISM.log
    $dismLogPath = Join-Path -Path $systemRootPath -ChildPath 'Logs\DISM\dism.log'
    if (Test-Path -Path $dismLogPath -PathType Leaf) {
        try { 
            $dismFile = Get-Item -Path $dismLogPath
            if ($dismFile.Length -gt 10MB) { $updateLogs.DismLog = Get-Content -Path $dismLogPath -Tail 10000 -Encoding UTF8 -ErrorAction Stop | Out-String }
            else { $updateLogs.DismLog = Get-Content -Path $dismLogPath -Raw -Encoding UTF8 -ErrorAction Stop }
        }
        catch {}
    }
    # CBS.log
    $cbsLogPath = Join-Path -Path $systemRootPath -ChildPath 'Logs\CBS\CBS.log'
    if (Test-Path -Path $cbsLogPath -PathType Leaf) {
        try { 
            $cbsFile = Get-Item -Path $cbsLogPath
            if ($cbsFile.Length -gt 10MB) { $updateLogs.CbsLog = Get-Content -Path $cbsLogPath -Tail 10000 -Encoding UTF8 -ErrorAction Stop | Out-String }
            else { $updateLogs.CbsLog = Get-Content -Path $cbsLogPath -Raw -Encoding UTF8 -ErrorAction Stop }
        }
        catch {}
    }
    return $updateLogs
}

class LogCollector : BaseCollector {
    [int]$LookbackDays

    LogCollector([int]$lookbackDays) : base("Logs", "Diagnostics") {
        $this.LookbackDays = $lookbackDays
    }

    [PSObject] Collect() {
        $this.LogStart()
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        $data = [PSCustomObject]@{
            NTEventLogInfo = Get-CimSafe -className Win32_NTEventlogFile | Select-Object Name, LogfileName, MaxFileSize, NumberOfRecords
            Hotfixes       = Get-CimSafe -className Win32_QuickFixEngineering
            EventLogs      = Get-EventLogs -LookbackDays $this.LookbackDays
            EventLogLookbackDays = $this.LookbackDays
            WindowsUpdate  = Get-WindowsUpdateInfo
        }

        $sw.Stop()
        $this.LogEnd($sw.ElapsedMilliseconds)
        return $data
    }
}

function Get-LogInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 365)]
        [int]$LookbackDays = 7
    )

    return ([LogCollector]::new($LookbackDays)).Collect()
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU+rEXKMOOs2QRfc0IpfeGy8Hc
# XWKgggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUurmt5roDK+kvC5rX40RM7xitkIgwDQYJ
# KoZIhvcNAQEBBQAEggEA1QNzBjET7OP0G/9X2MvzCDiRH5liWJ55qKHTNWvSarF4
# XiUAERcTw7tTbp4OVz3BAqOETkTTul04qtfrrtmEIH9KfwnlTCFaQxumzf8W1yr7
# 67eP1A5ROgf50Tk3cU4wVwcmqKUiOkMLpydQlfU3XY0zhqAIhlghgyF0MG8F4FEU
# ilkGcH8GtsYqmUrzvfsK546c0Bf8zcIyX0LDHB4MKbZnv6kUVtTh90/PHjoKFSw0
# FEUESZCbuWXrip4j0gw52X5+Jo090/NO3lQEpbSN9nByQsQGet4H4gKzT9q5md/6
# fjzQJk+PVBGjacUnXXzZ8qN9eOGVAbAKKq3NVmbu4Q==
# SIG # End signature block
