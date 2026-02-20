# EC-025 구현 로그 (2026-02-20)

대상 이슈: `#2 [P0] EC-025 수집 블록 무한 대기 방지`

## 1) 테스트 구현 계획
- 목표:
  - 병렬 수집 엔진이 태스크 타임아웃 값을 외부에서 받는지 검증
  - 타임아웃 초과 태스크가 무한 대기하지 않고 실패 상태로 반환되는지 검증
  - 메인 스크립트가 순차 모드에서도 타임아웃 가능한 수집 경로를 사용하는지 검증
- 테스트 항목:
  - `ParallelCollectionTimeoutContractTest`
    - `Invoke-ParallelCollection`이 `taskTimeoutSeconds` 파라미터를 제공하는지 확인
  - `ParallelCollectionTimeoutBehaviorTest`
    - 의도적으로 지연되는 태스크를 짧은 타임아웃으로 실행해 timeout 결과 확인
  - `MainScriptSequentialTimeoutContractTest`
    - 메인 스크립트에 `moduleTimeoutSeconds` 파라미터와 순차 모드 타임아웃 경로가 존재하는지 확인
- 기대 결과:
  - 구현 전: 최소 1개 이상 실패
  - 구현 후: 3개 테스트 모두 통과

## 2) 테스트 작성 결과 (구현 전)
- 추가 테스트:
  - `ParallelCollectionTimeoutContractTest`
  - `ParallelCollectionTimeoutBehaviorTest`
  - `MainScriptSequentialTimeoutContractTest`
- 실행 결과:
  - `ParallelCollectionTimeoutContractTest`: Failed (`Invoke-ParallelCollection must expose -taskTimeoutSeconds.`)
  - `ParallelCollectionTimeoutBehaviorTest`: Failed (`taskTimeoutSeconds` 파라미터 미존재)
  - `MainScriptSequentialTimeoutContractTest`: Failed (`Missing module timeout parameter in main script.`)

## 3) 코드 구현 계획
- 목표:
  - 수집 엔진에 태스크 타임아웃 파라미터를 공식화
  - 순차 모드도 타임아웃 가능한 경로로 통합해 무한 대기 방지
- 변경 설계:
  - `lib/Common.ps1`
    - `Invoke-ParallelCollection`에 `taskTimeoutSeconds`, `maxThreadsOverride` 파라미터 추가
    - 기존 고정(300s) 타임아웃 로직을 파라미터 기반으로 변경
  - `system_information_collector_for_windows.ps1`
    - `moduleTimeoutSeconds` 파라미터 추가
    - 순차 모드에서 `Invoke-ParallelCollection -maxThreadsOverride 1` 경로 사용
- 완료 기준:
  - 3개 테스트 모두 Passed
  - 타임아웃 메시지에 설정값(초)이 반영됨

## 4) 코드 구현 결과
- 변경 파일:
  - `lib/Common.ps1`
  - `system_information_collector_for_windows.ps1`
  - `tests/lib/EdgeCaseTests.ps1`
  - `tests/Comprehensive.Tests.ps1`
- 구현 내용:
  - `Invoke-ParallelCollection`에 `taskTimeoutSeconds` 파라미터 추가(기본 300초)
  - `Invoke-ParallelCollection`에 `maxThreadsOverride` 추가(0=자동, 1=순차 강제)
  - 고정 타임아웃(300초) 로직을 파라미터 기반(`taskTimeoutSeconds`)으로 전환
  - 메인 스크립트에 `moduleTimeoutSeconds` 파라미터 추가
  - 순차 모드도 `Invoke-ParallelCollection -maxThreadsOverride 1` 경로를 사용하도록 통합
- 구현 후 테스트 결과:
  - `ParallelCollectionTimeoutContractTest`: Passed
  - `ParallelCollectionTimeoutBehaviorTest`: Passed
  - `MainScriptSequentialTimeoutContractTest`: Passed

## 5) 보안 서명 점검 결과
- 수행 내용:
  - 변경 후 전체 `.ps1` 일괄 재서명 수행
  - `Get-AuthenticodeSignature`로 전체 상태 검증
- 결과:
  - `Valid: 29`
  - `Valid` 이외 상태: `0`
