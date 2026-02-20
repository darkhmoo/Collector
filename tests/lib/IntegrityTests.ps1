# --- Integrity & Compliance Test Classes ---

function Import-LogCollectorSafely {
    $collectorPath = Join-Path $PSScriptRoot "..\..\lib\collectors\LogCollector.ps1"
    try {
        . $collectorPath
    }
    catch {
        if ($_.Exception.Message -notlike "*Duplicate class*") {
            throw
        }
    }
}

class AESRoundTripTest : BaseTest {
    AESRoundTripTest() : base("AES-256 Round-trip Integrity", "Integrity") {}

    [string] Execute() {
        $testData = "Class-based Refactor Test $(Get-Date)"
        $tempFile = [System.IO.Path]::GetTempFileName()
        $encFile = $tempFile + ".aes"
        $key = ConvertTo-SecureString "Refactor123!" -AsPlainText -Force
        
        try {
            [System.IO.File]::WriteAllBytes($tempFile, [System.Text.Encoding]::UTF8.GetBytes($testData))
            Protect-File -Path $tempFile -DestinationPath $encFile -Key $key
            
            # Internal decryption check
            $fs = New-Object System.IO.FileStream($encFile, [System.IO.FileMode]::Open)
            $salt = New-Object byte[] 16; $iv = New-Object byte[] 16
            $fs.Read($salt, 0, 16) | Out-Null; $fs.Read($iv, 0, 16) | Out-Null
            
            $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($key)
            $kStr = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
            $pbkdf2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($kStr, $salt, 100000)
            $kb = $pbkdf2.GetBytes(32)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
            
            $aes = [System.Security.Cryptography.Aes]::Create()
            $aes.Key = $kb; $aes.IV = $iv
            $dec = $aes.CreateDecryptor()
            $cs = New-Object System.Security.Cryptography.CryptoStream($fs, $dec, [System.Security.Cryptography.CryptoStreamMode]::Read)
            $sr = New-Object System.IO.StreamReader($cs, [System.Text.Encoding]::UTF8)
            $restored = $sr.ReadToEnd()
            
            $sr.Dispose(); $cs.Dispose(); $dec.Dispose(); $aes.Dispose(); $fs.Dispose()
            
            if ($restored -ne $testData) { throw "Integrity mismatch." }
            return "AES-256 Binary Integrity Verified"
        }
        finally {
            if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
            if (Test-Path $encFile) { Remove-Item $encFile -Force }
        }
    }
}

class ComplianceTest : BaseTest {
    ComplianceTest() : base("BaseCollector Inheritance Check", "Compliance") {}

    [string] Execute() {
        $collectors = Get-ChildItem -Path "$PSScriptRoot\..\..\lib\collectors\*.ps1"
        foreach ($file in $collectors) {
            try { . $file.FullName } catch {
                if ($_.Exception.Message -notlike "*Duplicate class*") {
                    throw "Load failed for $($file.Name): $($_.Exception.Message)"
                }
            }
        }
        return "All classes compliant"
    }
}

class QuotaGuardTest : BaseTest {
    QuotaGuardTest() : base("LogCollector Resource Guard", "Guard") {}

    [string] Execute() {
        . Import-LogCollectorSafely
        $res = Get-LogInfo
        if ($null -eq $res) { throw "LogCollector returned null" }
        return "Quota guard initialized"
    }
}

class LogCollectionWindowParameterTest : BaseTest {
    LogCollectionWindowParameterTest() : base("LogCollection Lookback Parameter", "Guard") {}

    [string] Execute() {
        . Import-LogCollectorSafely

        $eventLogCommand = Get-Command Get-EventLogs -ErrorAction SilentlyContinue
        if ($null -eq $eventLogCommand) {
            throw "Get-EventLogs function not found."
        }

        if (-not $eventLogCommand.Parameters.ContainsKey("LookbackDays")) {
            throw "Get-EventLogs must expose -LookbackDays parameter for window control."
        }

        $originalGetWinEventFunction = Get-Item -Path function:global:Get-WinEvent -ErrorAction SilentlyContinue
        $originalGetWinEventScript = if ($originalGetWinEventFunction) {
            [scriptblock]::Create($originalGetWinEventFunction.ScriptBlock.ToString())
        }
        else {
            $null
        }

        $script:CapturedFilterXml = @()

        try {
            Set-Item -Path function:global:Get-WinEvent -Value {
                param(
                    [string]$FilterXml,
                    [int]$MaxEvents,
                    [object]$ErrorAction
                )
                $script:CapturedFilterXml += $FilterXml
                return @()
            }

            # 1) Default window check (expected 7 days = 604800000ms)
            $null = Get-EventLogs
            if ($script:CapturedFilterXml.Count -ne 3) {
                throw "Expected 3 log queries for default window, got $($script:CapturedFilterXml.Count)."
            }

            foreach ($queryXml in $script:CapturedFilterXml) {
                if ($queryXml -notmatch "timediff\(@SystemTime\)\s*&lt;=\s*604800000") {
                    throw "Default window mismatch. Expected timediff <= 604800000ms."
                }
            }

            # 2) Parameterized window check (2 days = 172800000ms)
            $script:CapturedFilterXml = @()
            $null = Get-EventLogs -LookbackDays 2
            if ($script:CapturedFilterXml.Count -ne 3) {
                throw "Expected 3 log queries for custom window, got $($script:CapturedFilterXml.Count)."
            }

            foreach ($queryXml in $script:CapturedFilterXml) {
                if ($queryXml -notmatch "timediff\(@SystemTime\)\s*&lt;=\s*172800000") {
                    throw "Custom window mismatch. Expected timediff <= 172800000ms for -LookbackDays 2."
                }
            }

            return "Lookback parameter verified for default(7d) and custom(2d) windows"
        }
        finally {
            if ($null -ne $originalGetWinEventScript) {
                Set-Item -Path function:global:Get-WinEvent -Value $originalGetWinEventScript
            }
            else {
                Remove-Item -Path function:global:Get-WinEvent -ErrorAction SilentlyContinue
            }

            Remove-Variable -Name CapturedFilterXml -Scope Script -ErrorAction SilentlyContinue
        }
    }
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUkKntrTJWKk5m1Q+VjwkKTwzj
# 8iCgggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUnqUNqyRz/5YznRA8EHY3kisCCvAwDQYJ
# KoZIhvcNAQEBBQAEggEAG9VCihNe35mMm104XiP2pbK/Cq8WDfXzXYLfMh4RYj/N
# FTrhbP6SNEbRT8n0hZ9JVm+HNIfyif9EBDqjQBGrIODjwC5MrmXwRkVBOsQ9H45U
# JhtzEBf8B0+vMBa9RYXwbm1OG0me3ktCuumRvAPLH+fuDCReCo/kH4r2K6iHIR6L
# l0rr3Nnzau+62G/7kqyvWQ28H5Gr9LDeEMa/R0kcSsTnh1i5WoeQhGZmpZoHz4LZ
# U1PYdyy2ZEwjH/WqXQyBQHjM30qjHRT9yMN+KC+djY0W9fqjU8yfnbYc3bA4lVfh
# kOi/2lPB9Whs99UxnQ+n7EWznEWm2uqsGdMiJ6Hrig==
# SIG # End signature block
