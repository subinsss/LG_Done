# Firestore 기반 실시간 할일 관리 시스템

## 🏗️ 아키텍처 개요

```
Flutter App → Firestore (직접 저장)
     ↑            ↓
     └─────── (실시간 읽기)
                  ↓
Flask Server ← (실시간 감지)
     ↓
ESP32 Device
```

## 📋 데이터 흐름

1. **Flutter → Firestore**: 할일 추가/수정/삭제를 Firestore에 직접 저장
2. **Firestore → Flutter**: 실시간 스트림으로 UI 자동 업데이트
3. **Firestore → Flask**: 변경사항을 실시간으로 감지
4. **Flask → ESP32**: 감지된 변경사항을 ESP32에 전송

## 🚀 장점

- **빠른 응답**: Flutter가 Firestore에 직접 저장하므로 UI 반응이 즉시
- **실시간 동기화**: Firestore의 실시간 기능 활용
- **안정성**: 네트워크 문제 시에도 Flutter-Firestore 간 동작 보장
- **확장성**: 여러 ESP32 디바이스에 동시 전송 가능

## 🛠️ 설정 방법

### 1. Firebase 서비스 계정 키 생성

1. [Firebase Console](https://console.firebase.google.com) 접속
2. 프로젝트 설정 → 서비스 계정
3. "새 비공개 키 생성" 클릭
4. JSON 파일 다운로드 후 `serviceAccountKey.json`으로 저장

### 2. Flask 서버 설정

```bash
# 패키지 설치
pip install -r requirements.txt

# 서비스 계정 키 경로 수정
# flask_firestore_listener.py 파일에서:
cred = credentials.Certificate('path/to/your/serviceAccountKey.json')

# ESP32 IP 주소 설정
ESP32_ENDPOINT = "http://your-esp32-ip/api/todos"
```

### 3. Flask 서버 실행

```bash
python flask_firestore_listener.py
```

### 4. Flutter 앱 실행

```bash
flutter run -d chrome
```

## 📡 ESP32 연동

ESP32에서 받을 데이터 형식:

```json
{
  "action": "create|update|delete",
  "id": "todo_document_id",
  "data": {
    "title": "할일 제목",
    "isCompleted": false,
    "priority": "medium",
    "estimatedMinutes": 30
  },
  "timestamp": 1234567890.123
}
```

## 🔧 API 엔드포인트

- `GET /status`: 서버 상태 확인
- `POST /start-listening`: Firestore 감지 시작
- `POST /stop-listening`: Firestore 감지 중지
- `POST /test-esp32`: ESP32 연결 테스트

## 🐛 디버깅

### Flask 서버 로그 확인
```bash
# 서버 실행 시 다음과 같은 로그가 출력됩니다:
🔄 Firestore 실시간 감지 시작...
📊 Firestore 변경 감지: 1개 변경사항
➕ 할일 추가: 새로운 할일
✅ ESP32 전송 성공: create - 새로운 할일
```

### Flutter 앱 로그 확인
```bash
# Chrome 개발자 도구 Console에서:
✅ Firestore에 할일 추가 성공: 새로운 할일 (ID: abc123)
📦 Firestore에서 받은 할일 개수: 3
```

## 🔒 보안 고려사항

1. **Firestore 규칙**: 프로덕션에서는 적절한 보안 규칙 설정 필요
2. **서비스 계정 키**: 안전한 위치에 저장하고 버전 관리에 포함하지 않기
3. **ESP32 인증**: ESP32와의 통신에 인증 토큰 사용 권장

## 📈 모니터링

- Firestore 사용량: Firebase Console에서 확인
- Flask 서버 상태: `/status` 엔드포인트 활용
- ESP32 연결 상태: `/test-esp32` 엔드포인트 활용 