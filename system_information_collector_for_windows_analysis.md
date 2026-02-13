# 📄 시스템 정보 수집 스크립트 분석

## 1️⃣ 스크립트 개요
| 항목 | 내용 |
|------|------|
| **목적** | Windows Server/Workstation 환경의 하드웨어·네트워크·OS·서비스·성능·로그·보안·HA 정보를 수집하고, JSON/HTML 보고서를 생성·압축한다. |
| **지원 PowerShell 버전** | `#Requires -Version 5.1` (PowerShell 5.1 이상) |
| **파라미터** | - `-OutputFormat` : `JSON`, `HTML`, `Both` (기본값 `HTML`) <br> - `-DebugMode` : 디버그 로그 파일을 생성 |
| **주요 흐름** | 1️⃣ 초기화 → 2️⃣ 라이브러리 로드 → 3️⃣ 사전 체크 → 4️⃣ 데이터 수집 → 5️⃣ 결과 출력(파일·압축) → 6️⃣ 정리(임시 파일 삭제) |
| **외부 모듈** | `lib\Common.ps1`, `lib\Collectors.ps1`, `lib\Reporters.ps1` (각각 로깅·검증·수집·보고서 생성 함수 포함) |

---

## 2️⃣ 상세 흐름
| 단계 | 설명 | 주요 코드 |
|------|------|-----------|
| **① 초기화** | 스크립트 실행 시간 측정(`Stopwatch`) 및 디버그 로그 파일 경로 설정 | ` $scriptStopwatch = [System.Diagnostics.Stopwatch]::StartNew()`<br>`if ($DebugMode){ $DebugLogFile = Join-Path … }` |
| **② 라이브러리 로드** | `Common.ps1`, `Collectors.ps1`, `Reporters.ps1` 를 `.`(dot‑sourcing) 으로 로드. 오류 시 `Write-Error` 후 종료. | ` . "$PSScriptRoot\lib\Common.ps1"` 등 |
| **③ 사전 체크** | - 관리자 권한 확인 (`Assert-AdminPrivileges`) <br> - 필수 전제조건 확인 (`Assert-Prerequisites`) <br> - 스크립트 동시 실행 방지를 위한 Mutex 획득 (`Get-ScriptMutex`) | `Assert-AdminPrivileges` <br> `Assert-Prerequisites` |
| **④ 데이터 수집** | `Invoke-Collection` 헬퍼를 이용해 8개의 카테고리별 수집 함수를 호출하고, 결과를 `$auditReport` 객체에 저장. | `Hardware = Invoke-Collection "1/8 Hardware" { Get-HardwareInfo }` 등 |
| **⑤ 실행 시간 기록** | `Stopwatch` 정지 → 실행 시간 문자열 저장 → `$auditReport.ExecutionTime` 에 할당 | `$scriptStopwatch.Stop()` |
| **⑥ 출력 생성** | - **JSON**: `ConvertTo-Json -Depth 5` → 파일 저장 <br> - **HTML**: `ConvertTo-HtmlReport` (커스텀 함수) → 파일 저장 <br> - **압축**: `Compress-Archive` 로 생성된 파일들을 하나의 ZIP 파일에 묶음 | `if ($OutputFormat -in @("JSON","Both")) { … }` |
| **⑦ 정리** | `-DebugMode` 가 꺼져 있으면 중간 파일(`*.json`, `*.html`)을 삭제. 디버그 모드이면 파일을 보존하고 로그에 알림. | `if (-not $DebugMode){ foreach ($file in $generatedFiles){ Remove-Item $file } }` |
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

