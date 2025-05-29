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
    
    // 모든 날짜를 오늘로 초기화
    DateTime today = DateTime.now();
    _selectedDay = today;
    _selectedWeek = today;
    _selectedMonth = DateTime(today.year, today.month, 1);
    _selectedYear = DateTime(today.year, 1, 1);
    
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
      
      // 현재 탭에 따라 다른 데이터 로드
      Future<List<DailyStats>> weeklyFuture;
      Future<List<DailyStats>> monthlyFuture;
      
      // 주간 데이터는 현재 선택된 주간의 데이터를 가져오기
      weeklyFuture = _statisticsService.getSpecificWeekStats(_selectedWeek);
      
      // 월간 데이터는 현재 선택된 월의 데이터를 가져오기
      monthlyFuture = _statisticsService.getSpecificMonthStats(_selectedMonth);
      
      final yearlyFuture = _statisticsService.getSpecificYearStats(_selectedYear);
      
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
      ]);

      // Firebase 데이터 확인
      DailyStats dailyData = results[0] as DailyStats;
      List<DailyStats> weeklyData = results[1] as List<DailyStats>;
      List<DailyStats> monthlyData = results[2] as List<DailyStats>;
      List<MonthlyStats> yearlyData = results[3] as List<MonthlyStats>;
      
      // 데이터가 모두 비어있으면 Firebase 연결 실패
      bool hasFirebaseData = dailyData.studyTimeMinutes > 0 || 
                            dailyData.completedTasks > 0 ||
                            weeklyData.isNotEmpty ||
                            monthlyData.isNotEmpty ||
                            yearlyData.isNotEmpty;

      setState(() {
        _dailyData = dailyData;
        _weeklyData = weeklyData;
        _monthlyData = monthlyData;
        _yearlyData = yearlyData;
        _dailyAchievements = results[4] as List<String>;
        _weeklyAchievements = results[5] as List<String>;
        _monthlyAchievements = results[6] as List<String>;
        _yearlyAchievements = results[7] as List<String>;
        _isLoading = false;
        _isOfflineMode = !hasFirebaseData;
        _errorMessage = !hasFirebaseData ? 'Firebase에 연결할 수 없습니다. 할일을 완료하면 통계가 표시됩니다.' : null;
      });
      
      print('✅ 통계 데이터 로딩 완료');
    } catch (e) {
      print('❌ 통계 데이터 로드 실패: $e');
      
      // 오류 발생 시 빈 데이터 사용
      setState(() {
        _dailyData = DailyStats.empty(_selectedDay);
        _weeklyData = [];
        _monthlyData = [];
        _yearlyData = [];
        _dailyAchievements = [];
        _weeklyAchievements = [];
        _monthlyAchievements = [];
        _yearlyAchievements = [];
        _isLoading = false;
        _isOfflineMode = true;
        _errorMessage = 'Firebase 연결에 실패했습니다. 네트워크 연결을 확인해주세요.';
      });
      
      // 사용자에게 알림 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Firebase 연결 실패 - 할일을 완료하면 통계가 표시됩니다'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
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
    // Firebase 연결 실패시에도 빈 리스트 반환
    return [];
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
          break;
      }
    });
    _loadStatistics(); // 새로운 기간의 데이터 로드
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

  // 시간별 활동에서 실제 블록 데이터 수집 - Firebase 데이터가 없으면 빈 데이터 반환
  Map<String, dynamic> _getTimeTableAnalysis() {
    // Firebase 데이터가 있는 경우에만 분석
    if (_dailyData != null && _dailyData!.categoryTime.isNotEmpty) {
      return {
        'categoryMinutes': _dailyData!.categoryTime,
        'totalActiveBlocks': (_dailyData!.studyTimeMinutes / 10).round(),
        'totalPlannedBlocks': (_dailyData!.totalTasks * 30 / 10).round(), // 할일당 평균 30분 가정
        'completionRate': _dailyData!.totalTasks > 0 ? (_dailyData!.completedTasks / _dailyData!.totalTasks * 100) : 0,
      };
    }
    
    // Firebase 데이터가 없으면 빈 데이터 반환
    return {
      'categoryMinutes': <String, int>{},
      'totalActiveBlocks': 0,
      'totalPlannedBlocks': 0,
      'completionRate': 0.0,
    };
  }

  // 통합된 일간 카테고리 데이터 생성 - Firebase 데이터 우선 사용
  Map<String, int> _getDailyUnifiedCategoryData() {
    // Firebase 데이터가 있으면 사용
    if (_dailyData != null && _dailyData!.categoryTime.isNotEmpty) {
      return _dailyData!.categoryTime;
    }
    
    // Firebase 데이터가 없으면 빈 데이터 반환
    return {};
  }

  // 일간 요약 카드 - Firebase 데이터가 없으면 적절한 메시지 표시
  Widget _buildDailySummaryCard() {
    // Firebase 데이터가 없으면 메시지 표시
    if (_isOfflineMode) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey.shade300, Colors.grey.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            const Text(
              'Firebase 연결 없음',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '할일을 완료하면 통계가 여기에 표시됩니다',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Firebase 데이터를 사용한 기존 로직
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

  // 타임테이블 - Firebase 데이터가 없으면 빈 표시
  Widget _buildTimeTable() {
    // Firebase 데이터가 없으면 빈 상태 표시
    if (_isOfflineMode) {
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '시간별 활동',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            Icon(
              Icons.schedule,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Firebase에 연결되지 않았습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '할일을 완료하면 시간별 활동이 표시됩니다',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
          ],
        ),
      );
    }

    // Firebase 데이터를 사용한 기존 로직
    Map<String, int> categoryTime = _getDailyUnifiedCategoryData();
    
    // 현재 활성 탭에 따라 다른 hourlyActivity 데이터 사용
    Map<int, int> hourlyActivity = {};
    
    switch (_tabController.index) {
      case 0: // 일간
        if (_dailyData != null) {
          hourlyActivity = _dailyData!.hourlyActivity;
        }
        break;
      case 1: // 주간
        // 현재 선택된 주간의 데이터만 필터링
        DateTime startOfWeek = _selectedWeek.subtract(Duration(days: _selectedWeek.weekday - 1));
        DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
        
        for (var dailyStats in _weeklyData) {
          // 현재 선택된 주에 해당하는 날짜인지 확인
          if (dailyStats.date.isAfter(startOfWeek.subtract(Duration(days: 1))) && 
              dailyStats.date.isBefore(endOfWeek.add(Duration(days: 1)))) {
            dailyStats.hourlyActivity.forEach((hour, minutes) {
              hourlyActivity[hour] = (hourlyActivity[hour] ?? 0) + minutes;
            });
          }
        }
        break;
      case 2: // 월간
        // 현재 선택된 월의 데이터만 필터링
        for (var dailyStats in _monthlyData) {
          if (dailyStats.date.year == _selectedMonth.year && 
              dailyStats.date.month == _selectedMonth.month) {
            dailyStats.hourlyActivity.forEach((hour, minutes) {
              hourlyActivity[hour] = (hourlyActivity[hour] ?? 0) + minutes;
            });
          }
        }
        break;
      case 3: // 연간
        // 연간은 시간대별 데이터가 너무 많으므로 빈 데이터 사용
        hourlyActivity = {};
        break;
    }
    
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
                Text(
                  _getTimeTableTitle(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // 총 활동 시간 표시
                if (hourlyActivity.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '총 ${_formatTime(hourlyActivity.values.fold(0, (a, b) => a + b))}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (categoryTime.isNotEmpty) ...[
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
              // 실제 데이터 기반 타임라인 (간단화)
              Container(
                height: 80,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(24, (hour) {
                    int maxActivity = hourlyActivity.isEmpty ? 0 : hourlyActivity.values.reduce((a, b) => a > b ? a : b);
                    int activityMinutes = hourlyActivity[hour] ?? 0;
                    double heightRatio = maxActivity > 0 ? activityMinutes / maxActivity : 0.0;
                    double barHeight = activityMinutes > 0 ? (60 * heightRatio + 10) : 10;
                    
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (activityMinutes > 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${hour}시: ${_formatTime(activityMinutes)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                duration: const Duration(seconds: 1),
                                backgroundColor: Colors.blue.shade600,
                              ),
                            );
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: activityMinutes > 0 
                                ? _getActivityIntensityColor(activityMinutes, maxActivity)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: activityMinutes > 0 
                                  ? Colors.blue.shade200
                                  : Colors.grey.shade200,
                              width: 0.5,
                            ),
                          ),
                          child: activityMinutes > 0 && barHeight > 20
                              ? Center(
                                  child: Text(
                                    '${activityMinutes}m',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ] else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _getEmptyTimeTableMessage(),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '할일을 완료하면 시간별 활동이 표시됩니다',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
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

  // 활동 강도에 따른 색상 반환
  Color _getActivityIntensityColor(int minutes, int maxMinutes) {
    if (maxMinutes == 0) return Colors.grey.shade200;
    
    double ratio = minutes / maxMinutes;
    if (ratio > 0.66) {
      return Colors.blue.shade600; // 높음
    } else if (ratio > 0.33) {
      return Colors.blue.shade400; // 보통
    } else {
      return Colors.blue.shade200; // 낮음
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

  // 일간 카테고리 차트 - Firebase 데이터가 없으면 빈 상태 표시
  Widget _buildDailyCategoryChart() {
    // Firebase 데이터가 없으면 빈 상태 표시
    if (_isOfflineMode) {
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '일간 카테고리별 시간',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            Icon(
              Icons.pie_chart,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Firebase에 연결되지 않았습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '카테고리별 활동 시간이 여기에 표시됩니다',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
          ],
        ),
      );
    }

    // Firebase 데이터를 사용한 기존 로직
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

  // 날짜 선택기 - 더 직관적인 UI로 개선
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
          // 이전 버튼
          IconButton(
            onPressed: () => _changePeriod(period, -1),
            icon: const Icon(Icons.chevron_left),
            color: Colors.purple.shade600,
            tooltip: _getPreviousTooltip(period),
          ),
          // 날짜 텍스트 + 오늘로 가기 버튼
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _getDateRangeText(period),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade600,
                  ),
                ),
                if (!_isToday(period)) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _goToToday(period),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.today,
                            size: 14,
                            color: Colors.purple.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '오늘',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.purple.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 다음 버튼 (미래는 오늘까지만)
          IconButton(
            onPressed: _canGoNext(period) ? () => _changePeriod(period, 1) : null,
            icon: const Icon(Icons.chevron_right),
            color: _canGoNext(period) ? Colors.purple.shade600 : Colors.grey.shade300,
            tooltip: _canGoNext(period) ? _getNextTooltip(period) : '미래 날짜는 선택할 수 없습니다',
          ),
        ],
      ),
    );
  }

  // 오늘인지 확인
  bool _isToday(String period) {
    DateTime today = DateTime.now();
    switch (period) {
      case '일간':
        return _selectedDay.year == today.year &&
               _selectedDay.month == today.month &&
               _selectedDay.day == today.day;
      case '주간':
        DateTime startOfThisWeek = today.subtract(Duration(days: today.weekday - 1));
        DateTime startOfSelectedWeek = _selectedWeek.subtract(Duration(days: _selectedWeek.weekday - 1));
        return startOfThisWeek.year == startOfSelectedWeek.year &&
               startOfThisWeek.month == startOfSelectedWeek.month &&
               startOfThisWeek.day == startOfSelectedWeek.day;
      case '월간':
        return _selectedMonth.year == today.year && _selectedMonth.month == today.month;
      case '연간':
        return _selectedYear.year == today.year;
      default:
        return false;
    }
  }

  // 다음으로 갈 수 있는지 확인 (미래 제한)
  bool _canGoNext(String period) {
    DateTime today = DateTime.now();
    switch (period) {
      case '일간':
        return _selectedDay.isBefore(DateTime(today.year, today.month, today.day));
      case '주간':
        DateTime nextWeek = _selectedWeek.add(const Duration(days: 7));
        DateTime startOfThisWeek = today.subtract(Duration(days: today.weekday - 1));
        return nextWeek.isBefore(startOfThisWeek) || nextWeek.isAtSameMomentAs(startOfThisWeek);
      case '월간':
        DateTime nextMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
        DateTime thisMonth = DateTime(today.year, today.month, 1);
        return nextMonth.isBefore(thisMonth) || nextMonth.isAtSameMomentAs(thisMonth);
      case '연간':
        return _selectedYear.year < today.year;
      default:
        return false;
    }
  }

  // 오늘로 이동
  void _goToToday(String period) {
    DateTime today = DateTime.now();
    setState(() {
      switch (period) {
        case '일간':
          _selectedDay = today;
          break;
        case '주간':
          _selectedWeek = today;
          break;
        case '월간':
          _selectedMonth = DateTime(today.year, today.month, 1);
          break;
        case '연간':
          _selectedYear = DateTime(today.year, 1, 1);
          break;
      }
    });
    _loadStatistics();
  }

  // 툴팁 텍스트
  String _getPreviousTooltip(String period) {
    switch (period) {
      case '일간': return '어제';
      case '주간': return '지난주';
      case '월간': return '지난달';
      case '연간': return '작년';
      default: return '이전';
    }
  }

  String _getNextTooltip(String period) {
    switch (period) {
      case '일간': return '내일';
      case '주간': return '다음주';
      case '월간': return '다음달';
      case '연간': return '내년';
      default: return '다음';
    }
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
                  
                  // 실제 날짜에 맞는 요일 계산
                  String dayOfWeek = _getDayOfWeekKorean(dayData.date.weekday);
                  
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
                        dayOfWeek,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: dayData.date.weekday == 7 ? FontWeight.bold : FontWeight.normal, // 일요일 강조
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

  // 요일 숫자를 한국어 요일로 변환
  String _getDayOfWeekKorean(int weekday) {
    switch (weekday) {
      case 1: return '월';
      case 2: return '화';
      case 3: return '수';
      case 4: return '목';
      case 5: return '금';
      case 6: return '토';
      case 7: return '일';
      default: return '';
    }
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
    print('🎨 연간 카테고리 데이터 생성 중 - 실제 Firebase 데이터 사용');
    
    // 실제 _yearlyData에서 카테고리 시간 집계
    Map<String, int> totalCategoryTime = {};
    for (var monthly in _yearlyData) {
      monthly.categoryTime.forEach((category, time) {
        totalCategoryTime[category] = (totalCategoryTime[category] ?? 0) + time;
      });
    }
    
    print('🎨 실제 연간 카테고리 분포: ${totalCategoryTime}');
    
    // 현재 선택된 연도 정보를 포함한 DailyStats로 반환
    return [
      DailyStats(
        date: _selectedYear,
        studyTimeMinutes: 0,
        completedTasks: 0,
        totalTasks: 0,
        categoryTime: totalCategoryTime,
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

  // 시간대별 활동 제목 반환
  String _getTimeTableTitle() {
    switch (_tabController.index) {
      case 0:
        return '일간 시간별 활동';
      case 1:
        return '주간 시간별 활동';
      case 2:
        return '월간 시간별 활동';
      case 3:
        return '연간 시간별 활동';
      default:
        return '시간별 활동';
    }
  }

  // 빈 시간대별 활동 메시지 반환
  String _getEmptyTimeTableMessage() {
    switch (_tabController.index) {
      case 0:
        return '${DateFormat('MM월 dd일').format(_selectedDay)}에 완료된 할일이 없습니다';
      case 1:
        DateTime startOfWeek = _selectedWeek.subtract(Duration(days: _selectedWeek.weekday - 1));
        DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
        return '${DateFormat('MM월 dd일').format(startOfWeek)} - ${DateFormat('MM월 dd일').format(endOfWeek)} 주간에\n완료된 할일이 없습니다';
      case 2:
        return '${DateFormat('yyyy년 MM월').format(_selectedMonth)}에 완료된 할일이 없습니다';
      case 3:
        return '${_selectedYear.year}년에 완료된 할일이 없습니다';
      default:
        return '완료된 할일이 없습니다';
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