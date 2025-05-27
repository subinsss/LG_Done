import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
import os
import json

firebase_key_json = os.environ.get("FIREBASE_KEY")

cred_dict = json.loads(firebase_key_json)

cred = credentials.Certificate(cred_dict)
firebase_admin.initialize_app(cred)
db = firestore.client()
