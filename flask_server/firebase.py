import firebase_admin
from firebase_admin import credentials, firestore

def init_firebase(service_account_path):
    """Firebase를 초기화하고 Firestore 클라이언트를 반환합니다."""
    try:
        # Firebase Admin SDK 초기화
        if not firebase_admin._apps:
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred)
            print("✅ Firebase 초기화 완료")
        else:
            print("✅ Firebase 이미 초기화됨")
        
        # Firestore 클라이언트 반환
        db = firestore.client()
        return db
        
    except Exception as e:
        print(f"❌ Firebase 초기화 실패: {e}")
        raise e 