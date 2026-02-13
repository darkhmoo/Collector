<#
.SYNOPSIS
    Performance Information Collector
.DESCRIPTION
    Collects performance metrics for CPU, memory, disk, network, and processes.
#>

<#
.SYNOPSIS
    Collects Performance information.
#>
function Get-PerformanceInfo {
    [PSCustomObject]@{
        RawCPU              = Get-CimSafe -ClassName Win32_PerfRawData_PerfOS_Processor
        RawMemory           = Get-CimSafe -ClassName Win32_PerfRawData_PerfOS_Memory
        FormattedDisk       = Get-CimSafe -ClassName Win32_PerfFormattedData_PerfDisk_LogicalDisk
        FormattedTCP        = Get-CimSafe -ClassName Win32_PerfFormattedData_Tcpip_NetworkInterface
        FormattedMem        = Get-CimSafe -ClassName Win32_PerfFormattedData_PerfOS_Memory
        FormattedPagingfile = Get-CimSafe -ClassName Win32_PerfFormattedData_PerfOS_PagingFile
        ProcessPerformance  = $(try { Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction Stop | Sort-Object -Property PercentProcessorTime -Descending | Select-Object -First 20 * -ExcludeProperty "Cim*" } catch { "Error: $_" })
    }
}
