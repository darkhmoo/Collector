# --- Comprehensive System Information Collector Tests (Class-based v2.0) ---
# Version: 2.0.0
# Author: Senior Windows Infrastructure & Security Engineer
# Description: Enterprise-grade Object-Oriented testing suite.

[CmdletBinding()]
param()

# --- 1. Initialization ---
Write-Host "[Init] Preparing Test Environment..." -ForegroundColor Cyan

try {
    # 1.1 Load Collector Core Libraries
    . "$PSScriptRoot\../lib/Classes.ps1"
    . "$PSScriptRoot\../lib/Common.ps1"
    . "$PSScriptRoot\../lib/OutputManager.ps1"
    $script:DebugMode = $true
    
    # 1.2 Load Test Framework Classes
    . "$PSScriptRoot\lib\TestClasses.ps1"
    
    # 1.3 Load Functional Test Modules
    . "$PSScriptRoot\lib\SecurityTests.ps1"
    . "$PSScriptRoot\lib\InfrastructureTests.ps1"
    . "$PSScriptRoot\lib\IntegrityTests.ps1"
    . "$PSScriptRoot\lib\EdgeCaseTests.ps1"
    
    Write-Host "[Init] Environment ready. All test classes loaded." -ForegroundColor Green
}
catch {
    Write-Host "CRITICAL: Initialization failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# --- 2. Test Registration ---

$runner = [TestRunner]::new()

# Infrastructure Group
$runner.AddTest([AdminPrivilegeTest]::new())
$runner.AddTest([MutexIsolationTest]::new())

# Security Group
$runner.AddTest([AuthenticodeTest]::new())
$runner.AddTest([DLPMaskingTest]::new())

# Integrity & Compliance Group
$runner.AddTest([AESRoundTripTest]::new())
$runner.AddTest([ComplianceTest]::new())
$runner.AddTest([QuotaGuardTest]::new())
$runner.AddTest([LogCollectionWindowParameterTest]::new())

# Edge Case (P0) Group
$runner.AddTest([WmiCorruptionTest]::new())
$runner.AddTest([TamperedSignatureTest]::new())
$runner.AddTest([DiskFullSimulationTest]::new())
$runner.AddTest([SaveResultsWriteFailurePropagationTest]::new())
$runner.AddTest([MainScriptFatalExitContractTest]::new())
$runner.AddTest([ParallelCollectionTimeoutContractTest]::new())
$runner.AddTest([ParallelCollectionTimeoutBehaviorTest]::new())
$runner.AddTest([MainScriptSequentialTimeoutContractTest]::new())
$runner.AddTest([ParallelTimeoutResultSchemaTest]::new())
$runner.AddTest([ParallelTimeoutIsolationBehaviorTest]::new())
$runner.AddTest([ParallelTimeoutResourceCleanupSmokeTest]::new())
$runner.AddTest([EndInvokeExceptionStructuredResultTest]::new())
$runner.AddTest([EndInvokeExceptionIsolationTest]::new())
$runner.AddTest([MainScriptRunspaceExceptionSummaryContractTest]::new())
$runner.AddTest([ParallelInterruptResultSchemaTest]::new())
$runner.AddTest([MainScriptInterruptContractTest]::new())

# --- 3. Execution ---

Write-Host "`nStarting Integrated Test Suite..." -ForegroundColor White -Bold
$runner.RunAll()

# --- 4. Final Reporting ---

$runner.ShowSummary()

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUezDcQcYBCXvlgU2TtUCAuyHJ
# mN2gggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUvRaDTaxooFnmqxJ5zOUY9zK71GswDQYJ
# KoZIhvcNAQEBBQAEggEADqW0qVAbMiKFYeXFyEa9CeVtmK4J1bF3SAr3LdOP3maE
# 2FkaK1qlMDPdTtiYhKrvGX95mCzPWddLg18B9sxzYeJMUK1cFFXm+dT7yQJG7891
# 4kYF5hWIy20Wc5XRb+cUckVhuDZhbCxFecKsIPuS43erA2LvvzU90PP/5As4/7E9
# /i427t4UU/dSSVRvwqllmgfKtYJ1+esQM+5zmC3eH2zbOW+jjcdPTu43kDZshUxp
# tqSChTzaovKdPJpT6D/6CzEcreEe7iqZ+rg+fD+AEL9/P4vRmEcf6dBQ36hGUf8F
# 1orL1wxhzZhJ/2d2a61m3sm34ghyyj/S30yA9/hdPA==
# SIG # End signature block
