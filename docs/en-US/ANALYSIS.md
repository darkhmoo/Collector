# 📄 System Information Collector Script Analysis

## 1️⃣ Script Overview
| Item | Content |
|------|---------|
| **Purpose** | Collects comprehensive system data (Hardware, Network, OS, Service, Perf, Logs, Security, AD, HA, Virtualization, Inventory, etc.), generates JSON/HTML/CSV reports, and provides secure archival/encryption. |
| **Supported PowerShell Version** | `#Requires -Version 5.1` (PowerShell 5.1 or higher) |
| **Parameters** | - `-OutputFormat` : `JSON`, `HTML`, `CSV`, `ALL` <br> - `-Compress` : ZIP Archival <br> - `-Encrypt` : AES-256 Encryption <br> - `-Parallel` : Parallel Collection <br> - `-DebugMode` : Detailed Logging |
| **Main Workflow** | 1️⃣ Init → 2️⃣ Load Classes & Libs → 3️⃣ Pre-checks → 4️⃣ Dynamic Plugin Load (Signature Verif) → 5️⃣ Data Collection → 6️⃣ Output Generation & Security Processing → 7️⃣ Cleanup |
| **External Modules** | `lib\Classes.ps1`, `lib\Common.ps1`, `lib\Collectors.ps1`, `lib\Reporters.ps1` |

---

