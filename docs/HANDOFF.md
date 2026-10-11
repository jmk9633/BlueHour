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

## 6단계 — 구매 · 무료 30개 카운트 ✅ 완료 (커밋됨)

관련 기획: R-GPTAFT, F-XUQOXA(무료 카운트), F-MVCMCF(구매 화면), F-WURMKT(구매 복원), PL-OBQXIP(정책). 연동: F-LKCUBW/F-PVXAMM(새 기록 입구), F-MDQVXP(삭제 문구), F-SAZNQX(나 탭·버전), F-LLFPXL(하늘 없이 저장도 +1).
상태: 빌드 성공, 전체 테스트 60개 통과(6단계 신규 15개 포함).

### 무료 하늘 카운트 (F-XUQOXA / PL-OBQXIP)
- **키체인 저장**(`KeychainFreeSkyCountStore`): `kSecAttrAccessibleAfterFirstUnlock`, `kSecAttrSynchronizable = false`. 앱 재설치·전체 삭제에도 유지되고 **감소 API 없음**(삭제해도 안 줄어듦). `FreeSkyCounter`(limit=30)가 보관·증가 담당.
- **+1 시점**: `RecordFlowViewModel.save`의 **신규 저장 경로에서만**(오늘·과거·텍스트로 쓰기·하늘 없이 저장 포함). **제외**: 수정(`editingEntry` → update), 다시 말하기(`replaceExisting`), 자동 분석(`PendingSkyAnalyzer`는 update만), 분석·저장 실패, 녹음 취소.
- **30번째 결과 카드 안내 1회**: `reachedFreeLimitNotice` → `ResultView`/`UndrawnSkyResultView` 하단 `"무료로 담을 수 있는 하늘을 모두 채웠어요."`. `AppSettings.Keys.hasShownFreeLimitNotice`로 1회 가드.

### 새 기록 입구 게이트 (사용자 합의)
- **공통 함수 `NewEntryGate.canStartNewEntry(entitlement:counter:)`** 를 입구 3곳에서 호출: ① 오늘 탭 [오늘 말하기](`RecordFlowViewModel.beginRecording`) ② 텍스트로 쓰기(`beginTextWriting`, `PermissionDeniedView`) ③ 하늘 달력 빈 과거 날짜(`SkyCalendarView` 탭 → 확인 알림보다 **먼저**).
- **권한 요청보다 먼저** 확인한다. 한도 도달·미구매면 녹음 대신 구매 화면(`showPurchase`)을 매번 연다.
- **구매 여부 확인 전 대기**: `PurchaseController.waitUntilReady()`로 앱 시작 직후 확인이 끝날 때까지 기다린 뒤 판단(구매자가 열자마자 구매 화면 보지 않도록).
- **안전망**: `startRecording()`에도 동일 게이트를 남겨 우회 진입을 막는다. 수정·다시 말하기는 게이트 제외.
- 구매 성공 후 원래 입구 동작으로 이어감: 녹음(`resumeAfterPurchase`)/텍스트 화면/해당 날짜 기록(캘린더는 `recordTarget`).

### 구매 (StoreKit 2)
- 비소모성 상품 1개 `academy.credo.BlueHour.lifetime`, 가족 공유 미사용. 프로토콜 `PurchaseServiceProtocol`로 감싸 Fake 테스트. 실제 구현 `StoreKitPurchaseService`(currentEntitlements·updates·AppStore.sync).
- `PurchaseController`(@Observable): `isUnlocked`, `displayPrice`(가격 하드코딩 금지 — `Product.displayPrice`), 구매/복원/승인대기 상태. 앱 실행 시 `start()`로 권한 확인+업데이트 청취(`DIContainer.init`).
- 구매 화면(`PurchaseView`): 제목 `"앞으로의 밤도 하늘로 남겨볼까요?"`, `"한 번 구매로 평생 이용"`, [평생 이용하기], [구매 복원], 이용약관·개인정보 링크. AI 미지원 문구는 **`isDeviceEligible()`(5단계)** 로 판별.
- 구매 복원 문구(F-WURMKT): `"평생 이용권을 다시 불러왔어요."` / `"불러올 구매 내역이 없어요."` / 오류 시 `"잠시 후 다시 시도해 주세요."`.

