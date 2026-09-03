# BizNote macOS App Store Connect Submission

## Release Choices

- Platform: macOS
- Bundle ID: `com.fakuku.biznote.mac`
- Version: `1.0`
- Build: `1`
- Price: Free
- Release mode: Automatic release after approval
- Primary metadata language: Korean
- Category: Productivity
- Secondary category: Business

## App Information

### Name

BizNote

### Subtitle

명함과 업무 기록을 한곳에서 관리

### Category

Productivity

### Secondary Category

Business

### Age Rating

일반 업무용 생산성 앱 기준으로 설문 작성. 사용자 생성 콘텐츠, 웹 브라우징, 도박, 폭력, 성인 콘텐츠가 없다면 낮은 연령 등급으로 산정될 가능성이 높음.

## Version Metadata

### Promotional Text

회의록, 업무일지, 전시회 기록, 명함 정보를 Mac에서 정리하고 iCloud로 관리하세요.

### Description

BizNote는 비즈니스 현장에서 필요한 노트와 명함 정보를 한곳에서 관리할 수 있는 macOS용 업무 기록 앱입니다.

회의록, 업무일지, 전시회 기록 등 업무 상황에 맞는 템플릿으로 기록을 빠르게 작성하고, 명함 이미지를 인식해 연락처 정보를 정리할 수 있습니다. 필요한 정보는 카테고리와 태그로 분류하고, iCloud를 통해 같은 계정의 기기에서 데이터를 관리할 수 있습니다.

주요 기능:

- 업무 노트, 회의록, 전시회 기록 작성
- 명함 이미지 인식 및 연락처 정보 정리
- 카테고리와 태그 기반 분류
- iCloud 기반 데이터 동기화
- 캘린더와 미리알림 연동
- PDF 및 스프레드시트 형식 내보내기

BizNote는 반복되는 업무 기록을 간결하게 정리하고, 현장에서 얻은 사람과 일정 정보를 놓치지 않도록 돕습니다.

### Keywords

비즈노트,업무노트,명함관리,회의록,업무일지,전시회,연락처,생산성,비즈니스,노트

### What's New

macOS용 BizNote 첫 출시입니다.

- 업무 노트와 회의록 작성
- 명함 인식 및 연락처 정리
- 전시회 기록 관리
- iCloud 동기화
- PDF 및 스프레드시트 내보내기

### Support URL

https://fakukulab.github.io/BizNoteforMac/support.html

### Marketing URL

https://fakukulab.github.io/BizNoteforMac/

### Privacy Policy URL

https://fakukulab.github.io/BizNoteforMac/privacy.html

### Copyright

© 2026 fakuku. All rights reserved.

## App Review Information

### Contact

TODO: App Store 심사 연락 담당자 이름, 전화번호, 이메일 입력

### Demo Account

Not required.

### Notes

BizNote는 업무 노트, 회의록, 전시회 기록, 명함 정보를 관리하는 macOS 생산성 앱입니다.

로그인은 필요하지 않습니다. iCloud 동기화 기능은 사용자의 Apple ID와 iCloud 설정을 사용합니다.

앱 권한 사용 목적:

- Camera: 명함을 촬영하고 텍스트를 인식하기 위해 사용합니다.
- Contacts: 검토한 명함 정보를 연락처에 저장하고 중복 여부를 확인하기 위해 사용합니다.
- Calendars: 행사 또는 회의 일정을 캘린더에 추가하기 위해 사용합니다.
- Reminders: 업무 항목을 미리알림에 추가하기 위해 사용합니다.
- Location: 회의 장소를 지도에서 찾기 위해 사용합니다.
- User Selected Files: 사용자가 선택한 위치로 PDF 또는 스프레드시트 파일을 내보내기 위해 사용합니다.

## App Privacy Draft

App Store Connect의 App Privacy는 실제 데이터 처리 방식에 맞게 최종 확인해야 합니다.

### Likely Data Types

- Contact Info: 명함 또는 연락처 정보를 사용자가 저장하는 경우
- User Content: 노트, 명함 이미지, 첨부파일, 업무 기록
- Location: 장소 검색 또는 현재 위치 기능을 사용하는 경우

### Tracking

No, unless a third-party analytics or advertising SDK tracks users across apps or websites.

### Data Linked to User

If data is stored only on the user's device or private iCloud container and not collected by the developer, App Store Connect answers may differ from data collected by the developer. Confirm before submission.

## Screenshot Plan

Upload macOS screenshots created from sample data only.

Recommended screenshots:

1. Main note list and note detail
2. Business card management or OCR result
3. Meeting minutes or work log template
4. Exhibition management screen
5. Export or iCloud settings screen

## Build Upload

Use the Xcode 26 Mac that successfully archives this project.

Archive for App Store Connect:

```sh
xcodebuild archive \
    -project BizNoteMac.xcodeproj \
    -scheme BizNoteMac \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath build/BizNoteMac-AppStore.xcarchive \
    -allowProvisioningUpdates
```

Upload the archive to App Store Connect:

```sh
xcodebuild -exportArchive \
    -archivePath build/BizNoteMac-AppStore.xcarchive \
    -exportPath build/AppStoreConnect \
    -exportOptionsPlist Distribution/ExportOptions-AppStoreConnect.plist \
    -allowProvisioningUpdates
```

After upload, wait for App Store Connect processing to finish, then select the processed build in the `1.0` macOS version page.

## Final Submit Checklist

- App record created for macOS
- Bundle ID selected: `com.fakuku.biznote.mac`
- Price set to Free
- Release mode set to Automatic
- Category set to Productivity
- Version metadata entered
- Screenshots uploaded
- Support URL entered
- Marketing URL entered
- Privacy Policy URL entered
- App Privacy completed
- Export Compliance completed
- Uploaded build selected
- App Review contact information entered
- Submit for Review clicked
