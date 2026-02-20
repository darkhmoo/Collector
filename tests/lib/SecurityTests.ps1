# --- Security Test Classes ---

class AuthenticodeTest : BaseTest {
    AuthenticodeTest() : base("Authenticode Signature Verification", "Security") {}

    [string] Execute() {
        $collectors = Get-ChildItem -Path "$PSScriptRoot\..\..\lib\collectors\*.ps1"
        foreach ($file in $collectors) {
            $sig = Get-AuthenticodeSignature -FilePath $file.FullName
            if ($sig.Status -ne "Valid") {
                throw "Signature invalid for $($file.Name): $($sig.Status)"
            }
        }
        return "$($collectors.Count) modules verified"
    }
}

class DLPMaskingTest : BaseTest {
    DLPMaskingTest() : base("DLP Sensitive Data Masking", "Security") {}

    [string] Execute() {
        $testMap = @{
            "my password is 123"  = $true
            "API_SECRET_KEY: abc" = $true
            "Normal system log"   = $false
        }
        foreach ($key in $testMap.Keys) {
            $masked = Get-MaskedValue -inputString $key
            if ($testMap[$key] -and $masked -notlike "*Masked*") { throw "Failed to mask: $key" }
            if (-not $testMap[$key] -and $masked -ne $key) { throw "Incorrectly masked: $key" }
        }
        return "DLP logic verified"
    }
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUxjcp/QYsvMLfEW4luoN97lbe
# APGgggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUlCsUqjOKq+EYrJnHmqlWywK9WpUwDQYJ
# KoZIhvcNAQEBBQAEggEAkTzOI8M/dIZiMo+OO0BzrYsblZm/alezWMHNS3LRndab
# 0O2glQKfgB1aOw8EBpcb79uvXFehASkpL/0RSpBJUN9PQ0mXwdSgpdcjjSDFqCUs
# XNTUiN5nFS2KI9fuSJ4S0LwPGtqQHIygbAOEobD3NkO0733/O5tJGDXmW09qQggI
# U+Xu+kdUsMY8VNrWGiuM2XjQF8cBrY9ys8JOtFy67sOSM1wHL4p18LASdDm/YBXe
# duT1BwDVi15Qd2hMF51mkKXansVyY/HkCKbS0zx7AdHFpZ+rrVq/9Y5f2AGb792U
# YuVhKG1kn/XfmB7NNsBfX2RoEJflZxxcADEDThVCPQ==
# SIG # End signature block
