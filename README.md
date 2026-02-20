# System Information Collector for Windows

> [!NOTE]
> **Language / 언어 선택**
> 
> | Document | 🇰🇷 Korean (ko-KR) | 🇺🇸 English (en-US) |
> | :--- | :--- | :--- |
> | **Usage Guide** | [사용 가이드](docs/ko-KR/USAGE_GUIDE.md) | [Usage Guide](docs/en-US/USAGE_GUIDE.md) |
> | **Analysis Report** | [아키텍처 분석](docs/ko-KR/ANALYSIS.md) | [Analysis Report](docs/en-US/ANALYSIS.md) |
> | **Clean Code Guide** | [클린 코드 가이드](docs/ko-KR/CLEAN_CODE_GUIDE.md) | [Clean Code Guide](docs/en-US/CLEAN_CODE_GUIDE.md) |
> | **Debug & Perf** | [성능 및 디버그](docs/ko-KR/DEBUG_PERFORMANCE_GUIDE.md) | [Debug & Performance](docs/en-US/DEBUG_PERFORMANCE_GUIDE.md) |
> | **History** | [변경 이력](docs/ko-KR/HISTORY.md) | [Project History](docs/en-US/HISTORY.md) |

---

# 🇰🇷 [KO] 한국어 안내

## 📌 프로젝트 개요
이 프로젝트는 Windows Server/Workstation 환경의 시스템 구성을 자동으로 수집하고, 운영 점검과 장애 분석에 활용할 수 있는 보고서를 생성하는 PowerShell 기반 도구입니다.

본 도구는 단순 자산 목록 수집을 넘어 다음 목적을 지원합니다.
- **운영 표준 점검**: 서버 기본 구성(OS/네트워크/보안/서비스)의 준수 여부를 확인합니다.
- **장애 원인 추적**: 로그/성능/가상화/AD 관점의 단일 스냅샷을 확보합니다.
- **변경 이력 비교**: 정기 수집 결과를 기준으로 구성 변화를 추적합니다.

## ✨ 주요 기능
- 하드웨어, 네트워크, OS, 가상화, 서비스, 성능, 로그, 보안, AD, HA 정보를 수집합니다.
- OS 구성 수집 시 Windows 언어팩/언어 설정 정보를 함께 수집합니다.
- `JSON`, `HTML`, `CSV`, `ALL` 출력 형식을 지원합니다.
- 이벤트 로그를 별도 산출물(`HTML` 또는 `CSV`)로 생성합니다.
- **병렬 수집(Parallel Collection)** 모드를 지원하여 대규모 환경에서 수집 속도를 극대화합니다.
- **플러그인 보안(Plugin Security)**: 모든 수집 모듈에 대한 디지털 서명 검증 후 로드하여 스크립트 주입을 차단합니다.
- **데이터 마스킹(Data Masking)**: 비밀번호, 키, 토큰 등 민감 정보를 범용 엔진으로 자동 식별하여 보안 마스킹 처리합니다.
- 디버그 모드에서 단계별 시간/메모리 변화를 추적합니다.
- 결과 파일을 AES-256 알고리즘(10만 회 PBKDF2)으로 암호화(`-Encrypt`)하여 기밀성을 확보합니다.
- 결과 파일을 선택적으로 ZIP으로 압축(`-Compress`)하고 중간 파일을 정리합니다.

## 🧩 수집 카테고리 (11개 모듈)
1. **하드웨어 (Hardware)**: BIOS, CPU, 메모리, 디스크 정보
2. **네트워크 (Network)**: 어댑터 구성, 라우팅 테이블, DNS 설정
3. **운영체제 설정 (OSConfig)**: 전원 계획, 시간 동기화, 페이지 파일, 기능 목록
4. **가상화 (Virtualization)**: Hyper-V, Windows 컨테이너, WSL 상태
5. **서비스 (Services)**: 실행 중인 서비스, 드라이버, 프로세스, 주요 태스크
6. **성능 (Performance)**: CPU/메모리/디스크/네트워크 성능 및 커널 누수 진단
7. **로그 (Logs)**: 이벤트 로그(7일), Windows Update 및 DISM 로그
8. **보안 (Security)**: 방화벽, 백신, 보안 정책, 로컬 계정 보안 감사
9. **인벤토리 (Inventory)**: 설치된 소프트웨어(64/32비트), Appx 패키지 목록
10. **액티브 디렉터리 (Active Directory)**: 도메인/포레스트 구성, 트러스트, 객체 요약
11. **고가용성 (High Availability)**: 클러스터 구성, NIC 티밍, MCCS 상태

