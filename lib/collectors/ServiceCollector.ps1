<#
.SYNOPSIS
    Service and Driver Information Collector
.DESCRIPTION
    Collects service, driver, process, and DTC information.
#>

<#
.SYNOPSIS
    Collects Service and Driver information.
#>
function Get-ServiceInfo {
    [PSCustomObject]@{
        Services         = Get-CimSafe -ClassName Win32_Service
        SystemDrivers    = Get-CimSafe -ClassName Win32_SystemDriver
        PnPSignedDrivers = Get-CimSafe -ClassName Win32_PnPSignedDriver -WhereBlock { $null -ne $_.DeviceName }
        PnPEntities      = Get-CimSafe -ClassName Win32_PnPEntity
        Processes        = Get-CimSafe -ClassName Win32_Process
        DTC              = $(try { Get-Dtc -ErrorAction Stop | Select-Object * } catch { "DTC Cmdlet Not Available" })
    }
}
