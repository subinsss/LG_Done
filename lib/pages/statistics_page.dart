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
        _yearlyData = results[3] as List<MonthlyStats>;
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

  // 기본 연간 데이터 (오프라인용)
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

  // 일간 요약 카드
  Widget _buildDailySummaryCard() {
    int totalStudyTime = _dailyData?.studyTimeMinutes ?? 0;
    int totalCompleted = _dailyData?.completedTasks ?? 0;
    int totalTasks = _dailyData?.totalTasks ?? 0;
    
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
                  '총 공부시간',
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
                  '완료 할일',
                  '$totalCompleted/$totalTasks',
                  Icons.task_alt,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildStatItem(
                  '집중도',
                  totalStudyTime > 0 ? "높음" : "낮음",
                  Icons.psychology,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 타임테이블 (10분 단위)
  Widget _buildTimeTable() {
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
              // 범례
              Row(
                children: [
                  _buildLegendItem('프로젝트', Colors.blue.shade400),
                  const SizedBox(width: 8),
                  _buildLegendItem('공부', Colors.purple.shade400),
                  const SizedBox(width: 8),
                  _buildLegendItem('운동', Colors.green.shade400),
                  const SizedBox(width: 8),
                  _buildLegendItem('기타', Colors.orange.shade400),
                ],
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
                        bool hasActivity = _getActivityForTimeSlot(hour, tenMinute * 10);
                        
                        return Expanded(
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.all(0.5),
                            decoration: BoxDecoration(
                              color: hasActivity ? color : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: hasActivity ? color.withOpacity(0.3) : Colors.grey.shade200,
                                width: 0.5,
                              ),
                            ),
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

  // 시간대별 활동 여부 확인 (임시 데이터)
  bool _getActivityForTimeSlot(int hour, int minute) {
    // 실제로는 Firebase에서 해당 시간대 데이터를 확인
    if (hour >= 9 && hour <= 12) return true; // 오전 공부시간
    if (hour >= 14 && hour <= 17) return true; // 오후 공부시간
    if (hour >= 19 && hour <= 21) return true; // 저녁 공부시간
    return false;
  }

  // 시간대별 활동 타입 (임시 데이터)
  String _getActivityTypeForTimeSlot(int hour, int minute) {
    if (hour >= 9 && hour <= 12) return '프로젝트';
    if (hour >= 14 && hour <= 17) return '공부';
    if (hour >= 19 && hour <= 21) return '운동';
    return '휴식';
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
      default:
        return Colors.grey.shade400;
    }
  }

  // 일간 카테고리 차트
  Widget _buildDailyCategoryChart() {
    // 일간 카테고리별 시간 집계 - 실제 일간 데이터 사용
    Map<String, int> categoryTime = _dailyData?.categoryTime ?? {};
    
    // 데이터가 없으면 기본 데이터 생성
    if (categoryTime.isEmpty) {
      categoryTime = {
        '프로젝트': 180, // 3시간
        '공부': 240,     // 4시간  
        '운동': 90,      // 1.5시간
        '기타': 60,      // 1시간
      };
    }
    
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
                                '${(entry.value / 60).toStringAsFixed(1)}시간',
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
          _buildYearlyCategoryChart(),
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
                  '총 공부시간',
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
                  '${weeklyAvg.toInt()}분/일',
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
                  '총 공부시간',
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
                  '${monthlyAvg.toInt()}분/주',
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
            '연간 요약',
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
                  '총 공부시간',
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

  Widget _buildWeeklyChart() {
    final weekDays = ['월', '화', '수', '목', '금', '토', '일'];
    
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
                
                int studyTime = _weeklyData[index].studyTimeMinutes;
                double maxHeight = 160;
                double height = _weeklyData.isNotEmpty 
                    ? (studyTime / _weeklyData.map((e) => e.studyTimeMinutes).reduce((a, b) => a > b ? a : b)) * maxHeight
                    : 0;
                
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 24,
                          height: height * _progressAnimation.value,
                          decoration: BoxDecoration(
                            color: index == 6 // 오늘 (일요일)
                                ? Colors.purple.shade400
                                : Colors.purple.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                      '$studyTime분',
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
    );
  }

  // 월간 차트
  Widget _buildMonthlyChart() {
    // 선택된 월의 일수 계산
    int daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    
    // 월간 데이터를 일별로 매핑 (1일~마지막일)
    Map<int, DailyStats?> dailyDataMap = {};
    for (var data in _monthlyData) {
      dailyDataMap[data.date.day] = data;
    }
    
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
                    int dayNumber = index + 1; // 1일부터 마지막일까지
                    DailyStats? dayData = dailyDataMap[dayNumber];
                    
                    int studyTime = dayData?.studyTimeMinutes ?? 0;
                    double maxHeight = 160;
                    
                    // 최대값 계산 (모든 일 데이터 중에서)
                    int maxStudyTime = _monthlyData.isNotEmpty 
                        ? _monthlyData.map((e) => e.studyTimeMinutes).reduce((a, b) => a > b ? a : b)
                        : 1;
                    
                    double height = maxStudyTime > 0 ? (studyTime / maxStudyTime) * maxHeight : 0;
                    
                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
                              return Container(
                                width: 8,
                                height: height * _progressAnimation.value,
                                decoration: BoxDecoration(
                                  color: dayData != null 
                                      ? Colors.purple.shade300 
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
              );
            },
          ),
                          const SizedBox(height: 4),
                          if (dayNumber % 5 == 1 || dayNumber == daysInMonth) // 1, 6, 11, 16, 21, 26일과 마지막일 표시
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
    );
  }

  // 연간 차트
  Widget _buildYearlyChart() {
    final months = ['1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월', '9월', '10월', '11월', '12월'];
    
    // 연간 데이터를 월별로 매핑 (1월~12월)
    Map<int, MonthlyStats?> monthlyDataMap = {};
    for (var data in _yearlyData) {
      monthlyDataMap[data.month.month] = data;
    }
    
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
                int monthNumber = index + 1; // 1월부터 12월까지
                MonthlyStats? monthData = monthlyDataMap[monthNumber];
                
                int studyTime = monthData?.totalStudyTimeMinutes ?? 0;
                double maxHeight = 160;
                
                // 최대값 계산 (모든 월 데이터 중에서)
                int maxStudyTime = _yearlyData.isNotEmpty 
                    ? _yearlyData.map((e) => e.totalStudyTimeMinutes).reduce((a, b) => a > b ? a : b)
                    : 1;
                
                double height = maxStudyTime > 0 ? (studyTime / maxStudyTime) * maxHeight : 0;
                
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
                          height: height * _progressAnimation.value,
                          decoration: BoxDecoration(
                                color: monthData != null 
                                ? Colors.purple.shade400
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                          ),
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
                        if (studyTime > 0)
                    Text(
                            '${(studyTime / 60).toInt()}h',
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
    );
  }

  Widget _buildCategoryChart(List<DailyStats> data) {
    // 카테고리별 시간 집계
    Map<String, int> categoryTime = {};
    for (var daily in data) {
      daily.categoryTime.forEach((category, time) {
        categoryTime[category] = (categoryTime[category] ?? 0) + time;
      });
    }
    
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
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Text(
                            '${percentage.toInt()}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
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

  // 연간 카테고리 차트
  Widget _buildYearlyCategoryChart() {
    // 연간 카테고리별 시간 집계
    Map<String, int> categoryTime = {};
    for (var monthly in _yearlyData) {
      monthly.categoryTime.forEach((category, time) {
        categoryTime[category] = (categoryTime[category] ?? 0) + time;
      });
    }
    
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
            '연간 카테고리별 시간',
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
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                  Text(
                            '${percentage.toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                              color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
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
    switch (category) {
      case '프로젝트':
        return Colors.blue.shade400;
      case '운동':
        return Colors.green.shade400;
      case '공부':
        return Colors.purple.shade400;
      case '기타':
        return Colors.orange.shade400;
      default:
        return Colors.grey.shade400;
    }
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
    switch (category) {
      case '프로젝트':
        return Colors.blue.shade400;
      case '운동':
        return Colors.green.shade400;
      case '공부':
        return Colors.purple.shade400;
      case '기타':
        return Colors.orange.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 