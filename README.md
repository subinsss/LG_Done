# 🔧 Smart Task Logger with ESP32, Flask, and Firebase

A lightweight IoT system that enables real-time task tracking  
via ESP32 hardware, Flask middleware, and Firebase Firestore integration.

---

## 🚀 Features

- ESP32-based sensor input & task status collection
- Flask server with ngrok tunnel for real-time data reception
- Firebase Firestore logging (structured and timestamped)
- Flutter client (optional) for task input and feedback display
- AI feedback module with GPT & Stable Diffusion (planned)

---

## 🛠️ Tech Stack

| Layer         | Technology              |
|---------------|--------------------------|
| Hardware      | ESP32                    |
| Communication | HTTP (POST) + JSON       |
| Backend       | Python (Flask + pyngrok) |
| Database      | Firebase Firestore       |
| Frontend      | Flutter (WIP)            |
| AI Module     | GPT, Stable Diffusion (future)

---
## 📁 Project Structure

```plaintext
📁 root/
├── firebase_init.py        # Firebase Admin SDK 초기화 (인증키 로딩 및 Firestore 연결)
├── server.ipynb            # Flask 서버 실행 및 데이터 수신 테스트 노트북
├── firebase_key.json       # Firebase 서비스 계정 키 (비공개 권장, .gitignore 필요)
├── README.md               # 프로젝트 소개 및 실행 가이드
├── requirements.txt        # 설치해야 할 패키지 리스트 (옵션)
│
├── flutter_app/            # (예정) 사용자 인터페이스용 Flutter 앱
│   └── lib/
│       └── main.dart       # Flutter 진입점
│
├── ai_module/              # (예정) GPT 피드백 및 Stable Diffusion 이미지 생성 모듈
│   ├── gpt_feedback.py     # 유저 기록 기반 GPT 피드백 생성기
│   └── image_generator.py  # SD 기반 피드백 이미지 생성기
│
└── logs/                   # ESP 데이터 로그 저장 (원하면)
    └── sample.json         # 테스트용 데이터 샘플
