import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ThinQ/data/goal.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class LifeTreePage extends StatefulWidget {
  const LifeTreePage({super.key});

  @override
  State<LifeTreePage> createState() => _LifeTreePageState();
}

class _LifeTreePageState extends State<LifeTreePage> with SingleTickerProviderStateMixin {
  List<Goal> _goals = [];
  bool _isLoading = true;
  String? _userId;
  late TabController _tabController;
  int _selectedTabIndex = 0;

  // 감정/집중도/피로도 데이터
  final Map<String, List<FlSpot>> _emotionData = {
    '행복': List.generate(7, (i) => FlSpot(i.toDouble(), (4 * (i % 3 + 1)).toDouble())),
    '집중': List.generate(7, (i) => FlSpot(i.toDouble(), (3 * (i % 4 + 2)).toDouble())),
    '피로': List.generate(7, (i) => FlSpot(i.toDouble(), (2 * ((7 - i) % 3 + 1)).toDouble())),
  };

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
    _loadGoals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final goalsSnapshot = await FirebaseFirestore.instance
          .collection('goals')
          .where('uid', isEqualTo: _userId)
          .get();

      final goals = goalsSnapshot.docs
          .map((doc) => Goal.fromMap(doc.data(), doc.id))
          .toList();

      setState(() {
        _goals = goals;
        _isLoading = false;
      });
    } catch (e) {
      print('목표 데이터 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('매크로 라이프 트리'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: '1개월'),
            Tab(text: '3개월'),
            Tab(text: '12개월'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGoalView(GoalTimeframe.SHORT),
                _buildGoalView(GoalTimeframe.MEDIUM),
                _buildGoalView(GoalTimeframe.LONG),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddGoalDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGoalView(GoalTimeframe timeframe) {
    final filteredGoals = _goals.where((goal) => goal.timeframe == timeframe).toList();

    if (filteredGoals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.map,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              '아직 등록된 목표가 없습니다.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                _showAddGoalDialog();
              },
              child: const Text('새 목표 추가하기'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTimelineHeader(timeframe),
        const SizedBox(height: 24),
        ...filteredGoals.map((goal) => _buildGoalCard(goal)).toList(),
        const SizedBox(height: 16),
        _buildEmotionChart(),
      ],
    );
  }

  Widget _buildTimelineHeader(GoalTimeframe timeframe) {
    final now = DateTime.now();
    String periodText;
    DateTime endDate;

    switch (timeframe) {
      case GoalTimeframe.SHORT:
        endDate = DateTime(now.year, now.month + 1, now.day);
        periodText = '1개월 로드맵';
        break;
      case GoalTimeframe.MEDIUM:
        endDate = DateTime(now.year, now.month + 3, now.day);
        periodText = '3개월 로드맵';
        break;
      case GoalTimeframe.LONG:
        endDate = DateTime(now.year + 1, now.month, now.day);
        periodText = '12개월 로드맵';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          periodText,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${DateFormat('yyyy.MM.dd').format(now)} ~ ${DateFormat('yyyy.MM.dd').format(endDate)}',
          style: TextStyle(
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: 0.3, // 예시 값
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('MM/dd').format(now),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            Text(
              DateFormat('MM/dd').format(endDate),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGoalCard(Goal goal) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: goal.isCompleted
                        ? Colors.green
                        : Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    goal.isCompleted ? '완료' : '${goal.progress}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(goal.description),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: goal.progress / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                goal.isCompleted ? Colors.green : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '기간: ${DateFormat('yy.MM.dd').format(goal.startDate)} ~ ${DateFormat('yy.MM.dd').format(goal.endDate)}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.checklist,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '하위 목표: ${goal.subGoalIds.length}개',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (goal.achievementBadges.isNotEmpty) const SizedBox(height: 16),
            if (goal.achievementBadges.isNotEmpty)
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    size: 16,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '획득한 배지: ${goal.achievementBadges.length}개',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // 하위 목표 관리
                  },
                  child: const Text('하위 목표 관리'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    // 목표 세부 정보 확인
                  },
                  child: const Text('자세히 보기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionChart() {
    final titles = ['감정', '집중도', '피로도'];
    final colors = [Colors.green, Colors.blue, Colors.red];
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '주간 상태 그래프',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text('지난 7일간의 상태 변화를 확인하세요.'),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) return const Text('');
                          
                          final weekday = DateTime.now().subtract(
                            Duration(days: (6 - value.toInt())),
                          ).weekday;
                          
                          // 요일을 한글로 변환
                          final days = ['', '월', '화', '수', '목', '금', '토', '일'];
                          return Text(
                            days[weekday],
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value % 2 != 0) return const Text('');
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _emotionData['행복']!,
                      isCurved: true,
                      color: colors[0],
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: colors[0].withOpacity(0.1),
                      ),
                    ),
                    LineChartBarData(
                      spots: _emotionData['집중']!,
                      isCurved: true,
                      color: colors[1],
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: colors[1].withOpacity(0.1),
                      ),
                    ),
                    LineChartBarData(
                      spots: _emotionData['피로']!,
                      isCurved: true,
                      color: colors[2],
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: colors[2].withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors[index],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(titles[index]),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddGoalDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    GoalTimeframe selectedTimeframe = GoalTimeframe.values[_selectedTabIndex];
    DateTime startDate = DateTime.now();
    DateTime endDate;

    // 기본 종료일 계산
    switch (selectedTimeframe) {
      case GoalTimeframe.SHORT:
        endDate = DateTime(startDate.year, startDate.month + 1, startDate.day);
        break;
      case GoalTimeframe.MEDIUM:
        endDate = DateTime(startDate.year, startDate.month + 3, startDate.day);
        break;
      case GoalTimeframe.LONG:
        endDate = DateTime(startDate.year + 1, startDate.month, startDate.day);
        break;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('새 목표 추가'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: '목표 제목',
                      ),
                    ),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '목표 설명',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<GoalTimeframe>(
                      value: selectedTimeframe,
                      decoration: const InputDecoration(
                        labelText: '목표 기간',
                      ),
                      items: GoalTimeframe.values
                          .map((timeframe) => DropdownMenuItem<GoalTimeframe>(
                                value: timeframe,
                                child: Text(
                                  timeframe == GoalTimeframe.SHORT
                                      ? '1개월'
                                      : timeframe == GoalTimeframe.MEDIUM
                                          ? '3개월'
                                          : '12개월',
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedTimeframe = value!;
                          // 기간에 따라 종료일 업데이트
                          switch (selectedTimeframe) {
                            case GoalTimeframe.SHORT:
                              endDate = DateTime(startDate.year, startDate.month + 1, startDate.day);
                              break;
                            case GoalTimeframe.MEDIUM:
                              endDate = DateTime(startDate.year, startDate.month + 3, startDate.day);
                              break;
                            case GoalTimeframe.LONG:
                              endDate = DateTime(startDate.year + 1, startDate.month, startDate.day);
                              break;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('시작일'),
                      subtitle: Text(DateFormat('yyyy.MM.dd').format(startDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final selectedDate = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (selectedDate != null) {
                          setState(() {
                            startDate = selectedDate;
                            // 종료일도 함께 업데이트
                            switch (selectedTimeframe) {
                              case GoalTimeframe.SHORT:
                                endDate = DateTime(startDate.year, startDate.month + 1, startDate.day);
                                break;
                              case GoalTimeframe.MEDIUM:
                                endDate = DateTime(startDate.year, startDate.month + 3, startDate.day);
                                break;
                              case GoalTimeframe.LONG:
                                endDate = DateTime(startDate.year + 1, startDate.month, startDate.day);
                                break;
                            }
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('종료일'),
                      subtitle: Text(DateFormat('yyyy.MM.dd').format(endDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final selectedDate = await showDatePicker(
                          context: context,
                          initialDate: endDate,
                          firstDate: startDate,
                          lastDate: DateTime(2100),
                        );
                        if (selectedDate != null) {
                          setState(() {
                            endDate = selectedDate;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    // 목표 추가 로직 구현
                    Navigator.pop(context);
                  },
                  child: const Text('추가'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}