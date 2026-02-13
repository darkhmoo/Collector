# PowerShell Clean Code Rules (Practical Protocol)

## 1) Naming Conventions

### Functions
- **Verb-Noun** Mandatory: `Get-Thing`, `Set-Thing`, `Invoke-Thing`.
- Use **Approved Verbs only** (Check via `Get-Verb`).
- **Intent-revealing Noun**: Avoid `Invoke-DoStuff` → Use `Invoke-CollectHardwareInfo`.

### Variables
- **camelCase** recommended: `$serverName`, `$timeoutSeconds`.
- **Boolean Prefixes**: `$isEnabled`, `$hasAdminPrivileges`, `$shouldSaveResults`.

### Constants/Configuration
- **No Hardcoding**: URLs, paths, and timeouts should be defined as constants at the top or passed as parameters.

---

---

## 2) Object-Oriented Design & Class Patterns (OOP) ✅ Modern Standards

* **`BaseCollector` Inheritance Mandatory**: All collection modules must inherit from the `BaseCollector` class for an object-oriented structure.
* **Standard Interface Compliance**:
  - `Collect()`: The primary method containing the actual collection logic (Must be overridden in each child module).
  - `LogStart() / LogEnd()`: Utilize the consistent logging interface to signal the start and end of collection.
* **Constructor Utilization**: Perform initial value settings, mandatory module loading, or common object initialization in the constructor (`new()`).
* **De-duplication (DRY)**: Define common logic—such as performance measurement, logging formats, and error handling—in the `BaseCollector` class to minimize redundant code.

---

## 3) Function Design Rules
- **One function, one job** (Single Responsibility Principle - SRP).
- **If more than 3 parameters**: Consider using an `-Options` (hashtable) or an object (`PSCustomObject`).
- **Output Objects**: Avoid excessive string outputs.
  - User messages: Use `Write-Information`, `Write-Verbose`, or `Write-Warning`.
  - Pipeline data: Use `Write-Output` or simply return the value.

---

## 3) CmdletBinding / Parameter Rules
- Use **Advanced Functions** by default:
  - `[CmdletBinding(SupportsShouldProcess=$true)]`
  - Use `[Parameter(Mandatory=...)]` and `[ValidateNotNullOrEmpty()]`.
- Supporting **-WhatIf / -Confirm** for risky operations (file deletion, registry edits, etc.):
  - Guard with `ShouldProcess()`.

---

## 4) Side-effect Isolation Rules ✅ CORE
- **No auto-execution on module import/load.**
- External impacts (opening browser, network calls, file writing) must be:
  - Isolated within `Invoke-*` functions.
  - Optionally provide a `-PassThru` parameter (returning "what to do" as an object instead of executing it).

---

## 5) Error Handling Rules
- **Catch exceptions only when you have a reason to handle them.**
- Consistent failure handling:
  - Use `throw` or `Write-Error -ErrorAction Stop`.
- Provide necessary information to the user:
  - "What failed + Next steps."
- In `try/catch/finally`, prioritize **specific exceptions** in `catch` blocks.

---

## 6) Logging/Output Rules
- `Write-Host` is a last resort (unfriendly for automation/testing).
- Standard Streams:
  - Debug: `Write-Debug`
  - Verbose: `Write-Verbose`
  - Information: `Write-Information`
  - Warning: `Write-Warning`
  - Error: `Write-Error`

---

## 7) Module/Structure Rules

### Recommended Structure (Modular)
- `Collector.psd1` (Manifest)
- `Collector.psm1` (Module Entry Point: exports only)
- `Public\*.ps1` (Exported functions)
- `Private\*.ps1` (Internal utilities/helpers)
- `Tests\*.Tests.ps1` (Pester tests)

### Rules
- `psm1` focuses on loading/exporting; logic is distributed across Public/Private.
- Export only Public functions via `Export-ModuleMember`.

---

## 8) Testing Rules (Pester)
- External calls must be **Mockable**:
  - E.g., `Start-Process`, `Invoke-WebRequest`, `Test-Path`.
- Test names should explain intent:
  - `It 'opens browser when -Open is specified' { ... }`

---

## 9) Style/Formatting Rules
- **Consistent PSStyle/Formatting.**
- Apply **PSScriptAnalyzer** rules:
  - Lint via `Invoke-ScriptAnalyzer`.
- Unified indentation/brace style:
  - `if (...) { }` / `try { } catch { }`

---

