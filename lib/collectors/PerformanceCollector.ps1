<#
.SYNOPSIS
    Performance Information Collector (Class-based)
#>

<#
.SYNOPSIS
    Diagnoses kernel memory and handle leaks.
#>
function Get-KernelLeakDiagnostics {
    [CmdletBinding()]
    param()

    $diagnostics = [PSCustomObject]@{
        PoolMemory         = $null
        TopHandleConsumers = @()
        SystemHandles      = $null
        Error              = $null
    }

    try {
        # 1. Kernel Pool Memory (Paged/Non-paged)
        $perfMem = Get-CimSafe -className Win32_PerfFormattedData_PerfOS_Memory
        if ($perfMem) {
            $diagnostics.PoolMemory = [PSCustomObject]@{
                NonPagedPoolBytes = $perfMem.PoolNonpagedBytes
                PagedPoolBytes    = $perfMem.PoolPagedBytes
                TotalPoolBytes    = $perfMem.PoolNonpagedBytes + $perfMem.PoolPagedBytes
            }
        }

        # 2. System-wide Handle Count
        $perfProc = Get-CimSafe -className Win32_PerfFormattedData_PerfProc_Process -whereBlock { $_.Name -eq "_Total" }
        if ($perfProc) {
            $diagnostics.SystemHandles = $perfProc.HandleCount
        }

        # 3. Top 15 Handle Consumers
        $diagnostics.TopHandleConsumers = @(
            Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | 
            Sort-Object HandleCount -Descending | 
            Select-Object -First 15 Name, HandleCount, ProcessId, @{N = "CommandLine"; E = { $_.CommandLine } }
        )
    }
    catch {
        $diagnostics.Error = $_.Exception.Message
    }

    return $diagnostics
}

class PerformanceCollector : BaseCollector {
    PerformanceCollector() : base("Performance", "Metrics") {}

    [PSObject] Collect() {
        $this.LogStart()
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        $data = [PSCustomObject]@{
            RawCpu              = Get-CimSafe -className Win32_PerfRawData_PerfOS_Processor
            RawMemory           = Get-CimSafe -className Win32_PerfRawData_PerfOS_Memory
            FormattedDisk       = Get-CimSafe -className Win32_PerfFormattedData_PerfDisk_LogicalDisk
            FormattedTcpip      = Get-CimSafe -className Win32_PerfFormattedData_Tcpip_NetworkInterface
            FormattedMemory     = Get-CimSafe -className Win32_PerfFormattedData_PerfOS_Memory
            FormattedPagingFile = Get-CimSafe -className Win32_PerfFormattedData_PerfOS_PagingFile
            TopProcesses        = $(
                try { 
                    Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction Stop | 
                    Sort-Object -Property PercentProcessorTime -Descending | 
                    Select-Object -First 20 * -ExcludeProperty "Cim*" 
                }
                catch { "Error: $_" }
            )
            LeakDiagnostics     = Get-KernelLeakDiagnostics
        }

        $sw.Stop()
        $this.LogEnd($sw.ElapsedMilliseconds)
        return $data
    }
}

function Get-PerformanceInfo {
    return ([PerformanceCollector]::new()).Collect()
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUGOOvOb0qsD3t01VNoetcleFn
# OlCgggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUxoEkf1t00+Dg2jvjcnljdCHSsxQwDQYJ
# KoZIhvcNAQEBBQAEggEAN0NkI9AlXYaUj/1Kc/KoAU3rfLO6O00ccxe9Yf7MmDag
# SOgeNwRtyNTly+CXGt2LzyMH+ZlAQIJ7HpDCq4pYAnRy2lrcoe+3UOz5DGaK0gTn
# Bt+fwk2+R0EB24NSC7vQcemDgqjD6eHhDA1ovKJjSQ24hn7MCzB7MSYuM0qBngkD
# Kqze+YbyVDkixqx/4wJmTg5GzTe2/gSFkwKVv1o9Ij5Aab5On9sGyq8wTYIAFVc0
# uiErjFdIjlxE5wERnQu/O95LNKpqeYjEbLRb9sqfFVY3PmYulm3F4qsoEmTBwmKL
# eHPlgEC3/DspWUql6sHWY7o/7qFeah+tKrFrUwoXww==
# SIG # End signature block
