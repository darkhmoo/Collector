# --- Infrastructure Test Classes ---

class AdminPrivilegeTest : BaseTest {
    AdminPrivilegeTest() : base("Admin Privileges Check", "Infrastructure") {}

    [string] Execute() {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "Not running as Administrator."
        }
        return "Running as Admin"
    }
}

class MutexIsolationTest : BaseTest {
    MutexIsolationTest() : base("Mutex Singleton Isolation", "Infrastructure") {}

    [string] Execute() {
        $mutex = Get-ScriptMutex
        try {
            $job = Start-Job -ScriptBlock {
                param($path)
                . (Join-Path $path "lib\Common.ps1")
                try { Get-ScriptMutex; return "Success" } catch { return "Failed: $($_.Exception.Message)" }
            } -ArgumentList (Resolve-Path "$PSScriptRoot\..\..").Path
            
            $res = Wait-Job $job | Receive-Job
            if ($res -notlike "*CRITICAL ERROR: Script is already running*") {
                throw "Mutex failed to block concurrent session. Result: $res"
            }
            return "Mutex isolation verified"
        }
        finally {
            if ($mutex) { $mutex.Dispose() }
        }
    }
}
