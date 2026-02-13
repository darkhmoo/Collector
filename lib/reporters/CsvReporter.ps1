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
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        $inputObject,
        
        [Parameter(Mandatory = $true)]
        [string]$outputPath
    )

    # Create base filename without extension
    $baseFileName = [System.IO.Path]::GetFileNameWithoutExtension($outputPath)
    $outputDir = [System.IO.Path]::GetDirectoryName($outputPath)
    
    # Summary CSV with all categories
    $summaryData = @()
    
    $categories = $inputObject | Get-Member -MemberType NoteProperty
    
    foreach ($cat in $categories) {
        if ($cat.Name -in @("Timestamp", "ExecutionTime")) { 
            continue 
        }

        $categoryName = $cat.Name
        $categoryData = $inputObject.($categoryName)
        
        # Create category-specific CSV file
        $fileName = "${baseFileName}_${categoryName}.csv"
        $filePath = Join-Path -Path $outputDir -ChildPath $fileName
        
        try {
            if ($categoryData -is [PSCustomObject]) {
                # Flatten the object for CSV using List for performance (Audit Fix)
                $flattenedList = [System.Collections.Generic.List[PSObject]]::new()
                
                $subCategories = $categoryData | Get-Member -MemberType NoteProperty
                foreach ($sub in $subCategories) {
                    $subName = $sub.Name
                    $subData = $categoryData.($subName)
                    
                    if ($subData -is [Array]) {
                        foreach ($item in $subData) {
                            if ($item -is [PSCustomObject]) {
                                $flatItem = $item | Select-Object *
                                $flatItem | Add-Member -NotePropertyName "Category" -NotePropertyValue $categoryName -Force
                                $flatItem | Add-Member -NotePropertyName "SubCategory" -NotePropertyValue $subName -Force
                                $flattenedList.Add($flatItem)
                            }
                            else {
                                $flattenedList.Add([PSCustomObject]@{
                                        Category    = $categoryName
                                        SubCategory = $subName
                                        Value       = "$item"
                                    })
                            }
                        }
                    }
                    elseif ($subData -is [PSCustomObject]) {
                        $flattenedList.Add([PSCustomObject]@{
                                Category    = $categoryName
                                SubCategory = $subName
                                Value       = ($subData | ConvertTo-Json -Depth 2 -Compress)
                            })
                    }
                    else {
                        $flattenedList.Add([PSCustomObject]@{
                                Category    = $categoryName
                                SubCategory = $subName
                                Value       = "$subData"
                            })
                    }
                }
                
                if ($flattenedList.Count -gt 0) {
                    if ($PSCmdlet.ShouldProcess($filePath, "Save category CSV")) {
                        $flattenedList.ToArray() | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
                        $script:generatedFiles += $filePath
                    }
                    
                    $summaryData += [PSCustomObject]@{
                        Category  = $categoryName
                        ItemCount = $flattenedList.Count
                        FileName  = $fileName
                    }
                }
            }
            elseif ($categoryData -is [Array]) {
                if ($PSCmdlet.ShouldProcess($filePath, "Save list CSV")) {
                    $categoryData | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
                    $script:generatedFiles += $filePath
                }
                
                $summaryData += [PSCustomObject]@{
                    Category  = $categoryName
                    ItemCount = $categoryData.Count
                    FileName  = $fileName
                }
            }
            else {
                # Single value
                if ($PSCmdlet.ShouldProcess($filePath, "Save value CSV")) {
                    [PSCustomObject]@{
                        Category = $categoryName
                        Value    = "$categoryData"
                    } | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
                    $script:generatedFiles += $filePath
                }
                
                $summaryData += [PSCustomObject]@{
                    Category  = $categoryName
                    ItemCount = 1
                    FileName  = $fileName
                }
            }
        }
        catch {
            Write-Warning "Failed to export category '$categoryName' to CSV: $_"
        }
    }
    
    # Create summary CSV
    if ($summaryData.Count -gt 0) {
        if ($PSCmdlet.ShouldProcess($outputPath, "Save summary CSV")) {
            $summaryData | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8
            Write-Log -message "  - Created summary CSV: $(Split-Path $outputPath -Leaf)" -color Gray
            Write-Log -message "  - Created $($summaryData.Count) category-specific CSV files" -color Gray
        }
    }
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU26JIiKR850f87QzmJS4DyBl7
# IsugggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUdlPwRYpBi+vIlb91KjwAWn1aX+YwDQYJ
# KoZIhvcNAQEBBQAEggEAmbvi71be52IoQON3gVOdkEyqDZ9+2Xix0NNIV1bmaebK
# 2X9A6V0fSH5qIsQ7ai+z0zGAdUbaAvqv4PLyckjtN5+71rB8DX6Uv/YeaIgpr+qn
# 9gK6IZRjn8se8w7MM2L+5HtiOH7TRtfAvq5LnGB3a8EgcVkUVwvmk1hGSw/Omjgj
# NgEPDMLZTHo+tyvdQNSnko9EMH0/EwFzJJOq5ZAVct7fS2MEko8Y11wlIwO0K5Ge
# UesHF9iS97vA32v2tlwW/99lPFgoYe7wujv3Ahx3hk6sx+hPbtJCgp/sxbwn0Ow8
# 9esr0YTEE4VU4FaebcHAguuCaDmo+qKAPlyedDJqmQ==
# SIG # End signature block
