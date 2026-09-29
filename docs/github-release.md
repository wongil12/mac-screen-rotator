# GitHub Releases 배포

## 지원 대상

- macOS 26.0 이상
- Apple Silicon MacBook
- M5 MacBook Pro / macOS 26.2에서 검증

현재 릴리스 번들은 arm64 전용이며 Intel Mac은 지원하지 않는다.

## 저장소 Secrets

GitHub 저장소의 **Settings → Secrets and variables → Actions**에 다음 secrets를 등록한다.

| Secret | 내용 |
|---|---|
| `DEVELOPER_ID_CERTIFICATE_BASE64` | Developer ID Application 인증서 `.p12`의 Base64 |
| `P12_PASSWORD` | `.p12` 내보내기 암호 |
| `KEYCHAIN_PASSWORD` | Actions 임시 Keychain 암호 |
| `MAC_ROTATOR_SIGNING_IDENTITY` | `Developer ID Application: 이름 (TEAMID)` |
| `APPLE_API_KEY_BASE64` | App Store Connect API `.p8` 키의 Base64 |
| `APPLE_API_KEY_ID` | App Store Connect API Key ID |
| `APPLE_API_ISSUER_ID` | App Store Connect Issuer ID |

Base64 값 생성 예시:

```bash
base64 -i DeveloperIDApplication.p12 | pbcopy
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

## 첫 릴리스

CI가 `master` 브랜치에서 통과한 뒤 태그를 푸시한다.

```bash
git tag -a v0.1.0 -m "Mac Screen Rotator 0.1.0"
git push origin v0.1.0
```

`Release` workflow가 다음 작업을 수행한다.

1. Swift 테스트
2. Developer ID 인증서 가져오기
3. 앱과 helper 서명
4. 앱 공증 및 ticket stapling
5. 설치용 DMG 생성
6. DMG 공증
7. SHA-256 체크섬 생성
8. GitHub Release 생성 및 파일 업로드

사용자가 다운로드할 파일은 `Mac-Screen-Rotator-v0.1.0.dmg`다.

## 인증서 없이 시험

일반 `CI` workflow는 ad-hoc 서명된 앱을 Actions artifact로 제공한다. 이 파일은 개발 시험용이며 공개 배포용이 아니다. 공개 다운로드에는 반드시 `Release` workflow가 만든 공증된 DMG를 사용한다.
