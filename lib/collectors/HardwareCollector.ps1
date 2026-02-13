<#
.SYNOPSIS
    Hardware Information Collector
.DESCRIPTION
    Collects hardware-related information including BIOS, CPU, Memory, Disk, and PnP devices.
#>

<#
.SYNOPSIS
    Collects a wide range of hardware diagnostic information.
#>
class HardwareCollector : BaseCollector {
    HardwareCollector() : base("Hardware", "Resources") {}

    [PSObject] Collect() {
        $this.LogStart()
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        
        $data = [PSCustomObject]@{
            BIOS             = Get-CimSafe -className Win32_BIOS
            Keyboard         = Get-CimSafe -className Win32_Keyboard
            Processor        = Get-CimSafe -className Win32_Processor
            PhysicalMemory   = Get-CimSafe -className Win32_PhysicalMemory
            PhysicalMemArray = Get-CimSafe -className Win32_PhysicalMemoryArray
            DiskDrive        = Get-CimSafe -className Win32_DiskDrive
            DiskPartition    = Get-CimSafe -className Win32_DiskPartition
            LogicalDisk      = Get-CimSafe -className Win32_LogicalDisk
            Volume           = Get-CimSafe -className Win32_Volume
            SystemInfo       = Get-CimSafe -className Win32_ComputerSystem
            PnPEntities      = Get-CimSafe -className Win32_PnPEntity | Select-Object Name, DeviceID, Status, Manufacturer, Service
        }

        $sw.Stop()
        $this.LogEnd($sw.ElapsedMilliseconds)
        return $data
    }
}

function Get-HardwareInfo {
    return ([HardwareCollector]::new()).Collect()
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUYNq1be0NP7+FEaNqb1xHu4ZD
# QFegggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU0/8ND2mFlXRV5xL22CtEIPTEEz4wDQYJ
# KoZIhvcNAQEBBQAEggEAms/3IFPq52MTCaU1QMMcXv+EGssnn/h0BXis+PWsMPC9
# f9lmmrj9RrhIn4FdCDEkc1tZEoxl2SxxmE7wRaOhviWKEJxD1VLH6JbFeEdp0Hc3
# TpPir6CXG+6Tqx7tCP4iYXC1O08dgTPmHloJRaovqytgEENBqhd7jTK3NtK4Tz3v
# qfVHJfuxo0vwKvwOE63au/QsDewmYlkWXA2BJt3Ah7j1M4O6004otG8RiAxWPrS7
# K9OqbTcdHCg0HA1By+tXMLb00cxNH5EE0OmVsiVjxEFnliB4XwN5R2g9YH9uF5zx
# Zg9lsoSeFEb+KBBVebfdlsYZsKPyfDrNArdoW45isw==
# SIG # End signature block
