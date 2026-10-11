# 블루아워 HANDOFF

잠들기 전 60초 음성 일기를 AI가 '오늘의 하늘'로 번역하는 iOS 프라이빗 음성 일기 앱.
새 세션은 이 문서를 먼저 읽고, 세부는 각 단계의 코드/테스트와 Manyfast 기획(F-/S-/PL- 코드)을 근거로 확인한다.

작성 근거: `git log`, 현재 코드, Manyfast 기획. 코드에서 확인하지 못한 항목은 "⚠️ 확인 필요"로 표시한다.

---

## 1~4단계에서 합의된 규칙

### 1단계 — 하루 경계 / 오늘 탭
- **새벽 4시 하루 경계.** 0시~3시 59분은 아직 전날로 본다. (`Domain/BlueHourCalendar.swift`, `boundaryHour = 4`)
- `DiaryEntry.date`는 항상 "논리적 하루의 자정"으로 정규화해 저장하고, `createdAt`에는 실제 작성 시각을 둔다.
- 오늘 탭은 기존 기록 유무로 분기한다. 기록이 있으면 '오늘의 하늘'(또는 아직 그려지지 않은 하늘), 없으면 빈 하늘 + [오늘 말하기].
- 캘린더에서 과거 날짜를 고르면 그 날짜를 대상으로 기록할 수 있고, 미래 날짜는 기록 불가. 과거 날짜 진입 시 확인 시트를 거친다.
- **하루 1개 정책**: 대상 날짜에 기록이 있으면 신규 녹음을 시작하지 않는다(진입 단계 차단). (`RecordFlowViewModel.startRecording`)

### 2단계 — 녹음 견고화 / 음성 저장
- **3초 규칙**: 3초 미만은 저장하지 않는다. [저장하기] 시 미달이면 안내만 하고 녹음을 계속 유지한다. (`minimumDuration = 3`)
- 최대 녹음 길이 60초, 도달 시 자동 정지. (`maxDuration = 60`)
- 녹음 중 화면 자동 잠금 방지(`isIdleTimerDisabled`), 일시중지/이어서 하기 지원.
- **인터럽션 보존**: 전화 등 오디오 인터럽션(`AVAudioSession.interruptionNotification`)이나 백그라운드 진입 시 녹음을 정지하고 지금까지의 녹음을 보존한다(`state = .interrupted`). 복귀 후 [저장하기]/[다시 말하기]를 고른다. (`RecordFlowViewModel.handleInterruption`)
  - 백그라운드 진입 감지는 `RecordFlowView`의 `scenePhase == .background`에서 `handleInterruption()` 호출.
- **권한 안내**: 마이크 권한 거부 시 권한 안내 화면(`PermissionDeniedView`), 녹음 없이 직접 입력으로 전환 가능(`writeWithoutRecording`). 음성 인식 권한은 녹음 시작 시 함께 요청.
- **음성 저장 설정 반영**: 저장 시점의 `saveOriginalAudio` 값을 기준으로, '글과 하늘만 남기기'면 변환 후 음성 파일 삭제. 설정은 **소급 적용하지 않는다**(이미 저장된 기록 불변).
- 전체 삭제 시 SwiftData 기록과 함께 `Documents/Recordings`의 음성 파일도 삭제.

### 3단계 — AI 안전망 / 아직 그려지지 않은 하늘
- 온디바이스 Foundation Models로 '오늘의 하늘' 생성. (`FoundationModelSkyGenerator`, `@Generable GeneratedSky`)
- **안전망 흐름** (`SkyAnalysisService`, `SkyExpressionPolicy`):
  1. 1차 생성 → 위험(진단·평가·임상) 표현 없으면 그대로 반환.
  2. 위험 표현 감지 시 강화 instructions로 **1회만** 재생성.
  3. 재생성에도 남으면 **걸린 필드만 대체**(sanitize).
  4. 재생성 자체가 실패하면 1차 결과에서 걸린 필드만 대체.
  - 재생성은 최대 1회, `weatherType`은 언제나 유지.
