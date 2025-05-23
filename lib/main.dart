import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';

// 앱 시작 시 한 번만 초기화하기 위한 전역 인스턴스
final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Firebase 초기화 (병렬 처리)
      await Future.wait([
        Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
        _initializeRemoteConfig(),
      ]);

      // 앱의 라이프사이클 이벤트를 감지합니다.
      AppLifecycleListener(
        onShow: () => _notifyActivityState(true),
        onHide: () => _notifyActivityState(false),
      );

      // Crashlytics는 웹에서 지원되지 않으므로 웹이 아닐 때만 설정
      if (!kIsWeb) {
        FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
        // 비동기 오류도 처리
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      }

      runApp(const ThinQApp());
    },
    (exception, stacktrace) async {
      print('Uncaught error: $exception');
      
      // Crashlytics는 웹에서 지원되지 않으므로 웹이 아닐 때만 설정
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.recordFlutterFatalError(
          FlutterErrorDetails(
            exception: exception,
            stack: stacktrace,
          ),
        );
      }
    },
  );
}

// Remote Config 초기화를 분리하여 코드 가독성 향상
Future<void> _initializeRemoteConfig() async {
  try {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1), // 개발 시 0, 프로덕션에서는 1시간 이상
      ),
    );
    await remoteConfig.fetchAndActivate();
  } catch (e) {
    // 오류 발생 시 기본값 사용
    print('Remote Config 초기화 오류: $e');
  }
}

class ThinQApp extends StatelessWidget {
  const ThinQApp({super.key});

  @override
  Widget build(BuildContext context) {
    // FirebaseAuth로부터 현재 로그인한 사용자 정보를 가져옵니다.
    final User? user = FirebaseAuth.instance.currentUser;

    return MaterialApp(
      title: 'ThinQ AI 어시스턴트',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: analytics),
      ],
      debugShowCheckedModeBanner: false,
      home: user == null ? const LoginPage() : const HomePage(),
    );
  }
}

// 액티비티 상태를 업데이트하는 단일 함수로 통합하여 코드 중복 방지
Future<void> _notifyActivityState(bool isActive) async {
  // 로그인 상태 확인
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  
  try {
    final DatabaseEvent currentData = await FirebaseDatabase.instance
        .ref()
        .child("active_users")
        .once();
    
    List<String?> activeUsers = [];
    if (currentData.snapshot.value != null) {
      activeUsers = List<String?>.from(currentData.snapshot.value as List<dynamic>);
    }
    
    final String? myName = user.displayName;
    
    if (isActive) {
      if (!activeUsers.contains(myName)) {
        activeUsers.insert(0, myName);
      }
    } else {
      activeUsers.remove(myName);
    }
    
    // 상태 변경 사항을 한 번만 저장
    await FirebaseDatabase.instance.ref().child("active_users").set(activeUsers);
  } catch (e) {
    print('사용자 활동 상태 업데이트 오류: $e');
  }
}
