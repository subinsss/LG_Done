#!/usr/bin/env python3
"""
Firebase Firestore에 테스트 이미지 두 개를 저장하는 스크립트
"""

import firebase_admin
from firebase_admin import credentials, firestore
import base64
import requests
from datetime import datetime
import os
import uuid

def initialize_firebase():
    """Firebase 초기화"""
    try:
        # 이미 초기화되어 있는지 확인
        firebase_admin.get_app()
        print("✅ Firebase가 이미 초기화되어 있습니다.")
    except ValueError:
        # service account key 파일이 있는지 확인
        key_file = 'firebase-service-account.json'
        if os.path.exists(key_file):
            cred = credentials.Certificate(key_file)
            firebase_admin.initialize_app(cred)
            print("✅ Firebase 초기화 완료 (Service Account 사용)")
        else:
            # 기본 credentials 사용 (환경변수에서)
            cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred)
            print("✅ Firebase 초기화 완료 (Default Credentials 사용)")
    
    return firestore.client()

def download_image_as_base64(url):
    """URL에서 이미지 다운로드 후 Base64로 변환"""
    try:
        print(f"🔄 이미지 다운로드 중: {url}")
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        
        # 이미지 타입 감지
        content_type = response.headers.get('content-type', 'image/jpeg')
        
        # Base64 인코딩
        base64_string = base64.b64encode(response.content).decode('utf-8')
        data_url = f"data:{content_type};base64,{base64_string}"
        
        print(f"✅ 이미지 다운로드 완료! 크기: {len(response.content)} bytes")
        return data_url
        
    except Exception as e:
        print(f"❌ 이미지 다운로드 실패: {e}")
        return None

def upload_character_to_firestore(db, character_data):
    """캐릭터를 Firestore에 업로드"""
    try:
        character_id = str(uuid.uuid4())
        character_data['character_id'] = character_id
        character_data['created_at'] = datetime.now()
        
        # characters 컬렉션에 추가
        doc_ref = db.collection('characters').document(character_id)
        doc_ref.set(character_data)
        
        print(f"✅ 캐릭터 '{character_data['name']}' 저장 완료! ID: {character_id}")
        return character_id
        
    except Exception as e:
        print(f"❌ 캐릭터 저장 실패: {e}")
        return None

def get_user_input():
    """사용자로부터 이미지 정보 입력받기"""
    print("📝 이미지 정보를 입력해주세요!")
    print()
    
    images = []
    
    # 첫 번째 이미지
    print("🎨 첫 번째 이미지:")
    name1 = input("캐릭터 이름: ").strip() or "테스트 캐릭터 1"
    prompt1 = input("프롬프트 (설명): ").strip() or "첫 번째 테스트 캐릭터"
    url1 = input("이미지 URL: ").strip()
    
    if url1:
        images.append({
            'name': name1,
            'prompt': prompt1,
            'url': url1,
            'type': 'ai_generated'
        })
    
    print()
    print("🎨 두 번째 이미지:")
    name2 = input("캐릭터 이름: ").strip() or "테스트 캐릭터 2"
    prompt2 = input("프롬프트 (설명): ").strip() or "두 번째 테스트 캐릭터"
    url2 = input("이미지 URL: ").strip()
    
    if url2:
        images.append({
            'name': name2,
            'prompt': prompt2,
            'url': url2,
            'type': 'ai_generated'
        })
    
    return images

def main():
    print("🚀 Firebase 이미지 업로드 스크립트 시작!")
    print("=" * 50)
    
    # 사용자 입력 받기
    print("👤 이미지 URL을 입력해서 Firebase에 저장하세요!")
    print("💡 팁: URL이 없으면 Enter를 눌러 건너뛸 수 있습니다.")
    print()
    
    test_images = get_user_input()
    
    if not test_images:
        print("❌ 입력된 이미지가 없습니다. 스크립트를 종료합니다.")
        return
    
    # Firebase 초기화
    print()
    print("🔥 Firebase 연결 중...")
    db = initialize_firebase()
    
    print(f"📊 총 {len(test_images)}개의 이미지를 업로드합니다...")
    print()
    
    success_count = 0
    for i, image_info in enumerate(test_images, 1):
        print(f"🎨 [{i}/{len(test_images)}] {image_info['name']} 처리 중...")
        
        # 이미지 다운로드 및 Base64 변환
        base64_image = download_image_as_base64(image_info['url'])
        
        if base64_image:
            # 캐릭터 데이터 구성
            character_data = {
                'name': image_info['name'],
                'prompt': image_info['prompt'],
                'image_url': base64_image,
                'user_id': 'test_user',  # 테스트용 사용자 ID
                'generation_type': 'prompt',
                'type': image_info['type'],
                'character_type': 'animal',
                'style': 'anime'
            }
            
            # Firestore에 업로드
            character_id = upload_character_to_firestore(db, character_data)
            
            if character_id:
                success_count += 1
                print(f"🎉 성공! ({success_count}/{len(test_images)})")
            else:
                print(f"💥 실패!")
        else:
            print(f"💥 이미지 다운로드 실패!")
        
        print("-" * 30)
    
    print()
    print("=" * 50)
    print(f"🏁 업로드 완료! 성공: {success_count}/{len(test_images)}")
    
    if success_count > 0:
        print("✅ Flutter 앱에서 '내 캐릭터' 탭을 확인해보세요!")
        print("📱 홈화면에서 설정 버튼 → 새로 만들기 → 내 캐릭터 탭")
    else:
        print("❌ 모든 업로드가 실패했습니다. 네트워크나 Firebase 설정을 확인해주세요.")

if __name__ == "__main__":
    main() 