import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ThinQ/data/task.dart';
import 'package:ThinQ/data/post.dart';
import 'package:ThinQ/pages/login_page.dart';
import 'package:ThinQ/pages/routine_booster_page.dart';
import 'package:ThinQ/pages/life_tree_page.dart';
import 'package:ThinQ/pages/micro_routine_page.dart';
import 'package:ThinQ/pages/learning_hub_page.dart';
import 'package:ThinQ/pages/setting_page.dart';
import 'package:ThinQ/pages/stats_page.dart';
import 'package:ThinQ/pages/community_page.dart';
import 'package:ThinQ/pages/home_page.dart';
import 'package:ThinQ/pages/write_page.dart';
import 'package:ThinQ/widgets/post_widget.dart';

class FeedPage extends StatefulWidget {
  final int initialTab;

  const FeedPage({super.key, this.initialTab = 0});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  List<Task> _tasks = [];
  List<Post> _posts = [];
  List<String?> _activeUsers = [];
  late int _currentIndex;
  int _totalMinutes = 0;
  bool _isPremium = false;
  bool _isLoading = true;
  bool _isServicesView = false;
  

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
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _initializeData();
  }
  
  // 데이터 초기화 및 로드를 위한 메서드
  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 데이터 로딩 작업을 병렬로 처리
      await Future.wait([
        _loadTasks(),
        _loadPosts(),
        _loadUserStatus(),
      ]);
      
      // 스트림 리스너 설정
      _setupActiveUsersListener();
      
      // 로딩 완료
      setState(() {
        _isLoading = false;
      });
      
      // 공지사항은 별도로 로드 (UI를 차단하지 않음)
      _loadNotice();
    } catch (e) {
      print('데이터 로드 중 오류 발생: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: const Color(0xFFF1F2F3),
      body: _isLoading 
          ? _buildLoadingView() 
          : _getPage(),
      floatingActionButton: _currentIndex == 0 ? _buildFloatingActionButton() : null,
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }
  
  // 현재 상태에 따라 적절한 페이지 반환
  Widget _getPage() {
    if (_isServicesView) {
      // 서비스 상세 페이지 표시
      return _services[_selectedServiceIndex]['page'];
    }

    switch (_currentIndex) {
      case 0: // 내역 탭 (피드 페이지)
        return RefreshIndicator(
          onRefresh: _loadPosts,
          child: SafeArea(
            bottom: false,
            child: CupertinoScrollbar(
              child: Column(
                children: [
                  // 활동 통계 카드
                  _buildActiveUsers(),
                  
                  // 피드 컨텐츠
                  Expanded(
                    child: _posts.isEmpty
                        ? _buildEmptyFeed()
                        : ListView.builder(
                            itemCount: _posts.length,
                            itemBuilder: (context, index) {
                              return PostWidget(
                                item: _posts[index],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      case 1: // 관리 탭 - HomePage로 이동
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomePage()),
          );
        });
        return Container();
      case 2: // 커뮤니티 탭
        return CommunityPage();
      case 3: // 통계 탭
        return StatsPage();
      default:
        return Container();
    }
  }
  
  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: const Icon(Icons.add, color: Colors.white),
      onPressed: () async {
        // 글쓰기 페이지로 이동
        await Navigator.push(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) {
              return WritePage();
            },
          ),
        );
        _loadPosts();
      },
    );
  }
  
  Widget _buildActiveUsers() {
    // 활동이 있는 경우와 없는 경우를 구분
    if (_posts.isEmpty) {
      return Container(); // 활동이 없는 경우 빈 컨테이너 반환
    }
    
    // 활동이 있는 경우 통계 요약 카드
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '활동 통계',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItemWithIcon(Icons.article, '${_posts.length}', '게시물'),
              _buildStatItemWithIcon(Icons.access_time, '${_totalMinutes ~/ 60}분', '시간'),
              _buildStatItemWithIcon(
                Icons.check_circle_outline, 
                '${_tasks.where((t) => t.isCompleted).length}/${_tasks.length}', 
                '완료'
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItemWithIcon(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue),
        SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
  
  // 하단 내비게이션 바
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        if (_isServicesView && index != 1) {
          // 서비스 상세 페이지에서 '관리' 탭이 아닌 다른 탭을 선택하면 서비스 뷰를 종료
          setState(() {
            _isServicesView = false;
            _currentIndex = index;
          });
        } else {
          setState(() {
            _currentIndex = index;
          });
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

  AppBar _buildAppBar() {
    final showPremiumBadge = _isPremium;
    final currentUser = FirebaseAuth.instance.currentUser;
    final username = currentUser?.displayName ?? '사용자';
    
    // 서비스 상세 페이지일 경우 해당 서비스 제목 표시
    if (_isServicesView) {
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _services[_selectedServiceIndex]['title'],
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            setState(() {
              _isServicesView = false;
            });
          },
        ),
      );
    }
    
    // 기본 앱바 (피드 페이지용)
    return AppBar(
      backgroundColor: const Color(0xFFF1F2F3),
      elevation: 0,
      title: Column(
        children: [
          Image.asset(
            'assets/ThinQ_logo2.png',
            width: 150,
          ),
          Text(
            '$username님의 활동 피드',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(
          Icons.settings,
          color: Colors.black,
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
      actions: [
        if (showPremiumBadge) ...[
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
        ],
        IconButton(
          icon: Icon(
            Icons.logout_rounded,
            color: Colors.black,
          ),
          onPressed: () async {
            // 로그아웃 처리
            await FirebaseAuth.instance.signOut();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) {
                  return LoginPage();
                },
              ),
            );

            // Google Analytics 이벤트 로깅
            await FirebaseAnalytics.instance.logEvent(
              name: 'logout',
            );
          },
        ),
      ],
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
      setState(() {
        _tasks = tasks;
        _totalMinutes = totalMinutes;
      });
    } catch (e) {
      print('태스크 로딩 오류: $e');
    }
  }

  Future<void> _loadPosts() async {
    // 현재 로그인한 사용자의 uid 가져오기
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }
    final currentUid = currentUser.uid;

    // FirebaseFirestore로부터 현재 사용자의 포스트만 가져옵니다.
    final snapshot = await FirebaseFirestore.instance
        .collection("posts")
        .where("uid", isEqualTo: currentUid)
        .orderBy("createdAt", descending: true)
        .get();
    final documents = snapshot.docs;

    // FirebaseFirestore로부터 받아온 데이터를 Post 객체로 변환합니다.
    List<Post> posts = [];

    for (final doc in documents) {
      final data = doc.data();
      final uid = data['uid'];
      final username = data['username'];
      final description = data['description'];
      final imageUrl = data['imageUrl'];
      final createdAt = data['createdAt'];
      posts.add(
        Post(
          uid: uid,
          username: username,
          description: description,
          imageUrl: imageUrl,
          createdAt: createdAt,
        ),
      );
    }

    // Post 객체를 이용하여 화면을 다시 그립니다.
    setState(() {
      _posts = posts;
    });
  }

  Future<void> _toggleTaskStatus(Task task) async {
    try {
      // 상태 토글
      final newStatus = !task.isCompleted;
      
      // Firestore 업데이트
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(task.id)
          .update({'isCompleted': newStatus});
      
      // 로컬 상태 업데이트
      setState(() {
        final index = _tasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          _tasks[index] = task.copyWith(isCompleted: newStatus);
          
          // 총 시간 업데이트
          if (newStatus) {
            _totalMinutes += task.duration;
          } else {
            _totalMinutes -= task.duration;
          }
        }
      });
      
      // 분석 이벤트 전송
      await FirebaseAnalytics.instance.logEvent(
        name: newStatus ? 'task_completed' : 'task_uncompleted',
        parameters: {
          'task_id': task.id,
          'duration': task.duration,
        },
      );
    } catch (e) {
      print('작업 상태 변경 오류: $e');
      // 에러 처리
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('작업 상태를 변경하는 중 오류가 발생했습니다.')),
      );
    }
  }

  // 활동 중인 사용자 목록을 위한 리스너 설정
  void _setupActiveUsersListener() {
    FirebaseDatabase.instance.ref().child('active_users').onValue.listen(
      (event) {
        setState(() {
          _activeUsers = event.snapshot.value == null
              ? []
              : List<String?>.from(
                  event.snapshot.value as List<dynamic>,
                );
        });
      },
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
        if (data != null) {
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
    if (notice.isEmpty) {
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
  
  Widget _buildEmptyFeed() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined, 
            size: 80, 
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 20),
          Text(
            '아직 작성된 게시물이 없습니다',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '오른쪽 상단의 + 버튼을 눌러 처음 작성해보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text('새 게시물 작성하기'),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (context) {
                    return WritePage();
                  },
                ),
              );
              _loadPosts();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2465D9),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
