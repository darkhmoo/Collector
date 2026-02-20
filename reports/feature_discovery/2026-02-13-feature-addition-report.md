# 기능 추가가 필요한 항목 발굴 보고서

## 1. 개요
`Collector` 프로젝트는 수집/출력/보안/테스트 파이프라인이 운영 가능한 수준으로 동작하고 있으나, 일부 모듈 계약 불일치·오류 전파·테스트 불일치로 인해 기능 확장 시 예측 가능한 장애 지점이 존재합니다. 본 보고서는 **기능 추가 우선순위 관점**에서 추가가 필요한 항목을 발굴하고, 각 항목별 테스트, 실패 로그, 복잡도 및 구현 선후순위를 제시합니다.

작성일: 2026-02-13

근거 파일: `system_information_collector_for_windows.ps1`, `lib/Collectors.ps1`, `lib/Common.ps1`, `lib/OutputManager.ps1`, `lib/collectors/*.ps1`, `tests/lib/*.ps1`

---

## 2. 기능 추가 후보 (우선순위)

### P0-1. 컬렉터 반환 계약(CollectorResult) 표준화
- 문제 근거
  - 각 컬렉터가 문자열/객체/배열을 혼합 반환, 병렬/직렬 집계부에서 fallback 처리 의존(`Invoke-ParallelCollection` 병합 로직).
  - `system_information_collector_for_windows.ps1:219`에서 HA 호출부 바인딩 불일치, `HACollector`/`Inventory`/`Security` 계열에서 각기 다른 실패 표현.
- 제안
  - 모든 컬렉터가 `[PSCustomObject]` 형태 `Result`로 통일:
    - `Status(Success/Partial/Fail)`, `Category`, `Data`, `Errors`, `Artifacts`, `ElapsedMs`
  - `system_information_collector_for_windows.ps1` 집계는 이 계약만 처리.
- 기대 효과
  - 병렬 결과 병합 신뢰도 향상, 실패 분석 자동화 기반 확보.
- 의존성
  - 기존 `BaseCollector` 확장(`lib/Classes.ps1`), 컬렉터 수정.

### P0-2. `Save-Results` 실패 전파 강화(예외/종료 코드 정책)
- 문제 근거
  - `lib/OutputManager.ps1:167-170`에서 실패를 `Write-Error`만 기록하고 종료 전파 없음.
  - 호출부에서 반환값/결과 코드 없음.
- 제안
  - `Save-Results`가 `bool` 또는 `SaveResult` 객체 반환.
  - 모든 출력 파이프라인(`JSON/HTML/CSV/ZIP/Encrypt`)에서 실패 시 상위에 에러 객체 전파.
  - 메인 스크립트 최종 종료 코드(`$LASTEXITCODE`) 설정.
- 기대 효과
  - 저장 실패가 운영 배포에서 침묵되지 않음.

### P0-3. HA 모듈 `WhatIf`/`OutputPath` 계약 정합성
- 문제 근거
  - `system_information_collector_for_windows.ps1:219`에서 `Get-HighAvailabilityInfo -WhatIf:$WhatIfPreference` 호출.
  - `lib/collectors/HACollector.ps1:82` wrapper는 `CmdletBinding()` 미지원/고정 `Get-HighAvailabilityInfo`만 사용.
  - `lib/collectors/HACollector.ps1:60` `Get-ClusterLog` 경로가 `script:outputPath` 의존.
- 제안
  - `Get-HighAvailabilityInfo -WhatIf` 파라미터 계약 적용 + `-OutputPath` 명시형 매개변수 추가.
  - 경로 기본값을 상위에서만 결정하고 wrapper는 전달받은 값 사용.

### P0-4. 테스트 계약 정합성 자동화(현재 EdgeCase 케이스 보정)
- 문제 근거
  - `tests/lib/EdgeCaseTests.ps1`의 `DiskFullSimulationTest`가 현재 `Save-Results` 시그니처와 다르게 호출됨.
  - `WmiCorruptionTest`도 기대값이 `null`로 고정되어 실제 계약(`@()`)과 불일치.
- 제안
  - 테스트 파라미터/시나리오를 실제 함수 계약( `-auditReport`, `-outputFormat`, `-outputDirectory`, `-isDebugMode`, `-zipResults`, `-encryptionKey` )으로 정렬.
  - 계약 불일치 탐지용 assertion 헬퍼 함수 추가.

