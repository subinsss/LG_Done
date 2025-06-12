import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/statistics_service.dart';
import 'package:intl/intl.dart';

// 도넛 차트 페인터
class DonutChartPainter extends CustomPainter {
  final Map<String, int> categoryTime;
  final int totalTime;
  final double animationValue;
  final Color Function(String) getCategoryColor;

  DonutChartPainter({
    required this.categoryTime,
    required this.totalTime,
    required this.animationValue,
    required this.getCategoryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 40.0;
    
    // 배경 원 그리기
    paint.color = Colors.grey.shade100;
    canvas.drawCircle(center, radius - paint.strokeWidth / 2, paint);
    
    double startAngle = -math.pi / 2;
    
    categoryTime.forEach((category, time) {
      final sweepAngle = 2 * math.pi * (time / totalTime) * animationValue;
      paint.color = getCategoryColor(category);
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - paint.strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      
      startAngle += sweepAngle;
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final StatisticsService _statisticsService = StatisticsService();
  
  bool _isLoading = false;
  bool _isOfflineMode = false;
  String? _errorMessage;
  
  // 선택된 날짜들
  DateTime _selectedDay = DateTime.now();
  DateTime _selectedWeek = DateTime.now();
  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedYear = DateTime.now();
  
  // 데이터
  DailyStats? _dailyData;
  List<DailyStats>? _weeklyData = [];
  List<DailyStats>? _monthlyData = [];
  List<MonthlyStats>? _yearlyData = [];
  
  // 배지 데이터
  List<String> _dailyAchievements = [];
  List<String> _weeklyAchievements = [];
  List<String> _monthlyAchievements = [];
  List<String> _yearlyAchievements = [];
  
  // 애니메이션
  late AnimationController _progressAnimation;
  
  // 오전/오후 선택
  bool _isAM = true; // true: 오전(0-11시), false: 오후(12-23시)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _progressAnimation = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _tabController.addListener(_handleTabChange);
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    try {
      await _statisticsService.initialize();
      await _loadStatistics();
    } catch (e) {
      print('❌ 초기화 실패: $e');
      if (mounted) {
        setState(() {
          _isOfflineMode = true;
          _errorMessage = '데이터 연결에 실패했습니다. 오프라인 모드로 전환합니다.';
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _progressAnimation.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      _loadStatistics();
    }
  }

  Future<void> _loadStatistics() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      switch (_tabController.index) {
        case 0: // 일간
          _dailyData = await _statisticsService.getDailyStats(_selectedDay);
          _dailyAchievements = _dailyData?.achievements ?? [];
          break;
        case 1: // 주간
          DateTime startOfWeek = _selectedWeek.subtract(Duration(days: _selectedWeek.weekday - 1));
          print('📅 주간 데이터 로드: ${startOfWeek.toString()}');
          _weeklyData = await _statisticsService.getWeeklyStats(startOfWeek);
          _weeklyAchievements = _weeklyData?.expand((stats) => stats.achievements).toSet().toList() ?? [];
          break;
        case 2: // 월간
          _monthlyData = await _statisticsService.getMonthlyStats(_selectedMonth);
          _monthlyAchievements = _monthlyData?.expand((stats) => stats.achievements).toSet().toList() ?? [];
          break;
        case 3: // 연간
          _yearlyData = await _statisticsService.getYearlyStats(_selectedYear);
          _yearlyAchievements = _yearlyData?.expand((stats) => stats.achievements).toSet().toList() ?? [];
          break;
      }
      
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      print('❌ 통계 로드 실패: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '데이터를 불러오는데 실패했습니다.';
      });
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

  // 전날 대비 활동시간 증감량 계산
  Future<int> _getYesterdayStudyTime() async {
    DateTime yesterday = _selectedDay.subtract(const Duration(days: 1));
    DailyStats? yesterdayData = await _statisticsService.getDailyStats(yesterday);
    return yesterdayData?.studyTimeMinutes ?? 0;
  }

  // 일간 요약 카드
  Widget _buildDailySummaryCard() {
    if (_isOfflineMode) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              'Firebase 연결 없음',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '할일을 완료하면 통계가 여기에 표시됩니다',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    Map<String, dynamic> analysis = _getTimeTableAnalysis();
    Map<String, int> categoryTime = analysis['categoryMinutes'];
    int totalStudyTime = categoryTime.values.fold(0, (sum, time) => sum + time);
    double completionRate = analysis['completionRate'];

    return FutureBuilder<int>(
      future: _getYesterdayStudyTime(),
      builder: (context, snapshot) {
        int yesterdayTime = snapshot.data ?? 0;
        int timeDifference = totalStudyTime - yesterdayTime;
        String differenceText = timeDifference >= 0 ? '+${_formatTime(timeDifference)}' : '-${_formatTime(timeDifference.abs())}';
        Color differenceColor = timeDifference >= 0 ? Colors.green.shade600 : Colors.red.shade600;

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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '일간 요약',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.timer, color: Colors.grey.shade600, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '총 활동시간',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(totalStudyTime),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.trending_up, color: Colors.grey.shade600, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '전날 대비',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          differenceText,
                          style: TextStyle(
                            color: differenceColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.grey.shade600, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '완료율',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${completionRate.toInt()}%',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.psychology, color: Colors.grey.shade600, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '집중도',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          focusLevel,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.grey.shade600, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
        
        for (var dailyStats in _weeklyData!) {
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
        for (var dailyStats in _monthlyData!) {
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

    // 최대 활동 시간 찾기
    int maxActivity = hourlyActivity.isEmpty ? 0 : hourlyActivity.values.reduce((a, b) => a > b ? a : b);
    
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
                Row(
                  children: [
                    // 오전/오후 선택 버튼
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isAM = true;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _isAM ? Colors.blue.shade600 : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '오전',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _isAM ? Colors.white : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isAM = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: !_isAM ? Colors.blue.shade600 : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '오후',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: !_isAM ? Colors.white : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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
              ],
            ),
            const SizedBox(height: 20),
            if (categoryTime.isNotEmpty) ...[
              // 시간 라벨 (0시~23시)
              SizedBox(
                height: 30,
                child: Row(
                  children: List.generate(12, (index) {
                    final hour = _isAM ? index : index + 12;
                    return Expanded(
                      child: Center(
                        child: Text(
                          (index == 0 ? 12 : index).toString(),
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
                  children: List.generate(12, (index) {
                    final hour = _isAM ? index : index + 12;
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
                            borderRadius: BorderRadius.zero,
                            border: Border.all(
                              color: activityMinutes > 0 
                                  ? Colors.blue.shade200
                                  : Colors.grey.shade200,
                              width: 0.5,
                            ),
                          ),
                          child: activityMinutes > 0
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${activityMinutes}',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                          color: barHeight > 20 ? Colors.white : Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        'm',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                          color: barHeight > 20 ? Colors.white : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
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
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '할일을 완료하면 시간별 활동이 표시됩니다',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
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
      print('📊 차트 상태: 오프라인 모드');
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
    print('📊 카테고리 데이터: $categoryTime');
    
    // 카테고리 정리 (10% 미만은 기타로)
    categoryTime = _processCategories(categoryTime);
    print('📊 처리된 카테고리 데이터: $categoryTime');
    
    if (categoryTime.isEmpty) {
      print('📊 차트 상태: 데이터 없음');
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
    print('📊 전체 시간: $totalTime');

    // totalTime이 0이면 빈 데이터 표시
    if (totalTime == 0) {
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

    // 애니메이션 시작
    _progressAnimation.forward(from: 0.0);
    
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
                    print('📊 애니메이션 값: ${_progressAnimation.value}');
                    return SizedBox(
                      width: 120,
                      height: 120,
                      child: CustomPaint(
                        size: const Size(120, 120),
                        painter: DonutChartPainter(
                          categoryTime: categoryTime,
                          totalTime: totalTime,
                          animationValue: _progressAnimation.value,
                          getCategoryColor: _getCategoryColor,
                        ),
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
                                _formatTime(entry.value),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '통계',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
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
          indicatorColor: Colors.black,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey.shade600,
          isScrollable: false,
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
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            )
          : TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(), // 스와이프 비활성화
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
          crossAxisAlignment: CrossAxisAlignment.center,
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
    if (_weeklyData!.isEmpty) {
      return const Center(child: Text('주간 데이터가 없습니다.'));
    }

    return GestureDetector(
      onPanUpdate: (details) {
        // 스와이프 감지
        if (details.delta.dx > 10) {
          // 오른쪽 스와이프 - 이전주
          _changePeriod('주간', -1);
        } else if (details.delta.dx < -10) {
          // 왼쪽 스와이프 - 다음주
          _changePeriod('주간', 1);
        }
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildDateSelector('주간'),
            const SizedBox(height: 16),
            _buildAchievementBadges(_weeklyAchievements, '주간'),
            _buildWeeklySummaryCard(),
            const SizedBox(height: 20),
              _buildWeeklyChart(),
              const SizedBox(height: 20),
            _buildCategoryChart(_weeklyData!),
          ],
        ),
      ),
    );
  }

  // 월간 뷰
  Widget _buildMonthlyView() {
    if (_monthlyData!.isEmpty) {
      return const Center(child: Text('월간 데이터가 없습니다.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildDateSelector('월간'),
          const SizedBox(height: 16),
          _buildAchievementBadges(_monthlyAchievements, '월간'),
          _buildMonthlySummaryCard(),
            const SizedBox(height: 20),
          _buildMonthlyChart(),
          const SizedBox(height: 20),
          _buildCategoryChart(_monthlyData!),
        ],
      ),
    );
  }

  // 연간 뷰
  Widget _buildYearlyView() {
    if (_yearlyData!.isEmpty) {
      return const Center(child: Text('연간 데이터가 없습니다.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
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
            color: Colors.black,
            tooltip: _getPreviousTooltip(period),
          ),
          // 날짜 텍스트 + 오늘로 가기 버튼
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _showDatePicker(period),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.black,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getDateRangeText(period),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!_isToday(period)) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _goToToday(period),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.today,
                            size: 10,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '오늘',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
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
            color: _canGoNext(period) ? Colors.black : Colors.grey.shade400,
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
        // 선택된 주의 시작일과 이번 주의 시작일 계산
        DateTime startOfSelectedWeek = _selectedWeek.subtract(Duration(days: _selectedWeek.weekday - 1));
        DateTime startOfThisWeek = today.subtract(Duration(days: today.weekday - 1));
        
        // 선택된 주의 다음 주 시작일이 이번 주 시작일보다 이전이면 다음으로 이동 가능
        DateTime startOfNextWeek = startOfSelectedWeek.add(const Duration(days: 7));
        return startOfNextWeek.isBefore(startOfThisWeek) || startOfNextWeek.isAtSameMomentAs(startOfThisWeek);
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
    int totalStudyTime = _weeklyData!.fold(0, (sum, stat) => sum + stat.studyTimeMinutes);
    int totalCompleted = _weeklyData!.fold(0, (sum, stat) => sum + stat.completedTasks);
    int totalTasks = _weeklyData!.fold(0, (sum, stat) => sum + stat.totalTasks);
    double weeklyAvg = _weeklyData!.isNotEmpty ? totalStudyTime / 7 : 0; // 주간 평균 (7일 기준)

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
            '주간 요약',
                style: TextStyle(
				  color: Colors.black,
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
    int totalStudyTime = _monthlyData!.fold(0, (sum, stat) => sum + stat.studyTimeMinutes);
    int totalCompleted = _monthlyData!.fold(0, (sum, stat) => sum + stat.completedTasks);
    int totalTasks = _monthlyData!.fold(0, (sum, stat) => sum + stat.totalTasks);
    double monthlyAvg = _monthlyData!.isNotEmpty ? totalStudyTime / 4 : 0; // 월간 평균을 주 단위로 (4주 기준)

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '월간 요약',
            style: TextStyle(
              color: Colors.black,
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



  // 연간 요약 카드
  Widget _buildYearlySummaryCard() {
    int totalStudyTime = _yearlyData!.fold(0, (sum, stat) => sum + stat.totalStudyTimeMinutes);
    int totalCompleted = _yearlyData!.fold(0, (sum, stat) => sum + stat.totalCompletedTasks);
    int totalTasks = _yearlyData!.fold(0, (sum, stat) => sum + stat.totalTasks);
    double yearlyAvg = _yearlyData!.isNotEmpty ? totalStudyTime / 12 : 0;

    return Container(
      key: ValueKey('yearly_summary_${_selectedYear.year}'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
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
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_selectedYear.year}년',
                style: TextStyle(
                  color: Colors.grey.shade600,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timer, color: Colors.grey.shade600, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '총 활동시간',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(totalStudyTime / 60).toInt()}시간',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.grey.shade600, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '완료율',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${totalTasks > 0 ? (totalCompleted / totalTasks * 100).toInt() : 0}%',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.trending_up, color: Colors.grey.shade600, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '연간 평균',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(yearlyAvg / 60).toInt()}시간/월',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.task_alt, color: Colors.grey.shade600, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '완료 할일',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalCompleted/$totalTasks',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
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
                  ? BorderRadius.zero
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
            borderRadius: BorderRadius.zero,
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
          borderRadius: BorderRadius.zero,
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
    for (int index = 0; index < 7 && index < _weeklyData!.length; index++) {
      DailyStats dayData = _weeklyData![index];
      Map<String, int> categoryTime = _processCategories(dayData.categoryTime);
      int totalTime = categoryTime.values.fold(0, (a, b) => a + b);
      if (totalTime > maxTotalTime) {
        maxTotalTime = totalTime;
      }
    }
    
    // maxTotalTime이 0이면 빈 데이터 표시
    if (maxTotalTime == 0) {
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              '주간 데이터가 없습니다',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
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
                    if (index >= _weeklyData!.length) return const SizedBox();
                    
                    DailyStats dayData = _weeklyData![index];
                    Map<String, int> categoryTime = _processCategories(dayData.categoryTime);
                    int totalTime = categoryTime.values.fold(0, (a, b) => a + b);
                    
                    double maxHeight = 140; // 최대 높이 감소
                    // 최대값 기준으로 높이 계산
                    double barHeight = maxTotalTime > 0 ? (totalTime / maxTotalTime) * maxHeight : 0;
                    
                    // 실제 날짜에 맞는 요일 계산
                    String dayOfWeek = _getDayOfWeekKorean(dayData.date.weekday);
                    
                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min, // 추가
                        children: [
                          AnimatedBuilder(
                            animation: _progressAnimation,
                            builder: (context, child) {
                              return GestureDetector(
                                onTap: () {
                                  if (totalTime > 0) {
                                    String formattedDate = DateFormat('yyyy년 MM월 dd일').format(dayData.date);
                                    _showCategoryTimeDialog(
                                      context,
                                      categoryTime,
                                      '$formattedDate ($dayOfWeek)',
                                    );
                                  }
                                },
                                child: SizedBox(
                                  width: 20,
                                  child: _buildCategoryBar(categoryTime, barHeight * _progressAnimation.value),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 4), // 간격 감소
                          Text(
                            dayOfWeek,
                            style: TextStyle(
                              fontSize: 11, // 폰트 크기 감소
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold, // 모든 요일 볼드체
                            ),
                          ),
                          Text(
                            '${totalTime}m',
                            style: TextStyle(
                              fontSize: 9, // 폰트 크기 감소
                              color: Colors.grey.shade500,
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
    for (var data in _monthlyData!) {
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
    
    // maxTotalTime이 0이면 빈 데이터 표시
    if (maxTotalTime == 0) {
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              '월간 데이터가 없습니다',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                width: 800,  // 고정된 너비
                height: 180,  // 높이 조정
                padding: EdgeInsets.symmetric(vertical: 10),  // 상하 패딩 추가
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(daysInMonth, (index) {
                    int dayNumber = index + 1;
                    DailyStats? dayData = dailyDataMap[dayNumber];
                    
                    Map<String, int> categoryTime = dayData != null ? _processCategories(dayData.categoryTime) : {};
                    int totalTime = categoryTime.values.fold(0, (a, b) => a + b);
                    
                    // 1일, 10일, 20일, 말일 또는 활동이 있는 날짜 표시
                    bool shouldShowDate = true;  // 모든 날짜 표시
                    
                    double maxHeight = 120;  // 높이 조정
                    // 최대값 기준으로 높이 계산
                    double barHeight = maxTotalTime > 0 ? (totalTime / maxTotalTime) * maxHeight : 0;
                    
                    return Container(
                      width: 24,  // 고정된 막대 너비
                      margin: EdgeInsets.symmetric(horizontal: 1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedBuilder(
                            animation: _progressAnimation,
                            builder: (context, child) {
                              return GestureDetector(
                                onTap: () {
                                  if (totalTime > 0) {
                                    String formattedDate = DateFormat('yyyy년 MM월 dd일').format(
                                      DateTime(_selectedMonth.year, _selectedMonth.month, dayNumber)
                                    );
                                    _showCategoryTimeDialog(
                                      context,
                                      categoryTime,
                                      formattedDate,
                                    );
                                  }
                                },
                                child: Container(
                                  width: 20,
                                  child: _buildCategoryBar(categoryTime, barHeight * _progressAnimation.value),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          // 날짜 표시 영역 - 고정 높이
                          Container(
                            height: 16,  // 날짜 영역 고정 높이
                            child: shouldShowDate
                              ? Text(
                                  dayNumber.toString(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              : const SizedBox(),
                          ),
                          // 시간 표시 영역 - 고정 높이
                          Container(
                            height: 12,  // 시간 영역 고정 높이
                            child: totalTime > 0
                              ? Text(
                                  '${(totalTime / 60).toStringAsFixed(1)}h',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey.shade500,
                                  ),
                                )
                              : const SizedBox(),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
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
    for (var data in _yearlyData!) {
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
                              return GestureDetector(
                                onTap: () {
                                  if (totalTime > 0) {
                                    String formattedDate = '${_selectedYear.year}년 ${index + 1}월';
                                    _showCategoryTimeDialog(
                                      context,
                                      categoryTime,
                                      formattedDate,
                                    );
                                  }
                                },
                                child: Container(
                                  width: 16,
                                  child: _buildCategoryBar(categoryTime, barHeight),
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
                          if (totalTime > 0)
                            Text(
                              '${totalTime}m',
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
    for (var monthly in _yearlyData!) {
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

  // 배지 색상 반환 - 최적화된 버전
  Color _getBadgeColor(String achievement) {
    if (achievement.contains('마스터') || achievement.contains('완벽')) {
      return Colors.purple.shade600;
    } else if (achievement.contains('집중') || achievement.contains('시간')) {
      return Colors.blue.shade600;
    } else if (achievement.contains('꾸준')) {
      return Colors.green.shade600;
    } else if (achievement.contains('목표')) {
      return Colors.teal.shade600;
    } else if (achievement.contains('연속')) {
      return Colors.deepOrange.shade600;
    } else {
      return Colors.orange.shade600;
    }
  }

  // 배지 이모지 반환 - 최적화된 버전
  String _getBadgeEmoji(String achievement) {
    if (achievement.contains('마스터')) {
      return '👑';
    } else if (achievement.contains('집중') || achievement.contains('시간')) {
      return '⏰';
    } else if (achievement.contains('꾸준')) {
      return '🔥';
    } else if (achievement.contains('완벽')) {
      return '⭐';
    } else if (achievement.contains('목표')) {
      return '🎯';
    } else if (achievement.contains('연속')) {
      return '📈';
    } else {
      return '🏆';
    }
  }

  // 카테고리 처리 - 최적화된 버전
  Map<String, int> _processCategories(Map<String, int> originalCategories) {
    if (originalCategories.isEmpty) return {};
    
    int totalTime = originalCategories.values.fold(0, (sum, time) => sum + time);
    double threshold = totalTime * 0.05; // 5% 미만은 '기타'로 통합
    
    Map<String, int> processedCategories = {};
    int otherTime = 0;
    
    // 카테고리를 시간 순으로 정렬
    List<MapEntry<String, int>> sortedCategories = originalCategories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    for (var entry in sortedCategories) {
      if (entry.value >= threshold) {
        processedCategories[entry.key] = entry.value;
      } else {
        otherTime += entry.value;
      }
    }
    
    // '기타' 카테고리가 있는 경우에만 추가
    if (otherTime > 0) {
      processedCategories['기타'] = otherTime;
    }
    
    return processedCategories;
  }

  // 카테고리 색상 반환 - 최적화된 버전
  Color _getCategoryColor(String category) {
    // 주요 카테고리들의 고정 색상
    Map<String, Color> fixedColors = {
      '프로젝트': Colors.blue.shade400,
      '공부': Colors.purple.shade400,
      '운동': Colors.green.shade400,
      '독서': Colors.pink.shade400,
      '취미': Colors.teal.shade400,
      '업무': Colors.indigo.shade400,
      '요리': Colors.lime.shade600,
      '영화': Colors.deepPurple.shade400,
      '음악': Colors.cyan.shade400,
      '게임': Colors.amber.shade600,
      '쇼핑': Colors.lightBlue.shade400,
      '여행': Colors.lightGreen.shade600,
      '친구': Colors.brown.shade400,
      '가족': Colors.red.shade400,
      '기타': Colors.grey.shade400,
    };

    // 고정 색상이 있으면 반환
    if (fixedColors.containsKey(category)) {
      return fixedColors[category]!;
    }

    // 없는 경우 해시 기반으로 색상 생성
    List<Color> extraColors = [
      Colors.deepOrange.shade400,
      Colors.amber.shade400,
      Colors.yellow.shade600,
      Colors.lightGreen.shade400,
      Colors.cyan.shade400,
      Colors.blue.shade300,
      Colors.purple.shade300,
      Colors.pink.shade300,
    ];

    int hash = category.hashCode.abs();
    return extraColors[hash % extraColors.length];
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

  // 일간 날짜 선택기 (달력)
  Future<void> _showDailyDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.purple.shade600,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDay) {
      setState(() {
        _selectedDay = picked;
      });
      _loadStatistics();
    }
  }

  // 주간 선택기
  Future<void> _showWeeklyPicker() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('← → 버튼으로 주간을 변경할 수 있습니다'),
          ],
        ),
        backgroundColor: Colors.purple.shade600,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 월간 선택기
  Future<void> _showMonthlyPicker() async {
    int currentYear = _selectedMonth.year;
    int currentMonth = _selectedMonth.month;
    int startYear = 2020;
    int endYear = DateTime.now().year;
    
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                '연월 선택',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Container(
                width: 320,
                height: 400,
                child: Column(
                  children: [
                    // 현재 선택된 연월 표시
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Text(
                        '${currentYear}년 ${currentMonth}월',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 연도와 월 선택 영역
                    Expanded(
                      child: Row(
                        children: [
                          // 연도 선택
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '연도',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: endYear - startYear + 1,
                                    reverse: true,
                                    itemBuilder: (context, index) {
                                      int year = endYear - index;
                                      bool isSelected = year == currentYear;
                                      
                                      return GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            currentYear = year;
                                            // 미래 월 선택 방지
                                            if (currentYear == DateTime.now().year && 
                                                currentMonth > DateTime.now().month) {
                                              currentMonth = DateTime.now().month;
                                            }
                                          });
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(vertical: 2),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected 
                                                ? Colors.purple.shade600 
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isSelected 
                                                  ? Colors.purple.shade600 
                                                  : Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${year}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                color: isSelected 
                                                    ? Colors.white 
                                                    : Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // 월 선택
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '월',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: 12,
                                    itemBuilder: (context, index) {
                                      int month = index + 1;
                                      bool isSelected = month == currentMonth;
                                      bool isDisabled = currentYear == DateTime.now().year && 
                                                      month > DateTime.now().month;
                                      
                                      return GestureDetector(
                                        onTap: isDisabled ? null : () {
                                          setDialogState(() {
                                            currentMonth = month;
                                          });
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(vertical: 2),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected 
                                                ? Colors.purple.shade600 
                                                : isDisabled
                                                    ? Colors.grey.shade100
                                                    : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isSelected 
                                                  ? Colors.purple.shade600 
                                                  : isDisabled
                                                      ? Colors.grey.shade200
                                                      : Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${month}월',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                color: isSelected 
                                                    ? Colors.white 
                                                    : isDisabled
                                                        ? Colors.grey.shade400
                                                        : Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(currentYear, currentMonth, 1);
                    });
                    Navigator.of(context).pop();
                    _loadStatistics();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('선택'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 기간별 날짜 선택기 호출
  Future<void> _showDatePicker(String period) async {
    switch (period) {
      case '일간':
        await _showDailyDatePicker();
        break;
      case '주간':
        await _showWeeklyPicker();
        break;
      case '월간':
        await _showMonthlyPicker();
        break;
      case '연간':
        await _showYearlyPicker();
        break;
    }
  }

  // 연간 선택기
  Future<void> _showYearlyPicker() async {
    int currentYear = _selectedYear.year;
    int startYear = 2020;
    int endYear = DateTime.now().year;
    
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                '연도 선택',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Container(
                width: 250,
                height: 300,
                child: Column(
                  children: [
                    // 현재 선택된 연도 표시
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Text(
                        '${currentYear}년',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 연도 스크롤 리스트
                    Expanded(
                      child: ListView.builder(
                        itemCount: endYear - startYear + 1,
                        reverse: true, // 최신 연도가 위에 오도록
                        itemBuilder: (context, index) {
                          int year = endYear - index;
                          bool isSelected = year == currentYear;
                          
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                currentYear = year;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? Colors.purple.shade600 
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected 
                                      ? Colors.purple.shade600 
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${year}년',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected 
                                        ? Colors.white 
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedYear = DateTime(currentYear, 1, 1);
                    });
                    Navigator.of(context).pop();
                    _loadStatistics();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('선택'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 카테고리 차트 빌더 - 최적화된 버전
  Widget _buildCategoryChart(List<DailyStats> data) {
    // 카테고리별 시간 집계
    Map<String, int> categoryTime = {};
    for (var daily in data) {
      daily.categoryTime.forEach((category, time) {
        categoryTime[category] = (categoryTime[category] ?? 0) + time;
      });
    }
    
    // 카테고리 정리 (5% 미만은 기타로)
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              '카테고리 데이터가 없습니다',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }
    
    int totalTime = categoryTime.values.reduce((a, b) => a + b);
    
    // totalTime이 0이면 빈 데이터 표시
    if (totalTime == 0) {
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              '카테고리 데이터가 없습니다',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
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
                    return SizedBox(
                      width: 120,
                      height: 120,
                      child: CustomPaint(
                        size: const Size(120, 120),
                        painter: DonutChartPainter(
                          categoryTime: categoryTime,
                          totalTime: totalTime,
                          animationValue: _progressAnimation.value,
                          getCategoryColor: _getCategoryColor,
                        ),
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
                                _formatTime(entry.value),
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

  // 카테고리별 시간 다이얼로그
  void _showCategoryTimeDialog(BuildContext context, Map<String, int> categoryTime, String title) {
    // 카테고리별 시간을 내림차순으로 정렬
    List<MapEntry<String, int>> sortedCategories = categoryTime.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    int totalTime = categoryTime.values.fold(0, (sum, time) => sum + time);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '총 활동시간: ${_formatTime(totalTime)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(240, 240),
                        painter: DonutChartPainter(
                          categoryTime: categoryTime,
                          totalTime: totalTime,
                          animationValue: 1.0,
                          getCategoryColor: _getCategoryColor,
                        ),
                      ),
                      Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${(totalTime / 60).toStringAsFixed(1)}h',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '총 시간',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ...sortedCategories.map((entry) {
                  double percentage = (entry.value / totalTime * 100);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getCategoryColor(entry.key),
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
                          '${percentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('닫기'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
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