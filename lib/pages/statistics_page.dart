import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/hardware_service.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  
  // 통계 데이터
  int _totalStudyTime = 0; // 총 공부 시간 (분)
  int _todayStudyTime = 0; // 오늘 공부 시간 (분)
  int _weeklyGoal = 300; // 주간 목표 (분)
  int _completedTasks = 0;
  int _totalTasks = 0;
  
  // 주간 데이터 (7일)
  List<int> _weeklyData = [45, 60, 30, 90, 75, 120, 85];
  List<String> _weekDays = ['월', '화', '수', '목', '금', '토', '일'];
  
  // 카테고리별 시간
  Map<String, int> _categoryTime = {
    '프로젝트': 120,
    '운동': 60,
    '공부': 90,
    '기타': 30,
  };

  @override
  void initState() {
    super.initState();
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
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    // 실제로는 서버에서 데이터를 가져옴
    setState(() {
      _todayStudyTime = 85;
      _totalStudyTime = 1250;
      _completedTasks = 8;
      _totalTasks = 12;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          '📊 학습 통계',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadStatistics,
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 오늘의 성과 카드
            _buildTodayCard(),
            const SizedBox(height: 20),
            
            // 주간 목표 진행률
            _buildWeeklyGoalCard(),
            const SizedBox(height: 20),
            
            // 주간 활동 차트
            _buildWeeklyChart(),
            const SizedBox(height: 20),
            
            // 카테고리별 시간 분포
            _buildCategoryChart(),
            const SizedBox(height: 20),
            
            // 성취 배지
            _buildAchievementBadges(),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayCard() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '오늘의 성과',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  '${DateTime.now().month}/${DateTime.now().day}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '공부 시간',
                  '${_todayStudyTime}분',
                  Icons.timer,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildStatItem(
                  '완료 할일',
                  '$_completedTasks/$_totalTasks',
                  Icons.check_circle,
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

  Widget _buildWeeklyGoalCard() {
    double progress = _todayStudyTime / _weeklyGoal;
    
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
                '주간 목표',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${(_todayStudyTime / _weeklyGoal * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: progress * _progressAnimation.value,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade400),
                minHeight: 8,
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            '$_todayStudyTime분 / $_weeklyGoal분',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
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
                double height = (_weeklyData[index] / 120) * 160; // 최대 높이 160
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
                      _weekDays[index],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: index == 6 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    Text(
                      '${_weeklyData[index]}분',
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

  Widget _buildCategoryChart() {
    int totalTime = _categoryTime.values.reduce((a, b) => a + b);
    
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
                        _categoryTime,
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
                  children: _categoryTime.entries.map((entry) {
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

  Widget _buildAchievementBadges() {
    List<Map<String, dynamic>> achievements = [
      {
        'title': '연속 학습',
        'description': '3일 연속 목표 달성',
        'icon': Icons.local_fire_department,
        'color': Colors.orange,
        'achieved': true,
      },
      {
        'title': '완벽주의자',
        'description': '모든 할일 완료',
        'icon': Icons.star,
        'color': Colors.yellow.shade700,
        'achieved': false,
      },
      {
        'title': '시간 관리자',
        'description': '주간 목표 달성',
        'icon': Icons.schedule,
        'color': Colors.blue,
        'achieved': true,
      },
    ];

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
            '🏆 성취 배지',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: achievements.map((achievement) {
              return Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: achievement['achieved'] 
                          ? achievement['color'] 
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                      boxShadow: achievement['achieved'] ? [
                        BoxShadow(
                          color: achievement['color'].withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ] : null,
                    ),
                    child: Icon(
                      achievement['icon'],
                      color: achievement['achieved'] ? Colors.white : Colors.grey.shade500,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    achievement['title'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: achievement['achieved'] ? Colors.black : Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }).toList(),
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
    final strokeWidth = 20.0;

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