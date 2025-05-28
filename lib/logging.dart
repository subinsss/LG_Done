import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

Future<void> logGoogleAnalyticsEvent(String eventName, Map<String, Object> eventParams) async {
  await FirebaseAnalytics.instance.logEvent(
    name: eventName,
    parameters: eventParams,
  );
}

class AppLogger {
  // 싱글톤 패턴 구현
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  // 로그 레벨 정의
  static const int VERBOSE = 0;
  static const int DEBUG = 1;
  static const int INFO = 2;
  static const int WARNING = 3;
  static const int ERROR = 4;
  
  // 현재 로그 레벨 (릴리즈 모드에서는 INFO부터, 디버그 모드에서는 VERBOSE부터)
  int _currentLogLevel = kReleaseMode ? INFO : VERBOSE;
  
  // 로그 레벨 설정
  void setLogLevel(int level) {
    _currentLogLevel = level;
  }
  
  // 로그 출력 메서드
  void v(String tag, String message) {
    if (_currentLogLevel <= VERBOSE) {
      print('🔍 V/$tag: $message');
    }
  }
  
  void d(String tag, String message) {
    if (_currentLogLevel <= DEBUG) {
      print('🐛 D/$tag: $message');
    }
  }
  
  void i(String tag, String message) {
    if (_currentLogLevel <= INFO) {
      print('ℹ️ I/$tag: $message');
    }
  }
  
  void w(String tag, String message) {
    if (_currentLogLevel <= WARNING) {
      print('⚠️ W/$tag: $message');
    }
  }
  
  void e(String tag, String message, {dynamic error, StackTrace? stackTrace}) {
    if (_currentLogLevel <= ERROR) {
      print('❌ E/$tag: $message');
      if (error != null) {
        print('Error: $error');
      }
      if (stackTrace != null) {
        print('StackTrace: $stackTrace');
      }
    }
    
    // Firebase Crashlytics에 비치명적 오류 기록 (웹이 아닌 플랫폼에서만)
    if (!kIsWeb) {
      try {
        FirebaseCrashlytics.instance.recordError(
          error ?? message,
          stackTrace,
          reason: 'Error in $tag: $message',
          fatal: false,
        );
      } catch (e) {
        print('Crashlytics recording failed: $e');
      }
    }
  }
  
  // 성능 로깅을 위한 메서드
  Stopwatch startPerformanceMeasurement(String tag, String operation) {
    final stopwatch = Stopwatch()..start();
    if (_currentLogLevel <= DEBUG) {
      print('⏱️ D/$tag: Started $operation');
    }
    return stopwatch;
  }
  
  void endPerformanceMeasurement(Stopwatch stopwatch, String tag, String operation) {
    stopwatch.stop();
    if (_currentLogLevel <= DEBUG) {
      print('⏱️ D/$tag: $operation completed in ${stopwatch.elapsedMilliseconds}ms');
    }
  }
}