## 2️⃣ Detailed Workflow
| Stage | Description | Key Code Samples |
|-------|-------------|-------------------|
| **① Initialization** | Measure execution time (`Stopwatch`) and set debug log paths. | ` $scriptStopwatch = [System.Diagnostics.Stopwatch]::StartNew()` |
| **② Library Loading** | Load `Classes.ps1` (BaseCollector), `Common.ps1`, `Collectors.ps1`, `Reporters.ps1` in sequence. | ` . "$PSScriptRoot\lib\Classes.ps1"` |
| **③ Pre-checks** | - Assert Admin privileges <br> - Assert prerequisites <br> - Acquire Mutex. | `Assert-AdminPrivileges` |
| **④ Plugin Loading** | Scans `lib\collectors\` for `.ps1` files and loads them after **Authenticode signature** verification. | `Get-AuthenticodeSignature` |
| **⑤ Data Collection** | Calls the class-based `Collect()` method for each of the 11 categories. | `$collector.Collect()` |
| **⑤ Record Time** | Stop `Stopwatch` → Format duration string → Assign to object. | `$scriptStopwatch.Stop()` |
| **⑥ Output Generation**| - **Data Conversion**: JSON/HTML/CSV reports <br> - **Encryption (`-Encrypt`)**: AES-256 encryption for each file (.aes) <br> - **Archiving (`-Compress`)**: Zip generated/encrypted files. | `Save-Results` logic |
| **⑦ Cleanup** | Deletes plain text originals immediately after encryption; normal cleanup if not DebugMode. | `if (-not $DebugMode){ ... }` |
| **⑧ Release Mutex** | `ReleaseMutex()` and `Dispose()`. | `$mutex.ReleaseMutex(); $mutex.Dispose()` |
| **⑨ Return** | Return final `$auditReport` object (enables pipeline usage). | `return $auditReport` |

---

## 3️⃣ Core Functions & Modules (External Files)
| File | Role | Key Functions (Examples) |
|------|------|--------------------------|
| `Common.ps1` | Logging, error handling, utilities | `Write-Log`, `Assert-AdminPrivileges`, `Get-ScriptMutex`, `Get-CimSafe`, `Invoke-Collection` |
| `Collectors.ps1` | Collector Module Loader | Loads all individual collector modules and provides a unified interface. |
| `Reporters.ps1` | Report generation & formatting | `ConvertTo-HtmlReport`, `Get-HtmlTable`, `Get-HtmlTemplate` |

### 📁 Collector Modules (lib/collectors/)
Separated by function following the Single Responsibility Principle (SRP):

| File | Responsibility | Key Functions |
|------|----------------|---------------|
| `HardwareCollector.ps1` | Hardware info | `Get-HardwareInfo` - BIOS, CPU, RAM, Disk, PnP Devices |
| `NetworkCollector.ps1` | Network info | `Get-NetworkInfo` - Adapters, Config, Routing, DNS |
| `OSCollector.ps1` | OS & Config | `Get-OSConfig` - Power Plans, Time Sync, PageFile, Features |
| `ServiceCollector.ps1` | Services & Drivers | `Get-ServiceInfo` - Services, Drivers, Processes, DTC |
| `PerformanceCollector.ps1` | Performance metrics | `Get-PerformanceInfo` - Pool Memory, Handle Leaks |
| `LogCollector.ps1` | Log information | `Get-LogInfo`, `Get-EventLogs`, `Get-WindowsUpdateInfo` |
| `SecurityCollector.ps1` | Security info | `Get-SecurityInfo` - Firewall, AV, Policy, Local Accounts |
| `HACollector.ps1` | High Availability | `Get-HighAvailabilityInfo`, `Get-ClusterInfo`, `Get-MCCSInfo` |
| `ADCollector.ps1` | Active Directory | `Get-ActiveDirectoryInfo` - Domain, Forest, Trust, Object Summary |
| `VirtualizationCollector.ps1`| Virtualization | `Get-VirtualizationInfo` - Hyper-V, Containers, WSL |
| `InventoryCollector.ps1` | Inventory | `Get-InventoryInfo` - Installed Software (64/32-bit), Appx Packages |


> **Advanced Architecture (Class-based)**: Each collector module inherits from the `BaseCollector` class, providing a consistent interface (`Collect()`, `LogStart()`, `LogEnd()`). This improves code reusability and runtime stability.

---

## 4️⃣ Code Quality & Improvement Points
| Area | Status | Improvement Suggestion |
|------|--------|------------------------|
| **Validation** | Uses `ValidateSet` for OutputFormat | Add `ValidatePattern` to prevent illegal characters in filenames |
| **Error Handling** | `try/catch` around main output | Add localized `try/catch` within `Invoke-Collection` for granular failure reporting |
| **Debug Logging** | Records via `Write-Log` | Verify automatic file persistence in `Common.ps1` to prevent log loss |
| **Memory & Resources** | GC triggered after Runspace | **Explicit `Dispose()` and `try-finally`** for `.NET` streams and CIM handles to prevent leaks |
| **Security Hardening** | Plain-text data exposure | **Universal Masking Engine (`Get-MaskedValue`)** for concealing sensitive info across all modules |
| **Digital Signatures** | Script manipulation risk | **Authenticode Verification** mandated for all plugin loads to ensure integrity |

---

## 5️⃣ Security & Operations
| Checkpoint | Content |
|------------|----------|
| **Admin Privs** | Mandatory pre-validation via `Assert-AdminPrivileges`. |
| **Execution Policy**| May require `Set-ExecutionPolicy RemoteSigned` for script execution. |
| **File Deletion** | Securely wipes plain text originals when encrypted to minimize data residue. |
| **Data Encryption** | Provides physical data protection via **AES-256** standard and **SecureString** input. |

---

## 6️⃣ Summary
- **Overall Flow**: Init → Load Libs → Pre-checks → 11 Category Collection → JSON/HTML/CSV Output → ZIP Archival → Cleanup.
- **Core Modules**: `Common.ps1` (Shared Logic), `Collectors.ps1` (Loader), `Reporters.ps1` (Reports), 11 specialized collectors.
- **Debug Mode**: Automatic log generation, performance summary, and skips cleanup.
- **Output Options**: Supports `JSON`, `HTML`, `CSV`, `ALL`; bundles results into ZIP.

---

## 7️⃣ Refactoring: Modularization & SRP

### 🎯 Design Philosophy & Clean Code Compliance
This project reflects **PowerShell Clean Code Guide** standards, emphasizing these principles:

1. **Single Responsibility Principle (SRP)**:
   - Collectors (`collectors/`), Reporters (`reporters/`), Libraries (`Common.ps1`), and Output Controllers (`OutputManager.ps1`) are physically decoupled to reduce coupling and increase maintainability.
2. **Side-effect Isolation**:
   - Actions altering system state (writing files, creating folders, zipping) are guarded via `SupportsShouldProcess` (`-WhatIf`).
3. **Intent-driven Naming**:
   - Functions follow `Verb-Noun` format; internal variables use `camelCase` for readability. Approved verbs only.
4. **Fail Fast & Defensive Design**:
   - Parameter validation blocks bad inputs early; module errors are isolated via `Invoke-Collection` to ensure one module's failure doesn't stop the entire process.

### 📦 Module Breakdown & Responsibilities

#### 1. HardwareCollector.ps1
- Collects BIOS, CPU, Memory, Disk, and PnP device information. Focused on WMI/Cim hardware queries.

#### 2. NetworkCollector.ps1
- Collects Adapters, IP Config, Routing, and DNS. Utilizes native PowerShell networking cmdlets.

#### 3. OSCollector.ps1
- Collects OS settings, Power Plans, Time Sync, PageFile, features, and Language Pack/Locale details.

#### 4. ServiceCollector.ps1
- Analyzes services, drivers, processes, and DTC. Provides a snapshot of the execution environment.

#### 5. PerformanceCollector.ps1
- Collects real-time metrics for CPU, memory, disk, and network.
- **Advanced Diagnostics**: Includes Kernel Pool memory and handle leak diagnostic logic.

#### 6. LogCollector.ps1
- Collects System/Application/Security Event Logs (last 7 days).
- Includes Windows Update logs (`Pending.xml`, `dism.log`, `CBS.log`).

#### 7. SecurityCollector.ps1
- Firewall rules, AV status, local security policies, and accounts. Supports auditing and compliance.

#### 8. HACollector.ps1
- Cluster, NIC Teaming, MCCS, and SAN. Analyzes enterprise High Availability environments.

#### 9. ADCollector.ps1
- Domain, Forest, Domain Controllers, and Trusts. Object counts (User/Group/Comp/OU) and status summaries.

#### 10. VirtualizationCollector.ps1
- Hyper-V Host, VMs, and Virtual Switches.
- Windows Containers (Docker/Native) and WSL (distributions/kernel) status.
- Installation status of virtualization features.

#### 11. InventoryCollector.ps1
- Installed software (64/32-bit registry search) and Appx Packages.

### 📋 Usage Examples
The interface remains consistent after refactoring:
```powershell
# Automatically loads all modules
. "$PSScriptRoot\lib\Collectors.ps1"

# Use individual collectors
$hw = Get-HardwareInfo
$net = Get-NetworkInfo
```

### 🛠️ Quality & Scalability
1. **Module Independence**: No dependencies between collector modules.
2. **Error Isolation**: Detailed logging and stack traces in Debug Mode.
3. **Flexible Parameters**: `-Modules` and `-OutputPath` allow environment-specific runs.
4. **Optimized Archive**: Results are zipped with optimal compression.
5. **Selective Loading**: Only required modules are loaded into memory.

---

## 8️⃣ Parallel Collection Mode
- **Tech Stack**: PowerShell 5.1 compatible `RunspacePool` multi-threading.
- **Mechanism**: Modules run simultaneously in isolated runspaces.
- **Performance**: Drastically reduces total collection time (up to 5x improvement depending on environment).

---

## 📌 Implementation Recommendations
1. **Unit Testing** – Test each collector module independently.
2. **Integration Testing** – Validate the end-to-end workflow after modularization.
3. **Benchmarks** – Quantitative comparison of Parallel vs. Sequential modes.
4. **Documentation** – Enhancement of Comment-Based Help for each function.
5. **CI/CD Pipeline** – Establish automated testing and deployment processes.
