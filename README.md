# UWB_capstone

캡스톤 디자인
UWB기반 출입 통제 시스템
---
## 구조
* 출입 통제 : 라즈베리파이
* uwb 통신
    * IOS - nrf52840 + dwm3000evb
    * Android - esp32 + dw3000
* 연결 구조

| 태그 | 앵커 |
|------|------|
| IOS | nrf52840 + dwm3000evb |
| Android + esp32 | esp32 |


---
## 개발환경
* IOS : xcode
* Android : Andriod studio
* esp32 : ArduinoIDE
* nrf52840 : SEGGER Embedded Studio
* raspberry pi : visual studio

---
## 각 기기의 역할
* dwm3000evb : uwb모듈이 장착된 개발보드, 앵커로 설치하여 u1 또는 u2칩이 적용된 IOS기기와 통신하는데 사용
* nrf52840 : dwm3000evb과 결합하여 IOS기기와 통신, BLE를 이용하여 초기 연결 설정
* IOS 기기 : nrf52840 + dwm3000evb와 통신, BLE를 통해 세션을 생성한 뒤 uwb 통신을 통해 거리측정 가능
* esp32 : uwb 모듈이 장착된 esp32를 통해 앵커로 설치된 esp32와 태그용 esp32간 거리 측정 가능
* Android 기기 : usb 시리얼 통신을 통해 esp32간 측정된 거리를 받아와 화면에 표시
* raspberry pi : DB 및 서버로 사용, 각 스마트폰 기기가 보내는 정보를 받아 문이 열리도록 함.
