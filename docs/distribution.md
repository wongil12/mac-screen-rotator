# 직접 배포 가이드

## 로컬 앱 번들 생성

```bash
chmod +x scripts/build-app.sh scripts/notarize-app.sh
scripts/build-app.sh
```

결과물은 `dist/Mac Screen Rotator.app`이다. Developer ID 인증서 환경 변수를 지정하지 않으면 로컬 시험용 ad-hoc 서명을 사용한다.

Developer ID 서명:

```bash
MAC_ROTATOR_SIGNING_IDENTITY="Developer ID Application: Example (TEAMID)" scripts/build-app.sh
```

앱은 MIT 라이선스인 `displayplacer` 실행 파일과 라이선스 문서를 `Contents/Helpers` 및 `Contents/Resources`에 포함한다.

## 공증

먼저 Apple 자격 증명을 Keychain 프로필로 저장한다.

```bash
xcrun notarytool store-credentials mac-screen-rotator-notary
scripts/notarize-app.sh mac-screen-rotator-notary
```

스크립트는 ZIP 생성, 공증 제출 및 대기, ticket stapling, Gatekeeper 검증을 순서대로 수행한다.

## 배포 전 체크리스트

- Developer ID Application 인증서로 앱과 helper 서명
- Hardened Runtime 적용 확인
- 공증 성공 및 staple 확인
- 깨끗한 Mac 사용자 계정에서 최초 실행 확인
- macOS 15 및 macOS 26 시험
- 오픈소스 라이선스 포함 확인
- 자동 업데이트 서명 키 준비

## GitHub Releases

태그 기반 GitHub Actions 배포 흐름과 필요한 저장소 Secrets는 [`github-release.md`](github-release.md)를 참고한다.

실제 Developer ID 서명과 Apple 공증은 해당 Apple Developer 인증서 및 계정 자격 증명이 있는 환경에서만 완료할 수 있다.