## 10) High-Volume Data Performance Rules
- **Avoid Array Append Loops**: Do not use `$arr += $item` when collecting large numbers of items (performance bottleneck).
- **Prefer Generic Lists**: Use `[System.Collections.Generic.List[PSObject]]`.
- **Pipeline Utilization**: Use pipelines (within `Process` blocks) for large data to preserve memory.

---

# "PowerShell Version Guide" for Collector

## Goals
- No automatic browser opening on import/execution.
- Only operate via explicit function calls like `Get-HardwareInfo`.
- Support `-WhatIf`.
- Decoupled for testability.

---

# Application Checklist (PowerShell)
- [ ] Functions use Verb-Noun with approved verbs.
- [ ] `CmdletBinding` + `SupportsShouldProcess` utilized.
- [ ] Side-effects (browser/network/file) isolated within `Invoke-*` functions.
- [ ] `Write-Host` minimized; logging streams used.
- [ ] Hardcoding removed (parameters/constants used).
- [ ] Passes `PSScriptAnalyzer`.
- [ ] External calls mocked in Pester tests.

---

# "Ready-to-Use" Template (Collector Style)
Key Principles:
- `Get-SystemInfo`: **Pure Function** (Data collection only).
- `Save-Results`: **Side-effect Function** (File saving/compression).
- `Save-Results` supports `-WhatIf` via `ShouldProcess()`.

---
---

# 📘 Markdown Clean Writing Rules
Goals: **Readability, Structural Clarity, Maintainability, Automation-Friendliness**.

---

## 1️⃣ Structure First

### ✅ Match Header Hierarchy to Logical Structure
- Use a single `#` for the document title.
- `##` for main sections.
- `###` for sub-sections.
- Do not skip levels (e.g., `#` followed immediately by `###`).

### ❌ Bad Example
```
# Title
### Description
## Other Section
```

### ✅ Good Example
```
# Title
## Overview
### Background
```

---

## 2️⃣ One Paragraph = One Message
- Keep paragraphs within **3 to 5 lines**.
- One core concept per paragraph.
- Avoid long, unbroken text blocks.

---

## 3️⃣ Use Lists Appropriate to Context

### Sequence matters → Numbered List
### Simple listing → Bullet List

```md
1. Install
2. Configure
3. Run
```

```md
- Pro
- Con
- Considerations
```

---

## 4️⃣ Code Block Rules

### ✅ Always specify the language
````md
```powershell
Get-Process
```
````

### ✅ Inline codes are for single concepts
E.g., `SupportsShouldProcess`

### ❌ Do not mix explanatory sentences within code blocks.

---

## 5️⃣ Readability Rules
- Keep line lengths within 100-120 characters.
- Use tables sparingly.
- Do not overuse emphasis (avoid overusing `**bold text**`).
- Limit emoji usage based on document tone.

---

## 6️⃣ Link/Reference Rules

### ✅ Descriptive Link Text
```md
[PSScriptAnalyzer Documentation](https://learn.microsoft.com/...)
```

### ❌ 
```md
Click here
```

---

## 7️⃣ Essential README Sections
Projects should include:
```md
# Project Name
## Overview
## Installation
## Usage
## Examples
## Configuration
## Testing
## Contribution
## License
```

---

## 8️⃣ Isolate Highly-Mutable Content
- Versions, paths, and URLs should be in an "Environment Info" section at the top.
- Avoid repeating hardcoded values.
- Use configuration code examples instead of large tables.

---

## 9️⃣ Single Responsibility Principle for Documents
One document, one purpose.
- Do not combine Installation + Architecture + Troubleshooting in a single file.
- Split them into `INSTALL.md`, `ARCHITECTURE.md`, `TROUBLESHOOTING.md`.

---

## 🔟 Automation-Friendly Rules

### Linter Recommended
- markdownlint
- Vale (style checker)

### Verify in CI
- Header order
- Blank lines
- Code block languages

---

# 🧠 Core Principles Summary
| Principle | Description |
|-----------|-------------|
| Structure First | Header hierarchy is the design. |
| Conciseness | Short paragraphs. |
| Clarity | Remove ambiguous expressions. |
| Consistency | Unified formatting and code styles. |
| Automatable | Verify via lint/CI. |

---

# 📋 Practical Checklist
- [ ] Only one H1 title exists.
- [ ] Header hierarchy is logically ordered.
- [ ] Languages specified for all code blocks.
- [ ] One message per paragraph.
- [ ] Essential README sections included.
- [ ] Link text is descriptive.
- [ ] Passes linter.
