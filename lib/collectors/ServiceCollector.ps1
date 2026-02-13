<#
.SYNOPSIS
    Service and Process Information Collector (Class-based)
#>

<#
.SYNOPSIS
    Collects modern Scheduled Tasks and legacy Scheduled Jobs.
#>
function Get-ScheduledTaskDetails {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        ModernTasks = $(
            if (Get-Command -Name Get-ScheduledTask -ErrorAction SilentlyContinue) {
                try { Get-ScheduledTask -ErrorAction Stop | Select-Object TaskName, TaskPath, State, @{N = "Author"; E = { $_.Principal.UserId } }, @{N = "Executable"; E = { $_.Actions.Execute } } } catch { "Task query failed: $_" }
            }
            else { "Get-ScheduledTask not available" }
        )
        LegacyJobs  = Get-CimSafe -className Win32_ScheduledJob
    }
}

<#
.SYNOPSIS
    Collects driver information including signing status.
#>
function Get-DriverDetails {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        SystemDrivers = Get-CimSafe -className Win32_PnPSignedDriver | Select-Object DeviceName, Manufacturer, DriverVersion, Signer, IsSigned
        LoadedDrivers = Get-CimSafe -className Win32_SystemDriver | Select-Object Name, DisplayName, State, StartMode, PathName
    }
}

class ServiceCollector : BaseCollector {
    ServiceCollector() : base("Services", "Execution") {}

    [PSObject] Collect() {
        $this.LogStart()
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        $data = [PSCustomObject]@{
            Services       = Get-CimSafe -className Win32_Service
            Processes      = Get-CimSafe -className Win32_Process | Select-Object Name, ProcessId, ExecutablePath, CommandLine, @{N = "WorkingSet"; E = { $_.WorkingSetSize / 1MB } }
            DTC            = Get-CimSafe -className Win32_DtcClusterDefaultResource
            ScheduledTasks = Get-ScheduledTaskDetails
            Drivers        = Get-DriverDetails
        }

        $sw.Stop()
        $this.LogEnd($sw.ElapsedMilliseconds)
        return $data
    }
}

function Get-ServiceInfo {
    return ([ServiceCollector]::new()).Collect()
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUTLW23Uim1ErwHuAvlzya7j2i
# IpKgggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUbQS4s0NUsA7zjJFk6Qml9pJdjMEwDQYJ
# KoZIhvcNAQEBBQAEggEAXDkCr/EJLnZSzTC/ftKTCnwWGlc6j0PwQy5UbJ7BWX7D
# MAeu5vk032nCQM3q7lY/6BALHwbSEJxfvoS7I0XO59fETi85xA87+hLTo+Gd9H29
# fVf89+aZL1PVadU2f0WdRuLrzCInHpPrrxD+qnAwnWShzDNfMJlQ9AZG3/WmrcoM
# 2qkg4KcMM6JhMA2dY8bdVPYQTMwnCqzoW2MsnMg3SxPDavc2X0TkybmzXHqUIBIT
# e432XcjcM9t2f/UGHdN+fSasM5Ikd2u4rgBa8OSLve175x41uzpn6BKqnNv3AEqE
# lCdueYueASVqJohqrQ5hJUCgvPkUJiOs7GC+c3SiVw==
# SIG # End signature block