### P1-1. Network 수집 명령 탐지/폴백 정책 강화
- 문제 근거
  - `lib/collectors/NetworkCollector.ps1:55`에서 `Get-NfsMountedIt` 존재성 체크/호출.
  - cmdlet 명칭/환경별 편차 시 “NFS Client/Module not available” 문자열로만 축약.
- 제안
  - cmdlet 존재 확인을 모듈/OS 버전 기준으로 다층화하고 실패 이유를 구조화.
  - `Sharing.NfsMounts`를 폴백 코드(`NFS_MISSING_CMD`, `NFS_PERMISSION`, `NFS_SUCCESS`)로 구성.

### P1-2. 플러그인 로더 보안 정책(허용 목록/폴더 신뢰) 추가
- 문제 근거
  - `lib/Collectors.ps1`는 `Get-AuthenticodeSignature` 상태가 `Valid`이면 로드.
- 제안
  - `Valid` + Thumbprint allowlist 또는 정책 파일 기반 allowlist 적용.
  - 로더와 수집 실행 분리(검증 실패 시 수집 목록에서 제외).

### P1-3. 병렬 실행 결과 수집기(리턴 메타데이터) 분리
- 문제 근거
  - 병렬 실행은 `Invoke-ParallelCollection`에서 `Data/StepTimings/GeneratedFiles`만 반환.
  - 컬렉터별 상태코드가 없어 실패 원인 집계 품질이 낮음.
- 제안
  - 병렬 반환 형식을 `CollectorResult`와 `RunContext`로 확장.
  - 병렬 실패 시 `timeout`/`runspace exception`/`serialization failure` 구분 코드 제공.

### P1-4. 출력 산출물 무결성 검증(Manifest) 기능
- 문제 근거
  - 현재 저장 후 결과 무결성 검증 단계 없음.
- 제안
  - 저장 완료 시 `result_*.manifest.json` 생성(파일명, SHA256, 크기, 생성시간, 항목 수).
  - `-Compress`/`-Encrypt` 조합 시 해시 계산 대상 규칙 정리.

### P2-1. 민감정보 마스킹 정책 고도화
- 문제 근거
  - `lib/Common.ps1:182` 키워드 기반으로만 마스킹 제한.
- 제안
  - 키워드 + 정규식 + 길이/패턴 추정(토큰/접속 문자열) 기반으로 2단계 마스킹.
  - 마스킹 실패 원인을 로그와 함께 남기고, 마스킹 규칙 버전 관리.

### P2-2. 사용자 경험: 실행 리포트 일관성 강화
- 문제 근거
  - 디버깅/실패 로그가 함수별로 포맷이 다르며 성공 실패 메시지 표준이 혼재.
- 제안
  - 실패/경고/완료 로그 prefix 표준화(예: `[FAIL]`, `[WARN]`, `[DONE]`, `[TIME]` ) 실행 요약에 `성공 모듈/실패 모듈/누적 실행시간/총로그크기` 추가.

---

## 3. 실패 시 기대 로그(표준안)

1. `[FAIL] Save-Results: Output generation failed - CRITICAL ERROR: ...`
2. `[FAIL] CollectorResult: HighAvailability.Status=Fail, ErrorCode=WHATIF_MISMATCH, Detail=Get-HighAvailabilityInfo does not support -WhatIf`
3. `[WARN] Network.NFS: NfsMounted cmdlet unavailable or unsupported in OS build`
4. `[FAIL] Parallel.Result: timeout module=Performance, elapsedMs=300000, status=TimedOut`
5. `[FAIL] Test.Integration: Save-Results contract mismatch - expected [PSCustomObject], received [string]`
6. `[WARN] PluginLoad: Collector signature valid but not allowlisted - skip`
7. `[DONE] Manifest: files=3, shaCheck=Pass, totalBytes=...`

로그 포맷은 공통 prefix, Module, ErrorCode, Context, Timestamp로 고정.

---

## 4. 제안 테스트 케이스 (최소 10개)

### T01. HA WhatIf 호출 계약
- 절차: `-WhatIf` + `-Modules ALL` 실행.
- 기대: 즉시 바인딩 실패 없음, 로그에 `[DONE]` 시작/종료.

