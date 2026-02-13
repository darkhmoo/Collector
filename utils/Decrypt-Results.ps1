<#
.SYNOPSIS
    AES-256 Decryption Utility for Collector Reports
.DESCRIPTION
    Decrypts files encrypted by the System Information Collector.
    Restores .aes files back to their original (.json, .html, .csv) formats.
.EXAMPLE
    .\Decrypt-Results.ps1 -Path ".\result_20260214.zip"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string]$Path,
    
    [Parameter(Mandatory = $false)]
    [SecureString]$Key
)

process {
    $targetPath = Resolve-Path $Path
    
    # If it's a ZIP, suggest unzipping first
    if ($targetPath.Extension -eq ".zip") {
        Write-Host "[Info] target is a ZIP file. Please unzip it first and decrypt individual .aes files." -ForegroundColor Yellow
        return
    }

    if ($targetPath.Extension -ne ".aes") {
        Write-Error "File is not an .aes encrypted report: $($targetPath.FileName)"
        return
    }

    $finalKey = $Key
    if (-not $finalKey) {
        $finalKey = Read-Host "Enter decryption key" -AsSecureString
    }

    $destPath = $targetPath.FullName.Substring(0, $targetPath.FullName.Length - 4)
    Write-Host "[Decrypting] $($targetPath.FileName) -> $(Split-Path $destPath -Leaf)" -ForegroundColor Cyan
    
    try {
        $fsIn = New-Object System.IO.FileStream($targetPath.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
        
        # 1. Read Metadata (Salt + IV)
        $salt = New-Object byte[] 16
        $iv = New-Object byte[] 16
        if ($fsIn.Read($salt, 0, 16) -ne 16) { throw "Invalid salt header" }
        if ($fsIn.Read($iv, 0, 16) -ne 16) { throw "Invalid IV header" }
        
        # 2. Derive Key using the same Salt and Iterations
        $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($finalKey)
        try {
            $keyStr = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
            
            $pbkdf2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($keyStr, $salt, 100000)
            $keyBytes = $pbkdf2.GetBytes(32)
        }
        finally {
            # Audit Fix: SECURELY wipe the plaintext key from memory
            if ($ptr -ne [System.IntPtr]::Zero) {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
            }
        }
        
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = $keyBytes
        $aes.IV = $iv
        
        # 3. Perform Stream Decryption with strict resource management
        $decryptor = $aes.CreateDecryptor()
        $fsOut = New-Object System.IO.FileStream($destPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
        try {
            $cryptoStream = New-Object System.Security.Cryptography.CryptoStream($fsIn, $decryptor, [System.Security.Cryptography.CryptoStreamMode]::Read)
            try {
                $buffer = New-Object byte[] 65536
                while (($read = $cryptoStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $fsOut.Write($buffer, 0, $read)
                }
            }
            finally {
                if ($null -ne $cryptoStream) { $cryptoStream.Dispose() }
            }
        }
        finally {
            # Audit Fix: Critical handle and memory release
            if ($null -ne $fsOut) { $fsOut.Dispose() }
            if ($null -ne $decryptor) { $decryptor.Dispose() }
        }
        
        Write-Host "[Success] Restored: $(Split-Path $destPath -Leaf)" -ForegroundColor Green
    }
    catch {
        Write-Error "Decryption failed. Incorrect key or corrupted file. Details: $($_.Exception.Message)"
    }
    finally {
        # Final secure wipe
        if ($null -ne $ptr) { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
        if ($null -ne $fsIn) { $fsIn.Dispose() }
        if ($null -ne $aes) { $aes.Dispose() }
    }
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUPyL2NRxOojRssM+M0PVvZ9fU
# aiSgggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUOANB2MpgfPWLBXogtQ2vvBGdnJ0wDQYJ
# KoZIhvcNAQEBBQAEggEAXEPBVHY75mbRuvhk8h32rfyNl7sFDC1a33p3jAExZk1p
# k/RlT7QBZ6jrian7A/uBwmnpUL4PE69CO5AbbY2XTKSvRyXh2JoMkWJRYpJck/vy
# BwmSYKvtwpdnie8gALdCcoMZZuWHk6izeFEwlYj3kngLOnHJRm0c3vPgZKWQ3up3
# g1QT6mqDiuhY5a9Ki7cMW2wWjF1668edhmPjGJnuk0sgyl9aV+QLICGAq+BNn9OU
# Y4i+EcMmt0+4CZMsCaDBv14QecqNEKlF6+9g3eu0k6f7BEhsAdV50+fvvy0HDQ5O
# KN3sURbvl2yS/KK7bAbSjLDhGWMWcio2T0g02MzKIA==
# SIG # End signature block
