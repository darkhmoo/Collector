# 논리적 오류 리뷰 보고서

## 1) 점검 대상
- `system_information_collector_for_windows.ps1`
- `lib/collectors/HACollector.ps1`
- `lib/collectors/NetworkCollector.ps1`
- `lib/OutputManager.ps1`
- `tests/lib/EdgeCaseTests.ps1`
- `tests/Comprehensive.Tests.ps1`

## 2) 핵심 논리 오류 (우선순위 순)

### 1. [Critical] HighAvailability 수집 시 `-WhatIf` 바인딩 실패
- 위치
  - `system_information_collector_for_windows.ps1:219`
  - `lib/collectors/HACollector.ps1:82`
- 문제
  - 메인 루프에서 HighAvailability 모듈 호출 시 `Get-HighAvailabilityInfo -WhatIf:$WhatIfPreference`를 항상 전달합니다.
  - 그러나 `Get-HighAvailabilityInfo` 함수에는 `CmdletBinding`/`SupportsShouldProcess`가 없어 `-WhatIf` 파라미터를 받을 수 없습니다.
- 영향
  - `-modules ALL`(기본)에서 실행 시 HighAvailability 모듈이 포함되면 즉시 파라미터 바인딩 예외로 전체 수집이 실패할 수 있습니다.
- 권고
  - `Get-HighAvailabilityInfo`에 `[CmdletBinding(SupportsShouldProcess=$true)]`를 추가하고 내부에서 `ShouldProcess()` 적용.
  - 또는 HighAvailability 블록에서 `-WhatIf` 전달을 제거/조건부로 변경.

### 2. [High] HighAvailability 클러스터 로그 경로 전달 누락
- 위치
  - `system_information_collector_for_windows.ps1:61`, `system_information_collector_for_windows.ps1:219`
  - `lib/collectors/HACollector.ps1:84`
- 문제
  - `Get-HighAvailabilityInfo`는 내부적으로 `([HACollector]::new($script:outputPath))`를 사용하지만, 메인에서는 로컬 `$outputPath` 파라미터(사용자 지정 출력 경로)를 넘기지 않습니다.
  - `script:outputPath`는 해당 스크립트에서 명시적 설정이 없어 `null`일 가능성이 높고, `GetClusterLog`는 기본적으로 `$PSScriptRoot`에 남습니다.
- 영향
  - 사용자가 지정한 출력 폴더와 다른 경로에 로그가 생성되어 추적 난이도 증가.
- 권고
  - `Get-HighAvailabilityInfo -OutputPath $outputPath` 같은 인자를 정의해 전달하고, `GetClusterLog` 출력 경로에 이를 사용.

### 3. [High] NFS 마운트 수집 cmdlet 오타
- 위치: `lib/collectors/NetworkCollector.ps1:55`
- 문제
  - 존재 여부를 `Get-Command -Name Get-NfsMountedIt`로 검사하고 호출도 동일 이름을 사용합니다.
- 영향
  - 실제 cmdlet명이 다르다면 해당 블록은 항상 실패해 `NfsMounts`가 항상 폴백 문자열로 남습니다.
- 권고
  - 올바른 NFS cmdlet명(운영 환경 기준)으로 변경 및 존재하지 않을 때도 로직이 일관되게 동작하도록 예외 처리 보강.

### 4. [High] EdgeCase 테스트의 Save-결과 파라미터 불일치
- 위치: `tests/lib/EdgeCaseTests.ps1:107`
- 문제
  - `Save-Results`는 `-auditReport`, `-outputFormat`, `-outputDirectory`, `-isDebugMode`, `-zipResults`, `-encryptionKey`만 사용하지만,
  - 테스트는 `-Data`, `-Path`, `-Format`, `-Encrypt`를 사용합니다.
- 영향
  - 테스트가 항상 바인딩 실패하며, 실제 저장 실패 시나리오를 검증하지 못함.
