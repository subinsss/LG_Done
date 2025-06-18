# DX Project

이 프로젝트는 Flutter와 Python을 활용한 하이브리드 애플리케이션입니다.

## 🚀 주요 기능

- AI 캐릭터 생성 (프롬프트 기반)
- 캐릭터 커스터마이징
- Firebase를 통한 캐릭터 저장 및 관리
- 할일 관리 기능
- ESP32 연동 지원
- 이미지 처리 및 저장
- 캘린더 기능
- 차트 및 데이터 시각화
- 로컬 데이터 저장 (SQLite)
- 푸시 알림 지원

## 기술 스택

### 프론트엔드 (Flutter)
- Flutter SDK (>=3.1.3)
- Firebase 서비스 (Authentication, Firestore, Storage, Analytics, Crashlytics)
- Provider (상태 관리)
- 다양한 Flutter 패키지 (cached_network_image, fl_chart, table_calendar 등)

### 백엔드 (Python)
- Flask (웹 서버)
- Firebase Admin SDK
- Google Cloud Firestore
- Pillow (이미지 처리)
- gunicorn (WSGI HTTP 서버)

## 📋 설치 방법

### 1. Flutter 앱 설정

```bash
# 의존성 설치
flutter pub get

# 앱 실행
flutter run
```

### 2. Flask 서버 설정

```bash
# Python 가상환경 생성 및 활성화
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 의존성 설치
pip install -r requirements.txt

# 서버 실행
python app.py
```

### 3. 환경 설정

1. Firebase 프로젝트 설정
   - `firebase_options.dart` 파일에 Firebase 설정 추가
   - Firebase Admin SDK 키 파일 (`lg-dx-school-5eaae-firebase-adminsdk-fbsvc-41ea7b7d71.json`) 설정

2. 서버 URL 설정
   - `lib/services/ai_character_service.dart`의 `baseUrl`을 실제 서버 IP로 변경
   - 예: `http://192.168.0.12:5050`

## 🔧 주요 파일 구조

```
├── lib/
│   ├── data/
│   │   ├── character.dart
│   │   └── character_item.dart
│   ├── pages/
│   │   ├── character_customization_page.dart
│   │   └── character_selection_page.dart
│   ├── screens/
│   │   └── character_settings_page.dart
│   ├── services/
│   │   └── ai_character_service.dart
│   └── main.dart
├── flask_server/
│   ├── app.py
│   └── free_anime_generator.py
└── assets/
    └── images/
```

## 🔑 주요 API 엔드포인트

- `POST /generate/prompt`: AI 캐릭터 생성
- `GET /esp-titles`: ESP32용 할일 목록 조회
- `GET /esp-image`: ESP32용 선택된 캐릭터 이미지 조회
- `POST /update-todo`: 할일 상태 업데이트

## ⚠️ 주의사항

1. 서버 실행 시 반드시 `host="0.0.0.0"`으로 설정
2. 모바일 기기에서 접속 시 `localhost` 대신 실제 서버 IP 사용
3. Firebase Admin SDK 키 파일 보안 유지

## 🔄 개발 워크플로우

1. Flask 서버 실행 (`python app.py`)
2. Flutter 앱 실행 (`flutter run`)
3. 모바일 기기에서 테스트 시 서버 IP 주소 확인

## 📝 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다. 
