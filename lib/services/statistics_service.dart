import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class StatisticsService {
  static final StatisticsService _instance = StatisticsService._internal();
  factory StatisticsService() => _instance;
  
  FirebaseFirestore? _firestore;
  
  StatisticsService._internal();

  // Firebase 초기화 메서드
  void initialize(FirebaseFirestore firestoreInstance) {
    _firestore = firestoreInstance;
  }

  // Firebase 사용 가능 여부 확인
  Future<bool> _isFirebaseAvailable() async {
    if (_firestore == null) return false;
    
    try {
      // 간단한 연결 테스트
      QuerySnapshot testSnapshot = await _firestore!
          .collection('todos')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));
      
      print('✅ Firebase 연결 성공!');
      return true;
    } catch (e) {
      print('❌ Firebase 연결 실패: $e');
      return false;
    }
  }

  // 실제 할일 데이터에서 일일 통계 생성 (Firebase 전용)
  Future<DailyStats> _getDailyStatsFromFirebase(DateTime date) async {
    try {
      String dateKey = DateFormat('yyyy-MM-dd').format(date);
      print('🔄 Firebase에서 일일 통계 로드: $dateKey');
      
      // 1. 기존 통계 데이터 확인
      DocumentSnapshot dailyDoc = await _firestore!
          .collection('statistics')
          .doc('daily')
          .collection('data')
          .doc(dateKey)
          .get();
      
      // 2. 모든 todos 가져와서 클라이언트에서 필터링
      QuerySnapshot todosSnapshot = await _firestore!
          .collection('todos')
          .get();
      
      print('📦 Firestore에서 받은 할일 개수: ${todosSnapshot.docs.length}');
      
      // 3. 클라이언트에서 날짜와 사용자 필터링 (수정됨)
      DateTime startOfDay = DateTime(date.year, date.month, date.day);
      DateTime endOfDay = startOfDay.add(Duration(days: 1));
      
      print('🗓️ 필터링 기준: ${dateKey}');
      print('   시작: $startOfDay');
      print('   종료: $endOfDay (미포함)');
      
      List<QueryDocumentSnapshot> filteredTodos = todosSnapshot.docs.where((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        // 사용자 확인
        String userId = data['userId'] ?? '';
        bool userMatch = userId == 'anonymous';
        
        // 날짜 확인 - dueDate 기준으로 해당 날짜에 속하는지 확인
        Timestamp? dueDate = data['dueDate'] as Timestamp?;
        bool dateMatch = false;
        
        if (dueDate != null) {
          DateTime todoDate = dueDate.toDate();
          // 수정: >= startOfDay && < endOfDay 로 변경 (해당 날짜 포함)
          dateMatch = todoDate.isAtSameMomentAs(startOfDay) || 
                     (todoDate.isAfter(startOfDay) && todoDate.isBefore(endOfDay));
          
          print('   📅 할일 "${data['title']}" (${data['category']})');
          print('      dueDate: $todoDate');
          print('      사용자: $userId, 날짜매치: $dateMatch, 완료: ${data['isCompleted']}');
        }
        
        bool shouldInclude = userMatch && dateMatch;
        return shouldInclude;
      }).toList();
      
      print('✅ 필터링된 할일 개수: ${filteredTodos.length}');
      
      // 4. todos 데이터에서 통계 계산 - isCompleted: true인 것만 카운팅 (기존 데이터와 합치지 않음)
      int totalTasks = filteredTodos.length;
      int completedTasks = 0;
      int totalStudyTime = 0;
      Map<String, int> categoryTime = {};
      
      // 완료된 할일과 미완료 할일 분리
      List<QueryDocumentSnapshot> completedTodos = [];
      List<QueryDocumentSnapshot> incompleteTodos = [];
      
      for (QueryDocumentSnapshot doc in filteredTodos) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        bool isCompleted = data['isCompleted'] ?? false;
        
        if (isCompleted) {
          completedTodos.add(doc);
        } else {
          incompleteTodos.add(doc);
        }
      }
      
      print('📊 할일 분류: 총 ${totalTasks}개 (완료: ${completedTodos.length}개, 미완료: ${incompleteTodos.length}개)');
      
      // 완료된 할일만 통계에 포함
      for (QueryDocumentSnapshot doc in completedTodos) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        String category = data['category'] ?? '기타';
        int estimatedMinutes = data['estimatedMinutes'] ?? 0;
        String title = data['title'] ?? '제목없음';
        
        print('✅ 완료된 할일: "$title" (${category}, ${estimatedMinutes}분)');
        
        completedTasks++;
        totalStudyTime += estimatedMinutes;
        categoryTime[category] = (categoryTime[category] ?? 0) + estimatedMinutes;
      }
      
      // 미완료 할일은 로그만 출력 (통계에 포함하지 않음)
      for (QueryDocumentSnapshot doc in incompleteTodos) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String title = data['title'] ?? '제목없음';
        String category = data['category'] ?? '기타';
        int estimatedMinutes = data['estimatedMinutes'] ?? 0;
        
        print('⏳ 미완료 할일: "$title" (${category}, ${estimatedMinutes}분) - 통계에서 제외');
      }
      
      // 기존 statistics 데이터는 무시하고 순수 todos 데이터만 사용
      List<String> achievements = _generateAchievements(completedTasks, totalStudyTime);
      
      print('📊 최종 통계 결과 (순수 todos 데이터): 완료 $completedTasks/$totalTasks, 총 시간 ${totalStudyTime}분');
      print('   카테고리별: $categoryTime');
      
      // 6. Firebase에 새로운 통계 저장 (기존 데이터 덮어쓰기)
      await _firestore!
          .collection('statistics')
          .doc('daily')
          .collection('data')
          .doc(dateKey)
          .set({
        'date': date.toIso8601String(),
        'studyTimeMinutes': totalStudyTime,
        'completedTasks': completedTasks,
        'totalTasks': totalTasks,
        'categoryTime': categoryTime,
        'achievements': achievements,
        'updatedAt': FieldValue.serverTimestamp(),
        'dataSource': 'todos_only', // 순수 todos 데이터임을 표시
      });
      
      Map<int, int> hourlyActivity = {};
      for (QueryDocumentSnapshot doc in completedTodos) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        int estimatedMinutes = data['estimatedMinutes'] ?? 0;
        
        // completedAt 시간을 사용
        Timestamp? completedAt = data['completedAt'] as Timestamp?;
        if (completedAt != null) {
          DateTime completedTime = completedAt.toDate();
          int hour = completedTime.hour;
          hourlyActivity[hour] = (hourlyActivity[hour] ?? 0) + estimatedMinutes;
        }
      }
      
      return DailyStats(
        date: date,
        studyTimeMinutes: totalStudyTime,
        completedTasks: completedTasks,
        totalTasks: totalTasks,
        categoryTime: categoryTime,
        achievements: achievements,
        hourlyActivity: hourlyActivity,
      );
      
    } catch (e) {
      print('❌ Firebase 일일 통계 로드 실패: $e');
      return DailyStats.empty(date);
    }
  }

  // 성취 목록 생성
  List<String> _generateAchievements(int completedTasks, int studyTime) {
    List<String> achievements = [];
    
    if (completedTasks >= 5) achievements.add('할일 마스터');
    if (studyTime >= 120) achievements.add('집중력 왕');
    if (completedTasks > 0 && studyTime > 0) achievements.add('꾸준함');
    if (studyTime >= 180) achievements.add('3시간 달성');
    if (completedTasks >= 8) achievements.add('완벽주의자');
    
    return achievements;
  }

  // 일일 통계 데이터 가져오기 (Firebase 전용)
  Future<DailyStats> getDailyStats(DateTime date) async {
    if (await _isFirebaseAvailable()) {
      return await _getDailyStatsFromFirebase(date);
    } else {
      print('🔌 Firebase 연결 없음 - 빈 데이터 반환');
      return DailyStats.empty(date);
    }
  }

  // 주간 통계 데이터 가져오기 (Firebase 전용) - todos에서 직접 가져와서 isCompleted만 카운팅
  Future<List<DailyStats>> getWeeklyStats() async {
    if (!await _isFirebaseAvailable()) {
      print('🔌 Firebase 연결 없음 - 빈 주간 데이터 반환');
      return [];
    }

    try {
      print('🔄 Firebase 주간 통계 데이터 로드 (todos에서 isCompleted만)');
      
      // todos 컬렉션에서 모든 데이터 가져오기
      QuerySnapshot todosSnapshot = await _firestore!
          .collection('todos')
          .get();
      
      print('📦 Firestore에서 받은 할일 개수: ${todosSnapshot.docs.length}');
      
      List<DailyStats> weeklyData = [];
      DateTime now = DateTime.now();
      
      // 최근 7일간의 데이터 생성
      for (int i = 6; i >= 0; i--) {
        DateTime date = now.subtract(Duration(days: i));
        DateTime startOfDay = DateTime(date.year, date.month, date.day);
        DateTime endOfDay = startOfDay.add(Duration(days: 1));
        
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        print('📅 처리 중인 날짜: $dateKey');
        
        // 해당 날짜의 할일들 필터링
        List<QueryDocumentSnapshot> dayTodos = todosSnapshot.docs.where((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          
          String userId = data['userId'] ?? '';
          bool userMatch = userId == 'anonymous';
          
          Timestamp? dueDate = data['dueDate'] as Timestamp?;
          bool dateMatch = false;
          
          if (dueDate != null) {
            DateTime todoDate = dueDate.toDate();
            dateMatch = todoDate.isAtSameMomentAs(startOfDay) || 
                       (todoDate.isAfter(startOfDay) && todoDate.isBefore(endOfDay));
          }
          
          return userMatch && dateMatch;
        }).toList();
        
        // isCompleted: true인 할일만 통계에 포함
        int totalTasks = dayTodos.length;
        int completedTasks = 0;
        int totalStudyTime = 0;
        Map<String, int> categoryTime = {};
        
        for (QueryDocumentSnapshot doc in dayTodos) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          bool isCompleted = data['isCompleted'] ?? false;
          
          if (isCompleted) {
            String category = data['category'] ?? '기타';
            int estimatedMinutes = data['estimatedMinutes'] ?? 0;
            String title = data['title'] ?? '제목없음';
            
            completedTasks++;
            totalStudyTime += estimatedMinutes;
            categoryTime[category] = (categoryTime[category] ?? 0) + estimatedMinutes;
            
            print('✅ $dateKey - 완료된 할일: "$title" (${category}, ${estimatedMinutes}분)');
          }
        }
        
        // 해당 날짜의 완료된 할일들로 hourlyActivity 생성
        Map<int, int> hourlyActivity = {};
        List<QueryDocumentSnapshot> completedDayTodos = dayTodos.where((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return data['isCompleted'] ?? false;
        }).toList();
        
        for (QueryDocumentSnapshot doc in completedDayTodos) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          int estimatedMinutes = data['estimatedMinutes'] ?? 0;
          
          Timestamp? completedAt = data['completedAt'] as Timestamp?;
          if (completedAt != null) {
            DateTime completedTime = completedAt.toDate();
            int hour = completedTime.hour;
            hourlyActivity[hour] = (hourlyActivity[hour] ?? 0) + estimatedMinutes;
          }
        }
        
        print('📊 $dateKey 통계: 완료 $completedTasks/$totalTasks, 총 시간 ${totalStudyTime}분');
        
        DailyStats dailyStats = DailyStats(
          date: date,
          studyTimeMinutes: totalStudyTime,
          completedTasks: completedTasks,
          totalTasks: totalTasks,
          categoryTime: categoryTime,
          achievements: _generateAchievements(completedTasks, totalStudyTime),
          hourlyActivity: hourlyActivity,
        );
        
        weeklyData.add(dailyStats);
      }
      
      return weeklyData;
    } catch (e) {
      print('❌ 주간 통계 로드 실패: $e');
      return [];
    }
  }

  // 월간 통계 데이터 가져오기 (Firebase 전용) - todos에서 직접 가져와서 isCompleted만 카운팅
  Future<List<DailyStats>> getMonthlyStats() async {
    if (!await _isFirebaseAvailable()) {
      print('🔌 Firebase 연결 없음 - 빈 월간 데이터 반환');
      return [];
    }

    try {
      print('🔄 Firebase 월간 통계 데이터 로드 (todos에서 isCompleted만)');
      
      // todos 컬렉션에서 모든 데이터 가져오기
      QuerySnapshot todosSnapshot = await _firestore!
          .collection('todos')
          .get();
      
      print('📦 Firestore에서 받은 할일 개수: ${todosSnapshot.docs.length}');
      
      List<DailyStats> monthlyData = [];
      DateTime now = DateTime.now();
      
      // 최근 30일간의 데이터 생성
      for (int i = 29; i >= 0; i--) {
        DateTime date = now.subtract(Duration(days: i));
        DateTime startOfDay = DateTime(date.year, date.month, date.day);
        DateTime endOfDay = startOfDay.add(Duration(days: 1));
        
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        
        // 해당 날짜의 할일들 필터링
        List<QueryDocumentSnapshot> dayTodos = todosSnapshot.docs.where((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          
          String userId = data['userId'] ?? '';
          bool userMatch = userId == 'anonymous';
          
          Timestamp? dueDate = data['dueDate'] as Timestamp?;
          bool dateMatch = false;
          
          if (dueDate != null) {
            DateTime todoDate = dueDate.toDate();
            dateMatch = todoDate.isAtSameMomentAs(startOfDay) || 
                       (todoDate.isAfter(startOfDay) && todoDate.isBefore(endOfDay));
          }
          
          return userMatch && dateMatch;
        }).toList();
        
        // isCompleted: true인 할일만 통계에 포함
        int totalTasks = dayTodos.length;
        int completedTasks = 0;
        int totalStudyTime = 0;
        Map<String, int> categoryTime = {};
        
        for (QueryDocumentSnapshot doc in dayTodos) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          bool isCompleted = data['isCompleted'] ?? false;
          
          if (isCompleted) {
            String category = data['category'] ?? '기타';
            int estimatedMinutes = data['estimatedMinutes'] ?? 0;
            
            completedTasks++;
            totalStudyTime += estimatedMinutes;
            categoryTime[category] = (categoryTime[category] ?? 0) + estimatedMinutes;
          }
        }
        
        // 해당 날짜의 완료된 할일들로 hourlyActivity 생성
        Map<int, int> hourlyActivity = {};
        List<QueryDocumentSnapshot> completedDayTodos = dayTodos.where((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return data['isCompleted'] ?? false;
        }).toList();
        
        for (QueryDocumentSnapshot doc in completedDayTodos) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          int estimatedMinutes = data['estimatedMinutes'] ?? 0;
          
          Timestamp? completedAt = data['completedAt'] as Timestamp?;
          if (completedAt != null) {
            DateTime completedTime = completedAt.toDate();
            int hour = completedTime.hour;
            hourlyActivity[hour] = (hourlyActivity[hour] ?? 0) + estimatedMinutes;
          }
        }
        
        if (totalStudyTime > 0) {
          print('📊 $dateKey 통계: 완료 $completedTasks/$totalTasks, 총 시간 ${totalStudyTime}분');
        }
        
        DailyStats dailyStats = DailyStats(
          date: date,
          studyTimeMinutes: totalStudyTime,
          completedTasks: completedTasks,
          totalTasks: totalTasks,
          categoryTime: categoryTime,
          achievements: _generateAchievements(completedTasks, totalStudyTime),
          hourlyActivity: hourlyActivity,
        );
        
        monthlyData.add(dailyStats);
      }
      
      return monthlyData;
    } catch (e) {
      print('❌ 월간 통계 로드 실패: $e');
      return [];
    }
  }

  // 연간 통계 데이터 가져오기 (Firebase 전용) - todos에서 직접 가져와서 isCompleted만 카운팅
  Future<List<MonthlyStats>> getYearlyStats() async {
    if (!await _isFirebaseAvailable()) {
      print('🔌 Firebase 연결 없음 - 빈 연간 데이터 반환');
      return [];
    }

    try {
      print('🔄 Firebase 연간 통계 데이터 로드 (todos에서 isCompleted만)');
      
      // todos 컬렉션에서 모든 데이터 가져오기
      QuerySnapshot todosSnapshot = await _firestore!
          .collection('todos')
          .get();
      
      print('📦 Firestore에서 받은 할일 개수: ${todosSnapshot.docs.length}');
      
      DateTime now = DateTime.now();
      List<MonthlyStats> yearlyData = [];
      
      // 최근 12개월간의 데이터 생성
      for (int i = 11; i >= 0; i--) {
        DateTime month = DateTime(now.year, now.month - i, 1);
        DateTime startOfMonth = month;
        DateTime endOfMonth = DateTime(month.year, month.month + 1, 1);
        
        print('📅 처리 중인 월: ${month.year}년 ${month.month}월');
        
        // 해당 월의 할일들 필터링
        List<QueryDocumentSnapshot> monthTodos = todosSnapshot.docs.where((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          
          String userId = data['userId'] ?? '';
          bool userMatch = userId == 'anonymous';
          
          Timestamp? dueDate = data['dueDate'] as Timestamp?;
          bool dateMatch = false;
          
          if (dueDate != null) {
            DateTime todoDate = dueDate.toDate();
            dateMatch = todoDate.isAfter(startOfMonth.subtract(Duration(days: 1))) && 
                       todoDate.isBefore(endOfMonth);
          }
          
          return userMatch && dateMatch;
        }).toList();
        
        // isCompleted: true인 할일만 통계에 포함
        int totalTasks = monthTodos.length;
        int completedTasks = 0;
        int totalStudyTime = 0;
        Map<String, int> categoryTime = {};
        
        for (QueryDocumentSnapshot doc in monthTodos) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          bool isCompleted = data['isCompleted'] ?? false;
          
          if (isCompleted) {
            String category = data['category'] ?? '기타';
            int estimatedMinutes = data['estimatedMinutes'] ?? 0;
            
            completedTasks++;
            totalStudyTime += estimatedMinutes;
            categoryTime[category] = (categoryTime[category] ?? 0) + estimatedMinutes;
          }
        }
        
        if (totalStudyTime > 0) {
          print('📊 ${month.year}년 ${month.month}월 통계: 완료 $completedTasks/$totalTasks, 총 시간 ${totalStudyTime}분');
        }
        
        double averageDaily = totalStudyTime > 0 ? totalStudyTime / DateTime(month.year, month.month + 1, 0).day : 0.0;
        
        MonthlyStats monthlyStats = MonthlyStats(
          month: month,
          totalStudyTimeMinutes: totalStudyTime,
          totalCompletedTasks: completedTasks,
          totalTasks: totalTasks,
          averageDailyStudyTime: averageDaily,
          categoryTime: categoryTime,
          achievements: _generateMonthlyAchievements([]), // 빈 배열로 전달
        );
        
        yearlyData.add(monthlyStats);
      }
      
      return yearlyData;
    } catch (e) {
      print('❌ 연간 통계 로드 실패: $e');
      return [];
    }
  }

  // 주간 배지 생성
  List<String> _generateWeeklyAchievements(List<DailyStats> weeklyData) {
    List<String> achievements = [];
    
    if (weeklyData.isEmpty) return achievements;
    
    int totalStudyTime = weeklyData.fold(0, (sum, stat) => sum + stat.studyTimeMinutes);
    int totalCompleted = weeklyData.fold(0, (sum, stat) => sum + stat.completedTasks);
    int activeDays = weeklyData.where((stat) => stat.studyTimeMinutes > 0).length;
    
    if (activeDays >= 7) achievements.add('완벽한 주');
    if (activeDays >= 5) achievements.add('주간 꾸준함');
    if (totalStudyTime >= 840) achievements.add('주간 14시간');
    if (totalCompleted >= 35) achievements.add('주간 할일 마스터');
    if (totalStudyTime >= 1200) achievements.add('주간 집중왕');
    
    return achievements;
  }

  // 월간 배지 생성
  List<String> _generateMonthlyAchievements(List<DailyStats> monthlyData) {
    List<String> achievements = [];
    
    if (monthlyData.isEmpty) return achievements;
    
    int totalStudyTime = monthlyData.fold(0, (sum, stat) => sum + stat.studyTimeMinutes);
    int totalCompleted = monthlyData.fold(0, (sum, stat) => sum + stat.completedTasks);
    int activeDays = monthlyData.where((stat) => stat.studyTimeMinutes > 0).length;
    
    if (activeDays >= 25) achievements.add('월간 꾸준함');
    if (activeDays >= 30) achievements.add('완벽한 달');
    if (totalStudyTime >= 3600) achievements.add('월간 60시간');
    if (totalCompleted >= 150) achievements.add('월간 할일 마스터');
    if (totalStudyTime >= 5400) achievements.add('월간 집중왕');
    
    return achievements;
  }

  // 연간 배지 생성
  List<String> _generateYearlyAchievements(List<MonthlyStats> yearlyData) {
    List<String> achievements = [];
    
    if (yearlyData.isEmpty) return achievements;
    
    int totalStudyTime = yearlyData.fold(0, (sum, stat) => sum + stat.totalStudyTimeMinutes);
    int totalCompleted = yearlyData.fold(0, (sum, stat) => sum + stat.totalCompletedTasks);
    int activeMonths = yearlyData.where((stat) => stat.totalStudyTimeMinutes > 0).length;
    
    if (activeMonths >= 12) achievements.add('완벽한 해');
    if (activeMonths >= 10) achievements.add('연간 꾸준함');
    if (totalStudyTime >= 43200) achievements.add('연간 720시간');
    if (totalCompleted >= 1800) achievements.add('연간 할일 마스터');
    if (totalStudyTime >= 72000) achievements.add('연간 집중왕');
    
    return achievements;
  }

  // 주간 배지 가져오기
  Future<List<String>> getWeeklyAchievements() async {
    try {
      List<DailyStats> weeklyData = await getWeeklyStats();
      return _generateWeeklyAchievements(weeklyData);
    } catch (e) {
      print('❌ 주간 배지 로드 실패: $e');
      return [];
    }
  }

  // 월간 배지 가져오기
  Future<List<String>> getMonthlyAchievements() async {
    try {
      List<DailyStats> monthlyData = await getMonthlyStats();
      return _generateMonthlyAchievements(monthlyData);
    } catch (e) {
      print('❌ 월간 배지 로드 실패: $e');
      return [];
    }
  }

  // 연간 배지 가져오기
  Future<List<String>> getYearlyAchievements() async {
    try {
      List<MonthlyStats> yearlyData = await getYearlyStats();
      return _generateYearlyAchievements(yearlyData);
    } catch (e) {
      print('❌ 연간 배지 로드 실패: $e');
      return [];
    }
  }

  // 일간 배지 가져오기
  Future<List<String>> getDailyAchievements(DateTime date) async {
    try {
      DailyStats dailyStats = await getDailyStats(date);
      return dailyStats.achievements;
    } catch (e) {
      print('❌ 일간 배지 로드 실패: $e');
      return [];
    }
  }

  // 카테고리 목록 가져오기
  Future<List<String>> getCategories() async {
    try {
      if (await _isFirebaseAvailable()) {
        QuerySnapshot snapshot = await _firestore!
            .collection('categories')
            .get();
        List<String> categories = [];
        for (QueryDocumentSnapshot doc in snapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String name = data['name'] ?? '';
          if (name.isNotEmpty) {
            categories.add(name);
          }
        }
        return categories.isNotEmpty ? categories : ['프로젝트', '공부', '운동', '기타'];
      }
    } catch (e) {
      print('❌ 카테고리 로드 실패: $e');
    }
    return ['프로젝트', '공부', '운동', '기타'];
  }

  // 특정 주간의 통계 데이터 가져오기 (Firebase 전용)
  Future<List<DailyStats>> getSpecificWeekStats(DateTime selectedWeek) async {
    if (!await _isFirebaseAvailable()) {
      print('🔌 Firebase 연결 없음 - 빈 주간 데이터 반환');
      return [];
    }

    try {
      DateTime startOfWeek = selectedWeek.subtract(Duration(days: selectedWeek.weekday - 1));
      DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
      
      print('🔄 Firebase 특정 주간 통계 데이터 로드: ${DateFormat('yyyy.MM.dd').format(startOfWeek)} - ${DateFormat('yyyy.MM.dd').format(endOfWeek)}');
      
      // todos 컬렉션에서 모든 데이터 가져오기
      QuerySnapshot todosSnapshot = await _firestore!
          .collection('todos')
          .get();
      
      List<DailyStats> weeklyData = [];
      
      // 선택된 주의 7일간 데이터 생성
      for (int i = 0; i < 7; i++) {
        DateTime date = startOfWeek.add(Duration(days: i));
        DateTime startOfDay = DateTime(date.year, date.month, date.day);
        DateTime endOfDay = startOfDay.add(Duration(days: 1));
        
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        
        // 해당 날짜의 할일들 필터링
        List<QueryDocumentSnapshot> dayTodos = todosSnapshot.docs.where((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          
          String userId = data['userId'] ?? '';
          bool userMatch = userId == 'anonymous';
          
          Timestamp? dueDate = data['dueDate'] as Timestamp?;
          bool dateMatch = false;
          
          if (dueDate != null) {
            DateTime todoDate = dueDate.toDate();
            dateMatch = todoDate.isAtSameMomentAs(startOfDay) || 
                       (todoDate.isAfter(startOfDay) && todoDate.isBefore(endOfDay));
          }
          
          return userMatch && dateMatch;
        }).toList();
        
        // isCompleted: true인 할일만 통계에 포함
        int totalTasks = dayTodos.length;
        int completedTasks = 0;
        int totalStudyTime = 0;
        Map<String, int> categoryTime = {};
        Map<int, int> hourlyActivity = {};
        
        List<QueryDocumentSnapshot> completedTodos = dayTodos.where((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return data['isCompleted'] ?? false;
        }).toList();
        
        for (QueryDocumentSnapshot doc in completedTodos) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String category = data['category'] ?? '기타';
          int estimatedMinutes = data['estimatedMinutes'] ?? 0;
          
          completedTasks++;
          totalStudyTime += estimatedMinutes;
          categoryTime[category] = (categoryTime[category] ?? 0) + estimatedMinutes;
          
          // completedAt 시간을 사용
          Timestamp? completedAt = data['completedAt'] as Timestamp?;
          if (completedAt != null) {
            DateTime completedTime = completedAt.toDate();
            int hour = completedTime.hour;
            hourlyActivity[hour] = (hourlyActivity[hour] ?? 0) + estimatedMinutes;
          }
        }
        
        DailyStats dailyStats = DailyStats(
          date: date,
          studyTimeMinutes: totalStudyTime,
          completedTasks: completedTasks,
          totalTasks: totalTasks,
          categoryTime: categoryTime,
          achievements: _generateAchievements(completedTasks, totalStudyTime),
          hourlyActivity: hourlyActivity,
        );
        
        weeklyData.add(dailyStats);
      }
      
      return weeklyData;
    } catch (e) {
      print('❌ 특정 주간 통계 로드 실패: $e');
      return [];
    }
  }

  // 특정 월간의 통계 데이터 가져오기 (Firebase 전용)
  Future<List<DailyStats>> getSpecificMonthStats(DateTime selectedMonth) async {
    if (!await _isFirebaseAvailable()) {
      print('🔌 Firebase 연결 없음 - 빈 월간 데이터 반환');
      return [];
    }

    try {
      DateTime startOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
      DateTime endOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
      int daysInMonth = endOfMonth.subtract(Duration(days: 1)).day;
      
      print('🔄 Firebase 특정 월간 통계 데이터 로드: ${DateFormat('yyyy년 MM월').format(selectedMonth)}');
      
      // todos 컬렉션에서 모든 데이터 가져오기
      QuerySnapshot todosSnapshot = await _firestore!
          .collection('todos')
          .get();
      
      List<DailyStats> monthlyData = [];
      
      // 선택된 월의 모든 날 데이터 생성
      for (int i = 0; i < daysInMonth; i++) {
        DateTime date = startOfMonth.add(Duration(days: i));
        DateTime startOfDay = DateTime(date.year, date.month, date.day);
        DateTime endOfDay = startOfDay.add(Duration(days: 1));
        
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        
        // 해당 날짜의 할일들 필터링
        List<QueryDocumentSnapshot> dayTodos = todosSnapshot.docs.where((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          
          String userId = data['userId'] ?? '';
          bool userMatch = userId == 'anonymous';
          
          Timestamp? dueDate = data['dueDate'] as Timestamp?;
          bool dateMatch = false;
          
          if (dueDate != null) {
            DateTime todoDate = dueDate.toDate();
            dateMatch = todoDate.isAtSameMomentAs(startOfDay) || 
                       (todoDate.isAfter(startOfDay) && todoDate.isBefore(endOfDay));
          }
          
          return userMatch && dateMatch;
        }).toList();
        
        // isCompleted: true인 할일만 통계에 포함
        int totalTasks = dayTodos.length;
        int completedTasks = 0;
        int totalStudyTime = 0;
        Map<String, int> categoryTime = {};
        Map<int, int> hourlyActivity = {};
        
        List<QueryDocumentSnapshot> completedTodos = dayTodos.where((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return data['isCompleted'] ?? false;
        }).toList();
        
        for (QueryDocumentSnapshot doc in completedTodos) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String category = data['category'] ?? '기타';
          int estimatedMinutes = data['estimatedMinutes'] ?? 0;
          
          completedTasks++;
          totalStudyTime += estimatedMinutes;
          categoryTime[category] = (categoryTime[category] ?? 0) + estimatedMinutes;
          
          // completedAt 시간을 사용
          Timestamp? completedAt = data['completedAt'] as Timestamp?;
          if (completedAt != null) {
            DateTime completedTime = completedAt.toDate();
            int hour = completedTime.hour;
            hourlyActivity[hour] = (hourlyActivity[hour] ?? 0) + estimatedMinutes;
          }
        }
        
        DailyStats dailyStats = DailyStats(
          date: date,
          studyTimeMinutes: totalStudyTime,
          completedTasks: completedTasks,
          totalTasks: totalTasks,
          categoryTime: categoryTime,
          achievements: _generateAchievements(completedTasks, totalStudyTime),
          hourlyActivity: hourlyActivity,
        );
        
        monthlyData.add(dailyStats);
      }
      
      return monthlyData;
    } catch (e) {
      print('❌ 특정 월간 통계 로드 실패: $e');
      return [];
    }
  }

  // 특정 연도의 통계 데이터 가져오기 (Firebase 전용)
  Future<List<MonthlyStats>> getSpecificYearStats(DateTime selectedYear) async {
    if (!await _isFirebaseAvailable()) {
      print('🔌 Firebase 연결 없음 - 빈 연간 데이터 반환');
      return [];
    }

    try {
      int year = selectedYear.year;
      print('🔄 Firebase 특정 연간 통계 데이터 로드: ${year}년');
      
      // todos 컬렉션에서 모든 데이터 가져오기
      QuerySnapshot todosSnapshot = await _firestore!
          .collection('todos')
          .get();
      
      List<MonthlyStats> yearlyData = [];
      
      // 선택된 연도의 12개월 데이터 생성
      for (int month = 1; month <= 12; month++) {
        DateTime startOfMonth = DateTime(year, month, 1);
        DateTime endOfMonth = DateTime(year, month + 1, 1);
        
        // 해당 월의 할일들 필터링
        List<QueryDocumentSnapshot> monthTodos = todosSnapshot.docs.where((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          
          String userId = data['userId'] ?? '';
          bool userMatch = userId == 'anonymous';
          
          Timestamp? dueDate = data['dueDate'] as Timestamp?;
          bool dateMatch = false;
          
          if (dueDate != null) {
            DateTime todoDate = dueDate.toDate();
            dateMatch = todoDate.isAfter(startOfMonth.subtract(Duration(days: 1))) && 
                       todoDate.isBefore(endOfMonth);
          }
          
          return userMatch && dateMatch;
        }).toList();
        
        // isCompleted: true인 할일만 통계에 포함
        int totalTasks = monthTodos.length;
        int completedTasks = 0;
        int totalStudyTime = 0;
        Map<String, int> categoryTime = {};
        
        for (QueryDocumentSnapshot doc in monthTodos) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          bool isCompleted = data['isCompleted'] ?? false;
          
          if (isCompleted) {
            String category = data['category'] ?? '기타';
            int estimatedMinutes = data['estimatedMinutes'] ?? 0;
            
            completedTasks++;
            totalStudyTime += estimatedMinutes;
            categoryTime[category] = (categoryTime[category] ?? 0) + estimatedMinutes;
          }
        }
        
        if (totalStudyTime > 0) {
          print('📊 ${year}년 ${month}월 통계: 완료 $completedTasks/$totalTasks, 총 시간 ${totalStudyTime}분');
        }
        
        double averageDaily = totalStudyTime > 0 ? totalStudyTime / DateTime(year, month + 1, 0).day : 0.0;
        
        MonthlyStats monthlyStats = MonthlyStats(
          month: startOfMonth,
          totalStudyTimeMinutes: totalStudyTime,
          totalCompletedTasks: completedTasks,
          totalTasks: totalTasks,
          averageDailyStudyTime: averageDaily,
          categoryTime: categoryTime,
          achievements: _generateMonthlyAchievements([]), // 빈 배열로 전달
        );
        
        yearlyData.add(monthlyStats);
      }
      
      return yearlyData;
    } catch (e) {
      print('❌ 특정 연간 통계 로드 실패: $e');
      return [];
    }
  }
}