- 권고
  - 테스트 파라미터를 실제 함수 계약에 맞춰 교체하고 예외 메시지/동작을 검증하도록 보정.

### 5. [High] EdgeCase `Get-CimSafe` 계약 위배
- 위치: `lib/Common.ps1:64`, `tests/lib/EdgeCaseTests.ps1:47`
- 문제
  - `Get-CimSafe`는 실패 시 `@()`를 반환하도록 되어 있으나 테스트는 `$null`을 기대합니다.
- 영향
  - WMI 오류 처리 동작 검증이 잘못되어, 실제 회귀를 가리는 오탐/미탐이 발생합니다.
- 권고
  - 테스트 기대값을 `@()` 또는 `.Count -eq 0`으로 변경.

### 6. [Medium] `Save-Results` 저장 실패 시 상위 실패 전파 누락
- 위치: `lib/OutputManager.ps1:167-170`
- 문제
  - 저장 단계의 `catch`가 `Write-Error`만 수행하고 종료/전파하지 않습니다.
- 영향
  - 저장 I/O 오류가 발생해도 스크립트가 성공한 것으로 보일 수 있습니다.
- 권고
  - `throw` 또는 `$PSCmdlet.ThrowTerminatingError`로 실패 플래그를 상위로 전파하고, 호출부에서 적절히 종료 코드를 설정.

### 7. [Medium] `-WhatIf`/`-Confirm` 사용 규약 불일치(고위험 연산)
- 위치
  - `lib/OutputManager.ps1`의 핵심 파일 삭제/암호화/압축 조작은 `SupportsShouldProcess`를 사용하지만,
  - 이를 호출하는 상위 모듈들 일부는 위험 연산의 동작 제어가 불완전합니다.
- 영향
  - 테스트/운영에서 예상한 Dry-run 동작이 일관되지 않아 실수로 민감 파일이 생성/삭제될 수 있습니다.
- 권고
  - `Save-Results`, `Get-HighAvailabilityInfo` 경로 처리, `GetClusterLog` 경로 생성/삭제를 동일 정책으로 정합.

### 8. [Low] 로그 폴백 메시지의 일관성 부족
- 위치: `lib/collectors/NetworkCollector.ps1:40~60`, `lib/collectors/SecurityCollector.ps1:16~18`
- 문제
  - 폴백 문자열(`"NFS Client/Module not available"`, `"Get-AppxPackage cmdlet not available"` 등)이 실제 장애와 유사한 권한/명령 오류를 구분하지 못하고 동일 메시지를 노출.
- 영향
  - 운영자가 원인 분석할 때 오탐 위험.
- 권고
  - 오류 코드를 포함한 정규 메시지 구조로 변경하고, 원인 분기 태그를 추가.

## 3) 재현 포인트 요약
1. `system_information_collector_for_windows.ps1` 기본 실행(`-modules ALL`)에서 고의로 `-WhatIf:$false` 기본값이라도 `Get-HighAvailabilityInfo -WhatIf` 바인딩으로 수집 중단 여부 확인.
2. NFS 미지원/오타 cmdlet 환경에서 `Network` 모듈 수집 시 `NfsMounts` 값이 항상 폴백인지 확인.
3. EdgeCaseTests의 DiskFullSimulationTest 실행 시 파라미터 바인딩 실패 발생 여부 확인.
4. WMI 강제 실패 주입 시 `Get-CimSafe` 결과가 `@()`인지 여부 확인.
5. 저장소 권한 없는 경로에서 `Save-Results` 호출 시 종료 코드가 실패로 반영되지 않는지 확인.

## 4) 전체 신뢰도 판단
- 현재 상태는 수집이 중단되는 치명 논리 오류가 최소 2건 포함되어 있어, 배포 전 수정이 필요합니다.
- 특히 HighAvailability 모듈과 테스트 계약 불일치(파라미터/반환 계약)는 운영 안정성에 직접적인 영향을 주므로 우선 조치 대상입니다.