- **아직 그려지지 않은 하늘**: 신규 흐름에서 AI를 쓸 수 없으면(`modelUnavailable`) 하늘 없이 글만 저장(`state = .savedWithoutSky`).
- **자동 분석**: AI를 다시 쓸 수 있게 되면 `PendingSkyAnalyzer`가 하늘이 비어 있는 기록을 자동으로 채운다. 앱 실행/포그라운드 복귀 시 `MainTabView`의 `.task`·`onChange(scenePhase == .active)`에서 실행하며, 중복 실행과 AI 미사용 상태는 스스로 막는다.
- 결과 카드: '회복의 신호' 표시, 날씨별 그라데이션(`SkyWeatherType+Appearance`).

### 4단계 — 하늘 상세 / 기록 관리
- **하늘 상세 메뉴**(`SkyDetailView`, `SkyDetailViewModel`)의 ··· 액션: **수정 / 다시 말하기 / 목소리 지우기 / 삭제**. 기록 변경은 이 상세 시트에서만.
- **목소리 재생**: 저장된 음성이 있을 때만 '그날의 목소리' 영역 노출, 재생(`AudioPlaybackController`). (S-OCQTHP)
- **목소리 지우기**(S-OZKPTH): 알림 본문은 `"하늘과 글은 그대로 남아요. 지운 목소리는 되돌릴 수 없어요."` (`SkyDetailView.swift`)
- **삭제**(F-MDQVXP): 알림 본문은 `"지운 기록은 되돌릴 수 없어요."`
- **다시 말하기(교체)**: 저장 시점에 대상 날짜의 기존 기록·음성을 새 기록으로 교체(`replaceExisting`). 녹음 시작/취소/확인 단계 이탈/앱 종료 시에는 기존 기록을 지우지 않고, **실제 저장 시점에만** 교체.
- **수정 후 재분석 실패 처리**: 수정 모드에서 재분석이 실패하면 고친 글은 저장하되 이전 하늘(analysis)은 그대로 유지한다. (`confirmAndAnalyze`의 editing 분기)

---

## 5단계 — 첫 실행 안내 + 프라이버시 ✅ 완료 (커밋됨)

관련 기획: F-SRJTXF(첫 실행 안내), F-JJFVFE(음성 저장 방식 선택), F-TNEYMY(Face ID 잠금).
상태: 빌드 성공, 전체 테스트 45개 통과(5단계 신규 18개 포함).

### 첫 실행 안내 (F-SRJTXF)
- 단계: ① 앱 소개 + 무료 30개 → ② 음성 저장 방식 선택 → ③ AI 미지원 안내(해당 기기만). 문구는 기획 display 그대로. (`Presentation/Onboarding/`)
- **`hasCompletedOnboarding`** (UserDefaults)으로 한 번만 표시. `complete()` 호출(마지막 단계) 시에만 기록하므로, 도중에 앱을 끄면 다음 실행 때 처음부터.
- **음성 저장 기본값은 true**('목소리 남기기'). F-SRJTXF display에 "'목소리 남기기'를 미리 선택해 둔다"로 명시 → `OnboardingViewModel.keepVoice = true`, `AppSettings` `saveOriginalAudio` 기본값 true. 고른 값으로 `saveOriginalAudio` 저장.
- **③은 `deviceNotEligible`일 때만** 보여준다. `isAvailable()`(AI 꺼짐·모델 준비중까지 false)이 아니라, 하드웨어 미지원(`SystemLanguageModel.Availability.unavailable(.deviceNotEligible)`)만 가려낸다. → `GeneratedSkyProducing.isDeviceEligible()` / `SkyAnalysisServiceProtocol.isDeviceEligible()` 추가.

### 음성 저장 방식 선택 (F-JJFVFE)
- 나 탭 '음성' 섹션: '목소리 남기기 / 글과 하늘만 남기기' 선택(Picker). footer에 `"새로 만드는 기록부터 적용돼요. 지난 기록은 그대로예요."`
- 설정 변경은 소급 적용하지 않음(기존 2단계 저장 로직 그대로 재사용).