// 일일 통계 데이터 모델
class DailyStats {
  final DateTime date;
  final int studyTimeMinutes;
  final int completedTasks;
  final int totalTasks;
  final Map<String, int> categoryTime;
  final List<String> achievements;
  final Map<int, int> hourlyActivity; // 시간대별 활동 (시간: 분)

  DailyStats({
    required this.date,
    required this.studyTimeMinutes,
    required this.completedTasks,
    required this.totalTasks,
    required this.categoryTime,
    required this.achievements,
    this.hourlyActivity = const {},
  });

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      date: DateTime.parse(json['date']),
      studyTimeMinutes: json['studyTimeMinutes'] ?? 0,
      completedTasks: json['completedTasks'] ?? 0,
      totalTasks: json['totalTasks'] ?? 0,
      categoryTime: Map<String, int>.from(json['categoryTime'] ?? {}),
      achievements: List<String>.from(json['achievements'] ?? []),
      hourlyActivity: Map<int, int>.from(json['hourlyActivity'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'studyTimeMinutes': studyTimeMinutes,
      'completedTasks': completedTasks,
      'totalTasks': totalTasks,
      'categoryTime': categoryTime,
      'achievements': achievements,
      'hourlyActivity': hourlyActivity,
    };
  }

  factory DailyStats.empty(DateTime date) {
    return DailyStats(
      date: date,
      studyTimeMinutes: 0,
      completedTasks: 0,
      totalTasks: 0,
      categoryTime: {},
      achievements: [],
      hourlyActivity: {},
    );
  }

