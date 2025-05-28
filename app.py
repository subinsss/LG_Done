from flask import Flask, request, jsonify
from flask_cors import CORS
from firebase_init import db
from google.cloud import firestore

app = Flask(__name__)
CORS(app)

@app.route("/")
def home():
    return "ㅎㅇ"

@app.route("/esp-titles", methods=["GET"])
def get_titles():
    docs = db.collection("todos").stream()
    titles = []
    for doc in docs:
        data = doc.to_dict()
        if "deleted" not in data and "title" in data:
            titles.append(data["title"])
    return jsonify(titles), 200
