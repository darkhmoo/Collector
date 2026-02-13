<#
.SYNOPSIS
    High Availability Information Collector
.DESCRIPTION
    Collects HA-related information including cluster, NIC teaming, MCCS, and SAN.
#>

<#
.SYNOPSIS
    Collects MCCS (Mantech Cluster) Information.
#>
function Get-MCCSInfo {
    try {
        $svc = Get-Service -Name "*MCCS*" -ErrorAction SilentlyContinue
        $path = Test-Path "C:\Program Files\Mantech\MCCS"
        $reg = Get-ItemProperty "HKLM:\SOFTWARE\Mantech\MCCS" -ErrorAction SilentlyContinue
        $confFiles = if ($path) { Get-ChildItem "C:\Program Files\Mantech\MCCS\conf" -ErrorAction SilentlyContinue | Select-Object * } else { $null }
            
        if ($svc -or $path) { 
            [PSCustomObject]@{ 
                Installed   = $true
                Services    = $svc
                PathExists  = $path
                Registry    = $reg
                ConfigFiles = $confFiles
            } 
        }
        else { "Not Detected" }
    }
    catch {
        return "Error: $_"
    }
}

<#
.SYNOPSIS
    Collects Failover Cluster information.
#>
function Get-ClusterInfo {
    if (-not (Get-Module -ListAvailable -Name FailoverClusters)) {
        return "Cluster Feature Not Installed"
    }

    try {
        $c = Get-Cluster -ErrorAction Stop
        
        # Generate Cluster Log
        Write-Log "  - Generating Cluster Log ..." -Color Gray
        Get-ClusterLog -Destination $PSScriptRoot -TimeSpan 15 -UseLocalTime -ErrorAction SilentlyContinue

        # Capture all generated cluster logs (format: NodeName_cluster.log)
        $clusterLogs = Get-ChildItem -Path $PSScriptRoot -Filter "*cluster.log" -ErrorAction SilentlyContinue
        
        foreach ($log in $clusterLogs) {
            $script:generatedFiles += $log.FullName
        }

        return [PSCustomObject]@{
            ClusterObject           = $c | Select-Object *
            Nodes                   = Get-ClusterNode | Select-Object *
            Groups                  = Get-ClusterGroup | Select-Object *
            Resources               = Get-ClusterResource | Select-Object *
            Networks                = Get-ClusterNetwork | Select-Object *
            MSClusterEvents         = Get-CimSafe -Namespace "root\MSCluster" -ClassName MSCluster_Event
            MSClusterServices       = Get-CimSafe -Namespace "root\MSCluster" -ClassName MSCluster_Service
            MSClusterValidation     = Get-CimSafe -Namespace "root\MSCluster" -ClassName MSCluster_ValidationStatus
            MSClusterDisks          = Get-CimSafe -Namespace "root\MSCluster" -ClassName MSCluster_Disk
            MSClusterPartitions     = Get-CimSafe -Namespace "root\MSCluster" -ClassName MSCluster_DiskPartition
            MSClusterSharedDiskType = Get-CimSafe -Namespace "root\MSCluster" -ClassName MSCluster_SharedDiskType
            ClusterLogGenerated     = ($clusterLogs.Count -gt 0)
            ClusterLogFiles         = ($clusterLogs.Name -join ", ")
        }
    }
    catch {
        return "Cluster Feature Installed but Not Configured or WMI Error: $_"
    }
}

<#
.SYNOPSIS
    Collects High Availability information (Cluster, Teaming, MCCS, SAN).
#>
function Get-HighAvailabilityInfo {
    [PSCustomObject]@{
        Cluster     = Get-ClusterInfo
        NICTeaming  = Get-NetLbfoTeam -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
        MCCS        = Get-MCCSInfo
        ExternalSAN = [PSCustomObject]@{
            HDLM      = Get-Service -Name "*HDLM*" -ErrorAction SilentlyContinue | Select-Object *
            PowerPath = Get-Service -Name "*PowerPath*" -ErrorAction SilentlyContinue | Select-Object *
        }
    }
}
