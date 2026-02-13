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
    param(
        $Events,
        [string]$LogName
    )
    
    $safeLogName = [System.Net.WebUtility]::HtmlEncode($LogName)
    $html = @"
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
    <div class="timestamp">Events: Last 7 days (Max 100)</div>
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

    foreach ($logEvent in $Events) {
        $levelClass = "level-$($logEvent.Level)"
        $levelText = switch ($logEvent.Level) {
            1 { "Critical" }
            2 { "Error" }
            3 { "Warning" }
            4 { "Information" }
            default { "Unknown" }
        }
        
        $timeCreated = [System.Net.WebUtility]::HtmlEncode($logEvent.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss"))
        $eventId = [System.Net.WebUtility]::HtmlEncode($logEvent.Id)
        $source = [System.Net.WebUtility]::HtmlEncode($logEvent.ProviderName)
        $message = [System.Net.WebUtility]::HtmlEncode($logEvent.Message)
        
        $html += @"
            <tr>
                <td>$timeCreated</td>
                <td class="$levelClass">$levelText</td>
                <td>$eventId</td>
                <td>$source</td>
                <td>$message</td>
            </tr>
"@
    }
    
    $html += @"
        </tbody>
    </table>
</body>
</html>
"@
    
    return $html
}

<#
    .SYNOPSIS
        Exports Event Logs to CSV or HTML files.
    .PARAMETER EventLogs
        Hashtable containing event logs.
    .PARAMETER Format
        Output format: HTML or CSV.
    .PARAMETER OutputDir
        Directory to save the files.
#>
function Export-EventLogFiles {
    param(
        [Hashtable]$EventLogs,
        [string]$Format = "HTML",
        [string]$OutputDir
    )
    
    if ($null -eq $EventLogs -or $EventLogs.Count -eq 0) {
        Write-Log "  ! No event logs to export" -Color Yellow -Level Warning
        return
    }
    
    foreach ($logName in $EventLogs.Keys) {
        $events = $EventLogs[$logName]
        
        # Skip if error string or empty
        if ($events -is [String] -or $null -eq $events -or ($events -is [Array] -and $events.Count -eq 0)) {
            continue
        }
        
        $fileExtension = if ($Format -eq "HTML") { "html" } else { "csv" }
        $safeFileLogName = ($logName -replace '[^\w\.-]', '_')
        $fileName = "Log_${safeFileLogName}.${fileExtension}"
        $filePath = Join-Path -Path $OutputDir -ChildPath $fileName
        
        try {
            Write-Log "  - Exporting $logName Log to $Format..." -Color Gray -Level Info
            
            if ($Format -eq "CSV") {
                $events | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
            }
            else {
                # Generate HTML for event log
                $htmlContent = ConvertTo-EventLogHtml -Events $events -LogName $logName
                $htmlContent | Set-Content -Path $filePath -Encoding UTF8
            }
            
            $script:generatedFiles += $filePath
            Write-Log "    ✓ Saved to $fileName" -Color DarkGray -Level Debug
        }
        catch {
            Write-Log ("    ✗ Export failed for {0}: {1}" -f $logName, $_) -Color Red -Level Error
        }
    }
}
