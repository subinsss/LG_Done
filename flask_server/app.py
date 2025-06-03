from flask import Flask, request, jsonify
from flask_cors import CORS
from firebase import init_firebase
from google.cloud import firestore
import requests
from PIL import Image
import io
import base64
import time
from datetime import datetime
import os

app = Flask(__name__)
CORS(app)

db = init_firebase("lg-dx-school-5eaae-firebase-adminsdk-fbsvc-41ea7b7d71.json")
HF_API_KEY = "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"
HF_API_URL = "https://api-inference.huggingface.co/models/stabilityai/stable-diffusion-xl-base-1.0"


def query_huggingface(payload):
    """허깅페이스 API 호출"""
    headers = {"Authorization": f"Bearer {HF_API_KEY}"}

    for attempt in range(3):
        response = requests.post(HF_API_URL, headers=headers, json=payload)

        if response.status_code == 200:
            return response.content
        elif response.status_code == 503:
            print(f"모델 로딩 중... {attempt + 1}/3 재시도")
            time.sleep(20)  # 모델 로딩 대기
            continue
        else:
            raise Exception(f"허깅페이스 API 오류: {response.status_code}, {response.text}")

    raise Exception("허깅페이스 API 재시도 초과")

@app.route("/")
def home():
    return "ㅎㅇ"

@app.route("/esp-titles", methods=["GET"])
def get_titles():
    docs = db.collection("todos").stream()
    titles = [doc.to_dict()["title"] for doc in docs if "title" in doc.to_dict()]
    return jsonify(titles), 200


@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy'})


