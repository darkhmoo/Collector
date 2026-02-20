# EC-074 Implementation Log (2026-02-20)

Target issue: `#4 [P0] EC-074 EndInvoke exception visibility`

## 1) Test implementation plan
- Validate that runspace failure is stored as a structured result object.
- Validate that one failed task does not break other task results.
- Validate that main script contains runspace exception summary logic.

## 2) Tests added and baseline
- Added tests:
  - `EndInvokeExceptionStructuredResultTest`
  - `EndInvokeExceptionIsolationTest`
  - `MainScriptRunspaceExceptionSummaryContractTest`
- Baseline before code changes:
  - Structured result test: failed (missing metadata fields)
  - Isolation test: failed (failed task not marked as `RunspaceError`)
  - Summary contract test: failed (missing summary logic)

## 3) Code implementation plan
- Add per-task validation for invalid task block input.
- Wrap `EndInvoke` with per-task `try/catch` and convert failures into structured metadata.
- Preserve timeout handling and normal completion behavior.
- Add runspace exception summary counter in main script.

## 4) Code implemented
- `lib/Common.ps1`
  - Added structured runspace error object fields:
    - `Status`, `TimedOut`, `ElapsedMs`, `ModuleName`, `ErrorMessage`, `ErrorType`, `StackTrace`
  - Added task block type validation (`ScriptBlock` required).
  - Added per-task `EndInvoke` exception capture and conversion.
  - Added stream-error fallback conversion when no structured payload is returned.
  - Kept per-task isolation and timeout path intact.
- `system_information_collector_for_windows.ps1`
  - Added runspace exception count calculation based on `Status -eq "RunspaceError"`.
  - Added summary log: `[Summary] Runspace exceptions: N`.

## 5) Verification
- Post-change targeted tests:
  - PASS `EndInvoke Exception Structured Result`
  - PASS `EndInvoke Exception Isolation`
  - PASS `Main Script Runspace Exception Summary Contract`
- Security signing check:
  - Re-signed changed scripts:
    - `lib/Common.ps1`
    - `system_information_collector_for_windows.ps1`
    - `tests/lib/EdgeCaseTests.ps1`
    - `tests/Comprehensive.Tests.ps1`
  - Signature validation:
    - `TOTAL_PS1=29`
    - `INVALID_COUNT=0`
