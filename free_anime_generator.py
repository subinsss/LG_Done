import requests
import os
from datetime import datetime
import time

class FreeAnimeGenerator:
    """무료 애니메이션 이미지 생성기"""
    
    def __init__(self):
        self.base_url = "https://image.pollinations.ai/prompt"
        self.static_dir = "static/images"
        
        # static/images 디렉토리 생성
        os.makedirs(self.static_dir, exist_ok=True)
    
    def generate_with_pollinations(self, prompt, style="anime"):
        """Pollinations AI를 사용하여 이미지 생성"""
        try:
            print(f"🎨 Pollinations AI로 이미지 생성 시작...")
            print(f"📝 프롬프트: {prompt}")
            
            # 애니메이션 스타일 프롬프트 개선
            enhanced_prompt = f"anime style, cute character, {prompt}, high quality, detailed, kawaii"
            
            # URL 인코딩
            import urllib.parse
            encoded_prompt = urllib.parse.quote(enhanced_prompt)
            
            # 이미지 URL 생성 (512x512 크기)
            image_url = f"{self.base_url}/{encoded_prompt}?width=512&height=512&seed={int(time.time())}"
            
            print(f"🔗 생성된 URL: {image_url}")
            
            # URL 유효성 검증
            response = requests.head(image_url, timeout=10)
            if response.status_code == 200:
                print("✅ 이미지 URL 생성 성공")
                return image_url
            else:
                print(f"❌ 이미지 URL 응답 오류: {response.status_code}")
                return None
                
        except Exception as e:
            print(f"❌ Pollinations AI 오류: {e}")
            return None
    
    def download_image(self, image_url, filename):
        """이미지를 다운로드하여 로컬에 저장"""
        try:
            print(f"⬇️ 이미지 다운로드 시작: {filename}")
            
            response = requests.get(image_url, timeout=30)
            response.raise_for_status()
            
            filepath = os.path.join(self.static_dir, filename)
            
            with open(filepath, 'wb') as f:
                f.write(response.content)
            
            print(f"✅ 이미지 저장 완료: {filepath}")
            return filepath
            
        except Exception as e:
            print(f"❌ 이미지 다운로드 실패: {e}")
            return None
    
    def generate_and_save(self, prompt, filename=None):
        """이미지 생성 및 저장을 한 번에 처리"""
        try:
            # 파일명 생성
            if not filename:
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = f"character_{timestamp}.png"
            
            # 이미지 URL 생성
            image_url = self.generate_with_pollinations(prompt)
            if not image_url:
                return None
            
            # 이미지 다운로드
            filepath = self.download_image(image_url, filename)
            if not filepath:
                return None
            
            return {
                'url': image_url,
                'filepath': filepath,
                'filename': filename
            }
            
        except Exception as e:
            print(f"❌ 이미지 생성 및 저장 실패: {e}")
            return None

# 테스트 함수
def test_generator():
    """FreeAnimeGenerator 테스트"""
    generator = FreeAnimeGenerator()
    
    test_prompt = "cute anime girl with pink hair"
    result = generator.generate_and_save(test_prompt, "test_character.png")
    
    if result:
        print(f"✅ 테스트 성공!")
        print(f"URL: {result['url']}")
        print(f"파일: {result['filepath']}")
    else:
        print("❌ 테스트 실패!")

if __name__ == "__main__":
    test_generator() 