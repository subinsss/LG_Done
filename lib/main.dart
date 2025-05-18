import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ThinQ/firebase_options.dart';
import 'package:ThinQ/pages/feed_page.dart';
import 'package:ThinQ/pages/home_page.dart';
import 'package:ThinQ/pages/login_page.dart';

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Firebase 초기화
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Firebase Remote Config 설정
      await FirebaseRemoteConfig.instance.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 0),
        ),
      );
      await FirebaseRemoteConfig.instance.fetchAndActivate();

      // 앱의 라이프사이클 이벤트를 감지합니다.
      AppLifecycleListener(
        onShow: () => _notifyActiveState(),
        onHide: () => _notifyDeactiveState(),
      );

      // Crashlytics는 웹에서 지원되지 않으므로 웹이 아닐 때만 설정
      if (!kIsWeb) {
        FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      }

      runApp(const ThinQApp());
    },
    (exception, stacktrace) async {
      print('Uncaught error: $exception');
      print(stacktrace);
      
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

class ThinQApp extends StatelessWidget {
  const ThinQApp({super.key});

  @override
  Widget build(BuildContext context) {
    // FirebaseAuth로부터 현재 로그인한 사용자 정보를 가져옵니다.
    final User? user = FirebaseAuth.instance.currentUser;

    // 만약 사용자가 로그인하지 않은 상태라면 `LoginPage`를 보여줍니다.
    // 만약 사용자가 로그인한 상태라면 `HomePage`를 보여줍니다.
    return MaterialApp(
      title: 'ThinQ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      debugShowCheckedModeBanner: false,
      home: user == null ? LoginPage() : HomePage(),
    );
  }
}

// Realtime Database에 접속 여부를 저장합니다.
Future<void> _notifyActiveState() async {
  // 현재 로그인한 사용자의 이름을 가져옵니다.
  DatabaseEvent currentData = await FirebaseDatabase.instance.ref().child("active_users").once();
  List<String?> activeUsers =
      currentData.snapshot.value == null ? [] : List<String?>.from(currentData.snapshot.value as List<dynamic>);

  // 만약 현재 로그인한 사용자의 이름이 사용자 목록에 없다면 추가합니다.
  final String? myName = FirebaseAuth.instance.currentUser?.displayName;
  if (!activeUsers.contains(myName)) {
    activeUsers.insert(0, myName);
  }

  // Realtime Database에 사용자 목록을 업데이트합니다.
  FirebaseDatabase.instance.ref().child("active_users").set(activeUsers);
}

// Realtime Database에 미접속 여부를 저장합니다.
Future<void> _notifyDeactiveState() async {
  // 현재 로그인한 사용자의 이름을 가져옵니다.
  DatabaseEvent currentData = await FirebaseDatabase.instance.ref().child("active_users").once();
  List<String?> activeUsers =
      currentData.snapshot.value == null ? [] : List<String?>.from(currentData.snapshot.value as List<dynamic>);

  // 만약 현재 로그인한 사용자의 이름이 사용자 목록에 없다면 추가합니다.
  final String? myName = FirebaseAuth.instance.currentUser?.displayName;
  if (activeUsers.contains(myName)) {
    activeUsers.remove(myName);
  }

  // Realtime Database에 사용자 목록을 업데이트합니다.
  FirebaseDatabase.instance.ref().child("active_users").set(activeUsers);
}
