# 📄 시스템 정보 수집 스크립트 분석

## 1️⃣ 스크립트 개요
| 항목 | 내용 |
|------|------|
| **기능** | 데이터 수집(Hardware, Network, OS, Service, Perf, Logs, Security, AD, HA, Virtualization, Inventory 등), 보고서 생성(JSON/HTML/CSV), 압축 및 암호화 |
| **PowerShell 버전** | `#Requires -Version 5.1` (PowerShell 5.1 이상 권장) |
| **파라미터** | - `-OutputFormat` : `JSON`, `HTML`, `CSV`, `ALL` <br> - `-Compress` : ZIP 압축 <br> - `-Encrypt` : AES-256 암호화 <br> - `-Parallel` : 병렬 수집 <br> - `-DebugMode` : 상세 로깅 |
| **핵심 워크플로우** | 1️⃣ 초기화 → 2️⃣ 클래스/라이브러리 로드 → 3️⃣ 사전 검증 → 4️⃣ 플러그인 동적 로드(서명 검증) → 5️⃣ 데이터 수집 → 6️⃣ 포맷 변환 및 보안 처리 → 7️⃣ 정리 |
| **주요 모듈** | `lib\Classes.ps1`, `lib\Common.ps1`, `lib\Collectors.ps1`, `lib\Reporters.ps1` |

---

