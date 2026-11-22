# My Paint

[Português (Brasil)](../../README.md) · [English](en.md) · [Español](es.md) · [Français](fr.md) · [Deutsch](de.md) · [Italiano](it.md) · [日本語](ja.md) · **한국어**

Windows 7의 그림판에서 영감을 얻은 macOS용 간단한 이미지 편집기입니다. 이미지를 열고 연필, 브러시, 도형, 텍스트로 그린 뒤, 손에 익은 단축키로 PNG, JPEG, BMP, GIF로 저장하세요.

## macOS용 다운로드

- **[Apple Silicon(M 시리즈)용 다운로드](https://github.com/leoars/my-paint/releases/download/0.1.0/My-Paint-0.1.0-arm64.pkg)**
- **[Intel용 다운로드](https://github.com/leoars/my-paint/releases/download/0.1.0/My-Paint-0.1.0-x86_64.pkg)**

macOS 12 이상이 필요합니다. [최신 릴리스 보기](https://github.com/leoars/my-paint/releases/latest)

![한국어 My Paint 윈도우. 홈 탭과 빈 캔버스가 보입니다.](../screenshots/ko-window.png)

## 이 프로젝트를 만든 이유

My Paint는 My Notepad와 같은 그리움에서 시작했습니다. Windows에서 Mac으로 옮기고 나면, 윈도우 하나와 도구 리본, 빈 캔버스만 있으면 되는 이미지 편집기가 아쉬워집니다. 이 프로젝트는 그 작업 방식을 외부 의존성 없이 Swift와 AppKit으로 되살립니다. 제목 표시줄과 메뉴 막대는 macOS의 것이고, 리본부터 아래는 모두 Windows 7 그림판을 따릅니다. 아이콘, 질감, 문구는 모두 처음부터 새로 그리고 썼습니다.

## 일상적인 사용

- **도구:** 연필, 지우개, 색 채우기, 색 선택, 돋보기, 텍스트. 왼쪽 버튼은 색 1로, 오른쪽 버튼은 색 2로 그립니다.
- **브러시:** 브러시, 캘리그래피 브러시 1과 2, 에어브러시, 유화 브러시, 크레용, 마커, 자연스러운 연필, 수채화 브러시. 브러시마다 크기가 따로 있습니다.
- **도형:** 갤러리의 23가지 전부. 선과 곡선부터 화살표, 별, 말풍선, 하트, 번개까지 있습니다. 윤곽선과 채우기(단색 또는 질감)를 고르고, 핸들로 조정한 뒤 바깥을 클릭하면 확정됩니다. `Shift`를 누르고 있으면 비율이나 각도가 유지됩니다.
- **선택:** 사각형 또는 자유형으로 선택하며, 투명하게 선택, 이동, 복제, 앱 간 잘라내기·복사·붙여넣기를 지원합니다. 자르기, 크기 조정 및 기울이기, 회전 또는 대칭 이동, 색 반전은 선택 영역이나 이미지 전체에 적용됩니다.
- **보기:** 12.5%에서 800%까지 확대/축소, 눈금자, 눈금선, 전체 화면, 미리 보기, 상태 표시줄.
- **인쇄, 이미지 속성, 색 편집**(팔레트에 사용자 지정 칸 10개), 최근 그림, **데스크탑 배경으로 설정**.
- **인터페이스 텍스트 크기**는 네 단계이며, 고해상도 디스플레이를 위해 보기 탭과 **My Paint → 설정…**에서 바꿀 수 있습니다.
- 포르투갈어, 영어, 스페인어, 프랑스어, 독일어, 이탈리아어, 일본어, 한국어를 지원합니다.

![23가지 도형이 모두 보이는 도형 갤러리.](../screenshots/shapes.jpg)

### 알아 두면 좋은 단축키

`Ctrl` 단축키는 Windows와 같은 방식으로 동작하며, `Cmd`로도 같은 동작을 할 수 있습니다.

| 키 | 동작 |
| --- | --- |
| `Ctrl+Z` · `Ctrl+Y` | 실행 취소와 다시 실행(50단계) |
| `Ctrl+A` · `Ctrl+C` · `Ctrl+X` · `Ctrl+V` | 모두 선택, 복사, 잘라내기, 붙여넣기 |
| `Ctrl+W` | 크기 조정 및 기울이기 |
| `Ctrl+Shift+X` · `Ctrl+Shift+I` | 자르기와 색 반전 |
| `Ctrl++` / `Ctrl+-` | 선 굵기 늘리기 또는 줄이기 |
| `Ctrl+B` · `Ctrl+I` · `Ctrl+U` | 텍스트의 굵게, 기울임꼴, 밑줄 |
| `Ctrl+R` · `Ctrl+G` · `F11` | 눈금자, 눈금선, 전체 화면 |
| `Ctrl+E` · `Ctrl+P` | 이미지 속성과 인쇄 |
| `Shift+F10` | 컨텍스트 메뉴 |

## Mac에서 빌드하고 설치하기

빌드하려면 Swift 컴파일러가 포함된 Apple 개발 도구가 필요합니다. 프로젝트 루트에서 다음을 실행하세요.

```sh
./build.sh
open "My Paint.app"
```

자동 테스트를 실행하려면:

```sh
./test.sh
```

두 가지 설치 프로그램을 만들려면 아래 명령을 실행하세요. `dist/`에서 Apple Silicon에는 `arm64`, Intel에는 `x86_64` 패키지를 고릅니다. `.pkg` 파일을 열면 앱이 `/Applications`에 설치됩니다.

```sh
./package.sh
```

아이콘은 `Tools/icon.swift`의 코드로 그립니다. 다시 만들려면 `swift Tools/icon.swift Resources/MyPaint.icns`를 실행하세요.

## 기여하기

도구, 리본, 대화 상자는 [Swift](../../Sources)로 작성했고, 테스트는 [Tests](../../Tests)에 있습니다. [번역](../../Resources)은 언어별 `.lproj` 폴더에 있습니다. 문제를 알릴 때는 macOS 버전, 사용한 도구, 그리고 가능하면 문제를 재현하는 작은 이미지를 함께 보내 주세요.

## 라이선스

이 프로젝트의 고유한 코드와 문서는 [Apache License 2.0](../../LICENSE)에 따라 배포됩니다. Paint, Windows, Microsoft는 Microsoft Corporation의 상표이며, 이 프로젝트는 해당 회사와 관련이 없습니다. [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md)를 참고하세요.
