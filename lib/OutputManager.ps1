<#
.SYNOPSIS
    Output Management Module
.DESCRIPTION
    Handles saving, compressing, and cleaning up report files.
#>

function Save-Results {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$AuditReport,
        
        [Parameter(Mandatory = $true)]
        [string[]]$OutputFormat,
        
        [Parameter(Mandatory = $true)]
        [string]$EventLogFormat,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputDirectory,
        
        [Parameter(Mandatory = $true)]
        [bool]$DebugMode
    )
    
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $jsonFileName = "result_$timestamp.json"
    $jsonFilePath = Join-Path -Path $OutputDirectory -ChildPath $jsonFileName
    $htmlFileName = "result_$timestamp.html"
    $htmlFilePath = Join-Path -Path $OutputDirectory -ChildPath $htmlFileName
    $csvFileName = "result_$timestamp.csv"
    $csvFilePath = Join-Path -Path $OutputDirectory -ChildPath $csvFileName
    $zipFileName = "result_$timestamp.zip"
    $zipFilePath = Join-Path -Path $OutputDirectory -ChildPath $zipFileName
    
    # Always reset generated file list for this run to avoid carrying stale paths.
    $script:generatedFiles = @()

    if (-not (Test-Path -Path $OutputDirectory -PathType Container)) {
        throw "Output directory does not exist: $OutputDirectory"
    }
    
    try {
        Write-Log "`n[Output] Generating reports in formats: $($OutputFormat -join ', ')" -Color Cyan -Level Info
        
        # 1. Generate Event Log Files
        if ($AuditReport.Logs.EventLogs) {
            Export-EventLogFiles -EventLogs $AuditReport.Logs.EventLogs -Format $EventLogFormat -OutputDir $OutputDirectory
        }

        # 2. Save Main JSON
        if ($OutputFormat -contains "JSON") {
            $AuditReport | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonFilePath -Encoding UTF8
            Write-Log "[Save] JSON saved: $jsonFileName" -Color Yellow -Level Info
            $script:generatedFiles += $jsonFilePath
        }

        # 3. Save HTML Report
        if ($OutputFormat -contains "HTML") {
            Write-Log "[Save] Generating HTML Report..." -Color Cyan -Level Info
            ConvertTo-HtmlReport -InputObject $AuditReport -OutputPath $htmlFilePath
            Write-Log "[Save] HTML saved: $htmlFileName" -Color Yellow -Level Info
            $script:generatedFiles += $htmlFilePath
        }

        # 4. Save CSV Report
        if ($OutputFormat -contains "CSV") {
            Write-Log "[Save] Generating CSV Report..." -Color Cyan -Level Info
            ConvertTo-CsvReport -InputObject $AuditReport -OutputPath $csvFilePath
            Write-Log "[Save] CSV saved: $csvFileName" -Color Yellow -Level Info
            $script:generatedFiles += $csvFilePath
        }

        # 5. Compress All Generated Files
        if ($script:generatedFiles.Count -gt 0) {
            Write-Log "[Compress] Zipping result file and logs..." -Color Cyan -Level Info
            Compress-Archive -Path $script:generatedFiles -DestinationPath $zipFilePath -Force
            Write-Log "[Complete] Zip saved: $zipFileName" -Color Green -Level Info
        }
        else {
            Write-Log "[Warning] No files generated to zip." -Color Yellow -Level Warning
        }

        # 6. Cleanup
        if (-not $DebugMode) {
            Write-Log "[Cleanup] Removing intermediate files..." -Color Yellow -Level Info
            foreach ($file in $script:generatedFiles) {
                if (Test-Path $file) {
                    Remove-Item $file -Force -ErrorAction SilentlyContinue
                    Write-Log "  - Deleted: $(Split-Path $file -Leaf)" -Color DarkGray -Level Debug
                }
            }
        }
        else {
            Write-Log "[DEBUG] Skipped cleanup." -Color Magenta -Level Debug
        }
    }
    catch {
        Write-Error "Failed to save or compress files: $_"
        Write-Log "[Error] Failed to save or compress files: $_" -Color Red -Level Error
    }
}