| 파일 | 책임 | 주요 함수 |
|------|------|-----------|
| `HardwareCollector.ps1` | 하드웨어 정보 수집 | `Get-HardwareInfo` - BIOS, CPU, 메모리, 디스크, PnP 장치 |
| `NetworkCollector.ps1` | 네트워크 정보 수집 | `Get-NetworkInfo` - 어댑터, 구성, 라우팅, DNS |
| `OSCollector.ps1` | OS 및 설정 정보 수집 | `Get-OSConfig` - 전원 계획, 시간 동기화, 페이지 파일, 기능 |
| `ServiceCollector.ps1` | 서비스 및 드라이버 정보 수집 | `Get-ServiceInfo` - 서비스, 드라이버, 프로세스, DTC |
| `PerformanceCollector.ps1` | 성능 메트릭 수집 | `Get-PerformanceInfo` - CPU, 메모리, 디스크, 네트워크 성능 |
| `LogCollector.ps1` | 로그 정보 수집 | `Get-LogInfo`, `Export-EventLogs`, `Get-WindowsUpdateInfo` |
| `SecurityCollector.ps1` | 보안 정보 수집 | `Get-SecurityInfo` - 방화벽, 백신, 정책, 계정 |
| `HACollector.ps1` | 고가용성 정보 수집 | `Get-HighAvailabilityInfo`, `Get-ClusterInfo`, `Get-MCCSInfo` |

> **리팩토링 원칙**: 각 컬렉터 모듈은 단일 책임을 가지며, 독립적으로 테스트 및 유지보수가 가능합니다. 메인 `Collectors.ps1`은 모든 모듈을 로드하는 로더 역할만 수행합니다.

---

## 4️⃣ 코드 품질·보완 포인트
| 영역 | 현황 | 개선 제안 |
|------|------|-----------|
| **파라미터 검증** | `ValidateSet` 으로 `OutputFormat` 제한 | `ValidatePattern` 등을 이용해 파일명에 사용할 수 없는 문자 검증 추가 |
| **에러 핸들링** | `try/catch` 로 전체 출력 단계 감싸고 있음 | 개별 `Invoke-Collection` 내부에서도 세부 `try/catch` 로 실패 시 해당 카테고리만 스킵하고 로그 남기기 |
| **디버그 로깅** | `$DebugLogFile` 경로 지정 후 `Write-Log` 로 기록 | 현재 `Write-Log`가 파일에 자동 기록되는지 확인 필요 (`Common.ps1` 구현에 따라). 파일 핸들링이 누락되면 로그가 사라질 수 있음 |
| **성능** | `Compress-Archive` 에 `-Force` 사용 → 기존 파일 덮어쓰기 | 대용량 파일(예: 로그) 압축 시 `-CompressionLevel Optimal` 지정해 압축 효율 향상 |
| **멀티스레드/동시 실행** | Mutex 사용으로 단일 인스턴스 보장 | 필요 시 `Start-Job` 등 비동기 수집으로 전체 실행 시간을 단축 가능 (다만 복잡도 증가) |
| **출력 경로** | `$PSScriptRoot` (스크립트 위치) 에 저장 | 사용자가 지정한 `-OutputPath` 파라미터를 추가해 유연성 강화 |
| **문서화** | 헤더에 간단한 설명만 존재 | `Get-Help` 를 위한 **Comment‑Based Help** 블록을 추가하면 `Get-Help` 로 바로 사용법 확인 가능 |

---

## 5️⃣ 보안·운영 측면
| 체크포인트 | 내용 |
|------------|------|
| **관리자 권한** | `Assert-AdminPrivileges` 로 사전 검증 (필수) |
| **스크립트 실행 정책** | `#Requires -Version 5.1` 외에 `Set-ExecutionPolicy` 가 필요할 수 있음 (예: `RemoteSigned`) |
| **파일 삭제** | `-Force -ErrorAction SilentlyContinue` 로 삭제 시 오류 무시 → 로그에 남지 않음. 디버그 모드에서는 삭제를 스킵해 문제 원인 파악 가능 |
| **압축 파일** | `Compress-Archive` 로 생성된 ZIP 파일은 기본적으로 암호화되지 않음. 민감 데이터가 포함될 경우 추가 암호화 고려 필요 |

---

