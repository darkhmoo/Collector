# Documentation Refactoring Plan

## Goal Description
The current project root is cluttered with multiple fragmented Markdown files describing past refactorings (from Dec 2025) and update logs. The goal is to:
1.  **Centralize** project documentation into a `docs/` directory.
2.  **Create a `README.md`** as the main entry point (currently missing).
3.  **Consolidate** historical logs into a single `HISTORY.md` file in Korean.
4.  **Cleanup** the root directory by removing obsolete files.

## User Review Required
> [!IMPORTANT]
> **File Deletion**: This plan involves **deleting** the following files after consolidating their content into `HISTORY.md`:
> - `REFACTORING_SUMMARY.md`
> - `REFACTORING_SRP.md`
> - `REFACTORING_EVENT_LOGS.md`
> - `SECURITY_PERFORMANCE_REVIEW.md`
> - `IMPROVEMENTS_APPLIED.md`
> - `UPDATE_LOG_2026-02-13.md`

## Proposed Changes

### Structural Changes
```text
Project Root
├── README.md (NEW)
├── docs/ (NEW Directory)
│   ├── USAGE_GUIDE.md (Moved)
│   ├── DEBUG_PERFORMANCE_GUIDE.md (Moved)
│   ├── ANALYSIS.md (Renamed from system_information_collector_for_windows_analysis.md)
│   └── HISTORY.md (NEW - Consolidated logs)
└── (Obsolete .md files removed)
```

### [Root]
#### [NEW] [README.md](file:///c:/Users/darkh/OneDrive/%EB%AC%B8%EC%84%9C/code/Collector/README.md)
-   Project Title & Description
-   Key Features (Summary)
-   Quick Start (One-liner)
-   Links to `docs/USAGE_GUIDE.md` and `docs/DEBUG_PERFORMANCE_GUIDE.md`
-   Written in **Korean**.

### [docs/ Directory]
#### [NEW] [HISTORY.md](file:///c:/Users/darkh/OneDrive/%EB%AC%B8%EC%84%9C/code/Collector/docs/HISTORY.md)
-   Aggregates content from `UPDATE_LOG_2026-02-13.md` (Translated to Korean).
-   Aggregates historical context from `REFACTORING_*.md` files (Dec 2025).

#### [MOVE] Guides
-   `USAGE_GUIDE.md` -> `docs/USAGE_GUIDE.md`
-   `DEBUG_PERFORMANCE_GUIDE.md` -> `docs/DEBUG_PERFORMANCE_GUIDE.md`
-   `system_information_collector_for_windows_analysis.md` -> `docs/ANALYSIS.md`

### [Cleanup]
#### [DELETE] Obsolete and fragmented files
-   `REFACTORING_SUMMARY.md`
-   `REFACTORING_SRP.md`
-   `REFACTORING_EVENT_LOGS.md`
-   `SECURITY_PERFORMANCE_REVIEW.md`
-   `IMPROVEMENTS_APPLIED.md`
-   `UPDATE_LOG_2026-02-13.md`

## Verification Plan

### Manual Verification
1.  Verify `README.md` exists and correctly links to files in `docs/`.
2.  Verify `docs/HISTORY.md` contains the consolidated information in Korean.
3.  Verify the root directory is clean of the listed obsolete markdown files.
