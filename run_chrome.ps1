Write-Host "Flutter 웹 앱을 크롬으로 실행합니다..." -ForegroundColor Green
Write-Host ""

# Flutter 웹 지원 활성화
Write-Host "Flutter 웹 지원을 활성화합니다..." -ForegroundColor Yellow
flutter config --enable-web

# 의존성 설치
Write-Host "의존성을 설치하는 중..." -ForegroundColor Yellow
flutter pub get

# 웹 앱을 크롬으로 실행
Write-Host "크롬 브라우저로 앱을 실행합니다..." -ForegroundColor Yellow
flutter run -d chrome --web-renderer html

Read-Host "계속하려면 Enter를 누르세요" 