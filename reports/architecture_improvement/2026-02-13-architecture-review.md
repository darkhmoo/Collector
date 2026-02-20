# 아키텍처 관점 개선 보고서

## 1. 개요
Collector 프로젝트는 `system_information_collector_for_windows.ps1`을 중심으로 **수집 파이프라인 → 병렬 실행기 → 출력 변환기**가 연결된 모놀리식 스크립트형 아키텍처입니다. 현재 기능은 동작하지만, 모듈 경계가 느슨하고 상태/오류 계약이 일부 섞여 있어 확장/안정성에 리스크가 큽니다.

이 보고서는 **아키텍처(관점) 개선**에 초점을 두고, 실행 흐름, 경계 계약, 오류 전파, 테스트 정합성을 기준으로 리팩토링 방향을 정리합니다.

## 2. 현재 아키텍처 지도

### 2.1 현재 실행 흐름

`system_information_collector_for_windows.ps1`
- 파라미터 수집(`OutputFormat`, `Modules`, `OutputPath`, `-Parallel`, `-DebugMode`, `-Encrypt`, `-Compress`)
- 핵심 라이브러리 로드(`Classes.ps1`, `Common.ps1`, `Collectors.ps1`, `Reporters.ps1`, `OutputManager.ps1`)
- 선행 조건 확인(`Assert-AdminPrivileges`, `Get-ScriptMutex`)
- 컬렉터 호출 맵 구성 (`$modulesToCollect`)
- `Invoke-Collection` 또는 `Invoke-ParallelCollection`로 수집 실행
- `Save-Results`로 포맷별 출력 저장
- 정리(`ReleaseMutex`, GC)

### 2.2 계층별 구성

- **진입/오케스트레이션 계층**
  - `system_information_collector_for_windows.ps1`
  - 단일 스크립트에서 구성/흐름/옵션 해석/실행 제어를 모두 수행

- **수집 계층**
  - `lib/collectors/*.ps1` + `lib/Classes.ps1`
  - BaseCollector 기반 클래스는 존재(`BaseCollector`), 각 모듈은 `Collect()` 구현 및 wrapper(`Get-*-Info`) 제공

- **공통 유틸 계층**
  - `lib/Common.ps1`
  - `Write-Log`, `Get-CimSafe`, `Assert-*`, `Invoke-Collection`, `Invoke-ParallelCollection`

- **출력/보고 계층**
  - `lib/OutputManager.ps1`(파일 생성/암호화/압축/정리)
  - `lib/Reporters.ps1` + `lib/reporters/*.ps1`(HTML/CSV/이벤트 로그)

- **품질보증 계층**
  - `tests/Comprehensive.Tests.ps1`, `tests/lib/*.ps1`
  - 현재 실행/엣지 케이스 테스트가 존재하나, 일부 테스트가 실제 API 계약과 다름

## 3. 현재 구조에서의 핵심 개선 포인트

1. **전역 상태 의존도가 높음**
- `$script:` 기반 값(`$script:generatedFiles`, `$script:outputPath`, `$script:DebugMode` 등)에 여러 컴포넌트가 강하게 의존
- 병렬 실행 시 공유 상태 경계가 명확하지 않아 예측 가능한 동작 보장이 어려움

2. **암시적(implicit) 계약과 테스트 계약 불일치**
- `Get-HighAvailabilityInfo -WhatIf:$WhatIfPreference` 호출은 호출부에서 WhatIf를 강제 전달하지만 수신 함수는 현재 `CmdletBinding(SupportsShouldProcess)`가 없음
- `Save-Results` 테스트 호출 시 파라미터명이 실제 함수 정의와 달라 테스트가 바인딩 레벨에서 실패

3. **오류 전파 정책 일관성 부족**
- 출력 계층에서 오류를 로그만 남기고 종료/전파를 생략하는 구간 존재
- 결과 자체가 성공처럼 보이는 구간이 생겨 상위 오케스트레이션이 실패를 감지하지 못함

