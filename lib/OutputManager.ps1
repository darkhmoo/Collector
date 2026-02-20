<#
.SYNOPSIS
    Output Management Module
.DESCRIPTION
    Handles saving, compressing, and cleaning up report files.
#>

<#
.SYNOPSIS
    Saves and compresses audit results into various formats.
.PARAMETER auditReport
    The central data object containing all collected info.
.PARAMETER outputFormat
    Desired output types (JSON, HTML, CSV).
.PARAMETER eventLogFormat
    Format for event logs (HTML, CSV).
.PARAMETER outputDirectory
    Destination folder.
.PARAMETER isDebugMode
    Whether to keep intermediate files and log extra info.
.PARAMETER zipResults
    Whether to compress all generated files into a ZIP archive.
.PARAMETER encryptionKey
    SecureString containing the key for AES-256 encryption.
#>
function Save-Results {
    [CmdletBinding(SupportsShouldProcess = $true, PositionalBinding = $false)]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$auditReport,
        
        [Parameter(Mandatory = $true)]
        [string[]]$outputFormat,
        
        [Parameter(Mandatory = $true)]
        [string]$eventLogFormat,
        
        [Parameter(Mandatory = $true)]
        [string]$outputDirectory,
        
        [Parameter(Mandatory = $true)]
        [bool]$isDebugMode,
        
        [Parameter(Mandatory = $true)]
        [bool]$zipResults,
        
        [Parameter(Mandatory = $false)]
        [SecureString]$encryptionKey
    )
    
    $timeStamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $jsonFileName = "result_$timeStamp.json"
    $jsonFilePath = Join-Path -Path $outputDirectory -ChildPath $jsonFileName
    $htmlFileName = "result_$timeStamp.html"
    $htmlFilePath = Join-Path -Path $outputDirectory -ChildPath $htmlFileName
    $csvFileName = "result_$timeStamp.csv"
    $csvFilePath = Join-Path -Path $outputDirectory -ChildPath $csvFileName
    $zipFileName = "result_$timeStamp.zip"
    $zipFilePath = Join-Path -Path $outputDirectory -ChildPath $zipFileName
    
    # Reset tracking list
    $script:generatedFiles = @()

    if (-not (Test-Path -path $outputDirectory -pathType Container)) {
        throw "Output directory does not exist: $outputDirectory"
    }

    # Audit Rule: Final Resource Check before I/O intensive tasks
    $drive = Get-PSDrive -Name $outputDirectory.Substring(0, 1)
    if ($drive.Free -lt 150MB) {
        throw "CRITICAL ERROR: Insufficient space in $outputDirectory. 150MB required for safe reporting."
    }
    
    try {
        Write-Log -message "`n[Output] Preparing reports in: $($outputFormat -join ', ')" -color Cyan -level Info
        
        # 1. Event Logs
        if ($auditReport.Logs.EventLogs) {
            $eventLogLookbackDays = 7
            if ($auditReport.Logs.PSObject.Properties.Name -contains "EventLogLookbackDays") {
                $eventLogLookbackDays = [int]$auditReport.Logs.EventLogLookbackDays
            }

            if ($PSCmdlet.ShouldProcess("All Event Logs to $outputDirectory", "Export as $eventLogFormat")) {
                Export-EventLogFiles -EventLogs $auditReport.Logs.EventLogs -outputFormat $eventLogFormat -OutputDir $outputDirectory -lookbackDays $eventLogLookbackDays -fileTimestamp $timeStamp
            }
        }

        # 2. Main JSON
        if ($outputFormat -contains "JSON") {
            Write-Log -message "  - Saving JSON report..." -color Gray
            try {
                $auditReport | ConvertTo-Json -Depth 10 -Compress -ErrorAction Stop | Set-Content -Path $jsonFilePath -Encoding UTF8
                Write-Log -message "[Save] JSON saved: $jsonFileName" -color Yellow -level Info
                $script:generatedFiles += $jsonFilePath
            }
            catch {
                Write-Log -message "    ! JSON serialization failed, attempting lower depth: $_" -color Yellow -level Warning
                # Attempt with lower depth if the first fails (e.g., due to circular references at higher depth)
                $auditReport | ConvertTo-Json -Depth 5 -Compress | Set-Content -Path $jsonFilePath -Encoding UTF8
                Write-Log -message "[Save] JSON saved (with reduced depth): $jsonFileName" -color Yellow -level Info
                $script:generatedFiles += $jsonFilePath
            }
        }

        # 3. HTML Report
        if ($outputFormat -contains "HTML") {
            if ($PSCmdlet.ShouldProcess($htmlFilePath, "Generate HTML Report")) {
                Write-Log -message "[Save] Generating HTML Report..." -color Cyan -level Info
                ConvertTo-HtmlReport -InputObject $auditReport -OutputPath $htmlFilePath
                Write-Log -message "[Save] HTML saved: $htmlFileName" -color Yellow -level Info
                $script:generatedFiles += $htmlFilePath
            }
        }

        # 4. CSV Report
        if ($outputFormat -contains "CSV") {
            if ($PSCmdlet.ShouldProcess($csvFilePath, "Generate CSV Report")) {
                Write-Log -message "[Save] Generating CSV Report..." -color Cyan -level Info
                ConvertTo-CsvReport -InputObject $auditReport -OutputPath $csvFilePath
                Write-Log -message "[Save] CSV saved: $csvFileName" -color Yellow -level Info
                $script:generatedFiles += $csvFilePath
            }
        }

        # 4.5 Encryption (Individual Core Reports)
        if ($encryptionKey -and $script:generatedFiles.Count -gt 0) {
            $encryptedFiles = @()
            foreach ($file in $script:generatedFiles) {
                if (Test-Path $file) {
                    $encFileName = (Split-Path $file -Leaf) + ".aes"
                    $encFilePath = $file + ".aes"
                    
                    if ($PSCmdlet.ShouldProcess($file, "Encrypt with AES-256")) {
                        Protect-File -Path $file -DestinationPath $encFilePath -Key $encryptionKey
                        Write-Log -message "[Encrypt] Secured: $encFileName" -color Magenta -level Info
                        
                        # Remove original plain text immediately
                        Remove-Item $file -Force -ErrorAction SilentlyContinue
                        $encryptedFiles += $encFilePath
                    }
                    else {
                        # If WhatIf, just track the hypothetical file
                        $encryptedFiles += $encFilePath
                    }
                }
            }
            # Update tracking list to encrypted versions
            $script:generatedFiles = $encryptedFiles
        }

        # 5. Zip Compression
        if ($zipResults -and $script:generatedFiles.Count -gt 0) {
            if ($PSCmdlet.ShouldProcess($zipFilePath, "Compress all generated files")) {
                Write-Log -message "[Compress] Zipping results (Level: Optimal)..." -color Cyan -level Info
                Compress-Archive -Path $script:generatedFiles -DestinationPath $zipFilePath -CompressionLevel Optimal -Force
                Write-Log -message "[Complete] Zip saved: $zipFileName" -color Green -level Info
            }
        }

        # 6. Cleanup - ZIP ?ïÏ∂ï ?úÏóêÎß?Ï§ëÍ∞Ñ ?åÏùº ??†ú
        if ($zipResults -and (Test-Path $zipFilePath)) {
            foreach ($file in $script:generatedFiles) {
                if (Test-Path $file) {
                    if ($PSCmdlet.ShouldProcess($file, "Cleanup intermediate file after ZIP")) {
                        Remove-Item $file -Force -ErrorAction SilentlyContinue
                        Write-Log -message "  - Deleted intermediate: $(Split-Path $file -Leaf)" -color DarkGray -level Debug
                    }
                }
            }
        }
    }
    catch {
        $errorMessage = "Output generation failed: $($_.Exception.Message)"
        Write-Error $errorMessage
        throw $errorMessage
    }
    finally {
        # Exhaustive Cleanup: ZIP ?ùÏÑ± ???îÏó¨ Ï§ëÍ∞Ñ ?åÏùº ?ïÎ¶¨
        if ($zipResults -and (Test-Path $zipFilePath)) {
            $uniqueFiles = $script:generatedFiles | Select-Object -Unique
            foreach ($file in $uniqueFiles) {
                if (Test-Path $file) {
                    Remove-Item $file -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

<#
.SYNOPSIS
    Encrypts a file using AES-256 algorithm.
#>
function Protect-File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,
        
        [Parameter(Mandatory = $true)]
        [SecureString]$Key
    )

    $aes = [System.Security.Cryptography.Aes]::Create()
    
    $ptr = $null
    $fsIn = $null
    $fsOut = $null
    $cryptoStream = $null

    try {
        # 1. Key Derivation (PBKDF2 with random 16-byte Salt)
        # Standard: 100,000 iterations for robust security (Audit Finding Fix)
        $salt = New-Object byte[] 16
        [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($salt)

        $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Key)
        try {
            $keyStr = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
            
            # Use PBKDF2 with salt for key derivation
            $pbkdf2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($keyStr, $salt, 100000)
            $keyBytes = $pbkdf2.GetBytes(32) # AES-256
            
            $aes.KeySize = 256
            $aes.Key = $keyBytes
            $aes.GenerateIV()
            $iv = $aes.IV
        }
        finally {
            # Audit Fix: SECURELY wipe the plaintext key from memory (BSTR)
            if ($ptr -ne [System.IntPtr]::Zero) {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
            }
        }
        
        # 2. Setup Streams
        $fsIn = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
        $fsOut = New-Object System.IO.FileStream($DestinationPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
        
        try {
            # 3. Write Metadata (Salt + IV) to the beginning
            # Layout: [Salt(16)] [IV(16)] [EncryptedData...]
            $fsOut.Write($salt, 0, $salt.Length)
            $fsOut.Write($iv, 0, $iv.Length)
            
            # 4. Perform Stream Encryption
            $encryptor = $aes.CreateEncryptor()
            $cryptoStream = New-Object System.Security.Cryptography.CryptoStream($fsOut, $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
            try {
                $buffer = New-Object byte[] 65536
                while (($read = $fsIn.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $cryptoStream.Write($buffer, 0, $read)
                }
                $cryptoStream.FlushFinalBlock()
            }
            finally {
                if ($null -ne $cryptoStream) { $cryptoStream.Dispose() }
            }
        }
        finally {
            # Audit Fix: Ensure file handles are released even on crash
            if ($null -ne $fsIn) { $fsIn.Dispose() }
            if ($null -ne $fsOut) { $fsOut.Dispose() }
            if ($null -ne $aes) { $aes.Dispose() }
        }
    }
    catch {
        throw # Re-throw the exception after ensuring resources are cleaned up
    }
    finally {
        # The outer finally block is now redundant for $ptr, $fsIn, $fsOut, $cryptoStream, $aes
        # as they are handled by nested finally blocks.
        # This block can be removed or kept for any other cleanup not covered by nested blocks.
        # For now, keeping it empty or removing the redundant checks.
    }
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUP2NkjC95Me1HAYCCSkJXHyKB
# egegggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUippd7qCX0n9q3fw5JfAFDA481nAwDQYJ
# KoZIhvcNAQEBBQAEggEA0dcouFVf0UC7F9wz/tyiFtQOIcikHzhOHHzfpujTrCDh
# fIkBRDe1Hu9+dUJ0oS+kCPvDPDfO/qT+cgnp7NZUp+wKb3aNbPCVhT0c6NV4iLAF
# RoxG8u0IqttGCUTA0XGs8twVwlz7keDiIL0yC+Lh2G8R4PRkAdxewjz0/BDV24Iu
# ebj59pJbaDGQAgvtywsSYYAJ/A4o+nuSzL969nsuNqtxVPlvEEdjX/ECNcv1ARJ6
# IiGgFAcSRiVhZWMjdbNfGpxPviMCzodHVbVQ0/8friNqYr9lEG/k0vTwsMC0O5Nz
# d4HlsT3viidPakds9FAMM2J1WKFrV1Fd9jNzmoILug==
# SIG # End signature block
