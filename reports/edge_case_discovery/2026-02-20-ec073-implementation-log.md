# EC-073 구현 로그 (2026-02-20)

대상 이슈: `#3 [P0] EC-073 병렬 태스크 타임아웃 격리`

## 1) 테스트 구현 계획
- 목표:
  - 병렬 수집에서 타임아웃 태스크 결과가 구조화 객체(`Status`, `TimedOut`, `ElapsedMs`)로 반환되는지 검증
  - 타임아웃 태스크가 있어도 다른 태스크 결과가 정상 수집/저장되는지 검증
  - 타임아웃 발생 시 runspace 자원 정리가 수행되는지 간접 검증
- 테스트 항목:
  - `ParallelTimeoutResultSchemaTest`
    - 타임아웃 결과가 문자열이 아닌 구조화 객체인지 확인
  - `ParallelTimeoutIsolationBehaviorTest`
    - 3개 태스크 중 1개만 타임아웃일 때 나머지 2개 결과가 정상인지 확인
  - `ParallelTimeoutResourceCleanupSmokeTest`
    - 타임아웃 반복 호출 후 추가 병렬 호출이 정상 완료되는지 확인
- 기대 결과:
  - 구현 전: 최소 1개 이상 실패
  - 구현 후: 3개 테스트 모두 통과

## 2) 테스트 작성 결과 (구현 전)
- 추가 테스트:
  - `ParallelTimeoutResultSchemaTest`
  - `ParallelTimeoutIsolationBehaviorTest`
  - `ParallelTimeoutResourceCleanupSmokeTest`
- 실행 결과:
  - `ParallelTimeoutResultSchemaTest`: Failed (`Timeout result must be a structured object.`)
  - `ParallelTimeoutIsolationBehaviorTest`: Failed (`Hang task must be timed out.`)
  - `ParallelTimeoutResourceCleanupSmokeTest`: Passed

## 3) 코드 구현 계획
- 목표:
  - 타임아웃 태스크 반환값을 문자열에서 구조화 결과 객체로 변경
  - 성공 태스크도 동일 스키마(`Status`, `TimedOut`, `ElapsedMs`)로 정규화
  - 기존 메인 병합 로직(`Data`, `StepTimings`, `GeneratedFiles`) 호환 유지
- 변경 포인트:
  - `lib/Common.ps1`의 `Invoke-ParallelCollection`
    - timeout 분기 결과를 `[PSCustomObject]`로 반환
    - completed 분기 결과도 최소 메타데이터 필드 추가
    - timeout 로그/데이터 메시지에 설정 시간 반영 유지
- 완료 기준:
  - 타임아웃 태스크가 `Status=TimedOut`으로 구분 가능
  - 타임아웃 발생 시에도 비타임아웃 태스크 결과 저장 유지

## 4) 코드 구현 결과
- 변경 파일:
  - `lib/Common.ps1`
  - `tests/lib/EdgeCaseTests.ps1`
  - `tests/Comprehensive.Tests.ps1`
- 구현 내용:
  - `Invoke-ParallelCollection`의 완료 분기 결과를 정규화(`Status=Completed`, `TimedOut=false`, `ElapsedMs`)
  - `Invoke-ParallelCollection`의 타임아웃 분기 결과를 구조화 객체로 변경(`Status=TimedOut`, `TimedOut=true`, `ElapsedMs`)
  - 기존 메인 병합 로직 호환을 위해 `Data/StepTimings/GeneratedFiles` 필드 유지
  - 타임아웃 격리 검증 테스트 3개 추가 및 러너 등록
- 구현 후 테스트 결과:
  - `ParallelTimeoutResultSchemaTest`: Passed
  - `ParallelTimeoutIsolationBehaviorTest`: Passed
  - `ParallelTimeoutResourceCleanupSmokeTest`: Passed

## 5) 보안 서명 점검 결과
- 수행 내용:
  - 변경 후 전체 `.ps1` 일괄 재서명 수행
  - `Get-AuthenticodeSignature`로 전체 상태 검증
- 결과:
  - `Valid: 29`
  - `Valid` 이외 상태: `0`