4. **플러그인/의존성 경계가 얇음**
- 로더(`lib/Collectors.ps1`)는 디스크 탐색 + 서명검증 + 로딩을 한 번에 처리
- 보안 정책(서명 판단/신뢰목록/예외 정책)이 수집 로딩 정책과 결합

5. **결과 스키마의 표준화 미비**
- 일부 수집 항목은 객체, 일부는 문자열 오류 메시지, 일부는 배열 등 비균일 반환
- 직렬화/CSV 변환 단계에서 후처리 분기 복잡도가 증가

## 4. 권장 아키텍처(목표)

### 4.1 레이어 재정의

- **CollectorOrchestrator(실행 제어기)**
  - 파이프라인 단계: 파라미터 정규화 → 모듈 로딩 → 실행 → 집계 → 출력기 호출 → 후처리
  - 모든 단계 결과는 `ExecutionResult` 객체로 반환

- **Collector Registry(수집 레지스트리)**
  - `lib/collectors/` 파일 스캔과 로딩을 분리
  - 수집 플러그인은 `metadata (Name, Category, Prereq, DependsOn)` + `Get-...Info(context)`를 계약으로 제공

- **Context 객체 주입**
  - `CollectorContext`에 출력 경로, 로깅, 디버그 설정, WhatIf, 동시성 옵션을 담아 전달
  - 전역 변수 대신 함수 인자/클래스 프로퍼티로 전달

- **Result Contract 고정**
  - 각 컬렉터 `Collect()`는 `CollectorResult`를 반환
    - `Status(Success/PartialFail/Failed)`
    - `Category` 
    - `Payload`(PSCustomObject)
    - `Errors`(배열)
    - `Artifacts`(생성 파일 경로)

- **Output Pipeline 표준화**
  - `Save-Results`는 출력 생성기 체인에만 집중하고, 내부 함수는 개별적으로 상태를 반환
  - 실패는 `SaveResult` 반환 객체로 상위로 통합 전파

### 4.2 아키텍처 다이어그램(개념)

`CLI 실행` 
`=>` `Config + Context` 
`=>` `CollectorLoader/Registry`
`=>` `CollectorRunner(Serial/Parallel)`
`=>` `Result Aggregator`
`=>` `Serializer/Reporter`(`JSON/HTML/CSV/EventLog`)
`=>` `Encrypt -> Compress -> Cleanup`
`=>` `Structured Audit Report`

## 5. 단계별 개선 로드맵

### P0 (핵심 안정성)
1. 수집 함수를 전역 상태에서 해방
   - HA, Network, Output 경로/옵션을 매개변수화하여 wrapper 및 수집 클래스에 전달
2. WhatIf/ShouldProcess 계약 정합화
   - 모든 위험 연산은 동일 규약(CmdletBinding + SupportsShouldProcess)으로 정리
3. `Save-Results` 실패 전파 정책 고정
   - 단순 `Write-Error`만 수행하는 형태 제거 후, 실패 결과 반환/예외 전달
4. 테스트 계약 정합성 복원
   - 기존 테스트에서 현재 함수 시그니처와 정확히 일치하도록 정규화

### P1 (구조 강화)
5. Collector Registry 메타데이터 도입
   - 현재 동적 로딩은 유지하되, 메타데이터와 로드 실패 원인 로깅을 분리
6. 결과 객체 스키마 통일
   - 오류/빈값을 문자열 폴백보다 상태코드+메시지 구조로 전환
7. 병렬 실행 결과 집계 형식 통일
   - 병렬 타임아웃, runspace 종료, 취소를 동일 결과 코드로 표현

### P2 (운영 품질)
8. 출력기 플러그인 등록 방식 통일
   - HTML/CSV/EventLog는 동일한 `IReporter` 형태로 등록
9. 관측성 강화
   - 각 단계별 `correlationId`, 입력 항목 수, 처리 시간, 메모리 델타를 공통 스키마로 기록
