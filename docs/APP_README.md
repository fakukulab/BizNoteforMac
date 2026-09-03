# BizNote for Mac

macOS 전용 SwiftUI 앱. iOS BizNote 앱과 **동일한 CloudKit 컨테이너**를 통해 노트·명함이 자동 동기화됩니다.

- CloudKit 컨테이너: `iCloud.com.fakuku.biznote` (iOS 앱과 공유)
- Bundle ID: `com.fakuku.biznote.mac`
- Team ID: `8S2Y83DCGM`
- 최소 macOS: 15.0 Sequoia
- Xcode 27+, Swift 5.10

## 프로젝트 생성

```bash
# XcodeGen (Homebrew) 필요
brew install xcodegen

# .xcodeproj 재생성 (project.yml 변경 시)
xcodegen generate
```

## 빌드

```bash
# 컴파일 검증 (서명 없이)
xcodebuild -project BizNoteMac.xcodeproj \
  -scheme BizNoteMac -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build
```

## 실행 (CloudKit 포함)

CloudKit이 작동하려면 반드시 Xcode에서 서명이 필요합니다.

1. Xcode에서 `BizNoteMac.xcodeproj`를 엽니다.
2. **Xcode → Settings → Accounts**에서 Team `8S2Y83DCGM` (fakuku) 계정으로 로그인합니다.
3. Signing & Capabilities에서 자동 서명이 활성화된 것을 확인합니다.
4. **⌘R**로 실행합니다. 첫 실행 시 macOS iCloud 로그인 여부를 확인하세요 (동일 Apple ID면 iOS와 자동 동기화).

## 주요 단축키

| 단축키 | 동작 |
|---|---|
| ⌘N | 새 노트 |
| ⌘D | 명함 사진 불러오기 (Inspector 자동 open) |
| ⌘E | 내보내기 시트 |
| ⌘, | 환경설정 |
| ⌘⌥I | 명함 Inspector 토글 |
| ⌘⌃S | 사이드바 토글 |
| ⌘1~⌘3 | 카테고리 이동 (업무일지/회의록/전시회) |

## 구조

- `Models/` — iOS와 완전히 동일한 5개 SwiftData `@Model` (`Note`, `BusinessCard`, `CustomCategory`, `ExhibitionPreset`, 그리고 템플릿 struct들). `CustomCategory`만 `#if canImport(UIKit) / AppKit` 조건부 컴파일로 크로스플랫폼 처리.
- `Views/Sidebar/` — 스마트 폴더 + 카테고리 + 뱃지 카운트 + iCloud 상태.
- `Views/NoteList/` — `@Query`, `.searchable`, 정렬 메뉴, 컨텍스트 메뉴(즐겨찾기/복제/삭제).
- `Views/NoteDetail/` — 자동 저장 에디터 + 카테고리별 템플릿(WorkLog/Meeting/Exhibition) + 태그.
- `Views/BusinessCard/` — 드래그&드롭 + `NSOpenPanel` + Vision OCR + 파싱 + 결과 편집 폼.
- `Views/Export/` — CSV 내보내기(UTF-8 BOM, `NSSavePanel`).
- `Views/Settings/` — 일반/카테고리/iCloud/내보내기/정보 5탭 (macOS `Settings` scene).
- `Services/` — `OCRService`(Vision, 한/영/중), `BusinessCardParser`(정규식), `ExcelExportService`, `CloudSyncService`(원격 변경 감지).

## CloudKit 스키마 주의

iOS와 완전히 동일해야 합니다. iOS `/Users/kimjyun/Developer/BizNote/BizNote/Models/`의 파일이 정본이며, `CustomCategory.swift`만 Mac용으로 조건부 컴파일 처리했습니다. iOS에서 `@Model` 프로퍼티를 추가/변경하면 반드시 Mac 쪽에도 동일하게 반영하세요.

## 알려진 제한

- 첫 CloudKit 실행 전 반드시 Xcode에서 Apple ID 로그인 필요 (CLI에서 자동 프로비저닝 불가).
- OCR 정확도는 명함 사진 해상도(가로 1000px 이상 권장)에 크게 좌우됩니다.
- iCloud Drive에 명함 원본 이미지 저장(공유 시) 기능은 현재 App Sandbox의 Application Support 로컬 경로만 사용합니다. 필요 시 `AttachmentStorage` 수정.
