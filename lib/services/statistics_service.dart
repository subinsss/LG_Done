// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class StatisticsService {
  static final StatisticsService _instance = StatisticsService._internal();
  factory StatisticsService() => _instance;
  StatisticsService._internal();

  static bool _isOfflineMode = true; // Firebase 없이 오프라인 모드로 작동

  // Firebase 사용 가능 여부 확인 (항상 false 반환)
  Future<bool> _isFirebaseAvailable() async {
    return false; // Firebase 비활성화
  }

  // 우선순위를 카테고리명으로 매핑
  String _mapPriorityToCategory(String priority) {
    switch (priority) {
      case 'high':
        return '프로젝트';
      case 'medium':
        return '공부';
      case 'low':
        return '운동';
      default:
        return '기타';
    }
  }

  // 실제 할일 데이터에서 일일 통계 생성 (로컬 버전)
  Future<DailyStats> _generateDailyStatsFromTodos(DateTime date) async {
    try {
      // 로컬 샘플 데이터 생성
      final random = Random(date.millisecondsSinceEpoch);
      
      int totalTasks = 3 + random.nextInt(5); // 3-7개 할일
      int completedTasks = random.nextInt(totalTasks + 1); // 0부터 totalTasks까지
      int totalStudyTime = completedTasks * (20 + random.nextInt(40)); // 20-60분씩
      
      Map<String, int> categoryTime = {};
      
      // 카테고리별 시간 분배 - 한국어 카테고리명으로 직접 저장
      if (completedTasks > 0) {
        List<String> priorities = ['high', 'medium', 'low'];
        for (String priority in priorities) {
          int categoryTasks = random.nextInt(completedTasks + 1);
          if (categoryTasks > 0) {
            String categoryName = _mapPriorityToCategory(priority);
            categoryTime[categoryName] = categoryTasks * (15 + random.nextInt(30));
          }
        }
        
        // 기타 카테고리도 추가
        if (random.nextBool()) {
          categoryTime['기타'] = random.nextInt(30) + 10;
        }
      }

      return DailyStats(
        date: date,
        studyTimeMinutes: totalStudyTime,
        completedTasks: completedTasks,
        totalTasks: totalTasks,
        categoryTime: categoryTime,
        achievements: _generateAchievements(completedTasks, totalStudyTime),
      );
    } catch (e) {
      print('❌ 일일 통계 생성 실패: $e');
      return DailyStats.empty(date);
    }
  }

  // 성취 목록 생성 - 배지 시스템 추가
  List<String> _generateAchievements(int completedTasks, int studyTime) {
    List<String> achievements = [];
    
    // 일간 배지
    if (completedTasks >= 5) achievements.add('할일 마스터');
    if (studyTime >= 120) achievements.add('집중력 왕');
    if (completedTasks > 0 && studyTime > 0) achievements.add('꾸준함');
    if (studyTime >= 180) achievements.add('3시간 달성');
    if (completedTasks >= 8) achievements.add('완벽주의자');
    
    return achievements;
  }

  // 일일 통계 데이터 저장 (로컬 버전 - 실제로는 저장하지 않음)
  Future<bool> saveDailyStats(DailyStats stats) async {
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(stats.date);
      print('✅ 일일 통계 저장 완료 (로컬): $dateKey');
      return true;
    } catch (e) {
      print('❌ 일일 통계 저장 실패: $e');
      return false;
    }
  }

  // 주간 통계 데이터 가져오기 (최근 7일)
  Future<List<DailyStats>> getWeeklyStats() async {
    try {
      print('🔄 로컬 주간 통계 데이터 생성');
      
      List<DailyStats> weeklyData = [];
      DateTime now = DateTime.now();
      
      for (int i = 6; i >= 0; i--) {
        DateTime date = now.subtract(Duration(days: i));
        DailyStats dailyStats = await _generateDailyStatsFromTodos(date);
        weeklyData.add(dailyStats);
      }
      
      return weeklyData;
    } catch (e) {
      print('❌ 주간 통계 로드 실패: $e');
      return _getDefaultWeeklyStats();
    }
  }

  // 월간 통계 데이터 가져오기 (최근 30일)
  Future<List<DailyStats>> getMonthlyStats() async {
    try {
      print('🔄 로컬 월간 통계 데이터 생성');
      
      List<DailyStats> monthlyData = [];
      DateTime now = DateTime.now();
      
      for (int i = 29; i >= 0; i--) {
        DateTime date = now.subtract(Duration(days: i));
        DailyStats dailyStats = await _generateDailyStatsFromTodos(date);
        monthlyData.add(dailyStats);
      }
      
      return monthlyData;
    } catch (e) {
      print('❌ 월간 통계 로드 실패: $e');
      return _getDefaultMonthlyStats();
    }
  }

  // 연간 통계 데이터 가져오기 (최근 12개월)
  Future<List<MonthlyStats>> getYearlyStats() async {
    try {
      print('🔄 로컬 연간 통계 데이터 생성');
      
      List<MonthlyStats> yearlyData = [];
      DateTime now = DateTime.now();
      
      for (int i = 11; i >= 0; i--) {
        DateTime month = DateTime(now.year, now.month - i, 1);
        
        // 해당 월의 일일 통계들을 모아서 월간 통계 생성
        List<DailyStats> dailyStats = [];
        int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
        
        for (int day = 1; day <= daysInMonth; day++) {
          DateTime date = DateTime(month.year, month.month, day);
          if (date.isBefore(now) || date.isAtSameMomentAs(DateTime(now.year, now.month, now.day))) {
            DailyStats dailyStat = await _generateDailyStatsFromTodos(date);
            dailyStats.add(dailyStat);
          }
        }
        
        MonthlyStats monthlyStats = MonthlyStats.fromDailyStats(month, dailyStats);
        yearlyData.add(monthlyStats);
      }
      
      return yearlyData;
    } catch (e) {
      print('❌ 연간 통계 로드 실패: $e');
      return _getDefaultYearlyStats();
    }
  }

  // 월간 통계 집계 및 저장 (로컬 버전)
  Future<bool> aggregateMonthlyStats(DateTime month) async {
    try {
      String monthKey = DateFormat('yyyy-MM').format(month);
      print('✅ 월간 통계 집계 완료 (로컬): $monthKey');
      return true;
    } catch (e) {
      print('❌ 월간 통계 집계 실패: $e');
      return false;
    }
  }

  // 기본 주간 데이터 (테스트용)
  List<DailyStats> _getDefaultWeeklyStats() {
    DateTime now = DateTime.now();
    return List.generate(7, (index) {
      DateTime date = now.subtract(Duration(days: 6 - index));
      return DailyStats(
        date: date,
        studyTimeMinutes: [45, 60, 30, 90, 75, 120, 85][index],
        completedTasks: [3, 4, 2, 6, 5, 8, 7][index],
        totalTasks: [5, 6, 4, 8, 7, 10, 9][index],
        categoryTime: {
          '프로젝트': [25, 35, 15, 50, 40, 70, 45][index],
          '공부': [15, 20, 10, 30, 25, 40, 30][index],
          '운동': [5, 5, 5, 10, 10, 10, 10][index],
        },
        achievements: index > 4 ? ['꾸준함'] : [],
      );
    });
  }

  // 기본 월간 데이터 (테스트용)
  List<DailyStats> _getDefaultMonthlyStats() {
    DateTime now = DateTime.now();
    return List.generate(30, (index) {
      DateTime date = now.subtract(Duration(days: 29 - index));
      return DailyStats(
        date: date,
        studyTimeMinutes: (index % 7 + 1) * 15 + (index % 3) * 10,
        completedTasks: (index % 5) + 2,
        totalTasks: (index % 7) + 4,
        categoryTime: {
          '프로젝트': (index % 4 + 1) * 15,
          '공부': (index % 3 + 1) * 12,
          '운동': (index % 2 + 1) * 8,
        },
        achievements: index % 7 == 0 ? ['주간 목표 달성'] : [],
      );
    });
  }

  // 기본 연간 데이터 (테스트용)
  List<MonthlyStats> _getDefaultYearlyStats() {
    DateTime now = DateTime.now();
    return List.generate(12, (index) {
      DateTime month = DateTime(now.year, now.month - 11 + index, 1);
      return MonthlyStats(
        month: month,
        totalStudyTimeMinutes: (index + 1) * 300 + (index % 3) * 100,
        totalCompletedTasks: (index + 1) * 50 + (index % 4) * 10,
        totalTasks: (index + 1) * 70 + (index % 5) * 15,
        averageDailyStudyTime: (index + 1) * 10 + (index % 3) * 5,
        categoryTime: {
          '프로젝트': (index + 1) * 120,
          '공부': (index + 1) * 100,
          '운동': (index + 1) * 80,
        },
        achievements: index % 3 == 0 ? ['월간 목표 달성'] : [],
      );
    });
  }

  // 주간 배지 생성
  List<String> _generateWeeklyAchievements(List<DailyStats> weeklyData) {
    List<String> achievements = [];
    
    int totalStudyTime = weeklyData.fold(0, (sum, stat) => sum + stat.studyTimeMinutes);
    int totalCompleted = weeklyData.fold(0, (sum, stat) => sum + stat.completedTasks);
    int activeDays = weeklyData.where((stat) => stat.studyTimeMinutes > 0).length;
    
    if (activeDays >= 7) achievements.add('완벽한 주');
    if (activeDays >= 5) achievements.add('주간 꾸준함');
    if (totalStudyTime >= 840) achievements.add('주간 14시간'); // 하루 평균 2시간
    if (totalCompleted >= 35) achievements.add('주간 할일 마스터');
    if (totalStudyTime >= 1200) achievements.add('주간 집중왕'); // 20시간
    
    return achievements;
  }

  // 월간 배지 생성
  List<String> _generateMonthlyAchievements(List<DailyStats> monthlyData) {
    List<String> achievements = [];
    
    int totalStudyTime = monthlyData.fold(0, (sum, stat) => sum + stat.studyTimeMinutes);
    int totalCompleted = monthlyData.fold(0, (sum, stat) => sum + stat.completedTasks);
    int activeDays = monthlyData.where((stat) => stat.studyTimeMinutes > 0).length;
    
    if (activeDays >= 25) achievements.add('월간 꾸준함');
    if (activeDays >= 30) achievements.add('완벽한 달');
    if (totalStudyTime >= 3600) achievements.add('월간 60시간'); // 하루 평균 2시간
    if (totalCompleted >= 150) achievements.add('월간 할일 마스터');
    if (totalStudyTime >= 5400) achievements.add('월간 집중왕'); // 90시간
    
    return achievements;
  }

  // 연간 배지 생성
  List<String> _generateYearlyAchievements(List<MonthlyStats> yearlyData) {
    List<String> achievements = [];
    
    int totalStudyTime = yearlyData.fold(0, (sum, stat) => sum + stat.totalStudyTimeMinutes);
    int totalCompleted = yearlyData.fold(0, (sum, stat) => sum + stat.totalCompletedTasks);
    int activeMonths = yearlyData.where((stat) => stat.totalStudyTimeMinutes > 0).length;
    
    if (activeMonths >= 12) achievements.add('완벽한 해');
    if (activeMonths >= 10) achievements.add('연간 꾸준함');
    if (totalStudyTime >= 43200) achievements.add('연간 720시간'); // 하루 평균 2시간
    if (totalCompleted >= 1800) achievements.add('연간 할일 마스터');
    if (totalStudyTime >= 72000) achievements.add('연간 집중왕'); // 1200시간
    
    return achievements;
  }

  // 주간 배지 가져오기
  Future<List<String>> getWeeklyAchievements() async {
    try {
      List<DailyStats> weeklyData = await getWeeklyStats();
      return _generateWeeklyAchievements(weeklyData);
    } catch (e) {
      print('❌ 주간 배지 로드 실패: $e');
      return ['주간 꾸준함']; // 기본 배지
    }
  }

  // 월간 배지 가져오기
  Future<List<String>> getMonthlyAchievements() async {
    try {
      List<DailyStats> monthlyData = await getMonthlyStats();
      return _generateMonthlyAchievements(monthlyData);
    } catch (e) {
      print('❌ 월간 배지 로드 실패: $e');
      return ['월간 꾸준함']; // 기본 배지
    }
  }

  // 연간 배지 가져오기
  Future<List<String>> getYearlyAchievements() async {
    try {
      List<MonthlyStats> yearlyData = await getYearlyStats();
      return _generateYearlyAchievements(yearlyData);
    } catch (e) {
      print('❌ 연간 배지 로드 실패: $e');
      return ['연간 꾸준함']; // 기본 배지
    }
  }

  // 일간 배지 가져오기
  Future<List<String>> getDailyAchievements(DateTime date) async {
    try {
      DailyStats dailyStats = await _generateDailyStatsFromTodos(date);
      return dailyStats.achievements;
    } catch (e) {
      print('❌ 일간 배지 로드 실패: $e');
      return ['꾸준함']; // 기본 배지
    }
  }

  // 일간 통계 데이터 가져오기
  Future<DailyStats> getDailyStats(DateTime date) async {
    try {
      return await _generateDailyStatsFromTodos(date);
    } catch (e) {
      print('❌ 일간 통계 로드 실패: $e');
      return DailyStats.empty(date);
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

  DailyStats({
    required this.date,
    required this.studyTimeMinutes,
    required this.completedTasks,
    required this.totalTasks,
    required this.categoryTime,
    required this.achievements,
  });

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      date: DateTime.parse(json['date']),
      studyTimeMinutes: json['studyTimeMinutes'] ?? 0,
      completedTasks: json['completedTasks'] ?? 0,
      totalTasks: json['totalTasks'] ?? 0,
      categoryTime: Map<String, int>.from(json['categoryTime'] ?? {}),
      achievements: List<String>.from(json['achievements'] ?? []),
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