## 2️⃣ 상세 흐름
| 단계 | 설명 | 주요 코드 |
|------|------|-----------|
| **① 초기화** | 스크립트 실행 시간 측정(`Stopwatch`) 및 디버그 로그 파일 경로 설정 | ` $scriptStopwatch = [System.Diagnostics.Stopwatch]::StartNew()`<br>`if ($DebugMode){ $DebugLogFile = Join-Path … }` |
| **② 라이브러리 로드** | `Classes.ps1` (BaseCollector 정의), `Common.ps1`, `Collectors.ps1`, `Reporters.ps1` 를 순서대로 로드. | ` . "$PSScriptRoot\lib\Classes.ps1"` 등 |
| **③ 사전 체크** | - 관리자 권한 확인 (`Assert-AdminPrivileges`) <br> - 필수 전제조건 확인 (`Assert-Prerequisites`) <br> - 스크립트 동시 실행 방지를 위한 Mutex 획득 (`Get-ScriptMutex`) | `Assert-AdminPrivileges` <br> `Assert-Prerequisites` |
| **④ 플러그인 로드** | `lib\collectors\` 내의 `.ps1` 파일을 스캔하여 **Authenticode 디지털 서명** 검증 후 안전하게 로드. | `Get-AuthenticodeSignature` 활용 |
| **⑤ 데이터 수집** | 클래스 기반의 `Collect()` 메서드를 호출하여 11개의 카테고리별 정보를 수집. | `$collector.Collect()` |
| **⑤ 실행 시간 기록** | `Stopwatch` 정지 → 실행 시간 문자열 저장 → `$auditReport.ExecutionTime` 에 할당 | `$scriptStopwatch.Stop()` |
| **⑥ 출력 생성** | - **데이터 변환**: JSON/HTML/CSV 포맷으로 리포트 생성 <br> - **암호화(`-Encrypt`)**: 각 리포트 파일을 AES-256으로 암호화 (.aes) <br> - **압축(`-Compress`)**: 생성된(또는 암호화된) 파일들을 ZIP으로 아카이브 | `Save-Results` 함수 내부 로직 |
| **⑦ 정리** | 암호화 성공 시 평문 원본 삭제, 디버그 모드가 아니면 중간 파일 삭제 고도화 | `if (-not $DebugMode){ ... }` |
| **⑧ Mutex 해제** | `ReleaseMutex()` 후 `Dispose()` | `if ($mutex){ $mutex.ReleaseMutex(); $mutex.Dispose() }` |
| **⑨ 반환** | 최종 `$auditReport` 객체를 반환 (스크립트 호출자가 파이프라인에서 활용 가능) | `return $auditReport` |

---

## 3️⃣ 핵심 함수·모듈 (외부 파일)
| 파일 | 역할 | 주요 함수 (예시) |
|------|------|-----------------|
| `Common.ps1` | 로깅, 에러 처리, 유틸리티 | `Write-Log`, `Assert-AdminPrivileges`, `Get-ScriptMutex`, `Get-CimSafe`, `Invoke-Collection` |
| `Collectors.ps1` | 컬렉터 모듈 로더 | 모든 개별 컬렉터 모듈을 로드하고 통합 인터페이스 제공 |
| `Reporters.ps1` | 보고서 생성·포맷 변환 | `ConvertTo-HtmlReport`, `Get-HtmlTable`, `Get-HtmlTemplate` |

### 📁 컬렉터 모듈 (lib/collectors/)
단일 책임 원칙(SRP)에 따라 기능별로 분리된 컬렉터 모듈:

| 파일명 | 책임 범위 | 주요 기능 및 대상 |
|------|------|-----------|
| `HardwareCollector.ps1` | 하드웨어 구성 | BIOS, CPU, 메모리, 물리 디스크, PnP 장치 상태 |
| `NetworkCollector.ps1` | 네트워크 토폴로지 | 어댑터 구성, IP 설정, 라우팅 테이블, DNS 캐시 및 서버 |
| `OSCollector.ps1` | 시스템 운영 환경 | OS 세부 정보, 전원 관리 정책, 시간 동기화 설정, 언어팩 |
| `ServiceCollector.ps1` | 실행 자원 및 태스크 | 서비스 엔진, 커널 드라이버, 활성 프로세스, 스케줄된 작업 |
| `PerformanceCollector.ps1` | 실시간 메트릭 분석 | CPU/Memory 부하 측정, 커널 메모리 풀 및 핸들 누수 진단 |
| `LogCollector.ps1` | 감사 기록 수집 | 주요 이벤트 로그(최근 7일), Windows Update 및 DISM 이력 |
| `SecurityCollector.ps1` | 보안 정책 및 감사 | 방화벽 구성, 백신 상태, 보안 정책(SecEdit), 로컬 계정(DLP) |
| `HACollector.ps1` | 고가용성 서비스 | 장애 조치 클러스터(Failover Cluster), NIC 티밍, MCCS |
| `ADCollector.ps1` | 디렉터리 엔터프라이즈 | 도메인/포레스트 트러스트, DC 상태, 계정 객체 요약 |
| `VirtualizationCollector.ps1`| 가상화 엔진 | Hyper-V 호스트, VM 상태, Windows 컨테이너 및 WSL |
| `InventoryCollector.ps1` | 소프트웨어 자산 | 설치된 소프트웨어(64/32비트), Appx 패키지 인벤토리 |

> **차세대 아키텍처 (Class-based Model)**: 모든 수집 모듈은 `BaseCollector` 클래스를 상속받습니다. 이를 통해 상속을 통한 수집 인터페이스 표준화(`Collect()`), 수립된 로깅 체계(`LogStart/LogEnd`), 그리고 런타임 시의 일관된 에러 처리 메커니즘을 제공합니다.

---

## 4️⃣ 코드 품질·보완 포인트
| 영역 | 현황 | 개선 제안 |
|------|------|-----------|
| **파라미터 검증** | `ValidateSet` 으로 `OutputFormat` 제한 | `ValidatePattern` 등을 이용해 파일명에 사용할 수 없는 문자 검증 추가 |
| **에러 핸들링** | `try/catch` 로 전체 출력 단계 감싸고 있음 | 개별 `Invoke-Collection` 내부에서도 세부 `try/catch` 로 실패 시 해당 카테고리만 스킵하고 로그 남기기 |
| **디버그 로깅** | `$DebugLogFile` 경로 지정 후 `Write-Log` 로 기록 | 현재 `Write-Log`가 파일에 자동 기록되는지 확인 필요 (`Common.ps1` 구현에 따라). 파일 핸들링이 누락되면 로그가 사라질 수 있음 |
| **성능** | `Compress-Archive` 에 `-Force` 사용 → 기존 파일 덮어쓰기 | 대용량 파일(예: 로그) 압축 시 `-CompressionLevel Optimal` 지정해 압축 효율 향상 |
| **메모리 및 자원** | 런스페이스 종료 시 GC 호출 | `.NET` 스트림 객체 및 CIM 핸들에 대해 **명시적 `Dispose()` 및 `try-finally`** 적용으로 누수 방지 |
| **보안 하드닝** | 평문 데이터 노출 위험 | **범용 마스킹 엔진(`Get-MaskedValue`)** 도입으로 전 수집 구간 내 민감 정보 은닉화 |
| **디지털 서명** | 스크립트 위변조 가능성 | **Authenticode 서명 검증**을 필수로 적용하여 신뢰할 수 있는 플러그인만 로드 |

---

## 5️⃣ 보안·운영 측면
| 체크포인트 | 내용 |
|------------|------|
| **관리자 권한** | `Assert-AdminPrivileges` 로 사전 검증 (필수) |
| **스크립트 실행 정책** | `#Requires -Version 5.1` 외에 `Set-ExecutionPolicy` 가 필요할 수 있음 (예: `RemoteSigned`) |
| **파일 삭제** | `-Force` 삭제 시 암호화된 경우 원본 평문을 즉시 파기하여 잔류 데이터 최소화 |
| **데이터 암호화** | **AES-256** 표준 및 **SecureString** 키 입력을 통해 결과물 물리적 보호 기능 제공 |