10. 테스트 계층을 아키텍처 계약 테스트로 확장

## 6. 위험도 평가

- P0 단계의 변경은 실행 동작과 테스트에 직접 영향이 큼. 기능 회귀를 막기 위해 단계적 실행 + 회귀 테스트 3종 병행 필요.
- P1/P2는 점진 적용 가능하며, 기존 동작 유지하에 내구성·유지보수성이 크게 개선됨.

## 7. 시간/공간 복잡도(현재 기준)

- **설정/모듈 스캔**: `O(M)` (`M`: collector 파일 수)
- **수집 실행**: `O(ΣCi)` (`Ci`: 각 컬렉터 수집 비용), 병렬 모드에서는 이론적 최대 `O(max(Ci))`에 근접하나 병렬 오버헤드 존재
- **출력 직렬화**: `O(R*S)` (`R`: 수집 항목 수, `S`: 직렬화 크기)
- **메모리**: 컬렉션 객체 전체 보유 시 `O(R*S)` + 리포트 텍스트/CSV/HTML 임시 버퍼

## 8. 엣지 케이스/검증 시나리오 (최소 10개)

1. `Modules=ALL` + `-WhatIf:$true`에서 `HighAvailability` 수집 시 파라미터 바인딩 오류 검증
2. `OutputPath` 미생성/경로권한 없음에서 즉시 실패 및 상위 전파 확인
3. `Get-ClusterLog` 실패 시 수집 전체 중단 여부와 에러 메시지 고정
4. `Get-NfsMountedIt` cmdlet 부재 환경에서 폴백 문자열이 정확히 기록되는지 확인
5. `Get-CimInstance` 실패 주입 시 `Get-CimSafe`가 빈 배열/로그 정책을 일관되게 반환하는지
6. `-Encrypt` 케이스에서 파일 암호화 중간 실패 시 민감 정보 잔류 여부 점검
7. 병렬 모드에서 1개 모듈 타임아웃(3000 tick) 발생 시 전체 종료 코드와 상세 로그 확인
8. `-Compress` 활성 시 임시 파일 정리 정책이 실제로 적용되는지 검증
9. `-outputFormat ALL + EventLogFormat=CSV/HTML` 조합에서 결과 파일 수 일치 여부 확인
10. `tests/EdgeCase`의 `Save-Results` 호출 시 현재 함수 계약과 동일한 파라미터로 테스트 보정 가능성 검증

## 9. 실패 시 기대 로그(표준안)

- `CRITICAL ERROR: Failed to load required collector module: <module>`
- `VALIDATION FAILED: Collector output contract mismatch: <module>, expected CollectorResult`
- `SAVE FAILED: Output generation failed (format=<JSON|HTML|CSV>) - <Reason>`
- `[Parallel] <module> timed out after <N>s`
- `[Orchestrator] Collection finished with status=<Failed>, failedModules=<n>, elapsed=<ms>`

## 10. 의존성/버전

- **PowerShell**: 최소 `5.1` (`#Requires -Version 5.1`)
- **운영체제**: Windows 10/11, Windows Server 2016+
- **.NET API**: `System.Diagnostics.Stopwatch`, `System.Threading.Mutex`, `System.IO.Compression.ZipFile`, `System.Security.Cryptography`
- **외부 모듈**: 기본적으로 OS 기본 모듈 사용(ActiveDirectory, Hyper-V, FailoverClusters는 환경존재 시 optional)

## 11. 자체 검토 결과

본 아키텍처 개선안은 현재 소스 구조에서 확인된 결함(전역 상태 결합, WhatIf 계약 불일치, 출력 실패 미전파, 테스트 계약 불일치) 중심으로 정합성과 운영 신뢰도를 높이도록 설계했습니다. 실제 구현 시에는 `P0` 항목을 선행하고, 각 단계마다 `Comprehensive.Tests.ps1` 회귀 및 엣지케이스 10개를 최소치로 검증해 배포 리스크를 제어해야 합니다.
