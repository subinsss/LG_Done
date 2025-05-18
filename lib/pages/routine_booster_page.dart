import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ThinQ/data/routine.dart';
import 'package:ThinQ/data/weather_calendar.dart';
import 'package:ThinQ/data/reward.dart' as reward;
import 'package:intl/intl.dart';

class RoutineBoosterPage extends StatefulWidget {
  const RoutineBoosterPage({super.key});

  @override
  State<RoutineBoosterPage> createState() => _RoutineBoosterPageState();
}

class _RoutineBoosterPageState extends State<RoutineBoosterPage> {
  List<Routine> _routines = [];
  List<RoutineWarning> _warnings = [];
  List<reward.Badge> _badges = [];
  int _userMileage = 0;
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 루틴 목록 가져오기
      final routinesSnapshot = await FirebaseFirestore.instance
          .collection('routines')
          .where('uid', isEqualTo: _userId)
          .get();

      final routines = routinesSnapshot.docs
          .map((doc) => Routine.fromMap(doc.data(), doc.id))
          .toList();

      // 경고 메시지 가져오기
      final warningsSnapshot = await FirebaseFirestore.instance
          .collection('routine_warnings')
          .where('uid', isEqualTo: _userId)
          .where('isResolved', isEqualTo: false)
          .get();

      final warnings = warningsSnapshot.docs
          .map((doc) => RoutineWarning.fromMap(doc.data(), doc.id))
          .toList();

      // 획득한 배지 목록 가져오기
      final userRewardSnapshot = await FirebaseFirestore.instance
          .collection('user_rewards')
          .where('uid', isEqualTo: _userId)
          .get();
      
      if (userRewardSnapshot.docs.isNotEmpty) {
        final userReward = reward.UserReward.fromMap(
            userRewardSnapshot.docs.first.data(), userRewardSnapshot.docs.first.id);
        _userMileage = userReward.mileage;

        // 배지 상세 정보 가져오기
        if (userReward.badgeIds.isNotEmpty) {
          final badgesSnapshot = await FirebaseFirestore.instance
              .collection('badges')
              .where(FieldPath.documentId, whereIn: userReward.badgeIds)
              .get();

          _badges = badgesSnapshot.docs
              .map((doc) => reward.Badge.fromMap(doc.data(), doc.id))
              .toList();
        }
      }