### 나 탭 · 삭제 문구
- 나 탭(`SettingsView`): 미구매 `"무료로 담은 하늘 N / 30"`(탭 → 구매 화면), 구매 후 **카운트 숨기고 `"평생 이용 중"`만**. [구매 복원] 항목. 앱 정보는 번들 버전(`CFBundleShortVersionString`).
- 삭제 모달(`SkyDetailView`, F-MDQVXP): 미구매자에게 본문에 `"지워도 무료로 담은 하늘 수는 줄어들지 않아요."` 추가.

### 사용자가 직접 할 설정 (pbxproj/scheme 미수정)
- ⚠️ **In-App Purchase capability 추가**: 타깃 BlueHour → Signing & Capabilities → + Capability → In-App Purchase.
- ⚠️ **Scheme에 StoreKit Configuration 지정**: Edit Scheme → Run → Options → StoreKit Configuration → `BlueHour.storekit`.
- (심사 전) App Store Connect에 같은 상품 ID로 비소모성 상품 등록.

### ⚠️ 미결 항목
- **이용약관·개인정보처리방침 URL이 임시값**(`Domain/Purchase/LegalLinks.swift`, `https://example.com/...`) — 실제 주소로 교체 필요.
- **평생 이용권 가격 미정**(PL-OBQXIP): `BlueHour.storekit`은 임시 가격(4,400).

### 6단계 신규/수정 파일
- 신규: `Domain/Purchase/{PurchaseTypes,FreeSkyCounting,FreeSkyCounter,NewEntryGate,LegalLinks}.swift`, `Data/Persistence/Services/{KeychainFreeSkyCountStore,StoreKitPurchaseService}.swift`, `Presentation/Purchase/{PurchaseController,PurchaseView}.swift`, `BlueHourTests/PurchaseCountTests.swift`, `BlueHour.storekit`.
- 수정: `App/{AppSettings,DIContainer}.swift`, `Presentation/RecordFlow/{RecordFlowViewModel,RecordFlowView,TodayView,PermissionDeniedView,ResultView,UndrawnSkyResultView}.swift`, `Presentation/SkyCalendar/{SkyCalendarView,SkyCalendarViewModel,SkyDetailView}.swift`, `Presentation/Settings/{SettingsView,SettingsViewModel}.swift`, `BlueHourTests/{Fakes,OnboardingLockTests}.swift`.

---

## 7단계 — 밤 리마인더 알림 ✅ 완료 (커밋됨)

관련 기획: F-LDUDEX(밤 리마인더), PL-OZYYZI(정책). 연동: F-FJEWRI/F-LLFPXL(첫 기록 제안 위치), F-XUQOXA(무료 30개), PL-SSBBVZ(새벽 4시 경계).
상태: 빌드 성공, 전체 테스트 77개 통과(7단계 신규 17개 포함).

### 예약 방식 (PL-OZYYZI)
- **개별 예약**: 매일 반복 알림이 아니라 앞으로 **7일 치를 하루에 하나씩** 개별 예약(`NightReminderScheduler`, `maxScheduled = 7`).
- **재예약 함수 하나**(`reschedule()`): 기존 리마인더 예약을 **모두 취소**한 뒤, 기록이 없는 논리 날짜에만 새로 예약. 식별자는 논리 날짜 기준 `night-reminder-yyyy-MM-dd`(날짜별 취소 가능).
- **재예약 시점**: 앱 실행·포그라운드 복귀(`MainTabView.refreshFromSystem`), 오늘 기록 저장·삭제·다시 말하기(`RecordFlowViewModel.save`, `SkyDetailViewModel.deleteEntry`, 전체 삭제), 리마인더 켜기·끄기·시간 변경(`NightReminderController`), 구매 완료(`PurchaseController.onUnlock` → reschedule).
- **문구 3종**(PL-OZYYZI display 그대로)을 논리 날짜에 따라 번갈아 사용. **제목은 비우고 body에만** 넣어 iOS가 헤더에 앱 이름을 표시(기획에 없는 제목 문구를 짓지 않음). 배지 미사용, 권한은 `[.alert, .sound]`만.

### 날짜 규칙 (PL-SSBBVZ 재사용)
- `BlueHourCalendar`(새벽 4시 경계) 재사용. 알림 시각 ≥4시면 그 논리 날짜 당일, **0:00~3:59면 다음 캘린더 새벽**에 발송(= 전날 논리 날짜의 알림, 전날 기록 없을 때만).
- 오늘 기록이 있으면 오늘 알림 없음. 과거 날짜 기록은 미래 방향 순회라 예약에 영향 없음. 이미 지난 시각은 예약하지 않음.

