# --- Infrastructure Test Classes ---

class AdminPrivilegeTest : BaseTest {
    AdminPrivilegeTest() : base("Admin Privileges Check", "Infrastructure") {}

    [string] Execute() {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "Not running as Administrator."
        }
        return "Running as Admin"
    }
}

class MutexIsolationTest : BaseTest {
    MutexIsolationTest() : base("Mutex Singleton Isolation", "Infrastructure") {}

    [string] Execute() {
        $mutex = Get-ScriptMutex
        try {
            $job = Start-Job -ScriptBlock {
                param($path)
                . (Join-Path $path "lib\Common.ps1")
                try { Get-ScriptMutex; return "Success" } catch { return "Failed: $($_.Exception.Message)" }
            } -ArgumentList (Resolve-Path "$PSScriptRoot\..\..").Path
            
            $res = Wait-Job $job | Receive-Job
            if ($res -notlike "*CRITICAL ERROR: Script is already running*") {
                throw "Mutex failed to block concurrent session. Result: $res"
            }
            return "Mutex isolation verified"
        }
        finally {
            if ($mutex) { $mutex.Dispose() }
        }
    }
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU7TmCXoVlaOZ2RGP3QsOoFGDz
# xtmgggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUmYNnmQ+Q7VKCgsmkpTmhSh5hbrgwDQYJ
# KoZIhvcNAQEBBQAEggEAvBbB1DAZyncCG3tMTiXJCxBD/EfJBVTeKzcfdfHul46D
# OrM1n+sTYGzwx6gmE6z94NTY7AK6UIz0KvPaISoPtb+d3sTUX3CCqauopTx5ebMT
# 6VPiddwMb0nFCtkyuOlL7MmtogDPYvmeWyD/EiDDWTkN+35bUriWcBtQeDaeHx6x
# PzlxsqH4Tlnbt9wWJb+OzDUW5rVkfyC2eDgYzRXos6vdRu/oKIY5axbVFcTKFSTh
# AQ7kAsTCbGnOneODBkA+xKc/83vTNCDsgrakNAtSm3qxyqENXWGCtPK5Ffmc2tji
# fgchNM1cYdoe8AHv4vH82NsCubbSuzfvC7YpnMK6Ag==
# SIG # End signature block
