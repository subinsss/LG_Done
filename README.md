# DX Project - 나만의 캐릭터와 함께하는 스마트 할일관리

- Flutter,firebase, flask를 활용한 현대적인 AI할일관리 애플리케이션입니다.
- esp32기반의 타이머와도 연동 되어 사용자의 데이터를 보다 직관적으로 확인하고, 분석할 수 있습니다.

## ✨ 주요 기능

### 📅 캘린더 기반 할일 관리
- 월간/주간/일간 뷰로 할일 확인
- 날짜별 할일 추가 및 관리
- 캘린더에 할일 개수 마커 표시
- 일별 완료/미완료 통계 제공

### 📋 카테고리별 할일 관리
- '약속', '꼭할일' 등 카테고리 구분
- 카테고리별 할일 추가/수정/삭제
- 카테고리별 할일 목록 한눈에 확인

### ⭐ 우선순위 관리
- 할일 우선순위 설정 (높음/보통/낮음)
- 우선순위별 색상 구분 (빨강/주황/초록)
- 우선순위별 필터링 기능

### 🔄 스마트 기능
- '내일하기': 할일을 다음 날로 이동
- '내일 또하기': 할일을 다음 날로 복사
- 예상 소요시간 설정
- 실시간 할일 개수 업데이트

### 🧠 머신러닝 기반 생산성 예측
- 랜덤 포레스트 기반 내장 ML 모델을 활용하여 사용자 할일 이력 데이터를 분석하고, 일간 예상 생산성 점수를 예측
- 예측 결과는 AI피드백 페이지에서 시각화되며, 사용자에게 목표 달성률과 개선 팁을 함께 제공

### 📊 통계 및 분석
- 일별/월별 할일 완료율
- 카테고리별 소요시간 통계
- 전체/완료/대기 할일 개수 표시

### 🤖 AI 캐릭터 생성
- 프롬프트 기반 AI 캐릭터 생성
- Stable Diffusion XL 모델 활용
- 생성된 캐릭터 Firebase 저장
- 캐릭터 커스터마이징 지원

### 🔌 ESP32 연동
- ESP32 디스플레이용 할일 목록 제공
- 선택된 캐릭터 이미지 전송
- 실시간 할일 상태 업데이트
- 자동 이미지 리사이징 (150x150)

## 🛠 기술 스택

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
- Hugging Face API (Stable Diffusion XL)
- Pollinations AI

## 📱 주요 특징
- 다크 모드 지원
- 직관적인 UI/UX
- 실시간 데이터 동기화
- 오프라인 모드 지원
- Firebase Firestore를 통한 실시간 데이터 동기화
- 로컬 데이터베이스(SQLite) 지원
- 데이터 백업 및 복원 기능

## 📋 설치 및 실행

### Flutter 앱 실행
1. Flutter SDK 설치
2. 의존성 설치:
   ```bash
   flutter pub get
   ```
3. 앱 실행:
   ```bash
   flutter run
   ```

### Python 백엔드 실행
1. Python 가상환경 생성 및 활성화
2. 의존성 설치:
   ```bash
   pip install -r requirements.txt
   ```
3. 서버 실행:
   ```bash
   python app.py
   ```

## ⚙️ 환경 설정
- Firebase 프로젝트 설정 필요
- 환경 변수 설정 (.env 파일)
- Firebase 설정 파일 (firebase.json)
- Hugging Face API 키 설정
- ESP32 디스플레이 설정

## 🔌 API 엔드포인트
- `POST /generate/prompt`: AI 캐릭터 생성
- `GET /esp-titles`: ESP32용 할일 목록 조회
- `GET /esp-image`: ESP32용 선택된 캐릭터 이미지 조회
- `POST /update-todo`: 할일 상태 업데이트
- `GET /health`: 서버 상태 확인

## 📝 라이선스
이 프로젝트는 MIT 라이선스 하에 배포됩니다. 
