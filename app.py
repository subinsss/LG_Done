from flask import Flask, request, jsonify
from flask_cors import CORS
from firebase_init import db

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