      setState(() {
        _routines = routines;
        _warnings = warnings;
        _isLoading = false;
      });
    } catch (e) {
      print('데이터 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('루틴 부스터'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMileageCard(),
                      const SizedBox(height: 16),
                      _buildWarningsSection(),
                      const SizedBox(height: 24),
                      _buildRoutinesSection(),
                      const SizedBox(height: 24),
                      if (_badges.isNotEmpty) _buildBadgesSection(),
                      const SizedBox(height: 24),
                      _buildMiniChallengeSection(),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 새 루틴 추가 페이지로 이동
          _showAddRoutineDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMileageCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade800, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
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
                '루틴 마일리지',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_userMileage 점',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '연속 달성: ${_calculateLongestStreak()} 일',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '완료한 루틴: ${_routines.where((r) => r.isCompleted).length} / ${_routines.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  int _calculateLongestStreak() {
    // 가장 긴 연속 달성 일수 계산 (간단한 예시)
    return _routines.isEmpty
        ? 0
        : _routines.map((r) => r.streakCount).reduce((a, b) => a > b ? a : b);
  }

  Widget _buildWarningsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '루틴 위험 알림',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _warnings.isEmpty
            ? const Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('현재 알림이 없습니다. 모든 루틴이 정상적으로 진행될 예정입니다.'),
                ),
              )
            : Column(
                children: _warnings.map((warning) {
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                warning.warningType == '날씨'
                                    ? Icons.wb_cloudy
                                    : Icons.calendar_today,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _getRoutineTitle(warning.routineId),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                DateFormat('MM/dd').format(warning.date),
                                style: const TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(warning.description),
                          const SizedBox(height: 8),
                          if (warning.alternativeRoutineId != null)
                            OutlinedButton(
                              onPressed: () {
                                // 대체 루틴으로 전환 기능
                              },
                              child: const Text('대체 루틴으로 전환'),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }

  String _getRoutineTitle(String routineId) {
    final routine = _routines.firstWhere(
      (r) => r.id == routineId,
      orElse: () => Routine(
        id: '',
        uid: '',
        title: '알 수 없는 루틴',
        description: '',
        category: '',
        duration: 0,
        weekdays: [],
        timeOfDay: DateTime.now(),
        isCompleted: false,
        streakCount: 0,
        createdAt: null,
      ),
    );
    return routine.title;
  }

  Widget _buildRoutinesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '내 루틴',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _routines.isEmpty
            ? const Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('아직 등록된 루틴이 없습니다. 새 루틴을 추가해보세요.'),
                ),
              )
            : Column(
                children: _routines.map((routine) {
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getCategoryColor(routine.category),
                        child: Icon(
                          _getCategoryIcon(routine.category),
                          color: Colors.white,
                        ),
                      ),
                      title: Text(routine.title),
                      subtitle: Text('${routine.duration}분 · ${routine.weekdays.join(', ')}'),
                      trailing: routine.isCompleted
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            )
                          : IconButton(
                              icon: const Icon(Icons.play_circle_filled),
                              color: Colors.blue,
                              onPressed: () {
                                // 루틴 시작 기능
                              },
                            ),
                      onTap: () {
                        // 루틴 상세 페이지로 이동
                      },
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case '운동':
        return Colors.orange;
      case '학습':
        return Colors.blue;
      case '명상':
        return Colors.purple;
      case '독서':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case '운동':
        return Icons.fitness_center;
      case '학습':
        return Icons.school;
      case '명상':
        return Icons.self_improvement;
      case '독서':
        return Icons.book;
      default:
        return Icons.schedule;
    }
  }

  Widget _buildBadgesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '획득한 배지',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _badges.length,
            itemBuilder: (context, index) {
              final badge = _badges[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: badge.isRare ? Colors.amber : Colors.blueGrey,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: badge.imageUrl.isEmpty
                            ? Text(
                                badge.title.substring(0, 1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                ),
                              )
                            : ClipOval(
                                child: Image.network(
                                  badge.imageUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      badge.title,
                      style: const TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMiniChallengeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '미니 챌린지',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 4,
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
                    const Text(
                      '일주일 연속 달성',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '+50 마일리지',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('7일 연속으로 루틴을 모두 완료하면 보상을 받을 수 있습니다.'),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: 0.42, // 예시 값
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                ),
                const SizedBox(height: 8),
                const Text(
                  '3/7일 완료',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddRoutineDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final durationController = TextEditingController();
    String selectedCategory = '운동';
    final List<bool> selectedWeekdays = List.filled(7, false);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('새 루틴 추가'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: '루틴 이름',
                      ),
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: '설명',
                      ),
                    ),
                    TextField(
                      controller: durationController,
                      decoration: const InputDecoration(
                        labelText: '소요 시간 (분)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: '카테고리',
                      ),
                      items: ['운동', '학습', '명상', '독서', '기타']
                          .map((category) => DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('요일 선택'),
                    Wrap(
                      spacing: 8,
                      children: [
                        '월', '화', '수', '목', '금', '토', '일'
                      ].asMap().entries.map((entry) {
                        final index = entry.key;
                        final day = entry.value;
                        return FilterChip(
                          label: Text(day),
                          selected: selectedWeekdays[index],
                          onSelected: (selected) {
                            setState(() {
                              selectedWeekdays[index] = selected;
                            });
                          },
                        );
                      }).toList(),
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
                    // 새 루틴 추가 로직
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