  double get completionRate => totalTasks > 0 ? completedTasks / totalTasks : 0.0;
}

// 월간 통계 데이터 모델
class MonthlyStats {
  final DateTime month;
  final int totalStudyTimeMinutes;
  final int totalCompletedTasks;
  final int totalTasks;
  final double averageDailyStudyTime;
  final Map<String, int> categoryTime;
  final List<String> achievements;

  MonthlyStats({
    required this.month,
    required this.totalStudyTimeMinutes,
    required this.totalCompletedTasks,
    required this.totalTasks,
    required this.averageDailyStudyTime,
    required this.categoryTime,
    required this.achievements,
  });

  factory MonthlyStats.fromJson(Map<String, dynamic> json) {
    return MonthlyStats(
      month: DateTime.parse(json['month']),
      totalStudyTimeMinutes: json['totalStudyTimeMinutes'] ?? 0,
      totalCompletedTasks: json['totalCompletedTasks'] ?? 0,
      totalTasks: json['totalTasks'] ?? 0,
      averageDailyStudyTime: (json['averageDailyStudyTime'] ?? 0.0).toDouble(),
      categoryTime: Map<String, int>.from(json['categoryTime'] ?? {}),
      achievements: List<String>.from(json['achievements'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month.toIso8601String(),
      'totalStudyTimeMinutes': totalStudyTimeMinutes,
      'totalCompletedTasks': totalCompletedTasks,
      'totalTasks': totalTasks,
      'averageDailyStudyTime': averageDailyStudyTime,
      'categoryTime': categoryTime,
      'achievements': achievements,
    };
  }

  factory MonthlyStats.fromDailyStats(DateTime month, List<DailyStats> dailyStats) {
    int totalStudyTime = dailyStats.fold(0, (sum, stat) => sum + stat.studyTimeMinutes);
    int totalCompleted = dailyStats.fold(0, (sum, stat) => sum + stat.completedTasks);
    int totalTasks = dailyStats.fold(0, (sum, stat) => sum + stat.totalTasks);
    
    Map<String, int> categoryTime = {};
    for (var daily in dailyStats) {
      daily.categoryTime.forEach((category, time) {
        categoryTime[category] = (categoryTime[category] ?? 0) + time;
      });
    }
    
    double averageDaily = dailyStats.isNotEmpty ? totalStudyTime / dailyStats.length : 0.0;
    
    return MonthlyStats(
      month: month,
      totalStudyTimeMinutes: totalStudyTime,
      totalCompletedTasks: totalCompleted,
      totalTasks: totalTasks,
      averageDailyStudyTime: averageDaily,
      categoryTime: categoryTime,
      achievements: [],
    );
  }

  factory MonthlyStats.empty(DateTime month) {
    return MonthlyStats(
      month: month,
      totalStudyTimeMinutes: 0,
      totalCompletedTasks: 0,
      totalTasks: 0,
      averageDailyStudyTime: 0.0,
      categoryTime: {},
      achievements: [],
    );
  }

  double get completionRate => totalTasks > 0 ? totalCompletedTasks / totalTasks : 0.0;
} 