### Face ID 잠금 (F-TNEYMY) — `Presentation/Lock/`, `Presentation/RootView.swift`
- 인증 정책은 **`.deviceOwnerAuthentication`** — Face ID가 실패해도 기기 암호로 해제 가능. (`BiometricAuthenticator`)
- **앱 전환기 덮개 조건**: `useFaceIDLock && scenePhase != .active` → 내용을 가리는 덮개(`Color.bhBackground`). `isLocked`이면 `LockView`가 우선. 잠금 OFF 상태에서 켜기 인증 중에는 덮개가 나오지 않는다(`useFaceIDLock`이 아직 false).
- **`isLocked` 전환은 `.background`에서만**(`AppLockController.enterBackground`). `.inactive`로는 잠그지 않는다.
- **Face ID 팝업으로 생기는 `.inactive`→`.active` 복귀에서는 재인증/반복 없음**: `pendingBackgroundReturn` 플래그를 `.background`에서만 세우고 `consumeBackgroundReturn()`으로 소비. `isAuthenticating` 가드로 중복 호출 차단.
- **잠금 켤 때 인증**: 나 탭 토글 켜기는 한 번 인증 성공해야만 켜진다(`SettingsViewModel.requestFaceIDLock`). 실패 시 꺼진 채 유지.
- **기기 암호 삭제 시**: 해제 시도에서 `canAuthenticate() == false`면 잠금을 풀고 `useFaceIDLock`도 false로 저장(영구 잠김 방지). 켜기 시도 시 암호/Face ID 없으면 `"기기에 암호를 설정하면 잠금을 사용할 수 있어요."` 안내.
- **2단계 인터럽션과의 순서**: 잠금은 `RootView`의 ZStack 오버레이라 `RecordFlowView`를 트리에서 제거하지 않는다. 따라서 백그라운드 진입 시 RecordFlowView의 녹음 정지·보존과 잠금이 **독립적으로** 동작하고, 복귀 시 인증을 먼저 요구한 뒤 보존된 녹음 화면이 드러난다.
- ⚠️ **`NSFaceIDUsageDescription`은 사용자가 직접 추가**한다(이번 작업에서 pbxproj 미수정).
  - Build Settings 키: `INFOPLIST_KEY_NSFaceIDUsageDescription`
  - 문구: `오늘의 기록을 나만 볼 수 있도록 Face ID로 잠가요.`
  - ⚠️ 확인 필요: 이 키가 실제로 빌드 설정에 들어갔는지(미입력 시 실기기에서 Face ID 평가 크래시 가능).

### 5단계 신규/수정 파일
- 신규: `Presentation/Onboarding/OnboardingViewModel.swift`, `OnboardingView.swift`, `Presentation/Lock/AppLockController.swift`, `LockView.swift`, `Presentation/RootView.swift`, `BlueHourTests/OnboardingLockTests.swift`
- 수정: `App/AppSettings.swift`(hasCompletedOnboarding), `App/BlueHourApp.swift`(RootView 진입), `Presentation/Settings/SettingsView.swift`·`SettingsViewModel.swift`, `Domain/Services/GeneratedSkyProducing.swift`·`SkyAnalysisServiceProtocol.swift`, `Data/Persistence/Services/FoundationModelSkyGenerator.swift`·`SkyAnalysisService.swift`, `BlueHourTests/Fakes.swift`
- 테스트: 전체 45개 통과(5단계 신규 18개 포함).

---

## 남은 단계

- **6단계 — 구매 · 무료 30개 카운트**: 하늘 30개까지 무료, 이후 한 번 구매로 평생 이용. **다시 말하기(교체)와 가져오기는 카운트 제외.**
  - 코드 근거: `RecordFlowViewModel.save`에 `TODO(6단계·무료 하늘 카운트)` — `replaceExisting == true` 저장은 카운트 증가 대상에서 제외.
  - ⚠️ 확인 필요: 과금/상품 ID·StoreKit 구성, 카운트 저장 위치.
- **7단계 — 밤 리마인더**: 잠들기 전 알림. ⚠️ 확인 필요(알림 시각·권한 흐름·문구).
- **8단계 — 내보내기 · 가져오기**: 나 탭 '데이터 내보내기' 버튼은 현재 자리만 있음(`SettingsView`, 동작 없음). ⚠️ 확인 필요(포맷·가져오기 시 카운트 처리).
- **9단계 — 다크 모드**: 디자인 토큰(`BlueHourColors`)의 다크 매핑 미정. ⚠️ 확인 필요(토큰 매핑 규칙).