## 🛠️ 실행 환경
- **OS**: Windows Server 2016 이상 또는 Windows 10/11
- **PowerShell**: 5.1 이상
- **권한**: 관리자 권한(Administrator) 권장
- **선택 모듈**:
  - AD 수집: `ActiveDirectory` 모듈 (RSAT)
  - 가상화 수집: `Hyper-V` PowerShell 모듈

## 🚀 빠른 실행
```powershell
# 기본 실행(HTML 보고서 생성)
.\system_information_collector_for_windows.ps1

# 모든 형식 출력 (JSON, HTML, CSV)
.\system_information_collector_for_windows.ps1 -OutputFormat ALL

# 병렬 수집 및 암호화 실행 (보안/속도 동시 확보)
.\system_information_collector_for_windows.ps1 -Parallel -Encrypt -Compress
```

## 🛠️ 기술 표준 및 설계 원칙
- **PowerShell Clean Code**: 네이밍, 함수 설계, 부작용 격리 규칙을 따릅니다 (참조: [CLEAN_CODE_GUIDE.md](docs/ko-KR/CLEAN_CODE_GUIDE.md)).
- **서명 운영 정책(Authenticode)**: 기본은 변경된 `.ps1` 파일만 재서명하고, 인증서 교체/갱신·대규모 개행/인코딩 변경·릴리스 직전에는 전체 일괄 재서명을 수행합니다.
- **서명 누락 차단(필수)**: `utils/Verify-Signatures.ps1`를 커밋 전/CI에서 실행해 `Valid`가 아닌 `.ps1`을 차단합니다. 로컬 훅 사용 시 `git config core.hooksPath .githooks`를 1회 설정합니다.
- **이슈 구현 절차(필수)**: `1) 테스트 구현 계획 작성 -> 2) 테스트 작성 -> 3) 코드 구현 계획 작성 -> 4) 코드 구현 -> 5) 보안 서명 점검` 순서를 준수합니다.
- **이슈 완료 처리(필수)**: GitHub 이슈 기반 작업은 코드 구현/검증 완료 후 즉시 해당 이슈를 `Closed` 처리합니다.
- **방어적 프로그래밍**: 일부 모듈이나 Cmdlet이 없는 환경에서도 수집이 중단되지 않도록 설계되었습니다.

## ⚠️ 운영 시 주의사항
- **AD/Hyper-V/Container**: 해당 서버 역할 및 관리 도구가 설치된 환경에서만 데이터가 수집되며, 그 외에는 비어 있을 수 있습니다.
- **이벤트 로그 및 AD 요약**: 대규모 환경에서는 쿼리 시간이 길어질 수 있습니다. `-DebugMode`를 사용하여 병목 지점을 확인하는 것을 권장합니다.

---

# 🇺🇸 [EN] English Information

## 📌 Project Overview
This project is a PowerShell-based tool that automatically collects system configurations in Windows Server/Workstation environments and generates reports for operational checks and failure analysis.

Beyond simple asset inventory, this tool supports:
- **Operational Standard Audit**: Verify compliance of core server configurations (OS/Network/Security/Services).
- **Incident Tracking**: Capture a single snapshot from Log/Performance/Virtualization/AD perspectives.
- **Change History Comparison**: Track configuration changes based on regular collection results.