---

## 6️⃣ 요약
- **전체 흐름**: 초기화 → 라이브러리 로드 → 사전 체크 → 11가지 카테고리 수집 → JSON/HTML 출력 → ZIP 압축 → 정리.
- **핵심 모듈**: `Common.ps1`(공통 로직), `Collectors.ps1`(모듈 로더), `Reporters.ps1`(보고서), 11개 전문 컬렉터 모듈.
- **디버그 모드**: 로그 파일 자동 생성, 정리 단계 스킵.
- **출력 옵션**: `JSON`, `HTML`, `Both` 지원, 결과를 ZIP으로 묶어 배포.
- **보완점**: 파라미터 검증 강화, 개별 오류 로깅, 성능 최적화, 사용자 지정 출력 경로, 보안(압축 암호화) 등.

---

## 7️⃣ 리팩토링: 모듈화 및 단일 책임 원칙 적용

### 🎯 설계 철학 및 클린 코드 준수
본 프로젝트는 **PowerShell Clean Code Guide**를 근간으로 하며, 다음 핵심 원칙을 설계에 반영하였습니다.

1.  **단일 책임 원칙 (SRP)**:
    - 수집기(`collectors/`), 리포터(`reporters/`), 라이브러리(`Common.ps1`), 출력 제어(`OutputManager.ps1`)를 물리적으로 분리하여 결합도를 낮추었습니다.
2.  **부작용 격리 (Side-effect Isolation)**:
    - 파일 쓰기, 폴더 생성, 압축 등 시스템 상태를 변화시키는 모든 동작은 `SupportsShouldProcess` 가드를 통해 격리됩니다. 이는 사용자가 `-WhatIf`를 통해 안전하게 결과를 예측할 수 있게 합니다.
3.  **명확한 네이밍 및 의도 중심 기술**:
    - 모든 함수는 `Verb-Noun` 형식을 따르며, 내부 변수는 `camelCase`를 적용하여 가독성을 확보했습니다.
4.  **Fail Fast 및 방어적 설계**:
    - 입력값 유효성 검사 매개변수를 통해 잘못된 입력이 시스템 전체로 확산되는 것을 차단하고, 특정 모듈 오류가 전체 수집 중단으로 이어지지 않도록 예외를 격리합니다.

### 📦 모듈 분리 및 책임 상세

### 🔧 모듈 분리 상세

#### 1. **HardwareCollector.ps1** (하드웨어)
- BIOS, CPU, 메모리, 디스크, PnP 장치 정보 수집
- WMI/CIM 기반 하드웨어 쿼리에 집중

#### 2. **NetworkCollector.ps1** (네트워크)
- 네트워크 어댑터, IP 구성, 라우팅, DNS 정보 수집
- PowerShell 네트워크 cmdlet 활용

#### 3. **OSCollector.ps1** (운영체제)
- OS 설정, 전원 계획, 시간 동기화, 페이지 파일, 기능 정보 수집
- 레지스트리 및 시스템 설정 쿼리

#### 4. **ServiceCollector.ps1** (서비스/드라이버)
- 서비스, 드라이버, 프로세스, DTC 정보 수집
- 시스템 실행 환경 분석

#### 5. **PerformanceCollector.ps1** (성능)
- CPU, 메모리, 디스크, 네트워크 성능 메트릭 수집
- **누수 진단 (고도화)**: 커널 풀 메모리 및 핸들 누수 진단
- 실시간 성능 카운터 쿼리

