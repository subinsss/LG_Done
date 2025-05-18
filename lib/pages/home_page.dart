import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ThinQ/data/post.dart';
import 'package:ThinQ/data/task.dart';
import 'package:ThinQ/pages/community_page.dart';
import 'package:ThinQ/pages/login_page.dart';
import 'package:ThinQ/pages/setting_page.dart';
import 'package:ThinQ/pages/stats_page.dart';
import 'package:ThinQ/pages/feed_page.dart';
import 'package:ThinQ/pages/routine_booster_page.dart';
import 'package:ThinQ/pages/life_tree_page.dart';
import 'package:ThinQ/pages/micro_routine_page.dart';
import 'package:ThinQ/pages/learning_hub_page.dart';
import 'package:ThinQ/widgets/post_widget.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Task> _tasks = [];
  List<String?> _activeUsers = [];
  int _currentIndex = 1; // 관리 탭 선택 상태
  int _totalMinutes = 0;
  bool _isPremium = false;
  bool _isLoading = true;
  
  // 선택된 서비스 인덱스
  int _selectedServiceIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // 데이터 초기화 및 로드를 위한 메서드
  Future<void> _initializeData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 데이터 로딩 작업을 병렬로 처리
      await Future.wait([
        _loadTasks(),
        _loadUserStatus(),
      ]);
      
      // 스트림 리스너 설정
      _setupActiveUsersListener();
      
      // 로딩 완료
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      // 공지사항은 별도로 로드 (UI를 차단하지 않음)
      _loadNotice();
    } catch (e) {
      print('데이터 로드 중 오류 발생: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: const Color(0xFFF1F2F3),
      body: _isLoading 
          ? _buildLoadingView() 
          : _buildServicesPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index != _currentIndex) {
            switch (index) {
              case 0: // 내역 페이지
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => FeedPage()),
                  (route) => false,
                );
                break;
              case 1: // 관리 (현재 페이지)
                break;
              case 2: // 커뮤니티 페이지
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => CommunityPage()),
                  (route) => false,
                );
                break;
              case 3: // 통계 페이지
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => StatsPage()),
                  (route) => false,
                );
                break;
            }
          }
        },
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
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

  Widget _buildServicesPage() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
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
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('${_totalMinutes ~/ 60}분', '총 시간', primaryColor),
                _buildStatItem('${_tasks.where((t) => t.isCompleted).length}개', '완료한 작업', primaryColor),
                _buildStatItem('${_tasks.where((t) => !t.isCompleted).length}개', '진행 중', primaryColor),
              ],
            ),
          ),
        ),
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
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
              children: [
                _buildServiceItem('루틴 부스터', Icons.trending_up, Colors.blue, () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => RoutineBoosterPage())
                  );
                }),
                _buildServiceItem('매크로 라이프 트리', Icons.account_tree, Colors.green, () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => LifeTreePage())
                  );
                }),
                _buildServiceItem('마이크로 루틴 인젝터', Icons.timer, Colors.orange, () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => MicroRoutinePage())
                  );
                }),
                _buildServiceItem('AI‑큐레이션 학습 허브', Icons.school, Colors.purple, () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => LearningHubPage())
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  // 통계 항목 위젯
  Widget _buildStatItem(String value, String label, Color primaryColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildServiceItem(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
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
                backgroundColor: color.withOpacity(0.2),
                child: Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 로딩 화면 위젯
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            '데이터를 불러오는 중입니다...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // 활동 중인 사용자 목록을 위한 리스너 설정
  void _setupActiveUsersListener() {
    FirebaseDatabase.instance.ref().child('active_users').onValue.listen(
      (event) {
        if (mounted) {
          setState(() {
            _activeUsers = event.snapshot.value == null
                ? []
                : List<String?>.from(
                    event.snapshot.value as List<dynamic>,
                  );
          });
        }
      },
    );
  }

  // 사용자 태스크 로드 함수
  Future<void> _loadTasks() async {
    try {
      // FirebaseFirestore로부터 데이터를 받아옵니다.
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final snapshot = await FirebaseFirestore.instance
          .collection("tasks")
          .where("uid", isEqualTo: user.uid)
          .orderBy("createdAt", descending: true)
          .get();
          
      final documents = snapshot.docs;

      // FirebaseFirestore로부터 받아온 데이터를 Task 객체로 변환합니다.
      List<Task> tasks = [];
      int totalMinutes = 0;

      for (final doc in documents) {
        final data = doc.data();
        final id = doc.id;
        final uid = data['uid'];
        final title = data['title'];
        final description = data['description'] ?? '';
        final int duration = (data['duration'] is int) ? data['duration'] : ((data['duration'] ?? 0) as num).toInt();
        final isCompleted = data['isCompleted'] ?? false;
        final createdAt = data['createdAt'];
        
        if (isCompleted) {
          totalMinutes += duration;
        }
        
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

      // Task 객체를 이용하여 화면을 다시 그립니다.
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _totalMinutes = totalMinutes;
        });
      }
    } catch (e) {
      print('태스크 로딩 오류: $e');
    }
  }

  AppBar _buildAppBar() {
    final showPremiumBadge = _isPremium;
    final currentUser = FirebaseAuth.instance.currentUser;
    final username = currentUser?.displayName ?? '사용자';

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Text(
        'ThinQ',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      centerTitle: true,
      actions: [
        if (showPremiumBadge) 
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'PREMIUM',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        IconButton(
          icon: Icon(
            Icons.settings,
            color: Colors.black87,
          ),
          onPressed: () {
            // 설정 페이지로 이동
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) {
                  return const SettingPage();
                },
              ),
            );
          },
        ),
      ],
    );
  }

  // 사용자 상태 정보 로드 (프리미엄 여부 등)
  Future<void> _loadUserStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && mounted) {
          setState(() {
            _isPremium = data['isPremium'] ?? false;
          });
        }
      }
    } catch (e) {
      print('사용자 상태 로딩 오류: $e');
    }
  }

  // 공지사항을 받아옵니다.
  Future<void> _loadNotice() async {
    final notice = FirebaseRemoteConfig.instance.getString('notice');
    if (notice.isEmpty || !mounted) {
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('공지사항'),
          content: Container(
            margin: const EdgeInsets.only(top: 10),
            child: Text(notice),
          ),
          actions: [
            CupertinoButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                '확인',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  @override
  void dispose() {
    super.dispose();
  }
} 