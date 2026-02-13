<#
.SYNOPSIS
    Security Information Collector
.DESCRIPTION
    Collects security-related information including firewall, antivirus, policies, and accounts.
#>

<#
.SYNOPSIS
    Collects Security information.
#>
function Get-SecurityInfo {
    [PSCustomObject]@{
        FirewallProfile  = Get-NetFirewallProfile -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
        FirewallRules    = Get-NetFirewallRule -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
        DefenderStatus   = Get-MpComputerStatus -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
        AntivirusProduct = Get-CimSafe -Namespace "root\SecurityCenter2" -ClassName AntivirusProduct
        LocalPolicy      = $(
            # Security: Use unique temp file name and ensure cleanup with try-finally
            $secPolPath = Join-Path $env:TEMP "secpol_$(Get-Random -Minimum 1000 -Maximum 9999)_$(Get-Date -Format 'yyyyMMddHHmmss').cfg"
            try { 
                Write-Log "    - Exporting local security policy..." -Color DarkGray -Level Debug
                $exportResult = secedit /export /cfg $secPolPath 2>&1
                
                if (Test-Path $secPolPath -PathType Leaf) {
                    $content = Get-Content $secPolPath -ErrorAction Stop | Select-Object -First 50
                    Write-Log "    ✓ Local policy exported" -Color DarkGray -Level Debug
                    $content
                }
                else {
                    Write-Log "    ✗ Policy export failed: $exportResult" -Color Red -Level Error
                    "Policy Export Failed: File not created"
                }
            }
            catch { 
                Write-Log "    ✗ Policy export exception: $_" -Color Red -Level Error
                "Policy Export Failed: $_" 
            }
            finally {
                # Security: Always cleanup temp file
                if (Test-Path $secPolPath) {
                    Remove-Item $secPolPath -Force -ErrorAction SilentlyContinue
                    Write-Log "    - Cleaned up temp policy file" -Color DarkGray -Level Debug
                }
            }
        )
        DomainController = $(
            try { 
                Write-Log "    - Querying domain controller..." -Color DarkGray -Level Debug
                $dc = Get-ADDomainController -ErrorAction Stop | Select-Object *
                Write-Log "    ✓ Domain controller info collected" -Color DarkGray -Level Debug
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
