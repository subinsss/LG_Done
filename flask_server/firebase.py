import firebase_admin
from firebase_admin import credentials, firestore
import os

def init_firebase(service_account_path):
    """Firebase Admin SDK 초기화"""
    try:
        # 이미 초기화되어 있으면 기존 앱 사용
        app = firebase_admin.get_app()
        print("✅ 기존 Firebase 앱 사용")
    except ValueError:
        # 초기화되지 않았으면 새로 초기화
        if os.path.exists(service_account_path):
            cred = credentials.Certificate(service_account_path)
            app = firebase_admin.initialize_app(cred)
            print(f"✅ Firebase 초기화 완료: {service_account_path}")
        else:
            raise Exception(f"❌ Firebase 서비스 계정 파일을 찾을 수 없습니다: {service_account_path}")
    
    # Firestore 클라이언트 반환
    db = firestore.client()
    print("✅ Firestore 클라이언트 생성 완료")
    return db 