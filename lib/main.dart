import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'pages/statistics_page.dart';
import 'pages/simple_home_page.dart';
import 'pages/ai_feedback_page.dart';
import 'pages/settings_page.dart';
import 'services/firestore_todo_service.dart';
import 'services/statistics_service.dart';

// Firestore 연결 테스트 함수
Future<void> _testFirestoreConnection(FirebaseFirestore firestore) async {
  try {
    print('🔄 Firestore 연결 테스트 시작...');
    
    // 매우 빠른 연결 테스트로 변경
    await firestore.collection('test').limit(1).get().timeout(
      const Duration(seconds: 3),
    );
    
    print('✅ Firestore 연결 테스트 성공!');
  } catch (e) {
    print('❌ Firestore 연결 테스트 실패: ${e.toString().substring(0, 100)}...');
    print('⚠️ 오프라인 모드로 동작합니다.');
    
    // 오프라인 우선 설정
    await firestore.disableNetwork();
    await firestore.enableNetwork();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase 초기화 완료!');
    
    // Firestore 및 서비스 초기화
    final firestore = FirebaseFirestore.instance;
    
    // Firestore 설정 추가 - 오프라인 우선 모드
    if (defaultTargetPlatform == TargetPlatform.android) {
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      // 오프라인 우선 모드 설정
      print('🔧 오프라인 우선 모드로 설정합니다...');
      try {
        await firestore.disableNetwork();
        await firestore.enableNetwork();
      } catch (e) {
        print('⚠️ 네트워크 설정 실패: $e');
      }
    }
    
    // 개발 환경에서 에뮬레이터 사용 (선택사항)
    if (kDebugMode) {
      try {
        // 에뮬레이터가 실행 중인 경우 연결 시도
        // firestore.useFirestoreEmulator('localhost', 8080);
        print('🔧 개발 모드에서 실행 중...');
      } catch (e) {
        print('💡 에뮬레이터 연결 실패, 실제 Firebase 사용: $e');
      }
    }
    
    final todoService = FirestoreTodoService();
    final statsService = StatisticsService();
    
    todoService.initialize(firestore);
    await statsService.initialize();
    
    print('✅ 서비스 초기화 완료!');
    print('🔍 TodoService 상태: $todoService');
    print('🔍 StatsService 상태: $statsService');
    
    // 연결 테스트
    await _testFirestoreConnection(firestore);
    
  } catch (e) {
    print('❌ Firebase 초기화 오류: $e');
    // Firebase 중복 초기화 오류인 경우 무시하고 계속 진행
    if (e.toString().contains('duplicate-app') || e.toString().contains('already exists')) {
      print('✅ Firebase 이미 초기화됨 - 계속 진행합니다.');
    }
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ThinQ 스터디 플래너',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          brightness: Brightness.light,
          primary: Colors.black,
          secondary: Colors.grey.shade700,
          surface: Colors.white,
          background: Colors.grey.shade50,
        ),
        useMaterial3: true,
        fontFamily: 'Pretendard',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey.shade400,
          elevation: 8,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const MainTabPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const SimpleHomePage(),      // 홈 (캐릭터 + 할일)
    const AIFeedbackPage(),      // AI 피드백 (생산성 분석)
    const StatisticsPage(),     // 통계 (스터디 플래너)
    const SettingsPage(),       // 환경설정
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey.shade400,
        backgroundColor: Colors.white,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome),
            label: 'AI 피드백',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: '통계',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '환경설정',
          ),
        ],
      ),
    );
  }
} 