### T02. HA 출력경로 일치성
- 절차: `-OutputPath C:\temp\ci-run` + `-Modules HighAvailability` 실행.
- 기대: HA 클러스터 로그 경로가 지정 경로에만 생성.

### T03. Save-Results 경로권한 실패
- 절차: 출력 폴더를 없는 경로 또는 쓰기불가 경로로 지정.
- 기대: 실패 코드 반환, `[FAIL] Save-Results` 로그.

### T04. Save-Results 예외 전파
- 절차: 강제 예외 시뮬레이션(임시로 파일 잠금).
- 기대: 상위 파이프라인 종료 코드 non-zero.

### T05. EdgeCase 계약 정합성
- 절차: `tests/lib/EdgeCaseTests.ps1`의 `WmiCorruptionTest` 수행.
- 기대: `Get-CimSafe` 결과가 `@()` 또는 `Count=0` 기준 통과.

### T06. EdgeCase 테스트 파라미터 정렬
- 절차: `DiskFullSimulationTest`를 현재 `Save-Results` 계약으로 재작성 후 실행.
- 기대: 유효한 예외 메시지로 정지.

### T07. 네트워크 NFS 명령 매핑
- 절차: cmdlet 없음/권한없음/성공 환경 3가지 케이스.
- 기대: 각기 `NFS_MISSING_CMD`, `NFS_PERMISSION`, `NFS_SUCCESS` 코드 발행.

### T08. 병렬 타임아웃 동작
- 절차: 특정 컬렉터를 인위적으로 지연.
- 기대: 300초 타임아웃 로그 및 실패 상태코드.

### T09. 플러그인 allowlist 정책
- 절차: 유효 서명이지만 allowlist 미등록 파일을 collector 폴더에 추가.
- 기대: 로드 거부 및 `[WARN] PluginLoad` 로그.

### T10. 출력 무결성
- 절차: `-OutputFormat ALL -Encrypt` 실행 후 manifest 생성/검증.
- 기대: 파일 해시 목록 일치 및 변조 시 `manifest` 검사 실패 경고.

### T11. 마스킹 정책 강화
- 절차: `password=abc123`, `AKIA...` 형식 문자열 포함 환경변수 수집.
- 기대: 민감 패턴이 마스킹된 문자열로 치환.

---

## 5. 시간/공간 복잡도(요약)

- **기능 추가 전반(일반 수집)**: O(M + ΣCi), `M=수집 모듈 수`, `Ci=각 모듈 수집 비용`.
- **CollectorResult 표준화**: 직렬 수집 O(M + ΣCi), 병렬 수집 O(max(Ci) + M) + 병합 O(M).
- **무결성 manifest**: O(R) 문자열/파일 수 `R`, I/O 비용 O(총 출력 크기).
- **병렬 실행 확장(실패 메타데이터 포함)**: O(max(Ci) + M) 메모리는 각 작업 결과 O(R) + runspace 부하.
- **마스킹 고도화**: 각 문자열 길이 `L`당 O(L) + 정규식 추가시 상수배.

---

## 6. 의존성/버전

- PowerShell: `5.1` 이상 (`#Requires -Version 5.1`).
- OS: Windows Server 2016+, Windows 10/11.
- 주요 모듈: `Get-CimInstance`/`Get-CimSafe` 기반 WMI 계열 cmdlet, `Get-Cluster`, `Get-Nfs*`, `Get-ActiveDirectory`/`ActiveDirectory`, Hyper-V/Containers 모듈(선택).
- .NET API: `System.Diagnostics.Stopwatch`, `System.Threading.Mutex`, `System.Security.Cryptography.Aes` 계열.

---

## 7. 구현 우선순위 제안

- **1단계(P0)**: P0-1, P0-2, P0-3, P0-4
- **2단계(P1)**: P1-1, P1-3, P1-2, P1-4
- **3단계(P2)**: P2-1, P2-2

---

## 8. 자체 검토

본 보고서는 기존 코드 패턴을 변경 없이 기능 추가 항목 중심으로 정리했습니다. 보고서에는 테스트 케이스 10개 이상, 실패 로그 표준안, 시간/공간 복잡도, 의존성/버전 정보를 포함했습니다.

