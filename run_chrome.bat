@echo off
echo Flutter 웹 앱을 크롬으로 실행합니다...
echo.

REM Flutter 웹 지원 확인
flutter config --enable-web

REM 의존성 설치
echo 의존성을 설치하는 중...
flutter pub get

REM 웹 앱을 크롬으로 실행
echo 크롬 브라우저로 앱을 실행합니다...
flutter run -d chrome --web-renderer html

pause 