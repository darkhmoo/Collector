<#
.SYNOPSIS
    Event Log Reporting Module
.DESCRIPTION
    Contains functions for generating Event Log reports (HTML/CSV).
#>

<#
.SYNOPSIS
    Converts event log data to HTML format.
#>
function ConvertTo-EventLogHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $events,
        
        [Parameter(Mandatory = $true)]
        [string]$logName,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 365)]
        [int]$lookbackDays = 7
    )
    
    $safeLogName = [System.Net.WebUtility]::HtmlEncode($logName)
    $htmlContainer = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$safeLogName Event Log</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f4f4f4; }
        h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; background-color: #fff; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; font-size: 14px; }
        th { background-color: #34495e; color: white; font-weight: 600; position: sticky; top: 0; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        tr:hover { background-color: #f1f1f1; }
        .level-0-failure { color: #e74c3c; font-weight: bold; } /* Audit Failure */
        .level-0-success { color: #27ae60; }               /* Audit Success */
        .level-1 { color: #e74c3c; font-weight: bold; } /* Critical */
        .level-2 { color: #e67e22; font-weight: bold; } /* Error */
        .level-3 { color: #f39c12; } /* Warning */
        .level-4 { color: #3498db; } /* Information */
        .timestamp { font-size: 0.9em; color: #7f8c8d; }
    </style>
</head>
<body>
    <h1>$safeLogName Event Log</h1>
    <div class="timestamp">Generated: $(Get-Date)</div>
    <div class="timestamp">Events: Last $lookbackDays days (Max 100)</div>
    <table>
        <thead>
            <tr>
                <th>Time Created</th>
                <th>Level</th>
                <th>Event ID</th>
                <th>Source</th>
                <th>Message</th>
            </tr>
        </thead>
        <tbody>
"@

    foreach ($logEvent in $events) {
        # Security Í∞êÏÇ¨ ?¥Î≤§??Level=0)??Keywords ?çÏÑ±?ºÎ°ú Audit Success/FailureÎ•?Íµ¨Î∂Ñ
        if ($logEvent.Level -eq 0) {
            $isAuditFailure = ($logEvent.Keywords -band 0x10000000000000) -gt 0
            $levelClass = if ($isAuditFailure) { "level-0-failure" } else { "level-0-success" }
            $levelText = if ($isAuditFailure) { "Audit Failure" } else { "Audit Success" }
        }
        else {
            $levelClass = "level-$($logEvent.Level)"
            $levelText = switch ($logEvent.Level) {
                1 { "Critical" }
                2 { "Error" }
                3 { "Warning" }
                4 { "Information" }
                default { "Unknown" }
            }
        }
        
        $timeCreated = [System.Net.WebUtility]::HtmlEncode($logEvent.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss"))
        $eventId = [System.Net.WebUtility]::HtmlEncode($logEvent.Id)
        $sourceName = [System.Net.WebUtility]::HtmlEncode($logEvent.ProviderName)
        $messageText = [System.Net.WebUtility]::HtmlEncode($logEvent.Message)
        
        $htmlContainer += @"
            <tr>
                <td>$timeCreated</td>
                <td class="$levelClass">$levelText</td>
                <td>$eventId</td>
                <td>$sourceName</td>
                <td>$messageText</td>
            </tr>
"@
    }
    
    $htmlContainer += @"
        </tbody>
    </table>
</body>
</html>
"@
    
    return $htmlContainer
}

<#
.SYNOPSIS
    Exports Event Logs to CSV or HTML files.
.PARAMETER eventLogs
    Hashtable containing event logs.
.PARAMETER outputFormat
    Output format: HTML or CSV.
.PARAMETER outputDir
    Directory to save the files.
#>
function Export-EventLogFiles {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$eventLogs,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("HTML", "CSV")]
        [string]$outputFormat = "HTML",
        
        [Parameter(Mandatory = $true)]
        [string]$outputDir,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 365)]
        [int]$lookbackDays = 7
    )
    
    if ($null -eq $eventLogs -or $eventLogs.Count -eq 0) {
        Write-Log -message "  ! No event logs to export" -color Yellow -level Warning
        return
    }
    
    foreach ($logKey in $eventLogs.Keys) {
        $eventsData = $eventLogs[$logKey]
        
        # Skip if error string or empty
        if ($eventsData -is [string] -or $null -eq $eventsData -or ($eventsData -is [array] -and $eventsData.Count -eq 0)) {
            continue
        }
        
        $fileExtension = if ($outputFormat -eq "HTML") { "html" } else { "csv" }
        $safeLogName = ($logKey -replace '[^\w\.-]', '_')
        $fileName = "Log_${safeLogName}.${fileExtension}"
        $filePath = Join-Path -Path $outputDir -ChildPath $fileName
        
        try {
            Write-Log -message "  - Exporting $logKey Log to $outputFormat..." -color Gray -level Info
            
            if ($outputFormat -eq "CSV") {
                if ($PSCmdlet.ShouldProcess($filePath, "Export Event Log to CSV")) {
                    $eventsData | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
                }
            }
            else {
                # Generate HTML for event log
                if ($PSCmdlet.ShouldProcess($filePath, "Export Event Log to HTML")) {
                    $htmlContent = ConvertTo-EventLogHtml -events $eventsData -logName $logKey -lookbackDays $lookbackDays
                    $htmlContent | Set-Content -Path $filePath -Encoding UTF8
                }
            }
            
            if ($PSCmdlet.ShouldProcess($filePath, "Track generated log file")) {
                $script:generatedFiles += $filePath
            }
            Write-Log -message "    ??Log file processed" -color DarkGray -level Debug
        }
        catch {
            Write-Log -message ("    ??Export failed for {0}: {1}" -f $logKey, $_) -color Red -level Error
        }
    }
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU7sASXghHvPSPUu24quEQascq
# AMCgggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUtGs8f0/ylHoDeQAdkR2LxE2kT90wDQYJ
# KoZIhvcNAQEBBQAEggEApd9r69Q89KMCjKvPfcC9pnFm5q2yrgcq3STnzSMpKcTV
# 3lKFGY+aStnly2wfT9D+Z1pCZbGe65L7IdlwNbh++izYohs5ep195NG8d4GJjek5
# Il0JNYdcy9nQdwxvPuxO3A//G+3xBnAMeYZlIo+wEx0q3jim7I6fJFYcJ5UeTkkq
# GJ9Wd7mPQR/RbYsNVG7UYGi7nAAtpUkCshJTr3RA+KTqxZoMo1UYzPsO6tzcJlf7
# h4iHuNfTn2zL23cCLCp60cOg8SShMjZNCYXcJQDOozfHtY5jDTtugTUl9NT4Ir5h
# jj3W+yYKy1QaUVVJtAX3tV5qITU1X2vbtE4CbRp8Qw==
# SIG # End signature block
