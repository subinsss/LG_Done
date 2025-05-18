import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ThinQ/data/task.dart';
import 'package:ThinQ/pages/community_page.dart';
import 'package:ThinQ/pages/feed_page.dart';
import 'package:ThinQ/pages/stats_page.dart';
import 'package:ThinQ/pages/routine_booster_page.dart';
import 'package:ThinQ/pages/life_tree_page.dart';
import 'package:ThinQ/pages/micro_routine_page.dart';
import 'package:ThinQ/pages/learning_hub_page.dart';

class TimerPage extends StatefulWidget {
  final Task? selectedTask;
  
  const TimerPage({super.key, this.selectedTask});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> with WidgetsBindingObserver {
  // 타이머 관련 변수
  int _duration = 25 * 60; // 초 단위로 25분
  int _initialDuration = 25 * 60; // 초기 설정 시간
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;
  Timer? _timer;
  int _completedSessions = 0;
  int _targetSessions = 4; // 목표 세션 수
  bool _isBreakTime = false;
  List<Task> _tasks = [];
  Task? _currentTask;
  List<int> _presetMinutes = [15, 25, 45, 60];
  int _currentIndex = 1; // 관리 탭 (타이머) 선택 상태
  int _totalMinutes = 0;
  bool _isPremium = false;
  
  // 서비스 목록 정의
  final List<Map<String, dynamic>> _services = [
    {
      'title': '루틴 부스터',
      'description': '날씨·일정 데이터를 연동해 루틴 실패 가능성을 사전에 알려주고, 대안 루틴을 제안합니다.',
      'icon': Icons.trending_up,
      'color': Colors.blue,
      'page': const RoutineBoosterPage(),
    },
    {
      'title': '매크로 라이프 트리',
      'description': '1/3/12 개월 단위 로드맵을 시각화하고 작은 성취를 타임라인에 적립합니다.',
      'icon': Icons.account_tree,
      'color': Colors.green,
      'page': const LifeTreePage(),
    },
    {
      'title': '마이크로 루틴 인젝터',
      'description': '사용자의 하루 패턴을 감지해 5‑10분짜리 습관 슬롯을 추천합니다.',
      'icon': Icons.timer,
      'color': Colors.orange,
      'page': const MicroRoutinePage(),
    },
    {
      'title': 'AI‑큐레이션 학습 허브',
      'description': '나와 유사한 목표를 가진 사람들과 함께하는 소규모 챌린지와 학습 자료를 제공합니다.',
      'icon': Icons.school,
      'color': Colors.purple,
      'page': const LearningHubPage(),
    },
  ];
  
  // 선택된 서비스 인덱스
  int _selectedServiceIndex = 0;
  bool _isServicesView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTasks();
    _currentTask = widget.selectedTask;
    if (_currentTask != null) {
      _duration = _currentTask!.duration * 60;
      _initialDuration = _duration;
      _remainingSeconds = _duration;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // 앱이 백그라운드로 갈 때 시간 저장
      _pauseTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F2F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isServicesView ? _services[_selectedServiceIndex]['title'] : '포모도로',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: _isServicesView 
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () {
                  setState(() {
                    _isServicesView = false;
                  });
                },
              )
            : null,
      ),
      body: _isServicesView 
          ? _services[_selectedServiceIndex]['page']
          : _buildServicesList(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (_isServicesView) {
            setState(() {
              _isServicesView = false;
            });
          }
          
          if (index != _currentIndex) {
            switch (index) {
              case 0: // 내역 페이지
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => FeedPage()),
                );
                break;
              case 1: // 현재 페이지(관리)
                // 이미 이 페이지에 있으므로 아무 동작 없음
                break;
              case 2: // 커뮤니티 페이지
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => CommunityPage()),
                );
                break;
              case 3: // 통계 페이지
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => StatsPage()),
                );
                break;
            }
          }
        },
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: '내역',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.manage_accounts),
            label: '관리',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: '커뮤니티',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: '통계',
          ),
        ],
      ),
    );
  }

  Widget _buildServicesList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(
                '오늘의 집중 시간',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
            ],
          ),
        ),
        _buildTimerCard(),
        SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '서비스',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: _services.length,
              itemBuilder: (context, index) {
                return _buildServiceCard(index);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard(int index) {
    final service = _services[index];
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedServiceIndex = index;
          _isServicesView = true;
        });
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: service['color'].withOpacity(0.2),
                child: Icon(
                  service['icon'],
                  color: service['color'],
                  size: 26,
                ),
              ),
              SizedBox(height: 12),
              Text(
                service['title'],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Expanded(
                child: Text(
                  service['description'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerCard() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    
    final progress = _isRunning || _remainingSeconds < _initialDuration
        ? 1 - (_remainingSeconds / _initialDuration)
        : 0.0;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isBreakTime ? '휴식 시간' : '집중 시간',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _isBreakTime ? Colors.green : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isBreakTime ? Colors.green : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: _isBreakTime ? Colors.green : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    if (_currentTask != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _currentTask!.title,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTimerButton(
                  icon: Icons.refresh,
                  onPressed: _resetTimer,
                  backgroundColor: Colors.amber,
                ),
                _buildTimerButton(
                  icon: _isRunning ? Icons.pause : Icons.play_arrow,
                  onPressed: _isRunning ? _pauseTimer : _startTimer,
                  backgroundColor: _isRunning 
                      ? Colors.orange
                      : _isBreakTime ? Colors.green : Theme.of(context).colorScheme.primary,
                  iconSize: 36,
                  buttonSize: 72,
                ),
                _buildTimerButton(
                  icon: Icons.skip_next,
                  onPressed: _skipTimer,
                  backgroundColor: Colors.grey.shade600,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _completedSessions / _targetSessions,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.amber,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '완료한 세션: $_completedSessions / $_targetSessions',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    double iconSize = 24,
    double buttonSize = 48,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        onPressed();
      },
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 2,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }

  Widget _buildTaskSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Task>(
          isExpanded: true,
          value: _currentTask,
          hint: Text('작업 선택하기'),
          icon: Icon(Icons.arrow_drop_down),
          items: _tasks.map((Task task) {
            return DropdownMenuItem<Task>(
              value: task,
              child: Text(
                task.title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: _currentTask == task ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
          onChanged: (Task? task) {
            if (task != null && !_isRunning) {
              setState(() {
                _currentTask = task;
                _duration = task.duration * 60;
                _initialDuration = _duration;
                _remainingSeconds = _duration;
              });
              HapticFeedback.selectionClick();
            } else if (_isRunning) {
              // 타이머 작동 중에는 작업 변경 불가
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('타이머 작동 중에는 작업을 변경할 수 없습니다.')),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildPresetButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '빠른 시간 설정',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _presetMinutes.map((minutes) {
              final isSelected = _initialDuration == minutes * 60 && !_isRunning;
              return InkWell(
                onTap: _isRunning 
                    ? null
                    : () {
                        setState(() {
                          _duration = minutes * 60;
                          _initialDuration = _duration;
                          _remainingSeconds = _duration;
                        });
                        HapticFeedback.selectionClick();
                      },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Theme.of(context).colorScheme.primary
                        : _isRunning ? Colors.grey.shade300 : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    '$minutes분',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _startTimer() {
    setState(() {
      _isRunning = true;
    });

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
          _isRunning = false;
          _onTimerComplete();
        }
      });
    });
  }

  void _pauseTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() {
        _isRunning = false;
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _initialDuration;
    });
  }

  void _skipTimer() {
    _timer?.cancel();
    _onTimerComplete();
  }

  void _onTimerComplete() {
    HapticFeedback.heavyImpact();
    
    // 타이머 완료 음향 재생
    if (_isBreakTime) {
      // 휴식 시간 종료
      setState(() {
        _isBreakTime = false;
        _remainingSeconds = _initialDuration;
      });
    } else {
      // 집중 시간 종료
      setState(() {
        _completedSessions++;
        
        if (_completedSessions < _targetSessions) {
          // 휴식 시간 시작
          _isBreakTime = true;
          _remainingSeconds = 5 * 60; // 5분 휴식
        } else {
          // 목표 세션 달성 시 작업 완료 처리
          _isBreakTime = false;
          _remainingSeconds = _initialDuration;
          _completedSessions = 0;
          _markTaskAsCompleted();
          _showCompletionDialog();
        }
      });
    }
  }

  void _markTaskAsCompleted() async {
    if (_currentTask != null && !_currentTask!.isCompleted) {
      try {
        await FirebaseFirestore.instance
            .collection('tasks')
            .doc(_currentTask!.id)
            .update({'isCompleted': true});
        
        // 분석 이벤트 전송
        await FirebaseAnalytics.instance.logEvent(
          name: 'task_completed_timer',
          parameters: {
            'task_id': _currentTask!.id,
            'duration': _currentTask!.duration,
          },
        );
      } catch (e) {
        print('작업 완료 처리 오류: $e');
      }
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('축하합니다!'),
        content: Column(
          children: [
            SizedBox(height: 16),
            Icon(
              Icons.celebration,
              size: 48,
              color: Colors.amber,
            ),
            SizedBox(height: 16),
            Text(
              '${_targetSessions}개의 세션을 모두 완료했습니다!',
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            if (_currentTask != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('총 ${_initialDuration ~/ 60}분 동안 ${_currentTask!.title}에 집중했습니다.'),
              ),
          ],
        ),
        actions: [
          CupertinoButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTasks() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final snapshot = await FirebaseFirestore.instance
          .collection("tasks")
          .where("uid", isEqualTo: user.uid)
          .where("isCompleted", isEqualTo: false)
          .orderBy("createdAt", descending: true)
          .get();
          
      final documents = snapshot.docs;

      List<Task> tasks = [];

      for (final doc in documents) {
        final data = doc.data();
        final id = doc.id;
        final uid = data['uid'];
        final title = data['title'];
        final description = data['description'] ?? '';
        final int duration = (data['duration'] is int) ? data['duration'] : ((data['duration'] ?? 0) as num).toInt();
        final isCompleted = data['isCompleted'] ?? false;
        final createdAt = data['createdAt'];
        
        tasks.add(
          Task(
            id: id,
            uid: uid,
            title: title,
            description: description,
            duration: duration,
            isCompleted: isCompleted,
            createdAt: createdAt,
          ),
        );
      }

      setState(() {
        _tasks = tasks;
      });
    } catch (e) {
      print('태스크 로딩 오류: $e');
    }
  }
} 