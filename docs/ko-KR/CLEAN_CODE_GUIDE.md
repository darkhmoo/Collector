
# PowerShell 클린 코드 규칙 (실전 규약)

## 1) 네이밍 규칙

### 함수

* **Verb-Noun** 필수: `Get-Thing`, `Set-Thing`, `Invoke-Thing`
* **승인된 Verb만 사용**(Get-Verb로 확인)
* **의도를 드러내는 Noun**: `Invoke-DoStuff` 금지 → `Invoke-CollectHardwareInfo`

### 변수

* camelCase 권장: `$serverName`, `$timeoutSeconds`
* **불리언 접두사**: `$isEnabled`, `$hasAdminPrivileges`, `$shouldSaveResults`

### 상수/설정

* 하드코딩 금지: URL/경로/타임아웃은 상단에 상수 또는 파라미터로

---

## 2) 객체 지향 및 클래스 패턴 (OOP)  ✅ 최신 표준

* **`BaseCollector` 상속 필수**: 모든 수집 모듈은 객체 지향적 구조를 위해 `BaseCollector` 클래스를 반드시 상속받아야 합니다.
* **표준 인터페이스 준수**:
  - `Collect()`: 실제 수집 로직을 구현하는 핵심 메서드로, 각 하위 모듈에서 반드시 오버라이드(Override)해야 합니다.
  - `LogStart() / LogEnd()`: 수집의 시작과 종료를 알리는 일관된 로깅 인터페이스를 호출합니다.
* **생성자 활용**: 초기값 설정, 필수 모듈 로드, 또는 공통 객체 초기화는 생성자(`new()`)에서 수행합니다.
* **중복 제거 (DRY)**: 성능 측정, 공통 로깅 형식, 에러 처리 등의 공통 로직은 상위 클래스(`BaseCollector`)에 정의하여 코드 중복을 최소화합니다.

---

## 3) 함수 설계 규칙

* **함수는 한 가지 일만**(SRP)
* **파라미터 3개 초과 시**: `-Options`(hashtable) 또는 객체(PSCustomObject) 고려
* **출력은 객체로**(문자열 출력 남발 금지)

  * 사용자 메시지는 `Write-Information/Write-Verbose/Write-Warning`
  * 파이프라인용 데이터는 `Write-Output` 또는 그냥 값 반환

---

## 3) CmdletBinding / 파라미터 규칙

* 고급 함수는 기본으로:

  * `[CmdletBinding(SupportsShouldProcess=$true)]`
  * 파라미터에 `[Parameter(Mandatory=...)]`, `[ValidateNotNullOrEmpty()]`
* 위험 동작(파일 삭제/레지스트리/브라우저 실행)은 **-WhatIf / -Confirm 지원**

  * `ShouldProcess()`로 보호

---

## 4) Side-effect(부작용) 격리 규칙  ✅ 핵심

* **모듈 import/로드 시 자동 실행 금지**
* 외부 영향(브라우저 열기, 네트워크 호출, 파일 쓰기)은:

  * `Invoke-*` 계열 함수 안으로 격리
  * 가능하면 `-PassThru` 옵션 제공(실행 대신 “무엇을 할지” 객체로 반환)

---

## 5) 에러 처리 규칙

* **예외는 “잡을 이유가 있을 때만” 잡기**
* 실패는 일관되게:

  * `throw` 또는 `Write-Error -ErrorAction Stop`
* 사용자에게 필요한 정보만:

  * “무엇이 실패했는지 + 다음 조치”
* `try/catch/finally`에서 `catch`는 가능하면 **구체적 예외** 우선

---

## 6) 로깅/출력 규칙

* `Write-Host`는 최후 수단(테스트/자동화에 불리)
* 표준:

  * 디버그: `Write-Debug`
  * 상세: `Write-Verbose`
  * 정보: `Write-Information`
  * 경고: `Write-Warning`
  * 오류: `Write-Error`

---

## 7) 모듈/구조 규칙

### 권장 구조(모듈형)

* `Collector.psd1` (Manifest)
* `Collector.psm1` (모듈 진입점: export만)
* `Public\*.ps1` (외부로 노출되는 함수)
* `Private\*.ps1` (내부 유틸/도우미)
* `Tests\*.Tests.ps1` (Pester)

### 규칙

* `psm1`에는 로드/Export 중심, 로직은 Public/Private에 분산
* Public 함수만 `Export-ModuleMember`

---

## 8) 테스트 규칙 (Pester)

* 외부 호출은 반드시 **Mock 가능**하게:

  * 예: `Start-Process`, `Invoke-WebRequest`, `Test-Path`
* 테스트 이름은 의도를 설명:

  * `It 'opens browser when -Open is specified' { ... }`

---

## 9) 스타일/포맷 규칙

* **PSStyle/포맷팅 일관성**
* 가능하면 **PSScriptAnalyzer** 룰 적용

  * `Invoke-ScriptAnalyzer`로 lint
* 들여쓰기/브레이스 스타일 통일:

  * `if (...) { }` / `try { } catch { }`

---

## 10) 대규모 데이터 처리 성능 규칙

