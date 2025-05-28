from flask import Flask, jsonify
import firebase_admin
from firebase_admin import credentials, firestore
import threading
import time
import requests
import json

app = Flask(__name__)

# Firebase 초기화 (서비스 계정 키 필요)
cred = credentials.Certificate('path/to/your/serviceAccountKey.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# ESP32 엔드포인트 설정
ESP32_ENDPOINT = "http://your-esp32-ip/api/todos"

class FirestoreListener:
    def __init__(self):
        self.last_todos = {}
        self.listener = None
        
    def start_listening(self):
        """Firestore 변경사항 실시간 감지 시작"""
        print("🔄 Firestore 실시간 감지 시작...")
        
        # todos 컬렉션의 변경사항 감지
        todos_ref = db.collection('todos')
        self.listener = todos_ref.on_snapshot(self.on_snapshot)
        
    def on_snapshot(self, col_snapshot, changes, read_time):
        """Firestore 변경사항 콜백"""
        print(f"📊 Firestore 변경 감지: {len(changes)}개 변경사항")
        
        for change in changes:
            doc = change.document
            todo_data = doc.to_dict()
            todo_id = doc.id
            
            if change.type.name == 'ADDED':
                print(f"➕ 할일 추가: {todo_data.get('title', '')}")
                self.send_to_esp32('create', todo_id, todo_data)
                
            elif change.type.name == 'MODIFIED':
                print(f"🔄 할일 수정: {todo_data.get('title', '')}")
                self.send_to_esp32('update', todo_id, todo_data)
                
            elif change.type.name == 'REMOVED':
                print(f"🗑️ 할일 삭제: {todo_id}")
                self.send_to_esp32('delete', todo_id, {})
    
    def send_to_esp32(self, action, todo_id, todo_data):
        """ESP32에 데이터 전송"""
        try:
            payload = {
                'action': action,
                'id': todo_id,
                'data': todo_data,
                'timestamp': time.time()
            }
            
            response = requests.post(
                ESP32_ENDPOINT,
                json=payload,
                timeout=5
            )
            
            if response.status_code == 200:
                print(f"✅ ESP32 전송 성공: {action} - {todo_data.get('title', todo_id)}")
            else:
                print(f"❌ ESP32 전송 실패: {response.status_code}")
                
        except Exception as e:
            print(f"❌ ESP32 전송 오류: {e}")
    
    def stop_listening(self):
        """감지 중지"""
        if self.listener:
            self.listener.unsubscribe()
            print("🛑 Firestore 감지 중지")

# 전역 리스너 인스턴스
firestore_listener = FirestoreListener()

@app.route('/start-listening', methods=['POST'])
def start_listening():
    """Firestore 감지 시작"""
    firestore_listener.start_listening()
    return jsonify({'status': 'listening_started'})

@app.route('/stop-listening', methods=['POST'])
def stop_listening():
    """Firestore 감지 중지"""
    firestore_listener.stop_listening()
    return jsonify({'status': 'listening_stopped'})

@app.route('/status', methods=['GET'])
def get_status():
    """서버 상태 확인"""
    return jsonify({
        'status': 'running',
        'listening': firestore_listener.listener is not None,
        'timestamp': time.time()
    })

@app.route('/test-esp32', methods=['POST'])
def test_esp32():
    """ESP32 연결 테스트"""
    try:
        test_data = {
            'action': 'test',
            'message': 'Flask 서버에서 테스트',
            'timestamp': time.time()
        }
        
        response = requests.post(ESP32_ENDPOINT, json=test_data, timeout=5)
        
        return jsonify({
            'esp32_status': response.status_code,
            'esp32_response': response.text
        })
    except Exception as e:
        return jsonify({
            'error': str(e)
        }), 500

if __name__ == '__main__':
    # 서버 시작 시 자동으로 Firestore 감지 시작
    def start_listener_delayed():
        time.sleep(2)  # 서버 시작 후 2초 대기
        firestore_listener.start_listening()
    
    # 백그라운드에서 리스너 시작
    threading.Thread(target=start_listener_delayed, daemon=True).start()
    
    print("🚀 Flask 서버 시작 - Firestore 실시간 감지 활성화")
    app.run(host='0.0.0.0', port=5000, debug=True) 