## ✨ Key Features
- Collects Hardware, Network, OS, Virtualization, Services, Performance, Logs, Security, AD, and HA info.
- Gathers Windows Language Pack and Locale settings during OS configuration collection.
- Supports `JSON`, `HTML`, `CSV`, and `ALL` output formats.
- Generates Event Logs as separate outputs (`HTML` or `CSV`).
- **Parallel Collection** mode using `RunspacePool` for maximum speed in large environments.
- **Plugin Security**: Loads collection modules only after Authenticode digital signature verification to prevent script injection.
- **Universal Data Masking**: Automatically identifies and masks sensitive data (passwords, keys, tokens) using a centralized engine.
- Tracks step-by-step time and memory changes in Debug Mode.
- Secures results using **AES-256** encryption (100,000 PBKDF2 iterations) for confidentiality.
- Optionally compresses results into a ZIP archive (`-Compress`) and cleans up intermediate files.

## 🧩 Collection Categories (11 Modules)
1. **Hardware**: BIOS, CPU, Memory, Disk information.
2. **Network**: Adapter configuration, Routing table, DNS settings.
3. **OSConfig**: Power plans, Time synchronization, Page file, Feature list.
4. **Virtualization**: Hyper-V, Windows Containers, WSL status.
5. **Services**: Running services, Drivers, Processes, Scheduled tasks.
6. **Performance**: CPU/Memory/Disk/Network performance and Kernel leak diagnostics.
7. **Logs**: Event logs (Last 7 days), Windows Update and DISM logs.
8. **Security**: Firewall, Antivirus, Security policies, Local account audit.
9. **Inventory**: Installed software (64/32-bit), Appx package list.
10. **Active Directory**: Domain/Forest configuration, Trusts, Object summary.
11. **High Availability**: Cluster configuration, NIC Teaming, MCCS status.

## 🛠️ System Requirements
- **OS**: Windows Server 2016 or higher, or Windows 10/11.
- **PowerShell**: 5.1 or higher.
- **Privileges**: Administrator privileges recommended.
- **Optional Modules**:
  - AD Collection: `ActiveDirectory` module (RSAT).
  - Virtualization Collection: `Hyper-V` PowerShell module.

## 🚀 Quick Start
```powershell
# Basic Execution (Generates HTML report)
.\system_information_collector_for_windows.ps1

# Output in all formats (JSON, HTML, CSV)
.\system_information_collector_for_windows.ps1 -OutputFormat ALL

# Run in Parallel mode with Encryption (High speed & Security)
.\system_information_collector_for_windows.ps1 -Parallel -Encrypt -Compress
```

## 🛠️ Technical Standards & Design Principles
- **Class-based Provider Model**: Ensures consistency across modules via an object-oriented structure inheriting from `BaseCollector`.
- **Dynamic Plugin Engine**: Dynamically recognizes `.ps1` files in `lib/collectors/` and securely loads them after Authenticode verification.
- **Signing Policy (Authenticode)**: Re-sign only changed `.ps1` files by default; run full bulk re-signing only for certificate rotation/renewal, large line-ending or encoding changes, and pre-release integrity sweeps.
- **Issue Implementation Workflow (Mandatory)**: Follow `1) test planning -> 2) test authoring -> 3) implementation planning -> 4) code implementation -> 5) security signing check` in this order.
- **Issue Closure Policy (Mandatory)**: For GitHub issue-driven work, close the issue immediately after code implementation and verification are completed.
- **PowerShell Clean Code**: Adheres to naming, design, and isolation rules (See [CLEAN_CODE_GUIDE.md](docs/en-US/CLEAN_CODE_GUIDE.md)).
- **Defensive Programming**: Designed to ensure uninterrupted collection even in environments where certain modules or cmdlets are missing.

## ⚠️ Operational Cautions
- **AD/Hyper-V/Container**: Data is only collected where the respective roles and management tools are installed; otherwise, fields may remain empty.
- **Event Logs & AD Summary**: Query times may increase in large environments. It is recommended to use `-DebugMode` to identify potential bottlenecks.