* **배열 추가 루프 자제**: 대량의 아이템을 수집할 때 `$arr += $item` 사용 금지.
* **Generic List 선호**: `[System.Collections.Generic.List[PSObject]]`를 사용하여 성능 병목 방지.
* **파이프라인 활용**: 대량 데이터를 다룰 때는 메모리 보존을 위해 가능한 한 파이프라인(`Process` 블록)을 통해 데이터를 흐르게 함.

---

# Collector에 적용하는 “PowerShell 버전 가이드”

## 목표

* import/실행 시 자동으로 브라우저 열지 말고,
* `Get-HardwareInfo` 같은 명시적 함수 호출로만 동작,
* `-WhatIf` 지원,
* 테스트 가능하게 분리.

---

# 적용 체크리스트 (PowerShell)

* [ ] 함수는 Verb-Noun, 승인 Verb 사용
* [ ] CmdletBinding + SupportsShouldProcess
* [ ] 부작용(브라우저/네트워크/파일)은 Invoke 함수 내부로 격리
* [ ] Write-Host 최소화, 로깅 스트림 사용
* [ ] 하드코딩 제거(상수/파라미터화)
* [ ] PSScriptAnalyzer 통과
* [ ] Pester 테스트에서 외부 호출 Mock

---

# “바로 쓰는” 템플릿 (antigravity 스타일)

아래 설계 원칙만 기억

* `Get-SystemInfo` : **순수 함수** (데이터 수집만)
* `Save-Results` : **부작용 함수** (파일 저장/압축)
* `Save-Results`는 `ShouldProcess()`로 `-WhatIf` 지원

---
---

좋습니다.
**Markdown(.md) 파일을 작성할 때 적용하는 “클린 코드 규칙”**을 실전 기준으로 정리합니다.
목표는 **읽기 쉬움, 구조 명확성, 유지보수성, 자동화 친화성**입니다.

---

# 📘 Markdown 클린 작성 규칙

---

## 1️⃣ 문서 구조 규칙 (Structure First)

### ✅ 헤더 계층은 논리 구조를 반영

* `#`는 문서 제목 하나만 사용
* `##` → 주요 섹션
* `###` → 하위 설명
* 계층 점프 금지 (`#` 다음에 바로 `###` 금지)

### ❌ 안 좋은 예

```
# 제목
### 설명
## 다른 섹션
```

### ✅ 좋은 예

```
# 제목
## 개요
### 배경
```

---

## 2️⃣ 한 문단 = 한 메시지

* 문단은 **3~5줄 이내**
* 한 문단에 하나의 핵심만
* 불필요한 장문 블록 금지

---

## 3️⃣ 리스트는 목적에 맞게 사용

### 순서가 중요할 때 → 번호 목록

### 나열일 때 → 불릿 목록

```md
1. 설치
2. 설정
3. 실행
```

```md
- 장점
- 단점
- 고려사항
```

---

## 4️⃣ 코드 블록 규칙

### ✅ 항상 언어 명시

````md
```powershell
Get-Process
```
````

### ✅ 인라인 코드는 단일 개념만

`SupportsShouldProcess` 처럼 사용

### ❌ 코드 블록 안에 설명 문장 혼합 금지

---

## 5️⃣ 가독성 규칙

* 한 줄 길이 100~120자 이내
* 표는 최소한만 사용
* 강조는 과하지 않게 (`**굵게**` 남발 금지)
* 이모지 사용은 문서 성격에 따라 제한

---

## 6️⃣ 링크/참조 규칙

### ✅ 명시적 링크 텍스트

```md
[PSScriptAnalyzer 공식 문서](https://learn.microsoft.com/...)
```

### ❌

```md
여기 클릭
```

---

## 7️⃣ README 기준 필수 섹션

프로젝트 문서라면:

```md
# 프로젝트 이름

## 개요
## 설치
## 사용법
## 예제
## 구성
## 테스트
## 기여 방법
## 라이선스
```

---

## 8️⃣ 변경 가능성 높은 내용 분리

* 버전, 경로, URL → 상단 “환경 정보” 섹션
* 하드코딩된 값 반복 금지
* 표 대신 설정 예제 코드 활용

---

## 9️⃣ 문서의 단일 책임 원칙

한 문서에는 한 목적만.

* ❌ 설치 + 설계 철학 + 트러블슈팅을 한 파일에 다 넣지 말 것
* ✅ `INSTALL.md`, `ARCHITECTURE.md`, `TROUBLESHOOTING.md` 분리

---

## 🔟 자동화 친화 규칙

### 린트 적용 권장

* markdownlint
* Vale (문장 스타일 검사)

### CI에서 검사

* 헤더 순서
* 공백 라인
* 코드 블록 언어 누락

---

# 🧠 Markdown 클린 코드 핵심 원칙 요약

| 원칙     | 설명            |
| ------ | ------------- |
| 구조 우선  | 헤더 계층이 곧 설계   |
| 간결성    | 짧은 문단         |
| 명확성    | 애매한 표현 제거     |
| 일관성    | 포맷, 코드 스타일 통일 |
| 자동화 가능 | lint/CI로 검증   |

---

# 📋 실전 체크리스트

* [ ] 문서 제목은 하나만 존재
* [ ] 헤더 계층이 논리적으로 정렬됨
* [ ] 코드 블록에 언어 지정
* [ ] 한 문단에 하나의 메시지
* [ ] README 필수 섹션 포함
* [ ] 링크 텍스트가 설명적임
* [ ] lint 통과

---
