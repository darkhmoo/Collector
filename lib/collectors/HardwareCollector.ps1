<#
.SYNOPSIS
    Hardware Information Collector
.DESCRIPTION
    Collects hardware-related information including BIOS, CPU, Memory, Disk, and PnP devices.
#>

<#
.SYNOPSIS
    Collects Hardware information.
#>
function Get-HardwareInfo {
    [PSCustomObject]@{
        BIOS             = Get-CimSafe -ClassName Win32_BIOS
        Keyboard         = Get-CimSafe -ClassName Win32_Keyboard
        Processor        = Get-CimSafe -ClassName Win32_Processor
        PhysicalMemory   = Get-CimSafe -ClassName Win32_PhysicalMemory
        PhysicalMemArray = Get-CimSafe -ClassName Win32_PhysicalMemoryArray
        DiskDrive        = Get-CimSafe -ClassName Win32_DiskDrive
        DiskPartition    = Get-CimSafe -ClassName Win32_DiskPartition
        LogicalDisk      = Get-CimSafe -ClassName Win32_LogicalDisk
        Volume           = Get-CimSafe -ClassName Win32_Volume
        SystemInfo       = Get-CimSafe -ClassName Win32_ComputerSystem
        PnPEntities      = Get-CimSafe -ClassName Win32_PnPEntity
    }
}
