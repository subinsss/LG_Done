from flask import Flask, request, jsonify
from flask_cors import CORS
from firebase_init import db
from google.cloud import firestore

app = Flask(__name__)
CORS(app)

@app.route("/")
def home():
    return "ㅎㅇ"

@app.route("/firebase-data", methods=["POST"])
def receive_data():
    data = request.get_json()
    print("받은 데이터:", data)

    db.collection("todos").add(data)

    if "title" in data:
        db.collection("esp_titles").add({"title": data["title"]})

    return jsonify({"status": "success", "message": "데이터 저장 완료"}), 200

@app.route("/firebase-data", methods=["GET"])
def get_data():
    docs = db.collection("todos").stream()
    data = [doc.to_dict() for doc in docs]
    return jsonify(data), 200

@app.route("/esp-titles", methods=["GET"])
def get_titles():
    docs = db.collection("esp_titles").stream()
    titles = [doc.to_dict().get("title", "") for doc in docs]
    return jsonify(titles), 200
