<#
.SYNOPSIS
    CSV Reporting Module
.DESCRIPTION
    Contains functions for generating CSV reports.
#>

<#
    .SYNOPSIS
        Converts the audit report object to CSV files.
    .DESCRIPTION
        Creates multiple CSV files, one for each category in the report.
        Complex nested objects are flattened or converted to JSON strings.
#>
function ConvertTo-CsvReport {
    param(
        [Parameter(Mandatory = $true)]
        $InputObject,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    # Create base filename without extension
    $baseFileName = [System.IO.Path]::GetFileNameWithoutExtension($OutputPath)
    $outputDir = [System.IO.Path]::GetDirectoryName($OutputPath)
    
    # Summary CSV with all categories
    $summaryData = @()
    
    $categories = $InputObject | Get-Member -MemberType NoteProperty
    
    foreach ($cat in $categories) {
        if ($cat.Name -in @("Timestamp", "ExecutionTime")) { 
            continue 
        }

        $catName = $cat.Name
        $catData = $InputObject.($cat.Name)
        
        # Create category-specific CSV file
        $catFileName = "${baseFileName}_${catName}.csv"
        $catFilePath = Join-Path -Path $outputDir -ChildPath $catFileName
        
        try {
            if ($catData -is [PSCustomObject]) {
                # Flatten the object for CSV
                $flattenedData = @()
                
                $subCats = $catData | Get-Member -MemberType NoteProperty
                foreach ($sub in $subCats) {
                    $subName = $sub.Name
                    $subData = $catData.($subName)
                    
                    if ($subData -is [Array]) {
                        # Export array items
                        foreach ($item in $subData) {
                            if ($item -is [PSCustomObject]) {
                                $flatItem = $item | Select-Object *
                                $flatItem | Add-Member -NotePropertyName "Category" -NotePropertyValue $catName -Force
                                $flatItem | Add-Member -NotePropertyName "SubCategory" -NotePropertyValue $subName -Force
                                $flattenedData += $flatItem
                            }
                            else {
                                $flattenedData += [PSCustomObject]@{
                                    Category    = $catName
                                    SubCategory = $subName
                                    Value       = "$item"
                                }
                            }
                        }
                    }
                    elseif ($subData -is [PSCustomObject]) {
                        # Convert complex object to JSON string
                        $flattenedData += [PSCustomObject]@{
                            Category    = $catName
                            SubCategory = $subName
                            Value       = ($subData | ConvertTo-Json -Depth 2 -Compress)
                        }
                    }
                    else {
                        $flattenedData += [PSCustomObject]@{
                            Category    = $catName
                            SubCategory = $subName
                            Value       = "$subData"
                        }
                    }
                }
                
                if ($flattenedData.Count -gt 0) {
                    $flattenedData | Export-Csv -Path $catFilePath -NoTypeInformation -Encoding UTF8
                    $script:generatedFiles += $catFilePath
                    
                    $summaryData += [PSCustomObject]@{
                        Category  = $catName
                        ItemCount = $flattenedData.Count
                        FileName  = $catFileName
                    }
                }
            }
            elseif ($catData -is [Array]) {
                $catData | Export-Csv -Path $catFilePath -NoTypeInformation -Encoding UTF8
                $script:generatedFiles += $catFilePath
                
                $summaryData += [PSCustomObject]@{
                    Category  = $catName
                    ItemCount = $catData.Count
                    FileName  = $catFileName
                }
            }
            else {
                # Single value
                [PSCustomObject]@{
                    Category = $catName
                    Value    = "$catData"
                } | Export-Csv -Path $catFilePath -NoTypeInformation -Encoding UTF8
                $script:generatedFiles += $catFilePath
                
                $summaryData += [PSCustomObject]@{
                    Category  = $catName
                    ItemCount = 1
                    FileName  = $catFileName
                }
            }
        }
        catch {
            Write-Warning "Failed to export category '$catName' to CSV: $_"
        }
    }
    
    # Create summary CSV
    if ($summaryData.Count -gt 0) {
        $summaryData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Log "  - Created summary CSV: $(Split-Path $OutputPath -Leaf)" -Color Gray
        Write-Log "  - Created $($summaryData.Count) category-specific CSV files" -Color Gray
    }
}
