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

# --- 3. Execution ---

Write-Host "`nStarting Integrated Test Suite..." -ForegroundColor White -Bold
$runner.RunAll()

# --- 4. Final Reporting ---

$runner.ShowSummary()