### 예외
- **무료 30개 채운 미구매자**: 예약하지 않음(토글은 켜진 채). 구매하면 다시 예약. 게이트 판단 전 `entitlement.waitUntilReady()`로 **구매 확인을 기다린 뒤** 판단(구매자 알림이 잘못 지워지지 않게).
- **권한 꺼짐**: `provisional`·`ephemeral`은 `authorized`로 취급. `denied`/`notDetermined`면 예약 안 함. 포그라운드 복귀 시 권한이 꺼져 있으면 나 탭 토글을 **꺼진 상태로** 표시(`refreshFromSystem`).
- **토글 켜기인데 권한 거부**: `설정에서 알림을 허용해 주세요.` + [설정 열기](`SettingsView`, `openSettingsURLString`).

### 첫 기록 제안 (F-LDUDEX / F-FJEWRI / F-LLFPXL)
- 첫 기록의 결과 카드(`ResultView`)와 '아직 그려지지 않은 하늘' 결과 화면(`UndrawnSkyResultView`)의 [오늘은 여기까지] 위에 `ReminderPromptView`로 한 번 표시. 문구 `내일 밤에도 하늘을 남길 수 있게 알려드릴까요?` + [알려주세요]/[괜찮아요].
- 가드: `hasShownReminderPrompt` + 이미 리마인더가 켜져 있으면 표시 안 함. **제안이 표시되는 순간**(`markPromptShown`) 가드를 세워, 버튼을 누르지 않고 닫아도 다시 뜨지 않음(사용자 합의).
- [알려주세요]일 때만 권한 요청. [괜찮아요]/거부면 다시 제안 안 함(가드가 이미 섬). 수정·다시 말하기 결과에는 제안하지 않음.

### 알림 탭·표시
- 알림을 누르면 오늘 탭으로 전환(`TabRouter.selection = 0`, `ReminderNotificationDelegate`). Face ID 잠금은 `RootView` 오버레이가 독립적으로 먼저 요구.
- 포그라운드에서 알림 시각이 되면 배너 미표시(`willPresent` → `[]`). 앱 아이콘 배지 미사용.

### 테스트 (프로토콜 + Fake)
- `NotificationScheduling`(UNUserNotificationCenter 래퍼)와 현재 시각(`now: () -> Date`)을 주입해 `FakeNotificationScheduler`로 결정적 검증.
- 커버: 오늘 기록 유무, 0~4시 시각 매핑, 지난 시각 제외, 7개 상한, 30개 미구매자 예약 없음→구매 후 예약, 권한 꺼짐, 토글 꺼짐, 오늘 기록 삭제 후 재예약, 과거 날짜 무영향, 재예약이 기존 예약 먼저 취소, 문구 3종 번갈아, 첫 기록 제안 1회·이미 켜짐이면 미제안·수락 시 켜짐+예약, 토글 켜기 권한거부 안내, 포그라운드 복귀 권한 꺼짐 반영.

### 사용자가 직접 할 설정
- **없음.** 로컬 알림은 Info.plist 키·capability가 필요 없다(권한은 런타임 `requestAuthorization`). `project.pbxproj` 미수정.

### 7단계 신규/수정 파일
- 신규: `Domain/Reminder/{NightReminderScheduling,NightReminderScheduler}.swift`, `Presentation/Reminder/{NightReminderController,ReminderNotificationDelegate,ReminderPromptView}.swift`, `Data/Persistence/Services/SystemNotificationScheduler.swift`, `BlueHourTests/NightReminderTests.swift`.
- 수정: `App/{AppSettings,DIContainer}.swift`, `Presentation/Purchase/PurchaseController.swift`(onUnlock), `Presentation/MainTabView.swift`(TabRouter 바인딩·refresh), `Presentation/RecordFlow/{RecordFlowViewModel,RecordFlowView,ResultView,UndrawnSkyResultView}.swift`, `Presentation/SkyCalendar/{SkyDetailView,SkyDetailViewModel}.swift`, `Presentation/Settings/{SettingsView,SettingsViewModel}.swift`, `BlueHourTests/{Fakes,OnboardingLockTests}.swift`.

---

## 남은 단계

- **8단계 — 내보내기 · 가져오기**: 나 탭 '데이터 내보내기' 버튼은 현재 자리만 있음(`SettingsView`, 동작 없음). ⚠️ 확인 필요(포맷·가져오기 시 카운트 처리).
- **9단계 — 다크 모드**: 디자인 토큰(`BlueHourColors`)의 다크 매핑 미정. ⚠️ 확인 필요(토큰 매핑 규칙).
