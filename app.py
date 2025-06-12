from flask import Flask, request, jsonify
from flask_cors import CORS
from firebase import init_firebase
from google.cloud import firestore
import requests
from PIL import Image
import io
import base64
import time
from datetime import datetime, time
import base64
import os
from flask import send_from_directory
from firebase_admin import firestore
from io import BytesIO
from pathlib import Path
import subprocess
import uuid
import os
from free_anime_generator import FreeAnimeGenerator
from functools import lru_cache
from datetime import datetime, timedelta

app = Flask(__name__)
CORS(app)

db = init_firebase("lg-dx-school-5eaae-firebase-adminsdk-fbsvc-41ea7b7d71.json")

# 캐시 설정
CACHE_DURATION = 300  # 5분
last_esp_image_check = None
cached_esp_image = None
last_titles_check = None
cached_titles = None

@app.route("/esp-titles", methods=["GET"])
def get_titles():
    global last_titles_check, cached_titles
    
    try:
        current_time = datetime.now()
        
        # 캐시가 유효한 경우 캐시된 데이터 반환
        if (last_titles_check is not None and 
            cached_titles is not None and 
            (current_time - last_titles_check).seconds < CACHE_DURATION):
            return jsonify(cached_titles), 200

        # 오늘 날짜를 'YYYY-MM-DD' 형식 문자열로 변환
        today_str = current_time.strftime("%Y-%m-%d")

        # 쿼리 최적화: limit 추가
        docs = db.collection("todos").filter("is_completed", "==", False).limit(20).stream()

        titles = []
        for doc in docs:
            data = doc.to_dict()
            due = data.get("due_date_string", "")

            if due == today_str and "title" in data:
                titles.append(data["title"])

        # 캐시 업데이트
        last_titles_check = current_time
        cached_titles = titles

        return jsonify(titles), 200

    except Exception as e:
        print(f"❌ esp-titles 오류: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/esp-image', methods=['GET'])
def get_selected_image_for_esp():
    global last_esp_image_check, cached_esp_image
    
    try:
        current_time = datetime.now()
        
        # 캐시가 유효한 경우 캐시된 데이터 반환
        if (last_esp_image_check is not None and 
            cached_esp_image is not None and 
            (current_time - last_esp_image_check).seconds < CACHE_DURATION):
            return jsonify(cached_esp_image)

        print("🔍 ESP 이미지 요청 시작...")

        # 쿼리 최적화: 필요한 필드만 선택
        docs = db.collection('characters') \
            .filter('is_selected', '==', True) \
            .select('image_url') \
            .limit(1).stream()

        selected_doc = next(docs, None)

        if not selected_doc:
            print("❌ 선택된 캐릭터가 없습니다")
            return jsonify({"error": "No selected character found"}), 404

        data = selected_doc.to_dict()
        image_url = data.get('image_url')

        if not image_url:
            print("❌ 이미지 URL이 없습니다")
            return jsonify({"error": "No image URL found"}), 404

        result = None
        
        # Base64 이미지 처리
        if image_url.startswith('data:image'):
            print("📷 Base64 이미지 처리 중...")

            # static 폴더 생성
            os.makedirs('static', exist_ok=True)

            # base64 디코딩 → 이미지 열기
            header, encoded = image_url.split(',', 1)
            image_data = base64.b64decode(encoded)
            image = Image.open(BytesIO(image_data))

            if image.mode != "RGB":
                image = image.convert("RGB")

            resized_image = image.resize((400, 400))

            file_path = 'static/esp.jpg'
            resized_image.save(file_path, format='JPEG')

            print("✅ 이미지 파일 저장 완료 (400x400)")
            result = {"image_url": "static/esp.jpg"}
        else:
            print("🔗 네트워크 이미지 URL 반환")
            result = {"image_url": image_url}

        # 캐시 업데이트
        last_esp_image_check = current_time
        cached_esp_image = result

        return jsonify(result)

    except Exception as e:
        print(f"❌ ESP 이미지 오류: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

# 할일 ID 캐시
todo_id_cache = {}

@app.route('/update-todo', methods=['POST'])
def update_todo():
    try:
        data = request.get_json()
        title = data.get('title')
        completed = data.get('is_completed', False)
        start_time = data.get('start_time')
        stop_time = data.get('stop_time')
        pause_times = data.get('pause_time')
        resume_times = data.get('resume_time')

        print(f"\n🚀 /update-todo 호출됨")
        print(f"📥 받은 데이터: {data}")

        if not title:
            print(f"❌ title 없음! 업데이트 불가")
            return jsonify({'error': '할일 제목(title)이 필요합니다'}), 400

        # 캐시된 ID 확인
        doc_id = todo_id_cache.get(title)
        doc_ref = None

        if doc_id:
            # 캐시된 ID가 있으면 직접 참조
            doc_ref = db.collection('todos').document(doc_id)
            doc = doc_ref.get()
            if not doc.exists:
                # 캐시가 무효한 경우
                doc_ref = None
                del todo_id_cache[title]

        if not doc_ref:
            # 캐시 미스: title로 검색
            query = db.collection('todos').filter('title', '==', title).limit(1).get()
            if not query:
                print(f"❌ '{title}'에 해당하는 문서 없음")
                return jsonify({'error': f'"{title}"에 해당하는 할일이 없습니다'}), 404

            doc = query[0]
            doc_ref = doc.reference
            # ID 캐시 업데이트
            todo_id_cache[title] = doc.id

        print(f"✅ 문서 찾음 → ID: {doc_ref.id}")

        update_data = {'is_completed': completed}

        if start_time is not None:
            update_data['start_time'] = start_time
        if stop_time is not None:
            update_data['stop_time'] = stop_time
        if pause_times is not None:
            update_data['pause_times'] = pause_times
        if resume_times is not None:
            update_data['resume_times'] = resume_times

        # Firestore 업데이트
        print(f"📤 업데이트할 데이터: {update_data}")
        doc_ref.update(update_data)

        print(f"✅ '{title}' 문서({doc_ref.id}) 업데이트 완료")
        print(f"🔥 최종 Firestore에 저장된 is_completed 값: {completed}\n")

        return jsonify({'success': True, 'id': doc_ref.id, 'updated': update_data})

    except Exception as e:
        print(f"❌ 할일 업데이트 오류: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@app.route('/generate/prompt', methods=['POST'])
def generate_from_prompt():
    try:
        data = request.get_json()
        
        # 데이터 검증 추가
        if not data:
            return jsonify({'error': '요청 데이터가 없습니다'}), 400
            
        prompt = data.get('prompt')
        if not prompt:
            return jsonify({'error': '프롬프트가 필요합니다'}), 400
            
        name = data.get('name', f'AI Character {datetime.now().strftime("%Y%m%d_%H%M%S")}')
        style = data.get('style', '3D mascot')

        print(f"🎨 캐릭터 생성 시작 - 프롬프트: {prompt}")
        print(f"📝 이름: {name}, 스타일: {style}")

        try:
            # FreeAnimeGenerator 사용 (만약 없다면 대체 방법 사용)
            generator = FreeAnimeGenerator()
            image_url = generator.generate_with_pollinations(prompt)

            if not image_url:
                raise Exception("이미지 생성 실패")

            # 이미지 다운로드 → static/images 에 저장
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"ai_character_{timestamp}.png"
            filepath = generator.download_image(image_url, filename)

            if not filepath:
                raise Exception("이미지 다운로드 실패")

            # Base64 인코딩
            with open(filepath, "rb") as image_file:
                img_base64 = base64.b64encode(image_file.read()).decode()
            image_data_url = f"data:image/png;base64,{img_base64}"
            
        except Exception as gen_error:
            print(f"❌ FreeAnimeGenerator 오류: {gen_error}")
            # 대체 방법: 허깅페이스 API 사용
            try:
                print("🔄 허깅페이스 API로 대체 시도...")
                
                # 애니메이션 스타일 프롬프트 개선
                enhanced_prompt = f"anime style, cute character, {prompt}, high quality, detailed"
                
                payload = {
                    "inputs": enhanced_prompt,
                    "parameters": {
                        "num_inference_steps": 30,
                        "guidance_scale": 7.5,
                        "width": 512,
                        "height": 512
                    }
                }
                
                image_bytes = query_huggingface(payload)
                
                # 이미지를 Base64로 인코딩
                img_base64 = base64.b64encode(image_bytes).decode()
                image_data_url = f"data:image/png;base64,{img_base64}"
                
                print("✅ 허깅페이스 API로 이미지 생성 성공")
                
            except Exception as hf_error:
                print(f"❌ 허깅페이스 API도 실패: {hf_error}")
                return jsonify({'error': f'이미지 생성 실패: {str(hf_error)}'}), 500

        # Firestore 저장
        character_ref = db.collection('characters').document()
        character_id = character_ref.id

        character_data = {
            'character_id': character_id,
            'user_id': 'anonymous_user',
            'name': name,
            'prompt': prompt,
            'generation_type': 'prompt',
            'image_url': image_data_url,
            'created_at': firestore.SERVER_TIMESTAMP,
            'type': 'custom',
            'style': style,
            'is_selected': False  # 기본값으로 선택되지 않은 상태
        }

        character_ref.set(character_data)
        print(f"✅ 캐릭터 저장 완료 - ID: {character_id}")

        return jsonify({
            'success': True,
            'character_id': character_id,
            'image_url': image_data_url,
            'message': '캐릭터가 성공적으로 생성되고 저장되었습니다!'
        })

    except Exception as e:
        print(f"❌ 캐릭터 생성 오류: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': f'캐릭터 생성 중 오류 발생: {str(e)}'}), 500 