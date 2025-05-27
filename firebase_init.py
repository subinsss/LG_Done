import os
import json
import firebase_admin
from firebase_admin import credentials, firestore

firebase_key_json = os.environ.get("FIREBASE_KEY")

if not firebase_key_json:
    raise RuntimeError("FIREBASE_KEY 환경변수가 설정되지 않았습니다.")

cred_dict = json.loads(firebase_key_json)
cred = credentials.Certificate(cred_dict)

if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)

db = firestore.client()
