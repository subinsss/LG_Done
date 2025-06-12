import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class StatisticsService {
  static final StatisticsService _instance = StatisticsService._internal();
  factory StatisticsService() => _instance;
  
  FirebaseFirestore? _firestore;
  bool _isInitialized = false;
  
  StatisticsService._internal();

  // Firebase 초기화 메서드
  Future<void> initialize() async {
    try {
      _firestore = FirebaseFirestore.instance;
      // 테스트 쿼리 실행하여 연결 확인
      await _firestore!.collection('todos').limit(1).get();
      _isInitialized = true;
      print('✅ Firebase 초기화 성공');
    } catch (e) {
      print('❌ Firebase 초기화 실패: $e');
      _isInitialized = false;
      _firestore = null;
    }
  }

  // Firebase 사용 가능 여부 확인
  Future<bool> _isFirebaseAvailable() async {
    if (!_isInitialized || _firestore == null) {
      await initialize();
    }
    return _isInitialized;
  }

  // 실제 작업 시간 계산 함수
  int calculateActualWorkTime(Map<String, dynamic> data) {
    try {
      String? startTime = data['start_time'];
      String? stopTime = data['stop_time'];
      
      if (startTime == null || stopTime == null) return 0;
      
      // 시작 시간과 종료 시간 파싱
      DateTime start = DateFormat('HH:mm:ss').parse(startTime);
      DateTime stop = DateFormat('HH:mm:ss').parse(stopTime);
      
      // 기본 작업 시간 계산
      int totalMinutes = stop.difference(start).inMinutes;
      
      // 일시정지 시간 계산
      int pausedMinutes = 0;
      var pauseTimes = data['pause_times'];
      var resumeTimes = data['resume_times'];
      
      if (pauseTimes != null && resumeTimes != null) {
        List<String> pauseList = [];
        List<String> resumeList = [];
        
        // 문자열 형태의 리스트를 파싱
        if (pauseTimes is String && pauseTimes.isNotEmpty) {
          pauseList = pauseTimes.replaceAll('[', '').replaceAll(']', '').split(',')
              .map((s) => s.trim().replaceAll("'", "").replaceAll('"', ''))
              .where((s) => s.isNotEmpty)
              .toList();
        } else if (pauseTimes is List) {
          pauseList = List<String>.from(pauseTimes);
        }
        
        if (resumeTimes is String && resumeTimes.isNotEmpty) {
          resumeList = resumeTimes.replaceAll('[', '').replaceAll(']', '').split(',')
              .map((s) => s.trim().replaceAll("'", "").replaceAll('"', ''))
              .where((s) => s.isNotEmpty)
              .toList();
        } else if (resumeTimes is List) {
          resumeList = List<String>.from(resumeTimes);
        }
        
        // 일시정지 시간 계산
        if (pauseList.length == resumeList.length) {
          for (int i = 0; i < pauseList.length; i++) {
            DateTime pauseTime = DateFormat('HH:mm:ss').parse(pauseList[i]);
            DateTime resumeTime = DateFormat('HH:mm:ss').parse(resumeList[i]);
            pausedMinutes += resumeTime.difference(pauseTime).inMinutes;
          }
        }
      }
      
      // 실제 작업 시간 = 전체 시간 - 일시정지 시간
      return max(0, totalMinutes - pausedMinutes);
    } catch (e) {
      print('❌ 작업 시간 계산 오류: $e');
      return 0;
    }
  }

  // 실제 할일 데이터에서 일일 통계 생성 (Firebase 전용)
  Future<DailyStats> _getDailyStatsFromFirebase(DateTime date) async {
    try {
      String dateKey = DateFormat('yyyy-MM-dd').format(date);
      print('🔄 Firebase에서 일일 통계 로드: $dateKey');
      
      QuerySnapshot todosSnapshot = await _firestore!
          .collection('todos')
          .where('userId', isEqualTo: 'anonymous')
          .get();
      
      List<QueryDocumentSnapshot> dayTodos = todosSnapshot.docs.where((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        String? dueDateString = data['due_date_string'];
        if (dueDateString == null) return false;
        
        try {
          DateTime todoDate = DateTime.parse(dueDateString);
          return todoDate.year == date.year && 
                 todoDate.month == date.month && 
                 todoDate.day == date.day;
        } catch (e) {
          return false;
        }
      }).toList();
      
      int totalTasks = dayTodos.length;
      int completedTasks = 0;
      int totalStudyTime = 0;
      Map<String, int> categoryTime = {};
      Map<int, int> hourlyActivity = {};
      
      for (var doc in dayTodos) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        bool isCompleted = data['is_completed'] ?? false;
        
        if (isCompleted) {
          String category = data['category'] ?? '기타';
          
          // 실제 작업 시간 계산
          int actualMinutes = calculateActualWorkTime(data);
          
          completedTasks++;
          totalStudyTime += actualMinutes;
          categoryTime[category] = (categoryTime[category] ?? 0) + actualMinutes;
          
          // 시간대별 활동 기록
          if (data['start_time'] != null) {
            int hour = int.parse(data['start_time'].split(':')[0]);
            hourlyActivity[hour] = (hourlyActivity[hour] ?? 0) + actualMinutes;
          }
        }
      }
      
      print('📊 $dateKey 통계: 완료 $completedTasks/$totalTasks, 총 시간 ${totalStudyTime}분');
      
      return DailyStats(
        date: date,
        studyTimeMinutes: totalStudyTime,
        completedTasks: completedTasks,
        totalTasks: totalTasks,
        categoryTime: categoryTime,
        achievements: _generateAchievements(completedTasks, totalStudyTime),
        hourlyActivity: hourlyActivity,
      );
    } catch (e) {
      print('❌ 일일 통계 로드 실패: $e');
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

  // 일일 통계 데이터 가져오기
  Future<DailyStats> getDailyStats(DateTime date) async {
    if (await _isFirebaseAvailable()) {
      try {
        return await _getDailyStatsFromFirebase(date);
      } catch (e) {
        print('❌ Firebase 데이터 로드 실패, 기본값 사용: $e');
        return _getDefaultDailyStats(date);
      }
    } else {
      print('🔌 Firebase 연결 없음 - 기본 데이터 반환');
      return _getDefaultDailyStats(date);
    }
  }

  // 기본 일일 통계 생성 (오프라인용)
  DailyStats _getDefaultDailyStats(DateTime date) {
    // 요일별로 다른 기본값 생성
    int dayOfWeek = date.weekday;
    int baseStudyTime = 60 + (dayOfWeek * 15); // 기본 1시간 + 요일별 추가시간
    int baseTasks = 3 + (dayOfWeek % 3); // 기본 3개 + 요일별 추가
    
    return DailyStats(
      date: date,
      studyTimeMinutes: baseStudyTime,
      completedTasks: baseTasks - 1,
      totalTasks: baseTasks,
      categoryTime: {
        '프로젝트': baseStudyTime ~/ 2,
        '공부': baseStudyTime ~/ 3,
        '운동': baseStudyTime ~/ 6,
      },
      achievements: _generateAchievements(baseTasks - 1, baseStudyTime),
      hourlyActivity: {
        9: baseStudyTime ~/ 3,
        14: baseStudyTime ~/ 3,
        16: baseStudyTime ~/ 3,
      },
    );
  }

  // 주간 통계 데이터 가져오기
  Future<List<DailyStats>> getWeeklyStats(DateTime selectedWeek) async {
    try {
      if (!await _isFirebaseAvailable()) {
        print('⚠️ Firebase 사용 불가 - 기본 데이터 반환');
        return _getDefaultWeeklyStats(selectedWeek);
      }

      // 해당 주의 시작일과 마지막일 계산
      DateTime startOfWeek = selectedWeek.subtract(Duration(days: selectedWeek.weekday - 1));
      DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
      
      print('📅 주간 통계 조회: ${DateFormat('yyyy.MM.dd').format(startOfWeek)} - ${DateFormat('yyyy.MM.dd').format(endOfWeek)}');

      List<DailyStats> weeklyStats = [];
      
      // 해당 주의 모든 날짜에 대해 일일 통계 가져오기
      for (int day = 0; day < 7; day++) {
        DateTime currentDate = startOfWeek.add(Duration(days: day));
        DailyStats dailyStats = await _getDailyStatsFromFirebase(currentDate);
        weeklyStats.add(dailyStats);
      }

      print('✅ 주간 통계 로드 완료: ${weeklyStats.length}일');
      return weeklyStats;
    } catch (e) {
      print('❌ 주간 통계 로드 실패: $e');
      return _getDefaultWeeklyStats(selectedWeek);
    }
  }

  // 기본 주간 데이터 (오프라인용)
  List<DailyStats> _getDefaultWeeklyStats(DateTime week) {
    DateTime startOfWeek = week.subtract(Duration(days: week.weekday - 1));
    
    return List.generate(7, (index) {
      DateTime date = startOfWeek.add(Duration(days: index));
      return DailyStats(
        date: date,
        studyTimeMinutes: (index + 1) * 10,
        completedTasks: (index % 3) + 1,
        totalTasks: (index % 5) + 2,
        categoryTime: {
          '프로젝트': (index % 2 + 1) * 15,
          '공부': (index % 3 + 1) * 10,
          '운동': (index % 2 + 1) * 5,
        },
        achievements: index % 3 == 0 ? ['일일 목표 달성'] : [],
        hourlyActivity: {},
      );
    });
  }

  // 월간 통계 데이터 가져오기
  Future<List<DailyStats>> getMonthlyStats(DateTime selectedMonth) async {
    try {
      if (!await _isFirebaseAvailable()) {
        print('⚠️ Firebase 사용 불가 - 기본 데이터 반환');
        return _getDefaultMonthlyStats(selectedMonth);
      }

      // 해당 월의 시작일과 마지막일 계산
      DateTime firstDayOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
      DateTime lastDayOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
      
      print('📅 월간 통계 조회: ${DateFormat('yyyy-MM').format(selectedMonth)}');
      print('   시작일: $firstDayOfMonth');
      print('   종료일: $lastDayOfMonth');

      List<DailyStats> monthlyStats = [];
      
      // 해당 월의 모든 날짜에 대해 일일 통계 가져오기
      for (int day = 1; day <= lastDayOfMonth.day; day++) {
        DateTime currentDate = DateTime(selectedMonth.year, selectedMonth.month, day);
        DailyStats dailyStats = await _getDailyStatsFromFirebase(currentDate);
        monthlyStats.add(dailyStats);
      }

      print('✅ 월간 통계 로드 완료: ${monthlyStats.length}일');
      return monthlyStats;
    } catch (e) {
      print('❌ 월간 통계 로드 실패: $e');
      return _getDefaultMonthlyStats(selectedMonth);
    }
  }

  // 기본 월간 데이터 (오프라인용)
  List<DailyStats> _getDefaultMonthlyStats(DateTime month) {
    // 해당 월의 일수 계산
    int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    
    return List.generate(daysInMonth, (index) {
      DateTime date = DateTime(month.year, month.month, index + 1);
      return DailyStats(
        date: date,
        studyTimeMinutes: (index + 1) * 15,
        completedTasks: (index % 4) + 1,
        totalTasks: (index % 6) + 2,
        categoryTime: {
          '프로젝트': (index % 3 + 1) * 20,
          '공부': (index % 4 + 1) * 15,
          '운동': (index % 2 + 1) * 10,
        },
        achievements: index % 5 == 0 ? ['일일 목표 달성'] : [],
        hourlyActivity: {},
      );
    });
  }

  // 연간 통계 데이터 가져오기
  Future<List<MonthlyStats>> getYearlyStats(DateTime selectedYear) async {
    try {
      print('📅 연간 통계 조회: ${selectedYear.year}');
      print('   시작일: ${selectedYear.year}-01-01 00:00:00.000');
      print('   종료일: ${selectedYear.year}-12-31 00:00:00.000');

      List<MonthlyStats> yearlyStats = [];
      DateTime now = DateTime.now();
      
      // 현재 월부터 1월까지 역순으로 처리
      for (int month = 12; month >= 1; month--) {
        DateTime monthStart = DateTime(selectedYear.year, month, 1);
        
        // 미래의 달은 건너뛰기
        if (monthStart.isAfter(now)) continue;
        
        // 해당 월의 일일 통계 데이터 수집
        List<DailyStats> monthlyDailyStats = [];
        int daysInMonth = DateTime(selectedYear.year, month + 1, 0).day;
        
        // 각 월의 마지막 날부터 첫 날까지 역순으로 처리
        for (int day = daysInMonth; day >= 1; day--) {
          DateTime date = DateTime(selectedYear.year, month, day);
          if (date.isAfter(now)) continue;
          
          DailyStats dailyStats = await getDailyStats(date);
          monthlyDailyStats.add(dailyStats);
        }
        
        // 월간 통계 생성 및 추가
        if (monthlyDailyStats.isNotEmpty) {
          MonthlyStats monthStats = _calculateMonthlyStats(monthlyDailyStats);
          yearlyStats.add(monthStats);
        }
      }
      
      print('✅ 연간 통계 로드 완료: ${yearlyStats.length}개월');
      return yearlyStats;
      
    } catch (e) {
      print('❌ 연간 통계 로드 실패: $e');
      return [];
    }
  }

  // 월간 통계 계산
  MonthlyStats _calculateMonthlyStats(List<DailyStats> dailyStats) {
    if (dailyStats.isEmpty) {
      return MonthlyStats.empty(DateTime.now());
    }

    int totalStudyTimeMinutes = 0;
    int totalCompletedTasks = 0;
    int totalTasks = 0;
    Map<String, int> categoryTime = {};
    Set<String> achievements = {};

    for (var stats in dailyStats) {
      totalStudyTimeMinutes += stats.studyTimeMinutes;
      totalCompletedTasks += stats.completedTasks;
      totalTasks += stats.totalTasks;
      
      // 카테고리별 시간 합산
      stats.categoryTime.forEach((category, time) {
        categoryTime[category] = (categoryTime[category] ?? 0) + time;
      });
      
      // 성취 목록 합치기
      achievements.addAll(stats.achievements);
    }

    double averageDailyStudyTime = dailyStats.isNotEmpty 
        ? totalStudyTimeMinutes / dailyStats.length 
        : 0;

    return MonthlyStats(
      month: dailyStats.first.date,
      totalStudyTimeMinutes: totalStudyTimeMinutes,
      totalCompletedTasks: totalCompletedTasks,
      totalTasks: totalTasks,
      averageDailyStudyTime: averageDailyStudyTime,
      categoryTime: categoryTime,
      achievements: achievements.toList(),
    );
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
      List<DailyStats> weeklyData = await getWeeklyStats(DateTime.now());
      return _generateWeeklyAchievements(weeklyData);
    } catch (e) {
      print('❌ 주간 배지 로드 실패: $e');
      return [];
    }
  }

  // 월간 배지 가져오기
  Future<List<String>> getMonthlyAchievements() async {
    try {
      List<DailyStats> monthlyData = await getMonthlyStats(DateTime.now());
      return _generateMonthlyAchievements(monthlyData);
    } catch (e) {
      print('❌ 월간 배지 로드 실패: $e');
      return [];
    }
  }

  // 연간 배지 가져오기
  Future<List<String>> getYearlyAchievements() async {
    try {
      List<MonthlyStats> yearlyData = await getYearlyStats(DateTime.now());
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
          
          bool dateMatch = false;
          
          if (data['dueDate'] != null) {
            DateTime? todoDate;
            
            // 새로운 문자열 필드 우선 체크
            if (data['due_date_string'] != null) {
              try {
                todoDate = DateTime.parse(data['due_date_string']);
              } catch (e) {
                print('❌ 날짜 파싱 오류: ${data['due_date_string']}');
              }
            }
            // 기존 dueDate 필드 체크 (하위 호환성)
            else if (data['dueDate'] != null) {
              if (data['dueDate'] is String) {
                try {
                  todoDate = DateTime.parse(data['dueDate']);
                } catch (e) {
                  print('❌ 날짜 파싱 오류: ${data['dueDate']}');
                }
              } else if (data['dueDate'] is Timestamp) {
                todoDate = (data['dueDate'] as Timestamp).toDate();
              }
            }
            
            if (todoDate != null) {
              // 날짜만 비교 (시간 무시)
              final todoDateOnly = DateTime(todoDate.year, todoDate.month, todoDate.day);
              final targetDateOnly = DateTime(date.year, date.month, date.day);
              dateMatch = todoDateOnly.isAtSameMomentAs(targetDateOnly);
            }
          }
          
          return userMatch && dateMatch;
        }).toList();
        
        // is_completed: true인 할일만 통계에 포함
        int totalTasks = dayTodos.length;
        int completedTasks = 0;
        int totalStudyTime = 0;
        Map<String, int> categoryTime = {};
        Map<int, int> hourlyActivity = {};
        
        List<QueryDocumentSnapshot> completedTodos = dayTodos.where((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return data['is_completed'] ?? data['isCompleted'] ?? false;
        }).toList();
        
        for (QueryDocumentSnapshot doc in completedTodos) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String category = data['category'] ?? '기타';
          int estimatedMinutes = 30; // 모든 할일 30분으로 고정
          
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
          
          bool dateMatch = false;
          
          if (data['dueDate'] != null) {
            DateTime? todoDate;
            
            // 새로운 문자열 필드 우선 체크
            if (data['due_date_string'] != null) {
              try {
                todoDate = DateTime.parse(data['due_date_string']);
              } catch (e) {
                print('❌ 날짜 파싱 오류: ${data['due_date_string']}');
              }
            }
            // 기존 dueDate 필드 체크 (하위 호환성)
            else if (data['dueDate'] != null) {
              if (data['dueDate'] is String) {
                try {
                  todoDate = DateTime.parse(data['dueDate']);
                } catch (e) {
                  print('❌ 날짜 파싱 오류: ${data['dueDate']}');
                }
              } else if (data['dueDate'] is Timestamp) {
                todoDate = (data['dueDate'] as Timestamp).toDate();
              }
            }
            
            if (todoDate != null) {
              // 월 범위 비교 (해당 월에 속하는지 확인)
              final todoDateOnly = DateTime(todoDate.year, todoDate.month, todoDate.day);
              dateMatch = todoDateOnly.isAfter(DateTime(date.year, date.month, 1).subtract(Duration(days: 1))) && 
                         todoDateOnly.isBefore(DateTime(date.year, date.month + 1, 1));
            }
          }
          
          return userMatch && dateMatch;
        }).toList();
        
        // is_completed: true인 할일만 통계에 포함
        int totalTasks = dayTodos.length;
        int completedTasks = 0;
        int totalStudyTime = 0;
        Map<String, int> categoryTime = {};
        Map<int, int> hourlyActivity = {};
        
        List<QueryDocumentSnapshot> completedTodos = dayTodos.where((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return data['is_completed'] ?? data['isCompleted'] ?? false;
        }).toList();
        
        for (QueryDocumentSnapshot doc in completedTodos) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String category = data['category'] ?? '기타';
          int estimatedMinutes = 30; // 모든 할일 30분으로 고정
          
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
          
          bool dateMatch = false;
          
          if (data['dueDate'] != null) {
            DateTime? todoDate;
            
            // 새로운 문자열 필드 우선 체크
            if (data['due_date_string'] != null) {
              try {
                todoDate = DateTime.parse(data['due_date_string']);
              } catch (e) {
                print('❌ 날짜 파싱 오류: ${data['due_date_string']}');
              }
            }
            // 기존 dueDate 필드 체크 (하위 호환성)
            else if (data['dueDate'] != null) {
              if (data['dueDate'] is String) {
                try {
                  todoDate = DateTime.parse(data['dueDate']);
                } catch (e) {
                  print('❌ 날짜 파싱 오류: ${data['dueDate']}');
                }
              } else if (data['dueDate'] is Timestamp) {
                todoDate = (data['dueDate'] as Timestamp).toDate();
              }
            }
            
            if (todoDate != null) {
              // 월 범위 비교 (해당 월에 속하는지 확인)
              final todoDateOnly = DateTime(todoDate.year, todoDate.month, todoDate.day);
              dateMatch = todoDateOnly.isAfter(startOfMonth.subtract(Duration(days: 1))) && 
                         todoDateOnly.isBefore(endOfMonth);
            }
          }
          
          return userMatch && dateMatch;
        }).toList();
        
        // is_completed: true인 할일만 통계에 포함
        int totalTasks = monthTodos.length;
        int completedTasks = 0;
        int totalStudyTime = 0;
        Map<String, int> categoryTime = {};
        
        for (QueryDocumentSnapshot doc in monthTodos) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          bool isCompleted = data['is_completed'] ?? data['isCompleted'] ?? false;
          
          if (isCompleted) {
            String category = data['category'] ?? '기타';
            int estimatedMinutes = 30; // 모든 할일 30분으로 고정
            
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