#### 6. **LogCollector.ps1** (로그)
- 이벤트 로그, Windows Update 로그 수집
- `Pending.xml`, `dism.log`, `CBS.log` 포함

#### 7. **SecurityCollector.ps1** (보안)
- 방화벽, 백신, 로컬 정책, 계정 정보 수집
- 보안 감사 및 컴플라이언스 지원

#### 8. **HACollector.ps1** (고가용성)
- 클러스터, NIC 티밍, MCCS, SAN 정보 수집
- 엔터프라이즈 HA 환경 분석

#### 9. **ADCollector.ps1** (Active Directory)
- 도메인, 포레스트, 도메인 컨트롤러, 트러스트 관계 수집
- 사용자/그룹/컴퓨터/OU 객체 수 샘플링 및 상태 요약

#### 10. **VirtualizationCollector.ps1** (가상화)
- Hyper-V 호스트, VM, 스위치 정보 수집
- Windows Container (Docker, Native) 런타임 상태 확인
- WSL (Windows Subsystem for Linux) 배포판 목록 및 커널 상태 수집
- 가상화 관련 Windows 기능(Hyper-V, Containers, WSL, 가상 기계 플랫폼) 설치 상태 확인

### 📋 사용 방법
리팩토링 후에도 기존 인터페이스는 동일하게 유지됩니다:

```powershell
# 메인 스크립트에서 자동으로 모든 모듈 로드
. "$PSScriptRoot\lib\Collectors.ps1"

# 개별 컬렉터 사용
$hwInfo = Get-HardwareInfo
$netInfo = Get-NetworkInfo
```

### 🛠️ 코드 품질 및 확장성 포인트
1. **모듈 독립성**: 각 컬렉터는 서로 의존성 없이 독립적으로 실행 가능합니다.
2. **에러 격리 및 상세 로깅**: 특정 모듈 오류 시 프로세스 중단을 방지하고, 디버그 모드에서 스택 트레이스를 제공합니다.
3. **유연한 파라미터 설계**: `-Modules`, `-OutputPath` 등을 통해 환경에 최적화된 수집이 가능합니다.
4. **최적화된 아카이브**: 데이터 수집 후 최적 압축률로 ZIP 파일을 생성하여 저장 공간을 절약합니다.
5. **선택적 로드**: 필요한 컬렉터만 로드하여 성능 최적화 가능
6. **문서화 용이**: 각 모듈의 역할이 명확하여 문서 작성 간편

---

### ✅ 리팩토링 이점
1. **명확한 책임 분리**: 각 파일이 하나의 도메인만 담당
2. **독립적 테스트**: 각 모듈을 개별적으로 테스트 가능
3. **병렬 개발**: 여러 개발자가 동시에 다른 모듈 작업 가능

---

## 8️⃣ Windows Update 로그 추가

- `Get-WindowsUpdateInfo` 함수가 추가되어 `Pending.xml`, `dism.log`, `CBS.log` 파일을 읽어 반환합니다.
- `Get-LogInfo`에 `WindowsUpdate` 속성이 포함되어 보고서에 포함됩니다.

---

## 9️⃣ 병렬 수집 모드 (Parallel Collection)

- **기술 스택**: PowerShell 5.1 호환 `RunspacePool` 기반 멀티스레딩.
- **작동 방식**: `-Parallel` 스위치 활성화 시, 각 수집 모듈이 별도의 런스페이스(Runspace)에서 독립적으로 실행됩니다.
- **장점**: 다수의 모듈 수집 시 전체 소요 시간을 획기적으로 단축 (최대 5배 이상 개선 가능).

---

## 📌 다음 단계 제안
1. **모듈별 단위 테스트** – 각 컬렉터 모듈을 독립적으로 테스트하여 정상 동작 확인
2. **통합 테스트** – 전체 시스템이 모듈화 후에도 정상 작동하는지 검증
3. **성능 벤치마크** – 리팩토링 전/후 성능 비교 (실행 시간, 메모리 사용량)
4. **문서화 강화** – 각 모듈에 `Get-Help` 용 상세 주석 추가
5. **CI/CD 파이프라인** – 자동화된 테스트 및 배포 프로세스 구축

궁금하신 부분이나 추가 개선 사항이 있으면 알려 주세요! 🚀