@app.route('/generate/prompt', methods=['POST'])
def generate_from_prompt():
    try:
        data = request.get_json()
        prompt = data['prompt']
        style = data.get('style', 'anime')

        print(f"🎨 캐릭터 생성 시작 - 프롬프트: {prompt}, 스타일: {style}")

        # 허깅페이스로 이미지 생성
        if style and style != 'none':
            enhanced_prompt = f"{prompt}, {style} style, character design, high quality"
        else:
            enhanced_prompt = f"{prompt}, character design, high quality"
        print(f"🔧 강화된 프롬프트: {enhanced_prompt}")

        image_bytes = query_huggingface({
            "inputs": enhanced_prompt,
            "parameters": {
                "negative_prompt": "blurry, low quality",
                "num_inference_steps": 20
            }
        })

        # Base64로 인코딩
        img_base64 = base64.b64encode(image_bytes).decode()
        image_url = f"data:image/png;base64,{img_base64}"
        print(f"✅ 이미지 생성 완료")

        # 🔥 Firestore에 캐릭터 저장 (새로 추가!)
        character_ref = db.collection('characters').document()
        character_id = character_ref.id
        
        character_data = {
            'character_id': character_id,
            'user_id': 'anonymous_user',  # 익명 사용자
            'name': f'AI Character {character_id[:8]}',
            'prompt': prompt,
            'generation_type': 'prompt',
            'image_url': image_url,
            'created_at': firestore.SERVER_TIMESTAMP,
            'type': 'custom',
            'style': style
        }

        print(f"💾 Firestore에 캐릭터 저장 중... ID: {character_id}")
        character_ref.set(character_data)
        print(f"✅ 캐릭터 저장 완료!")

        return jsonify({
            'success': True,
            'character_id': character_id,  # 캐릭터 ID 추가
            'image_url': image_url,
            'message': '캐릭터가 성공적으로 생성되고 저장되었습니다!'  # 메시지 추가
        })

    except Exception as e:
        print(f"❌ 오류 발생: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/generate/image', methods=['POST'])
def generate_from_image():
    try:
        file = request.files['image']
        style = request.form.get('style', 'anime')

        print(f"🖼️ 이미지 기반 캐릭터 생성 시작 - 스타일: {style}")

        # 업로드된 이미지를 Base64로 변환
        image_data = file.read()
        image_base64 = base64.b64encode(image_data).decode()

        # 허깅페이스 Image-to-Image 모델 사용
        img2img_url = "https://api-inference.huggingface.co/models/timbrooks/instruct-pix2pix"

        # AI에게 이미지 변환 요청
        prompt_instruction = f"turn this into a {style} character, cute and detailed"

        response = requests.post(
            img2img_url,
            headers={"Authorization": f"Bearer {HF_API_KEY}"},
            json={
                "inputs": prompt_instruction,
                "parameters": {
                    "image": f"data:image/jpeg;base64,{image_base64}",
                    "num_inference_steps": 20
                }
            }
        )

        if response.status_code == 200:
            # 생성된 이미지를 Base64로 인코딩
            generated_image = base64.b64encode(response.content).decode()
            image_url = f"data:image/png;base64,{generated_image}"
            print(f"✅ 이미지 변환 완료")

            # 🔥 Firestore에 캐릭터 저장 (새로 추가!)
            character_ref = db.collection('characters').document()
            character_id = character_ref.id
            
            character_data = {
                'character_id': character_id,
                'user_id': 'anonymous_user',  # 익명 사용자
                'name': f'AI Character {character_id[:8]}',
                'prompt': f'Generated from uploaded image with {style} style',
                'generation_type': 'image',
                'image_url': image_url,
                'created_at': firestore.SERVER_TIMESTAMP,
                'type': 'custom',
                'style': style
            }

            print(f"💾 Firestore에 캐릭터 저장 중... ID: {character_id}")
            character_ref.set(character_data)
            print(f"✅ 캐릭터 저장 완료!")

            return jsonify({
                'success': True,
                'character_id': character_id,  # 캐릭터 ID 추가
                'image_url': image_url,
                'message': '이미지 기반 캐릭터가 성공적으로 생성되고 저장되었습니다!'  # 메시지 추가
            })
        else:
            return jsonify({'error': '이미지 기반 생성 실패'}), 500

    except Exception as e:
        print(f"❌ 오류 발생: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/upload-image', methods=['POST'])
def upload_image_directly():
    """이미지를 직접 업로드해서 Firebase에 저장"""
    try:
        data = request.get_json()
        
        # 요청 데이터 확인
        if not data or 'image_data' not in data:
            return jsonify({'error': 'image_data가 필요합니다'}), 400
        
        image_data = data['image_data']  # Base64 형식 이미지
        name = data.get('name', f'업로드 이미지_{datetime.now().strftime("%H%M%S")}')
        prompt = data.get('prompt', '직접 업로드된 이미지')
        
        print(f"📁 이미지 직접 업로드 - 이름: {name}")
        
        # Firestore에 캐릭터 저장
        character_ref = db.collection('characters').document()
        character_id = character_ref.id
        
        character_data = {
            'character_id': character_id,
            'user_id': 'test_user',  # 테스트 사용자
            'name': name,
            'prompt': prompt,
            'generation_type': 'upload',
            'image_url': image_data,  # Base64 이미지 데이터
            'created_at': firestore.SERVER_TIMESTAMP,
            'type': 'ai_generated',
            'style': 'uploaded'
        }
        
        print(f"💾 Firestore에 캐릭터 저장 중... ID: {character_id}")
        character_ref.set(character_data)
        print(f"✅ 캐릭터 저장 완료!")
        
        return jsonify({
            'success': True,
            'character_id': character_id,
            'message': f'"{name}" 이미지가 성공적으로 업로드되었습니다!',
            'firebase_saved': True
        })
        
    except Exception as e:
        print(f"❌ 업로드 오류: {str(e)}")
        return jsonify({'error': str(e)}), 500


def save_image_to_firebase(image_url, name=None, prompt=None, is_selected=False):
    """이미지를 Firebase에 직접 저장하는 함수"""
    try:
        character_ref = db.collection('characters').document()
        character_id = character_ref.id
        
        character_data = {
            'character_id': character_id,
            'user_id': 'server_upload',
            'name': name or f'서버 이미지_{datetime.now().strftime("%H%M%S")}',
            'prompt': prompt or '서버에서 직접 업로드',
            'generation_type': 'server_upload',
            'image_url': image_url,
            'created_at': firestore.SERVER_TIMESTAMP,
            'type': 'ai_generated',
            'style': 'server',
            'is_selected': is_selected  # 🔥 선택 상태 추가!
        }
        
        character_ref.set(character_data)
        print(f"✅ Firebase 저장 완료! ID: {character_id}, 선택됨: {is_selected}")
        return character_id
        
    except Exception as e:
        print(f"❌ Firebase 저장 실패: {e}")
        return None

def save_base64_image(base64_data, name=None, prompt=None):
    """Base64 이미지를 Firebase에 저장"""
    if not base64_data.startswith('data:image/'):
        base64_data = f"data:image/jpeg;base64,{base64_data}"
    
    return save_image_to_firebase(base64_data, name, prompt)

def save_url_image(url, name=None, prompt=None):
    """URL 이미지를 다운로드해서 Base64로 변환 후 Firebase에 저장"""
    try:
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        
        base64_string = base64.b64encode(response.content).decode('utf-8')
        content_type = response.headers.get('content-type', 'image/jpeg')
        data_url = f"data:{content_type};base64,{base64_string}"
        
        return save_image_to_firebase(data_url, name, prompt)
        
    except Exception as e:
        print(f"❌ URL 이미지 저장 실패: {e}")
        return None

def save_local_file(file_path, name=None, prompt=None):
    """로컬 파일을 Firebase에 저장"""
    try:
        if not os.path.exists(file_path):
            print(f"❌ 파일이 없습니다: {file_path}")
            return None
        
        # 파일 읽기
        with open(file_path, 'rb') as f:
            image_data = f.read()
        
        # Base64 변환
        base64_string = base64.b64encode(image_data).decode('utf-8')
        
        # 파일 확장자로 content-type 결정
        file_ext = os.path.splitext(file_path)[1].lower()
        content_type_map = {
            '.jpg': 'image/jpeg',
            '.jpeg': 'image/jpeg',
            '.png': 'image/png',
            '.gif': 'image/gif',
            '.webp': 'image/webp'
        }
        content_type = content_type_map.get(file_ext, 'image/jpeg')
        data_url = f"data:{content_type};base64,{base64_string}"
        
        file_name = os.path.basename(file_path)
        return save_image_to_firebase(
            data_url, 
            name or f"로컬_{file_name}",
            prompt or f"로컬 파일: {file_name}"
        )
        
    except Exception as e:
        print(f"❌ 로컬 파일 저장 실패: {e}")
        return None

# 테스트용 이미지 저장 엔드포인트
@app.route('/test-save-images', methods=['POST'])
def test_save_images():
    """테스트용: 여러 이미지를 한번에 저장"""
    try:
        # 🔥 여기에 저장할 이미지들을 넣으세요! 🔥
        test_images = [
            {
                'path': r"C:\Users\413\Downloads\dog.jpg",
                'name': '강아지',
                'prompt': '귀여운 강아지'
            },
            {
                'path': r'C:\Users\413\Downloads\cat.jpg',
                'name': '고양이',
                'prompt': '귀여운 고양이'
            }
        ]
        
        results = []
        for img in test_images:
            file_path = img['path']
            name = img.get('name', '이름없음')
            prompt = img.get('prompt', '설명없음')
            
            print(f"📁 처리 중: {file_path}")
            
            if file_path.startswith('http'):
                # URL 이미지
                character_id = save_url_image(file_path, name, prompt)
            else:
                # 로컬 파일
                character_id = save_local_file(file_path, name, prompt)
            
            if character_id:
                results.append({
                    'success': True,
                    'character_id': character_id,
                    'name': name
                })
                print(f"✅ 성공: {name}")
            else:
                results.append({
                    'success': False,
                    'name': name
                })
                print(f"❌ 실패: {name}")
        
        success_count = len([r for r in results if r["success"]])
        return jsonify({
            'message': f'{success_count}개 이미지 저장 완료!',
            'results': results
        })
        
    except Exception as e:
        print(f"❌ 전체 오류: {str(e)}")
        return jsonify({'error': str(e)}), 500

def select_character(character_id):
    """캐릭터를 선택하고 다른 캐릭터들은 선택 해제"""
    try:
        # 1. 모든 캐릭터를 선택 해제
        characters_ref = db.collection('characters')
        all_chars = characters_ref.get()
        
        batch = db.batch()
        for char_doc in all_chars:
            batch.update(char_doc.reference, {'is_selected': False})
        
        # 2. 선택된 캐릭터만 true로 설정
        selected_char_ref = characters_ref.document(character_id)
        batch.update(selected_char_ref, {'is_selected': True})
        
        # 3. 배치 실행
        batch.commit()
        
        print(f"✅ 캐릭터 선택 완료: {character_id}")
        return True
        
    except Exception as e:
        print(f"❌ 캐릭터 선택 실패: {e}")
        return False

def get_selected_character():
    """현재 선택된 캐릭터 가져오기"""
    try:
        characters_ref = db.collection('characters')
        selected_chars = characters_ref.where('is_selected', '==', True).limit(1).get()
        
        if selected_chars:
            char_doc = selected_chars[0]
            char_data = char_doc.to_dict()
            print(f"✅ 선택된 캐릭터: {char_data.get('name')}")
            return char_data
        else:
            print("📝 선택된 캐릭터 없음")
            return None
            
    except Exception as e:
        print(f"❌ 선택된 캐릭터 조회 실패: {e}")
        return None

# 캐릭터 선택 엔드포인트
@app.route('/select-character', methods=['POST'])
def select_character_endpoint():
    """캐릭터 선택 API"""
    try:
        data = request.get_json()
        character_id = data.get('character_id')
        
        if not character_id:
            return jsonify({'error': 'character_id가 필요합니다'}), 400
        
        success = select_character(character_id)
        
        if success:
            return jsonify({
                'success': True,
                'message': '캐릭터가 선택되었습니다!',
                'selected_character_id': character_id
            })
        else:
            return jsonify({'error': '캐릭터 선택에 실패했습니다'}), 500
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# 선택된 캐릭터 조회 엔드포인트
@app.route('/selected-character', methods=['GET'])
def get_selected_character_endpoint():
    """현재 선택된 캐릭터 조회 API"""
    try:
        selected_char = get_selected_character()
        
        if selected_char:
            return jsonify({
                'success': True,
                'character': selected_char
            })
        else:
            return jsonify({
                'success': False,
                'message': '선택된 캐릭터가 없습니다'
            })
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5050, debug=True) 