import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ThinQ/data/micro_routine.dart';
import 'package:intl/intl.dart';

class MicroRoutinePage extends StatefulWidget {
  const MicroRoutinePage({super.key});

  @override
  State<MicroRoutinePage> createState() => _MicroRoutinePageState();
}

class _MicroRoutinePageState extends State<MicroRoutinePage> {
  List<MicroRoutine> _microRoutines = [];
  List<String> _suggestedTimeSlots = [];
  bool _isLoading = true;
  String? _userId;
  int _completedToday = 0;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _loadData();
    _detectDailyPattern();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final routinesSnapshot = await FirebaseFirestore.instance
          .collection('micro_routines')
          .where('uid', isEqualTo: _userId)
          .get();

      final microRoutines = routinesSnapshot.docs
          .map((doc) => MicroRoutine.fromMap(doc.data(), doc.id))
          .toList();

      // 완료된 루틴 카운트
      _completedToday = microRoutines
          .where((routine) {
            if (routine.lastCompletedAt == null) return false;
            final lastCompleted = (routine.lastCompletedAt as Timestamp).toDate();
            final now = DateTime.now();
            return lastCompleted.year == now.year &&
                lastCompleted.month == now.month &&
                lastCompleted.day == now.day;
          })
          .length;

      setState(() {
        _microRoutines = microRoutines;
        _isLoading = false;
      });
    } catch (e) {
      print('마이크로 루틴 데이터 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _detectDailyPattern() {
    // 여기서는 시간대 감지를 간단한 예시로 구현
    // 실제 앱에서는 사용자의 일정, 알람, 위치 등을 분석하여 시간대 추천
    final now = DateTime.now();
    final hour = now.hour;

    _suggestedTimeSlots = [];

    if (hour >= 5 && hour < 9) {
      _suggestedTimeSlots.add('아침 루틴');
    }
    if (hour >= 11 && hour < 14) {
      _suggestedTimeSlots.add('점심 시간');
    }
    if (hour >= 17 && hour < 19) {
      _suggestedTimeSlots.add('저녁 시간');
    }
    if (hour >= 21 && hour < 23) {
      _suggestedTimeSlots.add('취침 전');
    }

    // 통근 시간은 실제로는 위치 정보나 일정 등을 활용해 판단
    if ((hour >= 7 && hour < 9) || (hour >= 18 && hour < 20)) {
      _suggestedTimeSlots.add('통근 시간');
    }

    // 휴식 시간은 실제로는 일정 간 갭 등을 활용해 판단
    if ((hour >= 10 && hour < 11) || (hour >= 15 && hour < 16)) {
      _suggestedTimeSlots.add('휴식 시간');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('마이크로 루틴 인젝터'),
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
                      _buildDailyProgressCard(),
                      const SizedBox(height: 24),
                      if (_suggestedTimeSlots.isNotEmpty) _buildSuggestedRoutinesSection(),
                      const SizedBox(height: 24),
                      _buildMyRoutinesSection(),
                      const SizedBox(height: 24),
                      _buildRoutineCategoriesSection(),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddMicroRoutineDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDailyProgressCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '오늘의 마이크로 루틴',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('yyyy.MM.dd').format(DateTime.now()),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildProgressItem(
                  '완료',
                  _completedToday.toString(),
                  Colors.green,
                ),
                _buildProgressItem(
                  '남음',
                  (_microRoutines.length - _completedToday).toString(),
                  Colors.orange,
                ),
                _buildProgressItem(
                  '총 시간',
                  '${_calculateTotalMinutes()}분',
                  Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _microRoutines.isEmpty
                  ? 0
                  : _completedToday / _microRoutines.length,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${_completedToday}/${_microRoutines.length} 완료',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_completedToday > 0) const SizedBox(height: 16),
            if (_completedToday > 0)
              OutlinedButton(
                onPressed: () {
                  // 소셜 공유 기능
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.share),
                    const SizedBox(width: 8),
                    const Text('오늘의 성과 공유하기'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  int _calculateTotalMinutes() {
    return _microRoutines.fold(0, (total, routine) => total + routine.duration);
  }

  Widget _buildSuggestedRoutinesSection() {
    // 현재 시간대에 적합한 루틴 필터링
    final suggestedRoutines = _microRoutines.where((routine) {
      return routine.timeSlots.any((slot) => _suggestedTimeSlots.contains(slot));
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '지금 딱 좋은 습관',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _suggestedTimeSlots.first, // 첫 번째 시간대 표시
                style: TextStyle(
                  color: Colors.blue.shade800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (suggestedRoutines.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('현재 시간대에 추천할 마이크로 루틴이 없습니다.'),
            ),
          )
        else
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: suggestedRoutines.length,
              itemBuilder: (context, index) {
                final routine = suggestedRoutines[index];
                return _buildRoutineCard(routine);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildMyRoutinesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '내 마이크로 루틴',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _microRoutines.isEmpty
            ? const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('아직 등록된 마이크로 루틴이 없습니다. 새 루틴을 추가해보세요.'),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _microRoutines.length,
                itemBuilder: (context, index) {
                  final routine = _microRoutines[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getTagColor(routine.tags.isNotEmpty ? routine.tags.first : ''),
                        child: Icon(
                          _getTagIcon(routine.tags.isNotEmpty ? routine.tags.first : ''),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(routine.title),
                      subtitle: Text('${routine.duration}분 · ${routine.tags.join(', ')}'),
                      trailing: routine.isCompleted
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (routine.hasAudio)
                                  IconButton(
                                    icon: const Icon(Icons.headphones),
                                    onPressed: () {
                                      // 오디오 재생
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.play_arrow),
                                  color: Colors.blue,
                                  onPressed: () {
                                    // 루틴 바로 실행
                                  },
                                ),
                              ],
                            ),
                      onTap: () {
                        // 루틴 상세 정보 확인
                      },
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildRoutineCard(MicroRoutine routine) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () {
            // 루틴 실행
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _getTagColor(routine.tags.isNotEmpty ? routine.tags.first : ''),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getTagIcon(routine.tags.isNotEmpty ? routine.tags.first : ''),
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${routine.duration}분',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  routine.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Row(
                  children: [
                    if (routine.hasAudio)
                      const Icon(
                        Icons.headphones,
                        size: 16,
                        color: Colors.grey,
                      ),
                    if (routine.hasWidget)
                      Padding(
                        padding: EdgeInsets.only(left: routine.hasAudio ? 4 : 0),
                        child: const Icon(
                          Icons.widgets,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '바로 실행',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getTagColor(String tag) {
    switch (tag.toLowerCase()) {
      case '독서':
        return Colors.amber;
      case '스트레칭':
        return Colors.green;
      case '명상':
        return Colors.purple;
      case '학습':
        return Colors.blue;
      case '취미':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getTagIcon(String tag) {
    switch (tag.toLowerCase()) {
      case '독서':
        return Icons.book;
      case '스트레칭':
        return Icons.fitness_center;
      case '명상':
        return Icons.self_improvement;
      case '학습':
        return Icons.school;
      case '취미':
        return Icons.palette;
      default:
        return Icons.category;
    }
  }

  Widget _buildRoutineCategoriesSection() {
    final categories = [
      {'name': '독서', 'icon': Icons.book},
      {'name': '스트레칭', 'icon': Icons.fitness_center},
      {'name': '명상', 'icon': Icons.self_improvement},
      {'name': '학습', 'icon': Icons.school},
      {'name': '취미', 'icon': Icons.palette},
      {'name': '기타', 'icon': Icons.more_horiz},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '습관 카테고리',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () {
                  // 카테고리별 루틴 목록 보기
                },
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      category['icon'] as IconData,
                      color: _getTagColor(category['name'] as String),
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      category['name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showAddMicroRoutineDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final durationController = TextEditingController(text: '5');
    final selectedTags = <String>[];
    final selectedTimeSlots = <String>[];
    bool hasAudio = false;
    bool hasWidget = false;

    final allTags = ['독서', '스트레칭', '명상', '학습', '취미', '기타'];
    final allTimeSlots = ['아침 루틴', '통근 시간', '점심 시간', '휴식 시간', '저녁 시간', '취침 전'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('새 마이크로 루틴 추가'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: '루틴 이름',
                      ),
                    ),
                    TextField(
                      controller: descriptionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: '설명',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: durationController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '소요 시간(분)',
                              hintText: '5-10분',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: hasAudio,
                                  onChanged: (value) {
                                    setState(() {
                                      hasAudio = value!;
                                    });
                                  },
                                ),
                                const Text('오디오'),
                              ],
                            ),
                            Row(
                              children: [
                                Checkbox(
                                  value: hasWidget,
                                  onChanged: (value) {
                                    setState(() {
                                      hasWidget = value!;
                                    });
                                  },
                                ),
                                const Text('위젯'),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('태그 선택'),
                    Wrap(
                      spacing: 8,
                      children: allTags.map((tag) {
                        final isSelected = selectedTags.contains(tag);
                        return FilterChip(
                          label: Text(tag),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                selectedTags.add(tag);
                              } else {
                                selectedTags.remove(tag);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('추천 시간대 선택'),
                    Wrap(
                      spacing: 8,
                      children: allTimeSlots.map((slot) {
                        final isSelected = selectedTimeSlots.contains(slot);
                        return FilterChip(
                          label: Text(slot),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                selectedTimeSlots.add(slot);
                              } else {
                                selectedTimeSlots.remove(slot);
                              }
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
                    // 마이크로 루틴 추가 로직
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