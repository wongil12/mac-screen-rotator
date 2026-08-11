# Mac Screen Rotator

MacBook 내장 디스플레이를 0°, 90°, 180°, 270°로 회전시키는 macOS 메뉴 막대 앱 프로젝트다.

현재는 하드웨어와 macOS 호환성을 확인하는 0단계 PoC를 진행한다. 전체 계획은 [`docs/plan.md`](docs/plan.md)를 참고한다.

## PoC 안전 원칙

실제 회전 시험은 원래 각도를 기록하고 별도 복구 프로세스를 시작한 다음 수행한다. 기본적으로 15초 후 원래 방향으로 돌아온다.

## 실행

요구 사항:

- macOS 15 이상
- Xcode Command Line Tools
- `brew install displayplacer`

```bash
swift build
.build/debug/screen-rotator-poc inspect
.build/debug/screen-rotator-poc rotate-test 90
```

`rotate-test`는 0, 90, 180, 270 중 하나를 받는다. 현재 각도와 같은 값은 시험하지 않는다. 목표 각도를 3초간 유지한 뒤 원래 각도로 복구하며, 별도 프로세스가 15초 후 한 번 더 원복을 보장한다.
