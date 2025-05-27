# ThinQ

A new Flutter project.

## 하드웨어 연동 버전

이 앱은 하드웨어에서 타이머 데이터를 받아와서 표시하고, 캐릭터 상태와 할일 진행률을 하드웨어로 전송합니다.

### 🚀 테스트 서버 실행하기

1. **Python 환경 설정**
```bash
pip install -r requirements.txt
```

2. **테스트 서버 실행**
```bash
python test_server.py
```

서버가 `http://localhost:8080`에서 실행됩니다.

### 📱 Flutter 앱 실행하기

#### 방법 1: 배치 파일 사용 (Windows)
```bash
run_chrome.bat
```

#### 방법 2: PowerShell 스크립트 사용
```powershell
.\run_chrome.ps1
```

#### 방법 3: 직접 명령어 실행
```bash
flutter run -d chrome
```

### 🔗 하드웨어 연동 API

#### 타이머 데이터 받아오기 (GET)
```
GET /timer
```
응답:
```json
{
  "isRunning": true,
  "seconds": 1234,
  "formattedTime": "20:34",
  "timestamp": "2025-05-26T11:55:36.804Z"
}
```

#### 타이머 제어 (POST)
```
POST /timer/start   # 타이머 시작
POST /timer/stop    # 타이머 정지
POST /timer/reset   # 타이머 리셋
```

#### 캐릭터 상태 전송 (POST)
```
POST /character
```
요청:
```json
{
  "mood": "working",
  "status": "열심히 작업 중!",
  "timestamp": "2025-05-26T11:55:36.804Z"
}
```

#### 할일 진행률 전송 (POST)
```
POST /todo-progress
```
요청:
```json
{
  "totalTodos": 5,
  "completedTodos": 2,
  "progressPercentage": 40.0,
  "timestamp": "2025-05-26T11:55:36.804Z"
}
```

### 🎮 사용 방법

1. **테스트 서버 실행**: `python test_server.py`
2. **Flutter 앱 실행**: `flutter run -d chrome`
3. **연결 확인**: 앱 상단에 "연결됨" 표시 확인
4. **타이머 테스트**: 시작/정지/리셋 버튼으로 테스트
5. **캐릭터 변화**: 타이머 상태에 따라 캐릭터 이모지 변화 확인

### 📊 기능

- **실시간 타이머**: 하드웨어에서 1초마다 데이터 받아옴
- **캐릭터 상태**: 타이머 상태에 따라 😊→💪→😴 변화
- **할일 관리**: 할일 추가/완료/삭제 기능
- **하드웨어 연동**: HTTP API를 통한 양방향 통신
- **연결 상태 표시**: 실시간 연결 상태 확인

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
