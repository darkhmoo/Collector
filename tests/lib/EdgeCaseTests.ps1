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
                Logs = @{ EventLogs = $null }
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

class SaveResultsWriteFailurePropagationTest : BaseTest {
    SaveResultsWriteFailurePropagationTest() : base("Save-Results Write Failure Propagation", "EdgeCase-P0") {}

    [string] Execute() {
        [FaultInjectionEngine]::Inject("Export-EventLogFiles", {
                param($EventLogs, $outputFormat, $OutputDir, $lookbackDays, $fileTimestamp)
            })
        [FaultInjectionEngine]::Inject("Set-Content", {
                throw [System.UnauthorizedAccessException]::new("Mock access denied")
            })

        try {
            $dummyReport = [PSCustomObject]@{
                Logs = @{ EventLogs = @{} }
            }

            try {
                Save-Results `
                    -auditReport $dummyReport `
                    -outputFormat @("JSON") `
                    -eventLogFormat "HTML" `
                    -outputDirectory $env:TEMP `
                    -isDebugMode $false `
                    -zipResults $false `
                    -encryptionKey $null
                throw "Save-Results should have thrown on write failure."
            }
            catch {
                if ($_.Exception.Message -like "*Output generation failed*") {
                    return "Write failure was propagated to caller"
                }
                throw "Unexpected error contract: $($_.Exception.Message)"
            }
        }
        finally {
            [FaultInjectionEngine]::Restore("Export-EventLogFiles")
            [FaultInjectionEngine]::Restore("Set-Content")
        }
    }
}

class MainScriptFatalExitContractTest : BaseTest {
    MainScriptFatalExitContractTest() : base("Main Script Fatal Exit Contract", "EdgeCase-P0") {}

    [string] Execute() {
        $mainScriptPath = Join-Path $PSScriptRoot "..\..\system_information_collector_for_windows.ps1"
        if (-not (Test-Path -Path $mainScriptPath -PathType Leaf)) {
            throw "Main script not found: $mainScriptPath"
        }

        $content = Get-Content -Path $mainScriptPath -Raw -Encoding UTF8

        if ($content -notmatch '\$fatalError\s*=\s*\$null') {
            throw "Missing fatal error tracking variable."
        }
        if ($content -notmatch '(?s)catch\s*\{\s*\$fatalError\s*=') {
            throw "Missing top-level catch that captures fatal error."
        }
        if ($content -notmatch '(?s)if\s*\(\$fatalError\)\s*\{.*?exit\s+1') {
            throw "Missing explicit exit code 1 on fatal error."
        }

        return "Fatal catch and exit contract found"
    }
}
# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUVSjtxKouCbZC3Q/2u5DfRisL
# DxWgggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU8dz1DruamwIAu3yjj/yjNRFbN78wDQYJ
# KoZIhvcNAQEBBQAEggEAaiUGeVQB2Mm/UPadqSeTUa/5W2LFXM6n8cJKAFJ7bfRP
# 0mv4qcnEX6/1gePYYMTmCMXdNBtkGoHxad0wzezTGiFUnQ0VIXtZ2ncZb7DUHOJ2
# +IZcrfqUDeK2JJV1QbxY5ONY7+b58wjcVPVeG2hfd04zUShsR8LcNvh54DF8pLmS
# qPhO7qmj9odjgKXTQa4s31t1qOt3HaBU2JpBX7R86IMrc6YKNxsvM3GKDm+OYLyH
# uAZz/skHitvEpCPDTPlO5j6mBRZ3CBVOGFr/n0dIigwMonEQPti6N/MKtBwUOp/b
# Rsk8ORRaL1YXk3VfOH2nQ6TJHLsW83BmH3hCp5Zaww==
# SIG # End signature block
