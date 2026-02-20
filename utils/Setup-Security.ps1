<#
.SYNOPSIS
    Self-signed Code Signing Setup & Plugin Signer
.DESCRIPTION
    1. Creates a self-signed code signing certificate for 'Collector-Admin'.
    2. Installs it into 'Trusted Publishers' and 'Root' for local trust.
    3. Signs all .ps1 files in the 'lib/collectors' directory.
#>

$certSubject = "CN=Collector-Internal-Signer"
$certStore = "Cert:\CurrentUser\My"

Write-Host "--- 1. Checking for existing certificate ---" -ForegroundColor Cyan
$existingCert = Get-Item "$certStore\*" | Where-Object { $_.Subject -eq $certSubject } | Select-Object -First 1

if (-not $existingCert) {
    Write-Host "Creating new self-signed certificate..." -ForegroundColor Yellow
    $existingCert = New-SelfSignedCertificate -Subject $certSubject -Type CodeSigningCert -KeyUsage DigitalSignature -FriendlyName "Collector Security Signer" -CertStoreLocation $certStore
}

Write-Host "Certificate Thumbprint: $($existingCert.Thumbprint)" -ForegroundColor Green

Write-Host "--- 2. Registering Trust (Requires Admin) ---" -ForegroundColor Cyan
try {
    # Export and import to Trusted Root & Trusted Publishers
    $tempPath = Join-Path $env:TEMP "collector_temp_cert.cer"
    Export-Certificate -Cert $existingCert -FilePath $tempPath -Force | Out-Null
    
    Import-Certificate -FilePath $tempPath -CertStoreLocation "Cert:\CurrentUser\Root" | Out-Null
    Import-Certificate -FilePath $tempPath -CertStoreLocation "Cert:\CurrentUser\TrustedPublisher" | Out-Null
    
    Remove-Item $tempPath -Force
    Write-Host "Successfully registered in Trusted Root & Publishers." -ForegroundColor Green
}
catch {
    Write-Host "Failed to register trust. Please run as Administrator if this failed." -ForegroundColor Red
}

Write-Host "--- 3. Signing Plugins ---" -ForegroundColor Cyan
$pluginPath = Join-Path $PSScriptRoot "..\lib\collectors"
if (Test-Path $pluginPath) {
    $plugins = Get-ChildItem -Path $pluginPath -Filter "*.ps1"
    foreach ($file in $plugins) {
        Write-Host "Signing: $($file.Name)" -ForegroundColor DarkGray
        Set-AuthenticodeSignature -FilePath $file.FullName -Certificate $existingCert | Out-Null
    }
    Write-Host "All plugins signed successfully." -ForegroundColor Green
}
else {
    Write-Warning "Plugin path not found: $pluginPath"
}

# lib\reporters 폴더도 서명 대상에 포함
$reporterPath = Join-Path $PSScriptRoot "..\lib\reporters"
if (Test-Path $reporterPath) {
    $reporters = Get-ChildItem -Path $reporterPath -Filter "*.ps1"
    foreach ($file in $reporters) {
        Write-Host "Signing: $($file.Name)" -ForegroundColor DarkGray
        Set-AuthenticodeSignature -FilePath $file.FullName -Certificate $existingCert | Out-Null
    }
    Write-Host "All reporters signed successfully." -ForegroundColor Green
}
else {
    Write-Warning "Reporter path not found: $reporterPath"
}

Write-Host "`nSecurity Setup Complete. Plugin Loading Protection can now be enabled." -ForegroundColor Cyan

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUlO3QqOCyWxMEIezIpcyDLC1x
# mGCgggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUwSgz+HXU/yXEp9lP98GD/IlLlrcwDQYJ
# KoZIhvcNAQEBBQAEggEAI6wmi2oNdz3cau2F0nF6rymQ/T65RiqAvYeknPKnlxGM
# bMD0MpG1y99QWFfNSoZ3n7VMMyuzkqzAxsZOD88z5qOArWdLUjt6IHg00H5Bd/Bj
# uXZkN2a1RpyvmgWge3OE8lMG2QxmDRJRwAxkRx9guXrMM70NBln7p3oeu1mS05vh
# ClywHpndrJnhNhxoSe63x/RJXe6YhJBXLwgeb9pI24QuZ+Z/XN3OYeyfqigOX5fi
# ZPWBmNiv3L8P9sBpbSlw+yPWOrR3SUl29S5oQ+hz2MWb9G+qW838igFXSUxnx3Vu
# Mgv8GGbG7G1pnpijiJs5xpmReot4h2zTTVGqCaGIEg==
# SIG # End signature block
