from flask import Flask, request, jsonify
from flask_cors import CORS
from firebase_init import db
from google.cloud import firestore

app = Flask(__name__)
CORS(app)

@app.route("/")
def home():
    return "✅ Render Flask 서버 살아있음"

@app.route("/firebase-data", methods=["POST"])
def receive_data():
    data = request.get_json()
    print("🔥 받은 데이터:", data)
    db.collection("tasks").add(data)
    return jsonify({"status": "success", "message": "데이터 저장 완료"}), 200

@app.route("/firebase-data", methods=["GET"])
def get_data():
    docs = db.collection("tasks").stream()
    data = [doc.to_dict() for doc in docs]
    return jsonify(data), 200


@app.route("/esp-task", methods=["GET"])
def get_latest_task():
    docs = db.collection("tasks").order_by("createdAt", direction=firestore.Query.DESCENDING).limit(1).stream()
    latest = [doc.to_dict() for doc in docs]
    return jsonify(latest), 200

