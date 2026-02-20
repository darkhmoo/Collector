# --- Edge Case & Fault Injection Test Classes ---
# Purpose: Simulate enterprise-level edge cases and failures.

# --- 1. Fault Injection Helper ---

class FaultInjectionEngine {
    static [hashtable]$OriginalFunctions = @{}

    static [void] Inject([string]$FunctionName, [scriptblock]$FakeLogic) {
        if (-not [FaultInjectionEngine]::OriginalFunctions.ContainsKey($FunctionName)) {
            $existingGlobalFunction = Get-Item -Path "function:global:$FunctionName" -ErrorAction SilentlyContinue
            [FaultInjectionEngine]::OriginalFunctions[$FunctionName] = [PSCustomObject]@{
                HadGlobalFunction = ($null -ne $existingGlobalFunction)
                GlobalScriptBlock = if ($existingGlobalFunction) {
                    [scriptblock]::Create($existingGlobalFunction.ScriptBlock.ToString())
                }
                else {
                    $null
                }
            }
        }
        # Force override in global scope
        Set-Item -Path "function:global:$FunctionName" -Value $FakeLogic
    }

    static [void] Restore([string]$FunctionName) {
        if ([FaultInjectionEngine]::OriginalFunctions.ContainsKey($FunctionName)) {
            $original = [FaultInjectionEngine]::OriginalFunctions[$FunctionName]
            if ($original.HadGlobalFunction -and $null -ne $original.GlobalScriptBlock) {
                Set-Item -Path "function:global:$FunctionName" -Value $original.GlobalScriptBlock
            }
            else {
                Remove-Item -Path "function:global:$FunctionName" -ErrorAction SilentlyContinue
            }
            [FaultInjectionEngine]::OriginalFunctions.Remove($FunctionName)
        }
    }

    static [void] RestoreAll() {
        $names = @([FaultInjectionEngine]::OriginalFunctions.Keys)
        foreach ($name in $names) {
            $original = [FaultInjectionEngine]::OriginalFunctions[$name]
            if ($original.HadGlobalFunction -and $null -ne $original.GlobalScriptBlock) {
                Set-Item -Path "function:global:$name" -Value $original.GlobalScriptBlock
            }
            else {
                Remove-Item -Path "function:global:$name" -ErrorAction SilentlyContinue
            }
        }
        [FaultInjectionEngine]::OriginalFunctions.Clear()
    }
}

# --- 2. Phase 1 (P0) Test Classes ---

class WmiCorruptionTest : BaseTest {
    WmiCorruptionTest() : base("WMI Repository Corruption Simulation", "EdgeCase-P0") {}

    [string] Execute() {
        # Inject failure into Get-CimInstance
        [FaultInjectionEngine]::Inject("Get-CimInstance", {
                throw [System.Management.ManagementException]::new("WMI Repository is corrupted (HRESULT: 0x80041010)")
            })

        try {
            # This should be caught by Get-CimSafe in Common.ps1
            $res = Get-CimSafe -className "Win32_OperatingSystem"
            if ($null -ne $res) {
                throw "Get-CimSafe failed to return null during WMI corruption."
            }
            return "Get-CimSafe gracefully handled WMI corruption"
        }
        finally {
            [FaultInjectionEngine]::Restore("Get-CimInstance")
        }
    }
}

class TamperedSignatureTest : BaseTest {
    TamperedSignatureTest() : base("Tampered Script Signature Detection", "EdgeCase-P0") {}

    [string] Execute() {
        $tempFile = Join-Path $env:TEMP "tamper_test_$([guid]::NewGuid().ToString().Substring(0,8)).ps1"
        $content = "Write-Host 'Original Content'"
        $content | Out-File $tempFile -Encoding utf8
        
        try {
            # 1. Sign the file
            $cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -like "*Collector*" } | Select-Object -First 1
            if ($null -eq $cert) { throw "Test certificate not found. Run Setup-Security.ps1 first." }
            
            Set-AuthenticodeSignature -FilePath $tempFile -Certificate $cert | Out-Null
            
            # 2. Tamper the file (Append a space)
            Add-Content $tempFile " "
            
            # 3. Verify
            $sig = Get-AuthenticodeSignature -FilePath $tempFile
            if ($sig.Status -eq "Valid") {
                throw "Security failure: Tampered signature was still marked as Valid."
            }
            
            return "Tampered signature correctly detected as $($sig.Status)"
        }
        finally {
            if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
        }
    }
}

class DiskFullSimulationTest : BaseTest {
    DiskFullSimulationTest() : base("Storage Quota/Disk Full Simulation", "EdgeCase-P0") {}

    [string] Execute() {
        # Simulate critically low disk space for the output drive pre-check.
        [FaultInjectionEngine]::Inject("Get-PSDrive", {
                param([string]$Name)
                return [PSCustomObject]@{
                    Name = $Name
                    Free = 1024
                }
            })

        try {
            $dummyReport = [PSCustomObject]@{
                Logs = @{ EventLogs = @{} }
            }

            # Attempt to save results (should fail due to low-space guard).
            try {
                Save-Results `
                    -auditReport $dummyReport `
                    -outputFormat @("JSON") `
                    -eventLogFormat "HTML" `
                    -outputDirectory $env:TEMP `
                    -isDebugMode $false `
                    -zipResults $false `
                    -encryptionKey $null
                throw "Save-Results should have blocked the save due to low disk space."
            }
            catch {
                if ($_.Exception.Message -like "*Insufficient space*") {
                    return "Disk full guard correctly blocked the operation"
                }
                throw "Unexpected error: $($_.Exception.Message)"
            }
        }
        finally {
            [FaultInjectionEngine]::Restore("Get-PSDrive")
        }
    }
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUx08DEA0hf13vjj8gPw8mNzIg
# QiygggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU10QpHeJ9bQwq5RFRiiI9wKeWARUwDQYJ
# KoZIhvcNAQEBBQAEggEAGri9OQIOw0PzeSu9DxRHYHBxSnlkVFE0wms0T/+lRGpR
# 2IqgR4eybCaF4ghr4scv/q7LbpnWHX25LpouHsqQpnf0JHk26krwxJipikUFmma0
# 3NcPGju1BNJI6OHHr91RdNU/NW73chb09C7B1ppjqbeIxJsAWUj2oh5VHb6tWUJ0
# N84bOnA8O1AC3z+AQM2cyzefE8CyqlVAT+MGI/uD4a49GrSMjEllViDIxk+8CpHX
# ql9k0Bh+1XOKks/D8bLq7ylzE4KFruDq79wZAjFZYUnzP7lgaNnbp5eUj4A/7AS8
# 6RloEUmAd0vCojOwIW9BtJ2O7N4EMMJpq5ctTIc3jA==
# SIG # End signature block
