import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/statistics_service.dart';
import 'package:intl/intl.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  late TabController _tabController;
  
  final StatisticsService _statisticsService = StatisticsService();
  
  // 현재 선택된 기간
  final int _selectedPeriod = 0; // 0: 주간, 1: 월간, 2: 연간
  
  // 선택된 날짜
  DateTime _selectedDay = DateTime.now();
  DateTime _selectedWeek = DateTime.now();
  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedYear = DateTime.now();
  
  // 통계 데이터
  DailyStats? _dailyData;
  List<DailyStats> _weeklyData = [];
  List<DailyStats> _monthlyData = [];
  List<MonthlyStats> _yearlyData = [];
  
  // 배지 데이터
  List<String> _dailyAchievements = [];
  List<String> _weeklyAchievements = [];
  List<String> _monthlyAchievements = [];
  List<String> _yearlyAchievements = [];
  
  bool _isLoading = true;
  bool _isOfflineMode = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    
    _loadStatistics();
    _progressController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isOfflineMode = false;
    });

    try {
      print('📊 통계 데이터 로딩 시작...');
      
      // 타임아웃 설정 (10초)
      final dailyFuture = _statisticsService.getDailyStats(_selectedDay);
      final weeklyFuture = _statisticsService.getWeeklyStats();
      final monthlyFuture = _statisticsService.getMonthlyStats();
      final yearlyFuture = _statisticsService.getYearlyStats();
      
      // 배지 데이터도 함께 로드
      final dailyAchievementsFuture = _statisticsService.getDailyAchievements(_selectedDay);
      final weeklyAchievementsFuture = _statisticsService.getWeeklyAchievements();
      final monthlyAchievementsFuture = _statisticsService.getMonthlyAchievements();
      final yearlyAchievementsFuture = _statisticsService.getYearlyAchievements();
      
      // 병렬로 데이터 로드하되 타임아웃 설정
      final results = await Future.wait([
        dailyFuture.timeout(const Duration(seconds: 10)),
        weeklyFuture.timeout(const Duration(seconds: 10)),
        monthlyFuture.timeout(const Duration(seconds: 10)),
        yearlyFuture.timeout(const Duration(seconds: 10)),
        dailyAchievementsFuture.timeout(const Duration(seconds: 10)),
        weeklyAchievementsFuture.timeout(const Duration(seconds: 10)),
        monthlyAchievementsFuture.timeout(const Duration(seconds: 10)),
        yearlyAchievementsFuture.timeout(const Duration(seconds: 10)),
      ]).catchError((error) {
        print('⚠️ 통계 로딩 타임아웃 또는 오류: $error');
        // 타임아웃이나 오류 발생 시 기본 데이터 반환
        throw error; // 에러를 다시 던져서 catch 블록에서 처리
      });

      setState(() {
        _dailyData = results[0] as DailyStats;
        _weeklyData = results[1] as List<DailyStats>;
        _monthlyData = results[2] as List<DailyStats>;
        _yearlyData = _getDefaultYearlyStats();
        _dailyAchievements = results[4] as List<String>;
        _weeklyAchievements = results[5] as List<String>;
        _monthlyAchievements = results[6] as List<String>;
        _yearlyAchievements = results[7] as List<String>;
        _isLoading = false;
        _isOfflineMode = false;
        _errorMessage = null;
      });
      
      print('✅ 통계 데이터 로딩 완료');
    } catch (e) {
      print('❌ 통계 데이터 로드 실패: $e');
      
      // 오류 발생 시 기본 데이터 사용
      setState(() {
        _dailyData = DailyStats.empty(_selectedDay);
        _weeklyData = _getDefaultWeeklyStats();
        _monthlyData = _getDefaultMonthlyStats();
        _yearlyData = _getDefaultYearlyStats();
        _dailyAchievements = ['꾸준함'];
        _weeklyAchievements = ['주간 꾸준함'];
        _monthlyAchievements = ['월간 꾸준함'];
        _yearlyAchievements = ['연간 꾸준함'];
        _isLoading = false;
        _isOfflineMode = true;
        _errorMessage = 'Firebase 연결 실패로 오프라인 데이터를 표시합니다.';
      });
      
      // 사용자에게 알림 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('오프라인 모드로 전환되었습니다'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 기본 주간 데이터 (오프라인용)
  List<DailyStats> _getDefaultWeeklyStats() {
    DateTime now = DateTime.now();
    return List.generate(7, (index) {
      DateTime date = now.subtract(Duration(days: 6 - index));
      return DailyStats(
        date: date,
        studyTimeMinutes: (index + 1) * 15 + (index % 3) * 10,
        completedTasks: (index + 1) + (index % 2),
        totalTasks: (index + 2) + (index % 3),
        categoryTime: {
          '프로젝트': (index + 1) * 10,
          '공부': (index + 1) * 8,
          '운동': (index + 1) * 5,
        },
        achievements: index > 3 ? ['꾸준함'] : [],
      );
    });
  }

  // 기본 월간 데이터 (오프라인용)
  List<DailyStats> _getDefaultMonthlyStats() {
    DateTime now = DateTime.now();
    return List.generate(30, (index) {
      DateTime date = now.subtract(Duration(days: 29 - index));
      return DailyStats(
        date: date,
        studyTimeMinutes: (index + 1) * 8 + (index % 4) * 5,
        completedTasks: (index % 5) + 1,
        totalTasks: (index % 7) + 2,
        categoryTime: {
          '프로젝트': (index % 3 + 1) * 12,
          '공부': (index % 4 + 1) * 8,
          '운동': (index % 2 + 1) * 4,
        },
        achievements: index % 7 == 0 ? ['주간 목표 달성'] : [],
      );
    });
  }

  // 기본 연간 데이터 (동적 생성)
  List<MonthlyStats> _getDefaultYearlyStats() {
    int selectedYear = _selectedYear.year;
    print('🔄 연간 데이터 생성 중 - 연도: $selectedYear');
    
    return List.generate(12, (index) {
      DateTime month = DateTime(selectedYear, index + 1, 1);
      
      // 연도별로 완전히 다른 패턴 생성
      int adjustedTime;
      int adjustedTasks;
      
      if (selectedYear % 4 == 0) { // 4의 배수 연도 (예: 2024, 2020)
        // 하반기가 더 활발한 패턴
        adjustedTime = index >= 6 ? 600 + (index * 50) : 200 + (index * 30);
        adjustedTasks = index >= 6 ? 80 + (index * 5) : 40 + (index * 3);
      } else if (selectedYear % 4 == 1) { // 4로 나눈 나머지가 1 (예: 2025, 2021)
        // 상반기가 더 활발한 패턴
        adjustedTime = index < 6 ? 700 + (index * 40) : 300 + ((11 - index) * 20);
        adjustedTasks = index < 6 ? 90 + (index * 4) : 50 + ((11 - index) * 2);
      } else if (selectedYear % 4 == 2) { // 4로 나눈 나머지가 2 (예: 2026, 2022)
        // 중간이 높은 산 모양 패턴
        int centerDistance = ((index - 6).abs());
        adjustedTime = 800 - (centerDistance * 80);
        adjustedTasks = 100 - (centerDistance * 8);
      } else { // 4로 나눈 나머지가 3 (예: 2027, 2023)
        // 들쭉날쭉한 패턴
        adjustedTime = index % 2 == 0 ? 700 + (index * 20) : 300 + (index * 15);
        adjustedTasks = index % 2 == 0 ? 85 + (index * 2) : 45 + (index * 1);
      }
      
      // 최소값 보장
      adjustedTime = adjustedTime.clamp(100, 1000);
      adjustedTasks = adjustedTasks.clamp(20, 120);
      
      if (index == 0) { // 1월 데이터만 출력
        print('🔄 ${selectedYear}년 패턴 (${selectedYear % 4}): 1월 = ${adjustedTime}분');
      }
      
      return MonthlyStats(
        month: month,
        totalStudyTimeMinutes: adjustedTime,
        totalCompletedTasks: (adjustedTasks * 0.8).toInt(),
        totalTasks: adjustedTasks,
        averageDailyStudyTime: (adjustedTime ~/ 30).toDouble(),
        categoryTime: {
          '프로젝트': (adjustedTime * 0.4).toInt(),
          '공부': (adjustedTime * 0.35).toInt(),
          '운동': (adjustedTime * 0.25).toInt(),
        },
        achievements: (index + selectedYear) % 3 == 0 ? ['월간 목표 달성'] : [],
      );
    });
  }

  // 기간 변경 (이전/다음)
  void _changePeriod(String period, int direction) {
    setState(() {
      switch (period) {
        case '일간':
          _selectedDay = _selectedDay.add(Duration(days: direction));
          break;
        case '주간':
          _selectedWeek = _selectedWeek.add(Duration(days: 7 * direction));
          break;
        case '월간':
          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + direction, 1);
          break;
        case '연간':
          _selectedYear = DateTime(_selectedYear.year + direction, 1, 1);
          // 연간 데이터는 setState 안에서 즉시 업데이트
          _yearlyData = _getDefaultYearlyStats();
          return; // _loadStatistics 호출하지 않고 즉시 반환
      }
    });
    _loadStatistics(); // 새로운 기간의 데이터 로드 (연간 제외)
  }

  // 날짜 범위 텍스트 생성
  String _getDateRangeText(String period) {
    final DateFormat formatter = DateFormat('yyyy.MM.dd');
    final DateFormat monthFormatter = DateFormat('yyyy년 MM월');
    final DateFormat yearFormatter = DateFormat('yyyy년');

    switch (period) {
      case '일간':
        return formatter.format(_selectedDay);
      case '주간':
        DateTime startOfWeek = _selectedWeek.subtract(Duration(days: _selectedWeek.weekday - 1));
        DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
        return '${formatter.format(startOfWeek)} - ${formatter.format(endOfWeek)}';
      case '월간':
        return monthFormatter.format(_selectedMonth);
      case '연간':
        return yearFormatter.format(_selectedYear);
      default:
        return '';
    }
  }

  // 시간별 활동에서 실제 블록 데이터 수집
  Map<String, dynamic> _getTimeTableAnalysis() {
    Map<String, int> categoryBlocks = {};
    int totalActiveBlocks = 0;
    int totalPlannedBlocks = 0;
    
    for (int hour = 0; hour < 24; hour++) {
      for (int tenMinute = 0; tenMinute < 6; tenMinute++) {
        // 계획된 활동이 있는지 확인
        bool hasPlannedActivity = _getDetailedActivityForTimeSlot(hour, tenMinute);
        
        if (hasPlannedActivity) {
          totalPlannedBlocks++;
          
          // 해당 시간대의 활동 타입 가져오기
          String activity = _getActivityTypeForTimeSlot(hour, tenMinute * 10);
          
          // 실제 완료 여부 확인 (여기서는 계획된 것 중 일부만 완료된 것으로 시뮬레이션)
          // 날짜에 따라 일관된 완료 패턴 생성
          int dayOfMonth = _selectedDay.day;
          bool isCompleted = ((hour + tenMinute + dayOfMonth) % 3) != 0; // 약 67% 완료율
          
          if (isCompleted) {
            totalActiveBlocks++;
            categoryBlocks[activity] = (categoryBlocks[activity] ?? 0) + 1;
          }
        }
      }
    }
    
    // 블록을 분으로 변환 (1블록 = 10분)
    Map<String, int> categoryMinutes = {};
    categoryBlocks.forEach((key, value) {
      categoryMinutes[key] = value * 10;
    });
    
    return {
      'categoryMinutes': categoryMinutes,
      'totalActiveBlocks': totalActiveBlocks,
      'totalPlannedBlocks': totalPlannedBlocks,
      'completionRate': totalPlannedBlocks > 0 ? (totalActiveBlocks / totalPlannedBlocks * 100) : 0,
    };
  }

  // 통합된 일간 카테고리 데이터 생성 (시간별 활동 블록과 정확히 매치)
  Map<String, int> _getDailyUnifiedCategoryData() {
    // 항상 시간별 활동 분석 결과를 사용하여 일관성 확보
    Map<String, dynamic> analysis = _getTimeTableAnalysis();
    Map<String, int> categoryMinutes = analysis['categoryMinutes'];
    
    // 빈 데이터인 경우 기본 데이터 반환
    if (categoryMinutes.isEmpty) {
      return _getDefaultCategoryData();
    }
    
    return categoryMinutes;
  }

  // 실제 완료된 활동인지 확인 (시뮬레이션)
  bool _isActivityCompleted(int hour, int tenMinute) {
    int dayOfMonth = _selectedDay.day;
    return ((hour + tenMinute + dayOfMonth) % 3) != 0; // 약 67% 완료율
  }

  // 기본 카테고리 데이터 (백업용)
  Map<String, int> _getDefaultCategoryData() {
    int dayOfWeek = _selectedDay.weekday;
    int dayOfMonth = _selectedDay.day;
    
    if (dayOfWeek == 1 || dayOfWeek == 3 || dayOfWeek == 5) { // 월, 수, 금
      return {
        '프로젝트': 180 + (dayOfMonth % 3) * 30,
        '공부': 240 + (dayOfMonth % 4) * 20,
        '운동': 90 + (dayOfMonth % 2) * 30,
        '독서': 60 + (dayOfMonth % 5) * 10,
      };
    } else if (dayOfWeek == 2 || dayOfWeek == 4) { // 화, 목
      return {
        '프로젝트': 120 + (dayOfMonth % 4) * 40,
        '공부': 300 + (dayOfMonth % 3) * 30,
        '운동': 150 + (dayOfMonth % 2) * 20,
        '독서': 45 + (dayOfMonth % 6) * 15,
      };
    } else { // 주말
      if (dayOfMonth % 2 == 0) {
        return {
          '프로젝트': 90 + (dayOfMonth % 5) * 25,
          '공부': 120 + (dayOfMonth % 3) * 40,
          '운동': 180 + (dayOfMonth % 4) * 30,
          '취미': 100 + (dayOfMonth % 2) * 50,
        };
      } else {
        return {
          '프로젝트': 200 + (dayOfMonth % 3) * 35,
          '공부': 90 + (dayOfMonth % 4) * 25,
          '운동': 60 + (dayOfMonth % 5) * 20,
          '취미': 80 + (dayOfMonth % 2) * 40,
        };
      }
    }
  }

  // 통합된 데이터를 기반으로 시간대별 활동 시간표 생성 (10분 단위로 세밀하게)
  Map<int, String> _generateDailyTimeTable() {
    Map<int, String> timeTable = {};
    
    // 선택된 날짜 기반으로 고정된 활동 패턴 생성
    int dayOfWeek = _selectedDay.weekday;
    int dayOfMonth = _selectedDay.day;
    
    if (dayOfWeek == 1 || dayOfWeek == 3 || dayOfWeek == 5) { // 월, 수, 금
      // 8-12시: 공부 (4시간)
      for (int hour = 8; hour <= 11; hour++) {
        timeTable[hour] = '공부';
      }
      // 12-16시: 프로젝트 (4시간)  
      for (int hour = 12; hour <= 15; hour++) {
        timeTable[hour] = '프로젝트';
      }
      // 16-18시: 운동 (2시간)
      for (int hour = 16; hour <= 17; hour++) {
        timeTable[hour] = '운동';
      }
      // 18-20시: 독서 (2시간)
      for (int hour = 18; hour <= 19; hour++) {
        timeTable[hour] = '독서';
      }
    } else if (dayOfWeek == 2 || dayOfWeek == 4) { // 화, 목
      // 9-14시: 공부 (5시간)
      for (int hour = 9; hour <= 13; hour++) {
        timeTable[hour] = '공부';
      }
      // 14-17시: 프로젝트 (3시간)
      for (int hour = 14; hour <= 16; hour++) {
        timeTable[hour] = '프로젝트';
      }
      // 17-20시: 운동 (3시간)
      for (int hour = 17; hour <= 19; hour++) {
        timeTable[hour] = '운동';
      }
      // 20-21시: 독서 (1시간)
      timeTable[20] = '독서';
    } else { // 주말
      if (dayOfMonth % 2 == 0) {
        // 10-13시: 운동 (3시간)
        for (int hour = 10; hour <= 12; hour++) {
          timeTable[hour] = '운동';
        }
        // 14-16시: 공부 (2시간)
        for (int hour = 14; hour <= 15; hour++) {
          timeTable[hour] = '공부';
        }
        // 16-19시: 프로젝트 (3시간)
        for (int hour = 16; hour <= 18; hour++) {
          timeTable[hour] = '프로젝트';
        }
        // 19-21시: 취미 (2시간)
        for (int hour = 19; hour <= 20; hour++) {
          timeTable[hour] = '취미';
        }
      } else {
        // 8-12시: 프로젝트 (4시간)
        for (int hour = 8; hour <= 11; hour++) {
          timeTable[hour] = '프로젝트';
        }
        // 14-16시: 공부 (2시간)
        for (int hour = 14; hour <= 15; hour++) {
          timeTable[hour] = '공부';
        }
        // 16-17시: 운동 (1시간)
        timeTable[16] = '운동';
        // 19-21시: 취미 (2시간)
        for (int hour = 19; hour <= 20; hour++) {
          timeTable[hour] = '취미';
        }
      }
    }
    
    return timeTable;
  }

  // 10분 단위로 세밀한 활동 시간표 생성
  Map<String, int> _generateDetailedTimeTable() {
    int dayOfWeek = _selectedDay.weekday;
    int dayOfMonth = _selectedDay.day;
    Map<String, int> detailedTime = {};
    
    if (dayOfWeek == 1 || dayOfWeek == 3 || dayOfWeek == 5) { // 월, 수, 금
      // 8시: 공부 40분 (4칸)
      detailedTime['공부'] = (detailedTime['공부'] ?? 0) + 40;
      // 9시: 공부 50분 (5칸) 
      detailedTime['공부'] = (detailedTime['공부'] ?? 0) + 50;
      // 10시: 공부 30분 (3칸)
      detailedTime['공부'] = (detailedTime['공부'] ?? 0) + 30;
      // 11시: 공부 60분 (6칸)
      detailedTime['공부'] = (detailedTime['공부'] ?? 0) + 60;
      
      // 12시: 프로젝트 60분 (6칸)
      detailedTime['프로젝트'] = (detailedTime['프로젝트'] ?? 0) + 60;
      // 13시: 프로젝트 50분 (5칸)
      detailedTime['프로젝트'] = (detailedTime['프로젝트'] ?? 0) + 50;
      // 14시: 프로젝트 40분 (4칸)
      detailedTime['프로젝트'] = (detailedTime['프로젝트'] ?? 0) + 40;
      // 15시: 프로젝트 20분 (2칸)
      detailedTime['프로젝트'] = (detailedTime['프로젝트'] ?? 0) + 20;
      
      // 16시: 운동 30분 (3칸)
      detailedTime['운동'] = (detailedTime['운동'] ?? 0) + 30;
      // 17시: 운동 50분 (5칸)
      detailedTime['운동'] = (detailedTime['운동'] ?? 0) + 50;
      
      // 18시: 독서 40분 (4칸)
      detailedTime['독서'] = (detailedTime['독서'] ?? 0) + 40;
      // 19시: 독서 30분 (3칸)
      detailedTime['독서'] = (detailedTime['독서'] ?? 0) + 30;
      
    } else if (dayOfWeek == 2 || dayOfWeek == 4) { // 화, 목
      // 9시: 공부 60분 (6칸)
      detailedTime['공부'] = (detailedTime['공부'] ?? 0) + 60;
      // 10시: 공부 50분 (5칸)
      detailedTime['공부'] = (detailedTime['공부'] ?? 0) + 50;
      // 11시: 공부 40분 (4칸)
      detailedTime['공부'] = (detailedTime['공부'] ?? 0) + 40;
      // 12시: 공부 30분 (3칸)
      detailedTime['공부'] = (detailedTime['공부'] ?? 0) + 30;
      // 13시: 공부 20분 (2칸)
      detailedTime['공부'] = (detailedTime['공부'] ?? 0) + 20;
      
      // 14시: 프로젝트 50분 (5칸)
      detailedTime['프로젝트'] = (detailedTime['프로젝트'] ?? 0) + 50;
      // 15시: 프로젝트 40분 (4칸)
      detailedTime['프로젝트'] = (detailedTime['프로젝트'] ?? 0) + 40;
      // 16시: 프로젝트 30분 (3칸)
      detailedTime['프로젝트'] = (detailedTime['프로젝트'] ?? 0) + 30;
      
      // 17시: 운동 60분 (6칸)
      detailedTime['운동'] = (detailedTime['운동'] ?? 0) + 60;
      // 18시: 운동 50분 (5칸)
      detailedTime['운동'] = (detailedTime['운동'] ?? 0) + 50;
      // 19시: 운동 40분 (4칸)
      detailedTime['운동'] = (detailedTime['운동'] ?? 0) + 40;
      
      // 20시: 독서 30분 (3칸)
      detailedTime['독서'] = (detailedTime['독서'] ?? 0) + 30;
      
    } else { // 주말
      if (dayOfMonth % 2 == 0) {
        // 10시: 운동 60분 (6칸)
        detailedTime['운동'] = (detailedTime['운동'] ?? 0) + 60;
        // 11시: 운동 50분 (5칸)
        detailedTime['운동'] = (detailedTime['운동'] ?? 0) + 50;
        // 12시: 운동 40분 (4칸)
        detailedTime['운동'] = (detailedTime['운동'] ?? 0) + 40;
        
        // 14시: 공부 30분 (3칸)
        detailedTime['공부'] = (detailedTime['공부'] ?? 0) + 30;
        // 15시: 공부 50분 (5칸)
        detailedTime['공부'] = (detailedTime['공부'] ?? 0) + 50;
        
        // 16시: 프로젝트 60분 (6칸)
        detailedTime['프로젝트'] = (detailedTime['프로젝트'] ?? 0) + 60;
        // 17시: 프로젝트 40분 (4칸)
        detailedTime['프로젝트'] = (detailedTime['프로젝트'] ?? 0) + 40;
        // 18시: 프로젝트 20분 (2칸)
        detailedTime['프로젝트'] = (detailedTime['프로젝트'] ?? 0) + 20;
        
        // 19시: 취미 50분 (5칸)
        detailedTime['취미'] = (detailedTime['취미'] ?? 0) + 50;
        // 20시: 취미 30분 (3칸)
        detailedTime['취미'] = (detailedTime['취미'] ?? 0) + 30;
        
      } else {
        // 8시: 프로젝트 60분 (6칸)
        detailedTime['프로젝트'] = (detailedTime['프로젝트'] ?? 0) + 60;
        // 9시: 프로젝트 50분 (5칸)
        detailedTime['프로젝트'] = (detailedTime['프로젝트'] ?? 0) + 50;
        // 10시: 프로젝트 40분 (4칸)
        detailedTime['프로젝트'] = (detailedTime['프로젝트'] ?? 0) + 40;
        // 11시: 프로젝트 30분 (3칸)
        detailedTime['프로젝트'] = (detailedTime['프로젝트'] ?? 0) + 30;
        
        // 14시: 공부 50분 (5칸)
        detailedTime['공부'] = (detailedTime['공부'] ?? 0) + 50;
        // 15시: 공부 40분 (4칸)
        detailedTime['공부'] = (detailedTime['공부'] ?? 0) + 40;
        
        // 16시: 운동 30분 (3칸)
        detailedTime['운동'] = (detailedTime['운동'] ?? 0) + 30;
        
        // 19시: 취미 60분 (6칸)
        detailedTime['취미'] = (detailedTime['취미'] ?? 0) + 60;
        // 20시: 취미 20분 (2칸)
        detailedTime['취미'] = (detailedTime['취미'] ?? 0) + 20;
      }
    }
    
    return detailedTime;
  }

  // 시간대별 10분 블록 활동 여부 확인 (세밀한 패턴)
  bool _getDetailedActivityForTimeSlot(int hour, int tenMinuteIndex) {
    int dayOfWeek = _selectedDay.weekday;
    int dayOfMonth = _selectedDay.day;
    
    if (dayOfWeek == 1 || dayOfWeek == 3 || dayOfWeek == 5) { // 월, 수, 금
      switch (hour) {
        case 8: return tenMinuteIndex < 4; // 40분 (4칸)
        case 9: return tenMinuteIndex < 5; // 50분 (5칸)
        case 10: return tenMinuteIndex < 3; // 30분 (3칸)
        case 11: return tenMinuteIndex < 6; // 60분 (6칸)
        case 12: return tenMinuteIndex < 6; // 60분 (6칸)
        case 13: return tenMinuteIndex < 5; // 50분 (5칸)
        case 14: return tenMinuteIndex < 4; // 40분 (4칸)
        case 15: return tenMinuteIndex < 2; // 20분 (2칸)
        case 16: return tenMinuteIndex < 3; // 30분 (3칸)
        case 17: return tenMinuteIndex < 5; // 50분 (5칸)
        case 18: return tenMinuteIndex < 4; // 40분 (4칸)
        case 19: return tenMinuteIndex < 3; // 30분 (3칸)
        default: return false;
      }
    } else if (dayOfWeek == 2 || dayOfWeek == 4) { // 화, 목
      switch (hour) {
        case 9: return tenMinuteIndex < 6; // 60분 (6칸)
        case 10: return tenMinuteIndex < 5; // 50분 (5칸)
        case 11: return tenMinuteIndex < 4; // 40분 (4칸)
        case 12: return tenMinuteIndex < 3; // 30분 (3칸)
        case 13: return tenMinuteIndex < 2; // 20분 (2칸)
        case 14: return tenMinuteIndex < 5; // 50분 (5칸)
        case 15: return tenMinuteIndex < 4; // 40분 (4칸)
        case 16: return tenMinuteIndex < 3; // 30분 (3칸)
        case 17: return tenMinuteIndex < 6; // 60분 (6칸)
        case 18: return tenMinuteIndex < 5; // 50분 (5칸)
        case 19: return tenMinuteIndex < 4; // 40분 (4칸)
        case 20: return tenMinuteIndex < 3; // 30분 (3칸)
        default: return false;
      }
    } else { // 주말
      if (dayOfMonth % 2 == 0) {
        switch (hour) {
          case 10: return tenMinuteIndex < 6; // 60분 (6칸)
          case 11: return tenMinuteIndex < 5; // 50분 (5칸)
          case 12: return tenMinuteIndex < 4; // 40분 (4칸)
          case 14: return tenMinuteIndex < 3; // 30분 (3칸)
          case 15: return tenMinuteIndex < 5; // 50분 (5칸)
          case 16: return tenMinuteIndex < 6; // 60분 (6칸)
          case 17: return tenMinuteIndex < 4; // 40분 (4칸)
          case 18: return tenMinuteIndex < 2; // 20분 (2칸)
          case 19: return tenMinuteIndex < 5; // 50분 (5칸)
          case 20: return tenMinuteIndex < 3; // 30분 (3칸)
          default: return false;
        }
      } else {
        switch (hour) {
          case 8: return tenMinuteIndex < 6; // 60분 (6칸)
          case 9: return tenMinuteIndex < 5; // 50분 (5칸)
          case 10: return tenMinuteIndex < 4; // 40분 (4칸)
          case 11: return tenMinuteIndex < 3; // 30분 (3칸)
          case 14: return tenMinuteIndex < 5; // 50분 (5칸)
          case 15: return tenMinuteIndex < 4; // 40분 (4칸)
          case 16: return tenMinuteIndex < 3; // 30분 (3칸)
          case 19: return tenMinuteIndex < 6; // 60분 (6칸)
          case 20: return tenMinuteIndex < 2; // 20분 (2칸)
          default: return false;
        }
      }
    }
  }

  // 실제 완료된 활동 시간표 생성 (계획 대비 60-80% 완료)
  Map<int, String> _generateCompletedTimeTable() {
    Map<int, String> plannedTable = _generateDailyTimeTable();
    Map<int, String> completedTable = {};
    
    // 선택된 날짜에 따라 완료율 결정 (일관성 있게)
    int dayOfMonth = _selectedDay.day;
    double completionRate = 0.6 + (dayOfMonth % 5) * 0.05; // 60-80% 완료율
    
    plannedTable.forEach((hour, activity) {
      // 시간대별로 완료 여부 결정 (dayOfMonth를 시드로 사용)
      int seed = (hour + dayOfMonth) % 10;
      if (seed < (completionRate * 10)) {
        completedTable[hour] = activity;
      }
    });
    
    return completedTable;
  }

  // 빗금 패턴 생성 (계획만 하고 완료 안 한 경우용)
  ImageProvider _createDiagonalPattern(Color color) {
    // 간단한 방법으로 빗금 효과를 위해 투명도 조절로 대체
    return NetworkImage(''); // 임시로 빈 이미지 사용
  }

  // 시간대별 활동 완료 여부 확인 (실제 완료된 것만)
  bool _getActivityForTimeSlot(int hour, int minute) {
    Map<int, String> completedTable = _generateCompletedTimeTable();
    return completedTable.containsKey(hour);
  }

  // 시간대별 계획된 활동 여부 확인
  bool _getPlannedActivityForTimeSlot(int hour, int minute) {
    Map<int, String> plannedTable = _generateDailyTimeTable();
    return plannedTable.containsKey(hour);
  }

  // 시간대별 활동 타입 (계획된 활동 기준)
  String _getActivityTypeForTimeSlot(int hour, int minute) {
    Map<int, String> plannedTable = _generateDailyTimeTable();
    return plannedTable[hour] ?? '휴식';
  }

  // 일간 요약 카드
  Widget _buildDailySummaryCard() {
    // 시간별 활동 분석 결과 사용
    Map<String, dynamic> analysis = _getTimeTableAnalysis();
    Map<String, int> categoryTime = analysis['categoryMinutes'];
    int totalActiveBlocks = analysis['totalActiveBlocks'];
    int totalPlannedBlocks = analysis['totalPlannedBlocks'];
    double completionRate = analysis['completionRate'];
    
    int totalStudyTime = categoryTime.values.fold(0, (sum, time) => sum + time);
    
    // 집중도 계산 (완료율 기준)
    String focusLevel;
    if (completionRate < 33) {
      focusLevel = "낮음";
    } else if (completionRate < 66) {
      focusLevel = "보통";
    } else {
      focusLevel = "높음";
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade400, Colors.purple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '일간 요약',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '총 활동시간',
                  _formatTime(totalStudyTime),
                  Icons.timer,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildStatItem(
                  '완료 블록',
                  '$totalActiveBlocks/$totalPlannedBlocks',
                  Icons.task_alt,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '완료율',
                  '${completionRate.toInt()}%',
                  Icons.check_circle,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildStatItem(
                  '집중도',
                  focusLevel,
                  Icons.psychology,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 타임테이블 (통합 데이터 사용)
  Widget _buildTimeTable() {
    // 통합된 일간 카테고리 데이터 사용
    Map<String, int> categoryTime = _getDailyUnifiedCategoryData();
    
    return GestureDetector(
      onPanUpdate: (details) {
        // 스와이프 감지
        if (details.delta.dx > 10) {
          // 오른쪽 스와이프 - 이전날
          _changePeriod('일간', -1);
        } else if (details.delta.dx < -10) {
          // 왼쪽 스와이프 - 다음날
          _changePeriod('일간', 1);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '시간별 활동',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // 범례 - 통합된 카테고리에 따라 동적 생성
                Wrap(
                  spacing: 8,
                  children: _processCategories(categoryTime).keys.map((category) {
                    return _buildLegendItem(category, _getCategoryColor(category));
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 시간 라벨 (0시~23시)
            SizedBox(
              height: 30,
              child: Row(
                children: List.generate(24, (hour) {
                  return Expanded(
                    child: Center(
                      child: Text(
                        hour.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 10),
            // 통합 타임라인
            Container(
              height: 80,
              child: Row(
                children: List.generate(24, (hour) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      child: Column(
                        children: List.generate(6, (tenMinute) {
                          String activity = _getActivityTypeForTimeSlot(hour, tenMinute * 10);
                          Color color = _getActivityColor(activity);
                          bool hasPlannedActivity = _getPlannedActivityForTimeSlot(hour, tenMinute * 10);
                          bool hasCompletedActivity = _getActivityForTimeSlot(hour, tenMinute * 10);
                          
                          // 새로운 세밀한 패턴 사용
                          bool hasDetailedActivity = _getDetailedActivityForTimeSlot(hour, tenMinute);
                          bool isCompleted = _isActivityCompleted(hour, tenMinute);
                          
                          return Expanded(
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.all(0.5),
                              decoration: BoxDecoration(
                                color: hasDetailedActivity 
                                    ? (isCompleted
                                        ? color  // 완료된 활동은 진한 실색
                                        : color.withOpacity(0.2)) // 계획만 있는 활동은 매우 연한색
                                    : Colors.grey.shade100, // 활동 없으면 회색
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: hasDetailedActivity 
                                      ? color.withOpacity(0.4) 
                                      : Colors.grey.shade200,
                                  width: 0.5,
                                ),
                              ),
                              child: hasDetailedActivity && !isCompleted
                                  ? CustomPaint(
                                      painter: DiagonalStripePainter(color),
                                    )
                                  : null,
                            ),
                          );
                        }),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 10),
            // 시간 표시 (3시간 간격)
            Row(
              children: List.generate(8, (index) {
                int hour = index * 3;
                return Expanded(
                  flex: 3,
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}:00',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // 범례 아이템
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 시간대별 활동 여부 확인 (통합 데이터 사용)
  bool _getActivityForTimeSlotOld(int hour, int minute) {
    Map<int, String> timeTable = _generateDailyTimeTable();
    return timeTable.containsKey(hour);
  }

  // 시간대별 활동 타입 (통합 데이터 사용)
  String _getActivityTypeForTimeSlotOld(int hour, int minute) {
    Map<int, String> timeTable = _generateDailyTimeTable();
    return timeTable[hour] ?? '휴식';
  }

  // 활동별 색상
  Color _getActivityColor(String activity) {
    switch (activity) {
      case '프로젝트':
        return Colors.blue.shade400;
      case '공부':
        return Colors.purple.shade400;
      case '운동':
        return Colors.green.shade400;
      case '독서':
        return Colors.pink.shade400;
      case '취미':
        return Colors.teal.shade400;
      case '기타':
        return Colors.grey.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  // 시간을 "X시간 Y분" 형식으로 변환하는 함수
  String _formatTime(int minutes) {
    int hours = minutes ~/ 60;
    int remainingMinutes = minutes % 60;
    
    if (hours == 0) {
      return '${remainingMinutes}분';
    } else if (remainingMinutes == 0) {
      return '${hours}시간';
    } else {
      return '${hours}시간 ${remainingMinutes}분';
    }
  }

  // 일간 카테고리 차트 (통합된 데이터 사용)
  Widget _buildDailyCategoryChart() {
    // 통합된 일간 카테고리 데이터 사용
    Map<String, int> categoryTime = _getDailyUnifiedCategoryData();
    
    // 카테고리 정리 (10% 미만은 기타로)
    categoryTime = _processCategories(categoryTime);
    
    if (categoryTime.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text('카테고리 데이터가 없습니다.'),
        ),
      );
    }
    
    int totalTime = categoryTime.values.reduce((a, b) => a + b);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '일간 카테고리별 시간',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // 도넛 차트
              SizedBox(
                width: 120,
                height: 120,
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: DonutChartPainter(
                        categoryTime,
                        totalTime,
                        _progressAnimation.value,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 20),
              // 범례와 시간 정보
              Expanded(
                child: Column(
                  children: categoryTime.entries.map((entry) {
                    Color color = _getCategoryColor(entry.key);
                    double percentage = (entry.value / totalTime) * 100;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatTime(entry.value), // 시간 형식 변경
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${percentage.toInt()}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              '📊 활동 통계',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_isOfflineMode) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.wifi_off,
                size: 20,
                color: Colors.orange.shade300,
              ),
            ],
          ],
        ),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isOfflineMode)
            IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_errorMessage ?? '오프라인 모드입니다'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              icon: const Icon(Icons.info_outline),
              tooltip: '오프라인 모드 정보',
            ),
          IconButton(
            onPressed: _loadStatistics,
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(text: '일간'),
            Tab(text: '주간'),
            Tab(text: '월간'),
            Tab(text: '연간'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
              ),
            )
          : TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildDailyView(),
                _buildWeeklyView(),
                _buildMonthlyView(),
                _buildYearlyView(),
              ],
            ),
    );
  }

  // 일간 뷰
  Widget _buildDailyView() {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          _buildDateSelector('일간'),
          const SizedBox(height: 16),
          _buildAchievementBadges(_dailyAchievements, '일간'),
          _buildDailySummaryCard(),
            const SizedBox(height: 20),
          _buildTimeTable(),
            const SizedBox(height: 20),
          _buildDailyCategoryChart(),
        ],
      ),
    );
  }

  // 주간 뷰
  Widget _buildWeeklyView() {
    if (_weeklyData.isEmpty) {
      return const Center(child: Text('주간 데이터가 없습니다.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateSelector('주간'),
          const SizedBox(height: 16),
          _buildAchievementBadges(_weeklyAchievements, '주간'),
          _buildWeeklySummaryCard(),
          const SizedBox(height: 20),
            _buildWeeklyChart(),
            const SizedBox(height: 20),
          _buildCategoryChart(_weeklyData),
        ],
      ),
    );
  }

  // 월간 뷰
  Widget _buildMonthlyView() {
    if (_monthlyData.isEmpty) {
      return const Center(child: Text('월간 데이터가 없습니다.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateSelector('월간'),
          const SizedBox(height: 16),
          _buildAchievementBadges(_monthlyAchievements, '월간'),
          _buildMonthlySummaryCard(),
            const SizedBox(height: 20),
          _buildMonthlyChart(),
          const SizedBox(height: 20),
          _buildCategoryChart(_monthlyData),
        ],
      ),
    );
  }

  // 연간 뷰
  Widget _buildYearlyView() {
    if (_yearlyData.isEmpty) {
      return const Center(child: Text('연간 데이터가 없습니다.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateSelector('연간'),
          const SizedBox(height: 16),
          _buildAchievementBadges(_yearlyAchievements, '연간'),
          _buildYearlySummaryCard(),
          const SizedBox(height: 20),
          _buildYearlyChart(),
          const SizedBox(height: 20),
          Container(
            key: ValueKey('yearly_category_${_selectedYear.year}'),
            child: _buildCategoryChart(_getYearlyCategoryStats()),
          ),
        ],
      ),
    );
  }

  // 날짜 선택기
  Widget _buildDateSelector(String period) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => _changePeriod(period, -1),
            icon: const Icon(Icons.chevron_left),
            color: Colors.purple.shade600,
          ),
          Text(
            _getDateRangeText(period),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.purple.shade600,
            ),
          ),
          IconButton(
            onPressed: () => _changePeriod(period, 1),
            icon: const Icon(Icons.chevron_right),
            color: Colors.purple.shade600,
          ),
        ],
      ),
    );
  }

  // 주간 요약 카드
  Widget _buildWeeklySummaryCard() {
    int totalStudyTime = _weeklyData.fold(0, (sum, stat) => sum + stat.studyTimeMinutes);
    int totalCompleted = _weeklyData.fold(0, (sum, stat) => sum + stat.completedTasks);
    int totalTasks = _weeklyData.fold(0, (sum, stat) => sum + stat.totalTasks);
    double weeklyAvg = _weeklyData.isNotEmpty ? totalStudyTime / 7 : 0; // 주간 평균 (7일 기준)

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade400, Colors.purple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
            '주간 요약',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '총 활동시간',
                  '$totalStudyTime분',
                  Icons.timer,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildStatItem(
                  '완료율',
                  '${totalTasks > 0 ? (totalCompleted / totalTasks * 100).toInt() : 0}%',
                  Icons.check_circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '주간 평균',
                  '${(weeklyAvg / 60).toStringAsFixed(1)}시간/일',
                  Icons.trending_up,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildStatItem(
                  '완료 할일',
                  '$totalCompleted/$totalTasks',
                  Icons.task_alt,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 월간 요약 카드
  Widget _buildMonthlySummaryCard() {
    int totalStudyTime = _monthlyData.fold(0, (sum, stat) => sum + stat.studyTimeMinutes);
    int totalCompleted = _monthlyData.fold(0, (sum, stat) => sum + stat.completedTasks);
    int totalTasks = _monthlyData.fold(0, (sum, stat) => sum + stat.totalTasks);
    double monthlyAvg = _monthlyData.isNotEmpty ? totalStudyTime / 4 : 0; // 월간 평균을 주 단위로 (4주 기준)

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade400, Colors.purple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '월간 요약',
            style: TextStyle(
                    color: Colors.white,
              fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '총 활동시간',
                  '${(totalStudyTime / 60).toInt()}시간',
                  Icons.timer,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildStatItem(
                  '완료율',
                  '${totalTasks > 0 ? (totalCompleted / totalTasks * 100).toInt() : 0}%',
                  Icons.check_circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '월간 평균',
                  '${(monthlyAvg / 60).toStringAsFixed(1)}시간/주',
                  Icons.trending_up,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildStatItem(
                  '완료 할일',
                  '$totalCompleted/$totalTasks',
                  Icons.task_alt,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // 연간 요약 카드
  Widget _buildYearlySummaryCard() {
    int totalStudyTime = _yearlyData.fold(0, (sum, stat) => sum + stat.totalStudyTimeMinutes);
    int totalCompleted = _yearlyData.fold(0, (sum, stat) => sum + stat.totalCompletedTasks);
    int totalTasks = _yearlyData.fold(0, (sum, stat) => sum + stat.totalTasks);
    double yearlyAvg = _yearlyData.isNotEmpty ? totalStudyTime / 12 : 0; // 연간 평균 (12개월 기준)

    return Container(
      key: ValueKey('yearly_summary_${_selectedYear.year}'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade400, Colors.purple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '연간 요약',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_selectedYear.year}년',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '총 활동시간',
                  '${(totalStudyTime / 60).toInt()}시간',
                  Icons.timer,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildStatItem(
                  '완료율',
                  '${totalTasks > 0 ? (totalCompleted / totalTasks * 100).toInt() : 0}%',
                  Icons.check_circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '연간 평균',
                  '${(yearlyAvg / 60).toInt()}시간/월',
                  Icons.trending_up,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildStatItem(
                  '완료 할일',
                  '$totalCompleted/$totalTasks',
                  Icons.task_alt,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 카테고리별 스택 빌더
  List<Widget> _buildCategoryStack(Map<String, int> categoryTime, double totalHeight) {
    if (categoryTime.isEmpty || totalHeight <= 0) return [Container()];
    
    int totalTime = categoryTime.values.fold(0, (a, b) => a + b);
    List<Widget> stackItems = [];
    
    categoryTime.entries.forEach((entry) {
      double proportion = entry.value / totalTime;
      double height = totalHeight * proportion;
      
      if (height > 0.5) { // 최소 높이 0.5픽셀 이상만 표시
        stackItems.add(
          Container(
            height: height,
            decoration: BoxDecoration(
              color: _getCategoryColor(entry.key),
              borderRadius: stackItems.isEmpty 
                  ? BorderRadius.vertical(top: Radius.circular(4))
                  : stackItems.length == categoryTime.length - 1
                      ? BorderRadius.vertical(bottom: Radius.circular(4))
                      : BorderRadius.zero,
            ),
          ),
        );
      }
    });
    
    // 빈 스택인 경우 기본 컨테이너 반환
    if (stackItems.isEmpty) {
      return [
        Container(
          height: totalHeight,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
        )
      ];
    }
    
    return stackItems;
  }

  // 새로운 카테고리 스택 위젯 (Stack 기반)
  Widget _buildCategoryBar(Map<String, int> categoryTime, double totalHeight) {
    if (categoryTime.isEmpty || totalHeight <= 0) {
      return Container(
        height: totalHeight,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }
    
    int totalTime = categoryTime.values.fold(0, (a, b) => a + b);
    List<Widget> segments = [];
    double currentBottom = 0;
    
    // 카테고리를 정렬하여 일관성 있게 표시
    List<MapEntry<String, int>> sortedCategories = categoryTime.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    for (var entry in sortedCategories) {
      double segmentHeight = (entry.value / totalTime) * totalHeight;
      
      if (segmentHeight > 0.5) {
        segments.add(
          Positioned(
            bottom: currentBottom,
            left: 0,
            right: 0,
            height: segmentHeight,
            child: Container(
              decoration: BoxDecoration(
                color: _getCategoryColor(entry.key),
                borderRadius: currentBottom == 0 
                    ? BorderRadius.vertical(bottom: Radius.circular(4))
                    : currentBottom + segmentHeight >= totalHeight - 0.5
                        ? BorderRadius.vertical(top: Radius.circular(4))
                        : BorderRadius.zero,
              ),
            ),
          ),
        );
        currentBottom += segmentHeight;
      }
    }
    
    return SizedBox(
      height: totalHeight,
      child: Stack(children: segments),
    );
  }

  Widget _buildWeeklyChart() {
    final weekDays = ['월', '화', '수', '목', '금', '토', '일'];
    
    // 전체 주간 데이터에서 최대 카테고리 시간 합계 찾기
    int maxTotalTime = 0;
    for (int index = 0; index < 7 && index < _weeklyData.length; index++) {
      DailyStats dayData = _weeklyData[index];
      Map<String, int> categoryTime = _processCategories(dayData.categoryTime);
      int totalTime = categoryTime.values.fold(0, (a, b) => a + b);
      if (totalTime > maxTotalTime) {
        maxTotalTime = totalTime;
      }
    }
    
    return GestureDetector(
      onPanUpdate: (details) {
        if (details.delta.dx > 10) {
          _changePeriod('주간', -1);
        } else if (details.delta.dx < -10) {
          _changePeriod('주간', 1);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '주간 활동',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  if (index >= _weeklyData.length) return const SizedBox();
                  
                  DailyStats dayData = _weeklyData[index];
                  Map<String, int> categoryTime = _processCategories(dayData.categoryTime);
                  int totalTime = categoryTime.values.fold(0, (a, b) => a + b);
                  
                  double maxHeight = 160;
                  // 최대값 기준으로 높이 계산
                  double barHeight = maxTotalTime > 0 ? (totalTime / maxTotalTime) * maxHeight : 0;
                  
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 24,
                            child: _buildCategoryBar(categoryTime, barHeight * _progressAnimation.value),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        weekDays[index],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: index == 6 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      Text(
                        '$totalTime분',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyChart() {
    int daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    
    Map<int, DailyStats?> dailyDataMap = {};
    for (var data in _monthlyData) {
      dailyDataMap[data.date.day] = data;
    }
    
    // 전체 월간 데이터에서 최대 카테고리 시간 합계 찾기
    int maxTotalTime = 0;
    for (int index = 0; index < daysInMonth; index++) {
      int dayNumber = index + 1;
      DailyStats? dayData = dailyDataMap[dayNumber];
      if (dayData != null) {
        Map<String, int> categoryTime = _processCategories(dayData.categoryTime);
        int totalTime = categoryTime.values.fold(0, (a, b) => a + b);
        if (totalTime > maxTotalTime) {
          maxTotalTime = totalTime;
        }
      }
    }
    
    return GestureDetector(
      onPanUpdate: (details) {
        if (details.delta.dx > 10) {
          _changePeriod('월간', -1);
        } else if (details.delta.dx < -10) {
          _changePeriod('월간', 1);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '월간 활동',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(daysInMonth, (index) {
                  int dayNumber = index + 1;
                  DailyStats? dayData = dailyDataMap[dayNumber];
                  
                  Map<String, int> categoryTime = dayData != null ? _processCategories(dayData.categoryTime) : {};
                  int totalTime = categoryTime.values.fold(0, (a, b) => a + b);
                  
                  double maxHeight = 160;
                  // 최대값 기준으로 높이 계산
                  double barHeight = maxTotalTime > 0 ? (totalTime / maxTotalTime) * maxHeight : 0;
                  
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 8,
                              child: _buildCategoryBar(categoryTime, barHeight * _progressAnimation.value),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 9,
                            color: dayData != null 
                                ? Colors.grey.shade600 
                                : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearlyChart() {
    final months = ['1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월', '9월', '10월', '11월', '12월'];
    
    Map<int, MonthlyStats?> monthlyDataMap = {};
    for (var data in _yearlyData) {
      monthlyDataMap[data.month.month] = data;
    }
    
    // 전체 연간 데이터에서 최대 카테고리 시간 합계 찾기
    int maxTotalTime = 0;
    for (int index = 0; index < 12; index++) {
      int monthNumber = index + 1;
      MonthlyStats? monthData = monthlyDataMap[monthNumber];
      if (monthData != null) {
        Map<String, int> categoryTime = _processCategories(monthData.categoryTime);
        int totalTime = categoryTime.values.fold(0, (a, b) => a + b);
        if (totalTime > maxTotalTime) {
          maxTotalTime = totalTime;
        }
      }
    }
    
    return GestureDetector(
      key: ValueKey('yearly_chart_${_selectedYear.year}'),
      onPanUpdate: (details) {
        if (details.delta.dx > 10) {
          _changePeriod('연간', -1);
        } else if (details.delta.dx < -10) {
          _changePeriod('연간', 1);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '연간 활동',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(12, (index) {
                  int monthNumber = index + 1;
                  MonthlyStats? monthData = monthlyDataMap[monthNumber];
                  
                  Map<String, int> categoryTime = monthData != null ? _processCategories(monthData.categoryTime) : {};
                  int totalTime = categoryTime.values.fold(0, (a, b) => a + b);
                  
                  double maxHeight = 160;
                  // 최대값 기준으로 높이 계산
                  double barHeight = maxTotalTime > 0 ? (totalTime / maxTotalTime) * maxHeight : 0;
                  
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedBuilder(
                            animation: _progressAnimation,
                            builder: (context, child) {
                              return Container(
                                width: 16,
                                child: _buildCategoryBar(categoryTime, barHeight),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            months[index],
                            style: TextStyle(
                              fontSize: 9,
                              color: monthData != null 
                                  ? Colors.grey.shade600 
                                  : Colors.grey.shade400,
                              fontWeight: monthData != null 
                                  ? FontWeight.normal 
                                  : FontWeight.w300,
                            ),
                          ),
                          if (totalTime > 0)
                            Text(
                              '${(totalTime / 60).toInt()}h',
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.grey.shade500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DailyStats> _getYearlyCategoryStats() {
    int selectedYear = _selectedYear.year;
    print('🎨 카테고리 데이터 생성 중 - 연도: $selectedYear');
    
    // 현재 선택된 연도의 카테고리 시간을 합계
    Map<String, int> totalCategoryTime = {};
    for (var monthly in _yearlyData) {
      monthly.categoryTime.forEach((category, time) {
        totalCategoryTime[category] = (totalCategoryTime[category] ?? 0) + time;
      });
    }
    
    // 연도별로 다른 카테고리 비율 적용
    Map<String, int> adjustedCategoryTime = {};
    int totalTime = totalCategoryTime.values.fold(0, (sum, time) => sum + time);
    
    if (selectedYear % 4 == 0) { // 4의 배수 연도 - 프로젝트 중심
      adjustedCategoryTime = {
        '프로젝트': (totalTime * 0.5).toInt(),
        '공부': (totalTime * 0.25).toInt(),
        '운동': (totalTime * 0.15).toInt(),
        '기타': (totalTime * 0.1).toInt(),
      };
      print('🎨 프로젝트 중심 패턴');
    } else if (selectedYear % 4 == 1) { // 공부 중심
      adjustedCategoryTime = {
        '프로젝트': (totalTime * 0.2).toInt(),
        '공부': (totalTime * 0.55).toInt(),
        '운동': (totalTime * 0.15).toInt(),
        '기타': (totalTime * 0.1).toInt(),
      };
      print('🎨 공부 중심 패턴');
    } else if (selectedYear % 4 == 2) { // 운동 중심
      adjustedCategoryTime = {
        '프로젝트': (totalTime * 0.25).toInt(),
        '공부': (totalTime * 0.25).toInt(),
        '운동': (totalTime * 0.4).toInt(),
        '기타': (totalTime * 0.1).toInt(),
      };
      print('🎨 운동 중심 패턴');
    } else { // 균형 패턴
      adjustedCategoryTime = {
        '프로젝트': (totalTime * 0.3).toInt(),
        '공부': (totalTime * 0.3).toInt(),
        '운동': (totalTime * 0.25).toInt(),
        '기타': (totalTime * 0.15).toInt(),
      };
      print('🎨 균형 패턴');
    }
    
    print('🎨 카테고리 분포: ${adjustedCategoryTime}');
    
    // 선택된 연도 정보를 포함한 DailyStats로 반환
    return [
      DailyStats(
        date: _selectedYear, // 선택된 연도 사용
        studyTimeMinutes: 0,
        completedTasks: 0,
        totalTasks: 0,
        categoryTime: adjustedCategoryTime,
        achievements: [],
      )
    ];
  }

  // 배지 표시 위젯
  Widget _buildAchievementBadges(List<String> achievements, String period) {
    if (achievements.isEmpty) {
      return Container();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events,
                color: Colors.amber.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '$period 배지',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: achievements.map((achievement) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getBadgeColor(achievement).withOpacity(0.8),
                      _getBadgeColor(achievement),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _getBadgeColor(achievement).withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getBadgeEmoji(achievement),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      achievement,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 배지 색상 반환
  Color _getBadgeColor(String achievement) {
    if (achievement.contains('마스터') || achievement.contains('완벽')) {
      return Colors.purple.shade600;
    } else if (achievement.contains('집중') || achievement.contains('시간')) {
      return Colors.blue.shade600;
    } else if (achievement.contains('꾸준')) {
      return Colors.green.shade600;
    } else {
      return Colors.orange.shade600;
    }
  }

  // 배지 이모지 반환
  String _getBadgeEmoji(String achievement) {
    if (achievement.contains('마스터')) {
      return '👑';
    } else if (achievement.contains('집중') || achievement.contains('시간')) {
      return '⏰';
    } else if (achievement.contains('꾸준')) {
      return '🔥';
    } else if (achievement.contains('완벽')) {
      return '⭐';
    } else {
      return '🏆';
    }
  }

  Map<String, int> _processCategories(Map<String, int> originalCategories) {
    if (originalCategories.isEmpty) return {};
    
    // 10% 미만 처리를 제거하고 모든 카테고리를 유지
    // 카테고리를 시간 순으로 정렬하여 일관성 있게 표시
    List<MapEntry<String, int>> sortedCategories = originalCategories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    Map<String, int> processedCategories = {};
    for (var entry in sortedCategories) {
      processedCategories[entry.key] = entry.value;
    }
    
    return processedCategories;
  }

  Widget _buildCategoryChart(List<DailyStats> data) {
    // 카테고리별 시간 집계
    Map<String, int> categoryTime = {};
    for (var daily in data) {
      daily.categoryTime.forEach((category, time) {
        categoryTime[category] = (categoryTime[category] ?? 0) + time;
      });
    }
    
    // 카테고리 정리 (10% 미만은 기타로)
    categoryTime = _processCategories(categoryTime);
    
    if (categoryTime.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text('카테고리 데이터가 없습니다.'),
        ),
      );
    }
    
    int totalTime = categoryTime.values.reduce((a, b) => a + b);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '카테고리별 시간',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // 도넛 차트
              SizedBox(
                width: 120,
                height: 120,
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: DonutChartPainter(
                        categoryTime,
                        totalTime,
                        _progressAnimation.value,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 20),
              // 범례
              Expanded(
                child: Column(
                  children: categoryTime.entries.map((entry) {
                    Color color = _getCategoryColor(entry.key);
                    double percentage = (entry.value / totalTime) * 100;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatTime(entry.value), // 시간 형식 변경
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${percentage.toInt()}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    // 주요 카테고리들
    switch (category) {
      case '프로젝트':
        return Colors.blue.shade400;
      case '공부':
        return Colors.purple.shade400;
      case '운동':
        return Colors.green.shade400;
      case '독서':
        return Colors.pink.shade400;
      case '취미':
        return Colors.teal.shade400;
      case '업무':
        return Colors.indigo.shade400;
      case '요리':
        return Colors.lime.shade400;
      case '영화':
        return Colors.deepPurple.shade400;
      case '음악':
        return Colors.cyan.shade400;
      case '게임':
        return Colors.amber.shade400;
      case '쇼핑':
        return Colors.lightBlue.shade400;
      case '여행':
        return Colors.lightGreen.shade400;
      case '친구':
        return Colors.brown.shade400;
      case '가족':
        return Colors.red.shade400;
      case '기타':
        return Colors.grey.shade400;
      default:
        // 사용자 정의 카테고리를 위한 해시 기반 색상
        int hash = category.hashCode;
        List<Color> colors = [
          Colors.red.shade400,
          Colors.pink.shade400,
          Colors.purple.shade400,
          Colors.deepPurple.shade400,
          Colors.indigo.shade400,
          Colors.blue.shade400,
          Colors.lightBlue.shade400,
          Colors.cyan.shade400,
          Colors.teal.shade400,
          Colors.green.shade400,
          Colors.lightGreen.shade400,
          Colors.lime.shade400,
          Colors.yellow.shade400,
          Colors.amber.shade400,
          Colors.deepOrange.shade400,
          Colors.brown.shade400,
          Colors.blueGrey.shade400,
        ];
        return colors[hash.abs() % colors.length];
    }
  }
}

class DonutChartPainter extends CustomPainter {
  final Map<String, int> data;
  final int total;
  final double animationValue;

  DonutChartPainter(this.data, this.total, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 20.0;

    double startAngle = -math.pi / 2;

    data.forEach((category, value) {
      final sweepAngle = (value / total) * 2 * math.pi * animationValue;
      final paint = Paint()
        ..color = _getCategoryColor(category)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle / animationValue;
    });
  }

  Color _getCategoryColor(String category) {
    // 주요 카테고리들 - _StatisticsPageState와 동일한 색상 매핑
    switch (category) {
      case '프로젝트':
        return Colors.blue.shade400;
      case '공부':
        return Colors.purple.shade400;
      case '운동':
        return Colors.green.shade400;
      case '독서':
        return Colors.pink.shade400;
      case '취미':
        return Colors.teal.shade400;
      case '업무':
        return Colors.indigo.shade400;
      case '요리':
        return Colors.lime.shade400;
      case '영화':
        return Colors.deepPurple.shade400;
      case '음악':
        return Colors.cyan.shade400;
      case '게임':
        return Colors.amber.shade400;
      case '쇼핑':
        return Colors.lightBlue.shade400;
      case '여행':
        return Colors.lightGreen.shade400;
      case '친구':
        return Colors.brown.shade400;
      case '가족':
        return Colors.red.shade400;
      case '기타':
        return Colors.grey.shade400;
      default:
        // 사용자 정의 카테고리를 위한 해시 기반 색상
        int hash = category.hashCode;
        List<Color> colors = [
          Colors.red.shade400,
          Colors.pink.shade400,
          Colors.purple.shade400,
          Colors.deepPurple.shade400,
          Colors.indigo.shade400,
          Colors.blue.shade400,
          Colors.lightBlue.shade400,
          Colors.cyan.shade400,
          Colors.teal.shade400,
          Colors.green.shade400,
          Colors.lightGreen.shade400,
          Colors.lime.shade400,
          Colors.yellow.shade400,
          Colors.amber.shade400,
          Colors.deepOrange.shade400,
          Colors.brown.shade400,
          Colors.blueGrey.shade400,
        ];
        return colors[hash.abs() % colors.length];
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 빗금 패턴 그리기 위한 커스텀 페인터
class DiagonalStripePainter extends CustomPainter {
  final Color color;
  
  DiagonalStripePainter(this.color);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 0.5;
    
    // 작은 블록에 맞는 더 촘촘한 대각선 빗금
    for (double i = -size.height; i < size.width + size.height; i += 2.0) {
      final start = Offset(i, 0);
      final end = Offset(i + size.height, size.height);
      
      // 블록 경계 내에서만 그리기
      if (start.dx < size.width || end.dx > 0) {
        canvas.drawLine(
          Offset(math.max(0, start.dx), start.dy),
          Offset(math.min(size.width, end.dx), end.dy),
          paint,
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 