## 6️⃣ 요약
- **전체 흐름**: 초기화 → 라이브러리 로드 → 사전 체크 → 8가지 카테고리 수집 → JSON/HTML 출력 → ZIP 압축 → 정리.
- **핵심 모듈**: `Common.ps1`(공통 로직), `Collectors.ps1`(모듈 로더), `Reporters.ps1`(보고서), 8개 전문 컬렉터 모듈.
- **디버그 모드**: 로그 파일 자동 생성, 정리 단계 스킵.
- **출력 옵션**: `JSON`, `HTML`, `Both` 지원, 결과를 ZIP으로 묶어 배포.
- **보완점**: 파라미터 검증 강화, 개별 오류 로깅, 성능 최적화, 사용자 지정 출력 경로, 보안(압축 암호화) 등.

---

## 7️⃣ 리팩토링: 모듈화 및 단일 책임 원칙 적용

### 🎯 리팩토링 목표
- **단일 책임 원칙(SRP)**: 각 모듈이 하나의 명확한 책임만 가지도록 분리
- **유지보수성 향상**: 기능별로 독립된 파일로 분리하여 수정 및 테스트 용이
- **재사용성 증대**: 개별 컬렉터를 독립적으로 사용 가능
- **가독성 개선**: 파일 크기 축소 및 명확한 구조

### 📦 리팩토링 전/후 비교

| 구분 | 리팩토링 전 | 리팩토링 후 |
|------|-------------|-------------|
| **파일 구조** | `Collectors.ps1` (267줄, 단일 파일) | `Collectors.ps1` (로더) + 8개 전문 모듈 |
| **책임 분리** | 모든 수집 로직이 하나의 파일에 집중 | 기능별로 명확히 분리된 모듈 |
| **테스트** | 전체 파일을 로드해야 개별 기능 테스트 가능 | 각 모듈을 독립적으로 테스트 가능 |
| **유지보수** | 특정 기능 수정 시 큰 파일 전체를 검토 | 해당 모듈만 수정하면 됨 |
| **확장성** | 새 기능 추가 시 파일이 계속 비대해짐 | 새 컬렉터 모듈 추가만으로 확장 가능 |

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

### 📋 사용 방법
리팩토링 후에도 기존 인터페이스는 동일하게 유지됩니다:

```powershell
# 메인 스크립트에서 자동으로 모든 모듈 로드
. "$PSScriptRoot\lib\Collectors.ps1"

# 개별 컬렉터 사용
$hwInfo = Get-HardwareInfo
$netInfo = Get-NetworkInfo
```

### ✅ 리팩토링 이점
1. **명확한 책임 분리**: 각 파일이 하나의 도메인만 담당
2. **독립적 테스트**: 각 모듈을 개별적으로 테스트 가능
3. **병렬 개발**: 여러 개발자가 동시에 다른 모듈 작업 가능
4. **선택적 로드**: 필요한 컬렉터만 로드하여 성능 최적화 가능
5. **문서화 용이**: 각 모듈의 역할이 명확하여 문서 작성 간편

---

## 8️⃣ Windows Update 로그 추가

- `Get-WindowsUpdateInfo` 함수가 추가되어 `Pending.xml`, `dism.log`, `CBS.log` 파일을 읽어 반환합니다.
- `Get-LogInfo`에 `WindowsUpdate` 속성이 포함되어 보고서에 포함됩니다.

---

## 📌 다음 단계 제안
1. **모듈별 단위 테스트** – 각 컬렉터 모듈을 독립적으로 테스트하여 정상 동작 확인
2. **통합 테스트** – 전체 시스템이 모듈화 후에도 정상 작동하는지 검증
3. **성능 벤치마크** – 리팩토링 전/후 성능 비교 (실행 시간, 메모리 사용량)
4. **문서화 강화** – 각 모듈에 `Get-Help` 용 상세 주석 추가
5. **CI/CD 파이프라인** – 자동화된 테스트 및 배포 프로세스 구축

궁금하신 부분이나 추가 개선 사항이 있으면 알려 주세요! 🚀
