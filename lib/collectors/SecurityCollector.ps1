<#
.SYNOPSIS
    Security Information Collector
.DESCRIPTION
    Collects security-related information including firewall, antivirus, policy, and account data.
#>

function Get-SecurityInfo {
    [PSCustomObject]@{
        FirewallProfile  = Get-NetFirewallProfile -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
        FirewallRules    = Get-NetFirewallRule -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
        DefenderStatus   = Get-MpComputerStatus -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
        AntivirusProduct = Get-CimSafe -Namespace "root\SecurityCenter2" -ClassName AntivirusProduct
        LocalPolicy      = $(
            # Use a securely-created temporary file and always delete it.
            $tempFile = [System.IO.Path]::GetTempFileName()
            $secPolPath = [System.IO.Path]::ChangeExtension($tempFile, ".cfg")
            Move-Item -Path $tempFile -Destination $secPolPath -Force

            try {
                Write-Log "    - Exporting local security policy..." -Color DarkGray -Level Debug
                $exportResult = & secedit /export /cfg $secPolPath 2>&1

                if (Test-Path $secPolPath -PathType Leaf) {
                    $content = Get-Content -Path $secPolPath -ErrorAction Stop | Select-Object -First 50
                    Write-Log "    - Local policy exported" -Color DarkGray -Level Debug
                    $content
                }
                else {
                    Write-Log "    - Policy export failed: $exportResult" -Color Red -Level Error
                    "Policy Export Failed: File not created"
                }
            }
            catch {
                Write-Log "    - Policy export exception: $_" -Color Red -Level Error
                "Policy Export Failed: $_"
            }
            finally {
                if (Test-Path $secPolPath -PathType Leaf) {
                    Remove-Item -Path $secPolPath -Force -ErrorAction SilentlyContinue
                    Write-Log "    - Cleaned up temp policy file" -Color DarkGray -Level Debug
                }
            }
        )
        DomainController = $(
            try {
                Write-Log "    - Querying domain controller..." -Color DarkGray -Level Debug
                $dc = Get-ADDomainController -ErrorAction Stop | Select-Object *
                Write-Log "    - Domain controller info collected" -Color DarkGray -Level Debug
                $dc
            }
            catch {
                Write-Log "    ! RSAT/Domain not available" -Color Yellow -Level Debug
                "RSAT/Domain Not Available"
            }
        )
        Accounts         = Get-CimSafe -ClassName Win32_Account
        Groups           = Get-CimSafe -ClassName Win32_Group
        GroupUsers       = Get-CimSafe -ClassName Win32_GroupUser
    }
}
